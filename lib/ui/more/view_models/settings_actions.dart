import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../data/repositories/settings_repository.dart';
import '../../../data/services/server_policy.dart';
import '../../../domain/models/saved_server.dart';
import '../../../providers.dart';

class SettingsActions {
  SettingsActions(this._ref);
  final Ref _ref;

  String get baseUrl => _ref.read(settingsRepositoryProvider).baseUrl;

  List<SavedServer> get servers =>
      _ref.read(settingsRepositoryProvider).servers;

  bool get signedIn => _ref.read(sessionStoreProvider).signedIn;

  /// False in a build whose server was fixed when it was built.
  bool get canChooseServer => _ref.read(serverPolicyProvider) is DebugServers;

  bool _savingServer = false;

  /// Runs [body] unless another server save is in progress, on any screen
  /// instance. This object outlives the screen, so Back and reopen cannot
  /// start a second write. The state clears when [body] ends or throws.
  Future<void> exclusiveServerSave(Future<void> Function() body) async {
    if (_savingServer) return;
    _savingServer = true;
    try {
      await body();
    } finally {
      _savingServer = false;
    }
  }

  /// Saves the server URL and drops cached data from the old server. A new URL
  /// ends the session: its token must never reach a different server. What
  /// this phone keeps for the old server's account stays in its partition
  /// (unless [discardKept]), to sync when that account signs in there again.
  /// Throws a [StateError], before anything changes, when [canChooseServer] is
  /// false.
  Future<String> saveBaseUrl(String url, {bool discardKept = false}) async {
    if (!canChooseServer) {
      throw StateError('This build uses a fixed API server.');
    }
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
