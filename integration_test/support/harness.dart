import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:meta_frames/app.dart';
import 'package:meta_frames/data/services/session_store.dart';
import 'package:meta_frames/providers.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite/sqflite.dart';

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

/// Starts the app against [serverUrl] with its own preferences, session and
/// partitions directory: the installed app's stored data is never read or
/// written. Returns the session the app signs in to.
Future<SessionStore> startApp(WidgetTester tester) async {
  SharedPreferences.setMockInitialValues({'base_url': serverUrl});
  final prefs = await SharedPreferences.getInstance();
  final session = SessionStore();
  final partitions = await Directory.systemTemp.createTemp('e2e-partitions');
  addTearDown(() => partitions.delete(recursive: true));
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        prefsProvider.overrideWithValue(prefs),
        sessionStoreProvider.overrideWithValue(session),
        localDataProvider.overrideWithValue((
          factory: databaseFactory,
          dir: partitions.path,
        )),
      ],
      child: const MetaFramesApp(),
    ),
  );
  await tester.pump();
  return session;
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
