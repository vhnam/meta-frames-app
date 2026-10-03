import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../domain/models/models.dart';
import '../../../providers.dart';
import '../../core/theme.dart';
import '../../core/widgets/cards.dart';
import '../../core/widgets/common.dart';
import '../../core/widgets/form_kit.dart';
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
    final cs = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: formAppBar(context, 'Lenses · ${widget.camera.name}'),
      body: AsyncBody(
        value: all,
        onRefresh: () async => ref.refresh(lensesProvider.future),
        builder: (lenses) {
          final sel = selected;
          if (sel == null) {
            return const Center(child: CircularProgressIndicator());
          }
          final mount = widget.camera.mount;
          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              if (lenses.isEmpty)
                Text(
                  'No lenses yet. Add one below.',
                  style: TextStyle(fontSize: 13, color: cs.onSurfaceVariant),
                )
              else
                CardList(
                  children: [
                    for (final l in lenses)
                      CheckboxListTile(
                        value: sel.contains(l.id),
                        title: Text(
                          l.name,
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        subtitle: Text(
                          l.mount == mount
                              ? 'Mount ${l.mount} · same mount'
                              : 'Mount ${l.mount ?? '—'} · adapted',
                          style: monoStyle(
                            fontSize: 11.5,
                            color: cs.onSurfaceVariant,
                          ),
                        ),
                        onChanged: (v) => setState(
                          () => v! ? sel.add(l.id) : sel.remove(l.id),
                        ),
                      ),
                  ],
                ),
              const SizedBox(height: 8),
              DashedButton(
                label: 'New lens',
                onTap: () => context.push(Routes.lensNew),
              ),
              const SizedBox(height: 24),
              FormSaveBar(label: 'Save', busy: false, onPressed: _save),
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
