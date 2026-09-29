import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:in_app_purchase/in_app_purchase.dart';
import 'package:in_app_purchase_android/billing_client_wrappers.dart';
import 'package:in_app_purchase_android/in_app_purchase_android.dart';
import 'package:studafy/data/billing/store_subscription_repository.dart';
import 'package:studafy/data/billing/v1_billing_api.dart';
import 'package:studafy/features/study/domain/study.dart';

const sku = 'studafy_plus_monthly';
const maxSku = 'studafy_max_monthly';

class Billing extends Fake implements V1BillingApi {
  String account = 'student-a';
  bool approved = true;
  bool enabled = true;
  List<V1EntitlementRow> rows = [];
  Set<String> approvedKeys = {'studafy_plus'};
  @override
  Future<V1BillingCatalogue> catalogue() async => V1BillingCatalogue(
    purchaseAccountToken: account,
    products: const [
      V1BillingProduct(
        featureKey: 'studafy_plus',
        platform: 'play_store',
        storeProductId: sku,
      ),
      V1BillingProduct(
        featureKey: 'studafy_max',
        platform: 'play_store',
        storeProductId: maxSku,
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
          for (final key in approvedKeys)
            V1PurchaseApproval(
              id: 'approval-$key',
              studentId: 'student',
              studentName: 'Student',
              featureKey: key,
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
  // ignore: close_sinks - a fake store lives for one test.
  final events = StreamController<List<PurchaseDetails>>.broadcast();
  PurchaseParam? bought;
  bool available = true;

  /// Google Play's record of the subscriptions this phone's Google account
  /// bought, which an upgrade must name.
  List<GooglePlayPurchaseDetails> owned = [];
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
        productId: identifiers.single,
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

List<GooglePlayPurchaseDetails> ownedOnThisPhone(String product) =>
    GooglePlayPurchaseDetails.fromPurchase(
      PurchaseWrapper(
        orderId: 'GPA.1',
        packageName: 'com.studafy.light',
        purchaseTime: 0,
        purchaseToken: 'plus-token',
        signature: 'signature',
        products: [product],
        isAutoRenewing: true,
        originalJson: '{}',
        isAcknowledged: true,
        purchaseState: PurchaseStateWrapper.purchased,
      ),
    );

V1EntitlementRow held(
  String feature, {
  String platform = 'play_store',
  bool mine = true,
  String status = 'active',
  String? renewal,
  DateTime? endsAt,
  String? beneficiary,
}) => V1EntitlementRow(
  featureKey: feature,
  status: status,
  startsAt: DateTime.now().subtract(const Duration(days: 3)),
  endsAt: endsAt ?? DateTime.now().add(const Duration(days: 27)),
  beneficiaryStudentId: beneficiary,
  renewalStatus: renewal,
  platform: platform,
  storeProductId: feature == 'studafy_max' ? maxSku : sku,
  purchasedByMe: mine,
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Store store;
  late Billing billing;
  late StoreSubscriptionRepository repository;
  setUp(() {
    debugDefaultTargetPlatformOverride = TargetPlatform.android;
    store = Store();
    billing = Billing();
    repository = StoreSubscriptionRepository(
      store: store,
      billingApi: billing,
      playPurchases: (_) async =>
          QueryPurchaseDetailsResponse(pastPurchases: store.owned),
    );
  });
  tearDown(() async {
    await repository.dispose();
    await store.events.close();
    debugDefaultTargetPlatformOverride = null;
  });
  test(
    'shows renewal price and selects exact one-month trial at checkout',
    () async {
      final status = await repository.offer(StudyPlanTier.plus);
      expect(status.price, '\$2.49');
      expect(status.oneMonthTrial, isTrue);
      expect(status.canPurchase, isTrue);
      await repository.purchase(StudyPlanTier.plus);
      expect((store.bought as GooglePlayPurchaseParam).offerToken, 'trial');
      expect(store.bought!.applicationUserName, 'student-a');
      expect(
        (await repository.offer(StudyPlanTier.plus)).active,
        isFalse,
        reason: 'opening the store must not grant access',
      );
    },
  );
  test('rechecks consent and account before charging', () async {
    await repository.offer(StudyPlanTier.plus);
    billing.approved = false;
    await expectLater(
      repository.purchase(StudyPlanTier.plus),
      throwsStateError,
    );
    expect(store.bought, isNull);
    billing.approved = true;
    billing.account = 'different-account';
    await expectLater(
      repository.purchase(StudyPlanTier.plus),
      throwsStateError,
    );
    expect(store.bought, isNull);
  });
  test('school switch and store outage fail closed', () async {
    billing.enabled = false;
    expect((await repository.offer(StudyPlanTier.plus)).canPurchase, isFalse);
    store.available = false;
    final status = await repository.offer(StudyPlanTier.plus);
    expect(status.storeAvailable, isFalse);
    expect(status.price, isEmpty);
  });
  test('only a current, own Studafy Plus entitlement unlocks', () async {
    V1EntitlementRow row({
      String feature = 'studafy_plus',
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
      expect((await repository.offer(StudyPlanTier.plus)).active, isFalse);
    }
    billing.rows = [row()];
    expect((await repository.offer(StudyPlanTier.plus)).active, isTrue);
    billing.rows = [row(state: 'grace_period')];
    expect((await repository.offer(StudyPlanTier.plus)).active, isTrue);
  });

  group('never a second subscription or a second charge', () {
    test('Plus upgrades to Max by replacing Plus on Google Play', () async {
      billing
        ..approvedKeys = {'studafy_max'}
        ..rows = [held('studafy_plus')];
      store.owned = ownedOnThisPhone(sku);
      expect((await repository.offer(StudyPlanTier.max)).canPurchase, isTrue);
      await repository.purchase(StudyPlanTier.max);
      final change =
          (store.bought! as GooglePlayPurchaseParam).changeSubscriptionParam!;
      expect(change.oldPurchaseDetails.productID, sku);
      // At once, keeping the billing date; only the difference is charged.
      expect(change.replacementMode, ReplacementMode.chargeProratedPrice);
    });

    test('an upgrade needs the Google account that bought Plus', () async {
      billing
        ..approvedKeys = {'studafy_max'}
        ..rows = [held('studafy_plus')];
      await repository.offer(StudyPlanTier.max);
      await expectLater(
        repository.purchase(StudyPlanTier.max),
        throwsA(
          isA<PurchaseBlockedException>().having(
            (e) => e.reason,
            'reason',
            PurchaseBlock.upgradeNeedsOriginalAccount,
          ),
        ),
      );
      expect(store.bought, isNull);
    });

    for (final (name, rows, tier, reason) in [
      (
        'Max already includes Plus',
        [held('studafy_max')],
        StudyPlanTier.plus,
        PurchaseBlock.alreadySubscribed,
      ),
      (
        'a plan a parent pays for is theirs to change',
        [held('studafy_plus', mine: false)],
        StudyPlanTier.max,
        PurchaseBlock.paidByParent,
      ),
      (
        'a plan billed by the App Store is changed there',
        [held('studafy_plus', platform: 'app_store')],
        StudyPlanTier.max,
        PurchaseBlock.otherStore,
      ),
    ]) {
      test(name, () async {
        billing
          ..approvedKeys = {'studafy_plus', 'studafy_max'}
          ..rows = rows;
        await repository.offer(tier);
        await expectLater(
          repository.purchase(tier),
          throwsA(
            isA<PurchaseBlockedException>().having(
              (e) => e.reason,
              'reason',
              reason,
            ),
          ),
        );
        expect(store.bought, isNull);
      });
    }
  });

  group('the current subscription', () {
    final now = DateTime.now();

    test('the highest own plan, with its renewal and store', () {
      final current = currentStudyPlanSubscription([
        held('studafy_plus'),
        held('studafy_max', renewal: 'cancelled'),
        held('studafy_max', beneficiary: 'a-child'),
      ], now)!;
      expect(current.tier, StudyPlanTier.max);
      expect(current.renewal, RenewalStatus.cancelled);
      expect(current.store, SubscriptionStore.playStore);
      expect(current.storeProductId, maxSku);
    });

    test('a grace period or failed renewal is a payment problem', () {
      expect(
        currentStudyPlanSubscription([
          held('studafy_plus', status: 'grace_period', renewal: 'renewing'),
        ], now)!.renewal,
        RenewalStatus.paymentIssue,
      );
      expect(
        currentStudyPlanSubscription([
          held(
            'studafy_plus',
            status: 'on_hold',
            endsAt: now.subtract(const Duration(days: 2)),
          ),
        ], now)!.renewal,
        RenewalStatus.paymentIssue,
      );
    });

    test('a pause is shown as a pause, not a payment problem', () {
      expect(
        currentStudyPlanSubscription([
          held(
            'studafy_plus',
            status: 'on_hold',
            renewal: 'paused',
            endsAt: now.subtract(const Duration(days: 20)),
          ),
        ], now)!.renewal,
        RenewalStatus.paused,
      );
    });

    test('ended, refunded and other people\'s plans are no subscription', () {
      expect(
        currentStudyPlanSubscription([
          held('studafy_plus', status: 'expired'),
          held('studafy_plus', status: 'revoked'),
          held('studafy_max', beneficiary: 'a-child'),
          held('parent_insights'),
          held(
            'studafy_plus',
            endsAt: now.subtract(const Duration(minutes: 1)),
          ),
        ], now),
        isNull,
      );
    });
  });
}
