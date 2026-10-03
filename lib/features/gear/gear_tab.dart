import 'package:flutter/material.dart';

import '../../core/theme.dart';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/models.dart';
import '../../providers.dart';
import '../../widgets/cards.dart';
import '../../widgets/common.dart';
import 'camera_detail.dart';
import 'camera_form.dart';
import 'lens_detail.dart';
import 'lens_form.dart';

class GearTab extends ConsumerStatefulWidget {
  const GearTab({super.key});
  @override
  ConsumerState<GearTab> createState() => _State();
}

class _State extends ConsumerState<GearTab> {
  bool lenses = false;
  bool showInactive = false;

  void _add() => Navigator.push(
    context,
    MaterialPageRoute(
      builder: (_) =>
          lenses ? const LensFormScreen() : const CameraFormScreen(),
    ),
  );

  /// Contextual label while the current tab has no data, as in the empty design.
  String _addLabel = '+ Add';

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Scaffold(
      backgroundColor: cs.surface,
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            ScreenHeader(
              kicker: 'MetaFrames · Gear locker',
              title: 'Gear',
              trailing: TextButton(onPressed: _add, child: Text(_addLabel)),
            ),
            _Switcher(
              lenses: lenses,
              onChanged: (v) => setState(() => lenses = v),
            ),
            Expanded(child: lenses ? _lenses() : _cameras()),
          ],
        ),
      ),
    );
  }

  /// Active list in a card plus a collapsible inactive section.
  Widget _body<T>({
    required List<T> all,
    required bool Function(T) isActive,
    required Widget Function(T, bool inactive) tile,
    required IconData emptyIcon,
    required String emptyTitle,
    required String emptyText,
    required String addLabel,
    required String noneActiveText,
    required Future<void> Function() onRefresh,
  }) {
    final active = all.where(isActive).toList();
    final inactive = all.where((e) => !isActive(e)).toList();
    final onlyInactive = active.isEmpty && inactive.isNotEmpty;
    final expanded = onlyInactive || showInactive;
    final label = active.isEmpty ? addLabel : '+ Add';
    if (label != _addLabel) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) setState(() => _addLabel = label);
      });
    }
    return RefreshIndicator(
      onRefresh: onRefresh,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
        children: [
          _Label('ACTIVE · ${active.length}'),
          const SizedBox(height: 8),
          if (active.isEmpty)
            _EmptyCard(
              icon: emptyIcon,
              title: onlyInactive
                  ? emptyTitle
                        .replaceFirst('No ', 'No active ')
                        .replaceFirst(' yet', '')
                  : emptyTitle,
              text: onlyInactive ? noneActiveText : emptyText,
            )
          else
            CardList(children: [for (final e in active) tile(e, false)]),
          if (inactive.isNotEmpty) ...[
            const SizedBox(height: 16),
            InkWell(
              onTap: onlyInactive
                  ? null
                  : () => setState(() => showInactive = !showInactive),
              child: Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: _Label(
                  '${onlyInactive ? '' : '${expanded ? '▾' : '▸'} '}INACTIVE · ${inactive.length}',
                ),
              ),
            ),
            if (expanded)
              CardList(children: [for (final e in inactive) tile(e, true)]),
          ],
        ],
      ),
    );
  }

  Widget _cameras() => AsyncBody(
    value: ref.watch(camerasProvider),
    onRefresh: () async => ref.refresh(camerasProvider.future),
    builder: (cams) => _body<Camera>(
      all: cams,
      isActive: (c) => c.isActive,
      emptyIcon: Icons.camera_outlined,
      emptyTitle: 'No cameras yet',
      emptyText: 'Tap the button below to add your first camera body.',
      addLabel: '+ Camera',
      noneActiveText: 'Your inactive cameras are kept below for your roll history. Add a new camera with + Camera.',
      onRefresh: () async => ref.refresh(camerasProvider.future),
      tile: _cameraTile,
    ),
  );

  Widget _cameraTile(Camera cam, bool inactive) {
    final cs = Theme.of(context).colorScheme;
    final r = cam.loadedRoll;
    final first = cam.hasFixedLens ? 'Fixed lens' : '${cam.mount ?? '—'} mount';
    return CardTile(
      icon: cam.hasFixedLens && r == null
          ? Icons.camera_outlined
          : Icons.photo_camera,
      iconSize: inactive ? 40 : 44,
      iconBg: inactive ? cs.surface : (r == null ? cs.surfaceContainer : null),
      iconColor: inactive || r == null ? cs.onSurfaceVariant : null,
      title: cam.name,
      subtitle: inactive
          ? first
          : '$first · ${r == null ? 'Empty' : '${r.stockBrand} ${r.stockName}'}',
      padding: EdgeInsets.symmetric(
        horizontal: 16,
        vertical: inactive ? 12 : 14,
      ),
      dim: inactive,
      compact: inactive,
      badge: inactive
          ? const _InactiveTag()
          : (r == null ? null : const _StatusBadge('In Camera')),
      trailing: inactive || r == null
          ? Icon(Icons.chevron_right, color: cs.onSurfaceVariant)
          : null,
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => CameraDetailScreen(cameraId: cam.id)),
      ),
    );
  }

  Widget _lenses() => AsyncBody(
    value: ref.watch(lensesProvider),
    onRefresh: () async => ref.refresh(lensesProvider.future),
    builder: (all) => _body<Lens>(
      all: [...all]..sort((a, b) => a.focalLength - b.focalLength),
      isActive: (l) => l.isActive,
      emptyIcon: Icons.adjust,
      emptyTitle: 'No lenses yet',
      emptyText: 'Tap the button below to add interchangeable lenses and link them to your cameras.',
      addLabel: '+ Lens',
      noneActiveText: 'Your inactive lenses are kept below for your roll history. Add a new lens with + Lens.',
      onRefresh: () async => ref.refresh(lensesProvider.future),
      tile: _lensTile,
    ),
  );

  Widget _lensTile(Lens l, bool inactive) {
    final cs = Theme.of(context).colorScheme;
    final aperture = l.maxAperture.toStringAsFixed(
      l.maxAperture % 1 == 0 ? 0 : 1,
    );
    final title = [
      l.brand,
      l.model,
    ].where((e) => e != null && e.isNotEmpty).join(' ');
    return CardTile(
      icon: Icons.adjust,
      iconSize: inactive ? 40 : 44,
      iconBg: inactive ? cs.surface : cs.surfaceContainer,
      iconColor: cs.onSurfaceVariant,
      dim: inactive,
      compact: inactive,
      badge: inactive ? const _InactiveTag() : null,
      title: title.isEmpty ? l.name : title,
      subtitle:
          '${l.focalLength}mm · f/$aperture · ${l.isBuiltIn ? 'Built-in' : '${l.mount ?? '—'} mount'}',
      padding: EdgeInsets.symmetric(
        horizontal: 16,
        vertical: inactive ? 12 : 14,
      ),
      trailing: Icon(Icons.chevron_right, color: cs.onSurfaceVariant),
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => LensDetailScreen(lensId: l.id)),
      ),
    );
  }
}

class _Switcher extends StatelessWidget {
  const _Switcher({required this.lenses, required this.onChanged});
  final bool lenses;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    Widget seg(String label, bool value) {
      final on = lenses == value;
      return Expanded(
        child: GestureDetector(
          onTap: () => onChanged(value),
          child: Container(
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: on ? cs.surface : null,
              borderRadius: kCorners,
              border: on
                  ? Border.all(color: cs.outline, width: kHairline)
                  : null,
            ),
            child: Text(
              label,
              style: TextStyle(
                fontSize: 14,
                fontWeight: on ? FontWeight.w600 : FontWeight.w400,
                color: on ? cs.onSurface : cs.onSurfaceVariant,
              ),
            ),
          ),
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(color: cs.outlineVariant, width: 0.65),
        ),
      ),
      child: Container(
        height: 45,
        padding: const EdgeInsets.all(4),
        decoration: BoxDecoration(
          color: cs.surfaceContainerHighest,
          borderRadius: kCorners,
        ),
        child: Row(
          children: [
            seg('Cameras', false),
            const SizedBox(width: 2),
            seg('Lenses', true),
          ],
        ),
      ),
    );
  }
}

class _Label extends StatelessWidget {
  const _Label(this.text);
  final String text;
  @override
  Widget build(BuildContext context) => Text(
    text.toUpperCase(),
    style: monoStyle(
      fontWeight: FontWeight.w600,
      letterSpacing: 1.6,
      color: Theme.of(context).colorScheme.onSurfaceVariant,
    ),
  );
}

class _StatusBadge extends StatelessWidget {
  const _StatusBadge(this.text);
  final String text;
  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 2),
      decoration: BoxDecoration(
        color: cs.primaryContainer,
        borderRadius: BorderRadius.circular(kStampRadius),
        border: Border.all(color: cs.onPrimaryContainer, width: kHairline),
      ),
      child: Text(
        text.toUpperCase(),
        style: monoStyle(
          fontSize: 10.5,
          fontWeight: FontWeight.w600,
          letterSpacing: 1.0,
          color: cs.onPrimaryContainer,
        ),
      ),
    );
  }
}

class _EmptyCard extends StatelessWidget {
  const _EmptyCard({
    required this.icon,
    required this.title,
    required this.text,
  });
  final IconData icon;
  final String title, text;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
      decoration: BoxDecoration(
        borderRadius: kCorners,
        border: Border.all(color: cs.outline, width: kHairline),
      ),
      child: Column(
        children: [
          Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              color: cs.surfaceContainer,
              borderRadius: kCorners,
            ),
            child: Icon(icon, size: 24, color: cs.onSurfaceVariant),
          ),
          const SizedBox(height: 12),
          Text(
            title,
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w500,
              color: cs.onSurface,
            ),
          ),
          const SizedBox(height: 10),
          SizedBox(
            width: 240,
            child: Text(
              text,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 13,
                height: 1.5,
                color: cs.onSurfaceVariant,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _InactiveTag extends StatelessWidget {
  const _InactiveTag();
  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: cs.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(kStampRadius),
      ),
      child: Text(
        'INACTIVE',
        style: monoStyle(
          fontSize: 10.5,
          fontWeight: FontWeight.w600,
          color: cs.onSurfaceVariant,
        ),
      ),
    );
  }
}
