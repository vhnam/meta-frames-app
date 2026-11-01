import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';

import '../../../data/services/api_client.dart';
import '../../../routing/routes.dart';
import '../../core/widgets/common.dart';
import '../../core/widgets/form_kit.dart';
import 'google_button.dart';

/// Page shared by the auth screens: heading, validated fields, submit button
/// and the server's error. Below the form come [footer] widgets.
class AuthForm extends StatefulWidget {
  const AuthForm({
    super.key,
    required this.title,
    required this.description,
    required this.fields,
    required this.submitLabel,
    required this.onSubmit,
    this.onGoogle,
    this.bottom,
    this.footer = const [],
  });

  final String title, description, submitLabel;
  final List<Widget> fields, footer;

  /// Stays at the bottom of the screen, under the scrolling form.
  final Widget? bottom;

  /// Runs when every field is valid. An `ApiException` shows above the fields.
  final Future<void> Function() onSubmit;

  /// Shows "Continue with Google" above the fields. Errors show as for [onSubmit].
  final Future<void> Function()? onGoogle;

  @override
  State<AuthForm> createState() => _AuthFormState();
}

class _AuthFormState extends State<AuthForm> {
  final _formKey = GlobalKey<FormState>();
  bool _busy = false;
  String? _error;
  bool _networkError = false;

  Future<void> _submit() async {
    if (_busy || !_formKey.currentState!.validate()) return;
    await _run(() async {
      await widget.onSubmit();
      TextInput.finishAutofillContext();
    });
  }

  Future<void> _run(Future<void> Function() action) async {
    setState(() {
      _busy = true;
      _error = null;
      _networkError = false;
    });
    try {
      await action();
    } on ApiException catch (error) {
      if (mounted) {
        setState(() {
          _error = error.message;
          _networkError = error.isNetwork;
        });
      }
    } finally {
      // A successful sign-in has already moved the user off this screen.
      if (mounted) setState(() => _busy = false);
    }
  }

  /// The saved URL may be about to change, so the error is out of date.
  void _openSettings() {
    setState(() {
      _error = null;
      _networkError = false;
    });
    context.push(Routes.settings);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(),
      bottomNavigationBar: widget.bottom,
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.only(bottom: 24),
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(widget.title, style: theme.textTheme.headlineSmall),
                  const SizedBox(height: 4),
                  Text(
                    widget.description,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
            if (_error != null) ...[
              WarningBanner([_error!]),
              if (_networkError)
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                  child: OutlinedButton(
                    onPressed: _openSettings,
                    child: const Text('Server settings'),
                  ),
                ),
              const SizedBox(height: 16),
            ],
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Form(
                key: _formKey,
                child: AutofillGroup(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      if (widget.onGoogle case final onGoogle?)
                        GoogleButton(
                          onPressed: _busy ? null : () => _run(onGoogle),
                        ),
                      ...widget.fields,
                      const SizedBox(height: 8),
                      FormSaveBar(
                        label: widget.submitLabel,
                        busy: _busy,
                        onPressed: _submit,
                      ),
                      const SizedBox(height: 16),
                      ...widget.footer,
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Labeled text field for the auth screens. A password field has a show/hide
/// button.
class AuthField extends StatefulWidget {
  const AuthField({
    super.key,
    required this.label,
    required this.hint,
    required this.controller,
    required this.validator,
    this.helper,
    this.autofillHints = const [],
    this.keyboardType,
    this.password = false,
    this.lastField = false,
  });

  final String label, hint;
  final String? helper;
  final TextEditingController controller;
  final String? Function(String?) validator;
  final List<String> autofillHints;
  final TextInputType? keyboardType;
  final bool password, lastField;

  @override
  State<AuthField> createState() => _AuthFieldState();
}

class _AuthFieldState extends State<AuthField> {
  bool _hidden = true;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return LabeledField(
      label: widget.label,
      child: TextFormField(
        controller: widget.controller,
        validator: widget.validator,
        autovalidateMode: AutovalidateMode.onUserInteractionIfError,
        autofillHints: widget.autofillHints,
        keyboardType: widget.keyboardType,
        obscureText: widget.password && _hidden,
        enableSuggestions: !widget.password,
        autocorrect: false,
        textInputAction: widget.lastField
            ? TextInputAction.done
            : TextInputAction.next,
        decoration: formInputDecoration(
          widget.hint,
          colors,
          suffixIcon: widget.password
              ? IconButton(
                  tooltip: _hidden ? 'Show password' : 'Hide password',
                  icon: Icon(
                    _hidden
                        ? Icons.visibility_outlined
                        : Icons.visibility_off_outlined,
                  ),
                  onPressed: () => setState(() => _hidden = !_hidden),
                )
              : null,
        ).copyWith(helperText: widget.helper, helperMaxLines: 2),
      ),
    );
  }
}
