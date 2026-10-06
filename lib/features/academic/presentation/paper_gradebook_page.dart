import 'package:flutter/material.dart';

import '../../../core/studafy_design.dart';
import '../../../l10n/generated/app_l10n.dart';
import '../domain/academic_repository.dart';
import 'coursework_messages.dart';
import 'grade_attachments_sheet.dart';
import 'grade_correction_sheet.dart';
import 'gradebook_item_dialog.dart';

/// The grade sheet for one piece of paper work: every student in the class,
/// marked in one table.
///
/// Marks are drafts until the teacher publishes them - students and parents
/// see nothing before that. The whole sheet is saved in one request and
/// published in one, all or nothing; a published mark is changed only by
/// correcting it, which keeps the value it replaced and the reason.
class PaperGradebookPage extends StatefulWidget {
  const PaperGradebookPage({
    super.key,
    required this.repository,
    required this.assessmentId,
    this.attachments,
    this.classroomId,
  });

  final PaperGradebookRepository repository;
  final String assessmentId;

  /// Saves the files and links on the sheet - the class's and each
  /// student's own (ADR-0036). Without it the sheet has marks only.
  final OnlineAssessmentRepository? attachments;

  /// The class the sheet belongs to; scans are uploaded for it.
  final String? classroomId;

  @override
  State<PaperGradebookPage> createState() => _PaperGradebookPageState();
}

/// What the teacher has typed for one row and not saved yet.
class _RowEdit {
  _RowEdit({this.mark, String score = '', String feedback = ''})
    : score = TextEditingController(text: score),
      feedback = TextEditingController(text: feedback);

  GradeMark? mark;
  final TextEditingController score;
  final TextEditingController feedback;
  bool showComment = false;

  void dispose() {
    score.dispose();
    feedback.dispose();
  }
}

class _PaperGradebookPageState extends State<PaperGradebookPage> {
  PaperGradebook? _sheet;
  final Map<String, _RowEdit> _edits = {};
  final Set<String> _dirty = {};

  /// Rows the server refused, by student id, with its reason code.
  Map<String, String> _refused = const {};
  bool _loading = true;
  bool _saving = false;
  bool _loadFailed = false;
  String? _error;
  String? _notice;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    for (final edit in _edits.values) {
      edit.dispose();
    }
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _loadFailed = false;
    });
    try {
      final sheet = await widget.repository.paperGradebook(widget.assessmentId);
      if (!mounted) return;
      setState(() {
        _sheet = sheet;
        for (final edit in _edits.values) {
          edit.dispose();
        }
        _edits
          ..clear()
          ..addEntries([
            for (final row in sheet.rows)
              MapEntry(
                row.studentId,
                _RowEdit(
                  mark: row.grade?.mark,
                  score: _number(row.grade?.score),
                  feedback: row.grade?.feedback ?? '',
                ),
              ),
          ]);
        _dirty.clear();
        _loading = false;
      });
    } on Object {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _loadFailed = true;
      });
    }
  }

  static String _number(double? value) => value == null
      ? ''
      : value == value.roundToDouble()
      ? value.toInt().toString()
      : '$value';

  /// Students with no mark: an unmarked row, or no row at all yet. Neither
  /// is published, and neither is a zero.
  int _unmarked(PaperGradebook sheet) =>
      sheet.item.unmarked + sheet.rows.where((r) => r.grade == null).length;

  void _changed(String studentId) => setState(() {
    _dirty.add(studentId);
    _notice = null;
  });

  /// Rows the teacher can still edit here: not published yet.
  bool _editable(PaperGradebookRow row) =>
      row.grade == null ||
      row.grade!.state == PaperGradeState.unmarked ||
      row.grade!.state == PaperGradeState.ready;

  Future<void> _save() async {
    final sheet = _sheet;
    if (sheet == null || _saving || _dirty.isEmpty) return;
    final l10n = AppL10n.of(context);
    // Checked here first so an obvious slip is pointed at without a round
    // trip; the server checks every row again and refuses the whole sheet.
    final local = <String, String>{};
    final entries = <GradeDraft>[];
    for (final row in sheet.rows) {
      if (!_dirty.contains(row.studentId) || !_editable(row)) continue;
      final edit = _edits[row.studentId]!;
      final text = edit.score.text.trim().replaceAll(',', '.');
      final score = edit.mark == GradeMark.scored
          ? double.tryParse(text)
          : null;
      if (edit.mark == GradeMark.scored) {
        if (score == null) {
          local[row.studentId] = 'score_required';
        } else if (score < 0 || score > sheet.item.maximumScore) {
          local[row.studentId] = 'score_out_of_range';
        }
      }
      entries.add(
        GradeDraft(
          studentId: row.studentId,
          expectedVersion: row.grade?.version ?? 0,
          mark: edit.mark,
          score: score,
          feedback: edit.feedback.text.trim().isEmpty
              ? null
              : edit.feedback.text.trim(),
        ),
      );
    }
    if (local.isNotEmpty) {
      setState(() {
        _refused = local;
        _error = l10n.courseworkEntriesInvalid;
      });
      return;
    }
    if (entries.isEmpty) return;
    setState(() {
      _saving = true;
      _error = null;
      _notice = null;
      _refused = const {};
    });
    final saved = l10n.paperGradesSaved;
    try {
      // A class larger than one request allows is saved in slices, each
      // checked against the sheet as the previous one left it.
      var version = sheet.item.gradebookVersion;
      for (var start = 0; start < entries.length; start += 100) {
        final end = start + 100 < entries.length ? start + 100 : entries.length;
        version = await widget.repository.saveGradeDrafts(
          widget.assessmentId,
          version,
          entries.sublist(start, end),
        );
      }
      if (!mounted) return;
      setState(() => _saving = false);
      await _load();
      if (mounted) setState(() => _notice = saved);
    } on CourseworkRefusal catch (refusal) {
      if (!mounted) return;
      setState(() {
        _saving = false;
        _refused = refusal.rows;
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

  Future<void> _publish() async {
    final sheet = _sheet;
    if (sheet == null || _saving) return;
    final l10n = AppL10n.of(context);
    if (_dirty.isNotEmpty) {
      setState(() => _error = l10n.paperGradesSaveFirst);
      return;
    }
    if (sheet.item.ready == 0) {
      setState(() => _error = l10n.paperGradesNothingToPublish);
      return;
    }
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l10n.paperGradesPublishTitle),
        content: Text(
          l10n.paperGradesPublishBody(sheet.item.ready, _unmarked(sheet)),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(l10n.paperGradesCancel),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: Text(l10n.paperGradesPublish),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      final result = await widget.repository.publishGrades(
        widget.assessmentId,
        sheet.item.gradebookVersion,
      );
      if (!mounted) return;
      setState(() => _saving = false);
      await _load();
      if (mounted) {
        setState(() => _notice = l10n.paperGradesPublished(result.published));
      }
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

  Future<void> _correct(PaperGradebookRow row) async {
    final sheet = _sheet;
    final grade = row.grade;
    if (sheet == null || grade == null) return;
    final changed = await showGradeCorrectionSheet(
      context,
      repository: widget.repository,
      assessmentId: widget.assessmentId,
      studentName: row.displayName,
      grade: grade,
      maximumScore: sheet.item.maximumScore,
    );
    if (changed == true && mounted) {
      await _load();
      if (mounted) {
        setState(() => _notice = AppL10n.of(context).gradeCorrectionDone);
      }
    }
  }

  /// The class's files when [row] is null, otherwise that student's.
  /// Saving them moves the sheet on a version, so unsaved marks go first.
  Future<void> _editFiles([PaperGradebookRow? row]) async {
    final sheet = _sheet;
    final repository = widget.attachments;
    if (sheet == null || repository == null || _saving) return;
    final l10n = AppL10n.of(context);
    if (_dirty.isNotEmpty) {
      setState(() => _error = l10n.paperAttachmentsSaveFirst);
      return;
    }
    final saved = await showGradeAttachmentsSheet(
      context,
      repository: repository,
      assessmentId: widget.assessmentId,
      title: row == null
          ? l10n.paperShared
          : l10n.paperForStudent(row.displayName),
      hint: row == null ? l10n.paperSharedHint : l10n.paperForStudentHint,
      studentId: row?.studentId,
      classroomId: widget.classroomId,
      attachments: row == null
          ? sheet.item.sharedAttachments
          : row.grade?.attachments ?? const [],
      links: row == null
          ? sheet.item.sharedLinks
          : row.grade?.links ?? const [],
    );
    if (saved != true || !mounted) return;
    await _load();
    if (mounted) setState(() => _notice = l10n.paperAttachmentsSaved);
  }

  Future<void> _editItem() async {
    final item = _sheet?.item;
    if (item == null) return;
    final l10n = AppL10n.of(context);
    final details = await showGradebookItemDialog(
      context,
      initial: GradebookItemDetails(
        title: item.title,
        category: item.category,
        maximumScore: item.maximumScore,
        weight: item.weight,
        scheduledAt: item.scheduledAt,
      ),
    );
    if (details == null || !mounted) return;
    try {
      await widget.repository.updateGradebookItem(
        item.id,
        item.version,
        title: details.title,
        category: details.category,
        maximumScore: details.maximumScore,
        weight: details.weight,
        scheduledAt: details.scheduledAt,
      );
      await _load();
    } on CourseworkRefusal catch (refusal) {
      if (mounted) setState(() => _error = courseworkMessage(l10n, refusal));
    } on Object {
      if (mounted) setState(() => _error = l10n.courseworkFailed);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppL10n.of(context);
    final sheet = _sheet;
    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.paperGradesTitle(sheet?.item.title ?? '')),
        actions: [
          if (sheet != null)
            IconButton(
              tooltip: l10n.paperGradesEditItem,
              onPressed: _saving ? null : _editItem,
              icon: const Icon(Icons.edit_outlined),
            ),
        ],
      ),
      body: SafeArea(
        child: _loading
            ? const Center(child: CircularProgressIndicator())
            : _loadFailed || sheet == null
            ? Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(l10n.paperGradesLoadFailed),
                    const SizedBox(height: 12),
                    OutlinedButton(
                      onPressed: _load,
                      child: Text(l10n.paperGradesRetry),
                    ),
                  ],
                ),
              )
            : Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Padding(
                    padding: const EdgeInsetsDirectional.fromSTEB(
                      16,
                      12,
                      16,
                      4,
                    ),
                    child: Wrap(
                      spacing: 8,
                      runSpacing: 4,
                      children: [
                        Chip(label: Text(l10n.paperGradesPaperLabel)),
                        Chip(
                          label: Text(
                            l10n.paperGradesOutOf(
                              _number(sheet.item.maximumScore),
                            ),
                          ),
                        ),
                        if (sheet.item.weight case final weight?)
                          Chip(
                            label: Text(
                              l10n.paperGradesWeight(_number(weight)),
                            ),
                          ),
                      ],
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Text(
                      l10n.paperGradesCounts(
                        sheet.item.ready,
                        sheet.item.published,
                        _unmarked(sheet),
                      ),
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ),
                  if (widget.attachments != null)
                    _SharedFilesTile(
                      count:
                          sheet.item.sharedAttachments.length +
                          sheet.item.sharedLinks.length,
                      onTap: _saving ? null : _editFiles,
                    ),
                  if (_error != null)
                    Padding(
                      padding: const EdgeInsetsDirectional.fromSTEB(
                        16,
                        8,
                        16,
                        0,
                      ),
                      child: Text(
                        _error!,
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.error,
                        ),
                      ),
                    ),
                  if (_notice != null)
                    Padding(
                      padding: const EdgeInsetsDirectional.fromSTEB(
                        16,
                        8,
                        16,
                        0,
                      ),
                      child: Text(_notice!),
                    ),
                  const SizedBox(height: 8),
                  const Divider(height: 1),
                  Expanded(
                    child: sheet.rows.isEmpty
                        ? Center(child: Text(l10n.paperGradesEmpty))
                        : ListView.separated(
                            itemCount: sheet.rows.length,
                            separatorBuilder: (_, _) =>
                                const Divider(height: 1),
                            itemBuilder: (context, i) {
                              final row = sheet.rows[i];
                              return _SheetRow(
                                key: ValueKey(row.studentId),
                                row: row,
                                edit: _edits[row.studentId]!,
                                maximumScore: sheet.item.maximumScore,
                                dirty: _dirty.contains(row.studentId),
                                refusal:
                                    _refused[row.studentId] ??
                                    _refused[row.grade?.id],
                                enabled: !_saving && _editable(row),
                                onChanged: () => _changed(row.studentId),
                                onFiles: widget.attachments == null
                                    ? null
                                    : () => _editFiles(row),
                                onCorrect:
                                    row.grade?.state ==
                                        PaperGradeState.published
                                    ? () => _correct(row)
                                    : null,
                              );
                            },
                          ),
                  ),
                ],
              ),
      ),
      bottomNavigationBar: sheet == null || _loading
          ? null
          : SafeArea(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Row(
                  children: [
                    Expanded(
                      child: FilledButton(
                        onPressed: _saving || _dirty.isEmpty ? null : _save,
                        child: Text(
                          _saving
                              ? l10n.paperGradesSaving
                              : l10n.paperGradesSaveDraft,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: OutlinedButton(
                        onPressed: _saving ? null : _publish,
                        child: Text(l10n.paperGradesPublish),
                      ),
                    ),
                  ],
                ),
              ),
            ),
    );
  }
}

class _SheetRow extends StatelessWidget {
  const _SheetRow({
    super.key,
    required this.row,
    required this.edit,
    required this.maximumScore,
    required this.dirty,
    required this.refusal,
    required this.enabled,
    required this.onChanged,
    required this.onCorrect,
    this.onFiles,
  });

  final PaperGradebookRow row;
  final _RowEdit edit;
  final double maximumScore;
  final bool dirty;

  /// The server's (or the screen's own) reason this row was refused.
  final String? refusal;
  final bool enabled;
  final VoidCallback onChanged;
  final VoidCallback? onCorrect;
  final VoidCallback? onFiles;

  @override
  Widget build(BuildContext context) {
    final l10n = AppL10n.of(context);
    final grade = row.grade;
    final published = grade?.state == PaperGradeState.published;
    final theme = Theme.of(context);
    final status = dirty
        ? l10n.paperGradesStateChanged
        : switch (grade?.state) {
            PaperGradeState.published => l10n.paperGradesStatePublished,
            PaperGradeState.ready => l10n.paperGradesStateReady,
            _ => l10n.paperGradesStateDraft,
          };
    return Container(
      color: refusal == null ? null : theme.colorScheme.errorContainer,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(row.displayName, style: theme.textTheme.titleSmall),
                    if (!row.enrolled)
                      Text(
                        l10n.paperGradesLeftClass,
                        style: theme.textTheme.labelSmall,
                      ),
                  ],
                ),
              ),
              if (onFiles != null)
                IconButton(
                  tooltip: l10n.paperAttachments,
                  onPressed: enabled || published ? onFiles : null,
                  icon: Badge.count(
                    count:
                        (grade?.attachments.length ?? 0) +
                        (grade?.links.length ?? 0),
                    isLabelVisible:
                        (grade?.attachments.length ?? 0) +
                            (grade?.links.length ?? 0) >
                        0,
                    child: const Icon(Icons.attach_file_rounded),
                  ),
                ),
              Chip(label: Text(status), visualDensity: VisualDensity.compact),
            ],
          ),
          const SizedBox(height: 6),
          if (published)
            Row(
              children: [
                Expanded(
                  child: Text(
                    _markText(l10n, grade!.mark, grade.score, maximumScore),
                    style: theme.textTheme.bodyLarge,
                  ),
                ),
                if (grade.corrections > 0)
                  Padding(
                    padding: const EdgeInsetsDirectional.only(end: 8),
                    child: Text(
                      l10n.paperGradesCorrected(grade.corrections),
                      style: theme.textTheme.labelSmall,
                    ),
                  ),
                OutlinedButton(
                  onPressed: onCorrect,
                  child: Text(l10n.paperGradesCorrect),
                ),
              ],
            )
          else ...[
            // A score is what a teacher enters, so the box is there
            // straight away. Missing the exam, or not grading it, are the
            // exceptions - in a menu, and said in words.
            if (edit.mark == GradeMark.absent ||
                edit.mark == GradeMark.notGraded)
              InputChip(
                avatar: Icon(
                  edit.mark == GradeMark.absent
                      ? Icons.event_busy_rounded
                      : Icons.remove_circle_outline_rounded,
                  size: 18,
                ),
                label: Text(
                  edit.mark == GradeMark.absent
                      ? l10n.paperGradesAbsent
                      : l10n.paperGradesNotGraded,
                ),
                deleteButtonTooltipMessage: l10n.paperGradesEnterScore,
                onDeleted: enabled
                    ? () {
                        edit.mark = null;
                        onChanged();
                      }
                    : null,
              )
            else
              Row(
                children: [
                  SizedBox(
                    width: 110,
                    child: TextField(
                      controller: edit.score,
                      enabled: enabled,
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      decoration: InputDecoration(
                        isDense: true,
                        labelText: l10n.paperGradesScore,
                      ),
                      onChanged: (text) {
                        edit.mark = text.trim().isEmpty
                            ? null
                            : GradeMark.scored;
                        onChanged();
                      },
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      l10n.paperGradesOutOf(
                        _PaperGradebookPageState._number(maximumScore),
                      ),
                    ),
                  ),
                  PopupMenuButton<GradeMark>(
                    tooltip: l10n.paperGradesOtherMark,
                    enabled: enabled,
                    icon: const Icon(Icons.more_horiz_rounded),
                    onSelected: (mark) {
                      edit.mark = mark;
                      edit.score.clear();
                      onChanged();
                    },
                    itemBuilder: (_) => [
                      PopupMenuItem(
                        value: GradeMark.absent,
                        child: Text(l10n.paperGradesAbsent),
                      ),
                      PopupMenuItem(
                        value: GradeMark.notGraded,
                        child: Text(l10n.paperGradesNotGraded),
                      ),
                    ],
                  ),
                ],
              ),
            if (edit.showComment || edit.feedback.text.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: TextField(
                  controller: edit.feedback,
                  enabled: enabled,
                  maxLength: 2000,
                  minLines: 1,
                  maxLines: 4,
                  decoration: InputDecoration(
                    isDense: true,
                    labelText: l10n.paperGradesComment,
                    border: const OutlineInputBorder(),
                  ),
                  onChanged: (_) => onChanged(),
                ),
              )
            else
              Align(
                alignment: AlignmentDirectional.centerStart,
                child: TextButton.icon(
                  onPressed: enabled
                      ? () {
                          edit.showComment = true;
                          onChanged();
                        }
                      : null,
                  icon: const Icon(Icons.comment_outlined, size: 18),
                  label: Text(l10n.paperGradesAddComment),
                ),
              ),
          ],
          if (refusal case final reason?)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(
                gradeRowMessage(
                  l10n,
                  reason,
                  _PaperGradebookPageState._number(maximumScore),
                ),
                style: TextStyle(color: theme.colorScheme.error),
              ),
            ),
        ],
      ),
    );
  }
}

/// A mark in words: "17.5 out of 20", "Absent", "Not graded".
String _markText(
  AppL10n l10n,
  GradeMark? mark,
  double? score,
  double maximumScore,
) => switch (mark) {
  GradeMark.absent => l10n.paperGradesAbsent,
  GradeMark.notGraded => l10n.paperGradesNotGraded,
  _ when score != null =>
    '${_PaperGradebookPageState._number(score)} '
        '${l10n.paperGradesOutOf(_PaperGradebookPageState._number(maximumScore))}',
  _ => l10n.paperGradesUnmarked,
};

/// The files and links every student sees with their published mark.
class _SharedFilesTile extends StatelessWidget {
  const _SharedFilesTile({required this.count, required this.onTap});

  final int count;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final l10n = AppL10n.of(context);
    return ListTile(
      leading: Badge.count(
        count: count,
        isLabelVisible: count > 0,
        child: const Icon(Icons.folder_shared_outlined),
      ),
      title: Text(l10n.paperShared),
      subtitle: Text(l10n.paperSharedHint),
      trailing: Icon(forwardChevron(context)),
      onTap: onTap,
    );
  }
}
