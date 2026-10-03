import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../domain/models/models.dart';
import '../../core/widgets/common.dart';
import '../view_models/import_scans_view_model.dart';

import '../../../routing/navigation.dart';

/// M-33 import scans from device, M-34 offset / start frame numbering.
class ImportScansScreen extends ConsumerStatefulWidget {
  const ImportScansScreen({super.key, required this.processingId});
  final String processingId;
  @override
  ConsumerState<ImportScansScreen> createState() => _State();
}

class _State extends ConsumerState<ImportScansScreen> {
  final startFrame = TextEditingController();
  final offset = TextEditingController();

  late final _provider = importScansViewModelProvider(widget.processingId);
  ImportScansViewModel get _vm => ref.read(_provider.notifier);

  @override
  void dispose() {
    startFrame.dispose();
    offset.dispose();
    super.dispose();
  }

  Future<void> _pick() async {
    final res = await FilePicker.pickFiles(type: FileType.image);
    if (res.isEmpty) return;
    await _run(
      () => _vm.setFiles(
        [
          for (final f in res)
            if (f.path != null) (name: f.name, path: f.path!),
        ],
        startFrame: int.tryParse(startFrame.text),
        offset: int.tryParse(offset.text),
      ),
    );
  }

  Future<void> _preview() => _run(
    () => _vm.preview(
      startFrame: int.tryParse(startFrame.text),
      offset: int.tryParse(offset.text),
    ),
  );

  Future<void> _run(Future<void> Function() action) async {
    try {
      await action();
    } catch (e) {
      if (mounted) toast(context, e.toString());
    }
  }

  Future<void> _editFrame(ImportItem it) async {
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
    c.dispose();
    if (n != null && n >= 0) _vm.setFrame(it.name, n);
  }

  Future<void> _import() async {
    final summary = await _vm.import();
    if (!mounted) return;
    toast(context, summary.message);
    if (summary.complete) context.closeScreen();
  }

  @override
  Widget build(BuildContext context) {
    final st = ref.watch(_provider);
    final items = st.items;
    return Scaffold(
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
            selected: {st.scanner},
            onSelectionChanged: (s) => _vm.setScanner(s.first),
          ),
          gap,
          OutlinedButton.icon(
            onPressed: st.busy ? null : _pick,
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
              value: st.replace,
              onChanged: _vm.setReplace,
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
              onPressed: st.canImport ? _import : null,
              child: Text(st.busy ? (st.progress ?? 'Uploading…') : 'Import'),
            ),
          ],
          if (st.failures.isNotEmpty) ...[
            const SectionHeader('Failed'),
            for (final f in st.failures)
              ListTile(
                contentPadding: EdgeInsets.zero,
                dense: true,
                title: Text(f.fileName),
                subtitle: Text(f.reason),
              ),
            const Text(
              'Failed files are kept above. Tap Import to retry them.',
            ),
          ],
        ],
      ),
    );
  }
}
