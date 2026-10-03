import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../domain/models/roll_filter.dart';
import '../../../providers.dart';
import '../../core/widgets/common.dart';
import '../view_models/gear_actions.dart';
import '../../rolls/widgets/roll_tile.dart';
import '../../../routing/routes.dart';

import 'package:go_router/go_router.dart';

import '../../../routing/navigation.dart';

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
                  () => ref.read(lensActionsProvider).delete(lensId),
                );
                if (ok && context.mounted) context.closeScreen();
              },
            ),
          if (lens.value != null)
            IconButton(
              icon: const Icon(Icons.edit_outlined),
              onPressed: () => context.push(Routes.lensEdit(lens.value!.id)),
            ),
        ],
      ),
      body: AsyncBody(
        value: lens,
        onRefresh: () {
          ref
            ..invalidate(lensCamerasProvider(lensId))
            ..invalidate(rollsProvider(RollFilter(lensId: lensId)));
          return ref.refresh(lensProvider(lensId).future);
        },
        builder: (l) {
          final cams = ref.watch(lensCamerasProvider(l.id));
          final rolls = ref.watch(rollsProvider(RollFilter(lensId: l.id)));
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
                        await guard(
                          context,
                          () =>
                              ref.read(lensActionsProvider).setActive(l.id, v),
                        );
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
                            onTap: () => context.push(Routes.camera(c.id)),
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
