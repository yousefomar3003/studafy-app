import 'package:flutter/material.dart';

import '../../../core/studafy_design.dart';
import '../../../l10n/generated/app_l10n.dart';
import '../domain/study.dart';
import 'study_plan_copy.dart';

/// Which limit of the student's plan was reached.
enum UpgradeReason {
  /// The plan's AI tokens are used (ADR-0037).
  tokensUsed,

  /// The feature belongs to a higher plan.
  feature,
}

/// The reason behind a refusal from the server, or null when the refusal is
/// not about the plan.
UpgradeReason? upgradeReasonFor(StudyRefusal refusal) => switch (refusal) {
  StudyRefusal.allowanceUsed => UpgradeReason.tokensUsed,
  StudyRefusal.planRequired => UpgradeReason.feature,
  _ => null,
};

/// Tells a student which limit they reached and what the next plan adds,
/// with an Upgrade button that opens the Plans screen. It only explains:
/// the Plans screen shows the store's price and terms before anything is
/// bought. On Studafy Max there is nothing to upgrade to, so it says so.
///
/// [needs] is the plan a [UpgradeReason.feature] belongs to.
Future<void> showUpgradePrompt(
  BuildContext context, {
  required UpgradeReason reason,
  required StudyPlan? plan,
  StudyPlanTier? needs,
  required VoidCallback onUpgrade,
}) {
  final tier = plan?.tier ?? StudyPlanTier.free;
  final target = switch (reason) {
    UpgradeReason.feature => needs ?? tier.next,
    _ => tier.next,
  };
  return showModalBottomSheet<void>(
    context: context,
    showDragHandle: true,
    isScrollControlled: true,
    builder: (sheet) => UpgradePrompt(
      reason: reason,
      plan: plan,
      target: target != null && !tier.includes(target) ? target : null,
      onUpgrade: () {
        Navigator.of(sheet).pop();
        onUpgrade();
      },
    ),
  );
}

class UpgradePrompt extends StatelessWidget {
  const UpgradePrompt({
    super.key,
    required this.reason,
    required this.plan,
    required this.target,
    required this.onUpgrade,
  });

  final UpgradeReason reason;
  final StudyPlan? plan;

  /// The plan to offer; null when there is none above the student's.
  final StudyPlanTier? target;
  final VoidCallback onUpgrade;

  @override
  Widget build(BuildContext context) {
    final l10n = AppL10n.of(context);
    final theme = Theme.of(context);
    final target = this.target;
    final copy = target == null ? null : studyPlanCopy[target]!;
    final (title, body) = switch (reason) {
      UpgradeReason.tokensUsed => (
        l10n.upgradeTokensTitle,
        switch (plan?.allowance) {
          final allowance? when allowance.resetsAt.year < 2100 =>
            l10n.upgradeTokensBody(
              MaterialLocalizations.of(context)
                  .formatMediumDate(allowance.resetsAt),
            ),
          _ => l10n.upgradeAllowanceBody,
        },
      ),
      UpgradeReason.feature => (
        l10n.upgradeFeatureTitle(copy?.name ?? 'Studafy Plus'),
        l10n.upgradeFeatureBody,
      ),
    };
    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Icon(
              Icons.workspace_premium_rounded,
              size: 36,
              color: studafyCyan,
            ),
            const SizedBox(height: 10),
            Text(
              title,
              style: theme.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 6),
            Text(body),
            if (copy != null) ...[
              const SizedBox(height: 16),
              Text(
                l10n.upgradeWhatUnlocks(copy.name),
                style: theme.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 6),
              for (final feature in copy.adds)
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
            ] else ...[
              const SizedBox(height: 12),
              Text(l10n.upgradeTopPlan, style: theme.textTheme.bodySmall),
            ],
            const SizedBox(height: 20),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                if (copy != null) ...[
                  TextButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: Text(l10n.upgradeNotNow),
                  ),
                  const SizedBox(width: 8),
                  FilledButton.icon(
                    onPressed: onUpgrade,
                    icon: const Icon(Icons.lock_open_rounded),
                    label: Text(l10n.upgradeButton),
                  ),
                ] else
                  FilledButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: Text(
                      MaterialLocalizations.of(context).okButtonLabel,
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
