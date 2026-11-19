import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:go_router/go_router.dart';
import 'package:meta_frames/data/repositories/auth_repository.dart';
import 'package:meta_frames/data/services/api_client.dart';
import 'package:meta_frames/data/services/google_id_token.dart';
import 'package:meta_frames/data/services/server_policy.dart';
import 'package:meta_frames/data/services/session_store.dart';
import 'package:meta_frames/domain/auth_validators.dart';
import 'package:meta_frames/domain/models/models.dart';
import 'package:meta_frames/providers.dart';
import 'package:meta_frames/routing/router.dart';
import 'package:meta_frames/routing/routes.dart';
import 'package:meta_frames/ui/core/widgets/common.dart';
import 'package:meta_frames/ui/more/view_models/settings_actions.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../testing/fakes.dart';

/// Signs in the way the real API client does: by storing the session token.
class _FakeAuth implements AuthRepository {
  _FakeAuth(this.session);
  final SessionStore session;
  String? registeredName, googleToken;
  bool logoutFails = false;
  bool googleNotConfigured = false;
  bool loggedOut = false;

  @override
  Future<User> me() async => User.fromJson({
    'id': 'u1',
    'email': 'ansel@example.com',
    'name': 'Ansel',
  });

  @override
  Future<void> login({required String email, required String password}) async {
    if (password == 'offline') {
      throw ApiException(0, 'network', 'Cannot reach the server.');
    }
    if (password != 'right') {
      throw ApiException(401, 'invalid_credentials', 'Invalid Credentials');
    }
    await session.setToken('token');
  }

  @override
  Future<String> googleServerClientId() async {
    if (googleNotConfigured) {
      throw ApiException(
        404,
        'not_configured',
        'sign-in with Google is not configured',
      );
    }
    return 'web-client';
  }

  @override
  Future<void> loginWithGoogle(String idToken) async {
    googleToken = idToken;
    if (idToken == 'unverified') {
      throw ApiException(
        403,
        'email_not_verified',
        'Your Google email address is not verified.',
      );
    }
    await session.setToken('token');
  }

  @override
  Future<void> register({
    required String email,
    required String password,
    String? name,
  }) async {
    registeredName = name;
    await session.setToken('token');
  }

  @override
  Future<void> logout() async {
    loggedOut = true;
    if (logoutFails) throw ApiException(0, 'network', 'Cannot reach');
    await session.setToken(null);
  }

  @override
  Future<String> recover(String email) async => 'Check your inbox.';
}

class _FakeGoogle implements GoogleIdTokenSource {
  _FakeGoogle({this.available = true, this.token = 'id-token'});
  @override
  final bool available;
  final String? token;
  bool signedOut = false;
  String? requestedFor;

  @override
  Future<String?> idToken({required String serverClientId}) async {
    requestedFor = serverClientId;
    return token;
  }

  @override
  Future<void> signOut() async => signedOut = true;
}

class _Harness {
  _Harness(this.container, this.session, this.auth);
  final ProviderContainer container;
  final SessionStore session;
  final _FakeAuth auth;
  GoRouter get router => container.read(routerProvider);
  String get location =>
      router.routerDelegate.currentConfiguration.last.matchedLocation;
}

Future<_Harness> _pumpApp(
  WidgetTester tester, {
  String? token,
  _FakeGoogle? google,
  ServerPolicy? policy,
}) async {
  SharedPreferences.setMockInitialValues({});
  final prefs = await SharedPreferences.getInstance();
  final session = SessionStore(token);
  final auth = _FakeAuth(session);
  final container = ProviderContainer(
    overrides: [
      prefsProvider.overrideWithValue(prefs),
      if (policy != null) serverPolicyProvider.overrideWithValue(policy),
      sessionStoreProvider.overrideWithValue(session),
      authRepositoryProvider.overrideWithValue(auth),
      googleIdTokenSourceProvider.overrideWithValue(
        google ?? _FakeGoogle(available: false),
      ),
      rollRepositoryProvider.overrideWithValue(FakeRollRepository()),
      cameraRepositoryProvider.overrideWithValue(FakeCameraRepository()),
      lensRepositoryProvider.overrideWithValue(FakeLensRepository()),
      filmStockRepositoryProvider.overrideWithValue(FakeFilmStockRepository()),
      processingRepositoryProvider.overrideWithValue(
        FakeProcessingRepository(),
      ),
    ],
  );
  addTearDown(container.dispose);
  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: container,
      child: Consumer(
        builder: (_, ref, _) =>
            MaterialApp.router(routerConfig: ref.watch(routerProvider)),
      ),
    ),
  );
  await tester.pumpAndSettle();
  return _Harness(container, session, auth);
}

Future<void> _enter(WidgetTester tester, String hint, String text) =>
    tester.enterText(find.widgetWithText(TextFormField, hint), text);

/// Opens Settings from More and taps Log out.
Future<void> _logOut(WidgetTester tester) async {
  await _tapAndSettle(tester, find.text('Settings'));
  await tester.scrollUntilVisible(find.text('Log out'), 100);
  await _tapAndSettle(tester, find.text('Log out'));
}

Future<void> _tapAndSettle(WidgetTester tester, Finder finder) async {
  // A lazy list builds only what is near the screen.
  if (finder.evaluate().isEmpty) {
    await tester.scrollUntilVisible(finder, 200);
  }
  await tester.ensureVisible(finder);
  await tester.pumpAndSettle();
  await tester.tap(finder);
  await tester.pumpAndSettle();
}

void main() {
  group('authRedirect', () {
    String? check(bool signedIn, String location) =>
        authRedirect(signedIn: signedIn, location: location);

    test('a visitor goes to login from anywhere but signed-out screens', () {
      expect(check(false, Routes.shooting), Routes.login);
      expect(check(false, Routes.camera('c1')), Routes.login);
      expect(check(false, Routes.login), isNull);
      expect(check(false, Routes.register), isNull);
      expect(check(false, Routes.recover), isNull);
    });

    test('a signed-in user leaves the signed-out screens', () {
      expect(check(true, Routes.login), Routes.shooting);
      expect(check(true, Routes.register), Routes.shooting);
      expect(check(true, Routes.recover), Routes.shooting);
      expect(check(true, Routes.shooting), isNull);
    });

    test('settings is open to both', () {
      expect(check(false, Routes.settings), isNull);
      expect(check(true, Routes.settings), isNull);
    });
  });

  group('AuthValidators.newPassword', () {
    test('enforces the server rule', () {
      expect(AuthValidators.newPassword(''), 'Password is required.');
      expect(AuthValidators.newPassword('Aa1!'), 'Use at least 8 characters.');
      expect(
        AuthValidators.newPassword('aaaaaaa1!'),
        'Add an upper-case letter.',
      );
      expect(
        AuthValidators.newPassword('AAAAAAA1!'),
        'Add a lower-case letter.',
      );
      expect(AuthValidators.newPassword('Aaaaaaaa!'), 'Add a digit.');
      expect(AuthValidators.newPassword('Aaaaaaa11'), 'Add a symbol.');
      expect(AuthValidators.newPassword('Aaaaaaa1!'), isNull);
    });
  });

  group('AuthValidators.email', () {
    test('trims and checks the shape', () {
      expect(AuthValidators.email('  '), 'Email is required.');
      expect(AuthValidators.email('nope'), 'Enter a valid email address.');
      expect(AuthValidators.email(' a@b.co '), isNull);
    });
  });

  group('sign-in flow', () {
    testWidgets('a visitor opens on the login screen', (tester) async {
      final app = await _pumpApp(tester);
      expect(app.location, Routes.login);
      expect(find.text('Sign in to MetaFrames'), findsOneWidget);
      expect(find.byType(NavigationBar), findsNothing);
    });

    testWidgets('a saved session opens the app', (tester) async {
      final app = await _pumpApp(tester, token: 'saved');
      expect(app.location, Routes.shooting);
      expect(find.byType(NavigationBar), findsOneWidget);
    });

    testWidgets('empty fields show errors and do not submit', (tester) async {
      final app = await _pumpApp(tester);
      await _tapAndSettle(tester, find.text('Log in'));
      expect(find.text('Email is required.'), findsOneWidget);
      expect(find.text('Password is required.'), findsOneWidget);
      expect(app.session.signedIn, isFalse);
    });

    testWidgets('wrong credentials show the server message', (tester) async {
      final app = await _pumpApp(tester);
      await _enter(tester, 'you@example.com', 'a@b.co');
      await _enter(tester, 'Enter your password', 'wrong');
      await _tapAndSettle(tester, find.text('Log in'));
      expect(find.text('Invalid Credentials'), findsOneWidget);
      expect(find.text('Server settings'), findsNothing);
      expect(app.location, Routes.login);
    });

    testWidgets('a correct login opens the app', (tester) async {
      final app = await _pumpApp(tester);
      await _enter(tester, 'you@example.com', 'a@b.co');
      await _enter(tester, 'Enter your password', 'right');
      await _tapAndSettle(tester, find.text('Log in'));
      expect(app.location, Routes.shooting);
      expect(find.byType(NavigationBar), findsOneWidget);
    });

    testWidgets('registering checks the fields and opens the app', (
      tester,
    ) async {
      final app = await _pumpApp(tester);
      await _tapAndSettle(
        tester,
        find.text('New to the darkroom? Create an account'),
      );
      expect(app.location, Routes.register);

      await _enter(tester, 'e.g. Ansel Adams', ' Ansel ');
      await _enter(tester, 'you@example.com', 'a@b.co');
      await _enter(tester, 'At least 8 characters', 'Aaaaaaa1!');
      await _enter(tester, 'Repeat the password', 'different');
      await _tapAndSettle(tester, find.text('Create account'));
      expect(find.text('Passwords do not match.'), findsOneWidget);
      expect(app.session.signedIn, isFalse);

      await _enter(tester, 'Repeat the password', 'Aaaaaaa1!');
      await _tapAndSettle(tester, find.text('Create account'));
      expect(app.auth.registeredName, 'Ansel');
      expect(app.location, Routes.shooting);
    });

    testWidgets('recovery shows the server message', (tester) async {
      await _pumpApp(tester);
      await _tapAndSettle(tester, find.text('Forgot password?'));
      await _enter(tester, 'you@example.com', 'a@b.co');
      await _tapAndSettle(tester, find.text('Send reset link'));
      expect(find.textContaining('Check your inbox.'), findsOneWidget);
    });

    testWidgets('a connection error offers server settings', (tester) async {
      final app = await _pumpApp(tester);
      await _enter(tester, 'you@example.com', 'a@b.co');
      await _enter(tester, 'Enter your password', 'offline');
      await _tapAndSettle(tester, find.text('Log in'));
      expect(find.text('Cannot reach the server.'), findsOneWidget);

      await _tapAndSettle(tester, find.text('Server settings'));
      expect(app.location, Routes.settings);

      await _tapAndSettle(tester, find.text('Save'));
      expect(app.location, Routes.login);
      expect(find.text('Cannot reach the server.'), findsNothing);
    });

    testWidgets('one tap on the copyright does nothing', (tester) async {
      final app = await _pumpApp(tester);
      await tester.tap(find.text('© ${DateTime.now().year} MetaFrames'));
      await tester.pumpAndSettle();
      expect(app.location, Routes.login);
    });

    testWidgets('a visitor can reach settings and return to login', (
      tester,
    ) async {
      final app = await _pumpApp(tester);
      expect(find.byTooltip('Server settings'), findsNothing);
      final copyright = find.text('© ${DateTime.now().year} MetaFrames');
      await tester.tap(copyright);
      await tester.pump(const Duration(milliseconds: 50));
      await tester.tap(copyright);
      await tester.pumpAndSettle();
      expect(app.location, Routes.settings);
      await _tapAndSettle(tester, find.text('Save'));
      expect(app.location, Routes.login);
    });
  });

  group('a build with a fixed server', () {
    const fixed = FixedServer('https://api.example.com');

    Future<void> failToLogIn(WidgetTester tester) async {
      await _enter(tester, 'you@example.com', 'a@b.co');
      await _enter(tester, 'Enter your password', 'offline');
      await _tapAndSettle(tester, find.text('Log in'));
    }

    testWidgets('a connection error on login has no link to settings', (
      tester,
    ) async {
      await _pumpApp(tester, policy: fixed);
      await failToLogIn(tester);
      expect(find.text('Cannot reach the server.'), findsOneWidget);
      expect(find.byKey(serverSettingsLinkKey), findsNothing);
    });

    testWidgets('a double tap on the copyright stays on login', (tester) async {
      final app = await _pumpApp(tester, policy: fixed);
      final copyright = find.text('© ${DateTime.now().year} MetaFrames');
      await tester.tap(copyright);
      await tester.pump(const Duration(milliseconds: 50));
      await tester.tap(copyright);
      await tester.pumpAndSettle();
      expect(app.location, Routes.login);
    });

    testWidgets('a debug build keeps the link to settings', (tester) async {
      await _pumpApp(tester, policy: const DebugServers());
      await failToLogIn(tester);
      expect(find.byKey(serverSettingsLinkKey), findsOneWidget);
    });
  });

  group('connection failures in the app', () {
    final offline = ApiException(0, 'network', 'Cannot reach the server.');

    /// Pumps a screen with a button that runs [action] under [guard] and an
    /// async body that fails with [offline], under [policy].
    Future<({SessionStore session, List<bool> outcomes, List<int> refreshes})>
    pumpFailures(
      WidgetTester tester,
      ServerPolicy policy,
      Future<void> Function() action, {
      ValueNotifier<bool>? callerVisible,
    }) async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final session = SessionStore('token');
      final outcomes = <bool>[];
      final refreshes = <int>[];
      Widget caller() => Builder(
        builder: (context) => TextButton(
          onPressed: () async => outcomes.add(await guard(context, action)),
          child: const Text('Run'),
        ),
      );
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            prefsProvider.overrideWithValue(prefs),
            serverPolicyProvider.overrideWithValue(policy),
            sessionStoreProvider.overrideWithValue(session),
          ],
          child: MaterialApp(
            home: Scaffold(
              body: Column(
                children: [
                  if (callerVisible == null)
                    caller()
                  else
                    ValueListenableBuilder<bool>(
                      valueListenable: callerVisible,
                      builder: (_, visible, _) =>
                          visible ? caller() : const SizedBox.shrink(),
                    ),
                  Expanded(
                    child: AsyncBody<int>(
                      value: AsyncValue.error(offline, StackTrace.empty),
                      builder: (_) => const SizedBox(),
                      onRefresh: () async => refreshes.add(1),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
      return (session: session, outcomes: outcomes, refreshes: refreshes);
    }

    for (final (name, policy, linked) in [
      ('a debug build', const DebugServers() as ServerPolicy, true),
      (
        'a build with a fixed server',
        const FixedServer('https://api.example.com') as ServerPolicy,
        false,
      ),
    ]) {
      group(name, () {
        testWidgets('Retry runs the action again until it works', (
          tester,
        ) async {
          var calls = 0;
          final run = await pumpFailures(tester, policy, () async {
            if (++calls < 3) throw offline;
          });
          await _tapAndSettle(tester, find.text('Run'));
          expect(find.byType(AlertDialog), findsOneWidget);
          await _tapAndSettle(tester, find.text('Retry').last);
          expect(find.byType(AlertDialog), findsOneWidget);
          await _tapAndSettle(tester, find.text('Retry').last);
          expect(calls, 3);
          expect(run.outcomes, [true]);
          expect(find.byType(AlertDialog), findsNothing);
        });

        testWidgets('Cancel fails the action and keeps the session', (
          tester,
        ) async {
          final run = await pumpFailures(tester, policy, () async {
            throw offline;
          });
          await _tapAndSettle(tester, find.text('Run'));
          await _tapAndSettle(tester, find.text('Cancel'));
          expect(run.outcomes, [false]);
          expect(run.session.signedIn, isTrue);
        });

        testWidgets('links to settings only where the server can change', (
          tester,
        ) async {
          final run = await pumpFailures(tester, policy, () async {
            throw offline;
          });
          expect(
            find.byKey(serverSettingsLinkKey),
            linked ? findsOneWidget : findsNothing,
          );
          await _tapAndSettle(tester, find.text('Run'));
          expect(
            find.descendant(
              of: find.byType(AlertDialog),
              matching: find.byKey(serverSettingsLinkKey),
            ),
            linked ? findsOneWidget : findsNothing,
          );
          await _tapAndSettle(tester, find.text('Cancel'));
          // Retry on the error view asks for a refresh.
          await _tapAndSettle(tester, find.text('Retry'));
          expect(run.refreshes, [1]);
        });
      });
    }

    testWidgets('guard ignores a network failure after its caller unmounts', (
      tester,
    ) async {
      final action = Completer<void>();
      final run = await pumpFailures(
        tester,
        const FixedServer('https://api.example.com'),
        () => action.future,
      );
      await tester.tap(find.text('Run'));
      await tester.pumpWidget(const SizedBox.shrink());
      action.completeError(offline);
      await tester.pump();

      expect(run.outcomes, [false]);
      expect(tester.takeException(), isNull);
    });

    testWidgets('guard does not retry after its caller unmounts', (
      tester,
    ) async {
      final visible = ValueNotifier(true);
      addTearDown(visible.dispose);
      var calls = 0;
      final run = await pumpFailures(
        tester,
        const FixedServer('https://api.example.com'),
        () async {
          calls++;
          throw offline;
        },
        callerVisible: visible,
      );
      await _tapAndSettle(tester, find.text('Run'));
      visible.value = false;
      await tester.pump();
      await _tapAndSettle(
        tester,
        find.descendant(
          of: find.byType(AlertDialog),
          matching: find.text('Retry'),
        ),
      );

      expect(calls, 1);
      expect(run.outcomes, [false]);
      expect(tester.takeException(), isNull);
    });

    test('an unreachable fixed server is a connection failure only', () async {
      final session = SessionStore('token');
      final client = ApiClient(
        () => 'https://api.example.com',
        MockClient((_) async => throw http.ClientException('unreachable')),
        session,
      );
      await expectLater(
        client.send('GET', '/rolls'),
        throwsA(
          isA<ApiException>().having((e) => e.isNetwork, 'isNetwork', true),
        ),
      );
      expect(session.signedIn, isTrue);
    });
  });

  group('Google', () {
    const button = 'Continue with Google';

    testWidgets('the button is hidden when unavailable', (tester) async {
      await _pumpApp(tester);
      expect(find.text(button), findsNothing);
    });

    testWidgets('signing in sends the ID token and opens the app', (
      tester,
    ) async {
      final google = _FakeGoogle();
      final app = await _pumpApp(tester, google: google);
      await _tapAndSettle(tester, find.text(button));
      expect(google.requestedFor, 'web-client');
      expect(app.auth.googleToken, 'id-token');
      expect(app.location, Routes.shooting);
    });

    testWidgets('a server without Google shows its message', (tester) async {
      final google = _FakeGoogle();
      final app = await _pumpApp(tester, google: google);
      app.auth.googleNotConfigured = true;
      await _tapAndSettle(tester, find.text(button));
      expect(
        find.text('sign-in with Google is not configured'),
        findsOneWidget,
      );
      expect(google.requestedFor, isNull);
    });

    testWidgets('registering offers Google too', (tester) async {
      await _pumpApp(tester, google: _FakeGoogle());
      await _tapAndSettle(
        tester,
        find.text('New to the darkroom? Create an account'),
      );
      expect(find.text(button), findsOneWidget);
    });

    testWidgets('closing the picker stays on login without an error', (
      tester,
    ) async {
      final app = await _pumpApp(tester, google: _FakeGoogle(token: null));
      await _tapAndSettle(tester, find.text(button));
      expect(app.auth.googleToken, isNull);
      expect(app.location, Routes.login);
      expect(find.byIcon(Icons.warning_amber), findsNothing);
    });

    testWidgets('a server refusal shows its message', (tester) async {
      final app = await _pumpApp(
        tester,
        google: _FakeGoogle(token: 'unverified'),
      );
      await _tapAndSettle(tester, find.text(button));
      expect(
        find.text('Your Google email address is not verified.'),
        findsOneWidget,
      );
      expect(app.location, Routes.login);
    });

    testWidgets('logging out forgets the Google account', (tester) async {
      final google = _FakeGoogle();
      final app = await _pumpApp(tester, token: 'saved', google: google);
      await _tapAndSettle(tester, find.text('More'));
      await _logOut(tester);
      expect(google.signedOut, isTrue);
      expect(app.session.token, isNull);
      expect(app.location, Routes.login);
    });
  });

  group('signed-in user', () {
    Future<_Harness> openMore(WidgetTester tester) async {
      final app = await _pumpApp(tester, token: 'saved');
      await _tapAndSettle(tester, find.text('More'));
      return app;
    }

    testWidgets('the account is visible in Settings instead of More', (
      tester,
    ) async {
      await openMore(tester);
      expect(find.text('ansel@example.com'), findsNothing);
      await _tapAndSettle(tester, find.text('Settings'));
      expect(find.text('Ansel'), findsOneWidget);
      expect(find.text('ansel@example.com'), findsOneWidget);
    });

    testWidgets('logging out returns to login', (tester) async {
      final app = await openMore(tester);
      await _logOut(tester);
      expect(app.auth.loggedOut, isTrue);
      expect(app.session.token, isNull);
      expect(app.location, Routes.login);
    });

    testWidgets('logging out offline still ends the session here', (
      tester,
    ) async {
      final app = await openMore(tester);
      app.auth.logoutFails = true;
      await _logOut(tester);
      expect(app.session.signedIn, isFalse);
      expect(app.location, Routes.login);
    });

    testWidgets('an ended session returns to login', (tester) async {
      final app = await _pumpApp(tester, token: 'saved');
      await app.session.setToken(null);
      await tester.pumpAndSettle();
      expect(app.location, Routes.login);
    });

    testWidgets('a new server URL ends the session', (tester) async {
      final app = await openMore(tester);
      await _tapAndSettle(tester, find.text('Settings'));
      await _tapAndSettle(tester, find.text('Add server'));
      final fields = find.descendant(
        of: find.byType(AlertDialog),
        matching: find.byType(TextField),
      );
      await tester.enterText(fields.at(0), 'Other');
      await tester.enterText(fields.at(1), 'https://other.example');
      await tester.pump();
      await _tapAndSettle(tester, find.widgetWithText(TextButton, 'Add'));
      await _tapAndSettle(tester, find.widgetWithText(TextButton, 'Save'));
      expect(app.session.signedIn, isFalse);
      expect(app.location, Routes.login);
    });

    testWidgets('saving the same server URL keeps the session', (tester) async {
      final app = await openMore(tester);
      await _tapAndSettle(tester, find.text('Settings'));
      await _tapAndSettle(tester, find.text('Save'));
      expect(app.session.signedIn, isTrue);
      expect(app.location, Routes.more);
    });

    testWidgets('switching to a saved server ends the session', (tester) async {
      final app = await openMore(tester);
      final actions = app.container.read(settingsActionsProvider);
      await actions.saveServer('Production', 'https://other.example');
      await _tapAndSettle(tester, find.text('Settings'));
      await _tapAndSettle(tester, find.text('Production'));
      await _tapAndSettle(tester, find.text('Save'));
      expect(actions.baseUrl, 'https://other.example');
      expect(app.session.signedIn, isFalse);
      expect(app.location, Routes.login);
    });

    testWidgets('saveBaseUrl ignores a trailing slash', (tester) async {
      final app = await _pumpApp(tester, token: 'saved');
      final actions = app.container.read(settingsActionsProvider);
      await actions.saveBaseUrl('${actions.baseUrl}/');
      expect(app.session.signedIn, isTrue);
    });
  });
}
