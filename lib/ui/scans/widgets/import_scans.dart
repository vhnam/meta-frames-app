import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../domain/models/models.dart';
import '../../../providers.dart';
import '../../core/widgets/common.dart';

class _Item {
  _Item(this.name, this.path);
  final String name, path;
  int? frame;
  String? error;
}

/// M-33 import scans from device, M-34 offset / start frame numbering.
class ImportScansScreen extends ConsumerStatefulWidget {
  const ImportScansScreen({super.key, required this.processingId});
  final String processingId;
  @override
  ConsumerState<ImportScansScreen> createState() => _State();
}

class _State extends ConsumerState<ImportScansScreen> {
  Scanner scanner = Scanner.noritsu;
  bool replace = false;
  List<_Item> items = [];
  final startFrame = TextEditingController();
  final offset = TextEditingController();
  bool busy = false;
  String? progress;
  List<ImportFailure> failures = [];

  Future<void> _pick() async {
    final res = await FilePicker.pickFiles(type: FileType.image);
    if (res.isEmpty) return;
    final picked = [
      for (final f in res)
        if (f.path != null) _Item(f.name, f.path!),
    ]..sort((a, b) => a.name.compareTo(b.name));
    setState(() {
      items = picked;
      failures = [];
    });
    await _preview();
  }

  /// Ask the server to map file names to frame numbers (M-34 applies here).
  Future<void> _preview() async {
    if (items.isEmpty) return;
    try {
      final map = await ref
          .read(apiProvider)
          .previewImport(
            widget.processingId,
            items.map((e) => e.name).toList(),
            startFrame: int.tryParse(startFrame.text),
            offset: int.tryParse(offset.text),
          );
      setState(() {
        for (final m in map) {
          final it = items.firstWhere((e) => e.name == m.fileName);
          it.frame = m.frameNumber;
          it.error = m.error;
        }
      });
    } catch (e) {
      if (mounted) toast(context, e.toString());
    }
  }

  Future<void> _editFrame(_Item it) async {
    final c = TextEditingController(text: it.frame?.toString());
    final n = await showDialog<int>(
      context: context,
      builder: (d) => AlertDialog(
        title: Text(it.name),
        content: TextField(
          controller: c,
          keyboardType: TextInputType.number,
          autofocus: true,
          decoration: deco('Frame number'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(d),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(d, int.tryParse(c.text)),
            child: const Text('OK'),
          ),
        ],
      ),
    );
    if (n != null && n >= 0)
      setState(() {
        it.frame = n;
        it.error = null;
      });
  }

  Future<void> _import([List<_Item>? only]) async {
    final todo = (only ?? items)
        .where((e) => e.frame != null && e.error == null)
        .toList();
    if (todo.isEmpty) return;
    setState(() {
      busy = true;
      failures = [];
    });
    final api = ref.read(apiProvider);
    var done = 0, skipped = 0;
    final failed = <ImportFailure>[];
    final failedItems = <_Item>[];
    for (final it in todo) {
      setState(
        () => progress =
            'Uploading ${done + failed.length + 1} of ${todo.length}…',
      );
      try {
        final r = await api.importScan(
          widget.processingId,
          scanner: scanner,
          path: it.path,
          fileName: it.name,
          frameNumber: it.frame!,
          replace: replace,
        );
        done += r.imported.length;
        skipped += r.skipped.length;
        failed.addAll(r.failed);
      } catch (e) {
        failed.add(
          ImportFailure.fromJson({'fileName': it.name, 'reason': e.toString()}),
        );
        failedItems.add(it);
      }
    }
    if (!mounted) return;
    refreshAll(ref);
    setState(() {
      busy = false;
      progress = null;
      failures = failed;
      // Keep only failures so the user can retry them; successes stay attached.
      items = items
          .where((e) => failed.any((f) => f.fileName == e.name))
          .toList();
    });
    toast(
      context,
      '$done imported${skipped > 0 ? ', $skipped skipped' : ''}${failed.isNotEmpty ? ', ${failed.length} failed' : ''}',
    );
    if (failed.isEmpty) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Import scans')),
    body: ListView(
      padding: const EdgeInsets.all(16),
      children: [
        SegmentedButton<Scanner>(
          showSelectedIcon: false,
          segments: [
            for (final s in Scanner.values)
              ButtonSegment(value: s, label: Text(s.label)),
          ],
          selected: {scanner},
          onSelectionChanged: (s) => setState(() => scanner = s.first),
        ),
        gap,
        OutlinedButton.icon(
          onPressed: busy ? null : _pick,
          icon: const Icon(Icons.photo_library_outlined),
          label: Text(
            items.isEmpty ? 'Choose files' : 'Choose different files',
          ),
        ),
        if (items.isNotEmpty) ...[
          const SectionHeader('Frame numbering'),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            spacing: 12,
            children: [
              Expanded(
                child: TextField(
                  controller: startFrame,
                  decoration: deco('Start at', hint: 'e.g. 3'),
                  keyboardType: TextInputType.number,
                  onSubmitted: (_) => _preview(),
                ),
              ),
              Expanded(
                child: TextField(
                  controller: offset,
                  decoration: deco('Offset', hint: 'e.g. +2'),
                  keyboardType: const TextInputType.numberWithOptions(
                    signed: true,
                  ),
                  onSubmitted: (_) => _preview(),
                ),
              ),
              IconButton.filledTonal(
                onPressed: _preview,
                icon: const Icon(Icons.refresh),
              ),
            ],
          ),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Replace existing scans'),
            subtitle: const Text(
              'Off: skip frames that already have a scan from this scanner',
            ),
            value: replace,
            onChanged: (v) => setState(() => replace = v),
          ),
          SectionHeader('Preview (${items.length} files)'),
          for (final it in items)
            ListTile(
              contentPadding: EdgeInsets.zero,
              title: Text(it.name, overflow: TextOverflow.ellipsis),
              subtitle: it.error == null
                  ? null
                  : Text(
                      it.error!,
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.error,
                      ),
                    ),
              trailing: ActionChip(
                label: Text(it.frame == null ? 'Set frame' : '#${it.frame}'),
                onPressed: () => _editFrame(it),
              ),
            ),
          gap,
          FilledButton(
            onPressed:
                busy || items.every((e) => e.frame == null || e.error != null)
                ? null
                : () => _import(),
            child: Text(busy ? (progress ?? 'Uploading…') : 'Import'),
          ),
        ],
        if (failures.isNotEmpty) ...[
          const SectionHeader('Failed'),
          for (final f in failures)
            ListTile(
              contentPadding: EdgeInsets.zero,
              dense: true,
              title: Text(f.fileName),
              subtitle: Text(f.reason),
            ),
          const Text('Failed files are kept above. Tap Import to retry them.'),
        ],
      ],
    ),
  );
}
