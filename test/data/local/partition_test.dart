import 'dart:async';
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:meta_frames/data/local/local_store.dart';
import 'package:meta_frames/data/local/partition_controller.dart';
import 'package:meta_frames/data/local/read_cache.dart';
import 'package:meta_frames/data/services/api_client.dart';
import 'package:meta_frames/data/services/session_store.dart';
import 'package:meta_frames/data/sync/pending_op.dart';
import 'package:meta_frames/data/sync/sync_engine.dart';
import 'package:meta_frames/domain/models/models.dart';

import '../../testing/fake_server.dart';
import '../../testing/local.dart';

/// Answers like a server, or fails like no network.
class _Net {
  bool offline = false;
  final routes = <String, Object?>{};
  final hits = <String>[];

  /// Completes the next answer only when the test says so.
  Completer<void>? hold;

  late final client = MockClient((req) async {
    hits.add(req.url.path);
    if (hold != null) await hold!.future;
    if (offline) throw http.ClientException('offline');
    final body = routes[req.url.path];
    if (body == null) return http.Response('{"code":"not_found"}', 404);
    return http.Response(jsonEncode(body), 200);
  });
}

void main() {
  late String dir;
  late _Net net;
  late FakeServer api;
  var baseUrl = server;
  var verified = <String>[];

  PartitionController controllerFor(
    SessionStore session, {
    Future<User> Function(String, String)? verify,
  }) {
    final c = PartitionController(
      session: session,
      baseUrl: () => baseUrl,
      remote: (_, _) => SyncRemote(rolls: api, auth: api),
      verify:
          verify ??
          (server, token) async {
            verified.add(token);
            return api.me();
          },
      factory: testDbFactory(),
      directory: dir,
    )..start();
    addTearDown(c.dispose);
    return c;
  }

  Future<void> settle(PartitionController c, {bool open = true}) async {
    for (var i = 0; i < 200; i++) {
      if ((c.store != null) == open) return;
      await Future<void>.delayed(const Duration(milliseconds: 5));
    }
    fail('partition never ${open ? 'opened' : 'closed'}');
  }

  ApiClient clientFor(SessionStore session, PartitionController c) =>
      ApiClient(() => baseUrl, net.client, session)
        ..readCache = DeviceReadCache(c);

  setUp(() async {
    dir = await tempDir();
    net = _Net();
    api = FakeServer();
    baseUrl = server;
    verified = [];
  });

  test(
    'offline launch opens the bound account\'s data, no network needed',
    () async {
      // First run: online, a read is kept.
      var session = await boundSession();
      var c = controllerFor(session);
      await settle(c);
      net.routes['/cameras'] = [];
      await clientFor(session, c).send('GET', '/cameras');
      c.dispose();

      // Relaunch offline with the persisted binding.
      net.offline = true;
      api.faults.add(Fault.offline);
      session = await boundSession();
      c = controllerFor(session);
      await settle(c);
      expect(verified, isEmpty);
      final client = clientFor(session, c);
      expect(
        await client.send('GET', '/cameras'),
        isEmpty,
        reason: 'kept as an empty list',
      );
      await expectLater(
        client.send('GET', '/labs'),
        throwsA(isA<OfflineNoSnapshot>()),
        reason: 'never fetched is not empty',
      );
    },
  );

  test('a new token opens nothing until /auth/me answers for it', () async {
    final session = SessionStore('fresh');
    final gate = Completer<User>();
    final c = controllerFor(
      session,
      // Only the first token's answer ever arrives.
      verify: (_, token) =>
          token == 'fresh' ? gate.future : Completer<User>().future,
    );
    await Future<void>.delayed(const Duration(milliseconds: 20));
    expect(c.store, isNull);
    expect(await LocalStore.list(testDbFactory(), dir), isEmpty);

    // The user signs in again as someone else before the answer arrives.
    await session.setToken('newer');
    gate.complete(User.fromJson({'id': 'u1', 'email': 'u1@example.com'}));
    await Future<void>.delayed(const Duration(milliseconds: 20));
    expect(
      session.binding,
      isNull,
      reason: 'the old token\'s account is never given to the new one',
    );
  });

  test('a read answered after the session changed is dropped', () async {
    final session = await boundSession();
    final c = controllerFor(session);
    await settle(c);
    net.routes['/cameras'] = [
      {'id': 'c1'},
    ];
    net.hold = Completer();
    final read = clientFor(session, c).send('GET', '/cameras');
    await Future<void>.delayed(const Duration(milliseconds: 5));
    await session.setToken('other-account');
    net.hold!.complete();
    await expectLater(read, throwsA(isA<StaleSessionRead>()));
    await settle(c, open: false);
    final reopened = await openStore(dir);
    addTearDown(reopened.close);
    expect(await reopened.readSnapshot('/cameras'), isNull);
  });

  test('reads show pending changes over the kept answer', () async {
    final session = await boundSession();
    final c = controllerFor(session);
    await settle(c);
    net.routes['/cameras'] = [
      {'id': 'c1', 'loadedRoll': null},
    ];
    final client = clientFor(session, c);
    await client.send('GET', '/cameras');
    net.offline = true;
    api.faults.add(Fault.offline);
    await c.store!.enqueueStep(
      kind: OpKind.load,
      rollId: 'r1',
      cameraId: 'c1',
      payload: {
        'startedAt': '2026-11-07',
        'stockId': 's1',
        'stockBrand': 'Kodak',
        'stockName': 'Gold',
      },
    );
    final cams = await client.send('GET', '/cameras') as List;
    expect(cams.single['loadedRoll']['rollId'], 'r1');
  });

  test(
    'changing server or account closes the partition and keeps its file',
    () async {
      final session = await boundSession();
      final c = controllerFor(session);
      await settle(c);
      await c.store!.enqueueNotes(
        kind: OpKind.rollNotes,
        rollId: 'r1',
        text: 'kept',
        seenBase: '',
      );
      api.faults.add(Fault.offline);

      baseUrl = 'http://server-b';
      await session.setToken(null);
      await settle(c, open: false);

      final kept = await LocalStore.list(testDbFactory(), dir);
      expect(kept.single.openOps, 1);
      expect(kept.single.key.server, server);

      // Signing in on server B as the same user id opens another partition.
      await session.setToken('tb');
      await session.bind(binding(host: 'http://server-b'), forToken: 'tb');
      await settle(c);
      expect(await c.store!.openOps(), isEmpty);
    },
  );

  test('discard deletes only the chosen partition', () async {
    final session = await boundSession();
    final c = controllerFor(session);
    await settle(c);
    final other = await openStore(dir, user: 'u2');
    await other.saveDraft('d', DraftKind.lab, {
      'request': {'name': 'x'},
    });
    await other.close();

    await c.discard(const PartitionKey(server, 'u2'));
    final left = await LocalStore.list(testDbFactory(), dir);
    expect(left.map((p) => p.key.userId), ['u1']);
  });
}
