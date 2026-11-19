import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:meta_frames/data/local/local_store.dart';
import 'package:meta_frames/data/repositories/auth_repository.dart';
import 'package:meta_frames/data/services/api_client.dart';
import 'package:meta_frames/data/services/google_id_token.dart';
import 'package:meta_frames/data/services/server_policy.dart';
import 'package:meta_frames/data/services/session_store.dart';
import 'package:meta_frames/domain/models/models.dart';
import 'package:meta_frames/providers.dart';
import 'package:meta_frames/routing/router.dart';
import 'package:meta_frames/routing/routes.dart';
import 'package:meta_frames/ui/more/widgets/settings_screen.dart';
import 'package:meta_frames/ui/sync/view_models/sync_actions.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../testing/local.dart';

class _Auth implements AuthRepository {
  Future<User> Function() profile = () async => _user('before');
  ApiException? logoutError;
  Future<void>? logoutResponse;
  int reads = 0;
  int logouts = 0;

  @override
  Future<User> me() {
    reads++;
    return profile();
  }

  @override
  Future<void> logout() async {
    logouts++;
    if (logoutError case final error?) throw error;
    await logoutResponse;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _Google implements GoogleIdTokenSource {
  @override
  bool get available => false;

  int signOuts = 0;

  @override
  Future<void> signOut() async {
    signOuts++;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _Store implements LocalStore {
  final countResult = Completer<({int open, int attention})>();
  int countReads = 0;

  @override
  final key = const PartitionKey(server, 'u1');

  @override
  final changes = ValueNotifier<int>(0);

  @override
  bool get isClosed => false;

  @override
  Future<({int open, int attention})> counts() {
    countReads++;
    return countResult.future;
  }

  @override
  Future<List<Draft>> drafts([DraftKind? kind]) async => [];

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

User _user(String name) =>
    User.fromJson({'id': 'u1', 'name': name, 'email': '$name@example.com'});

Future<
  ({ProviderContainer container, GoRouter router, _Auth auth, _Google google})
>
_open(
  WidgetTester tester,
  SessionStore session, {
  String location = Routes.settings,
  _Store? store,
}) async {
  SharedPreferences.setMockInitialValues({});
  final prefs = await SharedPreferences.getInstance();
  final auth = _Auth();
  final google = _Google();
  final router = buildRouter(initialLocation: location, session: session);
  final container = ProviderContainer.test(
    retry: (_, _) => null,
    overrides: [
      prefsProvider.overrideWithValue(prefs),
      serverPolicyProvider.overrideWithValue(const DebugServers()),
      sessionStoreProvider.overrideWithValue(session),
      localStoreProvider.overrideWithValue(store),
      syncStatusProvider.overrideWithValue(null),
      if (store != null) openOpsProvider.overrideWith((_) async => []),
      partitionsProvider.overrideWith((_) async => []),
      authRepositoryProvider.overrideWithValue(auth),
      googleIdTokenSourceProvider.overrideWithValue(google),
    ],
  );
  addTearDown(router.dispose);
  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: container,
      child: MaterialApp.router(routerConfig: router),
    ),
  );
  await tester.pumpAndSettle();
  return (container: container, router: router, auth: auth, google: google);
}

Future<void> _logout(WidgetTester tester) async {
  final target = find.text('Log out');
  await tester.scrollUntilVisible(
    target,
    120,
    scrollable: find.byType(Scrollable).last,
  );
  await tester.tap(target);
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('signed-out settings never requests the account profile', (
    tester,
  ) async {
    final session = SessionStore();
    addTearDown(session.dispose);
    final app = await _open(tester, session);
    expect(app.auth.reads, 0);
    expect(find.byType(SettingsScreen), findsOneWidget);
  });

  for (final pushed in [false, true]) {
    testWidgets(
      'ending the session removes private settings data (pushed: $pushed)',
      (tester) async {
        final session = await boundSession();
        addTearDown(session.dispose);
        final app = await _open(
          tester,
          session,
          location: pushed ? Routes.more : Routes.settings,
        );
        if (pushed) {
          unawaited(app.router.push<void>(Routes.settings));
          await tester.pumpAndSettle();
        }
        expect(find.text('before@example.com'), findsOneWidget);
        final requests = app.auth.reads;
        await session.setToken(null);
        await tester.pumpAndSettle();
        expect(find.text('before@example.com'), findsNothing);
        expect(app.auth.reads, requests);
        expect(
          app.router.routerDelegate.currentConfiguration.uri.path,
          pushed ? Routes.login : Routes.settings,
        );
      },
    );
  }

  testWidgets('a retained profile stays hidden through refresh and failure', (
    tester,
  ) async {
    final session = await boundSession();
    addTearDown(session.dispose);
    final app = await _open(tester, session);
    expect(find.text('before@example.com'), findsOneWidget);

    final refresh = Completer<User>();
    app.auth.profile = () => refresh.future;
    app.container.invalidate(currentUserProvider);
    await tester.pumpAndSettle();
    expect(find.text('before@example.com'), findsNothing);
    refresh.completeError(Exception('profile unavailable'));
    await tester.pumpAndSettle();
    expect(find.text('before@example.com'), findsNothing);

    app.auth.profile = () async => _user('after');
    app.container.invalidate(currentUserProvider);
    await tester.pumpAndSettle();
    expect(find.text('after@example.com'), findsOneWidget);
  });

  testWidgets('Sync details returns to the same Settings route', (
    tester,
  ) async {
    final session = await boundSession();
    addTearDown(session.dispose);
    final app = await _open(tester, session);
    await tester.tap(find.widgetWithText(ListTile, 'Sync status'));
    await tester.pumpAndSettle();
    expect(
      app.router.routerDelegate.currentConfiguration.last.matchedLocation,
      Routes.sync,
    );
    app.router.pop();
    await tester.pumpAndSettle();
    expect(find.byType(SettingsScreen), findsOneWidget);
  });

  for (final status in [null, 0, 500]) {
    testWidgets(
      'logout clears the session and signs out of Google (status: $status)',
      (tester) async {
        final session = await boundSession();
        addTearDown(session.dispose);
        final app = await _open(tester, session);
        if (status != null) {
          app.auth.logoutError = ApiException(
            status,
            'failed',
            'Logout failed',
          );
        }
        await _logout(tester);
        expect(session.token, isNull);
        expect(app.auth.logouts, 1);
        expect(app.google.signOuts, 1);
        expect(
          app.router.routerDelegate.currentConfiguration.uri.path,
          Routes.login,
        );
      },
    );
  }

  testWidgets('cancelling logout preserves the session and pending work', (
    tester,
  ) async {
    final session = await boundSession();
    final store = _Store()..countResult.complete((open: 1, attention: 0));
    addTearDown(session.dispose);
    addTearDown(store.changes.dispose);
    final app = await _open(tester, session, store: store);
    await _logout(tester);
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
    expect(session.token, 't1');
    expect((await store.counts()).open, 1);
    expect(app.auth.logouts, 0);
    expect(
      app.router.routerDelegate.currentConfiguration.uri.path,
      Routes.settings,
    );
  });

  testWidgets('logout stops if Settings closes during the pending-work check', (
    tester,
  ) async {
    final session = await boundSession();
    final store = _Store();
    addTearDown(session.dispose);
    addTearDown(store.changes.dispose);
    final app = await _open(
      tester,
      session,
      location: Routes.more,
      store: store,
    );
    unawaited(app.router.push<void>(Routes.settings));
    await tester.pumpAndSettle();
    await _logout(tester);
    expect(store.countReads, 1);

    app.router.pop();
    await tester.pumpAndSettle();
    expect(find.byType(SettingsScreen), findsNothing);
    store.countResult.complete((open: 0, attention: 0));
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(session.token, 't1');
    expect(app.auth.logouts, 0);
  });
  testWidgets('confirmed logout finishes after leaving Settings', (
    tester,
  ) async {
    final session = await boundSession();
    final store = _Store()..countResult.complete((open: 1, attention: 0));
    final logoutResponse = Completer<void>();
    addTearDown(session.dispose);
    addTearDown(store.changes.dispose);
    final app = await _open(
      tester,
      session,
      location: Routes.more,
      store: store,
    );
    app.auth.logoutResponse = logoutResponse.future;
    unawaited(app.router.push<void>(Routes.settings));
    await tester.pumpAndSettle();
    await _logout(tester);
    await tester.tap(find.text('Keep on this phone'));
    await tester.pumpAndSettle();
    expect(app.auth.logouts, 1);
    expect(session.token, 't1');

    app.router.pop();
    await tester.pumpAndSettle();
    expect(find.byType(SettingsScreen), findsNothing);
    logoutResponse.complete();
    await tester.pumpAndSettle();

    expect(session.token, isNull);
    expect(app.google.signOuts, 1);
    expect((await store.counts()).open, 1);
    expect(
      app.router.routerDelegate.currentConfiguration.uri.path,
      Routes.login,
    );
    expect(tester.takeException(), isNull);
  });
}
