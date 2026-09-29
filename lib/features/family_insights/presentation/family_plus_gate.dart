import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/studafy_design.dart';
import '../../../core/user_content_text.dart';
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
      backgroundColor: studafyCanvas,
      appBar: AppBar(
        backgroundColor: Colors.white,
        title: Text(AppL10n.of(context).insightsTitle),
        actions: widget.actions,
      ),
      body: active == null
          ? const Center(child: CircularProgressIndicator())
          : FamilyPlusOffer(
              key: ValueKey(widget.studentId),
              subscriptions: widget.subscriptions,
              studentId: widget.studentId,
              childName: widget.childName,
              openLink: widget.openLink,
            ),
    );
  }
}

/// What Family+ is, what it costs, and the way to buy it for one child.
///
/// Follows the stores' subscription rules: the price shown is the store's
/// own, the buy button only appears over store-confirmed terms and working
/// terms and privacy links, and renewal, cancellation and restore are all on
/// the same screen.
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

  PaywallOffer? _offer;
  bool _loading = true;
  bool _busy = false;
  String? _message;

  @override
  void initState() {
    super.initState();
    _loadOffer();
  }

  Future<void> _loadOffer() async {
    final subscriptions = widget.subscriptions;
    PaywallOffer? offer;
    if (subscriptions != null) {
      try {
        offer = await subscriptions.insightsOffer();
      } on Object {
        offer = null;
      }
    }
    if (!mounted) return;
    setState(() {
      _offer = offer;
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

  @override
  Widget build(BuildContext context) {
    final l10n = AppL10n.of(context);
    final theme = Theme.of(context);
    final subscriptions = widget.subscriptions;
    final offer = _offer;
    final storeConfirmed = offer != null && offer.canPurchase;
    final links = _validUrl(_terms) && _validUrl(_privacy);

    final String price;
    if (storeConfirmed) {
      price = l10n.familyPlusPrice(offer.price);
    } else {
      price = l10n.familyPlusUsPrice;
    }
    final trial =
        storeConfirmed && offer.hasTrial && offer.trialLengthLabel.isNotEmpty
        ? l10n.familyPlusTrial(offer.trialLengthLabel, offer.price)
        : null;

    final Widget action;
    if (subscriptions == null) {
      action = Text(l10n.familyPlusNotInThisBuild);
    } else if (_loading) {
      action = Text(l10n.familyPlusCheckingStore);
    } else if (!storeConfirmed) {
      action = Text(l10n.familyPlusStoreUnavailable);
    } else {
      action = SizedBox(
        width: double.infinity,
        child: FilledButton.icon(
          onPressed: _busy || !links
              ? null
              : () => _perform(
                  () => subscriptions.purchaseInsightsMonthly(
                    beneficiaryStudentId: widget.studentId,
                  ),
                  l10n.familyPlusOpeningStore,
                ),
          icon: const Icon(Icons.lock_open_rounded),
          label: Text(
            trial != null
                ? l10n.familyPlusStartTrial
                : l10n.familyPlusSubscribe(widget.childName),
          ),
        ),
      );
    }

    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        Container(
          padding: const EdgeInsets.all(22),
          decoration: BoxDecoration(
            color: studafyNavy,
            borderRadius: BorderRadius.circular(24),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Icon(Icons.insights_rounded, color: Colors.white, size: 32),
              const SizedBox(height: 12),
              UserContentText(
                l10n.familyPlusHeadline(widget.childName),
                style: theme.textTheme.headlineSmall?.copyWith(
                  color: Colors.white,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                l10n.familyPlusIntro,
                style: const TextStyle(color: Colors.white70, height: 1.4),
              ),
            ],
          ),
        ),
        const SizedBox(height: 18),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                for (final feature in [
                  l10n.familyPlusFeatureTrends,
                  l10n.familyPlusFeatureDue,
                  l10n.familyPlusFeatureSubjects,
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
                          color: studafyCyan,
                        ),
                        const SizedBox(width: 8),
                        Expanded(child: Text(feature)),
                      ],
                    ),
                  ),
                const Divider(height: 26),
                Text(
                  price,
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
                if (trial != null) ...[const SizedBox(height: 4), Text(trial)],
                const SizedBox(height: 6),
                Text(
                  l10n.familyPlusOneChild(widget.childName),
                  style: theme.textTheme.bodySmall,
                ),
                const SizedBox(height: 14),
                action,
              ],
            ),
          ),
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
