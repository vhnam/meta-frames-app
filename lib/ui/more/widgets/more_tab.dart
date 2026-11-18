import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../providers.dart';
import '../../../routing/routes.dart';

import '../../auth/view_models/auth_actions.dart';
import '../../core/widgets/common.dart';
import '../../sync/widgets/sync_screen.dart';

/// Everything that is not a main tab: the account, sync status, gear, film
/// stocks, labs and settings. Expiry shows in the Rolls list
/// and the roll picker; its old screen stays reachable by link.
class MoreTab extends ConsumerWidget {
  const MoreTab({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(currentUserProvider).value;
    final ops = ref.watch(openOpsProvider).value ?? const [];
    final drafts = ref.watch(draftsProvider).value ?? const [];
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
                  if (user != null)
                    ListTile(
                      leading: const Icon(Icons.person_outline),
                      title: Text(
                        user.name?.isNotEmpty == true ? user.name! : user.email,
                      ),
                      subtitle: user.name?.isNotEmpty == true
                          ? Text(user.email)
                          : null,
                    ),
                  ListTile(
                    leading: const Icon(Icons.cloud_sync_outlined),
                    title: const Text('Sync status'),
                    subtitle: ops.isEmpty && drafts.isEmpty
                        ? null
                        : Text(
                            [
                              if (ops.isNotEmpty) '${ops.length} waiting',
                              if (ops.any((o) => o.needsAttention))
                                'needs attention',
                              if (drafts.isNotEmpty)
                                '${drafts.length} draft${drafts.length == 1 ? '' : 's'}',
                            ].join(' · '),
                          ),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () => context.push(Routes.sync),
                  ),
                  entry(Icons.photo_camera_outlined, 'Gear', Routes.gear),
                  entry(
                    Icons.local_movies_outlined,
                    'Film stocks',
                    Routes.film,
                  ),
                  entry(Icons.store_outlined, 'Labs', Routes.labs),
                  entry(Icons.settings_outlined, 'Settings', Routes.settings),
                  ListTile(
                    leading: const Icon(Icons.logout),
                    title: const Text('Log out'),
                    onTap: () async {
                      final discard = await askKeepOrDiscard(
                        context,
                        ref,
                        action: 'Log out',
                      );
                      if (discard == null) return;
                      await ref
                          .read(authActionsProvider)
                          .logout(discardKept: discard);
                    },
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
