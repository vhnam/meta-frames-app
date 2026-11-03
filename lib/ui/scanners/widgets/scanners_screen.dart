import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../domain/models/models.dart';
import '../../../providers.dart';
import '../../../routing/routes.dart';
import '../../core/widgets/cards.dart';
import '../../core/widgets/common.dart';

/// Machines film is scanned on: the shared built-in ones and the account's own.
class ScannersScreen extends ConsumerWidget {
  const ScannersScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final v = ref.watch(scannersProvider);
    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.surface,
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            ScreenHeader(
              kicker: 'MetaFrames · Film scanners',
              title: 'Scanners',
              back: true,
              trailing: TextButton(
                onPressed: () => context.push(Routes.scannerNew),
                child: const Text('+ Add'),
              ),
            ),
            Expanded(
              child: AsyncBody(
                value: v,
                onRefresh: () async => ref.refresh(scannersProvider.future),
                builder: (all) {
                  final builtIn = all.where((s) => s.builtIn).toList();
                  final own = all.where((s) => !s.builtIn).toList();
                  return ListView(
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
                    children: [
                      if (builtIn.isNotEmpty) ...[
                        SectionLabel('Built-in · ${builtIn.length}'),
                        const SizedBox(height: 8),
                        _ScannerList(builtIn),
                        const SizedBox(height: 20),
                      ],
                      SectionLabel('Yours · ${own.length}'),
                      const SizedBox(height: 8),
                      if (own.isEmpty)
                        const EmptyCard(
                          icon: Icons.scanner_outlined,
                          title: 'No scanners of your own',
                          text: 'Add a lab\'s machine, a flatbed or a camera rig.',
                        )
                      else
                        _ScannerList(own),
                    ],
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ScannerList extends StatelessWidget {
  const _ScannerList(this.scanners);
  final List<ScannerDevice> scanners;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return CardList(
      children: [
        for (final s in scanners)
          CardTile(
            icon: Icons.scanner_outlined,
            iconSize: 44,
            iconBg: cs.surfaceContainer,
            iconColor: cs.onSurfaceVariant,
            title: s.name,
            subtitle: s.kindLabel,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            trailing: Icon(Icons.chevron_right, color: cs.onSurfaceVariant),
            onTap: () => context.push(Routes.scanner(s.id)),
          ),
      ],
    );
  }
}
