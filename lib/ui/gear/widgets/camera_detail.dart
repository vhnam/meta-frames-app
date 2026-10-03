import 'dart:ui' show PathMetric;

import 'package:flutter/material.dart';

import '../../core/theme.dart';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../domain/models/models.dart';
import '../../../domain/models/roll_filter.dart';
import '../../../providers.dart';
import '../../core/widgets/cards.dart';
import '../view_models/gear_actions.dart';
import '../../core/widgets/common.dart';
import '../../../routing/routes.dart';

import 'package:go_router/go_router.dart';

import '../../../routing/navigation.dart';

/// M-11 camera details, M-05 activate/deactivate, M-09 entry point.
/// Read-only summary the user checks before deactivating or deleting.
class CameraDetailScreen extends ConsumerWidget {
  const CameraDetailScreen({super.key, required this.cameraId});
  final String cameraId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cam = ref.watch(cameraProvider(cameraId));
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
          cam.value?.name ?? 'Camera',
          style: const TextStyle(fontSize: 19, fontWeight: FontWeight.w600),
        ),
        actions: [
          if (cam.value != null)
            Padding(
              padding: const EdgeInsets.only(right: 4),
              child: TextButton(
                onPressed: () => context.push(Routes.cameraEdit(cam.value!.id)),
                child: const Text(
                  'Edit',
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
                ),
              ),
            ),
        ],
      ),
      body: AsyncBody(
        value: cam,
        onRefresh: () {
          ref
            ..invalidate(cameraLensesProvider(cameraId))
            ..invalidate(rollsProvider(RollFilter(cameraId: cameraId)));
          return ref.refresh(cameraProvider(cameraId).future);
        },
        builder: (c) => _Body(camera: c),
      ),
    );
  }
}

class _Body extends ConsumerWidget {
  const _Body({required this.camera});
  final Camera camera;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cs = Theme.of(context).colorScheme;
    final lenses = ref.watch(cameraLensesProvider(camera.id));
    final stocks = {
      for (final s in ref.watch(stocksProvider).value ?? const <FilmStock>[])
        s.id: s,
    };
    final loaded = camera.loadedRoll;
    final notes = camera.description?.trim() ?? '';

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        CardList(
          children: [
            _InfoRow(
              'Mount',
              camera.hasFixedLens ? '—' : (camera.mount ?? '—'),
            ),
            _InfoRow('Fixed lens', camera.hasFixedLens ? 'Yes' : 'No'),
            if (notes.isNotEmpty) _InfoRow('Notes', notes),
            _InfoRow('Status', camera.isActive ? 'Active' : 'Inactive'),
          ],
        ),
        const _Label('LOADED ROLL'),
        _LoadedRollCard(
          camera: camera,
          loaded: loaded,
          stock: stocks[loaded?.stockId],
        ),
        _Label(camera.hasFixedLens ? 'BUILT-IN LENS' : 'LINKED LENSES'),
        lenses.when(
          data: (ls) => ls.isEmpty
              ? Text(
                  'None linked',
                  style: TextStyle(fontSize: 13, color: cs.onSurfaceVariant),
                )
              : CardList(
                  children: [
                    for (final l in ls)
                      CardTile(
                        compact: true,
                        leading: Icon(
                          Icons.adjust,
                          size: 20,
                          color: cs.onSurfaceVariant,
                        ),
                        title: _lensTitle(l),
                        subtitle:
                            '${l.focalLength}mm · f/${_aperture(l.maxAperture)}',
                        onTap: () => context.push(Routes.lens(l.id)),
                      ),
                  ],
                ),
          loading: () => const LinearProgressIndicator(),
          error: (e, _) => Text('$e'),
        ),
        if (!camera.hasFixedLens) ...[
          const SizedBox(height: 8),
          _DashedButton(
            label: 'Manage lenses',
            onTap: () => context.push(Routes.cameraLenses(camera.id)),
          ),
        ],
        const SizedBox(height: 20),
        CardList(
          children: [
            _ActionRow(
              label: camera.isActive ? 'Deactivate camera' : 'Activate camera',
              color: cs.onPrimaryContainer,
              onTap: () => _toggleActive(context, ref),
            ),
            _ActionRow(
              label: 'Delete camera',
              color: cs.error,
              onTap: () => _delete(context, ref),
            ),
          ],
        ),
        const SizedBox(height: 16),
      ],
    );
  }

  Future<void> _toggleActive(BuildContext context, WidgetRef ref) async {
    if (camera.isActive && camera.loadedRoll != null) {
      toast(context, 'Camera is loaded. Finish the roll first.');
      return;
    }
    await guard(
      context,
      () => ref.read(cameraActionsProvider).setActive(camera, !camera.isActive),
    );
  }

  Future<void> _delete(BuildContext context, WidgetRef ref) async {
    if (!await confirm(
      context,
      'Delete camera?',
      '${camera.name} will be removed. Refused if it has rolls; deactivate instead.',
      ok: 'Delete',
    )) {
      return;
    }
    if (!context.mounted) return;
    final ok = await guard(
      context,
      () => ref.read(cameraActionsProvider).delete(camera.id),
    );
    if (ok && context.mounted) context.closeScreen();
  }

  static String _aperture(double a) => a.toStringAsFixed(a % 1 == 0 ? 0 : 1);

  static String _lensTitle(Lens l) {
    final n = [
      l.brand,
      l.model,
    ].where((e) => e != null && e.isNotEmpty).join(' ');
    return n.isEmpty ? l.name : n;
  }
}

class _Label extends StatelessWidget {
  const _Label(this.text);
  final String text;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(0, 20, 0, 8),
    child: Text(
      text,
      style: TextStyle(
        fontSize: 12,
        fontWeight: FontWeight.w600,
        letterSpacing: 0.96,
        color: Theme.of(context).colorScheme.onSurfaceVariant,
      ),
    ),
  );
}

class _InfoRow extends StatelessWidget {
  const _InfoRow(this.label, this.value);
  final String label, value;
  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 11),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: TextStyle(fontSize: 14, color: cs.onSurfaceVariant),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Text(
              value,
              textAlign: TextAlign.end,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w500,
                color: cs.onSurface,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ActionRow extends StatelessWidget {
  const _ActionRow({
    required this.label,
    required this.color,
    required this.onTap,
  });
  final String label;
  final Color color;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) => InkWell(
    onTap: onTap,
    child: Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 15,
          fontWeight: FontWeight.w500,
          color: color,
        ),
      ),
    ),
  );
}

class _DashedButton extends StatelessWidget {
  const _DashedButton({required this.label, required this.onTap});
  final String label;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return CustomPaint(
      painter: _DashedBorder(cs.outline),
      child: InkWell(
        onTap: onTap,
        borderRadius: kCorners,
        child: Container(
          height: 41,
          alignment: Alignment.center,
          child: Text(
            label,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w500,
              color: cs.onPrimaryContainer,
            ),
          ),
        ),
      ),
    );
  }
}

class _DashedBorder extends CustomPainter {
  _DashedBorder(this.color);
  final Color color;
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;
    final path = Path()
      ..addRRect(
        RRect.fromRectAndRadius(Offset.zero & size, const Radius.circular(12)),
      );
    for (final PathMetric m in path.computeMetrics()) {
      for (var d = 0.0; d < m.length; d += 7) {
        canvas.drawPath(m.extractPath(d, d + 4), paint);
      }
    }
  }

  @override
  bool shouldRepaint(_DashedBorder old) => old.color != color;
}

class _LoadedRollCard extends StatelessWidget {
  const _LoadedRollCard({
    required this.camera,
    required this.loaded,
    required this.stock,
  });
  final Camera camera;
  final LoadedRoll? loaded;
  final FilmStock? stock;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final r = loaded;
    if (r == null) {
      return CardList(
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    'Empty',
                    style: TextStyle(fontSize: 15, color: cs.onSurfaceVariant),
                  ),
                ),
                if (camera.isActive)
                  FilledButton.tonal(
                    onPressed: () =>
                        context.push(Routes.cameraLoadRoll(camera.id)),
                    child: const Text('Load roll'),
                  ),
              ],
            ),
          ),
        ],
      );
    }
    final iso = r.shotIso ?? stock?.boxIso;
    final pushed =
        r.shotIso != null && stock != null && r.shotIso != stock!.boxIso;
    final subtitle = [
      if (iso != null) 'ISO $iso (${pushed ? 'pushed/pulled' : 'box'})',
      if (r.startedAt != null)
        'loaded ${r.startedAt!.toIso8601String().substring(0, 10)}',
      '${r.daysLoaded}d',
    ].join(' · ');
    return CardList(
      children: [
        InkWell(
          onTap: () => context.push(Routes.roll(r.rollId)),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${r.stockBrand} ${r.stockName}',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w500,
                    color: cs.onSurface,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  subtitle,
                  style: TextStyle(fontSize: 13, color: cs.onSurfaceVariant),
                ),
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 9,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: cs.primaryContainer,
                    borderRadius: kCorners,
                  ),
                  child: Text(
                    'In Camera',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 0.5,
                      color: cs.onPrimaryContainer,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
