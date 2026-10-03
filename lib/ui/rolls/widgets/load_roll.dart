import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api.dart';
import '../../../domain/models/models.dart';
import '../../../providers.dart';
import '../../core/widgets/common.dart';

int _expiryKey(ExpiryMonth? e) =>
    e == null ? 1 << 30 : e.year * 12 + (e.month ?? 12);

bool isExpired(ExpiryMonth? e) {
  if (e == null) return false;
  final now = DateTime.now();
  return _expiryKey(e) < now.year * 12 + now.month;
}

/// M-19 load roll into camera. Pass [camera], [roll], both or neither.
class LoadRollScreen extends ConsumerStatefulWidget {
  const LoadRollScreen({super.key, this.camera, this.roll});
  final Camera? camera;
  final RollSummary? roll;
  @override
  ConsumerState<LoadRollScreen> createState() => _State();
}

class _State extends ConsumerState<LoadRollScreen> {
  late Camera? camera = widget.camera;
  late RollSummary? roll = widget.roll;
  DateTime started = DateTime.now();
  final iso = TextEditingController();
  final Set<String> lensIds = {};
  List<Lens>? suggested; // lenses linked to the camera
  final Map<String, Lens> extra = {};
  bool busy = false;

  @override
  void initState() {
    super.initState();
    if (roll != null) iso.text = '';
    if (camera != null) _loadLenses();
  }

  Future<void> _loadLenses() async {
    final c = camera!;
    if (c.hasFixedLens) {
      setState(() => suggested = []);
      return;
    }
    try {
      final ls = await ref.read(apiProvider).cameraLenses(c.id);
      if (mounted) setState(() => suggested = ls);
    } catch (e) {
      if (mounted) toast(context, e.toString());
    }
  }

  Future<void> _pickRoll() async {
    List<RollSummary> rolls;
    try {
      rolls = await ref.read(apiProvider).rolls(status: 'in_stock');
    } catch (e) {
      if (mounted) toast(context, e.toString());
      return;
    }
    rolls.sort((a, b) => _expiryKey(a.expiry).compareTo(_expiryKey(b.expiry)));
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
      setState(() {
        roll = r;
        iso.text = '';
      });
    }
  }

  Future<void> _pickCamera() async {
    List<Camera> cams;
    try {
      cams = await ref.read(apiProvider).cameras();
    } catch (e) {
      if (mounted) toast(context, e.toString());
      return;
    }
    cams = cams.where((c) => c.isActive && c.loadedRoll == null).toList();
    if (!mounted) return;
    final c = await pickOne<Camera>(
      context,
      title: 'Camera',
      items: cams,
      label: (c) => c.name,
      subtitle: (c) =>
          c.hasFixedLens ? 'Fixed lens' : 'Mount ${c.mount ?? '—'}',
    );
    if (c != null) {
      setState(() {
        camera = c;
        lensIds.clear();
        extra.clear();
        suggested = null;
      });
      _loadLenses();
    }
  }

  Future<void> _addOtherLens() async {
    final all = await ref.read(apiProvider).lenses();
    final cand = all
        .where(
          (l) =>
              l.isActive &&
              !l.isBuiltIn &&
              !(suggested ?? []).any((s) => s.id == l.id),
        )
        .toList();
    if (!mounted) return;
    final l = await pickOne<Lens>(
      context,
      title: 'Lens',
      items: cand,
      label: (l) => l.name,
      subtitle: (l) => 'Mount ${l.mount ?? '—'}',
    );
    if (l == null || !mounted) return;
    setState(() {
      extra[l.id] = l;
      lensIds.add(l.id);
    });
    // M-19 6a: offer to link adapted lens to the camera.
    if (await confirm(
          context,
          'Link lens?',
          'Link ${l.name} to ${camera!.name} for future use?',
          ok: 'Link',
        ) &&
        mounted) {
      final api = ref.read(apiProvider);
      await guard(context, () async {
        final cur = (await api.cameraLenses(camera!.id))
            .map((x) => x.id)
            .toList();
        await api.setCameraLenses(camera!.id, {...cur, l.id}.toList());
      });
      refreshAll(ref);
    }
  }

  @override
  Widget build(BuildContext context) {
    final expired = isExpired(roll?.expiry);
    final cam = camera;
    return Scaffold(
      appBar: AppBar(title: const Text('Load roll')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          PickerField(
            label: 'Camera',
            value: cam?.name,
            onTap: widget.camera != null ? () {} : _pickCamera,
          ),
          gap,
          PickerField(
            label: 'Roll',
            value: roll == null
                ? null
                : '${roll!.stockLabel} · ${roll!.format}',
            onTap: widget.roll != null ? () {} : _pickRoll,
          ),
          if (expired)
            const WarningBanner([
              'This roll is expired. You can still load it.',
            ]),
          gap,
          DateField(
            label: 'Start date',
            value: started,
            onChanged: (d) => setState(() => started = d!),
          ),
          gap,
          TextFormField(
            controller: iso,
            decoration: deco(
              'Shot ISO',
              hint: roll == null ? null : 'Box ISO (change to push/pull)',
            ),
            keyboardType: TextInputType.number,
          ),
          const SectionHeader('Lenses'),
          if (cam == null)
            const Text('Select a camera first.')
          else if (cam.hasFixedLens)
            const Text('Built-in lens is assigned automatically.')
          else if (suggested == null)
            const LinearProgressIndicator()
          else ...[
            if (suggested!.isEmpty && extra.isEmpty)
              const Text('No linked lenses. Add one below or decide later.'),
            for (final l in [...suggested!, ...extra.values])
              CheckboxListTile(
                contentPadding: EdgeInsets.zero,
                value: lensIds.contains(l.id),
                title: Text(l.name),
                onChanged: (v) => setState(
                  () => v! ? lensIds.add(l.id) : lensIds.remove(l.id),
                ),
              ),
            TextButton.icon(
              onPressed: _addOtherLens,
              icon: const Icon(Icons.add),
              label: const Text('Other lens (adapted)'),
            ),
          ],
          gap,
          FilledButton(
            onPressed: busy || roll == null || cam == null ? null : _save,
            child: const Text('Load'),
          ),
        ],
      ),
    );
  }

  Future<void> _save() async {
    setState(() => busy = true);
    final shot = int.tryParse(iso.text);
    final body = {
      'cameraId': camera!.id,
      'startedAt': ymd(started),
      'shotIso': ?shot,
      if (!camera!.hasFixedLens && lensIds.isNotEmpty)
        'lensIds': lensIds.toList(),
    };
    final ok = await guard(
      context,
      () => ref.read(apiProvider).loadRoll(roll!.id, body),
    );
    if (!mounted) return;
    setState(() => busy = false);
    if (!ok) return;
    refreshAll(ref);
    toast(context, 'Roll loaded');
    Navigator.pop(context);
  }
}
