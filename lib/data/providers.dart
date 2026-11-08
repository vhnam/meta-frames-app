import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite/sqflite.dart';

import 'local/local_store.dart';
import 'local/partition_controller.dart';
import 'local/read_cache.dart';

import 'repositories/auth_repository.dart';
import 'repositories/auth_repository_remote.dart';
import 'repositories/camera_repository.dart';
import 'repositories/camera_repository_remote.dart';
import 'repositories/film_stock_repository.dart';
import 'repositories/film_stock_repository_remote.dart';
import 'repositories/lab_repository.dart';
import 'repositories/lab_repository_remote.dart';
import 'repositories/lens_repository.dart';
import 'repositories/lens_repository_remote.dart';
import 'repositories/processing_repository.dart';
import 'repositories/processing_repository_remote.dart';
import 'repositories/roll_repository.dart';
import 'repositories/roll_repository_remote.dart';
import 'repositories/scan_repository.dart';
import 'repositories/scan_repository_remote.dart';
import 'repositories/scanner_repository.dart';
import 'repositories/scanner_repository_remote.dart';
import 'repositories/settings_repository.dart';
import 'repositories/settings_repository_prefs.dart';
import '../domain/models/models.dart';
import 'services/api_client.dart';
import 'services/google_id_token.dart';
import 'services/session_store.dart';
import 'sync/pending_op.dart';
import 'sync/sync_engine.dart';

/// Overridden in `main()` once [SharedPreferences] has loaded.
final prefsProvider = Provider<SharedPreferences>(
  (_) => throw UnimplementedError(),
);

final settingsRepositoryProvider = Provider<SettingsRepository>(
  (ref) => SettingsRepositoryPrefs(ref.watch(prefsProvider)),
);

/// Overridden in `main()` with the store that keeps the session on the device.
final sessionStoreProvider = Provider<SessionStore>((ref) {
  final store = SessionStore();
  ref.onDispose(store.dispose);
  return store;
});

final apiClientProvider = Provider<ApiClient>(
  (ref) => ApiClient(
    () => ref.read(settingsRepositoryProvider).baseUrl,
    null,
    ref.watch(sessionStoreProvider),
  )..readCache = DeviceReadCache(ref.watch(partitionControllerProvider)),
);

/// Where partitions are kept. Overridden in `main()`; null keeps nothing on
/// the device, and every write then goes straight to the server.
final localDataProvider = Provider<({DatabaseFactory factory, String dir})?>(
  (_) => null,
);

final _pinnedHttp = http.Client();

/// A client bound to one server and one token, whatever the settings say
/// later. Its own session store keeps the app's session out of its answers.
ApiClient pinnedClient(String server, String token) =>
    ApiClient(() => server, _pinnedHttp, SessionStore(token));

/// The endpoints the sync engine sends through. Tests override it.
final syncRemoteProvider = Provider<SyncRemoteFactory>(
  (_) => (binding, token) {
    final api = pinnedClient(binding.server, token);
    return SyncRemote(
      rolls: RollRepositoryRemote(api),
      auth: AuthRepositoryRemote(api),
    );
  },
);

/// `/auth/me` for a token on a server, to bind a new session to its account.
final verifySessionProvider =
    Provider<Future<User> Function(String server, String token)>(
      (_) =>
          (server, token) =>
              AuthRepositoryRemote(pinnedClient(server, token)).me(),
    );

final partitionControllerProvider = Provider<PartitionController>((ref) {
  final local = ref.watch(localDataProvider);
  final controller = PartitionController(
    session: ref.watch(sessionStoreProvider),
    baseUrl: () => ref.read(settingsRepositoryProvider).baseUrl,
    remote: ref.watch(syncRemoteProvider),
    verify: ref.watch(verifySessionProvider),
    factory: local?.factory,
    directory: local?.dir,
  )..start();
  ref.onDispose(controller.dispose);
  return controller;
});

/// The open partition, or null: signed out, not verified yet, or nothing kept
/// on this device.
final localStoreProvider = Provider<LocalStore?>((ref) {
  final controller = ref.watch(partitionControllerProvider);
  void changed() => ref.invalidateSelf();
  controller.addListener(changed);
  ref.onDispose(() => controller.removeListener(changed));
  return controller.store;
});

/// Changes waiting for the server in the open partition, oldest first.
final openOpsProvider = FutureProvider<List<PendingOp>>((ref) async {
  final store = ref.watch(localStoreProvider);
  if (store == null) return const [];
  void changed() => ref.invalidateSelf();
  store.changes.addListener(changed);
  ref.onDispose(() {
    if (!store.isClosed) store.changes.removeListener(changed);
  });
  return store.openOps();
});

/// Drafts in the open partition, oldest first.
final draftsProvider = FutureProvider<List<Draft>>((ref) async {
  final store = ref.watch(localStoreProvider);
  if (store == null) return const [];
  void changed() => ref.invalidateSelf();
  store.changes.addListener(changed);
  ref.onDispose(() {
    if (!store.isClosed) store.changes.removeListener(changed);
  });
  return store.drafts();
});

/// The sync engine's state, for the Shooting tab and Sync status.
final syncStatusProvider = Provider<SyncStatus?>((ref) {
  final engine = ref.watch(partitionControllerProvider).engine;
  ref.watch(localStoreProvider);
  if (engine == null) return null;
  void changed() => ref.invalidateSelf();
  engine.status.addListener(changed);
  ref.onDispose(() => engine.status.removeListener(changed));
  return engine.status.value;
});

/// For `Image.network`: scan files need the session too.
final scanImageHeadersProvider = Provider<Map<String, String>>(
  (ref) => ref.watch(apiClientProvider).sessionHeaders,
);

// Tests override these with fakes.
final googleIdTokenSourceProvider = Provider<GoogleIdTokenSource>(
  (_) => NativeGoogleIdTokenSource(),
);
final authRepositoryProvider = Provider<AuthRepository>(
  (ref) => AuthRepositoryRemote(ref.watch(apiClientProvider)),
);
final cameraRepositoryProvider = Provider<CameraRepository>(
  (ref) => CameraRepositoryRemote(ref.watch(apiClientProvider)),
);
final lensRepositoryProvider = Provider<LensRepository>(
  (ref) => LensRepositoryRemote(ref.watch(apiClientProvider)),
);
final filmStockRepositoryProvider = Provider<FilmStockRepository>(
  (ref) => FilmStockRepositoryRemote(ref.watch(apiClientProvider)),
);
final labRepositoryProvider = Provider<LabRepository>(
  (ref) => LabRepositoryRemote(ref.watch(apiClientProvider)),
);
final scannerRepositoryProvider = Provider<ScannerRepository>(
  (ref) => ScannerRepositoryRemote(ref.watch(apiClientProvider)),
);
final rollRepositoryProvider = Provider<RollRepository>(
  (ref) => RollRepositoryRemote(ref.watch(apiClientProvider)),
);
final processingRepositoryProvider = Provider<ProcessingRepository>(
  (ref) => ProcessingRepositoryRemote(ref.watch(apiClientProvider)),
);
final scanRepositoryProvider = Provider<ScanRepository>(
  (ref) => ScanRepositoryRemote(ref.watch(apiClientProvider)),
);
