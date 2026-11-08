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

import '../../testing/fake_server.dart';
import '../../testing/local.dart';

/// A server whose answer is decided when the request arrives and delivered
/// when the test lets it: a read can be out while the phone's own changes
/// reach the server.
class _Net {
  final routes = <String, Object?>{};
  final requests = <http.Request>[];

  /// Runs once the answer for a request is fixed and before it is delivered.
  Future<void> Function(int n)? whileOut;

  late final client = MockClient((req) async {
    requests.add(req);
    final n = requests.length;
    final body = routes[req.url.path];
    await whileOut?.call(n);
    if (body == null) return http.Response('{"code":"not_found"}', 404);
    return http.Response(jsonEncode(body), 200);
  });
}

Map<String, dynamic> _detail(String status) => {
  'roll': {'id': 'r1', 'status': status},
  'frames': <Object?>[],
};

Map<String, dynamic> _frame(String notes) => {
  'id': 'f7',
  'number': 7,
  'notes': notes,
  'scans': <Object?>[],
};

void main() {
  late String dir;
  late _Net net;
  late FakeServer api;
  late SessionStore session;
  late PartitionController partitions;
  late ApiClient client;

  setUp(() async {
    dir = await tempDir();
    net = _Net();
    api = FakeServer();
    session = await boundSession();
    partitions = PartitionController(
      session: session,
      baseUrl: () => server,
      remote: (_, _) => SyncRemote(rolls: api, auth: api),
      verify: (_, _) async => api.me(),
      factory: testDbFactory(),
      directory: dir,
    )..start();
    addTearDown(partitions.dispose);
    for (var i = 0; i < 200 && partitions.store == null; i++) {
      await Future<void>.delayed(const Duration(milliseconds: 5));
    }
    expect(partitions.store, isNotNull, reason: 'the partition opened');
    client = ApiClient(() => server, net.client, session)
      ..readCache = DeviceReadCache(partitions);
  });

  LocalStore store() => partitions.store!;

  Future<PendingOp> finishOp() => store().enqueueStep(
    kind: OpKind.finish,
    rollId: 'r1',
    cameraId: 'c1',
    payload: {'date': '2026-11-07'},
  );

  group('a read that is out while a change reaches the server', () {
    test('a 200 is read again with the state after the change', () async {
      net.routes['/rolls/r1'] = _detail('in_camera');
      final op = await finishOp();
      net.whileOut = (n) async {
        if (n != 1) return;
        // The answer above is already fixed: it predates the finish.
        net.routes['/rolls/r1'] = _detail('done_shooting');
        await store().complete(op, detail: _detail('done_shooting'));
      };
      final read = await client.send('GET', '/rolls/r1') as Map;
      expect(
        (read['roll'] as Map)['status'],
        'done_shooting',
        reason: 'the answer from before the change is not shown or kept',
      );
      expect(net.requests, hasLength(2));
      final kept = (await store().readSnapshot('/rolls/r1'))!.json;
      expect(kept['roll']['status'], 'done_shooting');
    });

    test('a discard in the meantime is read past the same way', () async {
      net.routes['/rolls/r1'] = _detail('in_camera');
      final op = await finishOp();
      net.whileOut = (n) async {
        if (n != 1) return;
        net.routes['/rolls/r1'] = _detail('done_shooting');
        await store().discard(op);
      };
      final read = await client.send('GET', '/rolls/r1') as Map;
      expect((read['roll'] as Map)['status'], 'done_shooting');
      expect(net.requests, hasLength(2));
    });

    test('a 404 for a frame is read again, not taken as "no frame"', () async {
      // The frame did not exist when the answer was fixed; a note on it
      // reaches the server while the answer is out.
      final op = (await store().enqueueNotes(
        kind: OpKind.frameNotes,
        rollId: 'r1',
        frame: 7,
        text: 'backlit',
        seenBase: '',
      ))!;
      net.whileOut = (n) async {
        if (n != 1) return;
        net.routes['/rolls/r1/frames/7'] = _frame('backlit');
        await store().complete(op, frame: _frame('backlit'));
      };
      final read = await client.send('GET', '/rolls/r1/frames/7') as Map?;
      expect(read, isNotNull, reason: 'the frame exists now');
      expect(read!['notes'], 'backlit');
      expect(net.requests, hasLength(2));
    });

    test('the second read is made as the same session', () async {
      net.routes['/rolls/r1'] = _detail('in_camera');
      final op = await finishOp();
      net.whileOut = (n) async {
        if (n == 1) await store().complete(op, detail: _detail('x'));
      };
      await client.send('GET', '/rolls/r1');
      final cookies = {for (final r in net.requests) r.headers['Cookie']};
      expect(cookies, {'metaframes_session=t1'});
    });

    test('changes that never stop: no loop, never a stale answer', () async {
      net.routes['/rolls/r1'] = _detail('in_camera');
      // Every answer is overtaken by another change.
      net.whileOut = (n) async {
        if (n > 20) return;
        final op = await finishOp();
        await store().complete(op, detail: _detail('after-$n'));
        net.routes['/rolls/r1'] = _detail('after-$n');
      };
      final read = await client.send('GET', '/rolls/r1') as Map;
      expect(net.requests, hasLength(4), reason: 'three retries, then stop');
      // The last response was fixed before change 3 and 4 landed (it says
      // after-3); the device's latest state is change 4.
      expect((read['roll'] as Map)['status'], 'after-4');
      final kept = (await store().readSnapshot('/rolls/r1'))!.json;
      expect(kept['roll']['status'], 'after-4');
    });

    test(
      'frame 404s that never stop show the frame the changes made',
      () async {
        net.whileOut = (n) async {
          if (n > 20) return;
          final op = (await store().enqueueNotes(
            kind: OpKind.frameNotes,
            rollId: 'r1',
            frame: 7,
            text: 'v$n',
            seenBase: '',
          ))!;
          await store().complete(op, frame: _frame('v$n'));
        };
        final read = await client.send('GET', '/rolls/r1/frames/7') as Map?;
        expect(net.requests, hasLength(4));
        expect(read, isNotNull, reason: 'the frame exists on the device');
        expect(read!['notes'], 'v4', reason: 'the latest, not "not found"');
      },
    );

    test('a stale answer with nothing kept fails, retriably', () async {
      net.routes['/cameras'] = [
        {'id': 'c1'},
      ];
      // Changes do not touch any kept list, so nothing is ever stored.
      net.whileOut = (n) async {
        if (n > 20) return;
        await store().complete(await finishOp());
      };
      await expectLater(
        client.send('GET', '/cameras'),
        throwsA(
          isA<StaleRead>().having((e) => e.isNetwork, 'retriable', isTrue),
        ),
      );
      expect(net.requests, hasLength(4));
      expect(await store().readSnapshot('/cameras'), isNull);
    });

    test(
      'a frame 404 that is stale with nothing kept fails, retriably',
      () async {
        net.whileOut = (n) async {
          if (n > 20) return;
          await store().complete(await finishOp());
        };
        await expectLater(
          client.send('GET', '/rolls/r1/frames/7'),
          throwsA(isA<StaleRead>()),
          reason: 'not "frame not found": no current answer exists',
        );
      },
    );

    test('a session change while it is out ends the read, no retry', () async {
      net.routes['/rolls/r1'] = _detail('in_camera');
      final op = await finishOp();
      net.whileOut = (n) async {
        if (n != 1) return;
        await store().complete(op, detail: _detail('done_shooting'));
        await session.setToken('someone-else');
      };
      await expectLater(
        client.send('GET', '/rolls/r1'),
        throwsA(isA<StaleSessionRead>()),
      );
      expect(net.requests, hasLength(1), reason: 'nothing sent as the new one');
    });
  });

  group('the stored answer and the changes are read together', () {
    ReadTicket ticket(String path) =>
        DeviceReadCache(partitions).begin(server, path, null)!;

    // The database runs transactions one at a time, in the order they are
    // started. Starting the completion right behind the write puts it between
    // the write and whatever reads the changes afterwards.
    test('a 200 stored just before the change completes', () async {
      final op = await finishOp();
      final answer = ticket('/rolls/r1').fresh(_detail('in_camera'));
      final done = store().complete(op, detail: _detail('done_shooting'));
      final read = await answer;
      await done;
      expect(read.retry, isFalse);
      expect(
        (read.json['roll'] as Map)['status'],
        'done_shooting',
        reason: 'the finished change is not shown as pending-and-lost',
      );
    });

    test('a frame 404 stored just before the change completes', () async {
      final op = (await store().enqueueNotes(
        kind: OpKind.frameNotes,
        rollId: 'r1',
        frame: 7,
        text: 'backlit',
        seenBase: '',
      ))!;
      final answer = ticket('/rolls/r1/frames/7')
          .notFound(ApiException(404, 'not_found', 'Not found'));
      final done = store().complete(op, frame: _frame('backlit'));
      final read = await answer;
      await done;
      expect(read.json, isNotNull, reason: 'no "not found" for a made frame');
      expect(read.json['notes'], 'backlit');
    });

    test('offline: either side of the completion shows the finish', () async {
      for (final completeFirst in [false, true]) {
        final op = await finishOp();
        await store().writeSnapshot(
          '/rolls/r1',
          200,
          _detail('in_camera'),
          epoch: store().epoch,
        );
        final offline = completeFirst
            ? null
            : ticket('/rolls/r1')
                  .offline(ApiException(0, 'network', 'offline'));
        final done = store().complete(op, detail: _detail('done_shooting'));
        final read =
            await (offline ??
                ticket('/rolls/r1')
                    .offline(ApiException(0, 'network', 'offline')));
        await done;
        expect(
          (read.json['roll'] as Map)['status'],
          'done_shooting',
          reason: 'completeFirst=$completeFirst',
        );
      }
    });
  });

  group('a ticket after a session change', () {
    ReadTicket ticket(String path) =>
        DeviceReadCache(partitions).begin(server, path, null)!;

    test(
      'fresh drops the answer instead of returning the old account\'s',
      () async {
        final answer = ticket('/cameras').fresh([
          {'id': 'c1'},
        ]);
        // The check at the start passed; the write is under way.
        await session.setToken('someone-else');
        await expectLater(answer, throwsA(isA<StaleSessionRead>()));
      },
    );

    test('notFound drops the answer too', () async {
      final answer = ticket('/rolls/r1/frames/7')
          .notFound(ApiException(404, 'not_found', 'Not found'));
      await session.setToken('someone-else');
      await expectLater(answer, throwsA(isA<StaleSessionRead>()));
    });

    test('offline does not serve the old account\'s kept answer', () async {
      await store().writeSnapshot('/cameras', 200, [
        {'id': 'c1'},
      ], epoch: store().epoch);
      final answer = ticket('/cameras')
          .offline(ApiException(0, 'network', 'offline'));
      await session.setToken('someone-else');
      await expectLater(answer, throwsA(isA<StaleSessionRead>()));
    });

    test('again is refused once the session or server has changed', () async {
      final first = ticket('/cameras');
      expect(() => first.again(server), returnsNormally);
      expect(
        () => first.again('http://server-b'),
        throwsA(isA<StaleSessionRead>()),
        reason: 'a retry never goes to another server',
      );
      await session.setToken('someone-else');
      expect(() => first.again(server), throwsA(isA<StaleSessionRead>()));
    });

    test('the same account signing in again is a new session', () async {
      final first = ticket('/cameras');
      await session.setToken(null);
      await session.setToken('t2');
      await session.bind(binding(), forToken: 't2');
      expect(() => first.again(server), throwsA(isA<StaleSessionRead>()));
    });
  });
}
