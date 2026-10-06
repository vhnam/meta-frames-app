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
    final counts = container.read(rollStatusCountsProvider)!;
    expect(counts[null], 3);
    expect(counts[RollStatus.inCamera], 2);
    expect(counts[RollStatus.scanned], 0);
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
            'boxIso': 200,
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

  test('clearing filters keeps the selected status', () {
    container.read(rollsViewModelProvider.notifier)
      ..selectStatus(RollStatus.scanned)
      ..setFormat(120)
      ..clearFilters();
    final state = container.read(rollsViewModelProvider);
    expect(state.filtered, isFalse);
    expect(state.status, RollStatus.scanned);
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
