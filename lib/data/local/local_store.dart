import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';

import '../../domain/utils.dart';
import '../services/session_store.dart';
import '../sync/pending_op.dart';
import '../sync/projection.dart';

/// One account on one server: the unit everything kept on the device is filed
/// under. Each partition is its own SQLite file, so nothing can be read, shown
/// or sent across accounts or servers by mistake.
@immutable
class PartitionKey {
  const PartitionKey(this.server, this.userId);
  final String server, userId;

  /// `mf_<16 hex digits>.db`. The clear-text server and user are kept inside
  /// the file and checked when it opens.
  String get fileName => 'mf_${fnv64('$server|$userId')}.db';

  @override
  bool operator ==(Object other) =>
      other is PartitionKey && other.server == server && other.userId == userId;

  @override
  int get hashCode => Object.hash(server, userId);
}

/// What another partition holds, without its contents: enough to say "3
/// changes are kept on this phone for ana@… on https://…" and to discard them.
class PartitionSummary {
  const PartitionSummary({
    required this.key,
    required this.email,
    required this.openOps,
    required this.attentionOps,
    required this.drafts,
    required this.path,
  });
  final PartitionKey key;
  final String email;

  /// Changes not on the server yet, and those of them that need the user.
  final int openOps, attentionOps;
  final int drafts;
  final String path;

  bool get hasUnsynced => openOps > 0 || drafts > 0;
}

/// A stored read: the server's answer and when it was fetched. [status] 404
/// records "the server has no such frame", which is not the same as never
/// having asked.
class Snapshot {
  const Snapshot(this.status, this.json, this.fetchedAt);
  final int status;
  final dynamic json;
  final DateTime fetchedAt;
}

/// A form saved before it was sent, so a timeout, an app kill or a restart
/// never loses what the user typed. [json] is the form's request plus the
/// client id or idempotency key that makes resending it safe.
class Draft {
  const Draft({
    required this.id,
    required this.kind,
    required this.json,
    required this.updatedAt,
  });
  final String id;
  final DraftKind kind;
  final Map<String, dynamic> json;
  final DateTime updatedAt;

  /// A line to show in a picker or in Sync status.
  String get label => json['label'] as String? ?? kind.name;

  /// The last error from sending it, if any.
  String? get error => json['error'] as String?;
}

enum DraftKind { camera, lens, stock, lab, rolls }

const _schemaVersion = 1;
const _doneKeptFor = Duration(days: 7);

/// How the stored row of an operation compares with the operation as it was
/// read (see `LocalStore._row`).
enum _Row { asRead, removed, changed }

/// The device copy of one partition: stored reads (snapshots), the outbox of
/// changes waiting for the server, and drafts.
///
/// Every outbox change and the projection the screens show from it commit in
/// one transaction: the projection is computed from the outbox, and a change
/// that reaches the server rewrites the affected stored reads in the same
/// transaction that marks it done.
class LocalStore {
  LocalStore._(this._db, this.key, this.path);

  final Database _db;
  final PartitionKey key;
  final String path;

  /// Moves on every change to the outbox or drafts. Screens listing pending
  /// changes refresh on it.
  final changes = ValueNotifier<int>(0);

  /// Moves when an operation reaches the server or is dropped. A read started
  /// before that may hold the old state, so its answer is not stored.
  int get epoch => _epoch;
  int _epoch = 0;

  bool _closed = false;
  bool get isClosed => _closed;

  /// Opens (or creates) the partition's file in [directory]. Operations left
  /// `sending` by an app that was killed become `unknown`; done operations
  /// older than a week are purged.
  static Future<LocalStore> open(
    DatabaseFactory factory,
    String directory,
    PartitionKey key, {
    String email = '',
  }) async {
    final path = directory == inMemoryDatabasePath
        ? inMemoryDatabasePath
        : p.join(directory, key.fileName);
    final db = await factory.openDatabase(
      path,
      options: OpenDatabaseOptions(
        version: _schemaVersion,
        onCreate: (db, _) => _create(db),
        singleInstance: false,
      ),
    );
    final store = LocalStore._(db, key, path);
    await store._claim(email);
    await store._recover();
    return store;
  }

  static Future<void> _create(Database db) async {
    final batch = db.batch()
      ..execute('CREATE TABLE meta(key TEXT PRIMARY KEY, value TEXT NOT NULL)')
      ..execute(
        'CREATE TABLE snapshot(key TEXT PRIMARY KEY, status INTEGER NOT NULL, '
        'json TEXT, fetched_at INTEGER NOT NULL)',
      )
      ..execute(
        'CREATE TABLE outbox(seq INTEGER PRIMARY KEY AUTOINCREMENT, '
        'op_id TEXT NOT NULL UNIQUE, kind TEXT NOT NULL, roll_id TEXT NOT NULL, '
        'camera_id TEXT, frame INTEGER, payload TEXT NOT NULL, base TEXT, '
        'state TEXT NOT NULL, attempts INTEGER NOT NULL DEFAULT 0, '
        'predecessor TEXT, last_error TEXT, server_value TEXT, '
        'created_at INTEGER NOT NULL, updated_at INTEGER NOT NULL)',
      )
      ..execute('CREATE INDEX outbox_state ON outbox(state)')
      ..execute(
        'CREATE TABLE draft(id TEXT PRIMARY KEY, kind TEXT NOT NULL, '
        'json TEXT NOT NULL, created_at INTEGER NOT NULL, '
        'updated_at INTEGER NOT NULL)',
      );
    await batch.commit(noResult: true);
  }

  /// Records whose file this is, or refuses a file that belongs to another
  /// account (a hash collision, or a file copied by hand).
  Future<void> _claim(String email) async {
    final meta = await _meta();
    final server = meta['server'], user = meta['userId'];
    if (server == null) {
      await _db.transaction((txn) async {
        for (final e in {
          'server': key.server,
          'userId': key.userId,
          'email': email,
        }.entries) {
          await txn.insert('meta', {
            'key': e.key,
            'value': e.value,
          }, conflictAlgorithm: ConflictAlgorithm.replace);
        }
      });
    } else if (server != key.server || user != key.userId) {
      await _db.close();
      throw StateError('$path belongs to another account');
    } else if (email.isNotEmpty && meta['email'] != email) {
      await _db.insert('meta', {
        'key': 'email',
        'value': email,
      }, conflictAlgorithm: ConflictAlgorithm.replace);
    }
  }

  Future<Map<String, String>> _meta() async => {
    for (final r in await _db.query('meta'))
      r['key'] as String: r['value'] as String,
  };

  Future<void> _recover() async {
    final now = DateTime.now().millisecondsSinceEpoch;
    await _db.transaction((txn) async {
      await txn.update(
        'outbox',
        {'state': OpState.unknown.name, 'updated_at': now},
        where: 'state = ?',
        whereArgs: [OpState.sending.name],
      );
      await txn.delete(
        'outbox',
        where: 'state = ? AND updated_at < ?',
        whereArgs: [OpState.done.name, now - _doneKeptFor.inMilliseconds],
      );
    });
  }

  Future<void> close() async {
    if (_closed) return;
    _closed = true;
    // Transactions run in the order they were asked for: one asked for before
    // this call (a draft being saved as the account signs out) finishes first
    // instead of finding the file closed.
    try {
      await _db.transaction((_) async {});
    } on Object catch (e) {
      debugPrint('Closing $path: $e');
    }
    await _db.close();
    changes.dispose();
  }

  void _changed() {
    if (!_closed) changes.value++;
  }

  // Snapshots.

  Future<Snapshot?> readSnapshot(String key) => _readSnapshot(_db, key);

  Future<Snapshot?> _readSnapshot(DatabaseExecutor db, String key) async {
    final rows = await db.query('snapshot', where: 'key = ?', whereArgs: [key]);
    if (rows.isEmpty) return null;
    return _snapshot(rows.single);
  }

  Snapshot _snapshot(Map<String, Object?> r) => Snapshot(
    r['status'] as int,
    r['json'] == null ? null : jsonDecode(r['json'] as String),
    DateTime.fromMillisecondsSinceEpoch(r['fetched_at'] as int),
  );

  /// Stores the server's answer to [key], unless an operation reached the
  /// server since the read began (its [epoch] then differs): the answer may
  /// predate it and must not replace what that operation wrote. Returns
  /// whether it was stored. The check runs inside a transaction, which the
  /// database runs one at a time with `complete` and `discard` (both raise the
  /// epoch inside theirs): the answer is stored wholly before them, and they
  /// then overwrite it, or wholly after, and it is refused.
  Future<bool> writeSnapshot(
    String key,
    int status,
    dynamic json, {
    required int epoch,
  }) async {
    if (_closed || epoch != _epoch) return false;
    return _db.transaction((txn) async {
      if (_closed || epoch != _epoch) return false;
      await txn.insert('snapshot', {
        'key': key,
        'status': status,
        'json': json == null ? null : jsonEncode(json),
        'fetched_at': DateTime.now().millisecondsSinceEpoch,
      }, conflictAlgorithm: ConflictAlgorithm.replace);
      return true;
    });
  }

  /// The stored answer for a frame, or one derived from the stored roll: a
  /// roll's page lists every frame the server had, so a frame missing from it
  /// did not exist when it was fetched. Null when neither was ever fetched.
  Future<Snapshot?> readFrameSnapshot(String rollId, int n) =>
      _readFrameSnapshot(_db, rollId, n);

  Future<Snapshot?> _readFrameSnapshot(
    DatabaseExecutor db,
    String rollId,
    int n,
  ) async {
    final own = await _readSnapshot(db, '/rolls/$rollId/frames/$n');
    if (own != null) return own;
    final roll = await _readSnapshot(db, '/rolls/$rollId');
    if (roll == null || roll.status != 200) return null;
    for (final f in (roll.json['frames'] as List? ?? const [])) {
      if ((f as Map)['number'] == n) return Snapshot(200, f, roll.fetchedAt);
    }
    return Snapshot(404, null, roll.fetchedAt);
  }

  /// The stored answer for one camera, or its entry in the stored camera
  /// list (the list holds every camera, as the detail does).
  Future<Snapshot?> readCameraSnapshot(String id) =>
      _readCameraSnapshot(_db, id);

  Future<Snapshot?> _readCameraSnapshot(DatabaseExecutor db, String id) async {
    final own = await _readSnapshot(db, '/cameras/$id');
    if (own != null) return own;
    final all = await _readSnapshot(db, '/cameras');
    if (all == null || all.status != 200) return null;
    for (final c in all.json as List) {
      if ((c as Map)['id'] == id) return Snapshot(200, c, all.fetchedAt);
    }
    return null;
  }

  /// What a screen shows for the read [key]: the stored answer (as the read
  /// would find it, see [readFrameSnapshot] and [readCameraSnapshot]) and the
  /// open operations, read in one transaction. `complete` and `discard` run
  /// in theirs, so the two are from the same moment: a change either is in
  /// the snapshot and out of the operations, or the other way round, never
  /// in neither.
  Future<({Snapshot? snapshot, List<PendingOp> ops})> view(String key) =>
      _db.transaction((txn) async {
        final read = ReadKey.parse(key);
        final snapshot = switch (read.kind) {
          ReadKind.frame => await _readFrameSnapshot(
            txn,
            read.rollId!,
            read.frame!,
          ),
          ReadKind.camera => await _readCameraSnapshot(
            txn,
            Uri.parse(key).pathSegments[1],
          ),
          _ => await _readSnapshot(txn, key),
        };
        return (snapshot: snapshot, ops: await _openOps(txn));
      });

  // Outbox.

  Future<List<PendingOp>> openOps() => _openOps(_db);

  Future<List<PendingOp>> _openOps(DatabaseExecutor db) async => [
    for (final r in await db.query(
      'outbox',
      where: 'state != ?',
      whereArgs: [OpState.done.name],
      orderBy: 'seq',
    ))
      PendingOp.fromRow(r),
  ];

  Future<PendingOp?> op(String opId) async {
    final rows = await _db.query(
      'outbox',
      where: 'op_id = ?',
      whereArgs: [opId],
    );
    return rows.isEmpty ? null : PendingOp.fromRow(rows.single);
  }

  /// Records a notes edit. An edit nobody has tried to send yet is rewritten
  /// in place, keeping its base. Otherwise the edit follows the last one on
  /// the same note, based on that one's text, so it applies whether or not
  /// the earlier one has landed. With no earlier edit, [seenBase] is the text
  /// the user saw (null when it was not on the phone). Returns the operation
  /// to send, or null when the edit changes nothing.
  Future<PendingOp?> enqueueNotes({
    required OpKind kind,
    required String rollId,
    int? frame,
    required String text,
    required String? seenBase,
  }) async {
    assert(kind.isNotes);
    final now = DateTime.now().millisecondsSinceEpoch;
    final opId = await _db.transaction((txn) async {
      final latest = await txn.query(
        'outbox',
        where:
            'kind = ? AND roll_id = ? AND state != ? AND '
            '${frame == null ? 'frame IS NULL' : 'frame = ?'}',
        whereArgs: [kind.name, rollId, OpState.done.name, ?frame],
        orderBy: 'seq DESC',
        limit: 1,
      );
      final last = latest.isEmpty ? null : PendingOp.fromRow(latest.single);
      if (last != null) {
        if (last.text == text) return last.opId;
        if (last.state == OpState.pending && last.attempts == 0) {
          await txn.update(
            'outbox',
            {
              'payload': jsonEncode({'text': text}),
              'updated_at': now,
            },
            where: 'seq = ?',
            whereArgs: [last.seq],
          );
          return last.opId;
        }
      } else if (seenBase != null && sameNotes(seenBase, text)) {
        return null;
      }
      final id = newId();
      await txn.insert('outbox', {
        'op_id': id,
        'kind': kind.name,
        'roll_id': rollId,
        'frame': frame,
        'payload': jsonEncode({'text': text}),
        'base': last == null ? seenBase : last.text,
        'state': OpState.pending.name,
        'predecessor': last?.opId,
        'created_at': now,
        'updated_at': now,
      });
      return id;
    });
    _changed();
    return opId == null ? null : op(opId);
  }

  /// Records a load or finish. These are never merged: each is its own step,
  /// sent after every earlier step on its roll and camera.
  Future<PendingOp> enqueueStep({
    required OpKind kind,
    required String rollId,
    String? cameraId,
    required Map<String, dynamic> payload,
  }) async {
    assert(!kind.isNotes);
    final now = DateTime.now().millisecondsSinceEpoch;
    final id = newId();
    await _db.insert('outbox', {
      'op_id': id,
      'kind': kind.name,
      'roll_id': rollId,
      'camera_id': cameraId,
      'payload': jsonEncode(payload),
      'state': OpState.pending.name,
      'created_at': now,
      'updated_at': now,
    });
    _changed();
    return (await op(id))!;
  }

  /// The first operation that can go now: pending or unknown, with no earlier
  /// open operation on any of its keys.
  Future<PendingOp?> nextRunnable() async {
    final open = await openOps();
    final held = <String>{};
    for (final op in open) {
      final blocked = op.keys.any(held.contains);
      held.addAll(op.keys);
      if (blocked) continue;
      if (op.state == OpState.pending || op.state == OpState.unknown) {
        return op;
      }
    }
    return null;
  }

  /// Marks [op] as on its way and counts the attempt, before any request
  /// leaves the device. Returns the claimed operation, as stored: send that
  /// one, not [op]. Returns null when the row changed since [op] was read (a
  /// newer edit was folded into it, or it was discarded): nothing is claimed
  /// and the caller selects again. The check and the claim run in one
  /// transaction, so an edit either lands before it, and is sent, or after
  /// it, and follows as its own operation.
  Future<PendingOp?> claim(PendingOp op) async {
    final claimed = await _db.transaction((txn) async {
      final rows = await txn.query(
        'outbox',
        where: 'seq = ?',
        whereArgs: [op.seq],
      );
      if (rows.isEmpty) return null;
      final stored = PendingOp.fromRow(rows.single);
      if (stored.state != op.state ||
          stored.attempts != op.attempts ||
          stored.base != op.base ||
          jsonEncode(stored.payload) != jsonEncode(op.payload)) {
        return null;
      }
      await txn.update(
        'outbox',
        {
          'state': OpState.sending.name,
          'attempts': op.attempts + 1,
          'updated_at': DateTime.now().millisecondsSinceEpoch,
        },
        where: 'seq = ?',
        whereArgs: [op.seq],
      );
      return PendingOp.fromRow(
        (await txn.query(
          'outbox',
          where: 'seq = ?',
          whereArgs: [op.seq],
        )).single,
      );
    });
    _changed();
    return claimed;
  }

  Future<void> markUnknown(PendingOp op, [String? error]) =>
      _update(op, {'state': OpState.unknown.name, 'last_error': error});

  /// Back to pending after a read showed the server still holds the base: the
  /// earlier attempt did not land, so sending again is safe.
  Future<void> markPending(
    PendingOp op, {
    String? base,
    bool setBase = false,
  }) => _update(op, {
    'state': OpState.pending.name,
    'last_error': null,
    'server_value': null,
    if (setBase) 'base': base,
  });

  Future<void> markConflict(
    PendingOp op, {
    required String error,
    String? serverValue,
  }) => _update(op, {
    'state': OpState.conflict.name,
    'last_error': error,
    'server_value': serverValue,
  });

  Future<void> markFailed(PendingOp op, String error) =>
      _update(op, {'state': OpState.failed.name, 'last_error': error});

  /// What to do with a decision made from [op] once it is time to apply it.
  ///
  /// [asRead]: the stored row is still [op]: same state and same request, so
  /// the decision applies. [removed]: the row is gone (dropped by the user):
  /// there is nothing to change and nothing is brought back. [changed]: the
  /// row moved on after [op] was read (a newer edit was folded into it, it
  /// was sent, finished or sent back to the user): whatever was decided from
  /// [op] must not be applied to it. This is how a stale card or an answer
  /// for a step already settled cannot revive or overwrite the row.
  Future<_Row> _row(DatabaseExecutor txn, PendingOp op) async {
    final rows = await txn.query(
      'outbox',
      columns: ['state', 'payload'],
      where: 'seq = ?',
      whereArgs: [op.seq],
    );
    if (rows.isEmpty) return _Row.removed;
    final row = rows.single;
    return row['state'] == op.state.name &&
            row['payload'] == jsonEncode(op.payload)
        ? _Row.asRead
        : _Row.changed;
  }

  Future<void> _update(PendingOp op, Map<String, Object?> values) async {
    await _db.transaction((txn) async {
      if (await _row(txn, op) != _Row.asRead) return;
      await txn.update(
        'outbox',
        {...values, 'updated_at': DateTime.now().millisecondsSinceEpoch},
        where: 'seq = ?',
        whereArgs: [op.seq],
      );
    });
    _changed();
  }

  /// Undoes [claim] for a request that never left the device (the session
  /// changed as the claim committed): [claimed] goes back to what [selected]
  /// was, attempts included, so it is neither counted as tried nor read back.
  Future<void> release(PendingOp claimed, PendingOp selected) async {
    if (_closed) return;
    await _db.transaction((txn) async {
      final rows = await txn.query(
        'outbox',
        where: 'seq = ? AND state = ? AND attempts = ?',
        whereArgs: [claimed.seq, OpState.sending.name, claimed.attempts],
      );
      if (rows.isEmpty) return;
      await txn.update(
        'outbox',
        {
          'state': selected.state.name,
          'attempts': selected.attempts,
          'updated_at': DateTime.now().millisecondsSinceEpoch,
        },
        where: 'seq = ?',
        whereArgs: [claimed.seq],
      );
    });
    _changed();
  }

  /// [op] reached the server. In one transaction: marks it done, stores what
  /// the server answered ([detail]: the roll's page; [frame]: the frame, null
  /// when it does not exist), and applies it to every stored list, so no
  /// screen shows the old state once the operation leaves the overlay.
  Future<void> complete(
    PendingOp op, {
    Map<String, dynamic>? detail,
    Map<String, dynamic>? frame,
    bool frameMissing = false,
  }) async {
    final now = DateTime.now().millisecondsSinceEpoch;
    await _db.transaction((txn) async {
      // Inside the transaction, ahead of any write: a read that began before
      // this point and asks to store its answer later is refused (see
      // writeSnapshot), and one already stored is overwritten below.
      _epoch++;
      // An edit folded into the row since [op] was read is not what reached
      // the server: leave it pending. A row dropped meanwhile stays dropped
      // (the update below finds nothing), and what the server answered is
      // still stored, as it is the server's state.
      if (await _row(txn, op) == _Row.changed) return;
      await txn.update(
        'outbox',
        {'state': OpState.done.name, 'last_error': null, 'updated_at': now},
        where: 'seq = ?',
        whereArgs: [op.seq],
      );
      Future<void> put(String key, int status, dynamic json) =>
          txn.insert('snapshot', {
            'key': key,
            'status': status,
            'json': json == null ? null : jsonEncode(json),
            'fetched_at': now,
          }, conflictAlgorithm: ConflictAlgorithm.replace);
      final rollKey = '/rolls/${op.rollId}';
      if (detail != null) await put(rollKey, 200, detail);
      if (op.kind == OpKind.frameNotes) {
        final frameKey = '$rollKey/frames/${op.frame}';
        if (frame != null || frameMissing) {
          await put(frameKey, frame == null ? 404 : 200, frame);
        }
      }
      for (final row in await txn.query('snapshot')) {
        final key = row['key'] as String;
        if (key == rollKey && detail != null) continue;
        final kind = ReadKey.parse(key).kind;
        if (kind == ReadKind.other || row['status'] != 200) continue;
        final json = jsonDecode(row['json'] as String);
        final next = applyOp(
          key,
          json,
          op,
          server: (detail?['roll'] as Map?)?.cast<String, dynamic>(),
        );
        await txn.update(
          'snapshot',
          {'json': jsonEncode(next)},
          where: 'key = ?',
          whereArgs: [key],
        );
      }
    });
    _changed();
  }

  /// "Use server" or "Discard": drops [op]. Every later open operation that
  /// shares one of its keys was based on it, so none of them is sent: each
  /// becomes a conflict for the user to look at again.
  Future<void> discard(PendingOp op) async {
    await _db.transaction((txn) async {
      _epoch++;
      // Already gone, or already done: nothing is being dropped, so nothing
      // that waits on it is held back.
      final stored = await txn.query(
        'outbox',
        columns: ['state'],
        where: 'seq = ?',
        whereArgs: [op.seq],
      );
      if (stored.isEmpty || stored.single['state'] == OpState.done.name) return;
      await txn.delete('outbox', where: 'seq = ?', whereArgs: [op.seq]);
      final later = await txn.query(
        'outbox',
        where: 'seq > ? AND state IN (?, ?)',
        whereArgs: [op.seq, OpState.pending.name, OpState.unknown.name],
        orderBy: 'seq',
      );
      final keys = {...op.keys};
      for (final row in later) {
        final dep = PendingOp.fromRow(row);
        if (!dep.keys.any(keys.contains)) continue;
        keys.addAll(dep.keys);
        await txn.update(
          'outbox',
          {
            'state': OpState.conflict.name,
            'last_error': predecessorDiscarded,
            'updated_at': DateTime.now().millisecondsSinceEpoch,
          },
          where: 'seq = ?',
          whereArgs: [dep.seq],
        );
      }
    });
    _changed();
  }

  /// Open operations, and those needing the user.
  Future<({int open, int attention})> counts() async {
    final rows = await _db.rawQuery(
      'SELECT state, COUNT(*) AS n FROM outbox WHERE state != ? GROUP BY state',
      [OpState.done.name],
    );
    var open = 0, attention = 0;
    for (final r in rows) {
      final n = r['n'] as int;
      open += n;
      if (r['state'] == OpState.conflict.name ||
          r['state'] == OpState.failed.name) {
        attention += n;
      }
    }
    return (open: open, attention: attention);
  }

  // Drafts.

  /// Saves [json] as draft [id], creating it on first save. Called before the
  /// first request, so what was typed survives a failed or lost request.
  Future<Draft> saveDraft(
    String id,
    DraftKind kind,
    Map<String, dynamic> json,
  ) async {
    final now = DateTime.now().millisecondsSinceEpoch;
    await _db.transaction((txn) async {
      final updated = await txn.update(
        'draft',
        {'json': jsonEncode(json), 'kind': kind.name, 'updated_at': now},
        where: 'id = ?',
        whereArgs: [id],
      );
      if (updated == 0) {
        await txn.insert('draft', {
          'id': id,
          'kind': kind.name,
          'json': jsonEncode(json),
          'created_at': now,
          'updated_at': now,
        });
      }
    });
    _changed();
    return Draft(
      id: id,
      kind: kind,
      json: json,
      updatedAt: DateTime.fromMillisecondsSinceEpoch(now),
    );
  }

  Future<Draft?> draft(String id) async {
    final rows = await _db.query('draft', where: 'id = ?', whereArgs: [id]);
    return rows.isEmpty ? null : _draft(rows.single);
  }

  Future<List<Draft>> drafts([DraftKind? kind]) async => [
    for (final r in await _db.query(
      'draft',
      where: kind == null ? null : 'kind = ?',
      whereArgs: kind == null ? null : [kind.name],
      orderBy: 'created_at',
    ))
      _draft(r),
  ];

  Draft _draft(Map<String, Object?> r) => Draft(
    id: r['id'] as String,
    kind: DraftKind.values.byName(r['kind'] as String),
    json: jsonDecode(r['json'] as String) as Map<String, dynamic>,
    updatedAt: DateTime.fromMillisecondsSinceEpoch(r['updated_at'] as int),
  );

  /// Moves draft [oldId] to [newId] with [json]: both writes or neither, so a
  /// close between them cannot leave the draft under both ids.
  Future<void> moveDraft(
    String oldId,
    String newId,
    DraftKind kind,
    Map<String, dynamic> json,
  ) async {
    final now = DateTime.now().millisecondsSinceEpoch;
    await _db.transaction((txn) async {
      await txn.delete('draft', where: 'id = ?', whereArgs: [oldId]);
      await txn.insert('draft', {
        'id': newId,
        'kind': kind.name,
        'json': jsonEncode(json),
        'created_at': now,
        'updated_at': now,
      });
    });
    _changed();
  }

  Future<void> deleteDraft(String id) async {
    await _db.delete('draft', where: 'id = ?', whereArgs: [id]);
    _changed();
  }

  /// The partitions in [directory], each read without its contents. Files
  /// that cannot be read are skipped.
  static Future<List<PartitionSummary>> list(
    DatabaseFactory factory,
    String directory,
  ) async {
    final dir = Directory(directory);
    if (!await dir.exists()) return const [];
    final out = <PartitionSummary>[];
    await for (final f in dir.list()) {
      final name = p.basename(f.path);
      if (!name.startsWith('mf_') || !name.endsWith('.db')) continue;
      try {
        final db = await factory.openDatabase(
          f.path,
          options: OpenDatabaseOptions(readOnly: true, singleInstance: false),
        );
        try {
          final meta = {
            for (final r in await db.query('meta'))
              r['key'] as String: r['value'] as String,
          };
          final ops = await db.rawQuery(
            'SELECT state, COUNT(*) AS n FROM outbox WHERE state != ? '
            'GROUP BY state',
            [OpState.done.name],
          );
          var open = 0, attention = 0;
          for (final r in ops) {
            open += r['n'] as int;
            if (r['state'] == OpState.conflict.name ||
                r['state'] == OpState.failed.name) {
              attention += r['n'] as int;
            }
          }
          final drafts =
              Sqflite.firstIntValue(
                await db.rawQuery('SELECT COUNT(*) FROM draft'),
              ) ??
              0;
          out.add(
            PartitionSummary(
              key: PartitionKey(meta['server']!, meta['userId']!),
              email: meta['email'] ?? '',
              openOps: open,
              attentionOps: attention,
              drafts: drafts,
              path: f.path,
            ),
          );
        } finally {
          await db.close();
        }
      } on Object catch (e) {
        debugPrint('Cannot read $name: $e');
      }
    }
    return out;
  }
}
