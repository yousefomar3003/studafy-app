import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/ai_tokens.dart';
import '../../../core/ai_usage.dart';
import '../../../core/failures.dart';
import '../../../core/studafy_design.dart';
import '../../../core/studafy_formatting.dart';
import '../../../l10n/generated/app_l10n.dart';
import '../domain/study.dart';
import 'cancel_subscription_sheet.dart';
import 'study_plan_copy.dart';

/// The three plans, what each unlocks, and where the student stands.
///
/// Prices come from the store listing, in the student's own currency. When
/// the store cannot be reached the US list price is shown, labelled as such:
/// the store is always what confirms the price (App Review 3.1.2).
///
/// Payment happens only in the App Store or Google Play sheet, with the
/// payment methods of the student's store account. There is no card form
/// and no wallet button here, and on the web and desktop, where there is
/// no store, plans are described but bought in the mobile app.
class StudyPlansPage extends StatefulWidget {
  const StudyPlansPage({
    super.key,
    required this.study,
    this.subscriptions,
    this.openLink,
  });

  final StudyRepository study;

  /// Null in builds with no store; plans are then described, not sold.
  final StudyPlanSubscriptionRepository? subscriptions;

  /// Opens a web page outside the app. Tests supply their own.
  final Future<bool> Function(Uri url)? openLink;

  @override
  State<StudyPlansPage> createState() => _StudyPlansPageState();
}

class _StudyPlansPageState extends State<StudyPlansPage> {
  StudyPlan? _plan;
  StudyPlanSubscription? _subscription;
  final Map<StudyPlanTier, StudyPlanOffer> _offers = {};

  /// The server answered that it takes no payments (billing not switched
  /// on), as opposed to the store being out of reach for a moment.
  bool _paymentsOff = false;
  bool _loading = true;
  bool _busy = false;
  String? _message;

  static const _terms = String.fromEnvironment('STUDAFY_TERMS_URL');
  static const _privacy = String.fromEnvironment('STUDAFY_PRIVACY_URL');

  /// The Android application id, for Google Play's link straight to this
  /// app's subscription. Matches android/app/build.gradle.kts.
  static const _androidPackage = String.fromEnvironment(
    'STUDAFY_ANDROID_PACKAGE',
    defaultValue: 'com.studafy.light',
  );

  SubscriptionStore? get _store => widget.subscriptions?.purchaseStore;

  @override
  void initState() {
    super.initState();
    widget.subscriptions?.addEntitlementListener(_load);
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  @override
  void dispose() {
    widget.subscriptions?.removeEntitlementListener(_load);
    super.dispose();
  }

  Future<void> _load() async {
    if (!mounted) return;
    setState(() => _loading = true);
    StudyPlan? plan;
    try {
      plan = await widget.study.plan();
    } on Object {
      plan = null;
    }
    StudyPlanSubscription? subscription;
    final offers = <StudyPlanTier, StudyPlanOffer>{};
    var paymentsOff = false;
    final subscriptions = widget.subscriptions;
    if (subscriptions != null) {
      try {
        subscription = await subscriptions.subscription();
      } on Object {
        subscription = null;
      }
      if (_store != null) {
        for (final tier in [StudyPlanTier.plus, StudyPlanTier.max]) {
          try {
            offers[tier] = await subscriptions.offer(tier);
          } on Object catch (error) {
            // A store outage never hides the plans; the card says the store
            // could not be reached. A server with no billing at all says
            // so instead, since trying again will not help.
            if (Failure.fromError(error).code == Failure.notFoundCode) {
              paymentsOff = true;
            }
          }
        }
      }
    }
    if (!mounted) return;
    setState(() {
      _plan = plan;
      _subscription = subscription;
      _offers
        ..clear()
        ..addAll(offers);
      _paymentsOff = paymentsOff;
      _loading = false;
    });
  }

  String _blockedText(AppL10n l10n, PurchaseBlock reason) => switch (reason) {
    PurchaseBlock.alreadySubscribed => l10n.studyPlansBlockedAlready,
    PurchaseBlock.paidByParent => l10n.studyPlansBlockedParent,
    PurchaseBlock.otherStore => l10n.studyPlansBlockedOtherStore(
      storeName(_subscription?.store ?? SubscriptionStore.appStore),
    ),
    PurchaseBlock.upgradeNeedsOriginalAccount =>
      l10n.studyPlansBlockedOriginalAccount,
  };

  Future<void> _perform(Future<void> Function() action, String done) async {
    if (_busy) return;
    final l10n = AppL10n.of(context);
    setState(() {
      _busy = true;
      _message = null;
    });
    try {
      await action();
      if (mounted) setState(() => _message = done);
      await _load();
    } on PurchaseBlockedException catch (blocked) {
      if (mounted) {
        setState(() => _message = _blockedText(l10n, blocked.reason));
      }
    } on Object {
      if (mounted) setState(() => _message = l10n.studySetThatDidNotWorkPlease);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  bool _validUrl(String value) {
    final uri = Uri.tryParse(value);
    return uri != null &&
        uri.scheme == 'https' &&
        uri.host.isNotEmpty &&
        uri.userInfo.isEmpty;
  }

  Future<void> _openUri(Uri uri) async {
    if (!_validUrl(uri.toString())) return;
    final open =
        widget.openLink ??
        (Uri u) => launchUrl(u, mode: LaunchMode.externalApplication);
    await open(uri);
  }

  Future<void> _open(String value) async {
    if (_validUrl(value)) await _openUri(Uri.parse(value));
  }

  Uri _manageUri(StudyPlanSubscription subscription) => manageSubscriptionUri(
    subscription.store ?? _store ?? SubscriptionStore.appStore,
    storeProductId: subscription.storeProductId,
    androidPackage: _androidPackage,
  );

  /// The plan's AI usage: a bar and a label, when it resets - never a
  /// count of tokens, which only the server keeps.
  Widget _usage(StudyPlan plan) {
    final l10n = AppL10n.of(context);
    final allowance = plan.allowance;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        AiUsageCard(
          compact: true,
          usage: AiUsageSnapshot(
            planName: studyPlanCopy[plan.tier]!.name,
            used: allowance.used,
            total: allowance.total,
            resetsAt: allowance.resetsAt,
            weekly: allowance.weekly,
            canUpgrade: plan.tier.next != null,
          ),
        ),
        Align(
          alignment: AlignmentDirectional.centerStart,
          child: TextButton.icon(
            onPressed: () => showTokenGuide(context),
            icon: const Icon(Icons.info_outline_rounded, size: 18),
            label: Text(l10n.tokensWhatAreThey),
          ),
        ),
      ],
    );
  }

  /// The paid plan as the store bills it: when it renews or ends, a payment
  /// problem, and the way to manage, pause or cancel it.
  Widget _subscriptionCard(StudyPlanSubscription subscription) {
    final l10n = AppL10n.of(context);
    final theme = Theme.of(context);
    final plan = studyPlanCopy[subscription.tier]!.name;
    final store = storeName(
      subscription.store ?? _store ?? SubscriptionStore.appStore,
    );
    final ends = subscription.endsAt;
    final date = ends == null
        ? l10n.studyPlansEndOfPeriod
        : studafyShortDate(context, ends.toLocal());
    final manage = _manageUri(subscription);

    final String status;
    if (!subscription.paidByMe) {
      status = l10n.studyPlansPaidByParent(store);
    } else {
      status = switch (subscription.renewal) {
        RenewalStatus.cancelled => l10n.studyPlansCancelledUntil(plan, date),
        RenewalStatus.paused => l10n.studyPlansPausedNote,
        RenewalStatus.paymentIssue => l10n.studyPlansPaymentIssue(store, plan),
        _ => l10n.studyPlansRenewsOn(date),
      };
    }

    return Card(
      margin: const EdgeInsets.only(bottom: 18),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              plan,
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              status,
              style: subscription.renewal == RenewalStatus.paymentIssue
                  ? TextStyle(color: theme.colorScheme.error)
                  : null,
            ),
            const SizedBox(height: 4),
            Text(
              l10n.studyPlansBilledBy(store),
              style: theme.textTheme.bodySmall,
            ),
            if (subscription.paidByMe) ...[
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  if (subscription.renewal == RenewalStatus.paymentIssue)
                    FilledButton.icon(
                      onPressed: () => _openUri(manage),
                      icon: const Icon(Icons.credit_card_rounded),
                      label: Text(l10n.studyPlansUpdatePayment),
                    ),
                  OutlinedButton(
                    onPressed: () => _openUri(manage),
                    child: Text(l10n.studyPlansManageSubscription),
                  ),
                  if (subscription.renewal != RenewalStatus.cancelled)
                    TextButton(
                      onPressed: () => showCancelSubscriptionSheet(
                        context,
                        subscription: subscription,
                        manageUri: manage,
                        openStore: _openUri,
                      ),
                      child: Text(l10n.studyPlansCancelSubscription),
                    ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _planCard(StudyPlanTier tier) {
    final l10n = AppL10n.of(context);
    final theme = Theme.of(context);
    final copy = studyPlanCopy[tier]!;
    final held = _plan?.tier ?? StudyPlanTier.free;
    final current = held == tier;
    // Max includes Plus: a Max student is never offered Plus as well.
    final included =
        !current && tier != StudyPlanTier.free && held.includes(tier);
    final offer = _offers[tier];
    final subscriptions = widget.subscriptions;
    final upgrading = held != StudyPlanTier.free;

    Widget? action;
    // What the plan's own button does; a tap anywhere on the card does the
    // same, so the whole plan is the thing to press.
    VoidCallback? primary;
    if (tier != StudyPlanTier.free &&
        !current &&
        !included &&
        subscriptions != null &&
        _store != null) {
      final links = _validUrl(_terms) && _validUrl(_privacy);
      if (offer == null) {
        action = Text(
          _paymentsOff
              ? l10n.studyPlansPaymentsNotSetUp
              : l10n.studyPlansTheStoreCouldNotBe,
        );
      } else if (!offer.selfPurchaseEnabled) {
        action = Text(l10n.studyPlansBuyingIsNotEnabledFor);
      } else if (offer.approval != 'approved') {
        primary = _busy || offer.approval == 'requested'
            ? null
            : () => _perform(
                () => subscriptions.requestApproval(tier),
                l10n.studyPlansWeAskedYourParentTo,
              );
        action = OutlinedButton.icon(
          onPressed: primary,
          icon: const Icon(Icons.family_restroom_rounded),
          label: Text(
            offer.approval == 'requested'
                ? l10n.studyPlansWaitingForAParent
                : l10n.studyPlansAskAParentToApprove,
          ),
        );
      } else {
        primary = _busy || !offer.canPurchase || !links
            ? null
            : () => _perform(
                () => subscriptions.purchase(tier),
                l10n.studyPlansOpeningTheStore,
              );
        action = Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            FilledButton.icon(
              onPressed: primary,
              icon: const Icon(Icons.lock_open_rounded),
              label: Text(
                upgrading
                    ? l10n.studyPlansUpgradeToName(copy.name)
                    : offer.oneMonthTrial
                    ? l10n.studyPlansStartAFreeMonth
                    : l10n.studyPlansSubscribeToName(copy.name),
              ),
            ),
            if (upgrading) ...[
              const SizedBox(height: 6),
              Text(
                l10n.studyPlansUpgradeReplaces(studyPlanCopy[held]!.name),
                style: theme.textTheme.bodySmall,
              ),
            ],
          ],
        );
      }
    }

    final price = tier == StudyPlanTier.free
        ? l10n.studyPlansFree
        : (offer != null && offer.storeAvailable && offer.price.isNotEmpty)
        ? l10n.studyPlansPriceMonth(offer.price)
        : l10n.studyPlansUspriceMonthInTheUs(copy.usPrice);

    VoidCallback? onTap = primary;
    if (onTap == null &&
        !_busy &&
        tier != StudyPlanTier.free &&
        !current &&
        !included) {
      // Nothing can be done from this plan yet: say why, rather than a tap
      // that does nothing.
      final String reason;
      if (subscriptions == null || _store == null) {
        reason = l10n.studyPlansBuyInMobileApp;
      } else if (_paymentsOff) {
        reason = l10n.studyPlansPaymentsNotSetUp;
      } else if (offer == null) {
        reason = l10n.studyPlansTheStoreCouldNotBe;
      } else {
        reason = l10n.studyPlansCannotBuyYet;
      }
      onTap = () => ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(content: Text(reason)));
    }

    return Card(
      clipBehavior: Clip.antiAlias,
      margin: const EdgeInsets.only(bottom: 14),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: current
            ? BorderSide(color: theme.colorScheme.primary, width: 2)
            : BorderSide.none,
      ),
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      copy.name,
                      style: theme.textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                  if (current)
                    Chip(label: Text(l10n.studyPlansYourPlan))
                  else if (included)
                    Chip(label: Text(l10n.studyPlansIncludedInYourPlan)),
                ],
              ),
              Text(price, style: theme.textTheme.titleMedium),
              const SizedBox(height: 10),
              for (final feature in copy.features)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 3),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Icon(
                        Icons.check_circle_rounded,
                        size: 18,
                        color: studafyCyan,
                      ),
                      const SizedBox(width: 8),
                      Expanded(child: Text(feature(l10n))),
                    ],
                  ),
                ),
              if (action != null) ...[const SizedBox(height: 12), action],
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppL10n.of(context);
    final plan = _plan;
    final subscription = _subscription;
    final subscriptions = widget.subscriptions;
    final store = _store;
    final small = Theme.of(context).textTheme.bodySmall;
    return Scaffold(
      appBar: AppBar(title: Text(l10n.studentLessonsPlans)),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : StudafyRefreshIndicator(
              onRefresh: _load,
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  if (plan != null)
                    Card(
                      margin: const EdgeInsets.only(bottom: 18),
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: _usage(plan),
                      ),
                    ),
                  if (subscription != null) _subscriptionCard(subscription),
                  for (final tier in StudyPlanTier.values) _planCard(tier),
                  if (_busy) const LinearProgressIndicator(),
                  if (_message != null)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      child: Text(_message!),
                    ),
                  if (subscriptions != null && store == null)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: Text(l10n.studyPlansBuyInMobileApp),
                    ),
                  if (subscriptions != null && store != null)
                    TextButton(
                      onPressed: _busy
                          ? null
                          : () => _perform(
                              subscriptions.restorePurchases,
                              l10n.studyPlansRestoringPurchases,
                            ),
                      child: Text(l10n.studyPlansRestorePurchases),
                    ),
                  const SizedBox(height: 8),
                  if (store != null)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 6),
                      child: Text(
                        store == SubscriptionStore.appStore
                            ? l10n.studyPlansPayWithApple
                            : l10n.studyPlansPayWithGoogle,
                        style: small,
                      ),
                    ),
                  Text(
                    l10n.studyPlansAutoRenewingMonthlySubscriptionsPayment,
                    style: small,
                  ),
                  Wrap(
                    children: [
                      TextButton(
                        onPressed: _validUrl(_terms)
                            ? () => _open(_terms)
                            : null,
                        child: Text(l10n.studyPlansTermsOfUse),
                      ),
                      TextButton(
                        onPressed: _validUrl(_privacy)
                            ? () => _open(_privacy)
                            : null,
                        child: Text(l10n.studyPlansPrivacyPolicy),
                      ),
                    ],
                  ),
                ],
              ),
            ),
    );
  }
}
