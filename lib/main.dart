import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite/sqflite.dart';

import 'app.dart';
import 'app_startup.dart';
import 'data/services/server_policy.dart';
import 'data/services/session_store.dart';
import 'providers.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  switch (ServerPolicy.fromBuild()) {
    case InvalidServerBuild():
      debugPrint('API_BASE_URL must be an HTTPS origin.');
      runApp(const InvalidServerBuildApp());
    case final FixedServer policy:
      final check = FixedServerCheck(
        server: policy.url,
        vault: const StrictSessionVault(DeviceSecureKeys()),
      );
      runApp(
        StartupGate(
          attempt: () async {
            final prefs = await SharedPreferences.getInstance();
            final start = await check.run(SharedServerPreference(prefs));
            return _app(
              prefs: prefs,
              policy: policy,
              session: SecureSessionStore.restored(start.token, start.binding),
              notice: StartupNotice(sessionEnded: start.sessionEnded),
            );
          },
        ),
      );
    case final DebugServers policy:
      final prefs = await SharedPreferences.getInstance();
      final session = await SecureSessionStore.load();
      runApp(
        await _app(
          prefs: prefs,
          policy: policy,
          session: session,
          notice: StartupNotice(),
        ),
      );
  }
}

Future<Widget> _app({
  required SharedPreferences prefs,
  required ServerPolicy policy,
  required SessionStore session,
  required StartupNotice notice,
}) async {
  // One SQLite file per account and server (see PartitionController).
  final support = await getApplicationSupportDirectory();
  final partitions = p.join(support.path, 'partitions');
  await Directory(partitions).create(recursive: true);
  return ProviderScope(
    overrides: [
      prefsProvider.overrideWithValue(prefs),
      serverPolicyProvider.overrideWithValue(policy),
      sessionEndedAtStartupProvider.overrideWithValue(notice),
      sessionStoreProvider.overrideWithValue(session),
      localDataProvider.overrideWithValue((
        factory: databaseFactory,
        dir: partitions,
      )),
    ],
    child: const MetaFramesApp(),
  );
}
