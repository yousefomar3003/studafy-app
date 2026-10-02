import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:studafy/core/runtime_environment.dart';
import 'package:studafy/core/studafy_domain.dart';
import 'package:studafy/core/telemetry.dart';
import 'package:studafy/features/session/application/session_interactor.dart';
import 'package:studafy/features/session/domain/session_repository.dart';

import '../../support/session_repository_fake.dart';

/// AUTH-030 session state machine.
///
/// The behaviour under test is what happens when a session stops being valid:
/// the app must say so, not quietly show stale or demo data.
class _Repository extends FakeSessionRepositoryBase {
  final StreamController<bool> sessions = StreamController<bool>.broadcast();
  UserProfile? profile;

  @override
  bool get hasCurrentSession => false;

  @override
  Stream<bool> get sessionChanges => sessions.stream;

  @override
  Future<void> signInWithProvider(LoginProvider provider) async {}

  @override
  Future<UserProfile?> currentProfile() async => profile;

  Future<void> close() async {
    await sessions.close();
    await closeLifecycle();
  }
}

UserProfile _teacher() => const UserProfile(
  id: 'user-1',
  displayName: 'Rana Haddad',
  email: 'rana@alnoor.edu',
  memberships: [
    SchoolMembership(
      id: 'membership-1',
      schoolId: 'school-1',
      schoolName: 'Al-Noor International',
      role: StudafyRole.teacher,
      active: true,
    ),
  ],
);

void main() {
  late _Repository repository;
  late SessionInteractor interactor;
  late ActiveContextController context;

  SessionInteractor build(RuntimePolicy policy) {
    StudafyRuntime.initialize(policy);
    return SessionInteractor(
      repository: repository,
      context: context,
      telemetry: const NoopTelemetry(),
      runtimePolicy: policy,
    );
  }

  setUp(() {
    repository = _Repository();
    context = ActiveContextController.instance..signOut();
  });

  tearDown(() async {
    await interactor.dispose();
    await repository.close();
  });

  group('refresh failure', () {
    test('enters reauthRequired rather than staying signed in', () async {
      interactor = build(const RuntimePolicy(StudafyEnvironment.development));
      repository.profile = _teacher();
      await interactor.completeRemoteLogin(
        role: StudafyRole.teacher,
        consentAccepted: true,
        locale: 'en',
      );
      expect(interactor.status, SessionStatus.authenticated);

      repository.emitLifecycle(SessionLifecycleEvent.refreshFailed);
      await Future<void>.delayed(Duration.zero);

      expect(interactor.status, SessionStatus.reauthRequired);
    });

    test('clears the active context so no stale school data renders', () async {
      interactor = build(const RuntimePolicy(StudafyEnvironment.development));
      repository.profile = _teacher();
      await interactor.completeRemoteLogin(
        role: StudafyRole.teacher,
        consentAccepted: true,
        locale: 'en',
      );
      expect(context.profile, isNotNull);

      repository.emitLifecycle(SessionLifecycleEvent.refreshFailed);
      await Future<void>.delayed(Duration.zero);

      expect(context.profile, isNull);
      expect(context.membership, isNull);
    });

    test(
      'never falls back to a demo session outside synthetic builds',
      () async {
        // The failure mode this guards against: an expired session silently
        // becoming a demo session, which would show fabricated school data to a
        // real user.
        interactor = build(const RuntimePolicy(StudafyEnvironment.development));
        repository.emitLifecycle(SessionLifecycleEvent.refreshFailed);
        await Future<void>.delayed(Duration.zero);

        expect(interactor.status, SessionStatus.reauthRequired);
        expect(
          () => interactor.startDemoSession(StudafyRole.teacher),
          throwsStateError,
        );
        expect(context.profile, isNull);
      },
    );

    test('a status listener is told, so the shell can prompt', () async {
      interactor = build(const RuntimePolicy(StudafyEnvironment.development));
      final seen = <SessionStatus>[];
      final subscription = interactor.statusChanges.listen(seen.add);

      repository.emitLifecycle(SessionLifecycleEvent.refreshFailed);
      await Future<void>.delayed(Duration.zero);
      await subscription.cancel();

      expect(seen, contains(SessionStatus.reauthRequired));
    });
  });

  group('sign-out', () {
    test('current-device sign-out is the default scope', () async {
      interactor = build(const RuntimePolicy(StudafyEnvironment.development));
      await interactor.signOut();
      expect(repository.signOutScopes, [SignOutScope.currentDevice]);
      expect(interactor.status, SessionStatus.signedOut);
    });

    test('all-device sign-out passes the wider scope through', () async {
      interactor = build(const RuntimePolicy(StudafyEnvironment.development));
      await interactor.signOut(scope: SignOutScope.allDevices);
      expect(repository.signOutScopes, [SignOutScope.allDevices]);
    });

    test('signing out clears the active context', () async {
      interactor = build(const RuntimePolicy(StudafyEnvironment.development));
      repository.profile = _teacher();
      await interactor.completeRemoteLogin(
        role: StudafyRole.teacher,
        consentAccepted: true,
        locale: 'en',
      );

      await interactor.signOut();

      expect(context.profile, isNull);
      expect(context.activeTermId, isNull);
    });
  });

  group('account switching', () {
    test('a second login replaces the previous account context', () async {
      interactor = build(const RuntimePolicy(StudafyEnvironment.development));
      repository.profile = _teacher();
      await interactor.completeRemoteLogin(
        role: StudafyRole.teacher,
        consentAccepted: true,
        locale: 'en',
      );
      expect(context.profile!.id, 'user-1');

      repository.profile = const UserProfile(
        id: 'user-2',
        displayName: 'Omar Nasser',
        email: 'omar@alnoor.edu',
        memberships: [
          SchoolMembership(
            id: 'membership-2',
            schoolId: 'school-2',
            schoolName: 'Second School',
            role: StudafyRole.teacher,
            active: true,
          ),
        ],
      );
      await interactor.completeRemoteLogin(
        role: StudafyRole.teacher,
        consentAccepted: true,
        locale: 'en',
      );

      // No trace of the first account may remain in the observable context.
      expect(context.profile!.id, 'user-2');
      expect(context.membership!.schoolId, 'school-2');
    });

    test('a teacher account signing in as a student enters nothing, and '
        'is pointed back to teaching', () async {
      interactor = build(const RuntimePolicy(StudafyEnvironment.development));
      repository.profile = _teacher();

      final result = await interactor.completeRemoteLogin(
        role: StudafyRole.student,
        consentAccepted: true,
        locale: 'en',
      );

      // One kind of account per email: no student role is conferred, the
      // teacher role is not silently swapped out, and the screen is told
      // which role this account is for.
      expect(result.require, LoginOutcome.wrongRole);
      expect(interactor.accountRole, StudafyRole.teacher);
      expect(context.membership, isNull);
      expect(context.role, isNull);
      expect(repository.signOutScopes, isEmpty);
      expect(repository.recordedKinds, isEmpty);
    });

    test('a student account signing in as a teacher or a parent enters '
        'nothing, and is pointed back to studying', () async {
      for (final role in [StudafyRole.teacher, StudafyRole.parent]) {
        interactor = build(const RuntimePolicy(StudafyEnvironment.development));
        repository.profile = const UserProfile(
          id: 'user-s',
          displayName: 'Sara',
          email: 'sara@example.test',
          memberships: [
            SchoolMembership(
              id: 'membership-s',
              schoolId: 'school-1',
              schoolName: 'Al-Noor International',
              role: StudafyRole.student,
              active: true,
            ),
          ],
        );
        final result = await interactor.completeRemoteLogin(
          role: role,
          consentAccepted: true,
          locale: 'en',
        );
        expect(result.require, LoginOutcome.wrongRole, reason: role.name);
        expect(interactor.accountRole, StudafyRole.student);
        expect(context.membership, isNull);
      }
    });

    test(
      'a student account with no class yet is still a student account',
      () async {
        interactor = build(const RuntimePolicy(StudafyEnvironment.development));
        repository.profile = const UserProfile(
          id: 'user-new',
          displayName: 'New',
          email: 'new@example.test',
          memberships: [],
          accountKind: AccountKind.student,
        );
        final result = await interactor.completeRemoteLogin(
          role: StudafyRole.teacher,
          consentAccepted: true,
          locale: 'en',
        );
        expect(result.require, LoginOutcome.wrongRole);
        expect(interactor.accountRole, StudafyRole.student);
      },
    );

    test(
      'a teacher signing in as a parent is asked first, then may add it',
      () async {
        interactor = build(const RuntimePolicy(StudafyEnvironment.development));
        repository.profile = _teacher();
        final offered = await interactor.completeRemoteLogin(
          role: StudafyRole.parent,
          consentAccepted: true,
          locale: 'en',
        );
        // Not carried into an empty parent home unasked.
        expect(offered.require, LoginOutcome.otherRole);
        expect(interactor.accountRole, StudafyRole.teacher);
        expect(context.signedInAs, isNull);

        final added = await interactor.completeRemoteLogin(
          role: StudafyRole.parent,
          consentAccepted: true,
          locale: 'en',
          addRole: true,
        );
        expect(added.require, LoginOutcome.needsOnboarding);
        expect(context.signedInAs, StudafyRole.parent);
        expect(context.membership, isNull);
      },
    );

    test(
      'a teacher who is also a parent goes straight in as a parent',
      () async {
        interactor = build(const RuntimePolicy(StudafyEnvironment.development));
        repository
          ..profile = _teacher()
          ..linkedChildren = true;
        final result = await interactor.completeRemoteLogin(
          role: StudafyRole.parent,
          consentAccepted: true,
          locale: 'en',
        );
        expect(result.require, LoginOutcome.needsOnboarding);
        expect(context.signedInAs, StudafyRole.parent);
      },
    );

    test('a parent signing in as a teacher is offered their parent account, '
        'not teacher setup', () async {
      interactor = build(const RuntimePolicy(StudafyEnvironment.development));
      repository
        ..profile = const UserProfile(
          id: 'user-p',
          displayName: 'Mona',
          email: 'mona@example.test',
          memberships: [],
          accountKind: AccountKind.adult,
        )
        ..linkedChildren = true;
      final offered = await interactor.completeRemoteLogin(
        role: StudafyRole.teacher,
        consentAccepted: true,
        locale: 'en',
      );
      expect(offered.require, LoginOutcome.otherRole);
      expect(interactor.accountRole, StudafyRole.parent);
      expect(context.signedInAs, isNull);

      // Continuing as the parent they are opens the parent home.
      final asParent = await interactor.completeRemoteLogin(
        role: StudafyRole.parent,
        consentAccepted: true,
        locale: 'en',
      );
      expect(asParent.require, LoginOutcome.needsOnboarding);
      expect(context.signedInAs, StudafyRole.parent);

      // Choosing to teach as well starts teacher setup.
      final teaching = await interactor.completeRemoteLogin(
        role: StudafyRole.teacher,
        consentAccepted: true,
        locale: 'en',
        addRole: true,
      );
      expect(teaching.require, LoginOutcome.needsOnboarding);
      expect(context.signedInAs, StudafyRole.teacher);
    });

    test(
      'a brand-new account takes the kind of the door it came through',
      () async {
        interactor = build(const RuntimePolicy(StudafyEnvironment.development));
        repository.profile = const UserProfile(
          id: 'user-fresh',
          displayName: 'Fresh',
          email: 'fresh@example.test',
          memberships: [],
        );
        final result = await interactor.completeRemoteLogin(
          role: StudafyRole.student,
          consentAccepted: true,
          locale: 'en',
        );
        expect(result.require, LoginOutcome.needsOnboarding);
        expect(repository.recordedKinds, [AccountKind.student]);
      },
    );

    test('a withdrawn membership is denied and signs out', () async {
      interactor = build(const RuntimePolicy(StudafyEnvironment.development));
      repository.profile = const UserProfile(
        id: 'user-4',
        displayName: 'Removed Teacher',
        email: 'removed@alnoor.edu',
        memberships: [
          SchoolMembership(
            id: 'membership-4',
            schoolId: 'school-1',
            schoolName: 'Al-Noor International',
            role: StudafyRole.teacher,
            active: false,
          ),
        ],
      );

      final result = await interactor.completeRemoteLogin(
        role: StudafyRole.teacher,
        consentAccepted: true,
        locale: 'en',
      );

      // Losing access must not be reinterpreted as never having had it.
      expect(result.isSuccess, isFalse);
      expect(context.profile, isNull);
      expect(repository.signOutScopes, isNotEmpty);
    });

    test('an inactive membership does not authenticate', () async {
      interactor = build(const RuntimePolicy(StudafyEnvironment.development));
      repository.profile = const UserProfile(
        id: 'user-3',
        displayName: 'Suspended Teacher',
        email: 'suspended@alnoor.edu',
        memberships: [
          SchoolMembership(
            id: 'membership-3',
            schoolId: 'school-1',
            schoolName: 'Al-Noor International',
            role: StudafyRole.teacher,
            active: false,
          ),
        ],
      );

      final result = await interactor.completeRemoteLogin(
        role: StudafyRole.teacher,
        consentAccepted: true,
        locale: 'en',
      );

      expect(result.isSuccess, isFalse);
      expect(interactor.status, SessionStatus.signedOut);
    });
  });
}
