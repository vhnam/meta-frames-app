import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../data/local/local_store.dart';
import '../../../data/repositories/settings_repository.dart';
import '../../../data/services/session_store.dart';
import '../../../domain/models/saved_server.dart';
import '../../../providers.dart';
import '../../../routing/routes.dart';
import '../../core/theme.dart';
import '../../core/widgets/cards.dart';
import '../../core/widgets/common.dart';
import '../../core/widgets/form_kit.dart';
import '../../sync/widgets/sync_screen.dart';
import '../view_models/settings_actions.dart';

/// The debug server list at [Routes.savedServers]. Selecting a row changes
/// nothing until Save applies it.
class SavedServersScreen extends ConsumerStatefulWidget {
  const SavedServersScreen({super.key});
  @override
  ConsumerState<SavedServersScreen> createState() => _State();
}

class _State extends ConsumerState<SavedServersScreen> {
  /// The server the Save button applies. Rows change it; Save writes it.
  late String _selected = ref.read(settingsActionsProvider).baseUrl;

  /// Back to whoever pushed this screen. A direct link has no caller, so it
  /// returns to Settings.
  void _leave() {
    final router = GoRouter.of(context);
    if (router.canPop()) {
      router.pop();
    } else {
      router.go(Routes.settings);
    }
  }

  @override
  Widget build(BuildContext context) {
    final actions = ref.read(settingsActionsProvider);
    final servers = actions.servers;
    final selected = normalizeBaseUrl(_selected);
    final inUse = normalizeBaseUrl(actions.baseUrl);
    final unsaved = !servers.any((server) => server.url == selected);
    return PopScope(
      // A direct link has nothing to pop to: system Back opens Settings.
      canPop: GoRouter.of(context).canPop(),
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _leave();
      },
      child: Scaffold(
        appBar: AppBar(
          leading: BackButton(onPressed: _leave),
          title: const Text('Server connection'),
          actions: [
            // Same label rule as Gear and Labs: contextual while the list is empty.
            TextButton(
              onPressed: () => _addServer(),
              child: Text(servers.isEmpty ? '+ Server' : '+ Add'),
            ),
            const SizedBox(width: 8),
          ],
        ),
        body: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            LabeledField(
              label: 'Saved servers',
              gapAfter: 8,
              child: CardList(
                children: [
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
                  if (servers.isEmpty && !unsaved)
                    const Padding(
                      padding: EdgeInsets.all(16),
                      child: Text('No saved servers.'),
                    ),
                ],
              ),
            ),
            const FormNote('Changing the server logs you out.'),
            // Save applies the selected row; selecting alone changes nothing.
            FormSaveBar(label: 'Save', busy: false, onPressed: _save),
          ],
        ),
      ),
    );
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

  /// The partition the session has confirmed, or null before `/auth/me`.
  static PartitionKey? _bound(SessionStore session) {
    final binding = session.binding;
    return binding == null
        ? null
        : PartitionKey(binding.server, binding.userId);
  }

  /// A confirmation belongs to the session that opened it: its answer is
  /// ignored once that session ends or changes, so it never discards another
  /// account's work.
  Future<void> _save() async {
    final router = GoRouter.of(context);
    final session = ref.read(sessionStoreProvider);
    final generation = session.generation;
    final bound = _bound(session);
    final actions = ref.read(settingsActionsProvider);
    var discard = false;
    final changing =
        normalizeBaseUrl(_selected) != normalizeBaseUrl(actions.baseUrl);
    if (changing && session.signedIn) {
      // The confirmation counts the open store's work: a store that lags the
      // binding would count, and discard, another account's.
      if (ref.read(localStoreProvider)?.key != bound) {
        toast(context, 'Try again in a moment');
        return;
      }
      final choice = await askKeepOrDiscard(
        context,
        ref,
        action: 'Change server',
      );
      // No await from here to saveBaseUrl, which reads the open store first.
      if (choice == null ||
          !mounted ||
          session.generation != generation ||
          _bound(session) != bound) {
        return;
      }
      // Keep discards nothing, so only Discard needs the same open store.
      if (choice && ref.read(localStoreProvider)?.key != bound) return;
      discard = choice;
    }
    final String saved;
    try {
      saved = await actions.saveBaseUrl(_selected, discardKept: discard);
    } catch (error) {
      // A failed save stays on this screen: no success notice, no navigation.
      if (mounted) toast(context, 'Could not save the server. $error');
      return;
    }
    if (mounted) toast(context, 'Saved. Server URL: $saved');
    // Without a session, the screens under this one need one too.
    if (!session.signedIn) {
      router.go(Routes.login);
    } else if (mounted && ModalRoute.of(context)?.isCurrent == true) {
      // A late completion must not pop the screen the user went back to.
      _leave();
    }
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
        color: selected
            ? cs.primary.withValues(alpha: 0.08)
            : Colors.transparent,
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
    final valid = validServerUrl(_url.text);
    if (valid == null) {
      setState(() => _error = 'Enter an http:// or https:// address');
      return;
    }
    for (final server in widget.saved) {
      if (validServerUrl(server.url) == valid) {
        setState(() => _error = 'Already saved as ${server.name}');
        return;
      }
    }
    // validServerUrl only accepts; the stored form keeps the typed host
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
