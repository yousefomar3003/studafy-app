import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:in_app_purchase/in_app_purchase.dart';
import 'package:in_app_purchase_android/billing_client_wrappers.dart'
    show ReplacementMode;
import 'package:in_app_purchase_android/in_app_purchase_android.dart';
import 'package:in_app_purchase_storekit/in_app_purchase_storekit.dart';
import 'package:in_app_purchase_storekit/store_kit_2_wrappers.dart';
import 'package:in_app_purchase_storekit/store_kit_wrappers.dart';

import '../../core/secure_storage.dart';
import '../../features/family_insights/domain/parent_subscription_repository.dart';
import '../../features/study/domain/study.dart';
import '../contracts/v1_client.generated.dart';
import '../contracts/v1_http_transport.dart';
import 'store_offer_details.dart';
import 'v1_billing_api.dart';

class StoreSubscriptionRepository
    implements ParentSubscriptionRepository, StudyPlanSubscriptionRepository {
  StoreSubscriptionRepository({
    InAppPurchase? store,
    V1BillingApi? billingApi,
    SecureStore? pendingStore,
    Future<QueryPurchaseDetailsResponse> Function(String account)?
    playPurchases,
    Future<V1MyGuardianLinksResponseDto> Function()? guardianLinks,
  }) : _injectedStore = store,
       // ignore: prefer_initializing_formals
       _billingApi = billingApi,
       _pending = pendingStore ?? InMemorySecureStore(),
       // ignore: prefer_initializing_formals
       _playPurchases = playPurchases,
       // ignore: prefer_initializing_formals
       _guardianLinks = guardianLinks;

  final InAppPurchase? _injectedStore;

  /// The store, reached only when billing is used: asking for
  /// `InAppPurchase.instance` opens a Google Play Billing connection, which
  /// someone who never buys (every teacher) has no reason to open.
  late final InAppPurchase _store = _injectedStore ?? InAppPurchase.instance;
  final V1BillingApi? _billingApi;

  /// The subscriptions this phone's Google account bought. Tests supply
  /// their own; the default asks Google Play.
  final Future<QueryPurchaseDetailsResponse> Function(String account)?
  _playPurchases;

  /// The parent's own guardian links, which also carry the server's Family+
  /// answer: which children are unlocked and the parent's family plan,
  /// bought or given. Unlike `/v1/billing/*` this read is served whether or
  /// not store billing is, so a plan given without a purchase shows on a
  /// server with billing off. Null in builds without a backend.
  final Future<V1MyGuardianLinksResponseDto> Function()? _guardianLinks;

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

  /// The server catalogue's product for each Family+ plan on this store.
  final Map<FamilyPlusPlan, V1BillingProduct> _familyProducts = {};

  /// The store offer each plan's purchase will use, and the billing account
  /// it was read for: a purchase must never bind to a different account than
  /// the one whose offer was shown.
  final Map<StudyPlanTier, ProductDetails> _planSelection = {};
  final Map<StudyPlanTier, String> _planSelectionAccount = {};

  bool get _isRemote => _billingApi != null;

  @override
  SubscriptionStore? get purchaseStore {
    if (kIsWeb) return null;
    return switch (defaultTargetPlatform) {
      TargetPlatform.iOS => SubscriptionStore.appStore,
      TargetPlatform.android => SubscriptionStore.playStore,
      _ => null,
    };
  }

  /// Called when an account signs in on this device (and after a switch).
  ///
  /// Listens to the store at once, so a purchase the store finished while
  /// the app was closed - or on the way to a new phone - is verified now,
  /// not when the Plans screen is next opened. On Android it also asks
  /// Google Play, silently, for this Google account's subscriptions, which
  /// the server attaches only to the Studafy account that bought them. The
  /// App Store's restore can ask for an Apple password, so on iPhone that
  /// stays behind the Restore purchases button.
  Future<void> resumeForAccount() async {
    if (!_isRemote || purchaseStore == null) return;
    await initialize();
    if (purchaseStore != SubscriptionStore.playStore) return;
    try {
      await _products();
      if (!await _store.isAvailable()) return;
      await _store.restorePurchases(applicationUserName: _accountToken);
    } on Object {
      // Offline or no Play Store: the next sign-in or Restore tries again.
    }
  }

  @override
  Future<StudyPlanSubscription?> subscription() async {
    if (!_isRemote) return null;
    return currentStudyPlanSubscription(
      await _billingApi!.entitlements(),
      DateTime.now(),
    );
  }

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

  /// Resolves this platform's current server catalogue. Product ids and
  /// availability are server-authoritative; the
  /// store product query later supplies price/trial for display only.
  Future<List<V1BillingProduct>> _products() async {
    if (!_isRemote) return <V1BillingProduct>[];
    try {
      final catalogue = await _billingApi!.catalogue();
      _accountToken = catalogue.purchaseAccountToken;
      final products = catalogue.products
          .where((product) => product.platform == _platformName)
          .toList();
      _familyProducts.clear();
      for (final product in products) {
        final plan = FamilyPlusPlan.fromFeatureKey(product.featureKey);
        if (plan != null) _familyProducts[plan] = product;
      }
      return products;
    } catch (_) {
      rethrow;
    }
  }

  @override
  Future<StudyPlanOffer> offer(StudyPlanTier tier) async {
    final featureKey = tier.featureKey;
    if (!_isRemote || featureKey == null) return StudyPlanOffer(tier: tier);
    await initialize();
    // Refresh authority on every read: a cached catalogue must never bind a
    // purchase to the account which used the device before this student.
    final catalogue = await _billingApi!.catalogue();
    final rows = await _billingApi.entitlements();
    final now = DateTime.now();
    final active = rows.where(
      (row) =>
          row.featureKey == featureKey &&
          row.beneficiaryStudentId == null &&
          row.grantsAccess &&
          !row.startsAt.isAfter(now) &&
          row.endsAt != null &&
          row.endsAt!.isAfter(now),
    );
    if (active.isNotEmpty) {
      return StudyPlanOffer(tier: tier, active: true);
    }
    final enabled = _selfPurchaseAllowed(catalogue);
    _planSelection.remove(tier);
    _planSelectionAccount.remove(tier);
    StoreOfferTerms terms = StoreOfferTerms.none;
    var eligibleTrial = false;
    try {
      final products = catalogue.products.where(
        (row) => row.featureKey == featureKey && row.platform == _platformName,
      );
      if (products.length == 1 && await _store.isAvailable()) {
        final result = await _store.queryProductDetails({
          products.single.storeProductId,
        });
        if (result.error == null) {
          final candidates = result.productDetails
              .where(
                (p) =>
                    p.id == products.single.storeProductId &&
                    resolveStoreOfferTerms(p).periodLength == '1 month',
              )
              .toList();
          // Google only returns offers available to this store account. Prefer
          // the configured one-month trial, and keep its exact offer token.
          candidates.sort(
            (a, b) =>
                (resolveStoreOfferTerms(b).trialLength == '1 month' ? 1 : 0)
                    .compareTo(
                      resolveStoreOfferTerms(a).trialLength == '1 month'
                          ? 1
                          : 0,
                    ),
          );
          if (candidates.isNotEmpty) {
            final selected = candidates.first;
            terms = resolveStoreOfferTerms(selected);
            eligibleTrial = terms.hasTrial && terms.trialLength == '1 month';
            if (defaultTargetPlatform == TargetPlatform.iOS) {
              // The plugin's StoreKit 2 model omits introductory terms. Read
              // the same SKU's StoreKit metadata, then check eligibility in SK2.
              final metadata = await SKRequestMaker().startProductRequest([
                selected.id,
              ]);
              final matching = metadata.products.where(
                (p) => p.productIdentifier == selected.id,
              );
              eligibleTrial = false;
              if (matching.length == 1) {
                final intro = resolveStoreOfferTerms(
                  AppStoreProductDetails.fromSKProduct(matching.single),
                );
                eligibleTrial =
                    intro.hasTrial &&
                    intro.trialLength == '1 month' &&
                    await SK2Product.isIntroductoryOfferEligible(selected.id);
              }
            }
            _planSelection[tier] = selected;
            _planSelectionAccount[tier] = catalogue.purchaseAccountToken;
          }
        }
      }
    } catch (_) {
      // Store outages never hide restore or consent, and never invent terms.
      _planSelection.remove(tier);
    }
    return StudyPlanOffer(
      tier: tier,
      price: terms.price,
      monthly: terms.periodLength == '1 month',
      oneMonthTrial: eligibleTrial,
      storeAvailable: _planSelection[tier] != null,
      selfPurchaseEnabled: enabled,
    );
  }

  /// The server's per-school switch, on unless a school opted out. A
  /// student buys their own plan: there is no approval step in Studafy
  /// (DL-071). The store account on the phone pays, and for a child the
  /// store's own family controls (Family Link, Ask to Buy) apply.
  static bool _selfPurchaseAllowed(V1BillingCatalogue catalogue) =>
      catalogue.selfPurchase.isNotEmpty &&
      catalogue.selfPurchase.every((row) => row.selfPurchaseEnabled);

  @override
  Future<void> purchase(StudyPlanTier tier) async {
    final featureKey = tier.featureKey;
    final selected = _planSelection[tier];
    final account = _planSelectionAccount[tier];
    if (!_isRemote ||
        featureKey == null ||
        selected == null ||
        account == null) {
      throw StateError('Reload the subscription offer');
    }
    // Recheck account and availability immediately before the store sheet,
    // without silently substituting a different price or offer.
    final catalogue = await _billingApi!.catalogue();
    if (catalogue.purchaseAccountToken != account ||
        !_selfPurchaseAllowed(catalogue) ||
        !catalogue.products.any(
          (row) =>
              row.featureKey == featureKey &&
              row.platform == _platformName &&
              row.storeProductId == selected.id,
        )) {
      throw StateError('This plan is no longer available to buy');
    }
    final terms = resolveStoreOfferTerms(selected);
    if (terms.periodLength != '1 month' ||
        terms.price.isEmpty ||
        terms.currencyCode.isEmpty) {
      throw StateError('Subscription terms are unavailable');
    }
    // Never a second subscription beside the first, and never a second
    // charge: the current plan is upgraded in place or the purchase stops.
    final current = currentStudyPlanSubscription(
      await _billingApi.entitlements(),
      DateTime.now(),
    );
    ChangeSubscriptionParam? replacing;
    if (current != null) {
      if (current.tier.includes(tier)) {
        throw const PurchaseBlockedException(PurchaseBlock.alreadySubscribed);
      }
      if (!current.paidByMe) {
        throw const PurchaseBlockedException(PurchaseBlock.paidByParent);
      }
      if (current.store != purchaseStore) {
        throw const PurchaseBlockedException(PurchaseBlock.otherStore);
      }
      // The App Store upgrades within the subscription group both plans
      // belong to and credits the unused part; Google Play needs the
      // subscription being replaced named.
      if (selected is GooglePlayProductDetails) {
        replacing = await _replacing(current.storeProductId, account);
      }
    }
    await initialize();
    final PurchaseParam param;
    if (selected is GooglePlayProductDetails) {
      final index = selected.subscriptionIndex!;
      param = GooglePlayPurchaseParam(
        productDetails: selected,
        applicationUserName: account,
        offerToken: selected
            .productDetails
            .subscriptionOfferDetails![index]
            .offerIdToken,
        changeSubscriptionParam: replacing,
      );
    } else {
      param = PurchaseParam(
        productDetails: selected,
        applicationUserName: account,
      );
    }
    if (!await _store.buyNonConsumable(purchaseParam: param)) {
      throw StateError('The store did not start the purchase');
    }
  }

  /// The Google Play subscription an upgrade replaces. Only the Google
  /// account that bought it can replace it, so it must be on this phone.
  /// The switch happens at once and Google charges only the difference for
  /// the rest of the current period.
  Future<ChangeSubscriptionParam> _replacing(
    String? storeProductId,
    String account,
  ) async {
    const blocked = PurchaseBlockedException(
      PurchaseBlock.upgradeNeedsOriginalAccount,
    );
    final QueryPurchaseDetailsResponse past;
    try {
      past =
          await (_playPurchases?.call(account) ??
              _store
                  .getPlatformAddition<InAppPurchaseAndroidPlatformAddition>()
                  .queryPastPurchases(applicationUserName: account));
    } on Object {
      throw blocked;
    }
    final owned = past.pastPurchases.where(
      (purchase) =>
          purchase.productID == storeProductId &&
          purchase.status != PurchaseStatus.error,
    );
    if (past.error != null || owned.isEmpty) throw blocked;
    return ChangeSubscriptionParam(
      oldPurchaseDetails: owned.first,
      replacementMode: ReplacementMode.chargeProratedPrice,
    );
  }

  Future<V1BillingProduct> _familyProductOrThrow(FamilyPlusPlan plan) async {
    await _products();
    final product = _familyProducts[plan];
    if (product == null) {
      throw StateError('Family+ is not on sale in this environment');
    }
    return product;
  }

  /// The server's Family+ answer from the parent's guardian links, or null
  /// when it cannot say: no backend, a server older than 2026-10-19 (its
  /// links carry no `familyPlus`), or the read failed. The billing read is
  /// then asked instead.
  Future<({FamilyPlusStatus status, Set<String> unlocked})?>
  _familyAccess() async {
    final read = _guardianLinks;
    if (read == null) return null;
    final V1MyGuardianLinksResponseDto response;
    try {
      response = await read();
    } catch (error) {
      if (error is V1ApiException && error.isUnauthenticated) rethrow;
      return null;
    }
    if (response.items.isNotEmpty &&
        response.items.every((link) => link.familyPlus == null)) {
      return null;
    }
    final unlocked = {
      for (final link in response.items)
        if (link.familyPlus == true) link.studentId,
    };
    final held = response.familyPlan;
    final plan = held == null
        ? null
        : FamilyPlusPlan.fromFeatureKey(held.featureKey);
    if (held == null || plan == null) {
      return (status: FamilyPlusStatus.none, unlocked: unlocked);
    }
    final endsAt = held.endsAt == null ? null : DateTime.parse(held.endsAt!);
    return (
      status: FamilyPlusStatus(
        plan: plan,
        coveredStudentIds: held.coveredStudentIds,
        endsAt: endsAt,
        paidByMe: !held.granted,
        granted: held.granted,
      ),
      unlocked: unlocked,
    );
  }

  /// The parent's live Family+ plan rows, largest plan first.
  static List<(FamilyPlusPlan, V1EntitlementRow)> _livePlans(
    List<V1EntitlementRow> rows,
    DateTime now,
  ) {
    final live = <(FamilyPlusPlan, V1EntitlementRow)>[];
    for (final row in rows) {
      final plan = FamilyPlusPlan.fromFeatureKey(row.featureKey);
      if (plan == null || row.beneficiaryStudentId != null) continue;
      if (!row.grantsAccess) continue;
      if (row.endsAt != null && !row.endsAt!.isAfter(now)) continue;
      live.add((plan, row));
    }
    live.sort((a, b) => b.$1.seats.compareTo(a.$1.seats));
    return live;
  }

  @override
  Future<SubscriptionEntitlement> entitlement({
    String? beneficiaryStudentId,
  }) async {
    // The same check the insights read makes, so the tab never opens for a
    // child the server would refuse, nor stays shut for one it would serve.
    final access = await _familyAccess();
    if (access != null) {
      final active =
          beneficiaryStudentId != null &&
          access.unlocked.contains(beneficiaryStudentId);
      return SubscriptionEntitlement(
        active: active,
        source: !active
            ? 'none'
            : access.status.granted
            ? 'granted'
            : 'active',
        expiresAt: active ? access.status.endsAt : null,
      );
    }
    if (!_isRemote) {
      return const SubscriptionEntitlement(active: false, source: 'preview');
    }
    try {
      final rows = await _billingApi!.entitlements();
      final now = DateTime.now();
      // The parent's family plan, when it covers this child. The server
      // decides which children are covered; the app never counts seats.
      for (final (_, row) in _livePlans(rows, now)) {
        if (beneficiaryStudentId != null &&
            row.coveredStudentIds.contains(beneficiaryStudentId)) {
          return SubscriptionEntitlement(
            active: true,
            source: row.status,
            expiresAt: row.endsAt,
          );
        }
      }
      for (final row in rows) {
        // A per-child Family+ bought before the family plans is held by the
        // child; a guardian reads it through the child's student id.
        if (row.featureKey == 'parent_insights' &&
            row.beneficiaryStudentId == beneficiaryStudentId &&
            beneficiaryStudentId != null) {
          return SubscriptionEntitlement(
            active:
                row.grantsAccess &&
                (row.endsAt == null || row.endsAt!.isAfter(now)),
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
  Future<FamilyPlusStatus> familyPlan() async {
    final access = await _familyAccess();
    if (access != null) return access.status;
    if (!_isRemote) return FamilyPlusStatus.none;
    final live = _livePlans(await _billingApi!.entitlements(), DateTime.now());
    if (live.isEmpty) return FamilyPlusStatus.none;
    // At the same size a bought plan is shown before a given one, so the
    // parent can still manage the subscription they pay for.
    final (plan, row) = live.firstWhere(
      (entry) => entry.$1 == live.first.$1 && !entry.$2.granted,
      orElse: () => live.first,
    );
    return FamilyPlusStatus(
      plan: plan,
      coveredStudentIds: row.coveredStudentIds,
      endsAt: row.endsAt,
      paidByMe: row.purchasedByMe,
      granted: row.granted,
    );
  }

  @override
  Future<PaywallOffer> familyOffer(FamilyPlusPlan plan) async {
    final fallback = PaywallOffer(
      featureKey: plan.featureKey,
      storeProductId: _familyProducts[plan]?.storeProductId ?? '',
    );
    if (!_isRemote) return fallback;
    final V1BillingProduct product;
    try {
      product = await _familyProductOrThrow(plan);
    } catch (_) {
      return fallback;
    }
    final response = await _store.queryProductDetails({product.storeProductId});
    if (response.error != null || response.productDetails.isEmpty) {
      return fallback;
    }
    final terms = resolveStoreOfferTerms(response.productDetails.first);
    return PaywallOffer(
      featureKey: plan.featureKey,
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
  Future<void> purchaseFamilyPlan(FamilyPlusPlan plan) async {
    await initialize();
    if (!_isRemote) throw StateError('Billing is unavailable in preview');
    final product = await _familyProductOrThrow(plan);
    final accountToken = _accountToken;
    if (accountToken == null) {
      throw StateError('Billing is unavailable right now');
    }
    // Never a second family plan beside the first: the current one is
    // upgraded in place, and the same or a smaller plan is not sold again.
    // A plan Studafy gave has no store subscription to upgrade, so a larger
    // plan bought over it is a new subscription, not a replacement.
    final live = _livePlans(await _billingApi!.entitlements(), DateTime.now());
    if (live.isNotEmpty && live.first.$1.seats >= plan.seats) {
      throw const PurchaseBlockedException(PurchaseBlock.alreadySubscribed);
    }
    final current = live.where((entry) => !entry.$2.granted).firstOrNull;
    if (current != null &&
        current.$2.platform != null &&
        SubscriptionStore.parse(current.$2.platform) != purchaseStore) {
      throw const PurchaseBlockedException(PurchaseBlock.otherStore);
    }
    if (!await _store.isAvailable()) {
      throw StateError('Store is unavailable');
    }
    final response = await _store.queryProductDetails({product.storeProductId});
    if (response.error != null) throw StateError(response.error!.message);
    if (response.productDetails.isEmpty) {
      throw StateError('Family+ is not available in this store region');
    }
    final selected = response.productDetails.first;
    final terms = resolveStoreOfferTerms(selected);
    if (terms.price.trim().isEmpty ||
        terms.currencyCode.trim().isEmpty ||
        terms.periodLength.trim().isEmpty) {
      throw StateError('Subscription terms are unavailable in this store');
    }
    final PurchaseParam param;
    if (selected is GooglePlayProductDetails) {
      // The App Store upgrades within the subscription group both plans
      // belong to; Google Play needs the subscription being replaced named.
      final replacing = current == null
          ? null
          : await _replacing(current.$2.storeProductId, accountToken);
      final index = selected.subscriptionIndex!;
      param = GooglePlayPurchaseParam(
        productDetails: selected,
        applicationUserName: accountToken,
        offerToken: selected
            .productDetails
            .subscriptionOfferDetails![index]
            .offerIdToken,
        changeSubscriptionParam: replacing,
      );
    } else {
      param = PurchaseParam(
        productDetails: selected,
        applicationUserName: accountToken,
      );
    }
    if (!await _store.buyNonConsumable(purchaseParam: param)) {
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

const _planFeatures = {
  'studafy_max': StudyPlanTier.max,
  'studafy_plus': StudyPlanTier.plus,
};

/// The student's own paid plan from their entitlement rows: the highest
/// plan that is active, in a payment grace period, or on hold (paused or
/// failing to renew) within the last 100 days. A plan a guardian reads for
/// a child ([V1EntitlementRow.beneficiaryStudentId]) is not the caller's.
StudyPlanSubscription? currentStudyPlanSubscription(
  List<V1EntitlementRow> rows,
  DateTime now,
) {
  StudyPlanSubscription? best;
  for (final row in rows) {
    final tier = _planFeatures[row.featureKey];
    if (tier == null || row.beneficiaryStudentId != null) continue;
    final ends = row.endsAt;
    final current = switch (row.status) {
      'active' || 'grace_period' => ends == null || ends.isAfter(now),
      'on_hold' =>
        ends == null || ends.isAfter(now.subtract(const Duration(days: 100))),
      _ => false,
    };
    if (!current) continue;
    var renewal = RenewalStatus.parse(row.renewalStatus);
    if (row.status == 'grace_period' ||
        (row.status == 'on_hold' && renewal != RenewalStatus.paused)) {
      renewal = RenewalStatus.paymentIssue;
    }
    final candidate = StudyPlanSubscription(
      tier: tier,
      renewal: renewal,
      endsAt: ends,
      store: SubscriptionStore.parse(row.platform),
      storeProductId: row.storeProductId,
      paidByMe: row.purchasedByMe,
    );
    if (best == null || candidate.tier.index > best.tier.index) {
      best = candidate;
    }
  }
  return best;
}
