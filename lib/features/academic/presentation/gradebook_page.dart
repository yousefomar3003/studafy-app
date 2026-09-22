import 'package:flutter/material.dart';

import '../../../l10n/generated/app_l10n.dart';
import '../domain/academic_repository.dart';

/// Entering marks for one piece of graded work, for one class.
///
/// Named apart from the legacy GradebookPage in teacher_features.dart, which
/// is the preview dashboard's own screen over the local database.
///
/// Marks are not created here. Publishing an assessment creates one
/// grade_results row per enrolled student, so this screen edits rows that
/// already exist — which is why work still in draft offers a publish button
/// instead of a register.
class ClassGradebookPage extends StatefulWidget {
  const ClassGradebookPage({
    super.key,
    required this.repository,
    required this.classroomId,
    required this.classroomName,
  });

  final AcademicRepository repository;
  final String classroomId;
  final String classroomName;

  @override
  State<ClassGradebookPage> createState() => _ClassGradebookPageState();
}

class _ClassGradebookPageState extends State<ClassGradebookPage> {
  List<AcademicRecord> _assessments = const [];
  List<ClassStudent> _students = const [];
  List<GradeEntry> _entries = const [];
  AcademicRecord? _selected;
  final Map<String, String> _edited = {};
  bool _loading = true;
  bool _saving = false;
  String? _error;
  String? _notice;
  late String _loadFailed;
  late String _saveFailed;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final l10n = AppL10n.of(context);
    _loadFailed = l10n.gradebookLoadFailed;
    _saveFailed = l10n.gradebookSaveFailed;
  }

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
      final students = await widget.repository.classStudents(
        widget.classroomId,
      );
      final entries = await widget.repository.gradeEntries(widget.classroomId);
      if (!mounted) return;
      setState(() {
        _assessments = assessments;
        _students = students;
        _entries = entries;
        _selected = assessments.any((item) => item.id == _selected?.id)
            ? _selected
            : (assessments.isEmpty ? null : assessments.first);
        _edited.clear();
        _loading = false;
      });
    } on Object {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = _loadFailed;
      });
    }
  }

  List<GradeEntry> get _entriesForSelected => [
    for (final entry in _entries)
      if (entry.assessmentId == _selected?.id) entry,
  ];

  GradeEntry? _entryFor(String studentId) =>
      _entriesForSelected.where((e) => e.studentId == studentId).firstOrNull;

  Future<void> _publishSelected() async {
    final selected = _selected;
    if (selected == null || _saving) return;
    setState(() => _saving = true);
    try {
      await widget.repository.publishAssessment(selected.id, selected.version);
      if (!mounted) return;
      setState(() => _saving = false);
      await _load();
    } on Object {
      if (!mounted) return;
      setState(() {
        _saving = false;
        _error = _saveFailed;
      });
    }
  }

  Future<void> _save() async {
    if (_saving) return;
    final l10n = AppL10n.of(context);
    if (_edited.isEmpty) {
      setState(() => _notice = l10n.gradebookNothingChanged);
      return;
    }
    // Every mark is checked before any is sent: a teacher should not find
    // half a register saved because the fourth entry was out of range.
    for (final studentId in _edited.keys) {
      final entry = _entryFor(studentId);
      final value = double.tryParse(_edited[studentId]!.trim());
      if (entry == null || value == null) continue;
      if (value > entry.maximumScore || value < 0) {
        setState(() => _error = l10n.gradebookScoreTooHigh);
        return;
      }
    }
    setState(() {
      _saving = true;
      _error = null;
      _notice = null;
    });
    final saved = l10n.gradebookSaved;
    try {
      for (final studentId in _edited.keys) {
        final entry = _entryFor(studentId);
        final value = double.tryParse(_edited[studentId]!.trim());
        if (entry == null || value == null) continue;
        await widget.repository.reviewGrade(entry.id, entry.version, value);
      }
      if (!mounted) return;
      setState(() {
        _saving = false;
        _notice = saved;
      });
      // Reviewing moves each row's version on, so the register is re-read
      // rather than left holding versions the server has since replaced.
      await _load();
    } on Object {
      if (!mounted) return;
      setState(() {
        _saving = false;
        _error = _saveFailed;
      });
    }
  }

  Future<void> _release() async {
    if (_saving) return;
    final l10n = AppL10n.of(context);
    final released = l10n.gradebookReleased;
    setState(() => _saving = true);
    try {
      for (final entry in _entriesForSelected) {
        if (entry.state == 'reviewed') {
          await widget.repository.publishGrade(entry.id, entry.version);
        }
      }
      if (!mounted) return;
      setState(() {
        _saving = false;
        _notice = released;
      });
      await _load();
    } on Object {
      if (!mounted) return;
      setState(() {
        _saving = false;
        _error = _saveFailed;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppL10n.of(context);
    final selected = _selected;
    final isDraft = selected != null && selected.state == 'draft';
    return Scaffold(
      appBar: AppBar(title: Text(l10n.gradebookTitle(widget.classroomName))),
      body: SafeArea(
        child: _loading
            ? const Center(child: CircularProgressIndicator())
            : _assessments.isEmpty
            ? Center(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Text(
                    l10n.gradebookNoAssessments,
                    textAlign: TextAlign.center,
                  ),
                ),
              )
            : Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.all(12),
                    child: DropdownButtonFormField<String>(
                      initialValue: selected?.id,
                      decoration: InputDecoration(
                        labelText: l10n.gradebookPickAssessment,
                        border: const OutlineInputBorder(),
                      ),
                      items: [
                        for (final item in _assessments)
                          DropdownMenuItem(
                            value: item.id,
                            child: Text(item.title),
                          ),
                      ],
                      onChanged: _saving
                          ? null
                          : (value) => setState(() {
                              _selected = _assessments
                                  .where((item) => item.id == value)
                                  .firstOrNull;
                              _edited.clear();
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
                  if (_notice != null)
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: Text(_notice!),
                    ),
                  const Divider(height: 1),
                  Expanded(
                    child: isDraft
                        ? _DraftNotice(
                            onPublish: _saving ? null : _publishSelected,
                          )
                        : _students.isEmpty
                        ? Center(child: Text(l10n.gradebookNoStudents))
                        : ListView.separated(
                            itemCount: _students.length,
                            separatorBuilder: (_, _) =>
                                const Divider(height: 1),
                            itemBuilder: (context, i) {
                              final student = _students[i];
                              final entry = _entryFor(student.id);
                              return _MarkRow(
                                name: student.displayName,
                                entry: entry,
                                value:
                                    _edited[student.id] ??
                                    entry?.score?.toString() ??
                                    '',
                                onChanged: (value) =>
                                    _edited[student.id] = value,
                              );
                            },
                          ),
                  ),
                ],
              ),
      ),
      bottomNavigationBar: isDraft || _assessments.isEmpty
          ? null
          : SafeArea(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Row(
                  children: [
                    Expanded(
                      child: FilledButton(
                        onPressed: _saving ? null : _save,
                        child: Text(
                          _saving ? l10n.gradebookSaving : l10n.gradebookSave,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: OutlinedButton(
                        onPressed: _saving ? null : _release,
                        child: Text(l10n.gradebookRelease),
                      ),
                    ),
                  ],
                ),
              ),
            ),
    );
  }
}

class _DraftNotice extends StatelessWidget {
  const _DraftNotice({required this.onPublish});

  final VoidCallback? onPublish;

  @override
  Widget build(BuildContext context) {
    final l10n = AppL10n.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(l10n.gradebookDraftNotice, textAlign: TextAlign.center),
            const SizedBox(height: 12),
            FilledButton(
              onPressed: onPublish,
              child: Text(l10n.gradebookPublishAssessment),
            ),
          ],
        ),
      ),
    );
  }
}

class _MarkRow extends StatelessWidget {
  const _MarkRow({
    required this.name,
    required this.entry,
    required this.value,
    required this.onChanged,
  });

  final String name;
  final GradeEntry? entry;
  final String value;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    final l10n = AppL10n.of(context);
    final maximum = entry?.maximumScore;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: Row(
        children: [
          Expanded(child: Text(name)),
          if (maximum != null) ...[
            SizedBox(
              width: 88,
              child: TextFormField(
                initialValue: value,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                decoration: const InputDecoration(isDense: true),
                onChanged: onChanged,
              ),
            ),
            const SizedBox(width: 8),
            Text(l10n.gradebookScoreOf(_formatted(maximum))),
          ],
        ],
      ),
    );
  }

  static String _formatted(double value) =>
      value == value.roundToDouble() ? value.toInt().toString() : '$value';
}
