import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../domain/models/models.dart';
import '../../../providers.dart';
import '../../core/widgets/common.dart';
import '../../core/widgets/form_kit.dart';
import '../../film/widgets/stock_picker.dart';
import 'roll_form_kit.dart';

/// M-17 add rolls in bulk.
class AddRollsScreen extends ConsumerStatefulWidget {
  const AddRollsScreen({super.key, this.stock});
  final FilmStock? stock;
  @override
  ConsumerState<AddRollsScreen> createState() => _State();
}

class _State extends ConsumerState<AddRollsScreen> {
  final _key = GlobalKey<FormState>();
  late FilmStock? stock = widget.stock;
  int format = 135;
  final exposures = TextEditingController(text: '36');
  final quantity = TextEditingController(text: '1');
  final price = TextEditingController();
  final year = TextEditingController();
  int? month;
  bool busy = false;

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
            LabeledField(
              label: 'Film stock',
              child: SelectField(
                hint: 'Select a film stock',
                value: stock?.label,
                onTap: () async {
                  final s = await pickStock(context, ref, withRollsFirst: true);
                  if (s != null) setState(() => stock = s);
                },
                validator: () => stock == null ? 'Select a film stock' : null,
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
    final body = <String, dynamic>{
      'filmStockId': stock!.id,
      'format': format,
      'exposures': int.parse(exposures.text),
      'quantity': n,
      if (price.text.isNotEmpty) 'price': int.parse(price.text),
      if (year.text.isNotEmpty) 'expiryYear': int.parse(year.text),
      if (year.text.isNotEmpty && month != null) 'expiryMonth': month,
    };
    final ok = await guard(
      context,
      () => ref.read(rollRepositoryProvider).addRolls(body),
    );
    if (!mounted) return;
    setState(() => busy = false);
    if (!ok) return;
    refreshAll(ref);
    toast(context, '$n roll${n == 1 ? '' : 's'} added to stock');
    Navigator.pop(context);
  }
}
