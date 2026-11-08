import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../domain/models/models.dart';
import '../../../providers.dart';
import '../../core/widgets/cards.dart';
import '../../core/widgets/common.dart';
import '../../scans/widgets/scan_grid.dart';
import '../view_models/processing_actions.dart';
import 'processing_jobs.dart';

/// Marks scans received / negatives returned. Date defaults to today.
Future<void> markReceived(
  BuildContext context,
  WidgetRef ref,
  Processing p, {
  required bool negatives,
  String? title,
}) async {
  DateTime date = DateTime.now();
  final ok = await showDialog<bool>(
    context: context,
    builder: (c) => StatefulBuilder(
      builder: (c, setS) => AlertDialog(
        title: Text(
          title ?? (negatives ? 'Negatives returned' : 'Scans received'),
        ),
        content: DateField(
          label: 'Date',
          value: date,
          onChanged: (d) => setS(() => date = d!),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(c, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(c, true),
            child: const Text('Confirm'),
          ),
        ],
      ),
    ),
  );
  if (ok != true || !context.mounted) return;
  await guard(context, () async {
    final actions = ref.read(processingActionsProvider);
    if (negatives) {
      await actions.markNegativesReturned(p.id, date);
    } else {
      await actions.markScansReceived(p.id, date);
    }
  });
}

/// M-28, M-29, M-32 (job part), M-35. Read-only summary of the job.
class ProcessingDetailScreen extends ConsumerWidget {
  const ProcessingDetailScreen({super.key, required this.processingId});
  final String processingId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final v = ref.watch(processingProvider(processingId));
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
          v.value == null
              ? 'Processing job'
              : '${v.value!.where} · ${v.value!.type.label}',
          style: const TextStyle(fontSize: 19, fontWeight: FontWeight.w600),
        ),
      ),
      body: AsyncBody(
        value: v,
        onRefresh: () async =>
            ref.refresh(processingProvider(processingId).future),
        builder: (p) => _Body(job: p),
      ),
    );
  }
}

class _Body extends ConsumerWidget {
  const _Body({required this.job});
  final Processing job;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final p = job;
    final notes = p.notes?.trim() ?? '';
    final scansLabel = p.isHome ? 'Scanned' : 'Scans received';
    final negativesLabel = !p.isHome
        ? 'Negatives returned'
        : p.type == ProcessingType.print
        ? 'Printed'
        : 'Negatives developed';
    const pad = EdgeInsets.all(16);
    final actions = [
      if (p.type.hasScans && p.scansReceivedAt == null)
        FilledButton.icon(
          style: FilledButton.styleFrom(padding: pad),
          icon: const Icon(Icons.check),
          label: Text(scansLabel),
          onPressed: () => markReceived(
            context,
            ref,
            p,
            negatives: false,
            title: scansLabel,
          ),
        ),
      if (p.type.recordsNegativesReturned(atLab: !p.isHome) &&
          p.negativesReturnedAt == null)
        FilledButton.icon(
          style: FilledButton.styleFrom(padding: pad),
          icon: const Icon(Icons.check),
          label: Text(negativesLabel),
          onPressed: () => markReceived(
            context,
            ref,
            p,
            negatives: true,
            title: negativesLabel,
          ),
        ),
    ];
    const cardPad = EdgeInsets.symmetric(horizontal: 16, vertical: 12);
    return CustomScrollView(
      slivers: [
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
          sliver: SliverList.list(
            children: [
              const DetailLabel('JOB', top: 0),
              CardList(
                children: [
                  DetailInfoRow('Lab', p.where),
                  DetailInfoRow('Service', p.type.label),
                  DetailInfoRow('Process', p.process.label),
                  DetailInfoRow('Price', fmtVnd(p.price)),
                  if (p.order case final o?)
                    DetailInfoRow('Order', '#${o.code}'),
                  DetailInfoRow('Status', p.isOpen ? 'Open' : 'Closed'),
                ],
              ),
              const DetailLabel('DATES'),
              CardList(
                children: [Padding(padding: cardPad, child: JobDates(p))],
              ),
              if (p.scanOrders.isNotEmpty) ...[
                const DetailLabel('SCANNERS'),
                CardList(
                  children: [
                    Padding(
                      padding: cardPad,
                      child: JobScanOrders(p.scanOrders),
                    ),
                  ],
                ),
              ],
              if (notes.isNotEmpty) ...[
                const DetailLabel('NOTES'),
                CardList(
                  children: [Padding(padding: cardPad, child: JobNotes(notes))],
                ),
              ],
            ],
          ),
        ),
        if (p.type.hasScans)
          SliverPadding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            sliver: ScanGrid(processing: p),
          ),
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(16, 20, 16, 16),
          sliver: SliverList.list(
            children: [
              for (final a in actions)
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: SizedBox(width: double.infinity, child: a),
                ),
            ],
          ),
        ),
      ],
    );
  }
}
