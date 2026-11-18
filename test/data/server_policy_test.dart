import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:meta_frames/data/repositories/settings_repository.dart';
import 'package:meta_frames/data/services/server_policy.dart';
import 'package:meta_frames/data/services/session_store.dart';
import 'package:meta_frames/providers.dart';
import 'package:meta_frames/ui/more/view_models/settings_actions.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  group('parseFixedOrigin', () {
    test('accepts an HTTPS origin and keeps its spelling', () {
      const accepted = {
        'https://api.example.com': 'https://api.example.com',
        ' https://api.example.com// ': 'https://api.example.com',
        'https://API.example.com:443': 'https://API.example.com:443',
        'https://api.example.com:8443': 'https://api.example.com:8443',
        'https://192.168.1.4:8443': 'https://192.168.1.4:8443',
        'https://[2001:db8::1]:8443': 'https://[2001:db8::1]:8443',
        'https://localhost:1': 'https://localhost:1',
        'https://localhost:65535': 'https://localhost:65535',
        'https://API.example.com.:443': 'https://API.example.com.:443',
        'https://xn--bcher-kva.example': 'https://xn--bcher-kva.example',
      };
      final longestLabel = 'a' * 63;
      expect(
        parseFixedOrigin('https://$longestLabel.example.com'),
        'https://$longestLabel.example.com',
      );
      accepted.forEach((raw, origin) {
        expect(parseFixedOrigin(raw), origin, reason: raw);
      });
    });

    test('refuses anything but an HTTPS origin', () {
      final refused = [
        '',
        '   ',
        'api.example.com',
        'http://api.example.com',
        'ftp://api.example.com',
        'https://',
        'https:///path',
        'https:api.example.com',
        'https://user:secret@api.example.com',
        'https://user@api.example.com',
        'https://api.example.com/v1',
        'https://api.example.com/v1/',
        'https://api.example.com?debug=1',
        'https://api.example.com/?debug=1',
        'https://api.example.com#top',
        'https://api.example.com:',
        'https://api.example.com:0',
        'https://api.example.com:65536',
        'https://api.example.com:99999999999999999999',
        'https://api.example.com:abc',
        'https://api example.com',
        'https://api%20example.com',
        'https://-',
        'https://[2001:db8::1',
        'https://api..example.com',
        'https://.example.com',
        'https://api.-example.com',
        'https://api-.example.com',
        'https://api.example.com..',
        'https://.',
        'https://${'a' * 64}.example.com',
        'https://${List.filled(64, 'abc').join('.')}',
        'https://999.1.1.1',
        'https://1.2.3',
        'https://192.168.1.4.:8443',
      ];
      for (final raw in refused) {
        expect(parseFixedOrigin(raw), isNull, reason: raw);
      }
    });

    test('two spellings of one host stay two identities', () {
      expect(
        parseFixedOrigin('https://API.example.com:443'),
        isNot(parseFixedOrigin('https://api.example.com')),
      );
    });
  });

  group('ServerPolicy.resolve', () {
    test('debug ignores a define that is present', () {
      expect(
        ServerPolicy.resolve(debug: true, define: 'https://api.example.com'),
        isA<DebugServers>(),
      );
    });

    test('a non-debug build uses its valid define', () {
      final policy = ServerPolicy.resolve(
        debug: false,
        define: 'https://api.example.com/',
      );
      expect((policy as FixedServer).url, 'https://api.example.com');
    });

    test('a non-debug build without a usable define is invalid', () {
      for (final define in ['', 'http://api.example.com', 'not a url']) {
        expect(
          ServerPolicy.resolve(debug: false, define: define),
          isA<InvalidServerBuild>(),
          reason: define,
        );
      }
    });
  });

  group('SettingsActions', () {
    const stored = 'http://nas';
    const fixed = 'https://api.example.com';

    Future<({ProviderContainer container, SharedPreferences prefs})> pump(
      ServerPolicy policy,
      SessionStore session, {
      bool partitionsOff = false,
    }) async {
      SharedPreferences.setMockInitialValues({'base_url': stored});
      final prefs = await SharedPreferences.getInstance();
      final container = ProviderContainer(
        overrides: [
          prefsProvider.overrideWithValue(prefs),
          serverPolicyProvider.overrideWithValue(policy),
          sessionStoreProvider.overrideWithValue(session),
          // A refused change must stop before it looks at any kept data.
          if (partitionsOff)
            localStoreProvider.overrideWith(
              (_) => throw UnsupportedError('partition read'),
            ),
        ],
      );
      addTearDown(container.dispose);
      return (container: container, prefs: prefs);
    }

    test('a fixed server refuses a change and changes nothing', () async {
      final session = SessionStore('token');
      final app = await pump(
        const FixedServer(fixed),
        session,
        partitionsOff: true,
      );
      final actions = app.container.read(settingsActionsProvider);

      expect(actions.canChooseServer, isFalse);
      expect(actions.baseUrl, fixed);
      await expectLater(
        actions.saveBaseUrl('https://other.example', discardKept: true),
        throwsStateError,
      );

      expect(session.token, 'token');
      expect(app.prefs.getString('base_url'), stored);
      expect(actions.baseUrl, fixed);
    });

    test('debug still switches server and ends the session', () async {
      final session = SessionStore('token');
      final app = await pump(const DebugServers(), session);
      final actions = app.container.read(settingsActionsProvider);

      expect(actions.canChooseServer, isTrue);
      expect(actions.baseUrl, stored);
      await actions.saveBaseUrl('https://other.example/');

      expect(session.token, isNull);
      expect(app.prefs.getString('base_url'), 'https://other.example');
      expect(
        app.container.read(settingsRepositoryProvider).baseUrl,
        normalizeBaseUrl('https://other.example/'),
      );
    });

    test('the app never runs on an invalid build', () async {
      final app = await pump(const InvalidServerBuild(), SessionStore());
      expect(
        () => app.container.read(settingsRepositoryProvider),
        throwsA(anything),
      );
    });
  });
}
