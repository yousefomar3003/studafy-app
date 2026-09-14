import 'dart:async';

import 'package:studafy/core/ids.dart';
import 'package:studafy/features/session/domain/session_repository.dart';

/// Base for session-repository fakes.
///
/// Every AUTH-030 lifecycle method defaults to a refusal rather than a
/// plausible value, so a test that exercises one has to opt in by overriding
/// it. A fake that silently returned success would let a screen appear to
/// enforce recent auth or MFA while proving nothing.
abstract class FakeSessionRepositoryBase implements SessionRepository {
  final StreamController<SessionLifecycleEvent> lifecycleController =
      StreamController<SessionLifecycleEvent>.broadcast();

  /// Records the scope of each sign-out so tests can assert all-device intent.
  final List<SignOutScope> signOutScopes = [];

  /// Recent-auth purposes the code under test actually confirmed.
  final List<ReauthPurpose> confirmedPurposes = [];

  static Never unimplemented() =>
      throw UnimplementedError('Override this in the test that needs it.');

  @override
  Stream<SessionLifecycleEvent> get lifecycleEvents =>
      lifecycleController.stream;

  void emitLifecycle(SessionLifecycleEvent event) =>
      lifecycleController.add(event);

  @override
  bool supportsProvider(LoginProvider provider) => true;

  @override
  Future<TermInfo?> activeTermForSchool(SchoolId school) async => null;

  @override
  Future<void> recordTermsConsent({required String locale}) async {}

  @override
  Future<void> signOut({
    SignOutScope scope = SignOutScope.currentDevice,
  }) async {
    signOutScopes.add(scope);
  }

  @override
  Future<List<AuthDevice>> devices() async => const [];

  @override
  Future<bool> revokeDevice(String deviceId) async => unimplemented();

  @override
  Future<void> confirmRecentAuth(ReauthPurpose purpose) async {
    confirmedPurposes.add(purpose);
  }

  @override
  Future<bool> mfaEnrolled() async => false;

  @override
  Future<String> beginTotpEnrolment() async => unimplemented();

  @override
  Future<bool> verifyTotp(String code) async => unimplemented();

  @override
  Future<DeletionImpact> deletionImpact() async => unimplemented();

  @override
  Future<DeletionRequest> requestAccountDeletion({
    required String reasonCode,
  }) async => unimplemented();

  @override
  Future<bool> cancelAccountDeletion() async => unimplemented();

  Future<void> closeLifecycle() => lifecycleController.close();
}
