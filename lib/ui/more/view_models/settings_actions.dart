import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../data/repositories/settings_repository.dart';
import '../../../domain/models/saved_server.dart';
import '../../../providers.dart';

/// Opens [uri] in the system browser. False when nothing could open it.
typedef UrlOpener = Future<bool> Function(Uri uri);

final urlOpenerProvider = Provider<UrlOpener>(
  (_) =>
      (uri) => launchUrl(uri, mode: LaunchMode.externalApplication),
);

class SettingsActions {
  SettingsActions(this._ref);
  final Ref _ref;

  String get baseUrl => _ref.read(settingsRepositoryProvider).baseUrl;

  List<SavedServer> get servers =>
      _ref.read(settingsRepositoryProvider).servers;

  bool get signedIn => _ref.read(sessionStoreProvider).signedIn;

  /// The dashboard of the server [server] (the current one by default).
  String? dashboardUrl([String? server]) =>
      _ref.read(settingsRepositoryProvider).dashboardUrl(server ?? baseUrl);

  /// Opens the current server's dashboard in the browser. False when this
  /// server has no usable http(s) address set or the browser could not open
  /// it; the caller then offers the address to copy.
  Future<bool> openDashboard() async {
    final url = dashboardUrl();
    final stored = url == null ? null : validDashboardUrl(url);
    if (stored == null) return false;
    try {
      return await _ref.read(urlOpenerProvider)(Uri.parse(stored));
    } on Object {
      return false;
    }
  }

  /// Throws a [FormatException] for anything but an http(s) URL.
  Future<void> setDashboardUrl(String server, String? url) =>
      _ref.read(settingsRepositoryProvider).setDashboardUrl(server, url);

  /// Saves the server URL and drops cached data from the old server. A new URL
  /// ends the session: its token must never reach a different server. What
  /// this phone keeps for the old server's account stays in its partition
  /// (unless [discardKept]), to sync when that account signs in there again.
  Future<String> saveBaseUrl(String url, {bool discardKept = false}) async {
    final settings = _ref.read(settingsRepositoryProvider);
    final before = settings.baseUrl;
    final kept = _ref.read(localStoreProvider)?.key;
    if (discardKept &&
        kept != null &&
        normalizeBaseUrl(url) != normalizeBaseUrl(before)) {
      await _ref.read(partitionControllerProvider).discard(kept);
    }
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

/// System, light or dark, kept on this device apart from the server settings.
class ThemeModeNotifier extends Notifier<ThemeMode> {
  static const _key = 'theme_mode';

  @override
  ThemeMode build() {
    final saved = ref.watch(prefsProvider).getString(_key);
    return ThemeMode.values.asNameMap()[saved] ?? ThemeMode.system;
  }

  Future<void> set(ThemeMode mode) async {
    state = mode;
    await ref.read(prefsProvider).setString(_key, mode.name);
  }
}

final themeModeProvider = NotifierProvider<ThemeModeNotifier, ThemeMode>(
  ThemeModeNotifier.new,
);
