import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'core/api.dart';
import 'core/models.dart';

final prefsProvider = Provider<SharedPreferences>(
  (_) => throw UnimplementedError(),
);
final apiProvider = Provider<Api>((ref) => Api(ref.watch(prefsProvider)));

typedef RollFilter = ({
  String? stockId,
  String? cameraId,
  String? lensId,
  int? format,
  DateTime? from,
  DateTime? to,
});

const emptyRollFilter = (
  stockId: null,
  cameraId: null,
  lensId: null,
  format: null,
  from: null,
  to: null,
);

typedef InventoryFilter = ({String? type, String? process, int? iso});

final camerasProvider = FutureProvider.autoDispose<List<Camera>>(
  (ref) => ref.watch(apiProvider).cameras(),
);
final cameraProvider = FutureProvider.autoDispose.family<Camera, String>(
  (ref, id) => ref.watch(apiProvider).camera(id),
);
final cameraLensesProvider = FutureProvider.autoDispose
    .family<List<Lens>, String>(
      (ref, id) => ref.watch(apiProvider).cameraLenses(id),
    );

final lensesProvider = FutureProvider.autoDispose<List<Lens>>(
  (ref) => ref.watch(apiProvider).lenses(),
);
final lensProvider = FutureProvider.autoDispose.family<Lens, String>(
  (ref, id) => ref.watch(apiProvider).lens(id),
);

final stocksProvider = FutureProvider.autoDispose<List<FilmStock>>(
  (ref) => ref.watch(apiProvider).stocks(),
);
final stockDetailProvider = FutureProvider.autoDispose
    .family<FilmStockDetail, String>(
      (ref, id) => ref.watch(apiProvider).stock(id),
    );
final inventoryProvider = FutureProvider.autoDispose
    .family<List<InventoryItem>, InventoryFilter>(
      (ref, f) => ref
          .watch(apiProvider)
          .inventory(type: f.type, process: f.process, iso: f.iso),
    );

final labsProvider = FutureProvider.autoDispose<List<Lab>>(
  (ref) => ref.watch(apiProvider).labs(),
);

final rollsProvider = FutureProvider.autoDispose
    .family<List<RollSummary>, RollFilter>(
      (ref, f) => ref
          .watch(apiProvider)
          .rolls(
            filmStockId: f.stockId,
            cameraId: f.cameraId,
            lensId: f.lensId,
            format: f.format,
            startedFrom: f.from,
            startedTo: f.to,
          ),
    );
final rollDetailProvider = FutureProvider.autoDispose
    .family<RollDetail, String>((ref, id) => ref.watch(apiProvider).roll(id));
final expiryProvider = FutureProvider.autoDispose<ExpiryView>(
  (ref) => ref.watch(apiProvider).expiry(),
);
final negativesAtLabProvider =
    FutureProvider.autoDispose<List<NegativesAtLabItem>>(
      (ref) => ref.watch(apiProvider).negativesAtLab(),
    );

final processingProvider = FutureProvider.autoDispose
    .family<Processing, String>(
      (ref, id) => ref.watch(apiProvider).processing(id),
    );
final scansProvider = FutureProvider.autoDispose
    .family<List<Scan>, (String, Scanner?)>(
      (ref, k) => ref.watch(apiProvider).scans(k.$1, scanner: k.$2),
    );
final compareProvider = FutureProvider.autoDispose
    .family<FrameComparison, (String, int)>(
      (ref, k) => ref.watch(apiProvider).compare(k.$1, k.$2),
    );
final frameProvider = FutureProvider.autoDispose.family<Frame, (String, int)>(
  (ref, k) => ref.watch(apiProvider).frame(k.$1, k.$2),
);

/// Invalidate every list/detail cache after a mutation.
void refreshAll(WidgetRef ref) {
  ref
    ..invalidate(camerasProvider)
    ..invalidate(cameraProvider)
    ..invalidate(cameraLensesProvider)
    ..invalidate(lensesProvider)
    ..invalidate(lensProvider)
    ..invalidate(stocksProvider)
    ..invalidate(stockDetailProvider)
    ..invalidate(inventoryProvider)
    ..invalidate(labsProvider)
    ..invalidate(rollsProvider)
    ..invalidate(rollDetailProvider)
    ..invalidate(expiryProvider)
    ..invalidate(negativesAtLabProvider)
    ..invalidate(processingProvider)
    ..invalidate(scansProvider)
    ..invalidate(compareProvider)
    ..invalidate(frameProvider);
}
