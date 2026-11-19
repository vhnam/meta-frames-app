import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:meta_frames/data/repositories/settings_repository.dart';
import 'package:meta_frames/data/repositories/settings_repository_prefs.dart';
import 'package:meta_frames/data/services/server_policy.dart';
import 'package:meta_frames/data/services/session_store.dart';
import 'package:meta_frames/ui/core/theme.dart';
import 'package:meta_frames/ui/more/view_models/settings_actions.dart';
import 'package:meta_frames/domain/models/saved_server.dart';
import 'package:meta_frames/providers.dart';
import 'package:meta_frames/routing/routes.dart';
import 'package:meta_frames/ui/more/widgets/settings_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _prod = 'https://api.example.com';

Future<SharedPreferences> _prefs() async {
  SharedPreferences.setMockInitialValues({});
  return SharedPreferences.getInstance();
}

Future<SharedPreferences> _pump(
  WidgetTester tester, {
  Map<String, Object> values = const {},
  double textScale = 1,
  Future<void> Function(SettingsRepositoryPrefs repo)? seed,
  SessionStore? session,
  ServerPolicy? policy,
  ThemeData? theme,
}) async {
  SharedPreferences.setMockInitialValues(values);
  final prefs = await SharedPreferences.getInstance();
  await seed?.call(SettingsRepositoryPrefs(prefs));
  final router = GoRouter(
    routes: [
      GoRoute(path: '/', builder: (_, _) => const SettingsScreen()),
      GoRoute(path: Routes.login, builder: (_, _) => const SizedBox()),
      GoRoute(path: Routes.shooting, builder: (_, _) => const SizedBox()),
    ],
  );
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        prefsProvider.overrideWithValue(prefs),
        if (policy != null) serverPolicyProvider.overrideWithValue(policy),
        if (session != null) sessionStoreProvider.overrideWithValue(session),
      ],
      child: MaterialApp.router(
        routerConfig: router,
        theme: theme,
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context)
              .copyWith(textScaler: TextScaler.linear(textScale)),
          child: child!,
        ),
      ),
    ),
  );
  return prefs;
}

List<String> _urls(SharedPreferences prefs) =>
    SettingsRepositoryPrefs(prefs).servers.map((server) => server.url).toList();

Finder get _dialog => find.byType(AlertDialog);
Finder get _dialogFields =>
    find.descendant(of: _dialog, matching: find.byType(TextField));

Future<void> _pickDarkTheme(WidgetTester tester) async {
  await tester.tap(find.widgetWithText(ListTile, 'Theme'));
  await tester.pumpAndSettle();
  await tester.tap(find.widgetWithText(ListTile, 'Dark'));
  await tester.pumpAndSettle();
}

Future<Finder> _revealSave(WidgetTester tester) async {
  final save = find.widgetWithText(TextButton, 'Save');
  await tester.scrollUntilVisible(save, 100);
  await tester.pumpAndSettle();
  return save;
}

Future<void> _openAdd(WidgetTester tester) async {
  await tester.tap(find.text('Add server'));
  await tester.pumpAndSettle();
}

Future<void> _fillAndAdd(WidgetTester tester, String name, String url) async {
  await tester.enterText(_dialogFields.at(0), name);
  await tester.enterText(_dialogFields.at(1), url);
  await tester.pump();
  await tester.tap(find.widgetWithText(TextButton, 'Add'));
  await tester.pumpAndSettle();
}

void main() {
  group('SettingsScreen under each server policy', () {
    const fixed = FixedServer('https://api.example.com');

    for (final policy in [fixed, const InvalidServerBuild()]) {
      testWidgets('$policy shows no server controls', (tester) async {
        await _pump(tester, policy: policy);
        expect(find.widgetWithText(ListTile, 'Theme'), findsOneWidget);
        expect(find.widgetWithText(TextButton, 'Save'), findsNothing);
        expect(find.byIcon(Icons.add), findsNothing);
        expect(find.byIcon(Icons.radio_button_checked), findsNothing);
      });
    }

    testWidgets('fixed Appearance ignores a malformed saved server list', (
      tester,
    ) async {
      const malformed = '{broken';
      final prefs = await _pump(
        tester,
        policy: fixed,
        values: {'saved_servers': malformed},
      );

      expect(tester.takeException(), isNull);
      await _pickDarkTheme(tester);
      expect(prefs.getString('theme_mode'), 'dark');
      expect(prefs.getString('saved_servers'), malformed);
    });

    testWidgets('a debug build shows the server controls', (tester) async {
      await _pump(tester, policy: const DebugServers());
      final save = find.widgetWithText(TextButton, 'Save');
      expect(save, findsOneWidget);
      expect(
        find.descendant(of: find.byType(AppBar), matching: save),
        findsNothing,
      );
      expect(tester.getSize(save).width, greaterThanOrEqualTo(48));
      expect(tester.getSize(save).height, greaterThanOrEqualTo(48));
      expect(find.byIcon(Icons.add), findsOneWidget);
    });

    for (final (name, policy) in [
      ('a fixed server', fixed as ServerPolicy),
      ('a debug build', const DebugServers() as ServerPolicy),
    ]) {
      testWidgets('$name keeps the theme choice and no server data', (
        tester,
      ) async {
        final prefs = await _pump(tester, policy: policy);
        await _pickDarkTheme(tester);
        expect(prefs.getString('theme_mode'), 'dark');
        expect(prefs.getKeys(), {'theme_mode'});
      });
    }

    testWidgets('a fixed server refuses a change of server', (tester) async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final container = ProviderContainer(
        overrides: [
          prefsProvider.overrideWithValue(prefs),
          serverPolicyProvider.overrideWithValue(fixed),
        ],
      );
      addTearDown(container.dispose);
      final actions = container.read(settingsActionsProvider);
      expect(actions.canChooseServer, isFalse);
      await expectLater(
        actions.saveBaseUrl('https://other.example.com'),
        throwsStateError,
      );
      expect(actions.baseUrl, 'https://api.example.com');
    });
  });

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
    testWidgets('Add stores the normalized URL, selects it, keeps base_url', (
      tester,
    ) async {
      final prefs = await _pump(tester);
      await _openAdd(tester);
      await _fillAndAdd(tester, 'Production', '$_prod/');

      expect(_urls(prefs), contains(_prod));
      expect(prefs.getString('base_url'), isNull);
      expect(find.byIcon(Icons.radio_button_checked), findsOneWidget);
      await tester.tap(await _revealSave(tester));
      await tester.pumpAndSettle();
      expect(prefs.getString('base_url'), _prod);
    });

    testWidgets('an invalid URL keeps the dialog open and saves nothing', (
      tester,
    ) async {
      final prefs = await _pump(tester);
      await _openAdd(tester);
      await _fillAndAdd(tester, 'Bad', 'ftp://example.com');

      expect(_dialog, findsOneWidget);
      expect(_urls(prefs), [defaultBaseUrl]);
    });

    testWidgets('a row changes the selection; Save writes base_url', (
      tester,
    ) async {
      final prefs = await _pump(
        tester,
        seed: (repo) =>
            repo.saveServer(const SavedServer(name: 'Production', url: _prod)),
      );
      await tester.tap(find.text('Production'));
      await tester.pump();
      expect(prefs.getString('base_url'), isNull);

      await tester.tap(await _revealSave(tester));
      await tester.pumpAndSettle();
      expect(SettingsRepositoryPrefs(prefs).baseUrl, _prod);
    });

    testWidgets('delete asks first; cancel keeps the server', (tester) async {
      final prefs = await _pump(tester);
      await tester.tap(find.byTooltip('Delete Localhost'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();
      expect(_urls(prefs), [defaultBaseUrl]);

      await tester.tap(find.byTooltip('Delete Localhost'));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(FilledButton, 'Delete'));
      await tester.pumpAndSettle();
      expect(_urls(prefs), isEmpty);
    });

    testWidgets('Add server works after every server is deleted', (
      tester,
    ) async {
      final prefs = await _pump(
        tester,
        seed: (repo) => repo.deleteServer(defaultBaseUrl),
      );
      await _openAdd(tester);
      await _fillAndAdd(tester, 'Production', _prod);
      expect(_urls(prefs), [_prod]);
    });

    testWidgets('an unsaved active URL shows a row that Save adds', (
      tester,
    ) async {
      final prefs = await _pump(tester, values: {'base_url': _prod});
      expect(find.text('Unsaved server'), findsOneWidget);
      expect(find.byTooltip('Delete Unsaved server'), findsNothing);

      await tester.tap(find.widgetWithText(TextButton, 'Add to saved'));
      await tester.pumpAndSettle();
      expect(
        tester.widget<TextField>(_dialogFields.at(1)).controller!.text,
        _prod,
      );
      await tester.enterText(_dialogFields.at(0), 'Production');
      await tester.pump();
      await tester.tap(find.widgetWithText(TextButton, 'Add'));
      await tester.pumpAndSettle();

      expect(_urls(prefs), contains(_prod));
      expect(find.text('Unsaved server'), findsNothing);
    });

    testWidgets('adding the active URL as typed keeps it and the session', (
      tester,
    ) async {
      const active = 'https://API.example.com:443';
      final session = SessionStore('token');
      final prefs = await _pump(
        tester,
        values: {'base_url': active},
        session: session,
      );
      await tester.tap(find.widgetWithText(TextButton, 'Add to saved'));
      await tester.pumpAndSettle();
      await tester.enterText(_dialogFields.at(0), 'Mine');
      await tester.pump();
      await tester.tap(find.widgetWithText(TextButton, 'Add'));
      await tester.pumpAndSettle();
      await tester.tap(await _revealSave(tester));
      await tester.pumpAndSettle();

      expect(SettingsRepositoryPrefs(prefs).baseUrl, active);
      expect(session.signedIn, isTrue);
    });

    testWidgets('deleting the selected server returns to the active one', (
      tester,
    ) async {
      final prefs = await _pump(
        tester,
        seed: (repo) =>
            repo.saveServer(const SavedServer(name: 'Production', url: _prod)),
      );
      await tester.tap(find.text('Production'));
      await tester.pump();
      await tester.tap(find.byTooltip('Delete Production'));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(FilledButton, 'Delete'));
      await tester.pumpAndSettle();
      await tester.tap(await _revealSave(tester));
      await tester.pumpAndSettle();

      expect(SettingsRepositoryPrefs(prefs).baseUrl, defaultBaseUrl);
    });

    testWidgets('a URL that is already saved keeps its name', (tester) async {
      final prefs = await _pump(
        tester,
        seed: (repo) => repo.saveServer(
          const SavedServer(name: 'Production', url: 'https://api.example.com'),
        ),
      );
      await _openAdd(tester);
      await _fillAndAdd(tester, 'Replacement', 'https://API.example.com:443/');

      expect(_dialog, findsOneWidget);
      final servers = SettingsRepositoryPrefs(prefs).servers;
      expect(servers.map((server) => server.name), ['Localhost', 'Production']);
    });

    testWidgets('each dialog field keeps its name on the editable node', (
      tester,
    ) async {
      final handle = tester.ensureSemantics();
      await _pump(tester);
      await _openAdd(tester);
      await tester.enterText(_dialogFields.at(0), 'Production');
      await tester.enterText(_dialogFields.at(1), _prod);
      await tester.pump();

      final editable = find.descendant(
        of: _dialog,
        matching: find.byType(EditableText),
      );
      // The focused field's label also carries its hint on the next line.
      String nameOf(int index) =>
          tester.getSemantics(editable.at(index)).label.split('\n').first;
      expect(nameOf(0), 'Name');
      expect(nameOf(1), 'Server URL');
      // Each name is announced once: no separate heading node beside the field.
      for (final name in ['name', 'server url']) {
        expect(
          find.descendant(
            of: _dialog,
            matching: find.bySemanticsLabel(
              RegExp('^$name(\\n|\$)', caseSensitive: false),
            ),
          ),
          findsOneWidget,
          reason: name,
        );
      }
      handle.dispose();
    });

    testWidgets('320 wide at 2x text raises no overflow', (tester) async {
      tester.view.physicalSize = const Size(320, 640);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await _pump(
        tester,
        values: {'base_url': 'https://a-long-host.example.com/with/a/path'},
        textScale: 2,
      );
      expect(tester.takeException(), isNull);
      await _openAdd(tester);
      expect(tester.takeException(), isNull);
    });

    for (final brightness in Brightness.values) {
      testWidgets(
        'Add server and Save work at 2x on a narrow $brightness screen',
        (tester) async {
          tester.view.physicalSize = const Size(320, 640);
          tester.view.devicePixelRatio = 1;
          addTearDown(tester.view.reset);
          final prefs = await _pump(
            tester,
            textScale: 2,
            theme: buildTheme(brightness),
          );
          await _openAdd(tester);
          await _fillAndAdd(tester, 'Production', _prod);
          expect(_urls(prefs), contains(_prod));
          expect(prefs.getString('base_url'), isNull);

          final save = await _revealSave(tester);
          expect(tester.getSize(save).width, greaterThanOrEqualTo(48));
          expect(tester.getSize(save).height, greaterThanOrEqualTo(48));
          await tester.tap(save);
          await tester.pumpAndSettle();
          expect(prefs.getString('base_url'), _prod);
          expect(tester.takeException(), isNull);
        },
      );
    }
  });
}
