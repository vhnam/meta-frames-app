import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:meta_frames/domain/models/models.dart';
import 'package:meta_frames/providers.dart';
import 'package:meta_frames/routing/router.dart';
import 'package:meta_frames/routing/routes.dart';
import 'package:meta_frames/ui/scans/widgets/scan_grid.dart';
import 'package:meta_frames/ui/scans/widgets/scan_viewer.dart';

import '../../testing/fakes.dart';

Map<String, dynamic> _order({int scanCount = 0, String code = 'noritsu'}) => {
  'scanner': code,
  'scannerId': kNoritsuHs1800,
  'scannerName': 'Noritsu HS-1800',
  'settings': const <String, Object?>{},
  'scanCount': scanCount,
};

Map<String, dynamic> _job({
  String? labId = 'l1',
  String type = 'develop_scan',
  List<Map<String, dynamic>>? orders,
  Map<String, dynamic> extra = const {},
}) => {
  'id': 'j1',
  'rollId': 'r',
  'labId': ?labId,
  if (labId != null) 'labName': 'Saigon Lab',
  'type': type,
  'process': 'C-41',
  'sentAt': '2026-03-21',
  'scanOrders': orders ?? [_order()],
  'isOpen': true,
  ...extra,
};

class _Rolls extends FakeRollRepository {
  _Rolls(this.job);
  final Map<String, dynamic> job;

  @override
  Future<RollDetail> roll(String id) async => RollDetail.fromJson({
    'roll': {
      'id': id,
      'filmStockId': 's1',
      'stockBrand': 'Kodak',
      'stockName': 'Gold',
      'format': 135,
      'exposures': 36,
      'status': 'at_lab',
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
    'processing': [job],
    'totals': {
      'rollPrice': 0,
      'processingPrice': 0,
      'total': 0,
      'incomplete': false,
    },
  });
}

Future<(GoRouter, FakeProcessingRepository)> _open(
  WidgetTester tester,
  Map<String, dynamic> job, {
  List<Scan> scans = const [],
}) async {
  tester.view
    ..physicalSize = const Size(800, 3000)
    ..devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  final processing = FakeProcessingRepository();
  processing.jobs['j1'] = Processing.fromJson(job);
  final router = buildRouter(initialLocation: Routes.rolls);
  addTearDown(router.dispose);
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        rollRepositoryProvider.overrideWithValue(_Rolls(job)),
        filmStockRepositoryProvider.overrideWithValue(
          FakeFilmStockRepository(),
        ),
        processingRepositoryProvider.overrideWithValue(processing),
        labRepositoryProvider.overrideWithValue(FakeLabRepository()),
        scannerRepositoryProvider.overrideWithValue(
          FakeScannerRepository([
            scanner(
              kNoritsuHs1800,
              'Noritsu HS-1800',
              kind: 'minilab',
              builtIn: true,
            ),
          ], const []),
        ),
        scanRepositoryProvider.overrideWithValue(FakeScanRepository()),
        scansProvider.overrideWith((ref, k) async => scans),
      ],
      child: MaterialApp.router(routerConfig: router),
    ),
  );
  await tester.pumpAndSettle();
  router.push(Routes.roll('r'));
  await tester.pumpAndSettle();
  router.push(Routes.processing('j1'));
  await tester.pumpAndSettle();
  return (router, processing);
}

void main() {
  testWidgets('shows the job in labelled sections', (tester) async {
    await _open(
      tester,
      _job(extra: {'notes': 'Push one stop', 'price': 90000}),
    );
    expect(find.text('Saigon Lab · Develop + scan'), findsOneWidget);
    for (final label in ['JOB', 'DATES', 'SCANNERS', 'NOTES', 'SCANS']) {
      expect(find.text(label), findsOneWidget, reason: label);
    }
    expect(find.text('Scans back'), findsOneWidget);
    expect(find.text('Noritsu HS-1800'), findsOneWidget);
    expect(find.text('Push one stop'), findsOneWidget);
    expect(find.text('No scans yet'), findsOneWidget);
  });

  testWidgets('a job that makes no scans has no scan sections', (tester) async {
    await _open(tester, _job(type: 'develop', orders: const []));
    expect(find.text('SCANS'), findsNothing);
    expect(find.text('SCANNERS'), findsNothing);
    expect(find.text('Negatives returned'), findsOneWidget);
  });

  testWidgets('shows the order code of a job on an order only', (tester) async {
    await _open(
      tester,
      _job(
        extra: {
          'order': {
            'id': 'o1',
            'code': '0510006',
            'items': [
              {'id': 'l1', 'product': 'Develop'},
            ],
          },
        },
      ),
    );
    expect(find.text('#0510006'), findsOneWidget);
  });

  testWidgets('home work takes its finish date in its own words', (
    tester,
  ) async {
    await _open(tester, _job(labId: null));
    expect(find.text('Scanned'), findsOneWidget);
    expect(find.text('Negatives developed'), findsOneWidget);
    expect(find.text('Scans received'), findsNothing);
    expect(find.text('Negatives returned'), findsNothing);
  });

  testWidgets('records a receipt date from its button', (tester) async {
    final (_, p) = await _open(
      tester,
      _job(extra: {'scansReceivedAt': '2026-03-25'}),
    );
    expect(find.text('Scans received'), findsNothing);
    await tester.tap(find.text('Negatives returned'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Confirm'));
    await tester.pumpAndSettle();
    expect(p.receipts.single, startsWith('negatives:j1:'));
  });

  testWidgets('records a scans-received date from its button', (tester) async {
    final (router, p) = await _open(
      tester,
      _job(extra: {'negativesReturnedAt': '2026-03-25'}),
    );
    final before =
        router.routerDelegate.currentConfiguration.last.matchedLocation;
    await tester.tap(find.text('Scans received'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Confirm'));
    await tester.pumpAndSettle();
    expect(p.receipts.single, startsWith('scans:j1:'));
    expect(
      router.routerDelegate.currentConfiguration.last.matchedLocation,
      before,
    );
  });

  testWidgets('a scan thumbnail opens that scan in the viewer', (tester) async {
    final scan = Scan.fromJson({
      'id': 's1',
      'processingId': 'j1',
      'frameId': 'f1',
      'frameNumber': 4,
      'scanner': 'noritsu',
      'fileName': 'a.jpg',
      'sizeBytes': 1,
      'fileUrl': '/x',
    });
    final (router, _) = await _open(
      tester,
      _job(orders: [_order(scanCount: 1)]),
      scans: [scan],
    );
    await tester.tap(
      find.descendant(
        of: find.byType(ScanGrid),
        matching: find.byType(GestureDetector),
      ),
    );
    await tester.pumpAndSettle();
    expect(
      router.routerDelegate.currentConfiguration.last.matchedLocation,
      Routes.scanViewer('j1', Scanner.noritsu, 0),
    );
    expect(find.byType(ScanViewerScreen), findsOneWidget);
  });

  test('scanners come from the scan orders; scannedWith from their scans', () {
    final job = Processing.fromJson(
      _job(
        orders: [
          _order(scanCount: 36),
          _order(code: 'other'),
          _order(code: 'other'),
        ],
      ),
    );
    expect(job.scanners, [Scanner.noritsu, Scanner.other]);
    expect(job.scannedWith, [Scanner.noritsu]);
    expect(job.hasScans, isTrue);
  });
}
