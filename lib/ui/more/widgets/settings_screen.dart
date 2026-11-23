import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:go_router/go_router.dart';

import '../../../domain/models/models.dart';
import '../../../providers.dart';
import '../../../routing/routes.dart';
import '../../auth/view_models/auth_actions.dart';
import '../../core/theme.dart';
import '../../core/widgets/cards.dart';
import '../../core/widgets/common.dart';
import '../../sync/view_models/sync_summary.dart';
import '../../sync/widgets/sync_screen.dart';
import '../view_models/settings_actions.dart';
import 'saved_servers_screen.dart';

class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});
  @override
  ConsumerState<SettingsScreen> createState() => _State();
}

class _State extends ConsumerState<SettingsScreen> {
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
    // A fixed-server build shows ordinary Settings for the servers link.
    if (actions.canChooseServer && _view(context) == 'servers') {
      return const SavedServersScreen();
    }
    final signedIn = _session.signedIn;
    final theme = ref.watch(themeModeProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          if (signedIn) ..._accountGroups(),
          const DetailLabel('Appearance', top: 0),
          CardList(
            children: [
              Semantics(
                hint: 'Opens a choice of System, Light or Dark',
                child: ListTile(
                  title: const Text('Theme'),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(_themeName(theme)),
                      const Icon(Icons.chevron_right),
                    ],
                  ),
                  onTap: () => _pickTheme(theme),
                ),
              ),
              Semantics(
                hint: 'Opens a choice of language',
                child: ListTile(
                  title: const Text('Language'),
                  trailing: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [Text('English'), Icon(Icons.chevron_right)],
                  ),
                  onTap: _pickLanguage,
                ),
              ),
            ],
          ),
          gap,
          if (actions.canChooseServer) ...[
            const DetailLabel('Connection', top: 0),
            CardList(
              children: [
                ListTile(
                  title: const Text('Server connection'),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => context.push(Routes.savedServers),
                ),
              ],
            ),
            gap,
          ],
          if (signedIn) ...[
            // Extra space on top of the group gap keeps Log out apart.
            gap,
            OutlinedButton(
              style: OutlinedButton.styleFrom(
                minimumSize: const Size.fromHeight(48),
                foregroundColor: Theme.of(context).colorScheme.error,
                side: BorderSide(
                  color: Theme.of(context).colorScheme.error,
                  width: kHairline,
                ),
              ),
              onPressed: _logOut,
              child: const Text('Log out', textAlign: TextAlign.center),
            ),
          ],
        ],
      ),
    );
  }

  /// English is the only language for now; Tiếng Việt is listed, not yet usable.
  Future<void> _pickLanguage() => showModalBottomSheet<void>(
    context: context,
    showDragHandle: true,
    builder: (_) => const _LanguageSheet(),
  );

  /// A dismissed sheet returns null and changes nothing.
  Future<void> _pickTheme(ThemeMode current) async {
    final mode = await showModalBottomSheet<ThemeMode>(
      context: context,
      showDragHandle: true,
      builder: (_) => _ThemeSheet(current: current),
    );
    if (mode == null || mode == current) return;
    await ref.read(themeModeProvider.notifier).set(mode);
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
        AccountCard(user),
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
}

/// The `view` query of this route. Null outside a router, as in a screen test.
String? _view(BuildContext context) => GoRouter.maybeOf(context) == null
    ? null
    : GoRouterState.of(context).uri.queryParameters['view'];

String _themeName(ThemeMode mode) => switch (mode) {
  ThemeMode.system => 'System',
  ThemeMode.light => 'Light',
  ThemeMode.dark => 'Dark',
};

/// The three theme choices. The mark is an icon, so it does not rely on color.
class _ThemeSheet extends StatelessWidget {
  const _ThemeSheet({required this.current});
  final ThemeMode current;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Padding(
              padding: EdgeInsets.fromLTRB(16, 0, 16, 8),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text('Theme', style: TextStyle(fontSize: 18)),
              ),
            ),
            for (final mode in ThemeMode.values)
              Semantics(
                selected: mode == current,
                inMutuallyExclusiveGroup: true,
                child: ListTile(
                  minTileHeight: 48,
                  selected: mode == current,
                  leading: Icon(
                    mode == current
                        ? Icons.radio_button_checked
                        : Icons.radio_button_unchecked,
                  ),
                  title: Text(_themeName(mode)),
                  onTap: () => Navigator.of(context).pop(mode),
                ),
              ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }
}

class _LanguageSheet extends StatelessWidget {
  const _LanguageSheet();

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Padding(
              padding: EdgeInsets.fromLTRB(16, 0, 16, 8),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text('Language', style: TextStyle(fontSize: 18)),
              ),
            ),
            Semantics(
              selected: true,
              inMutuallyExclusiveGroup: true,
              child: ListTile(
                minTileHeight: 48,
                selected: true,
                leading: const Icon(Icons.radio_button_checked),
                title: const Text('English'),
                onTap: () => Navigator.of(context).pop(),
              ),
            ),
            Semantics(
              selected: false,
              inMutuallyExclusiveGroup: true,
              child: const ListTile(
                minTileHeight: 48,
                enabled: false,
                leading: Icon(Icons.radio_button_unchecked),
                title: Text('Tiếng Việt'),
              ),
            ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }
}

/// The signed-in profile, in More and in Settings. It does nothing on tap.
class AccountCard extends ConsumerWidget {
  const AccountCard(this.user, {super.key});
  final User user;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final named = user.name?.isNotEmpty == true;
    const icon = Icon(Icons.person_outline);
    final url = user.avatarUrl;
    return CardList(
      children: [
        ListTile(
          leading: url == null
              ? icon
              : ClipOval(
                  child: SizedBox.square(
                    dimension: 40,
                    child: Image(
                      key: ValueKey(url),
                      image: ref.watch(avatarImageProvider)(url),
                      fit: BoxFit.cover,
                      excludeFromSemantics: true,
                      frameBuilder: (_, child, frame, _) =>
                          frame == null ? icon : child,
                      errorBuilder: (_, _, _) => icon,
                    ),
                  ),
                ),
          title: Text(named ? user.name! : user.email),
          subtitle: named ? Text(user.email) : null,
        ),
      ],
    );
  }
}
