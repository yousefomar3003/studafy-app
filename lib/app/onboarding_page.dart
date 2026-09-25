import 'package:flutter/material.dart';

import '../core/app_routes.dart';
import '../core/studafy_design.dart';
import '../core/studafy_domain.dart';
import '../features/classes/application/class_list_interactor.dart';
import '../features/classes/presentation/join_class_page.dart';
import '../features/onboarding/application/teacher_workspace_interactor.dart';
import '../features/session/application/session_interactor.dart';
import '../features/session/presentation/role_page.dart';
import '../l10n/generated/app_l10n.dart';

/// Where an account that belongs to nothing yet is sent after signing in.
///
/// Reaching this screen is the normal first minute of every real account, not
/// a failure: the person has proved who they are and simply has no class yet.
/// The session stays live throughout, which is precisely what lets a student
/// redeem a class link and a parent ask to be linked - both of which the API
/// accepts from an account with no membership, because the link token and the
/// child's own approval are the credentials.
///
/// The role shown is the one already chosen on [RolePage], so this screen only
/// has to explain the single next step rather than ask again.
class OnboardingPage extends StatefulWidget {
  const OnboardingPage({
    super.key,
    required this.role,
    required this.session,
    required this.classes,
    this.teacherWorkspace,
  });

  final UserRole role;
  final SessionInteractor session;

  /// Null in builds that expose no class repository, which is why the student
  /// branch degrades to an explanation instead of assuming a join is possible.
  final ClassListInteractor? classes;

  /// Null in synthetic builds, which have no backend to create a tenant.
  final TeacherWorkspaceInteractor? teacherWorkspace;

  @override
  State<OnboardingPage> createState() => _OnboardingPageState();
}

class _OnboardingPageState extends State<OnboardingPage> {
  bool _resolving = false;
  String? _error;

  /// Re-reads the profile now that the server has created the membership.
  ///
  /// Both joining a class and creating a workspace make the membership on the
  /// server, so the client has to ask again rather than infer it; only then
  /// does the shell have a school to work from.
  Future<void> _enterAfterMembership(String fallbackError) async {
    if (!mounted) return;
    final result = await widget.session.completeRemoteLogin(
      role: _studafyRole,
      consentAccepted: false,
      locale: Localizations.localeOf(context).languageCode,
    );
    if (!mounted) return;
    result.fold(
      onSuccess: (outcome) {
        if (outcome == LoginOutcome.ready) {
          _openShell();
          return;
        }
        // The call reported success but the membership has not landed. Say so
        // rather than looping back through a screen that looks identical.
        setState(() {
          _resolving = false;
          _error = fallbackError;
        });
      },
      onFailure: (failure) => setState(() {
        _resolving = false;
        _error = failure.message;
      }),
    );
  }

  /// Creates the teacher's workspace, then enters.
  ///
  /// Nothing is asked of the teacher first: the product has no school for
  /// them to name, and the server takes the name from their own profile.
  Future<void> _startTeaching() async {
    final workspace = widget.teacherWorkspace;
    if (workspace == null || _resolving) return;
    setState(() {
      _resolving = true;
      _error = null;
    });
    final l10n = AppL10n.of(context);
    final created = await workspace.create(
      locale: Localizations.localeOf(context).languageCode,
    );
    if (!mounted) return;
    await created.fold(
      onSuccess: (_) => _enterAfterMembership(l10n.onboardingNotReadyYet),
      onFailure: (failure) async => setState(() {
        _resolving = false;
        _error = failure.message;
      }),
    );
  }

  StudafyRole get _studafyRole => switch (widget.role) {
    UserRole.teacher => StudafyRole.teacher,
    UserRole.student => StudafyRole.student,
    UserRole.parent => StudafyRole.parent,
  };

  void _openShell() {
    final route = switch (widget.role) {
      UserRole.teacher => teacherRoute,
      UserRole.parent => parentRoute,
      UserRole.student => studentRoute,
    };
    Navigator.pushNamedAndRemoveUntil(context, route, (_) => false);
  }

  Future<void> _joinClass() async {
    final classes = widget.classes;
    if (classes == null) return;
    final joined = await Navigator.of(context).push<Object?>(
      MaterialPageRoute<Object?>(
        builder: (_) => JoinClassPage(classes: classes),
      ),
    );
    if (joined == null || !mounted) return;
    setState(() {
      _resolving = true;
      _error = null;
    });
    await _enterAfterMembership(AppL10n.of(context).onboardingNotReadyYet);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppL10n.of(context);
    final (title, body, action) = switch (widget.role) {
      UserRole.student => (
        l10n.onboardingStudentTitle,
        l10n.onboardingStudentBody,
        widget.classes == null ? null : (l10n.joinClassAction, _joinClass),
      ),
      // A parent never gets a membership at all - they are linked to a child,
      // not enrolled in a school - so the parent shell is the destination, not
      // a waiting room. It opens on the screen that looks a child up by ID.
      UserRole.parent => (
        l10n.onboardingParentTitle,
        l10n.onboardingParentBody,
        (l10n.onboardingParentAction, _openShell),
      ),
      UserRole.teacher =>
        widget.teacherWorkspace == null
            ? (l10n.onboardingTeacherTitle, l10n.onboardingTeacherBody, null)
            : (
                l10n.onboardingTeacherReadyTitle,
                l10n.onboardingTeacherReadyBody,
                (l10n.onboardingTeacherReadyAction, _startTeaching),
              ),
    };

    return AuthFrame(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const StudafyLogo(size: 36),
          const SizedBox(height: 40),
          Text(
            title,
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.headlineSmall,
          ),
          const SizedBox(height: 12),
          Text(
            body,
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodyMedium,
          ),
          if (_error != null) ...[
            const SizedBox(height: 16),
            Text(
              _error!,
              textAlign: TextAlign.center,
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
          ],
          const SizedBox(height: 32),
          if (action != null)
            FilledButton(
              onPressed: _resolving ? null : action.$2,
              child: Text(action.$1),
            ),
          const SizedBox(height: 12),
          TextButton(
            onPressed: _resolving
                ? null
                : () => Navigator.pushNamedAndRemoveUntil(
                    context,
                    rolesRoute,
                    (_) => false,
                  ),
            child: Text(l10n.onboardingChangeRole),
          ),
        ],
      ),
    );
  }
}
