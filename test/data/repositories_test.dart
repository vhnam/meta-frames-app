import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:meta_frames/data/repositories/camera_repository_remote.dart';
import 'package:meta_frames/data/repositories/film_stock_repository_remote.dart';
import 'package:meta_frames/data/repositories/lab_repository_remote.dart';
import 'package:meta_frames/data/repositories/lens_repository_remote.dart';
import 'package:meta_frames/data/repositories/processing_repository_remote.dart';
import 'package:meta_frames/data/repositories/roll_repository_remote.dart';
import 'package:meta_frames/data/repositories/scan_repository_remote.dart';
import 'package:meta_frames/data/repositories/settings_repository.dart';
import 'package:meta_frames/data/repositories/settings_repository_prefs.dart';
import 'package:meta_frames/data/services/api_client.dart';
import 'package:meta_frames/domain/models/film_requests.dart';
import 'package:meta_frames/domain/models/gear_requests.dart';
import 'package:meta_frames/domain/models/lab_requests.dart';
import 'package:meta_frames/domain/models/models.dart';
import 'package:meta_frames/domain/models/roll_requests.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _camera = {
  'id': 'c1',
  'brand': 'Nikon',
  'model': 'FM2',
  'hasFixedLens': false,
  'isActive': true,
};
const _lens = {
  'id': 'l1',
  'focalLength': 50,
  'maxAperture': 1.8,
  'isBuiltIn': false,
  'isActive': true,
};
const _stock = {
  'id': 's1',
  'brand': 'Kodak',
  'name': 'Gold',
  'type': 'color',
  'boxIso': 200,
  'process': 'C-41',
  'packaging': 'factory',
};
const _roll = {
  'id': 'r1',
  'filmStockId': 's1',
  'stockBrand': 'Kodak',
  'stockName': 'Gold',
  'format': 135,
  'exposures': 36,
  'status': 'in_stock',
};
const _rollDetail = {
  'roll': _roll,
  'stock': _stock,
  'totals': {
    'rollPrice': 0,
    'processingPrice': 0,
    'total': 0,
    'incomplete': false,
  },
};
const _processing = {
  'id': 'p1',
  'rollId': 'r1',
  'type': 'develop_scan',
  'process': 'C-41',
  'sentAt': '2026-01-01',
  'isOpen': true,
};

/// Records the last request and answers with [reply].
class Recorder {
  Recorder(this.reply);
  Object? reply;
  late http.Request last;
  final requests = <http.Request>[];

  ApiClient get client => ApiClient(
    () => 'http://srv',
    MockClient((r) async {
      last = r;
      requests.add(r);
      return http.Response(
        jsonEncode(reply),
        200,
        headers: {'content-type': 'application/json'},
      );
    }),
  );

  Map<String, dynamic> get body => jsonDecode(last.body);
  String get call => '${last.method} ${last.url.path}';
}

void main() {
  group('CameraRepositoryRemote', () {
    test('reads', () async {
      final rec = Recorder([_camera]);
      final repo = CameraRepositoryRemote(rec.client);

      expect((await repo.cameras()).single.id, 'c1');
      expect(rec.call, 'GET /cameras');

      rec.reply = _camera;
      await repo.camera('c1');
      expect(rec.call, 'GET /cameras/c1');

      rec.reply = [_lens];
      expect((await repo.lenses('c1')).single.id, 'l1');
      expect(rec.call, 'GET /cameras/c1/lenses');
    });

    test('writes', () async {
      final rec = Recorder(_camera);
      final repo = CameraRepositoryRemote(rec.client);
      const edit = CameraEdit(
        brand: 'Nikon',
        model: 'FM2',
        hasFixedLens: false,
        mount: 'F',
      );

      await repo.create(edit);
      expect(rec.call, 'POST /cameras');
      expect(rec.body, edit.toJson());

      await repo.update('c1', edit);
      expect(rec.call, 'PUT /cameras/c1');

      await repo.setActive('c1', false);
      expect(rec.call, 'PUT /cameras/c1/active');
      expect(rec.body, {'isActive': false});

      rec.reply = null;
      await repo.setLenses('c1', ['l1', 'l2']);
      expect(rec.call, 'PUT /cameras/c1/lenses');
      expect(rec.body, {
        'lensIds': ['l1', 'l2'],
      });

      await repo.delete('c1');
      expect(rec.call, 'DELETE /cameras/c1');
    });
  });

  group('LensRepositoryRemote', () {
    test('lists with an optional preferred mount', () async {
      final rec = Recorder([_lens]);
      final repo = LensRepositoryRemote(rec.client);

      await repo.lenses();
      expect(rec.last.url.hasQuery, isFalse);

      await repo.lenses(preferMount: 'F');
      expect(rec.last.url.queryParameters, {'preferMount': 'F'});
    });

    test('writes', () async {
      final rec = Recorder(_lens);
      final repo = LensRepositoryRemote(rec.client);
      const edit = LensEdit(focalLength: 50, maxAperture: 1.8);

      await repo.create(edit);
      expect(rec.call, 'POST /lenses');
      expect(rec.body, {'focalLength': 50, 'maxAperture': 1.8});

      await repo.update('l1', edit);
      expect(rec.call, 'PUT /lenses/l1');

      await repo.setActive('l1', true);
      expect(rec.call, 'PUT /lenses/l1/active');
      expect(rec.body, {'isActive': true});
    });
  });

  group('FilmStockRepositoryRemote', () {
    test('searches and filters inventory', () async {
      final rec = Recorder([_stock]);
      final repo = FilmStockRepositoryRemote(rec.client);

      await repo.stocks(q: 'gold');
      expect(rec.last.url.queryParameters, {'q': 'gold'});

      rec.reply = [];
      await repo.inventory(type: 'color', iso: 400);
      expect(rec.call, 'GET /inventory');
      expect(rec.last.url.queryParameters, {'type': 'color', 'iso': '400'});
    });

    test('create omits null description and base stock', () async {
      final rec = Recorder({'stock': _stock});
      final repo = FilmStockRepositoryRemote(rec.client);
      const edit = FilmStockEdit(
        brand: 'Kodak',
        name: 'Gold',
        type: StockType.color,
        boxIso: 200,
        process: Process.c41,
        packaging: Packaging.factory,
      );

      await repo.create(edit);
      expect(rec.call, 'POST /film-stocks');
      expect(rec.body['process'], 'C-41');
      expect(rec.body.containsKey('stockOrigin'), isFalse);
      expect(rec.body.containsKey('description'), isFalse);
      expect(rec.body.containsKey('baseStockId'), isFalse);
      expect(rec.body.containsKey('packOrigin'), isFalse);

      await repo.update('s1', edit);
      expect(rec.call, 'PUT /film-stocks/s1');
      expect(rec.body.containsKey('stockOrigin'), isFalse);
      expect(rec.body.containsKey('description'), isFalse);
      expect(rec.body.containsKey('baseStockId'), isFalse);
      expect(rec.body.containsKey('packOrigin'), isFalse);

      const repack = FilmStockEdit(
        brand: 'Kodak',
        name: 'Gold',
        type: StockType.color,
        boxIso: 200,
        process: Process.c41,
        packaging: Packaging.repack,
        packOrigin: 'Japan',
      );
      await repo.create(repack);
      expect(rec.body['packOrigin'], 'Japan');
    });
  });

  group('LabRepositoryRemote', () {
    test('writes', () async {
      final rec = Recorder({'id': 'b1', 'name': 'Lab'});
      final repo = LabRepositoryRemote(rec.client);

      await repo.create(const LabEdit(name: 'Lab'));
      expect(rec.call, 'POST /labs');
      expect(rec.body, {'name': 'Lab'});

      await repo.update('b1', const LabEdit(name: 'Lab', address: 'Hanoi'));
      expect(rec.call, 'PUT /labs/b1');
      expect(rec.body['address'], 'Hanoi');

      rec.reply = null;
      await repo.delete('b1');
      expect(rec.call, 'DELETE /labs/b1');
    });
  });

  group('RollRepositoryRemote', () {
    test('filters by every field and formats dates', () async {
      final rec = Recorder([_roll]);
      final repo = RollRepositoryRemote(rec.client);

      await repo.rolls(
        status: 'in_stock',
        filmStockId: 's1',
        cameraId: 'c1',
        lensId: 'l1',
        format: 120,
        startedFrom: DateTime(2026, 1, 5),
        startedTo: DateTime(2026, 12, 31),
      );

      expect(rec.last.url.queryParameters, {
        'status': 'in_stock',
        'filmStockId': 's1',
        'cameraId': 'c1',
        'lensId': 'l1',
        'format': '120',
        'startedFrom': '2026-01-05',
        'startedTo': '2026-12-31',
      });
    });

    test('bulk add sends an idempotency key, new on every call', () async {
      final rec = Recorder([_roll]);
      final repo = RollRepositoryRemote(rec.client);
      const rolls = NewRolls(
        filmStockId: 's1',
        format: 135,
        exposures: 36,
        quantity: 2,
      );

      await repo.addRolls(rolls);
      final first = rec.last.headers['Idempotency-Key'];
      await repo.addRolls(rolls);
      final second = rec.last.headers['Idempotency-Key'];

      expect(rec.call, 'POST /rolls/bulk');
      expect(rec.body['quantity'], 2);
      expect(first, isNotEmpty);
      expect(second, isNot(first));
    });

    test('roll writes', () async {
      final rec = Recorder(_rollDetail);
      final repo = RollRepositoryRemote(rec.client);

      await repo.update(
        'r1',
        const RollEdit(filmStockId: 's1', format: 135, exposures: 36),
      );
      expect(rec.call, 'PUT /rolls/r1');

      await repo.load(
        'r1',
        LoadRollRequest(
          cameraId: 'c1',
          startedAt: DateTime(2026, 3, 1),
          lensIds: const ['l1'],
        ),
      );
      expect(rec.call, 'PUT /rolls/r1/load');
      expect(rec.body, {
        'cameraId': 'c1',
        'startedAt': '2026-03-01',
        'lensIds': ['l1'],
      });

      await repo.finish('r1', DateTime(2026, 3, 9));
      expect(rec.call, 'PUT /rolls/r1/finish');
      expect(rec.body, {'date': '2026-03-09'});

      rec.reply = null;
      await repo.setLenses('r1', ['l1']);
      expect(rec.call, 'PUT /rolls/r1/lenses');
      await repo.delete('r1');
      expect(rec.call, 'DELETE /rolls/r1');
    });

    test('expiry', () async {
      final rec = Recorder({'expiring': [], 'noExpiry': []});
      final repo = RollRepositoryRemote(rec.client);
      await repo.expiry();
      expect(rec.call, 'GET /expiry');
    });
  });

  group('ProcessingRepositoryRemote', () {
    test('sending a roll puts a new job id in the path', () async {
      final rec = Recorder(_processing);
      final repo = ProcessingRepositoryRemote(rec.client);
      final job = NewProcessing(
        labId: null,
        type: ProcessingType.developScan,
        process: Process.c41,
        sentAt: DateTime(2026, 2, 3),
        price: 150000,
      );

      await repo.send('r1', job);
      final first = rec.last.url.path;
      await repo.send('r1', job);

      expect(first, matches(RegExp(r'^/rolls/r1/processing/[0-9a-f-]{36}$')));
      expect(rec.last.url.path, isNot(first));
      expect(rec.last.method, 'PUT');
      expect(rec.body, {
        'type': 'develop_scan',
        'process': 'C-41',
        'sentAt': '2026-02-03',
        'price': 150000,
      });
    });

    test('state changes', () async {
      final rec = Recorder(_processing);
      final repo = ProcessingRepositoryRemote(rec.client);

      await repo.scansReceived('p1', DateTime(2026, 2, 10));
      expect(rec.call, 'PUT /processing/p1/scans-received');
      expect(rec.body, {'date': '2026-02-10'});

      await repo.negativesReturned('p1', DateTime(2026, 2, 12));
      expect(rec.call, 'PUT /processing/p1/negatives-returned');

      await repo.processing('p1');
      expect(rec.call, 'GET /processing/p1');
    });

    test('lists', () async {
      final rec = Recorder([_processing]);
      final repo = ProcessingRepositoryRemote(rec.client);

      expect((await repo.forRoll('r1')).single.id, 'p1');
      expect(rec.call, 'GET /rolls/r1/processing');

      rec.reply = [];
      await repo.negativesAtLab();
      expect(rec.call, 'GET /negatives-at-lab');
    });
  });

  group('ScanRepositoryRemote', () {
    test('frame notes', () async {
      final rec = Recorder({
        'id': 'f1',
        'number': 3,
        'notes': 'hi',
        'scans': [],
      });
      final repo = ScanRepositoryRemote(rec.client);

      expect((await repo.frame('r1', 3)).notes, 'hi');
      expect(rec.call, 'GET /rolls/r1/frames/3');

      await repo.saveFrameNotes('r1', 3, null);
      expect(rec.call, 'PUT /rolls/r1/frames/3');
      expect(rec.body, {'notes': null});
    });

    test('scan listing and import preview', () async {
      final rec = Recorder([]);
      final repo = ScanRepositoryRemote(rec.client);

      await repo.scans('p1', scanner: Scanner.frontier);
      expect(rec.call, 'GET /processing/p1/scans');
      expect(rec.last.url.queryParameters, {'scanner': 'frontier'});

      await repo.previewImport('p1', ['a.jpg'], startFrame: 3);
      expect(rec.call, 'POST /processing/p1/scans/preview');
      expect(rec.body, {
        'fileNames': ['a.jpg'],
        'startFrame': 3,
      });
    });

    test('comparison', () async {
      final rec = Recorder({'frameNumber': 4});
      final repo = ScanRepositoryRemote(rec.client);

      expect((await repo.compare('p1', 4)).frameNumber, 4);
      expect(rec.call, 'GET /processing/p1/frames/4/compare');
    });

    test('builds scan URLs from the configured server', () {
      final repo = ScanRepositoryRemote(Recorder(null).client);
      final scan = Scan.fromJson({
        'id': 's1',
        'processingId': 'p1',
        'frameId': 'f1',
        'frameNumber': 1,
        'scanner': 'noritsu',
        'fileName': 'a.jpg',
        'sizeBytes': 1,
        'fileUrl': '/scans/s1/file',
      });

      expect(repo.fileUrl(scan), 'http://srv/scans/s1/file');
      expect(repo.scanUrl('s9'), 'http://srv/scans/s9/file');
    });
  });

  group('SettingsRepositoryPrefs', () {
    Future<SettingsRepositoryPrefs> repo([
      Map<String, Object> initial = const {},
    ]) async {
      SharedPreferences.setMockInitialValues(initial);
      return SettingsRepositoryPrefs(await SharedPreferences.getInstance());
    }

    test('defaults to the emulator host', () async {
      expect((await repo()).baseUrl, defaultBaseUrl);
    });

    test('trims whitespace and trailing slashes when saving', () async {
      final r = await repo();
      await r.setBaseUrl('  http://192.168.1.5:8080//  ');
      expect(r.baseUrl, 'http://192.168.1.5:8080');
    });

    test('reads a saved value', () async {
      expect((await repo({'base_url': 'http://nas'})).baseUrl, 'http://nas');
    });
  });
}
