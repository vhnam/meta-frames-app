import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../data/services/api_client.dart';
import '../../../domain/models/models.dart';
import '../view_models/roll_actions.dart';

/// Opens the plan of [detail]'s roll in a sheet, filled with the saved plan.
/// Save sends it online; on an error the sheet stays open with the input and
/// shows the server's reason.
Future<void> editPlan(BuildContext context, RollDetail detail) =>
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => SafeArea(
        top: false,
        child: _PlanSheet(
          rollId: detail.roll.id,
          plan: detail.roll.plan ?? const RollPlan(),
        ),
      ),
    );

class _PlanSheet extends ConsumerStatefulWidget {
  const _PlanSheet({required this.rollId, required this.plan});
  final String rollId;
  final RollPlan plan;

  @override
  ConsumerState<_PlanSheet> createState() => _PlanSheetState();
}

class _PlanSheetState extends ConsumerState<_PlanSheet> {
  late PlanTarget? _target = widget.plan.target;
  late StepActor? _developBy = widget.plan.developBy;
  late StepActor? _scanBy = widget.plan.scanBy;
  bool _saving = false;
  String? _error;

  Future<void> _save() async {
    if (_saving) return;
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      await ref
          .read(rollActionsProvider)
          .setPlan(
            widget.rollId,
            RollPlan(
              target: _target,
              developBy: _developBy,
              // The server refuses a scanner on a develop-only plan.
              scanBy: _target == PlanTarget.developed ? null : _scanBy,
            ),
          );
      if (mounted) Navigator.of(context).pop();
    } on ApiException catch (error) {
      if (mounted) setState(() => _error = error.message);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    const actors = {StepActor.self: 'At home', StepActor.lab: 'Lab'};
    return SingleChildScrollView(
      padding: EdgeInsets.fromLTRB(
        16,
        0,
        16,
        16 + MediaQuery.of(context).viewInsets.bottom,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text('Plan', style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 16),
          _Choice<PlanTarget>(
            label: 'Goal',
            value: _target,
            options: const {
              PlanTarget.developed: 'Develop only',
              PlanTarget.scanned: 'Develop + scan',
            },
            onChanged: (value) => setState(() => _target = value),
          ),
          _Choice<StepActor>(
            label: 'Develop by',
            value: _developBy,
            options: actors,
            onChanged: (value) => setState(() => _developBy = value),
          ),
          _Choice<StepActor>(
            label: 'Scan by',
            value: _target == PlanTarget.developed ? null : _scanBy,
            options: actors,
            onChanged: _target == PlanTarget.developed
                ? null
                : (value) => setState(() => _scanBy = value),
          ),
          if (_error case final error?)
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Text(
                error,
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
            ),
          FilledButton(
            onPressed: _saving ? null : _save,
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }
}

/// A plan field; the empty entry is "Not decided".
class _Choice<T> extends StatelessWidget {
  const _Choice({
    required this.label,
    required this.value,
    required this.options,
    required this.onChanged,
  });
  final String label;
  final T? value;
  final Map<T, String> options;
  final ValueChanged<T?>? onChanged;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 16),
    child: DropdownButtonFormField<T?>(
      key: ValueKey(value),
      initialValue: value,
      decoration: InputDecoration(labelText: label),
      items: [
        DropdownMenuItem<T?>(value: null, child: const Text('Not decided')),
        for (final MapEntry(:key, value: text) in options.entries)
          DropdownMenuItem<T?>(value: key, child: Text(text)),
      ],
      onChanged: onChanged,
    ),
  );
}
