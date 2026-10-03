import 'package:flutter/material.dart';

import '../../widgets/form_kit.dart';

/// Film formats offered by the roll forms; [extra] keeps a saved odd format.
List<int> rollFormats([int? extra]) => [
  135,
  120,
  220,
  110,
  127,
  if (extra != null && ![135, 120, 220, 110, 127].contains(extra)) extra,
];

/// Row of format buttons.
class FormatPicker extends StatelessWidget {
  const FormatPicker({
    super.key,
    required this.value,
    required this.formats,
    required this.onChanged,
  });
  final int value;
  final List<int> formats;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) => Row(
    spacing: 8,
    children: [
      for (final f in formats)
        Expanded(
          child: ChoiceButton(
            label: '$f',
            selected: value == f,
            onTap: () => onChanged(f),
          ),
        ),
    ],
  );
}

const _months = [
  'Jan',
  'Feb',
  'Mar',
  'Apr',
  'May',
  'Jun',
  'Jul',
  'Aug',
  'Sep',
  'Oct',
  'Nov',
  'Dec',
];

/// Expiry month dropdown + year field, side by side.
class ExpiryFields extends StatelessWidget {
  const ExpiryFields({
    super.key,
    required this.year,
    required this.month,
    required this.onMonth,
  });
  final TextEditingController year;
  final int? month;
  final ValueChanged<int?> onMonth;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      spacing: 12,
      children: [
        Expanded(
          child: DropdownButtonFormField<int?>(
            initialValue: month,
            isExpanded: true,
            decoration: formInputDecoration('Month', cs),
            items: [
              const DropdownMenuItem(value: null, child: Text('Unknown')),
              for (var m = 1; m <= 12; m++)
                DropdownMenuItem(value: m, child: Text(_months[m - 1])),
            ],
            onChanged: onMonth,
          ),
        ),
        Expanded(
          child: TextFormField(
            controller: year,
            decoration: formInputDecoration('Year', cs),
            keyboardType: TextInputType.number,
            validator: (v) {
              if (v == null || v.isEmpty) {
                return month != null ? 'Month needs a year' : null;
              }
              final n = int.tryParse(v);
              return n == null || n < 1950 || n > 2100 ? 'Invalid year' : null;
            },
          ),
        ),
      ],
    );
  }
}

String? validPrice(String? v) {
  if (v == null || v.isEmpty) return null;
  final n = int.tryParse(v);
  return n == null || n < 0 ? 'Zero or more' : null;
}

String? validExposures(String? v) =>
    (int.tryParse(v ?? '') ?? 0) < 1 ? 'At least 1' : null;
