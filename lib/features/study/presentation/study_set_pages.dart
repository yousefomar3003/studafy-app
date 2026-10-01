import 'package:flutter/material.dart';

import '../../../core/feedback.dart';
import '../../../core/navigation.dart';
import '../../../core/studafy_components.dart';
import '../../../core/studafy_design.dart';
import '../../../core/user_content_text.dart';
import '../../../l10n/generated/app_l10n.dart';
import '../domain/study.dart';
import 'upgrade_prompt.dart';

/// Quiz and Flashcards buttons under a lesson. Studafy Max; on any other plan
/// they still show, with a lock and a "Studafy Max" badge, and explain what
/// Max adds with an Upgrade button to the Plans screen - a student should
/// see what the plan would give them. On a server with study sets switched
/// off they show and say so.
class StudySetButtons extends StatefulWidget {
  const StudySetButtons({
    super.key,
    required this.study,
    required this.resourceId,
    required this.lessonTitle,
    required this.plan,
    required this.onOpenPlans,
  });

  final StudyRepository study;
  final String resourceId;
  final String lessonTitle;

  /// The caller's plan, read once by the host for the whole list.
  final StudyPlan? plan;
  final VoidCallback onOpenPlans;

  @override
  State<StudySetButtons> createState() => _StudySetButtonsState();
}

class _StudySetButtonsState extends State<StudySetButtons> {
  StudySetKind? _making;

  /// The server has study sets switched off. Only a plan that says so counts:
  /// without one the server is asked, and it is the authority.
  bool get _switchedOff => !(widget.plan?.studySetsOn ?? true);

  bool get _locked => !(widget.plan?.canMakeStudySets ?? false);

  Future<void> _open(StudySetKind kind) async {
    final messenger = ScaffoldMessenger.of(context);
    if (_switchedOff) {
      messenger.showMessage(AppL10n.of(context).studySetSwitchedOff);
      return;
    }
    if (_locked) {
      await showUpgradePrompt(
        context,
        reason: UpgradeReason.feature,
        plan: widget.plan,
        needs: StudyPlanTier.max,
        onUpgrade: widget.onOpenPlans,
      );
      return;
    }
    setState(() => _making = kind);
    final navigator = Navigator.of(context);
    try {
      final set = await widget.study.studySet(widget.resourceId, kind);
      if (!mounted) return;
      await navigator.pushOnce(
        MaterialPageRoute<void>(
          builder: (_) => kind == StudySetKind.quiz
              ? QuizPage(title: widget.lessonTitle, questions: set.questions)
              : FlashcardsPage(title: widget.lessonTitle, cards: set.cards),
        ),
      );
    } on StudyException catch (error) {
      if (!mounted) return;
      final reason = upgradeReasonFor(error.refusal);
      if (reason != null) {
        await showUpgradePrompt(
          context,
          reason: reason,
          plan: widget.plan,
          needs: StudyPlanTier.max,
          onUpgrade: widget.onOpenPlans,
        );
        return;
      }
      messenger.showMessage(switch (error.refusal) {
        StudyRefusal.planRequired => AppL10n.of(
          context,
        ).studySetQuizzesAndFlashcardsComeWith,
        StudyRefusal.allowanceUsed => AppL10n.of(
          context,
        ).studySetThisMonthSAiAllowance,
        StudyRefusal.lessonHasNoText => AppL10n.of(
          context,
        ).studySetThisLessonHasNoText,
        StudyRefusal.unavailable => AppL10n.of(context).studySetSwitchedOff,
        _ => AppL10n.of(context).studySetThatDidNotWorkPlease,
      });
    } finally {
      if (mounted) setState(() => _making = null);
    }
  }

  @override
  Widget build(BuildContext context) {
    final off = _switchedOff;
    final locked = !off && _locked;
    final scheme = Theme.of(context).colorScheme;
    Widget button(StudySetKind kind, IconData icon, String label) =>
        OutlinedButton.icon(
          onPressed: _making != null ? null : () => _open(kind),
          // Shown, not usable: dimmed rather than disabled, so a tap can
          // still say why.
          style: off
              ? OutlinedButton.styleFrom(
                  foregroundColor: scheme.onSurface.withValues(alpha: .45),
                )
              : null,
          icon: _making == kind
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : Icon(locked ? Icons.lock_outline_rounded : icon, size: 18),
          label: Text(label),
        );
    return Padding(
      padding: const EdgeInsets.only(top: 10),
      child: Wrap(
        spacing: 8,
        runSpacing: 6,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          button(
            StudySetKind.quiz,
            Icons.quiz_outlined,
            AppL10n.of(context).studySetQuiz,
          ),
          button(
            StudySetKind.flashcards,
            Icons.style_outlined,
            AppL10n.of(context).studySetFlashcards,
          ),
          if (locked)
            ActionChip(
              avatar: const Icon(Icons.workspace_premium_outlined, size: 16),
              label: Text(AppL10n.of(context).studySetMaxBadge),
              tooltip: AppL10n.of(context).studySetQuizzesAndFlashcardsComeWith,
              onPressed: widget.onOpenPlans,
              visualDensity: VisualDensity.compact,
            ),
        ],
      ),
    );
  }
}

/// Quizzes and flashcards, named at the top of a class's lessons so a
/// student sees them before there is a lesson to make one from - and sees
/// that they come with Studafy Max, when their plan does not include them.
class StudyToolsCard extends StatelessWidget {
  const StudyToolsCard({
    super.key,
    required this.plan,
    required this.hasLessons,
    required this.onOpenPlans,
  });

  final StudyPlan? plan;
  final bool hasLessons;
  final VoidCallback onOpenPlans;

  @override
  Widget build(BuildContext context) {
    final l10n = AppL10n.of(context);
    final plan = this.plan;
    final off = plan != null && !plan.studySetsOn;
    final locked = !off && !(plan?.canMakeStudySets ?? false);
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: FeatureCard(
        onTap: locked ? onOpenPlans : null,
        padding: const EdgeInsetsDirectional.fromSTEB(14, 12, 12, 12),
        child: Row(
          children: [
            IconBadge(
              icon: locked ? Icons.lock_outline_rounded : Icons.style_rounded,
              color: locked ? studafyMuted : studafyTeal,
              size: 40,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    l10n.studyToolsTitle,
                    style: const TextStyle(
                      color: studafyInk,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    off
                        ? l10n.studySetSwitchedOff
                        : locked
                        ? l10n.studyToolsLocked
                        : hasLessons
                        ? l10n.studyToolsReady
                        : l10n.studyToolsNoLessons,
                    style: const TextStyle(color: studafyMuted, fontSize: 13),
                  ),
                ],
              ),
            ),
            if (locked) ...[
              const SizedBox(width: 8),
              StatusPill(
                label: l10n.studySetMaxBadge,
                icon: Icons.workspace_premium_rounded,
                color: studafyDeep,
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// A quiz: pick an answer, see at once whether it was right and why.
class QuizPage extends StatefulWidget {
  const QuizPage({super.key, required this.title, required this.questions});

  final String title;
  final List<QuizQuestion> questions;

  @override
  State<QuizPage> createState() => _QuizPageState();
}

class _QuizPageState extends State<QuizPage> {
  final Map<int, int> _answers = {};

  int get _score => [
    for (final entry in _answers.entries)
      if (widget.questions[entry.key].answerIndex == entry.value) 1,
  ].length;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final done = _answers.length == widget.questions.length;
    return Scaffold(
      appBar: AppBar(title: UserContentText(widget.title)),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text(
            done
                ? AppL10n.of(context).studySetYouScoredScoreOfQuestionscount(
                    _score,
                    widget.questions.length,
                  )
                : AppL10n.of(context)
                      .studySetAnswerscountOfQuestionscountAnswered(
                        _answers.length,
                        widget.questions.length,
                      ),
            style: theme.textTheme.titleMedium,
          ),
          const SizedBox(height: 12),
          for (var i = 0; i < widget.questions.length; i++)
            Card(
              margin: const EdgeInsets.only(bottom: 12),
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    UserContentText(
                      '${i + 1}. ${widget.questions[i].question}',
                      style: theme.textTheme.titleSmall,
                    ),
                    const SizedBox(height: 8),
                    for (var o = 0; o < widget.questions[i].options.length; o++)
                      _Option(
                        text: widget.questions[i].options[o],
                        chosen: _answers[i] == o,
                        revealed: _answers.containsKey(i),
                        correct: widget.questions[i].answerIndex == o,
                        onTap: _answers.containsKey(i)
                            ? null
                            : () => setState(() => _answers[i] = o),
                      ),
                    if (_answers.containsKey(i) &&
                        widget.questions[i].explanation.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(top: 6),
                        child: UserContentText(
                          widget.questions[i].explanation,
                          style: theme.textTheme.bodySmall,
                        ),
                      ),
                  ],
                ),
              ),
            ),
          if (done)
            FilledButton.icon(
              onPressed: () => setState(_answers.clear),
              icon: const Icon(Icons.refresh_rounded),
              label: Text(AppL10n.of(context).studySetTryAgain),
            ),
        ],
      ),
    );
  }
}

class _Option extends StatelessWidget {
  const _Option({
    required this.text,
    required this.chosen,
    required this.revealed,
    required this.correct,
    this.onTap,
  });

  final String text;
  final bool chosen;
  final bool revealed;
  final bool correct;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final Color? tint = !revealed
        ? null
        : correct
        ? Colors.green.withValues(alpha: .15)
        : chosen
        ? scheme.error.withValues(alpha: .12)
        : null;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Material(
        color: tint ?? scheme.surfaceContainerHighest.withValues(alpha: .5),
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            child: Row(
              children: [
                Icon(
                  !revealed
                      ? Icons.radio_button_unchecked_rounded
                      : correct
                      ? Icons.check_circle_rounded
                      : chosen
                      ? Icons.cancel_rounded
                      : Icons.radio_button_unchecked_rounded,
                  size: 20,
                  color: revealed && correct
                      ? Colors.green
                      : revealed && chosen
                      ? scheme.error
                      : null,
                ),
                const SizedBox(width: 10),
                Expanded(child: UserContentText(text)),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Flashcards: tap a card to turn it over, swipe for the next.
class FlashcardsPage extends StatefulWidget {
  const FlashcardsPage({super.key, required this.title, required this.cards});

  final String title;
  final List<Flashcard> cards;

  @override
  State<FlashcardsPage> createState() => _FlashcardsPageState();
}

class _FlashcardsPageState extends State<FlashcardsPage> {
  final _flipped = <int>{};
  int _page = 0;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(title: UserContentText(widget.title)),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(12),
            child: Text(
              AppL10n.of(
                context,
              ).studySetCardPageOfCardscountTap(_page + 1, widget.cards.length),
            ),
          ),
          Expanded(
            child: PageView.builder(
              itemCount: widget.cards.length,
              onPageChanged: (page) => setState(() => _page = page),
              itemBuilder: (context, i) {
                final back = _flipped.contains(i);
                return Padding(
                  padding: const EdgeInsets.all(20),
                  child: Material(
                    color: back
                        ? theme.colorScheme.secondaryContainer
                        : theme.colorScheme.primaryContainer,
                    borderRadius: BorderRadius.circular(24),
                    child: InkWell(
                      borderRadius: BorderRadius.circular(24),
                      onTap: () => setState(
                        () => back ? _flipped.remove(i) : _flipped.add(i),
                      ),
                      child: Center(
                        child: Padding(
                          padding: const EdgeInsets.all(24),
                          child: UserContentText(
                            back ? widget.cards[i].back : widget.cards[i].front,
                            style: back
                                ? theme.textTheme.titleMedium
                                : theme.textTheme.headlineSmall,
                          ),
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
