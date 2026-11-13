import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../domain/models/models.dart';
import '../../../providers.dart';
import '../../core/widgets/common.dart';
import '../../labs/widgets/send_roll.dart';
import '../view_models/roll_actions.dart';

/// The Details button for the next processing step [action]. It stays
/// locked from the first tap until the flow ends, so a second tap while the
/// scanner list loads cannot open a second form.
class ProcessingButton extends ConsumerStatefulWidget {
  const ProcessingButton({
    super.key,
    required this.detail,
    required this.action,
    required this.label,
  });
  final RollDetail detail;
  final DetailAction action;
  final String label;

  @override
  ConsumerState<ProcessingButton> createState() => _ProcessingButtonState();
}

class _ProcessingButtonState extends ConsumerState<ProcessingButton> {
  bool _busy = false;

  Future<void> _start() async {
    // The old onPressed stays live until the next build.
    if (_busy) return;
    setState(() => _busy = true);
    try {
      await startProcessing(context, ref, widget.detail, widget.action);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => FilledButton.icon(
    style: FilledButton.styleFrom(padding: const EdgeInsets.all(16)),
    icon: const Icon(Icons.science_outlined),
    label: Text(widget.label),
    onPressed: _busy ? null : _start,
  );
}

/// The Details main button for the next processing step, or null when the
/// main action is not one of these.
String? processingLabel(DetailAction action) => switch (action) {
  DetailAction.choosePlan => 'Develop',
  DetailAction.chooseScanPlace => 'Scan',
  DetailAction.startHomeDevelop => 'Start developing at home',
  DetailAction.startHomeScan => 'Start scanning at home',
  DetailAction.handToLab => 'Hand to lab',
  _ => null,
};

/// Runs a processing [action] from roll Details. When the plan does not say
/// where the step is done ([DetailAction.choosePlan],
/// [DetailAction.chooseScanPlace]), a sheet asks first; then the send form
/// opens in the matching mode with the service the roll needs.
Future<void> startProcessing(
  BuildContext context,
  WidgetRef ref,
  RollDetail detail,
  DetailAction action,
) async {
  final roll = detail.roll;
  // A home develop needs a finished roll with no job that no lab holds; when
  // it cannot start, a lab is the only place, so there is nothing to ask.
  if (action == DetailAction.choosePlan &&
      !canStartHomeDevelop(
        roll.status,
        detail.processing,
        negativesAtLab: roll.negativesAtLab,
      )) {
    action = DetailAction.handToLab;
  }
  // A home scan needs a scanner of the user's own; with only lab scanners a
  // lab is the only place. When the list cannot load, the sheet still asks.
  if (action == DetailAction.chooseScanPlace) {
    // Keeps the auto-disposed list alive while it loads.
    final keep = ref.listenManual(scannersProvider, (_, _) {});
    final ownScanner = await ref
        .read(scannersProvider.future)
        .then(
          (scanners) => scanners.any((device) => !device.builtIn),
          onError: (_) => true,
        );
    keep.close();
    if (!context.mounted) return;
    if (!ownScanner) action = DetailAction.handToLab;
  }
  final scan = action == DetailAction.chooseScanPlace;
  if (action == DetailAction.choosePlan ||
      action == DetailAction.chooseScanPlace) {
    final atHome = await pickOne<bool>(
      context,
      title: 'How is it processed?',
      items: const [true, false],
      label: (home) => switch ((scan, home)) {
        (false, true) => 'Develop at home',
        (false, false) => 'Hand to a lab',
        (true, true) => 'Scan at home',
        (true, false) => 'Scan at a lab',
      },
    );
    if (atHome == null || !context.mounted) return;
    action = !atHome
        ? DetailAction.handToLab
        : scan
        ? DetailAction.startHomeScan
        : DetailAction.startHomeDevelop;
  }
  final develops = roll.stage == RollLifecycleStage.doneShooting;
  final (mode, types, type) = switch (action) {
    DetailAction.startHomeDevelop => (
      SendMode.startAtHome,
      const [ProcessingType.develop, ProcessingType.developScan],
      ProcessingType.develop,
    ),
    DetailAction.startHomeScan => (
      SendMode.startAtHome,
      const [ProcessingType.scan],
      ProcessingType.scan,
    ),
    // As the dashboard hand-over: develop only when the plan stops there or
    // scans at home; a developed roll goes for a scan.
    _ when develops => (
      SendMode.handToLab,
      const [ProcessingType.developScan, ProcessingType.develop],
      roll.plan?.target == PlanTarget.developed ||
              roll.plan?.scanBy == StepActor.self
          ? ProcessingType.develop
          : ProcessingType.developScan,
    ),
    _ => (SendMode.handToLab, const [ProcessingType.scan], ProcessingType.scan),
  };
  await Navigator.of(context).push(
    MaterialPageRoute<void>(
      builder: (_) => SendRollScreen(
        roll: roll,
        stock: detail.stock,
        types: types,
        type: type,
        mode: mode,
      ),
    ),
  );
}
