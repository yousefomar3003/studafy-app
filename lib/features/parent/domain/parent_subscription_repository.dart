import 'package:flutter/foundation.dart';

/// A store-stitched offer for the paywall. Prices and trial length come from
/// the store's product query (Apple 3.1.2: tiers vary per storefront, never
/// hardcode) against the store product id the server catalogue returns; the
/// feature key and store product id come from the server.
@immutable
class PaywallOffer {
  const PaywallOffer({
    required this.featureKey,
    required this.storeProductId,
    this.storeAvailable = false,
    this.price = '',
    this.currencyCode = '',
    this.periodLabel = '',
    this.hasTrial = false,
    this.trialLengthLabel = '',
  });

  final String featureKey;
  final String storeProductId;

  /// False when the store product query failed or returned nothing: the
  /// paywall must still render (restore/cancel disclosures) but cannot show a
  /// price it has not verified with the store.
  final bool storeAvailable;

  /// Never offer checkout before the store has supplied complete terms.
  bool get canPurchase =>
      storeAvailable &&
      storeProductId.trim().isNotEmpty &&
      price.trim().isNotEmpty &&
      currencyCode.trim().isNotEmpty &&
      periodLabel.trim().isNotEmpty;
  final String price;
  final String currencyCode;

  /// Billing period noun for "X / `<period>`" copy: "month", "3 months".
  final String periodLabel;
  final bool hasTrial;

  /// Duration of the free trial ("30 days"), empty when the store lists none.
  final String trialLengthLabel;
}

/// Emitted after a purchase/restore completes store-side and the server has
/// verified it, so a screen can re-read its entitlement without polling.
typedef EntitlementChanged = void Function();

abstract interface class ParentSubscriptionRepository {
  /// Parent Insights access for one linked child. Null reads the caller's
  /// own entitlement, which a guardian never holds for this product.
  Future<SubscriptionEntitlement> entitlement({String? beneficiaryStudentId});

  /// The store product id + verified price disclosure for the paywall.
  Future<PaywallOffer> insightsOffer();

  /// Starts the store purchase for one linked child. The entitlement is
  /// attached to that child, never to the purchasing guardian (ADR-0009).
  Future<void> purchaseInsightsMonthly({required String beneficiaryStudentId});

  Future<void> restorePurchases();

  /// Registers a callback fired when a purchase completes and is verified.
  void addEntitlementListener(EntitlementChanged listener);

  void removeEntitlementListener(EntitlementChanged listener);
}

@immutable
class SubscriptionEntitlement {
  const SubscriptionEntitlement({
    required this.active,
    required this.source,
    this.expiresAt,
  });

  final bool active;
  final String source;
  final DateTime? expiresAt;
}
