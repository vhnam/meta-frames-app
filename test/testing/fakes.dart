import 'dart:io';

import 'package:meta_frames/data/repositories/camera_repository.dart';
import 'package:meta_frames/data/repositories/film_stock_repository.dart';
import 'package:meta_frames/data/repositories/lab_repository.dart';
import 'package:meta_frames/data/repositories/scanner_repository.dart';
import 'package:meta_frames/data/repositories/lens_repository.dart';
import 'package:meta_frames/data/repositories/processing_repository.dart';
import 'package:meta_frames/data/repositories/roll_repository.dart';
import 'package:meta_frames/data/repositories/scan_repository.dart';
import 'package:meta_frames/data/services/api_client.dart';
import 'package:meta_frames/domain/models/film_requests.dart';
import 'package:meta_frames/domain/models/gear_requests.dart';
import 'package:meta_frames/domain/models/lab_requests.dart';
import 'package:meta_frames/domain/models/models.dart';
import 'package:meta_frames/domain/utils.dart';
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
  int format = 135,
  bool negativesAtLab = false,
  String? startedAt,
  bool? developed,
  bool? scanned,
  List<String>? openJobTypes,
  bool? openAtLab,
}) => RollSummary.fromJson({
  'id': id,
  'filmStockId': stockId,
  'stockBrand': 'Kodak',
  'stockName': 'Gold',
  'format': format,
  'exposures': 36,
  'status': status,
  'expiry': expiry,
  'negativesAtLab': negativesAtLab,
  'startedAt': ?startedAt,
  'developed': ?developed,
  'scanned': ?scanned,
  'openJobTypes': ?openJobTypes,
  'openAtLab': ?openAtLab,
});

RollDetail rollDetail(
  String id, {
  List<Map<String, dynamic>> frames = const [],
}) => RollDetail.fromJson({
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
    'boxIso': '200',
    'process': 'C-41',
    'packaging': 'factory',
  },
  'totals': {
    'rollPrice': 0,
    'processingPrice': 0,
    'total': 0,
    'incomplete': false,
  },
  'frames': frames,
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

  /// The `If-Match` version sent with each [update].
  final versions = <int?>[];

  @override
  Future<RollDetail> update(String id, RollEdit edit, {int? version}) async {
    calls.add('update:$id');
    versions.add(version);
    return _unusedDetail();
  }

  /// The idempotency key sent with each [addRolls].
  final keys = <String?>[];

  @override
  Future<List<RollSummary>> addRolls(
    NewRolls rolls, {
    String? idempotencyKey,
  }) async {
    calls.add('add');
    keys.add(idempotencyKey);
    return [
      for (var i = 0; i < rolls.quantity; i++)
        RollSummary.fromJson({
          'id': 'added$i',
          'filmStockId': rolls.filmStockId,
          'stockBrand': 'Kodak',
          'stockName': 'Gold',
          'format': rolls.format,
          'exposures': rolls.exposures,
          'status': 'in_stock',
        }),
    ];
  }

  /// Served by [expiry].
  ExpiryView expiryView = ExpiryView.fromJson({'expiring': [], 'noExpiry': []});

  @override
  Future<ExpiryView> expiry() async => expiryView;

  /// The roll with the frames noted through [saveFrameNotes].
  @override
  Future<RollDetail> roll(String id) async => rollDetail(
    id,
    frames: [
      for (final k in frameNotes.keys)
        if (k.$1 == id) _frameJson(id, k.$2),
    ],
  );

  /// Frame notes by roll id and number, as the server keeps them.
  final frameNotes = <(String, int), String?>{};

  @override
  Future<Frame> frame(String rollId, int n) async {
    if (!frameNotes.containsKey((rollId, n))) {
      throw ApiException(404, 'not_found', 'frame not found');
    }
    return _frame(rollId, n);
  }

  /// The base sent with each frame notes save.
  final bases = <String?>[];

  @override
  Future<Frame> saveFrameNotes(
    String rollId,
    int n,
    String? notes, {
    String? baseNotes,
  }) async {
    calls.add('frameNotes:$rollId:$n');
    bases.add(baseNotes);
    frameNotes[(rollId, n)] = notes;
    return _frame(rollId, n);
  }

  /// Roll notes by roll id, as the server keeps them.
  final rollNotes = <String, String>{};

  @override
  Future<RollDetail> saveRollNotes(
    String id,
    String description, {
    String? baseDescription,
  }) async {
    calls.add('rollNotes:$id');
    bases.add(baseDescription);
    rollNotes[id] = description;
    return _unusedDetail();
  }

  Map<String, dynamic> _frameJson(String rollId, int n) => {
    'id': '$rollId-$n',
    'number': n,
    'notes': frameNotes[(rollId, n)],
    'scans': [],
  };

  Frame _frame(String rollId, int n) => Frame.fromJson(_frameJson(rollId, n));

  RollDetail _unusedDetail() => rollDetail('r');
}

class FakeCameraRepository implements CameraRepository {
  FakeCameraRepository({this.cameraList = const [], this.linked = const {}});
  List<Camera> cameraList;

  /// Lenses linked per camera id.
  Map<String, List<Lens>> linked;
  int listCalls = 0;

  /// Lens ids last written per camera id by [setLenses].
  final lensWrites = <String, List<String>>{};
  final calls = <String>[];

  @override
  Future<List<Camera>> cameras() async {
    listCalls++;
    return cameraList;
  }

  @override
  Future<List<Lens>> lenses(String id) async => linked[id] ?? const [];

  @override
  Future<void> setLenses(String id, List<String> lensIds) async {
    lensWrites[id] = lensIds;
  }

  @override
  Future<Camera> camera(String id) async =>
      cameraList.firstWhere((c) => c.id == id);

  @override
  Future<Camera> create(CameraEdit camera, {String? id}) async {
    calls.add('create');
    return Camera.fromJson({
      'id': id ?? 'new',
      'brand': camera.brand,
      'model': camera.model,
      'hasFixedLens': camera.hasFixedLens,
      'isActive': true,
    });
  }
}

class FakeLensRepository implements LensRepository {
  FakeLensRepository([this.all = const []]);
  List<Lens> all;
  int listCalls = 0;
  final calls = <String>[];

  @override
  Future<List<Lens>> lenses({String? preferMount}) async {
    listCalls++;
    return all;
  }

  @override
  Future<Lens> lens(String id) async => all.firstWhere((l) => l.id == id);

  @override
  Future<Lens> create(LensEdit lens, {String? id}) async => _find(id ?? 'new');

  Lens _find(String id) => all.firstWhere(
    (l) => l.id == id,
    orElse: () => Lens.fromJson({
      'id': id,
      'focalLength': 50,
      'maxAperture': 1.8,
      'isBuiltIn': false,
      'isActive': true,
    }),
  );
}

class FakeScanRepository implements ScanRepository {
  @override
  Future<List<Scan>> scans(String processingId, {Scanner? scanner}) async =>
      const [];
  @override
  String fileUrl(Scan s) => 'http://x${s.fileUrl}';
  @override
  String scanUrl(String scanId) => 'http://x/scans/$scanId/file';
  @override
  Future<void> download(Scan s, File dest) => throw UnimplementedError();
}

class FakeFilmStockRepository implements FilmStockRepository {
  FakeFilmStockRepository([this.all = const []]);
  List<FilmStock> all;

  @override
  Future<List<FilmStock>> stocks({String? q}) async => all;

  @override
  Future<FilmStockDetail> stock(String id) => throw UnimplementedError();
  @override
  Future<FilmStockDetail> create(FilmStockEdit stock, {String? id}) =>
      throw UnimplementedError();
  @override
  Future<List<InventoryItem>> inventory({
    String? type,
    String? process,
    int? iso,
  }) async => const [];
}

class FakeProcessingRepository implements ProcessingRepository {
  List<NegativesAtLabItem> atLab = [];

  /// Jobs sent, and receipts recorded such as `scans:j1:2026-01-02`.
  final sent = <NewProcessing>[];
  final receipts = <String>[];
  final deleted = <String>[];

  /// Jobs that [processing] can load.
  final jobs = <String, Processing>{};

  Processing _job(String id, ProcessingType type, Process process) =>
      Processing.fromJson({
        'id': id,
        'rollId': 'r',
        'type': type.wire,
        'process': process.wire,
        'sentAt': '2026-01-01',
        'isOpen': true,
      });

  @override
  Future<List<NegativesAtLabItem>> negativesAtLab() async => atLab;

  @override
  Future<List<Processing>> forRoll(String rollId) async => const [];
  @override
  Future<Processing> send(String rollId, NewProcessing job) async {
    sent.add(job);
    return _job(job.id ?? 'new', job.type, job.process);
  }

  @override
  Future<Processing> processing(String id) async =>
      jobs[id] ?? (throw UnimplementedError());
  @override
  Future<void> delete(String id) async => deleted.add(id);
  @override
  Future<Processing> scansReceived(String id, DateTime date) async {
    receipts.add('scans:$id:${ymd(date)}');
    return _job(id, ProcessingType.scan, Process.c41);
  }

  @override
  Future<Processing> negativesReturned(String id, DateTime date) async {
    receipts.add('negatives:$id:${ymd(date)}');
    return _job(id, ProcessingType.scan, Process.c41);
  }
}

FilmStock stock(String id, {String brand = 'Kodak', String name = 'Gold'}) =>
    FilmStock.fromJson({
      'id': id,
      'brand': brand,
      'name': name,
      'type': 'color',
      'boxIso': '200',
      'process': 'C-41',
      'packaging': 'factory',
    });

class FakeLabRepository implements LabRepository {
  FakeLabRepository([List<Lab> labs = const []]) : all = [...labs];
  List<Lab> all;

  /// The last lab written.
  LabEdit? saved;

  @override
  Future<List<Lab>> labs() async => all;

  @override
  Future<Lab> lab(String id) async => all.firstWhere((l) => l.id == id);

  @override
  Future<Lab> create(LabEdit lab, {String? id}) async {
    saved = lab;
    return Lab.fromJson({
      'id': id ?? 'new',
      'name': lab.name,
      'address': lab.address,
    });
  }
}

Lab lab(
  String id,
  String name, {
  String? address,
  List<String> scannerIds = const [],
  String? defaultScannerId,
}) => Lab.fromJson({
  'id': id,
  'name': name,
  'address': address,
  'scannerIds': scannerIds,
  'defaultScannerId': defaultScannerId,
});

class FakeScannerRepository implements ScannerRepository {
  FakeScannerRepository([this.all = const [], this.kindOptions = const []]);
  final List<ScannerDevice> all;
  final List<ScannerKindOptions> kindOptions;

  @override
  Future<List<ScannerDevice>> scanners() async => all;

  @override
  Future<List<ScannerKindOptions>> kinds() async => kindOptions;
}

ScannerDevice scanner(
  String id,
  String name, {
  String? kind,
  bool builtIn = false,
  String? notes,
  Map<String, Object?> defaultSettings = const {},
}) => ScannerDevice.fromJson({
  'id': id,
  'brand': name,
  'name': name,
  'kind': kind,
  'notes': notes,
  'defaultSettings': defaultSettings,
  'builtIn': builtIn,
});
