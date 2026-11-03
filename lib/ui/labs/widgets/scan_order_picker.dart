import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../domain/models/lab_requests.dart';
import '../../../domain/models/models.dart';
import '../../../routing/routes.dart';
import '../../core/theme.dart';
import '../../scanners/widgets/scan_settings_fields.dart';

/// Picks the scanners of a job, one order per scanner, each with its settings
/// folded away under a one-line summary.
class ScanOrderPicker extends StatefulWidget {
  const ScanOrderPicker({
    super.key,
    required this.orders,
    required this.onChanged,
    required this.scanners,
    required this.kinds,
    required this.offered,
    this.locked = const {},
    this.names = const {},
    this.error,
  });
  final List<ScanOrder> orders;
  final ValueChanged<List<ScanOrder>> onChanged;
  final List<ScannerDevice> scanners;
  final List<ScannerKindOptions> kinds;

  /// Scanners the chosen lab runs; empty offers every scanner.
  final List<String> offered;

  /// Scanners that already have imported scans: they cannot be unticked.
  final Set<String> locked;

  /// Names of scanners on the job, for one missing from [scanners].
  final Map<String, String> names;
  final String? error;

  @override
  State<ScanOrderPicker> createState() => _ScanOrderPickerState();
}

class _ScanOrderPickerState extends State<ScanOrderPicker> {
  bool _showAll = false;
  final _expanded = <String>{};

  ScanOrder? _order(String id) {
    for (final o in widget.orders) {
      if (o.scannerId == id) return o;
    }
    return null;
  }

  /// The lab's scanners in its order, or every scanner, plus any ordered one
  /// not among them.
  List<ScannerDevice> get _rows {
    final byId = {for (final s in widget.scanners) s.id: s};
    final listed = widget.offered.isNotEmpty && !_showAll
        ? [for (final id in widget.offered) ?byId[id]]
        : widget.scanners;
    final known = {for (final s in listed) s.id};
    return [
      ...listed,
      for (final o in widget.orders)
        if (!known.contains(o.scannerId))
          byId[o.scannerId] ?? _missing(o.scannerId),
    ];
  }

  /// A row for a scanner on the job that the list no longer holds.
  ScannerDevice _missing(String id) => ScannerDevice.fromJson({
    'id': id,
    'brand': '',
    'name': widget.names[id] ?? 'Scanner',
    'builtIn': true,
  });

  void _toggle(ScannerDevice s, bool on) => widget.onChanged(
    on
        ? [
            ...widget.orders,
            ScanOrder(
              scannerId: s.id,
              settings: startingSettings(widget.kinds, s),
            ),
          ]
        : widget.orders.where((o) => o.scannerId != s.id).toList(),
  );

  void _setSettings(String id, Map<String, Object?> settings) =>
      widget.onChanged([
        for (final o in widget.orders)
          o.scannerId == id ? ScanOrder(scannerId: id, settings: settings) : o,
      ]);

  /// A scanner added from here is ordered straight away.
  Future<void> _addOwn() async {
    final s = await context.push<ScannerDevice>(Routes.scannerNew);
    if (s != null && mounted && _order(s.id) == null) _toggle(s, true);
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      spacing: 8,
      children: [
        for (final s in _rows) _row(s, cs),
        Wrap(
          spacing: 4,
          children: [
            if (widget.offered.isNotEmpty)
              TextButton(
                onPressed: () => setState(() => _showAll = !_showAll),
                child: Text(
                  _showAll ? 'Only this lab\'s scanners' : 'Show all scanners',
                ),
              ),
            TextButton.icon(
              icon: const Icon(Icons.add, size: 18),
              label: const Text('Add a scanner of your own'),
              onPressed: _addOwn,
            ),
          ],
        ),
        if (widget.locked.isNotEmpty)
          Text(
            'A scanner with imported scans cannot be removed.',
            style: TextStyle(fontSize: 12, color: cs.onSurfaceVariant),
          ),
        if (widget.error != null)
          Text(widget.error!, style: TextStyle(fontSize: 12, color: cs.error)),
      ],
    );
  }

  Widget _row(ScannerDevice s, ColorScheme cs) {
    final order = _order(s.id);
    final options = optionsForKind(widget.kinds, s.kind);
    final open = order != null && _expanded.contains(s.id);
    final locked = widget.locked.contains(s.id);
    return Container(
      decoration: BoxDecoration(
        color: cs.surface,
        borderRadius: kCorners,
        border: Border.all(color: cs.outlineVariant, width: kHairline),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          InkWell(
            onTap: locked ? null : () => _toggle(s, order == null),
            child: Row(
              children: [
                Checkbox(
                  value: order != null,
                  onChanged: locked ? null : (v) => _toggle(s, v ?? false),
                ),
                Expanded(child: Text(s.name, overflow: TextOverflow.ellipsis)),
                if (!s.builtIn)
                  Padding(
                    padding: const EdgeInsets.only(left: 8, right: 12),
                    child: Text(
                      'Yours',
                      style: TextStyle(
                        fontSize: 12,
                        color: cs.onSurfaceVariant,
                      ),
                    ),
                  ),
              ],
            ),
          ),
          if (order != null)
            InkWell(
              onTap: () => setState(
                () => open ? _expanded.remove(s.id) : _expanded.add(s.id),
              ),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(14, 4, 12, 10),
                child: Row(
                  spacing: 8,
                  children: [
                    Icon(Icons.tune, size: 16, color: cs.onSurfaceVariant),
                    Expanded(
                      child: Text(
                        describeSettings(order.settings, options),
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 12,
                          color: cs.onSurfaceVariant,
                        ),
                      ),
                    ),
                    Icon(
                      open ? Icons.expand_less : Icons.expand_more,
                      size: 18,
                      color: cs.onSurfaceVariant,
                    ),
                  ],
                ),
              ),
            ),
          if (open) ...[
            Divider(height: kHairline, color: cs.outlineVariant),
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 12, 12, 0),
              child: ScanSettingsFields(
                options: options,
                settings: order.settings,
                onChanged: (v) => _setSettings(s.id, v),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
