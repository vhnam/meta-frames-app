const defaultBaseUrl = 'http://10.0.2.2:8080';

abstract class SettingsRepository {
  String get baseUrl;
  Future<void> setBaseUrl(String url);
}
