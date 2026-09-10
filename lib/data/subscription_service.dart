import 'dart:async';

import 'package:in_app_purchase/in_app_purchase.dart';

import 'backend.dart';
import '../features/parent/domain/parent_subscription_repository.dart';

class StoreSubscriptionRepository implements ParentSubscriptionRepository {
  StoreSubscriptionRepository({InAppPurchase? store})
    : _store = store ?? InAppPurchase.instance;

  static const insightsMonthlyProduct = 'studafy_parent_insights_monthly';
  final InAppPurchase _store;
  StreamSubscription<List<PurchaseDetails>>? _purchaseListener;

  Future<void> initialize() async {
    _purchaseListener ??= _store.purchaseStream.listen(_handlePurchases);
  }

  Future<void> dispose() async => _purchaseListener?.cancel();

  @override
  Future<SubscriptionEntitlement> entitlement() async {
    if (!StudafyBackend.isRemote) {
      return const SubscriptionEntitlement(active: false, source: 'preview');
    }
    final user = StudafyBackend.client.auth.currentUser;
    if (user == null) {
      return const SubscriptionEntitlement(active: false, source: 'none');
    }
    final row = await StudafyBackend.client
        .from('subscription_entitlements')
        .select('active, source, expires_at')
        .eq('user_id', user.id)
        .maybeSingle();
    if (row == null) {
      return const SubscriptionEntitlement(active: false, source: 'none');
    }
    final expires = row['expires_at'] == null
        ? null
        : DateTime.parse(row['expires_at'] as String);
    final active = row['active'] as bool? ?? false;
    return SubscriptionEntitlement(
      active: active && (expires == null || expires.isAfter(DateTime.now())),
      source: row['source'] as String? ?? 'unknown',
      expiresAt: expires,
    );
  }

  @override
  Future<void> purchaseInsightsMonthly() async {
    await initialize();
    if (!await _store.isAvailable()) throw StateError('Store is unavailable');
    final response = await _store.queryProductDetails({insightsMonthlyProduct});
    if (response.error != null) throw StateError(response.error!.message);
    if (response.productDetails.isEmpty) {
      throw StateError('Insights+ is not available in this store region');
    }
    final started = await _store.buyNonConsumable(
      purchaseParam: PurchaseParam(
        productDetails: response.productDetails.single,
      ),
    );
    if (!started) throw StateError('The store did not start the purchase');
  }

  @override
  Future<void> restorePurchases() async {
    await initialize();
    await _store.restorePurchases();
  }

  Future<void> _handlePurchases(List<PurchaseDetails> purchases) async {
    for (final purchase in purchases) {
      if (purchase.productID != insightsMonthlyProduct) continue;
      if (purchase.status == PurchaseStatus.purchased ||
          purchase.status == PurchaseStatus.restored) {
        try {
          if (!StudafyBackend.isRemote) {
            throw StateError('Server verification is unavailable');
          }
          final response = await StudafyBackend.client.functions.invoke(
            'verify-store-purchase',
            body: {
              'product_id': purchase.productID,
              'purchase_id': purchase.purchaseID,
              'verification_data':
                  purchase.verificationData.serverVerificationData,
              'verification_source': purchase.verificationData.source,
            },
          );
          if (response.status < 200 || response.status >= 300) {
            throw StateError('Purchase verification failed');
          }
          if (purchase.pendingCompletePurchase) {
            await _store.completePurchase(purchase);
          }
        } catch (_) {
          // Do not grant access or complete a purchase the server has not
          // verified. The store stream will retry after reconnect/relaunch.
        }
      }
    }
  }
}
