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
  });
}
