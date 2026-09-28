import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/studafy_design.dart';
import '../domain/study.dart';
import '../../../l10n/generated/app_l10n.dart';

/// The three plans, what each unlocks, and where the student stands.
///
/// Prices come from the store listing, in the student's own currency. When
/// the store cannot be reached the US list price is shown, labelled as such:
/// the store is always what confirms the price (App Review 3.1.2).
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

class _PlanCopy {
  const _PlanCopy(this.name, this.usPrice, this.features);
  final String name;
  final String usPrice;

  /// What the plan includes, in the reader's language.
  final List<String Function(AppL10n)> features;
}

class _StudyPlansPageState extends State<StudyPlansPage> {
  StudyPlan? _plan;
  final Map<StudyPlanTier, StudyPlanOffer> _offers = {};
  bool _loading = true;
  bool _busy = false;
  String? _message;

  static const _terms = String.fromEnvironment('STUDAFY_TERMS_URL');
  static const _privacy = String.fromEnvironment('STUDAFY_PRIVACY_URL');

  static final _copy = {
    StudyPlanTier.free: _PlanCopy('Studafy Free', '', [
      (l) => l.studyPlansFeatureLessons,
      (l) => l.studyPlansFeatureNotebook,
      (l) => l.studyPlansFeatureTenQuestions,
    ]),
    StudyPlanTier.plus: _PlanCopy('Studafy Plus', r'US$3.99', [
      (l) => l.studyPlansFeatureEverythingInFree,
      (l) => l.studyPlansFeatureWhiteboard,
      (l) => l.studyPlansFeatureFortyQuestions,
    ]),
    StudyPlanTier.max: _PlanCopy('Studafy Max', r'US$5.99', [
      (l) => l.studyPlansFeatureEverythingInPlus,
      (l) => l.studyPlansFeatureQuizzes,
      (l) => l.studyPlansFeatureFlashcards,
      (l) => l.studyPlansFeatureSixtyQuestions,
    ]),
  };

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
    final offers = <StudyPlanTier, StudyPlanOffer>{};
    final subscriptions = widget.subscriptions;
    if (subscriptions != null) {
      for (final tier in [StudyPlanTier.plus, StudyPlanTier.max]) {
        try {
          offers[tier] = await subscriptions.offer(tier);
        } on Object {
          // A store outage never hides the plans; the card says the store
          // could not be reached.
        }
      }
    }
    if (!mounted) return;
    setState(() {
      _plan = plan;
      _offers
        ..clear()
        ..addAll(offers);
      _loading = false;
    });
  }

  Future<void> _perform(Future<void> Function() action, String done) async {
    if (_busy) return;
    setState(() {
      _busy = true;
      _message = null;
    });
    try {
      await action();
      if (mounted) setState(() => _message = done);
      await _load();
    } on Object {
      if (mounted) {
        setState(
          () => _message = AppL10n.of(context).studySetThatDidNotWorkPlease,
        );
      }
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

  Widget _usage(StudyPlan plan) {
    final theme = Theme.of(context);
    if (plan.tier == StudyPlanTier.free) {
      return Text(
        AppL10n.of(context).studyPlansQuestionsTodayAsktodayOfAskperday(
          plan.askToday,
          plan.askPerDay,
        ),
      );
    }
    final renews = MaterialLocalizations.of(context)
        .formatMediumDate(plan.resetsAt);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          AppL10n.of(
            context,
          ).studyPlansAiUsedThisMonthRound((plan.allowanceUsed * 100).round()),
        ),
        const SizedBox(height: 6),
        ClipRRect(
          borderRadius: BorderRadius.circular(6),
          child: LinearProgressIndicator(
            value: plan.allowanceUsed,
            minHeight: 8,
            color: plan.allowanceUsed >= 0.9 ? theme.colorScheme.error : null,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          AppL10n.of(context).studyPlansRenewsRenews(renews),
          style: theme.textTheme.bodySmall,
        ),
      ],
    );
  }

  Widget _planCard(StudyPlanTier tier) {
    final theme = Theme.of(context);
    final copy = _copy[tier]!;
    final current = (_plan?.tier ?? StudyPlanTier.free) == tier;
    final offer = _offers[tier];
    final subscriptions = widget.subscriptions;

    Widget? action;
    if (tier != StudyPlanTier.free && !current && subscriptions != null) {
      final links = _validUrl(_terms) && _validUrl(_privacy);
      if (offer == null) {
        action = Text(AppL10n.of(context).studyPlansTheStoreCouldNotBe);
      } else if (!offer.selfPurchaseEnabled) {
        action = Text(AppL10n.of(context).studyPlansBuyingIsNotEnabledFor);
      } else if (offer.approval != 'approved') {
        action = OutlinedButton.icon(
          onPressed: _busy || offer.approval == 'requested'
              ? null
              : () => _perform(
                  () => subscriptions.requestApproval(tier),
                  AppL10n.of(context).studyPlansWeAskedYourParentTo,
                ),
          icon: const Icon(Icons.family_restroom_rounded),
          label: Text(
            offer.approval == 'requested'
                ? AppL10n.of(context).studyPlansWaitingForAParent
                : AppL10n.of(context).studyPlansAskAParentToApprove,
          ),
        );
      } else {
        action = FilledButton.icon(
          onPressed: _busy || !offer.canPurchase || !links
              ? null
              : () => _perform(
                  () => subscriptions.purchase(tier),
                  AppL10n.of(context).studyPlansOpeningTheStore,
                ),
          icon: const Icon(Icons.lock_open_rounded),
          label: Text(
            offer.oneMonthTrial
                ? AppL10n.of(context).studyPlansStartAFreeMonth
                : AppL10n.of(context).studyPlansSubscribeToName(copy.name),
          ),
        );
      }
    }

    final price = tier == StudyPlanTier.free
        ? AppL10n.of(context).studyPlansFree
        : (offer != null && offer.storeAvailable && offer.price.isNotEmpty)
        ? AppL10n.of(context).studyPlansPriceMonth(offer.price)
        : AppL10n.of(context).studyPlansUspriceMonthInTheUs(copy.usPrice);

    return Card(
      margin: const EdgeInsets.only(bottom: 14),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: current
            ? BorderSide(color: theme.colorScheme.primary, width: 2)
            : BorderSide.none,
      ),
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
                  Chip(label: Text(AppL10n.of(context).studyPlansYourPlan)),
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
                    Expanded(child: Text(feature(AppL10n.of(context)))),
                  ],
                ),
              ),
            if (current && tier != StudyPlanTier.free) ...[
              const SizedBox(height: 10),
              TextButton(
                onPressed: () => _open(_manageUrl),
                child: Text(AppL10n.of(context).studyPlansManageOrCancel),
              ),
            ] else if (action != null) ...[
              const SizedBox(height: 12),
              action,
            ],
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final plan = _plan;
    final subscriptions = widget.subscriptions;
    return Scaffold(
      appBar: AppBar(title: Text(AppL10n.of(context).studentLessonsPlans)),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
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
                  for (final tier in StudyPlanTier.values) _planCard(tier),
                  if (_busy) const LinearProgressIndicator(),
                  if (_message != null)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      child: Text(_message!),
                    ),
                  if (subscriptions != null)
                    TextButton(
                      onPressed: _busy
                          ? null
                          : () => _perform(
                              subscriptions.restorePurchases,
                              AppL10n.of(context).studyPlansRestoringPurchases,
                            ),
                      child: Text(
                        AppL10n.of(context).studyPlansRestorePurchases,
                      ),
                    ),
                  const SizedBox(height: 8),
                  Text(
                    AppL10n.of(context)
                        .studyPlansAutoRenewingMonthlySubscriptionsPayment,
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                  Wrap(
                    children: [
                      TextButton(
                        onPressed: _validUrl(_terms)
                            ? () => _open(_terms)
                            : null,
                        child: Text(AppL10n.of(context).studyPlansTermsOfUse),
                      ),
                      TextButton(
                        onPressed: _validUrl(_privacy)
                            ? () => _open(_privacy)
                            : null,
                        child: Text(
                          AppL10n.of(context).studyPlansPrivacyPolicy,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
    );
  }
}
