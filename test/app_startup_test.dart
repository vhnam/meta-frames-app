import 'dart:async';

import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:meta_frames/app.dart';
import 'package:meta_frames/app_startup.dart';
import 'package:meta_frames/data/local/local_store.dart';
import 'package:meta_frames/data/local/partition_controller.dart';
import 'package:meta_frames/data/services/api_client.dart';
import 'package:meta_frames/data/services/server_policy.dart';
import 'package:meta_frames/data/services/session_store.dart';
import 'package:meta_frames/data/sync/pending_op.dart';
import 'package:meta_frames/data/sync/sync_engine.dart';
import 'package:meta_frames/providers.dart';
import 'package:meta_frames/ui/auth/widgets/login_screen.dart';
import 'package:meta_frames/ui/core/widgets/common.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'testing/fake_server.dart';
import 'testing/local.dart';

const _fixed = 'https://api.example.com';
const _old = 'https://old.example.com';
const _tokenKey = 'session_token';
const _bindingKey = 'session_binding';

/// Secure storage that fails where a test says.
class _Keys implements SecureKeys {
  _Keys(this.log, [Map<String, String>? values]) : values = values ?? {};
  final List<String> log;
  final Map<String, String> values;
  final failRead = <String>{}, failDelete = <String>{}, stuck = <String>{};

  @override
  Future<String?> read(String key) async {
    if (failRead.contains(key)) throw Exception('read failed');
    return values[key];
  }

  @override
  Future<void> delete(String key) async {
    log.add('delete $key');
    if (failDelete.contains(key)) throw Exception('delete failed');
    if (!stuck.contains(key)) values.remove(key);
  }
}

/// The URL preference, with a write that can fail in each way it can on a phone.
class _Preference implements ServerPreference {
  _Preference(this.log, [this.stored]);
  final List<String> log;
  Object? stored, _loaded;
  bool refuses = false, throws = false, loses = false;

  @override
  Future<void> reload() async => _loaded = stored;

  @override
  Object? get value => _loaded;

  @override
  Future<bool> write(String url) async {
    log.add('write preference');
    if (throws) throw Exception('write failed');
    if (refuses) return false;
    if (!loses) stored = url;
    return true;
  }
}

String _bound({
  String token = 't1',
  String host = _fixed,
  String user = 'u1',
  String email = 'u1@example.com',
  String? name,
}) => storedBinding(
  token,
  SessionBinding(server: host, userId: user, email: email, name: name),
);

void main() {
  late List<String> log;

  setUp(() => log = []);

  Future<FixedServerStart> check(_Keys keys, _Preference preference) =>
      FixedServerCheck(
        server: _fixed,
        vault: StrictSessionVault(keys),
      ).run(preference);

  _Keys session({String? binding}) =>
      _Keys(log, {_tokenKey: 't1', _bindingKey: ?binding});

  group('decision', () {
    test('a fresh install starts signed out and mirrors the URL', () async {
      final keys = _Keys(log);
      final preference = _Preference(log);

      final start = await check(keys, preference);

      expect(start.token, isNull);
      expect(start.sessionEnded, isFalse);
      expect(preference.stored, _fixed);
    });

    test('a verified session on the same server is kept', () async {
      final keys = session(binding: _bound());
      final preference = _Preference(log, _fixed);

      final start = await check(keys, preference);

      expect(start.token, 't1');
      expect(start.binding?.userId, 'u1');
      expect(start.sessionEnded, isFalse);
      expect(keys.values, contains(_tokenKey));
      expect(log, isEmpty);
    });

    test('a stored URL with a trailing slash is the same server', () async {
      final preference = _Preference(log, '$_fixed/');

      final start = await check(session(binding: _bound()), preference);

      expect(start.token, 't1');
      expect(preference.stored, _fixed);
    });

    test('a retained binding uses the normalized partition URL', () async {
      for (final name in [null, 'Field User']) {
        final start = await check(
          session(
            binding: _bound(
              host: '$_fixed/',
              user: 'member-42',
              email: 'field@example.com',
              name: name,
            ),
          ),
          _Preference(log, _fixed),
        );

        expect(start.token, 't1');
        expect(start.binding?.toJson(), {
          'server': _fixed,
          'userId': 'member-42',
          'email': 'field@example.com',
          'name': name,
        });
      }
    });

    final rejected = <String, (Object?, String?)>{
      'another stored server': (_old, _bound()),
      'a different spelling of the fixed origin': (
        'https://API.example.com:443',
        _bound(),
      ),
      'no stored server': (null, _bound()),
      'a malformed stored server': (42, _bound()),
      'no binding': (_fixed, null),
      'a malformed binding': (_fixed, 'not json'),
      "another token's binding": (_fixed, _bound(token: 'other')),
      'a binding for another server': (_fixed, _bound(host: _old)),
      'a binding with no user': (_fixed, _bound(user: ' ')),
      'a binding with no email': (_fixed, _bound(email: '')),
    };
    rejected.forEach((name, input) {
      test('$name ends the session on this device', () async {
        final keys = session(binding: input.$2);
        final preference = _Preference(log, input.$1);

        final start = await check(keys, preference);

        expect(start.token, isNull);
        expect(start.binding, isNull);
        expect(start.sessionEnded, isTrue);
        expect(keys.values, isEmpty);
        expect(preference.stored, _fixed);
      });
    });

    test('a binding with no token is removed without a notice', () async {
      final keys = _Keys(log, {_bindingKey: _bound()});

      final start = await check(keys, _Preference(log, _fixed));

      expect(start.sessionEnded, isFalse);
      expect(keys.values, isEmpty);
    });

    test('the token goes first and the mirror moves last', () async {
      await check(session(binding: _bound()), _Preference(log, _old));

      expect(log, [
        'delete $_tokenKey',
        'delete $_bindingKey',
        'write preference',
      ]);
    });
  });

  group('failure', () {
    Future<void> failsAndKeepsPreference(
      _Keys keys,
      _Preference preference,
    ) async {
      final before = preference.stored;
      await expectLater(check(keys, preference), throwsA(anything));
      expect(preference.stored, before);
    }

    for (final key in [_tokenKey, _bindingKey]) {
      test('a failed read of $key stops the check', () async {
        final keys = session(binding: _bound())..failRead.add(key);
        await failsAndKeepsPreference(keys, _Preference(log, _old));
        expect(keys.values, contains(_tokenKey));
      });

      test('a failed delete of $key stops the check', () async {
        final keys = session(binding: _bound())..failDelete.add(key);
        await failsAndKeepsPreference(keys, _Preference(log, _old));
      });

      test('$key still stored after its delete stops the check', () async {
        final keys = session(binding: _bound())..stuck.add(key);
        await expectLater(
          check(keys, _Preference(log, _old)),
          throwsA(isA<SessionNotCleared>()),
        );
        expect(log, isNot(contains('write preference')));
      });
    }

    test('a refused, thrown or lost mirror write stops the check', () async {
      final refused = _Preference(log, _old)..refuses = true;
      final thrown = _Preference(log, _old)..throws = true;
      final lost = _Preference(log, _old)..loses = true;

      for (final preference in [refused, thrown, lost]) {
        await expectLater(check(_Keys(log), preference), throwsA(anything));
      }
    });

    test('a restart after a partial removal finishes the removal', () async {
      final keys = session(binding: _bound())..failDelete.add(_bindingKey);
      final preference = _Preference(log, _old);
      await expectLater(check(keys, preference), throwsA(anything));
      expect(keys.values.keys, [_bindingKey]);

      keys.failDelete.clear();
      final start = await check(keys, preference);

      expect(start.token, isNull);
      expect(keys.values, isEmpty);
      expect(preference.stored, _fixed);
    });

    test('a restart after a failed mirror cannot restore the token', () async {
      final keys = session(binding: _bound());
      final preference = _Preference(log, _old)..refuses = true;
      await expectLater(check(keys, preference), throwsA(anything));

      preference.refuses = false;
      final start = await check(keys, preference);

      expect(start.token, isNull);
      expect(preference.stored, _fixed);
    });

    test('a retry still reports the session it ended', () async {
      final keys = session(binding: _bound());
      final preference = _Preference(log, _old)..refuses = true;
      final retried = FixedServerCheck(
        server: _fixed,
        vault: StrictSessionVault(keys),
      );
      await expectLater(retried.run(preference), throwsA(anything));

      preference.refuses = false;
      final start = await retried.run(preference);

      expect(start.sessionEnded, isTrue);
    });
  });

  test('the first request after a server change has no old cookie', () async {
    final start = await check(
      session(binding: _bound()),
      _Preference(log, _old),
    );
    final sent = <http.BaseRequest>[];
    final client = MockClient((request) async {
      sent.add(request);
      return http.Response('{}', 200);
    });

    await ApiClient(
      () => _fixed,
      client,
      SessionStore(start.token, start.binding),
    ).send('GET', '/auth/me');

    expect(sent.single.headers, isNot(contains('Cookie')));
  });

  test(
    'partitions of two servers stay whole and only the verified one opens',
    () async {
      final dir = await tempDir();
      final oldStore = await openStore(dir, host: _old);
      await oldStore.saveDraft('old', DraftKind.camera, {'name': 'kept'});
      final oldOp = await oldStore.enqueueNotes(
        kind: OpKind.rollNotes,
        rollId: 'r1',
        text: 'Old server notes',
        seenBase: '',
      );
      await oldStore.writeSnapshot('/cameras', 200, [
        {'id': 'old-camera'},
      ], epoch: oldStore.epoch);
      await oldStore.close();
      final fixedStore = await openStore(dir, host: _fixed);
      await fixedStore.saveDraft('new', DraftKind.camera, {'name': 'mine'});
      await fixedStore.writeSnapshot('/cameras', 200, [
        {'id': 'fixed-camera'},
      ], epoch: fixedStore.epoch);
      await fixedStore.close();

      final start = await check(
        session(binding: _bound(host: _old)),
        _Preference(log, _old),
      );
      final api = FakeServer();
      final restored = SessionStore(start.token, start.binding);
      final controller = PartitionController(
        session: restored,
        baseUrl: () => _fixed,
        remote: (_, _) => SyncRemote(rolls: api, auth: api),
        verify: (_, _) => api.me(),
        factory: testDbFactory(),
        directory: dir,
      )..start();
      addTearDown(controller.dispose);
      await controller.sync();
      expect(controller.store, isNull);
      await restored.setToken('new-token');
      for (var tries = 0; tries < 200 && controller.store == null; tries++) {
        await Future<void>.delayed(const Duration(milliseconds: 5));
      }

      final opened = await controller.store!.drafts();
      expect(opened.map((draft) => draft.id), ['new']);
      expect(await controller.store!.openOps(), isEmpty);
      expect((await controller.store!.readSnapshot('/cameras'))?.json, [
        {'id': 'fixed-camera'},
      ]);

      final reopened = await openStore(dir, host: _old);
      addTearDown(reopened.close);
      expect((await reopened.drafts()).map((draft) => draft.id), ['old']);
      expect((await reopened.openOps()).single.opId, oldOp!.opId);
      expect((await reopened.readSnapshot('/cameras'))?.json, [
        {'id': 'old-camera'},
      ]);
    },
  );

  group('StartupGate', () {
    const app = SizedBox(key: Key('app'));

    testWidgets('the app is not built until the attempt ends', (tester) async {
      final attempt = Completer<Widget>();
      await tester.pumpWidget(StartupGate(attempt: () => attempt.future));
      expect(find.byKey(app.key!), findsNothing);

      attempt.complete(app);
      await tester.pump();

      expect(find.byKey(app.key!), findsOneWidget);
    });

    testWidgets('Retry runs one attempt at a time', (tester) async {
      var attempts = 0;
      final pending = Completer<Widget>();
      await tester.pumpWidget(
        StartupGate(
          attempt: () {
            attempts++;
            return attempts == 1
                ? Future<Widget>.error(Exception('storage'))
                : pending.future;
          },
        ),
      );
      await tester.pump();
      expect(find.byKey(app.key!), findsNothing);

      final retry = tester.widget<FilledButton>(find.byType(FilledButton));
      retry.onPressed!();
      retry.onPressed!();
      await tester.pump();

      expect(attempts, 2);
      expect(find.byType(FilledButton), findsNothing);

      pending.complete(app);
      await tester.pump();
      expect(find.byKey(app.key!), findsOneWidget);
    });

    testWidgets('resume while the check waits cannot start app providers', (
      tester,
    ) async {
      final allowStartup = Completer<void>();
      final keys = session(binding: _bound(host: _old));
      final preference = _Preference(log, _old);
      SharedPreferences.setMockInitialValues({'base_url': _old});
      final prefs = await SharedPreferences.getInstance();
      final api = FakeServer();
      var partitionStarts = 0;
      var requests = 0;
      final client = MockClient((request) async {
        requests++;
        return http.Response('{}', 200);
      });
      await tester.pumpWidget(
        StartupGate(
          attempt: () async {
            await allowStartup.future;
            final start = await check(keys, preference);
            final session = SessionStore(start.token, start.binding);
            return ProviderScope(
              overrides: [
                prefsProvider.overrideWithValue(prefs),
                serverPolicyProvider.overrideWithValue(
                  const FixedServer(_fixed),
                ),
                sessionStoreProvider.overrideWithValue(session),
                sessionEndedAtStartupProvider.overrideWithValue(
                  StartupNotice(sessionEnded: start.sessionEnded),
                ),
                apiClientProvider.overrideWith(
                  (_) => ApiClient(() => _fixed, client, session),
                ),
                partitionControllerProvider.overrideWith((ref) {
                  partitionStarts++;
                  final controller = PartitionController(
                    session: session,
                    baseUrl: () => _fixed,
                    remote: (_, _) => SyncRemote(rolls: api, auth: api),
                    verify: (_, _) => api.me(),
                  )..start();
                  ref.onDispose(controller.dispose);
                  return controller;
                }),
              ],
              child: const MetaFramesApp(),
            );
          },
        ),
      );
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pump();

      expect(partitionStarts, 0);
      expect(requests, 0);
      expect(keys.values[_tokenKey], 't1');

      allowStartup.complete();
      await tester.pumpAndSettle();
      expect(partitionStarts, 1);
      expect(keys.values, isEmpty);
      expect(find.byType(LoginScreen), findsOneWidget);
      expect(find.byType(WarningBanner), findsOneWidget);
    });

    testWidgets('a build with no server offers no Retry', (tester) async {
      await tester.pumpWidget(const InvalidServerBuildApp());
      expect(find.byType(FilledButton), findsNothing);
    });
  });

  testWidgets('Login tells of the ended session once', (tester) async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final notice = StartupNotice(sessionEnded: true);
    Widget login(Key key) => ProviderScope(
      key: key,
      overrides: [
        prefsProvider.overrideWithValue(prefs),
        sessionEndedAtStartupProvider.overrideWithValue(notice),
      ],
      child: const MaterialApp(home: LoginScreen()),
    );

    await tester.pumpWidget(login(const Key('first')));
    await tester.pump();
    expect(find.byType(WarningBanner), findsOneWidget);

    await tester.pumpWidget(login(const Key('second')));
    await tester.pump();
    expect(find.byType(WarningBanner), findsNothing);
  });
}
