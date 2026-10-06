import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../domain/utils.dart';
import '../../../providers.dart';
import '../../../routing/routes.dart';
import '../../core/widgets/cards.dart';
import '../../core/widgets/common.dart';
import 'processing_detail.dart';

/// M-30 track negatives still at lab; mark returned from the list.
class NegativesAtLabScreen extends ConsumerWidget {
  const NegativesAtLabScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final v = ref.watch(negativesAtLabProvider);
    final cs = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(title: const Text('Negatives at lab')),
      body: AsyncBody(
        value: v,
        onRefresh: () async => ref.refresh(negativesAtLabProvider.future),
        builder: (items) {
          if (items.isEmpty) {
            return ListView(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
              children: const [
                EmptyCard(
                  icon: Icons.local_shipping_outlined,
                  title: 'Nothing at a lab',
                  text: 'Rolls you send out for development or scanning show up here until the negatives come back.',
                ),
              ],
            );
          }
          return ListView(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
            children: [
              SectionLabel('At lab · ${items.length}'),
              const SizedBox(height: 8),
              CardList(
                children: [
                  for (final it in items)
                    Builder(
                      builder: (context) {
                        final late = it.daysSinceSent >= followUpDays;
                        return CardTile(
                          icon: Icons.science,
                          iconBg: late
                              ? cs.errorContainer
                              : cs.tertiaryContainer,
                          iconColor: late ? cs.error : cs.onTertiaryContainer,
                          title: '${it.stockName} · ${it.labName}',
                          subtitle:
                              '${it.type.label} · sent ${fmtDate(it.sentAt)} · ${it.daysSinceSent}d${late ? ' · follow up?' : ''}',
                          subtitleColor: late ? cs.error : null,
                          compact: true,
                          trailing: TextButton(
                            onPressed: () async {
                              final p = await ref.read(
                                processingProvider(it.processingId).future,
                              );
                              if (context.mounted) {
                                await markReceived(
                                  context,
                                  ref,
                                  p,
                                  negatives: true,
                                );
                              }
                            },
                            child: const Text('Returned'),
                          ),
                          onTap: () => context.push(Routes.roll(it.rollId)),
                        );
                      },
                    ),
                ],
              ),
            ],
          );
        },
      ),
    );
  }
}
