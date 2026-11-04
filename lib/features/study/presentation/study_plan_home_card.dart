import 'package:flutter/material.dart';

import '../../../core/studafy_components.dart';
import '../../../l10n/generated/app_l10n.dart';
import '../domain/study.dart';

/// The next plan up, on the student's Today: Studafy Plus or Max for a
/// student on Free, Max for a student on Plus, in one card with one benefit
/// and See plans. When most of the AI allowance is used, the benefit line
/// says so instead ("You've used most of this week's AI...").
///
/// Nothing at all on Max; where this build cannot sell the plans (no store:
/// the web and desktop, or no billing); where the server has the AI tools
/// off or the next plan's tool switched off; when a parent pays for the
/// plan (only they can change it); or once hidden, until the app closes.
class StudyPlanHomeCard extends StatefulWidget {
  const StudyPlanHomeCard({
    super.key,
    required this.study,
    required this.subscriptions,
    required this.onOpen,
    this.padding = const EdgeInsets.only(top: 16),
  });

  final StudyRepository study;

  /// Buying the plans; null without billing.
  final StudyPlanSubscriptionRepository? subscriptions;

  /// Opens the Plans screen at the plan the card speaks of.
  final Future<void> Function(StudyPlanTier focus) onOpen;

  /// Around the card when it shows; nothing when it does not.
  final EdgeInsetsGeometry padding;

  /// Hidden by the student, until the app closes.
  static bool _hidden = false;

  @visibleForTesting
  static void showAgain() => _hidden = false;

  @override
  State<StudyPlanHomeCard> createState() => _StudyPlanHomeCardState();
}

class _StudyPlanHomeCardState extends State<StudyPlanHomeCard> {
  StudyPlan? _plan;

  @override
  void initState() {
    super.initState();
    widget.subscriptions?.addEntitlementListener(_load);
    _load();
  }

  @override
  void didUpdateWidget(StudyPlanHomeCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.subscriptions != widget.subscriptions) {
      oldWidget.subscriptions?.removeEntitlementListener(_load);
      widget.subscriptions?.addEntitlementListener(_load);
    }
  }

  @override
  void dispose() {
    widget.subscriptions?.removeEntitlementListener(_load);
    super.dispose();
  }

  Future<void> _load() async {
    final subscriptions = widget.subscriptions;
    if (subscriptions == null || subscriptions.purchaseStore == null) return;
    StudyPlan? plan;
    try {
      plan = await widget.study.plan();
    } on Object {
      plan = null;
    }
    // A plan a parent pays for is theirs to change: nothing to offer here.
    if (plan != null && plan.tier != StudyPlanTier.free) {
      try {
        final current = await subscriptions.subscription();
        if (current != null && !current.paidByMe) plan = null;
      } on Object {
        // Unknown: the Plans screen says if it cannot be changed.
      }
    }
    if (mounted) setState(() => _plan = plan);
  }

  Future<void> _open(StudyPlanTier focus) async {
    await widget.onOpen(focus);
    await _load();
  }

  @override
  Widget build(BuildContext context) {
    final plan = _plan;
    final target = plan?.tier.next;
    if (plan == null ||
        target == null ||
        StudyPlanHomeCard._hidden ||
        !plan.anyToolOn ||
        !(target == StudyPlanTier.plus
            ? plan.whiteboardOn
            : plan.studySetsOn)) {
      return const SizedBox.shrink();
    }
    final l10n = AppL10n.of(context);
    final free = plan.tier == StudyPlanTier.free;
    // Most of the allowance used: the moment more of it means something.
    final low = plan.allowance.usedFraction >= .75;
    return Padding(
      padding: widget.padding,
      child: PlanOfferCard(
        icon: Icons.workspace_premium_outlined,
        title: free ? l10n.studyHomeCardFreeTitle : l10n.studyHomeCardPlusTitle,
        body: switch ((free, low)) {
          (true, true) => l10n.studyPromptWeekLow,
          (false, true) => l10n.studyPromptMonthLow,
          (true, false) => l10n.studyHomeCardFreeBody,
          (false, false) => l10n.studyHomeCardPlusBody,
        },
        actionLabel: l10n.nbSeePlans,
        onAction: () => _open(target),
        hideLabel: l10n.planPromptHide,
        onHide: () => setState(() => StudyPlanHomeCard._hidden = true),
      ),
    );
  }
}
