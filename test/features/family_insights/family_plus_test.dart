import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:studafy/features/family_insights/domain/parent_subscription_repository.dart';
import 'package:studafy/features/family_insights/presentation/family_plus_gate.dart';

import '../../support/localized_app.dart';

/// Family+ is a family plan bought through the store: up to 4 or up to 8
/// linked children. The server keeps the entitlement and decides which
/// children it covers; these tests cover what the parent sees and can do.
void main() {
  void tall(WidgetTester tester) {
    tester.view.physicalSize = const Size(1200, 2600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
  }

  Widget gate(_Store? store) => localizedApp(
    home: FamilyPlusGate(
      subscriptions: store,
      studentId: 'child-1',
      childName: 'Sara',
      insights: const Scaffold(body: Text('INSIGHTS')),
    ),
  );

  testWidgets('a child with Family+ sees their insights', (tester) async {
    await tester.pumpWidget(gate(_Store(active: {'child-1'})));
    await tester.pumpAndSettle();
    expect(find.text('INSIGHTS'), findsOne);
  });

  testWidgets('without it, both family plans are offered at store prices', (
    tester,
  ) async {
    tall(tester);
    final store = _Store();
    await tester.pumpWidget(gate(store));
    await tester.pumpAndSettle();

    expect(find.text('INSIGHTS'), findsNothing);
    expect(find.text('Family+ for Sara'), findsOne);
    expect(
      find.text('What to focus on this week, most urgent first'),
      findsOne,
    );
    expect(find.text('Up to 4 children'), findsOne);
    expect(find.text('Up to 8 children'), findsOne);
    // The store's own prices and trial, never hard-coded ones.
    expect(find.text(r'$2.99 / month'), findsOne);
    expect(find.text(r'$4.99 / month'), findsOne);
    expect(
      find.text(r'If eligible, free for 30 days, then $2.99 / month'),
      findsOne,
    );
    // Asked about this child only.
    expect(store.entitlementAskedFor, ['child-1']);
  });

  testWidgets('no checkout without working terms and privacy links', (
    tester,
  ) async {
    tall(tester);
    final store = _Store();
    await tester.pumpWidget(gate(store));
    await tester.pumpAndSettle();
    // This build has no policy URLs configured, as a misconfigured release
    // would not: the buttons show but cannot start a purchase, and a tap on
    // the plan says why instead of doing nothing.
    final button = tester.widget<FilledButton>(
      find.widgetWithText(FilledButton, 'Start free trial').first,
    );
    expect(button.onPressed, isNull);
    await tester.tap(find.text('Up to 8 children'));
    await tester.pump();
    expect(
      find.text('This plan cannot be bought in this version of the app yet.'),
      findsOne,
    );
    expect(store.purchased, isEmpty);
  });

  testWidgets('a fifth child is told the 4-child plan does not cover them', (
    tester,
  ) async {
    tall(tester);
    final store = _Store(
      plan: const FamilyPlusStatus(
        plan: FamilyPlusPlan.upTo4,
        coveredStudentIds: ['a', 'b', 'c', 'd'],
      ),
    );
    await tester.pumpWidget(gate(store));
    await tester.pumpAndSettle();

    expect(find.text('Not covered by your plan yet'), findsOne);
    expect(find.textContaining('first 4 linked children'), findsOne);
    expect(find.text('Your plan'), findsOne);
    // Only the bigger plan is on offer; the one held is not sold again.
    expect(find.text('Upgrade to up to 8 children'), findsOne);
    expect(find.text('Subscribe for up to 4 children'), findsNothing);
  });

  testWidgets('purchases can be restored', (tester) async {
    tall(tester);
    final store = _Store();
    await tester.pumpWidget(gate(store));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Restore purchases'));
    await tester.pumpAndSettle();
    expect(store.restored, 1);
    expect(find.text('Checking your purchases...'), findsOne);
  });

  testWidgets('a verified purchase shows the insights without a reload', (
    tester,
  ) async {
    tall(tester);
    final store = _Store();
    await tester.pumpWidget(gate(store));
    await tester.pumpAndSettle();
    expect(find.text('INSIGHTS'), findsNothing);

    store.active.add('child-1');
    store.notify();
    await tester.pumpAndSettle();
    expect(find.text('INSIGHTS'), findsOne);
  });

  testWidgets('an unreachable store says so, with the US price as a guide', (
    tester,
  ) async {
    tall(tester);
    await tester.pumpWidget(gate(_Store(storeAvailable: false)));
    await tester.pumpAndSettle();
    expect(
      find.text('The store could not be reached. Try again later.'),
      findsOne,
    );
    expect(
      find.text('US\$2.99 / month in the US - the store shows your price'),
      findsOne,
    );
    expect(
      find.text('US\$4.99 / month in the US - the store shows your price'),
      findsOne,
    );
    final buttons = tester.widgetList<FilledButton>(find.byType(FilledButton));
    expect(buttons.every((b) => b.onPressed == null), isTrue);
  });

  testWidgets('a build with no store describes Family+ but cannot sell it', (
    tester,
  ) async {
    tall(tester);
    await tester.pumpWidget(gate(null));
    await tester.pumpAndSettle();
    expect(
      find.text('Family+ cannot be bought in this version of the app.'),
      findsOne,
    );
    expect(find.text('Restore purchases'), findsNothing);
  });

  testWidgets('reads in Arabic', (tester) async {
    tall(tester);
    await tester.pumpWidget(
      localizedApp(
        locale: const Locale('ar'),
        home: FamilyPlusGate(
          subscriptions: _Store(),
          studentId: 'child-1',
          childName: 'سارة',
          insights: const SizedBox(),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Family+ لـ سارة'), findsOne);
    expect(find.text('استعادة المشتريات'), findsOne);
  });
}

class _Store implements ParentSubscriptionRepository {
  _Store({
    Set<String>? active,
    this.storeAvailable = true,
    this.plan = FamilyPlusStatus.none,
  }) : active = active ?? {};

  final Set<String> active;
  final bool storeAvailable;
  final FamilyPlusStatus plan;
  final entitlementAskedFor = <String?>[];
  final purchased = <FamilyPlusPlan>[];
  final _listeners = <EntitlementChanged>[];
  int restored = 0;

  void notify() {
    for (final listener in List.of(_listeners)) {
      listener();
    }
  }

  @override
  Future<SubscriptionEntitlement> entitlement({
    String? beneficiaryStudentId,
  }) async {
    entitlementAskedFor.add(beneficiaryStudentId);
    return SubscriptionEntitlement(
      active: active.contains(beneficiaryStudentId),
      source: 'test',
    );
  }

  @override
  Future<FamilyPlusStatus> familyPlan() async => plan;

  @override
  Future<PaywallOffer> familyOffer(FamilyPlusPlan plan) async => storeAvailable
      ? PaywallOffer(
          featureKey: plan.featureKey,
          storeProductId: 'studafy_${plan.featureKey}_monthly',
          storeAvailable: true,
          price: plan == FamilyPlusPlan.upTo4 ? r'$2.99' : r'$4.99',
          currencyCode: 'USD',
          periodLabel: 'month',
          hasTrial: true,
          trialLengthLabel: '30 days',
        )
      : PaywallOffer(
          featureKey: plan.featureKey,
          storeProductId: 'studafy_${plan.featureKey}_monthly',
        );

  @override
  Future<void> purchaseFamilyPlan(FamilyPlusPlan plan) async =>
      purchased.add(plan);

  @override
  Future<void> restorePurchases() async => restored++;

  @override
  void addEntitlementListener(EntitlementChanged listener) =>
      _listeners.add(listener);

  @override
  void removeEntitlementListener(EntitlementChanged listener) =>
      _listeners.remove(listener);
}
