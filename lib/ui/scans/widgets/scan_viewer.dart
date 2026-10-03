import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import '../../../domain/models/models.dart';
import '../../../providers.dart';
import '../../core/widgets/common.dart';
import 'compare_screen.dart';
import 'frame_screen.dart';
import 'zoomable_scan.dart';

/// Full size scan viewer (M-35) with save/share (M-42).
class ScanViewerScreen extends ConsumerStatefulWidget {
  const ScanViewerScreen({
    super.key,
    required this.scans,
    required this.index,
    required this.processing,
    required this.rollId,
  });
  final List<Scan> scans;
  final int index;
  final Processing processing;
  final String rollId;
  @override
  ConsumerState<ScanViewerScreen> createState() => _State();
}

class _State extends ConsumerState<ScanViewerScreen> {
  late final PageController page = PageController(initialPage: widget.index);
  late int current = widget.index;

  Scan get scan => widget.scans[current];

  @override
  Widget build(BuildContext context) {
    final api = ref.watch(apiProvider);
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        title: Text('#${scan.frameNumber} · ${scan.scanner.label}'),
        actions: [
          if (widget.processing.scanners.length > 1)
            IconButton(
              tooltip: 'Compare scanners',
              icon: const Icon(Icons.compare),
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => CompareScreen(
                    processingId: widget.processing.id,
                    frameNumber: scan.frameNumber,
                  ),
                ),
              ),
            ),
          IconButton(
            tooltip: 'Frame notes',
            icon: const Icon(Icons.notes),
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => FrameScreen(
                  rollId: widget.rollId,
                  number: scan.frameNumber,
                ),
              ),
            ),
          ),
          IconButton(
            tooltip: 'Save or share',
            icon: const Icon(Icons.ios_share),
            onPressed: () => shareScan(context, ref, scan),
          ),
        ],
      ),
      body: PageView.builder(
        controller: page,
        itemCount: widget.scans.length,
        onPageChanged: (i) => setState(() => current = i),
        itemBuilder: (c, i) =>
            ZoomableScan(url: api.absolute(widget.scans[i].fileUrl)),
      ),
    );
  }
}

/// M-42 download the scan then hand it to the system share sheet
/// (which includes "Save to gallery"-style targets).
Future<void> shareScan(BuildContext context, WidgetRef ref, Scan s) async {
  try {
    final dir = await getTemporaryDirectory();
    final file = File('${dir.path}/${s.fileName}');
    await ref.read(apiProvider).downloadScan(s, file);
    await SharePlus.instance.share(ShareParams(files: [XFile(file.path)]));
  } catch (e) {
    if (context.mounted) toast(context, e.toString());
  }
}
