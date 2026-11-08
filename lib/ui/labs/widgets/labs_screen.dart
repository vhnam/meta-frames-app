import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../domain/models/models.dart';
import '../../../providers.dart';
import '../../../routing/routes.dart';
import '../../core/widgets/cards.dart';
import '../../core/widgets/common.dart';
import 'lab_dialog.dart';

/// Labs to pick from and look up, with a quick add of a name. The dashboard
/// edits and deletes labs.
class LabsScreen extends ConsumerWidget {
  const LabsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final v = ref.watch(labsProvider);
    final scanners = ref.watch(scannersProvider).value;
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
                onPressed: () => editLab(context),
                child: Text(addLabel),
              ),
            ),
            Expanded(
              child: AsyncBody(
                value: v,
                onRefresh: () async {
                  ref.invalidate(scannersProvider);
                  return ref.refresh(labsProvider.future);
                },
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
                    else
                      CardList(
                        children: [
                          for (final l in labs)
                            CardTile(
                              icon: Icons.store_outlined,
                              iconSize: 44,
                              iconBg: cs.surfaceContainer,
                              iconColor: cs.onSurfaceVariant,
                              title: l.name,
                              subtitle: l.address ?? 'No address',
                              detail: _scannerNames(l, scanners),
                              padding: const EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 14,
                              ),
                              trailing: Icon(
                                Icons.chevron_right,
                                color: cs.onSurfaceVariant,
                              ),
                              onTap: () => context.push(Routes.lab(l.id)),
                            ),
                        ],
                      ),
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

/// The lab's scanner names, in order. Null until the catalog has loaded.
String? _scannerNames(Lab lab, List<ScannerDevice>? catalog) {
  if (lab.scannerIds.isEmpty) return 'No scanners';
  if (catalog == null) return null;
  final names = lab.scannersFrom(catalog).map((s) => s.name);
  return names.isEmpty ? 'No scanners' : names.join(', ');
}
