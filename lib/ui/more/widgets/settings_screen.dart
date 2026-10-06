import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../data/repositories/settings_repository.dart';
import '../../core/widgets/common.dart';
import '../../core/widgets/form_kit.dart';
import '../view_models/settings_actions.dart';

import '../../../routing/navigation.dart';

class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});
  @override
  ConsumerState<SettingsScreen> createState() => _State();
}

class _State extends ConsumerState<SettingsScreen> {
  late final url = TextEditingController(
    text: ref.read(settingsActionsProvider).baseUrl,
  );

  @override
  void dispose() {
    url.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: formAppBar(context, 'Settings'),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          LabeledField(
            label: 'Server URL',
            gapAfter: 8,
            child: TextField(
              controller: url,
              decoration: formInputDecoration(defaultBaseUrl, cs),
              keyboardType: TextInputType.url,
            ),
          ),
          const FormNote(
            'Android emulator reaches the host machine at 10.0.2.2.',
          ),
          FormSaveBar(label: 'Save', busy: false, onPressed: _save),
        ],
      ),
    );
  }

  Future<void> _save() async {
    final saved = await ref.read(settingsActionsProvider).saveBaseUrl(url.text);
    if (!mounted) return;
    toast(context, 'Saved. Server URL: $saved');
    context.closeScreen();
  }
}
