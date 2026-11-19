import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:meta_frames/data/local/local_store.dart';
import 'package:meta_frames/data/local/partition_controller.dart';
import 'package:meta_frames/data/services/session_store.dart';
import 'package:meta_frames/data/sync/pending_op.dart';
import 'package:meta_frames/data/sync/sync_engine.dart';
import 'package:meta_frames/providers.dart';
import 'package:meta_frames/ui/sync/view_models/sync_actions.dart';
import 'package:meta_frames/ui/sync/widgets/op_status.dart';
import 'package:meta_frames/ui/sync/widgets/sync_screen.dart';

import '../../testing/local.dart';

class QueueStore implements LocalStore {
  @override
  final key = const PartitionKey(server, 'u1');

  @override
  final changes = ValueNotifier<int>(0);

  @override
  bool get isClosed => false;

  var opsRead = Completer<List<PendingOp>>();
  var draftsRead = Completer<List<Draft>>();
  int opsReads = 0;
  int draftsReads = 0;

  @override
  Future<List<PendingOp>> openOps() {
    opsReads++;
    return opsRead.future;
  }

  @override
  Future<List<Draft>> drafts([DraftKind? kind]) {
    draftsReads++;
    return draftsRead.future;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class IdleController implements PartitionController {
  int syncs = 0;

  @override
  Future<void> sync() async {
    syncs++;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

const opsEmpty = 'Everything is on the server.';
const draftsEmpty = 'No unsent drafts.';

void expectNoEmptyClaims() {
  expect(find.text(opsEmpty), findsNothing);
  expect(find.text(draftsEmpty), findsNothing);
  expect(find.textContaining('Up to date'), findsNothing);
}

Future<IdleController> showSync(WidgetTester tester, QueueStore store) async {
  final session = SessionStore('token', binding());
  final controller = IdleController();
  addTearDown(session.dispose);
  addTearDown(store.changes.dispose);
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        localStoreProvider.overrideWithValue(store),
        syncStatusProvider.overrideWithValue(const SyncStatus()),
        sessionStoreProvider.overrideWithValue(session),
        partitionControllerProvider.overrideWithValue(controller),
        partitionsProvider.overrideWith((_) async => []),
      ],
      child: const MaterialApp(home: SyncScreen()),
    ),
  );
  return controller;
}

void main() {
  testWidgets(
    'unknown and failed queues make no empty claim until Sync now rereads both',
    (tester) async {
      final store = QueueStore();
      final controller = await showSync(tester, store);
      expect(controller.syncs, 0);
      expectNoEmptyClaims();

      store.opsRead.completeError(Exception('operations unavailable'));
      store.draftsRead.completeError(Exception('drafts unavailable'));
      await tester.pumpAndSettle();
      expectNoEmptyClaims();
      expect(find.textContaining('Could not read'), findsNWidgets(2));

      store.opsRead = Completer<List<PendingOp>>();
      store.draftsRead = Completer<List<Draft>>();
      await tester.tap(find.text('Sync now'));
      await tester.pumpAndSettle();
      expect(controller.syncs, 1);
      expect(store.opsReads, 2);
      expect(store.draftsReads, 2);
      expect(store.changes.value, 0);
      expectNoEmptyClaims();

      store.opsRead.complete([]);
      store.draftsRead.complete([]);
      await tester.pumpAndSettle();
      expect(find.text(opsEmpty), findsOneWidget);
      expect(find.text(draftsEmpty), findsOneWidget);
      expect(find.textContaining('Could not read'), findsNothing);
    },
  );

  testWidgets(
    'a retry after failed reads cannot reuse an earlier empty result',
    (tester) async {
      final store = QueueStore();
      await showSync(tester, store);
      store.opsRead.complete([]);
      store.draftsRead.complete([]);
      await tester.pumpAndSettle();

      store.opsRead = Completer<List<PendingOp>>();
      store.draftsRead = Completer<List<Draft>>();
      store.changes.value++;
      await tester.pumpAndSettle();
      store.opsRead.completeError(Exception('operations unavailable'));
      store.draftsRead.completeError(Exception('drafts unavailable'));
      await tester.pumpAndSettle();
      expectNoEmptyClaims();

      store.opsRead = Completer<List<PendingOp>>();
      store.draftsRead = Completer<List<Draft>>();
      await tester.tap(find.text('Sync now'));
      await tester.pumpAndSettle();
      expect(store.opsReads, 3);
      expect(store.draftsReads, 3);
      expectNoEmptyClaims();
    },
  );
  testWidgets(
    'queue content stays through a healthy refresh and hides after failure',
    (tester) async {
      final store = QueueStore();
      await showSync(tester, store);
      final stamp = DateTime.utc(2026);
      final operation = PendingOp(
        seq: 1,
        opId: 'pending',
        kind: OpKind.rollNotes,
        rollId: 'roll',
        payload: const {},
        state: OpState.pending,
        createdAt: stamp,
        updatedAt: stamp,
      );
      final draft = Draft(
        id: 'draft',
        kind: DraftKind.rolls,
        json: const {},
        updatedAt: stamp,
      );
      final changeCard = find.byType(OpStatusCard);
      final draftAction = find.byTooltip('Discard draft');
      store.opsRead.complete([operation]);
      store.draftsRead.complete([draft]);
      await tester.pumpAndSettle();
      expect(changeCard, findsOneWidget);
      expect(draftAction, findsOneWidget);

      store.opsRead = Completer<List<PendingOp>>();
      store.draftsRead = Completer<List<Draft>>();
      await tester.tap(find.text('Sync now'));
      await tester.pumpAndSettle();
      expect(store.opsReads, 2);
      expect(store.draftsReads, 2);
      expect(changeCard, findsOneWidget);
      expect(draftAction, findsOneWidget);

      store.opsRead.completeError(Exception('operations unavailable'));
      store.draftsRead.completeError(Exception('drafts unavailable'));
      await tester.pumpAndSettle();
      expect(changeCard, findsNothing);
      expect(draftAction, findsNothing);

      store.opsRead = Completer<List<PendingOp>>();
      store.draftsRead = Completer<List<Draft>>();
      await tester.tap(find.text('Sync now'));
      await tester.pumpAndSettle();
      expect(store.opsReads, 3);
      expect(store.draftsReads, 3);
      expect(changeCard, findsNothing);
      expect(draftAction, findsNothing);

      store.opsRead.complete([operation]);
      store.draftsRead.complete([draft]);
      await tester.pumpAndSettle();
      expect(changeCard, findsOneWidget);
      expect(draftAction, findsOneWidget);
    },
  );

  testWidgets('Up to date requires both queue reads to succeed and be empty', (
    tester,
  ) async {
    final store = QueueStore();
    await showSync(tester, store);
    final upToDate = find.textContaining('Up to date');
    store.opsRead.complete([]);
    await tester.pumpAndSettle();
    expect(upToDate, findsNothing);

    store.draftsRead.completeError(Exception('drafts unavailable'));
    await tester.pumpAndSettle();
    expect(upToDate, findsNothing);

    store.draftsRead = Completer<List<Draft>>()
      ..complete([
        Draft(
          id: 'draft',
          kind: DraftKind.rolls,
          json: const {},
          updatedAt: DateTime.utc(2026),
        ),
      ]);
    store.changes.value++;
    await tester.pumpAndSettle();
    expect(upToDate, findsNothing);

    store.draftsRead = Completer<List<Draft>>()..complete([]);
    store.changes.value++;
    await tester.pumpAndSettle();
    expect(upToDate, findsOneWidget);
  });
}
