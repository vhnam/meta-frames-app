import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../domain/models/models.dart';
import '../../../providers.dart';

/// A gear list split into what is in use and what has been retired.
class GearGroups<T> {
  const GearGroups(this.active, this.inactive);
  final List<T> active, inactive;

  /// Everything is retired: show the inactive list open.
  bool get onlyInactive => active.isEmpty && inactive.isNotEmpty;
}

GearGroups<T> _split<T>(List<T> all, bool Function(T) isActive) => GearGroups(
  all.where(isActive).toList(),
  all.where((e) => !isActive(e)).toList(),
);

final cameraGroupsProvider =
    Provider.autoDispose<AsyncValue<GearGroups<Camera>>>(
      (ref) => ref
          .watch(camerasProvider)
          .whenData((all) => _split(all, (c) => c.isActive)),
    );

/// Lenses in focal length order.
final lensGroupsProvider = Provider.autoDispose<AsyncValue<GearGroups<Lens>>>(
  (ref) => ref
      .watch(lensesProvider)
      .whenData(
        (all) => _split(
          [...all]..sort((a, b) => a.focalLength - b.focalLength),
          (l) => l.isActive,
        ),
      ),
);

/// Lenses that can be linked to a camera: same-mount ones first, then by
/// focal length. Built-in and inactive lenses are left out.
final linkableLensesProvider = Provider.autoDispose
    .family<AsyncValue<List<Lens>>, String?>(
      (ref, mount) => ref
          .watch(lensesProvider)
          .whenData(
            (all) =>
                all.where((l) => l.isActive && !l.isBuiltIn).toList()
                  ..sort((a, b) {
                    final am = a.mount == mount ? 0 : 1;
                    final bm = b.mount == mount ? 0 : 1;
                    return am != bm ? am - bm : a.focalLength - b.focalLength;
                  }),
          ),
    );
