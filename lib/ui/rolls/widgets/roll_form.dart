import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../data/services/api_client.dart';
import '../../../domain/models/models.dart';
import '../../../providers.dart';
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
///
/// Saving replaces the whole roll, so it is conditional on the version the
/// form was opened with (`If-Match`). If the roll changed since (a note saved
/// from the phone, an edit on the dashboard), nothing is written: the form
/// keeps what the user typed, lists what changed, and waits for the user to
/// keep their edits on top of the latest roll or take the current values.
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

  /// The roll this edit is based on: its version is sent with the save, and
  /// the fields the form does not edit (shot ISO, dates, notes) come from it.
  late RollDetail _base = widget.detail;

  /// The roll as it is now, after a save was refused because it changed.
  RollDetail? _latest;

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
            if (_latest case final latest?)
              _ChangedElsewhere(
                changes: rollChanges(_base, latest),
                onKeepMine: () => setState(() {
                  _base = latest;
                  _latest = null;
                }),
                onUseCurrent: () => setState(() => _useCurrent(latest)),
              ),
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
            FormSaveBar(
              label: 'Save changes',
              busy: busy,
              // A refused save waits for the user's choice.
              onPressed: _latest == null ? _save : null,
            ),
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
      // The PUT replaces the roll: resend what this form does not edit, as
      // the roll it is based on holds it.
      shotIso: _base.roll.shotIso,
      startedAt: _base.roll.startedAt,
      finishedAt: _base.roll.finishedAt,
      description: _base.roll.description,
    );
    var changed = false;
    final ok = await guard(context, () async {
      try {
        await ref
            .read(rollActionsProvider)
            .edit(r.id, edit, version: _base.roll.version);
      } on ApiException catch (e) {
        if (e.status != 412) rethrow;
        changed = true;
      }
    });
    if (!mounted) return;
    if (ok && changed) {
      await _loadLatest();
      return;
    }
    setState(() => busy = false);
    if (!ok) return;
    context.closeScreen();
  }

  /// Reads the roll as it is now, keeping everything typed in the form.
  Future<void> _loadLatest() async {
    RollDetail? latest;
    final ok = await guard(context, () async {
      latest = await ref.refresh(rollDetailProvider(r.id).future);
    });
    if (!mounted) return;
    setState(() {
      busy = false;
      if (ok) _latest = latest;
    });
    if (!ok) toast(context, 'The roll changed. Reload it before saving.');
  }

  /// Resets the form to the roll as it is now.
  void _useCurrent(RollDetail latest) {
    final l = latest.roll;
    _base = latest;
    _latest = null;
    stock = latest.stock;
    format = l.format;
    exposures.text = '${l.exposures}';
    price.text = l.price?.toString() ?? '';
    year.text = l.expiry?.year.toString() ?? '';
    month = l.expiry?.month;
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

/// Fields that differ between two reads of a roll, as "Field: before → after".
List<String> rollChanges(RollDetail before, RollDetail after) {
  final a = before.roll, b = after.roll;
  String v(Object? x) => x == null || '$x'.trim().isEmpty ? '—' : '$x';
  String d(DateTime? x) => x == null ? '—' : fmtDate(x);
  return [
    if (a.status != b.status) 'Status: ${a.status.label} → ${b.status.label}',
    if (a.filmStockId != b.filmStockId)
      'Film stock: ${a.stockLabel} → ${b.stockLabel}',
    if (a.format != b.format) 'Format: ${a.format} → ${b.format}',
    if (a.exposures != b.exposures)
      'Exposures: ${a.exposures} → ${b.exposures}',
    if (a.price != b.price) 'Price: ${v(a.price)} → ${v(b.price)}',
    if ('${a.expiry}' != '${b.expiry}')
      'Expiry: ${v(a.expiry)} → ${v(b.expiry)}',
    if (a.shotIso != b.shotIso) 'Shot ISO: ${v(a.shotIso)} → ${v(b.shotIso)}',
    if (a.startedAt != b.startedAt)
      'Started: ${d(a.startedAt)} → ${d(b.startedAt)}',
    if (a.finishedAt != b.finishedAt)
      'Finished: ${d(a.finishedAt)} → ${d(b.finishedAt)}',
    if ((a.description ?? '') != (b.description ?? ''))
      'Notes: ${v(a.description)} → ${v(b.description)}',
  ];
}

class _ChangedElsewhere extends StatelessWidget {
  const _ChangedElsewhere({
    required this.changes,
    required this.onKeepMine,
    required this.onUseCurrent,
  });
  final List<String> changes;
  final VoidCallback onKeepMine, onUseCurrent;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: cs.errorContainer,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'This roll changed since you opened it. Nothing was saved.',
            style: TextStyle(fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 6),
          for (final c
              in changes.isEmpty
                  ? const [
                      'Only its version moved (a change outside this form).',
                    ]
                  : changes)
            Text('• $c'),
          Wrap(
            spacing: 8,
            children: [
              TextButton(
                onPressed: onKeepMine,
                child: const Text('Keep my edits'),
              ),
              TextButton(
                onPressed: onUseCurrent,
                child: const Text('Use the current values'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
