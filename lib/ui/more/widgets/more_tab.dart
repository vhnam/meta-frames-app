import 'package:flutter/material.dart';

import '../../../routing/routes.dart';

import 'package:go_router/go_router.dart';

class MoreTab extends StatelessWidget {
  const MoreTab({super.key});

  @override
  Widget build(BuildContext context) {
    void open(String route) => context.push(route);
    return Scaffold(
      appBar: AppBar(title: const Text('More')),
      body: ListView(
        children: [
          ListTile(
            leading: const Icon(Icons.search),
            title: const Text('Search rolls'),
            onTap: () => open(Routes.search),
          ),
          ListTile(
            leading: const Icon(Icons.hourglass_bottom),
            title: const Text('Expiry'),
            onTap: () => open(Routes.expiry),
          ),
          ListTile(
            leading: const Icon(Icons.local_shipping_outlined),
            title: const Text('Negatives at lab'),
            onTap: () => open(Routes.negativesAtLab),
          ),
          ListTile(
            leading: const Icon(Icons.store_outlined),
            title: const Text('Labs'),
            onTap: () => open(Routes.labs),
          ),
          ListTile(
            leading: const Icon(Icons.settings_outlined),
            title: const Text('Settings'),
            onTap: () => open(Routes.settings),
          ),
        ],
      ),
    );
  }
}
