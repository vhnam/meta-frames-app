import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../data/repositories/settings_repository.dart';
import '../../../providers.dart';
import '../../core/widgets/common.dart';

class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});
  @override
  ConsumerState<SettingsScreen> createState() => _State();
}

class _State extends ConsumerState<SettingsScreen> {
  late final url = TextEditingController(
    text: ref.read(settingsRepositoryProvider).baseUrl,
  );

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Settings')),
    body: ListView(
      padding: const EdgeInsets.all(16),
      children: [
        TextField(
          controller: url,
          decoration: deco('Server URL', hint: defaultBaseUrl),
          keyboardType: TextInputType.url,
        ),
        const Padding(
          padding: EdgeInsets.only(top: 4, left: 12),
          child: Text(
            'Android emulator reaches the host machine at 10.0.2.2.',
            style: TextStyle(fontSize: 12),
          ),
        ),
        gap,
        FilledButton(
          onPressed: () async {
            final settings = ref.read(settingsRepositoryProvider);
            await settings.setBaseUrl(url.text);
            refreshAll(ref);
            if (!context.mounted) return;
            toast(context, 'Saved. Server URL: ${settings.baseUrl}');
            Navigator.pop(context);
          },
          child: const Text('Save'),
        ),
      ],
    ),
  );
}
