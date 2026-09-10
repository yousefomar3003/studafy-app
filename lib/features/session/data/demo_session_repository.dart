import 'dart:async';

import '../../../core/ids.dart';
import '../../../core/studafy_domain.dart';
import '../domain/session_repository.dart';

/// Synthetic-build session source. There is no remote session by design;
/// the only "authentication" is the demo role start, which the interactor
/// guards behind the synthetic runtime policy.
class DemoSessionRepository implements SessionRepository {
  const DemoSessionRepository();

  @override
  bool get hasCurrentSession => false;

  @override
  Stream<bool> get sessionChanges => const Stream.empty();

  @override
  Future<void> signInWithProvider(LoginProvider provider) async {
    throw StateError('Synthetic builds do not authenticate remotely.');
  }

  @override
  Future<UserProfile?> currentProfile() async => null;

  @override
  Future<TermInfo?> activeTermForSchool(SchoolId school) async =>
      const TermInfo(id: TermId('demo-term-2026'), name: 'Term 1');

  @override
  Future<void> recordTermsConsent({required String locale}) async {}

  @override
  Future<void> signOut() async {}
}
