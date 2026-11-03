import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../domain/models/lab_requests.dart';
import '../../../domain/models/models.dart';
import '../../../providers.dart';
import '../../core/widgets/common.dart';
import '../../core/widgets/form_kit.dart';
import '../view_models/lab_actions.dart';

/// Add or edit a lab in a dialog. Returns the saved [Lab].
Future<Lab?> editLab(BuildContext context, [Lab? lab]) => showDialog<Lab>(
  context: context,
  builder: (_) => _LabDialog(lab: lab),
);

class _LabDialog extends ConsumerStatefulWidget {
  const _LabDialog({this.lab});
  final Lab? lab;

  @override
  ConsumerState<_LabDialog> createState() => _LabDialogState();
}

class _LabDialogState extends ConsumerState<_LabDialog> {
  late final _name = TextEditingController(text: widget.lab?.name);
  late final _address = TextEditingController(text: widget.lab?.address);

  /// The lab's scanners, in order.
  late List<String> _scannerIds = [...?widget.lab?.scannerIds];
  late String? _defaultId = widget.lab?.defaultScannerId;

  @override
  void dispose() {
    _name.dispose();
    _address.dispose();
    super.dispose();
  }

  void _toggle(String id, bool on) => setState(() {
    if (!on && _defaultId == id) _defaultId = null;
    _scannerIds = on
        ? [..._scannerIds, id]
        : _scannerIds.where((e) => e != id).toList();
  });

  /// The default moves to the top; switching it off leaves no default.
  void _setDefault(String id, bool on) => setState(() {
    if (!on) {
      _defaultId = null;
      return;
    }
    _scannerIds = [id, ..._scannerIds.where((e) => e != id)];
    _defaultId = id;
  });

  Future<void> _save() async {
    final name = _name.text.trim();
    if (name.isEmpty) return;
    final address = _address.text.trim();
    final edit = LabEdit(
      name: name,
      address: address.isEmpty ? null : address,
      scannerIds: _scannerIds,
      defaultScannerId: _defaultId,
    );
    Lab? saved;
    final ok = await guard(context, () async {
      saved = await ref
          .read(labActionsProvider)
          .save(edit, existing: widget.lab);
    });
    if (ok && mounted) Navigator.pop(context, saved);
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return AlertDialog(
      // Scanner rows need the width on a phone.
      insetPadding: const EdgeInsets.all(16),
      title: Text(widget.lab == null ? 'Add lab' : 'Edit lab'),
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
            LabeledField(
              label: 'Address (optional)',
              child: TextField(
                controller: _address,
                decoration: formInputDecoration('Street, city', cs),
              ),
            ),
            LabeledField(
              label: 'Scanners',
              gapAfter: 0,
              child: ref
                  .watch(scannersProvider)
                  .when(
                    data: _scannerRows,
                    loading: () => const LinearProgressIndicator(),
                    // Saving still works: the lab keeps the scanners it has.
                    error: (e, _) => Text('$e'),
                  ),
            ),
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

  /// Ticked scanners first, in their order, then the rest as the API lists them.
  Widget _scannerRows(List<ScannerDevice> all) {
    final byId = {for (final s in all) s.id: s};
    final rows = [
      for (final id in _scannerIds) ?byId[id],
      ...all.where((s) => !_scannerIds.contains(s.id)),
    ];
    return Column(
      children: [
        for (final s in rows)
          _ScannerRow(
            scanner: s,
            ticked: _scannerIds.contains(s.id),
            isDefault: _defaultId == s.id,
            onTicked: (on) => _toggle(s.id, on),
            onDefault: (on) => _setDefault(s.id, on),
          ),
      ],
    );
  }
}

class _ScannerRow extends StatelessWidget {
  const _ScannerRow({
    required this.scanner,
    required this.ticked,
    required this.isDefault,
    required this.onTicked,
    required this.onDefault,
  });
  final ScannerDevice scanner;
  final bool ticked, isDefault;
  final ValueChanged<bool> onTicked, onDefault;

  @override
  Widget build(BuildContext context) {
    final muted = TextStyle(
      fontSize: 12,
      color: Theme.of(context).colorScheme.onSurfaceVariant,
    );
    return Row(
      children: [
        Checkbox(value: ticked, onChanged: (on) => onTicked(on ?? false)),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(scanner.name, style: const TextStyle(fontSize: 14)),
              if (!scanner.builtIn) Text('Yours', style: muted),
            ],
          ),
        ),
        if (ticked) ...[
          const SizedBox(width: 8),
          Text('Default', style: muted),
          Switch(value: isDefault, onChanged: onDefault),
        ],
      ],
    );
  }
}
