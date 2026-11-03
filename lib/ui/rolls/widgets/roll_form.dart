import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../domain/models/models.dart';
import '../../../domain/models/roll_requests.dart';
import '../../core/widgets/cards.dart';
import '../../core/widgets/common.dart';
import '../../core/widgets/form_kit.dart';
import '../../film/widgets/stock_picker.dart';
import '../../labs/widgets/processing_jobs.dart';
import '../view_models/roll_actions.dart';
import 'roll_form_kit.dart';

import '../../../routing/navigation.dart';

/// M-18 edit roll: film, price and expiry in numbered sections, as on the
/// dashboard, the roll's processing jobs, and deleting a roll still in stock.
/// Stock can change only while `in_stock`.
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
  bool busy = false;

  @override
  void dispose() {
    for (final c in [exposures, price, year]) {
      c.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final locked = r.status != RollStatus.inStock;
    return Scaffold(
      backgroundColor: cs.surfaceContainerLow,
      appBar: formAppBar(context, 'Edit Roll'),
      body: Form(
        key: _key,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Padding(
              padding: const EdgeInsets.only(bottom: 16),
              child: Text(
                'Update the film, purchase price, expiry and processing of this roll',
                style: TextStyle(fontSize: 13, color: cs.onSurfaceVariant),
              ),
            ),
            const FormSectionHeader(
              number: '01',
              title: 'Film',
              note: '* Required attributes',
            ),
            LabeledField(
              label: locked ? 'Film stock (locked)' : 'Film stock *',
              child: SelectField(
                hint: 'Select film stock',
                value: stock.label,
                onTap: locked
                    ? null
                    : () async {
                        final s = await pickStock(context, ref);
                        if (s != null) setState(() => stock = s);
                      },
              ),
            ),
            if (locked)
              const FormNote(
                'Film stock can only be changed while the roll is In Stock.',
              ),
            LabeledField(
              label: 'Format *',
              child: FormatPicker(
                value: format,
                formats: rollFormats(r.format),
                onChanged: (v) => setState(() => format = v),
              ),
            ),
            LabeledField(
              label: 'Exposures *',
              trailing: QuickPicks(
                values: const [12, 24, 36],
                controller: exposures,
              ),
              child: TextFormField(
                controller: exposures,
                decoration: formInputDecoration('e.g. 36', cs),
                keyboardType: TextInputType.number,
                validator: validExposures,
              ),
            ),
            const FormSectionHeader(
              number: '02',
              title: 'Purchase',
              note: 'Shipping excluded',
            ),
            LabeledField(
              label: 'Unit price (optional)',
              child: TextFormField(
                controller: price,
                decoration: formInputDecoration(
                  'e.g. 150000',
                  cs,
                ).copyWith(suffixText: '₫ / roll'),
                keyboardType: TextInputType.number,
                validator: validPrice,
              ),
            ),
            const FormSectionHeader(
              number: '03',
              title: 'Expiry',
              note: 'As printed on the box',
            ),
            Padding(
              padding: const EdgeInsets.only(bottom: 24),
              child: ExpiryFields(
                year: year,
                month: month,
                onMonth: (v) => setState(() => month = v),
                yearLabel: 'Expiry year (optional)',
                monthLabel: 'Expiry month (optional)',
                yearHint: 'e.g. 2027',
              ),
            ),
            const FormSectionHeader(
              number: '04',
              title: 'Processing',
              note: 'Each job saves on its own',
            ),
            Padding(
              padding: const EdgeInsets.only(bottom: 24),
              child: ProcessingJobs(
                rollId: r.id,
                jobs: widget.detail.processing,
              ),
            ),
            FormSaveBar(label: 'Save changes', busy: busy, onPressed: _save),
            // The server deletes only a roll that is still in stock.
            if (r.status == RollStatus.inStock) ...[
              const SizedBox(height: 20),
              CardList(
                children: [
                  DetailActionRow(
                    label: 'Delete roll',
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

  Future<void> _save() async {
    if (!_key.currentState!.validate()) return;
    setState(() => busy = true);
    final edit = RollEdit(
      filmStockId: stock.id,
      format: format,
      exposures: int.parse(exposures.text),
      price: price.text.isEmpty ? null : int.parse(price.text),
      expiryYear: year.text.isEmpty ? null : int.parse(year.text),
      expiryMonth: month,
      // The PUT replaces the roll: resend what this form does not edit.
      shotIso: r.shotIso,
      startedAt: r.startedAt,
      finishedAt: r.finishedAt,
      description: r.description,
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

  Future<void> _delete() async {
    if (busy) return;
    if (!await confirm(
      context,
      'Delete roll?',
      'This roll is still in stock and will be removed.',
      ok: 'Delete',
    )) {
      return;
    }
    if (!mounted) return;
    final ok = await guard(
      context,
      () => ref.read(rollActionsProvider).delete(r.id),
    );
    if (ok && mounted) context.closeDeleted();
  }
}
