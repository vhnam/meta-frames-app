import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';

import '../../domain/models/models.dart';
import '../../domain/utils.dart';
import '../local/local_store.dart';
import '../repositories/auth_repository.dart';
import '../repositories/roll_repository.dart';
import '../services/api_client.dart';
import '../services/session_store.dart';
import 'pending_op.dart';

/// The endpoints the engine uses, bound to one server and one token. Built per
/// drain from the binding captured when it starts, never from the app's
/// current settings, so a queued change cannot reach another server.
class SyncRemote {
  const SyncRemote({required this.rolls, required this.auth});
  final RollRepository rolls;
  final AuthRepository auth;
}

typedef SyncRemoteFactory = SyncRemote Function(
  SessionBinding binding,
  String token,
);

/// Why the engine is not sending.
enum SyncPause {
  none,

  /// The server cannot be reached; retrying with back-off.
  offline,

  /// The session ended (401). Changes wait for the same account to sign in.
  signedOut,
}

class SyncStatus {
  const SyncStatus({
    this.running = false,
    this.pause = SyncPause.none,
    this.lastSynced,
    this.nextRetry,
  });
  final bool running;
  final SyncPause pause;
  final DateTime? lastSynced, nextRetry;
}

/// Sends a partition's outbox, oldest first, one operation at a time.
///
/// - One drain at a time per partition: a sync asked for while one runs makes
///   that drain go round once more.
/// - Before each operation the session must still be the one captured at the
///   start (same generation, so same token, server and user); otherwise the
///   drain stops. An answer that comes back under another generation is not
///   trusted: its operation becomes unknown.
/// - An operation is marked sending, with its attempt counted, before its
///   request leaves. A network error, timeout or 5xx after that means the
///   outcome is unknown; the operation is read back before anything that
///   depends on it is sent.
class SyncEngine {
  SyncEngine({
    required this.store,
    required this.session,
    required this.remote,
    this.retryDelays = const [
      Duration(seconds: 5),
      Duration(seconds: 15),
      Duration(seconds: 30),
      Duration(minutes: 1),
      Duration(minutes: 2),
      Duration(minutes: 5),
    ],
  });

  final LocalStore store;
  final SessionStore session;
  final SyncRemoteFactory remote;
  final List<Duration> retryDelays;

  final status = ValueNotifier<SyncStatus>(const SyncStatus());

  /// Rolls whose stored data an operation just changed, for the screens.
  final _done = StreamController<String>.broadcast();
  Stream<String> get completedRolls => _done.stream;

  Future<void>? _drain;
  bool _again = false, _stopped = false;
  Timer? _retry;
  int _failures = 0;

  /// Sends what can be sent. Returns when the drain this call joined ends.
  Future<void> sync() {
    if (_stopped) return Future.value();
    if (_drain != null) {
      _again = true;
      return _drain!;
    }
    _retry?.cancel();
    _retry = null;
    final run = _run().whenComplete(() => _drain = null);
    _drain = run;
    return run;
  }

  /// Something reached the server: if waiting to retry, retry now rather
  /// than at the end of the back-off.
  void wakeIfOffline() {
    if (!_stopped && status.value.pause == SyncPause.offline) unawaited(sync());
  }

  /// Stops sending and waits for a request on its way to settle, so the store
  /// can be closed safely.
  Future<void> stop() async {
    _stopped = true;
    _retry?.cancel();
    await _drain;
    await _done.close();
  }

  Future<void> _run() async {
    do {
      _again = false;
      await _drainOnce();
    } while (_again && !_stopped);
  }

  void _set(SyncStatus s) {
    if (!_stopped) status.value = s;
  }

  Future<void> _drainOnce() async {
    final token = session.token;
    final binding = session.binding;
    final generation = session.generation;
    if (token == null ||
        binding == null ||
        binding.server != store.key.server ||
        binding.userId != store.key.userId) {
      _set(SyncStatus(pause: SyncPause.signedOut, lastSynced: _lastSynced));
      return;
    }
    if (await store.nextRunnable() == null) {
      _set(SyncStatus(lastSynced: _lastSynced));
      return;
    }
    _set(SyncStatus(running: true, lastSynced: _lastSynced));
    final api = remote(binding, token);
    bool current() =>
        !_stopped && !store.isClosed && session.generation == generation;

    // One cheap read first: proves the server is reachable before anything is
    // marked as attempted, and that the token still belongs to this account.
    try {
      final me = await api.auth.me();
      if (!current()) return _idle();
      if (me.id != binding.userId) return _idle();
    } on ApiException catch (e) {
      if (!current()) return _idle();
      if (e.status == 401) return _signedOut(token);
      return _offline();
    }

    while (current()) {
      final op = await store.nextRunnable();
      if (!current()) return _idle();
      if (op == null) break;
      final Outcome outcome;
      if (op.state == OpState.unknown) {
        outcome = await _reconcile(api, op, current);
      } else if (op.kind.isNotes && op.base == null) {
        outcome = await _resolveBase(api, op, current);
      } else {
        outcome = await _send(api, op, current);
      }
      switch (outcome) {
        case Outcome.next:
          continue;
        case Outcome.offline:
          return _offline();
        case Outcome.signedOut:
          return _signedOut(token);
        case Outcome.stop:
          return _idle();
      }
    }
    _failures = 0;
    _lastSynced = DateTime.now();
    _idle();
  }

  DateTime? _lastSynced;

  void _idle() => _set(SyncStatus(lastSynced: _lastSynced));

  void _offline() {
    final delay = retryDelays[_failures.clamp(0, retryDelays.length - 1)];
    _failures++;
    final next = DateTime.now().add(delay);
    _set(
      SyncStatus(
        pause: SyncPause.offline,
        lastSynced: _lastSynced,
        nextRetry: next,
      ),
    );
    _retry?.cancel();
    if (!_stopped) _retry = Timer(delay, sync);
  }

  /// The session ended. The app's session is cleared only if it still holds
  /// the token that was refused, as `ApiClient` does for its own requests.
  Future<void> _signedOut(String token) async {
    _set(SyncStatus(pause: SyncPause.signedOut, lastSynced: _lastSynced));
    if (session.token == token) await session.setToken(null);
  }

  Future<Outcome> _send(
    SyncRemote api,
    PendingOp op,
    bool Function() current,
  ) async {
    final selected = op;
    final claimed = await store.claim(op);
    // Edited or discarded since it was selected: select again.
    if (claimed == null) return Outcome.next;
    op = claimed;
    // The session may have ended while the claim committed. The request has
    // not left: put the operation back as it was, and send nothing. No await
    // lies between this check and the request below.
    if (!current()) {
      await store.release(op, selected);
      return Outcome.stop;
    }
    try {
      switch (op.kind) {
        case OpKind.frameNotes:
          final frame = await api.rolls.saveFrameNotes(
            op.rollId,
            op.frame!,
            op.text.trim().isEmpty ? null : op.text,
            baseNotes: op.base,
          );
          if (!current()) return await _lost(op);
          await store.complete(op, frame: frame.json);
        case OpKind.rollNotes:
          final detail = await api.rolls.saveRollNotes(
            op.rollId,
            op.text,
            baseDescription: op.base,
          );
          if (!current()) return await _lost(op);
          await store.complete(op, detail: detail.json);
        case OpKind.load:
          final detail = await api.rolls.load(op.rollId, op.loadRequest);
          if (!current()) return await _lost(op);
          await store.complete(op, detail: detail.json);
        case OpKind.finish:
          final detail = await api.rolls.finish(op.rollId, op.finishDate);
          if (!current()) return await _lost(op);
          await store.complete(op, detail: detail.json);
      }
      _done.add(op.rollId);
      return Outcome.next;
    } on ApiException catch (e) {
      if (!current()) return await _lost(op);
      if (e.isNetwork || e.status >= 500) {
        await store.markUnknown(op, e.message);
        return Outcome.offline;
      }
      if (e.status == 401) {
        await store.markUnknown(op, e.message);
        return Outcome.signedOut;
      }
      if (e.status == 400) {
        await store.markFailed(op, '${e.code}: ${e.message}');
        _done.add(op.rollId);
        return Outcome.next;
      }
      // 404, 409, 412, 422 and anything else the server refused on the
      // merits: someone else changed it. Keep both sides for the user.
      await store.markConflict(
        op,
        error: e.code,
        serverValue: await _serverValue(api, op),
      );
      _done.add(op.rollId);
      return Outcome.next;
    }
  }

  /// The session changed while the request was out: nothing it answered is
  /// stored, and the operation is read back next time.
  Future<Outcome> _lost(PendingOp op) async {
    if (!store.isClosed) await store.markUnknown(op, 'session changed');
    return Outcome.stop;
  }

  /// Reads back an operation whose outcome is unknown, then decides: the
  /// server holds what it asked for → done; it still holds what the operation
  /// started from → send again (safe: the write is conditional); anything
  /// else → conflict.
  Future<Outcome> _reconcile(
    SyncRemote api,
    PendingOp op,
    bool Function() current,
  ) async {
    try {
      switch (op.kind) {
        case OpKind.frameNotes:
          final (frame, json) = await _frame(api, op);
          if (!current()) return Outcome.stop;
          final stored = frame?.notes ?? '';
          if (sameNotes(stored, op.text)) {
            await store.complete(op, frame: json, frameMissing: json == null);
            _done.add(op.rollId);
          } else if (op.base != null && sameNotes(stored, op.base)) {
            await store.markPending(op);
          } else {
            await store.markConflict(
              op,
              error: 'frame_notes_conflict',
              serverValue: stored,
            );
            _done.add(op.rollId);
          }
        case OpKind.rollNotes:
          final json = await _detailJson(api, op.rollId);
          if (!current()) return Outcome.stop;
          final stored = (json['roll'] as Map)['description'] as String? ?? '';
          if (sameNotes(stored, op.text)) {
            await store.complete(op, detail: json);
            _done.add(op.rollId);
          } else if (op.base != null && sameNotes(stored, op.base)) {
            await store.markPending(op);
          } else {
            await store.markConflict(
              op,
              error: 'roll_notes_conflict',
              serverValue: stored,
            );
            _done.add(op.rollId);
          }
        case OpKind.load || OpKind.finish:
          final json = await _detailJson(api, op.rollId);
          if (!current()) return Outcome.stop;
          final detail = RollDetail.fromJson(json);
          switch (stepOutcome(op, detail)) {
            case StepOutcome.landed:
              await store.complete(op, detail: json);
            case StepOutcome.notYet:
              await store.markPending(op);
            case StepOutcome.other:
              await store.markConflict(
                op,
                error: op.kind == OpKind.load
                    ? 'roll_loaded_elsewhere'
                    : 'roll_finished_elsewhere',
                serverValue: describeRoll(detail),
              );
          }
          _done.add(op.rollId);
      }
      return Outcome.next;
    } on ApiException catch (e) {
      if (!current()) return Outcome.stop;
      if (e.status == 401) return Outcome.signedOut;
      if (e.isNetwork || e.status >= 500) return Outcome.offline;
      // The roll is gone (404) or unreadable: the user decides.
      await store.markConflict(op, error: e.code, serverValue: null);
      _done.add(op.rollId);
      return Outcome.next;
    }
  }

  /// A note edited while its saved text was not on the phone. The saved text
  /// is read first: already the same → done without a write; empty → the
  /// edit is based on that and sent; anything else → conflict, both kept.
  Future<Outcome> _resolveBase(
    SyncRemote api,
    PendingOp op,
    bool Function() current,
  ) async {
    try {
      final String stored;
      Map<String, dynamic>? frameJson, detailJson;
      if (op.kind == OpKind.frameNotes) {
        final (frame, json) = await _frame(api, op);
        frameJson = json;
        stored = frame?.notes ?? '';
      } else {
        detailJson = await _detailJson(api, op.rollId);
        stored = (detailJson['roll'] as Map)['description'] as String? ?? '';
      }
      if (!current()) return Outcome.stop;
      if (sameNotes(stored, op.text)) {
        await store.complete(
          op,
          detail: detailJson,
          frame: frameJson,
          frameMissing: op.kind == OpKind.frameNotes && frameJson == null,
        );
      } else if (stored.trim().isEmpty) {
        await store.markPending(op, base: '', setBase: true);
      } else {
        await store.markConflict(
          op,
          error: op.kind == OpKind.frameNotes
              ? 'frame_notes_conflict'
              : 'roll_notes_conflict',
          serverValue: stored,
        );
      }
      _done.add(op.rollId);
      return Outcome.next;
    } on ApiException catch (e) {
      if (!current()) return Outcome.stop;
      if (e.status == 401) return Outcome.signedOut;
      if (e.isNetwork || e.status >= 500) return Outcome.offline;
      await store.markConflict(op, error: e.code, serverValue: null);
      _done.add(op.rollId);
      return Outcome.next;
    }
  }

  /// The server's side of a conflict, as text, best effort.
  Future<String?> _serverValue(SyncRemote api, PendingOp op) async {
    try {
      switch (op.kind) {
        case OpKind.frameNotes:
          return (await _frame(api, op)).$1?.notes ?? '';
        case OpKind.rollNotes:
          return (await api.rolls.roll(op.rollId)).roll.description ?? '';
        case OpKind.load || OpKind.finish:
          return describeRoll(await api.rolls.roll(op.rollId));
      }
    } on ApiException {
      return null;
    }
  }

  Future<(Frame?, Map<String, dynamic>?)> _frame(
    SyncRemote api,
    PendingOp op,
  ) async {
    try {
      final f = await api.rolls.frame(op.rollId, op.frame!);
      return (f, f.json);
    } on ApiException catch (e) {
      if (e.status == 404) return (null, null);
      rethrow;
    }
  }

  Future<Map<String, dynamic>> _detailJson(
    SyncRemote api,
    String rollId,
  ) async => (await api.rolls.roll(rollId)).json;
}

enum Outcome { next, offline, signedOut, stop }

enum StepOutcome {
  /// The server records what the step asked for (perhaps moved on since).
  landed,

  /// The roll is still where the step started from.
  notYet,

  /// Something else happened to the roll.
  other,
}

/// Decides from a fresh read whether a load or finish landed. Only an outcome
/// that can be established is accepted: a load counts as landed when the roll
/// is (or was, and has moved on from) in this camera with this start date,
/// shot ISO and lens set; a finish when the roll is done shooting (or past it)
/// on this date. Anything else is not assumed.
StepOutcome stepOutcome(PendingOp op, RollDetail detail) {
  final r = detail.roll;
  switch (op.kind) {
    case OpKind.load:
      if (r.status == RollStatus.inStock) return StepOutcome.notYet;
      final req = op.loadRequest;
      final wantIso =
          req.shotIso != null && detail.stock.isBoxSpeed(req.shotIso!)
          ? null
          : req.shotIso;
      final sameStart =
          r.startedAt != null && ymd(r.startedAt!) == ymd(req.startedAt);
      final sameLenses =
          op.payload['fixedLens'] == true ||
          setEquals({...req.lensIds}, {for (final l in detail.lenses) l.id});
      if (r.cameraId == req.cameraId &&
          sameStart &&
          r.shotIso == wantIso &&
          sameLenses) {
        return StepOutcome.landed;
      }
      return StepOutcome.other;
    case OpKind.finish:
      final date = ymd(op.finishDate);
      if (r.status == RollStatus.inCamera && r.cameraId == op.cameraId) {
        return StepOutcome.notYet;
      }
      final past = const {
        RollStatus.doneShooting,
        RollStatus.atLab,
        RollStatus.developed,
        RollStatus.scanned,
      }.contains(r.status);
      if (past && r.finishedAt != null && ymd(r.finishedAt!) == date) {
        return StepOutcome.landed;
      }
      return StepOutcome.other;
    case OpKind.frameNotes || OpKind.rollNotes:
      throw ArgumentError('not a step: ${op.kind}');
  }
}

/// The server's state of a roll, for a conflict: "In camera · Nikon FM2 ·
/// since 2026-11-01".
String describeRoll(RollDetail d) {
  final r = d.roll;
  return [
    r.status.label,
    ?r.cameraName,
    if (r.startedAt != null) 'started ${ymd(r.startedAt!)}',
    if (r.finishedAt != null) 'finished ${ymd(r.finishedAt!)}',
    if (r.shotIso != null) 'ISO ${r.shotIso}',
  ].join(' · ');
}

/// For tests and logs.
String debugOp(PendingOp op) => jsonEncode({
  'kind': op.kind.name,
  'roll': op.rollId,
  'state': op.state.name,
  'base': op.base,
  'text': op.payload['text'],
});
