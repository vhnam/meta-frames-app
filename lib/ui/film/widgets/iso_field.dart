import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../domain/models/models.dart';
import '../../core/theme.dart';
import '../../../providers.dart';
import '../../core/widgets/form_kit.dart';

/// Common box speeds offered before any stock uses them.
const _presets = [
  25,
  50,
  64,
  100,
  160,
  200,
  320,
  400,
  500,
  640,
  800,
  1600,
  3200,
];
const _customKey = 'customFilmIsos';

/// Select, type or add a box ISO, like the lens mount field. Speeds already used
/// by a stock show their count; custom ones that nothing uses can be removed.
class IsoField extends ConsumerStatefulWidget {
  const IsoField({super.key, required this.controller});
  final TextEditingController controller;
  @override
  ConsumerState<IsoField> createState() => _State();
}

class _State extends ConsumerState<IsoField> {
  final _focus = FocusNode();

  @override
  void initState() {
    super.initState();
    _focus.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _focus.dispose();
    super.dispose();
  }

  List<int> get _custom => [
    for (final s
        in ref.read(prefsProvider).getStringList(_customKey) ??
            const <String>[])
      if (int.tryParse(s) != null) int.parse(s),
  ];

  Future<void> _setCustom(List<int> v) => ref.read(prefsProvider).setStringList(
    _customKey,
    [for (final i in v) '$i'],
  );

  /// ISO -> number of stocks using it; presets and custom speeds start at 0.
  Map<int, int> _usage() {
    final usage = <int, int>{for (final p in _presets) p: 0};
    for (final c in _custom) {
      usage.putIfAbsent(c, () => 0);
    }
    for (final s in ref.watch(stocksProvider).value ?? const <FilmStock>[]) {
      usage[s.boxIso] = (usage[s.boxIso] ?? 0) + 1;
    }
    return usage;
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final usage = _usage();
    final names = usage.keys.toList()..sort();
    final open = _focus.hasFocus;
    return LayoutBuilder(
      builder: (context, box) => RawAutocomplete<String>(
        textEditingController: widget.controller,
        focusNode: _focus,
        optionsBuilder: (v) {
          final q = v.text.trim();
          final shown = [
            for (final n in names)
              if (q.isEmpty || '$n'.contains(q)) '$n',
          ];
          final n = int.tryParse(q);
          return [...shown, if (n != null && n > 0 && !usage.containsKey(n)) q];
        },
        onSelected: (v) async {
          final n = int.parse(v);
          if (!usage.containsKey(n)) await _setCustom([..._custom, n]);
          widget.controller.text = v;
        },
        fieldViewBuilder: (context, controller, focus, onSubmit) =>
            TextFormField(
              controller: controller,
              focusNode: focus,
              keyboardType: TextInputType.number,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              decoration: formInputDecoration(
                'Select, type or add an ISO',
                cs,
                suffixIcon: IconButton(
                  tooltip: open ? 'Close list' : 'Show ISO list',
                  icon: Icon(
                    open ? Icons.keyboard_arrow_up : Icons.keyboard_arrow_down,
                  ),
                  onPressed: () =>
                      open ? focus.unfocus() : focus.requestFocus(),
                ),
              ),
              validator: (v) {
                final n = int.tryParse(v ?? '');
                return n == null || n <= 0 ? 'Positive whole number' : null;
              },
            ),
        optionsViewBuilder: (context, onSelected, options) => Align(
          alignment: Alignment.topLeft,
          child: Material(
            elevation: 0,
            color: cs.surface,
            shape: RoundedRectangleBorder(
              borderRadius: kCorners,
              side: BorderSide(color: cs.outline, width: kHairline),
            ),
            clipBehavior: Clip.antiAlias,
            child: ConstrainedBox(
              constraints: BoxConstraints(
                maxWidth: box.maxWidth,
                maxHeight: 300,
              ),
              child: SizedBox(
                width: box.maxWidth,
                child: ListView(
                  padding: EdgeInsets.zero,
                  shrinkWrap: true,
                  children: [
                    for (final o in options)
                      _IsoRow(
                        iso: o,
                        isNew: !usage.containsKey(int.parse(o)),
                        uses: usage[int.parse(o)] ?? 0,
                        removable:
                            !_presets.contains(int.parse(o)) &&
                            (usage[int.parse(o)] ?? 0) == 0,
                        onTap: () => onSelected(o),
                        onRemove: () async {
                          await _setCustom(
                            _custom.where((e) => '$e' != o).toList(),
                          );
                          if (mounted) {
                            // Re-run the options builder so the row disappears.
                            final v = widget.controller.value;
                            widget.controller.value = TextEditingValue(
                              text: '${v.text} ',
                            );
                            widget.controller.value = v;
                            setState(() {});
                          }
                        },
                      ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _IsoRow extends StatelessWidget {
  const _IsoRow({
    required this.iso,
    required this.isNew,
    required this.uses,
    required this.removable,
    required this.onTap,
    required this.onRemove,
  });
  final String iso;
  final bool isNew, removable;
  final int uses;
  final VoidCallback onTap, onRemove;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    if (isNew) {
      return InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          child: Row(
            children: [
              Icon(Icons.add, size: 20, color: cs.onPrimaryContainer),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  'Add ISO $iso as a new speed',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w500,
                    color: cs.onPrimaryContainer,
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    }
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          children: [
            Expanded(
              child: Text(
                iso,
                style: TextStyle(fontSize: 15, color: cs.onSurface),
              ),
            ),
            if (uses > 0)
              Text(
                'In use · $uses',
                style: TextStyle(fontSize: 13, color: cs.onSurfaceVariant),
              )
            else if (removable)
              IconButton(
                tooltip: 'Remove ISO',
                visualDensity: VisualDensity.compact,
                icon: Icon(Icons.close, size: 20, color: cs.error),
                onPressed: onRemove,
              ),
          ],
        ),
      ),
    );
  }
}
