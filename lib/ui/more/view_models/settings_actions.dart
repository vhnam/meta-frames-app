import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../domain/models/saved_server.dart';
import '../../../providers.dart';

class SettingsActions {
  SettingsActions(this._ref);
  final Ref _ref;

  String get baseUrl => _ref.read(settingsRepositoryProvider).baseUrl;

  List<SavedServer> get servers =>
      _ref.read(settingsRepositoryProvider).servers;

  bool get signedIn => _ref.read(sessionStoreProvider).signedIn;

  /// Saves the server URL and drops cached data from the old server. A new URL
  /// ends the session: its token must never reach a different server.
  Future<String> saveBaseUrl(String url) async {
    final settings = _ref.read(settingsRepositoryProvider);
    final before = settings.baseUrl;
    await settings.setBaseUrl(url);
    if (settings.baseUrl != before) {
      await _ref.read(sessionStoreProvider).setToken(null);
    }
    invalidateAllData(_ref);
    return settings.baseUrl;
  }

  /// Only changes the list. The app switches server through [saveBaseUrl].
  Future<void> saveServer(String name, String url) => _ref
      .read(settingsRepositoryProvider)
      .saveServer(SavedServer(name: name, url: url));

  Future<void> deleteServer(String url) =>
      _ref.read(settingsRepositoryProvider).deleteServer(url);
}

final settingsActionsProvider = Provider<SettingsActions>(SettingsActions.new);
