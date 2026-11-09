import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../data/sync/sync_engine.dart';
import '../../../domain/models/models.dart';
import '../../../providers.dart';
import '../../../routing/routes.dart';
import '../../core/theme.dart';
import '../../core/widgets/cards.dart';
import '../../core/widgets/common.dart';
import '../../rolls/widgets/finish_roll.dart';
import '../../sync/view_models/sync_actions.dart';
import '../../sync/widgets/op_status.dart';
import '../../sync/widgets/sync_screen.dart';
import '../view_models/shooting_view_model.dart';

/// The cameras with film in them, opened in a few seconds between shots: what
/// each one holds, finishing the roll, and loading a new one into an empty
/// camera.
class ShootingTab extends ConsumerWidget {
  const ShootingTab({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final loaded = ref.watch(loadedCamerasProvider);
    final empty = ref.watch(emptyCamerasProvider).value ?? const <Camera>[];
    final stocks = ref.watch(stocksByIdProvider);
    final welcome = ref.watch(isNewUserProvider);
    final cs = Theme.of(context).colorScheme;

    return Scaffold(
      backgroundColor: cs.surface,
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            ScreenHeader(
              kicker: 'MetaFrames · In the field',
              title: 'Shooting',
              trailing: empty.isEmpty
                  ? null
                  : TextButton(
                      onPressed: () => context.push(Routes.load),
                      child: const Text('+ Load'),
                    ),
            ),
            const _SyncLine(),
            Expanded(
              child: AsyncBody(
                value: loaded,
                onRefresh: () => refreshShooting(ref),
                builder: (cams) => ListView(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
                  children: [
                    if (welcome)
                      const _Welcome()
                    else ...[
                      if (cams.isEmpty)
                        EmptyCard(
                          icon: Icons.photo_camera_outlined,
                          title: 'No film loaded',
                          text: empty.isEmpty
                              ? 'Add a camera to load a roll into it.'
                              : 'Load a roll to start shooting.',
                        ),
                      for (final c in cams) ...[
                        _LoadedCameraCard(
                          camera: c,
                          stock: stocks[c.loadedRoll!.stockId],
                        ),
                        const SizedBox(height: 12),
                      ],
                      if (empty.isNotEmpty) ...[
                        const DetailLabel('EMPTY CAMERAS'),
                        CardList(
                          gap: 8,
                          children: [
                            for (final c in empty) _EmptyCameraTile(camera: c),
                          ],
                        ),
                      ] else if (cams.isEmpty) ...[
                        const SizedBox(height: 12),
                        DashedButton(
                          label: 'Add a camera',
                          onTap: () => context.push(Routes.cameraNew),
                        ),
                      ],
                    ],
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// One camera and the roll in it, with the actions taken while shooting.
class _LoadedCameraCard extends ConsumerWidget {
  const _LoadedCameraCard({required this.camera, required this.stock});
  final Camera camera;
  final FilmStock? stock;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final r = camera.loadedRoll!;
    final cs = Theme.of(context).colorScheme;
    // Changes to this roll not on the server yet; one needing the user first.
    final ops = ref.watch(rollOpsProvider(r.rollId));
    final shown =
        ops.where((o) => o.needsAttention).firstOrNull ?? ops.firstOrNull;
    final meta = [
      ?r.isoLabel(stock),
      if (r.startedAt != null) 'since ${fmtDate(r.startedAt)}',
      '${r.daysLoaded}d',
    ].join(' · ');
    final compact = OutlinedButton.styleFrom(
      minimumSize: const Size(0, 40),
      padding: const EdgeInsets.symmetric(horizontal: 14),
    );

    return Material(
      color: cs.surfaceContainerLow,
      shape: RoundedRectangleBorder(
        borderRadius: kCorners,
        side: BorderSide(color: cs.outline, width: kHairline),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => context.push(Routes.roll(r.rollId)),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(Icons.photo_camera, size: 20, color: cs.primary),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      camera.name,
                      style: monoStyle(
                        fontWeight: FontWeight.w600,
                        letterSpacing: 0.4,
                        color: cs.onSurfaceVariant,
                      ),
                    ),
                  ),
                  if (shown != null) ...[
                    OpBadge(shown),
                    const SizedBox(width: 6),
                  ],
                  if (!camera.isActive)
                    StampBadge('Inactive', color: cs.onSurfaceVariant),
                  if (stock != null) ...[
                    const SizedBox(width: 6),
                    ProcessBadge(stock!.process),
                  ],
                ],
              ),
              const SizedBox(height: 10),
              Text(
                r.stockLabel,
                style: const TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                meta,
                style: TextStyle(fontSize: 13, color: cs.onSurfaceVariant),
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  OutlinedButton(
                    style: compact,
                    onPressed: () => context.push(Routes.rollNotes(r.rollId)),
                    child: const Text('Roll notes'),
                  ),
                  OutlinedButton(
                    style: compact,
                    onPressed: () =>
                        finishRoll(context, ref, r.rollId, cameraId: camera.id),
                    child: const Text('Finish'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// One line under the header when something is waiting for the server or
/// the server cannot be reached. Opens Sync status.
class _SyncLine extends ConsumerWidget {
  const _SyncLine();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ops = ref.watch(openOpsProvider).value ?? const [];
    final status = ref.watch(syncStatusProvider);
    final offline = status != null && status.pause != SyncPause.none;
    if (ops.isEmpty && !offline) return const SizedBox.shrink();
    final attention = ops.any((o) => o.needsAttention);
    final cs = Theme.of(context).colorScheme;
    return InkWell(
      onTap: () => context.push(Routes.sync),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 4),
        child: Row(
          children: [
            Icon(
              attention ? Icons.error_outline : Icons.cloud_queue,
              size: 16,
              color: attention ? cs.error : cs.onSurfaceVariant,
            ),
            const SizedBox(width: 6),
            Expanded(
              child: Text(
                attention
                    ? 'A change needs your attention'
                    : syncStatusLine(status, ops.length),
                style: TextStyle(
                  fontSize: 13,
                  color: attention ? cs.error : cs.onSurfaceVariant,
                ),
              ),
            ),
            Icon(Icons.chevron_right, size: 18, color: cs.onSurfaceVariant),
          ],
        ),
      ),
    );
  }
}

class _EmptyCameraTile extends StatelessWidget {
  const _EmptyCameraTile({required this.camera});
  final Camera camera;

  @override
  Widget build(BuildContext context) => CardTile(
    icon: Icons.photo_camera_outlined,
    title: camera.name,
    subtitle: camera.hasFixedLens
        ? 'Fixed lens'
        : 'Mount ${camera.mount ?? '—'}',
    compact: true,
    trailing: FilledButton.tonal(
      style: FilledButton.styleFrom(
        minimumSize: Size.zero,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
      ),
      onPressed: () => context.push(Routes.cameraLoadRoll(camera.id)),
      child: const Text('Load'),
    ),
    onTap: () => context.push(Routes.camera(camera.id)),
  );
}

class _Welcome extends StatelessWidget {
  const _Welcome();

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 52),
      child: Column(
        children: [
          Container(
            width: 80,
            height: 80,
            decoration: BoxDecoration(
              color: cs.primaryContainer,
              borderRadius: kCorners,
              border: Border.all(
                color: cs.onPrimaryContainer,
                width: kHairline,
              ),
            ),
            child: Icon(Icons.photo_camera, size: 40, color: cs.primary),
          ),
          const SizedBox(height: 20),
          Text(
            'Welcome to MetaFrames',
            style: text.headlineSmall?.copyWith(fontSize: 22),
          ),
          const SizedBox(height: 8),
          SizedBox(
            width: 280,
            child: Text(
              'Know what is in each camera. Start by adding a camera and some film.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 15,
                height: 1.6,
                color: cs.onSurfaceVariant,
              ),
            ),
          ),
          const SizedBox(height: 32),
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 300),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                FilledButton(
                  onPressed: () => context.push(Routes.cameraNew),
                  child: const Text('Add your first camera'),
                ),
                const SizedBox(height: 10),
                FilledButton.tonal(
                  onPressed: () => context.push(Routes.rollNew()),
                  child: const Text('Add rolls to your inventory'),
                ),
              ],
            ),
          ),
          const SizedBox(height: 28),
          Text(
            'You can also import existing rolls from a spreadsheet on the web app.',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 13,
              height: 1.5,
              color: cs.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}
