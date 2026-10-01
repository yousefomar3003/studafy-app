import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:studafy/core/ids.dart';
import 'package:studafy/core/runtime_environment.dart';
import 'package:studafy/core/studafy_domain.dart';
import 'package:studafy/core/telemetry.dart';
import 'package:studafy/features/session/application/session_interactor.dart';
import 'package:studafy/features/session/domain/session_repository.dart';
import 'package:studafy/features/session/presentation/account_security_page.dart';

import '../../support/localized_app.dart';
import '../../support/session_repository_fake.dart';

/// Deleting an account lives in Sign-in and security, behind a plain
/// explanation, before the deletion screen asks for its own typed
/// confirmation.
void main() {
  void tall(WidgetTester tester) {
    tester.view.physicalSize = const Size(1200, 2600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
  }

  testWidgets('delete account is here, explained, and asks before going on', (
    tester,
  ) async {
    tall(tester);
    var opened = 0;
    await tester.pumpWidget(
      localizedApp(
        home: AccountSecurityPage(
          session: _session(),
          onDeleteAccount: (_) => opened++,
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('TWO-FACTOR SIGN-IN'), findsOne);
    expect(find.text('Sign out everywhere'), findsOne);
    expect(find.text('Delete account'), findsWidgets);
    expect(
      find.textContaining('removes your personal data after 14 days'),
      findsOne,
    );

    // Cancelling the explanation goes nowhere.
    await tester.tap(find.text('Delete account').last);
    await tester.pumpAndSettle();
    expect(find.text('Delete your account?'), findsOne);
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
    expect(opened, 0);

    // Continuing opens the deletion screen, which confirms again itself.
    await tester.tap(find.text('Delete account').last);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Continue'));
    await tester.pumpAndSettle();
    expect(opened, 1);
  });

  testWidgets('without a deletion flow the section is not shown', (
    tester,
  ) async {
    tall(tester);
    await tester.pumpWidget(
      localizedApp(home: AccountSecurityPage(session: _session())),
    );
    await tester.pumpAndSettle();
    expect(find.text('Delete account'), findsNothing);
  });
}

SessionInteractor _session() => SessionInteractor(
  repository: _Repository(),
  context: ActiveContextController.instance,
  telemetry: const NoopTelemetry(),
  runtimePolicy: const RuntimePolicy(StudafyEnvironment.synthetic),
);

class _Repository extends FakeSessionRepositoryBase {
  @override
  bool get hasCurrentSession => false;

  @override
  Stream<bool> get sessionChanges => const Stream<bool>.empty();

  @override
  Future<void> signInWithProvider(LoginProvider provider) async {}

  @override
  Future<UserProfile?> currentProfile() async => null;

  @override
  Future<TermInfo?> activeTermForSchool(SchoolId school) async => null;

  @override
  Future<void> recordTermsConsent({required String locale}) async {}
}
