import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:meta_frames/data/local/local_store.dart';
import 'package:meta_frames/data/services/session_store.dart';
import 'package:meta_frames/data/sync/pending_op.dart';

import '../../testing/local.dart';

void main() {
  late String dir;
  setUp(() async => dir = await tempDir());

  group('durable on a real file', () {
    test('notes, steps, drafts and reads survive close and reopen', () async {
      var store = await openStore(dir);
      await store.enqueueNotes(
        kind: OpKind.frameNotes,
        rollId: 'r1',
        frame: 7,
        text: 'Market, backlit',
        seenBase: '',
      );
      await store.enqueueStep(
        kind: OpKind.finish,
        rollId: 'r1',
        cameraId: 'c1',
        payload: {'date': '2026-11-07'},
      );
      await store.saveDraft('d1', DraftKind.camera, {
        'request': {'brand': 'Leica', 'model': 'M6'},
      });
      await store.writeSnapshot('/cameras', 200, const [], epoch: store.epoch);
      await store.close();

      store = await openStore(dir);
      addTearDown(store.close);
      final ops = await store.openOps();
      expect(ops.map((o) => o.kind), [OpKind.frameNotes, OpKind.finish]);
      expect(ops.first.text, 'Market, backlit');
      expect(ops.first.base, '');
      expect((await store.draft('d1'))!.json['request']['model'], 'M6');
      final cams = await store.readSnapshot('/cameras');
      expect(cams!.json, isEmpty, reason: 'an empty answer is kept as empty');
      expect(await store.readSnapshot('/labs'), isNull);
    });

    test('an op left sending by a killed app reopens as unknown', () async {
      var store = await openStore(dir);
      final op = await store.enqueueNotes(
        kind: OpKind.rollNotes,
        rollId: 'r1',
        text: 'Overcast',
        seenBase: '',
      );
      await store.claim(op!);
      await store.close();

      store = await openStore(dir);
      addTearDown(store.close);
      final again = (await store.openOps()).single;
      expect(again.state, OpState.unknown);
      expect(again.attempts, 1);
    });

    test('a file belonging to another account is refused', () async {
      final a = await openStore(dir);
      await a.close();
      // u1's file under u2's name, as if copied by hand.
      const u2 = PartitionKey(server, 'u2');
      await File(a.path).copy(p.join(dir, u2.fileName));
      await expectLater(openStore(dir, user: 'u2'), throwsStateError);
    });
  });

  group('editing a note', () {
    test(
      'an edit never attempted is rewritten in place, keeping its base',
      () async {
        final store = await openStore(dir);
        addTearDown(store.close);
        await store.enqueueNotes(
          kind: OpKind.frameNotes,
          rollId: 'r1',
          frame: 3,
          text: 'one',
          seenBase: 'saved',
        );
        await store.enqueueNotes(
          kind: OpKind.frameNotes,
          rollId: 'r1',
          frame: 3,
          text: 'two',
          seenBase: 'ignored',
        );
        final op = (await store.openOps()).single;
        expect(op.text, 'two');
        expect(op.base, 'saved');
      },
    );

    test('an edit after an attempt follows it, based on its text', () async {
      final store = await openStore(dir);
      addTearDown(store.close);
      final first = await store.enqueueNotes(
        kind: OpKind.frameNotes,
        rollId: 'r1',
        frame: 3,
        text: 'one',
        seenBase: '',
      );
      final sent = (await store.claim(first!))!;
      await store.markUnknown(sent);
      await store.enqueueNotes(
        kind: OpKind.frameNotes,
        rollId: 'r1',
        frame: 3,
        text: 'two',
        seenBase: 'ignored',
      );
      final ops = await store.openOps();
      expect(ops, hasLength(2));
      expect(ops.last.base, 'one');
      expect(ops.last.predecessor, ops.first.opId);
      // The follower waits: the unknown one is read back first.
      expect((await store.nextRunnable())!.opId, ops.first.opId);
    });

    test('no change to what the user saw records nothing', () async {
      final store = await openStore(dir);
      addTearDown(store.close);
      expect(
        await store.enqueueNotes(
          kind: OpKind.rollNotes,
          rollId: 'r1',
          text: ' same ',
          seenBase: 'same',
        ),
        isNull,
      );
      expect(await store.openOps(), isEmpty);
    });
  });

  group('order', () {
    test('a load waits for the finish on the same camera', () async {
      final store = await openStore(dir);
      addTearDown(store.close);
      final finish = await store.enqueueStep(
        kind: OpKind.finish,
        rollId: 'a',
        cameraId: 'c',
        payload: {'date': '2026-11-07'},
      );
      await store.enqueueStep(
        kind: OpKind.load,
        rollId: 'b',
        cameraId: 'c',
        payload: {'startedAt': '2026-11-07'},
      );
      expect((await store.nextRunnable())!.opId, finish.opId);
      await store.markConflict(finish, error: 'roll_not_in_camera');
      expect(
        await store.nextRunnable(),
        isNull,
        reason: 'a conflict holds what depends on it',
      );
    });

    test('discarding a step turns its dependants into conflicts', () async {
      final store = await openStore(dir);
      addTearDown(store.close);
      final finish = await store.enqueueStep(
        kind: OpKind.finish,
        rollId: 'a',
        cameraId: 'c',
        payload: {'date': '2026-11-07'},
      );
      await store.enqueueStep(
        kind: OpKind.load,
        rollId: 'b',
        cameraId: 'c',
        payload: {'startedAt': '2026-11-07'},
      );
      final note = await store.enqueueNotes(
        kind: OpKind.frameNotes,
        rollId: 'b',
        frame: 1,
        text: 'unrelated',
        seenBase: '',
      );
      await store.markConflict(finish, error: 'roll_not_in_camera');
      await store.discard(finish);

      final ops = await store.openOps();
      final load = ops.firstWhere((o) => o.kind == OpKind.load);
      expect(load.state, OpState.conflict);
      expect(load.lastError, predecessorDiscarded);
      expect(
        ops.firstWhere((o) => o.opId == note!.opId).state,
        OpState.pending,
        reason: 'a note shares no key with the finish',
      );
    });
  });

  group('reads', () {
    test('an answer from before a change landed is not stored', () async {
      final store = await openStore(dir);
      addTearDown(store.close);
      final op = await store.enqueueStep(
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
      final readStarted = store.epoch;
      await store.writeSnapshot('/cameras', 200, [
        {'id': 'c1', 'loadedRoll': null},
      ], epoch: store.epoch);
      await store.complete(op);
      final stored = await store.writeSnapshot('/cameras', 200, [
        {'id': 'c1', 'loadedRoll': null},
      ], epoch: readStarted);
      expect(stored, isFalse);
      final cams = (await store.readSnapshot('/cameras'))!.json as List;
      expect(
        cams.single['loadedRoll']['rollId'],
        'r1',
        reason: 'the completed load patched the stored list',
      );
    });

    test(
      'a frame missing from a fetched roll is "no frame", not unknown',
      () async {
        final store = await openStore(dir);
        addTearDown(store.close);
        expect(await store.readFrameSnapshot('r1', 4), isNull);
        await store.writeSnapshot('/rolls/r1', 200, {
          'roll': {'id': 'r1'},
          'frames': [
            {'number': 2, 'notes': 'kept'},
          ],
        }, epoch: store.epoch);
        expect((await store.readFrameSnapshot('r1', 4))!.status, 404);
        expect((await store.readFrameSnapshot('r1', 2))!.json['notes'], 'kept');
      },
    );
  });

  test(
    'one camera is read from the kept camera list when not kept alone',
    () async {
      final store = await openStore(dir);
      addTearDown(store.close);
      expect(await store.readCameraSnapshot('c1'), isNull);
      await store.writeSnapshot('/cameras', 200, [
        {'id': 'c1', 'model': 'FM2'},
      ], epoch: store.epoch);
      expect((await store.readCameraSnapshot('c1'))!.json['model'], 'FM2');
      expect(
        await store.readCameraSnapshot('c2'),
        isNull,
        reason: 'not in the list: unknown, not invented',
      );
    },
  );

  test('moveDraft is all or nothing', () async {
    final store = await openStore(dir);
    addTearDown(store.close);
    await store.saveDraft('old', DraftKind.lab, {'label': 'a'});
    await store.saveDraft('taken', DraftKind.lab, {'label': 'b'});

    await store.moveDraft('old', 'new', DraftKind.lab, {'label': 'c'});
    expect((await store.drafts()).map((d) => d.id), ['taken', 'new']);

    // The insert fails (the id is held): the delete must roll back with it.
    await expectLater(
      store.moveDraft('new', 'taken', DraftKind.lab, {'label': 'd'}),
      throwsA(anything),
    );
    final left = {for (final d in await store.drafts()) d.id: d.json['label']};
    expect(left, {'taken': 'b', 'new': 'c'});
  });

  test('other partitions list counts, never contents', () async {
    final a = await openStore(dir);
    await a.enqueueNotes(
      kind: OpKind.frameNotes,
      rollId: 'r1',
      frame: 1,
      text: 'private',
      seenBase: '',
    );
    await a.saveDraft('d', DraftKind.lab, {
      'request': {'name': 'Lab'},
    });
    await a.close();
    final b = await openStore(dir, user: 'u2');
    await b.close();

    final list = await LocalStore.list(testDbFactory(), dir);
    final mine = list.firstWhere((p) => p.key.userId == 'u1');
    expect(mine.openOps, 1);
    expect(mine.drafts, 1);
    expect(mine.email, 'u1@example.com');
    expect(list.firstWhere((p) => p.key.userId == 'u2').hasUnsynced, isFalse);
  });

  test('a draft asked for just before close is written, not lost', () async {
    final store = await openStore(dir);
    // Not awaited: the write is asked for, then the partition is closed.
    final saved = store.saveDraft('d', DraftKind.lab, {'label': 'Lab'});
    await store.close();
    await saved;
    final reopened = await openStore(dir);
    addTearDown(reopened.close);
    expect((await reopened.drafts()).single.id, 'd');
  });

  group('session binding', () {
    test('a binding is kept only with the token it was verified for', () {
      final stored = storedBinding('token-a', binding());
      expect(bindingFor('token-a', stored), binding());
      expect(bindingFor('token-b', stored), isNull);
    });

    test('a new token has no account until verified', () async {
      final s = await boundSession(token: 'old');
      await s.setToken('new');
      expect(s.binding, isNull);
      // A slow answer for the old token cannot bind the new one.
      expect(await s.bind(binding(user: 'u9'), forToken: 'old'), isFalse);
      expect(s.binding, isNull);
    });
  });

  group('session persistence', sessionPersistenceTests);

  group('interleavings', () {
    test('an edit between select and claim is not lost', () async {
      final store = await openStore(dir);
      addTearDown(store.close);
      await store.enqueueNotes(
        kind: OpKind.rollNotes,
        rollId: 'roll-1',
        text: 'A',
        seenBase: '',
      );
      final selected = (await store.nextRunnable())!;
      await store.enqueueNotes(
        kind: OpKind.rollNotes,
        rollId: 'roll-1',
        text: 'B',
        seenBase: 'A',
      );
      expect(
        await store.claim(selected),
        isNull,
        reason: 'the row no longer asks for what was selected',
      );
      // The engine selects again and sends what is stored now.
      final next = (await store.nextRunnable())!;
      expect(next.text, 'B');
      final claimed = (await store.claim(next))!;
      expect(claimed.text, 'B');
      // An edit after the claim follows as its own operation.
      await store.enqueueNotes(
        kind: OpKind.rollNotes,
        rollId: 'roll-1',
        text: 'C',
        seenBase: 'B',
      );
      await store.complete(claimed);
      expect((await store.openOps()).map((o) => o.text), ['C']);
    });

    test('an answer for a stale op does not finish a newer edit', () async {
      final store = await openStore(dir);
      addTearDown(store.close);
      // Base unknown: read from the server before sending, so the op can be
      // rewritten while that read is out.
      await store.enqueueNotes(
        kind: OpKind.frameNotes,
        rollId: 'roll-1',
        frame: 3,
        text: 'A',
        seenBase: null,
      );
      final read = (await store.nextRunnable())!;
      await store.enqueueNotes(
        kind: OpKind.frameNotes,
        rollId: 'roll-1',
        frame: 3,
        text: 'B',
        seenBase: null,
      );
      await store.complete(read);
      await store.markConflict(read, error: 'frame_notes_conflict');
      final open = await store.openOps();
      expect(open.single.text, 'B');
      expect(open.single.state, OpState.pending);
    });

    test('a choice made on a stale card cannot revive a sent change', () async {
      final store = await openStore(dir);
      addTearDown(store.close);
      final op = (await store.enqueueNotes(
        kind: OpKind.rollNotes,
        rollId: 'roll-1',
        text: 'A',
        seenBase: '',
      ))!;
      await store.markConflict(
        op,
        error: 'roll_notes_conflict',
        serverValue: 'S',
      );
      // What the screen holds: the conflict, with "Keep mine" on it.
      final card = (await store.op(op.opId))!;
      await store.markPending(card, base: 'S', setBase: true);
      final claimed = (await store.claim((await store.nextRunnable())!))!;
      await store.complete(claimed);
      // The same button again, from the same card.
      await store.markPending(card, base: 'S', setBase: true);
      await store.markUnknown(card);
      expect(await store.openOps(), isEmpty);
      expect((await store.op(op.opId))!.state, OpState.done);
    });

    test('dropping a change that is already done holds nothing back', () async {
      final store = await openStore(dir);
      addTearDown(store.close);
      final first = await store.enqueueStep(
        kind: OpKind.finish,
        rollId: 'r1',
        cameraId: 'c1',
        payload: {'date': '2026-11-07'},
      );
      final second = await store.enqueueStep(
        kind: OpKind.load,
        rollId: 'r2',
        cameraId: 'c1',
        payload: {'cameraId': 'c1', 'startedAt': '2026-11-07'},
      );
      await store.complete((await store.claim(first))!);
      // "Use server" from a card that was not refreshed after the finish.
      await store.discard(first);
      final next = (await store.op(second.opId))!;
      expect(next.state, OpState.pending, reason: 'its step did land');
    });

    test(
      'a change dropped while on its way stays dropped when it lands',
      () async {
        final store = await openStore(dir);
        addTearDown(store.close);
        final op = await store.enqueueStep(
          kind: OpKind.finish,
          rollId: 'r1',
          cameraId: 'c1',
          payload: {'date': '2026-11-07'},
        );
        final sent = (await store.claim(op))!;
        await store.discard(sent);
        await store.complete(
          sent,
          detail: {
            'roll': {'id': 'r1', 'status': 'done_shooting'},
          },
        );
        expect(await store.op(op.opId), isNull, reason: 'not brought back');
        expect(await store.openOps(), isEmpty);
        // What is kept is what the server answered.
        final kept = (await store.readSnapshot('/rolls/r1'))!.json;
        expect(kept['roll']['status'], 'done_shooting');
      },
    );

    test('a read stored while a change completes is refused', () async {
      final store = await openStore(dir);
      addTearDown(store.close);
      final op = await store.enqueueStep(
        kind: OpKind.finish,
        rollId: 'r1',
        cameraId: 'c1',
        payload: {'date': '2026-11-07'},
      );
      await store.writeSnapshot('/rolls/r1', 200, {
        'roll': {'id': 'r1', 'status': 'shooting'},
      }, epoch: store.epoch);
      final readStarted = store.epoch;
      // The stale answer arrives while the completion is already running.
      final completing = store.complete(
        op,
        detail: {
          'roll': {'id': 'r1', 'status': 'done'},
        },
      );
      final stale = store.writeSnapshot('/rolls/r1', 200, {
        'roll': {'id': 'r1', 'status': 'shooting'},
      }, epoch: readStarted);
      await completing;
      expect(await stale, isFalse);
      final stored = (await store.readSnapshot('/rolls/r1'))!.json;
      expect(stored['roll']['status'], 'done');
    });

    test('a read stored while a discard runs is refused', () async {
      final store = await openStore(dir);
      addTearDown(store.close);
      final op = await store.enqueueStep(
        kind: OpKind.finish,
        rollId: 'r1',
        cameraId: 'c1',
        payload: {'date': '2026-11-07'},
      );
      final readStarted = store.epoch;
      final discarding = store.discard(op);
      final stale = store.writeSnapshot('/cameras', 200, const [
        {'id': 'c1'},
      ], epoch: readStarted);
      await discarding;
      expect(await stale, isFalse);
      expect(await store.readSnapshot('/cameras'), isNull);
    });
  });
}

class _SlowStorageSession extends SessionStore {
  _SlowStorageSession(super.token);

  /// What storage holds after the writes so far, as (token, binding user).
  (String?, String?) stored = (null, null);
  int running = 0, overlapped = 0;

  @override
  Future<void> persist(String? token, SessionBinding? binding) async {
    if (++running > 1) overlapped++;
    // An earlier write is slower than a later one.
    await Future<void>.delayed(Duration(milliseconds: token == null ? 1 : 20));
    stored = (token, binding?.userId);
    running--;
  }
}

void sessionPersistenceTests() {
  test('a slow save cannot land after a later sign-out', () async {
    final s = _SlowStorageSession('t1');
    final binding_ = s.bind(binding(), forToken: 't1');
    final signOut = s.setToken(null);
    await Future.wait([binding_, signOut]);
    expect(s.stored, (null, null));
    expect(s.overlapped, 0, reason: 'saves run one after the other');
  });
}
