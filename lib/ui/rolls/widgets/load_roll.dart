import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:go_router/go_router.dart';

import '../../../data/local/local_store.dart';
import '../../../domain/models/expiry.dart';
import '../../../domain/models/models.dart';
import '../../../providers.dart';
import '../../core/widgets/cards.dart';
import '../../core/widgets/common.dart';
import '../../core/widgets/form_kit.dart';
import '../../sync/view_models/drafts.dart' show draftsOf;
import '../../sync/widgets/create_footer.dart';
import '../view_models/load_roll_view_model.dart';
import '../../../routing/routes.dart';

import '../../../routing/navigation.dart';

/// M-19 load roll into camera. Pass [camera], [roll], both or neither. Only the
/// camera and the roll are needed: the start date defaults to today, the shot
/// ISO to the box speed, and lenses can be left out.
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
  String? _isoError;

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
    // Expiry warnings help but must not stop a roll being picked.
    final expiring = await _vm.expiringRollIds().catchError(
      (_) => const <String>{},
    );
    final drafts = await draftsOf(ref, DraftKind.rolls);
    if (!mounted) return;
    String expiry(RollSummary r) {
      if (r.expiry == null) return 'no expiry';
      if (isExpired(r.expiry)) return 'exp ${r.expiry} (expired)';
      if (expiring.contains(r.id)) return 'exp ${r.expiry} (expires soon)';
      return 'exp ${r.expiry}';
    }

    final r = await pickOne<RollSummary>(
      context,
      title: 'In-stock rolls',
      items: rolls,
      // The format is in the label so searching "120" narrows the list.
      label: (r) => '${r.stockLabel} · ${r.format}',
      subtitle: (r) => '${r.exposures} exp · ${expiry(r)}',
      // Film bought mid-trip: add it, then load it.
      footer: CreateFooter<RollSummary>(
        label: 'Add new film',
        drafts: drafts,
        create: (c) => c.push(Routes.rollNew(quick: true)),
        resume: (c, d) => c.push(Routes.rollNew(draft: d.id)),
      ),
    );
    if (r != null) {
      _vm.selectRoll(r);
      iso.text = '';
      setState(() => _isoError = null);
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
    final drafts = await draftsOf(ref, DraftKind.camera);
    if (!mounted) return;
    final c = await pickOne<Camera>(
      context,
      title: 'Camera',
      items: cams,
      label: (c) => c.name,
      subtitle: (c) =>
          c.hasFixedLens ? 'Fixed lens' : 'Mount ${c.mount ?? '—'}',
      // A borrowed camera: add the minimum, then load it.
      footer: CreateFooter<Camera>(
        label: 'Add a camera',
        drafts: drafts,
        create: (c) => c.push(Routes.cameraCreate()),
        resume: (c, d) => c.push(Routes.cameraCreate(draft: d.id)),
      ),
    );
    if (c != null) _vm.selectCamera(c);
  }

  Future<void> _addOtherLens() async {
    final List<Lens> cand;
    try {
      cand = await _vm.otherLenses();
    } catch (e) {
      if (mounted) toast(context, e.toString());
      return;
    }
    final drafts = await draftsOf(ref, DraftKind.lens);
    if (!mounted) return;
    final mount = ref.read(_provider).camera?.mount;
    final l = await pickOne<Lens>(
      context,
      title: 'Lens',
      items: cand,
      label: (l) => l.name,
      subtitle: (l) => 'Mount ${l.mount ?? '—'}',
      footer: CreateFooter<Lens>(
        label: 'Add a lens',
        drafts: drafts,
        create: (c) => c.push(Routes.lensCreate(mount: mount)),
        resume: (c, d) => c.push(Routes.lensCreate(draft: d.id)),
      ),
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
    final boxIso = roll == null
        ? null
        : ref.watch(stocksByIdProvider)[roll.filmStockId]?.boxIso;
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
                boxIso == null ? 'Empty = box ISO' : 'Empty = box ISO $boxIso',
                cs,
              ).copyWith(errorText: _isoError),
              keyboardType: TextInputType.number,
              onChanged: (_) {
                if (_isoError != null) setState(() => _isoError = null);
              },
            ),
          ),
          const DetailLabel('LENSES (OPTIONAL)', top: 4),
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
    final int? shotIso;
    try {
      shotIso = parseShotIso(iso.text);
    } on FormatException catch (e) {
      setState(() => _isoError = e.message);
      return;
    }
    setState(() => busy = true);
    final ok = await guard(context, () => _vm.submit(shotIso: shotIso));
    if (!mounted) return;
    setState(() => busy = false);
    if (!ok) return;
    toast(context, 'Roll loaded');
    context.closeScreen();
  }
}
