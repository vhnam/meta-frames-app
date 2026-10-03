import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../domain/models/models.dart';
import '../../../domain/models/roll_filter.dart';
import '../../../providers.dart';

/// Active cameras with a roll in them.
final loadedCamerasProvider = Provider.autoDispose<AsyncValue<List<Camera>>>(
  (ref) => ref
      .watch(camerasProvider)
      .whenData(
        (all) => all.where((c) => c.isActive && c.loadedRoll != null).toList(),
      ),
);

/// Finished rolls waiting to go to a lab.
final readyRollsProvider = Provider.autoDispose<AsyncValue<List<RollSummary>>>(
  (ref) => ref
      .watch(rollsProvider(RollFilter.empty))
      .whenData(
        (all) => all.where((r) => r.status == RollStatus.doneShooting).toList(),
      ),
);

/// Counts in the home strip. Null while the source is loading.
typedef HomeCounters = ({int? loaded, int? ready, int? atLab, int? expiring});

final homeCountersProvider = Provider.autoDispose<HomeCounters>(
  (ref) => (
    loaded: ref.watch(loadedCamerasProvider).value?.length,
    ready: ref.watch(readyRollsProvider).value?.length,
    atLab: ref.watch(negativesAtLabProvider).value?.length,
    expiring: ref.watch(expiryProvider).value?.expiring.length,
  ),
);

/// No cameras and no rolls yet: show the welcome card instead.
final isNewUserProvider = Provider.autoDispose<bool>((ref) {
  final cams = ref.watch(camerasProvider).value;
  final rolls = ref.watch(rollsProvider(RollFilter.empty)).value;
  return (cams?.isEmpty ?? false) && (rolls?.isEmpty ?? false);
});

final stocksByIdProvider = Provider.autoDispose<Map<String, FilmStock>>(
  (ref) => {
    for (final s in ref.watch(stocksProvider).value ?? const <FilmStock>[])
      s.id: s,
  },
);

/// Pull to refresh: reloads every list the home screen shows.
Future<void> refreshHome(WidgetRef ref) async {
  await Future.wait([
    ref.refresh(camerasProvider.future),
    ref.refresh(rollsProvider(RollFilter.empty).future),
    ref.refresh(negativesAtLabProvider.future),
    ref.refresh(expiryProvider.future),
    ref.refresh(stocksProvider.future),
  ]);
}
