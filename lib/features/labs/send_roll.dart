import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/api.dart';
import '../../core/models.dart';
import '../../providers.dart';
import '../../widgets/common.dart';
import 'labs_screen.dart';

/// M-27 send roll for processing, M-31 re-send for rescan or print.
class SendRollScreen extends ConsumerStatefulWidget {
  const SendRollScreen({
    super.key,
    required this.roll,
    required this.stock,
    this.resend = false,
  });
  final RollSummary roll;
  final FilmStock stock;
  final bool resend;
  @override
  ConsumerState<SendRollScreen> createState() => _State();
}

class _State extends ConsumerState<SendRollScreen> {
  Lab? lab;
  bool home = false;
  late ProcessingType type = widget.resend
      ? ProcessingType.scan
      : ProcessingType.developScan;
  late Process process = widget.stock.process;
  DateTime sent = DateTime.now();
  final price = TextEditingController();
  final notes = TextEditingController();
  bool busy = false;

  @override
  Widget build(BuildContext context) {
    final types = widget.resend
        ? [ProcessingType.scan, ProcessingType.print]
        : ProcessingType.values;
    return Scaffold(
      appBar: AppBar(title: Text(widget.resend ? 'Send again' : 'Send to lab')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Home processing'),
            value: home,
            onChanged: (v) => setState(() => home = v),
          ),
          if (!home) ...[
            PickerField(
              label: 'Lab',
              value: lab?.name,
              onTap: () async {
                final labs = await ref.read(apiProvider).labs();
                if (!context.mounted) return;
                final x = await pickOne<Lab>(
                  context,
                  title: 'Lab',
                  items: labs,
                  label: (l) => l.name,
                  subtitle: (l) => l.address ?? '',
                  footer: Builder(
                    builder: (c) => Padding(
                      padding: const EdgeInsets.all(8),
                      child: TextButton.icon(
                        icon: const Icon(Icons.add),
                        label: const Text('New lab'),
                        onPressed: () async {
                          final l = await editLab(c, ref);
                          if (l != null && c.mounted) Navigator.pop(c, l);
                        },
                      ),
                    ),
                  ),
                );
                if (x != null) setState(() => lab = x);
              },
            ),
            gap,
          ],
          DropdownButtonFormField<ProcessingType>(
            initialValue: type,
            decoration: deco('Job type'),
            items: [
              for (final t in types)
                DropdownMenuItem(value: t, child: Text(t.label)),
            ],
            onChanged: (v) => setState(() => type = v!),
          ),
          gap,
          DropdownButtonFormField<Process>(
            initialValue: process,
            decoration: deco('Process', hint: 'Prefilled from stock'),
            items: [
              for (final p in Process.values)
                DropdownMenuItem(value: p, child: Text(p.wire)),
            ],
            onChanged: (v) => setState(() => process = v!),
          ),
          if (process != widget.stock.process)
            Padding(
              padding: const EdgeInsets.only(top: 4, left: 12),
              child: Text(
                'Cross-processing: stock is ${widget.stock.process.wire}',
                style: const TextStyle(fontSize: 12),
              ),
            ),
          gap,
          DateField(
            label: 'Sent date',
            value: sent,
            onChanged: (d) => setState(() => sent = d!),
          ),
          gap,
          TextField(
            controller: price,
            decoration: deco('Price (₫, optional)'),
            keyboardType: TextInputType.number,
          ),
          gap,
          TextField(
            controller: notes,
            decoration: deco('Notes', hint: 'Push/pull, scan resolution…'),
            maxLines: 3,
          ),
          gap,
          FilledButton(
            onPressed: busy ? null : _save,
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  Future<void> _save() async {
    if (!home && lab == null) {
      toast(context, 'Select a lab or switch to home processing.');
      return;
    }
    setState(() => busy = true);
    final body = {
      'labId': home ? null : lab!.id,
      'type': type.wire,
      'process': process.wire,
      'sentAt': ymd(sent),
      if (price.text.isNotEmpty) 'price': int.tryParse(price.text),
      if (notes.text.trim().isNotEmpty) 'notes': notes.text.trim(),
    };
    final ok = await guard(
      context,
      () => ref.read(apiProvider).sendRoll(widget.roll.id, body),
    );
    if (!mounted) return;
    setState(() => busy = false);
    if (!ok) return;
    refreshAll(ref);
    Navigator.pop(context);
  }
}
