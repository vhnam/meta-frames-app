import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:go_router/go_router.dart';

import '../../../data/repositories/settings_repository.dart';
import '../../../domain/models/saved_server.dart';
import '../../../providers.dart';
import '../../core/theme.dart';
import '../../../routing/routes.dart';
import '../../auth/view_models/auth_actions.dart';
import '../../core/widgets/cards.dart';
import '../../core/widgets/common.dart';
import '../../core/widgets/form_kit.dart';
import '../../sync/view_models/sync_summary.dart';
import '../../sync/widgets/sync_screen.dart';
import '../view_models/settings_actions.dart';

import '../../../routing/navigation.dart';

class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});
  @override
  ConsumerState<SettingsScreen> createState() => _State();
}

class _State extends ConsumerState<SettingsScreen> {
  /// The server the Save button applies. Rows change it; Save writes it.
  late String _selected = ref.read(settingsActionsProvider).baseUrl;

  /// Settings stays open without a session, so the account groups follow the
  /// token while the screen shows.
  late final _session = ref.read(sessionStoreProvider);

  @override
  void initState() {
    super.initState();
    _session.addListener(_sessionChanged);
  }

  @override
  void dispose() {
    _session.removeListener(_sessionChanged);
    super.dispose();
  }

  void _sessionChanged() => setState(() {});

  @override
  Widget build(BuildContext context) {
    final actions = ref.read(settingsActionsProvider);
    final signedIn = _session.signedIn;
    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          if (signedIn) ..._accountGroups(),
          LabeledField(
            label: 'Appearance',
            child: SegmentedButton<ThemeMode>(
              segments: const [
                ButtonSegment(value: ThemeMode.system, label: Text('System')),
                ButtonSegment(value: ThemeMode.light, label: Text('Light')),
                ButtonSegment(value: ThemeMode.dark, label: Text('Dark')),
              ],
              selected: {ref.watch(themeModeProvider)},
              onSelectionChanged: (modes) =>
                  ref.read(themeModeProvider.notifier).set(modes.single),
            ),
          ),
          if (actions.canChooseServer) ..._serverControls(actions),
          if (signedIn)
            CardList(
              children: [
                ListTile(
                  leading: const Icon(Icons.logout),
                  title: const Text('Log out'),
                  onTap: _logOut,
                ),
              ],
            ),
        ],
      ),
    );
  }

  /// Account and Sync, for a signed-in session only. The profile does not
  /// gate them: a failed read must not hide the way to log out.
  List<Widget> _accountGroups() {
    final profile = ref.watch(currentUserProvider);
    // A profile still loading may be the previous account's.
    final user = profile.isLoading || profile.hasError ? null : profile.value;
    final summary = ref.watch(syncSummaryProvider);
    final cs = Theme.of(context).colorScheme;
    return [
      if (user != null) ...[
        const DetailLabel('Account', top: 0),
        CardList(
          children: [
            ListTile(
              leading: const Icon(Icons.person_outline),
              title: Text(
                user.name?.isNotEmpty == true ? user.name! : user.email,
              ),
              subtitle: user.name?.isNotEmpty == true ? Text(user.email) : null,
            ),
          ],
        ),
      ],
      if (summary != null) ...[
        DetailLabel('Sync', top: user == null ? 0 : 20),
        CardList(
          children: [
            Semantics(
              hint: 'Opens Sync status',
              child: ListTile(
                leading: Icon(
                  summary.attention
                      ? Icons.error_outline
                      : Icons.cloud_sync_outlined,
                  color: summary.attention ? cs.error : null,
                ),
                title: const Text('Sync status'),
                subtitle: Text(
                  summary.line,
                  style: summary.attention ? TextStyle(color: cs.error) : null,
                ),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => context.push(Routes.sync),
              ),
            ),
          ],
        ),
      ],
      gap,
    ];
  }

  /// Logs out after the keep-or-discard choice, then opens Login: Settings
  /// is open without a session, so the router does not leave it.
  Future<void> _logOut() async {
    final discard = await askKeepOrDiscard(context, ref, action: 'Log out');
    // Leaving Settings during the unsynced check cancels the logout.
    if (discard == null || !mounted) return;
    try {
      await ref.read(authActionsProvider).logout(discardKept: discard);
    } finally {
      if (mounted && !_session.signedIn) context.go(Routes.login);
    }
  }

  /// Read only when the build lets the user choose a server: a malformed
  /// saved list must not stop Appearance from opening.
  List<Widget> _serverControls(SettingsActions actions) {
    final servers = actions.servers;
    final selected = normalizeBaseUrl(_selected);
    final inUse = normalizeBaseUrl(actions.baseUrl);
    final unsaved = !servers.any((server) => server.url == selected);
    return [
      const DetailLabel('Connection', top: 0),
      LabeledField(
        label: 'Saved servers',
        gapAfter: 8,
        // Flexible, so a large text size wraps the label, not overflows.
        trailing: Flexible(
          child: Align(
            alignment: Alignment.centerRight,
            child: TextButton.icon(
              onPressed: () => _addServer(),
              icon: const Icon(Icons.add),
              label: const Text('Add server', maxLines: 2),
            ),
          ),
        ),
        child: _ServerList(
          rows: [
            if (unsaved)
              _ServerRow(
                name: 'Unsaved server',
                url: selected,
                selected: true,
                inUse: selected == inUse,
                onTap: () {},
                onSave: () => _addServer(selected),
              ),
            for (final server in servers)
              _ServerRow(
                name: server.name,
                url: server.url,
                selected: server.url == selected,
                inUse: server.url == inUse,
                onTap: () => setState(() => _selected = server.url),
                onDelete: () => _delete(server),
              ),
          ],
        ),
      ),
      const FormNote('Changing the server logs you out.'),
      // Save applies the selected row; selecting alone changes nothing.
      Align(
        alignment: Alignment.centerRight,
        child: TextButton(
          style: TextButton.styleFrom(minimumSize: const Size(48, 48)),
          onPressed: _save,
          child: const Text('Save'),
        ),
      ),
      gap,
    ];
  }

  Future<void> _addServer([String url = '']) async {
    final actions = ref.read(settingsActionsProvider);
    final added = await showDialog<({String name, String url})>(
      context: context,
      builder: (_) => _AddServerDialog(url: url, saved: actions.servers),
    );
    if (added == null) return;
    await actions.saveServer(added.name, added.url);
    if (mounted) setState(() => _selected = added.url);
  }

  Future<void> _delete(SavedServer server) async {
    final ok = await confirm(
      context,
      'Delete ${server.name}?',
      'This removes it from the saved servers.',
      ok: 'Delete',
    );
    if (!ok || !mounted) return;
    final actions = ref.read(settingsActionsProvider);
    await actions.deleteServer(server.url);
    if (!mounted) return;
    // A deleted row must not stay selected for Save to switch to.
    setState(() {
      if (normalizeBaseUrl(_selected) == server.url) {
        _selected = actions.baseUrl;
      }
    });
  }

  Future<void> _save() async {
    final actions = ref.read(settingsActionsProvider);
    var discard = false;
    final changing =
        normalizeBaseUrl(_selected) != normalizeBaseUrl(actions.baseUrl);
    if (changing && actions.signedIn) {
      final choice = await askKeepOrDiscard(
        context,
        ref,
        action: 'Change server',
      );
      if (choice == null) return;
      discard = choice;
    }
    final saved = await actions.saveBaseUrl(_selected, discardKept: discard);
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

/// The saved servers in one bordered card, divided by hairlines.
class _ServerList extends StatelessWidget {
  const _ServerList({required this.rows});
  final List<Widget> rows;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        border: Border.all(color: cs.outlineVariant, width: kHairline),
        borderRadius: BorderRadius.circular(kStampRadius),
      ),
      child: Column(
        children: [
          for (var index = 0; index < rows.length; index++) ...[
            if (index > 0) const Divider(),
            rows[index],
          ],
          if (rows.isEmpty)
            const Padding(
              padding: EdgeInsets.all(16),
              child: Text('No saved servers.'),
            ),
        ],
      ),
    );
  }
}

class _ServerRow extends StatelessWidget {
  const _ServerRow({
    required this.name,
    required this.url,
    required this.selected,
    required this.inUse,
    required this.onTap,
    this.onDelete,
    this.onSave,
  });
  final String name, url;
  final bool selected, inUse;
  final VoidCallback onTap;

  /// Set on a saved server; null on the unsaved row.
  final VoidCallback? onDelete;

  /// Set on the unsaved row only.
  final VoidCallback? onSave;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Semantics(
      selected: selected,
      child: Material(
        color: selected ? cs.primary.withValues(alpha: 0.08) : cs.surface,
        child: InkWell(
          onTap: onTap,
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 56),
            child: Padding(
              padding: const EdgeInsets.only(left: 12),
              child: Row(
                children: [
                  Icon(
                    selected
                        ? Icons.radio_button_checked
                        : Icons.radio_button_unchecked,
                    color: selected ? cs.primary : cs.onSurfaceVariant,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Wrap(
                            spacing: 8,
                            runSpacing: 4,
                            crossAxisAlignment: WrapCrossAlignment.center,
                            children: [
                              Text(
                                name,
                                style: Theme.of(context).textTheme.titleMedium
                                    ?.copyWith(fontWeight: FontWeight.w600),
                              ),
                              if (inUse)
                                StampBadge('In use', color: cs.primary),
                            ],
                          ),
                          const SizedBox(height: 2),
                          Text(
                            url,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: monoStyle(
                              fontSize: 12,
                              letterSpacing: 0,
                              color: cs.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  if (onSave != null)
                    Flexible(
                      child: TextButton(
                        onPressed: onSave,
                        child: const Text('Add to saved', maxLines: 2),
                      ),
                    ),
                  if (onDelete != null)
                    IconButton(
                      tooltip: 'Delete $name',
                      icon: const Icon(Icons.delete_outline),
                      onPressed: onDelete,
                    )
                  else
                    const SizedBox(width: 4),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Asks for a server's name and URL. Returns both (the URL normalized), or
/// null when cancelled.
class _AddServerDialog extends StatefulWidget {
  const _AddServerDialog({required this.url, required this.saved});
  final String url;
  final List<SavedServer> saved;

  @override
  State<_AddServerDialog> createState() => _AddServerDialogState();
}

class _AddServerDialogState extends State<_AddServerDialog> {
  final _name = TextEditingController();
  late final _url = TextEditingController(text: widget.url);
  String? _error;

  @override
  void dispose() {
    _name.dispose();
    _url.dispose();
    super.dispose();
  }

  void _add() {
    final valid = validDashboardUrl(_url.text);
    if (valid == null) {
      setState(() => _error = 'Enter an http:// or https:// address');
      return;
    }
    for (final server in widget.saved) {
      if (validDashboardUrl(server.url) == valid) {
        setState(() => _error = 'Already saved as ${server.name}');
        return;
      }
    }
    // validDashboardUrl only accepts; the stored form keeps the typed host
    // and port, so an active URL is not rewritten into a server change.
    Navigator.of(context)
        .pop((name: _name.text.trim(), url: normalizeBaseUrl(_url.text)));
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return AlertDialog(
      title: const Text('Add server'),
      scrollable: true,
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // labelText, not LabeledField: a screen reader hears each name once.
          TextField(
            controller: _name,
            autofocus: true,
            decoration: formInputDecoration('Production', cs).copyWith(
              labelText: 'Name',
              floatingLabelBehavior: FloatingLabelBehavior.always,
            ),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _url,
            decoration: formInputDecoration(defaultBaseUrl, cs).copyWith(
              labelText: 'Server URL',
              floatingLabelBehavior: FloatingLabelBehavior.always,
              errorText: _error,
            ),
            keyboardType: TextInputType.url,
            autocorrect: false,
            onChanged: (_) {
              if (_error != null) setState(() => _error = null);
            },
          ),
          const SizedBox(height: 8),
          const FormNote(
            'Android emulator reaches the host machine at 10.0.2.2.',
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        ListenableBuilder(
          listenable: Listenable.merge([_name, _url]),
          builder: (context, _) => TextButton(
            onPressed: _name.text.trim().isEmpty || _url.text.trim().isEmpty
                ? null
                : _add,
            child: const Text('Add'),
          ),
        ),
      ],
    );
  }
}
