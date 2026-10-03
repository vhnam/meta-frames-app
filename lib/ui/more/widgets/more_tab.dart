import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../routing/routes.dart';
import '../../core/widgets/cards.dart';
import '../../core/widgets/common.dart';

/// Everything that is not a main tab: search, film stocks, expiry, labs and
/// settings.
class MoreTab extends StatelessWidget {
  const MoreTab({super.key});

  @override
  Widget build(BuildContext context) {
    Widget entry(IconData icon, String title, String subtitle, String route) =>
        CardTile(
          icon: icon,
          title: title,
          subtitle: subtitle,
          trailing: Icon(
            Icons.chevron_right,
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
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
                padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
                children: [
                  CardList(
                    children: [
                      entry(
                        Icons.search,
                        'Search rolls',
                        'By stock, camera, lens or focal length',
                        Routes.search,
                      ),
                      entry(
                        Icons.local_movies_outlined,
                        'Film stocks',
                        'Catalog and unused rolls in stock',
                        Routes.film,
                      ),
                      entry(
                        Icons.hourglass_bottom,
                        'Expiry',
                        'Film that is expired or about to be',
                        Routes.expiry,
                      ),
                      entry(
                        Icons.local_shipping_outlined,
                        'Negatives at lab',
                        'Rolls sent out and not yet returned',
                        Routes.negativesAtLab,
                      ),
                      entry(
                        Icons.store_outlined,
                        'Labs',
                        'Where you send film',
                        Routes.labs,
                      ),
                      entry(
                        Icons.settings_outlined,
                        'Settings',
                        'Server connection',
                        Routes.settings,
                      ),
                    ],
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
