import 'package:flutter/material.dart';
import 'package:flutter_markdown_plus/flutter_markdown_plus.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../domain/models/models.dart';
import '../../../providers.dart';
import '../../../routing/navigation.dart';
import '../../../routing/routes.dart';
import '../../core/widgets/cards.dart';
import '../../core/widgets/common.dart';
import '../view_models/lab_order_actions.dart';

/// An order as the lab issued it: lines, amounts and the rolls on it.
class OrderDetailScreen extends ConsumerWidget {
  const OrderDetailScreen({super.key, required this.orderId});
  final String orderId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final order = ref.watch(labOrderProvider(orderId));
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
          order.value == null ? 'Order' : '#${order.value!.code}',
          style: const TextStyle(fontSize: 19, fontWeight: FontWeight.w600),
        ),
        actions: [
          if (order.value != null)
            Padding(
              padding: const EdgeInsets.only(right: 4),
              child: TextButton(
                onPressed: () => context.push(Routes.orderEdit(orderId)),
                child: const Text(
                  'Edit',
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
                ),
              ),
            ),
        ],
      ),
      body: AsyncBody(
        value: order,
        onRefresh: () => ref.refresh(labOrderProvider(orderId).future),
        builder: (o) => _Body(order: o),
      ),
    );
  }
}

class _Body extends ConsumerWidget {
  const _Body({required this.order});
  final LabOrder order;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cs = Theme.of(context).colorScheme;
    final jobs = order.jobs;
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        CardList(
          children: [
            DetailInfoRow('Lab', order.labName),
            DetailInfoRow(
              'Created',
              DateFormat('dd/MM/yyyy HH:mm').format(order.orderedAt),
            ),
            DetailInfoRow('Due', fmtDate(order.dueDate)),
            DetailInfoRow(
              'Rolls',
              '${order.rolls} · ${order.takenPlaces} of ${order.billedPlaces} places taken',
            ),
          ],
        ),
        DetailLabel('ORDER LINES · ${order.lines.length}'),
        CardList(
          children: [
            for (final l in order.lines) _LineTile(orderId: order.id, line: l),
          ],
        ),
        const DetailLabel('AMOUNTS'),
        CardList(
          children: [
            DetailInfoRow('Subtotal', fmtVnd(order.subtotal)),
            DetailInfoRow('VAT', fmtVnd(order.vat)),
            DetailInfoRow('Discount', '-${fmtVnd(order.discount)}'),
            DetailInfoRow('Total', fmtVnd(order.total)),
          ],
        ),
        DetailLabel('ROLLS · ${jobs.length}'),
        if (jobs.isEmpty)
          Text(
            'No rolls on this order yet.',
            style: TextStyle(fontSize: 13, color: cs.onSurfaceVariant),
          )
        else
          CardList(
            children: [
              for (final (:job, :lines) in jobs)
                CardTile(
                  compact: true,
                  title: job.stockName,
                  subtitle:
                      '${job.format} · ${job.type.label} · ${lines.map((l) => l.product).join(' + ')}',
                  onTap: () => context.push(Routes.roll(job.rollId)),
                  trailing: IconButton(
                    icon: const Icon(Icons.close, size: 18),
                    tooltip: 'Take ${job.stockName} off this order',
                    onPressed: () => _remove(context, ref, job),
                  ),
                ),
            ],
          ),
        const SizedBox(height: 12),
        FilledButton.icon(
          icon: const Icon(Icons.add),
          label: const Text('Add roll'),
          onPressed: order.lines.any((l) => l.room > 0)
              ? () => context.push(Routes.orderAddRoll(order.id))
              : null,
        ),
        if (order.notes?.trim().isNotEmpty ?? false) ...[
          const DetailLabel('NOTES'),
          MarkdownBody(data: order.notes!),
        ],
        const SizedBox(height: 20),
        CardList(
          children: [
            DetailActionRow(
              label: 'Delete order',
              color: cs.error,
              onTap: () => _delete(context, ref),
            ),
          ],
        ),
        const SizedBox(height: 16),
      ],
    );
  }

  Future<void> _remove(
    BuildContext context,
    WidgetRef ref,
    LabOrderJob job,
  ) async {
    if (!await confirm(
      context,
      'Take roll off this order?',
      '${job.stockName} leaves every line of this order, and the job then has no price.',
      ok: 'Take off',
    )) {
      return;
    }
    if (!context.mounted) return;
    await guard(
      context,
      () => ref.read(labOrderActionsProvider).setJobLines(job.id, const []),
    );
  }

  Future<void> _delete(BuildContext context, WidgetRef ref) async {
    if (!await confirm(
      context,
      'Delete order?',
      '#${order.code} will be removed. Refused while it has rolls.',
      ok: 'Delete',
    )) {
      return;
    }
    if (!context.mounted) return;
    final ok = await guard(
      context,
      () => ref.read(labOrderActionsProvider).delete(order.id),
    );
    if (ok && context.mounted) context.closeScreen();
  }
}

class _LineTile extends StatelessWidget {
  const _LineTile({required this.orderId, required this.line});
  final String orderId;
  final LabOrderLine line;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final muted = TextStyle(fontSize: 12, color: cs.onSurfaceVariant);
    return Padding(
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        spacing: 4,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            spacing: 12,
            children: [
              Expanded(
                child: Text(
                  line.product,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              Text(
                fmtVnd(line.lineTotal),
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          if (line.options?.trim().isNotEmpty ?? false)
            MarkdownBody(data: line.options!),
          Text('${line.quantity} × ${fmtVnd(line.unitPrice)}', style: muted),
          Row(
            children: [
              Expanded(
                child: Text(
                  '${line.jobs.length} of ${line.quantity} rolls · ${fmtVnd(line.unitCost)} each with VAT',
                  style: muted,
                ),
              ),
              if (line.room > 0)
                TextButton(
                  onPressed: () => context.push(
                    Routes.orderAddRoll(orderId, lineId: line.id),
                  ),
                  child: Text('Add to ${line.product}'),
                ),
            ],
          ),
        ],
      ),
    );
  }
}
