import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'data/providers.dart';
import 'domain/models/models.dart';
import 'domain/models/roll_filter.dart';

export 'data/providers.dart';

typedef InventoryFilter = ({String? type, String? process, int? iso});

extension _ApiCache on Ref {
  /// Keeps the answer of [fetch] after the last screen stops watching it, so a
  /// tab or segment that opens again does not call the API. The answer stays
  /// until something invalidates the provider: a write, a pull to refresh or a
  /// session change. A failed call is not kept, so the next screen tries again.
  Future<T> cached<T>(Future<T> fetch) async {
    final link = keepAlive();
    try {
      return await fetch;
    } catch (_) {
      link.close();
      rethrow;
    }
  }
}

final currentUserProvider = FutureProvider.autoDispose<User>(
  (ref) => ref.cached(ref.watch(authRepositoryProvider).me()),
);

final camerasProvider = FutureProvider.autoDispose<List<Camera>>(
  (ref) => ref.cached(ref.watch(cameraRepositoryProvider).cameras()),
);
final cameraProvider = FutureProvider.autoDispose.family<Camera, String>(
  (ref, id) => ref.watch(cameraRepositoryProvider).camera(id),
);
final cameraLensesProvider = FutureProvider.autoDispose
    .family<List<Lens>, String>(
      (ref, id) => ref.watch(cameraRepositoryProvider).lenses(id),
    );

final lensesProvider = FutureProvider.autoDispose<List<Lens>>(
  (ref) => ref.cached(ref.watch(lensRepositoryProvider).lenses()),
);
final lensProvider = FutureProvider.autoDispose.family<Lens, String>(
  (ref, id) => ref.watch(lensRepositoryProvider).lens(id),
);

/// Cameras a lens can be used on (no dedicated endpoint: derived from links).
final lensCamerasProvider = FutureProvider.autoDispose
    .family<List<Camera>, String>((ref, lensId) async {
      final cams = await ref.watch(camerasProvider.future);
      final out = <Camera>[];
      for (final c in cams) {
        final ls = await ref.watch(cameraRepositoryProvider).lenses(c.id);
        if (ls.any((l) => l.id == lensId)) out.add(c);
      }
      return out;
    });

final stocksProvider = FutureProvider.autoDispose<List<FilmStock>>(
  (ref) => ref.cached(ref.watch(filmStockRepositoryProvider).stocks()),
);
final stockDetailProvider = FutureProvider.autoDispose
    .family<FilmStockDetail, String>(
      (ref, id) => ref.watch(filmStockRepositoryProvider).stock(id),
    );
final inventoryProvider = FutureProvider.autoDispose
    .family<List<InventoryItem>, InventoryFilter>(
      (ref, f) => ref.cached(
        ref
            .watch(filmStockRepositoryProvider)
            .inventory(type: f.type, process: f.process, iso: f.iso),
      ),
    );

final labsProvider = FutureProvider.autoDispose<List<Lab>>(
  (ref) => ref.cached(ref.watch(labRepositoryProvider).labs()),
);
final labProvider = FutureProvider.autoDispose.family<Lab, String>(
  (ref, id) => ref.watch(labRepositoryProvider).lab(id),
);
final scannersProvider = FutureProvider.autoDispose<List<ScannerDevice>>(
  (ref) => ref.cached(ref.watch(scannerRepositoryProvider).scanners()),
);
final scannerProvider = FutureProvider.autoDispose
    .family<ScannerDevice, String>(
      (ref, id) => ref.watch(scannerRepositoryProvider).scanner(id),
    );
final scannerKindsProvider =
    FutureProvider.autoDispose<List<ScannerKindOptions>>(
      (ref) => ref.cached(ref.watch(scannerRepositoryProvider).kinds()),
    );

final rollsProvider = FutureProvider.autoDispose
    .family<List<RollSummary>, RollFilter>(
      (ref, f) => ref.cached(
        ref
            .watch(rollRepositoryProvider)
            .rolls(
              filmStockId: f.stockId,
              cameraId: f.cameraId,
              lensId: f.lensId,
              format: f.format,
              startedFrom: f.from,
              startedTo: f.to,
            ),
      ),
    );
final rollDetailProvider = FutureProvider.autoDispose
    .family<RollDetail, String>(
      (ref, id) => ref.watch(rollRepositoryProvider).roll(id),
    );
final expiryProvider = FutureProvider.autoDispose<ExpiryView>(
  (ref) => ref.cached(ref.watch(rollRepositoryProvider).expiry()),
);
final negativesAtLabProvider =
    FutureProvider.autoDispose<List<NegativesAtLabItem>>(
      (ref) =>
          ref.cached(ref.watch(processingRepositoryProvider).negativesAtLab()),
    );

final processingProvider = FutureProvider.autoDispose
    .family<Processing, String>(
      (ref, id) => ref.watch(processingRepositoryProvider).processing(id),
    );
final scansProvider = FutureProvider.autoDispose
    .family<List<Scan>, (String, Scanner?)>(
      (ref, k) async => [
        ...await ref.cached(
          ref.watch(scanRepositoryProvider).scans(k.$1, scanner: k.$2),
        ),
      ]..sort((a, b) => a.frameNumber - b.frameNumber),
    );
final compareProvider = FutureProvider.autoDispose
    .family<FrameComparison, (String, int)>(
      (ref, k) =>
          ref.cached(ref.watch(scanRepositoryProvider).compare(k.$1, k.$2)),
    );
final frameProvider = FutureProvider.autoDispose.family<Frame, (String, int)>(
  (ref, k) => ref.watch(scanRepositoryProvider).frame(k.$1, k.$2),
);

/// Drops every cached list and detail. For changes that affect all data, such
/// as pointing the app at another server. Mutations invalidate only what they
/// change, in their own actions classes.
void invalidateAllData(Ref ref) {
  ref
    ..invalidate(currentUserProvider)
    ..invalidate(camerasProvider)
    ..invalidate(cameraProvider)
    ..invalidate(cameraLensesProvider)
    ..invalidate(lensesProvider)
    ..invalidate(lensProvider)
    ..invalidate(lensCamerasProvider)
    ..invalidate(stocksProvider)
    ..invalidate(stockDetailProvider)
    ..invalidate(inventoryProvider)
    ..invalidate(labsProvider)
    ..invalidate(labProvider)
    ..invalidate(scannersProvider)
    ..invalidate(scannerProvider)
    ..invalidate(scannerKindsProvider)
    ..invalidate(rollsProvider)
    ..invalidate(rollDetailProvider)
    ..invalidate(expiryProvider)
    ..invalidate(negativesAtLabProvider)
    ..invalidate(processingProvider)
    ..invalidate(scansProvider)
    ..invalidate(compareProvider)
    ..invalidate(frameProvider);
}
