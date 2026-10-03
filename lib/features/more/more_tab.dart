import 'package:flutter/material.dart';

import '../labs/labs_screen.dart';
import '../labs/negatives_at_lab.dart';
import '../rolls/expiry_screen.dart';
import 'search_screen.dart';
import 'settings_screen.dart';

class MoreTab extends StatelessWidget {
  const MoreTab({super.key});

  @override
  Widget build(BuildContext context) {
    void open(Widget w) =>
        Navigator.push(context, MaterialPageRoute(builder: (_) => w));
    return Scaffold(
      appBar: AppBar(title: const Text('More')),
      body: ListView(
        children: [
          ListTile(
            leading: const Icon(Icons.search),
            title: const Text('Search rolls'),
            onTap: () => open(const SearchScreen()),
          ),
          ListTile(
            leading: const Icon(Icons.hourglass_bottom),
            title: const Text('Expiry'),
            onTap: () => open(const ExpiryScreen()),
          ),
          ListTile(
            leading: const Icon(Icons.local_shipping_outlined),
            title: const Text('Negatives at lab'),
            onTap: () => open(const NegativesAtLabScreen()),
          ),
          ListTile(
            leading: const Icon(Icons.store_outlined),
            title: const Text('Labs'),
            onTap: () => open(const LabsScreen()),
          ),
          ListTile(
            leading: const Icon(Icons.settings_outlined),
            title: const Text('Settings'),
            onTap: () => open(const SettingsScreen()),
          ),
        ],
      ),
    );
  }
}
