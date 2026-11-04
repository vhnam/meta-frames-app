import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../domain/models/models.dart';
import '../../../providers.dart';
import '../../../routing/navigation.dart';
import '../../core/widgets/cards.dart';
import '../../core/widgets/common.dart';
import '../../core/widgets/form_kit.dart';
import '../view_models/lab_order_actions.dart';
import 'order_lines_picker.dart';

/// Puts a roll on the lines of an order. A roll must be sent to the lab first,
/// because a job needs a service and scanners that an order does not hold.
class AddRollToOrderScreen extends ConsumerStatefulWidget {
  const AddRollToOrderScreen({super.key, required this.order, this.lineId});
  final LabOrder order;

  /// The line this was opened from: it starts ticked.
  final String? lineId;
  @override
  ConsumerState<AddRollToOrderScreen> createState() => _State();
}

class _State extends ConsumerState<AddRollToOrderScreen> {
  LabOrderJob? _job;
  late List<String> _lineIds = _startingLines();
  String? _rollError, _linesError;
  bool _busy = false;

  /// The line it was opened from, or the only line with room.
  List<String> _startingLines() {
    if (widget.lineId != null) return [widget.lineId!];
    final open = widget.order.lines.where((l) => l.room > 0).toList();
    return open.length == 1 ? [open.first.id] : const [];
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final order = widget.order;
    final jobs = ref.watch(linkableJobsProvider(order.id));
    return Scaffold(
      backgroundColor: cs.surfaceContainerLow,
      appBar: formAppBar(context, 'Add Roll to Order'),
      body: AsyncBody(
        value: jobs,
        onRefresh: () => ref.refresh(linkableJobsProvider(order.id).future),
        builder: (list) => ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Padding(
              padding: const EdgeInsets.only(bottom: 16),
              child: Text(
                '#${order.code} · Rolls sent to ${order.labName}. One roll can go on several lines, such as developing and scanning',
                style: TextStyle(fontSize: 13, color: cs.onSurfaceVariant),
              ),
            ),
            if (list.isEmpty)
              EmptyCard(
                icon: Icons.local_shipping_outlined,
                title: 'No roll is waiting for an order',
                text: 'Send a roll to ${order.labName} first.',
              )
            else ...[
              LabeledField(
                label: 'Roll *',
                gapAfter: _rollError == null ? 16 : 6,
                child: SelectField(
                  hint: 'Select a roll',
                  value: _job == null ? null : _jobLabel(_job!),
                  onTap: () => _pickJob(list),
                ),
              ),
              if (_rollError != null)
                Padding(
                  padding: const EdgeInsets.only(bottom: 16),
                  child: Text(
                    _rollError!,
                    style: TextStyle(fontSize: 13, color: cs.error),
                  ),
                ),
              const DetailLabel('ORDER LINES', top: 4),
              OrderLinesPicker(
                lines: order.lines,
                selected: _lineIds,
                ownLineIds: _job?.lineIds ?? const [],
                error: _linesError,
                onChanged: (v) => setState(() {
                  _lineIds = v;
                  _linesError = null;
                }),
              ),
              const SizedBox(height: 24),
              FormSaveBar(label: 'Add roll', busy: _busy, onPressed: _save),
            ],
          ],
        ),
      ),
    );
  }

  String _jobLabel(LabOrderJob j) =>
      '${j.stockName} · ${j.format} · ${j.type.label} · sent ${fmtDate(j.sentAt)}';

  Future<void> _pickJob(List<LabOrderJob> list) async {
    final picked = await pickOne<LabOrderJob>(
      context,
      title: 'Roll',
      items: list,
      label: _jobLabel,
      subtitle: (j) => j.lineIds.isEmpty ? '' : 'Already on this order',
    );
    if (picked == null) return;
    setState(() {
      _job = picked;
      _rollError = null;
      // Choosing a roll keeps what it is on, plus the line this was opened from.
      _lineIds = {...picked.lineIds, ..._startingLines()}.toList();
    });
  }

  Future<void> _save() async {
    setState(() {
      _rollError = _job == null ? 'Select a roll.' : null;
      _linesError = _lineIds.isEmpty ? 'Tick at least one line.' : null;
    });
    if (_job == null || _lineIds.isEmpty) return;
    setState(() => _busy = true);
    final ok = await guard(
      context,
      () => ref.read(labOrderActionsProvider).setJobLines(_job!.id, _lineIds),
    );
    if (!mounted) return;
    setState(() => _busy = false);
    if (ok) context.closeScreen();
  }
}
