import 'package:flutter/foundation.dart';
import 'package:in_app_purchase/in_app_purchase.dart';
import 'package:in_app_purchase_android/billing_client_wrappers.dart'
    show PricingPhaseWrapper, RecurrenceMode;
import 'package:in_app_purchase_android/in_app_purchase_android.dart'
    show GooglePlayProductDetails;
import 'package:in_app_purchase_storekit/in_app_purchase_storekit.dart'
    show AppStoreProductDetails, AppStoreProduct2Details;
import 'package:in_app_purchase_storekit/store_kit_wrappers.dart'
    show SKProductDiscountPaymentMode, SKSubscriptionPeriodUnit;

import 'package:in_app_purchase_storekit/store_kit_2_wrappers.dart'
    show SK2SubscriptionPeriodUnit;

/// Store-verified pricing and term strings for one paywall offer.
///
/// Every string comes from the store's product query (Apple 3.1.2: tiers and
/// trial terms vary per storefront - a hardcoded "1.99" is wrong in most
/// countries). Where a platform exposes no subscription metadata the fields
/// degrade to empty and the paywall falls back to neutral wording instead of
/// inventing a price.
@immutable
class StoreOfferTerms {
  const StoreOfferTerms({
    required this.price,
    required this.currencyCode,
    required this.periodLength,
    required this.periodAdjective,
    required this.hasTrial,
    required this.trialLength,
  });

  /// Formatted recurring price including the currency symbol ("$1.99").
  final String price;
  final String currencyCode;

  /// How long one billing period lasts ("1 month", "30 days").
  final String periodLength;

  /// Adjective for the same period ("monthly", "weekly", "yearly").
  final String periodAdjective;

  /// The period as a billing noun for "X / `<period>`" copy ("month", "3 months").
  String get periodNoun {
    final length = periodLength;
    if (length == '1 month') return 'month';
    if (length == '1 week') return 'week';
    if (length == '1 year') return 'year';
    if (length == '1 day') return 'day';
    return length;
  }

  /// True when the store lists a free-trial introductory phase/offer.
  final bool hasTrial;
  final String trialLength;

  static const none = StoreOfferTerms(
    price: '',
    currencyCode: '',
    periodLength: '',
    periodAdjective: '',
    hasTrial: false,
    trialLength: '',
  );
}

StoreOfferTerms _withBase(ProductDetails p) => StoreOfferTerms(
  price: p.price,
  currencyCode: p.currencyCode,
  periodLength: '',
  periodAdjective: '',
  hasTrial: false,
  trialLength: '',
);

/// Normalizes a store product query result into paywall terms.
///
/// iOS exposes the renewal price via [ProductDetails.price] plus an
/// `introductoryPrice` whose payment mode is a free trial. Android exposes the
/// subscription as an offer with pricing phases: the renewal phase is the
/// infinite recurring phase of the selected offer, the trial is a zero-priced finite phase
/// ahead of it (Google shows the first phase's price - "0.00" during a trial -
/// so the base [ProductDetails.price] cannot be trusted on Android).
StoreOfferTerms resolveStoreOfferTerms(ProductDetails product) {
  if (product is GooglePlayProductDetails) {
    return _fromGooglePlay(product);
  }
  if (product is AppStoreProduct2Details) {
    final period = product.sk2Product.subscription?.subscriptionPeriod;
    final unit = period?.unit;
    return StoreOfferTerms(
      price: product.price,
      currencyCode: product.currencyCode,
      periodLength: period == null || period.value <= 0
          ? ''
          : _countAndUnit(period.value, unit!.name),
      periodAdjective: switch (unit) {
        SK2SubscriptionPeriodUnit.day => 'daily',
        SK2SubscriptionPeriodUnit.week => 'weekly',
        SK2SubscriptionPeriodUnit.month => 'monthly',
        SK2SubscriptionPeriodUnit.year => 'yearly',
        null => '',
      },
      // Promotional offers do not prove introductory-offer eligibility.
      hasTrial: false,
      trialLength: '',
    );
  }
  if (product is AppStoreProductDetails) {
    return _fromAppStore(product);
  }
  return _withBase(product);
}

StoreOfferTerms _fromGooglePlay(GooglePlayProductDetails product) {
  final offers = product.productDetails.subscriptionOfferDetails;
  if (offers == null || offers.isEmpty) return _withBase(product);
  // Resolve the exact offer token passed to checkout, not another base plan.
  final index = product.subscriptionIndex;
  if (index == null || index < 0 || index >= offers.length) {
    return _withBase(product);
  }
  final phases = offers[index].pricingPhases;
  final recurring = phases.where(
    (phase) => phase.recurrenceMode == RecurrenceMode.infiniteRecurring,
  );
  if (recurring.length != 1) return _withBase(product);
  final renewal = recurring.single;
  PricingPhaseWrapper? trial;
  for (final phase in phases) {
    if (phase != renewal &&
        phase.priceAmountMicros == 0 &&
        phase.recurrenceMode == RecurrenceMode.finiteRecurring &&
        phase.billingCycleCount == 1) {
      trial = phase;
      break;
    }
  }
  return StoreOfferTerms(
    price: renewal.formattedPrice.isEmpty
        ? product.price
        : renewal.formattedPrice,
    currencyCode: renewal.priceCurrencyCode.isEmpty
        ? product.currencyCode
        : renewal.priceCurrencyCode,
    periodLength: _periodFromIso(renewal.billingPeriod),
    periodAdjective: _adjectiveFromIso(renewal.billingPeriod),
    hasTrial: trial != null,
    trialLength: trial == null ? '' : _periodFromIso(trial.billingPeriod),
  );
}

StoreOfferTerms _fromAppStore(AppStoreProductDetails product) {
  final sku = product.skProduct;
  final period = sku.subscriptionPeriod;
  final intro = sku.introductoryPrice;
  final hasTrial =
      intro != null &&
      intro.paymentMode == SKProductDiscountPaymentMode.freeTrail &&
      intro.subscriptionPeriod.numberOfUnits > 0 &&
      intro.numberOfPeriods > 0;
  return StoreOfferTerms(
    price: product.price,
    currencyCode: product.currencyCode,
    periodLength: period == null
        ? ''
        : _periodFromIos(period.numberOfUnits, period.unit),
    periodAdjective: period == null ? '' : _adjectiveFromIos(period.unit),
    hasTrial: hasTrial,
    trialLength: hasTrial
        ? _periodFromIos(
            intro.subscriptionPeriod.numberOfUnits * intro.numberOfPeriods,
            intro.subscriptionPeriod.unit,
          )
        : '',
  );
}

/// ISO-8601 duration like "P1M"/"P30D" -> "1 month"/"30 days".
String _periodFromIso(String iso) {
  final parsed = _parseIso(iso);
  return parsed == null ? '' : _countAndUnit(parsed.$1, parsed.$2);
}

/// ISO-8601 duration -> "monthly"/"60-day"/"".
String _adjectiveFromIso(String iso) {
  final parsed = _parseIso(iso);
  if (parsed == null) return '';
  final (count, unit) = parsed;
  if (count != 1) return '$count-$unit';
  return switch (unit) {
    'day' => 'daily',
    'week' => 'weekly',
    'month' => 'monthly',
    'year' => 'yearly',
    _ => '$count-$unit',
  };
}

(int, String)? _parseIso(String iso) {
  final match = RegExp(r'^P(?:(\d+)D|(\d+)W|(\d+)M|(\d+)Y)$').firstMatch(iso);
  if (match == null) return null;
  final days = match.group(1);
  final weeks = match.group(2);
  final months = match.group(3);
  final years = match.group(4);
  if (years != null) return (int.parse(years), 'year');
  if (months != null) return (int.parse(months), 'month');
  if (weeks != null) return (int.parse(weeks), 'week');
  if (days != null) return (int.parse(days), 'day');
  return null;
}

String _countAndUnit(int count, String unit) => count <= 0
    ? ''
    : count == 1
    ? '1 $unit'
    : '$count ${unit}s';

String _periodFromIos(int count, SKSubscriptionPeriodUnit unit) =>
    _countAndUnit(count, switch (unit) {
      SKSubscriptionPeriodUnit.day => 'day',
      SKSubscriptionPeriodUnit.week => 'week',
      SKSubscriptionPeriodUnit.month => 'month',
      SKSubscriptionPeriodUnit.year => 'year',
    });

String _adjectiveFromIos(SKSubscriptionPeriodUnit unit) => switch (unit) {
  SKSubscriptionPeriodUnit.day => 'daily',
  SKSubscriptionPeriodUnit.week => 'weekly',
  SKSubscriptionPeriodUnit.month => 'monthly',
  SKSubscriptionPeriodUnit.year => 'yearly',
};
