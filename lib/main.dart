import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite/sqflite.dart';

import 'app.dart';
import 'data/services/session_store.dart';
import 'providers.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final prefs = await SharedPreferences.getInstance();
  final session = await SecureSessionStore.load();
  // One SQLite file per account and server (see PartitionController).
  final support = await getApplicationSupportDirectory();
  final partitions = p.join(support.path, 'partitions');
  await Directory(partitions).create(recursive: true);
  runApp(
    ProviderScope(
      overrides: [
        prefsProvider.overrideWithValue(prefs),
        sessionStoreProvider.overrideWithValue(session),
        localDataProvider.overrideWithValue((
          factory: databaseFactory,
          dir: partitions,
        )),
      ],
      child: const MetaFramesApp(),
    ),
  );
}
