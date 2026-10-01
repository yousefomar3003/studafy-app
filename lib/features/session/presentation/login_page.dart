import 'dart:async';

import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart' show closeInAppWebView;

import '../../../core/app_routes.dart';
import '../../../core/failures.dart';
import '../../../core/studafy_design.dart';
import '../../../core/studafy_domain.dart';
import '../../../l10n/generated/app_l10n.dart';
import '../application/session_interactor.dart';
import '../domain/session_repository.dart';
import 'auth_frame.dart';
import 'provider_marks.dart';
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
  bool checkedRestoredSession = false;

  /// Whether a provider browser is open and still owes this screen a callback.
  /// Set only for a sign-in this screen launched, so a session restored at
  /// startup never tries to close a browser that was never opened.
  bool awaitingProviderCallback = false;

  /// While adding an account, the account that was current when this screen
  /// opened. Null otherwise.
  String? _addingTo;

  bool get _stillTheAccountBeingAddedTo =>
      _addingTo != null && widget.session.currentUserId == _addingTo;

  @override
  void initState() {
    super.initState();
    // Taken now, before any callback can replace the session.
    if (widget.session.addingAccount) {
      _addingTo = widget.session.currentUserId;
    }
    sessionSubscription = widget.session.sessionChanges.listen(
      (hasSession) {
        // Adding an account: only a sign-in as somebody else counts, not a
        // refresh of the account being added to.
        if (_stillTheAccountBeingAddedTo) return;
        if (hasSession) {
          _dismissProviderBrowser();
          _completeRemoteLogin();
        }
      },
      onError: (Object failure) {
        if (!mounted) return;
        // The provider has already sent the person back by the time the
        // exchange fails (a dropped connection, an expired code), so the
        // browser would only sit on its last page looking as if it were
        // still loading. Close it and say what happened here instead.
        final hadBrowser = awaitingProviderCallback;
        _dismissProviderBrowser();
        final known = Failure.fromError(failure);
        setState(() {
          signingIn = false;
          error = hadBrowser && known.code == Failure.unknownCode
              ? AppL10n.of(context).loginDidNotFinish
              : known.message;
        });
      },
    );
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (checkedRestoredSession) return;
    checkedRestoredSession = true;
    // Localizations is an inherited widget and cannot be read in initState.
    // While an account is being added, the session still here is the one
    // being added to; this screen waits for the new sign-in instead.
    if (widget.session.hasCurrentSession && !_stillTheAccountBeingAddedTo) {
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
    if (!accepted || signingIn || completingRemoteLogin) return;
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
    // Only ever set. A second attempt fails while the first browser is still
    // on screen — iOS presents one at a time — and that first browser is the
    // one holding the callback, so a failure here must not disown it.
    if (result.isSuccess) awaitingProviderCallback = true;
    // Native Sign in with Apple has its session before this returns, so the
    // listener above already skipped it as "no new account yet".
    if (result.isSuccess &&
        _addingTo != null &&
        widget.session.hasCurrentSession &&
        !_stillTheAccountBeingAddedTo) {
      unawaited(_completeRemoteLogin());
    }
    // Opening the browser is not a completed login. Let the user retry when
    // they dismiss it; sessionChanges handles the eventual OAuth callback.
    if (mounted) {
      setState(() {
        signingIn = false;
        error = result.fold(
          onSuccess: (_) => null,
          onFailure: (failure) => failure.message,
        );
      });
    }
  }

  /// Closes the provider browser once its callback has produced a session.
  ///
  /// supabase_flutter (2.17.2) consumes the deep link but leaves the browser
  /// it opened on screen, so a completed sign-in stranded the user on a blank
  /// page with the app already signed in behind it. Only a browser this
  /// screen opened is closed, and only after a session exists, so a refused
  /// sign-in still shows the provider's own message.
  void _dismissProviderBrowser() {
    if (!awaitingProviderCallback) return;
    awaitingProviderCallback = false;
    unawaited(closeInAppWebView());
  }

  Future<void> _completeRemoteLogin({UserRole? as}) async {
    if (!mounted || completingRemoteLogin || widget.session.isDemoSession) {
      return;
    }
    final role = as ?? widget.role;
    completingRemoteLogin = true;
    final result = await widget.session.completeRemoteLogin(
      role: _studafyRole(role),
      consentAccepted: accepted,
      locale: Localizations.localeOf(context).languageCode,
    );
    completingRemoteLogin = false;
    result.fold(
      onSuccess: (outcome) {
        if (!mounted) return;
        switch (outcome) {
          case LoginOutcome.ready:
            _openRole(role);
          case LoginOutcome.needsOnboarding:
            _openOnboarding(role);
          case LoginOutcome.wrongRole:
            final own = widget.session.accountRole;
            if (own != null) unawaited(_explainWrongRole(own));
        }
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

  /// Sends an account that belongs to nothing yet where it can act.
  ///
  /// Only a teacher is held back, and only because their workspace has to be
  /// created before any screen has data to show. A student signs up before a
  /// teacher has sent them anything, and a parent never gets a membership at
  /// all, so for both of them having nothing yet is an empty home rather than
  /// a locked door: they go straight in, and their shell offers the one step
  /// that fills it - join a class, or link to a child.
  void _openOnboarding(UserRole role) {
    if (role != UserRole.teacher) {
      _openRole(role);
      return;
    }
    Navigator.pushNamedAndRemoveUntil(
      context,
      onboardingRoute,
      (_) => false,
      arguments: role,
    );
  }

  static StudafyRole _studafyRole(UserRole role) => switch (role) {
    UserRole.teacher => StudafyRole.teacher,
    UserRole.parent => StudafyRole.parent,
    UserRole.student => StudafyRole.student,
  };

  static UserRole _userRole(StudafyRole role) => switch (role) {
    StudafyRole.teacher || StudafyRole.schoolAdmin => UserRole.teacher,
    StudafyRole.parent => UserRole.parent,
    StudafyRole.student => UserRole.student,
  };

  String _roleName(AppL10n l10n, StudafyRole role) => switch (role) {
    StudafyRole.teacher || StudafyRole.schoolAdmin => l10n.roleTeacher,
    StudafyRole.parent => l10n.roleParent,
    StudafyRole.student => l10n.roleStudent,
  };

  /// This email is another kind of account than the door it came through.
  /// Nothing has been entered: the person continues in the role the account
  /// is for, or signs in with a different email.
  Future<void> _explainWrongRole(StudafyRole own) async {
    final l10n = AppL10n.of(context);
    final student = own == StudafyRole.student;
    final ownName = _roleName(l10n, own);
    final choice = await showModalBottomSheet<bool>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (sheet) => SafeArea(
        child: Padding(
          padding: const EdgeInsetsDirectional.fromSTEB(24, 0, 24, 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Center(
                child: Container(
                  width: 64,
                  height: 64,
                  decoration: const BoxDecoration(
                    color: studafyWash,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    student ? Icons.menu_book_rounded : Icons.badge_rounded,
                    color: studafyNavy,
                    size: 30,
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Text(
                student
                    ? l10n.loginWrongRoleStudentTitle
                    : l10n.loginWrongRoleAdultTitle,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: studafyInk,
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                student
                    ? l10n.loginWrongRoleStudentBody
                    : l10n.loginWrongRoleAdultBody(ownName.toLowerCase()),
                textAlign: TextAlign.center,
                style: const TextStyle(color: studafyMuted, height: 1.45),
              ),
              const SizedBox(height: 22),
              FilledButton(
                onPressed: () => Navigator.pop(sheet, true),
                style: FilledButton.styleFrom(
                  minimumSize: const Size.fromHeight(52),
                ),
                child: Text(l10n.loginContinueAs(ownName)),
              ),
              const SizedBox(height: 8),
              TextButton(
                onPressed: () => Navigator.pop(sheet, false),
                style: TextButton.styleFrom(
                  minimumSize: const Size.fromHeight(48),
                ),
                child: Text(l10n.loginUseDifferentEmail),
              ),
            ],
          ),
        ),
      ),
    );
    if (!mounted) return;
    if (choice ?? false) {
      await _completeRemoteLogin(as: _userRole(own));
      return;
    }
    // A different email: this one leaves the device's sign-in, and the
    // screen waits for the next.
    setState(() {
      signingIn = false;
      error = null;
    });
    await widget.session.signOut();
  }

  void _openRole([UserRole? as]) {
    // The shells are registered as named routes by the app; the session
    // feature never imports the role shells directly.
    final route = switch (as ?? widget.role) {
      UserRole.teacher => teacherRoute,
      UserRole.parent => parentRoute,
      UserRole.student => studentRoute,
    };
    Navigator.pushNamedAndRemoveUntil(context, route, (_) => false);
  }

  /// Set when a provider is tapped before the terms are accepted, so the
  /// reminder turns red instead of the tap silently doing nothing.
  bool _nudged = false;

  IconData get _roleIcon => switch (widget.role) {
    UserRole.teacher => Icons.school_rounded,
    UserRole.student => Icons.menu_book_rounded,
    UserRole.parent => Icons.family_restroom_rounded,
  };

  void _tapProvider(LoginProvider provider) {
    if (signingIn) return;
    if (!accepted) {
      setState(() => _nudged = true);
      return;
    }
    login(provider);
  }

  @override
  Widget build(BuildContext c) {
    final l10n = AppL10n.of(c);
    return AuthFrame(
      header: const StudafyLogo(size: 38, onDark: true),
      footer: Center(
        child: TextButton.icon(
          onPressed: () => Navigator.pop(c),
          style: TextButton.styleFrom(foregroundColor: studafyFrost),
          icon: Icon(backChevron(c)),
          label: Text(l10n.loginChangeRole),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Center(
            child: Container(
              width: 64,
              height: 64,
              decoration: BoxDecoration(
                gradient: studafyActionGradient,
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: studafyDeep.withValues(alpha: .35),
                    blurRadius: 16,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              child: Icon(_roleIcon, color: Colors.white, size: 32),
            ),
          ),
          const SizedBox(height: 18),
          Text(
            l10n.loginWelcome(roleLabel(c, widget.role)),
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: studafyAbyss,
              fontSize: 26,
              fontWeight: FontWeight.w800,
              letterSpacing: -.6,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            l10n.loginSubtitle,
            textAlign: TextAlign.center,
            style: const TextStyle(color: studafySteel, height: 1.4),
          ),
          const SizedBox(height: 26),
          // Sign in with Apple is required on iOS wherever third-party login
          // establishes the primary account (Apple guideline 4.8). It is
          // hidden where it cannot complete natively rather than offered as a
          // button that fails.
          for (final x in [
            (const GoogleMark(), 'Google', LoginProvider.google),
            (const MicrosoftMark(), 'Microsoft', LoginProvider.microsoft),
            (
              const Icon(Icons.apple, size: 24, color: Colors.black),
              'Apple',
              LoginProvider.apple,
            ),
          ])
            if (widget.session.supportsProvider(x.$3))
              SocialButton(
                logo: x.$1,
                label: l10n.loginContinueWith(x.$2),
                onTap: () => _tapProvider(x.$3),
              ),
          if (signingIn)
            const Padding(
              padding: EdgeInsets.only(bottom: 12),
              child: LinearProgressIndicator(color: studafyTeal),
            ),
          if (error != null)
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Text(
                error!,
                style: const TextStyle(color: Color(0xFFB42318)),
              ),
            ),
          const SizedBox(height: 6),
          InkWell(
            borderRadius: BorderRadius.circular(12),
            onTap: () => setState(() {
              accepted = !accepted;
              if (accepted) _nudged = false;
            }),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Checkbox(
                  value: accepted,
                  activeColor: studafyDeep,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(5),
                  ),
                  onChanged: (v) => setState(() {
                    accepted = v ?? false;
                    if (accepted) _nudged = false;
                  }),
                ),
                Expanded(
                  child: Wrap(
                    children: [
                      Text(l10n.loginConsentPrefix),
                      LinkText(
                        l10n.loginTermsOfUse,
                        onTap: () => showPolicy(c, PolicyDocument.terms),
                      ),
                      Text(l10n.loginConsentAnd),
                      LinkText(
                        l10n.loginPrivacyPolicy,
                        onTap: () => showPolicy(c, PolicyDocument.privacy),
                      ),
                      Text(l10n.loginConsentSuffix),
                    ],
                  ),
                ),
              ],
            ),
          ),
          if (!accepted)
            Padding(
              padding: const EdgeInsetsDirectional.only(start: 14, top: 2),
              child: Text(
                l10n.loginAcceptFirst,
                style: TextStyle(
                  color: _nudged ? const Color(0xFFB42318) : studafySteel,
                  fontSize: 12,
                  fontWeight: _nudged ? FontWeight.w700 : FontWeight.w400,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// A provider's sign-in button: its real logo and "Continue with ...", on
/// the soft surface of the ocean screens.
class SocialButton extends StatelessWidget {
  const SocialButton({
    super.key,
    required this.label,
    required this.logo,
    required this.onTap,
  });
  final String label;
  final Widget logo;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext c) => Padding(
    padding: const EdgeInsets.only(bottom: 12),
    child: Semantics(
      button: true,
      label: label,
      excludeSemantics: true,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(28),
          child: Ink(
            height: 56,
            decoration: softSurface().copyWith(
              borderRadius: BorderRadius.circular(28),
            ),
            child: Row(
              children: [
                SizedBox(width: 56, child: Center(child: logo)),
                Expanded(
                  child: Text(
                    label,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: studafyAbyss,
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                const SizedBox(width: 56),
              ],
            ),
          ),
        ),
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
        color: studafyDeep,
        fontWeight: FontWeight.w700,
        decoration: TextDecoration.underline,
        decorationColor: studafyDeep,
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
      // The whole policy is read here before signing in, so the sheet can
      // grow to most of the screen and the text scrolls inside it.
      isScrollControlled: true,
      builder: (c) {
        final l10n = AppL10n.of(c);
        return ConstrainedBox(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.sizeOf(c).height * 0.85,
          ),
          child: Padding(
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
                Flexible(
                  child: SingleChildScrollView(
                    child: Text(
                      document == PolicyDocument.privacy
                          ? l10n.policyPrivacyBody
                          : l10n.policyTermsBody,
                    ),
                  ),
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
          ),
        );
      },
    );
