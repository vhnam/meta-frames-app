import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:meta_frames/data/local/local_store.dart';
import 'package:meta_frames/data/local/read_cache.dart';
import 'package:meta_frames/data/sync/pending_op.dart';
import 'package:meta_frames/domain/models/models.dart';
import 'package:meta_frames/providers.dart';
import 'package:meta_frames/ui/rolls/widgets/frame_notes.dart';

import '../../testing/fakes.dart';
import '../../testing/local.dart';

/// A frame whose saved notes come back when the test says, or never.
class _Rolls extends FakeRollRepository {
  _Rolls() : super(const []);
  Completer<Frame> read = Completer();

  @override
  Future<Frame> frame(String rollId, int n) => read.future;
}

Frame _frame(String notes) => Frame.fromJson({
  'id': 'f',
  'number': 7,
  'notes': notes,
  'scans': <Object>[],
});

Future<_Rolls> _pump(WidgetTester tester, {LocalStore? store}) async {
  final rolls = _Rolls();
  final router = GoRouter(
    routes: [
      GoRoute(
        path: '/',
        builder: (_, _) => const Scaffold(),
        routes: [
          GoRoute(
            path: 'frame',
            builder: (_, _) => const FrameScreen(rollId: 'r1', number: 7),
          ),
        ],
      ),
    ],
  );
  addTearDown(router.dispose);
  await tester.pumpWidget(
    ProviderScope(
      // A failed read stays failed until the user retries.
      retry: (_, _) => null,
      overrides: [
        rollRepositoryProvider.overrideWithValue(rolls),
        localStoreProvider.overrideWithValue(store),
      ],
      child: MaterialApp.router(routerConfig: router),
    ),
  );
  router.push('/frame');
  await tester.pump();
  return rolls;
}

Future<void> _tapSave(WidgetTester tester) async {
  await tester.tap(find.text('Save'));
  await tester.pump();
}

void main() {
  testWidgets('Save waits while the saved notes load', (tester) async {
    final rolls = await _pump(tester);
    await tester.enterText(find.byType(TextField), 'typed early');
    await _tapSave(tester);
    expect(rolls.calls, isEmpty);
  });

  testWidgets(
    'a failed read is not an empty note: without a partition, Save waits',
    (tester) async {
      final rolls = await _pump(tester);
      rolls.read.completeError(OfflineNoSnapshot());
      await tester.pump();
      await tester.enterText(find.byType(TextField), 'over an unread note');
      await _tapSave(tester);
      expect(rolls.calls, isEmpty, reason: 'nothing overwrites unread notes');
    },
  );

  testWidgets('saved notes arriving after typing never overwrite the typing', (
    tester,
  ) async {
    final rolls = await _pump(tester);
    await tester.enterText(find.byType(TextField), 'mine');
    rolls.read.complete(_frame('theirs'));
    await tester.pumpAndSettle();
    expect(
      tester.widget<TextField>(find.byType(TextField)).controller!.text,
      'mine',
    );
    await _tapSave(tester);
    await tester.pumpAndSettle();
    // Saved over the notes it now knows, so a newer change still conflicts.
    expect(rolls.calls, ['frameNotes:r1:7']);
    expect(rolls.bases, ['theirs']);
    expect(rolls.frameNotes[('r1', 7)], 'mine');
  });

  testWidgets('with a partition, an edit over unread notes is kept as based '
      'on unknown text', (tester) async {
    final dir = (await tester.runAsync(tempDir))!;
    final store = (await tester.runAsync(() => openStore(dir)))!;
    addTearDown(() => tester.runAsync(store.close));
    final rolls = await _pump(tester, store: store);
    rolls.read.completeError(OfflineNoSnapshot());
    await tester.pump();
    await tester.enterText(find.byType(TextField), 'written offline');
    await tester.runAsync(() async {
      await tester.tap(find.text('Save'));
      await Future<void>.delayed(const Duration(milliseconds: 100));
    });
    await tester.pump();

    final op = (await tester.runAsync(store.openOps))!.single;
    expect(op.kind, OpKind.frameNotes);
    expect(op.text, 'written offline');
    expect(op.base, isNull, reason: 'never assumed empty');
    expect(rolls.calls, isEmpty, reason: 'nothing was sent blindly');
  });
}
