import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../domain/models/models.dart';
import '../../../providers.dart';
import '../../core/widgets/common.dart';
import '../../film/widgets/stock_detail.dart';
import '../../gear/widgets/camera_detail.dart';
import '../../labs/widgets/processing_detail.dart';
import '../../labs/widgets/send_roll.dart';
import '../../scans/widgets/frame_screen.dart';
import 'finish_roll.dart';
import 'load_roll.dart';
import 'roll_form.dart';
import 'roll_lenses.dart';

/// M-24 roll details; hosts the status-dependent actions (M-19..M-21, M-27, M-31).
class RollDetailScreen extends ConsumerWidget {
  const RollDetailScreen({super.key, required this.rollId});
  final String rollId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final v = ref.watch(rollDetailProvider(rollId));
    return Scaffold(
      appBar: AppBar(
        title: Text(v.value?.roll.stockLabel ?? 'Roll'),
        actions: [
          if (v.value != null) ...[
            IconButton(
              icon: const Icon(Icons.edit_outlined),
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => RollFormScreen(detail: v.value!),
                ),
              ),
            ),
            if (v.value!.roll.status == RollStatus.inStock)
              IconButton(
                icon: const Icon(Icons.delete_outline),
                onPressed: () async {
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
                    () => ref.read(rollRepositoryProvider).delete(rollId),
                  );
                  if (ok && context.mounted) {
                    refreshAll(ref);
                    Navigator.pop(context);
                  }
                },
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
    return ListView(
      children: [
        WarningBanner(detail.warnings),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
          child: Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              if (r.status == RollStatus.inStock)
                FilledButton.icon(
                  icon: const Icon(Icons.photo_camera_outlined),
                  label: const Text('Load into camera'),
                  onPressed: () => Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => LoadRollScreen(roll: r)),
                  ),
                ),
              if (r.status == RollStatus.inCamera) ...[
                FilledButton.icon(
                  icon: const Icon(Icons.check),
                  label: const Text('Finish roll'),
                  onPressed: () => finishRoll(context, ref, r.id),
                ),
                if (cam != null && !cam.hasFixedLens)
                  OutlinedButton.icon(
                    icon: const Icon(Icons.lens_outlined),
                    label: const Text('Lenses'),
                    onPressed: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => RollLensesScreen(
                          rollId: r.id,
                          cameraId: cam.id,
                          current: detail.lenses,
                        ),
                      ),
                    ),
                  ),
              ],
              if (r.status == RollStatus.doneShooting)
                FilledButton.icon(
                  icon: const Icon(Icons.local_shipping_outlined),
                  label: const Text('Send to lab'),
                  onPressed: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) =>
                          SendRollScreen(roll: r, stock: detail.stock),
                    ),
                  ),
                ),
              if (r.status == RollStatus.developed ||
                  r.status == RollStatus.scanned)
                FilledButton.icon(
                  icon: const Icon(Icons.replay),
                  label: const Text('Send again'),
                  onPressed: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => SendRollScreen(
                        roll: r,
                        stock: detail.stock,
                        resend: true,
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
        const SectionHeader('Roll'),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(children: [StatusChip(r.status)]),
        ),
        if (r.negativesAtLab) const InfoRow('', 'Negatives at lab'),
        ListTile(
          dense: true,
          title: Text(detail.stock.label),
          subtitle: Text(
            detail.baseStock == null
                ? 'ISO ${detail.stock.boxIso} · ${detail.stock.process.wire}'
                : 'Base: ${detail.baseStock!.label}',
          ),
          trailing: const Icon(Icons.chevron_right),
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => StockDetailScreen(stockId: detail.stock.id),
            ),
          ),
        ),
        InfoRow('Format', '${r.format}'),
        InfoRow('Exposures', '${r.exposures}'),
        InfoRow('Price', fmtVnd(r.price)),
        InfoRow('Expiry', r.expiry?.toString()),
        InfoRow(
          'Shot ISO',
          r.shotIso?.toString() ?? 'Box (${detail.stock.boxIso})',
        ),
        InfoRow('Started', fmtDate(r.startedAt)),
        InfoRow('Finished', fmtDate(r.finishedAt)),
        InfoRow('Description', r.description),
        if (r.cameraId != null)
          ListTile(
            dense: true,
            title: Text(r.cameraName ?? 'Camera'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => CameraDetailScreen(cameraId: r.cameraId!),
              ),
            ),
          ),
        InfoRow(
          'Lenses',
          detail.lenses.isEmpty
              ? null
              : detail.lenses.map((l) => l.name).join('\n'),
        ),
        const SectionHeader('Cost'),
        InfoRow('Film', fmtVnd(detail.totals.rollPrice)),
        InfoRow('Processing', fmtVnd(detail.totals.processingPrice)),
        InfoRow(
          'Total',
          '${fmtVnd(detail.totals.total)}${detail.totals.incomplete ? ' (incomplete)' : ''}',
        ),
        const SectionHeader('Processing history'),
        if (jobs.isEmpty)
          const Padding(
            padding: EdgeInsets.all(16),
            child: Text('Not sent yet'),
          )
        else
          for (final j in jobs)
            ListTile(
              title: Text('${j.where} · ${j.type.label}'),
              subtitle: Text(
                [
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
              ),
              trailing: j.isOpen
                  ? const Chip(
                      label: Text('Open'),
                      visualDensity: VisualDensity.compact,
                    )
                  : null,
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => ProcessingDetailScreen(processingId: j.id),
                ),
              ),
            ),
        SectionHeader(
          'Frames',
          trailing: TextButton(
            onPressed: () async {
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
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => FrameScreen(rollId: r.id, number: n),
                  ),
                );
              }
            },
            child: const Text('Add notes'),
          ),
        ),
        if (detail.frames.isEmpty)
          const Padding(
            padding: EdgeInsets.all(16),
            child: Text('No frames yet. Import scans or add notes.'),
          )
        else
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Wrap(
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
                    onPressed: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) =>
                            FrameScreen(rollId: r.id, number: f.number),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        const SizedBox(height: 32),
      ],
    );
  }
}
