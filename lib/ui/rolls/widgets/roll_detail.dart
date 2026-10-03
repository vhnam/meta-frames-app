import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../domain/models/models.dart';
import '../../../providers.dart';
import '../../core/widgets/cards.dart';
import '../../core/widgets/common.dart';
import '../view_models/roll_actions.dart';
import 'finish_roll.dart';
import '../../../routing/routes.dart';

import 'package:go_router/go_router.dart';

import '../../../routing/navigation.dart';

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
                onPressed: () =>
                    context.push(Routes.rollEdit(v.value!.roll.id)),
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
          onPressed: () => finishRoll(context, ref, r.id),
        ),
      if (r.status == RollStatus.doneShooting)
        FilledButton.icon(
          style: FilledButton.styleFrom(padding: pad),
          icon: const Icon(Icons.local_shipping_outlined),
          label: const Text('Send to lab'),
          onPressed: () => context.push(Routes.rollSend(r.id)),
        ),
      if (r.status == RollStatus.developed || r.status == RollStatus.scanned)
        FilledButton.icon(
          style: FilledButton.styleFrom(padding: pad),
          icon: const Icon(Icons.replay),
          label: const Text('Send again'),
          onPressed: () => context.push(Routes.rollSend(r.id, resend: true)),
        ),
    ];
    final notes = r.description?.trim() ?? '';

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        WarningBanner(detail.warnings),
        const DetailLabel('ROLL', top: 0),
        CardList(
          children: [
            CardTile(
              title: detail.stock.label,
              subtitle: detail.baseStock == null
                  ? 'ISO ${detail.stock.boxIso} · ${detail.stock.process.wire}'
                  : 'Base: ${detail.baseStock!.label}',
              badge: StatusChip(r.status),
              trailing: Icon(
                Icons.chevron_right,
                size: 20,
                color: cs.onSurfaceVariant,
              ),
              onTap: () => context.push(Routes.stock(detail.stock.id)),
            ),
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
            if (notes.isNotEmpty) DetailInfoRow('Notes', notes),
          ],
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
            onPressed: () => _openFrame(context),
            child: const Text(
              'Add notes',
              style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
            ),
          ),
        ),
        if (detail.frames.isEmpty)
          Text(
            'No frames yet. Import scans or add notes.',
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
        if (r.status == RollStatus.inStock) ...[
          const SizedBox(height: 12),
          CardList(
            children: [
              DetailActionRow(
                label: 'Delete roll',
                color: cs.error,
                onTap: () => _delete(context, ref),
              ),
            ],
          ),
        ],
        const SizedBox(height: 16),
      ],
    );
  }

  Future<void> _delete(BuildContext context, WidgetRef ref) async {
    if (!await confirm(
      context,
      'Delete roll?',
      'This roll is still in stock and will be removed.',
      ok: 'Delete',
    )) {
      return;
    }
    if (!context.mounted) return;
    final ok = await guard(
      context,
      () => ref.read(rollActionsProvider).delete(detail.roll.id),
    );
    if (ok && context.mounted) context.closeScreen();
  }

  Future<void> _openFrame(BuildContext context) async {
    final c = TextEditingController();
    final n = await showDialog<int>(
      context: context,
      builder: (d) => AlertDialog(
        title: const Text('Frame number'),
        content: TextField(
          controller: c,
          keyboardType: TextInputType.number,
          autofocus: true,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(d),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(d, int.tryParse(c.text)),
            child: const Text('Open'),
          ),
        ],
      ),
    );
    if (n != null && context.mounted) {
      context.push(Routes.frame(detail.roll.id, n));
    }
  }
}
