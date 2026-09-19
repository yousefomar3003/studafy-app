import 'dart:async';

import 'package:flutter/material.dart';

import '../../../core/studafy_design.dart';
import '../../../l10n/generated/app_l10n.dart';
import '../../../core/studafy_domain.dart';
import '../application/session_interactor.dart';
import '../domain/session_repository.dart';
import 'role_page.dart';

/// The login screen drives [SessionInteractor]; it never touches Supabase,
/// SQLite, or any repository directly (ARC-011 session slice).
class LoginPage extends StatefulWidget {
  const LoginPage({super.key, required this.role, required this.session});
  final UserRole role;
  final SessionInteractor session;

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  bool accepted = false;
  bool signingIn = false;
  bool completingRemoteLogin = false;
  String? error;
  StreamSubscription<bool>? sessionSubscription;

  @override
  void initState() {
    super.initState();
    sessionSubscription = widget.session.sessionChanges.listen((hasSession) {
      if (hasSession) _completeRemoteLogin();
    });
    if (widget.session.hasCurrentSession) {
      _completeRemoteLogin();
    }
  }

  @override
  void dispose() {
    sessionSubscription?.cancel();
    super.dispose();
  }

  StudafyRole get selectedRole => switch (widget.role) {
    UserRole.teacher => StudafyRole.teacher,
    UserRole.parent => StudafyRole.parent,
    UserRole.student => StudafyRole.student,
  };

  Future<void> login(LoginProvider provider) async {
    if (!accepted) return;
    if (widget.session.isDemoSession) {
      widget.session.startDemoSession(selectedRole);
      _openRole();
      return;
    }
    setState(() {
      signingIn = true;
      error = null;
    });
    final result = await widget.session.signInWithProvider(provider);
    if (!result.isSuccess && mounted) {
      setState(() {
        signingIn = false;
        error = result.fold(
          onSuccess: (_) => null,
          onFailure: (failure) => failure.message,
        );
      });
    }
  }

  Future<void> _completeRemoteLogin() async {
    if (!mounted || completingRemoteLogin || widget.session.isDemoSession) {
      return;
    }
    completingRemoteLogin = true;
    final result = await widget.session.completeRemoteLogin(
      role: selectedRole,
      consentAccepted: accepted,
      locale: Localizations.localeOf(context).languageCode,
    );
    completingRemoteLogin = false;
    result.fold(
      onSuccess: (_) {
        if (mounted) _openRole();
      },
      onFailure: (failure) {
        if (mounted) {
          setState(() {
            signingIn = false;
            error = failure.message;
          });
        }
      },
    );
  }

  void _openRole() {
    // The shells are registered as named routes by the app; the session
    // feature never imports the role shells directly.
    final route = switch (widget.role) {
      UserRole.teacher => '/teacher',
      UserRole.parent => '/parent',
      UserRole.student => '/student',
    };
    Navigator.pushNamedAndRemoveUntil(context, route, (_) => false);
  }

  @override
  Widget build(BuildContext c) => AuthFrame(
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const StudafyLogo(size: 36),
        const SizedBox(height: 40),
        Text(
          AppL10n.of(c).loginWelcome(roleLabel(c, widget.role)),
          textAlign: TextAlign.center,
          style: Theme.of(c).textTheme.headlineSmall,
        ),
        const SizedBox(height: 8),
        Text(
          AppL10n.of(c).loginSubtitle,
          textAlign: TextAlign.center,
          style: const TextStyle(color: studafyMuted),
        ),
        const SizedBox(height: 30),
        // Sign in with Apple is required on iOS wherever third-party login
        // establishes the primary account (Apple guideline 4.8). It is hidden
        // where it cannot complete natively rather than offered as a button
        // that fails.
        for (final x in [
          ('G', 'Google', LoginProvider.google),
          ('M', 'Microsoft', LoginProvider.microsoft),
          ('', 'Apple', LoginProvider.apple),
        ])
          if (widget.session.supportsProvider(x.$3))
            SocialButton(
              mark: x.$1,
              label: AppL10n.of(c).loginContinueWith(x.$2),
              onTap: signingIn ? () {} : () => login(x.$3),
            ),
        if (signingIn)
          const Padding(
            padding: EdgeInsets.only(bottom: 12),
            child: LinearProgressIndicator(),
          ),
        if (error != null)
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Text(
              error!,
              style: const TextStyle(color: Color(0xFFB42318)),
            ),
          ),
        const SizedBox(height: 10),
        CheckboxListTile(
          value: accepted,
          onChanged: (v) => setState(() => accepted = v ?? false),
          controlAffinity: ListTileControlAffinity.leading,
          contentPadding: EdgeInsets.zero,
          title: Wrap(
            children: [
              Text(AppL10n.of(c).loginConsentPrefix),
              LinkText(
                AppL10n.of(c).loginTermsOfUse,
                onTap: () => showPolicy(c, PolicyDocument.terms),
              ),
              Text(AppL10n.of(c).loginConsentAnd),
              LinkText(
                AppL10n.of(c).loginPrivacyPolicy,
                onTap: () => showPolicy(c, PolicyDocument.privacy),
              ),
              Text(AppL10n.of(c).loginConsentSuffix),
            ],
          ),
        ),
        if (!accepted)
          Padding(
            padding: const EdgeInsetsDirectional.only(start: 12),
            child: Text(
              AppL10n.of(c).loginAcceptFirst,
              style: const TextStyle(color: studafyMuted, fontSize: 12),
            ),
          ),
        const SizedBox(height: 20),
        TextButton.icon(
          onPressed: () => Navigator.pop(c),
          icon: const Icon(Icons.arrow_back),
          label: Text(AppL10n.of(c).loginChangeRole),
        ),
      ],
    ),
  );
}

class SocialButton extends StatelessWidget {
  const SocialButton({
    super.key,
    required this.label,
    required this.mark,
    required this.onTap,
  });
  final String label, mark;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext c) => Padding(
    padding: const EdgeInsets.only(bottom: 12),
    child: OutlinedButton(
      onPressed: onTap,
      style: OutlinedButton.styleFrom(
        minimumSize: const Size.fromHeight(54),
        side: const BorderSide(color: Color(0xFFDCE0EE)),
      ),
      child: Row(
        children: [
          SizedBox(
            width: 42,
            child: Text(
              mark,
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w800,
                color: studafyInk,
              ),
            ),
          ),
          Expanded(child: Text(label, textAlign: TextAlign.center)),
          const SizedBox(width: 42),
        ],
      ),
    ),
  );
}

class LinkText extends StatelessWidget {
  const LinkText(this.text, {super.key, required this.onTap});
  final String text;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext c) => GestureDetector(
    onTap: onTap,
    child: Text(
      text,
      style: const TextStyle(
        color: studafyNavy,
        fontWeight: FontWeight.w700,
        decoration: TextDecoration.underline,
      ),
    ),
  );
}

/// Which policy document the sheet shows.
///
/// An enum, not a display string: the old code compared the *title* against
/// `'Privacy Policy'` to pick the body, so translating the title would have
/// silently shown the terms text under the privacy heading.
enum PolicyDocument { terms, privacy }

/// Placeholder policy text shown in a sheet.
///
/// REL-002 §21.6 replaces both documents with hosted URLs, which both stores
/// require; until then this keeps the app readable in either language. The
/// Arabic copy has not been reviewed by counsel.
void showPolicy(BuildContext c, PolicyDocument document) =>
    showModalBottomSheet(
      context: c,
      showDragHandle: true,
      builder: (c) {
        final l10n = AppL10n.of(c);
        return Padding(
          padding: const EdgeInsetsDirectional.fromSTEB(24, 8, 24, 40),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                document == PolicyDocument.privacy
                    ? l10n.loginPrivacyPolicy
                    : l10n.loginTermsOfUse,
                style: Theme.of(c).textTheme.headlineSmall,
              ),
              const SizedBox(height: 14),
              Text(
                document == PolicyDocument.privacy
                    ? l10n.policyPrivacyBody
                    : l10n.policyTermsBody,
              ),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: () => Navigator.pop(c),
                  child: Text(l10n.loginClose),
                ),
              ),
            ],
          ),
        );
      },
    );
