import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../providers.dart';
import '../../../routing/routes.dart';
import '../../core/widgets/cards.dart';
import '../../core/widgets/common.dart';

/// What each lab billed, newest first. Follows the dashboard's Orders page.
class OrdersScreen extends ConsumerWidget {
  const OrdersScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final v = ref.watch(labOrdersProvider);
    final cs = Theme.of(context).colorScheme;
    final addLabel = (v.value?.isEmpty ?? false) ? '+ Order' : '+ Add';
    return Scaffold(
      backgroundColor: cs.surface,
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            ScreenHeader(
              kicker: 'MetaFrames · Lab orders',
              title: 'Orders',
              back: true,
              trailing: TextButton(
                onPressed: () => context.push(Routes.orderNew),
                child: Text(addLabel),
              ),
            ),
            Expanded(
              child: AsyncBody(
                value: v,
                onRefresh: () async => ref.refresh(labOrdersProvider.future),
                builder: (orders) => ListView(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
                  children: [
                    SectionLabel('Orders · ${orders.length}'),
                    const SizedBox(height: 8),
                    if (orders.isEmpty)
                      const EmptyCard(
                        icon: Icons.receipt_long_outlined,
                        title: 'No orders yet',
                        text: 'Copy the order a lab issues, then add its rolls. A roll on an order takes its price from there.',
                      )
                    else
                      CardList(
                        children: [
                          for (final o in orders)
                            CardTile(
                              icon: Icons.receipt_long_outlined,
                              iconBg: cs.primaryContainer,
                              iconColor: cs.onPrimaryContainer,
                              title: '#${o.code}',
                              subtitle:
                                  '${o.labName} · ${fmtDate(o.orderedAt)} · ${o.rolls} roll${o.rolls == 1 ? '' : 's'}',
                              trailing: Text(
                                fmtVnd(o.total),
                                style: const TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              onTap: () => context.push(Routes.order(o.id)),
                            ),
                        ],
                      ),
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
