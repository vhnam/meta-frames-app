import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:sqflite/sqflite.dart';

import '../../domain/models/models.dart';
import '../repositories/settings_repository.dart';
import '../services/api_client.dart';
import '../services/session_store.dart';
import '../sync/sync_engine.dart';
import 'local_store.dart';

/// Opens the partition of the account the session is verified for, and only
/// that one.
///
/// A partition opens when the session has a binding for the server the app
/// points at; nothing is read from or written to any partition before that.
/// A token without a binding (just signed in, or restored from an older
/// version) is verified with `/auth/me` against the server it was issued for;
/// the answer binds the session only if the token and the server have not
/// changed meanwhile. Signing out, a server change or an expired session close
/// the partition and keep its file: what was not synced stays on the phone
/// until the same account signs in again on the same server, or the user
/// discards it.
class PartitionController extends ChangeNotifier {
  PartitionController({
    required this.session,
    required this.baseUrl,
    required this.remote,
    required this.verify,
    this.factory,
    this.directory,
  });

  final SessionStore session;
  final String Function() baseUrl;
  final SyncRemoteFactory remote;

  /// `/auth/me` for [token] on [server], pinned to both.
  final Future<User> Function(String server, String token) verify;

  /// Null when the device keeps no data (tests that do not need it).
  final DatabaseFactory? factory;
  final String? directory;

  LocalStore? _store;
  SyncEngine? _engine;
  LocalStore? get store => _store;
  SyncEngine? get engine => _engine;

  bool get enabled => factory != null && directory != null;

  Future<void> _queue = Future.value();
  bool _started = false, _disposed = false;
  String? _verifying;

  void start() {
    if (_started) return;
    _started = true;
    session.addListener(_onSession);
    _onSession();
  }

  void _onSession() => _serial(_reconcile);

  /// Runs [step] after the previous one, so a partition is never opened while
  /// another is closing, and two never open at once.
  Future<void> _serial(Future<void> Function() step) {
    final next = _queue.then((_) => _disposed ? null : step());
    _queue = next.catchError((Object e) => debugPrint('Partition: $e'));
    return next;
  }

  /// The partition this session should have open, if any.
  PartitionKey? get _wanted {
    final binding = session.binding;
    if (session.token == null || binding == null) return null;
    if (binding.server != normalizeBaseUrl(baseUrl())) return null;
    return PartitionKey(binding.server, binding.userId);
  }

  Future<void> _reconcile() async {
    if (!enabled) return;
    final want = _wanted;
    if (_store != null && _store!.key != want) await _close();
    if (want != null && _store == null) {
      final store = await LocalStore.open(
        factory!,
        directory!,
        want,
        email: session.binding!.email,
      );
      // The session may have moved on while the file opened.
      if (_wanted != want) {
        await store.close();
        return;
      }
      _store = store;
      _engine = SyncEngine(store: store, session: session, remote: remote);
      notifyListeners();
      unawaited(_engine!.sync());
    }
    if (session.token != null && session.binding == null) {
      unawaited(_bind());
    }
  }

  Future<void> _close() async {
    final engine = _engine, store = _store;
    _engine = null;
    _store = null;
    if (!_disposed) notifyListeners();
    await engine?.stop();
    await store?.close();
  }

  /// Verifies the current token and binds it to the account `/auth/me` names.
  /// Failure (offline) leaves the session unbound; [sync] tries again.
  Future<void> _bind() async {
    final token = session.token;
    final server = normalizeBaseUrl(baseUrl());
    if (token == null || _verifying == token) return;
    _verifying = token;
    try {
      final user = await verify(server, token);
      if (session.token != token || normalizeBaseUrl(baseUrl()) != server) {
        return;
      }
      await session.bind(
        SessionBinding(
          server: server,
          userId: user.id,
          email: user.email,
          name: user.name,
        ),
        forToken: token,
      );
    } on ApiException catch (e) {
      debugPrint('Cannot verify the session yet: ${e.message}');
    } finally {
      if (_verifying == token) _verifying = null;
    }
  }

  /// Sends what is waiting: on app resume, after a change, or when the user
  /// asks. Verifies the session first if it is not bound yet.
  Future<void> sync() async {
    if (session.token != null && session.binding == null) await _bind();
    await _engine?.sync();
  }

  /// Every partition kept on this phone, without contents.
  Future<List<PartitionSummary>> partitions() async {
    if (!enabled) return const [];
    return LocalStore.list(factory!, directory!);
  }

  /// Deletes a partition's file: its snapshots, unsynced changes and drafts.
  /// Only on the user's explicit choice.
  Future<void> discard(PartitionKey key) => _serial(() async {
    if (!enabled) return;
    if (_store?.key == key) await _close();
    final file = File('${directory!}/${key.fileName}');
    await factory!.deleteDatabase(file.path);
    if (!_disposed) notifyListeners();
    // A signed-in session gets a fresh, empty partition.
    await _reconcile();
  });

  @override
  void dispose() {
    if (_disposed) return;
    _disposed = true;
    session.removeListener(_onSession);
    unawaited(_close());
    super.dispose();
  }
}
