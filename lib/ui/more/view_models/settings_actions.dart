import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../providers.dart';

class SettingsActions {
  SettingsActions(this._ref);
  final Ref _ref;

  String get baseUrl => _ref.read(settingsRepositoryProvider).baseUrl;

  /// Saves the server URL and drops cached data from the old server.
  Future<String> saveBaseUrl(String url) async {
    final settings = _ref.read(settingsRepositoryProvider);
    await settings.setBaseUrl(url);
    invalidateAllData(_ref);
    return settings.baseUrl;
  }
}

final settingsActionsProvider = Provider<SettingsActions>(SettingsActions.new);
