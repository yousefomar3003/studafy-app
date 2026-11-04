import 'dart:async';

import 'package:flutter/material.dart';

import '../../../core/feedback.dart';
import '../../../core/studafy_design.dart';
import '../../../l10n/generated/app_l10n.dart';
import '../domain/marking.dart';
import 'marking_plan_page.dart';
import 'marking_references_page.dart';

/// An assessment's suggested marks as a marking screen holds them: the
/// plan, the references, the suggestions and the last request. While some
/// are still on their way it looks again every few seconds.
class MarkingSuggestionsController extends ChangeNotifier {
  MarkingSuggestionsController(this.services, this.assessmentId);

  final MarkingServices services;
  final String assessmentId;

  MarkingPlan? plan;
  MarkingReferences? references;
  MarkingSuggestions suggestions = MarkingSuggestions.none;

  /// What the teacher's last request queued, until they leave.
  MarkingRun? lastRun;
  bool busy = false;
  Timer? _poll;
  bool _disposed = false;

  static const pollEvery = Duration(seconds: 5);

  /// Suggestions can be asked for here: the server makes them.
  bool get offered => plan?.available ?? false;

  /// Work whose AI Marking prompt the teacher hid, until the app closes.
  static final _promptHidden = <String>{};

  bool get promptHidden => _promptHidden.contains(assessmentId);

  /// Hides the prompt for this work for the rest of the session.
  void hidePrompt() {
    _promptHidden.add(assessmentId);
    notifyListeners();
  }

  @visibleForTesting
  static void showPromptsAgain() => _promptHidden.clear();

  /// Opens the plan from the prompt, then reads the plan again: the teacher
  /// may have subscribed.
  Future<void> seePlan(BuildContext context) async {
    await openMarkingPlan(context, services);
    await load();
  }

  Future<void> load() async {
    _poll?.cancel();
    final repository = services.repository;
    final (plan, references, suggestions) = await (
      repository.plan().then<MarkingPlan?>(
        (value) => value,
        onError: (Object _) => null,
      ),
      repository
          .references(assessmentId)
          .then<MarkingReferences?>(
            (value) => value,
            onError: (Object _) => null,
          ),
      repository
          .suggestions(assessmentId)
          .then<MarkingSuggestions?>(
            (value) => value,
            onError: (Object _) => null,
          ),
    ).wait;
    if (_disposed) return;
    this.plan = plan ?? this.plan;
    this.references = references ?? this.references;
    this.suggestions = suggestions ?? this.suggestions;
    notifyListeners();
    if (this.suggestions.count(MarkingSuggestionStatus.pending) > 0) {
      _poll = Timer(pollEvery, load);
    }
  }

  /// Asks for suggestions - after the plan, when the teacher has none.
  Future<void> request(
    BuildContext context, {
    bool all = false,
    List<String>? studentIds,
  }) async {
    if (busy) return;
    if (plan != null && !plan!.active) {
      await openMarkingPlan(context, services);
      await load();
      return;
    }
    busy = true;
    notifyListeners();
    final run = await askForMarkingSuggestions(
      context,
      services,
      assessmentId,
      all: all,
      studentIds: studentIds,
    );
    if (_disposed) return;
    busy = false;
    lastRun = run ?? lastRun;
    await load();
  }

  /// Asks again for the students whose suggestions are from an older
  /// reference.
  Future<void> suggestAgainStale(BuildContext context) => request(
    context,
    all: true,
    studentIds: {
      for (final s in suggestions.items)
        if (s.stale) s.studentId,
    }.toList(),
  );

  /// Takes a suggestion off the teacher's list. Nothing else changes.
  Future<void> dismiss(BuildContext context, MarkingSuggestion s) async {
    final messenger = ScaffoldMessenger.of(context);
    final failed = AppL10n.of(context).markingDismissFailed;
    try {
      await services.repository.dismiss(s.id);
    } on Object {
      messenger.showMessage(failed);
      return;
    }
    if (_disposed) return;
    suggestions = MarkingSuggestions(
      strictness: suggestions.strictness,
      referenceVersion: suggestions.referenceVersion,
      items: [
        for (final item in suggestions.items)
          if (item.id != s.id) item,
      ],
    );
    notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    _poll?.cancel();
    super.dispose();
  }
}

/// "Suggest marks" on a marking screen: how the suggestions stand, what
/// the last request did, and the reminder that they are drafts.
class MarkingSuggestionsBar extends StatelessWidget {
  const MarkingSuggestionsBar({
    super.key,
    required this.controller,
    this.enabled = true,
    this.waiting = 0,
    this.handIns = false,
  });

  final MarkingSuggestionsController controller;
  final bool enabled;

  /// How much is waiting for a mark on this screen: submissions with
  /// written answers, or - [handIns] - students with no mark on the sheet.
  /// A teacher without the plan is told about it once, at this moment.
  final int waiting;
  final bool handIns;

  Future<void> _suggest(BuildContext context) async {
    final plan = controller.plan;
    if (plan != null && !plan.active) {
      await controller.request(context);
      return;
    }
    final all = await showDialog<bool>(
      context: context,
      builder: (_) => const _ScopeDialog(),
    );
    if (all == null || !context.mounted) return;
    await controller.request(context, all: all);
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: controller,
    builder: (context, _) {
      if (!controller.offered) return const SizedBox.shrink();
      final l10n = AppL10n.of(context);
      final theme = Theme.of(context);
      final s = controller.suggestions;
      final run = controller.lastRun;
      final pending = s.count(MarkingSuggestionStatus.pending);
      final ready = s.count(MarkingSuggestionStatus.ready);
      final busy = controller.busy || !enabled;
      final plan = controller.plan;
      // Only without the plan, only with work waiting, and not once hidden:
      // with the plan the button below is all there is.
      final prompt =
          plan != null &&
          !plan.active &&
          waiting > 0 &&
          !controller.promptHidden;
      return Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: FeatureCard(
          padding: const EdgeInsetsDirectional.fromSTEB(14, 10, 8, 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  const Icon(Icons.auto_awesome_outlined, color: studafyNavy),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      l10n.markingSuggestTitle,
                      style: theme.textTheme.titleSmall,
                    ),
                  ),
                  IconButton(
                    tooltip: l10n.markingRefresh,
                    onPressed: busy ? null : controller.load,
                    icon: const Icon(Icons.refresh_rounded),
                  ),
                ],
              ),
              if (prompt)
                Padding(
                  padding: const EdgeInsets.only(top: 2, bottom: 8),
                  child: MarkingPlanPrompt(
                    message: handIns
                        ? l10n.markingPromptHandIns(waiting)
                        : l10n.markingPromptAnswers(waiting),
                    onSeeHow: busy ? null : () => controller.seePlan(context),
                    onHide: controller.hidePrompt,
                  ),
                ),
              Text(
                l10n.markingSuggestDraftNote,
                style: theme.textTheme.bodySmall,
              ),
              if (run != null) ...[
                const SizedBox(height: 6),
                Text(l10n.markingRunQueued(run.queued)),
                if (run.optedOut > 0)
                  Text(l10n.markingRunOptedOut(run.optedOut)),
              ],
              if (pending + ready > 0)
                Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: Semantics(
                    liveRegion: true,
                    child: Text(l10n.markingStatusCounts(ready, pending)),
                  ),
                ),
              if (s.stale > 0)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: MarkingStaleBanner(
                    count: s.stale,
                    onSuggestAgain: busy
                        ? null
                        : () => controller.suggestAgainStale(context),
                  ),
                ),
              const SizedBox(height: 8),
              Align(
                alignment: AlignmentDirectional.centerStart,
                child: FilledButton.tonalIcon(
                  onPressed: busy ? null : () => _suggest(context),
                  icon: controller.busy
                      ? const SizedBox.square(
                          dimension: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.auto_awesome_outlined),
                  label: Text(l10n.markingSuggestAction),
                ),
              ),
            ],
          ),
        ),
      );
    },
  );
}

/// A teacher without Studafy AI Marking, at the moment work is waiting:
/// how much, that AI can suggest the marks, and the way to see how. It can
/// be hidden for the rest of the session.
class MarkingPlanPrompt extends StatelessWidget {
  const MarkingPlanPrompt({
    super.key,
    required this.message,
    required this.onSeeHow,
    required this.onHide,
  });

  final String message;
  final VoidCallback? onSeeHow;
  final VoidCallback onHide;

  @override
  Widget build(BuildContext context) {
    final l10n = AppL10n.of(context);
    return Container(
      padding: const EdgeInsetsDirectional.fromSTEB(12, 10, 4, 4),
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
                  Icons.lightbulb_outline_rounded,
                  size: 18,
                  color: studafyNavy,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  message,
                  style: const TextStyle(color: studafyInk, height: 1.35),
                ),
              ),
              IconButton(
                tooltip: l10n.markingPromptHide,
                visualDensity: VisualDensity.compact,
                onPressed: onHide,
                icon: const Icon(Icons.close_rounded, size: 18),
              ),
            ],
          ),
          TextButton(
            onPressed: onSeeHow,
            child: Text(l10n.markingPromptSeeHow),
          ),
        ],
      ),
    );
  }
}

/// Unmarked work only (the default), or everything again.
class _ScopeDialog extends StatefulWidget {
  const _ScopeDialog();

  @override
  State<_ScopeDialog> createState() => _ScopeDialogState();
}

class _ScopeDialogState extends State<_ScopeDialog> {
  bool _all = false;

  @override
  Widget build(BuildContext context) {
    final l10n = AppL10n.of(context);
    return AlertDialog(
      title: Text(l10n.markingSuggestAction),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(l10n.markingSuggestScopeBody),
            const SizedBox(height: 8),
            RadioGroup<bool>(
              groupValue: _all,
              onChanged: (value) => setState(() => _all = value ?? false),
              child: Column(
                children: [
                  RadioListTile<bool>(
                    value: false,
                    contentPadding: EdgeInsets.zero,
                    title: Text(l10n.markingSuggestScopeUnmarked),
                  ),
                  RadioListTile<bool>(
                    value: true,
                    contentPadding: EdgeInsets.zero,
                    title: Text(l10n.markingSuggestScopeAll),
                  ),
                ],
              ),
            ),
            Text(
              l10n.markingSuggestDraftNote,
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(l10n.linksCancel),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(context, _all),
          child: Text(l10n.markingSuggestStart),
        ),
      ],
    );
  }
}
