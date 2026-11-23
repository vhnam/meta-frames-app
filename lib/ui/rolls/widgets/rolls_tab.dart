import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../domain/models/expiry.dart';
import '../../../domain/models/models.dart';
import '../../../domain/models/roll_stage.dart';
import '../../../providers.dart';
import '../../core/theme.dart';
import '../../core/widgets/common.dart';
import '../../film/widgets/stock_picker.dart';
import '../view_models/rolls_view_model.dart';
import '../../../routing/routes.dart';

import 'package:go_router/go_router.dart';

import '../../core/widgets/cards.dart';
import 'roll_card.dart';

/// M-22 browse rolls by stage with filters. Film in stock shows its expiry,
/// so the separate Expiry screen is no longer needed to find film to use up.
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
    // Stage chips narrow [v] on the client. The global empty state is only
    // for an account with no rolls; an empty chip keeps the chips on screen.
    final noRolls =
        !state.filtered &&
        (ref.watch(rollsProvider(state.filter)).value?.isEmpty ?? false);
    final counts = ref.watch(rollCountsProvider);
    final formats = ref.watch(rollFormatsProvider);
    final cs = Theme.of(context).colorScheme;

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
              _StageChips(
                counts: counts,
                selected: state.stage,
                onStage: vm.selectStage,
              ),
            // Only worth a row when there is a choice, or one to undo.
            if (!noRolls && (formats.length > 1 || state.format != null))
              _FormatPills(
                formats: formats,
                selected: state.format,
                onSelected: vm.setFormat,
              ),
            Expanded(
              child: AsyncBody(
                value: v,
                onRefresh: () async =>
                    ref.refresh(rollsProvider(state.filter).future),
                builder: (rs) {
                  if (noRolls) return const _NoRolls();
                  if (rs.isEmpty) return const EmptyState('No rolls here.');
                  final idHints = rollIdHints(rs);
                  return ListView.separated(
                    padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
                    itemCount: rs.length,
                    separatorBuilder: (_, _) => const SizedBox(height: 8),
                    itemBuilder: (_, i) => RollCard(
                      roll: rs[i],
                      process: processes[rs[i].filmStockId],
                      expiring: expiring.contains(rs[i].id),
                      idHint: idHints[rs[i].id],
                      extraBadge:
                          rs[i].status == RollStatus.inStock &&
                              isExpired(rs[i].expiry)
                          ? StampBadge('Expired', color: cs.error)
                          : null,
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
    builder: (_) => const SafeArea(top: false, child: _FilterSheet()),
  );
}

class _FilterSheet extends ConsumerWidget {
  const _FilterSheet();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(rollsViewModelProvider);
    final vm = ref.read(rollsViewModelProvider.notifier);
    final filter = state.filter;
    // Scrolls on a short screen (landscape phone), where the fields and the
    // At lab / Needs scan row are taller than the sheet.
    return SingleChildScrollView(
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
            spacing: 6,
            children: [
              FilterPill(
                label: 'At lab',
                on: state.atLab,
                onTap: () => vm.setAtLab(!state.atLab),
              ),
              FilterPill(
                label: 'Needs scan',
                on: state.needsScan,
                onTap: () => vm.setNeedsScan(!state.needsScan),
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

/// "All 10  In stock 3  In camera 2 ... Completed 4" selectable chips: one per
/// stage. A roll cached without a stage is only under All.
class _StageChips extends StatelessWidget {
  const _StageChips({
    required this.counts,
    required this.selected,
    required this.onStage,
  });
  final RollCounts? counts;
  final RollLifecycleStage? selected;
  final ValueChanged<RollLifecycleStage?> onStage;

  @override
  Widget build(BuildContext context) {
    Widget chip(String label, int? count, bool on, VoidCallback onTap) =>
        FilterPill(
          label: '$label${count == null ? '' : ' $count'}',
          on: on,
          onTap: onTap,
        );

    return SizedBox(
      height: 60,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        children: [
          chip('All', counts?.all, selected == null, () => onStage(null)),
          for (final stage in RollLifecycleStage.values) ...[
            const SizedBox(width: 6),
            chip(
              stageLabel(stage),
              counts?.byStage[stage],
              selected == stage,
              () => onStage(stage),
            ),
          ],
        ],
      ),
    );
  }
}

/// "Any format  135  120" pills from the formats in the list.
class _FormatPills extends StatelessWidget {
  const _FormatPills({
    required this.formats,
    required this.selected,
    required this.onSelected,
  });
  final List<int> formats;
  final int? selected;
  final ValueChanged<int?> onSelected;

  @override
  Widget build(BuildContext context) => SizedBox(
    height: 48,
    child: ListView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
      children: [
        FilterPill(
          label: 'Any format',
          on: selected == null,
          onTap: () => onSelected(null),
        ),
        for (final f in {...formats, ?selected}) ...[
          const SizedBox(width: 6),
          FilterPill(
            label: '$f',
            on: selected == f,
            onTap: () => onSelected(f),
          ),
        ],
      ],
    ),
  );
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
        const EmptyCard(
          icon: Icons.movie_outlined,
          title: 'No rolls yet',
          text: 'Log the film you own, then track each roll from stock to camera, lab and scans.',
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
