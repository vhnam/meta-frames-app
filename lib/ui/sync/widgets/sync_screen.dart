import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../data/local/local_store.dart';
import '../../../data/sync/pending_op.dart';
import '../../../data/sync/sync_engine.dart';
import '../../../providers.dart';
import '../../../routing/routes.dart';
import '../../core/widgets/cards.dart';
import '../../core/widgets/common.dart';
import '../../labs/widgets/lab_dialog.dart';
import '../view_models/drafts.dart';
import '../view_models/sync_actions.dart';
import 'op_status.dart';

/// Sync status: what this phone holds that the server does not have yet, for
/// the signed-in account (with its contents) and for other accounts or
/// servers (counts only: their notes are never shown under this account).
class SyncScreen extends ConsumerWidget {
  const SyncScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final store = ref.watch(localStoreProvider);
    final status = ref.watch(syncStatusProvider);
    final ops = ref.watch(openOpsProvider).value ?? const <PendingOp>[];
    final drafts = ref.watch(draftsProvider).value ?? const <Draft>[];
    final binding = ref.watch(sessionStoreProvider).binding;
    final others = [
      for (final p in ref.watch(partitionsProvider).value ?? const [])
        if (p.key != store?.key && p.hasUnsynced) p,
    ];
    final cs = Theme.of(context).colorScheme;
    final muted = TextStyle(fontSize: 13, color: cs.onSurfaceVariant);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Sync status'),
        actions: [
          if (store != null)
            TextButton(
              onPressed: () => ref.read(syncActionsProvider).syncNow(),
              child: const Text('Sync now'),
            ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          if (store == null)
            Text(
              binding == null
                  ? 'Nothing is kept on this phone until the account is verified with the server.'
                  : 'Nothing is kept on this phone for this account.',
              style: muted,
            )
          else ...[
            Text(
              '${binding?.email ?? ''} · ${store.key.server}',
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 4),
            Text(syncStatusLine(status, ops.length), style: muted),
            const DetailLabel('CHANGES'),
            if (ops.isEmpty)
              Text('Everything is on the server.', style: muted)
            else
              for (final op in ops) ...[
                OpStatusCard(op: op),
                const SizedBox(height: 8),
              ],
            const DetailLabel('DRAFTS'),
            if (drafts.isEmpty)
              Text('No unsent drafts.', style: muted)
            else
              CardList(
                children: [
                  for (final d in drafts)
                    CardTile(
                      compact: true,
                      title: d.label,
                      subtitle: d.error ?? 'Not sent. Tap to finish and send.',
                      onTap: () => resumeDraft(context, d),
                      trailing: IconButton(
                        tooltip: 'Discard draft',
                        icon: const Icon(Icons.delete_outline),
                        onPressed: () async {
                          if (await confirm(
                                context,
                                'Discard draft?',
                                '${d.label} will be removed from this phone.',
                                ok: 'Discard',
                              ) &&
                              context.mounted) {
                            await ref.read(draftActionsProvider).discard(d.id);
                          }
                        },
                      ),
                    ),
                ],
              ),
          ],
          if (others.isNotEmpty) ...[
            const DetailLabel('OTHER ACCOUNTS ON THIS PHONE'),
            Text(
              'Kept until that account signs in on that server again. Their contents are not shown here.',
              style: muted,
            ),
            const SizedBox(height: 8),
            CardList(
              children: [
                for (final p in others)
                  CardTile(
                    compact: true,
                    title: '${p.email} · ${p.key.server}',
                    subtitle: partitionCounts(p),
                    trailing: TextButton(
                      onPressed: () => discardPartition(context, ref, p),
                      child: const Text('Discard'),
                    ),
                  ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

/// "Up to date", "3 waiting · offline, retrying at 14:02", …
String syncStatusLine(SyncStatus? s, int open) {
  final waiting = open == 0 ? 'Up to date' : '$open waiting';
  if (s == null) return waiting;
  final time = s.lastSynced == null
      ? ''
      : ' · last synced ${TimeOfDay.fromDateTime(s.lastSynced!).hhmm}';
  return switch (s.pause) {
    _ when s.running => 'Syncing…',
    SyncPause.offline =>
      '$waiting · server not reachable${s.nextRetry == null ? '' : ', retrying at ${TimeOfDay.fromDateTime(s.nextRetry!).hhmm}'}',
    SyncPause.signedOut => '$waiting · sign in to sync',
    SyncPause.none => '$waiting$time',
  };
}

extension on TimeOfDay {
  String get hhmm =>
      '${hour.toString().padLeft(2, '0')}:${minute.toString().padLeft(2, '0')}';
}

String partitionCounts(PartitionSummary p) => [
  if (p.openOps > 0) '${p.openOps} unsynced change${p.openOps == 1 ? '' : 's'}',
  if (p.attentionOps > 0) '${p.attentionOps} need attention',
  if (p.drafts > 0) '${p.drafts} draft${p.drafts == 1 ? '' : 's'}',
].join(' · ');

/// Reopens a draft's form. A finished form sends it.
Future<void> resumeDraft(BuildContext context, Draft d) async {
  switch (d.kind) {
    case DraftKind.camera:
      await context.push(Routes.cameraCreate(draft: d.id));
    case DraftKind.lens:
      await context.push(Routes.lensCreate(draft: d.id));
    case DraftKind.stock:
      await context.push(Routes.stockCreate(draft: d.id));
    case DraftKind.rolls:
      await context.push(Routes.rollNew(draft: d.id));
    case DraftKind.lab:
      await editLab(context, d);
  }
}

/// Deletes another account's kept data after a typed confirmation.
Future<void> discardPartition(
  BuildContext context,
  WidgetRef ref,
  PartitionSummary p,
) async {
  if (await confirmDiscard(
        context,
        'Discard data for ${p.email}?',
        '${partitionCounts(p)} kept for ${p.email} on ${p.key.server} will be deleted from this phone. This cannot be undone.',
      ) &&
      context.mounted) {
    await ref.read(syncActionsProvider).discardPartition(p.key);
  }
}

/// A destructive confirmation: the user types DISCARD.
Future<bool> confirmDiscard(
  BuildContext context,
  String title,
  String body,
) async {
  final ok = await showDialog<bool>(
    context: context,
    builder: (_) => _TypedConfirm(title: title, body: body),
  );
  return ok ?? false;
}

class _TypedConfirm extends StatefulWidget {
  const _TypedConfirm({required this.title, required this.body});
  final String title, body;
  @override
  State<_TypedConfirm> createState() => _TypedConfirmState();
}

class _TypedConfirmState extends State<_TypedConfirm> {
  final _typed = TextEditingController();

  @override
  void dispose() {
    _typed.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: Text(widget.title),
    content: Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(widget.body),
        const SizedBox(height: 12),
        TextField(
          controller: _typed,
          decoration: const InputDecoration(labelText: 'Type DISCARD'),
        ),
      ],
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context, false),
        child: const Text('Cancel'),
      ),
      ListenableBuilder(
        listenable: _typed,
        builder: (context, _) => FilledButton(
          style: FilledButton.styleFrom(
            backgroundColor: Theme.of(context).colorScheme.error,
          ),
          onPressed: _typed.text.trim() == 'DISCARD'
              ? () => Navigator.pop(context, true)
              : null,
          child: const Text('Discard'),
        ),
      ),
    ],
  );
}

/// Before signing out or changing server: if this phone holds anything the
/// server does not have for the account, asks what to do with it. Keeping is
/// the default and needs one tap; discarding needs DISCARD typed. Returns
/// null when the user cancels, otherwise whether to discard.
Future<bool?> askKeepOrDiscard(
  BuildContext context,
  WidgetRef ref, {
  required String action,
}) async {
  final kept = await ref.read(syncActionsProvider).unsynced();
  if (kept.changes == 0 && kept.drafts == 0) return false;
  if (!context.mounted) return null;
  final what = [
    if (kept.changes > 0)
      '${kept.changes} change${kept.changes == 1 ? '' : 's'} not synced',
    if (kept.drafts > 0) '${kept.drafts} draft${kept.drafts == 1 ? '' : 's'}',
  ].join(' and ');
  final choice = await showDialog<String>(
    context: context,
    builder: (c) => AlertDialog(
      title: Text('$action?'),
      content: Text(
        'This phone has $what for this account. Keep them here to sync when you sign in to this account on this server again, or discard them.',
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(c),
          child: const Text('Cancel'),
        ),
        TextButton(
          onPressed: () => Navigator.pop(c, 'discard'),
          child: const Text('Discard'),
        ),
        FilledButton(
          autofocus: true,
          onPressed: () => Navigator.pop(c, 'keep'),
          child: const Text('Keep on this phone'),
        ),
      ],
    ),
  );
  if (choice == null || !context.mounted) return null;
  if (choice == 'keep') return false;
  final sure = await confirmDiscard(
    context,
    'Discard $what?',
    'They will be deleted from this phone and never reach the server.',
  );
  return sure ? true : null;
}
