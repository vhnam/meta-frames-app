import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:meta_frames/data/repositories/settings_repository.dart';
import 'package:meta_frames/data/repositories/settings_repository_prefs.dart';
import 'package:meta_frames/providers.dart';
import 'package:meta_frames/ui/more/view_models/settings_actions.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  test('only absolute http(s) addresses with a host are accepted', () {
    expect(
      validDashboardUrl(' https://dash.example.com/ '),
      'https://dash.example.com',
    );
    expect(
      validDashboardUrl('http://192.168.1.4:5173'),
      'http://192.168.1.4:5173',
    );
    for (final bad in [
      'dash.example.com',
      'ftp://dash.example.com',
      'javascript:alert(1)',
      'https://',
      'https://user:pass@dash.example.com',
    ]) {
      expect(validDashboardUrl(bad), isNull, reason: bad);
    }
  });

  test('each server keeps its own dashboard', () async {
    SharedPreferences.setMockInitialValues({});
    final settings = SettingsRepositoryPrefs(
      await SharedPreferences.getInstance(),
    );
    await settings.setDashboardUrl('http://api-a/', 'https://dash-a');
    await settings.setDashboardUrl('http://api-b', 'https://dash-b');
    expect(settings.dashboardUrl('http://api-a'), 'https://dash-a');
    expect(settings.dashboardUrl('http://api-b/'), 'https://dash-b');
    expect(settings.dashboardUrl('http://api-c'), isNull);
    expect(
      () => settings.setDashboardUrl('http://api-a', 'not a url'),
      throwsFormatException,
    );
    await settings.setDashboardUrl('http://api-a', null);
    expect(settings.dashboardUrl('http://api-a'), isNull);
    expect(settings.dashboardUrl('http://api-b'), 'https://dash-b');
  });

  group('opening the dashboard', () {
    Future<(ProviderContainer, List<Uri>)> app({
      Future<bool> Function(Uri uri)? open,
    }) async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final opened = <Uri>[];
      final container = ProviderContainer(
        overrides: [
          prefsProvider.overrideWithValue(prefs),
          urlOpenerProvider.overrideWithValue((uri) {
            opened.add(uri);
            return open == null ? Future.value(true) : open(uri);
          }),
        ],
      );
      addTearDown(container.dispose);
      final actions = container.read(settingsActionsProvider);
      await actions.setDashboardUrl('http://api-a', 'https://dash-a/');
      await actions.setDashboardUrl('http://api-b', 'http://10.0.2.2:5173');
      return (container, opened);
    }

    test('the dashboard of the server in use is opened', () async {
      final (container, opened) = await app();
      final actions = container.read(settingsActionsProvider);
      await actions.saveBaseUrl('http://api-a');
      expect(await actions.openDashboard(), isTrue);
      await actions.saveBaseUrl('http://api-b');
      expect(await actions.openDashboard(), isTrue);
      expect(opened, [
        Uri.parse('https://dash-a'),
        Uri.parse('http://10.0.2.2:5173'),
      ]);
    });

    test('a server with no dashboard opens nothing', () async {
      final (container, opened) = await app();
      final actions = container.read(settingsActionsProvider);
      await actions.saveBaseUrl('http://api-c');
      expect(await actions.openDashboard(), isFalse);
      expect(opened, isEmpty);
    });

    test('a browser that cannot open it, or fails, is a false', () async {
      for (final open in <Future<bool> Function(Uri)>[
        (_) async => false,
        (_) async => throw StateError('no browser'),
      ]) {
        final (container, opened) = await app(open: open);
        final actions = container.read(settingsActionsProvider);
        await actions.saveBaseUrl('http://api-a');
        expect(await actions.openDashboard(), isFalse);
        expect(opened, hasLength(1));
      }
    });
  });
}
