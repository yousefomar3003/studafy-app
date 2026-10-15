import 'package:flutter/material.dart';

import '../../../core/coursework_attachments.dart';
import '../../../core/feedback.dart';
import '../../../core/navigation.dart';
import '../../../core/studafy_components.dart';
import '../../../core/studafy_design.dart';
import '../../../core/studafy_formatting.dart';
import '../../../core/user_content_text.dart';
import '../../../l10n/generated/app_l10n.dart';
import '../domain/academic_repository.dart';
import 'take_assessment_page.dart';

/// An online assessment for a student, or - read-only - for a parent of one
/// (ADR-0036). Four separate things, each shown only once the server sends
/// it: confirmation of each attempt, the published grade, the teacher's
/// feedback, and the answers once released. A parent ([studentId] set) can
/// never sit it.
class AssessmentPage extends StatefulWidget {
  const AssessmentPage({
    super.key,
    required this.repository,
    required this.assessmentId,
    required this.title,
    this.studentId,
    this.childName,
  });

  final OnlineAssessmentRepository repository;
  final String assessmentId;
  final String title;

  /// The child a parent is looking at; null for the student themself.
  final String? studentId;
  final String? childName;

  @override
  State<AssessmentPage> createState() => _AssessmentPageState();
}

class _AssessmentPageState extends State<AssessmentPage> {
  AssessmentResults? _results;
  bool _failed = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _failed = false);
    try {
      final results = await widget.repository.results(
        widget.assessmentId,
        studentId: widget.studentId,
      );
      if (mounted) setState(() => _results = results);
    } on Object {
      if (mounted) setState(() => _failed = true);
    }
  }

  Future<void> _start() async {
    final messenger = ScaffoldMessenger.of(context);
    final l10n = AppL10n.of(context);
    final confirmation = await Navigator.of(context)
        .pushOnce<AttemptConfirmation>(
          MaterialPageRoute<AttemptConfirmation>(
            builder: (_) => TakeAssessmentPage(
              title: widget.title,
              repository: widget.repository,
              assessmentId: widget.assessmentId,
            ),
          ),
        );
    if (confirmation == null) return;
    messenger.showMessage(l10n.takeSubmitted);
    await _load();
  }

  String _when(DateTime value) {
    return '${studafyMediumDate(context, value)} '
        '${studafyTimeOfDay(context, TimeOfDay.fromDateTime(value))}';
  }

  static String _number(double value) =>
      value == value.roundToDouble() ? value.toInt().toString() : '$value';

  @override
  Widget build(BuildContext context) {
    final l10n = AppL10n.of(context);
    final results = _results;
    return Scaffold(
      appBar: AppBar(title: Text(widget.title)),
      body: SafeArea(
        child: results == null
            ? Center(
                child: _failed
                    ? StudafyEmptyState(
                        icon: Icons.wifi_off_rounded,
                        title: l10n.takeLoadFailed,
                        actionLabel: l10n.takeRetry,
                        onAction: _load,
                      )
                    : const CircularProgressIndicator(),
              )
            : StudafyRefreshIndicator(
                onRefresh: _load,
                child: ListView(
                  padding: const EdgeInsetsDirectional.fromSTEB(16, 12, 16, 32),
                  children: _sections(l10n, results),
                ),
              ),
      ),
    );
  }

  List<Widget> _sections(AppL10n l10n, AssessmentResults r) {
    final theme = Theme.of(context);
    final parent = widget.studentId != null;
    final left = (r.attemptsAllowed - r.attemptsUsed).clamp(0, 20);
    final closes = r.closesAt;
    final closed = closes != null && !closes.isAfter(DateTime.now());
    return [
      if (widget.childName case final child?)
        Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: Text(child, style: theme.textTheme.titleSmall),
        ),
      FeatureCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (r.opensAt case final opens? when r.notOpenYet)
              Text(l10n.takeOpens(_when(opens)))
            else if (closed)
              Text(l10n.takeClosed)
            else if (closes != null)
              Text(l10n.takeCloses(_when(closes))),
            const SizedBox(height: 4),
            Text(l10n.takeAttemptsLeft(left), style: theme.textTheme.bodySmall),
            AttachmentsView(
              attachments: r.assessment.attachments,
              links: r.assessment.links,
            ),
            if (parent)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(
                  l10n.takeReadOnly,
                  style: theme.textTheme.bodySmall,
                ),
              )
            else if (r.canAttempt)
              Padding(
                padding: const EdgeInsets.only(top: 12),
                child: FilledButton.icon(
                  onPressed: _start,
                  icon: const Icon(Icons.play_arrow_rounded),
                  label: Text(
                    r.attemptsUsed == 0 ? l10n.takeStart : l10n.takeAgain,
                  ),
                ),
              ),
          ],
        ),
      ),
      if (r.attempts.isNotEmpty) ...[
        SectionHeader(parent ? l10n.takeChildAttempts : l10n.takeYourAttempts),
        for (final attempt in r.attempts)
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.task_alt_rounded, color: studafyTeal),
            title: Text(
              l10n.takeAttemptLine(
                attempt.attemptNumber ?? 1,
                _when(attempt.submittedAt),
              ),
            ),
          ),
      ],
      SectionHeader(l10n.takeGrade),
      _gradeCard(l10n, theme, r.grade),
      SectionHeader(l10n.takeAnswers),
      if (!r.answersReleased)
        Text(l10n.takeNotReleased, style: theme.textTheme.bodySmall)
      else
        for (final attempt in r.attempts.reversed)
          ..._review(l10n, theme, attempt),
    ];
  }

  Widget _gradeCard(AppL10n l10n, ThemeData theme, ReleasedGrade? grade) {
    if (grade == null) {
      return Text(l10n.takeGradePending, style: theme.textTheme.bodySmall);
    }
    return FeatureCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            // An absence is said as one, never as a zero or as "pending".
            switch (grade.mark) {
              'absent' => l10n.paperGradesAbsent,
              'not_graded' => l10n.paperGradesNotGraded,
              _ when grade.score == null => l10n.takeGradePending,
              _ => l10n.takeScore(
                _number(grade.score!),
                _number(grade.maximumScore),
              ),
            },
            style: theme.textTheme.headlineSmall,
          ),
          if ((grade.feedback ?? '').trim().isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(l10n.takeFeedback, style: theme.textTheme.labelLarge),
            UserContentText(grade.feedback!),
          ],
          if (grade.attachments.isNotEmpty || grade.links.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(l10n.gradeYourFiles, style: theme.textTheme.labelLarge),
            AttachmentsView(attachments: grade.attachments, links: grade.links),
          ],
          if (grade.sharedAttachments.isNotEmpty ||
              grade.sharedLinks.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(l10n.gradeClassFiles, style: theme.textTheme.labelLarge),
            AttachmentsView(
              attachments: grade.sharedAttachments,
              links: grade.sharedLinks,
            ),
          ],
        ],
      ),
    );
  }

  List<Widget> _review(AppL10n l10n, ThemeData theme, AttemptDetail attempt) =>
      [
        if (attempt.answers.isNotEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 6),
            child: Text(
              l10n.takeAttemptLine(
                attempt.attemptNumber ?? 1,
                _when(attempt.submittedAt),
              ),
              style: theme.textTheme.titleSmall,
            ),
          ),
        if ((attempt.feedback ?? '').trim().isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(bottom: 6),
            child: UserContentText(attempt.feedback!),
          ),
        for (final answer in attempt.answers)
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: FeatureCard(child: AnswerReview(answer: answer)),
          ),
      ];
}

/// One answer beside the correct one, with its mark and the teacher's
/// comment. Shared by the student's review and the teacher's marking.
class AnswerReview extends StatelessWidget {
  const AnswerReview({
    super.key,
    required this.answer,
    this.showKey = true,
    this.teacherView = false,
    this.showMark = true,
  });

  final AttemptAnswer answer;
  final bool showKey;

  /// Marking: the answer is the student's, not the reader's.
  final bool teacherView;

  /// Off where the page shows the mark in a field of its own.
  final bool showMark;

  static String _number(double value) =>
      value == value.roundToDouble() ? value.toInt().toString() : '$value';

  String _options(List<String>? ids) {
    final options = answer.question.options;
    return [
      for (final id in ids ?? const <String>[])
        options.where((o) => o.id == id).firstOrNull?.text ?? id,
    ].join(', ');
  }

  String? _given(AppL10n l10n) => switch (answer.question.kind) {
    QuestionKind.singleChoice || QuestionKind.multipleChoice =>
      (answer.selectedOptionIds ?? const []).isEmpty
          ? null
          : _options(answer.selectedOptionIds),
    QuestionKind.trueFalse =>
      answer.choice == null
          ? null
          : answer.choice!
          ? l10n.builderTrue
          : l10n.builderFalse,
    _ => (answer.answerText ?? '').trim().isEmpty ? null : answer.answerText,
  };

  String? _correct(AppL10n l10n) {
    final q = answer.question;
    return switch (q.kind) {
      QuestionKind.singleChoice || QuestionKind.multipleChoice =>
        (q.correctOptionIds ?? const []).isEmpty
            ? null
            : _options(q.correctOptionIds),
      QuestionKind.trueFalse =>
        q.correctChoice == null
            ? null
            : q.correctChoice!
            ? l10n.builderTrue
            : l10n.builderFalse,
      QuestionKind.shortAnswer =>
        (q.acceptedAnswers ?? const []).isEmpty
            ? null
            : q.acceptedAnswers!.join(' / '),
      QuestionKind.essay => null,
    };
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppL10n.of(context);
    final theme = Theme.of(context);
    final q = answer.question;
    final given = _given(l10n);
    final correct = showKey ? _correct(l10n) : null;
    final awarded = answer.awardedScore;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: UserContentText(
                q.prompt,
                style: theme.textTheme.titleSmall,
              ),
            ),
            if (showMark)
              Text(
                awarded == null
                    ? l10n.takeBeingMarked
                    : l10n.takeScore(_number(awarded), _number(q.maximumScore)),
                style: theme.textTheme.labelLarge?.copyWith(
                  color: awarded == null
                      ? studafyMuted
                      : awarded >= q.maximumScore
                      ? studafyTeal
                      : studafyInk,
                ),
              )
            else
              Text(
                l10n.markOutOf(_number(q.maximumScore)),
                style: theme.textTheme.labelLarge?.copyWith(
                  color: studafyMuted,
                ),
              ),
          ],
        ),
        AttachmentsView(
          attachments: q.attachments,
          links: q.links,
          dense: true,
        ),
        const SizedBox(height: 6),
        Text(
          teacherView ? l10n.markStudentAnswer : l10n.takeYourAnswer,
          style: theme.textTheme.labelSmall,
        ),
        given == null
            ? Text(
                l10n.takeNoAnswer,
                style: const TextStyle(color: studafyMuted),
              )
            : UserContentText(given),
        if (correct != null) ...[
          const SizedBox(height: 6),
          Text(
            q.kind == QuestionKind.shortAnswer
                ? l10n.takeAcceptedAnswers
                : l10n.takeCorrectAnswer,
            style: theme.textTheme.labelSmall,
          ),
          Text(correct, style: const TextStyle(color: studafyTeal)),
        ],
        if (showKey && (q.preferredAnswer ?? '').trim().isNotEmpty) ...[
          const SizedBox(height: 6),
          Text(l10n.builderModelAnswer, style: theme.textTheme.labelSmall),
          UserContentText(q.preferredAnswer!),
        ],
        if (showKey && (q.markingGuidance ?? '').trim().isNotEmpty) ...[
          const SizedBox(height: 6),
          Text(l10n.builderGuidance, style: theme.textTheme.labelSmall),
          UserContentText(q.markingGuidance!),
        ],
        if ((answer.feedback ?? '').trim().isNotEmpty) ...[
          const SizedBox(height: 6),
          Text(l10n.takeFeedback, style: theme.textTheme.labelSmall),
          UserContentText(answer.feedback!),
        ],
      ],
    );
  }
}
