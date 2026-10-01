import 'package:flutter/material.dart';

import '../../../core/studafy_formatting.dart';
import '../../../l10n/generated/app_l10n.dart';
import '../domain/academic_repository.dart';
import 'coursework_messages.dart';

/// Correcting one published mark: the new mark, a required reason, and every
/// earlier change to it. Answers true when the mark was corrected.
Future<bool?> showGradeCorrectionSheet(
  BuildContext context, {
  required PaperGradebookRepository repository,
  required String assessmentId,
  required String studentName,
  required PaperGrade grade,
  required double maximumScore,
}) => showModalBottomSheet<bool>(
  context: context,
  isScrollControlled: true,
  builder: (_) => _GradeCorrectionSheet(
    repository: repository,
    assessmentId: assessmentId,
    studentName: studentName,
    grade: grade,
    maximumScore: maximumScore,
  ),
);

class _GradeCorrectionSheet extends StatefulWidget {
  const _GradeCorrectionSheet({
    required this.repository,
    required this.assessmentId,
    required this.studentName,
    required this.grade,
    required this.maximumScore,
  });

  final PaperGradebookRepository repository;
  final String assessmentId;
  final String studentName;
  final PaperGrade grade;
  final double maximumScore;

  @override
  State<_GradeCorrectionSheet> createState() => _GradeCorrectionSheetState();
}

class _GradeCorrectionSheetState extends State<_GradeCorrectionSheet> {
  late GradeMark _mark = widget.grade.mark ?? GradeMark.scored;
  late final _score = TextEditingController(
    text: widget.grade.score == null ? '' : _number(widget.grade.score!),
  );
  late final _feedback = TextEditingController(text: widget.grade.feedback);
  final _reason = TextEditingController();
  late final Future<List<GradeChange>> _history = widget.repository
      .gradeHistory(widget.grade.id);
  bool _saving = false;
  String? _error;

  static String _number(double value) =>
      value == value.roundToDouble() ? value.toInt().toString() : '$value';

  @override
  void dispose() {
    _score.dispose();
    _feedback.dispose();
    _reason.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final l10n = AppL10n.of(context);
    final score = _mark == GradeMark.scored
        ? double.tryParse(_score.text.trim().replaceAll(',', '.'))
        : null;
    if (_mark == GradeMark.scored &&
        (score == null || score < 0 || score > widget.maximumScore)) {
      setState(
        () => _error = l10n.paperGradesRowScoreOutOfRange(
          _number(widget.maximumScore),
        ),
      );
      return;
    }
    if (_reason.text.trim().length < 3) {
      setState(() => _error = l10n.gradeCorrectionReasonTooShort);
      return;
    }
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      await widget.repository.correctGrades(
        widget.assessmentId,
        _reason.text.trim(),
        [
          GradeCorrection(
            gradeId: widget.grade.id,
            expectedVersion: widget.grade.version,
            mark: _mark,
            score: score,
            feedback: _feedback.text.trim().isEmpty
                ? null
                : _feedback.text.trim(),
          ),
        ],
      );
      if (mounted) Navigator.of(context).pop(true);
    } on CourseworkRefusal catch (refusal) {
      if (!mounted) return;
      setState(() {
        _saving = false;
        _error = courseworkMessage(l10n, refusal);
      });
    } on Object {
      if (!mounted) return;
      setState(() {
        _saving = false;
        _error = l10n.courseworkFailed;
      });
    }
  }

  String _describe(AppL10n l10n, GradeMark? mark, double? score) =>
      switch (mark) {
        GradeMark.absent => l10n.paperGradesAbsent,
        GradeMark.notGraded => l10n.paperGradesNotGraded,
        _ => score == null ? l10n.paperGradesUnmarked : _number(score),
      };

  @override
  Widget build(BuildContext context) {
    final l10n = AppL10n.of(context);
    final theme = Theme.of(context);
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                l10n.gradeCorrectionTitle(widget.studentName),
                style: theme.textTheme.titleMedium,
              ),
              const SizedBox(height: 12),
              SegmentedButton<GradeMark>(
                showSelectedIcon: false,
                segments: [
                  ButtonSegment(
                    value: GradeMark.scored,
                    label: Text(l10n.paperGradesScore),
                  ),
                  ButtonSegment(
                    value: GradeMark.absent,
                    label: Text(l10n.paperGradesAbsent),
                  ),
                  ButtonSegment(
                    value: GradeMark.notGraded,
                    label: Text(l10n.paperGradesNotGraded),
                  ),
                ],
                selected: {_mark},
                onSelectionChanged: _saving
                    ? null
                    : (value) => setState(() => _mark = value.first),
              ),
              if (_mark == GradeMark.scored) ...[
                const SizedBox(height: 12),
                TextField(
                  controller: _score,
                  enabled: !_saving,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  decoration: InputDecoration(
                    labelText: l10n.paperGradesScore,
                    suffixText: l10n.paperGradesOutOf(
                      _number(widget.maximumScore),
                    ),
                    border: const OutlineInputBorder(),
                  ),
                ),
              ],
              const SizedBox(height: 12),
              TextField(
                controller: _feedback,
                enabled: !_saving,
                maxLength: 2000,
                minLines: 1,
                maxLines: 4,
                decoration: InputDecoration(
                  labelText: l10n.paperGradesComment,
                  border: const OutlineInputBorder(),
                ),
              ),
              TextField(
                controller: _reason,
                enabled: !_saving,
                maxLength: 500,
                decoration: InputDecoration(
                  labelText: l10n.gradeCorrectionReason,
                  hintText: l10n.gradeCorrectionReasonHint,
                  border: const OutlineInputBorder(),
                ),
              ),
              Text(
                l10n.gradeCorrectionNotifies,
                style: theme.textTheme.bodySmall,
              ),
              if (_error != null)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Text(
                    _error!,
                    style: TextStyle(color: theme.colorScheme.error),
                  ),
                ),
              const SizedBox(height: 12),
              FilledButton(
                onPressed: _saving ? null : _save,
                child: Text(
                  _saving ? l10n.paperGradesSaving : l10n.gradeCorrectionSave,
                ),
              ),
              const SizedBox(height: 20),
              Text(
                l10n.gradeCorrectionHistory,
                style: theme.textTheme.titleSmall,
              ),
              FutureBuilder<List<GradeChange>>(
                future: _history,
                builder: (context, snapshot) {
                  final items = snapshot.data;
                  if (items == null) {
                    return const Padding(
                      padding: EdgeInsets.all(12),
                      child: Center(child: CircularProgressIndicator()),
                    );
                  }
                  if (items.isEmpty) {
                    return Text(l10n.gradeCorrectionHistoryEmpty);
                  }
                  return Column(
                    children: [
                      for (final change in items)
                        ListTile(
                          contentPadding: EdgeInsets.zero,
                          title: Text(
                            change.change == 'corrected'
                                ? '${l10n.gradeCorrectionChangeCorrected}: '
                                      '${_describe(l10n, change.previousMark, change.previousScore)}'
                                      ' → '
                                      '${_describe(l10n, change.nextMark, change.nextScore)}'
                                : '${l10n.gradeCorrectionChangePublished}: '
                                      '${_describe(l10n, change.nextMark, change.nextScore)}',
                          ),
                          subtitle: Text(
                            [
                              studafyDateTime(context, change.at),
                              if (change.actorName case final name?)
                                l10n.gradeCorrectionBy(name),
                              ?change.reason,
                            ].join(' · '),
                          ),
                        ),
                    ],
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}
