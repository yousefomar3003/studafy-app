import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/ai_usage.dart';
import '../../../core/feedback.dart';
import '../../../core/navigation.dart';
import '../../../core/studafy_components.dart';
import '../../../core/studafy_design.dart';
import '../../../core/studafy_formatting.dart';
import '../../../l10n/generated/app_l10n.dart';
import '../domain/marking.dart';

/// The plan's name: Latin in every language, isolated inside Arabic text.
final markingPlanName = studafyPlanName('Studafy AI Marking');

/// Opens the Studafy AI Marking plan. Completes when the teacher leaves it.
Future<void> openMarkingPlan(BuildContext context, MarkingServices services) =>
    Navigator.of(context).pushOnce<void>(
      MaterialPageRoute<void>(
        builder: (_) => MarkingPlanPage(services: services),
      ),
    );

/// Studafy AI Marking: what it does, this month's allowance once it is held,
/// and the way to buy it - the teacher's own monthly subscription.
///
/// Follows the stores' rules as Family+ does: the price is the store's own,
/// checkout opens only over terms the store confirmed and working terms and
/// privacy links, and renewal, cancellation and restore are on the same
/// screen. On the web and desktop the plan is described, not sold.
class MarkingPlanPage extends StatefulWidget {
  const MarkingPlanPage({super.key, required this.services, this.openLink});

  final MarkingServices services;

  /// Opens a web page outside the app. Tests supply their own.
  final Future<bool> Function(Uri url)? openLink;

  @override
  State<MarkingPlanPage> createState() => _MarkingPlanPageState();
}

class _MarkingPlanPageState extends State<MarkingPlanPage> {
  static const _terms = String.fromEnvironment('STUDAFY_TERMS_URL');
  static const _privacy = String.fromEnvironment('STUDAFY_PRIVACY_URL');

  MarkingPlan? _plan;
  MarkingPlanOffer? _offer;
  bool _loading = true;
  bool _busy = false;
  String? _message;

  MarkingPlanStore? get _store => widget.services.plans;

  @override
  void initState() {
    super.initState();
    _store?.addEntitlementListener(_load);
    _load();
  }

  @override
  void dispose() {
    _store?.removeEntitlementListener(_load);
    super.dispose();
  }

  Future<void> _load() async {
    final store = _store;
    final (plan, offer) = await (
      widget.services.repository.plan().then<MarkingPlan?>(
        (plan) => plan,
        onError: (Object _) => null,
      ),
      store == null || !store.sellsMarkingPlan
          ? Future<MarkingPlanOffer?>.value()
          : store.markingOffer().then<MarkingPlanOffer?>(
              (offer) => offer,
              onError: (Object _) => null,
            ),
    ).wait;
    if (!mounted) return;
    setState(() {
      _plan = plan;
      _offer = offer;
      _loading = false;
    });
  }

  static bool _validUrl(String value) {
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
    final plan = _plan;
    final store = _store;
    final offer = _offer;
    final active = plan?.active ?? false;
    final sells = store != null && store.sellsMarkingPlan;
    final links = _validUrl(_terms) && _validUrl(_privacy);
    final canBuy = sells && (offer?.canPurchase ?? false) && links && !_busy;
    return Scaffold(
      appBar: AppBar(title: Text(markingPlanName)),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsetsDirectional.fromSTEB(16, 8, 16, 32),
          children: [
            PlanSummaryCard(
              eyebrow: l10n.markingPlanYours,
              planName: active ? markingPlanName : l10n.markingPlanNone,
              detail: active ? null : l10n.markingPlanHeadline,
            ),
            if (plan != null && active)
              Padding(
                padding: const EdgeInsets.only(top: 12),
                child: FeatureCard(child: MarkingAllowance(plan: plan)),
              ),
            if (plan != null && !plan.available && !active)
              Padding(
                padding: const EdgeInsets.only(top: 12),
                child: Text(l10n.markingPlanUnavailable),
              ),
            SectionHeader(l10n.markingPlanWhatYouGet),
            FeatureCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  for (final feature in [
                    l10n.markingPlanFeatureCompare,
                    l10n.markingPlanFeatureDetail,
                    l10n.markingPlanFeatureDecide,
                    l10n.markingPlanFeatureOptOut,
                    l10n.markingPlanFeaturePrivacy,
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
            const SizedBox(height: 16),
            if (!active) ...[
              if (offer != null && offer.canPurchase)
                Text(
                  l10n.familyPlusPrice(offer.price),
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
              if (!sells)
                Text(l10n.markingPlanOnlyInApp)
              else if (_loading)
                Text(l10n.familyPlusCheckingStore)
              else if (!(offer?.canPurchase ?? false))
                Text(l10n.familyPlusStoreUnavailable)
              else if (!links)
                Text(l10n.familyPlusCannotBuyYet),
              const SizedBox(height: 12),
              if (sells)
                FilledButton.icon(
                  onPressed: canBuy
                      ? () => _perform(
                          store.purchaseMarkingPlan,
                          l10n.familyPlusOpeningStore,
                        )
                      : null,
                  icon: const Icon(Icons.lock_open_rounded),
                  label: Text(l10n.markingPlanSubscribe),
                ),
            ],
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
            if (sells) ...[
              const SizedBox(height: 8),
              Wrap(
                children: [
                  TextButton(
                    onPressed: () => _open(_manageUrl),
                    child: Text(l10n.familyPlusManage),
                  ),
                  TextButton(
                    onPressed: _busy
                        ? null
                        : () => _perform(
                            store.restorePurchases,
                            l10n.accountRestoringPurchases,
                          ),
                    child: Text(l10n.accountRestorePurchases),
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
        ),
      ),
    );
  }
}

/// This month's allowance as a bar and a label - never a count - and when
/// it resets, as every AI plan shows it.
class MarkingAllowance extends StatelessWidget {
  const MarkingAllowance({super.key, required this.plan});

  final MarkingPlan plan;

  @override
  Widget build(BuildContext context) {
    final l10n = AppL10n.of(context);
    final level = aiUsageLevel(used: plan.used, total: plan.total);
    final color = switch (level) {
      AiUsageLevel.plenty => studafyTeal,
      AiUsageLevel.low => const Color(0xFFB7791F),
      AiUsageLevel.reached => studafyDanger,
    };
    final fraction = plan.total <= 0
        ? 1.0
        : (plan.used / plan.total).clamp(0, 1).toDouble();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                l10n.markingPlanThisMonth,
                style: const TextStyle(
                  color: studafyInk,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
            Text(
              aiUsageLabel(l10n, level),
              style: TextStyle(color: color, fontWeight: FontWeight.w800),
            ),
          ],
        ),
        const SizedBox(height: 10),
        Semantics(
          label: l10n.usageBarLabel(aiUsageLabel(l10n, level)),
          child: ExcludeSemantics(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(999),
              child: LinearProgressIndicator(
                value: fraction,
                minHeight: 10,
                color: color,
                backgroundColor: studafyWash,
              ),
            ),
          ),
        ),
        const SizedBox(height: 8),
        Text(
          l10n.usageResets(studafyMediumDate(context, plan.resetsAt.toLocal())),
          style: const TextStyle(color: studafyMuted, fontSize: 13),
        ),
        if (level == AiUsageLevel.reached) ...[
          const SizedBox(height: 6),
          Text(
            l10n.markingPlanReached,
            style: const TextStyle(color: studafyInk, fontSize: 13),
          ),
        ],
      ],
    );
  }
}

/// Asks for suggestions, opening the plan first when the teacher has none.
/// Says what happened in [messenger]; returns the run, or null.
Future<MarkingRun?> askForMarkingSuggestions(
  BuildContext context,
  MarkingServices services,
  String assessmentId, {
  bool all = false,
  List<String>? studentIds,
}) async {
  final l10n = AppL10n.of(context);
  final messenger = ScaffoldMessenger.of(context);
  try {
    return await services.repository.requestSuggestions(
      assessmentId,
      all: all,
      studentIds: studentIds,
    );
  } on MarkingRefusal catch (refusal) {
    switch (refusal.problem) {
      case MarkingProblem.planRequired:
        if (context.mounted) await openMarkingPlan(context, services);
      case MarkingProblem.unavailable:
        messenger.showMessage(l10n.markingPlanUnavailable);
      case MarkingProblem.nothingToRead:
        messenger.showMessage(l10n.markingNothingToRead);
      case MarkingProblem.notAllowed || MarkingProblem.invalid:
        messenger.showMessage(l10n.markingRequestFailed);
    }
  } on Object {
    messenger.showMessage(l10n.markingRequestFailed);
  }
  return null;
}
