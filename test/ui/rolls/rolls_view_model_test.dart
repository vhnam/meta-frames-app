import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:meta_frames/domain/models/models.dart';
import 'package:meta_frames/domain/models/roll_filter.dart';
import 'package:meta_frames/providers.dart';
import 'package:meta_frames/ui/rolls/view_models/rolls_view_model.dart';

import '../../testing/fakes.dart';

/// A roll with a server stage. The shared `roll` fixture has no stage field,
/// so it stands for a summary cached by an older server.
RollSummary staged(
  String id,
  String status,
  String stage, {
  bool negativesAtLab = false,
  bool? needsScan,
  int format = 135,
  String? startedAt,
}) => RollSummary.fromJson({
  'id': id,
  'filmStockId': 's1',
  'stockBrand': 'Kodak',
  'stockName': 'Gold',
  'format': format,
  'exposures': 36,
  'status': status,
  'negativesAtLab': negativesAtLab,
  'stage': stage,
  'needsScan': ?needsScan,
  'startedAt': ?startedAt,
});

void main() {
  late FakeRollRepository rolls;
  late ProviderContainer container;

  setUp(() {
    rolls = FakeRollRepository([
      roll('a'),
      roll('b', status: 'in_camera'),
      roll('c', status: 'in_camera', stockId: 's2'),
    ]);
    container = ProviderContainer(
      overrides: [rollRepositoryProvider.overrideWithValue(rolls)],
    );
    addTearDown(container.dispose);
  });

  /// Waits for the list to load, then returns the visible roll ids.
  Future<List<String>> visibleIds() async {
    await container.read(
      rollsProvider(container.read(rollsViewModelProvider).filter).future,
    );
    return container
        .read(visibleRollsProvider)
        .requireValue
        .map((r) => r.id)
        .toList();
  }

  test('stage chip narrows the list client-side without refetching', () async {
    expect(await visibleIds(), ['a', 'b', 'c']);
    final before = rolls.listCalls;

    container
        .read(rollsViewModelProvider.notifier)
        .selectStage(RollLifecycleStage.inCamera);
    expect(await visibleIds(), ['b', 'c']);
    expect(rolls.listCalls, before);
  });

  test('stage counts cover every chip', () async {
    await visibleIds();
    final counts = container.read(rollCountsProvider)!;
    expect(counts.all, 3);
    expect(counts.byStage[RollLifecycleStage.inCamera], 2);
    expect(counts.byStage[RollLifecycleStage.completed], 0);
    expect(counts.byStage.keys, RollLifecycleStage.values);
  });

  group('with rolls in every stage', () {
    setUp(() {
      rolls.all = [
        roll('stock', format: 120),
        roll('camera', status: 'in_camera'),
        roll('done', status: 'done_shooting'),
        staged('lab', 'at_lab', 'processing', negativesAtLab: true),
        staged(
          'heldDone',
          'developed',
          'completed',
          negativesAtLab: true,
          format: 120,
        ),
        staged('marked', 'scanned', 'completed', needsScan: true),
        staged('back', 'scanned', 'completed', needsScan: false),
        // Cached by an older server: no stage, no needsScan.
        roll('old', status: 'scanned', negativesAtLab: true),
      ];
    });

    test(
      'each roll is under one stage chip; an old roll only in All',
      () async {
        await visibleIds();
        final vm = container.read(rollsViewModelProvider.notifier);
        final shown = <String>[];
        for (final stage in RollLifecycleStage.values) {
          vm.selectStage(stage);
          shown.addAll(await visibleIds());
        }
        expect(shown..sort(), [
          'back',
          'camera',
          'done',
          'heldDone',
          'lab',
          'marked',
          'stock',
        ]);
        final counts = container.read(rollCountsProvider)!;
        expect(counts.all, 8);
        expect(
          counts.byStage.values.fold<int>(0, (sum, count) => sum + count),
          7,
        );
      },
    );

    test('At lab combines with Completed and the counts follow', () async {
      await visibleIds();
      final before = rolls.listCalls;
      container.read(rollsViewModelProvider.notifier)
        ..setAtLab(true)
        ..selectStage(RollLifecycleStage.completed);
      expect(await visibleIds(), ['heldDone']);
      final counts = container.read(rollCountsProvider)!;
      expect(counts.all, 3, reason: 'lab, heldDone and the old roll');
      expect(counts.byStage[RollLifecycleStage.processing], 1);
      expect(counts.byStage[RollLifecycleStage.completed], 1);
      expect(rolls.listCalls, before);
    });

    test('Needs scan counts only rolls marked by the server', () async {
      await visibleIds();
      container.read(rollsViewModelProvider.notifier).setNeedsScan(true);
      expect(await visibleIds(), ['marked']);
      expect(container.read(rollCountsProvider)!.all, 1);
    });

    test('changing the stage keeps the filters', () async {
      await visibleIds();
      final vm = container.read(rollsViewModelProvider.notifier)
        ..setAtLab(true)
        ..setFormat(120)
        ..selectStage(RollLifecycleStage.processing);
      expect(await visibleIds(), isEmpty);
      vm.selectStage(null);
      expect(await visibleIds(), ['heldDone']);
      final state = container.read(rollsViewModelProvider);
      expect(state.atLab, isTrue);
      expect(state.format, 120);
    });

    test('format narrows on the client and the counts follow', () async {
      await visibleIds();
      final before = rolls.listCalls;
      expect(container.read(rollFormatsProvider), [120, 135]);

      container.read(rollsViewModelProvider.notifier).setFormat(120);
      expect(await visibleIds(), ['stock', 'heldDone']);
      final counts = container.read(rollCountsProvider)!;
      expect(counts.all, 2);
      expect(counts.byStage[RollLifecycleStage.completed], 1);
      // The formats to pick from do not shrink to the picked one.
      expect(container.read(rollFormatsProvider), [120, 135]);
      expect(rolls.listCalls, before);
    });
  });

  test('film in stock lists soonest expiry first, unknown last', () async {
    rolls.all = [
      roll('none'),
      roll('late', expiry: {'year': 2031, 'month': 2}),
      roll('year', expiry: {'year': 2030}),
      roll('soon', expiry: {'year': 2030, 'month': 3}),
      roll('none2'),
      roll('used', status: 'scanned', expiry: {'year': 2000}),
    ];
    container
        .read(rollsViewModelProvider.notifier)
        .selectStage(RollLifecycleStage.inStock);
    // A year without a month expires at the end of that year.
    expect(await visibleIds(), ['soon', 'year', 'late', 'none', 'none2']);
  });

  test(
    'lists newest start date first, rolls not started last in server order',
    () async {
      rolls.all = [
        roll('addedLast'),
        staged('old', 'scanned', 'completed', startedAt: '2026-01-05'),
        roll('addedFirst'),
        roll('new', status: 'in_camera', startedAt: '2026-10-01'),
        roll(
          'mid',
          status: 'at_lab',
          startedAt: '2026-05-01',
          negativesAtLab: true,
        ),
        staged(
          'midToo',
          'scanned',
          'completed',
          startedAt: '2026-05-01',
          negativesAtLab: true,
        ),
      ];
      expect(await visibleIds(), [
        'new',
        'mid',
        'midToo',
        'old',
        'addedLast',
        'addedFirst',
      ]);
      final vm = container.read(rollsViewModelProvider.notifier);
      vm.selectStage(RollLifecycleStage.completed);
      expect(await visibleIds(), ['midToo', 'old']);
      vm
        ..selectStage(null)
        ..setAtLab(true);
      expect(await visibleIds(), ['mid', 'midToo']);
    },
  );

  test('a filter change queries the server', () async {
    await visibleIds();
    container
        .read(rollsViewModelProvider.notifier)
        .setStock(
          FilmStock.fromJson({
            'id': 's2',
            'brand': 'Fuji',
            'name': 'C200',
            'type': 'color',
            'boxIso': '200',
            'process': 'C-41',
            'packaging': 'factory',
          }),
        );
    final state = container.read(rollsViewModelProvider);
    expect(state.filter, const RollFilter(stockId: 's2'));
    expect(state.stockLabel, 'Fuji C200');
    expect(state.filtered, isTrue);
    expect(await visibleIds(), ['c']);
  });

  test('clearing filters keeps the selected stage', () {
    container.read(rollsViewModelProvider.notifier)
      ..selectStage(RollLifecycleStage.completed)
      ..setFormat(120)
      ..setAtLab(true)
      ..setNeedsScan(true);
    expect(container.read(rollsViewModelProvider).filtered, isTrue);

    container.read(rollsViewModelProvider.notifier).clearFilters();
    final state = container.read(rollsViewModelProvider);
    expect(state.filtered, isFalse);
    expect(state.format, isNull);
    expect(state.atLab, isFalse);
    expect(state.needsScan, isFalse);
    expect(state.stage, RollLifecycleStage.completed);
  });

  test('RollFilter has value equality', () {
    expect(const RollFilter(format: 120), const RollFilter(format: 120));
    expect(
      const RollFilter(format: 120).hashCode,
      const RollFilter(format: 120).hashCode,
    );
    expect(const RollFilter(format: 120), isNot(RollFilter.empty));
  });
}
