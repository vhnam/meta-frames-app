import 'package:flutter/material.dart';

import '../../../domain/models/models.dart';
import '../../core/widgets/cards.dart';
import '../../core/widgets/common.dart';

/// Ticks the order lines a roll is billed on: one roll can be on several, such
/// as developing and scanning. Shows what the ticked lines add up to.
class OrderLinesPicker extends StatelessWidget {
  const OrderLinesPicker({
    super.key,
    required this.lines,
    required this.selected,
    required this.onChanged,
    this.ownLineIds = const [],
    this.error,
  });
  final List<LabOrderLine> lines;
  final List<String> selected;
  final ValueChanged<List<String>> onChanged;

  /// Lines the job is already on: they count as having room for it.
  final List<String> ownLineIds;
  final String? error;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final price = lines
        .where((l) => selected.contains(l.id))
        .fold<int>(0, (sum, l) => sum + l.unitCost);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        CardList(
          children: [
            for (final l in lines)
              CheckboxListTile(
                dense: true,
                controlAffinity: ListTileControlAffinity.leading,
                value: selected.contains(l.id),
                onChanged:
                    l.room <= 0 &&
                        !ownLineIds.contains(l.id) &&
                        !selected.contains(l.id)
                    ? null
                    : (on) => onChanged(
                        on == true
                            ? [...selected, l.id]
                            : [...selected.where((id) => id != l.id)],
                      ),
                title: Text(
                  '${l.product} (${l.jobs.length} of ${l.quantity})',
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                subtitle: Text('${fmtVnd(l.unitCost)} with VAT'),
              ),
            ListTile(
              dense: true,
              title: const Text(
                'Roll price',
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
              ),
              trailing: Text(
                fmtVnd(price),
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  fontFeatures: [FontFeature.tabularFigures()],
                ),
              ),
            ),
          ],
        ),
        if (error != null)
          Padding(
            padding: const EdgeInsets.only(top: 6),
            child: Text(
              error!,
              style: TextStyle(fontSize: 13, color: cs.error),
            ),
          ),
      ],
    );
  }
}
