import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:go_router/go_router.dart';

import '../../../data/repositories/settings_repository.dart';
import '../../../domain/models/saved_server.dart';
import '../../../routing/routes.dart';
import '../../core/widgets/common.dart';
import '../../core/widgets/form_kit.dart';
import '../../sync/widgets/sync_screen.dart';
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

  /// The dashboard of the server in [url]; follows the server picked.
  late final dashboard = TextEditingController(
    text: ref.read(settingsActionsProvider).dashboardUrl(),
  );
  String? _dashboardError;

  @override
  void dispose() {
    url.dispose();
    dashboard.dispose();
    super.dispose();
  }

  void _pick(String server) {
    url.text = server;
    dashboard.text =
        ref.read(settingsActionsProvider).dashboardUrl(server) ?? '';
    setState(() => _dashboardError = null);
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final servers = ref.read(settingsActionsProvider).servers;
    return Scaffold(
      appBar: formAppBar(context, 'Settings'),
      body: ListenableBuilder(
        listenable: url,
        builder: (context, _) {
          final entered = normalizeBaseUrl(url.text);
          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              LabeledField(
                label: 'Appearance',
                child: SegmentedButton<ThemeMode>(
                  segments: const [
                    ButtonSegment(
                      value: ThemeMode.system,
                      label: Text('System'),
                    ),
                    ButtonSegment(value: ThemeMode.light, label: Text('Light')),
                    ButtonSegment(value: ThemeMode.dark, label: Text('Dark')),
                  ],
                  selected: {ref.watch(themeModeProvider)},
                  onSelectionChanged: (s) =>
                      ref.read(themeModeProvider.notifier).set(s.single),
                ),
              ),
              if (servers.isNotEmpty)
                LabeledField(
                  label: 'Saved servers',
                  child: Column(
                    children: [
                      for (final s in servers)
                        _ServerRow(
                          server: s,
                          selected: s.url == entered,
                          onTap: () => _pick(s.url),
                          onDelete: () => _delete(s),
                        ),
                    ],
                  ),
                ),
              LabeledField(
                label: 'Server URL',
                gapAfter: 8,
                trailing: TextButton(
                  onPressed: entered.isEmpty ? null : () => _addServer(entered),
                  child: const Text('Add to saved'),
                ),
                child: TextField(
                  controller: url,
                  decoration: formInputDecoration(defaultBaseUrl, cs),
                  keyboardType: TextInputType.url,
                ),
              ),
              const FormNote(
                'Android emulator reaches the host machine at 10.0.2.2. '
                'Changing the server logs you out.',
              ),
              LabeledField(
                label: 'Dashboard URL (optional)',
                gapAfter: 8,
                child: TextField(
                  controller: dashboard,
                  decoration: formInputDecoration(
                    'https://dashboard.example.com',
                    cs,
                  ).copyWith(errorText: _dashboardError),
                  keyboardType: TextInputType.url,
                  onChanged: (_) {
                    if (_dashboardError != null) {
                      setState(() => _dashboardError = null);
                    }
                  },
                ),
              ),
              const FormNote(
                'The web dashboard for this server. More links to it.',
              ),
              FormSaveBar(label: 'Save', busy: false, onPressed: _save),
            ],
          );
        },
      ),
    );
  }

  Future<void> _addServer(String entered) async {
    final actions = ref.read(settingsActionsProvider);
    final existing = actions.servers.where((s) => s.url == entered);
    final name = await showDialog<String>(
      context: context,
      builder: (_) => _ServerNameDialog(
        url: entered,
        name: existing.isEmpty ? null : existing.first.name,
      ),
    );
    if (name == null) return;
    await actions.saveServer(name, entered);
    if (mounted) setState(() {});
  }

  Future<void> _delete(SavedServer server) async {
    await ref.read(settingsActionsProvider).deleteServer(server.url);
    if (mounted) setState(() {});
  }

  Future<void> _save() async {
    final actions = ref.read(settingsActionsProvider);
    final dash = dashboard.text.trim();
    if (dash.isNotEmpty && validDashboardUrl(dash) == null) {
      setState(() => _dashboardError = 'Enter an http:// or https:// address');
      return;
    }
    var discard = false;
    final changing =
        normalizeBaseUrl(url.text) != normalizeBaseUrl(actions.baseUrl);
    if (changing && actions.signedIn) {
      final choice = await askKeepOrDiscard(
        context,
        ref,
        action: 'Change server',
      );
      if (choice == null) return;
      discard = choice;
    }
    final saved = await actions.saveBaseUrl(url.text, discardKept: discard);
    await actions.setDashboardUrl(saved, dash.isEmpty ? null : dash);
    if (!mounted) return;
    toast(context, 'Saved. Server URL: $saved');
    // Without a session, the screens under this one need one too.
    if (actions.signedIn) {
      context.closeScreen();
    } else {
      context.go(Routes.login);
    }
  }
}

class _ServerRow extends StatelessWidget {
  const _ServerRow({
    required this.server,
    required this.selected,
    required this.onTap,
    required this.onDelete,
  });
  final SavedServer server;
  final bool selected;
  final VoidCallback onTap, onDelete;

  @override
  Widget build(BuildContext context) => ListTile(
    contentPadding: EdgeInsets.zero,
    selected: selected,
    leading: Icon(
      selected ? Icons.radio_button_checked : Icons.radio_button_unchecked,
    ),
    title: Text(server.name),
    subtitle: Text(server.url),
    trailing: IconButton(
      tooltip: 'Delete ${server.name}',
      icon: const Icon(Icons.delete_outline),
      onPressed: onDelete,
    ),
    onTap: onTap,
  );
}

/// Asks for a saved server's name. Returns the name, or null when cancelled.
class _ServerNameDialog extends StatefulWidget {
  const _ServerNameDialog({required this.url, this.name});
  final String url;
  final String? name;

  @override
  State<_ServerNameDialog> createState() => _ServerNameDialogState();
}

class _ServerNameDialogState extends State<_ServerNameDialog> {
  late final _name = TextEditingController(text: widget.name);

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: const Text('Save server'),
    content: Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(widget.url),
        const SizedBox(height: 12),
        TextField(
          controller: _name,
          autofocus: true,
          decoration: formInputDecoration(
            'Name, like Production',
            Theme.of(context).colorScheme,
          ),
        ),
      ],
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.of(context).pop(),
        child: const Text('Cancel'),
      ),
      ListenableBuilder(
        listenable: _name,
        builder: (context, _) => TextButton(
          onPressed: _name.text.trim().isEmpty
              ? null
              : () => Navigator.of(context).pop(_name.text.trim()),
          child: const Text('Add'),
        ),
      ),
    ],
  );
}
