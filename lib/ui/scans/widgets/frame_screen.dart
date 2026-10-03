import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api.dart';
import '../../../domain/models/models.dart';
import '../../../providers.dart';
import '../../core/widgets/common.dart';

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
  Frame? frame;
  bool loading = true, busy = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final f = await ref.read(apiProvider).frame(widget.rollId, widget.number);
      frame = f;
      notes.text = f.notes ?? '';
    } on ApiException catch (e) {
      // 404: frame has no scans or notes yet; saving creates it.
      if (e.status != 404 && mounted) toast(context, e.message);
    }
    if (mounted) setState(() => loading = false);
  }

  @override
  Widget build(BuildContext context) {
    final api = ref.watch(apiProvider);
    return Scaffold(
      appBar: AppBar(
        title: Text('Frame #${widget.number}'),
        actions: [
          TextButton(onPressed: busy ? null : _save, child: const Text('Save')),
        ],
      ),
      body: loading
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
                if (frame != null && frame!.scans.isNotEmpty) ...[
                  const SectionHeader('Scans'),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      for (final s in frame!.scans)
                        SizedBox(
                          width: 120,
                          child: Column(
                            children: [
                              Image.network(
                                api.absolute('/scans/${s.id}/file'),
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
          .read(apiProvider)
          .saveFrameNotes(widget.rollId, widget.number, t.isEmpty ? null : t),
    );
    if (!mounted) return;
    setState(() => busy = false);
    if (!ok) return;
    refreshAll(ref);
    Navigator.pop(context);
  }
}
