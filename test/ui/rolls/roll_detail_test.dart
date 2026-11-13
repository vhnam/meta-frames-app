import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:meta_frames/data/services/api_client.dart';
import 'package:meta_frames/domain/models/models.dart';
import 'package:meta_frames/domain/utils.dart';
import 'package:meta_frames/providers.dart';
import 'package:meta_frames/routing/router.dart';
import 'package:meta_frames/routing/routes.dart';
import 'package:meta_frames/ui/core/widgets/common.dart';
import 'package:meta_frames/ui/labs/widgets/send_roll.dart';

import '../../testing/fakes.dart';

const _name = 'Fujifilm Fujicolor Superia X-TRA 400 Respooled Long Name';
const _base = 'Kodak Vision3 500T Remjet Removed Long Name';

Map<String, dynamic> _stock(String id, String name) => {
  'id': id,
  'brand': name.split(' ').first,
  'name': name.split(' ').skip(1).join(' '),
  'type': 'color',
  'boxIso': '400',
  'process': 'C-41',
  'packaging': 'factory',
};

class _Rolls extends FakeRollRepository {
  _Rolls({
    required this.withBase,
    this.fields = const {},
    this.jobs = const [],
  });
  final bool withBase;

  /// The roll's processing jobs.
  final List<Map<String, dynamic>> jobs;

  /// Roll fields laid over the default done-shooting roll.
  final Map<String, dynamic> fields;

  /// How many times the roll was read: each refresh reads it again.
  int reads = 0;

  @override
  Future<RollDetail> roll(String id) async {
    reads++;
    return RollDetail.fromJson({
      'roll': {
        'id': id,
        'filmStockId': 's1',
        'stockBrand': 'Fujifilm',
        'stockName': 'Superia',
        'format': 135,
        'exposures': 36,
        'status': 'done_shooting',
        ...fields,
      },
      'stock': _stock('s1', _name),
      'processing': jobs,
      if (withBase) 'baseStock': _stock('s2', _base),
      'totals': {
        'rollPrice': 0,
        'processingPrice': 0,
        'total': 0,
        'incomplete': false,
      },
    });
  }
}

/// Scanners that arrive only when the test completes [load].
class _SlowScanners extends FakeScannerRepository {
  final load = Completer<List<ScannerDevice>>();

  @override
  Future<List<ScannerDevice>> scanners() => load.future;
}

/// Opens the roll's page at the width of a narrow phone.
Future<GoRouter> _pump(
  WidgetTester tester, {
  bool withBase = true,
  Map<String, dynamic> fields = const {},
  FakeProcessingRepository? processing,
  bool ownScanner = true,
  FakeScannerRepository? scanners,
  _Rolls? rolls,
}) async {
  tester.view
    ..physicalSize = const Size(360, 2000)
    ..devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  final router = buildRouter(initialLocation: Routes.roll('r'));
  addTearDown(router.dispose);
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        rollRepositoryProvider.overrideWithValue(
          rolls ?? _Rolls(withBase: withBase, fields: fields),
        ),
        filmStockRepositoryProvider.overrideWithValue(
          FakeFilmStockRepository(),
        ),
        processingRepositoryProvider.overrideWithValue(
          processing ?? FakeProcessingRepository(),
        ),
        labRepositoryProvider.overrideWithValue(
          FakeLabRepository([lab('l1', 'Foto Lab')]),
        ),
        scannerRepositoryProvider.overrideWithValue(
          // A lab with no scanner list scans on the Noritsu.
          scanners ??
              FakeScannerRepository([
                scanner(
                  kNoritsuHs1800,
                  'Noritsu',
                  kind: 'minilab',
                  builtIn: true,
                ),
                if (ownScanner) scanner('own', 'Epson V850', kind: 'flatbed'),
              ], const []),
        ),
      ],
      child: MaterialApp.router(routerConfig: router),
    ),
  );
  await tester.pumpAndSettle();
  return router;
}

Finder _inCard(String text) =>
    find.descendant(of: find.byType(ListView), matching: find.text(text));

void main() {
  testWidgets('the status sits under the names, in that order', (tester) async {
    await _pump(tester);
    final name = tester.getTopLeft(_inCard(_name));
    final base = tester.getTopLeft(_inCard('Base: $_base'));
    final status = tester.getTopLeft(
      find.ancestor(
        of: _inCard('DONE SHOOTING'),
        matching: find.byType(StampBadge),
      ),
    );
    expect(name.dy, lessThan(base.dy));
    expect(base.dy, lessThan(status.dy));
    expect(status.dx, name.dx);
  });

  testWidgets('a long name has the width of the card and is not cut', (
    tester,
  ) async {
    await _pump(tester);
    // 360 wide, less 16 page, 16 card padding each side, chevron and its gap.
    expect(tester.getSize(_inCard(_name)).width, greaterThan(250));
    final title = tester.widget<Text>(_inCard(_name));
    expect(title.maxLines, isNull);
    expect(title.overflow, isNull);
    expect(tester.takeException(), isNull);
  });

  testWidgets('without a base stock it shows the speed and process', (
    tester,
  ) async {
    await _pump(tester, withBase: false);
    expect(_inCard('ISO 400 · C-41'), findsOneWidget);
  });

  testWidgets('the row opens the stock', (tester) async {
    final router = await _pump(tester);
    await tester.tap(_inCard(_name));
    await tester.pumpAndSettle();
    expect(
      router.routerDelegate.currentConfiguration.last.matchedLocation,
      Routes.stock('s1'),
    );
  });

  group('processing from the plan', () {
    Future<void> tap(WidgetTester tester, String text) async {
      await tester.tap(find.text(text).last);
      await tester.pumpAndSettle();
    }

    testWidgets('no plan: the sheet asks, then home develop starts open', (
      tester,
    ) async {
      final jobs = FakeProcessingRepository();
      await _pump(
        tester,
        fields: {'stage': 'done_shooting', 'plan': <String, dynamic>{}},
        processing: jobs,
      );
      await tap(tester, 'Develop');
      expect(find.text('Hand to a lab'), findsOneWidget);
      await tap(tester, 'Develop at home');
      await tap(tester, 'Start');

      final job = jobs.sent.single;
      expect(job.labId, isNull);
      expect(job.type, ProcessingType.develop);
      expect(jobs.receipts, isEmpty);
      // The form closed: back on the roll's page.
      expect(find.byType(SendRollScreen), findsNothing);
      expect(find.text('Develop'), findsOneWidget);
    });

    testWidgets('no plan: the sheet can hand the roll to a lab', (
      tester,
    ) async {
      final jobs = FakeProcessingRepository();
      await _pump(
        tester,
        fields: {'stage': 'done_shooting', 'plan': <String, dynamic>{}},
        processing: jobs,
      );
      await tap(tester, 'Develop');
      await tap(tester, 'Hand to a lab');
      await tap(tester, 'Select a lab');
      await tap(tester, 'Foto Lab');
      await tap(tester, 'Send to lab');

      expect(jobs.sent.single.labId, 'l1');
      expect(jobs.sent.single.type, ProcessingType.developScan);
    });

    testWidgets('a full plan skips the sheet', (tester) async {
      final jobs = FakeProcessingRepository();
      await _pump(
        tester,
        fields: {
          'stage': 'done_shooting',
          'plan': {'target': 'developed', 'developBy': 'lab'},
        },
        processing: jobs,
      );
      await tap(tester, 'Hand to lab');
      expect(find.text('How is it processed?'), findsNothing);
      await tap(tester, 'Select a lab');
      await tap(tester, 'Foto Lab');
      await tap(tester, 'Send to lab');

      // The plan stops at developed, so the lab only develops.
      expect(jobs.sent.single.type, ProcessingType.develop);
      expect(jobs.sent.single.labId, 'l1');
    });

    testWidgets('a home develop in the plan opens the form at once', (
      tester,
    ) async {
      final jobs = FakeProcessingRepository();
      await _pump(
        tester,
        fields: {
          'stage': 'done_shooting',
          'plan': {'developBy': 'self'},
        },
        processing: jobs,
      );
      await tap(tester, 'Start developing at home');
      expect(find.text('How is it processed?'), findsNothing);
      await tap(tester, 'Start');
      expect(jobs.sent.single.labId, isNull);
      expect(jobs.receipts, isEmpty);
    });

    testWidgets('a lab that holds the film leaves only a lab to choose', (
      tester,
    ) async {
      final jobs = FakeProcessingRepository();
      await _pump(
        tester,
        fields: {
          'stage': 'done_shooting',
          'plan': <String, dynamic>{},
          'negativesAtLab': true,
        },
        processing: jobs,
      );
      await tap(tester, 'Develop');
      // No sheet: a home develop cannot start, so the hand-over opens.
      expect(find.text('Develop at home'), findsNothing);
      await tap(tester, 'Select a lab');
      await tap(tester, 'Foto Lab');
      await tap(tester, 'Send to lab');
      expect(jobs.sent.single.labId, 'l1');
    });

    testWidgets('a home scan in the plan has the lab only develop', (
      tester,
    ) async {
      final jobs = FakeProcessingRepository();
      await _pump(
        tester,
        fields: {
          'stage': 'done_shooting',
          'plan': {'developBy': 'lab', 'scanBy': 'self'},
        },
        processing: jobs,
      );
      await tap(tester, 'Hand to lab');
      await tap(tester, 'Select a lab');
      await tap(tester, 'Foto Lab');
      await tap(tester, 'Send to lab');
      expect(jobs.sent.single.type, ProcessingType.develop);
    });

    testWidgets('a scan with no place asks where, then scans at home', (
      tester,
    ) async {
      final jobs = FakeProcessingRepository();
      await _pump(
        tester,
        fields: {
          'status': 'developed',
          'stage': 'completed',
          'needsScan': true,
          'plan': <String, dynamic>{},
          'negativesAtLab': false,
        },
        processing: jobs,
      );
      await tap(tester, 'Scan');
      expect(find.text('Scan at a lab'), findsOneWidget);
      await tap(tester, 'Scan at home');
      await tap(tester, 'Start');

      final job = jobs.sent.single;
      expect(job.type, ProcessingType.scan);
      expect(job.labId, isNull);
      expect(job.scanOrders.single.scannerId, 'own');
    });

    testWidgets('with only lab scanners, a scan goes to a lab at once', (
      tester,
    ) async {
      final jobs = FakeProcessingRepository();
      await _pump(
        tester,
        fields: {
          'status': 'developed',
          'stage': 'completed',
          'needsScan': true,
          'plan': <String, dynamic>{},
          'negativesAtLab': false,
        },
        processing: jobs,
        ownScanner: false,
      );
      await tap(tester, 'Scan');
      expect(find.text('Scan at home'), findsNothing);
      await tap(tester, 'Select a lab');
      await tap(tester, 'Foto Lab');
      await tap(tester, 'Send to lab');

      expect(jobs.sent.single.type, ProcessingType.scan);
      expect(jobs.sent.single.labId, 'l1');
    });

    testWidgets('a second tap while scanners load opens no second form', (
      tester,
    ) async {
      final slow = _SlowScanners();
      await _pump(
        tester,
        fields: {
          'status': 'developed',
          'stage': 'completed',
          'needsScan': true,
          'plan': <String, dynamic>{},
          'negativesAtLab': false,
        },
        scanners: slow,
      );
      // Both taps land before the button rebuilds.
      await tester.tap(find.text('Scan'));
      await tester.tap(find.text('Scan'));
      await tester.pump();
      slow.load.complete(const []);
      await tester.pumpAndSettle();
      expect(find.byType(SendRollScreen), findsOneWidget);

      // One Back returns to the roll's page, and Scan works again.
      await tester.pageBack();
      await tester.pumpAndSettle();
      expect(find.byType(SendRollScreen), findsNothing);
      await tester.tap(find.text('Scan'));
      await tester.pumpAndSettle();
      expect(find.byType(SendRollScreen), findsOneWidget);
    });

    testWidgets('a scan picked for a lab hands over a scan job', (
      tester,
    ) async {
      final jobs = FakeProcessingRepository();
      await _pump(
        tester,
        fields: {
          'status': 'developed',
          'stage': 'completed',
          'needsScan': true,
          'plan': <String, dynamic>{},
          'negativesAtLab': false,
        },
        processing: jobs,
      );
      await tap(tester, 'Scan');
      await tap(tester, 'Scan at a lab');
      await tap(tester, 'Select a lab');
      await tap(tester, 'Foto Lab');
      await tap(tester, 'Send to lab');

      expect(jobs.sent.single.type, ProcessingType.scan);
      expect(jobs.sent.single.labId, 'l1');
    });
  });

  group('plan and Needs scan menu', () {
    Future<_Rolls> open(
      WidgetTester tester,
      Map<String, dynamic> fields,
    ) async {
      final rolls = _Rolls(
        withBase: true,
        fields: {'stage': 'done_shooting', ...fields},
      );
      await _pump(tester, rolls: rolls);
      await tester.tap(find.byTooltip('More actions'));
      await tester.pumpAndSettle();
      return rolls;
    }

    Future<void> pick(WidgetTester tester, String field, String option) async {
      await tester.tap(find.widgetWithText(InputDecorator, field));
      await tester.pumpAndSettle();
      await tester.tap(find.text(option).last);
      await tester.pumpAndSettle();
    }

    testWidgets('the plan opens with the saved choices and saves online', (
      tester,
    ) async {
      final rolls = await open(tester, {
        'needsScan': false,
        'plan': {'developBy': 'lab'},
      });
      await tester.tap(find.text('Change plan'));
      await tester.pumpAndSettle();
      await pick(tester, 'Goal', 'Develop + scan');
      final reads = rolls.reads;
      await tester.tap(find.text('Save'));
      await tester.pumpAndSettle();

      final plan = rolls.plans.single;
      expect(plan.target, PlanTarget.scanned);
      // The saved choice the user did not touch is kept.
      expect(plan.developBy, StepActor.lab);
      expect(plan.scanBy, isNull);
      expect(find.text('Save'), findsNothing);
      expect(rolls.reads, greaterThan(reads));
    });

    testWidgets('a develop-only plan drops the scanner', (tester) async {
      final rolls = await open(tester, {
        'needsScan': false,
        'plan': {'target': 'scanned', 'scanBy': 'self'},
      });
      await tester.tap(find.text('Change plan'));
      await tester.pumpAndSettle();
      await pick(tester, 'Goal', 'Develop only');
      await tester.tap(find.text('Save'));
      await tester.pumpAndSettle();

      expect(rolls.plans.single.target, PlanTarget.developed);
      expect(rolls.plans.single.scanBy, isNull);
    });

    testWidgets('a refused plan keeps the sheet and the input', (tester) async {
      final rolls = await open(tester, {
        'needsScan': false,
        'plan': <String, dynamic>{},
      });
      rolls.writeError = ApiException(422, 'invalid_plan', 'Plan refused.');
      await tester.tap(find.text('Change plan'));
      await tester.pumpAndSettle();
      await pick(tester, 'Develop by', 'At home');
      final reads = rolls.reads;
      await tester.tap(find.text('Save'));
      await tester.pumpAndSettle();

      expect(find.text('Plan refused.'), findsOneWidget);
      expect(rolls.plans, isEmpty);
      expect(rolls.reads, reads);

      // Saving again sends the input that was kept.
      rolls.writeError = null;
      await tester.tap(find.text('Save'));
      await tester.pumpAndSettle();
      expect(rolls.plans.single.developBy, StepActor.self);
      expect(find.text('Save'), findsNothing);
    });

    testWidgets('Needs scan marks the roll and refreshes it', (tester) async {
      final rolls = await open(tester, {'needsScan': false});
      final reads = rolls.reads;
      await tester.tap(find.text('Needs scan'));
      await tester.pumpAndSettle();
      expect(rolls.calls, contains('markScan:r'));
      expect(rolls.reads, greaterThan(reads));
    });

    testWidgets('Remove needs scan unmarks the roll', (tester) async {
      final rolls = await open(tester, {'needsScan': true});
      await tester.tap(find.text('Remove needs scan'));
      await tester.pumpAndSettle();
      expect(rolls.calls, contains('unmarkScan:r'));
    });

    testWidgets('a refused Needs scan shows why and refreshes nothing', (
      tester,
    ) async {
      final rolls = await open(tester, {'needsScan': false});
      rolls.writeError = ApiException(409, 'conflict', 'Roll changed.');
      final reads = rolls.reads;
      await tester.tap(find.text('Needs scan'));
      await tester.pumpAndSettle();
      expect(find.text('Roll changed.'), findsOneWidget);
      expect(rolls.reads, reads);
    });

    testWidgets('a cached roll with no stage has no plan menu', (tester) async {
      await _pump(tester, fields: {'status': 'developed'});
      expect(find.byTooltip('More actions'), findsNothing);
    });
  });

  group('date actions and the main button', () {
    Map<String, dynamic> job(
      String id, {
      String type = 'develop',
      String? labId = 'l1',
      String? developedAt,
      String? scansReceivedAt,
      bool isOpen = true,
    }) => {
      'id': id,
      'rollId': 'r',
      'labId': labId,
      'type': type,
      'process': 'C-41',
      'sentAt': '2026-10-02',
      'developedAt': developedAt,
      'scansReceivedAt': scansReceivedAt,
      'isOpen': isOpen,
    };

    // A lab is developing the roll; one open develop job.
    const developing = {
      'status': 'at_lab',
      'stage': 'processing',
      'stageDetail': 'lab_developing',
      'negativesAtLab': true,
      'needsScan': false,
      'plan': <String, dynamic>{},
    };

    Future<void> openMenu(WidgetTester tester) async {
      await tester.tap(find.byTooltip('More actions'));
      await tester.pumpAndSettle();
    }

    testWidgets('Mark as developed sends the picked day once', (tester) async {
      final rolls = _Rolls(
        withBase: true,
        fields: developing,
        jobs: [job('j1')],
      );
      await _pump(tester, rolls: rolls);
      final reads = rolls.reads;
      await tester.tap(find.text('Mark as developed'));
      await tester.pumpAndSettle();

      // The day can be from the job's sent date to today, not later.
      final picker = tester.widget<DatePickerDialog>(
        find.byType(DatePickerDialog),
      );
      expect(picker.firstDate, DateTime(2026, 10, 2));
      expect(picker.lastDate, DateUtils.dateOnly(DateTime.now()));
      await tester.tap(find.text('OK'));
      await tester.pumpAndSettle();

      expect(ymd(rolls.developed.single.date!), ymd(DateTime.now()));
      expect(rolls.developed.single.target, isNull);
      expect(rolls.reads, greaterThan(reads));

      // The main action is not in the menu again.
      await openMenu(tester);
      expect(find.text('Change plan'), findsOneWidget);
      expect(find.text('Mark as developed'), findsOneWidget);
    });

    testWidgets('with no job, the develop date starts at the finish date', (
      tester,
    ) async {
      final rolls = _Rolls(
        withBase: true,
        fields: {
          'stage': 'done_shooting',
          'finishedAt': '2026-10-01',
          'negativesAtLab': false,
          'needsScan': false,
          'plan': {'developBy': 'self'},
        },
      );
      await _pump(tester, rolls: rolls);
      // The main button starts a home develop; the menu records one done.
      await openMenu(tester);
      await tester.tap(find.text('Mark as developed'));
      await tester.pumpAndSettle();
      final picker = tester.widget<DatePickerDialog>(
        find.byType(DatePickerDialog),
      );
      expect(picker.firstDate, DateTime(2026, 10, 1));
      await tester.tap(find.text('OK'));
      await tester.pumpAndSettle();
      expect(rolls.developed, hasLength(1));
    });

    testWidgets('a refused develop date shows why and refreshes nothing', (
      tester,
    ) async {
      final rolls = _Rolls(
        withBase: true,
        fields: developing,
        jobs: [job('j1')],
      );
      rolls.writeError = ApiException(
        422,
        'developed_before_sent',
        'Developed before the job was sent.',
      );
      await _pump(tester, rolls: rolls);
      final reads = rolls.reads;
      await tester.tap(find.text('Mark as developed'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('OK'));
      await tester.pumpAndSettle();

      expect(find.text('Developed before the job was sent.'), findsOneWidget);
      expect(rolls.developed, isEmpty);
      expect(rolls.reads, reads);
    });

    testWidgets('a cancelled date picker sends nothing', (tester) async {
      final rolls = _Rolls(
        withBase: true,
        fields: developing,
        jobs: [job('j1')],
      );
      await _pump(tester, rolls: rolls);
      await tester.tap(find.text('Mark as developed'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();
      expect(rolls.developed, isEmpty);
    });

    testWidgets('the return comes before a scan, by the handoff id', (
      tester,
    ) async {
      final rolls = _Rolls(
        withBase: true,
        fields: {
          'status': 'developed',
          'stage': 'completed',
          'needsScan': true,
          'plan': {'scanBy': 'lab'},
          'negativesAtLab': true,
          'openHandoffId': 'h1',
        },
        jobs: [job('j1', developedAt: '2026-10-05', isOpen: false)],
      )..all = [roll('r', status: 'developed')];
      await _pump(tester, rolls: rolls);
      // No hand-over button: returning the negatives is the main action.
      expect(find.text('Hand to lab'), findsNothing);
      await tester.tap(find.text('Negatives returned'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('OK'));
      await tester.pumpAndSettle();

      expect(rolls.calls, ['returned:h1:${ymd(DateTime.now())}']);
      await openMenu(tester);
      expect(find.text('Negatives returned'), findsOneWidget);
      // No scan while the lab holds the negatives.
      expect(find.text('Re-scan'), findsNothing);
    });

    testWidgets('a roll from before handoffs returns on its lab job', (
      tester,
    ) async {
      final rolls = _Rolls(
        withBase: true,
        fields: {
          'status': 'developed',
          'stage': 'completed',
          'needsScan': false,
          'plan': <String, dynamic>{},
          'negativesAtLab': true,
        },
        jobs: [
          job('home', labId: null, isOpen: false),
          job('j2', developedAt: '2026-10-05', isOpen: false),
        ],
      );
      final router = await _pump(tester, rolls: rolls);
      await openMenu(tester);
      expect(find.text('Re-scan'), findsNothing);
      await tester.tapAt(Offset.zero);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Negatives returned'));
      await tester.pumpAndSettle();

      expect(
        router.routerDelegate.currentConfiguration.last.matchedLocation,
        Routes.processing('j2'),
      );
      expect(rolls.calls, isEmpty);
    });

    testWidgets('one lab scan in progress opens its job', (tester) async {
      final rolls = _Rolls(
        withBase: true,
        fields: {
          'status': 'developed',
          'stage': 'processing',
          'stageDetail': 'lab_scanning',
          'negativesAtLab': true,
          'needsScan': false,
          'plan': <String, dynamic>{},
          'openHandoffId': null,
        },
        jobs: [job('s1', type: 'scan')],
      );
      final router = await _pump(tester, rolls: rolls);
      // Both taps land before the button rebuilds.
      await tester.tap(find.text('Open job'));
      await tester.tap(find.text('Open job'));
      await tester.pumpAndSettle();
      expect(
        router.routerDelegate.currentConfiguration.last.matchedLocation,
        Routes.processing('s1'),
      );

      // The job opened once: one Back returns to the roll's page.
      await tester.pageBack();
      await tester.pumpAndSettle();
      expect(
        router.routerDelegate.currentConfiguration.last.matchedLocation,
        Routes.roll('r'),
      );
    });

    testWidgets(
      'done shooting has one hand-over button; the record form is in the menu',
      (tester) async {
        final router = await _pump(
          tester,
          fields: {
            'stage': 'done_shooting',
            'needsScan': false,
            'plan': {'developBy': 'lab'},
          },
        );
        expect(find.byType(FilledButton), findsOneWidget);
        expect(find.text('Send to lab'), findsNothing);
        await openMenu(tester);
        await tester.tap(find.text('Send to lab'));
        await tester.pumpAndSettle();
        expect(router.state.uri.toString(), Routes.rollSend('r'));
      },
    );

    testWidgets(
      'completed with nothing waiting: no main button, Re-scan in the menu',
      (tester) async {
        final router = await _pump(
          tester,
          rolls: _Rolls(
            withBase: true,
            fields: {
              'status': 'developed',
              'stage': 'completed',
              'needsScan': false,
              'plan': <String, dynamic>{},
              'negativesAtLab': false,
            },
            jobs: [job('j1', developedAt: '2026-10-05', isOpen: false)],
          ),
        );
        expect(find.byType(FilledButton), findsNothing);
        await openMenu(tester);
        await tester.tap(find.text('Re-scan'));
        await tester.pumpAndSettle();
        expect(router.state.uri.toString(), Routes.rollSend('r', resend: true));
      },
    );
  });

  testWidgets('a home develop reads as one stage label, not At lab', (
    tester,
  ) async {
    await _pump(
      tester,
      fields: {
        'status': 'at_lab',
        'stage': 'processing',
        'stageDetail': 'home_developing',
        'negativesAtLab': false,
        'needsScan': false,
        'plan': <String, dynamic>{},
      },
    );
    // Stamps are upper case.
    expect(_inCard('DEVELOPING AT HOME'), findsOneWidget);
    expect(_inCard(RollStatus.atLab.label.toUpperCase()), findsNothing);
  });

  group('entries and block order', () {
    const inCamera = {
      'status': 'in_camera',
      'stage': 'in_camera',
      'needsScan': false,
      'plan': <String, dynamic>{},
    };

    double top(WidgetTester tester, String label) =>
        tester.getTopLeft(find.text(label)).dy;

    testWidgets('in a camera, one tap opens the frame log', (tester) async {
      final router = await _pump(tester, fields: inCamera);
      await tester.tap(find.text('Log frame'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField), '3');
      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();
      expect(
        router.routerDelegate.currentConfiguration.last.matchedLocation,
        Routes.frame('r', 3),
      );
    });

    testWidgets(
      'in a camera, Finish is in the menu and frames come before the history',
      (tester) async {
        final rolls = _Rolls(withBase: true, fields: inCamera);
        await _pump(tester, rolls: rolls);
        // The main action is at the top of the page.
        expect(top(tester, 'Log frame'), lessThan(top(tester, 'ROLL')));
        expect(
          top(tester, 'FRAMES'),
          lessThan(top(tester, 'PROCESSING HISTORY')),
        );
        expect(
          top(tester, 'NOTES'),
          lessThan(top(tester, 'PROCESSING HISTORY')),
        );
        expect(find.byType(FilledButton), findsOneWidget);

        await tester.tap(find.byTooltip('More actions'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Finish roll'));
        await tester.pumpAndSettle();
        await tester.tap(find.widgetWithText(FilledButton, 'Finish'));
        await tester.pumpAndSettle();
        expect(rolls.calls, contains('finish:r'));
      },
    );

    testWidgets('in stock, the main button loads the roll', (tester) async {
      final router = await _pump(
        tester,
        fields: {'status': 'in_stock', 'stage': 'in_stock'},
      );
      await tester.tap(find.text('Load into camera'));
      await tester.pumpAndSettle();
      expect(
        router.routerDelegate.currentConfiguration.last.matchedLocation,
        Routes.rollLoad('r'),
      );
    });

    testWidgets('while processed, the jobs come first', (tester) async {
      await _pump(
        tester,
        fields: {
          'status': 'at_lab',
          'stage': 'processing',
          'stageDetail': 'lab_developing',
          'negativesAtLab': true,
          'needsScan': false,
          'plan': <String, dynamic>{},
        },
      );
      expect(top(tester, 'PROCESSING HISTORY'), lessThan(top(tester, 'NOTES')));
      expect(
        top(tester, 'PROCESSING HISTORY'),
        lessThan(top(tester, 'FRAMES')),
      );
    });
  });
}
