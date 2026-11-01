import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../providers.dart';

class SettingsActions {
  SettingsActions(this._ref);
  final Ref _ref;

  String get baseUrl => _ref.read(settingsRepositoryProvider).baseUrl;

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
}

final settingsActionsProvider = Provider<SettingsActions>(SettingsActions.new);
