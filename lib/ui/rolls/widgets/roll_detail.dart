import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../domain/models/models.dart';
import '../../../domain/models/roll_requests.dart';
import '../../../domain/models/roll_stage.dart';
import '../../../providers.dart';
import '../../core/widgets/cards.dart';
import '../../core/widgets/common.dart';
import '../../sync/view_models/sync_actions.dart';
import '../../sync/widgets/op_status.dart';
import '../view_models/roll_actions.dart';
import 'finish_roll.dart';
import 'frame_notes.dart';
import 'roll_plan_sheet.dart';
import 'roll_processing_choice.dart';
import '../../../routing/routes.dart';

import 'package:go_router/go_router.dart';

/// M-24 roll details; hosts the status-dependent actions (M-19..M-21, M-27, M-31).
class RollDetailScreen extends ConsumerWidget {
  const RollDetailScreen({super.key, required this.rollId});
  final String rollId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final v = ref.watch(rollDetailProvider(rollId));
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
          v.value?.roll.stockLabel ?? 'Roll',
          style: const TextStyle(fontSize: 19, fontWeight: FontWeight.w600),
        ),
        actions: [
          if (v.value != null) ...[
            Padding(
              padding: const EdgeInsets.only(right: 4),
              child: TextButton(
                // The edit replaces the whole roll: it waits until this
                // phone's changes to the roll are on the server, so it never
                // starts from a state the server does not have.
                onPressed: () => ref.read(rollOpsProvider(rollId)).isEmpty
                    ? context.push(Routes.rollEdit(v.value!.roll.id))
                    : toast(
                        context,
                        'This roll has changes waiting to sync. Edit it once they are on the server.',
                      ),
                child: const Text(
                  'Edit',
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
                ),
              ),
            ),
            _Menu(detail: v.value!),
          ],
        ],
      ),
      body: AsyncBody(
        value: v,
        onRefresh: () async => ref.refresh(rollDetailProvider(rollId).future),
        builder: (d) => _Body(detail: d),
      ),
    );
  }
}

/// Details actions that are not a processing step, for the main button and
/// the menu.
const _labels = {
  DetailAction.loadRoll: 'Load into camera',
  DetailAction.logFrame: 'Log frame',
  DetailAction.finish: 'Finish roll',
  DetailAction.markDeveloped: 'Mark as developed',
  DetailAction.returnHandoff: 'Negatives returned',
  DetailAction.returnJob: 'Negatives returned',
  DetailAction.openJob: 'Open job',
  DetailAction.changePlan: 'Change plan',
  DetailAction.markNeedsScan: 'Needs scan',
  DetailAction.unmarkNeedsScan: 'Remove needs scan',
};

/// A day from [first] to today. The server checks the rest, such as a
/// develop date after the negatives came back.
Future<DateTime?> _pickDay(BuildContext context, DateTime? first) {
  final today = DateUtils.dateOnly(DateTime.now());
  final start = first == null ? DateTime(1950) : DateUtils.dateOnly(first);
  return showDatePicker(
    context: context,
    initialDate: today,
    firstDate: start.isAfter(today) ? today : start,
    lastDate: today,
  );
}

/// Runs [action] from the main button or the menu. [jobId] is the job that
/// [DetailAction.openJob] and [DetailAction.returnJob] open.
Future<void> _run(
  BuildContext context,
  WidgetRef ref,
  RollDetail detail,
  DetailAction action,
  String? jobId,
) async {
  final roll = detail.roll;
  final actions = ref.read(rollActionsProvider);
  switch (action) {
    case DetailAction.loadRoll:
      await context.push(Routes.rollLoad(roll.id));
    case DetailAction.logFrame:
      await noteFrame(context, roll.id);
    case DetailAction.finish:
      await finishRoll(context, ref, roll.id, cameraId: roll.cameraId);
    case DetailAction.markDeveloped:
      final date = await _pickDay(
        context,
        developingJob(detail.processing)?.sentAt ?? roll.finishedAt,
      );
      if (date == null || !context.mounted) return;
      await guard(
        context,
        () => actions.markDeveloped(roll.id, DevelopedInput(date: date)),
      );
    case DetailAction.returnHandoff:
      final date = await _pickDay(context, roll.finishedAt);
      if (date == null || !context.mounted) return;
      await guard(
        context,
        () => actions.returnHandoff(roll.openHandoffId!, date),
      );
    // A roll from before handoffs returns its negatives on the job.
    case DetailAction.openJob || DetailAction.returnJob:
      await context.push(Routes.processing(jobId!));
    case DetailAction.changePlan:
      await editPlan(context, detail);
    case DetailAction.markNeedsScan || DetailAction.unmarkNeedsScan:
      await guard(
        context,
        () =>
            actions.setNeedsScan(roll.id, action == DetailAction.markNeedsScan),
      );
    default:
      return;
  }
}

/// The roll's other valid actions, as [detailActions] allows, and the send
/// form that records processing already done.
class _Menu extends ConsumerWidget {
  const _Menu({required this.detail});
  final RollDetail detail;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final roll = detail.roll;
    final jobs = detail.processing;
    final items = <(String, Future<void> Function())>[
      for (final action in detailActions(detail).menu)
        if (_labels[action] case final label?)
          (label, () => _run(context, ref, detail, action, null)),
      if (roll.status == RollStatus.doneShooting && jobs.isEmpty)
        ('Send to lab', () => context.push(Routes.rollSend(roll.id))),
      // A scan again needs the negatives at home: a lab that holds them gives
      // them back first.
      if (jobs.isNotEmpty &&
          sendableTypes(roll.status, jobs.length).isNotEmpty &&
          !roll.negativesAtLab &&
          roll.openHandoffId == null)
        ('Re-scan', () => context.push(Routes.rollSend(roll.id, resend: true))),
    ];
    if (items.isEmpty) return const SizedBox.shrink();
    return PopupMenuButton<Future<void> Function()>(
      tooltip: 'More actions',
      itemBuilder: (_) => [
        for (final (label, run) in items)
          PopupMenuItem(value: run, child: Text(label)),
      ],
      onSelected: (run) => run(),
    );
  }
}

/// The main button for a Details action. It stays locked from
/// the first tap until the action ends, so two fast taps run it once.
class _MainButton extends ConsumerStatefulWidget {
  const _MainButton({
    required this.detail,
    required this.action,
    required this.jobId,
  });
  final RollDetail detail;
  final DetailAction action;
  final String? jobId;

  @override
  ConsumerState<_MainButton> createState() => _MainButtonState();
}

class _MainButtonState extends ConsumerState<_MainButton> {
  bool _busy = false;

  Future<void> _start() async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      await _run(context, ref, widget.detail, widget.action, widget.jobId);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => FilledButton.icon(
    style: FilledButton.styleFrom(padding: const EdgeInsets.all(16)),
    icon: Icon(switch (widget.action) {
      DetailAction.loadRoll => Icons.photo_camera_outlined,
      DetailAction.logFrame => Icons.edit_note,
      _ => Icons.science_outlined,
    }),
    label: Text(_labels[widget.action]!),
    onPressed: _busy ? null : _start,
  );
}

class _Body extends ConsumerWidget {
  const _Body({required this.detail});
  final RollDetail detail;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final r = detail.roll;
    final cam = r.cameraId == null
        ? null
        : ref.watch(cameraProvider(r.cameraId!)).value;
    final jobs = [...detail.processing]
      ..sort((a, b) => a.sentAt.compareTo(b.sentAt));
    final cs = Theme.of(context).colorScheme;
    final canManageLenses =
        r.status == RollStatus.inCamera && cam != null && !cam.hasFixedLens;
    final (:primary, :jobId, menu: _) = detailActions(detail);
    final processing = primary == null ? null : processingLabel(primary);
    final actions = [
      if (processing != null)
        ProcessingButton(detail: detail, action: primary!, label: processing)
      else if (_labels.containsKey(primary))
        _MainButton(detail: detail, action: primary!, jobId: jobId),
    ];
    final notes = r.description?.trim() ?? '';
    final ops = ref.watch(rollOpsProvider(r.id));

    final rollBlock = <Widget>[
      const DetailLabel('ROLL', top: 0),
      CardList(
        children: [
          _StockRow(detail: detail),
          if (r.negativesAtLab) const DetailInfoRow('Negatives', 'At lab'),
          DetailInfoRow('Format', '${r.format}'),
          DetailInfoRow('Exposures', '${r.exposures}'),
          DetailInfoRow('Price', fmtVnd(r.price)),
          DetailInfoRow('Expiry', r.expiry?.toString()),
          DetailInfoRow(
            'Shot ISO',
            r.shotIso?.toString() ?? 'Box (${detail.stock.boxIso})',
          ),
          DetailInfoRow('Started', fmtDate(r.startedAt)),
          DetailInfoRow('Finished', fmtDate(r.finishedAt)),
        ],
      ),
    ];
    final notesBlock = <Widget>[
      DetailLabel(
        'NOTES',
        trailing: TextButton(
          style: TextButton.styleFrom(
            minimumSize: const Size(0, 32),
            padding: const EdgeInsets.symmetric(horizontal: 8),
          ),
          onPressed: () => context.push(Routes.rollNotes(r.id)),
          child: Text(
            notes.isEmpty ? 'Add notes' : 'Edit',
            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
          ),
        ),
      ),
      Text(
        notes.isEmpty ? 'Subject, location, conditions, incidents.' : notes,
        style: TextStyle(
          fontSize: 14,
          color: notes.isEmpty ? cs.onSurfaceVariant : cs.onSurface,
        ),
      ),
    ];
    final gearBlock = <Widget>[
      if (r.cameraId != null ||
          detail.lenses.isNotEmpty ||
          canManageLenses) ...[
        const DetailLabel('GEAR'),
        CardList(
          children: [
            if (r.cameraId != null)
              CardTile(
                compact: true,
                leading: Icon(
                  Icons.photo_camera_outlined,
                  size: 20,
                  color: cs.onSurfaceVariant,
                ),
                title: r.cameraName ?? 'Camera',
                subtitle: 'Camera',
                trailing: Icon(
                  Icons.chevron_right,
                  size: 20,
                  color: cs.onSurfaceVariant,
                ),
                onTap: () => context.push(Routes.camera(r.cameraId!)),
              ),
            for (final l in detail.lenses)
              CardTile(
                compact: true,
                leading: Icon(
                  Icons.adjust,
                  size: 20,
                  color: cs.onSurfaceVariant,
                ),
                title: l.name,
                subtitle: 'Lens',
              ),
          ],
        ),
        if (canManageLenses) ...[
          const SizedBox(height: 8),
          DashedButton(
            label: 'Manage lenses',
            onTap: () => context.push(Routes.rollLenses(r.id)),
          ),
        ],
      ],
    ];
    final costBlock = <Widget>[
      const DetailLabel('COST'),
      CardList(
        children: [
          DetailInfoRow('Film', fmtVnd(detail.totals.rollPrice)),
          DetailInfoRow('Processing', fmtVnd(detail.totals.processingPrice)),
          DetailInfoRow(
            'Total',
            '${fmtVnd(detail.totals.total)}${detail.totals.incomplete ? ' (incomplete)' : ''}',
            bold: true,
          ),
        ],
      ),
    ];
    final historyBlock = <Widget>[
      const DetailLabel('PROCESSING HISTORY'),
      if (jobs.isEmpty)
        Text(
          'Not sent yet',
          style: TextStyle(fontSize: 13, color: cs.onSurfaceVariant),
        )
      else
        CardList(
          children: [
            for (final j in jobs)
              CardTile(
                compact: true,
                title: '${j.where} · ${j.type.label}',
                subtitle: [
                  j.process.wire,
                  'sent ${fmtDate(j.sentAt)}',
                  if (j.scansReceivedAt != null)
                    'scans ${fmtDate(j.scansReceivedAt)}',
                  if (j.negativesReturnedAt != null)
                    'negatives ${fmtDate(j.negativesReturnedAt)}',
                  if (j.scanners.isNotEmpty)
                    j.scanners.map((s) => s.label).join('+'),
                  if (j.price != null) fmtVnd(j.price),
                  if (j.notes != null) j.notes!,
                ].join(' · '),
                badge: j.isOpen
                    ? StampBadge('Open', color: cs.onPrimaryContainer)
                    : null,
                onTap: () => context.push(Routes.processing(j.id)),
              ),
          ],
        ),
    ];
    final framesBlock = <Widget>[
      DetailLabel(
        'FRAMES',
        trailing: TextButton(
          style: TextButton.styleFrom(
            minimumSize: const Size(0, 32),
            padding: const EdgeInsets.symmetric(horizontal: 8),
          ),
          onPressed: () => noteFrame(context, r.id),
          child: const Text(
            'Add notes',
            style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
          ),
        ),
      ),
      if (detail.frames.isEmpty)
        Text(
          'No frames yet. Add notes, or import scans in the dashboard.',
          style: TextStyle(fontSize: 13, color: cs.onSurfaceVariant),
        )
      else
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final f in detail.frames)
              ActionChip(
                label: Text(
                  '#${f.number}${f.scans.isEmpty ? '' : ' · ${f.scans.length}'}',
                ),
                avatar: f.notes == null
                    ? null
                    : const Icon(Icons.notes, size: 14),
                onPressed: () => context.push(Routes.frame(r.id, f.number)),
              ),
          ],
        ),
    ];
    // In a camera, frames and notes come before the history; while it is
    // processed, the jobs come first (where the negatives are is in the roll
    // card).
    final order = switch (r.stage) {
      RollLifecycleStage.inCamera => [
        rollBlock,
        framesBlock,
        notesBlock,
        gearBlock,
        historyBlock,
        costBlock,
      ],
      RollLifecycleStage.processing => [
        rollBlock,
        historyBlock,
        notesBlock,
        framesBlock,
        gearBlock,
        costBlock,
      ],
      _ => [
        rollBlock,
        notesBlock,
        gearBlock,
        costBlock,
        historyBlock,
        framesBlock,
      ],
    };
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        WarningBanner(detail.warnings),
        for (final op in ops) ...[
          OpStatusCard(op: op),
          const SizedBox(height: 8),
        ],
        // The main action comes first, one tap from the top of the page.
        for (final a in actions) ...[
          SizedBox(width: double.infinity, child: a),
          const SizedBox(height: 20),
        ],
        for (final block in order) ...block,
        const SizedBox(height: 16),
      ],
    );
  }
}

/// The roll's stock and status. The status sits under the names, so a long name
/// has the card's full width.
class _StockRow extends StatelessWidget {
  const _StockRow({required this.detail});
  final RollDetail detail;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final stock = detail.stock;
    final base = detail.baseStock;
    return InkWell(
      onTap: () => context.push(Routes.stock(stock.id)),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Row(
          spacing: 12,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    stock.label,
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: cs.onSurface,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    base == null
                        ? 'ISO ${stock.boxIso} · ${stock.process.wire}'
                        : 'Base: ${base.label}',
                    style: TextStyle(fontSize: 13, color: cs.onSurfaceVariant),
                  ),
                  const SizedBox(height: 10),
                  // The same one label as the roll's card in the list.
                  StampBadge(
                    rollStageLabel(detail.roll),
                    color: statusTone(context, detail.roll.status),
                  ),
                ],
              ),
            ),
            Icon(Icons.chevron_right, size: 20, color: cs.onSurfaceVariant),
          ],
        ),
      ),
    );
  }
}
