import 'package:flutter/material.dart';

import '../../../data/local/local_store.dart';

/// The foot of a picker: create the thing being picked without leaving the
/// flow, or finish a draft of one that was not sent. Whatever the form
/// returns is picked. A draft is never picked itself: it becomes pickable
/// once the server has it.
class CreateFooter<T> extends StatelessWidget {
  const CreateFooter({
    super.key,
    required this.label,
    required this.create,
    this.drafts = const [],
    this.resume,
  });
  final String label;
  final Future<Object?> Function(BuildContext context) create;
  final List<Draft> drafts;
  final Future<Object?> Function(BuildContext context, Draft draft)? resume;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    Future<void> open(Future<Object?> Function() form) async {
      final made = await form();
      final picked = pickedFrom<T>(made);
      if (picked != null && context.mounted) Navigator.pop(context, picked);
    }

    return Padding(
      padding: const EdgeInsets.all(8),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (final d in drafts)
            ListTile(
              dense: true,
              leading: const Icon(Icons.edit_note),
              title: Text('Draft: ${d.label}'),
              subtitle: Text(
                d.error ?? 'Not sent. Tap to finish and send.',
                style: TextStyle(color: cs.onSurfaceVariant),
              ),
              onTap: resume == null
                  ? null
                  : () => open(() => resume!(context, d)),
            ),
          TextButton.icon(
            icon: const Icon(Icons.add),
            label: Text(label),
            onPressed: () => open(() => create(context)),
          ),
        ],
      ),
    );
  }
}

/// What a create form returned, as the picker's item: the item itself, or
/// the first of a list (adding rolls returns every roll added).
T? pickedFrom<T>(Object? made) => switch (made) {
  final T one => one,
  final List<Object?> many when many.isNotEmpty && many.first is T =>
    many.first as T,
  _ => null,
};
