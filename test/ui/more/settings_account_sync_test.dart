import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:meta_frames/data/local/local_store.dart';
import 'package:meta_frames/data/local/partition_controller.dart';
import 'package:meta_frames/data/repositories/settings_repository_prefs.dart';
import 'package:meta_frames/domain/models/saved_server.dart';
import 'package:meta_frames/ui/more/view_models/settings_actions.dart';
import 'package:meta_frames/ui/more/widgets/saved_servers_screen.dart';
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
  _Store({this.key = const PartitionKey(server, 'u1')});
  final countResult = Completer<({int open, int attention})>();
  int countReads = 0;

  @override
  final PartitionKey key;

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

class _Partitions implements PartitionController {
  final discarded = <PartitionKey>[];

  @override
  Future<void> discard(PartitionKey key) async => discarded.add(key);

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _DeferredSettings extends SettingsRepositoryPrefs {
  _DeferredSettings(super.prefs);

  final write = Completer<void>();

  @override
  Future<void> setBaseUrl(String url) async {
    await write.future;
    await super.setBaseUrl(url);
  }
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
  _Partitions? partitions,
  ValueNotifier<_Store?>? openStore,
  bool setupServers = false,
  SettingsRepositoryPrefs Function(SharedPreferences)? settings,
}) async {
  SharedPreferences.setMockInitialValues({});
  final prefs = await SharedPreferences.getInstance();
  if (setupServers) {
    await prefs.setString('base_url', server);
    await SettingsRepositoryPrefs(prefs)
        .saveServer(const SavedServer(name: 'Other', url: _other));
  }
  final auth = _Auth();
  final google = _Google();
  final router = buildRouter(initialLocation: location, session: session);
  final container = ProviderContainer.test(
    retry: (_, _) => null,
    overrides: [
      prefsProvider.overrideWithValue(prefs),
      serverPolicyProvider.overrideWithValue(const DebugServers()),
      sessionStoreProvider.overrideWithValue(session),
      localStoreProvider.overrideWith((ref) {
        if (openStore == null) return store;
        openStore.addListener(ref.invalidateSelf);
        ref.onDispose(() => openStore.removeListener(ref.invalidateSelf));
        return openStore.value;
      }),
      if (partitions != null)
        partitionControllerProvider.overrideWithValue(partitions),
      if (settings != null)
        settingsRepositoryProvider.overrideWithValue(settings(prefs)),
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
  final target = find.widgetWithText(OutlinedButton, 'Log out');
  await tester.scrollUntilVisible(
    target,
    120,
    scrollable: find.descendant(
      of: find.byType(SettingsScreen),
      matching: find.byType(Scrollable),
    ),
  );
  await tester.pumpAndSettle();
  await tester.tap(target);
  await tester.pumpAndSettle();
}

const _other = 'https://other.example';

Future<void> _serverSave(WidgetTester tester, {bool change = true}) async {
  if (change) await tester.tap(find.text(_other));
  await tester.pump();
  final save = find.widgetWithText(FilledButton, 'Save');
  await tester.scrollUntilVisible(save, 100);
  await tester.pumpAndSettle();
  await tester.tap(save);
  await tester.pumpAndSettle();
}

String _path(GoRouter router) =>
    router.routerDelegate.currentConfiguration.last.matchedLocation;

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

  testWidgets('Log out stays reachable at 2x on a narrow screen', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 640);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    tester.platformDispatcher.textScaleFactorTestValue = 2;
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    final session = await boundSession();
    addTearDown(session.dispose);
    final app = await _open(tester, session);
    expect(tester.takeException(), isNull);

    final target = find.widgetWithText(OutlinedButton, 'Log out');
    await tester.scrollUntilVisible(
      target,
      120,
      scrollable: find.descendant(
        of: find.byType(SettingsScreen),
        matching: find.byType(Scrollable),
      ),
    );
    await tester.pumpAndSettle();
    expect(tester.getSize(target).height, greaterThanOrEqualTo(48));
    await tester.tap(target);
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    expect(session.token, isNull);
    expect(app.auth.logouts, 1);
  });

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
  test('the save action only discards for a changed normalized URL', () async {
    SharedPreferences.setMockInitialValues({'base_url': server});
    final prefs = await SharedPreferences.getInstance();
    final session = await boundSession();
    addTearDown(session.dispose);
    final partitions = _Partitions();
    final store = _Store();
    final container = ProviderContainer.test(
      overrides: [
        prefsProvider.overrideWithValue(prefs),
        serverPolicyProvider.overrideWithValue(const DebugServers()),
        sessionStoreProvider.overrideWithValue(session),
        partitionControllerProvider.overrideWithValue(partitions),
        localStoreProvider.overrideWithValue(store),
      ],
    );
    final actions = container.read(settingsActionsProvider);
    expect(await actions.saveBaseUrl('$server/', discardKept: true), server);
    expect(partitions.discarded, isEmpty);
    expect(session.signedIn, isTrue);
    expect(await actions.saveBaseUrl(_other, discardKept: true), _other);
    expect(partitions.discarded, [store.key]);
    expect(prefs.getString('base_url'), _other);
    expect(session.signedIn, isFalse);
  });

  testWidgets(
    'token end closes the Log out discard prompt on public Settings',
    (tester) async {
      final session = await boundSession();
      addTearDown(session.dispose);
      final store = _Store()..countResult.complete((open: 2, attention: 0));
      final app = await _open(tester, session, store: store);
      await _logout(tester);
      await tester.tap(find.widgetWithText(TextButton, 'Discard'));
      await tester.pumpAndSettle();
      expect(find.byType(TextField), findsOneWidget);
      await session.setToken(null);
      await tester.pumpAndSettle();
      expect(find.byType(AlertDialog), findsNothing);
      expect(_path(app.router), Routes.settings);
      expect(app.auth.logouts, 0);
    },
  );

  group('Saved servers confirmation', () {
    for (final choice in ['Keep on this phone', 'Discard', 'Cancel']) {
      testWidgets('$choice applies only the intended partition changes', (
        tester,
      ) async {
        final session = await boundSession();
        addTearDown(session.dispose);
        final store = _Store()..countResult.complete((open: 2, attention: 0));
        final partitions = _Partitions();
        final app = await _open(
          tester,
          session,
          location: Routes.savedServers,
          store: store,
          partitions: partitions,
          setupServers: true,
        );
        await _serverSave(tester);
        await tester.tap(
          find.widgetWithText(
            choice == 'Keep on this phone' ? FilledButton : TextButton,
            choice,
          ),
        );
        await tester.pumpAndSettle();
        if (choice == 'Discard') {
          await tester.enterText(find.byType(TextField), 'DISCARD');
          await tester.pump();
          await tester.tap(find.widgetWithText(FilledButton, 'Discard'));
          await tester.pumpAndSettle();
        }
        final cancelled = choice == 'Cancel';
        expect(
          app.container.read(settingsRepositoryProvider).baseUrl,
          cancelled ? server : _other,
        );
        expect(session.signedIn, cancelled);
        expect(
          partitions.discarded,
          choice == 'Discard' ? [store.key] : isEmpty,
        );
        if (cancelled) {
          expect(find.byType(SavedServersScreen), findsOneWidget);
        } else {
          expect(_path(app.router), Routes.login);
        }
      });
    }

    for (final phase in [
      'read',
      'choice',
      'handoff',
      'typed',
      'stacked popup',
    ]) {
      testWidgets('token end during $phase cancels only the server flow', (
        tester,
      ) async {
        final session = await boundSession();
        addTearDown(session.dispose);
        final store = _Store();
        final partitions = _Partitions();
        if (phase != 'read') {
          store.countResult.complete((open: 2, attention: 0));
        }
        final app = await _open(
          tester,
          session,
          location: Routes.savedServers,
          store: store,
          partitions: partitions,
          setupServers: true,
        );
        await _serverSave(tester);
        expect(store.countReads, 1);
        final screen = tester.element(find.byType(SavedServersScreen));
        if (phase == 'handoff' || phase == 'typed') {
          if (phase == 'handoff') {
            Navigator.of(screen, rootNavigator: true).pop('discard');
          } else {
            await tester.tap(find.widgetWithText(TextButton, 'Discard'));
            await tester.pumpAndSettle();
            expect(find.byType(TextField), findsOneWidget);
          }
        }
        final unrelated = find.byType(Checkbox);
        if (phase == 'stacked popup') {
          unawaited(
            showDialog<void>(
              context: screen,
              builder: (_) => const AlertDialog(
                content: Checkbox(value: true, onChanged: null),
              ),
            ),
          );
          await tester.pumpAndSettle();
          expect(unrelated, findsOneWidget);
        }
        await session.setToken(null);
        if (phase == 'read') {
          store.countResult.complete((open: 2, attention: 0));
        }
        await tester.pumpAndSettle();
        expect(partitions.discarded, isEmpty);
        expect(app.container.read(settingsRepositoryProvider).baseUrl, server);
        expect(find.byType(SavedServersScreen), findsOneWidget);
        expect(find.byType(TextField), findsNothing);
        if (phase == 'stacked popup') {
          expect(unrelated, findsOneWidget);
          expect(find.byType(AlertDialog), findsOneWidget);
        } else {
          expect(find.byType(AlertDialog), findsNothing);
        }
      });
    }

    for (final changeBinding in [false, true]) {
      testWidgets(
        'Discard rejects a new store (binding changed: $changeBinding)',
        (tester) async {
          final session = await boundSession();
          addTearDown(session.dispose);
          final store = _Store()..countResult.complete((open: 2, attention: 0));
          final openStore = ValueNotifier<_Store?>(store);
          addTearDown(openStore.dispose);
          final partitions = _Partitions();
          final app = await _open(
            tester,
            session,
            location: Routes.savedServers,
            store: store,
            openStore: openStore,
            partitions: partitions,
            setupServers: true,
          );
          await _serverSave(tester);
          await tester.tap(find.widgetWithText(TextButton, 'Discard'));
          await tester.pumpAndSettle();
          await tester.enterText(find.byType(TextField), 'DISCARD');
          await tester.pump();
          openStore.value = _Store(key: const PartitionKey(server, 'second'));
          if (changeBinding) {
            await session.bind(binding(user: 'second'), forToken: 't1');
          } else {
            await tester.tap(find.widgetWithText(FilledButton, 'Discard'));
          }
          await tester.pumpAndSettle();
          expect(find.byType(AlertDialog), findsNothing);
          expect(partitions.discarded, isEmpty);
          expect(
            app.container.read(settingsRepositoryProvider).baseUrl,
            server,
          );
          expect(session.signedIn, isTrue);
        },
      );
    }

    testWidgets('a store for another binding is never read or discarded', (
      tester,
    ) async {
      final session = await boundSession(user: 'second');
      addTearDown(session.dispose);
      final store = _Store();
      final partitions = _Partitions();
      final app = await _open(
        tester,
        session,
        location: Routes.savedServers,
        store: store,
        partitions: partitions,
        setupServers: true,
      );
      await _serverSave(tester);
      expect(store.countReads, 0);
      expect(partitions.discarded, isEmpty);
      expect(session.signedIn, isTrue);
      expect(find.byType(AlertDialog), findsNothing);
      expect(app.container.read(settingsRepositoryProvider).baseUrl, server);
    });
  });

  for (final location in [Routes.more, Routes.settings, Routes.savedServers]) {
    testWidgets('token end without a store from $location', (tester) async {
      final session = await boundSession();
      addTearDown(session.dispose);
      final app = await _open(tester, session, location: location);
      if (location == Routes.more) {
        app.router.push(Routes.settings);
        await tester.pumpAndSettle();
      }
      if (location != Routes.savedServers) {
        await tester.tap(find.widgetWithText(ListTile, 'Server connection'));
        await tester.pumpAndSettle();
      }
      expect(find.byType(SavedServersScreen), findsOneWidget);
      await session.setToken(null);
      await tester.pumpAndSettle();
      if (location == Routes.more) {
        expect(_path(app.router), Routes.login);
        expect(find.byType(SavedServersScreen), findsNothing);
      } else {
        expect(find.byType(SavedServersScreen), findsOneWidget);
        await tester.tap(find.byType(BackButton));
        await tester.pumpAndSettle();
        expect(find.byType(SavedServersScreen), findsNothing);
        expect(find.byType(AccountCard), findsNothing);
        expect(_path(app.router), Routes.settings);
      }
    });
  }

  for (final signedIn in [true, false]) {
    testWidgets('unchanged URL from direct link (signed in: $signedIn)', (
      tester,
    ) async {
      final session = signedIn ? await boundSession() : SessionStore();
      addTearDown(session.dispose);
      final app = await _open(
        tester,
        session,
        location: Routes.savedServers,
        setupServers: true,
      );
      await _serverSave(tester, change: false);
      expect(_path(app.router), signedIn ? Routes.settings : Routes.login);
      expect(find.byType(SavedServersScreen), findsNothing);
      expect(session.signedIn, signedIn);
    });
  }

  testWidgets('Back through Settings before login drops the selection', (
    tester,
  ) async {
    final session = SessionStore();
    addTearDown(session.dispose);
    final app = await _open(
      tester,
      session,
      location: Routes.login,
      setupServers: true,
    );
    app.router.push(Routes.settings);
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(ListTile, 'Server connection'));
    await tester.pumpAndSettle();
    await tester.tap(find.text(_other));
    await tester.tap(find.byType(BackButton));
    await tester.pumpAndSettle();
    expect(_path(app.router), Routes.settings);
    await tester.tap(find.widgetWithText(ListTile, 'Server connection'));
    await tester.pumpAndSettle();
    await _serverSave(tester, change: false);
    expect(_path(app.router), Routes.login);
    expect(app.container.read(settingsRepositoryProvider).baseUrl, server);
  });

  testWidgets('a changed Save still opens Login after leaving the screen', (
    tester,
  ) async {
    final session = SessionStore('unbound');
    addTearDown(session.dispose);
    late _DeferredSettings repo;
    final app = await _open(
      tester,
      session,
      setupServers: true,
      settings: (prefs) => repo = _DeferredSettings(prefs),
    );
    app.router.push(Routes.savedServers);
    await tester.pumpAndSettle();
    await _serverSave(tester);
    await tester.tap(find.byType(BackButton));
    await tester.pumpAndSettle();
    expect(_path(app.router), Routes.settings);
    repo.write.complete();
    await tester.pumpAndSettle();
    expect(repo.baseUrl, _other);
    expect(session.signedIn, isFalse);
    expect(_path(app.router), Routes.login);
  });

  for (final succeeds in [true, false]) {
    testWidgets('an unchanged Save can finish late (success: $succeeds)', (
      tester,
    ) async {
      final session = await boundSession();
      addTearDown(session.dispose);
      late _DeferredSettings repo;
      final app = await _open(
        tester,
        session,
        location: Routes.more,
        setupServers: true,
        settings: (prefs) => repo = _DeferredSettings(prefs),
      );
      app.router.push(Routes.settings);
      await tester.pumpAndSettle();
      app.router.push(Routes.savedServers);
      await tester.pumpAndSettle();
      await _serverSave(tester, change: false);
      if (succeeds) {
        await tester.tap(find.byType(BackButton));
        await tester.pumpAndSettle();
        repo.write.complete();
      } else {
        repo.write.completeError(StateError('write failed'));
      }
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      if (succeeds) {
        expect(_path(app.router), Routes.settings);
        expect(find.byType(SavedServersScreen), findsNothing);
      } else {
        final snackBar = find.byType(SnackBar);
        expect(find.byType(SavedServersScreen), findsOneWidget);
        expect(repo.baseUrl, server);
        expect(snackBar, findsOneWidget);

        // Dismiss the error and check that no success notice was queued.
        ScaffoldMessenger.of(tester.element(find.byType(SavedServersScreen)))
            .hideCurrentSnackBar();
        await tester.pumpAndSettle();
        expect(snackBar, findsNothing);
        expect(find.byType(SavedServersScreen), findsOneWidget);
      }
      expect(session.signedIn, isTrue);
    });
  }
}
