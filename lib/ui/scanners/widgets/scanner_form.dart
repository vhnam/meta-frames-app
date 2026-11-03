import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../domain/models/models.dart';
import '../../../domain/models/scanner_requests.dart';
import '../../../providers.dart';
import '../../../routing/navigation.dart';
import '../../core/theme.dart';
import '../../core/widgets/cards.dart';
import '../../core/widgets/common.dart';
import '../../core/widgets/form_kit.dart';
import '../view_models/scanner_actions.dart';
import 'scan_settings_fields.dart';

/// Add a scanner, edit one of the account's own, or view a built-in one, which
/// is shared by every account and cannot be changed.
class ScannerFormScreen extends ConsumerStatefulWidget {
  const ScannerFormScreen({super.key, this.scanner});
  final ScannerDevice? scanner;
  @override
  ConsumerState<ScannerFormScreen> createState() => _State();
}

class _State extends ConsumerState<ScannerFormScreen> {
  final _key = GlobalKey<FormState>();
  late final _brand = TextEditingController(text: widget.scanner?.brand);
  late final _model = TextEditingController(text: widget.scanner?.model);
  late final _notes = TextEditingController(text: widget.scanner?.notes);
  late ScannerKind? _kind = widget.scanner?.kind;
  late Map<String, Object?> _settings = {...?widget.scanner?.defaultSettings};
  bool _busy = false;

  bool get _editing => widget.scanner != null;
  bool get _readOnly => widget.scanner?.builtIn ?? false;

  @override
  void dispose() {
    _brand.dispose();
    _model.dispose();
    _notes.dispose();
    super.dispose();
  }

  String? _t(TextEditingController c) =>
      c.text.trim().isEmpty ? null : c.text.trim();

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final kinds = ref.watch(scannerKindsProvider);
    // Null until the kinds load. Saving waits for them, because the server
    // replaces the default settings and they cannot be completed without them.
    final options = kinds.hasValue
        ? optionsForKind(kinds.requireValue, _kind)
        : null;
    final title = _readOnly
        ? 'Built-in Scanner'
        : (_editing ? 'Edit Scanner' : 'New Scanner');
    return Scaffold(
      backgroundColor: cs.surfaceContainerLow,
      appBar: formAppBar(context, title),
      body: Form(
        key: _key,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            if (_readOnly) ...[
              const FormNote(
                'A lab scanner shared by every account. It cannot be changed; its orders start from these settings.',
              ),
              const SizedBox(height: 16),
            ],
            LabeledField(
              label: 'Brand',
              child: TextFormField(
                controller: _brand,
                enabled: !_readOnly,
                decoration: formInputDecoration(
                  'e.g. Noritsu, Frontier, Epson',
                  cs,
                ),
                textCapitalization: TextCapitalization.words,
                validator: (v) =>
                    v == null || v.trim().isEmpty ? 'Required' : null,
              ),
            ),
            LabeledField(
              label: 'Model (optional)',
              child: TextFormField(
                controller: _model,
                enabled: !_readOnly,
                decoration: formInputDecoration(
                  'e.g. V850, Flextight X5, A7R IV + 100mm',
                  cs,
                ),
              ),
            ),
            LabeledField(
              label: 'Kind (optional)',
              child: DropdownButtonFormField<ScannerKind?>(
                initialValue: _kind,
                decoration: formInputDecoration('Select a kind', cs),
                borderRadius: kCorners,
                items: [
                  const DropdownMenuItem(child: Text('Unknown kind')),
                  for (final k in ScannerKind.values)
                    DropdownMenuItem(value: k, child: Text(k.label)),
                ],
                onChanged: _readOnly ? null : (k) => setState(() => _kind = k),
              ),
            ),
            const DetailLabel('DEFAULT SCAN SETTINGS', top: 4),
            if (kinds.hasError && !kinds.hasValue)
              Text('${kinds.error}')
            else if (options == null)
              const LinearProgressIndicator()
            else
              ScanSettingsFields(
                key: ValueKey(_kind),
                options: options,
                settings: _settings,
                readOnly: _readOnly,
                onChanged: (v) => setState(() => _settings = v),
              ),
            const SizedBox(height: 16),
            LabeledField(
              label: 'Notes (optional)',
              child: TextFormField(
                controller: _notes,
                enabled: !_readOnly,
                decoration: formInputDecoration(
                  'Light source, film holder, conversion software…',
                  cs,
                ),
                minLines: 4,
                maxLines: 4,
              ),
            ),
            if (!_readOnly)
              FormSaveBar(
                label: _editing ? 'Save changes' : 'Add scanner',
                busy: _busy,
                onPressed: options == null ? null : () => _save(options),
              ),
            if (_editing && !_readOnly) ...[
              const SizedBox(height: 20),
              CardList(
                children: [
                  DetailActionRow(
                    label: 'Delete scanner',
                    color: cs.error,
                    onTap: _delete,
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  Future<void> _save(List<ScanOption> options) async {
    if (!_key.currentState!.validate()) return;
    setState(() => _busy = true);
    final edit = ScannerEdit(
      brand: _brand.text.trim(),
      model: _t(_model),
      kind: _kind,
      notes: _t(_notes),
      defaultSettings: completeSettings(options, _settings),
    );
    ScannerDevice? saved;
    final ok = await guard(context, () async {
      saved = await ref
          .read(scannerActionsProvider)
          .save(edit, existing: widget.scanner);
    });
    if (!mounted) return;
    setState(() => _busy = false);
    if (ok) context.closeScreen(saved);
  }

  Future<void> _delete() async {
    if (_busy) return;
    final scanner = widget.scanner!;
    if (!await confirm(
      context,
      'Delete scanner?',
      '${scanner.name} will be removed, and labs that run it lose it. Refused if a job or scan uses it.',
      ok: 'Delete',
    )) {
      return;
    }
    if (!mounted) return;
    final ok = await guard(
      context,
      () => ref.read(scannerActionsProvider).delete(scanner.id),
    );
    if (ok && mounted) context.closeScreen();
  }
}
