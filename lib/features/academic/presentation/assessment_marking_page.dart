import 'package:flutter/material.dart';

import '../../../core/feedback.dart';
import '../../../core/file_upload_repository.dart';
import '../../../core/navigation.dart';
import '../../../core/studafy_components.dart';
import '../../../core/studafy_design.dart';
import '../../../core/studafy_formatting.dart';
import '../../../core/user_content_text.dart';
import '../../../l10n/generated/app_l10n.dart';
import '../domain/academic_repository.dart';
import '../domain/marking.dart';
import 'assessment_builder_page.dart';
import 'assessment_grant_dialog.dart';
import 'assessment_page.dart';
import 'coursework_messages.dart';
import 'marking_references_page.dart';
import 'marking_review.dart';
import 'marking_scope.dart';
import 'marking_suggestions_bar.dart';

/// A teacher's view of an online assessment (ADR-0036): every submission,
/// where each one's marking stands, and the actions around it - edit, give
/// one student more time or attempts, publish the grades, release the
/// answers.
class AssessmentMarkingPage extends StatefulWidget {
  const AssessmentMarkingPage({
    super.key,
    required this.repository,
    required this.assessmentId,
    required this.title,
    this.classroomId,
    this.schoolId,
    this.uploads,
  });

  final AcademicRepository repository;
  final String assessmentId;
  final String title;
  final String? classroomId;
  final String? schoolId;
  final FileUploadRepository? uploads;

  @override
  State<AssessmentMarkingPage> createState() => _AssessmentMarkingPageState();
}

class _AssessmentMarkingPageState extends State<AssessmentMarkingPage> {
  List<AttemptDetail>? _attempts;
  OnlineAssessment? _assessment;

  /// The class's gradebook for this work: every enrolled student, with the
  /// grade each has - so those who handed nothing in are listed too.
  PaperGradebook? _sheet;
  bool _failed = false;
  bool _busy = false;

  /// Suggested marks (ADR-0046), where the app provides them.
  MarkingSuggestionsController? _marking;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final services = MarkingScope.maybeOf(context);
    if (_marking == null && services != null) {
      _marking = MarkingSuggestionsController(services, widget.assessmentId)
        ..load();
    }
  }

  @override
  void dispose() {
    _marking?.dispose();
    super.dispose();
  }

  Future<void> _openReferences() async {
    await Navigator.of(context).pushOnce<void>(
      MaterialPageRoute<void>(
        builder: (_) =>
            MarkingReferencesPage(assessmentId: widget.assessmentId),
      ),
    );
    await _marking?.load();
  }

  Future<void> _load() async {
    setState(() => _failed = false);
    try {
      final (attempts, records, sheet) = await (
        widget.repository.attempts(widget.assessmentId),
        widget.repository.load(
          AcademicFeed.assessments,
          classroomId: widget.classroomId,
        ),
        widget.repository.paperGradebook(widget.assessmentId),
      ).wait;
      if (!mounted) return;
      setState(() {
        _attempts = attempts;
        _sheet = sheet;
        _assessment = records
            .where((r) => r.id == widget.assessmentId)
            .firstOrNull
            ?.online;
      });
    } on Object {
      if (mounted) setState(() => _failed = true);
    }
  }

  Future<void> _run(Future<String?> Function() action) async {
    if (_busy) return;
    final messenger = ScaffoldMessenger.of(context);
    setState(() => _busy = true);
    String? message;
    try {
      message = await action();
    } finally {
      if (mounted) setState(() => _busy = false);
    }
    if (message != null) messenger.showMessage(message);
    await _load();
  }

  /// Publishes every grade that is fully marked, after saying how many will
  /// be seen and how many stay back. Unmarked work is never released.
  Future<void> _publishGrades() => _run(() async {
    final l10n = AppL10n.of(context);
    try {
      final sheet = await widget.repository.paperGradebook(widget.assessmentId);
      if (sheet.item.ready == 0) return l10n.markNothingToPublish;
      if (!mounted) return null;
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: Text(l10n.markPublishTitle),
          content: Text(
            l10n.paperGradesPublishBody(sheet.item.ready, sheet.item.unmarked),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: Text(l10n.linksCancel),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(dialogContext, true),
              child: Text(l10n.paperGradesPublish),
            ),
          ],
        ),
      );
      if (confirmed != true) return null;
      final done = await widget.repository.publishGrades(
        widget.assessmentId,
        sheet.item.gradebookVersion,
      );
      return l10n.markPublished(done.published);
    } on CourseworkRefusal catch (refusal) {
      // Someone marked or published in between: the list is read again.
      return refusal.problem == CourseworkProblem.invalidState
          ? l10n.markNothingToPublish
          : courseworkMessage(l10n, refusal);
    } on Object {
      return l10n.markPublishFailed;
    }
  });

  Future<void> _releaseNow() => _run(() async {
    final l10n = AppL10n.of(context);
    final assessment = _assessment;
    if (assessment == null) return l10n.courseworkFailed;
    try {
      await widget.repository.updateAssessmentDesign(
        assessment.id,
        assessment.version,
        releaseAnswersNow: true,
      );
      return l10n.markReleased;
    } on Object {
      return l10n.markReleaseRefused;
    }
  });

  Future<void> _edit() async {
    final assessment = _assessment;
    if (assessment == null) return;
    final messenger = ScaffoldMessenger.of(context);
    final done = await Navigator.of(context).pushOnce<String>(
      MaterialPageRoute<String>(
        builder: (_) => AssessmentBuilderPage(
          repository: widget.repository,
          classes: [ClassOption(id: assessment.classroomId, name: '')],
          schoolId: widget.schoolId,
          uploads: widget.uploads,
          existing: assessment,
        ),
      ),
    );
    if (done != null) messenger.showMessage(done);
    await _load();
  }

  Future<void> _grant() async {
    final classroomId = widget.classroomId ?? _assessment?.classroomId;
    if (classroomId == null) return;
    final l10n = AppL10n.of(context);
    final messenger = ScaffoldMessenger.of(context);
    List<ClassStudent> students;
    try {
      students = await widget.repository.classStudents(classroomId);
    } on Object {
      messenger.showMessage(l10n.markGrantFailed);
      return;
    }
    if (!mounted) return;
    final granted = await showDialog<bool>(
      context: context,
      builder: (_) => GrantAccessDialog(
        repository: widget.repository,
        assessmentId: widget.assessmentId,
        students: students,
        closesAt: _assessment?.settings.closesAt,
      ),
    );
    if (granted ?? false) messenger.showMessage(l10n.markGranted);
  }

  /// Records, changes or removes the absence of a student who handed
  /// nothing in. Unpublished, it is a draft; published, it is corrected with
  /// a reason, as any published mark is.
  Future<void> _absence(PaperGradebookRow row) => _run(() async {
    final l10n = AppL10n.of(context);
    final sheet = _sheet;
    if (sheet == null) return null;
    final grade = row.grade;
    final published = grade?.state == PaperGradeState.published;
    final choice = await showDialog<_AbsenceChoice>(
      context: context,
      builder: (_) => _AbsenceDialog(
        name: row.displayName,
        absent: grade?.mark == GradeMark.absent,
        published: published,
        notes: grade?.feedback ?? '',
      ),
    );
    if (choice == null || !mounted) return null;
    try {
      if (published) {
        await widget.repository.correctGrades(
          widget.assessmentId,
          choice.reason!,
          [
            GradeCorrection(
              gradeId: grade!.id,
              expectedVersion: grade.version,
              mark: choice.mark!,
              feedback: choice.notes,
            ),
          ],
        );
        return l10n.markAbsenceCorrected;
      }
      await widget.repository.saveGradeDrafts(
        widget.assessmentId,
        sheet.item.gradebookVersion,
        [
          GradeDraft(
            studentId: row.studentId,
            expectedVersion: grade?.version ?? 0,
            mark: choice.mark,
            feedback: choice.mark == null ? null : choice.notes,
          ),
        ],
      );
      return choice.mark == null
          ? l10n.markAbsenceRemoved
          : l10n.markAbsenceSaved;
    } on CourseworkRefusal catch (refusal) {
      return refusal.problem == CourseworkProblem.invalidState
          ? l10n.markAbsenceRefused
          : courseworkMessage(l10n, refusal);
    } on Object {
      return l10n.markAbsenceFailed;
    }
  });

  Future<void> _open(AttemptDetail attempt) async {
    await Navigator.of(context).pushOnce<void>(
      MaterialPageRoute<void>(
        builder: (_) => MarkAttemptPage(
          repository: widget.repository,
          attemptId: attempt.id,
          studentName: attempt.studentName ?? '',
          assessmentId: widget.assessmentId,
        ),
      ),
    );
    await _load();
    await _marking?.load();
  }

  static String _number(double value) =>
      value == value.roundToDouble() ? value.toInt().toString() : '$value';

  @override
  Widget build(BuildContext context) {
    final l10n = AppL10n.of(context);
    final attempts = _attempts;
    final max = _assessment?.maximumScore;
    int count(MarkingStatus status) =>
        attempts?.where((a) => a.markingStatus == status).length ?? 0;
    final toMark =
        count(MarkingStatus.notMarked) + count(MarkingStatus.partlyMarked);
    final submitted = {
      for (final a in attempts ?? const <AttemptDetail>[]) a.studentId,
    };
    final missing = [
      for (final row in _sheet?.rows ?? const <PaperGradebookRow>[])
        if (!submitted.contains(row.studentId) &&
            (row.enrolled || row.grade != null))
          row,
    ];
    final absent = missing
        .where((row) => row.grade?.mark == GradeMark.absent)
        .length;
    final notSubmitted = missing
        .where((row) => rosterStatus(row) == MarkingStatus.notSubmitted)
        .length;
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.title),
        actions: [
          PopupMenuButton<String>(
            enabled: !_busy,
            onSelected: (value) => switch (value) {
              'edit' => _edit(),
              'grant' => _grant(),
              'release' => _releaseNow(),
              'references' => _openReferences(),
              _ => _publishGrades(),
            },
            itemBuilder: (_) => [
              PopupMenuItem(value: 'edit', child: Text(l10n.markEditQuestions)),
              if (_marking != null)
                PopupMenuItem(
                  value: 'references',
                  child: Text(l10n.markingRefsTitle),
                ),
              PopupMenuItem(value: 'grant', child: Text(l10n.markGrantAccess)),
              PopupMenuItem(
                value: 'publish',
                child: Text(l10n.markPublishGrades),
              ),
              PopupMenuItem(value: 'release', child: Text(l10n.markReleaseNow)),
            ],
          ),
        ],
      ),
      body: SafeArea(
        child: attempts == null
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
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            l10n.markAnswersCount(attempts.length),
                            style: Theme.of(context).textTheme.titleSmall,
                          ),
                        ),
                        FilledButton.tonal(
                          onPressed: _busy ? null : _publishGrades,
                          child: Text(l10n.markPublishGrades),
                        ),
                      ],
                    ),
                    if (attempts.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(top: 4),
                        child: Text(
                          l10n.markSummary(
                            toMark,
                            count(MarkingStatus.marked),
                            count(MarkingStatus.published),
                          ),
                          style: const TextStyle(color: studafyMuted),
                        ),
                      ),
                    if (missing.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(top: 2, bottom: 4),
                        child: Text(
                          l10n.markRosterSummary(notSubmitted, absent),
                          style: const TextStyle(color: studafyMuted),
                        ),
                      ),
                    if (_failed)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: Text(
                          l10n.markRefreshFailed,
                          style: const TextStyle(color: studafyDanger),
                        ),
                      ),
                    const SizedBox(height: 8),
                    if (_marking case final marking?)
                      MarkingSuggestionsBar(
                        controller: marking,
                        enabled: !_busy,
                      ),
                    if (attempts.isEmpty && missing.isEmpty)
                      StudafyEmptyState(
                        icon: Icons.inbox_outlined,
                        title: l10n.markNone,
                      ),
                    for (final attempt in attempts)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: FeatureCard(
                          onTap: _busy ? null : () => _open(attempt),
                          child: Row(
                            children: [
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    UserContentText(
                                      attempt.studentName ?? '',
                                      style: const TextStyle(
                                        fontWeight: FontWeight.w800,
                                      ),
                                    ),
                                    Text(
                                      l10n.takeAttemptLine(
                                        attempt.attemptNumber ?? 1,
                                        studafyMediumDate(
                                          context,
                                          attempt.submittedAt,
                                        ),
                                      ),
                                      style: const TextStyle(
                                        color: studafyMuted,
                                      ),
                                    ),
                                    if (attempt.awardedScore case final score?
                                        when max != null)
                                      Text(
                                        l10n.markDone(
                                          _number(score),
                                          _number(max),
                                        ),
                                        style: const TextStyle(
                                          color: studafyMuted,
                                        ),
                                      ),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 8),
                              MarkingStatusPill(status: attempt.markingStatus),
                            ],
                          ),
                        ),
                      ),
                    if (missing.isNotEmpty) ...[
                      SectionHeader(l10n.markNotSubmittedSection),
                      Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: Text(
                          l10n.markNotSubmittedHint,
                          style: const TextStyle(color: studafyMuted),
                        ),
                      ),
                      for (final row in missing)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 8),
                          child: FeatureCard(
                            onTap: _busy ? null : () => _absence(row),
                            child: Row(
                              children: [
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      UserContentText(
                                        row.displayName,
                                        style: const TextStyle(
                                          fontWeight: FontWeight.w800,
                                        ),
                                      ),
                                      if ((row.grade?.feedback ?? '')
                                          .trim()
                                          .isNotEmpty)
                                        UserContentText(
                                          row.grade!.feedback!,
                                          style: const TextStyle(
                                            color: studafyMuted,
                                          ),
                                        ),
                                    ],
                                  ),
                                ),
                                const SizedBox(width: 8),
                                MarkingStatusPill(status: rosterStatus(row)),
                              ],
                            ),
                          ),
                        ),
                    ],
                  ],
                ),
              ),
      ),
    );
  }
}

/// Where a student who handed nothing in stands.
@visibleForTesting
MarkingStatus rosterStatus(PaperGradebookRow row) {
  final grade = row.grade;
  final published = grade?.state == PaperGradeState.published;
  return switch (grade?.mark) {
    GradeMark.absent =>
      published ? MarkingStatus.absentPublished : MarkingStatus.absent,
    GradeMark.notGraded when published => MarkingStatus.notGradedPublished,
    _ => MarkingStatus.notSubmitted,
  };
}

/// What the teacher chose for a non-submitter: a mark ('absent', or null to
/// clear it; 'not_graded' when correcting a published absence), notes, and
/// - for a published grade - the reason.
class _AbsenceChoice {
  const _AbsenceChoice({this.mark, this.notes, this.reason});

  final GradeMark? mark;
  final String? notes;
  final String? reason;
}

class _AbsenceDialog extends StatefulWidget {
  const _AbsenceDialog({
    required this.name,
    required this.absent,
    required this.published,
    required this.notes,
  });

  final String name;
  final bool absent;
  final bool published;
  final String notes;

  @override
  State<_AbsenceDialog> createState() => _AbsenceDialogState();
}

class _AbsenceDialogState extends State<_AbsenceDialog> {
  late final _notes = TextEditingController(text: widget.notes);
  final _reason = TextEditingController();
  late GradeMark _mark = widget.absent ? GradeMark.notGraded : GradeMark.absent;

  @override
  void dispose() {
    _notes.dispose();
    _reason.dispose();
    super.dispose();
  }

  String? get _trimmedNotes =>
      _notes.text.trim().isEmpty ? null : _notes.text.trim();

  @override
  Widget build(BuildContext context) {
    final l10n = AppL10n.of(context);
    final published = widget.published;
    final reasonOk = _reason.text.trim().length >= 3;
    return AlertDialog(
      title: UserContentText(widget.name),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              published ? l10n.markAbsencePublishedBody : l10n.markAbsenceBody,
            ),
            if (published) ...[
              const SizedBox(height: 8),
              RadioGroup<GradeMark>(
                groupValue: _mark,
                onChanged: (value) => setState(() => _mark = value ?? _mark),
                child: Column(
                  children: [
                    RadioListTile<GradeMark>(
                      value: GradeMark.absent,
                      contentPadding: EdgeInsets.zero,
                      title: Text(l10n.markStatusAbsent),
                    ),
                    RadioListTile<GradeMark>(
                      value: GradeMark.notGraded,
                      contentPadding: EdgeInsets.zero,
                      title: Text(l10n.markAbsenceExcused),
                    ),
                  ],
                ),
              ),
            ],
            const SizedBox(height: 8),
            TextField(
              controller: _notes,
              maxLength: 5000,
              minLines: 1,
              maxLines: 4,
              decoration: InputDecoration(
                labelText: l10n.markAbsenceNotes,
                border: const OutlineInputBorder(),
              ),
            ),
            if (published)
              TextField(
                controller: _reason,
                maxLength: 500,
                onChanged: (_) => setState(() {}),
                decoration: InputDecoration(
                  labelText: l10n.markCorrectionReason,
                  border: const OutlineInputBorder(),
                ),
              ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(l10n.linksCancel),
        ),
        if (widget.absent && !published)
          TextButton(
            onPressed: () => Navigator.pop(context, const _AbsenceChoice()),
            child: Text(l10n.markAbsenceRemove),
          ),
        FilledButton(
          onPressed: published && !reasonOk
              ? null
              : () => Navigator.pop(
                  context,
                  _AbsenceChoice(
                    mark: published ? _mark : GradeMark.absent,
                    notes: _trimmedNotes,
                    reason: published ? _reason.text.trim() : null,
                  ),
                ),
          child: Text(
            published
                ? l10n.markSaveCorrection
                : widget.absent
                ? l10n.markAbsenceSaveNotes
                : l10n.markAbsenceMark,
          ),
        ),
      ],
    );
  }
}

/// Where a submission's marking stands, in words and an icon - never colour
/// alone.
class MarkingStatusPill extends StatelessWidget {
  const MarkingStatusPill({super.key, required this.status});

  final MarkingStatus status;

  @override
  Widget build(BuildContext context) {
    final l10n = AppL10n.of(context);
    return switch (status) {
      MarkingStatus.notMarked => StatusPill(
        label: l10n.markStatusNotMarked,
        icon: Icons.edit_note_rounded,
        color: studafyDanger,
      ),
      MarkingStatus.partlyMarked => StatusPill(
        label: l10n.markStatusPartly,
        icon: Icons.pending_outlined,
        color: studafyCyan,
      ),
      MarkingStatus.marked => StatusPill(
        label: l10n.markStatusMarked,
        icon: Icons.task_alt_rounded,
        color: studafyMuted,
      ),
      MarkingStatus.published => StatusPill(
        label: l10n.markStatusPublished,
        icon: Icons.check_circle_rounded,
      ),
      MarkingStatus.notSubmitted => StatusPill(
        label: l10n.markStatusNotSubmitted,
        icon: Icons.hourglass_empty_rounded,
        color: studafyMuted,
      ),
      MarkingStatus.absent => StatusPill(
        label: l10n.markStatusAbsent,
        icon: Icons.event_busy_rounded,
        color: studafyCyan,
      ),
      MarkingStatus.absentPublished => StatusPill(
        label: l10n.markStatusAbsentPublished,
        icon: Icons.event_busy_rounded,
      ),
      MarkingStatus.notGradedPublished => StatusPill(
        label: l10n.markStatusNotGradedPublished,
        icon: Icons.do_not_disturb_on_outlined,
      ),
    };
  }
}

/// Marking one attempt: every answer with the question, its files, the key,
/// the automatic mark where there is one, and a score and comment the
/// teacher can set or change.
///
/// Saving keeps the marks as a draft only the class's teachers see; they
/// reach the student and their parents when the grades are published. Once
/// they are, a change is a correction and asks for a reason. Nothing typed is
/// lost to a failed save, and leaving with unsaved marks asks first.
class MarkAttemptPage extends StatefulWidget {
  const MarkAttemptPage({
    super.key,
    required this.repository,
    required this.attemptId,
    required this.studentName,
    this.assessmentId,
  });

  final OnlineAssessmentRepository repository;
  final String attemptId;
  final String studentName;

  /// The assessment, for its suggested marks (ADR-0046). Without it, or
  /// without a [MarkingScope], the page marks as it always did.
  final String? assessmentId;

  @override
  State<MarkAttemptPage> createState() => _MarkAttemptPageState();
}

class _MarkAttemptPageState extends State<MarkAttemptPage> {
  AttemptDetail? _attempt;
  bool _failed = false;
  bool _saving = false;
  String? _error;

  /// The result of the last save, shown just above the Save button. A
  /// snackbar there covered the button on phones for a few seconds after
  /// every save (2026-10-11).
  String? _notice;
  final Map<String, TextEditingController> _scores = {};
  final Map<String, TextEditingController> _comments = {};
  final _overall = TextEditingController();

  /// What the server last held, to tell an unsaved change from a saved one.
  Map<String, String> _savedScores = const {};
  Map<String, String> _savedComments = const {};
  String _savedOverall = '';

  /// Questions whose score cannot be saved as typed, with why.
  final Map<String, String> _invalid = {};

  /// Suggested marks for the written answers, where the app provides them.
  MarkingSuggestionsController? _marking;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final services = MarkingScope.maybeOf(context);
    final assessmentId = widget.assessmentId;
    if (_marking == null && services != null && assessmentId != null) {
      _marking = MarkingSuggestionsController(services, assessmentId)..load();
    }
  }

  @override
  void dispose() {
    for (final c in [..._scores.values, ..._comments.values]) {
      c.dispose();
    }
    _overall.dispose();
    _marking?.dispose();
    super.dispose();
  }

  /// Fills in this answer's score and comment from the suggestion. Nothing
  /// is saved: the teacher checks it, changes it if they want, and saves.
  void _use(AttemptAnswer answer, MarkingSuggestion suggestion) {
    final score = suggestion.suggestedScore;
    if (score == null) return;
    final id = answer.question.id;
    final feedback = (suggestion.feedback ?? '').trim();
    setState(() {
      _scores[id]?.text = _number(score);
      if (feedback.isNotEmpty) _comments[id]?.text = feedback;
      _invalid.remove(id);
      _error = null;
      _notice = AppL10n.of(context).markingUsed;
    });
  }

  /// The question and answer as marking shows them; for a written answer
  /// with suggested marks, side by side with the reference and suggestion.
  Widget _review(AttemptDetail attempt, AttemptAnswer answer) {
    final marking = _marking;
    final written =
        answer.question.kind == QuestionKind.shortAnswer ||
        answer.question.kind == QuestionKind.essay;
    final plain = AnswerReview(
      answer: answer,
      teacherView: true,
      showMark: false,
    );
    if (marking == null || !written) return plain;
    return ListenableBuilder(
      listenable: marking,
      builder: (context, _) {
        final id = answer.question.id;
        final suggestion = marking.suggestions.forAnswer(attempt.id, id);
        final q = answer.question;
        return MarkingAnswerReview(
          answer: answer,
          // The question's own key and model answer until the references
          // are read.
          reference:
              marking.references?.forQuestion(id) ??
              MarkingReference(
                questionId: id,
                position: q.position,
                kind: q.kind,
                maximumScore: q.maximumScore,
                acceptedAnswers: q.acceptedAnswers,
                preferredAnswer: q.preferredAnswer,
                markingGuidance: q.markingGuidance,
              ),
          suggestion: suggestion,
          onUse: _saving || suggestion == null
              ? null
              : () => _use(answer, suggestion),
          onDismiss: suggestion == null || _saving
              ? null
              : () => marking.dismiss(context, suggestion),
          onSuggestAgain: marking.offered && !_saving
              ? () => marking.request(
                  context,
                  all: true,
                  studentIds: [attempt.studentId],
                )
              : null,
        );
      },
    );
  }

  static String _number(double value) =>
      value == value.roundToDouble() ? value.toInt().toString() : '$value';

  bool get _dirty {
    if (_overall.text.trim() != _savedOverall) return true;
    for (final entry in _scores.entries) {
      if (entry.value.text.trim() != (_savedScores[entry.key] ?? '')) {
        return true;
      }
    }
    for (final entry in _comments.entries) {
      if (entry.value.text.trim() != (_savedComments[entry.key] ?? '')) {
        return true;
      }
    }
    return false;
  }

  void _remember(AttemptDetail attempt) {
    _savedScores = {
      for (final a in attempt.answers)
        a.question.id: a.awardedScore == null ? '' : _number(a.awardedScore!),
    };
    _savedComments = {
      for (final a in attempt.answers) a.question.id: a.feedback ?? '',
    };
    _savedOverall = (attempt.feedback ?? '').trim();
  }

  Future<void> _load() async {
    setState(() => _failed = false);
    try {
      final attempt = await widget.repository.attempt(widget.attemptId);
      if (!mounted) return;
      setState(() {
        _attempt = attempt;
        _remember(attempt);
        _overall.text = _savedOverall;
        for (final a in attempt.answers) {
          (_scores[a.question.id] ??= TextEditingController()).text =
              _savedScores[a.question.id]!;
          (_comments[a.question.id] ??= TextEditingController()).text =
              _savedComments[a.question.id]!;
        }
      });
    } on Object {
      if (mounted) setState(() => _failed = true);
    }
  }

  /// Asks why a published grade is changing. Null when the teacher backs out.
  Future<String?> _askReason() => showDialog<String>(
    context: context,
    builder: (_) => const _CorrectionReasonDialog(),
  );

  Future<void> _save() async {
    if (_saving) return;
    final l10n = AppL10n.of(context);
    final attempt = _attempt;
    if (attempt == null) return;
    final marks = <AnswerMark>[];
    final invalid = <String, String>{};
    for (final a in attempt.answers) {
      final id = a.question.id;
      final text = _scores[id]!.text.trim();
      final comment = _comments[id]!.text.trim();
      if (text.isEmpty) {
        // A comment needs a mark to travel with; an empty score is simply
        // not marked yet.
        if (comment != (_savedComments[id] ?? '')) {
          invalid[id] = l10n.markScoreNeededForComment;
        }
        continue;
      }
      final score = double.tryParse(text.replaceAll(',', '.'));
      if (score == null || score < 0 || score > a.question.maximumScore) {
        invalid[id] = l10n.markScoreInvalid(_number(a.question.maximumScore));
        continue;
      }
      if (score != a.awardedScore || comment != (a.feedback ?? '')) {
        marks.add(
          AnswerMark(
            questionId: id,
            score: score,
            feedback: comment.isEmpty ? null : comment,
          ),
        );
      }
    }
    final overall = _overall.text.trim();
    final overallChanged = overall != _savedOverall;
    if (invalid.isNotEmpty) {
      setState(() {
        _invalid
          ..clear()
          ..addAll(invalid);
        _error = l10n.markFixHighlighted;
      });
      return;
    }
    // A published absence this attempt came after is replaced from here,
    // even with nothing typed: saving applies the attempt's mark.
    if (marks.isEmpty && !overallChanged && !attempt.publishedAbsent) {
      setState(() {
        _invalid.clear();
        _error = null;
        _notice = l10n.markNothingChanged;
      });
      return;
    }
    setState(() {
      _saving = true;
      _error = null;
      _notice = null;
      _invalid.clear();
    });
    // Whether a change is a correction is the server's to say: only a change
    // to a published mark or score is, and it alone needs a reason. So the
    // save goes as it is, and a reason is asked for only when the server
    // refuses it without one - which changes nothing until it is given.
    String? reason;
    while (true) {
      try {
        final updated = await widget.repository.markAttempt(
          attempt.id,
          marks,
          // Only sent when it changed; an empty one clears it.
          feedback: overallChanged ? overall : null,
          correctionReason: reason,
        );
        if (!mounted) return;
        setState(() {
          _attempt = updated;
          _remember(updated);
          _saving = false;
          _notice = reason != null
              ? l10n.markCorrected
              : updated.published
              ? l10n.markSavedPublished
              : l10n.markDraftSaved;
        });
        return;
      } on CourseworkRefusal catch (refusal) {
        if (!mounted) return;
        if (refusal.problem == CourseworkProblem.reasonRequired &&
            reason == null) {
          // Nothing is saving while the teacher writes the reason.
          setState(() => _saving = false);
          reason = await _askReason();
          if (!mounted) return;
          if (reason != null) {
            setState(() => _saving = true);
            continue;
          }
          // Backed out: nothing was saved, and everything typed stays.
          setState(() {
            _saving = false;
            _error = l10n.markCorrectionCancelled;
          });
          return;
        }
        setState(() {
          _saving = false;
          _error = courseworkMessage(l10n, refusal);
        });
        return;
      } on Object {
        if (!mounted) return;
        setState(() {
          _saving = false;
          _error = l10n.markSaveFailed;
        });
        return;
      }
    }
  }

  Future<bool> _confirmLeave() async {
    final l10n = AppL10n.of(context);
    final leave = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(l10n.markUnsavedTitle),
        content: Text(l10n.markUnsavedBody),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: Text(l10n.markUnsavedKeep),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: studafyDanger),
            onPressed: () => Navigator.pop(dialogContext, true),
            child: Text(l10n.markUnsavedDiscard),
          ),
        ],
      ),
    );
    return leave ?? false;
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppL10n.of(context);
    final attempt = _attempt;
    final total = attempt?.answers.fold<double>(
      0,
      (sum, a) => sum + a.question.maximumScore,
    );
    return PopScope(
      canPop: _saving || attempt == null || !_dirty,
      onPopInvokedWithResult: (didPop, _) async {
        if (didPop) return;
        final navigator = Navigator.of(context);
        if (await _confirmLeave()) navigator.pop();
      },
      child: Scaffold(
        appBar: AppBar(
          title: UserContentText(attempt?.studentName ?? widget.studentName),
        ),
        body: SafeArea(
          child: attempt == null
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
              : ListView(
                  padding: const EdgeInsetsDirectional.fromSTEB(16, 12, 16, 32),
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            attempt.awardedScore == null || total == null
                                ? l10n.markStillToMark
                                : l10n.markDone(
                                    _number(attempt.awardedScore!),
                                    _number(total),
                                  ),
                            style: Theme.of(context).textTheme.titleMedium,
                          ),
                        ),
                        MarkingStatusPill(status: attempt.markingStatus),
                      ],
                    ),
                    Padding(
                      padding: const EdgeInsets.only(top: 6, bottom: 12),
                      child: Text(
                        attempt.publishedAbsent
                            ? l10n.markPublishedAbsentNotice
                            : attempt.published
                            ? l10n.markPublishedNotice
                            : l10n.markDraftNotice,
                        style: TextStyle(
                          color: attempt.publishedAbsent
                              ? studafyDanger
                              : studafyMuted,
                        ),
                      ),
                    ),
                    for (final answer in attempt.answers)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: FeatureCard(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              _review(attempt, answer),
                              if (answer.autoScore != null)
                                Padding(
                                  padding: const EdgeInsets.only(top: 6),
                                  child: Text(
                                    l10n.markAutoScore(
                                      _number(answer.autoScore!),
                                      _number(answer.question.maximumScore),
                                    ),
                                    style: Theme.of(context)
                                        .textTheme
                                        .bodySmall,
                                  ),
                                ),
                              const SizedBox(height: 8),
                              TextField(
                                controller: _scores[answer.question.id],
                                enabled: !_saving,
                                keyboardType:
                                    const TextInputType.numberWithOptions(
                                      decimal: true,
                                    ),
                                onChanged: (_) =>
                                    setState(() => _notice = null),
                                decoration: InputDecoration(
                                  labelText: l10n.markScoreLabel(
                                    _number(answer.question.maximumScore),
                                  ),
                                  errorText: _invalid[answer.question.id],
                                  border: const OutlineInputBorder(),
                                  isDense: true,
                                ),
                              ),
                              const SizedBox(height: 8),
                              TextField(
                                controller: _comments[answer.question.id],
                                enabled: !_saving,
                                minLines: 1,
                                maxLines: 4,
                                maxLength: 5000,
                                onChanged: (_) =>
                                    setState(() => _notice = null),
                                decoration: InputDecoration(
                                  labelText: l10n.markAnswerFeedback,
                                  border: const OutlineInputBorder(),
                                  isDense: true,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    TextField(
                      controller: _overall,
                      enabled: !_saving,
                      minLines: 2,
                      maxLines: 6,
                      maxLength: 5000,
                      onChanged: (_) => setState(() => _notice = null),
                      decoration: InputDecoration(
                        labelText: l10n.markOverallFeedback,
                        helperText: l10n.markOverallFeedbackHelp,
                        border: const OutlineInputBorder(),
                      ),
                    ),
                    if (_error != null)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: Text(
                          _error!,
                          style: TextStyle(
                            color: Theme.of(context).colorScheme.error,
                          ),
                        ),
                      ),
                    if (_notice != null)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: Semantics(
                          liveRegion: true,
                          child: Row(
                            children: [
                              Icon(
                                Icons.check_circle_outline,
                                size: 18,
                                color: Theme.of(context).colorScheme.primary,
                              ),
                              const SizedBox(width: 8),
                              Expanded(child: Text(_notice!)),
                            ],
                          ),
                        ),
                      ),
                    FilledButton.icon(
                      onPressed: _saving ? null : _save,
                      icon: _saving
                          ? const SizedBox.square(
                              dimension: 18,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.save_outlined),
                      label: Text(
                        attempt.publishedAbsent
                            ? l10n.markReplaceAbsence
                            : attempt.published
                            ? l10n.markSaveChanges
                            : l10n.markSaveDraft,
                      ),
                    ),
                  ],
                ),
        ),
      ),
    );
  }
}

/// The reason for changing a grade the student and parents already see.
/// Owns its controller, so it is not disposed while the dialog closes.
class _CorrectionReasonDialog extends StatefulWidget {
  const _CorrectionReasonDialog();

  @override
  State<_CorrectionReasonDialog> createState() =>
      _CorrectionReasonDialogState();
}

class _CorrectionReasonDialogState extends State<_CorrectionReasonDialog> {
  final _reason = TextEditingController();

  @override
  void dispose() {
    _reason.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppL10n.of(context);
    final ready = _reason.text.trim().length >= 3;
    return AlertDialog(
      title: Text(l10n.markCorrectionTitle),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(l10n.markCorrectionBody),
          const SizedBox(height: 12),
          TextField(
            controller: _reason,
            autofocus: true,
            maxLength: 500,
            onChanged: (_) => setState(() {}),
            decoration: InputDecoration(
              labelText: l10n.markCorrectionReason,
              border: const OutlineInputBorder(),
            ),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(l10n.linksCancel),
        ),
        FilledButton(
          onPressed: ready
              ? () => Navigator.pop(context, _reason.text.trim())
              : null,
          child: Text(l10n.markSaveCorrection),
        ),
      ],
    );
  }
}
