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
          return ListView(
            children: [
              const SectionHeader('Expired or expiring within 6 months'),
              if (d.expiring.isEmpty)
                const Padding(padding: EdgeInsets.all(16), child: Text('None')),
              for (final e in d.expiring)
                RollTile(
                  roll: e.roll,
                  trailing: Text(
                    e.expired ? 'Expired' : fmtDate(e.expiresOn),
                    style: TextStyle(
                      color: e.expired
                          ? Theme.of(context).colorScheme.error
                          : null,
                    ),
                  ),
                ),
              if (d.noExpiry.isNotEmpty) ...[
                const SectionHeader('No expiry information'),
                for (final r in d.noExpiry) RollTile(roll: r),
              ],
            ],
          );
        },
      ),
    );
  }
}
