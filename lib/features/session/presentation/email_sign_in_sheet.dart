import 'package:flutter/material.dart';

import '../../../core/studafy_design.dart';
import '../../../l10n/generated/app_l10n.dart';
import '../application/session_interactor.dart';
import '../domain/session_repository.dart';

/// Email and password sign-in, for accounts Studafy sets up itself - the
/// app store reviewers' demo accounts among them (docs/store/reviewer-access.md).
///
/// It is offered in every build, as a secondary choice under the providers:
/// a login that only reviewers could find is grounds for rejection on its
/// own. It deliberately has no "create account" and no "forgot password":
/// the server refuses email sign-up, and these accounts' passwords are
/// rotated by Studafy, never reset by mail.
///
/// Completes with true once a session exists. The login screen then finishes
/// the sign-in from its session listener, exactly as for a provider.
Future<bool> showEmailSignInSheet(
  BuildContext context,
  SessionInteractor session,
) async {
  final signedIn = await showModalBottomSheet<bool>(
    context: context,
    showDragHandle: true,
    isScrollControlled: true,
    builder: (_) => EmailSignInForm(session: session),
  );
  return signedIn ?? false;
}

/// The sheet's content: separate from [showEmailSignInSheet] so a test can
/// pump it directly.
class EmailSignInForm extends StatefulWidget {
  const EmailSignInForm({super.key, required this.session});

  final SessionInteractor session;

  @override
  State<EmailSignInForm> createState() => _EmailSignInFormState();
}

class _EmailSignInFormState extends State<EmailSignInForm> {
  final _email = TextEditingController();
  final _password = TextEditingController();
  final _passwordFocus = FocusNode();
  bool _obscured = true;
  bool _busy = false;

  /// What went wrong, already in the reader's language. One message at a
  /// time, announced to screen readers as it appears.
  String? _error;

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    _passwordFocus.dispose();
    super.dispose();
  }

  /// Deliberately loose: the server decides. This only catches the
  /// obvious slip of typing a name where the address goes.
  static bool _looksLikeEmail(String value) =>
      RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(value);

  Future<void> _submit() async {
    if (_busy) return;
    final l10n = AppL10n.of(context);
    final email = _email.text.trim();
    final password = _password.text;
    final invalid = email.isEmpty
        ? l10n.loginEmailMissing
        : !_looksLikeEmail(email)
        ? l10n.loginEmailInvalid
        : password.isEmpty
        ? l10n.loginPasswordMissing
        : null;
    if (invalid != null) {
      setState(() => _error = invalid);
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    final failure = await widget.session.signInWithPassword(
      email: email,
      password: password,
    );
    if (!mounted) return;
    if (failure == null) {
      Navigator.of(context).pop(true);
      return;
    }
    setState(() {
      _busy = false;
      // A wrong password is retyped, not the address.
      if (failure == PasswordSignInError.invalidCredentials) {
        _password.clear();
      }
      _error = switch (failure) {
        PasswordSignInError.invalidCredentials => l10n.loginEmailWrong,
        PasswordSignInError.tooManyAttempts => l10n.loginEmailTooMany,
        PasswordSignInError.network => l10n.loginEmailOffline,
        PasswordSignInError.unavailable => l10n.loginEmailUnavailable,
      };
    });
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppL10n.of(context);
    final error = _error;
    return SafeArea(
      child: Padding(
        // Lifted above the keyboard, so the button is never hidden by it.
        padding: EdgeInsetsDirectional.fromSTEB(
          24,
          0,
          24,
          20 + MediaQuery.viewInsetsOf(context).bottom,
        ),
        child: AutofillGroup(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Semantics(
                header: true,
                child: Text(
                  l10n.loginWithEmail,
                  style: const TextStyle(
                    color: studafyInk,
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              const SizedBox(height: 6),
              Text(
                l10n.loginEmailNote,
                style: const TextStyle(color: studafyMuted, height: 1.4),
              ),
              const SizedBox(height: 18),
              TextField(
                key: const Key('emailSignInAddress'),
                controller: _email,
                enabled: !_busy,
                keyboardType: TextInputType.emailAddress,
                textInputAction: TextInputAction.next,
                autocorrect: false,
                enableSuggestions: false,
                autofillHints: const [AutofillHints.email],
                // An address reads left to right in either language.
                textDirection: TextDirection.ltr,
                decoration: InputDecoration(
                  labelText: l10n.loginEmailLabel,
                  border: const OutlineInputBorder(),
                ),
                onSubmitted: (_) => _passwordFocus.requestFocus(),
              ),
              const SizedBox(height: 12),
              TextField(
                key: const Key('emailSignInPassword'),
                controller: _password,
                focusNode: _passwordFocus,
                enabled: !_busy,
                obscureText: _obscured,
                autocorrect: false,
                enableSuggestions: false,
                textInputAction: TextInputAction.done,
                autofillHints: const [AutofillHints.password],
                textDirection: TextDirection.ltr,
                decoration: InputDecoration(
                  labelText: l10n.loginPasswordLabel,
                  border: const OutlineInputBorder(),
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
                onSubmitted: (_) => _submit(),
              ),
              if (error != null)
                Padding(
                  padding: const EdgeInsets.only(top: 12),
                  child: Semantics(
                    liveRegion: true,
                    child: Text(
                      error,
                      key: const Key('emailSignInError'),
                      style: const TextStyle(
                        color: Color(0xFFB42318),
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
              const SizedBox(height: 18),
              FilledButton(
                key: const Key('emailSignInSubmit'),
                onPressed: _busy ? null : _submit,
                style: FilledButton.styleFrom(
                  minimumSize: const Size.fromHeight(52),
                ),
                child: _busy
                    ? SizedBox.square(
                        dimension: 22,
                        child: CircularProgressIndicator(
                          strokeWidth: 2.5,
                          semanticsLabel: l10n.loginEmailSubmit,
                        ),
                      )
                    : Text(l10n.loginEmailSubmit),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
