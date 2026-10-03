import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../routing/routes.dart';
import '../../core/widgets/common.dart';

/// Everything that is not a main tab: search, film stocks, expiry, labs and
/// settings.
class MoreTab extends StatelessWidget {
  const MoreTab({super.key});

  @override
  Widget build(BuildContext context) {
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
                  entry(Icons.search, 'Search rolls', Routes.search),
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
                  entry(Icons.settings_outlined, 'Settings', Routes.settings),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
