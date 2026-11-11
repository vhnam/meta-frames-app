import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../domain/models/expiry.dart';
import '../../../domain/models/models.dart';
import '../../../domain/models/roll_filter.dart';
import '../../../providers.dart';

/// State of the Rolls tab: the server-side filter, the labels shown for the
/// picked filter values, and the client-side narrowing: a stage chip, and the
/// At lab, Needs scan and format filters shared by every chip.
class RollsState {
  const RollsState({
    this.filter = RollFilter.empty,
    this.stockLabel,
    this.cameraLabel,
    this.lensLabel,
    this.stage,
    this.atLab = false,
    this.needsScan = false,
    this.format,
  });
  final RollFilter filter;
  final String? stockLabel, cameraLabel, lensLabel;

  /// The stage chip. Null is "All", the only chip that lists a roll cached
  /// without a stage.
  final RollLifecycleStage? stage;

  /// Rolls a lab still holds, whatever their stage: a completed roll can still
  /// have its negatives at the lab.
  final bool atLab;

  /// Rolls marked for a scan that has not started.
  final bool needsScan;

  /// Film format, picked from the formats of the listed rolls. Null is any.
  final int? format;

  /// Whether a filter in the filter sheet is set. The stage chips and format
  /// pills show their own selection.
  bool get filtered => !filter.isEmpty || atLab || needsScan;

  RollsState _with({
    RollFilter? filter,
    (String?,)? stockLabel,
    (String?,)? cameraLabel,
    (String?,)? lensLabel,
    (RollLifecycleStage?,)? stage,
    bool? atLab,
    bool? needsScan,
    (int?,)? format,
  }) => RollsState(
    filter: filter ?? this.filter,
    stockLabel: stockLabel == null ? this.stockLabel : stockLabel.$1,
    cameraLabel: cameraLabel == null ? this.cameraLabel : cameraLabel.$1,
    lensLabel: lensLabel == null ? this.lensLabel : lensLabel.$1,
    stage: stage == null ? this.stage : stage.$1,
    atLab: atLab ?? this.atLab,
    needsScan: needsScan ?? this.needsScan,
    format: format == null ? this.format : format.$1,
  );
}

class RollsViewModel extends Notifier<RollsState> {
  @override
  RollsState build() => const RollsState();

  /// A stage chip, or "All" for null. The filters stay.
  void selectStage(RollLifecycleStage? stage) =>
      state = state._with(stage: (stage,));

  void setAtLab(bool on) => state = state._with(atLab: on);
  void setNeedsScan(bool on) => state = state._with(needsScan: on);

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

  /// Narrows the loaded list on the client, so picking a format needs no call.
  void setFormat(int? v) => state = state._with(format: (v,));
  void setFrom(DateTime? d) =>
      state = state._with(filter: state.filter.withFrom(d));
  void setTo(DateTime? d) =>
      state = state._with(filter: state.filter.withTo(d));

  /// Clears every filter but keeps the selected stage chip.
  void clearFilters() => state = RollsState(stage: state.stage);
}

final rollsViewModelProvider = NotifierProvider<RollsViewModel, RollsState>(
  RollsViewModel.new,
);

/// Rolls matching the server-side filter and the shared client filters
/// (format, At lab, Needs scan): what the stage chips count and narrow.
final _filteredRollsProvider =
    Provider.autoDispose<AsyncValue<List<RollSummary>>>((ref) {
      final state = ref.watch(rollsViewModelProvider);
      final rolls = ref.watch(rollsProvider(state.filter));
      return rolls.whenData(
        (all) => [
          for (final roll in all)
            if ((state.format == null || roll.format == state.format) &&
                (!state.atLab || roll.negativesAtLab) &&
                // An older cache without needsScan does not count as marked.
                (!state.needsScan || roll.needsScan == true))
              roll,
        ],
      );
    });

/// Formats of the rolls under the server-side filter, smallest first, to pick
/// from. Empty while loading.
final rollFormatsProvider = Provider.autoDispose<List<int>>((ref) {
  final all = ref
      .watch(
        rollsProvider(
          ref.watch(rollsViewModelProvider.select((s) => s.filter)),
        ),
      )
      .value;
  return ({for (final r in all ?? const <RollSummary>[]) r.format}.toList()
    ..sort());
});

/// The rolls on screen: the filtered list, narrowed again to the selected
/// stage. Film in stock is listed soonest expiry first, so film to use up
/// comes first; every other list is newest start date first, rolls not
/// started last.
final visibleRollsProvider =
    Provider.autoDispose<AsyncValue<List<RollSummary>>>((ref) {
      final stage = ref.watch(
        rollsViewModelProvider.select((rolls) => rolls.stage),
      );
      return ref.watch(_filteredRollsProvider).whenData((all) {
        final shown = [
          for (final roll in all)
            if (stage == null || roll.stage == stage) roll,
        ];
        if (stage == RollLifecycleStage.inStock) {
          return _sortKeepingServerOrder(
            shown,
            (first, second) =>
                expiryKey(first.expiry).compareTo(expiryKey(second.expiry)),
          );
        }
        return _sortKeepingServerOrder(shown, (first, second) {
          final (firstStart, secondStart) = (first.startedAt, second.startedAt);
          if (firstStart != null && secondStart != null) {
            return secondStart.compareTo(firstStart);
          }
          return (firstStart == null ? 1 : 0) - (secondStart == null ? 1 : 0);
        });
      });
    });

/// Sorts [rolls] in place by [compare]. List.sort is not stable: the index
/// keeps the server order among equal rolls.
List<RollSummary> _sortKeepingServerOrder(
  List<RollSummary> rolls,
  int Function(RollSummary a, RollSummary b) compare,
) {
  final order = {for (final (i, r) in rolls.indexed) r.id: i};
  return rolls..sort((a, b) {
    final by = compare(a, b);
    return by != 0 ? by : order[a.id]!.compareTo(order[b.id]!);
  });
}

/// How many rolls each chip would show for the current filters. A roll
/// cached without a stage is only in [all], so the stages can add up to less.
typedef RollCounts = ({int all, Map<RollLifecycleStage, int> byStage});

/// Roll counts per chip. Null while loading.
final rollCountsProvider = Provider.autoDispose<RollCounts?>((ref) {
  final all = ref.watch(_filteredRollsProvider).value;
  if (all == null) return null;
  return (
    all: all.length,
    byStage: {
      for (final stage in RollLifecycleStage.values)
        stage: all.where((roll) => roll.stage == stage).length,
    },
  );
});

/// Process of each stock by id, for tinting roll cards.
final stockProcessByIdProvider = Provider.autoDispose<Map<String, Process>>(
  (ref) => {
    for (final e in ref.watch(stocksByIdProvider).entries)
      e.key: e.value.process,
  },
);

final expiringRollIdsProvider = Provider.autoDispose<Set<String>>(
  (ref) => {
    for (final e
        in ref.watch(expiryProvider).value?.expiring ?? const <ExpiryRoll>[])
      e.roll.id,
  },
);
