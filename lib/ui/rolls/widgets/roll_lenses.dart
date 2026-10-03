import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../domain/models/models.dart';
import '../../../providers.dart';
import '../../core/widgets/common.dart';

/// M-20 record lenses used on a roll (e.g. after swapping lenses mid-roll).
class RollLensesScreen extends ConsumerStatefulWidget {
  const RollLensesScreen({
    super.key,
    required this.rollId,
    required this.cameraId,
    required this.current,
  });
  final String rollId, cameraId;
  final List<Lens> current;
  @override
  ConsumerState<RollLensesScreen> createState() => _State();
}

class _State extends ConsumerState<RollLensesScreen> {
  late final Set<String> selected = widget.current.map((l) => l.id).toSet();
  List<Lens>? options;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final linked = await ref
          .read(cameraRepositoryProvider)
          .lenses(widget.cameraId);
      final all = await ref.read(lensRepositoryProvider).lenses();
      final byId = <String, Lens>{};
      for (final l in [...linked, ...widget.current]) {
        byId[l.id] = l;
      }
      final extra = all.where(
        (l) => l.isActive && !l.isBuiltIn && !byId.containsKey(l.id),
      );
      if (mounted) setState(() => options = [...byId.values, ...extra]);
    } catch (e) {
      if (mounted) toast(context, e.toString());
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: const Text('Lenses used'),
      actions: [TextButton(onPressed: _save, child: const Text('Save'))],
    ),
    body: options == null
        ? const Center(child: CircularProgressIndicator())
        : ListView(
            children: [
              for (final l in options!)
                CheckboxListTile(
                  value: selected.contains(l.id),
                  title: Text(l.name),
                  onChanged: (v) => setState(
                    () => v! ? selected.add(l.id) : selected.remove(l.id),
                  ),
                ),
            ],
          ),
  );

  Future<void> _save() async {
    final ok = await guard(
      context,
      () => ref
          .read(rollRepositoryProvider)
          .setLenses(widget.rollId, selected.toList()),
    );
    if (!mounted || !ok) return;
    refreshAll(ref);
    Navigator.pop(context);
  }
}
