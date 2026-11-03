import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../providers.dart';
import '../../../routing/routes.dart';
import '../../auth/view_models/auth_actions.dart';
import '../../core/widgets/common.dart';

/// Everything that is not a main tab: the account, gear, film stocks, expiry,
/// labs, scanners and settings.
class MoreTab extends ConsumerWidget {
  const MoreTab({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(currentUserProvider).value;
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
                  entry(Icons.photo_camera_outlined, 'Gear', Routes.gear),
                  entry(
                    Icons.local_movies_outlined,
                    'Film stocks',
                    Routes.film,
                  ),
                  entry(Icons.hourglass_bottom, 'Expiry', Routes.expiry),
                  entry(
                    Icons.local_shipping_outlined,
                    'Negatives at lab',
                    Routes.negativesAtLab,
                  ),
                  entry(Icons.store_outlined, 'Labs', Routes.labs),
                  entry(Icons.scanner_outlined, 'Scanners', Routes.scanners),
                  entry(Icons.settings_outlined, 'Settings', Routes.settings),
                  ListTile(
                    leading: const Icon(Icons.logout),
                    title: const Text('Log out'),
                    onTap: () => ref.read(authActionsProvider).logout(),
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
