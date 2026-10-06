import 'package:flutter/material.dart';

import '../../../core/navigation.dart';
import '../../../core/studafy_components.dart';
import '../../../core/studafy_design.dart';
import '../../../core/user_content_text.dart';
import '../../../l10n/generated/app_l10n.dart';
import '../domain/academic_repository.dart';
import 'coursework_messages.dart';
import 'gradebook_item_dialog.dart';
import 'gradebook_page.dart';
import 'paper_gradebook_page.dart';

/// The Gradebook tab: every mark a teacher gives, in one place.
///
/// Organised the way a teacher thinks about marks - pick a class, see its
/// graded work split into paper and online, each saying whether it is still
/// a draft or already published, then open one to mark the class. Teaching
/// content (lessons, setting work) stays on the Teaching tab; the only
/// links back are contextual, from a mark to the hand-ins it grades.
class GradebookHomePage extends StatefulWidget {
  const GradebookHomePage({
    super.key,
    required this.repository,
    required this.loadClassChoices,
    this.onOpenAssignment,
  });

  final AcademicRepository repository;
  final Future<List<ClassChoice>> Function() loadClassChoices;

  /// Opens the hand-ins of the assignment a mark belongs to.
  final void Function(AcademicRecord assignment)? onOpenAssignment;

  @override
  State<GradebookHomePage> createState() => _GradebookHomePageState();
}

class _GradebookHomePageState extends State<GradebookHomePage> {
  List<ClassChoice> _classes = const [];
  ClassChoice? _selected;
  List<AcademicRecord> _assessments = const [];
  Map<String, AcademicRecord> _assignments = const {};
  bool _loadingClasses = true;
  bool _loading = false;

  /// The class whose lists are on screen.
  String? _shownClassId;
  bool _failed = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadClasses();
  }

  Future<void> _loadClasses() async {
    setState(() {
      _loadingClasses = true;
      _failed = false;
    });
    try {
      final classes = await widget.loadClassChoices();
      if (!mounted) return;
      setState(() {
        _classes = classes;
        _selected = classes.any((c) => c.id == _selected?.id)
            ? _selected
            : classes.firstOrNull;
        _loadingClasses = false;
      });
      await _loadClass();
    } on Object {
      if (!mounted) return;
      setState(() {
        _loadingClasses = false;
        _failed = true;
      });
    }
  }

  Future<void> _loadClass() async {
    final selected = _selected;
    if (selected == null) return;
    setState(() {
      // Coming back to the same class keeps its list on screen; only another
      // class, whose list is not this one, waits behind the spinner.
      _loading = _shownClassId != selected.id;
      _failed = false;
      _error = null;
    });
    try {
      // Both at once: neither waits on the other.
      final (assessments, assignments) = await (
        widget.repository.load(
          AcademicFeed.assessments,
          classroomId: selected.id,
        ),
        widget.repository.load(
          AcademicFeed.assignments,
          classroomId: selected.id,
        ),
      ).wait;
      if (!mounted || selected.id != _selected?.id) return;
      setState(() {
        _assessments = assessments;
        _assignments = {for (final item in assignments) item.id: item};
        _loading = false;
        _shownClassId = selected.id;
      });
    } on Object {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _failed = true;
      });
    }
  }

  /// Paper work recorded after the fact is marked on its own grade sheet.
  static bool _isPaperSheet(AcademicRecord item) =>
      item.delivery == 'paper' && item.markedAssignmentId == null;

  Future<void> _open(AcademicRecord item) async {
    final selected = _selected;
    if (selected == null) return;
    await Navigator.of(context).pushOnce(
      MaterialPageRoute<void>(
        builder: (_) => _isPaperSheet(item)
            ? PaperGradebookPage(
                repository: widget.repository,
                assessmentId: item.id,
              )
            : ClassGradebookPage(
                repository: widget.repository,
                classroomId: selected.id,
                classroomName: selected.name,
                initialAssessmentId: item.id,
              ),
      ),
    );
    if (mounted) await _loadClass();
  }

  Future<void> _markOnline() async {
    final selected = _selected;
    if (selected == null) return;
    await Navigator.of(context).pushOnce(
      MaterialPageRoute<void>(
        builder: (_) => ClassGradebookPage(
          repository: widget.repository,
          classroomId: selected.id,
          classroomName: selected.name,
        ),
      ),
    );
    if (mounted) await _loadClass();
  }

  Future<void> _newPaperGrade() async {
    final selected = _selected;
    if (selected == null) return;
    final l10n = AppL10n.of(context);
    final details = await showGradebookItemDialog(context);
    if (details == null || !mounted) return;
    try {
      final id = await widget.repository.createPaperGradebookItem(
        selected.id,
        title: details.title,
        category: details.category,
        maximumScore: details.maximumScore,
        weight: details.weight,
        scheduledAt: details.scheduledAt,
      );
      if (!mounted) return;
      await Navigator.of(context).pushOnce(
        MaterialPageRoute<void>(
          builder: (_) => PaperGradebookPage(
            repository: widget.repository,
            assessmentId: id,
          ),
        ),
      );
      if (mounted) await _loadClass();
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
    return Scaffold(
      appBar: AppBar(title: Text(l10n.navGradebook)),
      body: _loadingClasses
          ? const Center(child: CircularProgressIndicator())
          : _classes.isEmpty
          ? Center(
              child: _failed
                  ? StudafyEmptyState(
                      icon: Icons.wifi_off_rounded,
                      title: l10n.gradebookLoadFailed,
                      actionLabel: l10n.paperGradesRetry,
                      onAction: _loadClasses,
                    )
                  : StudafyEmptyState(
                      icon: Icons.class_outlined,
                      title: l10n.todayEmpty,
                      message: l10n.gradebookHomeNoClasses,
                    ),
            )
          : Column(
              children: [
                PillTabs<ClassChoice>(
                  values: _classes,
                  selected: selected!,
                  label: (choice) => choice.name,
                  icon: (choice) => subjectIcon(choice.name),
                  onSelected: (choice) {
                    setState(() => _selected = choice);
                    _loadClass();
                  },
                ),
                Expanded(
                  child: StudafyRefreshIndicator(
                    onRefresh: _loadClass,
                    child: ListView(
                      padding: const EdgeInsetsDirectional.fromSTEB(
                        20,
                        12,
                        20,
                        32,
                      ),
                      children: [
                        _ClassSummary(
                          name: selected.name,
                          total: _assessments.length,
                          drafts: _assessments
                              .where((a) => a.state == 'draft')
                              .length,
                          onNewPaper: _loading ? null : _newPaperGrade,
                          onMarkOnline: _loading ? null : _markOnline,
                        ),
                        if (_error != null)
                          Padding(
                            padding: const EdgeInsets.only(top: 12),
                            child: Text(
                              _error!,
                              style: const TextStyle(color: studafyDanger),
                            ),
                          ),
                        if (_loading)
                          const Padding(
                            padding: EdgeInsets.all(32),
                            child: Center(child: CircularProgressIndicator()),
                          )
                        else if (_failed)
                          StudafyEmptyState(
                            icon: Icons.wifi_off_rounded,
                            title: l10n.gradebookLoadFailed,
                            actionLabel: l10n.paperGradesRetry,
                            onAction: _loadClass,
                          )
                        else if (_assessments.isEmpty)
                          StudafyEmptyState(
                            icon: Icons.grading_rounded,
                            title: l10n.gradebookHomeNothing,
                            message: l10n.gradebookHomeNothingDetail,
                          )
                        else ...[
                          for (final paper in [true, false])
                            if (_assessments.any(
                              (a) => (a.delivery == 'paper') == paper,
                            )) ...[
                              SectionHeader(
                                paper
                                    ? l10n.paperGradesPaperSection
                                    : l10n.paperGradesOnlineSection,
                              ),
                              for (final item in _assessments)
                                if ((item.delivery == 'paper') == paper)
                                  Padding(
                                    padding: const EdgeInsets.only(bottom: 10),
                                    child: _AssessmentCard(
                                      item: item,
                                      linkedAssignment:
                                          _assignments[item.markedAssignmentId],
                                      onOpen: () => _open(item),
                                      onOpenAssignment: widget.onOpenAssignment,
                                    ),
                                  ),
                            ],
                        ],
                      ],
                    ),
                  ),
                ),
              ],
            ),
    );
  }
}

class _ClassSummary extends StatelessWidget {
  const _ClassSummary({
    required this.name,
    required this.total,
    required this.drafts,
    required this.onNewPaper,
    required this.onMarkOnline,
  });

  final String name;
  final int total;
  final int drafts;
  final VoidCallback? onNewPaper;
  final VoidCallback? onMarkOnline;

  @override
  Widget build(BuildContext context) {
    final l10n = AppL10n.of(context);
    return FeatureCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              IconBadge(icon: subjectIcon(name)),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    UserContentText(
                      name,
                      style: const TextStyle(
                        color: studafyInk,
                        fontSize: 17,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    Text(
                      l10n.gradebookHomeCounts(total, drafts),
                      style: const TextStyle(
                        color: studafyMuted,
                        fontSize: 12.5,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          // Stacked, so each action reads in full at any text size.
          FilledButton.icon(
            onPressed: onNewPaper,
            icon: const Icon(Icons.post_add_rounded),
            label: Text(l10n.paperGradesNew),
          ),
          const SizedBox(height: 8),
          OutlinedButton.icon(
            onPressed: onMarkOnline,
            icon: const Icon(Icons.edit_note_rounded),
            label: Text(l10n.gradebookMarkOnline),
          ),
        ],
      ),
    );
  }
}

class _AssessmentCard extends StatelessWidget {
  const _AssessmentCard({
    required this.item,
    required this.linkedAssignment,
    required this.onOpen,
    required this.onOpenAssignment,
  });

  final AcademicRecord item;
  final AcademicRecord? linkedAssignment;
  final VoidCallback onOpen;
  final void Function(AcademicRecord assignment)? onOpenAssignment;

  static String _number(double value) =>
      value == value.roundToDouble() ? value.toInt().toString() : '$value';

  @override
  Widget build(BuildContext context) {
    final l10n = AppL10n.of(context);
    final paper = item.delivery == 'paper';
    final draft = item.state == 'draft';
    final linked = linkedAssignment;
    return FeatureCard(
      onTap: onOpen,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              IconBadge(
                icon: paper
                    ? Icons.description_rounded
                    : Icons.laptop_mac_rounded,
                color: paper ? studafyNavy : studafyCyan,
                size: 42,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    UserContentText(
                      item.title,
                      style: const TextStyle(
                        color: studafyInk,
                        fontWeight: FontWeight.w800,
                        fontSize: 15.5,
                      ),
                    ),
                    if (item.maximumScore case final max?)
                      Text(
                        l10n.academicGradedOutOf(_number(max)),
                        style: const TextStyle(
                          color: studafyMuted,
                          fontSize: 12.5,
                        ),
                      ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              StatusPill(
                label: draft
                    ? l10n.paperGradesStateDraft
                    : l10n.paperGradesStatePublished,
                icon: draft
                    ? Icons.edit_note_rounded
                    : Icons.check_circle_rounded,
                color: draft ? studafyMuted : studafyNavy,
              ),
            ],
          ),
          if (linked != null && onOpenAssignment != null)
            Align(
              alignment: AlignmentDirectional.centerStart,
              child: Padding(
                padding: const EdgeInsets.only(top: 6),
                child: TextButton.icon(
                  onPressed: () => onOpenAssignment!(linked),
                  icon: const Icon(Icons.assignment_outlined, size: 18),
                  label: Text(l10n.gradebookViewHandIns),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
