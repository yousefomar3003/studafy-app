import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:studafy/core/ids.dart';
import 'package:studafy/core/runtime_environment.dart';
import 'package:studafy/core/studafy_domain.dart';
import 'package:studafy/core/telemetry.dart';
import 'package:studafy/features/session/application/session_interactor.dart';
import 'package:studafy/features/session/domain/session_repository.dart';

import 'support/localized_app.dart';
import 'support/session_repository_fake.dart';

import 'package:studafy/features/session/presentation/login_page.dart';
import 'package:studafy/features/session/presentation/role_page.dart';

void main() {
  tearDown(() => ActiveContextController.instance.signOut());

  testWidgets('synthetic login requires consent then opens the selected role', (
    tester,
  ) async {
    StudafyRuntime.initialize(
      const RuntimePolicy(StudafyEnvironment.synthetic),
    );
    final repository = _WidgetSessionRepository();
    final session = _interactor(
      repository,
      const RuntimePolicy(StudafyEnvironment.synthetic),
    );

    await tester.pumpWidget(
      localizedApp(
        routes: {'/teacher': (_) => const Text('Teacher home')},
        home: LoginPage(role: UserRole.teacher, session: session),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Continue with Google'));
    await tester.pump();
    expect(find.byType(LoginPage), findsOneWidget);
    expect(ActiveContextController.instance.role, isNull);

    await tester.tap(find.byType(Checkbox));
    await tester.pump();
    await tester.tap(find.text('Continue with Google'));
    await tester.pumpAndSettle();

    expect(find.text('Teacher home'), findsOneWidget);
    expect(ActiveContextController.instance.role, StudafyRole.teacher);
    expect(repository.providerCalls, 0);
    await repository.close();
  });

  testWidgets('remote provider failure returns safe session error state', (
    tester,
  ) async {
    const policy = RuntimePolicy(StudafyEnvironment.development);
    StudafyRuntime.initialize(policy);
    final repository = _WidgetSessionRepository(failProvider: true);
    final session = _interactor(repository, policy);

    await tester.pumpWidget(
      localizedApp(
        home: LoginPage(role: UserRole.student, session: session),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byType(Checkbox));
    await tester.pump();
    await tester.tap(find.text('Continue with Google'));
    await tester.pumpAndSettle();

    expect(repository.providerCalls, 1);
    expect(
      find.text('Something went wrong. Please try again.'),
      findsOneWidget,
    );
    expect(find.byType(LoginPage), findsOneWidget);
    expect(session.status, SessionStatus.signedOut);
    await repository.close();
  });

  testWidgets('dismissing OAuth permits retry with another provider', (
    tester,
  ) async {
    const policy = RuntimePolicy(StudafyEnvironment.development);
    StudafyRuntime.initialize(policy);
    final repository = _WidgetSessionRepository();
    final session = _interactor(repository, policy);
    await tester.pumpWidget(
      localizedApp(
        home: LoginPage(role: UserRole.student, session: session),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byType(Checkbox));
    await tester.pump();
    await tester.tap(find.text('Continue with Google'));
    await tester.pumpAndSettle();
    expect(find.byType(LinearProgressIndicator), findsNothing);
    await tester.tap(find.text('Continue with Microsoft'));
    await tester.pumpAndSettle();
    expect(repository.providerCalls, 2);
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.runAsync(() async {
      await session.dispose();
      await repository.close();
    });
  });

  testWidgets('restored session resolves after localizations are available', (
    tester,
  ) async {
    const policy = RuntimePolicy(StudafyEnvironment.development);
    StudafyRuntime.initialize(policy);
    final repository = _WidgetSessionRepository(restoredSession: true);
    final session = _interactor(repository, policy);
    await tester.pumpWidget(
      localizedApp(
        home: LoginPage(role: UserRole.student, session: session),
      ),
    );
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    expect(
      find.text('This account does not have the selected school role.'),
      findsOneWidget,
    );
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.runAsync(() async {
      await session.dispose();
      await repository.close();
    });
  });

  testWidgets(
    'auth stream errors are handled without exposing provider details',
    (tester) async {
      const policy = RuntimePolicy(StudafyEnvironment.development);
      StudafyRuntime.initialize(policy);
      final repository = _WidgetSessionRepository();
      final session = _interactor(repository, policy);
      await tester.pumpWidget(
        localizedApp(
          home: LoginPage(role: UserRole.student, session: session),
        ),
      );
      await tester.pumpAndSettle();
      repository._sessions.addError(StateError('private provider details'));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      expect(
        find.text('Something went wrong. Please try again.'),
        findsOneWidget,
      );
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.runAsync(() async {
        await session.dispose();
        await repository.close();
      });
    },
  );
}

SessionInteractor _interactor(
  SessionRepository repository,
  RuntimePolicy policy,
) => SessionInteractor(
  repository: repository,
  context: ActiveContextController.instance,
  telemetry: const NoopTelemetry(),
  runtimePolicy: policy,
);

class _WidgetSessionRepository extends FakeSessionRepositoryBase {
  _WidgetSessionRepository({
    this.failProvider = false,
    this.restoredSession = false,
  });

  final bool failProvider;
  final bool restoredSession;
  final StreamController<bool> _sessions = StreamController<bool>.broadcast();
  int providerCalls = 0;

  @override
  bool get hasCurrentSession => restoredSession;

  @override
  Stream<bool> get sessionChanges => _sessions.stream;

  @override
  Future<void> signInWithProvider(LoginProvider provider) async {
    providerCalls++;
    if (failProvider) throw StateError('synthetic provider failure');
  }

  @override
  Future<UserProfile?> currentProfile() async => null;

  @override
  Future<TermInfo?> activeTermForSchool(SchoolId school) async => null;

  @override
  Future<void> recordTermsConsent({required String locale}) async {}

  Future<void> close() async {
    await _sessions.close();
    await closeLifecycle();
  }
}
