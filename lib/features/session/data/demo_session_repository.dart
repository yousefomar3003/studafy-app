import 'dart:async';

import '../../../core/ids.dart';
import '../../../core/studafy_domain.dart';
import '../domain/session_repository.dart';

/// Synthetic-build session source. There is no remote session by design;
/// the only "authentication" is the demo role start, which the interactor
/// guards behind the synthetic runtime policy.
///
/// The AUTH-030 lifecycle operations are all refusals rather than stubs that
/// return plausible values: a synthetic build has no server to revoke a
/// session, enrol a factor, or delete an account, and pretending otherwise
/// would let a demo screen imply a guarantee that does not exist.
class DemoSessionRepository implements SessionRepository {
  const DemoSessionRepository();

  static Never _noRemoteBackend() =>
      throw StateError('Synthetic builds have no remote session (SEC-001).');

  @override
  bool get hasCurrentSession => false;

  @override
  Stream<bool> get sessionChanges => const Stream.empty();

  @override
  Stream<SessionLifecycleEvent> get lifecycleEvents => const Stream.empty();

  @override
  bool supportsProvider(LoginProvider provider) => true;

  @override
  Future<void> signInWithProvider(LoginProvider provider) async =>
      _noRemoteBackend();

  @override
  Future<UserProfile?> currentProfile() async => null;

  @override
  Future<TermInfo?> activeTermForSchool(SchoolId school) async =>
      const TermInfo(id: TermId('demo-term-2026'), name: 'Term 1');

  @override
  Future<void> recordTermsConsent({required String locale}) async {}

  @override
  Future<void> signOut({
    SignOutScope scope = SignOutScope.currentDevice,
  }) async {}

  @override
  Future<List<AuthDevice>> devices() async => const [];

  @override
  Future<bool> revokeDevice(String deviceId) async => _noRemoteBackend();

  @override
  Future<void> confirmRecentAuth(ReauthPurpose purpose) async =>
      _noRemoteBackend();

  @override
  Future<bool> mfaEnrolled() async => false;

  @override
  Future<String> beginTotpEnrolment() async => _noRemoteBackend();

  @override
  Future<bool> verifyTotp(String code) async => _noRemoteBackend();

  @override
  Future<DeletionImpact> deletionImpact() async => _noRemoteBackend();

  @override
  Future<DeletionRequest> requestAccountDeletion({
    required String reasonCode,
  }) async => _noRemoteBackend();

  @override
  Future<bool> cancelAccountDeletion() async => _noRemoteBackend();
}
