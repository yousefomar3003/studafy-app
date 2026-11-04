import 'package:flutter/material.dart';

import '../../../core/ai_usage.dart';
import '../../../core/studafy_components.dart';
import '../../../core/studafy_design.dart';
import '../../../l10n/generated/app_l10n.dart';
import '../domain/marking.dart';
import 'marking_plan_page.dart';
import 'marking_scope.dart';

/// This month's Studafy AI Marking allowance as every usage card shows it:
/// a bar and a label, never a count. Used by Account and the teacher's home.
/// [reachedDetail] is `markingUsageReached`, read before any await.
AiUsageSnapshot markingUsageSnapshot(
  MarkingPlan plan, {
  required String reachedDetail,
}) => AiUsageSnapshot(
  planName: markingPlanName,
  used: plan.used,
  total: plan.total,
  resetsAt: plan.resetsAt,
  weekly: false,
  canUpgrade: false,
  showPlans: false,
  reachedDetail: reachedDetail,
);

/// Studafy AI Marking on the teacher's home, kept quiet.
///
/// Without the plan: one card saying what it does, opening the plan page.
/// With it: nothing while there is plenty left (Account shows the bar), and
/// the bar only once it runs low or out, so the teacher is not surprised
/// when suggestions stop. Nothing at all where the app cannot sell the
/// plan, where the server makes no suggestions, or for anyone the server
/// does not count as a teacher.
class MarkingHomeCard extends StatefulWidget {
  const MarkingHomeCard({
    super.key,
    this.padding = const EdgeInsets.only(top: 16),
  });

  /// Around the card when it shows; nothing when it does not.
  final EdgeInsetsGeometry padding;

  @override
  State<MarkingHomeCard> createState() => _MarkingHomeCardState();
}

class _MarkingHomeCardState extends State<MarkingHomeCard> {
  MarkingServices? _services;
  MarkingPlan? _plan;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final services = MarkingScope.maybeOf(context);
    if (services == _services) return;
    _services?.plans?.removeEntitlementListener(_load);
    _services = services;
    services?.plans?.addEntitlementListener(_load);
    _load();
  }

  @override
  void dispose() {
    _services?.plans?.removeEntitlementListener(_load);
    super.dispose();
  }

  Future<void> _load() async {
    final services = _services;
    if (services == null || services.plans == null) return;
    MarkingPlan? plan;
    try {
      plan = await services.repository.plan();
    } on Object {
      plan = null;
    }
    if (mounted) setState(() => _plan = plan);
  }

  Future<void> _open() async {
    final services = _services;
    if (services == null) return;
    await openMarkingPlan(context, services);
    await _load();
  }

  @override
  Widget build(BuildContext context) {
    final plan = _plan;
    if (_services?.plans == null ||
        plan == null ||
        !plan.teacher ||
        !plan.available) {
      return const SizedBox.shrink();
    }
    final Widget card;
    if (plan.active) {
      final usage = markingUsageSnapshot(
        plan,
        reachedDetail: AppL10n.of(context).markingUsageReached,
      );
      if (usage.level == AiUsageLevel.plenty) return const SizedBox.shrink();
      card = FeatureCard(
        onTap: _open,
        child: AiUsageCard(usage: usage, compact: true),
      );
    } else {
      card = _Offer(onOpen: _open);
    }
    return Padding(padding: widget.padding, child: card);
  }
}

/// The card for a teacher without the plan.
class _Offer extends StatelessWidget {
  const _Offer({required this.onOpen});

  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context) {
    final l10n = AppL10n.of(context);
    return FeatureCard(
      tint: studafySky,
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const IconBadge(icon: Icons.auto_awesome_outlined, size: 40),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      markingPlanName,
                      style: const TextStyle(
                        color: studafyInk,
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      l10n.markingPlanHeadline,
                      style: const TextStyle(
                        color: studafyMuted,
                        fontSize: 13,
                        height: 1.35,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          StudafyPillButton(
            icon: Icons.visibility_outlined,
            label: l10n.markingHomeCardAction,
            onPressed: onOpen,
          ),
        ],
      ),
    );
  }
}
