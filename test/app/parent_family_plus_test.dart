import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:studafy/app/parent_shell.dart';
import 'package:studafy/app/studafy_theme.dart';
import 'package:studafy/core/runtime_environment.dart';
import 'package:studafy/core/studafy_design.dart';
import 'package:studafy/core/studafy_domain.dart';
import 'package:studafy/core/telemetry.dart';
import 'package:studafy/features/academic/data/preview_academic_repository.dart';
import 'package:studafy/features/family/application/family_interactor.dart';
import 'package:studafy/features/family/domain/family.dart';
import 'package:studafy/features/family/presentation/family_scope.dart';
import 'package:studafy/features/family_insights/application/family_insights_interactor.dart';
import 'package:studafy/features/family_insights/domain/family_insights.dart';
import 'package:studafy/features/family_insights/domain/parent_subscription_repository.dart';
import 'package:studafy/features/family_insights/presentation/family_plus_prompts.dart';

import '../support/localized_app.dart';

/// Family+ where a parent meets it outside its own tab (2026-11-04): a card
/// on Today while no child has it, and a line on a child's marks - both
/// opening the Family+ page for that child.
void main() {
  setUp(() {
    FamilyPlusHomeCard.showAgain();
    FamilyPlusNudge.showAgain();
    StudafyRuntime.initialize(
      const RuntimePolicy(StudafyEnvironment.synthetic),
    );
    ActiveContextController.instance.hydrate(
      authenticatedProfile: const UserProfile(
        id: 'parent-1',
        displayName: 'Nadia Hassan',
        email: 'nadia@example.test',
        memberships: [],
        accountKind: AccountKind.adult,
      ),
      signedInAs: StudafyRole.parent,
    );
  });
  tearDown(() => ActiveContextController.instance.signOut());

  Future<void> shell(WidgetTester tester, _Store store) async {
    tester.view.physicalSize = const Size(1000, 1400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      localizedApp(
        theme: studafyTheme(),
        scopes: (child) => FamilyScope(
          interactor: FamilyInteractor(
            family: _OneChild(),
            telemetry: const NoopTelemetry(),
          ),
          child: child,
        ),
        home: ParentShell(
          academic: PreviewAcademicRepository(),
          insights: const FamilyInsightsInteractor(
            repository: _NoInsights(),
            telemetry: NoopTelemetry(),
          ),
          familyPlus: store,
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  int selected(WidgetTester tester) => tester
      .widget<StudafyNavigationBar>(find.byType(StudafyNavigationBar))
      .selectedIndex;

  testWidgets('Today offers Family+, opening it for the child', (tester) async {
    await shell(tester, _Store());
    final card = find.text('See Family+');
    await tester.scrollUntilVisible(card, 200);
    await tester.tap(card);
    await tester.pumpAndSettle();
    // The Family+ tab, on the child's own page.
    expect(selected(tester), 2);
    expect(find.text('See how Layla Hassan is really doing'), findsOne);
  });

  testWidgets('a child\'s grades say what Family+ would show, and open it', (
    tester,
  ) async {
    await shell(tester, _Store());
    await tester.tap(find.byType(StudafyNavDestination).at(1));
    await tester.pumpAndSettle();
    const line =
        'See trends and what to focus on for Layla Hassan with Family+';
    // Work first: nothing about Family+ there.
    expect(find.text(line), findsNothing);
    await tester.tap(find.text('Grades'));
    await tester.pumpAndSettle();
    expect(find.text(line), findsOne);
    await tester.tap(find.text('Attendance'));
    await tester.pumpAndSettle();
    expect(find.text(line), findsOne);
    await tester.tap(find.text('See Family+'));
    await tester.pumpAndSettle();
    expect(selected(tester), 2);
  });

  testWidgets('with Family+ there is no card and no line', (tester) async {
    await shell(
      tester,
      _Store(
        plan: const FamilyPlusStatus(
          plan: FamilyPlusPlan.upTo4,
          coveredStudentIds: ['layla'],
        ),
        active: {'layla'},
      ),
    );
    expect(find.text('See Family+'), findsNothing);
    await tester.tap(find.byType(StudafyNavDestination).at(1));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Grades'));
    await tester.pumpAndSettle();
    expect(find.textContaining('with Family+'), findsNothing);
  });
}

class _OneChild implements FamilyRepository {
  @override
  Future<List<GuardianChild>> children() async => const [
    GuardianChild(
      linkId: 'l1',
      studentId: 'layla',
      studentName: 'Layla Hassan',
      schoolId: 'noor',
      schoolName: 'Al-Noor International School',
      status: GuardianLinkStatus.verified,
    ),
  ];

  @override
  dynamic noSuchMethod(Invocation invocation) => throw UnimplementedError();
}

class _NoInsights implements FamilyInsightsRepository {
  const _NoInsights();

  @override
  Future<FamilyInsights> forStudent(String studentId) =>
      throw UnimplementedError();
}

class _Store implements ParentSubscriptionRepository {
  _Store({this.plan = FamilyPlusStatus.none, Set<String>? active})
    : active = active ?? {};

  final FamilyPlusStatus plan;
  final Set<String> active;

  @override
  bool get sellsFamilyPlus => true;

  @override
  Future<SubscriptionEntitlement> entitlement({
    String? beneficiaryStudentId,
  }) async => SubscriptionEntitlement(
    active: active.contains(beneficiaryStudentId),
    source: 'test',
  );

  @override
  Future<FamilyPlusStatus> familyPlan() async => plan;

  @override
  Future<PaywallOffer> familyOffer(FamilyPlusPlan plan) async => PaywallOffer(
    featureKey: plan.featureKey,
    storeProductId: 'studafy_${plan.featureKey}_monthly',
  );

  @override
  Future<void> purchaseFamilyPlan(FamilyPlusPlan plan) async {}

  @override
  Future<void> restorePurchases() async {}

  @override
  void addEntitlementListener(EntitlementChanged listener) {}

  @override
  void removeEntitlementListener(EntitlementChanged listener) {}
}
