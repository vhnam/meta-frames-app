import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../domain/models/models.dart';
import '../../../providers.dart';
import '../../core/widgets/cards.dart';
import '../view_models/scan_actions.dart';
import '../../../routing/routes.dart';

import 'package:go_router/go_router.dart';

/// M-35 grid of scans ordered by frame number, switchable per scanner.
/// Returns slivers: place it directly inside a [CustomScrollView], which sets
/// the side padding.
class ScanGrid extends ConsumerStatefulWidget {
  const ScanGrid({super.key, required this.processing});
  final Processing processing;
  @override
  ConsumerState<ScanGrid> createState() => _State();
}

class _State extends ConsumerState<ScanGrid> {
  Scanner? scanner;

  @override
  Widget build(BuildContext context) {
    final p = widget.processing;
    final scanned = p.scannedWith;
    if (scanned.isEmpty) {
      return SliverToBoxAdapter(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const DetailLabel('SCANS'),
            Text(
              'No scans yet',
              style: TextStyle(
                fontSize: 13,
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      );
    }
    final sel = scanner != null && scanned.contains(scanner)
        ? scanner!
        : scanned.first;
    final scans = ref.watch(scansProvider((p.id, sel)));
    return SliverMainAxisGroup(
      slivers: [
        const SliverToBoxAdapter(child: DetailLabel('SCANS')),
        if (scanned.length > 1)
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: SegmentedButton<Scanner>(
                showSelectedIcon: false,
                segments: [
                  for (final s in scanned)
                    ButtonSegment(value: s, label: Text(s.label)),
                ],
                selected: {sel},
                onSelectionChanged: (s) => setState(() => scanner = s.first),
              ),
            ),
          ),
        ...scans.when(
          loading: () => const [
            SliverToBoxAdapter(
              child: Padding(
                padding: EdgeInsets.all(24),
                child: Center(child: CircularProgressIndicator()),
              ),
            ),
          ],
          error: (e, _) => [
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Text('$e'),
              ),
            ),
          ],
          data: (sorted) => [
            SliverGrid.builder(
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 3,
                mainAxisSpacing: 6,
                crossAxisSpacing: 6,
              ),
              itemCount: sorted.length,
              itemBuilder: (c, i) => _Thumb(
                scan: sorted[i],
                url: ref.watch(scanUrlProvider)(sorted[i]),
                onTap: () => c.push(Routes.scanViewer(p.id, sel, i)),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _Thumb extends ConsumerWidget {
  const _Thumb({required this.scan, required this.url, required this.onTap});
  final Scan scan;
  final String url;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context, WidgetRef ref) => GestureDetector(
    onTap: onTap,
    child: Stack(
      fit: StackFit.expand,
      children: [
        Image.network(
          url,
          headers: ref.watch(scanImageHeadersProvider),
          fit: BoxFit.cover,
          cacheWidth: 300,
          errorBuilder: (_, _, _) => const ColoredBox(
            color: Colors.black12,
            child: Icon(Icons.broken_image),
          ),
        ),
        Positioned(
          left: 0,
          bottom: 0,
          child: Container(
            color: Colors.black54,
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            child: Text(
              '#${scan.frameNumber}',
              style: const TextStyle(color: Colors.white, fontSize: 11),
            ),
          ),
        ),
      ],
    ),
  );
}
