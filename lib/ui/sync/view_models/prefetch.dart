import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../data/services/api_client.dart';
import '../../../providers.dart';

/// Reads what the field workflow needs offline, so each read is kept in the
/// partition: cameras, the rolls lists the Shooting and Rolls tabs and the
/// load picker use, each loaded roll's page (with its frames and notes, the
/// base of any later note), stocks, inventory, labs, lenses, the lenses of
/// each interchangeable-lens camera, and the expiry report. Scans are never fetched.
///
/// Runs through the same repositories as the screens, so the stored reads are
/// the ones the screens ask for. Stops quietly when offline.
Future<void> prefetchFieldData(Ref ref) async {
  if (ref.read(localStoreProvider) == null) return;
  final rolls = ref.read(rollRepositoryProvider);
  final cameras = ref.read(cameraRepositoryProvider);
  try {
    final cams = await cameras.cameras();
    await Future.wait<Object?>([
      ref.read(authRepositoryProvider).me(),
      rolls.rolls(),
      rolls.rolls(status: 'in_stock'),
      rolls.expiry(),
      ref.read(filmStockRepositoryProvider).stocks(),
      ref.read(filmStockRepositoryProvider).inventory(),
      ref.read(labRepositoryProvider).labs(),
      ref.read(lensRepositoryProvider).lenses(),
      for (final c in cams) ...[
        if (c.loadedRoll != null) rolls.roll(c.loadedRoll!.rollId),
        // A loaded camera may be emptied and loaded again offline.
        if (c.isActive && !c.hasFixedLens) cameras.lenses(c.id),
      ],
    ]);
  } on ApiException {
    // Offline or refused: what was kept before stays.
  }
}

/// Each time a partition opens (and on app resume): screens that read before
/// it was open read again, now with this phone's data and pending changes,
/// and the field data is fetched to keep it current. Watched by the app.
final prefetchOnOpenProvider = Provider<void>((ref) {
  final store = ref.watch(localStoreProvider);
  if (store == null) return;
  Future.microtask(() async {
    if (!ref.mounted || store.isClosed) return;
    invalidateAllData(ref);
    await prefetchFieldData(ref);
  });
});
