import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/widgets/common.dart';
import '../view_models/import_scans_view_model.dart';
import '../view_models/scan_actions.dart';

import '../../../routing/navigation.dart';

/// M-37 frame notes. The frame is created by the server on first save.
class FrameScreen extends ConsumerStatefulWidget {
  const FrameScreen({super.key, required this.rollId, required this.number});
  final String rollId;
  final int number;
  @override
  ConsumerState<FrameScreen> createState() => _State();
}

class _State extends ConsumerState<FrameScreen> {
  final notes = TextEditingController();
  bool busy = false, _filled = false;

  late final _frame = frameNotesProvider((widget.rollId, widget.number));

  @override
  void initState() {
    super.initState();
    // Fill the field once from the server; later refreshes must not overwrite typing.
    ref.listenManual(_frame, (_, v) {
      if (v.hasError) toast(context, v.error.toString());
      if (!_filled && !v.isLoading) {
        _filled = true;
        notes.text = v.value?.notes ?? '';
      }
    }, fireImmediately: true);
  }

  @override
  void dispose() {
    notes.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final v = ref.watch(_frame);
    final frame = v.value;
    final scanUrl = ref.watch(scanRefUrlProvider);
    return Scaffold(
      appBar: AppBar(
        title: Text('Frame #${widget.number}'),
        actions: [
          TextButton(onPressed: busy ? null : _save, child: const Text('Save')),
        ],
      ),
      body: v.isLoading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                TextField(
                  controller: notes,
                  decoration: deco(
                    'Notes',
                    hint: 'Subject, location, exposure settings',
                  ),
                  maxLines: 6,
                ),
                if (frame != null && frame.scans.isNotEmpty) ...[
                  const SectionHeader('Scans'),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      for (final s in frame.scans)
                        SizedBox(
                          width: 120,
                          child: Column(
                            children: [
                              Image.network(
                                scanUrl(s.id),
                                height: 100,
                                cacheHeight: 300,
                                fit: BoxFit.cover,
                              ),
                              Text(
                                s.scanner.label,
                                style: const TextStyle(fontSize: 12),
                              ),
                            ],
                          ),
                        ),
                    ],
                  ),
                ],
              ],
            ),
    );
  }

  Future<void> _save() async {
    setState(() => busy = true);
    final t = notes.text.trim();
    final ok = await guard(
      context,
      () => ref
          .read(scanActionsProvider)
          .saveFrameNotes(widget.rollId, widget.number, t.isEmpty ? null : t),
    );
    if (!mounted) return;
    setState(() => busy = false);
    if (!ok) return;
    context.closeScreen();
  }
}
