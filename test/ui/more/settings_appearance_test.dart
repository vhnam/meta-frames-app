import 'dart:ui' show Tristate;

import 'package:material_ui/material_ui.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter/services.dart';
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

final _theme = find.widgetWithText(ListTile, 'Theme');

String _modeName(ThemeMode mode) =>
    mode.name[0].toUpperCase() + mode.name.substring(1);

Finder _choice(ThemeMode mode) => find.descendant(
  of: find.byType(BottomSheet),
  matching: find.widgetWithText(ListTile, _modeName(mode)),
);

Future<void> _showChoices(WidgetTester tester) async {
  await tester.tap(_theme);
  await tester.pumpAndSettle();
}

int _countSemanticsLabels(SemanticsNode node, String label) {
  var count = node.getSemanticsData().label == label ? 1 : 0;
  node.visitChildren((child) {
    count += _countSemanticsLabels(child, label);
    return true;
  });
  return count;
}

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

    await _showChoices(tester);
    await tester.tap(_choice(ThemeMode.dark));
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

    await _showChoices(tester);
    await tester.tap(_choice(ThemeMode.system));
    await tester.pumpAndSettle();
    expect(_shown(tester), Brightness.dark);

    tester.platformDispatcher.platformBrightnessTestValue = Brightness.light;
    await tester.pumpAndSettle();
    expect(_shown(tester), Brightness.light);
  });

  for (final mode in ThemeMode.values) {
    testWidgets('marks the stored ${mode.name} mode', (tester) async {
      final semantics = tester.ensureSemantics();

      await prefs.setString('theme_mode', mode.name);
      addTearDown(tester.platformDispatcher.clearPlatformBrightnessTestValue);
      for (final brightness in Brightness.values) {
        tester.platformDispatcher.platformBrightnessTestValue = brightness;
        await _open(tester, prefs);
        expect(
          find.descendant(of: _theme, matching: find.text(_modeName(mode))),
          findsOneWidget,
        );
        await _showChoices(tester);
        for (final choice in ThemeMode.values) {
          final choiceNode = tester.getSemantics(_choice(choice));
          var root = choiceNode;
          while (root.parent != null) {
            root = root.parent!;
          }
          final node = choiceNode.getSemanticsData();
          expect(_countSemanticsLabels(root, _modeName(choice)), 1);
          expect(node.label, _modeName(choice));
          expect(node.hasAction(SemanticsAction.tap), isTrue);
          expect(
            node.flagsCollection.isSelected == Tristate.isTrue,
            choice == mode,
            reason: 'Selected state for the ${choice.name} action',
          );
        }
        await tester.binding.handlePopRoute();
        await tester.pumpAndSettle();
      }
      semantics.dispose();
    });
  }

  testWidgets('reselect, Back, and outside tap preserve the preference', (
    tester,
  ) async {
    await _open(tester, prefs);
    await _showChoices(tester);
    await tester.tap(_choice(ThemeMode.system));
    await tester.pumpAndSettle();
    expect(_choice(ThemeMode.dark), findsNothing);
    expect(prefs.containsKey('theme_mode'), isFalse);
    await _showChoices(tester);
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(_choice(ThemeMode.dark), findsNothing);
    expect(prefs.containsKey('theme_mode'), isFalse);
    await _showChoices(tester);
    await tester.tapAt(const Offset(10, 10));
    await tester.pumpAndSettle();
    expect(_choice(ThemeMode.dark), findsNothing);
    expect(prefs.containsKey('theme_mode'), isFalse);
  });

  testWidgets('keyboard focus returns to Theme on dismissal', (tester) async {
    final semantics = tester.ensureSemantics();

    await _open(tester, prefs);
    await tester.sendKeyEvent(LogicalKeyboardKey.tab);
    await tester.pumpAndSettle();
    expect(
      tester.getSemantics(_theme).getSemanticsData().flagsCollection.isFocused,
      Tristate.isTrue,
    );
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pumpAndSettle();
    expect(_choice(ThemeMode.dark), findsOneWidget);
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(
      tester.getSemantics(_theme).getSemanticsData().flagsCollection.isFocused,
      Tristate.isTrue,
    );
    semantics.dispose();
  });

  for (final brightness in Brightness.values) {
    testWidgets('Theme targets remain operable at 200% in $brightness', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(320, 400);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      tester.platformDispatcher.textScaleFactorTestValue = 2;
      tester.platformDispatcher.platformBrightnessTestValue = brightness;
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
      addTearDown(tester.platformDispatcher.clearPlatformBrightnessTestValue);
      for (final mode in ThemeMode.values) {
        final explicitMode = brightness == Brightness.dark
            ? ThemeMode.dark
            : ThemeMode.light;
        final initial = mode == ThemeMode.system
            ? explicitMode
            : ThemeMode.system;
        await prefs.setString('theme_mode', initial.name);
        await _open(tester, prefs);
        for (final target in [_theme, _choice(mode)]) {
          await tester.ensureVisible(target);
          await tester.pumpAndSettle();
          final size = tester.getSize(target);
          expect(size.width, greaterThanOrEqualTo(48));
          expect(size.height, greaterThanOrEqualTo(48));
          await tester.tap(target);
          await tester.pumpAndSettle();
        }
        expect(prefs.getString('theme_mode'), mode.name);
        expect(tester.takeException(), isNull);
      }
    });
  }

  for (final textScale in [1.0, 2.0]) {
    testWidgets('Language sheet offers only English at ${textScale}x', (
      tester,
    ) async {
      tester.platformDispatcher.textScaleFactorTestValue = textScale;
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
      await _open(tester, prefs);
      await tester.tap(find.widgetWithText(ListTile, 'Language'));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);

      Finder option(String name) => find.descendant(
        of: find.byType(BottomSheet),
        matching: find.widgetWithText(ListTile, name),
      );
      final vietnamese = option('Tiếng Việt');
      await tester.tap(vietnamese, warnIfMissed: false);
      await tester.pumpAndSettle();
      // Disabled: the tap neither closes the sheet nor stores a choice.
      expect(vietnamese, findsOneWidget);

      final english = option('English');
      expect(tester.getSize(english).height, greaterThanOrEqualTo(48));
      await tester.tap(english);
      await tester.pumpAndSettle();
      expect(find.byType(BottomSheet), findsNothing);
      expect(prefs.getKeys(), isEmpty);
    });
  }
}
