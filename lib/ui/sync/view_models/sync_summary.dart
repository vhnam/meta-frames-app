import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../data/local/local_store.dart';
import '../../../data/services/session_store.dart';
import '../../../data/sync/pending_op.dart';
import '../../../data/sync/sync_engine.dart';
import '../../../providers.dart';
import '../widgets/sync_screen.dart';

enum SyncSummaryState {
  loading,
  storeUnavailable,
  dataUnavailable,
  running,
  offline,
  sessionExpired,
  blocked,
  waiting,
  draftsOnly,
  upToDate,
}

/// The short sync status of the active partition. Holds no change or draft
/// content.
class SyncSummary {
  const SyncSummary(this.state, this.line);
  final SyncSummaryState state;
  final String line;

  bool get attention => state == SyncSummaryState.blocked;
}

/// The summary for the current session, or null without a token. Counts and
/// attention come only from finished reads of the store that matches the
/// session: an earlier account's store can stay open, with its lists loaded,
/// until the partition controller closes it.
SyncSummary? summarizeSync({
  required bool signedIn,
  required PartitionKey? storeKey,
  required SessionBinding? binding,
  required SyncStatus? status,
  required AsyncValue<List<PendingOp>> ops,
  required AsyncValue<List<Draft>> drafts,
}) {
  const loading = SyncSummary(
    SyncSummaryState.loading,
    'Checking sync status…',
  );
  const unavailable = SyncSummary(
    SyncSummaryState.dataUnavailable,
    'Sync status unavailable',
  );
  if (!signedIn) return null;
  if (storeKey == null) {
    return const SyncSummary(
      SyncSummaryState.storeUnavailable,
      'Local storage unavailable',
    );
  }
  if (binding == null ||
      storeKey != PartitionKey(binding.server, binding.userId)) {
    return loading;
  }
  if (ops.isLoading || drafts.isLoading) return loading;
  if (ops.hasError || drafts.hasError) return unavailable;
  final openOps = ops.value;
  final kept = drafts.value;
  if (status == null || openOps == null || kept == null) return loading;

  final open = openOps.length;
  final state = switch (status) {
    _ when openOps.any((op) => op.needsAttention) => SyncSummaryState.blocked,
    SyncStatus(running: true) => SyncSummaryState.running,
    SyncStatus(pause: SyncPause.offline) => SyncSummaryState.offline,
    SyncStatus(pause: SyncPause.signedOut) => SyncSummaryState.sessionExpired,
    _ when open > 0 => SyncSummaryState.waiting,
    _ when kept.isNotEmpty => SyncSummaryState.draftsOnly,
    _ => SyncSummaryState.upToDate,
  };
  final paused =
      state == SyncSummaryState.offline ||
      state == SyncSummaryState.sessionExpired;
  return SyncSummary(
    state,
    [
      if (state == SyncSummaryState.blocked)
        '$open waiting · needs attention'
      else if (paused && open == 0)
        _pauseDetail(status)
      else if (state != SyncSummaryState.draftsOnly)
        syncStatusLine(status, open),
      if (kept.isNotEmpty) '${kept.length} draft${kept.length == 1 ? '' : 's'}',
    ].join(' · '),
  );
}

/// The pause wording of [syncStatusLine] without its leading "Up to date",
/// which is not true during a pause.
String _pauseDetail(SyncStatus status) {
  final detail = syncStatusLine(status, 0).split(' · ').skip(1).join(' · ');
  return '${detail[0].toUpperCase()}${detail.substring(1)}';
}

/// Only reads: watching the summary never starts a sync.
final syncSummaryProvider = Provider.autoDispose<SyncSummary?>((ref) {
  final session = ref.watch(sessionStoreProvider);
  void changed() => ref.invalidateSelf();
  session.addListener(changed);
  ref.onDispose(() => session.removeListener(changed));
  return summarizeSync(
    signedIn: session.signedIn,
    storeKey: ref.watch(localStoreProvider)?.key,
    binding: session.binding,
    status: ref.watch(syncStatusProvider),
    ops: ref.watch(openOpsProvider),
    drafts: ref.watch(draftsProvider),
  );
});
