import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../domain/models/models.dart';
import '../../../providers.dart';
import '../../core/widgets/cards.dart';
import '../../core/widgets/common.dart';

/// A lab's name, address and scanners, as the dashboard's lab shows them.
/// Read-only: the dashboard edits and deletes labs.
class LabDetailScreen extends ConsumerWidget {
  const LabDetailScreen({super.key, required this.labId});
  final String labId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final lab = ref.watch(labProvider(labId));
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
          lab.value?.name ?? 'Lab',
          style: const TextStyle(fontSize: 19, fontWeight: FontWeight.w600),
        ),
      ),
      body: AsyncBody(
        value: lab,
        onRefresh: () {
          ref.invalidate(scannersProvider);
          return ref.refresh(labProvider(labId).future);
        },
        builder: (l) => _Body(lab: l),
      ),
    );
  }
}

class _Body extends ConsumerWidget {
  const _Body({required this.lab});
  final Lab lab;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scanners = ref.watch(scannersProvider);

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        CardList(
          children: [
            DetailInfoRow('Name', lab.name),
            DetailInfoRow('Address', lab.address ?? 'No address'),
          ],
        ),
        const DetailLabel('SCANNERS'),
        if (lab.scannerIds.isEmpty)
          _muted(context, 'No scanners')
        else
          scanners.when(
            data: (all) => _scannerList(context, all),
            loading: () => const LinearProgressIndicator(),
            error: (e, _) => Text('$e'),
          ),
        const SizedBox(height: 16),
      ],
    );
  }

  Widget _muted(BuildContext context, String text) => Text(
    text,
    style: TextStyle(
      fontSize: 13,
      color: Theme.of(context).colorScheme.onSurfaceVariant,
    ),
  );

  /// The lab's scanners in the lab's order.
  Widget _scannerList(BuildContext context, List<ScannerDevice> all) {
    final cs = Theme.of(context).colorScheme;
    final own = lab.scannersFrom(all);
    if (own.isEmpty) return _muted(context, 'No scanners');
    return CardList(
      children: [
        for (final s in own)
          CardTile(
            compact: true,
            leading: Icon(
              Icons.scanner_outlined,
              size: 20,
              color: cs.onSurfaceVariant,
            ),
            title: s.name,
            subtitle: s.builtIn ? s.kindLabel : '${s.kindLabel} · Yours',
            badge: s.id == lab.defaultScannerId
                ? StampBadge('Default', color: cs.primary)
                : null,
          ),
      ],
    );
  }
}
