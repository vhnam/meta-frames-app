import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:meta_frames/domain/models/models.dart';
import 'package:meta_frames/domain/models/roll_filter.dart';
import 'package:meta_frames/providers.dart';
import 'package:meta_frames/ui/rolls/view_models/rolls_view_model.dart';

import '../../testing/fakes.dart';

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

  test('status chip narrows the list client-side without refetching', () async {
    expect(await visibleIds(), ['a', 'b', 'c']);
    final before = rolls.listCalls;

    container
        .read(rollsViewModelProvider.notifier)
        .selectStatus(RollStatus.inCamera);
    expect(await visibleIds(), ['b', 'c']);
    expect(rolls.listCalls, before);
  });

  test('status counts cover every chip', () async {
    await visibleIds();
    final counts = container.read(rollCountsProvider)!;
    expect(counts.all, 3);
    expect(counts.byStatus[RollStatus.inCamera], 2);
    expect(counts.byStatus[RollStatus.scanned], 0);
    expect(counts.byStatus.keys, RollStatus.values);
  });

  group('with rolls in every status', () {
    setUp(() {
      rolls.all = [
        roll('stock', format: 120),
        roll('camera', status: 'in_camera'),
        roll('done', status: 'done_shooting'),
        roll('lab', status: 'at_lab', negativesAtLab: true),
        roll('dev', status: 'developed', negativesAtLab: true),
        roll('scan', status: 'scanned', negativesAtLab: true, format: 120),
        roll('home', status: 'scanned'),
      ];
    });

    test('every status keeps its own chip, in camera included', () async {
      await visibleIds();
      final vm = container.read(rollsViewModelProvider.notifier);
      final shown = <String>[];
      for (final s in RollStatus.values) {
        vm.selectStatus(s);
        shown.addAll(await visibleIds());
      }
      // Each roll is in exactly one status chip.
      expect(shown..sort(), [
        'camera',
        'dev',
        'done',
        'home',
        'lab',
        'scan',
        'stock',
      ]);
      vm.selectStatus(RollStatus.inCamera);
      expect(await visibleIds(), ['camera']);
    });

    test('negatives at lab finds developed and scanned rolls too', () async {
      await visibleIds();
      container.read(rollsViewModelProvider.notifier).selectNegativesAtLab();
      expect(await visibleIds(), ['lab', 'dev', 'scan']);
      expect(container.read(rollCountsProvider)!.negativesAtLab, 3);
      expect(container.read(rollsViewModelProvider).status, isNull);

      container
          .read(rollsViewModelProvider.notifier)
          .selectStatus(RollStatus.scanned);
      expect(container.read(rollsViewModelProvider).negativesAtLab, isFalse);
      expect(await visibleIds(), ['scan', 'home']);
    });

    test('format narrows on the client and the counts follow', () async {
      await visibleIds();
      final before = rolls.listCalls;
      expect(container.read(rollFormatsProvider), [120, 135]);

      container.read(rollsViewModelProvider.notifier).setFormat(120);
      expect(await visibleIds(), ['stock', 'scan']);
      final counts = container.read(rollCountsProvider)!;
      expect(counts.all, 2);
      expect(counts.byStatus[RollStatus.scanned], 1);
      expect(counts.negativesAtLab, 1);
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
        .selectStatus(RollStatus.inStock);
    // A year without a month expires at the end of that year.
    expect(await visibleIds(), ['soon', 'year', 'late', 'none', 'none2']);
  });

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

  test('clearing filters keeps the selected chip', () {
    container.read(rollsViewModelProvider.notifier)
      ..selectStatus(RollStatus.scanned)
      ..setFormat(120)
      ..clearFilters();
    final state = container.read(rollsViewModelProvider);
    expect(state.filtered, isFalse);
    expect(state.format, isNull);
    expect(state.status, RollStatus.scanned);

    container.read(rollsViewModelProvider.notifier)
      ..selectNegativesAtLab()
      ..clearFilters();
    expect(container.read(rollsViewModelProvider).negativesAtLab, isTrue);
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
