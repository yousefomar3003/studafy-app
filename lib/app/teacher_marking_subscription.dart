import 'package:flutter/widgets.dart';

import '../core/ai_usage.dart';
import '../features/academic/presentation/marking_plan_page.dart';
import '../features/academic/presentation/marking_scope.dart';
import '../l10n/generated/app_l10n.dart';
import 'account_hub_page.dart';

/// The Subscription part of a teacher's profile: Studafy AI Marking, the
/// teacher's own plan (ADR-0046), and Restore purchases where a store sells
/// it. Null in builds that cannot sell it.
SubscriptionEntry? teacherMarkingSubscription(BuildContext context) {
  final services = MarkingScope.maybeOf(context);
  final store = services?.plans;
  if (services == null || store == null) return null;
  final reached = AppL10n.of(context).markingUsageReached;
  return SubscriptionEntry(
    title: markingPlanName,
    detail: AppL10n.of(context).markingPlanAccountDetail,
    open: (context) => openMarkingPlan(context, services),
    currentPlan: () async =>
        (await services.repository.plan()).active ? markingPlanName : null,
    // This month's AI Marking allowance, as a bar, while the plan is held
    // (7,000,000 tokens a month, 2026-11-03); nothing without it.
    usageTitle: AppL10n.of(context).markingUsageTitle,
    usage: () async {
      final plan = await services.repository.plan();
      if (!plan.active) return null;
      return AiUsageSnapshot(
        planName: markingPlanName,
        used: plan.used,
        total: plan.total,
        resetsAt: plan.resetsAt,
        weekly: false,
        canUpgrade: false,
        showPlans: false,
        reachedDetail: reached,
      );
    },
    // Only where a store sells the plan (not the web or desktop).
    restorePurchases: store.sellsMarkingPlan ? store.restorePurchases : null,
  );
}
