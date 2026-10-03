import 'package:flutter/material.dart';

import '../../core/theme.dart';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../domain/models/gear_requests.dart';
import '../../../domain/models/models.dart';
import '../../../domain/models/roll_filter.dart';
import '../../../providers.dart';
import '../../core/widgets/cards.dart';
import '../../core/widgets/common.dart';
import '../view_models/gear_actions.dart';
import '../../core/widgets/form_kit.dart';
import 'lens_form.dart';

/// M-02 add camera, M-03 fixed-lens camera, M-04 edit camera.
/// Linked lenses are picked inline instead of on a follow-up screen.
class CameraFormScreen extends ConsumerStatefulWidget {
  const CameraFormScreen({super.key, this.camera});
  final Camera? camera;
  @override
  ConsumerState<CameraFormScreen> createState() => _State();
}

class _State extends ConsumerState<CameraFormScreen> {
  final _key = GlobalKey<FormState>();
  late final brand = TextEditingController(text: widget.camera?.brand);
  late final model = TextEditingController(text: widget.camera?.model);
  late final mount = TextEditingController(text: widget.camera?.mount);
  late final desc = TextEditingController(text: widget.camera?.description);
  final lensFocal = TextEditingController();
  final lensAperture = TextEditingController();
  final lensName = TextEditingController();
  late bool fixed = widget.camera?.hasFixedLens ?? false;
  bool busy = false;
  Set<String>? selected;

  @override
  void initState() {
    super.initState();
    mount.addListener(() => setState(() {}));
  }

  bool get editing => widget.camera != null;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    // M-04: fixed-lens flag locked once the camera has rolls.
    final hasRolls = editing
        ? ref
                  .watch(rollsProvider(RollFilter(cameraId: widget.camera!.id)))
                  .value
                  ?.isNotEmpty ??
              true
        : false;
    final typeLocked = editing || hasRolls;
    final saveLabel = editing ? 'Save changes' : 'Add camera';
    return Scaffold(
      backgroundColor: cs.surfaceContainerLow,
      appBar: formAppBar(context, editing ? 'Edit Camera' : 'New Camera'),
      body: Form(
        key: _key,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            LabeledField(
              label: 'Brand',
              child: TextFormField(
                controller: brand,
                decoration: formInputDecoration('e.g. Nikon', cs),
                textCapitalization: TextCapitalization.words,
                validator: _required,
              ),
            ),
            LabeledField(
              label: 'Model',
              child: TextFormField(
                controller: model,
                decoration: formInputDecoration('e.g. FM2', cs),
                validator: _required,
              ),
            ),
            LabeledField(
              label: 'Lens type',
              gapAfter: 16,
              child: Row(
                children: [
                  Expanded(
                    child: _TypeButton(
                      label: 'Interchangeable',
                      selected: !fixed,
                      onTap: typeLocked
                          ? null
                          : () => setState(() => fixed = false),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _TypeButton(
                      label: 'Fixed lens',
                      selected: fixed,
                      onTap: typeLocked
                          ? null
                          : () => setState(() => fixed = true),
                    ),
                  ),
                ],
              ),
            ),
            if (hasRolls && editing)
              Padding(
                padding: const EdgeInsets.only(bottom: 16),
                child: Text(
                  'Lens type is locked: this camera already has rolls.',
                  style: TextStyle(fontSize: 12, color: cs.onSurfaceVariant),
                ),
              ),
            if (fixed && !editing)
              LabeledField(
                label: 'Lens name (optional)',
                child: TextFormField(
                  controller: lensName,
                  decoration: formInputDecoration('e.g. Zuiko 35mm f/2.8', cs),
                ),
              ),
            if (fixed && !editing)
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
                          controller: lensFocal,
                          decoration: formInputDecoration('35', cs),
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
                          controller: lensAperture,
                          decoration: formInputDecoration('2.8', cs),
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
            if (!fixed) _mountField(cs),
            LabeledField(
              label: 'Notes (optional)',
              child: TextFormField(
                controller: desc,
                decoration: formInputDecoration(
                  'Serial number, condition, where you got it…',
                  cs,
                ),
                minLines: 4,
                maxLines: 4,
              ),
            ),
            if (!fixed) _linkedLenses(cs) else _fixedInfo(cs),
            const SizedBox(height: 16),
            FilledButton(
              style: FilledButton.styleFrom(
                padding: const EdgeInsets.all(14),
                textStyle: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                ),
              ),
              onPressed: busy ? null : _save,
              child: busy
                  ? const SizedBox(
                      height: 18,
                      width: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : Text(saveLabel),
            ),
          ],
        ),
      ),
    );
  }

  /// Mounts come from the lens inventory; with no lenses, guide to add one first.
  List<String>? _mountOptions() {
    final lenses = ref.watch(lensesProvider);
    if (!lenses.hasValue) return null;
    final mounts = <String>{
      for (final l in lenses.requireValue)
        if (l.isActive && !l.isBuiltIn && (l.mount ?? '').trim().isNotEmpty)
          l.mount!.trim(),
      // Keep the saved mount selectable even if its lenses are gone or inactive.
      if (mount.text.trim().isNotEmpty) mount.text.trim(),
    }.toList()..sort();
    return mounts;
  }

  Widget _mountField(ColorScheme cs) {
    final options = _mountOptions();
    if (options == null) {
      return const Padding(
        padding: EdgeInsets.only(bottom: 16),
        child: LinearProgressIndicator(),
      );
    }
    if (options.isEmpty) {
      return LabeledField(
        label: 'Lens mount',
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: cs.primaryContainer,
            borderRadius: kCorners,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Camera mounts come from your lens inventory, and you don’t have any lenses yet. Add a lens first, then come back to add this camera.',
                style: TextStyle(
                  fontSize: 14,
                  height: 1.45,
                  color: cs.onPrimaryContainer,
                ),
              ),
              const SizedBox(height: 10),
              FilledButton(
                style: FilledButton.styleFrom(
                  minimumSize: Size.zero,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 18,
                    vertical: 8,
                  ),
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  textStyle: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                onPressed: () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const LensFormScreen()),
                ),
                child: const Text('Add a lens first'),
              ),
            ],
          ),
        ),
      );
    }
    final current = mount.text.trim();
    return LabeledField(
      label: 'Lens mount',
      child: DropdownButtonFormField<String>(
        initialValue: options.contains(current) ? current : null,
        decoration: formInputDecoration('Select a mount', cs),
        borderRadius: kCorners,
        items: [
          for (final m in options) DropdownMenuItem(value: m, child: Text(m)),
        ],
        onChanged: (v) => setState(() {
          mount.text = v ?? '';
          // Linked lenses depend on the mount.
          selected = editing ? selected : {};
        }),
        validator: (v) =>
            v == null ? 'Required for interchangeable lens' : null,
      ),
    );
  }

  Widget _fixedInfo(ColorScheme cs) => Row(
    children: [
      Icon(Icons.info, size: 16, color: cs.onSurfaceVariant),
      const SizedBox(width: 4),
      Expanded(
        child: Text(
          'A built-in lens is created and kept in sync with this camera.',
          style: TextStyle(fontSize: 12, color: cs.onSurfaceVariant),
        ),
      ),
    ],
  );

  Widget _linkedLenses(ColorScheme cs) {
    final m = mount.text.trim().toLowerCase();
    final label = Text(
      'LINKED LENSES',
      style: TextStyle(
        fontSize: 12,
        fontWeight: FontWeight.w600,
        letterSpacing: 0.96,
        color: cs.onSurfaceVariant,
      ),
    );
    if (editing) {
      selected ??= ref
          .watch(cameraLensesProvider(widget.camera!.id))
          .value
          ?.map((l) => l.id)
          .toSet();
    } else {
      selected ??= {};
    }
    final sel = selected;
    final lenses =
        (ref.watch(lensesProvider).value ?? const <Lens>[])
            .where(
              (l) =>
                  l.isActive &&
                  !l.isBuiltIn &&
                  m.isNotEmpty &&
                  (l.mount ?? '').trim().toLowerCase() == m,
            )
            .toList()
          ..sort((a, b) => a.focalLength - b.focalLength);
    Widget body;
    if (m.isEmpty) {
      body = _hint('Enter a mount to see compatible lenses.', cs);
    } else if (lenses.isEmpty) {
      body = _hint('No lenses with this mount yet.', cs);
    } else if (sel == null) {
      body = const LinearProgressIndicator();
    } else {
      body = CardList(
        children: [
          for (final l in lenses)
            CardTile(
              compact: true,
              leading: Checkbox(
                value: sel.contains(l.id),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(kStampRadius),
                ),
                onChanged: (v) => _toggle(l.id, v ?? false),
              ),
              title:
                  [
                    l.brand,
                    l.model,
                  ].where((e) => e != null && e.isNotEmpty).join(' ').isEmpty
                  ? l.name
                  : [
                      l.brand,
                      l.model,
                    ].where((e) => e != null && e.isNotEmpty).join(' '),
              subtitle:
                  '${l.focalLength}mm · f/${l.maxAperture.toStringAsFixed(l.maxAperture % 1 == 0 ? 0 : 1)}',
              onTap: () => _toggle(l.id, !sel.contains(l.id)),
            ),
        ],
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [label, const SizedBox(height: 8), body],
    );
  }

  Widget _hint(String text, ColorScheme cs) => Padding(
    padding: const EdgeInsets.symmetric(horizontal: 2),
    child: Text(
      text,
      style: TextStyle(fontSize: 13, color: cs.onSurfaceVariant),
    ),
  );

  void _toggle(String id, bool on) =>
      setState(() => on ? selected!.add(id) : selected!.remove(id));

  static String? _required(String? v) =>
      v == null || v.trim().isEmpty ? 'Required' : null;

  String? _t(TextEditingController c) =>
      c.text.trim().isEmpty ? null : c.text.trim();

  Future<void> _save() async {
    if (!fixed && (_mountOptions()?.isEmpty ?? true)) {
      toast(context, 'Add a lens first, then pick its mount.');
      return;
    }
    if (!_key.currentState!.validate()) return;
    setState(() => busy = true);
    final camera = CameraEdit(
      brand: brand.text.trim(),
      model: model.text.trim(),
      hasFixedLens: fixed,
      mount: fixed ? null : _t(mount),
      description: _t(desc),
      fixedLens: fixed && !editing
          ? FixedLensSpec(
              focalLength: int.parse(lensFocal.text),
              maxAperture: double.parse(lensAperture.text),
              // The built-in lens shares the camera brand; the user names the lens.
              brand: brand.text.trim(),
              model: _t(lensName),
            )
          : null,
    );
    Camera? saved;
    final ok = await guard(context, () async {
      saved = await ref
          .read(cameraActionsProvider)
          // Only touch links when the user could see and change them.
          .save(camera, existing: widget.camera, lensIds: selected);
    });
    if (!mounted) return;
    setState(() => busy = false);
    if (!ok) return;
    Navigator.of(context).pop(saved);
  }
}

class _TypeButton extends StatelessWidget {
  const _TypeButton({
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
    return Opacity(
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
              color: selected ? cs.primary : cs.outline,
              width: selected ? 1.95 : 0.65,
            ),
          ),
          child: Text(
            label,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: selected ? cs.onPrimaryContainer : cs.onSurface,
            ),
          ),
        ),
      ),
    );
  }
}
