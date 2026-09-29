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

/// Adding a second account: the account being added *to* is still signed
/// in while the login screen is up, and must not be taken for the new one.
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

  Future<(_Accounts, SessionInteractor)> pump(
    WidgetTester tester, {
    required bool adding,
  }) async {
    const policy = RuntimePolicy(StudafyEnvironment.development);
    StudafyRuntime.initialize(policy);
    final repository = _Accounts();
    final session = SessionInteractor(
      repository: repository,
      context: ActiveContextController.instance,
      telemetry: const NoopTelemetry(),
      runtimePolicy: policy,
    )..addingAccount = adding;
    await tester.pumpWidget(
      localizedApp(
        home: LoginPage(role: UserRole.parent, session: session),
        routes: {'/parent': (_) => const Text('parent home')},
      ),
    );
    await tester.pumpAndSettle();
    return (repository, session);
  }

  testWidgets('normally, a session already here signs straight in', (
    tester,
  ) async {
    final (repository, _) = await pump(tester, adding: false);
    expect(repository.profilesLoaded, 1);
    await repository.close();
  });

  testWidgets('adding an account, the current one does not sign in again', (
    tester,
  ) async {
    final (repository, session) = await pump(tester, adding: true);
    expect(repository.profilesLoaded, 0);

    // The account being added to refreshes its token meanwhile.
    repository.emitSession();
    await tester.pumpAndSettle();
    expect(repository.profilesLoaded, 0);
    expect(session.addingAccount, isTrue);
    await repository.close();
  });

  testWidgets('adding an account, the new sign-in completes', (tester) async {
    final (repository, session) = await pump(tester, adding: true);

    await tester.tap(find.byType(Checkbox));
    await tester.pump();
    await tester.tap(find.text('Continue with Google'));
    await tester.pumpAndSettle();
    repository.current = 'second-account';
    repository.emitSession();
    await tester.pumpAndSettle();

    expect(repository.profilesLoaded, 1);
    expect(ActiveContextController.instance.profile?.id, 'second-account');
    expect(session.addingAccount, isFalse);
    expect(find.text('parent home'), findsOne);
    await repository.close();
  });
}

class _Accounts extends FakeSessionRepositoryBase {
  String current = 'first-account';
  int profilesLoaded = 0;
  final _sessions = StreamController<bool>.broadcast();

  void emitSession() => _sessions.add(true);

  @override
  bool get hasCurrentSession => true;
  @override
  String? get currentUserId => current;
  @override
  Stream<bool> get sessionChanges => _sessions.stream;
  @override
  Future<void> signInWithProvider(LoginProvider provider) async {}
  @override
  Future<TermInfo?> activeTermForSchool(SchoolId school) async => null;

  @override
  Future<UserProfile?> currentProfile() async {
    profilesLoaded++;
    return UserProfile(
      id: current,
      displayName: current,
      email: '',
      memberships: const [],
    );
  }

  Future<void> close() async {
    await _sessions.close();
    await closeLifecycle();
  }
}
