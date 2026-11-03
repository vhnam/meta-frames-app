import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../../domain/models/saved_server.dart';
import 'settings_repository.dart';

const _baseUrlKey = 'base_url';
const _serversKey = 'saved_servers';

class SettingsRepositoryPrefs implements SettingsRepository {
  SettingsRepositoryPrefs(this._prefs);
  final SharedPreferences _prefs;

  @override
  String get baseUrl => _prefs.getString(_baseUrlKey) ?? defaultBaseUrl;

  @override
  Future<void> setBaseUrl(String url) =>
      _prefs.setString(_baseUrlKey, normalizeBaseUrl(url));

  @override
  List<SavedServer> get servers {
    final raw = _prefs.getString(_serversKey);
    if (raw == null) {
      return const [SavedServer(name: 'Localhost', url: defaultBaseUrl)];
    }
    return [
      for (final s in jsonDecode(raw) as List)
        SavedServer.fromJson(s as Map<String, dynamic>),
    ];
  }

  @override
  Future<void> saveServer(SavedServer server) {
    final saved = SavedServer(
      name: server.name.trim(),
      url: normalizeBaseUrl(server.url),
    );
    final list = servers;
    final at = list.indexWhere((s) => s.url == saved.url);
    return _write(
      at < 0
          ? [...list, saved]
          : [...list.take(at), saved, ...list.skip(at + 1)],
    );
  }

  @override
  Future<void> deleteServer(String url) {
    final target = normalizeBaseUrl(url);
    return _write(servers.where((s) => s.url != target).toList());
  }

  Future<void> _write(List<SavedServer> list) =>
      _prefs.setString(_serversKey, jsonEncode(list));
}
