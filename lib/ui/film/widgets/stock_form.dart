import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../domain/models/film_requests.dart';
import '../../../domain/models/models.dart';
import '../../../providers.dart';
import '../../core/widgets/common.dart';
import '../view_models/film_stock_actions.dart';
import '../../core/widgets/form_kit.dart';
import 'iso_field.dart';
import 'stock_picker.dart';

import '../../../routing/navigation.dart';

/// M-12 add stock, M-13 edit stock, M-14 set base stock.
/// Pops the saved [FilmStock] so callers can create stocks inline.
class StockFormScreen extends ConsumerStatefulWidget {
  const StockFormScreen({super.key, this.stock, this.baseStock});
  final FilmStock? stock;
  final FilmStock? baseStock;
  @override
  ConsumerState<StockFormScreen> createState() => _State();
}

class _State extends ConsumerState<StockFormScreen> {
  final _key = GlobalKey<FormState>();
  late final brand = TextEditingController(text: widget.stock?.brand);
  late final name = TextEditingController(text: widget.stock?.name);
  late final iso = TextEditingController(text: widget.stock?.boxIso.toString());
  late final stockOrigin = TextEditingController(
    text: widget.stock?.stockOrigin,
  );
  late final packOrigin = TextEditingController(text: widget.stock?.packOrigin);
  late final desc = TextEditingController(text: widget.stock?.description);
  late StockType type = widget.stock?.type ?? StockType.color;
  late Process process = widget.stock?.process ?? Process.c41;
  late Packaging packaging = widget.stock?.packaging ?? Packaging.factory;
  late FilmStock? base = widget.baseStock;
  bool busy = false;

  bool get editing => widget.stock != null;

  @override
  void initState() {
    super.initState();
    final id = widget.stock?.baseStockId;
    if (id != null && base == null) {
      ref.read(stockDetailProvider(id).future).then((d) {
        if (mounted) setState(() => base = d.stock);
      }, onError: (_) {});
    }
  }

  String? get _mismatch {
    if (type == StockType.bw && process != Process.bw) {
      return 'B&W film is normally processed as BW.';
    }
    if (type == StockType.slide && process != Process.e6) {
      return 'Slide film is normally processed as E-6.';
    }
    return null;
  }

  String? _t(TextEditingController c) =>
      c.text.trim().isEmpty ? null : c.text.trim();

  @override
  void dispose() {
    for (final c in [brand, name, iso, stockOrigin, packOrigin, desc]) {
      c.dispose();
    }
    super.dispose();
  }

  String? _required(String? v) =>
      v == null || v.trim().isEmpty ? 'Required' : null;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final warn = _mismatch;
    return Scaffold(
      appBar: formAppBar(
        context,
        editing ? 'Edit film stock' : 'New film stock',
      ),
      body: Form(
        key: _key,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            LabeledField(
              label: 'Brand',
              child: TextFormField(
                controller: brand,
                decoration: formInputDecoration('e.g. Kodak', cs),
                textCapitalization: TextCapitalization.words,
                validator: _required,
              ),
            ),
            LabeledField(
              label: 'Name',
              child: TextFormField(
                controller: name,
                decoration: formInputDecoration('e.g. Portra 400', cs),
                textCapitalization: TextCapitalization.words,
                validator: _required,
              ),
            ),
            LabeledField(
              label: 'Type',
              child: ChoiceRow<StockType>(
                values: StockType.values,
                value: type,
                label: (t) => switch (t) {
                  StockType.color => 'Color',
                  StockType.bw => 'B&W',
                  StockType.slide => 'Slide',
                },
                onChanged: (v) => setState(() => type = v),
              ),
            ),
            LabeledField(
              label: 'Process',
              gapAfter: warn == null ? 16 : 8,
              child: ChoiceRow<Process>(
                values: Process.values,
                value: process,
                label: (p) => p.wire,
                onChanged: (v) => setState(() => process = v),
              ),
            ),
            if (warn != null) ...[FormNote(warn)],
            LabeledField(
              label: 'Box ISO',
              child: IsoField(controller: iso),
            ),
            LabeledField(
              label: 'Packaging',
              child: ChoiceRow<Packaging>(
                values: Packaging.values,
                value: packaging,
                label: (p) => switch (p) {
                  Packaging.factory => 'Factory',
                  Packaging.repack => 'Repack',
                  Packaging.respooled => 'Respooled',
                },
                onChanged: (v) => setState(() => packaging = v),
              ),
            ),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              spacing: 12,
              children: [
                Expanded(
                  child: LabeledField(
                    label: 'Stock origin',
                    child: TextFormField(
                      controller: stockOrigin,
                      decoration: formInputDecoration('e.g. USA', cs),
                    ),
                  ),
                ),
                if (packaging != Packaging.factory)
                  Expanded(
                    child: LabeledField(
                      label: 'Pack origin',
                      child: TextFormField(
                        controller: packOrigin,
                        decoration: formInputDecoration('e.g. Japan', cs),
                      ),
                    ),
                  ),
              ],
            ),
            LabeledField(
              label: 'Base stock (optional)',
              gapAfter: 8,
              child: SelectField(
                hint: 'Select a base stock',
                value: base?.label,
                onTap: () async {
                  final s = await pickStock(
                    context,
                    ref,
                    title: 'Base stock',
                    exclude: widget.stock?.id,
                    allowCreate: false,
                  );
                  if (s != null) setState(() => base = s);
                },
                onClear: () => setState(() => base = null),
              ),
            ),
            const FormNote(
              'Original emulsion of a repacked film. Leave empty if unknown and describe below.',
            ),
            LabeledField(
              label: 'Notes (optional)',
              child: TextFormField(
                controller: desc,
                decoration: formInputDecoration(
                  'Characteristics, where you buy it…',
                  cs,
                ),
                minLines: 4,
                maxLines: 4,
              ),
            ),
            FormSaveBar(
              label: editing ? 'Save changes' : 'Add film stock',
              busy: busy,
              onPressed: _save,
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _save() async {
    if (!_key.currentState!.validate()) return;
    setState(() => busy = true);
    final stock = FilmStockEdit(
      brand: brand.text.trim(),
      name: name.text.trim(),
      type: type,
      boxIso: int.parse(iso.text),
      process: process,
      packaging: packaging,
      stockOrigin: _t(stockOrigin),
      packOrigin: packaging == Packaging.factory ? null : _t(packOrigin),
      description: _t(desc),
      baseStockId: base?.id,
    );
    FilmStockDetail? saved;
    final ok = await guard(context, () async {
      saved = await ref
          .read(filmStockActionsProvider)
          .save(stock, existing: widget.stock);
    });
    if (!mounted) return;
    setState(() => busy = false);
    if (!ok) return;
    context.closeScreen(saved!.stock);
  }
}
