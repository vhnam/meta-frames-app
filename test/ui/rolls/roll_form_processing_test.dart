import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:meta_frames/domain/models/models.dart';
import 'package:meta_frames/domain/utils.dart';
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

  group('editing a job', () {
    Future<FakeProcessingRepository> edit(
      WidgetTester tester, [
      Map<String, dynamic> job = _scanJob,
    ]) async {
      final (_, processing) = await _open(tester, [job]);
      await tester.tap(find.text('Edit'));
      await tester.pumpAndSettle();
      return processing;
    }

    testWidgets('starts from the job, with lab and service fixed', (
      tester,
    ) async {
      await edit(tester);
      expect(find.text('Edit Processing Job'), findsOneWidget);
      expect(find.text('LAB (LOCKED)'), findsOneWidget);
      expect(find.text('SERVICE (LOCKED)'), findsOneWidget);
      expect(
        find.text(
          'The lab and service cannot be changed once the job is recorded.',
        ),
        findsOneWidget,
      );
      expect(find.text('* Required attributes'), findsOneWidget);
      expect(find.text('DATE SENT *'), findsOneWidget);
      expect(find.text('Saigon Lab'), findsOneWidget);
      expect(find.text('Push one stop'), findsOneWidget);
      expect(find.text('90000'), findsOneWidget);
      expect(find.text('SCANS RECEIVED (OPTIONAL)'), findsOneWidget);
      expect(find.text('NEGATIVES RECEIVED (OPTIONAL)'), findsOneWidget);
    });

    testWidgets('saves under the same id and sends no unchanged receipt', (
      tester,
    ) async {
      final p = await edit(tester);
      await tester.enterText(
        find.widgetWithText(TextFormField, '90000'),
        '100000',
      );
      await tester.tap(find.text('Save changes'));
      await tester.pumpAndSettle();

      final job = p.sent.single;
      expect(job.id, 'lab-job');
      expect(job.labId, 'l1');
      expect(job.type, ProcessingType.developScan);
      expect(job.price, 100000);
      expect(ymd(job.sentAt!), '2026-03-21');
      expect(ymd(job.scansExpectedAt!), '2026-03-25');
      expect(ymd(job.negativesExpectedAt!), '2026-03-23');
      expect(job.scanOrders.single.settings, {'format': 'tiff'});
      expect(p.receipts, isEmpty);
      expect(find.text('Edit Roll'), findsOneWidget);
    });

    testWidgets('deleting a job confirms and returns to Edit Roll', (
      tester,
    ) async {
      final p = await edit(tester);
      await tester.tap(find.text('Delete job'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Delete'));
      await tester.pumpAndSettle();
      expect(p.deleted, ['lab-job']);
      expect(find.text('Edit Roll'), findsOneWidget);
    });

    testWidgets('a job with imported scans has no delete action', (
      tester,
    ) async {
      await edit(tester, {
        ..._scanJob,
        'scanOrders': [
          {
            'scannerId': kNoritsuHs1800,
            'scannerName': 'Noritsu HS-1800',
            'scanCount': 36,
          },
        ],
      });
      expect(find.text('Save changes'), findsOneWidget);
      expect(find.text('Delete job'), findsNothing);
    });

    testWidgets('a scanner with imported scans cannot be unticked', (
      tester,
    ) async {
      await edit(tester, {
        ..._scanJob,
        'scanOrders': [
          {
            'scannerId': kNoritsuHs1800,
            'scannerName': 'Noritsu HS-1800',
            'scanCount': 36,
          },
        ],
      });
      expect(
        find.text('A scanner with imported scans cannot be removed.'),
        findsOneWidget,
      );
      expect(tester.widget<Checkbox>(find.byType(Checkbox)).onChanged, isNull);
    });
  });
}
