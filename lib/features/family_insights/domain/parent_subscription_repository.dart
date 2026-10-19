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

/// The two Family+ plans. Both are the parent's own subscription and cover
/// their linked children, earliest linked first, up to [seats].
enum FamilyPlusPlan {
  upTo4(featureKey: 'family_plus', seats: 4, usPrice: r'US$2.99'),
  upTo8(featureKey: 'family_plus_large', seats: 8, usPrice: r'US$4.99');

  const FamilyPlusPlan({
    required this.featureKey,
    required this.seats,
    required this.usPrice,
  });

  /// The server's feature key for this plan.
  final String featureKey;
  final int seats;

  /// Shown only until the store has confirmed the price where the parent
  /// lives; the store's own price always wins.
  final String usPrice;

  static FamilyPlusPlan? fromFeatureKey(String key) {
    for (final plan in values) {
      if (plan.featureKey == key) return plan;
    }
    return null;
  }
}

/// The parent's Family+ plan, as the server sees it now.
@immutable
class FamilyPlusStatus {
  const FamilyPlusStatus({
    this.plan,
    this.coveredStudentIds = const [],
    this.endsAt,
    this.paidByMe = true,
    this.granted = false,
  });

  static const none = FamilyPlusStatus();

  /// Null without a live plan.
  final FamilyPlusPlan? plan;

  /// The linked children the plan covers now, decided by the server.
  final List<String> coveredStudentIds;
  final DateTime? endsAt;
  final bool paidByMe;

  /// Given by Studafy without a purchase. There is no store subscription
  /// behind it, so nothing to manage or cancel in the store.
  final bool granted;

  bool covers(String studentId) => coveredStudentIds.contains(studentId);
}

abstract interface class ParentSubscriptionRepository {
  /// Whether this linked child's Family+ insights are unlocked: covered by
  /// the parent's family plan, or by a per-child subscription bought before
  /// Family+ became a family plan.
  Future<SubscriptionEntitlement> entitlement({String? beneficiaryStudentId});

  /// The parent's own family plan and the children it covers.
  Future<FamilyPlusStatus> familyPlan();

  /// The store product id and store-confirmed price of one plan.
  Future<PaywallOffer> familyOffer(FamilyPlusPlan plan);

  /// Starts the store purchase of a family plan, held by the parent. Moving
  /// from 4 to 8 upgrades the same subscription; it never adds a second.
  Future<void> purchaseFamilyPlan(FamilyPlusPlan plan);

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
