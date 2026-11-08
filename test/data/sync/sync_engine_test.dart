import 'package:flutter_test/flutter_test.dart';
import 'package:meta_frames/data/local/local_store.dart';
import 'package:meta_frames/data/services/session_store.dart';
import 'package:meta_frames/data/sync/pending_op.dart';
import 'package:meta_frames/data/sync/sync_engine.dart';

import '../../testing/fake_server.dart';
import '../../testing/local.dart';

void main() {
  late String dir;
  late FakeServer api;
  late LocalStore store;
  late SessionStore session;
  late SyncEngine engine;

  SyncEngine engineFor(LocalStore s, SessionStore session) {
    final e = SyncEngine(
      store: s,
      session: session,
      remote: (_, _) => SyncRemote(rolls: api, auth: api),
      // No timer fires during a test: each sync is started by the test.
      retryDelays: const [Duration(hours: 1)],
    );
    addTearDown(e.stop);
    return e;
  }

  setUp(() async {
    dir = await tempDir();
    api = FakeServer();
    store = await openStore(dir);
    addTearDown(() => store.close());
    session = await boundSession();
    engine = engineFor(store, session);
  });

  Future<PendingOp?> note(int frame, String text, {String? seen = ''}) =>
      store.enqueueNotes(
        kind: OpKind.frameNotes,
        rollId: 'r1',
        frame: frame,
        text: text,
        seenBase: seen,
      );

  Future<PendingOp> step(OpKind kind, String roll, String camera) =>
      store.enqueueStep(
        kind: kind,
        rollId: roll,
        cameraId: camera,
        payload: kind == OpKind.finish
            ? {'date': '2026-11-07'}
            : {
                'cameraId': camera,
                'startedAt': '2026-11-07',
                'cameraName': camera,
                'stockId': 's1',
                'stockBrand': 'Kodak',
                'stockName': 'Gold',
              },
      );

  Future<List<PendingOp>> open() => store.openOps();

  test('a note saved offline survives a restart and syncs once', () async {
    api.addRoll('r1', status: 'in_camera');
    await note(7, 'Market, backlit');
    api.faults.add(Fault.offline);
    await engine.sync();
    expect(api.writes, isEmpty);
    expect(
      (await open()).single.attempts,
      0,
      reason: 'offline before anything was sent: not attempted',
    );
    expect(engine.status.value.pause, SyncPause.offline);

    // The app is killed and opened again.
    await engine.stop();
    await store.close();
    store = await openStore(dir);
    engine = engineFor(store, session);
    expect((await open()).single.text, 'Market, backlit');

    await engine.sync();
    await engine.sync();
    expect(api.writes, ['frame:r1:7']);
    expect(api.frames[('r1', 7)], 'Market, backlit');
    expect(await open(), isEmpty);
  });

  test(
    'a lost answer then a new edit: each edit written once, in order',
    () async {
      api.addRoll('r1', status: 'in_camera');
      await note(7, 'one');
      api.faults.add(Fault.lostAnswer);
      await engine.sync();
      final first = (await open()).single;
      expect(first.state, OpState.unknown);
      expect(api.frames[('r1', 7)], 'one', reason: 'the server committed it');

      // The user edits again while the outcome is unknown.
      await note(7, 'two');
      final ops = await open();
      expect(ops.last.base, 'one', reason: 'based on the earlier edit');

      await engine.sync();
      expect(api.writes, ['frame:r1:7', 'frame:r1:7']);
      expect(api.frames[('r1', 7)], 'two');
      expect(await open(), isEmpty);
    },
  );

  test('killed mid-request: read back, never written twice', () async {
    api.addRoll('r1', status: 'in_camera');
    final op = await note(3, 'Bridge');
    await store.claim(op!);
    // The request reached the server before the app died.
    api.frames[('r1', 3)] = 'Bridge';
    await engine.stop();
    await store.close();

    store = await openStore(dir);
    engine = engineFor(store, session);
    expect((await open()).single.state, OpState.unknown);
    await engine.sync();
    expect(api.writes, isEmpty, reason: 'it was there: no second write');
    expect(api.requests, contains('GET frame:r1:3'));
    expect(await open(), isEmpty);
  });

  test('killed before the request left: sent after the read-back', () async {
    api.addRoll('r1', status: 'in_camera');
    final op = await note(3, 'Bridge');
    await store.claim(op!);
    await engine.stop();
    await store.close();

    store = await openStore(dir);
    engine = engineFor(store, session);
    await engine.sync();
    expect(api.writes, ['frame:r1:3']);
  });

  test('finish A then load B into the same camera go in that order', () async {
    api.loadOnDashboard('a', 'c', DateTime(2026, 11, 1));
    api.addRoll('b');
    api.writes.clear();
    await step(OpKind.finish, 'a', 'c');
    await step(OpKind.load, 'b', 'c');

    await engine.sync();
    expect(api.writes, ['finish:a', 'load:b']);
    expect(api.stored['b']!.cameraId, 'c');
  });

  test('a conflicted finish holds the load that depends on it', () async {
    api.addRoll('a', status: 'done_shooting').finishedAt = DateTime(2026, 1, 1);
    api.addRoll('b');
    await step(OpKind.finish, 'a', 'c');
    await step(OpKind.load, 'b', 'c');

    await engine.sync();
    final ops = await open();
    expect(ops.first.state, OpState.conflict);
    expect(ops.last.state, OpState.pending);
    expect(api.requests, isNot(contains('PUT load:b')));

    // "Use server" on the finish: the load is not sent on its own.
    await store.discard(ops.first);
    await engine.sync();
    expect(api.requests, isNot(contains('PUT load:b')));
    final load = (await open()).single;
    expect(load.state, OpState.conflict);
    expect(load.lastError, predecessorDiscarded);
  });

  test(
    'the dashboard loaded the camera first: conflict, nothing overwritten',
    () async {
      api.loadOnDashboard('x', 'c', DateTime(2026, 11, 2));
      api.addRoll('b');
      await step(OpKind.load, 'b', 'c');
      await engine.sync();
      final op = (await open()).single;
      expect(op.state, OpState.conflict);
      expect(op.lastError, 'camera_loaded');
      expect(api.stored['x']!.cameraId, 'c');
      expect(api.stored['b']!.status, 'in_stock');
    },
  );

  test(
    'a load whose answer was lost counts once the roll has moved on',
    () async {
      api.addRoll('b');
      await step(OpKind.load, 'b', 'c');
      api.faults.add(Fault.lostAnswer);
      await engine.sync();
      // Finished on the dashboard before the phone reconnects.
      api.stored['b']!
        ..status = 'done_shooting'
        ..finishedAt = DateTime(2026, 11, 8);
      await engine.sync();
      expect(await open(), isEmpty);
      expect(api.writes, ['load:b']);
    },
  );

  test('a load that landed differently is a conflict, not a success', () async {
    api.addRoll('b');
    await step(OpKind.load, 'b', 'c');
    api.faults.add(Fault.offline);
    await engine.sync();
    api.loadOnDashboard('b', 'other', DateTime(2026, 11, 7));
    // Send it as if it had been attempted and its outcome lost.
    final op = (await open()).single;
    final sent = (await store.claim(op))!;
    await store.markUnknown(sent);
    await engine.sync();
    expect((await open()).single.state, OpState.conflict);
    expect(api.stored['b']!.cameraId, 'other');
  });

  test('a finish replayed after a lost answer is not written twice', () async {
    api.loadOnDashboard('a', 'c', DateTime(2026, 11, 1));
    api.writes.clear();
    await step(OpKind.finish, 'a', 'c');
    api.faults.add(Fault.lostAnswer);
    await engine.sync();
    expect((await open()).single.state, OpState.unknown);
    await engine.sync();
    expect(api.writes, ['finish:a']);
    expect(await open(), isEmpty);
  });

  group('notes whose saved text was not on the phone', () {
    test('are checked first: the server has text, so a conflict', () async {
      api.addRoll('r1', status: 'in_camera');
      api.frames[('r1', 5)] = 'Written on the dashboard';
      await note(5, 'Written offline', seen: null);
      await engine.sync();
      final op = (await open()).single;
      expect(op.state, OpState.conflict);
      expect(op.serverValue, 'Written on the dashboard');
      expect(op.text, 'Written offline');
      expect(api.writes, isEmpty);
    });

    test('are sent based on "" when the server has none', () async {
      api.addRoll('r1', status: 'in_camera');
      await note(5, 'Written offline', seen: null);
      await engine.sync();
      expect(api.writes, ['frame:r1:5']);
    });
  });

  test('"Use server" on an edit with a follower; then "Keep mine"', () async {
    api.addRoll('r1', status: 'in_camera');
    api.frames[('r1', 2)] = 'dash';
    await note(2, 'one');
    await engine.sync();
    final conflicted = (await open()).single;
    expect(conflicted.state, OpState.conflict);
    expect(conflicted.serverValue, 'dash');
    await note(2, 'two');

    await store.discard(conflicted);
    var follower = (await open()).single;
    expect(
      follower.state,
      OpState.conflict,
      reason: 'it was based on the discarded edit',
    );
    await engine.sync();
    expect(api.writes, isEmpty);

    // Keep mine, with the server's text unknown: read again before sending.
    await store.markPending(
      follower,
      base: follower.serverValue,
      setBase: true,
    );
    await engine.sync();
    follower = (await open()).single;
    expect(follower.state, OpState.conflict);
    expect(follower.serverValue, 'dash');
    expect(api.writes, isEmpty);

    await store.markPending(
      follower,
      base: follower.serverValue,
      setBase: true,
    );
    await engine.sync();
    expect(api.writes, ['frame:r1:2']);
    expect(api.frames[('r1', 2)], 'two');
  });

  group('session', () {
    test(
      'a change of session mid-request: answer dropped, drain stops',
      () async {
        api.addRoll('r1', status: 'in_camera');
        await note(1, 'first');
        await note(2, 'second');
        api.duringWrite = () {
          api.duringWrite = null;
          session.setToken('someone-else');
        };
        await engine.sync();
        final ops = await open();
        expect(ops.first.state, OpState.unknown);
        expect(ops.last.state, OpState.pending);
        expect(api.requests.where((r) => r.startsWith('PUT')), hasLength(1));
        expect(await store.readSnapshot('/rolls/r1/frames/1'), isNull);
      },
    );

    test('signing out while an op is being claimed sends nothing', () async {
      api.addRoll('r1', status: 'in_camera');
      await note(1, 'kept');
      // The claim commits; the user signs out before the engine goes on.
      void signOut() {
        store.changes.removeListener(signOut);
        session.setToken(null);
      }

      store.changes.addListener(signOut);
      await engine.sync();
      expect(api.writes, isEmpty);
      expect(api.requests.where((r) => r.startsWith('PUT')), isEmpty);
      final op = (await open()).single;
      expect(op.state, OpState.pending, reason: 'the request never left');
      expect(op.attempts, 0);
    });

    test(
      'another account\'s session sends nothing from this partition',
      () async {
        api.addRoll('r1', status: 'in_camera');
        await note(1, 'mine');
        final other = await boundSession(user: 'u2');
        final e = engineFor(store, other);
        await e.sync();
        expect(api.requests, isEmpty);
        expect(e.status.value.pause, SyncPause.signedOut);
      },
    );

    test(
      'another server\'s session sends nothing from this partition',
      () async {
        await note(1, 'mine');
        final other = await boundSession(host: 'http://server-b');
        await engineFor(store, other).sync();
        expect(api.requests, isEmpty);
      },
    );

    test('an expired session pauses; the same account resumes', () async {
      api.addRoll('r1', status: 'in_camera');
      await note(1, 'kept');
      api.sessionEnded = true;
      await engine.sync();
      expect(session.signedIn, isFalse);
      expect((await open()).single.attempts, 0);
      expect(engine.status.value.pause, SyncPause.signedOut);

      api.sessionEnded = false;
      await session.setToken('t2');
      await session.bind(binding(), forToken: 't2');
      await engine.sync();
      expect(api.writes, ['frame:r1:1']);
    });

    test('a 401 on the write itself: unknown, then read back', () async {
      api.addRoll('r1', status: 'in_camera');
      await note(1, 'kept');
      api.faults.add(Fault.unauthorized);
      await engine.sync();
      expect(session.signedIn, isFalse);
      expect((await open()).single.state, OpState.unknown);
    });
  });
}
