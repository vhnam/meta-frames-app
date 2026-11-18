import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'data/repositories/settings_repository.dart';
import 'data/services/session_store.dart';
import 'ui/core/theme.dart';

/// The URL preference of earlier app versions. A fixed build only mirrors it.
abstract class ServerPreference {
  /// Loads the stored value again.
  Future<void> reload();
  Object? get value;

  /// False when the value was not stored.
  Future<bool> write(String url);
}

class SharedServerPreference implements ServerPreference {
  const SharedServerPreference(this._prefs);
  final SharedPreferences _prefs;
  static const _key = 'base_url';

  @override
  Future<void> reload() => _prefs.reload();

  @override
  Object? get value => _prefs.get(_key);

  @override
  Future<bool> write(String url) => _prefs.setString(_key, url);
}

/// Thrown when the mirror of the fixed URL could not be confirmed.
class ServerMirrorFailed implements Exception {
  const ServerMirrorFailed();
}

/// The session a fixed build may start with.
typedef FixedServerStart = ({
  String? token,
  SessionBinding? binding,
  bool sessionEnded,
});

/// Decides, before the app exists and with no request sent, whether the stored
/// session may be used on [server]. A token that cannot be shown to belong to
/// [server] is removed from this device. Partitions are not touched: what they
/// keep waits for its own account and server.
///
/// Any failure throws, and [run] can run again from the start.
class FixedServerCheck {
  FixedServerCheck({required this.server, required this.vault});
  final String server;
  final StrictSessionVault vault;

  /// Kept across retries: a retry finds the token already gone.
  bool _sessionEnded = false;

  Future<FixedServerStart> run(ServerPreference preference) async {
    await preference.reload();
    final stored = await vault.read();
    final token = stored.token;
    final binding = token == null
        ? null
        : _verified(token, stored.binding, preference.value);
    if (binding == null && (token != null || stored.binding != null)) {
      if (token != null) _sessionEnded = true;
      await vault.clear();
    }
    if (preference.value != server) await _mirror(preference);
    return (
      token: binding == null ? null : token,
      binding: binding,
      sessionEnded: _sessionEnded,
    );
  }

  /// The binding of [token], if both it and [prior] prove it was issued by
  /// [server]. An app that never stored a URL was on the default server.
  SessionBinding? _verified(String token, String? raw, Object? prior) {
    final previous = prior ?? defaultBaseUrl;
    if (previous is! String || normalizeBaseUrl(previous) != server) {
      return null;
    }
    final binding = bindingFor(token, raw);
    if (binding == null ||
        normalizeBaseUrl(binding.server) != server ||
        binding.userId.trim().isEmpty ||
        binding.email.trim().isEmpty) {
      return null;
    }
    // Partitions are filed under the exact server URL.
    return SessionBinding(
      server: server,
      userId: binding.userId,
      email: binding.email,
      name: binding.name,
    );
  }

  Future<void> _mirror(ServerPreference preference) async {
    if (!await preference.write(server)) throw const ServerMirrorFailed();
    await preference.reload();
    if (preference.value != server) throw const ServerMirrorFailed();
  }
}

/// Holds the app back until [attempt] has built it. A failed attempt blocks
/// the app and offers Retry, which runs the whole attempt again.
class StartupGate extends StatefulWidget {
  const StartupGate({super.key, required this.attempt});
  final Future<Widget> Function() attempt;

  @override
  State<StartupGate> createState() => _StartupGateState();
}

class _StartupGateState extends State<StartupGate> {
  Widget? _app;
  bool _running = false, _failed = false;

  @override
  void initState() {
    super.initState();
    _run();
  }

  Future<void> _run() async {
    if (_running) return;
    _running = true;
    if (_failed) setState(() => _failed = false);
    try {
      final app = await widget.attempt();
      if (mounted) setState(() => _app = app);
    } on Object catch (error) {
      // The type only: an error may quote what storage holds.
      debugPrint('Startup check failed: ${error.runtimeType}');
      if (mounted) setState(() => _failed = true);
    } finally {
      _running = false;
    }
  }

  @override
  Widget build(BuildContext context) =>
      _app ??
      _StartupScreen(
        title: _failed ? 'MetaFrames could not start' : null,
        message: _failed
            ? 'The app could not check its secure storage. Try again. '
                  'Your saved offline work stays on this device.'
            : null,
        onRetry: _failed ? _run : null,
      );
}

/// Shown instead of the app by a release or profile build that was built
/// without a usable `API_BASE_URL`. Nothing on the device is read or changed.
class InvalidServerBuildApp extends StatelessWidget {
  const InvalidServerBuildApp({super.key});

  @override
  Widget build(BuildContext context) => const _StartupScreen(
    title: 'This build has no API server',
    message:
        'API_BASE_URL is missing or is not an HTTPS origin. Build the app '
        'again with --dart-define=API_BASE_URL=https://api.example.com.',
  );
}

/// A spinner, or [title] and [message] with an optional Retry.
class _StartupScreen extends StatelessWidget {
  const _StartupScreen({this.title, this.message, this.onRetry});
  final String? title, message;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) => MaterialApp(
    title: 'MetaFrames',
    theme: buildTheme(Brightness.light),
    darkTheme: buildTheme(Brightness.dark),
    home: Scaffold(
      body: SafeArea(
        child: Center(
          child: title == null
              ? const CircularProgressIndicator()
              : SingleChildScrollView(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Builder(
                        builder: (context) => Text(
                          title!,
                          textAlign: TextAlign.center,
                          style: Theme.of(context).textTheme.titleLarge,
                        ),
                      ),
                      const SizedBox(height: 12),
                      Text(message!, textAlign: TextAlign.center),
                      if (onRetry != null) ...[
                        const SizedBox(height: 24),
                        FilledButton(
                          onPressed: onRetry,
                          child: const Text('Retry'),
                        ),
                      ],
                    ],
                  ),
                ),
        ),
      ),
    ),
  );
}
