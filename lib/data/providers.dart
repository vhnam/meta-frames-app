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
import 'services/fixed_origin_client.dart';
import 'services/google_id_token.dart';
import 'services/server_policy.dart';
import 'services/session_image.dart';
import 'services/session_store.dart';
import 'sync/pending_op.dart';
import 'sync/sync_engine.dart';

/// Overridden in `main()` once [SharedPreferences] has loaded.
final prefsProvider = Provider<SharedPreferences>(
  (_) => throw UnimplementedError(),
);

/// Overridden in `main()` with the policy this build was compiled with.
final serverPolicyProvider = Provider<ServerPolicy>(
  (_) => const DebugServers(),
);

final settingsRepositoryProvider = Provider<SettingsRepository>(
  (ref) => SettingsRepositoryPrefs(
    ref.watch(prefsProvider),
    fixedUrl: switch (ref.watch(serverPolicyProvider)) {
      DebugServers() => null,
      FixedServer(:final url) => url,
      InvalidServerBuild() => throw StateError(
        'API_BASE_URL must be an HTTPS origin.',
      ),
    },
  ),
);

/// Whether the startup check ended a stored session. Told once.
class StartupNotice {
  StartupNotice({bool sessionEnded = false}) : _pending = sessionEnded;
  bool _pending;

  bool take() {
    final pending = _pending;
    _pending = false;
    return pending;
  }
}

/// Overridden in `main()` with the outcome of the startup check.
final sessionEndedAtStartupProvider = Provider<StartupNotice>(
  (_) => StartupNotice(),
);

/// Overridden in `main()` with the store that keeps the session on the device.
final sessionStoreProvider = Provider<SessionStore>((ref) {
  final store = SessionStore();
  ref.onDispose(store.dispose);
  return store;
});

/// The transport of every request. A fixed build stays on its one origin.
final httpClientProvider = Provider<http.Client>(
  (ref) => switch (ref.watch(serverPolicyProvider)) {
    DebugServers() => http.Client(),
    FixedServer(:final url) => FixedOriginClient(url),
    InvalidServerBuild() => throw StateError(
      'API_BASE_URL must be an HTTPS origin.',
    ),
  },
);

final apiClientProvider = Provider<ApiClient>(
  (ref) => ApiClient(
    () => ref.read(settingsRepositoryProvider).baseUrl,
    ref.watch(httpClientProvider),
    ref.watch(sessionStoreProvider),
  )..readCache = DeviceReadCache(ref.watch(partitionControllerProvider)),
);

/// Where partitions are kept. Overridden in `main()`; null keeps nothing on
/// the device, and every write then goes straight to the server.
final localDataProvider = Provider<({DatabaseFactory factory, String dir})?>(
  (_) => null,
);

/// A client bound to one server and one token, whatever the settings say
/// later. Its own session store keeps the app's session out of its answers.
ApiClient pinnedClient(http.Client client, String server, String token) =>
    ApiClient(() => server, client, SessionStore(token));

/// The endpoints the sync engine sends through. Tests override it.
final syncRemoteProvider = Provider<SyncRemoteFactory>((ref) {
  final client = ref.watch(httpClientProvider);
  return (binding, token) {
    final api = pinnedClient(client, binding.server, token);
    return SyncRemote(
      rolls: RollRepositoryRemote(api),
      auth: AuthRepositoryRemote(api),
    );
  };
});

/// `/auth/me` for a token on a server, to bind a new session to its account.
final verifySessionProvider =
    Provider<Future<User> Function(String server, String token)>((ref) {
      final client = ref.watch(httpClientProvider);
      return (server, token) =>
          AuthRepositoryRemote(pinnedClient(client, server, token)).me();
    });

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

/// A pending automatic retry keeps its error through a store change, where it
/// cannot be told from a failed read of the new store.
Duration? _noRetry(int _, Object _) => null;

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
}, retry: _noRetry);

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
}, retry: _noRetry);

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

/// Builds the image of a scan file for the current session. Rebuilds when the
/// session changes, so a screen on show never keeps an earlier session's image.
final scanImageProvider = Provider<SessionImage Function(String url)>((ref) {
  final client = ref.watch(httpClientProvider);
  final headers = ref.watch(apiClientProvider).sessionHeaders;
  final session = ref.watch(sessionStoreProvider);
  void changed() => ref.invalidateSelf();
  session.addListener(changed);
  ref.onDispose(() => session.removeListener(changed));
  return (url) => SessionImage(url, client: client, headers: headers);
});

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
