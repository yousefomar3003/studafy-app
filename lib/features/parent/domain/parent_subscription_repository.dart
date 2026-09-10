import 'package:flutter/foundation.dart';

abstract interface class ParentSubscriptionRepository {
  Future<SubscriptionEntitlement> entitlement();

  Future<void> purchaseInsightsMonthly();

  Future<void> restorePurchases();
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
