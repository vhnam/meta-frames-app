import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/models.dart';
import '../../providers.dart';
import '../../widgets/common.dart';
import '../rolls/roll_tile.dart';
import 'camera_detail.dart';
import 'lens_form.dart';

/// Cameras a lens can be used on (no dedicated endpoint: derived from links).
final _lensCamerasProvider = FutureProvider.autoDispose
    .family<List<Camera>, String>((ref, lensId) async {
      final api = ref.watch(apiProvider);
      final cams = await api.cameras();
      final out = <Camera>[];
      for (final c in cams) {
        final ls = await api.cameraLenses(c.id);
        if (ls.any((l) => l.id == lensId)) out.add(c);
      }
      return out;
    });

/// M-11 lens details, M-08 activate/deactivate.
class LensDetailScreen extends ConsumerWidget {
  const LensDetailScreen({super.key, required this.lensId});
  final String lensId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final lens = ref.watch(lensProvider(lensId));
    return Scaffold(
      appBar: AppBar(
        title: Text(lens.value?.name ?? 'Lens'),
        actions: [
          if (lens.value != null && !lens.value!.isBuiltIn)
            IconButton(
              icon: const Icon(Icons.delete_outline),
              tooltip: 'Delete lens',
              onPressed: () async {
                if (!await confirm(
                  context,
                  'Delete lens?',
                  '${lens.value!.name} will be removed. Refused if used on a roll; deactivate instead.',
                  ok: 'Delete',
                )) {
                  return;
                }
                if (!context.mounted) return;
                final ok = await guard(
                  context,
                  () => ref.read(apiProvider).deleteLens(lensId),
                );
                if (ok && context.mounted) {
                  refreshAll(ref);
                  Navigator.pop(context);
                }
              },
            ),
          if (lens.value != null)
            IconButton(
              icon: const Icon(Icons.edit_outlined),
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => LensFormScreen(lens: lens.value),
                ),
              ),
            ),
        ],
      ),
      body: AsyncBody(
        value: lens,
        onRefresh: () async => refreshAll(ref),
        builder: (l) {
          final cams = ref.watch(_lensCamerasProvider(l.id));
          final rolls = ref.watch(
            rollsProvider((
              stockId: null,
              cameraId: null,
              lensId: l.id,
              format: null,
              from: null,
              to: null,
            )),
          );
          return ListView(
            children: [
              SwitchListTile(
                title: const Text('Active'),
                subtitle: Text(
                  l.isBuiltIn
                      ? 'Built-in lens follows its camera'
                      : 'Inactive lenses are hidden from pickers',
                ),
                value: l.isActive,
                onChanged: l.isBuiltIn
                    ? null
                    : (v) async {
                        final ok = await guard(
                          context,
                          () => ref.read(apiProvider).setLensActive(l.id, v),
                        );
                        if (ok) refreshAll(ref);
                      },
              ),
              InfoRow('Brand', l.brand),
              InfoRow('Model', l.model),
              InfoRow('Mount', l.isBuiltIn ? 'Built-in' : l.mount),
              InfoRow('Focal length', '${l.focalLength} mm'),
              InfoRow('Max aperture', 'f/${l.maxAperture.toStringAsFixed(1)}'),
              InfoRow('Description', l.description),
              const SectionHeader('Cameras'),
              ...cams.when(
                data: (cs) => cs.isEmpty
                    ? [
                        const Padding(
                          padding: EdgeInsets.all(16),
                          child: Text('Not linked to any camera'),
                        ),
                      ]
                    : [
                        for (final c in cs)
                          ListTile(
                            title: Text(c.name),
                            onTap: () => Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) =>
                                    CameraDetailScreen(cameraId: c.id),
                              ),
                            ),
                          ),
                      ],
                loading: () => [const LinearProgressIndicator()],
                error: (e, _) => [
                  Padding(padding: const EdgeInsets.all(16), child: Text('$e')),
                ],
              ),
              const SectionHeader('Rolls shot'),
              ...rolls.when(
                data: (rs) => rs.isEmpty
                    ? [
                        const Padding(
                          padding: EdgeInsets.all(16),
                          child: Text('No rolls yet'),
                        ),
                      ]
                    : [for (final r in rs) RollTile(roll: r)],
                loading: () => [const LinearProgressIndicator()],
                error: (e, _) => [
                  Padding(padding: const EdgeInsets.all(16), child: Text('$e')),
                ],
              ),
              const SizedBox(height: 32),
            ],
          );
        },
      ),
    );
  }
}
