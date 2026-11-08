import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../data/local/local_store.dart';
import '../../../domain/models/lab_requests.dart';
import '../../../domain/utils.dart';
import '../../sync/view_models/drafts.dart';
import '../../../domain/models/models.dart';
import '../../core/widgets/common.dart';
import '../../core/widgets/form_kit.dart';
import '../view_models/lab_actions.dart';

/// Quick add of a lab, in a dialog: only its name. Address and scanners are
/// set on the dashboard. Returns the saved [Lab]. A new lab is kept as a draft
/// until the server confirms it; [draft] reopens one.
Future<Lab?> editLab(BuildContext context, [Draft? draft]) => showDialog<Lab>(
  context: context,
  builder: (_) => _LabDialog(draft: draft),
);

class _LabDialog extends ConsumerStatefulWidget {
  const _LabDialog({this.draft});
  final Draft? draft;

  @override
  ConsumerState<_LabDialog> createState() => _LabDialogState();
}

class _LabDialogState extends ConsumerState<_LabDialog> {
  late final LabEdit? _restored = widget.draft == null
      ? null
      : LabEdit.fromJson(widget.draft!.json['request']);
  late final _name = TextEditingController(text: _restored?.name);

  /// The new lab's client id, kept with its draft.
  late String _draftId = widget.draft?.id ?? newId();

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final name = _name.text.trim();
    if (name.isEmpty) return;
    final edit = LabEdit(name: name);
    Lab? saved;
    final actions = ref.read(labActionsProvider);
    final id = _draftId;
    final ok = await guard(context, () async {
      try {
        saved = await ref
            .read(draftActionsProvider)
            .submit(
              id: id,
              kind: DraftKind.lab,
              label: edit.name,
              form: {'request': edit.toJson()},
              send: () => actions.save(edit, id: id),
              readBack: () => actions.landed(id, edit),
            );
      } on DraftIdTaken catch (e) {
        _draftId = e.newId;
        throw draftError(e);
      }
    });
    if (ok && mounted) Navigator.pop(context, saved);
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return AlertDialog(
      title: const Text('Add lab'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            LabeledField(
              label: 'Name',
              child: TextField(
                controller: _name,
                autofocus: true,
                textCapitalization: TextCapitalization.words,
                decoration: formInputDecoration('e.g. Foto Lab', cs),
              ),
            ),
            if (widget.draft?.error case final e?) Text(e),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        FilledButton(onPressed: _save, child: const Text('Save')),
      ],
    );
  }
}
