import 'dart:async';
import 'dart:io';

import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:meta_frames/app.dart';
import 'package:meta_frames/data/local/local_store.dart';
import 'package:meta_frames/data/repositories/settings_repository.dart';
import 'package:meta_frames/data/services/session_store.dart';
import 'package:meta_frames/data/sync/pending_op.dart';
import 'package:meta_frames/providers.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite/sqflite.dart';

import 'offline.dart';

/// The local development server the tests run against: `10.0.2.2` from the
/// emulator, `127.0.0.1` through `adb reverse` on a device.
final String serverUrl = () {
  const url = String.fromEnvironment(
    'E2E_SERVER',
    defaultValue: 'http://10.0.2.2:8080',
  );
  const local = {'10.0.2.2', '127.0.0.1', 'localhost'};
  if (!local.contains(Uri.parse(url).host)) {
    throw StateError('E2E_SERVER must be a local server, got $url');
  }
  return url;
}();

/// A new email for each run and case, so no account is reused.
String newEmail(String testCase) =>
    'e2e-${DateTime.now().millisecondsSinceEpoch}-$testCase@example.com';

/// What a phone keeps between two starts of the app: preferences, session and
/// partitions directory. The installed app's stored data is never read or
/// written. [net] switches only the app offline.
class Device {
  Device._(this.prefs, this.session, this.partitions);
  final SharedPreferences prefs;
  final SessionStore session;
  final Directory partitions;
  final net = OfflineSwitch();
}

/// A new [Device] that points at [serverUrl]; [token] signs it in.
Future<Device> newDevice({String? token}) async {
  SharedPreferences.setMockInitialValues({'base_url': serverUrl});
  final prefs = await SharedPreferences.getInstance();
  final partitions = await Directory.systemTemp.createTemp('e2e-partitions');
  addTearDown(() => partitions.delete(recursive: true));
  return Device._(prefs, SessionStore(token), partitions);
}

/// Starts the app on [device] in a new `ProviderScope`.
Future<void> launch(WidgetTester tester, Device device) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        prefsProvider.overrideWithValue(device.prefs),
        sessionStoreProvider.overrideWithValue(device.session),
        localDataProvider.overrideWithValue((
          factory: databaseFactory,
          dir: device.partitions.path,
        )),
        ...device.net.overrides,
      ],
      child: const MetaFramesApp(),
    ),
  );
  await tester.pump();
}

/// Starts the app signed out. Returns the session the app signs in to.
Future<SessionStore> startApp(WidgetTester tester) async {
  final device = await newDevice();
  await launch(tester, device);
  return device.session;
}

/// The container of the running app.
ProviderContainer scope(WidgetTester tester) =>
    ProviderScope.containerOf(tester.element(find.byType(MetaFramesApp)));

/// The open partition, or null.
LocalStore? openStore(WidgetTester tester) =>
    scope(tester).read(partitionControllerProvider).store;

/// The partition of [userId] on the test server.
PartitionKey partitionOf(String userId) =>
    PartitionKey(normalizeBaseUrl(serverUrl), userId);

/// Waits until the partition [key] is open.
Future<void> waitForPartition(WidgetTester tester, PartitionKey key) =>
    pumpUntil(tester, () => openStore(tester)?.key == key);

/// The changes on the phone that wait for the server, oldest first.
Future<List<PendingOp>> openOps(WidgetTester tester) =>
    openStore(tester)!.openOps();

/// Stops the app and starts it again on the same [device]. The engine and the
/// store close while the old widget tree is alive; the next frame then builds
/// a different widget, so the old scope is disposed and the new one does not
/// reuse its element. This checks SQLite durability, not an OS process kill.
Future<void> restart(WidgetTester tester, Device device) async {
  final controller = scope(tester).read(partitionControllerProvider);
  final key = controller.store?.key;
  await controller.engine?.stop();
  await controller.store?.close();
  await tester.pumpWidget(const SizedBox());
  await launch(tester, device);
  if (key != null) await waitForPartition(tester, key);
}

/// Pumps frames until [done] holds. Real requests finish outside the frame
/// clock, so `pumpAndSettle` can return before the server answers.
Future<void> pumpUntil(
  WidgetTester tester,
  bool Function() done, {
  Duration timeout = const Duration(seconds: 20),
}) async {
  final end = DateTime.now().add(timeout);
  while (!done()) {
    if (DateTime.now().isAfter(end)) {
      throw TimeoutException('condition not met', timeout);
    }
    await Future<void>.delayed(const Duration(milliseconds: 100));
    await tester.pump();
  }
}

/// Waits until [finder] finds a widget.
Future<void> pumpUntilFound(WidgetTester tester, Finder finder) =>
    pumpUntil(tester, () => finder.evaluate().isNotEmpty);

/// Brings [finder] on screen, taps it and lets the frame build.
Future<void> tapOn(WidgetTester tester, Finder finder) async {
  await pumpUntilFound(tester, finder);
  await tester.ensureVisible(finder.first);
  await tester.pump();
  await tester.tap(finder.first);
  await tester.pump();
}

/// Types [text] into the form field that shows [hint].
Future<void> enterField(WidgetTester tester, String hint, String text) async {
  final field = find.widgetWithText(TextFormField, hint);
  await pumpUntilFound(tester, field);
  await tester.ensureVisible(field);
  await tester.enterText(field, text);
  await tester.pump();
}

/// Like [pumpUntil], for a condition that asks the server or the store.
Future<void> pumpUntilAsync(
  WidgetTester tester,
  Future<bool> Function() done, {
  Duration timeout = const Duration(seconds: 30),
}) async {
  final end = DateTime.now().add(timeout);
  while (!await done()) {
    if (DateTime.now().isAfter(end)) {
      throw TimeoutException('condition not met', timeout);
    }
    await Future<void>.delayed(const Duration(milliseconds: 200));
    await tester.pump();
  }
}
