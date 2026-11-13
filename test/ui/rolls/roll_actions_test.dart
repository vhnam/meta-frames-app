import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:meta_frames/data/services/api_client.dart';
import 'package:meta_frames/domain/models/models.dart';
import 'package:meta_frames/domain/models/roll_filter.dart';
import 'package:meta_frames/domain/models/roll_requests.dart';
import 'package:meta_frames/providers.dart';
import 'package:meta_frames/ui/rolls/view_models/roll_actions.dart';

import '../../testing/fakes.dart';

void main() {
  detailActionTests();

  test('finishing a roll refreshes roll and camera data, not lenses', () async {
    final rolls = FakeRollRepository([roll('a')]);
    final cameras = FakeCameraRepository(cameraList: [camera('c1')]);
    final lenses = FakeLensRepository([lens('l1')]);
    final container = ProviderContainer(
      overrides: [
        rollRepositoryProvider.overrideWithValue(rolls),
        cameraRepositoryProvider.overrideWithValue(cameras),
        lensRepositoryProvider.overrideWithValue(lenses),
      ],
    );
    addTearDown(container.dispose);

    // Keep the providers alive, as mounted screens would.
    final subs = [
      container.listen(rollsProvider(RollFilter.empty), (_, _) {}),
      container.listen(camerasProvider, (_, _) {}),
      container.listen(lensesProvider, (_, _) {}),
    ];
    addTearDown(() {
      for (final s in subs) {
        s.close();
      }
    });
    await container.read(rollsProvider(RollFilter.empty).future);
    await container.read(camerasProvider.future);
    await container.read(lensesProvider.future);
    final rollListCalls = rolls.listCalls;
    final cameraListCalls = cameras.listCalls;
    final lensListCalls = lenses.listCalls;

    await container.read(rollActionsProvider).finish('a', DateTime(2026, 1, 1));
    await container.read(rollsProvider(RollFilter.empty).future);
    await container.read(camerasProvider.future);

    expect(rolls.calls, ['finish:a']);
    expect(rolls.listCalls, rollListCalls + 1);
    expect(cameras.listCalls, cameraListCalls + 1);
    expect(lenses.listCalls, lensListCalls);
  });

  test('setting a roll\'s lenses refreshes roll lists once', () async {
    final rolls = FakeRollRepository([roll('a')]);
    final container = ProviderContainer(
      overrides: [rollRepositoryProvider.overrideWithValue(rolls)],
    );
    addTearDown(container.dispose);
    final sub = container.listen(rollsProvider(RollFilter.empty), (_, _) {});
    addTearDown(sub.close);
    await container.read(rollsProvider(RollFilter.empty).future);
    final before = rolls.listCalls;

    await container.read(rollActionsProvider).setLenses('a', ['l1']);
    await Future<void>.delayed(Duration.zero);

    // A cached list filtered by lens must not keep the old answer.
    expect(rolls.calls, ['setLenses:a']);
    expect(rolls.listCalls, before + 1);
  });

  group('online roll writes', () {
    late FakeRollRepository rolls;
    late ProviderContainer container;

    setUp(() async {
      rolls = FakeRollRepository([roll('a')]);
      container = ProviderContainer(
        overrides: [rollRepositoryProvider.overrideWithValue(rolls)],
      );
      addTearDown(container.dispose);
      final listSub = container.listen(
        rollsProvider(RollFilter.empty),
        (_, _) {},
      );
      final detailSub = container.listen(rollDetailProvider('a'), (_, _) {});
      addTearDown(listSub.close);
      addTearDown(detailSub.close);
      await container.read(rollsProvider(RollFilter.empty).future);
      await container.read(rollDetailProvider('a').future);
    });

    test('sends the plan once and refreshes list and details after the server took it', () async {
      final before = rolls.listCalls;
      final detailsBefore = rolls.detailCalls;
      const plan = RollPlan(target: PlanTarget.scanned, scanBy: StepActor.lab);

      await container.read(rollActionsProvider).setPlan('a', plan);
      await container.read(rollsProvider(RollFilter.empty).future);
      await container.read(rollDetailProvider('a').future);

      expect(rolls.calls, ['setPlan:a']);
      expect(rolls.plans.single, plan);
      expect(rolls.listCalls, before + 1);
      expect(rolls.detailCalls, detailsBefore + 1);
    });

    test('a failed save throws and refreshes nothing', () async {
      final before = rolls.listCalls;
      final detailsBefore = rolls.detailCalls;
      rolls.writeError = ApiException(0, 'network', 'Cannot reach the server.');

      await expectLater(
        container.read(rollActionsProvider).setPlan('a', const RollPlan()),
        throwsA(isA<ApiException>()),
      );
      await Future<void>.delayed(Duration.zero);

      expect(rolls.calls, isEmpty);
      expect(rolls.listCalls, before);
      expect(rolls.detailCalls, detailsBefore);
    });

    test(
      'marking and unmarking Needs scan each refresh list and details',
      () async {
        for (final (needed, call) in [
          (true, 'markScan:a'),
          (false, 'unmarkScan:a'),
        ]) {
          final before = rolls.listCalls;
          final detailsBefore = rolls.detailCalls;

          await container.read(rollActionsProvider).setNeedsScan('a', needed);
          await container.read(rollsProvider(RollFilter.empty).future);
          await container.read(rollDetailProvider('a').future);

          expect(rolls.calls.last, call);
          expect(rolls.listCalls, before + 1, reason: call);
          expect(rolls.detailCalls, detailsBefore + 1, reason: call);
        }
        expect(rolls.calls, ['markScan:a', 'unmarkScan:a']);
      },
    );

    test('a failed Needs scan change throws and refreshes nothing', () async {
      final before = rolls.listCalls;
      final detailsBefore = rolls.detailCalls;
      rolls.writeError = ApiException(0, 'network', 'Cannot reach the server.');

      await expectLater(
        container.read(rollActionsProvider).setNeedsScan('a', true),
        throwsA(isA<ApiException>()),
      );
      await Future<void>.delayed(Duration.zero);

      expect(rolls.calls, isEmpty);
      expect(rolls.listCalls, before);
      expect(rolls.detailCalls, detailsBefore);
    });

    test(
      'marking developed sends once, then refreshes list and details',
      () async {
        final before = rolls.listCalls;
        final detailsBefore = rolls.detailCalls;
        final input = DevelopedInput(
          date: DateTime(2026, 11, 3),
          target: PlanTarget.developed,
        );

        await container.read(rollActionsProvider).markDeveloped('a', input);
        await container.read(rollsProvider(RollFilter.empty).future);
        await container.read(rollDetailProvider('a').future);

        expect(rolls.calls, ['developed:a']);
        expect(rolls.developed.single, input);
        expect(rolls.listCalls, before + 1);
        expect(rolls.detailCalls, detailsBefore + 1);
      },
    );

    for (final failure in [
      ApiException(
        422,
        'developed_before_sent',
        'The develop date is before the roll was sent.',
      ),
      ApiException(0, 'network', 'Cannot reach the server.'),
    ]) {
      test(
        'a develop date that fails (${failure.code}) throws and refreshes nothing',
        () async {
          final before = rolls.listCalls;
          final detailsBefore = rolls.detailCalls;
          rolls.writeError = failure;

          await expectLater(
            container
                .read(rollActionsProvider)
                .markDeveloped('a', const DevelopedInput()),
            throwsA(
              isA<ApiException>()
                  .having((error) => error.code, 'code', failure.code)
                  .having(
                    (error) => error.isNetwork,
                    'isNetwork',
                    failure.isNetwork,
                  ),
            ),
          );
          await Future<void>.delayed(Duration.zero);

          expect(rolls.calls, isEmpty);
          expect(rolls.listCalls, before);
          expect(rolls.detailCalls, detailsBefore);
        },
      );
    }

    group('returning a handoff', () {
      late FakeProcessingRepository jobs;
      late ProviderContainer withJobs;

      setUp(() async {
        jobs = FakeProcessingRepository()
          ..jobs['j1'] = Processing.fromJson({
            'id': 'j1',
            'rollId': 'a',
            'type': 'develop',
            'process': 'C-41',
            'sentAt': '2026-11-01',
            'isOpen': true,
          });
        withJobs = ProviderContainer(
          overrides: [
            rollRepositoryProvider.overrideWithValue(rolls),
            processingRepositoryProvider.overrideWithValue(jobs),
          ],
        );
        addTearDown(withJobs.dispose);
        final subs = [
          withJobs.listen(rollsProvider(RollFilter.empty), (_, _) {}),
          withJobs.listen(rollDetailProvider('a'), (_, _) {}),
          withJobs.listen(processingProvider('j1'), (_, _) {}),
        ];
        addTearDown(() {
          for (final sub in subs) {
            sub.close();
          }
        });
        await withJobs.read(processingProvider('j1').future);
      });

      Future<void> reread() async {
        await withJobs.read(rollsProvider(RollFilter.empty).future);
        await withJobs.read(rollDetailProvider('a').future);
        await withJobs.read(processingProvider('j1').future);
      }

      test(
        'sends once by handoff id, then refreshes roll, list and job',
        () async {
          await reread();
          final before = (rolls.listCalls, rolls.detailCalls, jobs.jobReads);

          await withJobs
              .read(rollActionsProvider)
              .returnHandoff('h1', DateTime(2026, 11, 5));
          await reread();

          expect(rolls.calls, ['returned:h1:2026-11-05']);
          expect(rolls.listCalls, before.$1 + 1);
          expect(rolls.detailCalls, before.$2 + 1);
          expect(jobs.jobReads, before.$3 + 1);
        },
      );

      test('a failed return throws and refreshes nothing', () async {
        await reread();
        final before = (rolls.listCalls, rolls.detailCalls, jobs.jobReads);
        rolls.writeError = ApiException(
          0,
          'network',
          'Cannot reach the server.',
        );

        await expectLater(
          withJobs
              .read(rollActionsProvider)
              .returnHandoff('h1', DateTime(2026, 11, 5)),
          throwsA(
            isA<ApiException>().having(
              (error) => error.isNetwork,
              'isNetwork',
              true,
            ),
          ),
        );
        await Future<void>.delayed(Duration.zero);

        expect(rolls.calls, isEmpty);
        expect((rolls.listCalls, rolls.detailCalls, jobs.jobReads), before);
      });
    });
  });
}

/// A roll's details as the server answers them, for [detailActions].
RollDetail _detail({
  String? stage,
  String? stageDetail,
  String status = 'at_lab',
  bool negativesAtLab = false,
  String? openHandoffId,
  bool? needsScan = false,
  Map<String, dynamic>? plan,
  List<Map<String, dynamic>> jobs = const [],
}) => RollDetail.fromJson({
  'roll': {
    'id': 'r1',
    'filmStockId': 's1',
    'stockBrand': 'Kodak',
    'stockName': 'Gold',
    'format': 135,
    'exposures': 36,
    'status': status,
    'negativesAtLab': negativesAtLab,
    'stage': ?stage,
    'stageDetail': ?stageDetail,
    'openHandoffId': ?openHandoffId,
    'needsScan': ?needsScan,
    'plan': ?plan,
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

Map<String, dynamic> _job(
  String id, {
  String type = 'develop',
  String? labId = 'lab1',
  String? developedAt,
  String? negativesReturnedAt,
  bool isOpen = true,
}) => {
  'id': id,
  'rollId': 'r1',
  'labId': labId,
  'type': type,
  'process': 'C-41',
  'sentAt': '2026-10-02',
  'developedAt': developedAt,
  'negativesReturnedAt': negativesReturnedAt,
  'isOpen': isOpen,
};

void detailActionTests() {
  group('detailActions', () {
    test(
      'in stock loads; in camera logs frames and keeps Finish in the menu',
      () {
        expect(
          detailActions(_detail(stage: 'in_stock', status: 'in_stock')).primary,
          DetailAction.loadRoll,
        );
        final inCamera = detailActions(
          _detail(stage: 'in_camera', status: 'in_camera'),
        );
        expect(inCamera.primary, DetailAction.logFrame);
        // The plan and the scan mark can be set ahead, while still shooting.
        expect(inCamera.menu, [
          DetailAction.finish,
          DetailAction.changePlan,
          DetailAction.markNeedsScan,
        ]);
      },
    );

    group('done shooting', () {
      RollDetail done({String? developBy, bool atLab = false}) => _detail(
        stage: 'done_shooting',
        status: 'done_shooting',
        negativesAtLab: atLab,
        plan: {'developBy': ?developBy},
      );

      test('the plan picks home develop, lab, or the plan sheet', () {
        expect(
          detailActions(done(developBy: 'self')).primary,
          DetailAction.startHomeDevelop,
        );
        expect(
          detailActions(done(developBy: 'lab')).primary,
          DetailAction.handToLab,
        );
        expect(detailActions(done()).primary, DetailAction.choosePlan);
      });

      test('a lab that still holds the film blocks a home develop', () {
        final actions = detailActions(done(developBy: 'self', atLab: true));
        expect(actions.primary, isNot(DetailAction.startHomeDevelop));
        expect(actions.menu, isNot(contains(DetailAction.startHomeDevelop)));
        expect(actions.menu, isNot(contains(DetailAction.markDeveloped)));
        // No handoff and no job that holds it: nothing to open, so refresh.
        expect(actions.primary, DetailAction.refresh);
      });

      test('with no job, the menu also records a develop done at home', () {
        expect(
          detailActions(done(developBy: 'lab')).menu,
          containsAll([
            DetailAction.startHomeDevelop,
            DetailAction.markDeveloped,
          ]),
        );
      });
    });

    group('processing', () {
      RollDetail processing(
        String detail, {
        List<Map<String, dynamic>> jobs = const [],
        bool atLab = false,
        String? openHandoffId,
      }) => _detail(
        stage: 'processing',
        stageDetail: detail,
        negativesAtLab: atLab,
        openHandoffId: openHandoffId,
        jobs: jobs,
      );

      test('developing: Mark developed while the develop job has no date', () {
        for (final detail in ['lab_developing', 'home_developing']) {
          expect(
            detailActions(processing(detail, jobs: [_job('j1')])).primary,
            DetailAction.markDeveloped,
            reason: detail,
          );
        }
      });

      test('developing without a job to mark opens the develop job', () {
        final actions = detailActions(
          processing(
            'lab_developing',
            jobs: [_job('j1', developedAt: '2026-10-03')],
          ),
        );
        expect(actions.primary, DetailAction.openJob);
        expect(actions.jobId, 'j1');
      });

      test('scanning, rescanning and printing open the one current job', () {
        for (final (detail, type) in [
          ('lab_scanning', 'scan'),
          ('home_scanning', 'develop_scan'),
          ('rescanning', 'scan'),
          ('printing', 'print'),
        ]) {
          final actions = detailActions(
            processing(detail, jobs: [_job('j2', type: type)]),
          );
          expect(actions.primary, DetailAction.openJob, reason: detail);
          expect(actions.jobId, 'j2', reason: detail);
        }
      });

      test('several fitting jobs: pick one in the history, never guess', () {
        final actions = detailActions(
          processing(
            'lab_scanning',
            jobs: [
              _job('j1', type: 'scan'),
              _job('j2', type: 'scan'),
            ],
          ),
        );
        expect(actions.primary, DetailAction.pickJob);
        expect(actions.jobId, isNull);
      });

      test('waiting: home scan, lab scan, or the scan place sheet', () {
        expect(
          detailActions(processing('waiting_home_scan')).primary,
          DetailAction.startHomeScan,
        );
        expect(
          detailActions(processing('waiting_lab_scan')).primary,
          DetailAction.handToLab,
        );
        expect(
          detailActions(processing('waiting_scan')).primary,
          DetailAction.chooseScanPlace,
        );
      });

      test('waiting while a lab holds the film: return it first', () {
        final byHandoff = detailActions(
          processing('waiting_home_scan', atLab: true, openHandoffId: 'h1'),
        );
        expect(byHandoff.primary, DetailAction.returnHandoff);
        // No home scan while the negatives are at the lab; a scan next at
        // the same lab stays possible.
        expect(byHandoff.menu, isNot(contains(DetailAction.startHomeScan)));
        expect(byHandoff.menu, contains(DetailAction.handToLab));

        final legacy = detailActions(
          processing(
            'waiting_lab_scan',
            atLab: true,
            jobs: [_job('j1', developedAt: '2026-10-03')],
          ),
        );
        expect(legacy.primary, DetailAction.returnJob);
        expect(legacy.jobId, 'j1');
      });
    });

    group('completed', () {
      RollDetail completed({
        bool needsScan = false,
        String? scanBy,
        bool atLab = false,
        String? openHandoffId,
        List<Map<String, dynamic>> jobs = const [],
      }) => _detail(
        stage: 'completed',
        status: 'scanned',
        needsScan: needsScan,
        plan: {'scanBy': ?scanBy},
        negativesAtLab: atLab,
        openHandoffId: openHandoffId,
        jobs: jobs,
      );

      test(
        'an open handoff is returned first, even when marked for a scan',
        () {
          final actions = detailActions(
            completed(
              needsScan: true,
              scanBy: 'self',
              atLab: true,
              openHandoffId: 'h1',
            ),
          );
          expect(actions.primary, DetailAction.returnHandoff);
          expect(actions.menu, isNot(contains(DetailAction.returnHandoff)));
          expect(actions.menu, contains(DetailAction.unmarkNeedsScan));
        },
      );

      test('legacy Negatives at lab opens the job that holds them', () {
        final actions = detailActions(
          completed(
            atLab: true,
            jobs: [
              _job('home', type: 'scan', labId: null),
              _job('back', type: 'scan', negativesReturnedAt: '2026-10-05'),
              _job('held', type: 'scan'),
            ],
          ),
        );
        expect(actions.primary, DetailAction.returnJob);
        expect(actions.jobId, 'held');
      });

      test('a closed lab scan job still holds the negatives', () {
        final job = _job('j1', type: 'scan', isOpen: false)
          ..['scansReceivedAt'] = '2026-10-04';
        final actions = detailActions(completed(atLab: true, jobs: [job]));
        expect(actions.primary, DetailAction.returnJob);
        expect(actions.jobId, 'j1');
      });

      test('two lab jobs that hold the negatives: pick one, never guess', () {
        final actions = detailActions(
          completed(
            atLab: true,
            jobs: [
              _job('j1', type: 'scan'),
              _job('j2', type: 'print'),
            ],
          ),
        );
        expect(actions.primary, DetailAction.pickJob);
        expect(actions.jobId, isNull);
      });

      test('home and marked for a scan: the plan picks where', () {
        expect(
          detailActions(completed(needsScan: true, scanBy: 'self')).primary,
          DetailAction.startHomeScan,
        );
        expect(
          detailActions(completed(needsScan: true, scanBy: 'lab')).primary,
          DetailAction.handToLab,
        );
        expect(
          detailActions(completed(needsScan: true)).primary,
          DetailAction.chooseScanPlace,
        );
      });

      test(
        'nothing waiting: no main button, the plan and the mark in the menu',
        () {
          final actions = detailActions(completed());
          expect(actions.primary, isNull);
          expect(actions.menu, [
            DetailAction.changePlan,
            DetailAction.markNeedsScan,
          ]);
        },
      );
    });

    test('a roll cached without its stage only offers a refresh', () {
      final actions = detailActions(
        _detail(status: 'developed', needsScan: null),
      );
      expect(actions.primary, DetailAction.refresh);
      expect(actions.menu, isEmpty);
    });
  });
}
