import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:studafy/core/failures.dart';
import 'package:studafy/core/ids.dart';
import 'package:studafy/core/runtime_environment.dart';
import 'package:studafy/core/studafy_domain.dart';
import 'package:studafy/core/telemetry.dart';
import 'package:studafy/features/session/application/session_interactor.dart';
import 'package:studafy/features/session/domain/session_repository.dart';

/// ARC-011 session slice tests: prove the state machine, the demo denial,
/// and the term resolution — all against a fake repository, never a real
/// provider client.
class _FakeSessionRepository implements SessionRepository {
  _FakeSessionRepository({
    this.profileToReturn,
    this.termToReturn,
    this.failConsent = false,
  });

  UserProfile? profileToReturn;
  TermInfo? termToReturn;
  bool failConsent;

  int consentCalls = 0;
  int signOutCalls = 0;
  int profileCalls = 0;
  int termCalls = 0;

  final _sessionController = StreamController<bool>.broadcast();
  SessionState? _lastAuthState;

  @override
  bool get hasCurrentSession => _lastAuthState?.session != null;

  @override
  Stream<bool> get sessionChanges => _sessionController.stream;

  void emitSession(bool hasSession) {
    _lastAuthState = SessionState(hasSession);
    _sessionController.add(hasSession);
  }

  @override
  Future<void> signInWithProvider(LoginProvider provider) async {}

  @override
  Future<UserProfile?> currentProfile() async {
    profileCalls++;
    return profileToReturn;
  }

  @override
  Future<TermInfo?> activeTermForSchool(SchoolId school) async {
    termCalls++;
    return termToReturn;
  }

  @override
  Future<void> recordTermsConsent({required String locale}) async {
    consentCalls++;
    if (failConsent) {
      throw Exception('consent RPC failed');
    }
  }

  @override
  Future<void> signOut() async {
    signOutCalls++;
  }

  void dispose() => _sessionController.close();
}

class SessionState {
  const SessionState(this.session);
  final Object? session;
}

UserProfile _teacherProfile() => UserProfile(
  id: 'user-1',
  displayName: 'Rana Haddad',
  email: 'rana@alnoor.edu',
  memberships: [
    const SchoolMembership(
      id: 'membership-1',
      schoolId: 'school-1',
      schoolName: 'Al-Noor International',
      role: StudafyRole.teacher,
      active: true,
    ),
  ],
);

void main() {
  group('SessionInteractor.completeRemoteLogin', () {
    test('hydrates the context with profile, membership, and term', () async {
      final repo = _FakeSessionRepository(
        profileToReturn: _teacherProfile(),
        termToReturn: const TermInfo(id: TermId('term-1'), name: 'Term 1'),
      );
      final controller = ActiveContextController.instance;
      controller.signOut();
      final interactor = SessionInteractor(
        repository: repo,
        context: controller,
        telemetry: const NoopTelemetry(),
        runtimePolicy: const RuntimePolicy(StudafyEnvironment.development),
      );

      final result = await interactor.completeRemoteLogin(
        role: StudafyRole.teacher,
        consentAccepted: true,
        locale: 'en',
      );

      expect(result.isSuccess, isTrue);
      expect(repo.consentCalls, 1);
      expect(repo.profileCalls, 1);
      expect(repo.termCalls, 1);
      expect(controller.role, StudafyRole.teacher);
      expect(controller.activeTermId, 'term-1');
      expect(controller.profile?.displayName, 'Rana Haddad');
    });

    test(
      'signs out and returns validation failure when no membership',
      () async {
        final repo = _FakeSessionRepository(profileToReturn: null);
        final controller = ActiveContextController.instance;
        controller.signOut();
        final interactor = SessionInteractor(
          repository: repo,
          context: controller,
          telemetry: const NoopTelemetry(),
          runtimePolicy: const RuntimePolicy(StudafyEnvironment.development),
        );

        final result = await interactor.completeRemoteLogin(
          role: StudafyRole.teacher,
          consentAccepted: false,
          locale: 'en',
        );

        expect(result.isFailure, isTrue);
        expect(repo.signOutCalls, 1);
        expect(
          result.fold(onSuccess: (_) => '', onFailure: (f) => f.code),
          Failure.validationCode,
        );
        expect(controller.profile, isNull);
      },
    );

    test(
      'consent failure surfaces as an unknown failure, not a crash',
      () async {
        final repo = _FakeSessionRepository(
          profileToReturn: _teacherProfile(),
          failConsent: true,
        );
        final interactor = SessionInteractor(
          repository: repo,
          context: ActiveContextController.instance,
          telemetry: const NoopTelemetry(),
          runtimePolicy: const RuntimePolicy(StudafyEnvironment.development),
        );

        final result = await interactor.completeRemoteLogin(
          role: StudafyRole.teacher,
          consentAccepted: true,
          locale: 'en',
        );

        expect(result.isFailure, isTrue);
        expect(repo.profileCalls, 0, reason: 'consent ran before the profile');
      },
    );
  });

  group('SessionInteractor demo denial (Phase 1 gate item)', () {
    test('a non-synthetic build can never start a demo session', () {
      final controller = ActiveContextController.instance;
      controller.signOut();

      // Initialize the runtime to a non-synthetic environment.
      StudafyRuntime.initialize(
        const RuntimePolicy(StudafyEnvironment.development),
      );

      final interactor = SessionInteractor(
        repository: _FakeSessionRepository(),
        context: controller,
        telemetry: const NoopTelemetry(),
        runtimePolicy: const RuntimePolicy(StudafyEnvironment.development),
      );

      expect(
        () => interactor.startDemoSession(StudafyRole.teacher),
        throwsStateError,
      );
      expect(controller.profile, isNull);
      expect(controller.role, isNull);
    });

    test('a synthetic build can start a demo session', () {
      final controller = ActiveContextController.instance;
      controller.signOut();

      StudafyRuntime.initialize(
        const RuntimePolicy(StudafyEnvironment.synthetic),
      );

      final interactor = SessionInteractor(
        repository: _FakeSessionRepository(),
        context: controller,
        telemetry: const NoopTelemetry(),
        runtimePolicy: const RuntimePolicy(StudafyEnvironment.synthetic),
      );

      interactor.startDemoSession(StudafyRole.teacher);
      expect(controller.role, StudafyRole.teacher);
      expect(controller.profile?.id, 'demo-user');
    });

    test('switchRole outside synthetic never falls back to a demo role', () {
      final controller = ActiveContextController.instance;
      controller.signOut();

      StudafyRuntime.initialize(
        const RuntimePolicy(StudafyEnvironment.development),
      );

      // A profile with no parent membership.
      controller.hydrate(
        authenticatedProfile: _teacherProfile(),
        activeMembership: const SchoolMembership(
          id: 'membership-1',
          schoolId: 'school-1',
          schoolName: 'Al-Noor International',
          role: StudafyRole.teacher,
          active: true,
        ),
      );

      controller.switchRole(StudafyRole.parent);

      expect(
        controller.role,
        StudafyRole.teacher,
        reason: 'role unchanged — demo fallback must not fire',
      );
      expect(
        controller.profile?.id,
        'user-1',
        reason: 'profile must not be replaced by a demo identity',
      );
    });

    test('switchRole inside synthetic does fall back to a demo role', () {
      final controller = ActiveContextController.instance;
      controller.signOut();

      StudafyRuntime.initialize(
        const RuntimePolicy(StudafyEnvironment.synthetic),
      );

      controller.hydrate(
        authenticatedProfile: _teacherProfile(),
        activeMembership: const SchoolMembership(
          id: 'membership-1',
          schoolId: 'school-1',
          schoolName: 'Al-Noor International',
          role: StudafyRole.teacher,
          active: true,
        ),
      );

      controller.switchRole(StudafyRole.parent);

      expect(controller.role, StudafyRole.parent);
      expect(controller.profile?.id, 'demo-user');
    });
  });

  group('SessionInteractor signOut', () {
    test('clears both the repository session and the context', () async {
      final repo = _FakeSessionRepository();
      final controller = ActiveContextController.instance;
      controller.hydrate(
        authenticatedProfile: _teacherProfile(),
        activeMembership: const SchoolMembership(
          id: 'membership-1',
          schoolId: 'school-1',
          schoolName: 'Al-Noor International',
          role: StudafyRole.teacher,
          active: true,
        ),
      );
      final interactor = SessionInteractor(
        repository: repo,
        context: controller,
        telemetry: const NoopTelemetry(),
        runtimePolicy: const RuntimePolicy(StudafyEnvironment.development),
      );

      await interactor.signOut();

      expect(repo.signOutCalls, 1);
      expect(controller.profile, isNull);
      expect(controller.role, isNull);
    });
  });

  group('ActiveContextController immutability invariants', () {
    test('hydrate replaces the snapshot atomically', () {
      final controller = ActiveContextController.instance;
      controller.signOut();
      controller.hydrate(
        authenticatedProfile: _teacherProfile(),
        activeMembership: const SchoolMembership(
          id: 'membership-1',
          schoolId: 'school-1',
          schoolName: 'Al-Noor International',
          role: StudafyRole.teacher,
          active: true,
        ),
        termId: 'term-1',
      );
      expect(controller.activeTermId, 'term-1');

      controller.hydrate(
        authenticatedProfile: _teacherProfile(),
        activeMembership: const SchoolMembership(
          id: 'membership-2',
          schoolId: 'school-2',
          schoolName: 'Other School',
          role: StudafyRole.parent,
          active: true,
        ),
        termId: 'term-2',
      );
      expect(controller.membership?.id, 'membership-2');
      expect(controller.activeTermId, 'term-2');
      expect(controller.role, StudafyRole.parent);
    });
  });
}
