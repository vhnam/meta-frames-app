import 'dart:ui' show PathMetric;

import 'package:flutter/material.dart';

import '../theme.dart';

/// Rounded surface holding tiles; tiles are separate cards when [gap] > 0,
/// otherwise rows divided inside one card.
class CardList extends StatelessWidget {
  const CardList({
    super.key,
    required this.children,
    this.gap = 0,
    this.outline,
  });
  final List<Widget> children;
  final double gap;
  final Color? outline;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    Widget card(Widget child) => Material(
      color: cs.surfaceContainerLow,
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(
        borderRadius: kCorners,
        side: BorderSide(color: outline ?? cs.outlineVariant, width: kHairline),
      ),
      child: child,
    );
    if (gap > 0) {
      return Column(
        children: [
          for (var i = 0; i < children.length; i++) ...[
            if (i > 0) SizedBox(height: gap),
            SizedBox(width: double.infinity, child: card(children[i])),
          ],
        ],
      );
    }
    return SizedBox(
      width: double.infinity,
      child: card(
        Column(
          children: [
            for (var i = 0; i < children.length; i++) ...[
              if (i > 0)
                Divider(
                  height: kHairline,
                  thickness: kHairline,
                  color: cs.outlineVariant,
                ),
              children[i],
            ],
          ],
        ),
      ),
    );
  }
}

class CardTile extends StatelessWidget {
  const CardTile({
    super.key,
    required this.title,
    required this.subtitle,
    this.icon,
    this.leading,
    this.iconSize = 36,
    this.iconBg,
    this.iconColor,
    this.subtitleColor,
    this.badge,
    this.trailing,
    this.compact = false,
    this.dim = false,
    this.padding = const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
    this.onTap,
  });
  final String title, subtitle;
  final IconData? icon;
  final Widget? leading, badge, trailing;
  final double iconSize;
  final Color? iconBg, iconColor, subtitleColor;
  final bool compact;

  /// Faded look for inactive items: icon at 60%, text at 70%.
  final bool dim;
  final EdgeInsets padding;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    // Fade through colour alpha: Opacity would force an offscreen layer per row.
    Color fade(Color c, double a) => dim ? c.withValues(alpha: c.a * a) : c;
    final lead =
        leading ??
        (icon == null
            ? null
            : Container(
                width: iconSize,
                height: iconSize,
                decoration: BoxDecoration(
                  border: Border.all(
                    color: fade(cs.outlineVariant, 0.6),
                    width: kHairline,
                  ),
                  color: fade(
                    iconBg ??
                        (iconSize > 40
                            ? cs.primaryContainer
                            : cs.secondaryContainer),
                    0.6,
                  ),
                  borderRadius: kCorners,
                ),
                child: Icon(
                  icon,
                  size: 24,
                  color: fade(
                    iconColor ??
                        (iconSize > 40 ? cs.primary : cs.onSecondaryContainer),
                    0.6,
                  ),
                ),
              ));
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: padding,
        child: Row(
          children: [
            if (lead != null) ...[
              dim && leading != null
                  ? Opacity(opacity: 0.6, child: lead)
                  : lead,
              SizedBox(width: leading != null ? 10 : 12),
            ],
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: compact ? 14 : 15,
                      fontWeight: FontWeight.w600,
                      color: fade(cs.onSurface, 0.7),
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: monoStyle(
                      letterSpacing: 0.2,
                      fontSize: compact ? 11.5 : 12.5,
                      color: fade(subtitleColor ?? cs.onSurfaceVariant, 0.7),
                    ),
                  ),
                ],
              ),
            ),
            if (badge != null) ...[const SizedBox(width: 12), badge!],
            if (trailing != null) ...[const SizedBox(width: 12), trailing!],
          ],
        ),
      ),
    );
  }
}

/// Mono uppercase label above a group of cards.
class SectionLabel extends StatelessWidget {
  const SectionLabel(this.text, {super.key});
  final String text;

  @override
  Widget build(BuildContext context) => Text(
    text.toUpperCase(),
    style: monoStyle(
      fontWeight: FontWeight.w600,
      letterSpacing: 1.6,
      color: Theme.of(context).colorScheme.onSurfaceVariant,
    ),
  );
}

/// Bordered card for a list with nothing in it: icon, title, one explanation.
class EmptyCard extends StatelessWidget {
  const EmptyCard({
    super.key,
    required this.icon,
    required this.title,
    required this.text,
  });
  final IconData icon;
  final String title, text;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
      decoration: BoxDecoration(
        borderRadius: kCorners,
        border: Border.all(color: cs.outline, width: kHairline),
      ),
      child: Column(
        children: [
          Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              color: cs.surfaceContainer,
              borderRadius: kCorners,
            ),
            child: Icon(icon, size: 24, color: cs.onSurfaceVariant),
          ),
          const SizedBox(height: 12),
          Text(
            title,
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w500,
              color: cs.onSurface,
            ),
          ),
          const SizedBox(height: 10),
          SizedBox(
            width: 240,
            child: Text(
              text,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 13,
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

/// Full-width segmented switch under a screen header (Cameras / Lenses).
class SegmentSwitcher extends StatelessWidget {
  const SegmentSwitcher({
    super.key,
    required this.labels,
    required this.selected,
    required this.onChanged,
  });
  final List<String> labels;
  final int selected;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    Widget seg(int i) {
      final on = selected == i;
      return Expanded(
        child: Semantics(
          button: true,
          selected: on,
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: () => onChanged(i),
            child: Container(
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: on ? cs.surface : null,
                borderRadius: kCorners,
                border: on
                    ? Border.all(color: cs.outline, width: kHairline)
                    : null,
              ),
              child: Text(
                labels[i],
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: on ? FontWeight.w600 : FontWeight.w400,
                  color: on ? cs.onSurface : cs.onSurfaceVariant,
                ),
              ),
            ),
          ),
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(color: cs.outlineVariant, width: 0.65),
        ),
      ),
      child: Container(
        height: 45,
        padding: const EdgeInsets.all(4),
        decoration: BoxDecoration(
          color: cs.surfaceContainerHighest,
          borderRadius: kCorners,
        ),
        child: Row(
          children: [
            for (var i = 0; i < labels.length; i++) ...[
              if (i > 0) const SizedBox(width: 2),
              seg(i),
            ],
          ],
        ),
      ),
    );
  }
}

/// Mono pill used for filters and status chips.
class FilterPill extends StatelessWidget {
  const FilterPill({
    super.key,
    required this.label,
    required this.on,
    this.onTap,
  });
  final String label;
  final bool on;

  /// Null when the pill only decorates a control that handles the tap, such as
  /// a popup menu.
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final color = on ? cs.onPrimaryContainer : cs.onSurfaceVariant;
    return Semantics(
      button: true,
      selected: on,
      child: InkWell(
        borderRadius: kCorners,
        onTap: onTap,
        child: Container(
          constraints: const BoxConstraints(minHeight: 40),
          padding: const EdgeInsets.symmetric(horizontal: 14),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: on ? cs.primaryContainer : null,
            borderRadius: kCorners,
            border: Border.all(
              color: on ? cs.onPrimaryContainer : cs.outlineVariant,
              width: kHairline,
            ),
          ),
          child: Text(
            label.toUpperCase(),
            style: monoStyle(
              fontSize: 11.5,
              fontWeight: on ? FontWeight.w700 : FontWeight.w500,
              letterSpacing: 1.0,
              color: color,
            ),
          ),
        ),
      ),
    );
  }
}

/// Mono uppercase label above a card on a detail screen, with an optional
/// trailing action.
class DetailLabel extends StatelessWidget {
  const DetailLabel(this.text, {super.key, this.top = 20, this.trailing});
  final String text;
  final double top;
  final Widget? trailing;
  @override
  Widget build(BuildContext context) => Padding(
    padding: EdgeInsets.fromLTRB(0, top, 0, trailing == null ? 8 : 0),
    child: Row(
      children: [
        Expanded(child: SectionLabel(text)),
        ?trailing,
      ],
    ),
  );
}

/// Label on the left, value on the right; a row inside a [CardList].
class DetailInfoRow extends StatelessWidget {
  const DetailInfoRow(this.label, this.value, {super.key, this.bold = false});
  final String label;
  final String? value;
  final bool bold;
  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final v = value == null || value!.isEmpty ? '—' : value!;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 11),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: TextStyle(fontSize: 14, color: cs.onSurfaceVariant),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Text(
              v,
              textAlign: TextAlign.end,
              style: TextStyle(
                fontSize: 14,
                fontWeight: bold ? FontWeight.w700 : FontWeight.w500,
                color: cs.onSurface,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Full-width text action row inside a [CardList] (Deactivate, Delete).
class DetailActionRow extends StatelessWidget {
  const DetailActionRow({
    super.key,
    required this.label,
    required this.color,
    required this.onTap,
  });
  final String label;
  final Color color;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) => InkWell(
    onTap: onTap,
    child: Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 15,
          fontWeight: FontWeight.w500,
          color: color,
        ),
      ),
    ),
  );
}

/// Full-width dashed outline button for a secondary add action.
class DashedButton extends StatelessWidget {
  const DashedButton({super.key, required this.label, required this.onTap});
  final String label;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return CustomPaint(
      painter: _DashedBorder(cs.outline),
      child: InkWell(
        onTap: onTap,
        borderRadius: kCorners,
        child: Container(
          height: 41,
          alignment: Alignment.center,
          child: Text(
            label,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w500,
              color: cs.onPrimaryContainer,
            ),
          ),
        ),
      ),
    );
  }
}

class _DashedBorder extends CustomPainter {
  _DashedBorder(this.color);
  final Color color;
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;
    final path = Path()
      ..addRRect(
        RRect.fromRectAndRadius(Offset.zero & size, const Radius.circular(12)),
      );
    for (final PathMetric m in path.computeMetrics()) {
      for (var d = 0.0; d < m.length; d += 7) {
        canvas.drawPath(m.extractPath(d, d + 4), paint);
      }
    }
  }

  @override
  bool shouldRepaint(_DashedBorder old) => old.color != color;
}
