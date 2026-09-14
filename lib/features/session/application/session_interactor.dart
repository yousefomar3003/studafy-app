import 'dart:async';

import '../../../core/failures.dart';
import '../../../core/ids.dart';
import '../../../core/result.dart';
import '../../../core/runtime_environment.dart';
import '../../../core/studafy_domain.dart';
import '../../../core/telemetry.dart';
import '../domain/session_repository.dart';

/// Where the session currently stands (AUTH-030).
///
/// The previous boolean could not express the state that matters most: a
/// session whose refresh has failed. That is [reauthRequired] — an explicit
/// signed-out-and-say-so state, never a silent downgrade to demo data.
enum SessionStatus { signedOut, authenticating, authenticated, reauthRequired }

/// Drives the session state machine (ARC-011 session slice, AUTH-030).
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
  }) {
    _lifecycle = repository.lifecycleEvents.listen(_onLifecycleEvent);
  }

  final SessionRepository repository;
  final ActiveContextController context;
  final Telemetry telemetry;
  final RuntimePolicy runtimePolicy;

  StreamSubscription<SessionLifecycleEvent>? _lifecycle;
  final _statusController = StreamController<SessionStatus>.broadcast();

  SessionStatus _status = SessionStatus.signedOut;

  SessionStatus get status => _status;

  /// Emits every status transition, so the shell can show a re-authentication
  /// prompt rather than an empty screen when a session expires.
  Stream<SessionStatus> get statusChanges => _statusController.stream;

  /// True when this build authenticates against the synthetic demo fixture.
  bool get isDemoSession => runtimePolicy.isSynthetic;

  bool get hasCurrentSession => repository.hasCurrentSession;

  Stream<bool> get sessionChanges => repository.sessionChanges;

  Future<void> dispose() async {
    await _lifecycle?.cancel();
    await _statusController.close();
  }

  void _setStatus(SessionStatus next) {
    if (_status == next) return;
    _status = next;
    telemetry.event('session_status', {'status': next.name});
    if (!_statusController.isClosed) _statusController.add(next);
  }

  void _onLifecycleEvent(SessionLifecycleEvent event) {
    switch (event) {
      case SessionLifecycleEvent.refreshFailed:
        // The refresh token is gone, rotated out, or revoked. The user has to
        // sign in again; there is nothing to degrade to.
        _setStatus(SessionStatus.reauthRequired);
        context.signOut();
      case SessionLifecycleEvent.signedOut:
        _setStatus(SessionStatus.signedOut);
        context.signOut();
      case SessionLifecycleEvent.signedIn:
      case SessionLifecycleEvent.tokenRefreshed:
      case SessionLifecycleEvent.userUpdated:
        break;
    }
  }

  /// Whether the login screen should offer [provider] on this platform.
  bool supportsProvider(LoginProvider provider) =>
      repository.supportsProvider(provider);

  /// Opens the provider OAuth flow. Only valid outside synthetic builds.
  Future<Result<void>> signInWithProvider(LoginProvider provider) {
    telemetry.event('session_oauth_started', {'provider': provider.name});
    _setStatus(SessionStatus.authenticating);
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
      onSuccess: (authenticatedRole) {
        _setStatus(SessionStatus.authenticated);
        telemetry.event('session_authenticated', {
          'role': authenticatedRole.name,
        });
      },
      onFailure: (failure) {
        _setStatus(SessionStatus.signedOut);
        telemetry.event('session_login_failed', {'code': failure.code});
      },
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
    _setStatus(SessionStatus.authenticated);
    telemetry.event('session_demo_started', {'role': role.name});
  }

  /// Clears the session everywhere.
  ///
  /// [scope] of [SignOutScope.allDevices] also stops sessions on other
  /// devices: the server records a watermark, so their still-unexpired access
  /// tokens are refused on their next request rather than at expiry.
  Future<void> signOut({
    SignOutScope scope = SignOutScope.currentDevice,
  }) async {
    await repository.signOut(scope: scope);
    context.signOut();
    _setStatus(SessionStatus.signedOut);
    telemetry.event('session_signed_out', {'scope': scope.name});
  }

  // --------------------------------------------------------------------
  // Account security
  //
  // Thin passthroughs so presentation never holds a repository reference.
  // Recent-auth grants are obtained inside the repository for the operations
  // that need them, so a screen cannot forget to ask for one.
  // --------------------------------------------------------------------

  Future<bool> mfaEnrolled() => repository.mfaEnrolled();

  Future<List<AuthDevice>> devices() => repository.devices();

  Future<String> beginTotpEnrolment() {
    telemetry.event('session_mfa_enrolment_started');
    return repository.beginTotpEnrolment();
  }

  Future<bool> verifyTotp(String code) async {
    final verified = await repository.verifyTotp(code);
    telemetry.event('session_mfa_verified', {'verified': verified});
    return verified;
  }

  Future<bool> revokeDevice(String deviceId) async {
    final revoked = await repository.revokeDevice(deviceId);
    telemetry.event('session_device_revoked', {'revoked': revoked});
    return revoked;
  }

  Future<DeletionImpact> deletionImpact() => repository.deletionImpact();

  Future<DeletionRequest> requestAccountDeletion({
    required String reasonCode,
  }) async {
    final request = await repository.requestAccountDeletion(
      reasonCode: reasonCode,
    );
    telemetry.event('session_deletion_requested');
    return request;
  }

  Future<bool> cancelAccountDeletion() async {
    final cancelled = await repository.cancelAccountDeletion();
    telemetry.event('session_deletion_cancelled', {'cancelled': cancelled});
    return cancelled;
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
