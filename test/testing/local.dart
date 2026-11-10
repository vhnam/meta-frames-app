import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:meta_frames/data/local/local_store.dart';
import 'package:meta_frames/data/services/session_store.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

const server = 'http://server-a';

/// SQLite through FFI, on files in a temporary directory: the same SQL the
/// phone runs, closed and reopened like an app restart.
DatabaseFactory testDbFactory() {
  sqfliteFfiInit();
  return databaseFactoryFfi;
}

/// A fresh directory, deleted after the test.
Future<String> tempDir() async {
  final dir = await Directory.systemTemp.createTemp('mf_test');
  addTearDown(() => dir.delete(recursive: true));
  return dir.path;
}

SessionBinding binding({String user = 'u1', String host = server}) =>
    SessionBinding(server: host, userId: user, email: '$user@example.com');

/// Opens user [user]'s partition on [host] in [dir].
Future<LocalStore> openStore(
  String dir, {
  String user = 'u1',
  String host = server,
}) => LocalStore.open(
  testDbFactory(),
  dir,
  PartitionKey(host, user),
  email: '$user@example.com',
);

/// A session already verified for [user] on [host].
Future<SessionStore> boundSession({
  String token = 't1',
  String user = 'u1',
  String host = server,
}) async {
  final s = SessionStore(token);
  await s.bind(
    binding(user: user, host: host),
    forToken: token,
  );
  return s;
}
