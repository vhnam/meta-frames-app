import 'package:flutter/material.dart';

import '../theme.dart';

/// Label above a form control, shared by the add/edit forms.
class LabeledField extends StatelessWidget {
  const LabeledField({
    super.key,
    required this.label,
    required this.child,
    this.gapAfter = 16,
  });
  final String label;
  final Widget child;
  final double gapAfter;

  @override
  Widget build(BuildContext context) => Padding(
    padding: EdgeInsets.only(bottom: gapAfter),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 2, bottom: 6),
          child: Text(
            label.toUpperCase(),
            style: monoStyle(
              fontSize: 11.5,
              fontWeight: FontWeight.w600,
              letterSpacing: 1.2,
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
        ),
        child,
      ],
    ),
  );
}

/// Outlined white input used by the add/edit forms.
InputDecoration formInputDecoration(
  String hint,
  ColorScheme cs, {
  Widget? suffixIcon,
}) {
  OutlineInputBorder border(Color c, [double w = kHairline]) =>
      OutlineInputBorder(
        borderRadius: kCorners,
        borderSide: BorderSide(color: c, width: w),
      );
  return InputDecoration(
    hintText: hint,
    hintStyle: TextStyle(color: cs.onSurface.withValues(alpha: 0.5)),
    filled: true,
    fillColor: cs.surface,
    suffixIcon: suffixIcon,
    contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
    border: border(cs.outline),
    enabledBorder: border(cs.outline),
    focusedBorder: border(cs.primary, 1.5),
    errorBorder: border(cs.error),
    focusedErrorBorder: border(cs.error, 1.5),
  );
}

/// Top bar for the add/edit forms. The single save action is [FormSaveBar].
AppBar formAppBar(BuildContext context, String title) =>
    AppBar(title: Text(title));

/// Full-width pill at the bottom of the add/edit forms.
class FormSaveBar extends StatelessWidget {
  const FormSaveBar({
    super.key,
    required this.label,
    required this.busy,
    required this.onPressed,
  });
  final String label;
  final bool busy;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) => FilledButton(
    style: FilledButton.styleFrom(padding: const EdgeInsets.all(16)),
    onPressed: busy ? null : onPressed,
    child: busy
        ? const SizedBox(
            height: 18,
            width: 18,
            child: CircularProgressIndicator(strokeWidth: 2),
          )
        : Text(label),
  );
}

/// Selectable option button (e.g. film format). Selected = tinted + bold rule.
class ChoiceButton extends StatelessWidget {
  const ChoiceButton({
    super.key,
    required this.label,
    required this.selected,
    required this.onTap,
  });
  final String label;
  final bool selected;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Semantics(
      button: true,
      selected: selected,
      child: Opacity(
        opacity: onTap == null && !selected ? 0.5 : 1,
        child: InkWell(
          onTap: onTap,
          borderRadius: kCorners,
          child: Container(
            height: 47,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: selected ? cs.primaryContainer : null,
              borderRadius: kCorners,
              border: Border.all(
                color: selected ? cs.onPrimaryContainer : cs.outline,
                width: selected ? 1.5 : kHairline,
              ),
            ),
            child: Text(
              label,
              style: monoStyle(
                fontSize: 13.5,
                fontWeight: FontWeight.w600,
                letterSpacing: 0.4,
                color: selected ? cs.onPrimaryContainer : cs.onSurface,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Tappable box that looks like a text field: value or hint plus a trailing
/// icon, with an optional validation message below.
class SelectField extends StatelessWidget {
  const SelectField({
    super.key,
    required this.hint,
    required this.value,
    required this.onTap,
    this.onClear,
    this.icon = Icons.keyboard_arrow_down,
    this.validator,
  });
  final String hint;
  final String? value;
  final VoidCallback? onTap;
  final VoidCallback? onClear;
  final IconData icon;
  final String? Function()? validator;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return FormField<String>(
      validator: validator == null ? null : (_) => validator!(),
      builder: (f) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          InkWell(
            onTap: onTap,
            borderRadius: kCorners,
            child: Container(
              height: 47,
              padding: const EdgeInsets.only(left: 14, right: 8),
              decoration: BoxDecoration(
                color: onTap == null ? cs.surfaceContainer : cs.surface,
                borderRadius: kCorners,
                border: Border.all(
                  color: f.hasError ? cs.error : cs.outline,
                  width: kHairline,
                ),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      value ?? hint,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 15,
                        color: value == null
                            ? cs.onSurface.withValues(alpha: 0.5)
                            : cs.onSurface,
                      ),
                    ),
                  ),
                  if (onClear != null && value != null)
                    IconButton(
                      tooltip: 'Clear',
                      icon: const Icon(Icons.close, size: 18),
                      onPressed: onClear,
                    )
                  else
                    Padding(
                      padding: const EdgeInsets.only(right: 6),
                      child: Icon(icon, size: 20, color: cs.onSurfaceVariant),
                    ),
                ],
              ),
            ),
          ),
          if (f.hasError)
            Padding(
              padding: const EdgeInsets.only(left: 12, top: 6),
              child: Text(
                f.errorText!,
                style: TextStyle(color: cs.error, fontSize: 12),
              ),
            ),
        ],
      ),
    );
  }
}

/// Small info line with a leading icon, shown above the save bar.
class FormNote extends StatelessWidget {
  const FormNote(this.text, {super.key});
  final String text;
  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 2),
            child: Icon(
              Icons.info_outline,
              size: 14,
              color: cs.onSurfaceVariant,
            ),
          ),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              text,
              style: TextStyle(
                fontSize: 12,
                height: 1.5,
                color: cs.onSurfaceVariant,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Row of equal-width [ChoiceButton]s for a small enum or list of values.
class ChoiceRow<T> extends StatelessWidget {
  const ChoiceRow({
    super.key,
    required this.values,
    required this.value,
    required this.label,
    required this.onChanged,
  });
  final List<T> values;
  final T value;
  final String Function(T) label;
  final ValueChanged<T> onChanged;

  @override
  Widget build(BuildContext context) => Row(
    spacing: 8,
    children: [
      for (final v in values)
        Expanded(
          child: ChoiceButton(
            label: label(v),
            selected: v == value,
            onTap: () => onChanged(v),
          ),
        ),
    ],
  );
}
