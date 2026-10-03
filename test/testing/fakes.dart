import 'dart:io';

import 'package:meta_frames/data/repositories/camera_repository.dart';
import 'package:meta_frames/data/repositories/lens_repository.dart';
import 'package:meta_frames/data/repositories/roll_repository.dart';
import 'package:meta_frames/data/repositories/scan_repository.dart';
import 'package:meta_frames/domain/models/models.dart';
import 'package:meta_frames/domain/models/roll_requests.dart';

Camera camera(
  String id, {
  bool fixedLens = false,
  bool active = true,
  bool loaded = false,
}) => Camera.fromJson({
  'id': id,
  'brand': 'Nikon',
  'model': id,
  'mount': fixedLens ? null : 'F',
  'hasFixedLens': fixedLens,
  'isActive': active,
  if (loaded)
    'loadedRoll': {
      'rollId': 'r0',
      'stockId': 's1',
      'stockBrand': 'Kodak',
      'stockName': 'Gold',
      'startedAt': '2026-01-01',
      'daysLoaded': 1,
    },
});

Lens lens(String id, {bool active = true}) => Lens.fromJson({
  'id': id,
  'brand': 'Nikon',
  'model': id,
  'focalLength': 50,
  'maxAperture': 1.8,
  'isBuiltIn': false,
  'isActive': active,
});

RollSummary roll(
  String id, {
  String status = 'in_stock',
  String stockId = 's1',
  Map<String, dynamic>? expiry,
}) => RollSummary.fromJson({
  'id': id,
  'filmStockId': stockId,
  'stockBrand': 'Kodak',
  'stockName': 'Gold',
  'format': 135,
  'exposures': 36,
  'status': status,
  'expiry': expiry,
});

RollDetail rollDetail(String id) => RollDetail.fromJson({
  'roll': {
    'id': id,
    'filmStockId': 's1',
    'stockBrand': 'Kodak',
    'stockName': 'Gold',
    'format': 135,
    'exposures': 36,
    'status': 'in_stock',
  },
  'stock': {
    'id': 's1',
    'brand': 'Kodak',
    'name': 'Gold',
    'type': 'color',
    'boxIso': 200,
    'process': 'C-41',
    'packaging': 'factory',
  },
  'totals': {
    'rollPrice': 0,
    'processingPrice': 0,
    'total': 0,
    'incomplete': false,
  },
});

class FakeRollRepository implements RollRepository {
  FakeRollRepository([this.all = const []]);
  List<RollSummary> all;

  /// Every write, in order, e.g. `finish:r1` or `load:r1`.
  final calls = <String>[];
  LoadRollRequest? lastLoad;
  int listCalls = 0;

  @override
  Future<List<RollSummary>> rolls({
    String? status,
    String? filmStockId,
    String? cameraId,
    String? lensId,
    int? format,
    DateTime? startedFrom,
    DateTime? startedTo,
  }) async {
    listCalls++;
    return [
      for (final r in all)
        if ((status == null || r.status.wire == status) &&
            (filmStockId == null || r.filmStockId == filmStockId))
          r,
    ];
  }

  @override
  Future<RollDetail> finish(String id, DateTime date) async {
    calls.add('finish:$id');
    return _unusedDetail();
  }

  @override
  Future<RollDetail> load(String id, LoadRollRequest request) async {
    calls.add('load:$id');
    lastLoad = request;
    return _unusedDetail();
  }

  @override
  Future<void> setLenses(String id, List<String> lensIds) async =>
      calls.add('setLenses:$id');

  @override
  Future<void> delete(String id) async => calls.add('delete:$id');

  @override
  Future<RollDetail> update(String id, RollEdit edit) async {
    calls.add('update:$id');
    return _unusedDetail();
  }

  @override
  Future<List<RollSummary>> addRolls(NewRolls rolls) async {
    calls.add('add');
    return const [];
  }

  @override
  Future<ExpiryView> expiry() async =>
      ExpiryView.fromJson({'expiring': [], 'noExpiry': []});

  @override
  Future<RollDetail> roll(String id) async => _unusedDetail();

  @override
  Future<List<SearchResult>> searchByFocalLength(int mm) async => const [];

  RollDetail _unusedDetail() => rollDetail('r');
}

class FakeCameraRepository implements CameraRepository {
  FakeCameraRepository({this.cameraList = const [], this.linked = const {}});
  List<Camera> cameraList;

  /// Lenses linked per camera id.
  Map<String, List<Lens>> linked;
  int listCalls = 0;

  @override
  Future<List<Camera>> cameras() async {
    listCalls++;
    return cameraList;
  }

  @override
  Future<List<Lens>> lenses(String id) async => linked[id] ?? const [];

  @override
  Future<void> setLenses(String id, List<String> lensIds) async {}

  @override
  Future<Camera> camera(String id) async =>
      cameraList.firstWhere((c) => c.id == id);
  @override
  Future<Camera> create(Map<String, dynamic> body) =>
      throw UnimplementedError();
  @override
  Future<Camera> update(String id, Map<String, dynamic> body) =>
      throw UnimplementedError();
  @override
  Future<void> delete(String id) => throw UnimplementedError();
  @override
  Future<Camera> setActive(String id, bool active) =>
      throw UnimplementedError();
}

class FakeLensRepository implements LensRepository {
  FakeLensRepository([this.all = const []]);
  List<Lens> all;
  int listCalls = 0;

  @override
  Future<List<Lens>> lenses({String? preferMount}) async {
    listCalls++;
    return all;
  }

  @override
  Future<Lens> lens(String id) async => all.firstWhere((l) => l.id == id);
  @override
  Future<Lens> create(Map<String, dynamic> body) => throw UnimplementedError();
  @override
  Future<Lens> update(String id, Map<String, dynamic> body) =>
      throw UnimplementedError();
  @override
  Future<void> delete(String id) => throw UnimplementedError();
  @override
  Future<Lens> setActive(String id, bool active) => throw UnimplementedError();
}

class FakeScanRepository implements ScanRepository {
  /// File names the fake server cannot number, with the reason.
  final unnumberable = <String, String>{};

  /// File names whose upload throws.
  final uploadFails = <String>{};
  final uploaded = <String>[];

  @override
  Future<List<ImportPreviewItem>> previewImport(
    String processingId,
    List<String> names, {
    int? startFrame,
    int? offset,
  }) async => [
    for (var i = 0; i < names.length; i++)
      ImportPreviewItem.fromJson({
        'fileName': names[i],
        'frameNumber': unnumberable.containsKey(names[i])
            ? null
            : (startFrame ?? 1) + i + (offset ?? 0),
        'error': unnumberable[names[i]],
      }),
  ];

  @override
  Future<ImportResult> importScan(
    String processingId, {
    required Scanner scanner,
    required String path,
    required String fileName,
    required int frameNumber,
    required bool replace,
  }) async {
    if (uploadFails.contains(fileName)) throw 'disk full';
    uploaded.add('$fileName@$frameNumber');
    return ImportResult.fromJson({
      'imported': [
        {
          'id': 's$frameNumber',
          'processingId': processingId,
          'frameId': 'f',
          'frameNumber': frameNumber,
          'scanner': scanner.name,
          'fileName': fileName,
          'sizeBytes': 1,
          'fileUrl': '/x',
        },
      ],
      'skipped': [],
      'failed': [],
    });
  }

  @override
  Future<Frame> frame(String rollId, int n) => throw UnimplementedError();
  @override
  Future<Frame> saveFrameNotes(String rollId, int n, String? notes) =>
      throw UnimplementedError();
  @override
  Future<List<Scan>> scans(String processingId, {Scanner? scanner}) async =>
      const [];
  @override
  Future<FrameComparison> compare(String processingId, int n) =>
      throw UnimplementedError();
  @override
  String fileUrl(Scan s) => 'http://x${s.fileUrl}';
  @override
  String scanUrl(String scanId) => 'http://x/scans/$scanId/file';
  @override
  Future<void> download(Scan s, File dest) => throw UnimplementedError();
}
