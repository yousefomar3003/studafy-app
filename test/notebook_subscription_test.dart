import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:in_app_purchase/in_app_purchase.dart';
import 'package:in_app_purchase_android/billing_client_wrappers.dart';
import 'package:in_app_purchase_android/in_app_purchase_android.dart';
import 'package:studafy/data/billing/v1_billing_api.dart';
import 'package:studafy/data/subscription_service.dart';

const sku = 'studafy_student_notebook_monthly';

class Billing extends Fake implements V1BillingApi {
  String account = 'student-a';
  bool approved = true;
  bool enabled = true;
  List<V1EntitlementRow> rows = [];
  @override
  Future<V1BillingCatalogue> catalogue() async => V1BillingCatalogue(
    purchaseAccountToken: account,
    products: const [
      V1BillingProduct(
        featureKey: 'student_notebook',
        platform: 'play_store',
        storeProductId: sku,
      ),
    ],
    selfPurchase: [
      V1BillingSelfPurchaseStatus(
        schoolId: 'school',
        selfPurchaseEnabled: enabled,
      ),
    ],
  );
  @override
  Future<List<V1EntitlementRow>> entitlements() async => rows;
  @override
  Future<List<V1PurchaseApproval>> purchaseApprovals() async => approved
      ? [
          V1PurchaseApproval(
            id: 'approval',
            studentId: 'student',
            studentName: 'Student',
            featureKey: 'student_notebook',
            status: 'approved',
            requestedAt: DateTime.now(),
            expiresAt: DateTime.now().add(const Duration(hours: 1)),
          ),
        ]
      : [];
}

PricingPhaseWrapper phase(int micros, String price, RecurrenceMode mode) =>
    PricingPhaseWrapper(
      billingCycleCount: mode == RecurrenceMode.finiteRecurring ? 1 : 0,
      billingPeriod: 'P1M',
      formattedPrice: price,
      priceAmountMicros: micros,
      priceCurrencyCode: 'USD',
      recurrenceMode: mode,
    );

class Store extends Fake implements InAppPurchase {
  final events = StreamController<List<PurchaseDetails>>.broadcast();
  PurchaseParam? bought;
  bool available = true;
  @override
  Stream<List<PurchaseDetails>> get purchaseStream => events.stream;
  @override
  Future<bool> isAvailable() async => available;
  @override
  Future<ProductDetailsResponse> queryProductDetails(
    Set<String> identifiers,
  ) async => ProductDetailsResponse(
    productDetails: GooglePlayProductDetails.fromProductDetails(
      ProductDetailsWrapper(
        description: 'Notebook',
        name: 'Notebook',
        productId: sku,
        productType: ProductType.subs,
        title: 'Notebook',
        subscriptionOfferDetails: [
          SubscriptionOfferDetailsWrapper(
            basePlanId: 'monthly',
            offerTags: [],
            offerIdToken: 'base',
            pricingPhases: [
              phase(2490000, '\$2.49', RecurrenceMode.infiniteRecurring),
            ],
          ),
          SubscriptionOfferDetailsWrapper(
            basePlanId: 'monthly',
            offerTags: [],
            offerIdToken: 'trial',
            pricingPhases: [
              phase(0, '\$0.00', RecurrenceMode.finiteRecurring),
              phase(2490000, '\$2.49', RecurrenceMode.infiniteRecurring),
            ],
          ),
        ],
      ),
    ),
    notFoundIDs: [],
  );
  @override
  Future<bool> buyNonConsumable({required PurchaseParam purchaseParam}) async {
    bought = purchaseParam;
    return true;
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Store store;
  late Billing billing;
  late StoreSubscriptionRepository repository;
  setUp(() {
    debugDefaultTargetPlatformOverride = TargetPlatform.android;
    store = Store();
    billing = Billing();
    repository = StoreSubscriptionRepository(store: store, billingApi: billing);
  });
  tearDown(() async {
    await repository.dispose();
    await store.events.close();
    debugDefaultTargetPlatformOverride = null;
  });
  test(
    'shows renewal price and selects exact one-month trial at checkout',
    () async {
      final status = await repository.notebookStatus();
      expect(status.price, '\$2.49');
      expect(status.oneMonthTrial, isTrue);
      expect(status.canPurchase, isTrue);
      await repository.purchaseNotebook();
      expect((store.bought as GooglePlayPurchaseParam).offerToken, 'trial');
      expect(store.bought!.applicationUserName, 'student-a');
      expect(
        (await repository.notebookStatus()).active,
        isFalse,
        reason: 'opening the store must not grant access',
      );
    },
  );
  test('rechecks consent and account before charging', () async {
    await repository.notebookStatus();
    billing.approved = false;
    await expectLater(repository.purchaseNotebook(), throwsStateError);
    expect(store.bought, isNull);
    billing.approved = true;
    billing.account = 'different-account';
    await expectLater(repository.purchaseNotebook(), throwsStateError);
    expect(store.bought, isNull);
  });
  test('school switch and store outage fail closed', () async {
    billing.enabled = false;
    expect((await repository.notebookStatus()).canPurchase, isFalse);
    store.available = false;
    final status = await repository.notebookStatus();
    expect(status.storeAvailable, isFalse);
    expect(status.price, isEmpty);
  });
  test('only current own Notebook entitlement unlocks', () async {
    V1EntitlementRow row({
      String feature = 'student_notebook',
      String state = 'active',
      DateTime? endsAt,
      String? beneficiary,
    }) => V1EntitlementRow(
      featureKey: feature,
      status: state,
      startsAt: DateTime.now().subtract(const Duration(days: 1)),
      endsAt: endsAt ?? DateTime.now().add(const Duration(days: 1)),
      beneficiaryStudentId: beneficiary,
    );
    for (final invalid in [
      row(feature: 'parent_insights'),
      row(state: 'revoked'),
      row(state: 'pending'),
      row(beneficiary: 'another-child'),
      row(endsAt: DateTime.now().subtract(const Duration(seconds: 1))),
    ]) {
      billing.rows = [invalid];
      expect((await repository.notebookStatus()).active, isFalse);
    }
    billing.rows = [row()];
    expect((await repository.notebookStatus()).active, isTrue);
    billing.rows = [row(state: 'grace_period')];
    expect((await repository.notebookStatus()).active, isTrue);
  });
}
