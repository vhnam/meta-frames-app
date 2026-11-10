import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../domain/models/expiry.dart';
import '../../../domain/models/models.dart';
import '../../../domain/models/roll_filter.dart';
import '../../../domain/models/roll_stage.dart';
import '../../../providers.dart';

/// State of the Rolls tab: the server-side filter, the labels shown for the
/// picked filter values, and the client-side narrowing: a status chip or the
/// Negatives at lab chip, and a format.
class RollsState {
  const RollsState({
    this.filter = RollFilter.empty,
    this.stockLabel,
    this.cameraLabel,
    this.lensLabel,
    this.status,
    this.negativesAtLab = false,
    this.format,
  });
  final RollFilter filter;
  final String? stockLabel, cameraLabel, lensLabel;

  /// One of the six business statuses. Null with [negativesAtLab] false is the
  /// "All" chip.
  final RollStatus? status;

  /// Rolls whose negatives are still at a lab, whatever their status: a roll
  /// already developed or scanned can still have its negatives at the lab.
  final bool negativesAtLab;

  /// Film format, picked from the formats of the listed rolls. Null is any.
  final int? format;

  /// Whether the server-side filter is set. The status, negatives and format
  /// pills show their own selection.
  bool get filtered => !filter.isEmpty;

  RollsState _with({
    RollFilter? filter,
    (String?,)? stockLabel,
    (String?,)? cameraLabel,
    (String?,)? lensLabel,
    (RollStatus?,)? status,
    bool? negativesAtLab,
    (int?,)? format,
  }) => RollsState(
    filter: filter ?? this.filter,
    stockLabel: stockLabel == null ? this.stockLabel : stockLabel.$1,
    cameraLabel: cameraLabel == null ? this.cameraLabel : cameraLabel.$1,
    lensLabel: lensLabel == null ? this.lensLabel : lensLabel.$1,
    status: status == null ? this.status : status.$1,
    negativesAtLab: negativesAtLab ?? this.negativesAtLab,
    format: format == null ? this.format : format.$1,
  );
}

class RollsViewModel extends Notifier<RollsState> {
  @override
  RollsState build() => const RollsState();

  /// A status chip, or "All" for null.
  void selectStatus(RollStatus? s) =>
      state = state._with(status: (s,), negativesAtLab: false);

  void selectNegativesAtLab() =>
      state = state._with(status: (null,), negativesAtLab: true);

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

  /// Clears every filter but keeps the selected chip.
  void clearFilters() => state = RollsState(
    status: state.status,
    negativesAtLab: state.negativesAtLab,
  );
}

final rollsViewModelProvider = NotifierProvider<RollsViewModel, RollsState>(
  RollsViewModel.new,
);

/// Rolls matching the server-side filter and the picked format: what the chips
/// count and narrow.
final _formatRollsProvider =
    Provider.autoDispose<AsyncValue<List<RollSummary>>>((ref) {
      final format = ref.watch(rollsViewModelProvider.select((s) => s.format));
      final rolls = ref.watch(
        rollsProvider(
          ref.watch(rollsViewModelProvider.select((s) => s.filter)),
        ),
      );
      if (format == null) return rolls;
      return rolls.whenData(
        (all) => all.where((r) => r.format == format).toList(),
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

/// The rolls on screen: the format-narrowed list, narrowed again to the
/// selected chip. Film in stock is listed soonest expiry first, so film to use
/// up comes first; every other list is newest start date first, rolls not
/// started last.
final visibleRollsProvider =
    Provider.autoDispose<AsyncValue<List<RollSummary>>>((ref) {
      final state = ref.watch(rollsViewModelProvider);
      final status = state.status;
      return ref.watch(_formatRollsProvider).whenData((all) {
        final shown = [
          for (final r in all)
            if (state.negativesAtLab
                ? r.negativesAtLab
                : status == null || inStatusChip(r, status))
              r,
        ];
        if (status == RollStatus.inStock) {
          return _sortKeepingServerOrder(
            shown,
            (a, b) => expiryKey(a.expiry).compareTo(expiryKey(b.expiry)),
          );
        }
        return _sortKeepingServerOrder(shown, (a, b) {
          final (x, y) = (a.startedAt, b.startedAt);
          if (x != null && y != null) return y.compareTo(x);
          return (x == null ? 1 : 0) - (y == null ? 1 : 0);
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

/// How many rolls each chip would show for the current filter and format.
typedef RollCounts = ({
  int all,
  Map<RollStatus, int> byStatus,
  int negativesAtLab,
});

/// Roll counts per chip. Null while loading.
final rollCountsProvider = Provider.autoDispose<RollCounts?>((ref) {
  final all = ref.watch(_formatRollsProvider).value;
  if (all == null) return null;
  return (
    all: all.length,
    byStatus: {
      for (final s in RollStatus.values)
        s: all.where((r) => inStatusChip(r, s)).length,
    },
    negativesAtLab: all.where((r) => r.negativesAtLab).length,
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
