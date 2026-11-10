import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../domain/models/models.dart';
import '../../../providers.dart';
import '../../core/widgets/cards.dart';
import '../../core/widgets/common.dart';
import '../../sync/view_models/sync_actions.dart';
import '../../sync/widgets/op_status.dart';
import 'finish_roll.dart';
import 'frame_notes.dart';
import '../../../routing/routes.dart';

import 'package:go_router/go_router.dart';

/// M-24 roll details; hosts the status-dependent actions (M-19..M-21, M-27, M-31).
class RollDetailScreen extends ConsumerWidget {
  const RollDetailScreen({super.key, required this.rollId});
  final String rollId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final v = ref.watch(rollDetailProvider(rollId));
    final cs = Theme.of(context).colorScheme;
    return Scaffold(
      backgroundColor: cs.surfaceContainerLow,
      appBar: AppBar(
        backgroundColor: cs.surface,
        scrolledUnderElevation: 0,
        shape: Border(
          bottom: BorderSide(color: cs.outlineVariant, width: 0.65),
        ),
        title: Text(
          v.value?.roll.stockLabel ?? 'Roll',
          style: const TextStyle(fontSize: 19, fontWeight: FontWeight.w600),
        ),
        actions: [
          if (v.value != null) ...[
            Padding(
              padding: const EdgeInsets.only(right: 4),
              child: TextButton(
                // The edit replaces the whole roll: it waits until this
                // phone's changes to the roll are on the server, so it never
                // starts from a state the server does not have.
                onPressed: () => ref.read(rollOpsProvider(rollId)).isEmpty
                    ? context.push(Routes.rollEdit(v.value!.roll.id))
                    : toast(
                        context,
                        'This roll has changes waiting to sync. Edit it once they are on the server.',
                      ),
                child: const Text(
                  'Edit',
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
                ),
              ),
            ),
          ],
        ],
      ),
      body: AsyncBody(
        value: v,
        onRefresh: () async => ref.refresh(rollDetailProvider(rollId).future),
        builder: (d) => _Body(detail: d),
      ),
    );
  }
}

class _Body extends ConsumerWidget {
  const _Body({required this.detail});
  final RollDetail detail;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final r = detail.roll;
    final cam = r.cameraId == null
        ? null
        : ref.watch(cameraProvider(r.cameraId!)).value;
    final jobs = [...detail.processing]
      ..sort((a, b) => a.sentAt.compareTo(b.sentAt));
    final cs = Theme.of(context).colorScheme;
    const pad = EdgeInsets.all(16);
    final canManageLenses =
        r.status == RollStatus.inCamera && cam != null && !cam.hasFixedLens;
    final actions = [
      if (r.status == RollStatus.inStock)
        FilledButton.icon(
          style: FilledButton.styleFrom(padding: pad),
          icon: const Icon(Icons.photo_camera_outlined),
          label: const Text('Load into camera'),
          onPressed: () => context.push(Routes.rollLoad(r.id)),
        ),
      if (r.status == RollStatus.inCamera)
        FilledButton.icon(
          style: FilledButton.styleFrom(padding: pad),
          icon: const Icon(Icons.check),
          label: const Text('Finish roll'),
          onPressed: () => finishRoll(context, ref, r.id, cameraId: r.cameraId),
        ),
      if (r.status == RollStatus.doneShooting && detail.processing.isEmpty)
        FilledButton.icon(
          style: FilledButton.styleFrom(padding: pad),
          icon: const Icon(Icons.local_shipping_outlined),
          label: const Text('Send to lab'),
          onPressed: () => context.push(Routes.rollSend(r.id)),
        ),
      // Once processed, scanning again is the only action left.
      if (detail.processing.isNotEmpty &&
          sendableTypes(r.status, detail.processing.length).isNotEmpty)
        FilledButton.icon(
          style: FilledButton.styleFrom(padding: pad),
          icon: const Icon(Icons.replay),
          label: const Text('Re-scan'),
          onPressed: () => context.push(Routes.rollSend(r.id, resend: true)),
        ),
    ];
    final notes = r.description?.trim() ?? '';
    final ops = ref.watch(rollOpsProvider(r.id));

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        WarningBanner(detail.warnings),
        for (final op in ops) ...[
          OpStatusCard(op: op),
          const SizedBox(height: 8),
        ],
        const DetailLabel('ROLL', top: 0),
        CardList(
          children: [
            _StockRow(detail: detail),
            if (r.negativesAtLab) const DetailInfoRow('Negatives', 'At lab'),
            DetailInfoRow('Format', '${r.format}'),
            DetailInfoRow('Exposures', '${r.exposures}'),
            DetailInfoRow('Price', fmtVnd(r.price)),
            DetailInfoRow('Expiry', r.expiry?.toString()),
            DetailInfoRow(
              'Shot ISO',
              r.shotIso?.toString() ?? 'Box (${detail.stock.boxIso})',
            ),
            DetailInfoRow('Started', fmtDate(r.startedAt)),
            DetailInfoRow('Finished', fmtDate(r.finishedAt)),
          ],
        ),
        DetailLabel(
          'NOTES',
          trailing: TextButton(
            style: TextButton.styleFrom(
              minimumSize: const Size(0, 32),
              padding: const EdgeInsets.symmetric(horizontal: 8),
            ),
            onPressed: () => context.push(Routes.rollNotes(r.id)),
            child: Text(
              notes.isEmpty ? 'Add notes' : 'Edit',
              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
            ),
          ),
        ),
        Text(
          notes.isEmpty ? 'Subject, location, conditions, incidents.' : notes,
          style: TextStyle(
            fontSize: 14,
            color: notes.isEmpty ? cs.onSurfaceVariant : cs.onSurface,
          ),
        ),
        if (r.cameraId != null ||
            detail.lenses.isNotEmpty ||
            canManageLenses) ...[
          const DetailLabel('GEAR'),
          CardList(
            children: [
              if (r.cameraId != null)
                CardTile(
                  compact: true,
                  leading: Icon(
                    Icons.photo_camera_outlined,
                    size: 20,
                    color: cs.onSurfaceVariant,
                  ),
                  title: r.cameraName ?? 'Camera',
                  subtitle: 'Camera',
                  trailing: Icon(
                    Icons.chevron_right,
                    size: 20,
                    color: cs.onSurfaceVariant,
                  ),
                  onTap: () => context.push(Routes.camera(r.cameraId!)),
                ),
              for (final l in detail.lenses)
                CardTile(
                  compact: true,
                  leading: Icon(
                    Icons.adjust,
                    size: 20,
                    color: cs.onSurfaceVariant,
                  ),
                  title: l.name,
                  subtitle: 'Lens',
                ),
            ],
          ),
          if (canManageLenses) ...[
            const SizedBox(height: 8),
            DashedButton(
              label: 'Manage lenses',
              onTap: () => context.push(Routes.rollLenses(r.id)),
            ),
          ],
        ],
        const DetailLabel('COST'),
        CardList(
          children: [
            DetailInfoRow('Film', fmtVnd(detail.totals.rollPrice)),
            DetailInfoRow('Processing', fmtVnd(detail.totals.processingPrice)),
            DetailInfoRow(
              'Total',
              '${fmtVnd(detail.totals.total)}${detail.totals.incomplete ? ' (incomplete)' : ''}',
              bold: true,
            ),
          ],
        ),
        const DetailLabel('PROCESSING HISTORY'),
        if (jobs.isEmpty)
          Text(
            'Not sent yet',
            style: TextStyle(fontSize: 13, color: cs.onSurfaceVariant),
          )
        else
          CardList(
            children: [
              for (final j in jobs)
                CardTile(
                  compact: true,
                  title: '${j.where} · ${j.type.label}',
                  subtitle: [
                    j.process.wire,
                    'sent ${fmtDate(j.sentAt)}',
                    if (j.scansReceivedAt != null)
                      'scans ${fmtDate(j.scansReceivedAt)}',
                    if (j.negativesReturnedAt != null)
                      'negatives ${fmtDate(j.negativesReturnedAt)}',
                    if (j.scanners.isNotEmpty)
                      j.scanners.map((s) => s.label).join('+'),
                    if (j.price != null) fmtVnd(j.price),
                    if (j.notes != null) j.notes!,
                  ].join(' · '),
                  badge: j.isOpen
                      ? StampBadge('Open', color: cs.onPrimaryContainer)
                      : null,
                  onTap: () => context.push(Routes.processing(j.id)),
                ),
            ],
          ),
        DetailLabel(
          'FRAMES',
          trailing: TextButton(
            style: TextButton.styleFrom(
              minimumSize: const Size(0, 32),
              padding: const EdgeInsets.symmetric(horizontal: 8),
            ),
            onPressed: () => noteFrame(context, r.id),
            child: const Text(
              'Add notes',
              style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
            ),
          ),
        ),
        if (detail.frames.isEmpty)
          Text(
            'No frames yet. Add notes, or import scans in the dashboard.',
            style: TextStyle(fontSize: 13, color: cs.onSurfaceVariant),
          )
        else
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final f in detail.frames)
                ActionChip(
                  label: Text(
                    '#${f.number}${f.scans.isEmpty ? '' : ' · ${f.scans.length}'}',
                  ),
                  avatar: f.notes == null
                      ? null
                      : const Icon(Icons.notes, size: 14),
                  onPressed: () => context.push(Routes.frame(r.id, f.number)),
                ),
            ],
          ),
        if (actions.isNotEmpty) ...[
          const SizedBox(height: 20),
          for (final a in actions) SizedBox(width: double.infinity, child: a),
        ],
        const SizedBox(height: 16),
      ],
    );
  }
}

/// The roll's stock and status. The status sits under the names, so a long name
/// has the card's full width.
class _StockRow extends StatelessWidget {
  const _StockRow({required this.detail});
  final RollDetail detail;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final stock = detail.stock;
    final base = detail.baseStock;
    return InkWell(
      onTap: () => context.push(Routes.stock(stock.id)),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Row(
          spacing: 12,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    stock.label,
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: cs.onSurface,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    base == null
                        ? 'ISO ${stock.boxIso} · ${stock.process.wire}'
                        : 'Base: ${base.label}',
                    style: TextStyle(fontSize: 13, color: cs.onSurfaceVariant),
                  ),
                  const SizedBox(height: 10),
                  StatusChip(detail.roll.status),
                ],
              ),
            ),
            Icon(Icons.chevron_right, size: 20, color: cs.onSurfaceVariant),
          ],
        ),
      ),
    );
  }
}
