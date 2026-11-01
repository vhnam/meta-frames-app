import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../domain/auth_validators.dart';
import '../../../routing/navigation.dart';
import '../view_models/auth_actions.dart';
import 'auth_form.dart';

/// Requests a reset email. The link in the email opens the web dashboard, where
/// the user sets the new password.
class RecoverScreen extends ConsumerStatefulWidget {
  const RecoverScreen({super.key});
  @override
  ConsumerState<RecoverScreen> createState() => _State();
}

class _State extends ConsumerState<RecoverScreen> {
  final _email = TextEditingController();
  String? _sent;

  @override
  void dispose() {
    _email.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final message = await ref.read(authActionsProvider).recover(_email.text);
    if (mounted) setState(() => _sent = message);
  }

  @override
  Widget build(BuildContext context) {
    final back = TextButton(
      onPressed: () => context.closeScreen(),
      child: const Text('Back to log in'),
    );
    final sent = _sent;
    if (sent != null) {
      return Scaffold(
        appBar: AppBar(),
        body: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'Check your email',
                style: Theme.of(context).textTheme.headlineSmall,
              ),
              const SizedBox(height: 8),
              Text('$sent The link is valid for 24 hours.'),
              const SizedBox(height: 16),
              back,
            ],
          ),
        ),
      );
    }
    return AuthForm(
      title: 'Forgot your password?',
      description: 'We will email you a link to set a new one.',
      submitLabel: 'Send reset link',
      onSubmit: _submit,
      fields: [
        AuthField(
          label: 'Email',
          hint: 'you@example.com',
          controller: _email,
          validator: AuthValidators.email,
          keyboardType: TextInputType.emailAddress,
          autofillHints: const [AutofillHints.email],
          lastField: true,
        ),
      ],
      footer: [back],
    );
  }
}
