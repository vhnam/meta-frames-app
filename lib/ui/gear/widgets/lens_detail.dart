import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../domain/models/models.dart';
import '../../../domain/models/roll_filter.dart';
import '../../../providers.dart';
import '../../core/widgets/cards.dart';
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
    final cs = Theme.of(context).colorScheme;
    return Scaffold(
      backgroundColor: cs.surfaceContainerLow,
      appBar: AppBar(
        backgroundColor: cs.surface,
        scrolledUnderElevation: 0,
        shape: Border(
          bottom: BorderSide(color: cs.outlineVariant, width: 0.65),
        ),
        title: Text(
          lens.value?.name ?? 'Lens',
          style: const TextStyle(fontSize: 19, fontWeight: FontWeight.w600),
        ),
        actions: [
          if (lens.value != null)
            Padding(
              padding: const EdgeInsets.only(right: 4),
              child: TextButton(
                onPressed: () => context.push(Routes.lensEdit(lens.value!.id)),
                child: const Text(
                  'Edit',
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
                ),
              ),
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
        builder: (l) => _Body(lens: l),
      ),
    );
  }
}

class _Body extends ConsumerWidget {
  const _Body({required this.lens});
  final Lens lens;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = lens;
    final cs = Theme.of(context).colorScheme;
    final cams = ref.watch(lensCamerasProvider(l.id));
    final rolls = ref.watch(rollsProvider(RollFilter(lensId: l.id)));
    final notes = l.description?.trim() ?? '';
    Widget muted(String t) =>
        Text(t, style: TextStyle(fontSize: 13, color: cs.onSurfaceVariant));

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        CardList(
          children: [
            DetailInfoRow('Brand', l.brand),
            DetailInfoRow('Model', l.model),
            DetailInfoRow('Mount', l.isBuiltIn ? 'Built-in' : l.mount),
            DetailInfoRow('Focal length', '${l.focalLength} mm'),
            DetailInfoRow(
              'Max aperture',
              'f/${l.maxAperture.toStringAsFixed(1)}',
            ),
            if (notes.isNotEmpty) DetailInfoRow('Notes', notes),
            DetailInfoRow('Status', l.isActive ? 'Active' : 'Inactive'),
          ],
        ),
        const DetailLabel('CAMERAS'),
        cams.when(
          data: (cs2) => cs2.isEmpty
              ? muted('Not linked to any camera')
              : CardList(
                  children: [
                    for (final c in cs2)
                      CardTile(
                        compact: true,
                        leading: Icon(
                          Icons.photo_camera_outlined,
                          size: 20,
                          color: cs.onSurfaceVariant,
                        ),
                        title: c.name,
                        subtitle: 'Camera',
                        trailing: Icon(
                          Icons.chevron_right,
                          size: 20,
                          color: cs.onSurfaceVariant,
                        ),
                        onTap: () => context.push(Routes.camera(c.id)),
                      ),
                  ],
                ),
          loading: () => const LinearProgressIndicator(),
          error: (e, _) => Text('$e'),
        ),
        const DetailLabel('ROLLS SHOT'),
        rolls.when(
          data: (rs) => rs.isEmpty
              ? muted('No rolls yet')
              : CardList(children: [for (final r in rs) RollTile(roll: r)]),
          loading: () => const LinearProgressIndicator(),
          error: (e, _) => Text('$e'),
        ),
        if (!l.isBuiltIn) ...[
          const SizedBox(height: 20),
          CardList(
            children: [
              DetailActionRow(
                label: l.isActive ? 'Deactivate lens' : 'Activate lens',
                color: cs.onPrimaryContainer,
                onTap: () => guard(
                  context,
                  () => ref
                      .read(lensActionsProvider)
                      .setActive(l.id, !l.isActive),
                ),
              ),
              DetailActionRow(
                label: 'Delete lens',
                color: cs.error,
                onTap: () => _delete(context, ref),
              ),
            ],
          ),
        ],
        const SizedBox(height: 16),
      ],
    );
  }

  Future<void> _delete(BuildContext context, WidgetRef ref) async {
    if (!await confirm(
      context,
      'Delete lens?',
      '${lens.name} will be removed. Refused if used on a roll; deactivate instead.',
      ok: 'Delete',
    )) {
      return;
    }
    if (!context.mounted) return;
    final ok = await guard(
      context,
      () => ref.read(lensActionsProvider).delete(lens.id),
    );
    if (ok && context.mounted) context.closeScreen();
  }
}
