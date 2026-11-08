import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../providers.dart';
import '../../../routing/routes.dart';

import '../../auth/view_models/auth_actions.dart';
import '../../core/widgets/common.dart';
import '../../sync/widgets/sync_screen.dart';
import '../view_models/settings_actions.dart';

/// Everything that is not a main tab: the account, sync status, gear, film
/// stocks, labs, the dashboard link and settings. Expiry shows in the Rolls list
/// and the roll picker; its old screen stays reachable by link.
class MoreTab extends ConsumerWidget {
  const MoreTab({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(currentUserProvider).value;
    final ops = ref.watch(openOpsProvider).value ?? const [];
    final drafts = ref.watch(draftsProvider).value ?? const [];
    final dashboard = ref.read(settingsActionsProvider).dashboardUrl();
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
                  entry(
                    Icons.local_shipping_outlined,
                    'Negatives at lab',
                    Routes.negativesAtLab,
                  ),
                  entry(Icons.store_outlined, 'Labs', Routes.labs),
                  ListTile(
                    leading: const Icon(Icons.open_in_new),
                    title: const Text('Dashboard'),
                    subtitle: Text(
                      dashboard ??
                          'Set its address for this server in Settings',
                    ),
                    onTap: () => _openDashboard(context, ref),
                  ),
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

/// Opens the dashboard of the server in use now (read at the tap, so a server
/// switched or a URL saved since the tab was built is the one used). With no
/// address set it goes to Settings; when no browser takes it, the address is
/// offered for copying.
Future<void> _openDashboard(BuildContext context, WidgetRef ref) async {
  final actions = ref.read(settingsActionsProvider);
  final url = actions.dashboardUrl();
  if (url == null) {
    context.push(Routes.settings);
    return;
  }
  final messenger = ScaffoldMessenger.of(context);
  if (await actions.openDashboard()) return;
  messenger.showSnackBar(
    SnackBar(
      content: const Text('Could not open the dashboard.'),
      action: SnackBarAction(
        label: 'Copy address',
        onPressed: () => Clipboard.setData(ClipboardData(text: url)),
      ),
    ),
  );
}
