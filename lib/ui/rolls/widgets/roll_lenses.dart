import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../domain/models/models.dart';
import '../../../providers.dart';
import '../../core/widgets/common.dart';
import '../view_models/roll_actions.dart';

import '../../../routing/navigation.dart';

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

/// Lenses offered for a roll: the camera's linked lenses, the ones already on
/// the roll, then any other active lens.
final _rollLensOptionsProvider = FutureProvider.autoDispose
    .family<List<Lens>, ({String cameraId, List<Lens> current})>((
      ref,
      args,
    ) async {
      final linked = await ref.watch(
        cameraLensesProvider(args.cameraId).future,
      );
      final all = await ref.watch(lensesProvider.future);
      final byId = <String, Lens>{
        for (final l in [...linked, ...args.current]) l.id: l,
      };
      final extra = all.where(
        (l) => l.isActive && !l.isBuiltIn && !byId.containsKey(l.id),
      );
      return [...byId.values, ...extra];
    });

class _State extends ConsumerState<RollLensesScreen> {
  late final Set<String> selected = widget.current.map((l) => l.id).toSet();

  @override
  Widget build(BuildContext context) {
    final options = ref.watch(
      _rollLensOptionsProvider((
        cameraId: widget.cameraId,
        current: widget.current,
      )),
    );
    ref.listen(
      _rollLensOptionsProvider((
        cameraId: widget.cameraId,
        current: widget.current,
      )),
      (_, v) {
        if (v.hasError) toast(context, v.error.toString());
      },
    );
    return Scaffold(
      appBar: AppBar(
        title: const Text('Lenses used'),
        actions: [TextButton(onPressed: _save, child: const Text('Save'))],
      ),
      body: options.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (_, _) => const Center(child: CircularProgressIndicator()),
        data: (options) => ListView(
          children: [
            for (final l in options)
              CheckboxListTile(
                value: selected.contains(l.id),
                title: Text(l.name),
                onChanged: (v) => setState(
                  () => v! ? selected.add(l.id) : selected.remove(l.id),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Future<void> _save() async {
    final ok = await guard(
      context,
      () => ref
          .read(rollActionsProvider)
          .setLenses(widget.rollId, selected.toList()),
    );
    if (!mounted || !ok) return;
    context.closeScreen();
  }
}
