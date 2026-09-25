import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:studafy/app/onboarding_page.dart';
import 'package:studafy/core/app_routes.dart';
import 'package:studafy/core/ids.dart';
import 'package:studafy/core/runtime_environment.dart';
import 'package:studafy/core/studafy_domain.dart';
import 'package:studafy/core/telemetry.dart';
import 'package:studafy/core/failures.dart';
import 'package:studafy/features/onboarding/application/teacher_workspace_interactor.dart';
import 'package:studafy/features/onboarding/domain/teacher_workspace_repository.dart';
import 'package:studafy/features/session/application/session_interactor.dart';
import 'package:studafy/features/session/domain/session_repository.dart';
import 'package:studafy/features/session/presentation/role_page.dart';

import 'support/localized_app.dart';
import 'support/session_repository_fake.dart';

/// Onboarding is the screen every real account sees first, so what matters is
/// that each role is told the one thing it has to do next - and that a parent,
/// who never gets a membership at all, is not parked here forever.
void main() {
  const policy = RuntimePolicy(StudafyEnvironment.development);

  setUp(() => StudafyRuntime.initialize(policy));
  tearDown(() => ActiveContextController.instance.signOut());

  SessionInteractor interactor(_OnboardingSessionRepository repository) =>
      SessionInteractor(
        repository: repository,
        context: ActiveContextController.instance,
        telemetry: const NoopTelemetry(),
        runtimePolicy: policy,
      );

  Future<void> pumpRole(
    WidgetTester tester,
    UserRole role,
    SessionInteractor session, {
    Locale locale = const Locale('en'),
    TeacherWorkspaceInteractor? teacherWorkspace,
  }) async {
    await tester.pumpWidget(
      localizedApp(
        locale: locale,
        routes: {
          teacherRoute: (_) => const Text('Teacher home'),
          parentRoute: (_) => const Text('Parent home'),
          studentRoute: (_) => const Text('Student home'),
        },
        home: OnboardingPage(
          role: role,
          session: session,
          classes: null,
          teacherWorkspace: teacherWorkspace,
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('a parent is let straight through to link their child', (
    tester,
  ) async {
    final repository = _OnboardingSessionRepository();
    final session = interactor(repository);

    await pumpRole(tester, UserRole.parent, session);
    expect(find.text('Link to your child'), findsOneWidget);

    await tester.tap(find.text('Continue'));
    await tester.pumpAndSettle();

    // A guardian is linked to a student, never enrolled in a school, so
    // waiting for a membership that will never arrive would strand them.
    expect(find.text('Parent home'), findsOneWidget);

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.runAsync(repository.close);
    await tester.runAsync(session.dispose);
  });

  testWidgets('a student with no class repository is told, not stuck', (
    tester,
  ) async {
    final repository = _OnboardingSessionRepository();
    final session = interactor(repository);

    await pumpRole(tester, UserRole.student, session);

    expect(find.text('Join your first class'), findsOneWidget);
    expect(find.text('Join class'), findsNothing);
    expect(find.text('Choose a different role'), findsOneWidget);

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.runAsync(repository.close);
    await tester.runAsync(session.dispose);
  });

  testWidgets('a synthetic build offers a teacher no dead button', (
    tester,
  ) async {
    final repository = _OnboardingSessionRepository();
    final session = interactor(repository);

    await pumpRole(tester, UserRole.teacher, session);

    expect(find.text('Teacher accounts are almost ready'), findsOneWidget);
    expect(find.byType(FilledButton), findsNothing);

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.runAsync(repository.close);
    await tester.runAsync(session.dispose);
  });

  testWidgets('a teacher gets a workspace and is taken straight in', (
    tester,
  ) async {
    // The membership only exists after the server makes it, so the profile
    // has to change between the two reads the flow performs.
    final repository = _OnboardingSessionRepository(
      grantsTeacherAfterCreate: true,
    );
    final session = interactor(repository);
    final workspace = _RecordingWorkspace(repository);

    await pumpRole(
      tester,
      UserRole.teacher,
      session,
      teacherWorkspace: TeacherWorkspaceInteractor(
        repository: workspace,
        telemetry: const NoopTelemetry(),
      ),
    );

    // The teacher is never asked to name or describe a school.
    expect(find.byType(TextField), findsNothing);
    await tester.tap(find.text('Get started'));
    await tester.pumpAndSettle();

    expect(workspace.calls, 1);
    expect(find.text('Teacher home'), findsOneWidget);
    expect(ActiveContextController.instance.role, StudafyRole.teacher);

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.runAsync(repository.close);
    await tester.runAsync(session.dispose);
  });

  testWidgets('a failed workspace creation says so and stays put', (
    tester,
  ) async {
    final repository = _OnboardingSessionRepository();
    final session = interactor(repository);
    final workspace = _FailingWorkspace();

    await pumpRole(
      tester,
      UserRole.teacher,
      session,
      teacherWorkspace: TeacherWorkspaceInteractor(
        repository: workspace,
        telemetry: const NoopTelemetry(),
      ),
    );

    await tester.tap(find.text('Get started'));
    await tester.pumpAndSettle();

    expect(find.text('Teacher home'), findsNothing);
    expect(find.text('the workspace could not be created'), findsOneWidget);

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.runAsync(repository.close);
    await tester.runAsync(session.dispose);
  });

  testWidgets('every role reads in Arabic too', (tester) async {
    for (final role in UserRole.values) {
      final repository = _OnboardingSessionRepository();
      final session = interactor(repository);
      await pumpRole(tester, role, session, locale: const Locale('ar'));

      expect(
        directionOf(tester, find.byType(OnboardingPage)),
        TextDirection.rtl,
      );
      expect(find.textContaining(RegExp(r'[؀-ۿ]')), findsWidgets);

      await tester.pumpWidget(const SizedBox.shrink());
      await tester.runAsync(repository.close);
      await tester.runAsync(session.dispose);
    }
  });
}

/// Creates the workspace, and makes the session repository report the
/// membership that the real server would have created.
class _RecordingWorkspace implements TeacherWorkspaceRepository {
  _RecordingWorkspace(this._session);

  final _OnboardingSessionRepository _session;
  int calls = 0;

  @override
  Future<void> createForCurrentTeacher({
    required String locale,
    String? timezone,
  }) async {
    calls++;
    _session.created = true;
  }
}

class _FailingWorkspace implements TeacherWorkspaceRepository {
  @override
  Future<void> createForCurrentTeacher({
    required String locale,
    String? timezone,
  }) async => throw Failure.validation('the workspace could not be created');
}

class _OnboardingSessionRepository extends FakeSessionRepositoryBase {
  _OnboardingSessionRepository({this.grantsTeacherAfterCreate = false});

  final bool grantsTeacherAfterCreate;
  final StreamController<bool> _sessions = StreamController<bool>.broadcast();

  /// Flipped by the fake workspace, standing in for the server's own write.
  bool created = false;

  @override
  bool get hasCurrentSession => true;

  @override
  Stream<bool> get sessionChanges => _sessions.stream;

  @override
  Future<void> signInWithProvider(LoginProvider provider) async =>
      FakeSessionRepositoryBase.unimplemented();

  @override
  Future<UserProfile?> currentProfile() async => UserProfile(
    id: 'new-user',
    displayName: 'New Account',
    email: 'new@studafy.test',
    memberships: grantsTeacherAfterCreate && created
        ? const [
            SchoolMembership(
              id: 'membership-new',
              schoolId: 'school-new',
              schoolName: 'New Account',
              role: StudafyRole.teacher,
              active: true,
            ),
          ]
        : const [],
  );

  @override
  Future<TermInfo?> activeTermForSchool(SchoolId school) async => null;

  @override
  Future<void> recordTermsConsent({required String locale}) async {}

  Future<void> close() async {
    await _sessions.close();
    await closeLifecycle();
  }
}
