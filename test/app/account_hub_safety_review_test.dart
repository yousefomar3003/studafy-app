import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:studafy/app/account_hub_page.dart';
import 'package:studafy/app/account_scope.dart';
import 'package:studafy/core/account_lifecycle.dart';
import 'package:studafy/core/studafy_domain.dart';
import 'package:studafy/features/account/application/account_interactor.dart';
import 'package:studafy/features/account/domain/account_repository.dart';
import 'package:studafy/features/safety_review/application/safety_review_interactor.dart';
import 'package:studafy/features/safety_review/presentation/safety_reports_page.dart';

import '../support/localized_app.dart';
import '../support/safety_review_fake.dart';

class _Account implements AccountRepository {
  @override
  Future<DeletionImpact> deletionImpact() => throw UnimplementedError();
  @override
  Future<DeletionRequest> requestAccountDeletion({
    required String reasonCode,
  }) => throw UnimplementedError();
  @override
  Future<bool> cancelAccountDeletion() async => false;
}

/// The safety-report review is offered on the account screen only to an
/// account the server marks as a platform operator (GET /v1/me). There is no
/// school administrator; no school role brings it.
void main() {
  late FakeSafetyReviewRepository server;

  setUp(() => server = FakeSafetyReviewRepository());
  tearDown(() {
    ActiveContextController.instance
      ..profile = null
      ..membership = null;
  });

  Future<void> pumpHub(
    WidgetTester tester, {
    required bool platformOperator,
    StudafyRole role = StudafyRole.teacher,
    bool withReview = true,
  }) async {
    final membership = SchoolMembership(
      id: 'membership-1',
      schoolId: 'school-1',
      schoolName: 'Al-Noor International',
      role: role,
      active: true,
    );
    ActiveContextController.instance
      ..membership = membership
      ..profile = UserProfile(
        id: 'user-1',
        displayName: 'Yousef',
        email: 'owner@example.test',
        memberships: [membership],
        platformOperator: platformOperator,
      );
    tester.view.physicalSize = const Size(390, 1600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      localizedApp(
        locale: const Locale('en'),
        home: const AccountHubPage(),
        scopes: (child) => AccountScope(
          account: AccountInteractor(_Account()),
          safetyReview: withReview ? SafetyReviewInteractor(server) : null,
          child: child,
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('a platform operator sees Safety reports and opens the queue', (
    tester,
  ) async {
    await pumpHub(tester, platformOperator: true);
    expect(find.text('Safety reports'), findsOneWidget);
    await tester.ensureVisible(find.text('Safety reports'));
    await tester.tap(find.text('Safety reports'));
    await tester.pumpAndSettle();
    expect(find.byType(SafetyReportsPage), findsOneWidget);
    expect(server.calls, ['queue']);
  });

  for (final role in StudafyRole.values) {
    testWidgets('a ${role.name} who is not an operator never sees it', (
      tester,
    ) async {
      await pumpHub(tester, platformOperator: false, role: role);
      expect(find.text('Safety reports'), findsNothing);
      expect(server.calls, isEmpty);
    });
  }

  testWidgets('a build with no server offers nothing', (tester) async {
    await pumpHub(tester, platformOperator: true, withReview: false);
    expect(find.text('Safety reports'), findsNothing);
  });
}
