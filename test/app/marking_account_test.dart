import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:studafy/app/account_hub_page.dart';
import 'package:studafy/app/account_scope.dart';
import 'package:studafy/app/teacher_marking_subscription.dart';
import 'package:studafy/core/account_lifecycle.dart';
import 'package:studafy/core/studafy_domain.dart';
import 'package:studafy/core/studafy_formatting.dart';
import 'package:studafy/features/academic/data/preview_marking_repository.dart';
import 'package:studafy/features/academic/domain/marking.dart';
import 'package:studafy/features/academic/presentation/marking_plan_page.dart';
import 'package:studafy/features/academic/presentation/marking_scope.dart';
import 'package:studafy/features/account/application/account_interactor.dart';
import 'package:studafy/features/account/domain/account_repository.dart';

import '../support/localized_app.dart';

/// Studafy AI Marking on the account screen (ADR-0046): a student's own
/// switch for suggested marks, and a teacher's plan with Restore purchases.

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

class _Preference extends PreviewMarkingRepository {
  final writes = <bool>[];

  @override
  Future<bool> setOptedOut(bool optedOut) async {
    writes.add(optedOut);
    return super.setOptedOut(optedOut);
  }
}

class _Store implements MarkingPlanStore {
  int restores = 0;
  int purchases = 0;

  @override
  bool get sellsMarkingPlan => true;

  @override
  Future<MarkingPlanOffer> markingOffer() async => const MarkingPlanOffer(
    storeAvailable: true,
    price: r'$4.99',
    currencyCode: 'USD',
    periodLabel: 'month',
  );

  @override
  Future<void> purchaseMarkingPlan() async => purchases++;

  @override
  Future<void> restorePurchases() async => restores++;

  @override
  void addEntitlementListener(void Function() listener) {}

  @override
  void removeEntitlementListener(void Function() listener) {}
}

void _signIn(StudafyRole role) {
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
      displayName: 'Sara Al-Amin',
      email: 'sara@example.test',
      memberships: [membership],
    );
}

Widget _app(MarkingServices services, Widget home) => localizedApp(
  home: home,
  scopes: (child) => AccountScope(
    account: AccountInteractor(_Account()),
    child: MarkingScope(services: services, child: child),
  ),
);

void main() {
  tearDown(() {
    ActiveContextController.instance
      ..profile = null
      ..membership = null;
  });

  void tall(WidgetTester tester) {
    tester.view.physicalSize = const Size(1200, 3200);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
  }

  testWidgets('a student can turn suggested marks off from their account', (
    tester,
  ) async {
    tall(tester);
    _signIn(StudafyRole.student);
    final preference = _Preference();
    await tester.pumpWidget(
      _app(
        MarkingServices(repository: preference, preference: preference),
        const AccountHubPage(),
      ),
    );
    await tester.pumpAndSettle();
    final toggle = find.byKey(const ValueKey('marking-opt-out-switch'));
    expect(toggle, findsOneWidget);
    expect(tester.widget<Switch>(toggle).value, isTrue);
    await tester.tap(
      find.text('Let my teachers use AI to suggest marks on my work'),
    );
    await tester.pumpAndSettle();
    expect(preference.writes, [true]);
    expect(tester.widget<Switch>(toggle).value, isFalse);
  });

  testWidgets('a teacher has no such switch', (tester) async {
    tall(tester);
    _signIn(StudafyRole.teacher);
    final preference = _Preference();
    await tester.pumpWidget(
      _app(
        MarkingServices(repository: preference, preference: preference),
        const AccountHubPage(),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('marking-opt-out-switch')), findsNothing);
  });

  testWidgets('a teacher reaches Studafy AI Marking and Restore purchases '
      'under Subscription', (tester) async {
    tall(tester);
    _signIn(StudafyRole.teacher);
    final store = _Store();
    final services = MarkingServices(
      repository: PreviewMarkingRepository(
        plan: MarkingPlan(
          active: false,
          teacher: true,
          available: true,
          used: 0,
          total: 100,
          resetsAt: DateTime.utc(2026, 11),
        ),
      ),
      plans: store,
    );
    await tester.pumpWidget(
      _app(
        services,
        Builder(
          builder: (context) =>
              AccountHubPage(subscription: teacherMarkingSubscription(context)),
        ),
      ),
    );
    await tester.pumpAndSettle();
    final name = studafyPlanName('Studafy AI Marking');
    expect(find.text(name), findsOneWidget);
    await tester.tap(find.text('Restore purchases'));
    await tester.pumpAndSettle();
    expect(store.restores, 1);

    await tester.tap(find.text(name));
    await tester.pumpAndSettle();
    expect(find.byType(MarkingPlanPage), findsOneWidget);
    // The store's own price; buying needs the terms and privacy links,
    // which a test build does not have.
    expect(find.text(r'$4.99 / month'), findsOneWidget);
    expect(
      find.text('This plan cannot be bought in this version of the app yet.'),
      findsOneWidget,
    );
    expect(store.purchases, 0);
  });

  testWidgets('no store, no Studafy AI Marking row', (tester) async {
    tall(tester);
    _signIn(StudafyRole.teacher);
    await tester.pumpWidget(
      _app(
        MarkingServices(repository: PreviewMarkingRepository()),
        Builder(
          builder: (context) =>
              AccountHubPage(subscription: teacherMarkingSubscription(context)),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text(studafyPlanName('Studafy AI Marking')), findsNothing);
    expect(find.text('Restore purchases'), findsNothing);
  });
}
