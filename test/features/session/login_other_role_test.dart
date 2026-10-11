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

/// An adult may be a teacher and a parent, but is never carried into the
/// other role unasked: a parent's email at the Teacher door used to land in
/// teacher setup as if it were new. Now it is told it is a parent account,
/// and chooses.
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

  Future<_ParentAccount> pump(WidgetTester tester) async {
    const policy = RuntimePolicy(StudafyEnvironment.development);
    StudafyRuntime.initialize(policy);
    final repository = _ParentAccount();
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
          '/parent': (_) => const Text('parent home'),
          '/teacher': (_) => const Text('teacher home'),
          '/onboarding': (_) => const Text('teacher setup'),
        },
      ),
    );
    await tester.pumpAndSettle();
    return repository;
  }

  testWidgets('a parent email at the Teacher door is told it is a parent', (
    tester,
  ) async {
    await pump(tester);
    expect(find.text('This email is already a parent account'), findsOne);
    expect(find.text('teacher setup'), findsNothing);

    await tester.tap(find.text('Continue as Parent'));
    await tester.pumpAndSettle();
    expect(find.text('parent home'), findsOneWidget);
    expect(ActiveContextController.instance.signedInAs, StudafyRole.parent);
  });

  testWidgets('or chooses to teach as well, which starts teacher setup', (
    tester,
  ) async {
    await pump(tester);
    await tester.tap(find.text('Also use it as a teacher'));
    await tester.pumpAndSettle();
    expect(find.text('teacher setup'), findsOneWidget);
  });
}

class _ParentAccount extends FakeSessionRepositoryBase {
  _ParentAccount() {
    linkedChildren = true;
  }

  final _sessions = StreamController<bool>.broadcast();

  @override
  bool get hasCurrentSession => true;
  @override
  String? get currentUserId => 'parent-1';
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
  }) async {}

  @override
  Future<UserProfile?> currentProfile() async => const UserProfile(
    id: 'parent-1',
    displayName: 'Mona',
    email: 'mona@example.test',
    memberships: [],
    accountKind: AccountKind.adult,
  );
}
