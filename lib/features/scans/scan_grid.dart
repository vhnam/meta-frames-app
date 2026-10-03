import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/models.dart';
import '../../providers.dart';
import '../../widgets/common.dart';
import 'scan_viewer.dart';

/// M-35 grid of scans ordered by frame number, switchable per scanner.
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
      return const Padding(
        padding: EdgeInsets.all(16),
        child: Text('No scans imported yet.'),
      );
    }
    final sel = scanner != null && p.scanners.contains(scanner)
        ? scanner!
        : p.scanners.first;
    final scans = ref.watch(scansProvider((p.id, sel)));
    final api = ref.watch(apiProvider);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SectionHeader('Scans'),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
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
        const SizedBox(height: 8),
        scans.when(
          loading: () => const Padding(
            padding: EdgeInsets.all(24),
            child: Center(child: CircularProgressIndicator()),
          ),
          error: (e, _) =>
              Padding(padding: const EdgeInsets.all(16), child: Text('$e')),
          data: (list) {
            final sorted = [...list]
              ..sort((a, b) => a.frameNumber - b.frameNumber);
            return GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              padding: const EdgeInsets.symmetric(horizontal: 16),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 3,
                mainAxisSpacing: 6,
                crossAxisSpacing: 6,
              ),
              itemCount: sorted.length,
              itemBuilder: (c, i) {
                final s = sorted[i];
                return GestureDetector(
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
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      Image.network(
                        api.absolute(s.fileUrl),
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
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 2,
                          ),
                          child: Text(
                            '#${s.frameNumber}',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 11,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              },
            );
          },
        ),
      ],
    );
  }
}
