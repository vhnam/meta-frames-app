import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:meta_frames/domain/models/models.dart';
import 'package:meta_frames/providers.dart';
import 'package:meta_frames/routing/router.dart';
import 'package:meta_frames/routing/routes.dart';
import 'package:meta_frames/ui/core/widgets/common.dart';

import '../../testing/fakes.dart';

const _scanJob = <String, dynamic>{
  'id': 'lab-job',
  'rollId': 'r',
  'labId': 'l1',
  'labName': 'Saigon Lab',
  'type': 'develop_scan',
  'process': 'C-41',
  'sentAt': '2026-03-21',
  'negativesExpectedAt': '2026-03-23',
  'negativesReturnedAt': '2026-03-24',
  'scansExpectedAt': '2026-03-25',
  'price': 90000,
  'notes': 'Push one stop',
  'scanOrders': [
    {
      'scannerId': kNoritsuHs1800,
      'scannerName': 'Noritsu HS-1800',
      'settings': {'format': 'tiff'},
      'scanCount': 0,
    },
  ],
  'isOpen': true,
};

class _Rolls extends FakeRollRepository {
  _Rolls(this.jobs);
  final List<Map<String, dynamic>> jobs;

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
    'processing': jobs,
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
  List<Map<String, dynamic>> jobs,
) async {
  tester.view
    ..physicalSize = const Size(800, 4000)
    ..devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  final processing = FakeProcessingRepository();
  for (final j in jobs) {
    processing.jobs[j['id']] = Processing.fromJson(j);
  }
  final router = buildRouter(initialLocation: Routes.rolls);
  addTearDown(router.dispose);
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        rollRepositoryProvider.overrideWithValue(_Rolls(jobs)),
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
      ],
      child: MaterialApp.router(routerConfig: router),
    ),
  );
  await tester.pumpAndSettle();
  router.push(Routes.rollEdit('r'));
  await tester.pumpAndSettle();
  return (router, processing);
}

void main() {
  testWidgets('a roll without jobs says so', (tester) async {
    await _open(tester, const []);
    expect(find.text('PROCESSING'), findsOneWidget);
    expect(find.text('Not sent for processing yet.'), findsOneWidget);
  });

  testWidgets('lists a job with its dates, scanners and notes', (tester) async {
    await _open(tester, const [_scanJob]);
    expect(find.text('Saigon Lab'), findsOneWidget);
    expect(
      find.text('Develop + scan · C-41 · ${fmtVnd(90000)}'),
      findsOneWidget,
    );
    expect(find.text('OPEN'), findsOneWidget);
    expect(find.text('Negatives back'), findsOneWidget);
    expect(find.text('Scans back'), findsOneWidget);
    expect(find.text('Noritsu HS-1800'), findsOneWidget);
    expect(find.text('Push one stop'), findsOneWidget);
  });

  testWidgets('lists the latest job first', (tester) async {
    await _open(tester, [
      {..._scanJob, 'id': 'old', 'labName': 'Old Lab', 'sentAt': '2026-01-01'},
      {..._scanJob, 'id': 'new', 'labName': 'New Lab', 'sentAt': '2026-03-01'},
    ]);
    expect(
      tester.getTopLeft(find.text('New Lab')).dy,
      lessThan(tester.getTopLeft(find.text('Old Lab')).dy),
    );
  });
}
