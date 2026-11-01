import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../domain/auth_validators.dart';
import '../../../routing/navigation.dart';
import '../view_models/auth_actions.dart';
import 'auth_form.dart';

class RegisterScreen extends ConsumerStatefulWidget {
  const RegisterScreen({super.key});
  @override
  ConsumerState<RegisterScreen> createState() => _State();
}

class _State extends ConsumerState<RegisterScreen> {
  final _name = TextEditingController();
  final _email = TextEditingController();
  final _password = TextEditingController();
  final _confirm = TextEditingController();

  @override
  void dispose() {
    _name.dispose();
    _email.dispose();
    _password.dispose();
    _confirm.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AuthForm(
    title: 'Create an account',
    description: 'Track every roll, from stock to scan.',
    submitLabel: 'Create account',
    onGoogle: ref.read(authActionsProvider).googleAvailable
        ? ref.read(authActionsProvider).signInWithGoogle
        : null,
    onSubmit: () => ref
        .read(authActionsProvider)
        .register(
          name: _name.text,
          email: _email.text,
          password: _password.text,
        ),
    fields: [
      AuthField(
        label: 'Full name',
        hint: 'e.g. Ansel Adams',
        controller: _name,
        validator: AuthValidators.name,
        keyboardType: TextInputType.name,
        autofillHints: const [AutofillHints.name],
      ),
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
        hint: 'At least 8 characters',
        helper: AuthValidators.passwordHint,
        controller: _password,
        validator: AuthValidators.newPassword,
        autofillHints: const [AutofillHints.newPassword],
        password: true,
      ),
      AuthField(
        label: 'Confirm password',
        hint: 'Repeat the password',
        controller: _confirm,
        validator: (value) =>
            value == _password.text ? null : 'Passwords do not match.',
        autofillHints: const [AutofillHints.newPassword],
        password: true,
        lastField: true,
      ),
    ],
    footer: [
      TextButton(
        onPressed: () => context.closeScreen(),
        child: const Text('Already have an account? Log in'),
      ),
    ],
  );
}
