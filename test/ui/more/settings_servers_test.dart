import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:meta_frames/data/repositories/settings_repository.dart';
import 'package:meta_frames/data/repositories/settings_repository_prefs.dart';
import 'package:meta_frames/domain/models/saved_server.dart';
import 'package:meta_frames/providers.dart';
import 'package:meta_frames/ui/more/widgets/settings_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _prod = 'https://api.example.com';

Future<SharedPreferences> _prefs() async {
  SharedPreferences.setMockInitialValues({});
  return SharedPreferences.getInstance();
}

Future<SharedPreferences> _pump(WidgetTester tester) async {
  final prefs = await _prefs();
  await tester.pumpWidget(
    ProviderScope(
      overrides: [prefsProvider.overrideWithValue(prefs)],
      child: const MaterialApp(home: SettingsScreen()),
    ),
  );
  return prefs;
}

Finder get _urlField => find.byType(TextField).first;

String _urlText(WidgetTester tester) =>
    tester.widget<TextField>(_urlField).controller!.text;

void main() {
  group('SettingsRepositoryPrefs servers', () {
    test('lists the default server until the user saves one', () async {
      final repo = SettingsRepositoryPrefs(await _prefs());
      expect(repo.servers.single.url, defaultBaseUrl);
    });

    test('saved servers survive a new repository', () async {
      final prefs = await _prefs();
      await SettingsRepositoryPrefs(prefs)
          .saveServer(const SavedServer(name: 'Production', url: _prod));
      expect(SettingsRepositoryPrefs(prefs).servers.map((s) => s.name), [
        'Localhost',
        'Production',
      ]);
    });

    test('the same URL renames the saved server in place', () async {
      final repo = SettingsRepositoryPrefs(await _prefs());
      await repo.saveServer(const SavedServer(name: 'Production', url: _prod));
      await repo.saveServer(const SavedServer(name: ' Live ', url: '$_prod/'));
      expect(repo.servers.map((s) => s.name), ['Localhost', 'Live']);
    });

    test('a deleted default server stays deleted', () async {
      final repo = SettingsRepositoryPrefs(await _prefs());
      await repo.deleteServer(defaultBaseUrl);
      expect(repo.servers, isEmpty);
    });

    test('changing the list keeps the active server', () async {
      final repo = SettingsRepositoryPrefs(await _prefs());
      await repo.setBaseUrl(_prod);
      await repo.saveServer(const SavedServer(name: 'Production', url: _prod));
      await repo.deleteServer(_prod);
      expect(repo.baseUrl, _prod);
    });
  });

  group('SettingsScreen servers', () {
    testWidgets('a URL is added under the name the user enters', (
      tester,
    ) async {
      await _pump(tester);
      await tester.enterText(_urlField, '$_prod/');
      await tester.pump();
      await tester.tap(find.text('Add to saved'));
      await tester.pumpAndSettle();

      expect(find.text(_prod), findsOneWidget);
      final add = find.widgetWithText(TextButton, 'Add');
      expect(tester.widget<TextButton>(add).onPressed, isNull);

      await tester.enterText(
        find.descendant(
          of: find.byType(AlertDialog),
          matching: find.byType(TextField),
        ),
        'Production',
      );
      await tester.pump();
      await tester.tap(add);
      await tester.pumpAndSettle();

      expect(find.text('Production'), findsOneWidget);
      expect(find.byIcon(Icons.radio_button_checked), findsOneWidget);
    });

    testWidgets('tapping a saved server fills the URL only', (tester) async {
      final prefs = await _pump(tester);
      await tester.enterText(_urlField, _prod);
      await tester.pump();
      expect(find.byIcon(Icons.radio_button_checked), findsNothing);

      await tester.tap(find.text('Localhost'));
      await tester.pump();

      expect(_urlText(tester), defaultBaseUrl);
      expect(find.byIcon(Icons.radio_button_checked), findsOneWidget);
      expect(prefs.getString('base_url'), isNull);
    });

    testWidgets('deleting a server removes its row', (tester) async {
      await _pump(tester);
      await tester.tap(find.byTooltip('Delete Localhost'));
      await tester.pump();
      expect(find.text('Localhost'), findsNothing);
      expect(find.text('SAVED SERVERS'), findsNothing);
    });

    testWidgets('an empty URL cannot be added', (tester) async {
      await _pump(tester);
      await tester.enterText(_urlField, '   ');
      await tester.pump();
      final button = find.widgetWithText(TextButton, 'Add to saved');
      expect(tester.widget<TextButton>(button).onPressed, isNull);
    });
  });
}
