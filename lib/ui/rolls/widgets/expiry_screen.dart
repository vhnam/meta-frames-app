import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../providers.dart';
import '../../core/widgets/common.dart';
import 'roll_tile.dart';

/// M-23 expired or soon-to-expire in-stock rolls.
class ExpiryScreen extends ConsumerWidget {
  const ExpiryScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final v = ref.watch(expiryProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('Expiry')),
      body: AsyncBody(
        value: v,
        onRefresh: () async => ref.refresh(expiryProvider.future),
        builder: (d) {
          if (d.expiring.isEmpty && d.noExpiry.isEmpty) {
            return const EmptyState('No in-stock rolls to check.');
          }
          return CustomScrollView(
            slivers: [
              const SliverToBoxAdapter(
                child: SectionHeader('Expired or expiring within 6 months'),
              ),
              if (d.expiring.isEmpty)
                const SliverToBoxAdapter(
                  child: Padding(
                    padding: EdgeInsets.all(16),
                    child: Text('None'),
                  ),
                )
              else
                SliverList.builder(
                  itemCount: d.expiring.length,
                  itemBuilder: (context, i) {
                    final e = d.expiring[i];
                    return RollTile(
                      roll: e.roll,
                      trailing: Text(
                        e.expired ? 'Expired' : fmtDate(e.expiresOn),
                        style: TextStyle(
                          color: e.expired
                              ? Theme.of(context).colorScheme.error
                              : null,
                        ),
                      ),
                    );
                  },
                ),
              if (d.noExpiry.isNotEmpty) ...[
                const SliverToBoxAdapter(
                  child: SectionHeader('No expiry information'),
                ),
                SliverList.builder(
                  itemCount: d.noExpiry.length,
                  itemBuilder: (_, i) => RollTile(roll: d.noExpiry[i]),
                ),
              ],
            ],
          );
        },
      ),
    );
  }
}
