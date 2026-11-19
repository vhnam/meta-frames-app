import '../../domain/models/saved_server.dart';

const defaultBaseUrl = 'http://10.0.2.2:8080';

/// The form every server URL is stored and compared in.
String normalizeBaseUrl(String url) =>
    url.trim().replaceAll(RegExp(r'/+$'), '');

/// A server URL in its stored form, or null when it is not an absolute
/// http(s) URL with a host (and no user name or password in it).
String? validServerUrl(String url) {
  final uri = Uri.tryParse(url.trim());
  if (uri == null ||
      !(uri.scheme == 'http' || uri.scheme == 'https') ||
      uri.host.isEmpty ||
      uri.userInfo.isNotEmpty) {
    return null;
  }
  return normalizeBaseUrl(uri.toString());
}

abstract class SettingsRepository {
  String get baseUrl;
  Future<void> setBaseUrl(String url);

  /// The saved servers. A device that has saved none lists the default server.
  List<SavedServer> get servers;

  /// Adds [server], or renames the saved server that has the same URL.
  Future<void> saveServer(SavedServer server);

  Future<void> deleteServer(String url);
}
