import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/models.dart';
import '../../providers.dart';
import 'scan_viewer.dart';
import 'zoomable_scan.dart';

/// M-36 compare Noritsu vs Frontier. Toggle or swipe between the two scans;
/// previous / next frame buttons keep compare mode.
class CompareScreen extends ConsumerStatefulWidget {
  const CompareScreen({
    super.key,
    required this.processingId,
    required this.frameNumber,
  });
  final String processingId;
  final int frameNumber;
  @override
  ConsumerState<CompareScreen> createState() => _State();
}

class _State extends ConsumerState<CompareScreen> {
  late int frame = widget.frameNumber;
  Scanner shown = Scanner.noritsu;

  @override
  Widget build(BuildContext context) {
    final v = ref.watch(compareProvider((widget.processingId, frame)));
    final api = ref.watch(apiProvider);
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        title: Text('Frame #$frame'),
        actions: [
          if (v.value != null &&
              (v.value!.noritsu ?? v.value!.frontier) != null)
            IconButton(
              icon: const Icon(Icons.ios_share),
              onPressed: () {
                final c = v.value!;
                final s =
                    (shown == Scanner.noritsu ? c.noritsu : c.frontier) ??
                    c.noritsu ??
                    c.frontier!;
                shareScan(context, ref, s);
              },
            ),
        ],
      ),
      body: v.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(
          child: Text('$e', style: const TextStyle(color: Colors.white)),
        ),
        data: (c) {
          final pairs = [
            (Scanner.noritsu, c.noritsu),
            (Scanner.frontier, c.frontier),
          ];
          return Column(
            children: [
              Padding(
                padding: const EdgeInsets.all(8),
                child: SegmentedButton<Scanner>(
                  showSelectedIcon: false,
                  segments: [
                    for (final p in pairs)
                      ButtonSegment(
                        value: p.$1,
                        label: Text(
                          '${p.$1.label}${p.$2 == null ? ' (missing)' : ''}',
                        ),
                      ),
                  ],
                  selected: {shown},
                  onSelectionChanged: (s) => setState(() => shown = s.first),
                ),
              ),
              Expanded(
                child: GestureDetector(
                  onHorizontalDragEnd: (d) {
                    // Swipe to flip between scanners.
                    if ((d.primaryVelocity ?? 0).abs() > 200) {
                      setState(
                        () => shown = shown == Scanner.noritsu
                            ? Scanner.frontier
                            : Scanner.noritsu,
                      );
                    }
                  },
                  child: Builder(
                    builder: (_) {
                      final s = shown == Scanner.noritsu
                          ? c.noritsu
                          : c.frontier;
                      if (s == null) {
                        return Center(
                          child: Text(
                            'No ${shown.label} scan for this frame',
                            style: const TextStyle(color: Colors.white70),
                          ),
                        );
                      }
                      return ZoomableScan(
                        key: ValueKey(s.fileUrl),
                        url: api.absolute(s.fileUrl),
                      );
                    },
                  ),
                ),
              ),
              SafeArea(
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    TextButton.icon(
                      onPressed: c.previousFrameNumber == null
                          ? null
                          : () =>
                                setState(() => frame = c.previousFrameNumber!),
                      icon: const Icon(Icons.chevron_left),
                      label: const Text('Previous'),
                    ),
                    TextButton.icon(
                      onPressed: c.nextFrameNumber == null
                          ? null
                          : () => setState(() => frame = c.nextFrameNumber!),
                      icon: const Icon(Icons.chevron_right),
                      iconAlignment: IconAlignment.end,
                      label: const Text('Next'),
                    ),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}
