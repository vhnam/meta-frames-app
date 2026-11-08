import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../data/sync/pending_op.dart';
import '../../core/theme.dart';
import '../../core/widgets/common.dart';
import '../view_models/sync_actions.dart';

/// A short label for a change's state, for badges.
String opStateLabel(PendingOp op) => switch (op.state) {
  OpState.pending => 'Waiting to sync',
  OpState.sending => 'Sending',
  OpState.unknown => 'Checking with server',
  OpState.conflict => 'Conflict',
  OpState.failed => 'Not accepted',
  OpState.done => 'Synced',
};

/// What a change does, in a few words.
String opTitle(PendingOp op) => switch (op.kind) {
  OpKind.frameNotes => 'Frame #${op.frame} notes',
  OpKind.rollNotes => 'Roll notes',
  OpKind.load => 'Load into ${op.payload['cameraName'] ?? 'camera'}',
  OpKind.finish => 'Finish roll on ${op.payload['date']}',
};

String _conflictReason(PendingOp op) => switch (op.lastError) {
  predecessorDiscarded =>
    'The change this one followed was discarded, so it was not sent.',
  'frame_notes_conflict' ||
  'roll_notes_conflict' => 'The notes were changed elsewhere.',
  'camera_loaded' => 'The camera already holds another roll on the server.',
  'roll_not_in_stock' ||
  'roll_loaded_elsewhere' => 'The roll is no longer in stock on the server.',
  'roll_loaded_differently' =>
    'The roll was loaded with other details on the server.',
  'roll_not_in_camera' ||
  'roll_finished_elsewhere' => 'The roll is no longer in this camera.',
  'not_found' => 'The roll is gone from the server.',
  final e? => 'The server refused it ($e).',
  null => 'The server holds something else.',
};

/// A small stamp for a card: pending, conflict or not accepted.
class OpBadge extends StatelessWidget {
  const OpBadge(this.op, {super.key});
  final PendingOp op;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return StampBadge(
      opStateLabel(op),
      color: op.needsAttention ? cs.error : cs.onSurfaceVariant,
    );
  }
}

/// A change waiting for the server, with the choices it needs. A conflict
/// shows both sides: nothing is dropped or sent until the user picks.
class OpStatusCard extends ConsumerWidget {
  const OpStatusCard({super.key, required this.op});
  final PendingOp op;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cs = Theme.of(context).colorScheme;
    final actions = ref.read(syncActionsProvider);
    final attention = op.needsAttention;
    final muted = TextStyle(fontSize: 13, color: cs.onSurfaceVariant);
    final mine = op.kind.isNotes ? op.text : null;

    Widget side(String label, String? value) => Padding(
      padding: const EdgeInsets.only(top: 6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: muted),
          SelectableText(
            value == null || value.trim().isEmpty ? '(empty)' : value,
            style: const TextStyle(fontSize: 14),
          ),
        ],
      ),
    );

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: attention ? cs.errorContainer : cs.surfaceContainerHigh,
        borderRadius: kCorners,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                attention ? Icons.error_outline : Icons.cloud_upload_outlined,
                size: 18,
                color: attention ? cs.onErrorContainer : cs.onSurfaceVariant,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  '${opTitle(op)} · ${opStateLabel(op)}',
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
              ),
            ],
          ),
          if (op.state == OpState.conflict) ...[
            const SizedBox(height: 4),
            Text(_conflictReason(op), style: muted),
            if (op.kind.isNotes) ...[
              if (op.lastError != predecessorDiscarded)
                side('Server', op.serverValue),
              side('This phone', mine),
            ] else if (op.serverValue != null)
              side('Server', op.serverValue),
          ],
          if (op.state == OpState.failed) ...[
            const SizedBox(height: 4),
            Text(op.lastError ?? 'The server refused it.', style: muted),
            if (mine != null) side('This phone', mine),
          ],
          if (attention)
            Wrap(
              spacing: 8,
              children: [
                TextButton(
                  onPressed: () => actions.useServer(op),
                  child: Text(
                    op.state == OpState.failed ? 'Discard' : 'Use server',
                  ),
                ),
                if (op.state == OpState.conflict && op.kind.isNotes)
                  TextButton(
                    onPressed: () => actions.keepMine(op),
                    child: const Text('Keep mine'),
                  ),
                if (op.state == OpState.conflict && !op.kind.isNotes)
                  TextButton(
                    onPressed: () => actions.retry(op),
                    child: const Text('Try again'),
                  ),
                if (mine != null && mine.isNotEmpty)
                  TextButton(
                    onPressed: () async {
                      await Clipboard.setData(ClipboardData(text: mine));
                      if (context.mounted) toast(context, 'Copied');
                    },
                    child: const Text('Copy mine'),
                  ),
              ],
            ),
        ],
      ),
    );
  }
}
