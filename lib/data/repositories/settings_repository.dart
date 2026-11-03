import '../../domain/models/saved_server.dart';

const defaultBaseUrl = 'http://10.0.2.2:8080';

/// The form every server URL is stored and compared in.
String normalizeBaseUrl(String url) =>
    url.trim().replaceAll(RegExp(r'/+$'), '');

abstract class SettingsRepository {
  String get baseUrl;
  Future<void> setBaseUrl(String url);

  /// The saved servers. A device that has saved none lists the default server.
  List<SavedServer> get servers;

  /// Adds [server], or renames the saved server that has the same URL.
  Future<void> saveServer(SavedServer server);

  Future<void> deleteServer(String url);
}
