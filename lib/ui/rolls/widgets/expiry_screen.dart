import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../providers.dart';
import '../../core/widgets/cards.dart';
import '../../core/widgets/common.dart';
import '../view_models/rolls_view_model.dart';
import 'roll_card.dart';

/// M-23 expired or soon-to-expire in-stock rolls.
class ExpiryScreen extends ConsumerWidget {
  const ExpiryScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final v = ref.watch(expiryProvider);
    final processes = ref.watch(stockProcessByIdProvider);
    final cs = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(title: const Text('Expiry')),
      body: AsyncBody(
        value: v,
        onRefresh: () async => ref.refresh(expiryProvider.future),
        builder: (d) {
          if (d.expiring.isEmpty && d.noExpiry.isEmpty) {
            return ListView(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
              children: const [
                EmptyCard(
                  icon: Icons.hourglass_bottom,
                  title: 'Nothing to check',
                  text: 'Rolls in stock appear here once you add them.',
                ),
              ],
            );
          }
          return CustomScrollView(
            slivers: [
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
                sliver: SliverToBoxAdapter(
                  child: SectionLabel(
                    'Expired or expiring within 6 months · ${d.expiring.length}',
                  ),
                ),
              ),
              if (d.expiring.isEmpty)
                const SliverPadding(
                  padding: EdgeInsets.symmetric(horizontal: 16),
                  sliver: SliverToBoxAdapter(
                    child: EmptyCard(
                      icon: Icons.check_circle_outline,
                      title: 'All clear',
                      text: 'No film in stock expires within 6 months.',
                    ),
                  ),
                )
              else
                SliverPadding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  sliver: SliverList.separated(
                    itemCount: d.expiring.length,
                    separatorBuilder: (_, _) => const SizedBox(height: 8),
                    itemBuilder: (_, i) {
                      final e = d.expiring[i];
                      return RollCard(
                        roll: e.roll,
                        process: processes[e.roll.filmStockId],
                        expiring: true,
                        extraBadge: e.expired
                            ? StampBadge('Expired', color: cs.error)
                            : null,
                      );
                    },
                  ),
                ),
              if (d.noExpiry.isNotEmpty) ...[
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(16, 24, 16, 8),
                  sliver: SliverToBoxAdapter(
                    child: SectionLabel(
                      'No expiry information · ${d.noExpiry.length}',
                    ),
                  ),
                ),
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                  sliver: SliverList.separated(
                    itemCount: d.noExpiry.length,
                    separatorBuilder: (_, _) => const SizedBox(height: 8),
                    itemBuilder: (_, i) => RollCard(
                      roll: d.noExpiry[i],
                      process: processes[d.noExpiry[i].filmStockId],
                    ),
                  ),
                ),
              ],
            ],
          );
        },
      ),
    );
  }
}
