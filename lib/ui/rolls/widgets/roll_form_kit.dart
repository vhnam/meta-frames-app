import 'package:flutter/material.dart';

import '../../core/theme.dart';
import '../../core/widgets/form_kit.dart';

/// Film formats offered by the roll forms, matching the dashboard. It also
/// offers 4x5, which the API cannot store because `format` is an integer.
/// [extra] keeps a saved odd format.
List<int> rollFormats([int? extra]) => [
  135,
  120,
  110,
  if (extra != null && ![135, 120, 110].contains(extra)) extra,
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
  'January',
  'February',
  'March',
  'April',
  'May',
  'June',
  'July',
  'August',
  'September',
  'October',
  'November',
  'December',
];

/// Optional expiry: a year field and a month dropdown. Side by side without
/// labels. With labels they stack, as the dashboard does at phone width, so a
/// long label cannot wrap and push one field out of line with the other.
class ExpiryFields extends StatelessWidget {
  const ExpiryFields({
    super.key,
    required this.year,
    required this.month,
    required this.onMonth,
    this.yearLabel,
    this.monthLabel,
    this.yearHint = 'Year',
  });
  final TextEditingController year;
  final int? month;
  final ValueChanged<int?> onMonth;
  final String? yearLabel, monthLabel;
  final String yearHint;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final yearField = TextFormField(
      controller: year,
      decoration: formInputDecoration(yearHint, cs),
      keyboardType: TextInputType.number,
      validator: (v) {
        if (v == null || v.isEmpty) return null;
        final n = int.tryParse(v);
        return n == null || n < 1900 || n > 2100 ? '1900 to 2100' : null;
      },
    );
    // The API stores a month only with a year, so a month waits for one.
    final monthField = ValueListenableBuilder(
      valueListenable: year,
      builder: (context, value, _) {
        final hasYear = value.text.isNotEmpty;
        return DropdownButtonFormField<int?>(
          key: ValueKey(hasYear),
          initialValue: hasYear ? month : null,
          isExpanded: true,
          // A dropdown defaults to a heading style; match the text field.
          style: theme.textTheme.bodyLarge,
          decoration: formInputDecoration('Month', cs),
          items: [
            const DropdownMenuItem(value: null, child: Text('Unknown')),
            for (var m = 1; m <= 12; m++)
              DropdownMenuItem(value: m, child: Text(_months[m - 1])),
          ],
          onChanged: hasYear ? onMonth : null,
        );
      },
    );
    if (yearLabel == null || monthLabel == null) {
      return Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        spacing: 12,
        children: [
          Expanded(child: yearField),
          Expanded(child: monthField),
        ],
      );
    }
    return Column(
      children: [
        LabeledField(label: yearLabel!, child: yearField),
        LabeledField(label: monthLabel!, gapAfter: 0, child: monthField),
      ],
    );
  }
}

/// Small chips that fill a number field with a common value.
class QuickPicks extends StatelessWidget {
  const QuickPicks({super.key, required this.values, required this.controller});
  final List<int> values;
  final TextEditingController controller;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return ValueListenableBuilder(
      valueListenable: controller,
      builder: (context, current, _) => Row(
        spacing: 6,
        children: [
          for (final v in values)
            Builder(
              builder: (context) {
                final on = current.text == '$v';
                return Material(
                  color: on ? cs.primaryContainer : cs.surfaceContainerHigh,
                  borderRadius: BorderRadius.circular(kStampRadius),
                  child: InkWell(
                    borderRadius: BorderRadius.circular(kStampRadius),
                    onTap: () => controller.text = '$v',
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 6,
                      ),
                      child: Text(
                        '$v',
                        style: monoStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          letterSpacing: 0,
                          color: on
                              ? cs.onPrimaryContainer
                              : cs.onSurfaceVariant,
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
        ],
      ),
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
