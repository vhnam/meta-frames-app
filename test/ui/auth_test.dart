import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:meta_frames/data/repositories/auth_repository.dart';
import 'package:meta_frames/data/services/api_client.dart';
import 'package:meta_frames/data/services/google_id_token.dart';
import 'package:meta_frames/data/services/session_store.dart';
import 'package:meta_frames/domain/auth_validators.dart';
import 'package:meta_frames/domain/models/models.dart';
import 'package:meta_frames/providers.dart';
import 'package:meta_frames/routing/router.dart';
import 'package:meta_frames/routing/routes.dart';
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
}) async {
  SharedPreferences.setMockInitialValues({});
  final prefs = await SharedPreferences.getInstance();
  final session = SessionStore(token);
  final auth = _FakeAuth(session);
  final container = ProviderContainer(
    overrides: [
      prefsProvider.overrideWithValue(prefs),
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

/// Taps Log out, at the end of a list that can be longer than the screen.
Future<void> _logOut(WidgetTester tester) async {
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
      await _pumpApp(tester, token: 'saved', google: google);
      await _tapAndSettle(tester, find.text('More'));
      await _logOut(tester);
      expect(google.signedOut, isTrue);
    });
  });

  group('signed-in user', () {
    Future<_Harness> openMore(WidgetTester tester) async {
      final app = await _pumpApp(tester, token: 'saved');
      await _tapAndSettle(tester, find.text('More'));
      return app;
    }

    testWidgets('More shows the account', (tester) async {
      await openMore(tester);
      expect(find.text('Ansel'), findsOneWidget);
      expect(find.text('ansel@example.com'), findsOneWidget);
    });

    testWidgets('logging out returns to login', (tester) async {
      final app = await openMore(tester);
      await _logOut(tester);
      expect(app.auth.loggedOut, isTrue);
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
      await tester.enterText(
        find.byType(TextField).first,
        'https://other.example',
      );
      await _tapAndSettle(tester, find.text('Save'));
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
