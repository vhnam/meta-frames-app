import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:meta_frames/data/services/api_client.dart';
import 'package:meta_frames/domain/models/models.dart';
import 'package:meta_frames/domain/models/roll_filter.dart';
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

  group('setPlan', () {
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
      rolls.planError = ApiException(0, 'network', 'Cannot reach the server.');

      await expectLater(
        container.read(rollActionsProvider).setPlan('a', const RollPlan()),
        throwsA(isA<ApiException>()),
      );
      await Future<void>.delayed(Duration.zero);

      expect(rolls.calls, isEmpty);
      expect(rolls.listCalls, before);
      expect(rolls.detailCalls, detailsBefore);
    });
  });
}
