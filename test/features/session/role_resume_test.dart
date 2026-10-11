import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:studafy/core/device_settings.dart';
import 'package:studafy/core/ids.dart';
import 'package:studafy/core/runtime_environment.dart';
import 'package:studafy/core/studafy_domain.dart';
import 'package:studafy/core/telemetry.dart';
import 'package:studafy/features/session/application/session_interactor.dart';
import 'package:studafy/features/session/domain/session_repository.dart';
import 'package:studafy/features/session/presentation/role_page.dart';

import '../../support/localized_app.dart';
import '../../support/session_repository_fake.dart';

/// A launch with a session still signed in goes straight back to the role
/// this device last opened, instead of asking for the role and the sign-in
/// again. Anything it cannot simply reopen falls back to the picker.
void main() {
  tearDown(ActiveContextController.instance.signOut);

  Future<void> pump(
    WidgetTester tester, {
    required bool signedIn,
    String? lastRole,
    bool addingAccount = false,
  }) async {
    const policy = RuntimePolicy(StudafyEnvironment.development);
    StudafyRuntime.initialize(policy);
    final repository = _StudentAccount(signedIn: signedIn);
    addTearDown(repository.close);
    final session = SessionInteractor(
      repository: repository,
      context: ActiveContextController.instance,
      telemetry: const NoopTelemetry(),
      runtimePolicy: policy,
    )..addingAccount = addingAccount;
    await tester.pumpWidget(
      localizedApp(
        home: RolePage(
          session: session,
          settings: InMemoryDeviceSettings({
            DeviceSettingKeys.introSeen: '1',
            DeviceSettingKeys.lastRole: ?lastRole,
          }),
        ),
        routes: {
          '/student': (_) => const Text('student home'),
          '/teacher': (_) => const Text('teacher home'),
        },
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('a signed-in launch reopens the role it last opened', (
    tester,
  ) async {
    await pump(tester, signedIn: true, lastRole: 'student');
    expect(find.text('student home'), findsOneWidget);
    expect(find.byType(RoleTile), findsNothing);
  });

  testWidgets('a role this account is not falls back to the picker', (
    tester,
  ) async {
    await pump(tester, signedIn: true, lastRole: 'teacher');
    expect(find.text('teacher home'), findsNothing);
    expect(find.byType(RoleTile), findsNWidgets(3));
  });

  testWidgets('adding another account shows the picker, not this one', (
    tester,
  ) async {
    await pump(
      tester,
      signedIn: true,
      lastRole: 'student',
      addingAccount: true,
    );
    expect(find.text('student home'), findsNothing);
    expect(find.byType(RoleTile), findsNWidgets(3));
  });

  testWidgets('signed out, the picker is shown', (tester) async {
    await pump(tester, signedIn: false, lastRole: 'student');
    expect(find.text('student home'), findsNothing);
    expect(find.byType(RoleTile), findsNWidgets(3));
  });
}

class _StudentAccount extends FakeSessionRepositoryBase {
  _StudentAccount({required this.signedIn});

  final bool signedIn;
  final _sessions = StreamController<bool>.broadcast();

  @override
  bool get hasCurrentSession => signedIn;
  @override
  String? get currentUserId => signedIn ? 'student-1' : null;
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
