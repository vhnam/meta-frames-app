import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:meta_frames/data/services/api_client.dart';
import 'package:meta_frames/domain/models/lab_requests.dart';
import 'package:meta_frames/domain/models/models.dart';
import 'package:meta_frames/domain/utils.dart';
import 'package:meta_frames/providers.dart';
import 'package:meta_frames/routing/router.dart';
import 'package:meta_frames/routing/routes.dart';
import 'package:meta_frames/ui/labs/widgets/send_roll.dart';

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

/// A lab that refuses the job, as the server does while another lab holds
/// the film.
class _Refusing extends FakeProcessingRepository {
  @override
  Future<Processing> send(String rollId, NewProcessing job) async {
    sent.add(job);
    throw ApiException(409, 'negatives_at_lab', 'Another lab holds the film.');
  }
}

/// Opens the send form in [mode], the way the roll's page will (slice 11).
Future<FakeProcessingRepository> _pumpMode(
  WidgetTester tester,
  SendMode mode, {
  List<ProcessingType> types = ProcessingType.values,
  ProcessingType? type,
  List<Lab> labs = const [],
  List<ScannerDevice>? scanners,
  FakeProcessingRepository? processing,
  Size size = const Size(800, 4000),
}) async {
  tester.view
    ..physicalSize = size
    ..devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  final jobs = processing ?? FakeProcessingRepository();
  final stock = FilmStock.fromJson({
    'id': 's1',
    'brand': 'Kodak',
    'name': 'Gold',
    'type': 'color',
    'boxIso': '200',
    'process': 'C-41',
    'packaging': 'factory',
  });
  final router = GoRouter(
    routes: [
      GoRoute(
        path: '/',
        builder: (_, _) => const Scaffold(body: Text('Roll')),
      ),
      GoRoute(
        path: '/send',
        builder: (_, _) => SendRollScreen(
          roll: roll('r', status: 'done_shooting'),
          stock: stock,
          types: types,
          type: type,
          mode: mode,
        ),
      ),
    ],
  );
  addTearDown(router.dispose);
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        processingRepositoryProvider.overrideWithValue(jobs),
        labRepositoryProvider.overrideWithValue(FakeLabRepository(labs)),
        scannerRepositoryProvider.overrideWithValue(
          FakeScannerRepository(scanners ?? [_noritsu, _frontier], _kinds),
        ),
      ],
      child: MaterialApp.router(routerConfig: router),
    ),
  );
  router.push('/send');
  await tester.pumpAndSettle();
  return jobs;
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
    // The record form entries are in the roll's menu.
    Future<void> openMenu(WidgetTester tester) async {
      await tester.tap(find.byTooltip('More actions'));
      await tester.pumpAndSettle();
    }

    testWidgets('a finished roll with no job offers Send to lab', (
      tester,
    ) async {
      await _pump(tester, path: Routes.roll('r'));
      await openMenu(tester);
      expect(find.text('Send to lab'), findsOneWidget);
      expect(find.text('Re-scan'), findsNothing);
    });

    testWidgets('a processed roll offers Re-scan', (tester) async {
      await _pump(tester, status: 'developed', jobs: 1, path: Routes.roll('r'));
      await openMenu(tester);
      expect(find.text('Re-scan'), findsOneWidget);
      expect(find.text('Send to lab'), findsNothing);
    });

    testWidgets('a roll at the lab offers neither', (tester) async {
      await _pump(tester, status: 'at_lab', jobs: 1, path: Routes.roll('r'));
      // No entry at all, so the menu does not show.
      expect(find.byTooltip('More actions'), findsNothing);
    });
  });

  group('start at home', () {
    testWidgets('starts an open job with no result date', (tester) async {
      final jobs = await _pumpMode(
        tester,
        SendMode.startAtHome,
        type: ProcessingType.develop,
      );
      await _tap(tester, 'Start');

      final job = jobs.sent.single;
      expect(job.labId, isNull);
      expect(job.type, ProcessingType.develop);
      // No receipt: the job stays open until its results are recorded.
      expect(jobs.receipts, isEmpty);
      expect(find.text('Roll'), findsOneWidget);
    });

    testWidgets('a home scan needs a scanner of your own', (tester) async {
      final jobs = await _pumpMode(
        tester,
        SendMode.startAtHome,
        types: const [ProcessingType.scan, ProcessingType.print],
        type: ProcessingType.scan,
      );
      await _tap(tester, 'Start');
      expect(find.text('Pick at least one scanner.'), findsOneWidget);
      expect(jobs.sent, isEmpty);
    });

    testWidgets('a home scan never runs on a lab scanner', (tester) async {
      final jobs = await _pumpMode(
        tester,
        SendMode.startAtHome,
        type: ProcessingType.scan,
        scanners: [_noritsu, _frontier],
      );
      // Only built-in lab scanners: none to pick, none sent.
      expect(find.text('Noritsu HS-1800'), findsNothing);
      expect(find.text('Frontier SP-3000'), findsNothing);
      await _tap(tester, 'Start');
      expect(find.text('Pick at least one scanner.'), findsOneWidget);
      expect(jobs.sent, isEmpty);
    });

    testWidgets('a home scan starts on your scanner, open', (tester) async {
      final jobs = await _pumpMode(
        tester,
        SendMode.startAtHome,
        type: ProcessingType.scan,
        scanners: [_noritsu, _epson],
      );
      await _tap(tester, 'Start');
      expect(jobs.sent.single.scanOrders.single.scannerId, 'epson');
      expect(jobs.receipts, isEmpty);
    });
  });

  testWidgets('a service the roll cannot have falls back to the first', (
    tester,
  ) async {
    final jobs = await _pumpMode(
      tester,
      SendMode.startAtHome,
      types: const [ProcessingType.scan, ProcessingType.print],
      type: ProcessingType.develop,
      scanners: [_noritsu, _epson],
    );
    await _tap(tester, 'Start');
    expect(jobs.sent.single.type, ProcessingType.scan);
  });

  group('hand to a lab', () {
    final lone = lab('l1', 'Foto Lab');

    testWidgets('needs a real lab before it sends', (tester) async {
      final jobs = await _pumpMode(tester, SendMode.handToLab, labs: [lone]);
      await _tap(tester, 'Send to lab');
      expect(find.text('Pick a lab.'), findsOneWidget);
      expect(jobs.sent, isEmpty);

      // The picker offers labs only, not working at home.
      await _tap(tester, 'Select a lab');
      expect(find.text('Self-develop'), findsNothing);
    });

    testWidgets('needs a lab even when its field is scrolled away', (
      tester,
    ) async {
      final jobs = await _pumpMode(
        tester,
        SendMode.handToLab,
        type: ProcessingType.develop,
        labs: [lone],
        size: const Size(390, 500),
      );
      await tester.scrollUntilVisible(
        find.text('Send to lab'),
        300,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.pumpAndSettle();
      // The Lab field is out of the list, so the Form cannot validate it.
      expect(find.text('Select a lab'), findsNothing);

      await _tap(tester, 'Send to lab');

      expect(find.text('Pick a lab.'), findsOneWidget);
      expect(jobs.sent, isEmpty);
    });

    testWidgets('sends this one roll to the picked lab', (tester) async {
      final jobs = await _pumpMode(
        tester,
        SendMode.handToLab,
        type: ProcessingType.develop,
        labs: [lone],
      );
      await _pickLab(tester, 'Select a lab', 'Foto Lab');
      await _tap(tester, 'Send to lab');

      final job = jobs.sent.single;
      expect(job.labId, 'l1');
      expect(job.type, ProcessingType.develop);
      expect(jobs.receipts, isEmpty);
    });

    testWidgets('a refused hand-over shows the reason and keeps the form', (
      tester,
    ) async {
      final jobs = await _pumpMode(
        tester,
        SendMode.handToLab,
        type: ProcessingType.develop,
        labs: [lone],
        processing: _Refusing(),
      );
      await _pickLab(tester, 'Select a lab', 'Foto Lab');
      await tester.enterText(find.byType(TextFormField).first, 'Rush');
      await _tap(tester, 'Send to lab');

      expect(find.text('Another lab holds the film.'), findsOneWidget);
      expect(find.text('Foto Lab'), findsOneWidget);
      expect(find.text('Rush'), findsOneWidget);

      // Saving again reuses the job id, so it cannot make a second job.
      await _tap(tester, 'Send to lab');
      expect(jobs.sent, hasLength(2));
      expect(jobs.sent.last.id, jobs.sent.first.id);
    });
  });
}
