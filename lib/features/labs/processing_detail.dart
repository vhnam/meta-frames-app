import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/models.dart';
import '../../providers.dart';
import '../../widgets/common.dart';
import '../scans/import_scans.dart';
import '../scans/scan_grid.dart';

/// Marks scans received / negatives returned. Date defaults to today.
Future<void> markReceived(
  BuildContext context,
  WidgetRef ref,
  Processing p, {
  required bool negatives,
}) async {
  DateTime date = DateTime.now();
  final ok = await showDialog<bool>(
    context: context,
    builder: (c) => StatefulBuilder(
      builder: (c, setS) => AlertDialog(
        title: Text(negatives ? 'Negatives returned' : 'Scans received'),
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
  final api = ref.read(apiProvider);
  final done = await guard(context, () async {
    if (negatives) {
      await api.negativesReturned(p.id, date);
    } else {
      await api.scansReceived(p.id, date);
    }
  });
  if (!done || !context.mounted) return;
  refreshAll(ref);
  // M-28: offer to import the files now.
  if (!negatives &&
      await confirm(
        context,
        'Import scans now?',
        'Pick the scan files from this device.',
        ok: 'Import',
      ) &&
      context.mounted) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => ImportScansScreen(processingId: p.id)),
    );
  }
}

/// M-28, M-29, M-32 (job part), M-33, M-35.
class ProcessingDetailScreen extends ConsumerWidget {
  const ProcessingDetailScreen({super.key, required this.processingId});
  final String processingId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final v = ref.watch(processingProvider(processingId));
    return Scaffold(
      appBar: AppBar(
        title: Text(
          v.value == null
              ? 'Processing job'
              : '${v.value!.where} · ${v.value!.type.label}',
        ),
      ),
      body: AsyncBody(
        value: v,
        onRefresh: () async => refreshAll(ref),
        builder: (p) => CustomScrollView(
          slivers: [
            SliverList(
              delegate: SliverChildListDelegate([
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                  child: Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      if (p.type.hasScans && p.scansReceivedAt == null)
                        FilledButton.tonal(
                          onPressed: () =>
                              markReceived(context, ref, p, negatives: false),
                          child: const Text('Scans received'),
                        ),
                      if (!p.isHome && p.negativesReturnedAt == null)
                        FilledButton.tonal(
                          onPressed: () =>
                              markReceived(context, ref, p, negatives: true),
                          child: const Text('Negatives returned'),
                        ),
                      if (p.type.hasScans)
                        FilledButton.icon(
                          icon: const Icon(Icons.upload_file),
                          label: const Text('Import scans'),
                          onPressed: () => Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) =>
                                  ImportScansScreen(processingId: p.id),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
                InfoRow('Where', p.where),
                InfoRow('Type', p.type.label),
                InfoRow('Process', p.process.wire),
                InfoRow('Sent', fmtDate(p.sentAt)),
                InfoRow('Scans received', fmtDate(p.scansReceivedAt)),
                if (!p.isHome)
                  InfoRow('Negatives back', fmtDate(p.negativesReturnedAt)),
                InfoRow('Price', fmtVnd(p.price)),
                InfoRow('Notes', p.notes),
                InfoRow('Status', p.isOpen ? 'Open' : 'Closed'),
              ]),
            ),
            if (p.type.hasScans) ScanGrid(processing: p),
            const SliverToBoxAdapter(child: SizedBox(height: 32)),
          ],
        ),
      ),
    );
  }
}
