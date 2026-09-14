import 'dart:async';

import 'package:flutter/material.dart';

import '../../../core/studafy_localizations.dart';
import '../../../core/studafy_design.dart';
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
      locale: StudafyLocaleController.instance.locale.languageCode,
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
          'Welcome, ${widget.role.name}',
          textAlign: TextAlign.center,
          style: Theme.of(c).textTheme.headlineSmall,
        ),
        const SizedBox(height: 8),
        const Text(
          'Use your school or personal account to continue.',
          textAlign: TextAlign.center,
          style: TextStyle(color: studafyMuted),
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
              label: 'Continue with ${x.$2}',
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
              const Text('I agree to the '),
              LinkText(
                'Terms of Use',
                onTap: () => showPolicy(c, 'Terms of Use'),
              ),
              const Text(' and '),
              LinkText(
                'Privacy Policy',
                onTap: () => showPolicy(c, 'Privacy Policy'),
              ),
              const Text('.'),
            ],
          ),
        ),
        if (!accepted)
          const Padding(
            padding: EdgeInsets.only(left: 12),
            child: Text(
              'Please accept before signing in.',
              style: TextStyle(color: studafyMuted, fontSize: 12),
            ),
          ),
        const SizedBox(height: 20),
        TextButton.icon(
          onPressed: () => Navigator.pop(c),
          icon: const Icon(Icons.arrow_back),
          label: const Text('Change role'),
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

void showPolicy(BuildContext c, String title) => showModalBottomSheet(
  context: c,
  showDragHandle: true,
  builder: (c) => Padding(
    padding: const EdgeInsets.fromLTRB(24, 8, 24, 40),
    child: Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: Theme.of(c).textTheme.headlineSmall),
        const SizedBox(height: 14),
        Text(
          title == 'Privacy Policy'
              ? 'Studafy uses account, school, class, attendance, and communication data only to provide and secure the service. Schools control student records. We do not sell personal data. Contact your school to access, correct, or delete eligible records.'
              : 'Use Studafy only for authorized school communication. Keep accounts secure, respect students and staff, and do not upload harmful or unlawful content. School policies continue to apply. Misuse may lead to account suspension.',
        ),
        const SizedBox(height: 20),
        SizedBox(
          width: double.infinity,
          child: FilledButton(
            onPressed: () => Navigator.pop(c),
            child: const Text('Close'),
          ),
        ),
      ],
    ),
  ),
);
