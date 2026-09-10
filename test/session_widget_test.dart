import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:studafy/core/ids.dart';
import 'package:studafy/core/runtime_environment.dart';
import 'package:studafy/core/studafy_domain.dart';
import 'package:studafy/core/telemetry.dart';
import 'package:studafy/features/session/application/session_interactor.dart';
import 'package:studafy/features/session/domain/session_repository.dart';
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
      MaterialApp(
        routes: {'/teacher': (_) => const Text('Teacher home')},
        home: LoginPage(role: UserRole.teacher, session: session),
      ),
    );

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
      MaterialApp(
        home: LoginPage(role: UserRole.student, session: session),
      ),
    );
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
    await repository.close();
  });
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

class _WidgetSessionRepository implements SessionRepository {
  _WidgetSessionRepository({this.failProvider = false});

  final bool failProvider;
  final StreamController<bool> _sessions = StreamController<bool>.broadcast();
  int providerCalls = 0;

  @override
  bool get hasCurrentSession => false;

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

  @override
  Future<void> signOut() async {}

  Future<void> close() => _sessions.close();
}
