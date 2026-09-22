import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:in_app_purchase/in_app_purchase.dart';

import '../core/secure_storage.dart';
import '../features/parent/domain/parent_subscription_repository.dart';
import 'billing/store_offer_details.dart';
import 'billing/v1_billing_api.dart';
import 'contracts/v1_http_transport.dart';

class StoreSubscriptionRepository implements ParentSubscriptionRepository {
  StoreSubscriptionRepository({
    InAppPurchase? store,
    V1BillingApi? billingApi,
    SecureStore? pendingStore,
  }) : _store = store ?? InAppPurchase.instance,
       // ignore: prefer_initializing_formals
       _billingApi = billingApi,
       _pending = pendingStore ?? InMemorySecureStore();

  final InAppPurchase _store;
  final V1BillingApi? _billingApi;

  /// Remembers which linked child a started purchase is for, keyed by store
  /// product id. It must survive an app kill between the store sheet and
  /// server verification: the store stream replays the purchase on the next
  /// launch, and without the beneficiary the server would refuse it, leaving
  /// Google to auto-refund an unacknowledged purchase after three days. It
  /// is cleared on sign-out with the rest of the secure store, which is also
  /// correct: a different account's token could never verify it.
  final SecureStore _pending;
  String? _accountToken;

  static String _pendingKey(String storeProductId) =>
      'pay071.pending_beneficiary.$storeProductId';

  StreamSubscription<List<PurchaseDetails>>? _purchaseListener;

  final List<EntitlementChanged> _entitlementListeners = [];

  V1BillingProduct? _insightsProduct;
  bool _catalogueLoaded = false;
  List<V1BillingProduct> _catalogueProducts = const [];

  bool get _isRemote => _billingApi != null;

  @override
  void addEntitlementListener(EntitlementChanged listener) {
    _entitlementListeners.add(listener);
  }

  @override
  void removeEntitlementListener(EntitlementChanged listener) {
    _entitlementListeners.remove(listener);
  }

  Future<void> initialize() async {
    _purchaseListener ??= _store.purchaseStream.listen(_handlePurchases);
  }

  Future<void> dispose() async {
    await _purchaseListener?.cancel();
    _purchaseListener = null;
  }

  String get _platformName => switch (defaultTargetPlatform) {
    TargetPlatform.iOS => 'app_store',
    TargetPlatform.android => 'play_store',
    _ => throw UnsupportedError(
      'Subscriptions require the native mobile store',
    ),
  };

  /// Resolves this platform's product rows from the server catalogue (lazy,
  /// once). Store product ids and availability are server-authoritative; the
  /// store product query later supplies price/trial for display only.
  Future<List<V1BillingProduct>> _products() async {
    if (_catalogueLoaded) {
      return _catalogueProducts;
    }
    if (!_isRemote) return <V1BillingProduct>[];
    try {
      final catalogue = await _billingApi!.catalogue();
      _accountToken = catalogue.purchaseAccountToken;
      final products = catalogue.products
          .where((product) => product.platform == _platformName)
          .toList();
      final matched = products.indexWhere(
        (product) => product.featureKey == 'parent_insights',
      );
      _insightsProduct = matched < 0 ? null : products[matched];
      _catalogueProducts = List.unmodifiable(products);
      _catalogueLoaded = true;
      return products;
    } catch (_) {
      rethrow;
    }
  }

  Future<V1BillingProduct> _insightsProductOrThrow() async {
    await _products();
    final insights = _insightsProduct;
    if (insights == null) {
      // PAY-071 §29: Parent Insights is not sold until legal sign-off and is
      // absent from every non-synthetic catalogue.
      throw StateError('Insights+ is not available in this environment');
    }
    return insights;
  }

  @override
  Future<SubscriptionEntitlement> entitlement({
    String? beneficiaryStudentId,
  }) async {
    if (!_isRemote) {
      return const SubscriptionEntitlement(active: false, source: 'preview');
    }
    try {
      final rows = await _billingApi!.entitlements();
      for (final row in rows) {
        // Parent Insights is held by the child; a guardian reads it through
        // the child's student id, never as their own entitlement.
        if (row.featureKey == 'parent_insights' &&
            row.beneficiaryStudentId == beneficiaryStudentId) {
          return SubscriptionEntitlement(
            active:
                row.grantsAccess &&
                (row.endsAt == null || row.endsAt!.isAfter(DateTime.now())),
            source: row.status,
            expiresAt: row.endsAt,
          );
        }
      }
      return const SubscriptionEntitlement(active: false, source: 'none');
    } catch (error) {
      if (error is V1ApiException && error.isUnauthenticated) rethrow;
      return const SubscriptionEntitlement(
        active: false,
        source: 'unavailable',
      );
    }
  }

  @override
  Future<PaywallOffer> insightsOffer() async {
    final fallback = PaywallOffer(
      featureKey: 'parent_insights',
      storeProductId: _insightsProduct?.storeProductId ?? '',
    );
    if (!_isRemote) return fallback;
    final V1BillingProduct product;
    try {
      product = await _insightsProductOrThrow();
    } catch (_) {
      return fallback;
    }
    final response = await _store.queryProductDetails({product.storeProductId});
    if (response.error != null || response.productDetails.isEmpty) {
      return fallback;
    }
    final terms = resolveStoreOfferTerms(response.productDetails.first);
    return PaywallOffer(
      featureKey: 'parent_insights',
      storeProductId: product.storeProductId,
      storeAvailable: true,
      price: terms.price,
      currencyCode: terms.currencyCode,
      periodLabel: terms.periodNoun,
      hasTrial: terms.hasTrial,
      trialLengthLabel: terms.trialLength,
    );
  }

  @override
  Future<void> purchaseInsightsMonthly({
    required String beneficiaryStudentId,
  }) async {
    await initialize();
    if (!_isRemote) throw StateError('Billing is unavailable in preview');
    if (beneficiaryStudentId.isEmpty) {
      throw StateError('Choose the child this subscription is for');
    }
    final product = await _insightsProductOrThrow();
    final accountToken = _accountToken;
    if (accountToken == null) {
      throw StateError('Billing is unavailable right now');
    }
    if (!await _store.isAvailable()) {
      throw StateError('Store is unavailable');
    }
    final response = await _store.queryProductDetails({product.storeProductId});
    if (response.error != null) throw StateError(response.error!.message);
    if (response.productDetails.isEmpty) {
      throw StateError('Insights+ is not available in this store region');
    }
    final terms = resolveStoreOfferTerms(response.productDetails.first);
    if (terms.price.trim().isEmpty ||
        terms.currencyCode.trim().isEmpty ||
        terms.periodLength.trim().isEmpty) {
      throw StateError('Subscription terms are unavailable in this store');
    }
    await _pending.write(
      _pendingKey(product.storeProductId),
      beneficiaryStudentId,
    );
    final started = await _store.buyNonConsumable(
      purchaseParam: PurchaseParam(
        productDetails: response.productDetails.first,
        applicationUserName: accountToken,
      ),
    );
    if (!started) {
      await _pending.delete(_pendingKey(product.storeProductId));
      throw StateError('The store did not start the purchase');
    }
  }

  @override
  Future<void> restorePurchases() async {
    await initialize();
    if (!_isRemote) return;
    await _products();
    await _store.restorePurchases(applicationUserName: _accountToken);
  }

  Future<void> _handlePurchases(List<PurchaseDetails> purchases) async {
    if (!_isRemote) return;
    for (final purchase in purchases) {
      switch (purchase.status) {
        case PurchaseStatus.purchased:
        case PurchaseStatus.restored:
          await _verifyAndComplete(
            purchase,
            restored: purchase.status == PurchaseStatus.restored,
          );
        case PurchaseStatus.pending:
          // Store is confirming payment; the stream re-emits the outcome.
          continue;
        case PurchaseStatus.error:
        case PurchaseStatus.canceled:
          // Release an abandoned/failed payment; nothing was charged and the
          // server is never told about an unverified purchase (§13).
          await _pending.delete(_pendingKey(purchase.productID));
          if (purchase.pendingCompletePurchase) {
            await _store.completePurchase(purchase);
          }
      }
    }
  }

  Future<void> _verifyAndComplete(
    PurchaseDetails purchase, {
    required bool restored,
  }) async {
    // Only the store-signed blob may reach the server; local/simulator
    // verification data is dropped so no local transaction is ever recorded.
    final verificationPayload =
        purchase.verificationData.serverVerificationData;
    if (verificationPayload.isEmpty ||
        purchase.verificationData.source.isEmpty) {
      return;
    }
    try {
      final products = await _products();
      final matched = products.indexWhere(
        (row) => row.storeProductId == purchase.productID,
      );
      final product = matched < 0 ? null : products[matched];
      if (product == null) return;
      // Deterministic idempotency key: a replayed stream event collapses onto
      // the server's completed idempotency reservation instead of submitting
      // the same store receipt twice.
      final idempotencyKey =
          'pay071:${purchase.purchaseID ?? product.storeProductId}';
      if (restored) {
        await _billingApi!.restorePurchase(
          platform: product.platform,
          storeProductId: product.storeProductId,
          featureKey: product.featureKey,
          verificationPayload: verificationPayload,
          idempotencyKey: idempotencyKey,
        );
      } else {
        await _billingApi!.submitPurchase(
          platform: product.platform,
          storeProductId: product.storeProductId,
          featureKey: product.featureKey,
          verificationPayload: verificationPayload,
          beneficiaryStudentId: await _pending.read(
            _pendingKey(product.storeProductId),
          ),
          idempotencyKey: idempotencyKey,
        );
        await _pending.delete(_pendingKey(product.storeProductId));
      }
    } catch (_) {
      // Do not complete or grant access to a purchase the server has not
      // verified. The store stream retries after reconnect/relaunch.
      return;
    }
    if (purchase.pendingCompletePurchase) {
      await _store.completePurchase(purchase);
    }
    for (final listener in List.of(_entitlementListeners)) {
      listener();
    }
  }
}
