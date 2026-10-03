import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../domain/models/models.dart';
import '../../../providers.dart';
import '../../core/widgets/common.dart';
import '../view_models/gear_actions.dart';
import '../view_models/gear_view_model.dart';
import '../../../routing/routes.dart';

import 'package:go_router/go_router.dart';

import '../../../routing/navigation.dart';

/// M-09 link lenses to a camera. Same-mount lenses listed first.
class ManageLensesScreen extends ConsumerStatefulWidget {
  const ManageLensesScreen({super.key, required this.camera});
  final Camera camera;
  @override
  ConsumerState<ManageLensesScreen> createState() => _State();
}

class _State extends ConsumerState<ManageLensesScreen> {
  Set<String>? selected;

  @override
  Widget build(BuildContext context) {
    final all = ref.watch(linkableLensesProvider(widget.camera.mount));
    final linked = ref.watch(cameraLensesProvider(widget.camera.id));
    selected ??= linked.value?.map((l) => l.id).toSet();
    return Scaffold(
      appBar: AppBar(
        title: Text('Lenses · ${widget.camera.name}'),
        actions: [
          TextButton(
            onPressed: selected == null ? null : _save,
            child: const Text('Save'),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () async {
          await context.push(Routes.lensNew);
        },
        child: const Icon(Icons.add),
      ),
      body: AsyncBody(
        value: all,
        onRefresh: () async => ref.refresh(lensesProvider.future),
        builder: (lenses) {
          if (selected == null)
            return const Center(child: CircularProgressIndicator());
          final mount = widget.camera.mount;
          final active = lenses;
          if (active.isEmpty)
            return const EmptyState('No lenses yet. Tap + to add one.');
          return ListView(
            children: [
              for (final l in active)
                CheckboxListTile(
                  value: selected!.contains(l.id),
                  title: Text(l.name),
                  subtitle: Text(
                    l.mount == mount
                        ? 'Mount ${l.mount} · same mount'
                        : 'Mount ${l.mount ?? '—'} · adapted',
                  ),
                  onChanged: (v) => setState(
                    () => v! ? selected!.add(l.id) : selected!.remove(l.id),
                  ),
                ),
            ],
          );
        },
      ),
    );
  }

  Future<void> _save() async {
    final ok = await guard(
      context,
      () => ref
          .read(cameraActionsProvider)
          .setLenses(widget.camera.id, selected!.toList()),
    );
    if (!mounted || !ok) return;
    context.closeScreen();
  }
}
