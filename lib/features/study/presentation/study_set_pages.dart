import 'package:flutter/material.dart';

import '../../../core/feedback.dart';
import '../../../core/material_selection.dart';
import '../../../core/material_unavailable_dialog.dart';
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
    this.pick,
  });

  final StudyRepository study;
  final String resourceId;
  final String lessonTitle;

  /// Chooses exactly what the quiz or flashcards are made from, starting
  /// with this lesson (ADR-0039). Null makes them from the whole lesson.
  final MaterialPicker? pick;

  /// The caller's plan, read once by the host for the whole list.
  final StudyPlan? plan;
  final VoidCallback onOpenPlans;

  @override
  State<StudySetButtons> createState() => _StudySetButtonsState();
}

class _StudySetButtonsState extends State<StudySetButtons> {
  /// The server has study sets switched off. Only a plan that says so counts:
  /// without one the server is asked, and it is the authority.
  bool get _switchedOff => !(widget.plan?.studySetsOn ?? true);

  bool get _locked => !(widget.plan?.canMakeStudySets ?? false);

  Future<void> _open(StudySetKind kind) async {
    final pick = widget.pick;
    if (pick != null) {
      await openStudySetFromSelection(
        context,
        study: widget.study,
        pick: pick,
        kind: kind,
        request: MaterialPickRequest(
          action: kind == StudySetKind.quiz
              ? MaterialAction.quiz
              : MaterialAction.flashcards,
          preselectLessonId: widget.resourceId,
        ),
        plan: widget.plan,
        onOpenPlans: widget.onOpenPlans,
      );
      return;
    }
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
    await Navigator.of(context).pushOnce(
      MaterialPageRoute<void>(
        builder: (_) => StudySetPage(
          title: widget.lessonTitle,
          kind: kind,
          load: (_) => widget.study.studySet(widget.resourceId, kind),
          plan: widget.plan,
          onOpenPlans: widget.onOpenPlans,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final off = _switchedOff;
    final locked = !off && _locked;
    final scheme = Theme.of(context).colorScheme;
    Widget button(StudySetKind kind, IconData icon, String label) =>
        OutlinedButton.icon(
          onPressed: () => _open(kind),
          // Shown, not usable: dimmed rather than disabled, so a tap can
          // still say why.
          style: off
              ? OutlinedButton.styleFrom(
                  foregroundColor: scheme.onSurface.withValues(alpha: .45),
                )
              : null,
          icon: Icon(locked ? Icons.lock_outline_rounded : icon, size: 18),
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

/// A quiz or flashcards from material the student chooses: the plan is
/// checked first, then the picker shows exactly what will be used, and
/// only that is sent (ADR-0039).
Future<void> openStudySetFromSelection(
  BuildContext context, {
  required StudyRepository study,
  required MaterialPicker pick,
  required StudySetKind kind,
  required MaterialPickRequest request,
  required StudyPlan? plan,
  required VoidCallback onOpenPlans,
}) async {
  final l10n = AppL10n.of(context);
  if (!(plan?.studySetsOn ?? true)) {
    ScaffoldMessenger.of(context).showMessage(l10n.studySetSwitchedOff);
    return;
  }
  if (!(plan?.canMakeStudySets ?? false)) {
    await showUpgradePrompt(
      context,
      reason: UpgradeReason.feature,
      plan: plan,
      needs: StudyPlanTier.max,
      onUpgrade: onOpenPlans,
    );
    return;
  }
  final selection = await pick(context, request);
  if (selection == null || selection.isEmpty || !context.mounted) return;
  await Navigator.of(context).pushOnce(
    MaterialPageRoute<void>(
      builder: (_) => StudySetPage(
        title: kind == StudySetKind.quiz
            ? l10n.studySetQuiz
            : l10n.studySetFlashcards,
        kind: kind,
        selection: selection,
        load: (skip) =>
            study.selectionStudySet(kind, selection, skipUnavailable: skip),
        plan: plan,
        onOpenPlans: onOpenPlans,
      ),
    ),
  );
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
    this.onMake,
  });

  final StudyPlan? plan;
  final bool hasLessons;
  final VoidCallback onOpenPlans;

  /// Makes one from material the student chooses.
  final void Function(StudySetKind kind)? onMake;

  @override
  Widget build(BuildContext context) {
    final l10n = AppL10n.of(context);
    final plan = this.plan;
    final off = plan != null && !plan.studySetsOn;
    final locked = !off && !(plan?.canMakeStudySets ?? false);
    final card = Padding(
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
    final make = onMake;
    if (make == null || off || locked || !hasLessons) return card;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        card,
        Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: Wrap(
            spacing: 8,
            runSpacing: 6,
            children: [
              OutlinedButton.icon(
                onPressed: () => make(StudySetKind.quiz),
                icon: const Icon(Icons.quiz_outlined, size: 18),
                label: Text(l10n.pickActionQuiz),
              ),
              OutlinedButton.icon(
                onPressed: () => make(StudySetKind.flashcards),
                icon: const Icon(Icons.style_outlined, size: 18),
                label: Text(l10n.pickActionFlashcards),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

/// A quiz or flashcards being made, then shown: "Making your quiz…" while
/// the server writes it (or finds the one already made - reopening one is
/// free), an explanation and Try again when it could not be made, and a
/// way to the plans when the plan or the tokens are the reason.
class StudySetPage extends StatefulWidget {
  const StudySetPage({
    super.key,
    required this.title,
    required this.kind,
    required this.load,
    this.plan,
    this.onOpenPlans,
    this.selection,
  });

  final String title;
  final StudySetKind kind;

  /// Makes or reopens it; true goes on without chosen files that cannot be
  /// read now.
  final Future<StudySet> Function(bool skipUnavailable) load;

  /// What was chosen, to name files that cannot be read.
  final MaterialSelection? selection;
  final StudyPlan? plan;
  final VoidCallback? onOpenPlans;

  @override
  State<StudySetPage> createState() => _StudySetPageState();
}

class _StudySetPageState extends State<StudySetPage> {
  StudySet? _set;
  StudyRefusal? _refusal;
  MaterialUnavailableException? _unavailable;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load({bool skipUnavailable = false}) async {
    setState(() {
      _set = null;
      _refusal = null;
      _unavailable = null;
    });
    try {
      final set = await widget.load(skipUnavailable);
      if (mounted) setState(() => _set = set);
    } on MaterialUnavailableException catch (error) {
      if (!mounted) return;
      setState(() => _unavailable = error);
      // Named, never dropped: the student decides.
      final go = await confirmContinueWithout(
        context,
        error,
        selection: widget.selection,
      );
      if (go && mounted) await _load(skipUnavailable: true);
    } on StudyException catch (error) {
      if (mounted) setState(() => _refusal = error.refusal);
    } on Object {
      if (mounted) setState(() => _refusal = StudyRefusal.failed);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppL10n.of(context);
    final set = _set;
    final quiz = widget.kind == StudySetKind.quiz;
    if (set != null) {
      final empty = quiz ? set.questions.isEmpty : set.cards.isEmpty;
      if (!empty) {
        final from = set.scope == null || set.scope!.lessons.isEmpty
            ? null
            : scopeLine(l10n, set.scope!);
        return quiz
            ? QuizPage(
                title: widget.title,
                questions: set.questions,
                madeFrom: from,
              )
            : FlashcardsPage(
                title: widget.title,
                cards: set.cards,
                madeFrom: from,
              );
      }
    }
    final refusal = _refusal;
    final Widget body;
    if (_unavailable != null) {
      body = StudafyEmptyState(
        icon: Icons.hourglass_top_rounded,
        title: l10n.unavailableTitle,
        message: l10n.unavailableBody,
        actionLabel: l10n.nbRetry,
        onAction: _load,
      );
    } else if (set == null && refusal == null) {
      body = Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const CircularProgressIndicator(),
          const SizedBox(height: 20),
          Text(
            quiz ? l10n.setMakingQuiz : l10n.setMakingCards,
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 8),
          Text(
            l10n.setMakingDetail,
            textAlign: TextAlign.center,
            style: const TextStyle(color: studafyMuted),
          ),
        ],
      );
    } else if (set != null) {
      body = StudafyEmptyState(
        icon: Icons.inbox_outlined,
        title: l10n.setEmpty,
        actionLabel: l10n.nbRetry,
        onAction: _load,
      );
    } else {
      final upgrade =
          (refusal == StudyRefusal.planRequired ||
              refusal == StudyRefusal.allowanceUsed) &&
          widget.onOpenPlans != null;
      body = StudafyEmptyState(
        icon: switch (refusal) {
          StudyRefusal.planRequired => Icons.workspace_premium_outlined,
          StudyRefusal.allowanceUsed => Icons.hourglass_empty_rounded,
          StudyRefusal.materialProcessing => Icons.hourglass_top_rounded,
          _ => Icons.error_outline_rounded,
        },
        title: switch (refusal) {
          StudyRefusal.planRequired =>
            l10n.studySetQuizzesAndFlashcardsComeWith,
          StudyRefusal.allowanceUsed => l10n.studySetThisMonthSAiAllowance,
          StudyRefusal.lessonHasNoText => l10n.studySetThisLessonHasNoText,
          StudyRefusal.materialProcessing => l10n.studySetMaterialProcessing,
          StudyRefusal.unavailable => l10n.studySetSwitchedOff,
          StudyRefusal.aiConsent => l10n.aiConsentNeeded,
          _ => l10n.setFailed,
        },
        message: upgrade ? null : l10n.setFailedDetail,
        actionLabel: upgrade ? l10n.setSeePlans : l10n.nbRetry,
        onAction: upgrade
            ? () {
                Navigator.of(context).pop();
                widget.onOpenPlans!();
              }
            : _load,
      );
    }
    return Scaffold(
      appBar: AppBar(title: UserContentText(widget.title)),
      body: Center(
        child: Padding(padding: const EdgeInsets.all(24), child: body),
      ),
    );
  }
}

/// A quiz: answer every question, then check - the score, which were
/// right, and why each answer is the answer. Try again starts over.
class QuizPage extends StatefulWidget {
  const QuizPage({
    super.key,
    required this.title,
    required this.questions,
    this.madeFrom,
  });

  final String title;
  final List<QuizQuestion> questions;

  /// The lessons and files it was made from.
  final String? madeFrom;

  @override
  State<QuizPage> createState() => _QuizPageState();
}

class _QuizPageState extends State<QuizPage> {
  final Map<int, int> _answers = {};
  bool _checked = false;
  final _scroll = ScrollController();

  int get _score => [
    for (final entry in _answers.entries)
      if (widget.questions[entry.key].answerIndex == entry.value) 1,
  ].length;

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  void _check() {
    setState(() => _checked = true);
    _scroll.animateTo(
      0,
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeOut,
    );
  }

  void _retry() {
    setState(() {
      _answers.clear();
      _checked = false;
    });
    _scroll.jumpTo(0);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppL10n.of(context);
    final theme = Theme.of(context);
    final count = widget.questions.length;
    final all = _answers.length == count;
    return Scaffold(
      appBar: AppBar(title: UserContentText(widget.title)),
      body: ListView(
        controller: _scroll,
        padding: const EdgeInsets.all(16),
        children: [
          if (widget.madeFrom case final from?) MadeFromLine(from),
          if (_checked)
            FeatureCard(
              tint: _score == count ? studafyTeal : studafyNavy,
              child: Row(
                children: [
                  IconBadge(
                    icon: _score == count
                        ? Icons.emoji_events_rounded
                        : Icons.fact_check_rounded,
                    color: _score == count ? studafyTeal : studafyNavy,
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '$_score / $count',
                          style: theme.textTheme.headlineSmall?.copyWith(
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        Text(l10n.quizScoreLine('$_score', '$count')),
                      ],
                    ),
                  ),
                ],
              ),
            )
          else ...[
            Text(
              l10n.studySetAnswerscountOfQuestionscountAnswered(
                _answers.length,
                count,
              ),
              style: theme.textTheme.titleMedium,
            ),
            const SizedBox(height: 6),
            LinearProgressIndicator(
              value: count == 0 ? 0 : _answers.length / count,
              borderRadius: BorderRadius.circular(4),
            ),
          ],
          const SizedBox(height: 14),
          for (var i = 0; i < count; i++)
            _QuestionCard(
              number: i + 1,
              count: count,
              question: widget.questions[i],
              chosen: _answers[i],
              checked: _checked,
              onChoose: (o) => setState(() => _answers[i] = o),
            ),
          if (!_checked) ...[
            if (!all)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Text(
                  l10n.quizAnswerAll,
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: studafyMuted),
                ),
              ),
            FilledButton.icon(
              onPressed: all ? _check : null,
              icon: const Icon(Icons.fact_check_outlined),
              label: Text(l10n.quizSubmit),
            ),
          ] else
            FilledButton.icon(
              onPressed: _retry,
              icon: const Icon(Icons.refresh_rounded),
              label: Text(l10n.studySetTryAgain),
            ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }
}

class _QuestionCard extends StatelessWidget {
  const _QuestionCard({
    required this.number,
    required this.count,
    required this.question,
    required this.chosen,
    required this.checked,
    required this.onChoose,
  });

  final int number;
  final int count;
  final QuizQuestion question;
  final int? chosen;
  final bool checked;
  final ValueChanged<int> onChoose;

  @override
  Widget build(BuildContext context) {
    final l10n = AppL10n.of(context);
    final theme = Theme.of(context);
    final right = chosen == question.answerIndex;
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    l10n.quizQuestionOf('$number', '$count'),
                    style: const TextStyle(color: studafyMuted, fontSize: 12.5),
                  ),
                ),
                if (checked)
                  StatusPill(
                    label: right ? l10n.quizCorrect : l10n.quizWrong,
                    icon: right
                        ? Icons.check_circle_rounded
                        : Icons.cancel_rounded,
                    color: right ? Colors.green.shade700 : studafyDanger,
                  ),
              ],
            ),
            const SizedBox(height: 6),
            UserContentText(
              question.question,
              style: theme.textTheme.titleSmall,
            ),
            const SizedBox(height: 8),
            for (var o = 0; o < question.options.length; o++)
              _Option(
                text: question.options[o],
                chosen: chosen == o,
                revealed: checked,
                correct: question.answerIndex == o,
                onTap: checked ? null : () => onChoose(o),
              ),
            if (checked && question.explanation.isNotEmpty)
              Container(
                margin: const EdgeInsets.only(top: 8),
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: studafyWash,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(
                      Icons.lightbulb_outline_rounded,
                      size: 18,
                      color: studafyNavy,
                    ),
                    const SizedBox(width: 8),
                    Expanded(child: UserContentText(question.explanation)),
                  ],
                ),
              ),
          ],
        ),
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
    final Color tint = !revealed
        ? chosen
              ? studafyNavy.withValues(alpha: .12)
              : scheme.surfaceContainerHighest.withValues(alpha: .5)
        : correct
        ? Colors.green.withValues(alpha: .15)
        : chosen
        ? scheme.error.withValues(alpha: .12)
        : scheme.surfaceContainerHighest.withValues(alpha: .5);
    final IconData icon = !revealed
        ? chosen
              ? Icons.radio_button_checked_rounded
              : Icons.radio_button_unchecked_rounded
        : correct
        ? Icons.check_circle_rounded
        : chosen
        ? Icons.cancel_rounded
        : Icons.radio_button_unchecked_rounded;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Semantics(
        selected: chosen,
        inMutuallyExclusiveGroup: true,
        child: Material(
          color: tint,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
            side: BorderSide(
              color: chosen && !revealed ? studafyNavy : Colors.transparent,
            ),
          ),
          child: InkWell(
            borderRadius: BorderRadius.circular(12),
            onTap: onTap,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              child: Row(
                children: [
                  Icon(
                    icon,
                    size: 20,
                    color: revealed && correct
                        ? Colors.green
                        : revealed && chosen
                        ? scheme.error
                        : chosen
                        ? studafyNavy
                        : null,
                  ),
                  const SizedBox(width: 10),
                  Expanded(child: UserContentText(text)),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Flashcards: tap to turn a card over, then say whether you knew it.
/// Previous and Next step through them; at the end, the count you knew and
/// a round of just the ones you are still learning.
class FlashcardsPage extends StatefulWidget {
  const FlashcardsPage({
    super.key,
    required this.title,
    required this.cards,
    this.madeFrom,
  });

  final String title;
  final List<Flashcard> cards;

  /// The lessons and files they were made from.
  final String? madeFrom;

  @override
  State<FlashcardsPage> createState() => _FlashcardsPageState();
}

class _FlashcardsPageState extends State<FlashcardsPage> {
  late List<Flashcard> _deck = widget.cards;
  final _known = <Flashcard>{};
  final _learning = <Flashcard>{};
  int _index = 0;
  bool _back = false;

  bool get _done => _index >= _deck.length;

  void _go(int index) => setState(() {
    _index = index.clamp(0, _deck.length);
    _back = false;
  });

  void _mark(bool knew) {
    final card = _deck[_index];
    setState(() {
      if (knew) {
        _known.add(card);
        _learning.remove(card);
      } else {
        _learning.add(card);
        _known.remove(card);
      }
    });
    _go(_index + 1);
  }

  void _restart({required bool learningOnly}) => setState(() {
    _deck = learningOnly && _learning.isNotEmpty
        ? [
            for (final card in widget.cards)
              if (_learning.contains(card)) card,
          ]
        : widget.cards;
    _known.clear();
    _learning.clear();
    _index = 0;
    _back = false;
  });

  @override
  Widget build(BuildContext context) {
    final l10n = AppL10n.of(context);
    final theme = Theme.of(context);
    final count = _deck.length;
    return Scaffold(
      appBar: AppBar(title: UserContentText(widget.title)),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: _done
              ? Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const IconBadge(
                        icon: Icons.emoji_events_rounded,
                        color: studafyTeal,
                        size: 64,
                      ),
                      const SizedBox(height: 16),
                      Text(l10n.cardsDone, style: theme.textTheme.titleLarge),
                      const SizedBox(height: 6),
                      Text(l10n.cardsKnewCount('${_known.length}', '$count')),
                      const SizedBox(height: 20),
                      if (_learning.isNotEmpty)
                        FilledButton.icon(
                          onPressed: () => _restart(learningOnly: true),
                          icon: const Icon(Icons.replay_rounded),
                          label: Text(l10n.cardsLearningOnly),
                        ),
                      const SizedBox(height: 8),
                      OutlinedButton.icon(
                        onPressed: () => _restart(learningOnly: false),
                        icon: const Icon(Icons.restart_alt_rounded),
                        label: Text(l10n.cardsAgain),
                      ),
                    ],
                  ),
                )
              : Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    if (widget.madeFrom case final from?) MadeFromLine(from),
                    Text(
                      l10n.cardsProgress('${_index + 1}', '$count'),
                      textAlign: TextAlign.center,
                      style: theme.textTheme.titleSmall,
                    ),
                    const SizedBox(height: 6),
                    LinearProgressIndicator(
                      value: (_index + 1) / count,
                      borderRadius: BorderRadius.circular(4),
                    ),
                    const SizedBox(height: 16),
                    Expanded(
                      child: _FlipCard(
                        key: ValueKey(_index),
                        front: _deck[_index].front,
                        back: _deck[_index].back,
                        showBack: _back,
                        onTap: () => setState(() => _back = !_back),
                      ),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      _back ? l10n.cardsDidYouKnow : l10n.cardsTapToFlip,
                      textAlign: TextAlign.center,
                      style: const TextStyle(color: studafyMuted),
                    ),
                    const SizedBox(height: 10),
                    if (_back)
                      Row(
                        children: [
                          Expanded(
                            child: OutlinedButton.icon(
                              onPressed: () => _mark(false),
                              icon: const Icon(Icons.school_outlined),
                              label: Text(l10n.cardsLearning),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: FilledButton.icon(
                              onPressed: () => _mark(true),
                              icon: const Icon(Icons.check_rounded),
                              label: Text(l10n.cardsKnew),
                            ),
                          ),
                        ],
                      )
                    else
                      Row(
                        children: [
                          IconButton.outlined(
                            tooltip: l10n.cardsPrevious,
                            onPressed: _index == 0
                                ? null
                                : () => _go(_index - 1),
                            icon: Icon(backChevron(context)),
                          ),
                          const Spacer(),
                          IconButton.outlined(
                            tooltip: l10n.cardsNext,
                            onPressed: () => _go(_index + 1),
                            icon: Icon(forwardChevron(context)),
                          ),
                        ],
                      ),
                  ],
                ),
        ),
      ),
    );
  }
}

/// A card that turns over, front to back, in a quarter of a second.
class _FlipCard extends StatelessWidget {
  const _FlipCard({
    super.key,
    required this.front,
    required this.back,
    required this.showBack,
    required this.onTap,
  });

  final String front;
  final String back;
  final bool showBack;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final l10n = AppL10n.of(context);
    final theme = Theme.of(context);
    final reduce = MediaQuery.disableAnimationsOf(context);
    return Semantics(
      button: true,
      label: showBack ? l10n.cardsAnswer : l10n.cardsQuestion,
      child: GestureDetector(
        onTap: onTap,
        child: TweenAnimationBuilder<double>(
          tween: Tween(end: showBack ? 1 : 0),
          duration: reduce ? Duration.zero : const Duration(milliseconds: 260),
          builder: (context, turn, _) {
            final backSide = turn >= .5;
            final angle = turn * 3.14159;
            return Transform(
              alignment: Alignment.center,
              transform: Matrix4.identity()
                ..setEntry(3, 2, .001)
                ..rotateY(backSide ? angle - 3.14159 : angle),
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: backSide
                      ? null
                      : const LinearGradient(
                          colors: [studafyNavy, studafyIndigo],
                          begin: AlignmentDirectional.topStart,
                          end: AlignmentDirectional.bottomEnd,
                        ),
                  color: backSide ? Colors.white : null,
                  borderRadius: BorderRadius.circular(24),
                  border: backSide ? Border.all(color: studafyHairline) : null,
                  boxShadow: [
                    BoxShadow(
                      color: studafyAbyss.withValues(alpha: .1),
                      blurRadius: 18,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    children: [
                      Text(
                        backSide ? l10n.cardsAnswer : l10n.cardsQuestion,
                        style: TextStyle(
                          color: backSide
                              ? studafyMuted
                              : Colors.white.withValues(alpha: .8),
                          fontWeight: FontWeight.w700,
                          fontSize: 12.5,
                        ),
                      ),
                      Expanded(
                        child: Center(
                          child: SingleChildScrollView(
                            child: UserContentText(
                              backSide ? back : front,
                              style:
                                  (backSide
                                          ? theme.textTheme.titleLarge
                                          : theme.textTheme.headlineSmall)
                                      ?.copyWith(
                                        color: backSide
                                            ? studafyInk
                                            : Colors.white,
                                        fontWeight: FontWeight.w700,
                                        height: 1.35,
                                      ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

/// "Made from: Cells (lesson text, Leaf.pdf)": so the student can check
/// what a result used.
class MadeFromLine extends StatelessWidget {
  const MadeFromLine(this.text, {super.key});

  final String text;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 12),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Padding(
          padding: EdgeInsets.only(top: 2),
          child: Icon(Icons.source_outlined, size: 16, color: studafyMuted),
        ),
        const SizedBox(width: 6),
        Expanded(
          child: Text(
            AppL10n.of(context).madeFrom(text),
            style: const TextStyle(color: studafyMuted, fontSize: 12.5),
          ),
        ),
      ],
    ),
  );
}
