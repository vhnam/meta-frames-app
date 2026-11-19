import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:meta_frames/data/local/local_store.dart';
import 'package:meta_frames/data/services/session_store.dart';
import 'package:meta_frames/data/sync/pending_op.dart';
import 'package:meta_frames/data/sync/sync_engine.dart';
import 'package:meta_frames/providers.dart';
import 'package:meta_frames/ui/sync/view_models/sync_summary.dart';

import '../../testing/local.dart';

class ObservedSession extends SessionStore {
  ObservedSession(SessionBinding account) : super('t1', account);

  bool get listening => hasListeners;
}

class QueueReadStore implements LocalStore {
  QueueReadStore(this.key);

  @override
  final PartitionKey key;

  @override
  final changes = ValueNotifier<int>(0);

  @override
  bool get isClosed => false;

  var pending = Completer<List<PendingOp>>();
  final savedDrafts = Completer<List<Draft>>();

  @override
  Future<List<PendingOp>> openOps() => pending.future;

  @override
  Future<List<Draft>> drafts([DraftKind? kind]) => savedDrafts.future;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

const storeKey = PartitionKey(server, 'u1');
const emptyOps = AsyncData<List<PendingOp>>([]);
const emptyDrafts = AsyncData<List<Draft>>([]);

final blockedOps = [
  PendingOp(
    seq: 1,
    opId: 'blocked',
    kind: OpKind.rollNotes,
    rollId: 'roll',
    payload: const {},
    state: OpState.conflict,
    createdAt: DateTime.utc(2026),
    updatedAt: DateTime.utc(2026),
  ),
];

SyncSummary? summary({
  bool signedIn = true,
  PartitionKey? key = storeKey,
  SessionBinding? account,
  SyncStatus? status = const SyncStatus(),
  AsyncValue<List<PendingOp>> ops = emptyOps,
  AsyncValue<List<Draft>> drafts = emptyDrafts,
}) => summarizeSync(
  signedIn: signedIn,
  storeKey: key,
  binding: account,
  status: status,
  ops: ops,
  drafts: drafts,
);

void expectState(
  SyncSummary? result,
  SyncSummaryState state, {
  bool attention = false,
}) {
  expect(result?.state, state);
  expect(result?.attention, attention);
  if (state != SyncSummaryState.upToDate) {
    expect(result?.line, isNot(contains('Up to date')));
  }
}

void main() {
  test('no token takes priority over an open store and loaded changes', () {
    expect(
      summary(signedIn: false, account: binding(), ops: AsyncData(blockedOps)),
      isNull,
    );
  });

  test('token without an open store reports unavailable storage', () {
    for (final account in [null, binding()]) {
      expectState(
        summary(key: null, account: account),
        SyncSummaryState.storeUnavailable,
      );
    }
  });

  test('old store hides loaded changes until the session matches', () {
    for (final account in [
      null,
      binding(user: 'u2'),
      binding(host: 'http://server-b'),
    ]) {
      expectState(
        summary(account: account, ops: AsyncData(blockedOps)),
        SyncSummaryState.loading,
      );
    }
  });

  test('each failed read reports unavailable data', () {
    final failure = Exception('read failed');
    expectState(
      summary(account: binding(), ops: AsyncError(failure, StackTrace.empty)),
      SyncSummaryState.dataUnavailable,
    );
    expectState(
      summary(
        account: binding(),
        drafts: AsyncError(failure, StackTrace.empty),
      ),
      SyncSummaryState.dataUnavailable,
    );
  });

  test('reload clears previous attention and previous read errors', () async {
    final store = await openStore(await tempDir());
    addTearDown(store.close);
    final session = await boundSession();
    addTearDown(session.dispose);
    var nextRead = Completer<List<PendingOp>>()..complete(blockedOps);
    final container = ProviderContainer.test(
      retry: (_, _) => null,
      overrides: [
        sessionStoreProvider.overrideWithValue(session),
        localStoreProvider.overrideWithValue(store),
        syncStatusProvider.overrideWithValue(const SyncStatus()),
        openOpsProvider.overrideWith((_) => nextRead.future),
        draftsProvider.overrideWith((_) async => []),
      ],
    );
    final subscription = container.listen(syncSummaryProvider, (_, _) {});
    await container.read(openOpsProvider.future);
    await container.read(draftsProvider.future);
    expectState(subscription.read(), SyncSummaryState.blocked, attention: true);

    nextRead = Completer<List<PendingOp>>();
    container.invalidate(openOpsProvider);
    expectState(subscription.read(), SyncSummaryState.loading);

    final failedRead = expectLater(
      container.read(openOpsProvider.future),
      throwsException,
    );
    nextRead.completeError(Exception('read failed'));
    await failedRead;
    expectState(subscription.read(), SyncSummaryState.dataUnavailable);

    nextRead = Completer<List<PendingOp>>();
    container.invalidate(openOpsProvider);
    expectState(subscription.read(), SyncSummaryState.loading);
    nextRead.complete([]);
    await container.read(openOpsProvider.future);
    expectState(subscription.read(), SyncSummaryState.upToDate);
  });

  test('failed queue reads report unavailable data without retrying', () async {
    final session = await boundSession();
    addTearDown(session.dispose);
    final store = QueueReadStore(storeKey);
    addTearDown(store.changes.dispose);
    final pending = Completer<List<PendingOp>>();
    final savedDrafts = Completer<List<Draft>>();
    var opsReads = 0;
    var draftReads = 0;
    final container = ProviderContainer.test(
      retry: (attempt, _) => attempt == 0 ? Duration.zero : null,
      overrides: [
        sessionStoreProvider.overrideWithValue(session),
        localStoreProvider.overrideWithValue(store),
        syncStatusProvider.overrideWithValue(const SyncStatus()),
        openOpsProvider.overrideWith((_) async {
          return ++opsReads == 1 ? pending.future : [];
        }),
        draftsProvider.overrideWith((_) async {
          return ++draftReads == 1 ? savedDrafts.future : [];
        }),
      ],
    );
    final subscription = container.listen(syncSummaryProvider, (_, _) {});
    final failedOps = expectLater(
      container.read(openOpsProvider.future),
      throwsException,
    );
    final failedDrafts = expectLater(
      container.read(draftsProvider.future),
      throwsException,
    );
    pending.completeError(Exception('operations read failed'));
    savedDrafts.completeError(Exception('drafts read failed'));
    await Future.wait([failedOps, failedDrafts]);
    expectState(subscription.read(), SyncSummaryState.dataUnavailable);

    await Future<void>.delayed(Duration.zero);
    await container.pump();
    expect(opsReads, 1);
    expect(draftReads, 1);
    expectState(subscription.read(), SyncSummaryState.dataUnavailable);
  });

  test(
    'store notifications reload a failed read and publish the new result',
    () async {
      final session = await boundSession();
      addTearDown(session.dispose);
      final store = QueueReadStore(storeKey);
      addTearDown(store.changes.dispose);
      store.savedDrafts.complete([]);
      final container = ProviderContainer.test(
        overrides: [
          sessionStoreProvider.overrideWithValue(session),
          localStoreProvider.overrideWithValue(store),
          syncStatusProvider.overrideWithValue(const SyncStatus()),
        ],
      );
      final subscription = container.listen(syncSummaryProvider, (_, _) {});
      final failedRead = expectLater(
        container.read(openOpsProvider.future),
        throwsException,
      );
      store.pending.completeError(Exception('operations read failed'));
      await failedRead;
      await container.read(draftsProvider.future);
      expectState(subscription.read(), SyncSummaryState.dataUnavailable);

      store.pending = Completer<List<PendingOp>>();
      store.changes.value++;
      expectState(subscription.read(), SyncSummaryState.loading);
      store.pending.complete(blockedOps);
      await container.read(openOpsProvider.future);
      await container.read(draftsProvider.future);
      expectState(
        subscription.read(),
        SyncSummaryState.blocked,
        attention: true,
      );
    },
  );

  for (final (active, reopen) in [
    (true, false),
    (false, false),
    (true, true),
    (false, true),
  ]) {
    test(
      'new store loads without old retry errors (active: $active, same key: $reopen)',
      () async {
        final session = await boundSession();
        addTearDown(session.dispose);
        final previous = QueueReadStore(storeKey);
        final next = QueueReadStore(
          reopen ? storeKey : const PartitionKey(server, 'u2'),
        );
        addTearDown(previous.changes.dispose);
        addTearDown(next.changes.dispose);
        final store = ValueNotifier<LocalStore?>(previous);
        addTearDown(store.dispose);
        final container = ProviderContainer.test(
          retry: (_, _) => const Duration(minutes: 1),
          overrides: [
            sessionStoreProvider.overrideWithValue(session),
            localStoreProvider.overrideWith((ref) {
              store.addListener(ref.invalidateSelf);
              ref.onDispose(() => store.removeListener(ref.invalidateSelf));
              return store.value;
            }),
            syncStatusProvider.overrideWithValue(const SyncStatus()),
          ],
        );
        final subscription = container.listen(syncSummaryProvider, (_, _) {});
        final previousFailure = Completer<void>();
        final draftFailure = Completer<void>();
        final opsFailureSubscription = container.listen(openOpsProvider, (
          _,
          value,
        ) {
          if (value.hasError && !previousFailure.isCompleted) {
            previousFailure.complete();
          }
        });
        final draftFailureSubscription = container.listen(draftsProvider, (
          _,
          value,
        ) {
          if (value.hasError && !draftFailure.isCompleted) {
            draftFailure.complete();
          }
        });
        previous.pending.completeError(Exception('old operations read failed'));
        previous.savedDrafts.completeError(Exception('old drafts read failed'));
        await Future.wait([previousFailure.future, draftFailure.future]);
        expectState(subscription.read(), SyncSummaryState.dataUnavailable);
        opsFailureSubscription.close();
        draftFailureSubscription.close();
        if (!active) subscription.pause();
        await container.pump();

        if (!reopen) {
          await session.bind(binding(user: 'u2'), forToken: 't1');
          if (active) {
            expectState(subscription.read(), SyncSummaryState.loading);
          }
        }
        store.value = null;
        if (active) {
          expectState(subscription.read(), SyncSummaryState.storeUnavailable);
          await container.read(openOpsProvider.future);
          await container.read(draftsProvider.future);
        }
        await container.pump();

        store.value = next;
        if (!active) subscription.resume();
        expectState(subscription.read(), SyncSummaryState.loading);
        next.pending.complete([]);
        await container.read(openOpsProvider.future);
        expectState(subscription.read(), SyncSummaryState.loading);
        next.savedDrafts.complete([]);
        await container.read(draftsProvider.future);
        expectState(subscription.read(), SyncSummaryState.upToDate);
      },
    );
  }

  test('a new store failure is visible when the summary resumes', () async {
    final session = await boundSession();
    addTearDown(session.dispose);
    final previous = QueueReadStore(storeKey);
    final next = QueueReadStore(const PartitionKey(server, 'u2'));
    addTearDown(previous.changes.dispose);
    addTearDown(next.changes.dispose);
    final store = ValueNotifier<LocalStore?>(previous);
    addTearDown(store.dispose);
    final container = ProviderContainer.test(
      overrides: [
        sessionStoreProvider.overrideWithValue(session),
        localStoreProvider.overrideWith((ref) {
          store.addListener(ref.invalidateSelf);
          ref.onDispose(() => store.removeListener(ref.invalidateSelf));
          return store.value;
        }),
        syncStatusProvider.overrideWithValue(const SyncStatus()),
      ],
    );
    previous.pending.complete(blockedOps);
    previous.savedDrafts.complete([]);
    next.savedDrafts.complete([]);
    final subscription = container.listen(syncSummaryProvider, (_, _) {});
    await container.read(openOpsProvider.future);
    await container.read(draftsProvider.future);
    expectState(subscription.read(), SyncSummaryState.blocked, attention: true);

    subscription.pause();
    await session.bind(binding(user: 'u2'), forToken: 't1');
    store.value = null;
    await container.pump();
    store.value = next;
    final failedRead = expectLater(
      container.read(openOpsProvider.future),
      throwsException,
    );
    next.pending.completeError(Exception('new store read failed'));
    await failedRead;
    await container.read(draftsProvider.future);

    subscription.resume();
    expectState(subscription.read(), SyncSummaryState.dataUnavailable);
  });

  test(
    'token and binding changes update the summary with the old store open',
    () async {
      final store = await openStore(await tempDir());
      addTearDown(store.close);
      final session = ObservedSession(binding());
      addTearDown(session.dispose);
      final container = ProviderContainer.test(
        overrides: [
          sessionStoreProvider.overrideWithValue(session),
          localStoreProvider.overrideWithValue(store),
          syncStatusProvider.overrideWithValue(const SyncStatus()),
          openOpsProvider.overrideWith((_) async => blockedOps),
          draftsProvider.overrideWith((_) async => []),
        ],
      );
      final subscription = container.listen(syncSummaryProvider, (_, _) {});
      await container.read(openOpsProvider.future);
      await container.read(draftsProvider.future);
      expectState(
        subscription.read(),
        SyncSummaryState.blocked,
        attention: true,
      );

      await session.bind(binding(user: 'u2'), forToken: 't1');
      expectState(subscription.read(), SyncSummaryState.loading);
      await session.bind(binding(), forToken: 't1');
      expectState(
        subscription.read(),
        SyncSummaryState.blocked,
        attention: true,
      );
      await session.setToken(null);
      expect(subscription.read(), isNull);

      subscription.close();
      await container.pump();
      expect(session.listening, isFalse);
    },
  );

  test(
    'only completed idle reads with no changes or drafts report success',
    () {
      expectState(summary(account: binding()), SyncSummaryState.upToDate);
      expectState(
        summary(account: binding(), status: null),
        SyncSummaryState.loading,
      );
      expectState(
        summary(account: binding(), status: const SyncStatus(running: true)),
        SyncSummaryState.running,
      );
      expectState(
        summary(account: binding(), drafts: const AsyncLoading()),
        SyncSummaryState.loading,
      );
    },
  );

  test('a pause or a draft prevents success with no pending changes', () {
    final draft = Draft(
      id: 'draft',
      kind: DraftKind.rolls,
      json: const {},
      updatedAt: DateTime.utc(2026),
    );
    expectState(
      summary(account: binding(), drafts: AsyncData([draft])),
      SyncSummaryState.draftsOnly,
    );
    for (final (pause, state) in [
      (SyncPause.offline, SyncSummaryState.offline),
      (SyncPause.signedOut, SyncSummaryState.sessionExpired),
    ]) {
      for (final nextRetry in [null, DateTime.utc(2026)]) {
        for (final drafts in [
          emptyDrafts,
          AsyncData([draft]),
        ]) {
          expectState(
            summary(
              account: binding(),
              status: SyncStatus(pause: pause, nextRetry: nextRetry),
              drafts: drafts,
            ),
            state,
          );
        }
      }
    }
  });
}
