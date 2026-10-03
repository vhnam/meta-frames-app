import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../domain/models/models.dart';
import '../../../domain/models/roll_requests.dart';
import '../../core/widgets/common.dart';
import '../../core/widgets/form_kit.dart';
import '../../film/widgets/stock_picker.dart';
import '../view_models/roll_actions.dart';
import 'roll_form_kit.dart';

import '../../../routing/navigation.dart';

/// M-18 edit roll. Stock can change only while `in_stock`.
class RollFormScreen extends ConsumerStatefulWidget {
  const RollFormScreen({super.key, required this.detail});
  final RollDetail detail;
  @override
  ConsumerState<RollFormScreen> createState() => _State();
}

class _State extends ConsumerState<RollFormScreen> {
  final _key = GlobalKey<FormState>();
  RollSummary get r => widget.detail.roll;
  late FilmStock stock = widget.detail.stock;
  late int format = r.format;
  late final exposures = TextEditingController(text: '${r.exposures}');
  late final price = TextEditingController(text: r.price?.toString() ?? '');
  late final year = TextEditingController(
    text: r.expiry?.year.toString() ?? '',
  );
  late int? month = r.expiry?.month;
  late final iso = TextEditingController(text: r.shotIso?.toString() ?? '');
  late final desc = TextEditingController(text: r.description);
  late DateTime? started = r.startedAt;
  late DateTime? finished = r.finishedAt;
  bool busy = false;

  @override
  void dispose() {
    for (final c in [exposures, price, year, iso, desc]) {
      c.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final locked = r.status != RollStatus.inStock;
    return Scaffold(
      appBar: formAppBar(context, 'Edit roll'),
      body: Form(
        key: _key,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            LabeledField(
              label: locked ? 'Film stock (locked)' : 'Film stock',
              child: SelectField(
                hint: 'Select a film stock',
                value: stock.label,
                onTap: locked
                    ? null
                    : () async {
                        final s = await pickStock(
                          context,
                          ref,
                          withRollsFirst: true,
                        );
                        if (s != null) setState(() => stock = s);
                      },
              ),
            ),
            LabeledField(
              label: 'Format',
              child: FormatPicker(
                value: format,
                formats: rollFormats(r.format),
                onChanged: (v) => setState(() => format = v),
              ),
            ),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              spacing: 12,
              children: [
                Expanded(
                  child: LabeledField(
                    label: 'Exposures',
                    child: TextFormField(
                      controller: exposures,
                      decoration: formInputDecoration('36', cs),
                      keyboardType: TextInputType.number,
                      validator: validExposures,
                    ),
                  ),
                ),
                Expanded(
                  child: LabeledField(
                    label: 'Price (₫, optional)',
                    child: TextFormField(
                      controller: price,
                      decoration: formInputDecoration('180000', cs),
                      keyboardType: TextInputType.number,
                      validator: validPrice,
                    ),
                  ),
                ),
              ],
            ),
            LabeledField(
              label: 'Expiry (optional)',
              child: ExpiryFields(
                year: year,
                month: month,
                onMonth: (v) => setState(() => month = v),
              ),
            ),
            LabeledField(
              label: 'Shot ISO (optional)',
              child: TextFormField(
                controller: iso,
                decoration: formInputDecoration(
                  'Empty = box ISO ${stock.boxIso}',
                  cs,
                ),
                keyboardType: TextInputType.number,
                validator: (v) {
                  if (v == null || v.isEmpty) return null;
                  final n = int.tryParse(v);
                  return n == null || n <= 0 ? 'Positive whole number' : null;
                },
              ),
            ),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              spacing: 12,
              children: [
                Expanded(
                  child: LabeledField(
                    label: 'Start date',
                    child: _DateField(
                      started,
                      (d) => setState(() => started = d),
                    ),
                  ),
                ),
                Expanded(
                  child: LabeledField(
                    label: 'Finish date',
                    child: _DateField(
                      finished,
                      (d) => setState(() => finished = d),
                    ),
                  ),
                ),
              ],
            ),
            LabeledField(
              label: 'Notes (optional)',
              child: TextFormField(
                controller: desc,
                decoration: formInputDecoration(
                  'Where it was bought, how it was stored…',
                  cs,
                ),
                minLines: 4,
                maxLines: 4,
              ),
            ),
            if (locked)
              const FormNote(
                'Film stock can only be changed while the roll is In Stock.',
              ),
            FormSaveBar(label: 'Save changes', busy: busy, onPressed: _save),
          ],
        ),
      ),
    );
  }

  Future<void> _save() async {
    if (!_key.currentState!.validate()) return;
    setState(() => busy = true);
    final shot = int.tryParse(iso.text);
    final edit = RollEdit(
      filmStockId: stock.id,
      format: format,
      exposures: int.parse(exposures.text),
      price: price.text.isEmpty ? null : int.parse(price.text),
      expiryYear: year.text.isEmpty ? null : int.parse(year.text),
      expiryMonth: month,
      // Stored as null when equal to the box ISO.
      shotIso: shot == null || shot == stock.boxIso ? null : shot,
      startedAt: started,
      finishedAt: finished,
      description: desc.text.trim().isEmpty ? null : desc.text.trim(),
    );
    final ok = await guard(
      context,
      () => ref.read(rollActionsProvider).edit(r.id, edit),
    );
    if (!mounted) return;
    setState(() => busy = false);
    if (!ok) return;
    context.closeScreen();
  }
}

class _DateField extends StatelessWidget {
  const _DateField(this.value, this.onChanged);
  final DateTime? value;
  final ValueChanged<DateTime?> onChanged;

  @override
  Widget build(BuildContext context) => SelectField(
    hint: 'Select date',
    value: value == null ? null : fmtDate(value),
    icon: Icons.calendar_today,
    onTap: () async {
      final d = await pickDate(context, value);
      if (d != null) onChanged(d);
    },
    onClear: () => onChanged(null),
  );
}
