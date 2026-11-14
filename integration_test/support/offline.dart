import 'package:flutter_riverpod/misc.dart';
import 'package:http/http.dart' as http;
import 'package:meta_frames/data/local/read_cache.dart';
import 'package:meta_frames/data/repositories/auth_repository_remote.dart';
import 'package:meta_frames/data/repositories/roll_repository_remote.dart';
import 'package:meta_frames/data/services/api_client.dart';
import 'package:meta_frames/data/services/session_store.dart';
import 'package:meta_frames/data/sync/sync_engine.dart';
import 'package:meta_frames/providers.dart';

/// Takes only the app offline: a request from the app fails like an
/// unreachable server while [online] is false. The test's own `ServerApi`
/// has its own client and is never affected.
class OfflineSwitch {
  bool online = true;

  late final http.Client client = _SwitchedClient(this);

  /// The three providers that carry every API call of the app. Their bodies
  /// copy `lib/data/providers.dart`, with [client] in place of the real one.
  List<Override> get overrides => [
    apiClientProvider.overrideWith(
      (ref) => ApiClient(
        () => ref.read(settingsRepositoryProvider).baseUrl,
        client,
        ref.watch(sessionStoreProvider),
      )..readCache = DeviceReadCache(ref.watch(partitionControllerProvider)),
    ),
    syncRemoteProvider.overrideWithValue((binding, token) {
      final api = _pinned(binding.server, token);
      return SyncRemote(
        rolls: RollRepositoryRemote(api),
        auth: AuthRepositoryRemote(api),
      );
    }),
    verifySessionProvider.overrideWithValue(
      (server, token) => AuthRepositoryRemote(_pinned(server, token)).me(),
    ),
  ];

  ApiClient _pinned(String server, String token) =>
      ApiClient(() => server, client, SessionStore(token));
}

class _SwitchedClient extends http.BaseClient {
  _SwitchedClient(this._switch);
  final OfflineSwitch _switch;
  final _inner = http.Client();

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) {
    // `ApiClient` reads any `Exception` as "not reachable".
    if (!_switch.online) {
      throw http.ClientException('e2e: offline', request.url);
    }
    return _inner.send(request);
  }
}
