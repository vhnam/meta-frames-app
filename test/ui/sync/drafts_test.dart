import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:meta_frames/data/local/local_store.dart';
import 'package:meta_frames/data/services/api_client.dart';
import 'package:meta_frames/data/sync/sync_engine.dart';
import 'package:meta_frames/domain/models/gear_requests.dart';
import 'package:meta_frames/domain/models/models.dart';
import 'package:meta_frames/domain/models/roll_requests.dart';
import 'package:meta_frames/providers.dart';
import 'package:meta_frames/ui/gear/view_models/gear_actions.dart';
import 'package:meta_frames/ui/rolls/view_models/roll_actions.dart';
import 'package:meta_frames/ui/sync/view_models/drafts.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../testing/fake_server.dart';
import '../../testing/fakes.dart';
import '../../testing/local.dart';

/// Cameras as the server keeps them, with create-only PUTs.
class _Cameras extends FakeCameraRepository {
  final byId = <String, CameraEdit>{};

  /// Ids held by another account: a create gets 412, a read gets 404.
  final hidden = <String>{};

  /// The next create: 'offline' never arrives; 'lost' lands, answer lost.
  final script = <String>[];
  int creates = 0, reads = 0;

  /// Runs when a create reaches the server, before its outcome is decided
  /// and delivered: the session can change while the request is out.
  Future<void> Function()? whileOut;

  /// Runs as a create or a read answers: what it starts (a session change on
  /// a later event) lands while the draft's cleanup is being written.
  void Function()? onAnswer;

  Camera _camera(String id, CameraEdit e) => Camera.fromJson({
    'id': id,
    'brand': e.brand,
    'model': e.model,
    'mount': e.mount,
    'hasFixedLens': e.hasFixedLens,
    'isActive': true,
  });

  @override
  Future<Camera> create(CameraEdit camera, {String? id}) async {
    final step = script.isEmpty ? null : script.removeAt(0);
    await whileOut?.call();
    if (step == 'unauthorized') throw ApiException(401, 'unauthorized', 'no');
    if (step == 'offline') throw ApiException(0, 'network', 'offline');
    if (byId.containsKey(id) || hidden.contains(id)) {
      throw ApiException(412, 'already_exists', '');
    }
    byId[id!] = camera;
    creates++;
    if (step == 'lost') throw ApiException(0, 'network', 'timeout');
    onAnswer?.call();
    return _camera(id, camera);
  }

  @override
  Future<Camera> camera(String id) async {
    reads++;
    final e = byId[id];
    onAnswer?.call();
    if (e == null) throw ApiException(404, 'not_found', '');
    return _camera(id, e);
  }
}

class _Rolls extends FakeRollRepository {
  _Rolls() : super(const []);
  bool lose = false;

  /// Runs when the request reaches the server, before it answers.
  Future<void> Function()? whileOut;

  /// Answers with rolls of another stock, as a replay of an earlier request.
  bool replayOther = false;

  @override
  Future<List<RollSummary>> addRolls(
    NewRolls rolls, {
    String? idempotencyKey,
  }) async {
    await whileOut?.call();
    final added = await super.addRolls(
      replayOther
          ? NewRolls(
              filmStockId: 'other',
              format: rolls.format,
              exposures: rolls.exposures,
              quantity: rolls.quantity,
            )
          : rolls,
      idempotencyKey: idempotencyKey,
    );
    if (lose) throw ApiException(0, 'network', 'timeout');
    return added;
  }
}

void main() {
  late String dir;
  late _Cameras cameras;
  late _Rolls rolls;

  const borrowed = CameraEdit(
    brand: 'Leica',
    model: 'M6',
    hasFixedLens: false,
    mount: 'M',
  );

  /// The app's providers on a partition file in [dir]: a new container is an
  /// app restart.
  Future<ProviderContainer> app() async {
    SharedPreferences.setMockInitialValues({'base_url': server});
    final api = FakeServer();
    final c = ProviderContainer(
      overrides: [
        prefsProvider.overrideWithValue(await SharedPreferences.getInstance()),
        sessionStoreProvider.overrideWithValue(await boundSession()),
        localDataProvider.overrideWithValue((
          factory: testDbFactory(),
          dir: dir,
        )),
        syncRemoteProvider.overrideWithValue(
          (_, _) => SyncRemote(rolls: api, auth: api),
        ),
        // Any token but the first one's belongs to another account.
        verifySessionProvider.overrideWithValue(
          (_, token) async => token == 't1'
              ? api.me()
              : User.fromJson({'id': 'u2', 'email': 'u2@example.com'}),
        ),
        cameraRepositoryProvider.overrideWithValue(cameras),
        rollRepositoryProvider.overrideWithValue(rolls),
      ],
    );
    addTearDown(c.dispose);
    final sub = c.listen(localStoreProvider, (_, _) {});
    addTearDown(sub.close);
    for (var i = 0; i < 200 && c.read(localStoreProvider) == null; i++) {
      await Future<void>.delayed(const Duration(milliseconds: 5));
    }
    expect(c.read(localStoreProvider), isNotNull);
    return c;
  }

  Future<Camera> createCamera(ProviderContainer c, String id) {
    final actions = c.read(cameraActionsProvider);
    return c
        .read(draftActionsProvider)
        .submit(
          id: id,
          kind: DraftKind.camera,
          label: 'Leica M6',
          form: {'request': borrowed.toJson()},
          send: () => actions.save(borrowed, id: id),
          readBack: () => actions.landed(id, borrowed),
        );
  }

  setUp(() async {
    dir = await tempDir();
    cameras = _Cameras();
    rolls = _Rolls();
  });

  test(
    'a create whose answer was lost: kept over a restart, never doubled',
    () async {
      var c = await app();
      cameras.script.add('lost');
      await expectLater(createCamera(c, 'cam-1'), throwsA(isA<ApiException>()));
      c.dispose();

      c = await app();
      final store = c.read(localStoreProvider)!;
      final draft = (await store.drafts()).single;
      expect(draft.id, 'cam-1');
      expect(CameraEdit.fromJson(draft.json['request']).model, 'M6');

      // Sent again under the draft's id: the server already has it.
      final saved = await createCamera(c, draft.id);
      expect(saved.id, 'cam-1');
      expect(cameras.creates, 1);
      expect(await store.drafts(), isEmpty);
    },
  );

  test(
    'a create that never left is kept as a draft before the request',
    () async {
      final c = await app();
      cameras.script.add('offline');
      await expectLater(createCamera(c, 'cam-2'), throwsA(isA<ApiException>()));
      final draft = (await c.read(localStoreProvider)!.drafts()).single;
      expect(draft.error, isNotNull);
      expect(cameras.byId, isEmpty);
    },
  );

  test('an id held by a different camera: conflict shown, draft kept under its '
      'id, no second create', () async {
    final c = await app();
    cameras.byId['cam-3'] = const CameraEdit(
      brand: 'Nikon',
      model: 'FM2',
      hasFixedLens: false,
      mount: 'F',
    );
    for (var i = 0; i < 2; i++) {
      await expectLater(
        createCamera(c, 'cam-3'),
        throwsA(isA<ApiException>().having((e) => e.status, 'status', 412)),
      );
    }
    expect(cameras.byId['cam-3']!.model, 'FM2');
    expect(cameras.creates, 0);
    final drafts = await c.read(localStoreProvider)!.drafts();
    expect(drafts.single.id, 'cam-3');
    expect(drafts.single.error, isNotNull);
    expect(drafts.single.json['request']['model'], 'M6');
  });

  test(
    'an id held by another account: draft kept under a new id, nothing sent',
    () async {
      final c = await app();
      cameras.hidden.add('cam-4');
      await expectLater(createCamera(c, 'cam-4'), throwsA(isA<DraftIdTaken>()));
      expect(cameras.byId, isEmpty);
      final drafts = await c.read(localStoreProvider)!.drafts();
      expect(drafts.single.id, isNot('cam-4'));
      expect(drafts.single.json['request']['model'], 'M6');
      // Saved again from that draft, it is created under its new id.
      final saved = await createCamera(c, drafts.single.id);
      expect(saved.id, drafts.single.id);
      expect(cameras.creates, 1);
      expect(await c.read(localStoreProvider)!.drafts(), isEmpty);
    },
  );

  group('a session change while a create is under way', () {
    Future<void> signOut(ProviderContainer c) async {
      final store = c.read(localStoreProvider)!;
      await c.read(sessionStoreProvider).setToken(null);
      for (var i = 0; i < 200 && !store.isClosed; i++) {
        await Future<void>.delayed(const Duration(milliseconds: 5));
      }
      expect(store.isClosed, isTrue, reason: 'the partition closed');
    }

    /// The new account's session finishes verifying (it binds), so nothing is
    /// left running when the test ends.
    Future<void> settle(ProviderContainer c) async {
      final session = c.read(sessionStoreProvider);
      for (var i = 0; i < 200 && session.binding == null; i++) {
        await Future<void>.delayed(const Duration(milliseconds: 5));
      }
    }

    /// What the original account still holds, read from its file.
    Future<List<Draft>> kept() async {
      final store = await openStore(dir);
      addTearDown(store.close);
      return store.drafts();
    }

    Future<Camera> create(ProviderContainer c, String id) =>
        createCamera(c, id);

    test(
      'another account while the draft is being saved: nothing sent',
      () async {
        final c = await app();
        final store = c.read(localStoreProvider)!;
        final pending = create(c, 'cam-5');
        // Synchronously: the draft's write has not finished.
        await c.read(sessionStoreProvider).setToken('someone-else');
        await expectLater(pending, throwsA(isA<SessionChanged>()));
        expect(cameras.creates, 0);
        expect(cameras.byId, isEmpty, reason: 'the draft was not sent as them');
        await settle(c);
        for (var i = 0; i < 200 && !store.isClosed; i++) {
          await Future<void>.delayed(const Duration(milliseconds: 5));
        }
        c.dispose();
        expect((await kept()).single.id, 'cam-5');
      },
    );

    test(
      'another server while the draft is being saved: nothing sent',
      () async {
        final c = await app();
        final pending = create(c, 'cam-6');
        await c.read(settingsRepositoryProvider).setBaseUrl('http://server-b');
        await expectLater(pending, throwsA(isA<SessionChanged>()));
        expect(cameras.byId, isEmpty);
        expect(cameras.reads, 0);
      },
    );

    test(
      'logout while the request is out: landed, not delivered, kept',
      () async {
        var c = await app();
        cameras.whileOut = () => signOut(c);
        await expectLater(create(c, 'cam-7'), throwsA(isA<SessionChanged>()));
        expect(cameras.creates, 1, reason: 'the request had left');
        c.dispose();
        // Not masked by a failed write on the closed partition, and not lost.
        expect((await kept()).single.id, 'cam-7');

        // The same account again: the same id reads back what landed.
        cameras.whileOut = null;
        c = await app();
        final saved = await create(c, 'cam-7');
        expect(saved.id, 'cam-7');
        expect(cameras.creates, 1, reason: 'never doubled');
        expect(await c.read(localStoreProvider)!.drafts(), isEmpty);
      },
    );

    for (final step in ['offline', 'unauthorized']) {
      test(
        '$step after logout: a session change, draft left as saved',
        () async {
          final c = await app();
          cameras.script.add(step);
          cameras.whileOut = () => signOut(c);
          await expectLater(create(c, 'cam-8'), throwsA(isA<SessionChanged>()));
          c.dispose();
          final draft = (await kept()).single;
          expect(draft.id, 'cam-8');
          expect(
            draft.error,
            isNull,
            reason: 'no error of the old session kept',
          );
        },
      );
    }

    test('412 after logout: no read-back, no new id', () async {
      final c = await app();
      cameras.hidden.add('cam-9');
      cameras.whileOut = () => signOut(c);
      await expectLater(create(c, 'cam-9'), throwsA(isA<SessionChanged>()));
      expect(cameras.reads, 0);
      c.dispose();
      expect((await kept()).single.id, 'cam-9');
    });

    test('another account before the 412 read-back: nothing is read', () async {
      final c = await app();
      cameras.byId['cam-10'] = borrowed;
      cameras.whileOut = () async {
        await c.read(sessionStoreProvider).setToken('someone-else');
      };
      await expectLater(create(c, 'cam-10'), throwsA(isA<SessionChanged>()));
      expect(cameras.reads, 0);
      expect(cameras.creates, 0);
      await settle(c);
    });

    /// Starts [change] on a later event: the answer is delivered, and the
    /// draft's cleanup is the only thing left running when it lands.
    void later(Future<void> Function() change) =>
        cameras.onAnswer = () => Future(change);

    for (final server in [false, true]) {
      test('${server ? 'another server' : 'logout'} while the finished '
          'create is cleaned up: not delivered as a success', () async {
        final c = await app();
        later(
          () async => server
              ? c.read(settingsRepositoryProvider).setBaseUrl('http://b')
              : c.read(sessionStoreProvider).setToken(null),
        );
        await expectLater(create(c, 'cam-13'), throwsA(isA<SessionChanged>()));
        expect(cameras.creates, 1, reason: 'it did land');
        await Future<void>.delayed(const Duration(milliseconds: 50));
      });
    }

    test('logout while a taken id is moved: no id of the old session '
        'is delivered', () async {
      final c = await app();
      cameras.hidden.add('cam-14');
      later(() async => c.read(sessionStoreProvider).setToken(null));
      await expectLater(create(c, 'cam-14'), throwsA(isA<SessionChanged>()));
      expect(cameras.creates, 0);
      await Future<void>.delayed(const Duration(milliseconds: 50));
      c.dispose();
      // The draft is in the file, under its id or the new one, never lost.
      expect(await kept(), hasLength(1));
    });
  });

  group('added rolls', () {
    const bought = NewRolls(
      filmStockId: 's1',
      format: 120,
      exposures: 12,
      quantity: 3,
    );

    Future<List<RollSummary>> add(ProviderContainer c, String key) => c
        .read(draftActionsProvider)
        .submit(
          id: key,
          kind: DraftKind.rolls,
          label: '3 × Gold',
          form: {'request': bought.toJson()},
          send: () =>
              c.read(rollActionsProvider).add(bought, idempotencyKey: key),
        );

    test('keep one idempotency key across a restart', () async {
      var c = await app();
      rolls.lose = true;
      await expectLater(add(c, 'key-1'), throwsA(isA<ApiException>()));
      c.dispose();

      c = await app();
      rolls.lose = false;
      final draft = (await c.read(localStoreProvider)!.drafts()).single;
      expect(await add(c, draft.id), hasLength(3));
      expect(rolls.keys, ['key-1', 'key-1']);
      expect(await c.read(localStoreProvider)!.drafts(), isEmpty);
    });

    test('a replay of other values is kept under a new key', () async {
      final c = await app();
      rolls.replayOther = true;
      await expectLater(add(c, 'key-2'), throwsA(isA<DraftIdTaken>()));
      final draft = (await c.read(localStoreProvider)!.drafts()).single;
      expect(draft.id, isNot('key-2'));
      expect(draft.json['request']['quantity'], 3);
    });

    test('a session change while the rolls request is out writes no draft '
        'to the new partition', () async {
      final c = await app();
      rolls.replayOther = true;
      rolls.whileOut = () async {
        await c.read(sessionStoreProvider).setToken('someone-else');
      };
      await expectLater(add(c, 'key-3'), throwsA(isA<SessionChanged>()));
      // Wait for the new account's partition, then read it.
      for (var i = 0; i < 200; i++) {
        final s = c.read(localStoreProvider);
        if (s != null && !s.isClosed) break;
        await Future<void>.delayed(const Duration(milliseconds: 5));
      }
      final now = c.read(localStoreProvider);
      expect(now == null || await now.drafts().then((d) => d.isEmpty), isTrue);
      await Future<void>.delayed(const Duration(milliseconds: 50));
      c.dispose();
      // The first account's draft stays under its own key, in its own file.
      final old = await openStore(dir);
      addTearDown(old.close);
      expect((await old.drafts()).map((d) => d.id), ['key-3']);
    });
  });
}
