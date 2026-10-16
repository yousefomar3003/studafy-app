import 'package:flutter/material.dart';

import '../l10n/generated/app_l10n.dart';
import 'studafy_design.dart';
import 'studafy_formatting.dart';

/// AI usage as a person sees it (2026-10-07): a bar and a plain label, never
/// a count. Tokens are still what the server meters and limits; they stay
/// there.
enum AiUsageLevel {
  /// Under three-quarters used.
  plenty,

  /// A quarter or less left.
  low,

  /// Nothing left until it resets.
  reached,
}

/// The level for [used] of [total], as the server reports them.
AiUsageLevel aiUsageLevel({required int used, required int total}) {
  if (total <= 0 || used >= total) return AiUsageLevel.reached;
  return used / total >= .75 ? AiUsageLevel.low : AiUsageLevel.plenty;
}

String aiUsageLabel(AppL10n l10n, AiUsageLevel level) => switch (level) {
  AiUsageLevel.plenty => l10n.usagePlenty,
  AiUsageLevel.low => l10n.usageLow,
  AiUsageLevel.reached => l10n.usageReached,
};

/// "Plenty available · resets 13 Oct": the usage in one line.
String aiUsageLine(
  BuildContext context, {
  required AiUsageLevel level,
  required DateTime resetsAt,
}) {
  final l10n = AppL10n.of(context);
  return l10n.usageLine(
    aiUsageLabel(l10n, level),
    studafyMediumDate(context, resetsAt),
  );
}

/// One plan's usage, read from the server.
@immutable
class AiUsageSnapshot {
  const AiUsageSnapshot({
    required this.planName,
    required this.used,
    required this.total,
    required this.resetsAt,
    required this.weekly,
    this.canUpgrade = true,
  });

  final String planName;

  /// What the server metered; shown only as a fraction of the bar.
  final int used;
  final int total;
  final DateTime resetsAt;
  final bool weekly;
  final bool canUpgrade;

  double get fraction => total <= 0 ? 1 : (used / total).clamp(0, 1).toDouble();
  AiUsageLevel get level => aiUsageLevel(used: used, total: total);
}

/// The AI usage card: plan, bar, label, when it resets, and the plans.
class AiUsageCard extends StatelessWidget {
  const AiUsageCard({
    super.key,
    required this.usage,
    this.onPlans,
    this.compact = false,
  });

  final AiUsageSnapshot usage;

  /// Opens the plans, to compare them and upgrade.
  final VoidCallback? onPlans;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final l10n = AppL10n.of(context);
    final level = usage.level;
    final color = switch (level) {
      AiUsageLevel.plenty => studafyTeal,
      AiUsageLevel.low => const Color(0xFFB7791F),
      AiUsageLevel.reached => studafyDanger,
    };
    final resets = studafyMediumDate(context, usage.resetsAt);
    return Padding(
      padding: EdgeInsets.all(compact ? 0 : 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  l10n.usagePlan(usage.planName),
                  style: const TextStyle(
                    color: studafyInk,
                    fontWeight: FontWeight.w800,
                    fontSize: 15,
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
                  value: usage.fraction,
                  minHeight: 10,
                  color: color,
                  backgroundColor: studafyWash,
                ),
              ),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            usage.weekly
                ? l10n.usageResetsWeekly(resets)
                : l10n.usageResets(resets),
            style: const TextStyle(color: studafyMuted, fontSize: 13),
          ),
          if (level == AiUsageLevel.reached) ...[
            const SizedBox(height: 6),
            Text(
              l10n.usageReachedDetail,
              style: const TextStyle(color: studafyInk, fontSize: 13),
            ),
          ],
          if (onPlans != null) ...[
            const SizedBox(height: 12),
            Align(
              alignment: AlignmentDirectional.centerStart,
              child: usage.canUpgrade
                  ? FilledButton.icon(
                      onPressed: onPlans,
                      icon: const Icon(Icons.workspace_premium_rounded),
                      label: Text(l10n.usageUpgrade),
                    )
                  : OutlinedButton(
                      onPressed: onPlans,
                      child: Text(l10n.usageComparePlans),
                    ),
            ),
          ],
        ],
      ),
    );
  }
}
