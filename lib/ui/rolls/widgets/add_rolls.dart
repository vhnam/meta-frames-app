import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../data/local/local_store.dart';
import '../../../domain/models/models.dart';
import '../../../domain/models/roll_requests.dart';
import '../../../domain/utils.dart';
import '../../core/widgets/common.dart';
import '../../core/widgets/form_kit.dart';
import '../../film/widgets/stock_picker.dart';
import '../../sync/view_models/drafts.dart';
import '../view_models/roll_actions.dart';
import 'roll_form_kit.dart';

import '../../../routing/navigation.dart';

/// M-17 add rolls in bulk. Only the stock, format, exposures and quantity are
/// needed; in [quick] mode (film bought mid-trip, opened from a picker) the
/// price and expiry fold away. Pops the rolls it added.
///
/// The form is kept as a draft before it is sent, under one idempotency key
/// for its whole life (and when resumed from [draft]), so a retry after a
/// timeout or a restart never adds the rolls twice.
class AddRollsScreen extends ConsumerStatefulWidget {
  const AddRollsScreen({super.key, this.stock, this.draft, this.quick = false});
  final FilmStock? stock;
  final Draft? draft;
  final bool quick;
  @override
  ConsumerState<AddRollsScreen> createState() => _State();
}

class _State extends ConsumerState<AddRollsScreen> {
  final _key = GlobalKey<FormState>();
  late final NewRolls? _restored = widget.draft == null
      ? null
      : NewRolls.fromJson(widget.draft!.json['request']);
  late String? stockId = widget.stock?.id ?? _restored?.filmStockId;
  late String? stockLabel =
      widget.stock?.label ?? widget.draft?.json['stockLabel'] as String?;
  late int format = _restored?.format ?? 135;
  late final exposures = TextEditingController(
    text: '${_restored?.exposures ?? 36}',
  );
  late final quantity = TextEditingController(
    text: '${_restored?.quantity ?? 1}',
  );
  late final price = TextEditingController(
    text: _restored?.price?.toString() ?? '',
  );
  late final year = TextEditingController(
    text: _restored?.expiryYear?.toString() ?? '',
  );
  late int? month = _restored?.expiryMonth;
  bool busy = false;

  /// The draft's id, which is also the request's idempotency key.
  late String _draftId = widget.draft?.id ?? newId();
  late bool _more =
      !widget.quick || price.text.isNotEmpty || year.text.isNotEmpty;

  @override
  void dispose() {
    for (final c in [exposures, quantity, price, year]) {
      c.dispose();
    }
    super.dispose();
  }

  int get _qty => int.tryParse(quantity.text) ?? 1;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final n = _qty < 1 ? 1 : _qty;
    return Scaffold(
      appBar: formAppBar(context, 'New roll'),
      body: Form(
        key: _key,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            if (widget.draft?.error case final e?) WarningBanner([e]),
            LabeledField(
              label: 'Film stock',
              child: SelectField(
                hint: 'Select a film stock',
                value: stockLabel,
                onTap: () async {
                  final s = await pickStock(context, ref);
                  if (s != null) {
                    setState(() {
                      stockId = s.id;
                      stockLabel = s.label;
                    });
                  }
                },
                validator: () => stockId == null ? 'Select a film stock' : null,
              ),
            ),
            LabeledField(
              label: 'Format',
              child: FormatPicker(
                value: format,
                formats: rollFormats(),
                onChanged: (v) => setState(() {
                  format = v;
                  if (v == 135) exposures.text = '36';
                  if (v == 120) exposures.text = '12';
                }),
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
                    label: 'Quantity',
                    child: TextFormField(
                      controller: quantity,
                      decoration: formInputDecoration('1', cs),
                      keyboardType: TextInputType.number,
                      validator: (v) {
                        final n = int.tryParse(v ?? '') ?? 0;
                        return n < 1 || n > 200 ? '1 to 200' : null;
                      },
                      onChanged: (_) => setState(() {}),
                    ),
                  ),
                ),
              ],
            ),
            if (!_more)
              Align(
                alignment: Alignment.centerLeft,
                child: TextButton(
                  onPressed: () => setState(() => _more = true),
                  child: const Text('Add price or expiry'),
                ),
              ),
            if (_more) ...[
              LabeledField(
                label: 'Unit price per roll (₫, optional)',
                child: TextFormField(
                  controller: price,
                  decoration: formInputDecoration('180000', cs),
                  keyboardType: TextInputType.number,
                  validator: validPrice,
                ),
              ),
              LabeledField(
                label: 'Expiry (optional)',
                child: ExpiryFields(
                  year: year,
                  month: month,
                  onMonth: (v) => setState(() => month = v),
                ),
              ),
            ],
            const FormNote(
              'New rolls start as In Stock. Load them into a camera from the roll’s page.',
            ),
            FormSaveBar(
              label: n == 1 ? 'Add roll' : 'Add $n rolls',
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
    final n = int.parse(quantity.text);
    final rolls = NewRolls(
      filmStockId: stockId!,
      format: format,
      exposures: int.parse(exposures.text),
      quantity: n,
      price: price.text.isEmpty ? null : int.parse(price.text),
      expiryYear: year.text.isEmpty ? null : int.parse(year.text),
      expiryMonth: month,
    );
    final key = _draftId;
    List<RollSummary>? added;
    final ok = await guard(context, () async {
      try {
        added = await ref
            .read(draftActionsProvider)
            .submit(
              id: key,
              kind: DraftKind.rolls,
              label: '$n × $stockLabel ($format)',
              form: {'request': rolls.toJson(), 'stockLabel': stockLabel},
              send: () =>
                  ref.read(rollActionsProvider).add(rolls, idempotencyKey: key),
            );
      } on DraftIdTaken catch (e) {
        _draftId = e.newId;
        throw draftError(e);
      }
    });
    if (!mounted) return;
    setState(() => busy = false);
    if (!ok) return;
    toast(context, '$n roll${n == 1 ? '' : 's'} added');
    context.closeScreen(added);
  }
}
