import 'package:flutter/material.dart';

import '../../../core/feedback.dart';
import '../../../core/file_upload_repository.dart';
import '../../../core/navigation.dart';
import '../../../core/studafy_components.dart';
import '../../../core/studafy_design.dart';
import '../../../l10n/generated/app_l10n.dart';
import '../domain/academic_repository.dart';
import 'assessment_builder_page.dart';
import 'assessment_page.dart';

/// A teacher's view of an online assessment (ADR-0036): every submission,
/// what still needs marking, and the actions around it - edit, give one
/// student more time or attempts, publish the grades, release the answers.
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
  bool _failed = false;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _failed = false);
    try {
      final (attempts, records) = await (
        widget.repository.attempts(widget.assessmentId),
        widget.repository.load(
          AcademicFeed.assessments,
          classroomId: widget.classroomId,
        ),
      ).wait;
      if (!mounted) return;
      setState(() {
        _attempts = attempts;
        _assessment = records
            .where((r) => r.id == widget.assessmentId)
            .firstOrNull
            ?.online;
      });
    } on Object {
      if (mounted) setState(() => _failed = true);
    }
  }

  Future<void> _run(Future<String> Function() action) async {
    if (_busy) return;
    final messenger = ScaffoldMessenger.of(context);
    setState(() => _busy = true);
    try {
      messenger.showMessage(await action());
    } finally {
      if (mounted) setState(() => _busy = false);
    }
    await _load();
  }

  Future<void> _publishGrades() => _run(() async {
    final l10n = AppL10n.of(context);
    try {
      final sheet = await widget.repository.paperGradebook(widget.assessmentId);
      if (sheet.item.ready == 0) return l10n.markNothingToPublish;
      final done = await widget.repository.publishGrades(
        widget.assessmentId,
        sheet.item.gradebookVersion,
      );
      return l10n.markPublished(done.published);
    } on Object {
      return l10n.courseworkFailed;
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
      builder: (_) => _GrantDialog(
        repository: widget.repository,
        assessmentId: widget.assessmentId,
        students: students,
        closesAt: _assessment?.settings.closesAt,
      ),
    );
    if (granted ?? false) messenger.showMessage(l10n.markGranted);
  }

  Future<void> _open(AttemptDetail attempt) async {
    await Navigator.of(context).pushOnce<void>(
      MaterialPageRoute<void>(
        builder: (_) => MarkAttemptPage(
          repository: widget.repository,
          attemptId: attempt.id,
          studentName: attempt.studentName ?? '',
        ),
      ),
    );
    await _load();
  }

  static String _number(double value) =>
      value == value.roundToDouble() ? value.toInt().toString() : '$value';

  @override
  Widget build(BuildContext context) {
    final l10n = AppL10n.of(context);
    final attempts = _attempts;
    final max = _assessment?.maximumScore;
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
              _ => _publishGrades(),
            },
            itemBuilder: (_) => [
              PopupMenuItem(value: 'edit', child: Text(l10n.markEditQuestions)),
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
            : RefreshIndicator(
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
                    const SizedBox(height: 8),
                    if (attempts.isEmpty)
                      StudafyEmptyState(
                        icon: Icons.inbox_outlined,
                        title: l10n.markNone,
                      ),
                    for (final attempt in attempts)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: FeatureCard(
                          onTap: () => _open(attempt),
                          child: Row(
                            children: [
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      attempt.studentName ?? '',
                                      style: const TextStyle(
                                        fontWeight: FontWeight.w800,
                                      ),
                                    ),
                                    Text(
                                      l10n.takeAttemptLine(
                                        attempt.attemptNumber ?? 1,
                                        MaterialLocalizations.of(
                                          context,
                                        ).formatMediumDate(attempt.submittedAt),
                                      ),
                                      style: const TextStyle(
                                        color: studafyMuted,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              StatusPill(
                                label: attempt.needsMarking ?? false
                                    ? l10n.markNeeds
                                    : l10n.markDone(
                                        _number(attempt.awardedScore ?? 0),
                                        max == null ? '' : _number(max),
                                      ),
                                icon: attempt.needsMarking ?? false
                                    ? Icons.edit_note_rounded
                                    : Icons.check_circle_rounded,
                                color: attempt.needsMarking ?? false
                                    ? studafyDanger
                                    : studafyTeal,
                              ),
                            ],
                          ),
                        ),
                      ),
                  ],
                ),
              ),
      ),
    );
  }
}

class _GrantDialog extends StatefulWidget {
  const _GrantDialog({
    required this.repository,
    required this.assessmentId,
    required this.students,
    this.closesAt,
  });

  final OnlineAssessmentRepository repository;
  final String assessmentId;
  final List<ClassStudent> students;
  final DateTime? closesAt;

  @override
  State<_GrantDialog> createState() => _GrantDialogState();
}

class _GrantDialogState extends State<_GrantDialog> {
  String? _student;
  DateTime? _until;
  int _extra = 0;
  bool _saving = false;
  String? _error;

  Future<void> _pick() async {
    final now = DateTime.now();
    final start = widget.closesAt != null && widget.closesAt!.isAfter(now)
        ? widget.closesAt!
        : now.add(const Duration(days: 1));
    final date = await showDatePicker(
      context: context,
      initialDate: start,
      firstDate: now,
      lastDate: now.add(const Duration(days: 365)),
    );
    if (date == null || !mounted) return;
    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(start),
    );
    if (!mounted) return;
    setState(
      () => _until = DateTime(
        date.year,
        date.month,
        date.day,
        time?.hour ?? 23,
        time?.minute ?? 59,
      ),
    );
  }

  Future<void> _save() async {
    final l10n = AppL10n.of(context);
    final student = _student;
    if (student == null || (_until == null && _extra == 0)) return;
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      await widget.repository.grantAccess(
        widget.assessmentId,
        student,
        closesAt: _until,
        extraAttempts: _extra,
      );
      if (mounted) Navigator.of(context).pop(true);
    } on Object {
      if (!mounted) return;
      setState(() {
        _saving = false;
        _error = l10n.markGrantFailed;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppL10n.of(context);
    final until = _until;
    return AlertDialog(
      title: Text(l10n.markGrantAccess),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          DropdownButtonFormField<String>(
            initialValue: _student,
            decoration: InputDecoration(labelText: l10n.markGrantStudent),
            items: [
              for (final s in widget.students)
                DropdownMenuItem(value: s.id, child: Text(s.displayName)),
            ],
            onChanged: _saving ? null : (id) => setState(() => _student = id),
          ),
          ListTile(
            contentPadding: EdgeInsets.zero,
            title: Text(l10n.markGrantUntil),
            subtitle: Text(
              until == null
                  ? l10n.builderNotSet
                  : '${MaterialLocalizations.of(context).formatShortDate(until)} '
                        '${MaterialLocalizations.of(context).formatTimeOfDay(TimeOfDay.fromDateTime(until))}',
            ),
            onTap: _saving ? null : _pick,
          ),
          Row(
            children: [
              Expanded(child: Text(l10n.markGrantExtra)),
              IconButton(
                onPressed: _saving || _extra == 0
                    ? null
                    : () => setState(() => _extra--),
                icon: const Icon(Icons.remove_circle_outline_rounded),
              ),
              Text('$_extra'),
              IconButton(
                onPressed: _saving || _extra >= 20
                    ? null
                    : () => setState(() => _extra++),
                icon: const Icon(Icons.add_circle_outline_rounded),
              ),
            ],
          ),
          if (_error != null)
            Text(
              _error!,
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: _saving ? null : () => Navigator.pop(context, false),
          child: Text(l10n.linksCancel),
        ),
        FilledButton(
          onPressed:
              _saving || _student == null || (_until == null && _extra == 0)
              ? null
              : _save,
          child: Text(l10n.markGrantGive),
        ),
      ],
    );
  }
}

/// Marking one attempt: every answer with the key, the automatic mark where
/// there is one, and a score and comment the teacher can set or change.
class MarkAttemptPage extends StatefulWidget {
  const MarkAttemptPage({
    super.key,
    required this.repository,
    required this.attemptId,
    required this.studentName,
  });

  final OnlineAssessmentRepository repository;
  final String attemptId;
  final String studentName;

  @override
  State<MarkAttemptPage> createState() => _MarkAttemptPageState();
}

class _MarkAttemptPageState extends State<MarkAttemptPage> {
  AttemptDetail? _attempt;
  bool _failed = false;
  bool _saving = false;
  String? _error;
  final Map<String, TextEditingController> _scores = {};
  final Map<String, TextEditingController> _comments = {};
  final _overall = TextEditingController();

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    for (final c in [..._scores.values, ..._comments.values]) {
      c.dispose();
    }
    _overall.dispose();
    super.dispose();
  }

  static String _number(double value) =>
      value == value.roundToDouble() ? value.toInt().toString() : '$value';

  Future<void> _load() async {
    setState(() => _failed = false);
    try {
      final attempt = await widget.repository.attempt(widget.attemptId);
      if (!mounted) return;
      setState(() {
        _attempt = attempt;
        _overall.text = attempt.feedback ?? '';
        for (final a in attempt.answers) {
          _scores[a.question.id] = TextEditingController(
            text: a.awardedScore == null ? '' : _number(a.awardedScore!),
          );
          _comments[a.question.id] = TextEditingController(
            text: a.feedback ?? '',
          );
        }
      });
    } on Object {
      if (mounted) setState(() => _failed = true);
    }
  }

  Future<void> _save() async {
    final l10n = AppL10n.of(context);
    final attempt = _attempt;
    if (attempt == null) return;
    final marks = <AnswerMark>[];
    for (final a in attempt.answers) {
      final text = _scores[a.question.id]!.text.trim();
      final comment = _comments[a.question.id]!.text.trim();
      if (text.isEmpty) continue;
      final score = double.tryParse(text);
      if (score == null || score < 0 || score > a.question.maximumScore) {
        setState(
          () =>
              _error = l10n.markScoreInvalid(_number(a.question.maximumScore)),
        );
        return;
      }
      if (score != a.awardedScore || comment != (a.feedback ?? '')) {
        marks.add(
          AnswerMark(
            questionId: a.question.id,
            score: score,
            feedback: comment.isEmpty ? null : comment,
          ),
        );
      }
    }
    setState(() {
      _saving = true;
      _error = null;
    });
    final messenger = ScaffoldMessenger.of(context);
    try {
      final updated = await widget.repository.markAttempt(
        attempt.id,
        marks,
        feedback: _overall.text.trim().isEmpty ? null : _overall.text.trim(),
      );
      if (!mounted) return;
      setState(() {
        _attempt = updated;
        _saving = false;
      });
      messenger.showMessage(l10n.markSaved);
    } on Object {
      if (!mounted) return;
      setState(() {
        _saving = false;
        _error = l10n.markSaveFailed;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppL10n.of(context);
    final attempt = _attempt;
    return Scaffold(
      appBar: AppBar(title: Text(widget.studentName)),
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
                  for (final answer in attempt.answers)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: FeatureCard(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            AnswerReview(answer: answer),
                            if (answer.autoScore != null)
                              Padding(
                                padding: const EdgeInsets.only(top: 6),
                                child: Text(
                                  l10n.markAuto,
                                  style: Theme.of(context).textTheme.bodySmall,
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
                              decoration: InputDecoration(
                                labelText: l10n.markScoreLabel(
                                  _number(answer.question.maximumScore),
                                ),
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
                    decoration: InputDecoration(
                      labelText: l10n.markOverallFeedback,
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
                  FilledButton(
                    onPressed: _saving ? null : _save,
                    child: Text(l10n.markSave),
                  ),
                ],
              ),
      ),
    );
  }
}
