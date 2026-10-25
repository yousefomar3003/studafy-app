import 'package:flutter/material.dart';

import '../../../core/navigation.dart';
import '../../../core/studafy_components.dart';
import '../../../l10n/generated/app_l10n.dart';
import '../domain/academic_repository.dart';
import 'assessment_marking_page.dart';
import 'coursework_messages.dart';
import 'gradebook_item_dialog.dart';
import 'paper_gradebook_page.dart';

/// One class's graded work, to pick the piece to mark.
///
/// Named apart from the legacy GradebookPage in teacher_features.dart, which
/// is the preview dashboard's own screen over the local database.
///
/// Marks are not entered on this screen. Work answered in the app is marked
/// from each student's answers; paper work - a paper exam, or the mark for an
/// assignment - on the class's grade sheet. Both keep marks as drafts until
/// they are published together, and change published ones only as
/// corrections. This screen used to save each student's mark on its own,
/// which refused any mark already published and reported success for rows it
/// had skipped.
class ClassGradebookPage extends StatefulWidget {
  const ClassGradebookPage({
    super.key,
    required this.repository,
    required this.classroomId,
    required this.classroomName,
    this.focusAssignmentId,
    this.initialAssessmentId,
  });

  final AcademicRepository repository;
  final String classroomId;
  final String classroomName;

  /// Opens on the mark for this assignment, when coming from its hand-ins.
  final String? focusAssignmentId;

  /// Opens on this piece of graded work, when chosen in the Gradebook.
  final String? initialAssessmentId;

  @override
  State<ClassGradebookPage> createState() => _ClassGradebookPageState();
}

class _ClassGradebookPageState extends State<ClassGradebookPage> {
  List<AcademicRecord> _assessments = const [];
  AcademicRecord? _selected;
  bool _loading = true;
  bool _saving = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final assessments = await widget.repository.load(
        AcademicFeed.assessments,
        classroomId: widget.classroomId,
      );
      if (!mounted) return;
      setState(() {
        _assessments = assessments;
        final focus = widget.focusAssignmentId;
        final initial = widget.initialAssessmentId;
        final focused = focus != null
            ? assessments
                  .where((item) => item.markedAssignmentId == focus)
                  .firstOrNull
            : initial != null
            ? assessments.where((item) => item.id == initial).firstOrNull
            : null;
        _selected = assessments.any((item) => item.id == _selected?.id)
            ? assessments.firstWhere((item) => item.id == _selected!.id)
            : (focused ?? (assessments.isEmpty ? null : assessments.first));
        _loading = false;
      });
    } on Object {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = AppL10n.of(context).gradebookLoadFailed;
      });
    }
  }

  Future<void> _publishSelected() async {
    final selected = _selected;
    if (selected == null || _saving) return;
    final l10n = AppL10n.of(context);
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      await widget.repository.publishAssessment(selected.id, selected.version);
      if (!mounted) return;
      setState(() => _saving = false);
      await _load();
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
        _error = l10n.academicPublishFailed;
      });
    }
  }

  static bool _isPaper(AcademicRecord? item) => item?.delivery == 'paper';

  Future<void> _openSheet(String assessmentId) async {
    // The mark for a graded assignment: its hand-ins can be suggested.
    final handIn = _assessments.any(
      (item) => item.id == assessmentId && item.markedAssignmentId != null,
    );
    await Navigator.of(context).pushOnce(
      MaterialPageRoute<void>(
        builder: (_) => PaperGradebookPage(
          repository: widget.repository,
          assessmentId: assessmentId,
          attachments: widget.repository,
          classroomId: widget.classroomId,
          handIn: handIn,
        ),
      ),
    );
    if (mounted) await _load();
  }

  Future<void> _openAnswers(AcademicRecord item) async {
    await Navigator.of(context).pushOnce(
      MaterialPageRoute<void>(
        builder: (_) => AssessmentMarkingPage(
          repository: widget.repository,
          assessmentId: item.id,
          title: item.title,
          classroomId: widget.classroomId,
        ),
      ),
    );
    if (mounted) await _load();
  }

  Future<void> _newPaperGrade() async {
    final l10n = AppL10n.of(context);
    final details = await showGradebookItemDialog(context);
    if (details == null || !mounted) return;
    try {
      final id = await widget.repository.createPaperGradebookItem(
        widget.classroomId,
        title: details.title,
        category: details.category,
        maximumScore: details.maximumScore,
        weight: details.weight,
        scheduledAt: details.scheduledAt,
      );
      if (!mounted) return;
      await _openSheet(id);
    } on CourseworkRefusal catch (refusal) {
      if (mounted) setState(() => _error = courseworkMessage(l10n, refusal));
    } on Object {
      if (mounted) setState(() => _error = l10n.gradebookSaveFailed);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppL10n.of(context);
    final selected = _selected;
    final paper = _isPaper(selected);
    final isDraft = selected != null && selected.state == 'draft' && !paper;
    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.gradebookTitle(widget.classroomName)),
        actions: [
          TextButton.icon(
            onPressed: _saving || _loading ? null : _newPaperGrade,
            icon: const Icon(Icons.post_add_outlined),
            label: Text(l10n.paperGradesNew),
          ),
        ],
      ),
      body: SafeArea(
        child: _loading
            ? const Center(child: CircularProgressIndicator())
            : _assessments.isEmpty
            ? Center(
                child: _error != null
                    ? StudafyEmptyState(
                        icon: Icons.wifi_off_rounded,
                        title: _error!,
                        actionLabel: l10n.paperGradesRetry,
                        onAction: _load,
                      )
                    : Padding(
                        padding: const EdgeInsets.all(24),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              l10n.gradebookNoAssessments,
                              textAlign: TextAlign.center,
                            ),
                            const SizedBox(height: 12),
                            OutlinedButton.icon(
                              onPressed: _newPaperGrade,
                              icon: const Icon(Icons.post_add_outlined),
                              label: Text(l10n.paperGradesNew),
                            ),
                          ],
                        ),
                      ),
              )
            : Column(
                children: [
                  Padding(
                    padding: const EdgeInsetsDirectional.fromSTEB(16, 8, 16, 8),
                    child: DropdownButtonFormField<String>(
                      initialValue: selected?.id,
                      isExpanded: true,
                      decoration: InputDecoration(
                        labelText: l10n.gradebookPickAssessment,
                        prefixIcon: const Icon(Icons.grading_rounded),
                      ),
                      items: [
                        for (final item in _assessments)
                          DropdownMenuItem(
                            value: item.id,
                            child: Text(
                              _isPaper(item)
                                  ? '${item.title} · ${l10n.paperGradesPaperLabel}'
                                  : item.title,
                            ),
                          ),
                      ],
                      onChanged: _saving
                          ? null
                          : (value) => setState(() {
                              _selected = _assessments
                                  .where((item) => item.id == value)
                                  .firstOrNull;
                              _error = null;
                            }),
                    ),
                  ),
                  if (_error != null)
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: Text(
                        _error!,
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.error,
                        ),
                      ),
                    ),
                  Expanded(
                    child: selected == null
                        ? const SizedBox.shrink()
                        : paper
                        ? _Notice(
                            icon: Icons.description_rounded,
                            title: l10n.paperGradesSheetHint,
                            action: l10n.paperGradesOpenSheet,
                            onAction: () => _openSheet(selected.id),
                          )
                        : isDraft
                        ? _Notice(
                            icon: Icons.edit_note_rounded,
                            title: l10n.gradebookDraftNotice,
                            action: l10n.gradebookPublishAssessment,
                            onAction: _saving ? null : _publishSelected,
                          )
                        : _Notice(
                            icon: Icons.laptop_mac_rounded,
                            title: l10n.gradebookOnlineHint,
                            action: l10n.gradebookOpenAnswers,
                            onAction: () => _openAnswers(selected),
                          ),
                  ),
                ],
              ),
      ),
    );
  }
}

class _Notice extends StatelessWidget {
  const _Notice({
    required this.icon,
    required this.title,
    required this.action,
    required this.onAction,
  });

  final IconData icon;
  final String title;
  final String action;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) => Center(
    child: StudafyEmptyState(
      icon: icon,
      title: title,
      actionLabel: action,
      onAction: onAction,
    ),
  );
}
