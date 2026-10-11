import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/studafy_components.dart';
import '../../../core/studafy_design.dart';
import '../../../l10n/generated/app_l10n.dart';
import '../domain/parent_subscription_repository.dart';

/// Family+ for one child: the insights when that child has it, the offer
/// when not.
///
/// The server answers "not found" for a child without Family+, the same as
/// for a child the caller is not linked to, so it cannot be used to learn
/// whether a student exists. The app therefore asks for the child's
/// entitlement first and shows the offer when there is none.
class FamilyPlusGate extends StatefulWidget {
  const FamilyPlusGate({
    super.key,
    required this.subscriptions,
    required this.studentId,
    required this.childName,
    required this.insights,
    this.actions = const [],
    this.openLink,
  });

  /// Null in builds with no store: the offer is described, not sold.
  final ParentSubscriptionRepository? subscriptions;
  final String studentId;
  final String childName;

  /// The insights screen, shown once the child has Family+.
  final Widget insights;
  final List<Widget> actions;

  /// Opens a web page outside the app. Tests supply their own.
  final Future<bool> Function(Uri url)? openLink;

  @override
  State<FamilyPlusGate> createState() => _FamilyPlusGateState();
}

class _FamilyPlusGateState extends State<FamilyPlusGate> {
  bool? _active;

  @override
  void initState() {
    super.initState();
    widget.subscriptions?.addEntitlementListener(_check);
    _check();
  }

  @override
  void didUpdateWidget(FamilyPlusGate oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.subscriptions != widget.subscriptions) {
      oldWidget.subscriptions?.removeEntitlementListener(_check);
      widget.subscriptions?.addEntitlementListener(_check);
    }
    if (oldWidget.studentId != widget.studentId) _check();
  }

  @override
  void dispose() {
    widget.subscriptions?.removeEntitlementListener(_check);
    super.dispose();
  }

  Future<void> _check() async {
    final subscriptions = widget.subscriptions;
    if (subscriptions == null) {
      setState(() => _active = false);
      return;
    }
    setState(() => _active = null);
    bool active;
    try {
      active = (await subscriptions.entitlement(
        beneficiaryStudentId: widget.studentId,
      )).active;
    } on Object {
      active = false;
    }
    if (mounted) setState(() => _active = active);
  }

  @override
  Widget build(BuildContext context) {
    final active = _active;
    if (active == true) return widget.insights;
    return Scaffold(
      body: Column(
        children: [
          StudafyLargeTitle(
            title: AppL10n.of(context).insightsTitle,
            subtitle: AppL10n.of(context).familyPlusHeadline(widget.childName),
            actions: widget.actions,
          ),
          Expanded(
            child: active == null
                ? const Center(child: CircularProgressIndicator())
                : FamilyPlusOffer(
                    key: ValueKey(widget.studentId),
                    subscriptions: widget.subscriptions,
                    studentId: widget.studentId,
                    childName: widget.childName,
                    openLink: widget.openLink,
                  ),
          ),
        ],
      ),
    );
  }
}

/// What Family+ is, what the two family plans cost, and the way to buy one.
///
/// Follows the stores' subscription rules: the price shown is the store's
/// own, buying only happens over store-confirmed terms and working terms and
/// privacy links, and renewal, cancellation and restore are all on the same
/// screen. Each plan card is the thing to press.
class FamilyPlusOffer extends StatefulWidget {
  const FamilyPlusOffer({
    super.key,
    required this.subscriptions,
    required this.studentId,
    required this.childName,
    this.openLink,
  });

  final ParentSubscriptionRepository? subscriptions;
  final String studentId;
  final String childName;
  final Future<bool> Function(Uri url)? openLink;

  @override
  State<FamilyPlusOffer> createState() => _FamilyPlusOfferState();
}

class _FamilyPlusOfferState extends State<FamilyPlusOffer> {
  static const _terms = String.fromEnvironment('STUDAFY_TERMS_URL');
  static const _privacy = String.fromEnvironment('STUDAFY_PRIVACY_URL');

  final Map<FamilyPlusPlan, PaywallOffer> _offers = {};
  FamilyPlusStatus _status = FamilyPlusStatus.none;
  bool _loading = true;
  bool _busy = false;
  String? _message;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final subscriptions = widget.subscriptions;
    final offers = <FamilyPlusPlan, PaywallOffer>{};
    var status = FamilyPlusStatus.none;
    if (subscriptions != null) {
      // Both plans' prices and the current plan together: one wait, not
      // three in a row.
      final results = await Future.wait<Object?>([
        for (final plan in FamilyPlusPlan.values)
          subscriptions
              .familyOffer(plan)
              .then<Object?>((offer) => offer, onError: (Object _) => null),
        subscriptions.familyPlan().then<Object?>(
          (plan) => plan,
          onError: (Object _) => FamilyPlusStatus.none,
        ),
      ]);
      for (final (index, plan) in FamilyPlusPlan.values.indexed) {
        if (results[index] case final PaywallOffer offer) offers[plan] = offer;
      }
      if (results.last case final FamilyPlusStatus current) status = current;
    }
    if (!mounted) return;
    setState(() {
      _offers
        ..clear()
        ..addAll(offers);
      _status = status;
      _loading = false;
    });
  }

  bool _validUrl(String value) {
    final uri = Uri.tryParse(value);
    return uri != null &&
        uri.scheme == 'https' &&
        uri.host.isNotEmpty &&
        uri.userInfo.isEmpty;
  }

  Future<void> _open(String value) async {
    if (!_validUrl(value)) return;
    final open =
        widget.openLink ??
        (Uri u) => launchUrl(u, mode: LaunchMode.externalApplication);
    await open(Uri.parse(value));
  }

  String get _manageUrl => defaultTargetPlatform == TargetPlatform.iOS
      ? 'https://apps.apple.com/account/subscriptions'
      : 'https://play.google.com/store/account/subscriptions';

  Future<void> _perform(Future<void> Function() action, String done) async {
    if (_busy) return;
    final failed = AppL10n.of(context).familyPlusFailed;
    setState(() {
      _busy = true;
      _message = null;
    });
    try {
      await action();
      if (mounted) setState(() => _message = done);
    } on Object {
      if (mounted) setState(() => _message = failed);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _explain(String reason) => ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(content: Text(reason)));

  Widget _planCard(FamilyPlusPlan plan) {
    final l10n = AppL10n.of(context);
    final theme = Theme.of(context);
    final subscriptions = widget.subscriptions;
    final offer = _offers[plan];
    final confirmed = offer != null && offer.canPurchase;
    final links = _validUrl(_terms) && _validUrl(_privacy);
    final held = _status.plan;
    final current = held == plan;
    // A plan the same size or smaller than the one held is not sold again.
    final covered = held != null && held.seats >= plan.seats;

    final price = confirmed
        ? l10n.familyPlusPrice(offer.price)
        : l10n.familyPlusUsPrice(plan.usPrice);
    final trial =
        confirmed && offer.hasTrial && offer.trialLengthLabel.isNotEmpty
        ? l10n.familyPlusTrial(offer.trialLengthLabel, offer.price)
        : null;

    VoidCallback? onTap;
    Widget? action;
    if (!covered) {
      if (subscriptions == null) {
        onTap = () => _explain(l10n.familyPlusNotInThisBuild);
      } else if (_loading) {
        onTap = null;
      } else if (!confirmed) {
        onTap = () => _explain(l10n.familyPlusStoreUnavailable);
      } else if (!links) {
        onTap = () => _explain(l10n.familyPlusCannotBuyYet);
      } else if (!_busy) {
        onTap = () => _perform(
          () => subscriptions.purchaseFamilyPlan(plan),
          l10n.familyPlusOpeningStore,
        );
      }
      action = SizedBox(
        width: double.infinity,
        child: FilledButton.icon(
          onPressed: confirmed && links && !_busy ? onTap : null,
          icon: const Icon(Icons.lock_open_rounded),
          label: Text(
            held != null
                ? l10n.familyPlusUpgrade(plan.seats)
                : trial != null
                ? l10n.familyPlusStartTrial
                : l10n.familyPlusSubscribePlan(plan.seats),
          ),
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Material(
        color: Colors.white,
        clipBehavior: Clip.antiAlias,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(22),
          side: current
              ? const BorderSide(color: studafyTeal, width: 2)
              : const BorderSide(color: studafyHairline),
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
                    const Icon(
                      Icons.family_restroom_rounded,
                      color: studafyNavy,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        l10n.familyPlusPlanName(plan.seats),
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                    if (current)
                      StatusPill(
                        label: l10n.familyPlusYourPlan,
                        icon: Icons.check_circle_rounded,
                        color: studafyTeal,
                      ),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  price,
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
                if (trial != null) ...[const SizedBox(height: 4), Text(trial)],
                const SizedBox(height: 4),
                Text(
                  l10n.familyPlusPlanDetail(plan.seats),
                  style: theme.textTheme.bodySmall,
                ),
                if (action != null) ...[const SizedBox(height: 12), action],
              ],
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppL10n.of(context);
    final theme = Theme.of(context);
    final subscriptions = widget.subscriptions;
    final held = _status.plan;

    final ends = _status.endsAt;
    return ListView(
      padding: const EdgeInsetsDirectional.fromSTEB(16, 4, 16, 32),
      children: [
        // Where the parent stands, first: the plan they have, or none.
        PlanSummaryCard(
          eyebrow: l10n.familyPlusCurrentPlan,
          planName: held == null
              ? l10n.familyPlusNoPlan
              : 'Family+ · ${l10n.familyPlusPlanName(held.seats)}',
          detail: held == null
              ? l10n.familyPlusIntro
              : [
                  l10n.familyPlusCoveredCount(_status.coveredStudentIds.length),
                  if (ends != null)
                    l10n.familyPlusEnds(
                      MaterialLocalizations.of(context)
                          .formatMediumDate(ends.toLocal()),
                    ),
                ].join(' · '),
        ),
        if (held != null && !_status.covers(widget.studentId))
          Padding(
            padding: const EdgeInsets.only(top: 12),
            child: StudafyStatusCard(
              icon: Icons.group_add_outlined,
              title: l10n.familyPlusNotCoveredTitle,
              message: l10n.familyPlusNotCovered(held.seats, widget.childName),
            ),
          ),
        // The plans, straight away - nothing to scroll past to find them.
        SectionHeader(l10n.familyPlusPlansTitle),
        for (final plan in FamilyPlusPlan.values) _planCard(plan),
        SectionHeader(l10n.familyPlusWhatYouGet),
        FeatureCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              for (final feature in [
                l10n.familyPlusFeatureFocus,
                l10n.familyPlusFeatureClasses,
                l10n.familyPlusFeatureChart,
                l10n.familyPlusFeatureMissing,
                l10n.familyPlusFeatureTrends,
                l10n.familyPlusFeatureSchool,
              ])
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Icon(
                        Icons.check_circle_rounded,
                        size: 18,
                        color: studafyTeal,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          feature,
                          style: const TextStyle(
                            color: studafyInk,
                            height: 1.35,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        if (subscriptions == null)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Text(l10n.familyPlusNotInThisBuild),
          )
        else if (!_loading && !_offers.values.any((offer) => offer.canPurchase))
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Text(l10n.familyPlusStoreUnavailable),
          ),
        Text(l10n.familyPlusCoversFamily, style: theme.textTheme.bodySmall),
        if (_loading)
          Padding(
            padding: const EdgeInsets.only(top: 12),
            child: Text(l10n.familyPlusCheckingStore),
          ),
        if (_busy)
          const Padding(
            padding: EdgeInsets.only(top: 12),
            child: LinearProgressIndicator(),
          ),
        if (_message != null)
          Padding(
            padding: const EdgeInsets.only(top: 12),
            child: Text(_message!),
          ),
        if (subscriptions != null) ...[
          const SizedBox(height: 8),
          Wrap(
            children: [
              TextButton(
                onPressed: _busy
                    ? null
                    : () => _perform(
                        subscriptions.restorePurchases,
                        l10n.familyPlusRestoring,
                      ),
                child: Text(l10n.familyPlusRestore),
              ),
              TextButton(
                onPressed: () => _open(_manageUrl),
                child: Text(l10n.familyPlusManage),
              ),
            ],
          ),
        ],
        const SizedBox(height: 8),
        Text(l10n.familyPlusDisclosure, style: theme.textTheme.bodySmall),
        Wrap(
          children: [
            TextButton(
              onPressed: _validUrl(_terms) ? () => _open(_terms) : null,
              child: Text(l10n.familyPlusTerms),
            ),
            TextButton(
              onPressed: _validUrl(_privacy) ? () => _open(_privacy) : null,
              child: Text(l10n.familyPlusPrivacy),
            ),
          ],
        ),
      ],
    );
  }
}
