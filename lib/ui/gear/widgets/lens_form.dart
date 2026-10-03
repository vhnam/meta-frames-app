import 'package:flutter/material.dart';

import '../../core/theme.dart';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../domain/models/gear_requests.dart';
import '../../../domain/models/models.dart';
import '../../../providers.dart';
import '../../core/widgets/cards.dart';
import '../../core/widgets/common.dart';
import '../view_models/gear_actions.dart';
import '../../core/widgets/form_kit.dart';

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

/// M-06 add lens, M-07 edit lens.
/// Cameras sharing the mount are linked inline instead of in a follow-up dialog.
class LensFormScreen extends ConsumerStatefulWidget {
  const LensFormScreen({super.key, this.lens});
  final Lens? lens;
  @override
  ConsumerState<LensFormScreen> createState() => _State();
}

class _State extends ConsumerState<LensFormScreen> {
  final _key = GlobalKey<FormState>();
  late final brand = TextEditingController(text: widget.lens?.brand);
  late final model = TextEditingController(text: widget.lens?.model);
  late final mount = TextEditingController(text: widget.lens?.mount);
  late final desc = TextEditingController(text: widget.lens?.description);
  late final focal = TextEditingController(
    text: widget.lens?.focalLength.toString(),
  );
  late final aperture = TextEditingController(
    text: widget.lens?.maxAperture.toStringAsFixed(1),
  );
  bool busy = false;

  /// Cameras the lens is linked to; null while loading when editing.
  Set<String>? linked;
  Set<String>? _initialLinked;

  bool get editing => widget.lens != null;
  bool get builtIn => widget.lens?.isBuiltIn ?? false;

  String? _t(TextEditingController c) =>
      c.text.trim().isEmpty ? null : c.text.trim();

  static String _norm(String? m) => (m ?? '').trim().toLowerCase();

  @override
  void initState() {
    super.initState();
    mount.addListener(() => setState(() {}));
    _mountFocus.addListener(() => setState(() {}));
    if (editing && !builtIn) {
      _loadLinked();
    } else {
      linked = {};
    }
  }

  /// Cameras currently linked to the lens, derived from each camera's links.
  Future<void> _loadLinked() async {
    try {
      final cams = await ref.read(lensCamerasProvider(widget.lens!.id).future);
      final ids = {
        for (final c in cams)
          if (!c.hasFixedLens) c.id,
      };
      if (!mounted) return;
      setState(() {
        _initialLinked = {...ids};
        linked = ids;
      });
    } catch (_) {
      if (mounted) setState(() => linked = {});
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Scaffold(
      backgroundColor: cs.surfaceContainerLow,
      appBar: formAppBar(context, editing ? 'Edit Lens' : 'New Lens'),
      body: Form(
        key: _key,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            LabeledField(
              label: builtIn ? 'Brand (optional)' : 'Brand',
              child: TextFormField(
                controller: brand,
                decoration: formInputDecoration('e.g. Nikkor', cs),
                textCapitalization: TextCapitalization.words,
                validator: (v) => !builtIn && (v == null || v.trim().isEmpty)
                    ? 'Required'
                    : null,
              ),
            ),
            LabeledField(
              label: builtIn ? 'Model (optional)' : 'Model',
              child: TextFormField(
                controller: model,
                decoration: formInputDecoration('e.g. 50mm f/1.4 AI-S', cs),
                validator: (v) => !builtIn && (v == null || v.trim().isEmpty)
                    ? 'Required'
                    : null,
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
            if (!builtIn) _mountField(cs),
            LabeledField(
              label: 'Notes (optional)',
              child: TextFormField(
                controller: desc,
                decoration: formInputDecoration(
                  'Serial number, condition, quirks…',
                  cs,
                ),
                minLines: 4,
                maxLines: 4,
              ),
            ),
            if (!builtIn) _linkedCameras(cs),
            const SizedBox(height: 16),
            FormSaveBar(
              label: editing ? 'Save changes' : 'Add lens',
              busy: busy,
              onPressed: _save,
            ),
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
                validator: (v) =>
                    v == null || v.trim().isEmpty ? 'Required' : null,
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

  List<Camera> _compatibleCameras() {
    final m = _norm(mount.text);
    if (m.isEmpty) return const [];
    return (ref.watch(camerasProvider).value ?? const <Camera>[])
        .where((c) => c.isActive && !c.hasFixedLens && _norm(c.mount) == m)
        .toList();
  }

  Widget _linkedCameras(ColorScheme cs) {
    final cams = _compatibleCameras();
    final sel = linked;
    Widget hint(String t) => Padding(
      padding: const EdgeInsets.fromLTRB(2, 10, 2, 0),
      child: Text(
        t,
        style: TextStyle(fontSize: 13, color: cs.onSurfaceVariant),
      ),
    );
    Widget body;
    if (mount.text.trim().isEmpty) {
      body = hint('Enter a mount to see compatible cameras.');
    } else if (cams.isEmpty) {
      body = hint('No cameras with a ${mount.text.trim()} mount yet.');
    } else if (sel == null) {
      body = const Padding(
        padding: EdgeInsets.only(top: 10),
        child: LinearProgressIndicator(),
      );
    } else {
      body = Padding(
        padding: const EdgeInsets.only(top: 8),
        child: CardList(
          children: [
            for (final c in cams)
              CardTile(
                compact: true,
                leading: Checkbox(
                  value: sel.contains(c.id),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(kStampRadius),
                  ),
                  onChanged: (v) => _toggle(c.id, v ?? false),
                ),
                title: c.name,
                subtitle: '${c.mount} mount',
                onTap: () => _toggle(c.id, !sel.contains(c.id)),
              ),
          ],
        ),
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'LINKED TO CAMERAS',
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            letterSpacing: 0.96,
            color: cs.onSurfaceVariant,
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(2, 4, 2, 0),
          child: Text(
            'One lens can be linked to many cameras that share its mount.',
            style: TextStyle(fontSize: 12, color: cs.onSurfaceVariant),
          ),
        ),
        body,
      ],
    );
  }

  void _toggle(String id, bool on) =>
      setState(() => on ? linked!.add(id) : linked!.remove(id));

  Future<void> _save() async {
    if (!_key.currentState!.validate()) return;
    setState(() => busy = true);
    final lens = LensEdit(
      brand: _t(brand),
      model: _t(model),
      mount: builtIn ? null : _t(mount),
      description: _t(desc),
      focalLength: int.parse(focal.text),
      maxAperture: double.parse(double.parse(aperture.text).toStringAsFixed(1)),
    );
    Lens? saved;
    final ok = await guard(context, () async {
      saved = await ref
          .read(lensActionsProvider)
          .save(
            lens,
            existing: widget.lens,
            // Only touch cameras the user could see; add or remove this lens.
            links: builtIn || linked == null
                ? null
                : LensLinks(
                    cameras: _compatibleCameras(),
                    wanted: linked!,
                    initial: _initialLinked ?? const {},
                  ),
          );
    });
    if (!mounted) return;
    setState(() => busy = false);
    if (!ok) return;
    Navigator.pop(context, saved);
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
