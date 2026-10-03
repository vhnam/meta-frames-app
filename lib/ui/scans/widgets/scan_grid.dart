import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../domain/models/models.dart';
import '../../../providers.dart';
import '../../core/widgets/common.dart';
import 'scan_viewer.dart';

/// M-35 grid of scans ordered by frame number, switchable per scanner.
/// Returns slivers: place it directly inside a [CustomScrollView].
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
    if (p.scanners.isEmpty) {
      return const SliverToBoxAdapter(
        child: Padding(
          padding: EdgeInsets.all(16),
          child: Text('No scans imported yet.'),
        ),
      );
    }
    final sel = scanner != null && p.scanners.contains(scanner)
        ? scanner!
        : p.scanners.first;
    final scans = ref.watch(scansProvider((p.id, sel)));
    final api = ref.watch(apiProvider);
    return SliverMainAxisGroup(
      slivers: [
        const SliverToBoxAdapter(child: SectionHeader('Scans')),
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
            child: SegmentedButton<Scanner>(
              showSelectedIcon: false,
              segments: [
                for (final s in p.scanners)
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
            SliverPadding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              sliver: SliverGrid.builder(
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 3,
                  mainAxisSpacing: 6,
                  crossAxisSpacing: 6,
                ),
                itemCount: sorted.length,
                itemBuilder: (c, i) => _Thumb(
                  scan: sorted[i],
                  url: api.absolute(sorted[i].fileUrl),
                  onTap: () => Navigator.push(
                    c,
                    MaterialPageRoute(
                      builder: (_) => ScanViewerScreen(
                        scans: sorted,
                        index: i,
                        processing: p,
                        rollId: p.rollId,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _Thumb extends StatelessWidget {
  const _Thumb({required this.scan, required this.url, required this.onTap});
  final Scan scan;
  final String url;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: onTap,
    child: Stack(
      fit: StackFit.expand,
      children: [
        Image.network(
          url,
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
