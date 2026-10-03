import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../domain/models/lab_requests.dart';
import '../../../domain/models/models.dart';
import '../../../providers.dart';
import '../../core/widgets/cards.dart';
import '../../core/widgets/common.dart';
import '../../core/widgets/form_kit.dart';
import '../view_models/lab_actions.dart';

/// Add or edit a lab in a dialog. Returns the saved [Lab].
Future<Lab?> editLab(BuildContext context, WidgetRef ref, [Lab? lab]) {
  final name = TextEditingController(text: lab?.name);
  final address = TextEditingController(text: lab?.address);
  final cs = Theme.of(context).colorScheme;
  return showDialog<Lab>(
    context: context,
    builder: (c) => AlertDialog(
      title: Text(lab == null ? 'Add lab' : 'Edit lab'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          LabeledField(
            label: 'Name',
            child: TextField(
              controller: name,
              autofocus: true,
              textCapitalization: TextCapitalization.words,
              decoration: formInputDecoration('e.g. Foto Lab', cs),
            ),
          ),
          LabeledField(
            label: 'Address (optional)',
            gapAfter: 0,
            child: TextField(
              controller: address,
              decoration: formInputDecoration('Street, city', cs),
            ),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(c),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: () async {
            if (name.text.trim().isEmpty) return;
            final edit = LabEdit(
              name: name.text.trim(),
              address: address.text.trim().isEmpty ? null : address.text.trim(),
            );
            Lab? saved;
            final ok = await guard(c, () async {
              saved = await ref
                  .read(labActionsProvider)
                  .save(edit, existing: lab);
            });
            if (ok && c.mounted) Navigator.pop(c, saved);
          },
          child: const Text('Save'),
        ),
      ],
    ),
  );
}

/// M-25 browse labs, M-26 add/edit/delete own labs.
class LabsScreen extends ConsumerWidget {
  const LabsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final v = ref.watch(labsProvider);
    final cs = Theme.of(context).colorScheme;
    // Contextual label while there are none, as on the Gear tab.
    final addLabel = (v.value?.isEmpty ?? false) ? '+ Lab' : '+ Add';
    return Scaffold(
      backgroundColor: cs.surface,
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            ScreenHeader(
              kicker: 'MetaFrames · Film labs',
              title: 'Labs',
              back: true,
              trailing: TextButton(
                onPressed: () => editLab(context, ref),
                child: Text(addLabel),
              ),
            ),
            Expanded(
              child: AsyncBody(
                value: v,
                onRefresh: () async => ref.refresh(labsProvider.future),
                builder: (labs) => ListView(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
                  children: [
                    SectionLabel('Labs · ${labs.length}'),
                    const SizedBox(height: 8),
                    if (labs.isEmpty)
                      const EmptyCard(
                        icon: Icons.store_outlined,
                        title: 'No labs yet',
                        text: 'Add the labs you send film to. You pick one each time you send a roll.',
                      )
                    else ...[
                      CardList(
                        children: [
                          for (final l in labs)
                            Dismissible(
                              key: ValueKey(l.id),
                              direction: DismissDirection.endToStart,
                              background: Container(
                                color: cs.error,
                                alignment: Alignment.centerRight,
                                padding: const EdgeInsets.only(right: 16),
                                child: Icon(Icons.delete, color: cs.onError),
                              ),
                              confirmDismiss: (_) async {
                                if (!await confirm(
                                  context,
                                  'Delete lab?',
                                  l.name,
                                  ok: 'Delete',
                                )) {
                                  return false;
                                }
                                if (!context.mounted) return false;
                                // Server refuses (409) when the lab has processing history.
                                return guard(
                                  context,
                                  () =>
                                      ref.read(labActionsProvider).delete(l.id),
                                );
                              },
                              child: CardTile(
                                icon: Icons.store_outlined,
                                iconSize: 44,
                                iconBg: cs.surfaceContainer,
                                iconColor: cs.onSurfaceVariant,
                                title: l.name,
                                subtitle: l.address ?? 'No address',
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 16,
                                  vertical: 14,
                                ),
                                trailing: Icon(
                                  Icons.chevron_right,
                                  color: cs.onSurfaceVariant,
                                ),
                                onTap: () => editLab(context, ref, l),
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      const FormNote('Swipe a lab left to delete it.'),
                    ],
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
