import 'package:flutter/material.dart';

import '../../../l10n/generated/app_l10n.dart';

/// Asks an account that signs in with a password for it again, before an
/// action that needs a sign-in from moments ago - deleting the account,
/// exporting its data (launch plan 2.10). The OAuth accounts get their
/// provider's sign-in instead; this is the same proof for the accounts
/// Studafy provisions, such as the app store reviewers'.
///
/// Completes with the password, or null when the person cancels.
Future<String?> showPasswordReauthDialog(BuildContext context, String email) =>
    showDialog<String>(
      context: context,
      builder: (_) => PasswordReauthDialog(email: email),
    );

class PasswordReauthDialog extends StatefulWidget {
  const PasswordReauthDialog({super.key, required this.email});

  final String email;

  @override
  State<PasswordReauthDialog> createState() => _PasswordReauthDialogState();
}

class _PasswordReauthDialogState extends State<PasswordReauthDialog> {
  final _password = TextEditingController();
  bool _obscured = true;
  bool _missing = false;

  @override
  void dispose() {
    _password.dispose();
    super.dispose();
  }

  void _confirm() {
    if (_password.text.isEmpty) {
      setState(() => _missing = true);
      return;
    }
    Navigator.of(context).pop(_password.text);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppL10n.of(context);
    return AlertDialog(
      title: Text(l10n.reauthPasswordTitle),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(l10n.reauthPasswordBody(widget.email)),
          const SizedBox(height: 14),
          TextField(
            key: const Key('reauthPassword'),
            controller: _password,
            autofocus: true,
            obscureText: _obscured,
            autocorrect: false,
            enableSuggestions: false,
            autofillHints: const [AutofillHints.password],
            textDirection: TextDirection.ltr,
            decoration: InputDecoration(
              labelText: l10n.loginPasswordLabel,
              border: const OutlineInputBorder(),
              errorText: _missing ? l10n.loginPasswordMissing : null,
              suffixIcon: IconButton(
                tooltip: _obscured
                    ? l10n.loginShowPassword
                    : l10n.loginHidePassword,
                icon: Icon(
                  _obscured
                      ? Icons.visibility_rounded
                      : Icons.visibility_off_rounded,
                ),
                onPressed: () => setState(() => _obscured = !_obscured),
              ),
            ),
            onSubmitted: (_) => _confirm(),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(l10n.reauthPasswordCancel),
        ),
        FilledButton(
          key: const Key('reauthPasswordConfirm'),
          onPressed: _confirm,
          child: Text(l10n.reauthPasswordConfirm),
        ),
      ],
    );
  }
}
