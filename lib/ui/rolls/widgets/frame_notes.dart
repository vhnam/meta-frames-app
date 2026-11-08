import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../routing/navigation.dart';
import '../../../routing/routes.dart';
import '../../../data/sync/pending_op.dart';
import '../../../data/sync/sync_engine.dart';
import '../../../providers.dart';
import '../../core/theme.dart';
import '../../core/widgets/common.dart';
import '../../scans/view_models/scan_actions.dart';
import '../../sync/view_models/sync_actions.dart';
import '../../sync/widgets/op_status.dart';
import '../view_models/frame_notes.dart';

/// Asks for a frame number, then opens that frame's notes. The field starts
/// empty every time: the app cannot know which frame was just taken.
Future<void> noteFrame(BuildContext context, String rollId) async {
  final n = await showDialog<int>(
    context: context,
    builder: (_) => const _FrameNumberDialog(),
  );
  if (n != null && context.mounted) {
    await context.push(Routes.frame(rollId, n));
  }
}

class _FrameNumberDialog extends StatefulWidget {
  const _FrameNumberDialog();
  @override
  State<_FrameNumberDialog> createState() => _FrameNumberDialogState();
}

class _FrameNumberDialogState extends State<_FrameNumberDialog> {
  final _text = TextEditingController();
  String? _error;

  @override
  void dispose() {
    _text.dispose();
    super.dispose();
  }

  void _open() {
    final n = parseFrameNumber(_text.text);
    if (n == null) {
      setState(() => _error = 'Enter a frame number, 0 or more');
      return;
    }
    Navigator.pop(context, n);
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: const Text('Frame number'),
    content: TextField(
      controller: _text,
      keyboardType: TextInputType.number,
      autofocus: true,
      decoration: InputDecoration(errorText: _error),
      onSubmitted: (_) => _open(),
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: const Text('Cancel'),
      ),
      FilledButton(onPressed: _open, child: const Text('Open')),
    ],
  );
}

/// M-37 frame notes. The frame is created by the server on first save, so a
/// note needs no scans. Scans already imported for the frame show below.
class FrameScreen extends ConsumerWidget {
  const FrameScreen({super.key, required this.rollId, required this.number});
  final String rollId;
  final int number;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final provider = frameProvider((rollId, number));
    final v = ref.watch(provider);
    final frame = v.value;
    final scanUrl = ref.watch(scanRefUrlProvider);
    return NotesEditor(
      target: (rollId: rollId, frame: number),
      title: 'Frame #$number',
      hint: 'Subject, place, light, anything to remember',
      saved: v.whenData((f) => f?.notes),
      onRetry: () => ref.invalidate(provider),
      footer: [
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
                        headers: ref.watch(scanImageHeadersProvider),
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
    );
  }
}

/// The roll's own notes: subject, place, conditions, incidents. Saved on
/// their own, so they never revert anything else about the roll.
class RollNotesScreen extends ConsumerWidget {
  const RollNotesScreen({super.key, required this.rollId});
  final String rollId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final provider = rollDetailProvider(rollId);
    return NotesEditor(
      target: (rollId: rollId, frame: null),
      title: 'Roll notes',
      hint: 'Subject, location, conditions, incidents',
      saved: ref.watch(provider).whenData((d) => d.roll.description),
      onRetry: () => ref.invalidate(provider),
    );
  }
}

/// Edits one note. The field is filled once from the saved text and never
/// overwritten while the user types.
///
/// Save waits for the saved text: an edit must say what it was based on.
/// When the saved text cannot be read (offline and never kept on the phone,
/// or the server failed), it is not taken to be empty. With a partition the
/// edit is still kept on the phone, marked as based on unknown text, and the
/// saved text is read before anything is sent; without one, Save waits.
/// Saved text that arrives after the user started typing is shown next to
/// their text, for them to choose.
class NotesEditor extends ConsumerStatefulWidget {
  const NotesEditor({
    super.key,
    required this.target,
    required this.title,
    required this.hint,
    required this.saved,
    required this.onRetry,
    this.footer = const [],
  });
  final NotesTarget target;
  final String title, hint;

  /// The saved text (null for none), as the device read gives it: the
  /// server's, with this phone's pending edit to it laid over.
  final AsyncValue<String?> saved;
  final VoidCallback onRetry;
  final List<Widget> footer;

  @override
  ConsumerState<NotesEditor> createState() => _NotesEditorState();
}

class _NotesEditorState extends ConsumerState<NotesEditor> {
  final _text = TextEditingController();
  bool _busy = false, _filled = false, _typed = false;

  /// The user typed before the saved text was known.
  bool _typedBlind = false;

  /// The saved text the field started from, once known.
  String? _base;

  @override
  void initState() {
    super.initState();
    _fill(widget.saved);
  }

  @override
  void didUpdateWidget(NotesEditor old) {
    super.didUpdateWidget(old);
    _fill(widget.saved);
  }

  void _fill(AsyncValue<String?> v) {
    if (!v.hasValue) return;
    final saved = v.requireValue ?? '';
    if (!_filled) {
      _filled = true;
      _base = saved;
      if (_typed) {
        _typedBlind = true;
      } else {
        _text.text = saved;
      }
    } else if (!_typed && _base != saved) {
      // A refresh after a save elsewhere: nothing typed, so follow it.
      _base = saved;
      _text.text = saved;
    }
  }

  @override
  void dispose() {
    _text.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final v = widget.saved;
    final keeps = ref.watch(localStoreProvider) != null;
    final loading = !v.hasValue && v.isLoading;
    final unavailable = !v.hasValue && v.hasError;
    final saved = v.value ?? '';
    // Saved text arrived after typing began and differs from it.
    final arrived = _typedBlind && v.hasValue && !sameNotes(saved, _text.text);
    final op = ref.watch(notesOpProvider(widget.target));
    final canSave = !_busy && !loading && (!unavailable || keeps);

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.title),
        actions: [
          TextButton(
            onPressed: canSave ? _save : null,
            child: const Text('Save'),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          if (loading) const LinearProgressIndicator(),
          if (unavailable)
            _Notice(
              text: keeps
                  ? 'The saved notes are not on this phone yet. What you write is kept here and checked against them before it is sent.'
                  : 'The saved notes could not be loaded. Saving waits until they are, so they are not overwritten.',
              detail: '${v.error}',
              action: TextButton(
                onPressed: widget.onRetry,
                child: const Text('Retry'),
              ),
            ),
          if (arrived)
            _Notice(
              text: 'Saved notes arrived while you were typing:',
              detail: saved.isEmpty ? '(empty)' : saved,
              action: TextButton(
                onPressed: () => setState(() {
                  _text.text = saved;
                  _base = saved;
                  _typed = false;
                  _typedBlind = false;
                }),
                child: const Text('Use saved notes'),
              ),
            ),
          TextField(
            controller: _text,
            autofocus: true,
            onChanged: (_) {
              if (!_typed) setState(() => _typed = true);
            },
            decoration: deco('Notes', hint: widget.hint),
            maxLines: 6,
          ),
          if (op != null) ...[const SizedBox(height: 12), OpStatusCard(op: op)],
          ...widget.footer,
        ],
      ),
      backgroundColor: cs.surface,
    );
  }

  Future<void> _save() async {
    setState(() => _busy = true);
    final v = widget.saved;
    // The text the edit is based on: the latest saved text if it is known,
    // otherwise unknown (null), never assumed empty.
    final seen = v.hasValue ? (v.requireValue ?? '') : null;
    var queued = false;
    final ok = await guard(context, () async {
      queued = await ref
          .read(notesActionsProvider)
          .save(widget.target, _text.text, seenBase: seen);
    });
    if (!mounted) return;
    setState(() => _busy = false);
    if (!ok) return;
    if (queued && ref.read(syncStatusProvider)?.pause == SyncPause.offline) {
      toast(context, 'Saved on this phone. It syncs when the server is back.');
    }
    context.closeScreen();
  }
}

class _Notice extends StatelessWidget {
  const _Notice({required this.text, this.detail, this.action});
  final String text;
  final String? detail;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: cs.surfaceContainerHigh,
        borderRadius: kCorners,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(text),
          if (detail != null) ...[
            const SizedBox(height: 4),
            SelectableText(
              detail!,
              style: TextStyle(fontSize: 13, color: cs.onSurfaceVariant),
            ),
          ],
          ?action,
        ],
      ),
    );
  }
}
