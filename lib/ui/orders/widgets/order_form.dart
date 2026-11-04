import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../domain/models/lab_order_requests.dart';
import '../../../domain/models/models.dart';
import '../../../domain/utils.dart';
import '../../../providers.dart';
import '../../../routing/navigation.dart';
import '../../core/theme.dart';
import '../../core/widgets/cards.dart';
import '../../core/widgets/common.dart';
import '../../core/widgets/form_kit.dart';
import '../../rolls/widgets/roll_form_kit.dart';
import '../view_models/lab_order_actions.dart';

/// One line as the form edits it.
class _LineDraft {
  _LineDraft({LabOrderLine? line})
    : id = line?.id ?? newId(),
      rolls = line?.jobs.length ?? 0,
      product = TextEditingController(text: line?.product),
      options = TextEditingController(text: line?.options),
      quantity = TextEditingController(text: '${line?.quantity ?? 1}'),
      unitPrice = TextEditingController(text: line?.unitPrice.toString());
  final String id;

  /// Rolls already on the line: it keeps room for them, and cannot go.
  final int rolls;
  final TextEditingController product, options, quantity, unitPrice;

  int get lineTotal =>
      (int.tryParse(quantity.text) ?? 0) * (int.tryParse(unitPrice.text) ?? 0);

  void dispose() {
    product.dispose();
    options.dispose();
    quantity.dispose();
    unitPrice.dispose();
  }
}

/// Copies the order a lab issued, or edits one. Follows the dashboard's order
/// dialog.
class OrderFormScreen extends ConsumerStatefulWidget {
  const OrderFormScreen({super.key, this.order});
  final LabOrder? order;
  @override
  ConsumerState<OrderFormScreen> createState() => _State();
}

class _State extends ConsumerState<OrderFormScreen> {
  final _key = GlobalKey<FormState>();

  /// Kept across retries, so saving again cannot create a second order.
  late final _orderId = widget.order?.id ?? newId();
  late String? _labId = widget.order?.labId;
  late final _code = TextEditingController(text: widget.order?.code);
  late DateTime _created = widget.order?.orderedAt ?? DateTime.now();
  late DateTime? _due = widget.order?.dueDate;
  late final _vat = TextEditingController(
    text: widget.order == null ? '' : '${widget.order!.vat}',
  );
  late final _discount = TextEditingController(
    text: widget.order == null ? '' : '${widget.order!.discount}',
  );
  late final _notes = TextEditingController(text: widget.order?.notes);
  late final List<_LineDraft> _lines = widget.order == null
      ? [_LineDraft()]
      : [for (final l in widget.order!.lines) _LineDraft(line: l)];
  String? _labError, _linesError;
  bool _busy = false;

  bool get _editing => widget.order != null;
  bool get _hasRolls => widget.order?.jobs.isNotEmpty ?? false;

  @override
  void dispose() {
    _code.dispose();
    _vat.dispose();
    _discount.dispose();
    _notes.dispose();
    for (final l in _lines) {
      l.dispose();
    }
    super.dispose();
  }

  int get _total =>
      _lines.fold<int>(0, (sum, l) => sum + l.lineTotal) +
      (int.tryParse(_vat.text) ?? 0) -
      (int.tryParse(_discount.text) ?? 0);

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final labs = ref.watch(labsProvider).value ?? const <Lab>[];
    return Scaffold(
      backgroundColor: cs.surfaceContainerLow,
      appBar: formAppBar(context, _editing ? 'Edit Order' : 'Add Order'),
      body: Form(
        key: _key,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            const FormSectionHeader(
              number: '01',
              title: 'Order',
              note: '* Required attributes',
            ),
            LabeledField(
              label: _hasRolls ? 'Lab (locked)' : 'Lab *',
              gapAfter: _labError == null ? 16 : 6,
              child: SelectField(
                hint: 'Select a lab',
                value:
                    labs.where((l) => l.id == _labId).firstOrNull?.name ??
                    widget.order?.labName,
                onTap: _hasRolls ? null : _pickLab,
              ),
            ),
            if (_labError != null) _error(cs, _labError!),
            LabeledField(
              label: 'Order code *',
              child: TextFormField(
                controller: _code,
                decoration: formInputDecoration('0510006', cs),
                validator: (v) =>
                    v == null || v.trim().isEmpty ? 'Required' : null,
              ),
            ),
            LabeledField(
              label: 'Created *',
              child: SelectField(
                hint: 'Select a date',
                value: DateFormat('dd/MM/yyyy HH:mm').format(_created),
                icon: Icons.calendar_today,
                onTap: _pickCreated,
              ),
            ),
            LabeledField(
              label: 'Due (optional)',
              child: SelectField(
                hint: 'Select a date',
                value: _due == null ? null : fmtDate(_due),
                icon: Icons.calendar_today,
                onTap: () async {
                  final d = await pickDate(context, _due);
                  if (d != null) setState(() => _due = d);
                },
                onClear: _due == null
                    ? null
                    : () => setState(() => _due = null),
              ),
            ),
            const FormSectionHeader(
              number: '02',
              title: 'Lines',
              note: 'One line per product, as on the order',
            ),
            for (final (index, line) in _lines.indexed)
              Padding(
                key: ValueKey(line.id),
                padding: const EdgeInsets.only(bottom: 12),
                child: _lineCard(cs, index, line),
              ),
            OutlinedButton.icon(
              icon: const Icon(Icons.add),
              label: const Text('Add line'),
              onPressed: () => setState(() => _lines.add(_LineDraft())),
            ),
            if (_linesError != null) ...[
              const SizedBox(height: 6),
              _error(cs, _linesError!),
            ],
            const SizedBox(height: 16),
            const FormSectionHeader(
              number: '03',
              title: 'Amounts',
              note: 'Amounts in dong, as on the order',
            ),
            LabeledField(
              label: 'VAT (optional)',
              child: _amount(_vat, '44800'),
            ),
            LabeledField(
              label: 'Discount (optional)',
              child: _amount(_discount, '0'),
            ),
            Align(
              alignment: Alignment.centerRight,
              child: Text(
                'Total ${fmtVnd(_total)}',
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            const SizedBox(height: 16),
            const FormSectionHeader(number: '04', title: 'Notes'),
            LabeledField(
              label: 'Notes (optional)',
              gapAfter: 24,
              child: TextFormField(
                controller: _notes,
                decoration: formInputDecoration('Paid by…', cs),
                minLines: 3,
                maxLines: 3,
              ),
            ),
            FormSaveBar(
              label: _editing ? 'Save changes' : 'Add order',
              busy: _busy,
              onPressed: _save,
            ),
          ],
        ),
      ),
    );
  }

  Widget _error(ColorScheme cs, String text) => Padding(
    padding: const EdgeInsets.only(bottom: 16),
    child: Text(text, style: TextStyle(fontSize: 13, color: cs.error)),
  );

  Widget _amount(TextEditingController c, String hint) => TextFormField(
    controller: c,
    decoration: formInputDecoration(
      hint,
      Theme.of(context).colorScheme,
    ).copyWith(suffixText: '₫'),
    keyboardType: TextInputType.number,
    validator: validPrice,
    onChanged: (_) => setState(() {}),
  );

  Widget _lineCard(ColorScheme cs, int index, _LineDraft line) => Container(
    padding: const EdgeInsets.all(12),
    decoration: BoxDecoration(
      color: cs.surface,
      borderRadius: kCorners,
      border: Border.all(color: cs.outlineVariant, width: kHairline),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(child: SectionLabel('Line ${index + 1}')),
            IconButton(
              icon: const Icon(Icons.delete_outline, size: 20),
              tooltip: 'Remove line ${index + 1}',
              onPressed: line.rolls > 0
                  ? null
                  : () => setState(() {
                      _lines.removeAt(index).dispose();
                    }),
            ),
          ],
        ),
        LabeledField(
          label: 'Product *',
          child: TextFormField(
            controller: line.product,
            decoration: formInputDecoration('35mm Colour film', cs),
            validator: (v) => v == null || v.trim().isEmpty ? 'Required' : null,
          ),
        ),
        LabeledField(
          label: 'Description (optional)',
          child: TextFormField(
            controller: line.options,
            decoration: formInputDecoration(
              'Development + Scan, High-Resolution',
              cs,
            ),
            minLines: 1,
            maxLines: 3,
          ),
        ),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          spacing: 12,
          children: [
            SizedBox(
              width: 88,
              child: LabeledField(
                label: 'Qty *',
                child: TextFormField(
                  controller: line.quantity,
                  decoration: formInputDecoration('1', cs),
                  keyboardType: TextInputType.number,
                  onChanged: (_) => setState(() {}),
                  validator: (v) {
                    final n = int.tryParse(v ?? '');
                    if (n == null || n < 1) return 'At least 1';
                    return n < line.rolls ? '${line.rolls} rolls on it' : null;
                  },
                ),
              ),
            ),
            Expanded(
              child: LabeledField(
                label: 'Unit price *',
                child: TextFormField(
                  controller: line.unitPrice,
                  decoration: formInputDecoration(
                    '145000',
                    cs,
                  ).copyWith(suffixText: '₫'),
                  keyboardType: TextInputType.number,
                  onChanged: (_) => setState(() {}),
                  validator: (v) {
                    final n = int.tryParse(v ?? '');
                    return n == null || n < 0 ? 'Enter a price' : null;
                  },
                ),
              ),
            ),
          ],
        ),
        Align(
          alignment: Alignment.centerRight,
          child: Text(
            fmtVnd(line.lineTotal),
            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
          ),
        ),
      ],
    ),
  );

  Future<void> _pickLab() async {
    final labs = await ref.read(labsProvider.future);
    if (!mounted) return;
    final id = await pickOne<String>(
      context,
      title: 'Lab',
      items: [for (final l in labs) l.id],
      label: (id) => labs.firstWhere((l) => l.id == id).name,
    );
    if (id != null) {
      setState(() {
        _labId = id;
        _labError = null;
      });
    }
  }

  /// The day, then the time: the order states both.
  Future<void> _pickCreated() async {
    final day = await pickDate(context, _created);
    if (day == null || !mounted) return;
    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(_created),
    );
    final at = time ?? TimeOfDay.fromDateTime(_created);
    setState(
      () =>
          _created = DateTime(day.year, day.month, day.day, at.hour, at.minute),
    );
  }

  String? _t(TextEditingController c) =>
      c.text.trim().isEmpty ? null : c.text.trim();

  Future<void> _save() async {
    final valid = _key.currentState!.validate();
    setState(() {
      _labError = _labId == null ? 'Select a lab.' : null;
      _linesError = _lines.isEmpty ? 'Add at least one line.' : null;
    });
    if (!valid || _labId == null || _lines.isEmpty) return;
    setState(() => _busy = true);
    final edit = LabOrderEdit(
      labId: _labId!,
      code: _code.text.trim().replaceFirst(RegExp(r'^#'), ''),
      orderedAt: _created,
      dueDate: _due,
      vat: int.tryParse(_vat.text) ?? 0,
      discount: int.tryParse(_discount.text) ?? 0,
      notes: _t(_notes),
      lines: [
        for (final l in _lines)
          LabOrderLineEdit(
            id: l.id,
            product: l.product.text.trim(),
            options: _t(l.options),
            quantity: int.parse(l.quantity.text),
            unitPrice: int.parse(l.unitPrice.text),
          ),
      ],
    );
    final ok = await guard(
      context,
      () => ref.read(labOrderActionsProvider).save(_orderId, edit),
    );
    if (!mounted) return;
    setState(() => _busy = false);
    if (ok) context.closeScreen(_orderId);
  }
}
