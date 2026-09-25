import 'package:flutter/foundation.dart';

@immutable
class NotebookSubscription {
  const NotebookSubscription({
    this.active = false,
    this.expiresAt,
    this.price = '',
    this.currency = '',
    this.monthly = false,
    this.oneMonthTrial = false,
    this.storeAvailable = false,
    this.selfPurchaseEnabled = false,
    this.approval = 'none',
  });

  final bool active;
  final DateTime? expiresAt;
  final String price;
  final String currency;
  final bool monthly;
  final bool oneMonthTrial;
  final bool storeAvailable;
  final bool selfPurchaseEnabled;
  final String approval;
  bool get canPurchase =>
      !active &&
      storeAvailable &&
      monthly &&
      price.isNotEmpty &&
      currency.isNotEmpty &&
      selfPurchaseEnabled &&
      approval == 'approved';
}

abstract interface class NotebookSubscriptionRepository {
  Future<NotebookSubscription> notebookStatus();
  Future<void> requestNotebookApproval();
  Future<void> purchaseNotebook();
  Future<void> restorePurchases();
  void addEntitlementListener(VoidCallback listener);
  void removeEntitlementListener(VoidCallback listener);
}
