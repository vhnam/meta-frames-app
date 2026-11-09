import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:meta_frames/providers.dart';
import 'package:meta_frames/ui/core/theme.dart';
import 'package:meta_frames/ui/more/view_models/settings_actions.dart';
import 'package:meta_frames/ui/more/widgets/settings_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// The app's theme wiring around the Settings screen, as in `app.dart`.
class _App extends ConsumerWidget {
  const _App();
  @override
  Widget build(BuildContext context, WidgetRef ref) => MaterialApp(
    theme: buildTheme(Brightness.light),
    darkTheme: buildTheme(Brightness.dark),
    themeMode: ref.watch(themeModeProvider),
    home: const SettingsScreen(),
  );
}

Future<void> _open(WidgetTester tester, SharedPreferences prefs) async {
  // A new scope each time, like opening the app again.
  await tester.pumpWidget(
    ProviderScope(
      key: UniqueKey(),
      overrides: [prefsProvider.overrideWithValue(prefs)],
      child: const _App(),
    ),
  );
  await tester.pumpAndSettle();
}

Brightness _shown(WidgetTester tester) =>
    Theme.of(tester.element(find.byType(SettingsScreen))).brightness;

void main() {
  late SharedPreferences prefs;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    prefs = await SharedPreferences.getInstance();
  });

  testWidgets('picking a theme applies at once and survives a reopen', (
    tester,
  ) async {
    tester.platformDispatcher.platformBrightnessTestValue = Brightness.light;
    addTearDown(tester.platformDispatcher.clearPlatformBrightnessTestValue);
    await _open(tester, prefs);

    await tester.tap(find.text('Dark'));
    await tester.pumpAndSettle();
    expect(_shown(tester), Brightness.dark);

    await _open(tester, prefs);
    expect(_shown(tester), Brightness.dark);

    // The server Save button was never pressed.
    expect(prefs.getKeys(), {'theme_mode'});
  });

  testWidgets('System follows the device brightness', (tester) async {
    await prefs.setString('theme_mode', 'light');
    tester.platformDispatcher.platformBrightnessTestValue = Brightness.dark;
    addTearDown(tester.platformDispatcher.clearPlatformBrightnessTestValue);
    await _open(tester, prefs);
    expect(_shown(tester), Brightness.light);

    await tester.tap(find.text('System'));
    await tester.pumpAndSettle();
    expect(_shown(tester), Brightness.dark);

    tester.platformDispatcher.platformBrightnessTestValue = Brightness.light;
    await tester.pumpAndSettle();
    expect(_shown(tester), Brightness.light);
  });
}
