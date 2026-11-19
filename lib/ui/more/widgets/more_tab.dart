import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../routing/routes.dart';

import '../../core/widgets/common.dart';
import '../../sync/view_models/sync_summary.dart';

/// Everything that is not a main tab: gear, film stocks, labs and settings.
/// The account, sync status and log out are in Settings. Expiry shows in the
/// Rolls list and the roll picker; its old screen stays reachable by link.
class MoreTab extends ConsumerWidget {
  const MoreTab({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final attention = ref.watch(syncSummaryProvider)?.attention ?? false;
    final error = Theme.of(context).colorScheme.error;
    Widget entry(IconData icon, String title, String route) => ListTile(
      leading: Icon(icon),
      title: Text(title),
      trailing: const Icon(Icons.chevron_right),
      onTap: () => context.push(route),
    );
    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.surface,
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            const ScreenHeader(kicker: 'MetaFrames · Tools', title: 'More'),
            Expanded(
              child: ListView(
                children: [
                  entry(Icons.photo_camera_outlined, 'Gear', Routes.gear),
                  entry(
                    Icons.local_movies_outlined,
                    'Film stocks',
                    Routes.film,
                  ),
                  entry(Icons.store_outlined, 'Labs', Routes.labs),
                  ListTile(
                    leading: Icon(
                      attention ? Icons.error_outline : Icons.settings_outlined,
                      color: attention ? error : null,
                    ),
                    title: const Text('Settings'),
                    subtitle: attention
                        ? Text(
                            'A change needs your attention',
                            style: TextStyle(color: error),
                          )
                        : null,
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () => context.push(Routes.settings),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
