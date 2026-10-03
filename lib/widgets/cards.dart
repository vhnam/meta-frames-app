import 'package:flutter/material.dart';

import '../core/theme.dart';

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
    final lead =
        leading ??
        (icon == null
            ? null
            : Container(
                width: iconSize,
                height: iconSize,
                decoration: BoxDecoration(
                  border: Border.all(
                    color: cs.outlineVariant,
                    width: kHairline,
                  ),
                  color:
                      iconBg ??
                      (iconSize > 40
                          ? cs.primaryContainer
                          : cs.secondaryContainer),
                  borderRadius: kCorners,
                ),
                child: Icon(
                  icon,
                  size: 24,
                  color:
                      iconColor ??
                      (iconSize > 40 ? cs.primary : cs.onSecondaryContainer),
                ),
              ));
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: padding,
        child: Row(
          children: [
            if (lead != null) ...[
              dim ? Opacity(opacity: 0.6, child: lead) : lead,
              SizedBox(width: leading != null ? 10 : 12),
            ],
            Expanded(
              child: Opacity(
                opacity: dim ? 0.7 : 1,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        fontSize: compact ? 14 : 15,
                        fontWeight: FontWeight.w600,
                        color: cs.onSurface,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: monoStyle(
                        letterSpacing: 0.2,
                        fontSize: compact ? 11.5 : 12.5,
                        color: subtitleColor ?? cs.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
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
