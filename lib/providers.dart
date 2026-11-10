import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'data/providers.dart';
import 'data/services/api_client.dart';
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

/// Every stock by id, for screens that show a roll's box speed or process.
/// Empty while the stocks load.
final stocksByIdProvider = Provider.autoDispose<Map<String, FilmStock>>(
  (ref) => {
    for (final s in ref.watch(stocksProvider).value ?? const <FilmStock>[])
      s.id: s,
  },
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

/// One frame of a roll, or null when the frame has no notes or scans yet: it
/// is created on first save, so a 404 is an empty frame rather than an error.
/// Answering null, rather than failing, also keeps the provider from retrying.
final frameProvider = FutureProvider.autoDispose.family<Frame?, (String, int)>((
  ref,
  k,
) async {
  try {
    return await ref.watch(rollRepositoryProvider).frame(k.$1, k.$2);
  } on ApiException catch (e) {
    if (e.status == 404) return null;
    rethrow;
  }
});

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
    ..invalidate(scannerKindsProvider)
    ..invalidate(rollsProvider)
    ..invalidate(rollDetailProvider)
    ..invalidate(expiryProvider)
    ..invalidate(negativesAtLabProvider)
    ..invalidate(processingProvider)
    ..invalidate(scansProvider)
    ..invalidate(frameProvider);
}
