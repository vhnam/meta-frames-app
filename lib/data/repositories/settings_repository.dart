import '../../domain/models/saved_server.dart';

const defaultBaseUrl = 'http://10.0.2.2:8080';

/// The form every server URL is stored and compared in.
String normalizeBaseUrl(String url) =>
    url.trim().replaceAll(RegExp(r'/+$'), '');

/// The dashboard URL in its stored form, or null when it is not an absolute
/// http(s) URL with a host (and no user name or password in it).
String? validDashboardUrl(String url) {
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

  /// The web dashboard that goes with the API server at [server], if set.
  /// Kept per server, so switching servers never links to another server's
  /// dashboard.
  String? dashboardUrl(String server);

  /// Sets (or, with null, clears) [server]'s dashboard URL. Throws a
  /// [FormatException] for a URL [validDashboardUrl] refuses.
  Future<void> setDashboardUrl(String server, String? url);
}
