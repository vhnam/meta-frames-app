import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:meta_frames/domain/models/models.dart';
import 'package:meta_frames/domain/utils.dart';
import 'package:meta_frames/providers.dart';
import 'package:meta_frames/routing/router.dart';
import 'package:meta_frames/routing/routes.dart';

import '../../testing/fakes.dart';

final _kinds = [
  ScannerKindOptions.fromJson({
    'kind': 'minilab',
    'label': 'Lab minilab',
    'options': [
      {
        'key': 'format',
        'label': 'Format',
        'type': 'enum',
        'values': [
          {'value': 'jpeg', 'label': 'JPEG'},
          {'value': 'tiff', 'label': 'TIFF'},
        ],
        'default': 'jpeg',
      },
    ],
  }),
  ScannerKindOptions.fromJson({
    'kind': 'flatbed',
    'label': 'Flatbed',
    'options': [
      {
        'key': 'dpi',
        'label': 'DPI',
        'type': 'integer',
        'min': 100,
        'max': 200,
        'default': 150,
      },
    ],
  }),
  ScannerKindOptions.fromJson({'label': 'Unknown kind', 'options': []}),
];

final _noritsu = scanner(
  kNoritsuHs1800,
  'Noritsu HS-1800',
  kind: 'minilab',
  builtIn: true,
);
final _frontier = scanner(
  'front',
  'Frontier SP-3000',
  kind: 'minilab',
  builtIn: true,
);
final _epson = scanner('epson', 'Epson V850', kind: 'flatbed');

class _Rolls extends FakeRollRepository {
  _Rolls(this.status, this.jobs);
  final String status;
  final int jobs;

  @override
  Future<RollDetail> roll(String id) async => RollDetail.fromJson({
    'roll': {
      'id': id,
      'filmStockId': 's1',
      'stockBrand': 'Kodak',
      'stockName': 'Gold',
      'format': 135,
      'exposures': 36,
      'status': status,
      'finishedAt': '2026-03-20',
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
    'processing': [
      for (var i = 0; i < jobs; i++)
        {
          'id': 'p$i',
          'rollId': id,
          'type': 'develop',
          'process': 'C-41',
          'sentAt': '2026-03-21',
          'isOpen': false,
        },
    ],
    'totals': {
      'rollPrice': 0,
      'processingPrice': 0,
      'total': 0,
      'incomplete': false,
    },
  });
}

/// Opens the roll's page, or the send form when [path] is given.
Future<FakeProcessingRepository> _pump(
  WidgetTester tester, {
  String status = 'done_shooting',
  int jobs = 0,
  String? path,
  List<Lab> labs = const [],
  List<ScannerDevice>? scanners,
}) async {
  tester.view
    ..physicalSize = const Size(800, 4000)
    ..devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  final processing = FakeProcessingRepository();
  final router = buildRouter(initialLocation: Routes.rolls);
  addTearDown(router.dispose);
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        rollRepositoryProvider.overrideWithValue(_Rolls(status, jobs)),
        filmStockRepositoryProvider.overrideWithValue(
          FakeFilmStockRepository(),
        ),
        processingRepositoryProvider.overrideWithValue(processing),
        labRepositoryProvider.overrideWithValue(FakeLabRepository(labs)),
        scannerRepositoryProvider.overrideWithValue(
          FakeScannerRepository(scanners ?? [_noritsu, _frontier], _kinds),
        ),
      ],
      child: MaterialApp.router(routerConfig: router),
    ),
  );
  await tester.pumpAndSettle();
  router.push(path ?? Routes.rollSend('r'));
  await tester.pumpAndSettle();
  return processing;
}

Future<void> _tap(WidgetTester tester, String text) async {
  await tester.tap(find.text(text).last);
  await tester.pumpAndSettle();
}

Future<void> _pickLab(WidgetTester tester, String from, String name) async {
  await _tap(tester, from);
  await _tap(tester, name);
}

Future<void> _pickService(WidgetTester tester, String name) async {
  await _tap(tester, 'Develop');
  await _tap(tester, name);
}

void main() {
  group('at home, where the form starts', () {
    testWidgets('records a developed roll with its date', (tester) async {
      final p = await _pump(tester);
      expect(find.text('Send to Lab'), findsOneWidget);
      expect(find.text('Self-develop'), findsOneWidget);
      expect(find.text('Kodak Gold'), findsOneWidget);
      expect(find.textContaining('135 · 36 exp · finished'), findsOneWidget);
      expect(find.text('SCANS'), findsNothing);
      expect(find.text('DATE STARTED (OPTIONAL)'), findsOneWidget);
      expect(find.text('NEGATIVES DEVELOPED (OPTIONAL)'), findsOneWidget);
      expect(find.text('SCANS EXPECTED BACK (OPTIONAL)'), findsNothing);

      await _tap(tester, 'Record processing');

      final job = p.sent.single;
      expect(job.labId, isNull);
      expect(job.type, ProcessingType.develop);
      expect(job.process, Process.c41);
      expect(job.sentAt, isNull);
      expect(job.scanOrders, isEmpty);
      final today = ymd(DateTime.now());
      expect(p.receipts, ['negatives:${job.id}:$today']);
    });

    testWidgets('scans on your own scanner by default', (tester) async {
      final p = await _pump(tester, scanners: [_noritsu, _epson]);
      await _pickService(tester, 'Develop + scan');
      expect(find.text('Scanned'.toUpperCase()), findsNothing);
      expect(find.text('SCANNED (OPTIONAL)'), findsOneWidget);

      await _tap(tester, 'Record processing');

      final job = p.sent.single;
      expect(job.scanOrders.single.scannerId, 'epson');
      expect(job.scanOrders.single.settings, {'dpi': 150});
      expect(p.receipts, hasLength(2));
    });

    testWidgets('a scan job needs a scanner', (tester) async {
      final p = await _pump(tester);
      await _pickService(tester, 'Scan');
      await _tap(tester, 'Record processing');
      expect(find.text('Pick at least one scanner.'), findsOneWidget);
      expect(p.sent, isEmpty);
    });

    testWidgets('clearing a date skips its receipt', (tester) async {
      final p = await _pump(tester);
      await tester.tap(find.byIcon(Icons.close));
      await tester.pumpAndSettle();
      await _tap(tester, 'Record processing');
      expect(p.sent, hasLength(1));
      expect(p.receipts, isEmpty);
    });
  });

  group('at a lab', () {
    final lone = lab('l1', 'Foto Lab');
    final runs = lab(
      'l2',
      'Scan Lab',
      scannerIds: ['front', kNoritsuHs1800],
      defaultScannerId: 'front',
    );

    testWidgets('sends the roll without receipts', (tester) async {
      final p = await _pump(tester, labs: [lone]);
      await _pickLab(tester, 'Self-develop', 'Foto Lab');
      expect(find.text('DATE SENT (OPTIONAL)'), findsOneWidget);
      expect(find.text('NEGATIVES EXPECTED BACK (OPTIONAL)'), findsOneWidget);
      expect(find.text('NEGATIVES DEVELOPED (OPTIONAL)'), findsNothing);

      await tester.enterText(find.byType(TextFormField).first, 'ISO 800 push');
      await _tap(tester, 'Send to lab');

      // Create-only: no price, no order lines; notes are what was typed.
      final job = p.sent.single;
      expect(job.labId, 'l1');
      expect(job.price, isNull);
      expect(job.orderItemIds, isEmpty);
      expect(job.notes, 'ISO 800 push');
      expect(job.toJson().containsKey('orderItemIds'), isFalse);
      expect(p.receipts, isEmpty);
    });

    testWidgets('a lab naming no scanners scans on the Noritsu', (
      tester,
    ) async {
      final p = await _pump(tester, labs: [lone]);
      await _pickService(tester, 'Develop + scan');
      await _pickLab(tester, 'Self-develop', 'Foto Lab');
      await _tap(tester, 'Send to lab');
      expect(p.sent.single.scanOrders.single.scannerId, kNoritsuHs1800);
      expect(p.sent.single.scanOrders.single.settings, {'format': 'jpeg'});
    });

    testWidgets('offers the lab\'s scanners, starting on its default', (
      tester,
    ) async {
      final p = await _pump(
        tester,
        labs: [runs],
        scanners: [_noritsu, _frontier, _epson],
      );
      await _pickService(tester, 'Develop + scan');
      await _pickLab(tester, 'Self-develop', 'Scan Lab');
      expect(find.text('Epson V850'), findsNothing);
      await _tap(tester, 'Show all scanners');
      expect(find.text('Epson V850'), findsOneWidget);
      await _tap(tester, 'Only this lab\'s scanners');

      await _tap(tester, 'Send to lab');
      expect(p.sent.single.scanOrders.single.scannerId, 'front');
    });

    testWidgets('scanners picked by hand survive changing the lab', (
      tester,
    ) async {
      final p = await _pump(tester, labs: [lone, runs]);
      await _pickService(tester, 'Develop + scan');
      await _pickLab(tester, 'Self-develop', 'Scan Lab');
      await _tap(tester, 'Noritsu HS-1800');
      await _pickLab(tester, 'Scan Lab', 'Foto Lab');
      await _tap(tester, 'Send to lab');
      expect(p.sent.single.scanOrders.map((o) => o.scannerId), {
        'front',
        kNoritsuHs1800,
      });
    });

    testWidgets('an order\'s settings unfold and save', (tester) async {
      final p = await _pump(tester, labs: [lone]);
      await _pickService(tester, 'Scan');
      await _pickLab(tester, 'Self-scan (at home)', 'Foto Lab');
      expect(find.text('JPEG'), findsOneWidget);
      await _tap(tester, 'JPEG');
      await _tap(tester, 'JPEG');
      await _tap(tester, 'TIFF');
      await _tap(tester, 'Send to lab');
      expect(p.sent.single.scanOrders.single.settings, {'format': 'tiff'});
    });
  });

  group('re-scan', () {
    testWidgets('offers only a scan, worded as a re-scan', (tester) async {
      final p = await _pump(
        tester,
        status: 'scanned',
        jobs: 1,
        path: Routes.rollSend('r', resend: true),
        scanners: [_noritsu, _epson],
      );
      expect(find.text('Re-scan Roll'), findsOneWidget);
      expect(find.text('Self-scan (at home)'), findsOneWidget);
      await _tap(tester, 'Add re-scan');
      expect(p.sent.single.type, ProcessingType.scan);
      expect(p.sent.single.scanOrders.single.scannerId, 'epson');
    });
  });

  group('the roll\'s page', () {
    testWidgets('a finished roll with no job offers Send to lab', (
      tester,
    ) async {
      await _pump(tester, path: Routes.roll('r'));
      expect(find.text('Send to lab'), findsOneWidget);
      expect(find.text('Re-scan'), findsNothing);
    });

    testWidgets('a processed roll offers Re-scan', (tester) async {
      await _pump(tester, status: 'developed', jobs: 1, path: Routes.roll('r'));
      expect(find.text('Re-scan'), findsOneWidget);
      expect(find.text('Send to lab'), findsNothing);
    });

    testWidgets('a roll at the lab offers neither', (tester) async {
      await _pump(tester, status: 'at_lab', jobs: 1, path: Routes.roll('r'));
      expect(find.text('Re-scan'), findsNothing);
      expect(find.text('Send to lab'), findsNothing);
    });
  });
}
