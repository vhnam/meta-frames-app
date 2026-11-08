import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../domain/models/models.dart';
import '../../../domain/models/roll_filter.dart';
import '../../../providers.dart';

/// Cameras holding a roll, active or not: a roll in a camera stays on screen
/// until it is finished, so it can always be noted and finished from here.
final loadedCamerasProvider = Provider.autoDispose<AsyncValue<List<Camera>>>(
  (ref) => ref
      .watch(camerasProvider)
      .whenData((all) => all.where((c) => c.loadedRoll != null).toList()),
);

/// Active cameras with nothing in them: where a new roll can be loaded.
final emptyCamerasProvider = Provider.autoDispose<AsyncValue<List<Camera>>>(
  (ref) => ref
      .watch(camerasProvider)
      .whenData(
        (all) => all.where((c) => c.isActive && c.loadedRoll == null).toList(),
      ),
);

/// Frames of a roll that have notes, in frame order, for editing a note from
/// the roll's card. Frames with only scans are left to the roll's page.
final notedFramesProvider = Provider.autoDispose
    .family<AsyncValue<List<Frame>>, String>(
      (ref, rollId) => ref
          .watch(rollDetailProvider(rollId))
          .whenData(
            (d) =>
                d.frames
                    .where((f) => f.notes?.trim().isNotEmpty ?? false)
                    .toList()
                  ..sort((a, b) => a.number.compareTo(b.number)),
          ),
    );

/// No cameras and no rolls yet: show the welcome card instead.
final isNewUserProvider = Provider.autoDispose<bool>((ref) {
  final cams = ref.watch(camerasProvider).value;
  final rolls = ref.watch(rollsProvider(RollFilter.empty)).value;
  return (cams?.isEmpty ?? false) && (rolls?.isEmpty ?? false);
});

/// Pull to refresh: reloads the cameras, the stocks their rolls name, and the
/// frames of each loaded roll.
Future<void> refreshShooting(WidgetRef ref) async {
  ref.invalidate(rollDetailProvider);
  await Future.wait([
    ref.refresh(camerasProvider.future),
    ref.refresh(stocksProvider.future),
    ref.refresh(rollsProvider(RollFilter.empty).future),
  ]);
}
