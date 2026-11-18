import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../data/repositories/settings_repository.dart';
import '../../../domain/auth_validators.dart';
import '../../../providers.dart';
import '../../../routing/routes.dart';
import '../../core/widgets/common.dart';
import '../../sync/view_models/sync_actions.dart';
import '../../more/view_models/settings_actions.dart';
import '../../sync/widgets/sync_screen.dart';
import '../view_models/auth_actions.dart';
import 'auth_form.dart';

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});
  @override
  ConsumerState<LoginScreen> createState() => _State();
}

class _State extends ConsumerState<LoginScreen> {
  final _email = TextEditingController();
  final _password = TextEditingController();

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AuthForm(
    title: 'Sign in to MetaFrames',
    showLogo: true,
    description: 'Access your roll logs, gear stash and darkroom archives.',
    submitLabel: 'Log in',
    onGoogle: ref.read(authActionsProvider).googleAvailable
        ? ref.read(authActionsProvider).signInWithGoogle
        : null,
    // A debug build's server URL has to be reachable before anyone can sign
    // in. A build with a fixed server has no server settings to open.
    bottom: SafeArea(
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onDoubleTap: ref.read(settingsActionsProvider).canChooseServer
            ? () => context.push(Routes.settings)
            : null,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Text(
            '© ${DateTime.now().year} MetaFrames',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
        ),
      ),
    ),
    onSubmit: () => ref
        .read(authActionsProvider)
        .login(email: _email.text, password: _password.text),
    fields: [
      const _SessionEndedNotice(),
      AuthField(
        label: 'Email',
        hint: 'you@example.com',
        controller: _email,
        validator: AuthValidators.email,
        keyboardType: TextInputType.emailAddress,
        autofillHints: const [AutofillHints.email],
      ),
      AuthField(
        label: 'Password',
        hint: 'Enter your password',
        controller: _password,
        validator: AuthValidators.currentPassword,
        autofillHints: const [AutofillHints.password],
        password: true,
        lastField: true,
      ),
    ],
    footer: [
      const _KeptOnPhone(),
      TextButton(
        onPressed: () => context.push(Routes.recover),
        child: const Text('Forgot password?'),
      ),
      TextButton(
        onPressed: () => context.push(Routes.register),
        child: const Text('New to the darkroom? Create an account'),
      ),
    ],
  );
}

/// Tells the user, once, that this launch ended the stored session.
class _SessionEndedNotice extends ConsumerStatefulWidget {
  const _SessionEndedNotice();
  @override
  ConsumerState<_SessionEndedNotice> createState() => _NoticeState();
}

class _NoticeState extends ConsumerState<_SessionEndedNotice> {
  late final _show = ref.read(sessionEndedAtStartupProvider).take();

  @override
  Widget build(BuildContext context) => _show
      ? const Padding(
          padding: EdgeInsets.only(bottom: 12),
          child: WarningBanner([
            'Please sign in again. Your saved offline work stays on this '
                'device.',
          ]),
        )
      : const SizedBox.shrink();
}

/// Says what this phone keeps for accounts on this server, so a user whose
/// session expired knows their changes wait for them. Counts only.
class _KeptOnPhone extends ConsumerWidget {
  const _KeptOnPhone();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final server = normalizeBaseUrl(
      ref.read(settingsRepositoryProvider).baseUrl,
    );
    final kept = [
      for (final p in ref.watch(partitionsProvider).value ?? const [])
        if (p.key.server == server && p.hasUnsynced) p,
    ];
    if (kept.isEmpty) return const SizedBox.shrink();
    final cs = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Column(
        children: [
          for (final p in kept)
            Text(
              '${partitionCounts(p)} kept on this phone for ${p.email}. Sign in as ${p.email} to sync them.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 13, color: cs.onSurfaceVariant),
            ),
        ],
      ),
    );
  }
}
