import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../domain/models/models.dart';
import '../../../providers.dart';
import '../../core/widgets/cards.dart';
import '../../core/widgets/common.dart';
import '../../core/widgets/form_kit.dart';
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
  bool busy = false;

  late final _provider = _rollLensOptionsProvider((
    cameraId: widget.cameraId,
    current: widget.current,
  ));

  void _toggle(String id) => setState(
    () => selected.contains(id) ? selected.remove(id) : selected.add(id),
  );

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Scaffold(
      backgroundColor: cs.surfaceContainerLow,
      appBar: formAppBar(context, 'Lenses used'),
      body: AsyncBody(
        value: ref.watch(_provider),
        onRefresh: () async => ref.refresh(_provider.future),
        builder: (options) => ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Padding(
              padding: const EdgeInsets.only(bottom: 16),
              child: Text(
                'Tick every lens used on this roll, such as after a lens swap mid-roll',
                style: TextStyle(fontSize: 13, color: cs.onSurfaceVariant),
              ),
            ),
            FormSectionHeader(
              number: '01',
              title: 'Lenses',
              note: '${selected.length} selected',
            ),
            if (options.isEmpty)
              const EmptyCard(
                icon: Icons.adjust,
                title: 'No lenses',
                text: 'There are no active lenses to pick from.',
              )
            else
              CardList(
                children: [
                  for (final l in options)
                    MergeSemantics(
                      child: CardTile(
                        compact: true,
                        leading: Checkbox(
                          value: selected.contains(l.id),
                          onChanged: (_) => _toggle(l.id),
                        ),
                        title: l.name,
                        subtitle: 'Mount ${l.mount ?? '—'}',
                        padding: const EdgeInsets.fromLTRB(4, 8, 16, 8),
                        onTap: () => _toggle(l.id),
                      ),
                    ),
                ],
              ),
            const SizedBox(height: 24),
            FormSaveBar(label: 'Save', busy: busy, onPressed: _save),
          ],
        ),
      ),
    );
  }

  Future<void> _save() async {
    setState(() => busy = true);
    final ok = await guard(
      context,
      () => ref
          .read(rollActionsProvider)
          .setLenses(widget.rollId, selected.toList()),
    );
    if (!mounted) return;
    setState(() => busy = false);
    if (!ok) return;
    context.closeScreen();
  }
}
