import 'package:flutter/widgets.dart';

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
  return SubscriptionEntry(
    title: markingPlanName,
    detail: AppL10n.of(context).markingPlanAccountDetail,
    open: (context) => openMarkingPlan(context, services),
    currentPlan: () async =>
        (await services.repository.plan()).active ? markingPlanName : null,
    // Only where a store sells the plan (not the web or desktop).
    restorePurchases: store.sellsMarkingPlan ? store.restorePurchases : null,
  );
}
