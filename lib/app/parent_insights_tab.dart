import 'package:flutter/material.dart';

import '../core/navigation.dart';
import '../core/studafy_components.dart';
import '../features/family/domain/family.dart';
import '../features/family/presentation/linked_child_switcher.dart';
import '../features/family_insights/application/family_insights_interactor.dart';
import '../features/family_insights/domain/parent_subscription_repository.dart';
import '../features/family_insights/presentation/family_insights_page.dart';
import '../features/family_insights/presentation/family_plus_gate.dart';
import '../l10n/generated/app_l10n.dart';

/// The Family+ tab.
///
/// With no child selected there is nothing to report on, which is a different
/// state from "you have not paid" and says so.
class ParentInsightsTab extends StatelessWidget {
  const ParentInsightsTab({
    super.key,
    required this.insights,
    required this.familyPlus,
    required this.childName,
    required this.studentId,
    required this.onSelectChild,
    required this.severalChildren,
  });

  final FamilyInsightsInteractor insights;
  final ParentSubscriptionRepository? familyPlus;
  final String childName;
  final String? studentId;
  final ValueChanged<GuardianChild> onSelectChild;
  final bool severalChildren;

  @override
  Widget build(BuildContext context) {
    final l10n = AppL10n.of(context);
    final id = studentId;
    if (id == null) {
      return Scaffold(
        body: Column(
          children: [
            StudafyLargeTitle(title: l10n.insightsTitle),
            Expanded(
              child: Center(
                child: StudafyEmptyState(
                  icon: Icons.child_care_outlined,
                  title: l10n.insightsNoChildTitle,
                  message: l10n.insightsNoChildBody,
                ),
              ),
            ),
          ],
        ),
      );
    }
    // No profile button here: it is on Today. Which child, when there are
    // several - and, once subscribed, the plan.
    final switcher = [
      if (severalChildren) LinkedChildSwitcher(onSelect: onSelectChild),
    ];
    // Keyed by child, so switching child checks that child's Family+.
    return FamilyPlusGate(
      key: ValueKey(id),
      subscriptions: familyPlus,
      studentId: id,
      childName: childName,
      actions: switcher,
      insights: FamilyInsightsPage(
        insights: insights,
        studentId: id,
        actions: [
          ...switcher,
          Padding(
            padding: const EdgeInsetsDirectional.only(end: 8),
            child: StudafyPillButton(
              icon: Icons.workspace_premium_rounded,
              label: l10n.familyPlusManagePlan,
              onPressed: () => Navigator.of(context).pushOnce(
                MaterialPageRoute<void>(
                  builder: (_) => Scaffold(
                    appBar: AppBar(title: Text(l10n.insightsTitle)),
                    body: FamilyPlusOffer(
                      subscriptions: familyPlus,
                      studentId: id,
                      childName: childName,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
