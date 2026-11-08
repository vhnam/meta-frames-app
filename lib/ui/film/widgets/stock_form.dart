import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../data/local/local_store.dart';
import '../../../domain/models/film_requests.dart';
import '../../../domain/models/models.dart';
import '../../../domain/utils.dart';
import '../../core/widgets/common.dart';
import '../../sync/view_models/drafts.dart';
import '../view_models/film_stock_actions.dart';
import '../../core/widgets/form_kit.dart';
import 'iso_field.dart';

import '../../../routing/navigation.dart';

/// Quick add of a film stock (from a picker, mid-trip, or from the film list).
/// Pops the saved [FilmStock] so callers can create stocks inline.
///
/// It asks only what the server needs: brand, name, box ISO, and the type,
/// process and packaging, which stay visible with their usual defaults and are
/// never inferred from each other (chromogenic B&W is C-41; cross-processed
/// slide film exists). Origins, base stock and notes are set on the dashboard.
/// A new stock is kept as a draft until the server confirms it; [draft]
/// reopens one.
class StockFormScreen extends ConsumerStatefulWidget {
  const StockFormScreen({super.key, this.draft});
  final Draft? draft;
  @override
  ConsumerState<StockFormScreen> createState() => _State();
}

class _State extends ConsumerState<StockFormScreen> {
  final _key = GlobalKey<FormState>();
  late final FilmStockEdit? _restored = widget.draft == null
      ? null
      : FilmStockEdit.fromJson(widget.draft!.json['request']);
  late final brand = TextEditingController(text: _restored?.brand);
  late final name = TextEditingController(text: _restored?.name);
  late final iso = TextEditingController(text: _restored?.boxIso);
  late StockType type = _restored?.type ?? StockType.color;
  late Process process = _restored?.process ?? Process.c41;
  late Packaging packaging = _restored?.packaging ?? Packaging.factory;
  bool busy = false;

  /// The new stock's client id, kept with its draft.
  late String _draftId = widget.draft?.id ?? newId();

  String? get _mismatch {
    if (type == StockType.bw && process != Process.bw) {
      return 'B&W film is normally processed as BW.';
    }
    if (type == StockType.slide && process != Process.e6) {
      return 'Slide film is normally processed as E-6.';
    }
    return null;
  }

  @override
  void dispose() {
    for (final c in [brand, name, iso]) {
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
      appBar: formAppBar(context, 'New film stock'),
      body: Form(
        key: _key,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            if (widget.draft?.error case final e?) WarningBanner([e]),
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
            const FormNote(
              'Origins, base stock and notes can be added later on the dashboard.',
            ),
            FormSaveBar(label: 'Add film stock', busy: busy, onPressed: _save),
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
      boxIso: iso.text.trim(),
      process: process,
      packaging: packaging,
    );
    FilmStockDetail? saved;
    final actions = ref.read(filmStockActionsProvider);
    final id = _draftId;
    final ok = await guard(context, () async {
      try {
        saved = await ref
            .read(draftActionsProvider)
            .submit(
              id: id,
              kind: DraftKind.stock,
              label: '${stock.brand} ${stock.name}',
              form: {'request': stock.toJson()},
              send: () => actions.save(stock, id: id),
              readBack: () => actions.landed(id, stock),
            );
      } on DraftIdTaken catch (e) {
        _draftId = e.newId;
        throw draftError(e);
      }
    });
    if (!mounted) return;
    setState(() => busy = false);
    if (!ok) return;
    context.closeScreen(saved!.stock);
  }
}
