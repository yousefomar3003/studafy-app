import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:studafy/features/family_insights/domain/parent_subscription_repository.dart';
import 'package:studafy/features/family_insights/presentation/family_plus_gate.dart';

import '../../support/localized_app.dart';

/// Family+ is bought per child through the store. The server keeps the
/// entitlement; these tests cover what the parent sees and can do.
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

  testWidgets('without it, the offer names the child, the price and trial', (
    tester,
  ) async {
    tall(tester);
    final store = _Store();
    await tester.pumpWidget(gate(store));
    await tester.pumpAndSettle();

    expect(find.text('INSIGHTS'), findsNothing);
    expect(find.text('Family+ for Sara'), findsOne);
    expect(find.text('Work due this week, so nothing slips'), findsOne);
    // The store's own price and trial, never a hard-coded one.
    expect(find.text(r'$1.99 / month'), findsOne);
    expect(
      find.text(r'If eligible, free for 30 days, then $1.99 / month'),
      findsOne,
    );
    expect(
      find.text('Covers Sara only. Each child has their own Family+.'),
      findsOne,
    );
    // Asked about this child only.
    expect(store.entitlementAskedFor, ['child-1']);
  });

  testWidgets('no checkout without working terms and privacy links', (
    tester,
  ) async {
    tall(tester);
    await tester.pumpWidget(gate(_Store()));
    await tester.pumpAndSettle();
    // This build has no policy URLs configured, as a misconfigured release
    // would not: the button is shown but cannot start a purchase.
    final button = tester.widget<FilledButton>(
      find.widgetWithText(FilledButton, 'Start free trial'),
    );
    expect(button.onPressed, isNull);
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
      find.text('US\$1.99 / month in the US - the store shows your price'),
      findsOne,
    );
    expect(find.byType(FilledButton), findsNothing);
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
  _Store({Set<String>? active, this.storeAvailable = true})
    : active = active ?? {};

  final Set<String> active;
  final bool storeAvailable;
  final entitlementAskedFor = <String?>[];
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
  Future<PaywallOffer> insightsOffer() async => storeAvailable
      ? const PaywallOffer(
          featureKey: 'parent_insights',
          storeProductId: 'studafy_parent_insights_monthly',
          storeAvailable: true,
          price: r'$1.99',
          currencyCode: 'USD',
          periodLabel: 'month',
          hasTrial: true,
          trialLengthLabel: '30 days',
        )
      : const PaywallOffer(
          featureKey: 'parent_insights',
          storeProductId: 'studafy_parent_insights_monthly',
        );

  @override
  Future<void> purchaseInsightsMonthly({
    required String beneficiaryStudentId,
  }) async {}

  @override
  Future<void> restorePurchases() async => restored++;

  @override
  void addEntitlementListener(EntitlementChanged listener) =>
      _listeners.add(listener);

  @override
  void removeEntitlementListener(EntitlementChanged listener) =>
      _listeners.remove(listener);
}
