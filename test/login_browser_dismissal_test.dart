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

import 'support/localized_app.dart';
import 'support/session_repository_fake.dart';

/// The channel `closeInAppWebView()` reaches in a test binding, where no
/// platform implementation of url_launcher is registered.
const _urlLauncher = MethodChannel('plugins.flutter.io/url_launcher');

void main() {
  late List<String> launcherCalls;

  setUp(() {
    launcherCalls = <String>[];
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(_urlLauncher, (call) async {
          launcherCalls.add(call.method);
          return true;
        });
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(_urlLauncher, null);
    ActiveContextController.instance.signOut();
  });

  testWidgets('the provider browser is closed once the session arrives', (
    tester,
  ) async {
    const policy = RuntimePolicy(StudafyEnvironment.development);
    StudafyRuntime.initialize(policy);
    final repository = _DismissalRepository();
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

    expect(launcherCalls, isEmpty, reason: 'nothing to close before callback');

    repository.emitSession();
    await tester.pumpAndSettle();

    expect(launcherCalls, contains('closeWebView'));
    await repository.close();
  });

  testWidgets('a second launch that fails does not disown the open browser', (
    tester,
  ) async {
    // The reported sequence: tapping one provider, then another while the
    // first browser is still up. iOS presents one at a time, so the second
    // launch fails — but the first browser is the one holding the callback,
    // and it still has to be closed when the session lands.
    const policy = RuntimePolicy(StudafyEnvironment.development);
    StudafyRuntime.initialize(policy);
    final repository = _DismissalRepository(failFromCall: 2);
    final session = _interactor(repository, policy);

    await tester.pumpWidget(
      localizedApp(
        home: LoginPage(role: UserRole.student, session: session),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byType(Checkbox));
    await tester.pump();

    await tester.tap(find.text('Continue with Microsoft'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Continue with Google'));
    await tester.pumpAndSettle();

    expect(repository.providerCalls, 2);

    repository.emitSession();
    await tester.pumpAndSettle();

    expect(
      launcherCalls,
      contains('closeWebView'),
      reason: 'the first browser still owes us a dismissal',
    );
    await repository.close();
  });

  testWidgets('a session restored at startup closes no browser', (
    tester,
  ) async {
    // Nothing was opened, so nothing may be dismissed: a blanket close here
    // would shut an in-app browser the user opened for something else.
    const policy = RuntimePolicy(StudafyEnvironment.development);
    StudafyRuntime.initialize(policy);
    final repository = _DismissalRepository();
    final session = _interactor(repository, policy);

    await tester.pumpWidget(
      localizedApp(
        home: LoginPage(role: UserRole.student, session: session),
      ),
    );
    await tester.pumpAndSettle();

    repository.emitSession();
    await tester.pumpAndSettle();

    expect(launcherCalls, isEmpty);
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

class _DismissalRepository extends FakeSessionRepositoryBase {
  _DismissalRepository({this.failFromCall});

  /// 1-based index of the first launch that fails, mirroring iOS refusing to
  /// present a second browser while one is already on screen.
  final int? failFromCall;

  final StreamController<bool> _sessions = StreamController<bool>.broadcast();
  int providerCalls = 0;

  @override
  bool get hasCurrentSession => false;

  @override
  Stream<bool> get sessionChanges => _sessions.stream;

  @override
  Future<void> signInWithProvider(LoginProvider provider) async {
    providerCalls++;
    final fails = failFromCall;
    if (fails != null && providerCalls >= fails) {
      throw StateError('Could not open the sign-in browser.');
    }
  }

  void emitSession() => _sessions.add(true);

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
