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
import 'lens_form.dart' show validAperture, validFocal;
import '../../../routing/navigation.dart';

/// Quick add of a camera (a borrowed body, or one added from Gear or the load
/// screen). It asks only what the server needs: brand, model, and a mount,
/// typed freely, or a fixed lens's focal length and aperture. Notes and linked
/// lenses are set on the dashboard. A new camera is kept as a draft until the
/// server confirms it; [draft] reopens one.
class CameraFormScreen extends ConsumerStatefulWidget {
  const CameraFormScreen({super.key, this.draft});
  final Draft? draft;
  @override
  ConsumerState<CameraFormScreen> createState() => _State();
}

class _State extends ConsumerState<CameraFormScreen> {
  final _key = GlobalKey<FormState>();
  late final CameraEdit? _restored = widget.draft == null
      ? null
      : CameraEdit.fromJson(widget.draft!.json['request']);
  late final brand = TextEditingController(text: _restored?.brand);
  late final model = TextEditingController(text: _restored?.model);
  late final mount = TextEditingController(text: _restored?.mount);
  late final lensFocal = TextEditingController(
    text: _restored?.fixedLens?.focalLength.toString(),
  );
  late final lensAperture = TextEditingController(
    text: _restored?.fixedLens?.maxAperture.toString(),
  );
  late final lensName = TextEditingController(
    text: _restored?.fixedLens?.model,
  );
  late bool fixed = _restored?.hasFixedLens ?? false;
  bool busy = false;

  /// The new camera's client id, kept with its draft.
  late String _draftId = widget.draft?.id ?? newId();

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Scaffold(
      backgroundColor: cs.surfaceContainerLow,
      appBar: formAppBar(context, 'New Camera'),
      body: Form(
        key: _key,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            if (widget.draft?.error case final e?) WarningBanner([e]),
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
                      onTap: () => setState(() => fixed = false),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _TypeButton(
                      label: 'Fixed lens',
                      selected: fixed,
                      onTap: () => setState(() => fixed = true),
                    ),
                  ),
                ],
              ),
            ),
            if (fixed)
              LabeledField(
                label: 'Lens name (optional)',
                child: TextFormField(
                  controller: lensName,
                  decoration: formInputDecoration('e.g. Zuiko 35mm f/2.8', cs),
                ),
              ),
            if (fixed)
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
            if (!fixed) _freeMountField(cs),
            const FormNote('Notes and linked lenses can be added later.'),
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
                  : const Text('Add camera'),
            ),
          ],
        ),
      ),
    );
  }

  /// A borrowed body's mount may match no lens on file: typed freely, with
  /// the mounts already known offered as quick picks.
  Widget _freeMountField(ColorScheme cs) {
    final known = <String>{
      for (final l in ref.watch(lensesProvider).value ?? const <Lens>[])
        if (l.isActive && !l.isBuiltIn && (l.mount ?? '').trim().isNotEmpty)
          l.mount!.trim(),
    }.toList()..sort();
    return LabeledField(
      label: 'Lens mount',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          TextFormField(
            controller: mount,
            decoration: formInputDecoration('e.g. Nikon F', cs),
            validator: (v) => v == null || v.trim().isEmpty
                ? 'Required for interchangeable lens'
                : null,
          ),
          if (known.isNotEmpty)
            Wrap(
              spacing: 6,
              children: [
                for (final m in known)
                  ActionChip(label: Text(m), onPressed: () => mount.text = m),
              ],
            ),
        ],
      ),
    );
  }

  static String? _required(String? v) =>
      v == null || v.trim().isEmpty ? 'Required' : null;

  String? _t(TextEditingController c) =>
      c.text.trim().isEmpty ? null : c.text.trim();

  Future<void> _save() async {
    if (!_key.currentState!.validate()) return;
    setState(() => busy = true);
    final camera = CameraEdit(
      brand: brand.text.trim(),
      model: model.text.trim(),
      hasFixedLens: fixed,
      mount: fixed ? null : _t(mount),
      fixedLens: fixed
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
    final actions = ref.read(cameraActionsProvider);
    final id = _draftId;
    final ok = await guard(context, () async {
      try {
        saved = await ref
            .read(draftActionsProvider)
            .submit(
              id: id,
              kind: DraftKind.camera,
              label: '${camera.brand} ${camera.model}',
              form: {'request': camera.toJson()},
              send: () => actions.save(camera, id: id),
              readBack: () => actions.landed(id, camera),
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

class _TypeButton extends StatelessWidget {
  const _TypeButton({
    required this.label,
    required this.selected,
    required this.onTap,
  });
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return InkWell(
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
    );
  }
}
