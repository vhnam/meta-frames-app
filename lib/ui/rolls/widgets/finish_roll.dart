import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/widgets/common.dart';
import '../view_models/roll_actions.dart';

/// M-21 mark roll as finished shooting. Date defaults to today.
Future<void> finishRoll(
  BuildContext context,
  WidgetRef ref,
  String rollId,
) async {
  DateTime date = DateTime.now();
  final ok = await showDialog<bool>(
    context: context,
    builder: (c) => StatefulBuilder(
      builder: (c, setS) => AlertDialog(
        title: const Text('Finish roll'),
        content: DateField(
          label: 'Finish date',
          value: date,
          onChanged: (d) => setS(() => date = d!),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(c, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(c, true),
            child: const Text('Finish'),
          ),
        ],
      ),
    ),
  );
  if (ok != true || !context.mounted) return;
  final done = await guard(
    context,
    () => ref.read(rollActionsProvider).finish(rollId, date),
  );
  if (done && context.mounted) toast(context, 'Roll finished. Camera is free.');
}
