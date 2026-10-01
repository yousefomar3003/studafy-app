import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:studafy/core/ids.dart';
import 'package:studafy/core/runtime_environment.dart';
import 'package:studafy/core/studafy_domain.dart';
import 'package:studafy/core/telemetry.dart';
import 'package:studafy/features/session/application/session_interactor.dart';
import 'package:studafy/features/session/domain/session_repository.dart';
import 'package:studafy/features/session/presentation/login_page.dart';
import 'package:studafy/features/session/presentation/role_page.dart';

import '../../support/localized_app.dart';
import '../../support/session_repository_fake.dart';

const _urlLauncher = MethodChannel('plugins.flutter.io/url_launcher');

/// One kind of account per email: a student's email signing in through the
/// Teacher door is told it is a student account, and continues as one -
/// it is never carried into a new role.
void main() {
  setUp(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(_urlLauncher, (call) async => true);
  });
  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(_urlLauncher, null);
    ActiveContextController.instance.signOut();
  });

  Future<_StudentAccount> pump(WidgetTester tester) async {
    const policy = RuntimePolicy(StudafyEnvironment.development);
    StudafyRuntime.initialize(policy);
    final repository = _StudentAccount();
    addTearDown(repository.close);
    final session = SessionInteractor(
      repository: repository,
      context: ActiveContextController.instance,
      telemetry: const NoopTelemetry(),
      runtimePolicy: policy,
    );
    await tester.pumpWidget(
      localizedApp(
        home: LoginPage(role: UserRole.teacher, session: session),
        routes: {
          '/student': (_) => const Text('student home'),
          '/teacher': (_) => const Text('teacher home'),
          '/onboarding': (_) => const Text('teacher setup'),
        },
      ),
    );
    await tester.pumpAndSettle();
    return repository;
  }

  testWidgets('a student email at the Teacher door is told what it is', (
    tester,
  ) async {
    await pump(tester);
    expect(find.text('This email is a student account'), findsOneWidget);
    expect(find.text('teacher setup'), findsNothing);
    expect(ActiveContextController.instance.membership, isNull);

    await tester.tap(find.text('Continue as Student'));
    await tester.pumpAndSettle();
    expect(find.text('student home'), findsOneWidget);
    expect(
      ActiveContextController.instance.membership?.role,
      StudafyRole.student,
    );
  });

  testWidgets('or the person signs in with a different email instead', (
    tester,
  ) async {
    final repository = await pump(tester);
    await tester.tap(find.text('Use a different email'));
    await tester.pumpAndSettle();
    expect(repository.signedOut, isTrue);
    expect(find.text('student home'), findsNothing);
    expect(find.text('teacher setup'), findsNothing);
  });
}

class _StudentAccount extends FakeSessionRepositoryBase {
  final _sessions = StreamController<bool>.broadcast();
  bool signedOut = false;

  @override
  bool get hasCurrentSession => !signedOut;
  @override
  String? get currentUserId => 'student-1';
  @override
  Stream<bool> get sessionChanges => _sessions.stream;

  Future<void> close() async {
    await _sessions.close();
    await closeLifecycle();
  }
  @override
  Future<void> signInWithProvider(LoginProvider provider) async {}
  @override
  Future<TermInfo?> activeTermForSchool(SchoolId school) async => null;
  @override
  Future<void> signOut({
    SignOutScope scope = SignOutScope.currentDevice,
  }) async => signedOut = true;

  @override
  Future<UserProfile?> currentProfile() async => const UserProfile(
    id: 'student-1',
    displayName: 'Sara',
    email: 'sara@example.test',
    memberships: [
      SchoolMembership(
        id: 'membership-1',
        schoolId: 'school-1',
        schoolName: 'Rara Nana',
        role: StudafyRole.student,
        active: true,
      ),
    ],
  );
}
