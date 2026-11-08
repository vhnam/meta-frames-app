import 'package:flutter/material.dart';

import '../../core/theme.dart';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../data/local/local_store.dart';
import '../../../domain/models/gear_requests.dart';
import '../../../domain/utils.dart';
import '../../sync/view_models/drafts.dart';
import '../../../domain/models/models.dart';
import '../../../providers.dart';
import '../../core/widgets/common.dart';
import '../view_models/gear_actions.dart';
import '../../core/widgets/form_kit.dart';

import '../../../routing/navigation.dart';

String? validFocal(String? v) {
  final n = int.tryParse(v ?? '');
  return n == null || n <= 0 ? 'Positive whole number' : null;
}

String? validAperture(String? v) {
  final n = double.tryParse(v ?? '');
  return n == null || n < 0.1 || n > 99.9
      ? 'Enter 0.1 to 99.9, e.g. 1.4'
      : null;
}

/// Quick add of a lens (picked up mid-trip, or added from Gear or the load
/// screen). It asks only what the server needs: focal length and maximum
/// aperture. Brand, model and mount are optional; [mount] prefills the
/// camera's. Notes and camera links are set on the dashboard. A new lens is
/// kept as a draft until the server confirms it; [draft] reopens one.
class LensFormScreen extends ConsumerStatefulWidget {
  const LensFormScreen({super.key, this.draft, this.mount});
  final Draft? draft;
  final String? mount;
  @override
  ConsumerState<LensFormScreen> createState() => _State();
}

class _State extends ConsumerState<LensFormScreen> {
  final _key = GlobalKey<FormState>();
  late final LensEdit? _restored = widget.draft == null
      ? null
      : LensEdit.fromJson(widget.draft!.json['request']);
  late final brand = TextEditingController(text: _restored?.brand);
  late final model = TextEditingController(text: _restored?.model);
  late final mount = TextEditingController(
    text: _restored?.mount ?? widget.mount,
  );
  late final focal = TextEditingController(
    text: _restored?.focalLength.toString(),
  );
  late final aperture = TextEditingController(
    text: _restored?.maxAperture.toStringAsFixed(1),
  );
  bool busy = false;

  /// The new lens's client id, kept with its draft.
  late String _draftId = widget.draft?.id ?? newId();
  String? _t(TextEditingController c) =>
      c.text.trim().isEmpty ? null : c.text.trim();

  static String _norm(String? m) => (m ?? '').trim().toLowerCase();

  @override
  void initState() {
    super.initState();
    _mountFocus.addListener(() => setState(() {}));
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Scaffold(
      backgroundColor: cs.surfaceContainerLow,
      appBar: formAppBar(context, 'New Lens'),
      body: Form(
        key: _key,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            if (widget.draft?.error case final e?) WarningBanner([e]),
            LabeledField(
              label: 'Brand (optional)',
              child: TextFormField(
                controller: brand,
                decoration: formInputDecoration('e.g. Nikkor', cs),
                textCapitalization: TextCapitalization.words,
              ),
            ),
            LabeledField(
              label: 'Model (optional)',
              child: TextFormField(
                controller: model,
                decoration: formInputDecoration('e.g. 50mm f/1.4 AI-S', cs),
              ),
            ),
            Padding(
              padding: const EdgeInsets.only(bottom: 16),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: LabeledField(
                      label: 'Focal length (mm)',
                      gapAfter: 0,
                      child: TextFormField(
                        controller: focal,
                        decoration: formInputDecoration('50', cs),
                        keyboardType: TextInputType.number,
                        validator: validFocal,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: LabeledField(
                      label: 'Max aperture (f/)',
                      gapAfter: 0,
                      child: TextFormField(
                        controller: aperture,
                        decoration: formInputDecoration('1.4', cs),
                        keyboardType: const TextInputType.numberWithOptions(
                          decimal: true,
                        ),
                        validator: validAperture,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            _mountField(cs),
            const FormNote('Notes and camera links can be added later.'),
            const SizedBox(height: 16),
            FormSaveBar(label: 'Add lens', busy: busy, onPressed: _save),
          ],
        ),
      ),
    );
  }

  static const _customKey = 'customLensMounts';
  final _mountFocus = FocusNode();

  @override
  void dispose() {
    _mountFocus.dispose();
    super.dispose();
  }

  List<String> get _customMounts =>
      ref.read(prefsProvider).getStringList(_customKey) ?? const [];

  Future<void> _setCustomMounts(List<String> v) =>
      ref.read(prefsProvider).setStringList(_customKey, v);

  /// Mount -> number of lenses and cameras using it; custom mounts start at 0.
  Map<String, int> _mountUsage() {
    final usage = <String, int>{};
    String? key(String? m) => (m ?? '').trim().isEmpty ? null : m!.trim();
    void add(String? m) {
      final k = key(m);
      if (k == null) return;
      final existing = usage.keys.firstWhere(
        (e) => _norm(e) == _norm(k),
        orElse: () => k,
      );
      usage[existing] = (usage[existing] ?? 0) + 1;
    }

    for (final l in ref.watch(lensesProvider).value ?? const <Lens>[]) {
      if (!l.isBuiltIn) add(l.mount);
    }
    for (final c in ref.watch(camerasProvider).value ?? const <Camera>[]) {
      if (!c.hasFixedLens) add(c.mount);
    }
    for (final m in _customMounts) {
      if (!usage.keys.any((e) => _norm(e) == _norm(m))) usage[m] = 0;
    }
    return usage;
  }

  /// Select, type or add a mount; unused custom mounts can be removed.
  Widget _mountField(ColorScheme cs) {
    final usage = _mountUsage();
    final names = usage.keys.toList()
      ..sort(
        (a, b) =>
            usage[b]! != usage[a]! ? usage[b]! - usage[a]! : a.compareTo(b),
      );
    final open = _mountFocus.hasFocus;
    return LabeledField(
      label: 'Lens mount',
      child: LayoutBuilder(
        builder: (context, box) => RawAutocomplete<String>(
          textEditingController: mount,
          focusNode: _mountFocus,
          optionsBuilder: (v) {
            final q = _norm(v.text);
            final shown = names
                .where((n) => q.isEmpty || _norm(n).contains(q))
                .toList();
            final exact = names.any((n) => _norm(n) == q);
            return [...shown, if (q.isNotEmpty && !exact) v.text.trim()];
          },
          onSelected: (m) async {
            if (!usage.keys.any((e) => _norm(e) == _norm(m))) {
              await _setCustomMounts([..._customMounts, m]);
            }
            mount.text = m;
          },
          fieldViewBuilder: (context, controller, focus, onSubmit) =>
              TextFormField(
                controller: controller,
                focusNode: focus,
                decoration: formInputDecoration(
                  'Select, type or add a mount',
                  cs,
                  suffixIcon: IconButton(
                    icon: Icon(
                      open
                          ? Icons.keyboard_arrow_up
                          : Icons.keyboard_arrow_down,
                    ),
                    onPressed: () =>
                        open ? focus.unfocus() : focus.requestFocus(),
                  ),
                ),
              ),
          optionsViewBuilder: (context, onSelected, options) => Align(
            alignment: Alignment.topLeft,
            child: Material(
              elevation: 4,
              color: cs.surface,
              borderRadius: kCorners,
              clipBehavior: Clip.antiAlias,
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  maxWidth: box.maxWidth,
                  maxHeight: 340,
                ),
                child: SizedBox(
                  width: box.maxWidth,
                  child: ListView(
                    padding: EdgeInsets.zero,
                    shrinkWrap: true,
                    children: [
                      for (final o in options)
                        _MountRow(
                          name: o,
                          isNew: !usage.keys.any((e) => _norm(e) == _norm(o)),
                          uses:
                              usage[usage.keys.firstWhere(
                                (e) => _norm(e) == _norm(o),
                                orElse: () => '',
                              )] ??
                              0,
                          onTap: () => onSelected(o),
                          onRemove: () async {
                            await _setCustomMounts(
                              _customMounts
                                  .where((m) => _norm(m) != _norm(o))
                                  .toList(),
                            );
                            if (mounted) {
                              // Re-run the options builder so the row disappears.
                              final v = mount.value;
                              mount.value = TextEditingValue(
                                text: '${v.text} ',
                              );
                              mount.value = v;
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
      ),
    );
  }

  Future<void> _save() async {
    if (!_key.currentState!.validate()) return;
    setState(() => busy = true);
    final lens = LensEdit(
      brand: _t(brand),
      model: _t(model),
      mount: _t(mount),
      focalLength: int.parse(focal.text),
      maxAperture: double.parse(double.parse(aperture.text).toStringAsFixed(1)),
    );
    Lens? saved;
    final actions = ref.read(lensActionsProvider);
    final id = _draftId;
    final ok = await guard(context, () async {
      try {
        saved = await ref
            .read(draftActionsProvider)
            .submit(
              id: id,
              kind: DraftKind.lens,
              label: [
                ?lens.brand,
                ?lens.model,
                '${lens.focalLength}mm f/${lens.maxAperture}',
              ].join(' '),
              form: {'request': lens.toJson()},
              send: () => actions.save(lens, id: id),
              readBack: () => actions.landed(id, lens),
            );
      } on DraftIdTaken catch (e) {
        _draftId = e.newId;
        throw draftError(e);
      }
    });
    if (!mounted) return;
    setState(() => busy = false);
    if (!ok) return;
    context.closeScreen(saved);
  }
}

class _MountRow extends StatelessWidget {
  const _MountRow({
    required this.name,
    required this.isNew,
    required this.uses,
    required this.onTap,
    required this.onRemove,
  });
  final String name;
  final bool isNew;
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
                  'Add “$name” as a new mount',
                  style: TextStyle(
                    fontSize: 16,
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
                name,
                style: TextStyle(fontSize: 16, color: cs.onSurface),
              ),
            ),
            if (uses > 0)
              Text(
                'In use · $uses',
                style: TextStyle(fontSize: 13, color: cs.onSurfaceVariant),
              )
            else
              IconButton(
                tooltip: 'Remove mount',
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
