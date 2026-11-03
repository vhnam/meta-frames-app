import 'package:flutter/material.dart';

import '../../../domain/models/models.dart';
import '../../core/theme.dart';
import '../../core/widgets/form_kit.dart';

/// A field per scan option of a scanner kind, editing a settings map.
class ScanSettingsFields extends StatelessWidget {
  const ScanSettingsFields({
    super.key,
    required this.options,
    required this.settings,
    required this.onChanged,
    this.readOnly = false,
  });
  final List<ScanOption> options;
  final Map<String, Object?> settings;
  final ValueChanged<Map<String, Object?>> onChanged;
  final bool readOnly;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    if (options.isEmpty) {
      return Text(
        'No options for this scanner.',
        style: TextStyle(fontSize: 13, color: cs.onSurfaceVariant),
      );
    }
    final values = completeSettings(options, settings);
    void set(String key, Object? value) => onChanged({...settings, key: value});
    return Column(
      children: [
        for (final o in options)
          switch (o.type) {
            ScanOptionType.boolean => Padding(
              key: ValueKey(o),
              padding: const EdgeInsets.only(bottom: 16),
              child: Row(
                children: [
                  Expanded(child: Text(o.label)),
                  Switch(
                    value: values[o.key] == true,
                    onChanged: readOnly ? null : (v) => set(o.key, v),
                  ),
                ],
              ),
            ),
            ScanOptionType.choice => LabeledField(
              key: ValueKey(o),
              label: o.label,
              child: DropdownButtonFormField<String>(
                initialValue: values[o.key] as String?,
                decoration: formInputDecoration('', cs),
                borderRadius: kCorners,
                items: [
                  for (final c in o.values)
                    DropdownMenuItem(value: c.value, child: Text(c.label)),
                ],
                onChanged: readOnly ? null : (v) => set(o.key, v),
              ),
            ),
            ScanOptionType.integer => LabeledField(
              key: ValueKey(o),
              label: o.label,
              child: TextFormField(
                initialValue: '${values[o.key]}',
                enabled: !readOnly,
                decoration: formInputDecoration('', cs),
                keyboardType: TextInputType.number,
                onChanged: (t) {
                  final n = int.tryParse(t);
                  // A folded field is not validated, so keep only valid values.
                  if (o.allows(n)) set(o.key, n);
                },
                validator: (t) => o.allows(int.tryParse(t ?? ''))
                    ? null
                    : 'Enter ${o.min} to ${o.max}',
              ),
            ),
          },
      ],
    );
  }
}
