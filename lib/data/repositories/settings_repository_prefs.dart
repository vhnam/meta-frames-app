import 'package:shared_preferences/shared_preferences.dart';

import 'settings_repository.dart';

const _baseUrlKey = 'base_url';

class SettingsRepositoryPrefs implements SettingsRepository {
  SettingsRepositoryPrefs(this._prefs);
  final SharedPreferences _prefs;

  @override
  String get baseUrl => _prefs.getString(_baseUrlKey) ?? defaultBaseUrl;

  @override
  Future<void> setBaseUrl(String url) =>
      _prefs.setString(_baseUrlKey, url.trim().replaceAll(RegExp(r'/+$'), ''));
}
