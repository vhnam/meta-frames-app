import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../domain/models/models.dart';
import '../../../domain/models/roll_filter.dart';
import '../../../providers.dart';

/// State of the Rolls tab: the server-side filter, the labels shown for the
/// picked filter values, and the selected status chip (applied client-side).
class RollsState {
  const RollsState({
    this.filter = RollFilter.empty,
    this.stockLabel,
    this.cameraLabel,
    this.lensLabel,
    this.status,
  });
  final RollFilter filter;
  final String? stockLabel, cameraLabel, lensLabel;

  /// Null is the "All" chip.
  final RollStatus? status;

  bool get filtered => !filter.isEmpty;

  RollsState _with({
    RollFilter? filter,
    (String?,)? stockLabel,
    (String?,)? cameraLabel,
    (String?,)? lensLabel,
    (RollStatus?,)? status,
  }) => RollsState(
    filter: filter ?? this.filter,
    stockLabel: stockLabel == null ? this.stockLabel : stockLabel.$1,
    cameraLabel: cameraLabel == null ? this.cameraLabel : cameraLabel.$1,
    lensLabel: lensLabel == null ? this.lensLabel : lensLabel.$1,
    status: status == null ? this.status : status.$1,
  );
}

class RollsViewModel extends Notifier<RollsState> {
  @override
  RollsState build() => const RollsState();

  void selectStatus(RollStatus? s) => state = state._with(status: (s,));

  void setStock(FilmStock? s) => state = state._with(
    filter: state.filter.withStock(s?.id),
    stockLabel: (s?.label,),
  );
  void setCamera(Camera? c) => state = state._with(
    filter: state.filter.withCamera(c?.id),
    cameraLabel: (c?.name,),
  );
  void setLens(Lens? l) => state = state._with(
    filter: state.filter.withLens(l?.id),
    lensLabel: (l?.name,),
  );
  void setFormat(int? v) =>
      state = state._with(filter: state.filter.withFormat(v));
  void setFrom(DateTime? d) =>
      state = state._with(filter: state.filter.withFrom(d));
  void setTo(DateTime? d) =>
      state = state._with(filter: state.filter.withTo(d));

  /// Clears every filter but keeps the selected status chip.
  void clearFilters() => state = RollsState(status: state.status);
}

final rollsViewModelProvider = NotifierProvider<RollsViewModel, RollsState>(
  RollsViewModel.new,
);

/// Rolls matching the current filter, narrowed to the selected status chip.
final visibleRollsProvider =
    Provider.autoDispose<AsyncValue<List<RollSummary>>>((ref) {
      final status = ref.watch(rollsViewModelProvider.select((s) => s.status));
      final rolls = ref.watch(
        rollsProvider(
          ref.watch(rollsViewModelProvider.select((s) => s.filter)),
        ),
      );
      if (status == null) return rolls;
      return rolls.whenData(
        (all) => all.where((r) => r.status == status).toList(),
      );
    });

/// Roll counts per status chip for the current filter. Null while loading.
final rollStatusCountsProvider = Provider.autoDispose<Map<RollStatus?, int>?>((
  ref,
) {
  final all = ref
      .watch(
        rollsProvider(
          ref.watch(rollsViewModelProvider.select((s) => s.filter)),
        ),
      )
      .value;
  if (all == null) return null;
  return {
    null: all.length,
    for (final s in RollStatus.values)
      s: all.where((r) => r.status == s).length,
  };
});

/// Process of each stock by id, for tinting roll cards.
final stockProcessByIdProvider = Provider.autoDispose<Map<String, Process>>(
  (ref) => {
    for (final s in ref.watch(stocksProvider).value ?? const <FilmStock>[])
      s.id: s.process,
  },
);

final expiringRollIdsProvider = Provider.autoDispose<Set<String>>(
  (ref) => {
    for (final e
        in ref.watch(expiryProvider).value?.expiring ?? const <ExpiryRoll>[])
      e.roll.id,
  },
);
