import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/models.dart';
import '../../providers.dart';
import '../../widgets/common.dart';

/// Add or edit a lab in a dialog. Returns the saved [Lab].
Future<Lab?> editLab(BuildContext context, WidgetRef ref, [Lab? lab]) {
  final name = TextEditingController(text: lab?.name);
  final address = TextEditingController(text: lab?.address);
  return showDialog<Lab>(
    context: context,
    builder: (c) => AlertDialog(
      title: Text(lab == null ? 'Add lab' : 'Edit lab'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        spacing: 12,
        children: [
          TextField(
            controller: name,
            decoration: deco('Name'),
            autofocus: true,
          ),
          TextField(
            controller: address,
            decoration: deco('Address (optional)'),
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
            final body = {
              'name': name.text.trim(),
              'address': address.text.trim().isEmpty
                  ? null
                  : address.text.trim(),
            };
            final api = ref.read(apiProvider);
            Lab? saved;
            final ok = await guard(c, () async {
              saved = lab == null
                  ? await api.createLab(body)
                  : await api.updateLab(lab.id, body);
            });
            if (ok && c.mounted) {
              refreshAll(ref);
              Navigator.pop(c, saved);
            }
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
    return Scaffold(
      appBar: AppBar(title: const Text('Labs')),
      floatingActionButton: FloatingActionButton(
        onPressed: () => editLab(context, ref),
        child: const Icon(Icons.add),
      ),
      body: AsyncBody(
        value: v,
        onRefresh: () async => ref.refresh(labsProvider.future),
        builder: (labs) {
          if (labs.isEmpty)
            return const EmptyState('No labs yet. Tap + to add one.');
          return ListView.separated(
            itemCount: labs.length,
            separatorBuilder: (_, _) => const Divider(height: 1),
            itemBuilder: (c, i) {
              final l = labs[i];
              return Dismissible(
                key: ValueKey(l.id),
                direction: DismissDirection.endToStart,
                background: Container(
                  color: Theme.of(c).colorScheme.error,
                  alignment: Alignment.centerRight,
                  padding: const EdgeInsets.only(right: 16),
                  child: const Icon(Icons.delete, color: Colors.white),
                ),
                confirmDismiss: (_) async {
                  if (!await confirm(c, 'Delete lab?', l.name, ok: 'Delete'))
                    return false;
                  if (!c.mounted) return false;
                  // Server refuses (409) when the lab has processing history.
                  return guard(c, () => ref.read(apiProvider).deleteLab(l.id));
                },
                onDismissed: (_) => refreshAll(ref),
                child: ListTile(
                  title: Text(l.name),
                  subtitle: l.address == null ? null : Text(l.address!),
                  trailing: const Icon(Icons.edit_outlined, size: 18),
                  onTap: () => editLab(c, ref, l),
                ),
              );
            },
          );
        },
      ),
    );
  }
}
