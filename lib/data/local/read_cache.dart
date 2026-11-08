import '../repositories/settings_repository.dart';
import '../services/api_client.dart';
import '../sync/projection.dart';
import 'local_store.dart';
import 'partition_controller.dart';

/// Thrown for a read the server could not answer and that was never stored on
/// this phone: "not available offline yet", which is not the same as empty.
class OfflineNoSnapshot extends ApiException {
  OfflineNoSnapshot()
    : super(
        0,
        'not_offline',
        'Not available offline yet. Open it once while connected to keep it on this phone.',
      );
}

/// Thrown when the session changed while a read was out: its answer belongs
/// to the previous account or server and is not shown.
class StaleSessionRead extends ApiException {
  StaleSessionRead() : super(0, 'session_changed', 'The session changed.');
}

/// Thrown when the server's answer was overtaken by a change of this phone
/// that reached the server meanwhile, and the device has nothing newer to
/// show: the answer is not shown, and reading again is safe.
class StaleRead extends ApiException {
  StaleRead()
    : super(0, 'read_stale', 'This changed while it was loading. Try again.');
}

/// Keeps the reads the field workflow needs in the open partition, serves them
/// when the server cannot be reached, and lays the partition's pending changes
/// over every answer (see `project`).
class DeviceReadCache implements ReadCache {
  DeviceReadCache(this._partitions);
  final PartitionController _partitions;

  @override
  ReadTicket? begin(String baseUrl, String path, Map<String, String?>? query) {
    if (!isKeptRead(path, query)) return null;
    final store = _partitions.store;
    final session = _partitions.session;
    final binding = session.binding;
    if (store == null ||
        store.isClosed ||
        binding == null ||
        PartitionKey(binding.server, binding.userId) != store.key ||
        normalizeBaseUrl(baseUrl) != binding.server) {
      return null;
    }
    return _Ticket(
      _partitions,
      store,
      readKey(path, query),
      session.generation,
      store.epoch,
      binding.server,
    );
  }
}

class _Ticket implements ReadTicket {
  _Ticket(
    this._partitions,
    this._store,
    this._key,
    this._generation,
    this._epoch,
    this._server,
  );
  final PartitionController _partitions;
  final LocalStore _store;
  final String _key, _server;
  final int _generation, _epoch;

  bool get _current =>
      !_store.isClosed && _partitions.session.generation == _generation;

  bool get _isFrame => ReadKey.parse(_key).kind == ReadKind.frame;

  /// Runs a step that reads or writes the partition. Whatever it makes of the
  /// answer, nothing is handed back once the session has moved on: the answer
  /// belongs to the account that asked, not to whoever is signed in now. A
  /// failure after the partition closed is the same thing.
  Future<T> _whileCurrent<T>(Future<T> Function() step) async {
    if (!_current) throw StaleSessionRead();
    final T out;
    try {
      out = await step();
    } on Object {
      if (!_current) throw StaleSessionRead();
      rethrow;
    }
    if (!_current) throw StaleSessionRead();
    return out;
  }

  @override
  ReadTicket again(String baseUrl) {
    if (!_current || normalizeBaseUrl(baseUrl) != _server) {
      throw StaleSessionRead();
    }
    return _Ticket(
      _partitions,
      _store,
      _key,
      _generation,
      _store.epoch,
      _server,
    );
  }

  /// What the device holds for this read, with the pending changes laid over
  /// it, from one moment (see `LocalStore.view`). [missing] is thrown when
  /// nothing is kept; a kept "no such frame" is the server's 404, unless a
  /// change made on this phone created the frame.
  Future<ReadResult> _kept(ApiException Function() missing) async {
    final view = await _store.view(_key);
    final snapshot = view.snapshot;
    if (snapshot == null || snapshot.status == 404) {
      // A frame noted on this phone exists here even if never fetched.
      final local = _isFrame ? project(_key, null, view.ops) : null;
      if (local != null) return ReadResult(local);
      throw snapshot == null
          ? missing()
          : ApiException(404, 'not_found', 'Not found');
    }
    return ReadResult(project(_key, snapshot.json, view.ops));
  }

  /// The server answered; [stored] says whether the answer was kept. A kept
  /// answer is served as read back from the device, after any change that
  /// reached the server meanwhile. An answer that was not kept (a change
  /// overtook it and the reads were used up) is proven stale and is never
  /// served: the device's latest state is, or a failure to retry if it has
  /// none.
  Future<ReadResult> _answered(bool stored, bool last) async {
    if (!stored && !last && _store.epoch != _epoch) {
      return const ReadResult.retry();
    }
    // The server answered: anything waiting to retry can go now.
    _partitions.engine?.wakeIfOffline();
    return _kept(StaleRead.new);
  }

  @override
  Future<ReadResult> fresh(dynamic json, {bool last = false}) => _whileCurrent(
    () async => _answered(
      await _store.writeSnapshot(_key, 200, json, epoch: _epoch),
      last,
    ),
  );

  @override
  Future<ReadResult> notFound(ApiException error, {bool last = false}) =>
      _whileCurrent(() async {
        if (!_isFrame) throw error;
        return _answered(
          await _store.writeSnapshot(_key, 404, null, epoch: _epoch),
          last,
        );
      });

  @override
  Future<ReadResult> offline(ApiException error) =>
      _whileCurrent(() => _kept(OfflineNoSnapshot.new));
}
