import 'package:flutter/material.dart';

import '../../../core/studafy_components.dart';
import '../../../core/studafy_design.dart';
import '../../../core/studafy_formatting.dart';
import '../../../l10n/generated/app_l10n.dart';
import '../domain/parent_subscription_repository.dart';

/// Family+ on the parent's Today: one card saying what it shows, opening
/// the Family+ page.
///
/// Only for a parent with at least one linked child and no Family+ - no
/// family plan, and no child unlocked by an older per-child subscription.
/// Nothing where this build cannot sell Family+, while the plan is being
/// read, or once hidden, until the app closes.
class FamilyPlusHomeCard extends StatefulWidget {
  const FamilyPlusHomeCard({
    super.key,
    required this.subscriptions,
    required this.studentIds,
    required this.onOpen,
  });

  final ParentSubscriptionRepository? subscriptions;

  /// The linked, approved children.
  final List<String> studentIds;
  final VoidCallback onOpen;

  static bool _hidden = false;

  @visibleForTesting
  static void showAgain() => _hidden = false;

  @override
  State<FamilyPlusHomeCard> createState() => _FamilyPlusHomeCardState();
}

class _FamilyPlusHomeCardState extends State<FamilyPlusHomeCard> {
  /// True once the server says no child here has Family+.
  bool _offer = false;

  @override
  void initState() {
    super.initState();
    widget.subscriptions?.addEntitlementListener(_load);
    _load();
  }

  @override
  void didUpdateWidget(FamilyPlusHomeCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.subscriptions != widget.subscriptions) {
      oldWidget.subscriptions?.removeEntitlementListener(_load);
      widget.subscriptions?.addEntitlementListener(_load);
    }
    if (oldWidget.studentIds.join() != widget.studentIds.join()) _load();
  }

  @override
  void dispose() {
    widget.subscriptions?.removeEntitlementListener(_load);
    super.dispose();
  }

  Future<void> _load() async {
    final subscriptions = widget.subscriptions;
    final children = widget.studentIds;
    var offer = false;
    if (subscriptions != null &&
        subscriptions.sellsFamilyPlus &&
        children.isNotEmpty) {
      try {
        final status = await subscriptions.familyPlan();
        if (status.plan == null) {
          final unlocked = await Future.wait([
            for (final id in children)
              subscriptions
                  .entitlement(beneficiaryStudentId: id)
                  .then((entitlement) => entitlement.active),
          ]);
          offer = !unlocked.contains(true);
        }
      } on Object {
        // Unknown: say nothing rather than offer what may already be held.
        offer = false;
      }
    }
    if (mounted) setState(() => _offer = offer);
  }

  @override
  Widget build(BuildContext context) {
    if (!_offer || FamilyPlusHomeCard._hidden) return const SizedBox.shrink();
    final l10n = AppL10n.of(context);
    return Padding(
      padding: const EdgeInsets.only(top: 16),
      child: PlanOfferCard(
        icon: Icons.insights_rounded,
        title: studafyPlanName('Family+'),
        body: l10n.familyHomeCardBody,
        actionLabel: l10n.familyHomeCardAction,
        onAction: widget.onOpen,
        hideLabel: l10n.planPromptHide,
        onHide: () => setState(() => FamilyPlusHomeCard._hidden = true),
      ),
    );
  }
}

/// One line on a child's marks or attendance, for a parent without Family+
/// for that child: what Family+ would show for them, and the way to it. It
/// can be hidden for that child until the app closes.
class FamilyPlusNudge extends StatefulWidget {
  const FamilyPlusNudge({
    super.key,
    required this.subscriptions,
    required this.studentId,
    required this.childName,
    required this.onOpen,
  });

  final ParentSubscriptionRepository? subscriptions;
  final String studentId;
  final String childName;
  final VoidCallback onOpen;

  /// Children whose line the parent hid, until the app closes.
  static final _hidden = <String>{};

  @visibleForTesting
  static void showAgain() => _hidden.clear();

  @override
  State<FamilyPlusNudge> createState() => _FamilyPlusNudgeState();
}

class _FamilyPlusNudgeState extends State<FamilyPlusNudge> {
  bool _offer = false;

  @override
  void initState() {
    super.initState();
    widget.subscriptions?.addEntitlementListener(_load);
    _load();
  }

  @override
  void didUpdateWidget(FamilyPlusNudge oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.subscriptions != widget.subscriptions) {
      oldWidget.subscriptions?.removeEntitlementListener(_load);
      widget.subscriptions?.addEntitlementListener(_load);
    }
    if (oldWidget.studentId != widget.studentId) _load();
  }

  @override
  void dispose() {
    widget.subscriptions?.removeEntitlementListener(_load);
    super.dispose();
  }

  Future<void> _load() async {
    final subscriptions = widget.subscriptions;
    var offer = false;
    if (subscriptions != null && subscriptions.sellsFamilyPlus) {
      try {
        offer = !(await subscriptions.entitlement(
          beneficiaryStudentId: widget.studentId,
        )).active;
      } on Object {
        offer = false;
      }
    }
    if (mounted) setState(() => _offer = offer);
  }

  @override
  Widget build(BuildContext context) {
    if (!_offer || FamilyPlusNudge._hidden.contains(widget.studentId)) {
      return const SizedBox.shrink();
    }
    final l10n = AppL10n.of(context);
    return Padding(
      padding: const EdgeInsetsDirectional.fromSTEB(16, 10, 16, 0),
      child: Container(
        padding: const EdgeInsetsDirectional.fromSTEB(12, 8, 4, 4),
        decoration: BoxDecoration(
          color: studafyWash,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: studafyFrost.withValues(alpha: .7)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Padding(
                  padding: EdgeInsets.only(top: 2),
                  child: Icon(
                    Icons.insights_rounded,
                    size: 18,
                    color: studafyNavy,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    l10n.familyPlusNudge(widget.childName),
                    style: const TextStyle(color: studafyInk, height: 1.35),
                  ),
                ),
                IconButton(
                  tooltip: l10n.planPromptHide,
                  visualDensity: VisualDensity.compact,
                  onPressed: () => setState(
                    () => FamilyPlusNudge._hidden.add(widget.studentId),
                  ),
                  icon: const Icon(Icons.close_rounded, size: 18),
                ),
              ],
            ),
            TextButton(
              onPressed: widget.onOpen,
              child: Text(l10n.familyHomeCardAction),
            ),
          ],
        ),
      ),
    );
  }
}
