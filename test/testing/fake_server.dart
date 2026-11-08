import 'package:meta_frames/data/repositories/auth_repository.dart';
import 'package:meta_frames/data/repositories/roll_repository.dart';
import 'package:meta_frames/data/services/api_client.dart';
import 'package:meta_frames/domain/models/models.dart';
import 'package:meta_frames/domain/models/roll_requests.dart';
import 'package:meta_frames/domain/utils.dart';

/// How the next write fails, to stand in for the network.
enum Fault {
  /// Never reaches the server.
  offline,

  /// The server commits it, and the answer is lost.
  lostAnswer,

  /// The server answers 500 without committing.
  serverError,

  /// The session has ended.
  unauthorized,
}

/// A roll as the fake server keeps it.
class ServerRoll {
  ServerRoll(this.id, {this.status = 'in_stock', this.boxIso = '400'});
  final String id;
  String status;
  String boxIso;
  String? cameraId, cameraName, description;
  DateTime? startedAt, finishedAt;
  int? shotIso;
  int version = 0;
  Set<String> lenses = {};

  Map<String, dynamic> summary() => {
    'id': id,
    'filmStockId': 's1',
    'stockBrand': 'Kodak',
    'stockName': 'Gold',
    'format': 135,
    'exposures': 36,
    'status': status,
    'cameraId': cameraId,
    'cameraName': cameraName,
    'shotIso': shotIso,
    'description': description,
    'startedAt': startedAt == null ? null : ymd(startedAt!),
    'finishedAt': finishedAt == null ? null : ymd(finishedAt!),
    'version': version,
  };
}

/// The server's rules for the endpoints the sync engine uses, from the
/// current server code: compare-and-set notes, load and finish with their
/// replay and conflict rules. Counts the writes it commits.
class FakeServer implements RollRepository, AuthRepository {
  FakeServer({this.userId = 'u1'});

  String userId;
  final stored = <String, ServerRoll>{};
  final frames = <(String, int), String?>{};
  final faults = <Fault>[];

  /// Writes the server committed, e.g. `frame:r1:7`, `load:r1`.
  final writes = <String>[];

  /// Requests made, in order, e.g. `GET roll:r1`, `PUT frame:r1:7`.
  final requests = <String>[];

  /// Runs while a write is in flight, before it commits: lets a test change
  /// the session mid-request.
  void Function()? duringWrite;

  ServerRoll addRoll(String id, {String status = 'in_stock'}) =>
      stored[id] = ServerRoll(id, status: status);

  /// Puts [roll] in [camera] as the dashboard would.
  void loadOnDashboard(String roll, String camera, DateTime date) {
    final r = stored.putIfAbsent(roll, () => ServerRoll(roll))
      ..status = 'in_camera'
      ..cameraId = camera
      ..cameraName = camera
      ..startedAt = date
      ..version += 1;
    writes.add('dashboard-load:${r.id}');
  }

  Never _fail(int status, String code) =>
      throw ApiException(status, code, code);

  /// Applies the next fault around [commit].
  Future<T> _write<T>(String name, T Function() commit) async {
    requests.add('PUT $name');
    final fault = faults.isEmpty ? null : faults.removeAt(0);
    duringWrite?.call();
    switch (fault) {
      case Fault.offline:
        throw ApiException(0, 'network', 'offline');
      case Fault.serverError:
        _fail(500, 'error');
      case Fault.unauthorized:
        _fail(401, 'unauthorized');
      case Fault.lostAnswer:
        commit();
        throw ApiException(0, 'network', 'timeout');
      case null:
        return commit();
    }
  }

  void _read(String name) {
    requests.add('GET $name');
    if (faults.isNotEmpty && faults.first == Fault.offline) {
      faults.removeAt(0);
      throw ApiException(0, 'network', 'offline');
    }
  }

  ServerRoll _roll(String id) => stored[id] ?? _fail(404, 'not_found');

  Map<String, dynamic> _detailJson(ServerRoll r) => {
    'roll': r.summary(),
    'stock': {
      'id': 's1',
      'brand': 'Kodak',
      'name': 'Gold',
      'type': 'color',
      'boxIso': r.boxIso,
      'process': 'C-41',
      'packaging': 'factory',
    },
    'lenses': [
      for (final l in r.lenses)
        {
          'id': l,
          'focalLength': 50,
          'maxAperture': 1.8,
          'isBuiltIn': false,
          'isActive': true,
        },
    ],
    'frames': [
      for (final e in frames.entries)
        if (e.key.$1 == r.id) _frameJson(r.id, e.key.$2),
    ],
    'totals': {
      'rollPrice': 0,
      'processingPrice': 0,
      'total': 0,
      'incomplete': false,
    },
  };

  Map<String, dynamic> _frameJson(String roll, int n) => {
    'id': 'f-$roll-$n',
    'number': n,
    'notes': frames[(roll, n)],
    'scans': <Object>[],
  };

  static String _t(String? s) => (s ?? '').trim();

  /// `/auth/me` answers 401: the session has ended.
  bool sessionEnded = false;

  @override
  Future<User> me() async {
    _read('me');
    if (sessionEnded) _fail(401, 'unauthorized');
    return User.fromJson({'id': userId, 'email': '$userId@example.com'});
  }

  @override
  Future<RollDetail> roll(String id) async {
    _read('roll:$id');
    return RollDetail.fromJson(_detailJson(_roll(id)));
  }

  @override
  Future<Frame> frame(String rollId, int n) async {
    _read('frame:$rollId:$n');
    _roll(rollId);
    if (!frames.containsKey((rollId, n))) _fail(404, 'not_found');
    return Frame.fromJson(_frameJson(rollId, n));
  }

  @override
  Future<Frame> saveFrameNotes(
    String rollId,
    int n,
    String? notes, {
    String? baseNotes,
  }) => _write('frame:$rollId:$n', () {
    _roll(rollId);
    final current = frames[(rollId, n)];
    if (baseNotes != null && _t(current) != _t(notes)) {
      if (_t(current) != _t(baseNotes)) _fail(409, 'frame_notes_conflict');
    }
    if (baseNotes == null || _t(current) != _t(notes)) {
      frames[(rollId, n)] = _t(notes).isEmpty ? null : _t(notes);
      writes.add('frame:$rollId:$n');
    }
    return Frame.fromJson(_frameJson(rollId, n));
  });

  @override
  Future<RollDetail> saveRollNotes(
    String id,
    String description, {
    String? baseDescription,
  }) => _write('notes:$id', () {
    final r = _roll(id);
    if (baseDescription != null && _t(r.description) != _t(description)) {
      if (_t(r.description) != _t(baseDescription)) {
        _fail(409, 'roll_notes_conflict');
      }
    }
    if (_t(r.description) != _t(description)) {
      r
        ..description = _t(description).isEmpty ? null : _t(description)
        ..version += 1;
      writes.add('notes:$id');
    }
    return RollDetail.fromJson(_detailJson(r));
  });

  @override
  Future<RollDetail> load(String id, LoadRollRequest request) =>
      _write('load:$id', () {
        final r = _roll(id);
        final iso = request.shotIso != null && '${request.shotIso}' == r.boxIso
            ? null
            : request.shotIso;
        if (r.status == 'in_camera' && r.cameraId == request.cameraId) {
          final same =
              ymd(r.startedAt!) == ymd(request.startedAt) &&
              r.shotIso == iso &&
              r.lenses.length == request.lensIds.toSet().length &&
              r.lenses.containsAll(request.lensIds);
          if (!same) _fail(409, 'roll_loaded_differently');
          return RollDetail.fromJson(_detailJson(r));
        }
        if (r.status != 'in_stock') _fail(409, 'roll_not_in_stock');
        if (stored.values.any(
          (o) => o.status == 'in_camera' && o.cameraId == request.cameraId,
        )) {
          _fail(409, 'camera_loaded');
        }
        r
          ..status = 'in_camera'
          ..cameraId = request.cameraId
          ..cameraName = request.cameraId
          ..startedAt = request.startedAt
          ..shotIso = iso
          ..lenses = request.lensIds.toSet()
          ..version += 1;
        writes.add('load:$id');
        return RollDetail.fromJson(_detailJson(r));
      });

  @override
  Future<RollDetail> finish(String id, DateTime date) =>
      _write('finish:$id', () {
        final r = _roll(id);
        if (r.status == 'done_shooting' && ymd(r.finishedAt!) == ymd(date)) {
          return RollDetail.fromJson(_detailJson(r));
        }
        if (r.status != 'in_camera') _fail(409, 'roll_not_in_camera');
        r
          ..status = 'done_shooting'
          ..finishedAt = date
          ..version += 1;
        writes.add('finish:$id');
        return RollDetail.fromJson(_detailJson(r));
      });

  @override
  Future<RollDetail> update(String id, RollEdit edit, {int? version}) =>
      _write('roll:$id', () {
        final r = _roll(id);
        if (version != null && version != r.version) _fail(412, 'roll_changed');
        r
          ..description = edit.description
          ..version += 1;
        writes.add('update:$id');
        return RollDetail.fromJson(_detailJson(r));
      });

  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw UnimplementedError('${invocation.memberName}');
}
