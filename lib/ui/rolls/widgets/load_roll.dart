import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../domain/models/expiry.dart';
import '../../../domain/models/models.dart';
import '../../core/widgets/cards.dart';
import '../../core/widgets/common.dart';
import '../../core/widgets/form_kit.dart';
import '../view_models/load_roll_view_model.dart';

import '../../../routing/navigation.dart';

/// M-19 load roll into camera. Pass [camera], [roll], both or neither.
class LoadRollScreen extends ConsumerStatefulWidget {
  const LoadRollScreen({super.key, this.camera, this.roll});
  final Camera? camera;
  final RollSummary? roll;
  @override
  ConsumerState<LoadRollScreen> createState() => _State();
}

class _State extends ConsumerState<LoadRollScreen> {
  final iso = TextEditingController();
  bool busy = false;

  late final _provider = loadRollViewModelProvider((
    camera: widget.camera,
    roll: widget.roll,
  ));

  @override
  void dispose() {
    iso.dispose();
    super.dispose();
  }

  LoadRollViewModel get _vm => ref.read(_provider.notifier);

  Future<void> _pickRoll() async {
    final List<RollSummary> rolls;
    try {
      rolls = await _vm.inStockRolls();
    } catch (e) {
      if (mounted) toast(context, e.toString());
      return;
    }
    if (!mounted) return;
    final r = await pickOne<RollSummary>(
      context,
      title: 'In-stock rolls',
      items: rolls,
      label: (r) => r.stockLabel,
      subtitle: (r) =>
          '${r.format} · ${r.exposures} exp · ${r.expiry == null ? 'no expiry' : 'exp ${r.expiry}${isExpired(r.expiry) ? ' (expired)' : ''}'}',
    );
    if (r != null) {
      _vm.selectRoll(r);
      iso.text = '';
    }
  }

  Future<void> _pickCamera() async {
    final List<Camera> cams;
    try {
      cams = await _vm.emptyCameras();
    } catch (e) {
      if (mounted) toast(context, e.toString());
      return;
    }
    if (!mounted) return;
    final c = await pickOne<Camera>(
      context,
      title: 'Camera',
      items: cams,
      label: (c) => c.name,
      subtitle: (c) =>
          c.hasFixedLens ? 'Fixed lens' : 'Mount ${c.mount ?? '—'}',
    );
    if (c != null) _vm.selectCamera(c);
  }

  Future<void> _addOtherLens() async {
    final cand = await _vm.otherLenses();
    if (!mounted) return;
    final l = await pickOne<Lens>(
      context,
      title: 'Lens',
      items: cand,
      label: (l) => l.name,
      subtitle: (l) => 'Mount ${l.mount ?? '—'}',
    );
    if (l == null || !mounted) return;
    _vm.addExtraLens(l);
    // M-19 6a: offer to link adapted lens to the camera.
    final camera = ref.read(_provider).camera!;
    if (await confirm(
          context,
          'Link lens?',
          'Link ${l.name} to ${camera.name} for future use?',
          ok: 'Link',
        ) &&
        mounted) {
      await guard(context, () => _vm.linkLens(l));
    }
  }

  @override
  Widget build(BuildContext context) {
    ref.listen(_provider.select((s) => s.lensError), (_, e) {
      if (e != null) toast(context, e);
    });
    final s = ref.watch(_provider);
    final cam = s.camera;
    final roll = s.roll;
    final cs = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: formAppBar(context, 'Load roll'),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          LabeledField(
            label: 'Camera',
            child: SelectField(
              hint: 'Select a camera',
              value: cam?.name,
              onTap: widget.camera != null ? null : _pickCamera,
            ),
          ),
          LabeledField(
            label: 'Roll',
            child: SelectField(
              hint: 'Select a roll',
              value: roll == null
                  ? null
                  : '${roll.stockLabel} · ${roll.format}',
              onTap: widget.roll != null ? null : _pickRoll,
            ),
          ),
          if (s.expired)
            const WarningBanner([
              'This roll is expired. You can still load it.',
            ]),
          LabeledField(
            label: 'Start date',
            child: SelectField(
              hint: 'Select date',
              value: fmtDate(s.started),
              icon: Icons.calendar_today,
              onTap: () async {
                final d = await pickDate(context, s.started);
                if (d != null) _vm.setStarted(d);
              },
            ),
          ),
          LabeledField(
            label: 'Shot ISO (optional)',
            child: TextFormField(
              controller: iso,
              decoration: formInputDecoration(
                roll == null
                    ? 'Empty = box ISO'
                    : 'Box ISO (change to push/pull)',
                cs,
              ),
              keyboardType: TextInputType.number,
            ),
          ),
          const DetailLabel('LENSES', top: 4),
          if (cam == null)
            _note(cs, 'Select a camera first.')
          else if (cam.hasFixedLens)
            _note(cs, 'Built-in lens is assigned automatically.')
          else if (s.suggested == null)
            const LinearProgressIndicator()
          else ...[
            if (s.suggested!.isEmpty && s.extra.isEmpty)
              _note(cs, 'No linked lenses. Add one below or decide later.')
            else
              CardList(
                children: [
                  for (final l in s.lensChoices)
                    CheckboxListTile(
                      value: s.lensIds.contains(l.id),
                      title: Text(
                        l.name,
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      onChanged: (v) => _vm.toggleLens(l.id, v!),
                    ),
                ],
              ),
            const SizedBox(height: 8),
            DashedButton(label: 'Other lens (adapted)', onTap: _addOtherLens),
          ],
          const SizedBox(height: 24),
          FormSaveBar(
            label: 'Load',
            busy: busy,
            onPressed: s.canSubmit ? _save : null,
          ),
        ],
      ),
    );
  }

  Widget _note(ColorScheme cs, String t) =>
      Text(t, style: TextStyle(fontSize: 13, color: cs.onSurfaceVariant));

  Future<void> _save() async {
    setState(() => busy = true);
    final ok = await guard(
      context,
      () => _vm.submit(shotIso: int.tryParse(iso.text)),
    );
    if (!mounted) return;
    setState(() => busy = false);
    if (!ok) return;
    toast(context, 'Roll loaded');
    context.closeScreen();
  }
}
