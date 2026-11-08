import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../data/local/local_store.dart';
import '../../../data/sync/pending_op.dart';
import '../../../providers.dart';

/// The user's choices on changes waiting for the server.
class SyncActions {
  SyncActions(this._ref);
  final Ref _ref;

  LocalStore? get _store => _ref.read(localStoreProvider);

  /// Sends what is waiting now, instead of at the next retry.
  Future<void> syncNow() => _ref.read(partitionControllerProvider).sync();

  /// "Use server" (or "Discard"): drops the change. Nothing that was based on
  /// it is sent; each becomes a conflict to look at again.
  Future<void> useServer(PendingOp op) async {
    await _store?.discard(op);
    refreshRoll(_ref, op.rollId);
  }

  /// "Keep mine" on a notes conflict: send the phone's text again, now based
  /// on the server's text just shown, so it applies only if that is still
  /// what the server holds. When the server's text is not known, it is read
  /// again before anything is sent.
  Future<void> keepMine(PendingOp op) async {
    assert(op.kind.isNotes);
    await _store?.markPending(op, base: op.serverValue, setBase: true);
    unawaited(syncNow());
  }

  /// "Try again" on a load or finish: the roll is read again first; the step
  /// is sent only if the roll is still where it started.
  Future<void> retry(PendingOp op) async {
    await _store?.markUnknown(op, null);
    unawaited(syncNow());
  }

  /// Every partition on this phone, without contents.
  Future<List<PartitionSummary>> partitions() =>
      _ref.read(partitionControllerProvider).partitions();

  /// Deletes everything kept for [key]: unsynced changes, drafts and saved
  /// reads. Only on the user's explicit, confirmed choice.
  Future<void> discardPartition(PartitionKey key) async {
    await _ref.read(partitionControllerProvider).discard(key);
    invalidateAllData(_ref);
  }

  /// What the open partition holds that the server does not have yet.
  Future<({int changes, int drafts})> unsynced() async {
    final store = _store;
    if (store == null) return (changes: 0, drafts: 0);
    final counts = await store.counts();
    return (changes: counts.open, drafts: (await store.drafts()).length);
  }
}

final syncActionsProvider = Provider<SyncActions>(SyncActions.new);

/// Refreshes what shows [rollId] after one of its changes reached the server
/// or was dropped.
void refreshRoll(Ref ref, String rollId) => ref
  ..invalidate(rollDetailProvider(rollId))
  ..invalidate(frameProvider)
  ..invalidate(camerasProvider)
  ..invalidate(cameraProvider)
  ..invalidate(rollsProvider)
  ..invalidate(expiryProvider)
  ..invalidate(inventoryProvider);

/// Keeps the screens in step with the sync engine: refreshes a roll's data
/// when one of its changes completes. Watched by the app.
final syncRefresherProvider = Provider<void>((ref) {
  final engine = ref.watch(partitionControllerProvider).engine;
  ref.watch(localStoreProvider);
  if (engine == null) return;
  final sub = engine.completedRolls.listen(
    (rollId) => refreshRoll(ref, rollId),
  );
  ref.onDispose(sub.cancel);
});

/// Every partition on this phone, for Sync status and the login screen.
final partitionsProvider = FutureProvider.autoDispose<List<PartitionSummary>>((
  ref,
) {
  ref.watch(localStoreProvider);
  ref.watch(openOpsProvider);
  return ref.read(syncActionsProvider).partitions();
});

/// Open changes on one roll (its load, finish and notes), oldest first.
final rollOpsProvider = Provider.autoDispose.family<List<PendingOp>, String>(
  (ref, rollId) => [
    for (final op in ref.watch(openOpsProvider).value ?? const <PendingOp>[])
      if (op.rollId == rollId) op,
  ],
);

/// The open change to one note that matters most: one needing the user if
/// any (an earlier edit in conflict holds the later ones), otherwise the
/// latest. Null when the note has no open change.
final notesOpProvider = Provider.autoDispose
    .family<PendingOp?, ({String rollId, int? frame})>((ref, t) {
      final kind = t.frame == null ? OpKind.rollNotes : OpKind.frameNotes;
      PendingOp? last;
      for (final op in ref.watch(rollOpsProvider(t.rollId))) {
        if (op.kind != kind || op.frame != t.frame) continue;
        if (op.needsAttention) return op;
        last = op;
      }
      return last;
    });
