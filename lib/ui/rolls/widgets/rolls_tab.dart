import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../domain/models/models.dart';
import '../../../providers.dart';
import '../../core/theme.dart';
import '../../core/widgets/common.dart';
import '../../film/widgets/stock_picker.dart';
import '../view_models/rolls_view_model.dart';
import '../../../routing/routes.dart';

import 'package:go_router/go_router.dart';

/// M-22 browse rolls by status with filters.
class RollsTab extends ConsumerWidget {
  const RollsTab({super.key});

  void _add(BuildContext context) => context.push(Routes.rollNew());

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(rollsViewModelProvider);
    final vm = ref.read(rollsViewModelProvider.notifier);
    final v = ref.watch(visibleRollsProvider);
    final processes = ref.watch(stockProcessByIdProvider);
    final expiring = ref.watch(expiringRollIdsProvider);
    final noRolls = !state.filtered && (v.value?.isEmpty ?? false);
    final counts = ref.watch(rollStatusCountsProvider);

    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            ScreenHeader(
              kicker: 'MetaFrames · Roll log',
              title: 'Rolls',
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (!noRolls)
                    IconButton(
                      tooltip: 'Filter',
                      icon: Badge(
                        isLabelVisible: state.filtered,
                        child: const Icon(Icons.filter_list),
                      ),
                      onPressed: () => _openFilter(context),
                    ),
                  TextButton(
                    onPressed: () => _add(context),
                    child: Text(noRolls ? '+ Roll' : '+ Add'),
                  ),
                ],
              ),
            ),
            if (!noRolls)
              _StatusChips(
                counts: counts,
                selected: state.status,
                onSelected: vm.selectStatus,
              ),
            Expanded(
              child: AsyncBody(
                value: v,
                onRefresh: () async =>
                    ref.refresh(rollsProvider(state.filter).future),
                builder: (rs) {
                  if (noRolls) return const _NoRolls();
                  if (rs.isEmpty) return const EmptyState('No rolls here.');
                  return ListView.separated(
                    padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
                    itemCount: rs.length,
                    separatorBuilder: (_, _) => const SizedBox(height: 8),
                    itemBuilder: (_, i) => _RollCard(
                      roll: rs[i],
                      process: processes[rs[i].filmStockId],
                      expiring: expiring.contains(rs[i].id),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _openFilter(BuildContext context) => showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (_) => const _FilterSheet(),
  );
}

class _FilterSheet extends ConsumerWidget {
  const _FilterSheet();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(rollsViewModelProvider);
    final vm = ref.read(rollsViewModelProvider.notifier);
    final filter = state.filter;
    return Padding(
      padding: EdgeInsets.fromLTRB(
        16,
        0,
        16,
        16 + MediaQuery.of(context).viewInsets.bottom,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        spacing: 12,
        children: [
          PickerField(
            label: 'Film stock',
            value: state.stockLabel,
            onTap: () async {
              final s = await pickStock(context, ref);
              if (s != null) vm.setStock(s);
            },
            onClear: () => vm.setStock(null),
          ),
          PickerField(
            label: 'Camera',
            value: state.cameraLabel,
            onTap: () async {
              final cams = await ref.read(camerasProvider.future);
              if (!context.mounted) return;
              final x = await pickOne<Camera>(
                context,
                title: 'Camera',
                items: cams,
                label: (e) => e.name,
              );
              if (x != null) vm.setCamera(x);
            },
            onClear: () => vm.setCamera(null),
          ),
          PickerField(
            label: 'Lens',
            value: state.lensLabel,
            onTap: () async {
              final ls = await ref.read(lensesProvider.future);
              if (!context.mounted) return;
              final x = await pickOne<Lens>(
                context,
                title: 'Lens',
                items: ls,
                label: (e) => e.name,
              );
              if (x != null) vm.setLens(x);
            },
            onClear: () => vm.setLens(null),
          ),
          DropdownButtonFormField<int?>(
            initialValue: filter.format,
            decoration: deco('Format'),
            items: const [
              DropdownMenuItem(value: null, child: Text('Any')),
              DropdownMenuItem(value: 135, child: Text('135')),
              DropdownMenuItem(value: 120, child: Text('120')),
              DropdownMenuItem(value: 220, child: Text('220')),
            ],
            onChanged: vm.setFormat,
          ),
          Row(
            spacing: 12,
            children: [
              Expanded(
                child: DateField(
                  label: 'Started from',
                  value: filter.from,
                  clearable: true,
                  onChanged: vm.setFrom,
                ),
              ),
              Expanded(
                child: DateField(
                  label: 'Started to',
                  value: filter.to,
                  clearable: true,
                  onChanged: vm.setTo,
                ),
              ),
            ],
          ),
          Row(
            children: [
              TextButton(
                onPressed: vm.clearFilters,
                child: const Text('Clear all'),
              ),
              const Spacer(),
              FilledButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Done'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// "All (10)  In stock (3)  In camera (2) ..." selectable chips.
class _StatusChips extends StatelessWidget {
  const _StatusChips({
    required this.counts,
    required this.selected,
    required this.onSelected,
  });
  final Map<RollStatus?, int>? counts;
  final RollStatus? selected;
  final ValueChanged<RollStatus?> onSelected;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    Widget chip(String label, RollStatus? value, int? count) {
      final on = selected == value;
      final color = on ? cs.onPrimaryContainer : cs.onSurfaceVariant;
      return Semantics(
        button: true,
        selected: on,
        child: InkWell(
          borderRadius: kCorners,
          onTap: () => onSelected(value),
          child: Container(
            constraints: const BoxConstraints(minHeight: 40),
            padding: const EdgeInsets.symmetric(horizontal: 14),
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: on ? cs.primaryContainer : null,
              borderRadius: kCorners,
              border: Border.all(
                color: on ? cs.onPrimaryContainer : cs.outlineVariant,
                width: kHairline,
              ),
            ),
            child: Text(
              '${label.toUpperCase()}${count == null ? '' : ' $count'}',
              style: monoStyle(
                fontSize: 11.5,
                fontWeight: on ? FontWeight.w700 : FontWeight.w500,
                letterSpacing: 1.0,
                color: color,
              ),
            ),
          ),
        ),
      );
    }

    int? count(RollStatus? s) => counts?[s];

    return SizedBox(
      height: 60,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        children: [
          chip('All', null, count(null)),
          for (final s in RollStatus.values) ...[
            const SizedBox(width: 6),
            chip(s.label, s, count(s)),
          ],
        ],
      ),
    );
  }
}

/// One roll: status-tinted icon, name, meta line, status + process stamps.
class _RollCard extends StatelessWidget {
  const _RollCard({
    required this.roll,
    required this.process,
    required this.expiring,
  });
  final RollSummary roll;
  final Process? process;
  final bool expiring;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tone = statusTone(context, roll.status);
    final meta = [
      '${roll.format} · ${roll.exposures} exp',
      if (roll.cameraName != null) roll.cameraName!,
      if (roll.shotIso != null) 'ISO ${roll.shotIso}',
      if (roll.startedAt != null) fmtDate(roll.startedAt),
      if (roll.expiry != null && roll.status == RollStatus.inStock)
        'exp ${roll.expiry}',
    ].join(' · ');
    return Material(
      color: cs.surfaceContainerLow,
      shape: RoundedRectangleBorder(
        borderRadius: kCorners,
        side: BorderSide(
          color: expiring ? cs.error.withValues(alpha: 0.5) : cs.outlineVariant,
          width: kHairline,
        ),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => context.push(Routes.roll(roll.id)),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: tone.withValues(alpha: 0.1),
                  borderRadius: kCorners,
                  border: Border.all(
                    color: tone.withValues(alpha: 0.5),
                    width: kHairline,
                  ),
                ),
                child: Icon(Icons.movie_outlined, size: 22, color: tone),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      roll.stockLabel,
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      meta,
                      style: monoStyle(
                        letterSpacing: 0.2,
                        fontSize: 12,
                        color: cs.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 6,
                      runSpacing: 4,
                      children: [
                        StatusChip(roll.status),
                        if (process != null) ProcessBadge(process!),
                        if (roll.negativesAtLab)
                          StampBadge(
                            'Negatives at lab',
                            color: cs.onPrimaryContainer,
                          ),
                      ],
                    ),
                  ],
                ),
              ),
              if (expiring) ...[
                const SizedBox(width: 8),
                Tooltip(
                  message: 'Expiring soon',
                  child: Icon(Icons.warning_rounded, size: 18, color: cs.error),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// Shown on every chip when the user has logged no rolls at all. Same card
/// as the Gear empty state; the add action lives in the header.
class _NoRolls extends StatelessWidget {
  const _NoRolls();

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
      children: [
        Container(
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
                child: Icon(
                  Icons.movie_outlined,
                  size: 24,
                  color: cs.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                'No rolls yet',
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
                  'Log the film you own, then track each roll from stock to camera, lab and scans.',
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
        ),
        const SizedBox(height: 20),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.info_outline, size: 16, color: cs.onSurfaceVariant),
            const SizedBox(width: 6),
            Flexible(
              child: Text(
                'Tip: add a camera in Gear to load rolls into it.',
                style: monoStyle(
                  fontSize: 11.5,
                  letterSpacing: 0.2,
                  color: cs.onSurfaceVariant,
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }
}
