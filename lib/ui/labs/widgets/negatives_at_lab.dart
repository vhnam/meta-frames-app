import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../providers.dart';
import '../../core/widgets/common.dart';
import 'processing_detail.dart';
import '../../../routing/routes.dart';

import 'package:go_router/go_router.dart';

/// M-30 track negatives still at lab; mark returned from the list.
class NegativesAtLabScreen extends ConsumerWidget {
  const NegativesAtLabScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final v = ref.watch(negativesAtLabProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('Negatives at lab')),
      body: AsyncBody(
        value: v,
        onRefresh: () async => ref.refresh(negativesAtLabProvider.future),
        builder: (items) {
          if (items.isEmpty)
            return const EmptyState('No negatives waiting at a lab.');
          return ListView.separated(
            itemCount: items.length,
            separatorBuilder: (_, _) => const Divider(height: 1),
            itemBuilder: (c, i) {
              final it = items[i];
              return ListTile(
                title: Text('${it.stockName} · ${it.labName}'),
                subtitle: Text(
                  '${it.type.label} · sent ${fmtDate(it.sentAt)} · ${it.daysSinceSent} days',
                ),
                trailing: TextButton(
                  onPressed: () async {
                    final p = await ref.read(
                      processingProvider(it.processingId).future,
                    );
                    if (c.mounted)
                      await markReceived(c, ref, p, negatives: true);
                  },
                  child: const Text('Returned'),
                ),
                onTap: () => c.push(Routes.roll(it.rollId)),
              );
            },
          );
        },
      ),
    );
  }
}
