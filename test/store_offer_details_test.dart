import 'package:flutter_test/flutter_test.dart';
import 'package:in_app_purchase_android/billing_client_wrappers.dart';
import 'package:in_app_purchase_android/in_app_purchase_android.dart';
import 'package:in_app_purchase_storekit/in_app_purchase_storekit.dart';
import 'package:in_app_purchase_storekit/store_kit_2_wrappers.dart';
import 'package:studafy/data/billing/store_offer_details.dart';

PricingPhaseWrapper phase(int amount, String period, RecurrenceMode mode) =>
    PricingPhaseWrapper(
      billingCycleCount: mode == RecurrenceMode.infiniteRecurring ? 0 : 1,
      billingPeriod: period,
      formattedPrice: 'JOD $amount',
      priceAmountMicros: amount * 1000000,
      priceCurrencyCode: 'JOD',
      recurrenceMode: mode,
    );

SubscriptionOfferDetailsWrapper offer(
  String id,
  List<PricingPhaseWrapper> phases,
) => SubscriptionOfferDetailsWrapper(
  basePlanId: id,
  offerTags: const [],
  offerIdToken: id,
  pricingPhases: phases,
);

List<GooglePlayProductDetails> products(
  List<SubscriptionOfferDetailsWrapper> offers,
) => GooglePlayProductDetails.fromProductDetails(
  ProductDetailsWrapper(
    description: 'Synthetic subscription',
    name: 'Plan',
    productId: 'test.plan',
    productType: ProductType.subs,
    subscriptionOfferDetails: offers,
    title: 'Plan',
  ),
);

void main() {
  test('Google disclosure follows the exact selected plan instead of the first plan', () {
    final rows = products([
      offer('monthly', [phase(3, 'P1M', RecurrenceMode.infiniteRecurring)]),
      offer('yearly', [phase(30, 'P1Y', RecurrenceMode.infiniteRecurring)]),
    ]);
    final terms = resolveStoreOfferTerms(rows[1]);
    expect(terms.price, 'JOD 30');
    expect(terms.periodNoun, 'year');
    expect(terms.hasTrial, isFalse);
  });

  test('recurring price is not inferred from the most expensive introductory phase', () {
    final row = products([
      offer('monthly', [
        phase(9, 'P1M', RecurrenceMode.finiteRecurring),
        phase(3, 'P1M', RecurrenceMode.infiniteRecurring),
      ]),
    ]).single;
    expect(resolveStoreOfferTerms(row).price, 'JOD 3');
  });

  test('trial disclosures preserve the selected plan renewal price', () {
    final row = products([
      offer('trial', [
        phase(0, 'P7D', RecurrenceMode.finiteRecurring),
        phase(3, 'P1M', RecurrenceMode.infiniteRecurring),
      ]),
    ]).single;
    final terms = resolveStoreOfferTerms(row);
    expect(terms.price, 'JOD 3');
    expect(terms.hasTrial, isTrue);
    expect(terms.trialLength, '7 days');
  });

  test('a prepaid plan is not described as automatically renewing', () {
    final row = products([
      offer('prepaid', [phase(3, 'P1M', RecurrenceMode.nonRecurring)]),
    ]).single;
    expect(resolveStoreOfferTerms(row).periodLength, isEmpty);
  });

  test(
    'StoreKit 2 supplies renewal period without inventing trial eligibility',
    () {
      final row = AppStoreProduct2Details.fromSK2Product(
        SK2Product(
          id: 'test.plan',
          displayName: 'Plan',
          displayPrice: 'JOD 3',
          description: 'Synthetic subscription',
          price: 3,
          type: SK2ProductType.autoRenewable,
          priceLocale: SK2PriceLocale(
            currencyCode: 'JOD',
            currencySymbol: 'JOD',
          ),
          subscription: const SK2SubscriptionInfo(
            subscriptionGroupID: 'test.group',
            promotionalOffers: [],
            subscriptionPeriod: SK2SubscriptionPeriod(
              value: 1,
              unit: SK2SubscriptionPeriodUnit.month,
            ),
          ),
        ),
      );
      final terms = resolveStoreOfferTerms(row);
      expect(terms.price, 'JOD 3');
      expect(terms.currencyCode, 'JOD');
      expect(terms.periodNoun, 'month');
      expect(terms.hasTrial, isFalse);
    },
  );
}
