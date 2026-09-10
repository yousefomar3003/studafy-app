import '../../../core/failures.dart';
import '../../../core/ids.dart';
import '../../../core/result.dart';
import '../../../core/runtime_environment.dart';
import '../../../core/studafy_domain.dart';
import '../../../core/telemetry.dart';
import '../domain/session_repository.dart';

/// Drives the session state machine (ARC-011 session slice).
///
/// The controller remains the observable state holder so legacy screens keep
/// working; this interactor is the only code that mutates it through
/// reviewed, telemetry-visible transitions. Demo authorization is confined
/// to synthetic builds — a non-synthetic build can never hydrate demo data.
class SessionInteractor {
  SessionInteractor({
    required this.repository,
    required this.context,
    required this.telemetry,
    required this.runtimePolicy,
  });

  final SessionRepository repository;
  final ActiveContextController context;
  final Telemetry telemetry;
  final RuntimePolicy runtimePolicy;

  /// True when this build authenticates against the synthetic demo fixture.
  bool get isDemoSession => runtimePolicy.isSynthetic;

  bool get hasCurrentSession => repository.hasCurrentSession;

  Stream<bool> get sessionChanges => repository.sessionChanges;

  /// Opens the provider OAuth flow. Only valid outside synthetic builds.
  Future<Result<void>> signInWithProvider(LoginProvider provider) {
    telemetry.event('session_oauth_started', {'provider': provider.name});
    return runCatching(() => repository.signInWithProvider(provider));
  }

  /// Hydrates the authenticated context after a remote session appears:
  /// consent, profile, matching membership, and the school's active term.
  Future<Result<StudafyRole>> completeRemoteLogin({
    required StudafyRole role,
    required bool consentAccepted,
    required String locale,
  }) async {
    final result = await runCatching(() async {
      if (consentAccepted) {
        await repository.recordTermsConsent(locale: locale);
      }
      final profile = await repository.currentProfile();
      final membership = profile?.memberships
          .where((item) => item.active && item.role == role)
          .firstOrNull;
      if (profile == null || membership == null) {
        await repository.signOut();
        throw Failure.validation(
          'This account does not have the selected school role.',
        );
      }
      final term = await repository.activeTermForSchool(
        SchoolId(membership.schoolId),
      );
      context.hydrate(
        authenticatedProfile: profile,
        activeMembership: membership,
        termId: term?.id.value,
      );
      return role;
    });
    result.fold(
      onSuccess: (authenticatedRole) => telemetry.event(
        'session_authenticated',
        {'role': authenticatedRole.name},
      ),
      onFailure: (failure) =>
          telemetry.event('session_login_failed', {'code': failure.code}),
    );
    return result;
  }

  /// Starts the synthetic demo session. Refuses every non-synthetic build.
  void startDemoSession(StudafyRole role) {
    if (!runtimePolicy.isSynthetic) {
      telemetry.event('session_demo_denied', {'role': role.name});
      throw StateError(
        'Demo sessions exist only in synthetic builds (SEC-001).',
      );
    }
    context.startDemoRole(role);
    telemetry.event('session_demo_started', {'role': role.name});
  }

  /// Clears the session everywhere.
  Future<void> signOut() async {
    await repository.signOut();
    context.signOut();
    telemetry.event('session_signed_out');
  }

  /// Switches to another role the profile holds. Outside synthetic builds a
  /// missing membership is a denial, never a demo fallback.
  void switchRole(StudafyRole target) {
    context.switchRole(target);
    telemetry.event('session_role_switched', {
      'role': context.role?.name ?? 'denied',
    });
  }
}
