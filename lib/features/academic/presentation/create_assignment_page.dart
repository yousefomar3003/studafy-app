import 'package:flutter/material.dart';

import '../../../l10n/generated/app_l10n.dart';
import '../domain/academic_repository.dart';

/// Setting work for a class, graded or not.
///
/// The two are one form because they are one act to a teacher, but they are
/// stored differently on purpose: ungraded work is an assignment, which is
/// handed in and nothing more, while graded work is an assessment, the only
/// record a grade can attach to. The switch picks which, so a teacher never
/// has to know that distinction exists.
class CreateAssignmentPage extends StatefulWidget {
  const CreateAssignmentPage({
    super.key,
    required this.repository,
    required this.classes,
    this.initialClassroomId,
  });

  final AcademicRepository repository;

  /// Classes this teacher can set work for. A single-entry list still shows
  /// the field, so the teacher can see which class they are setting work for.
  final List<ClassOption> classes;

  /// Preselected when opened from inside a class.
  final String? initialClassroomId;

  @override
  State<CreateAssignmentPage> createState() => _CreateAssignmentPageState();
}

class _CreateAssignmentPageState extends State<CreateAssignmentPage> {
  final _title = TextEditingController();
  final _instructions = TextEditingController();
  final _maxScore = TextEditingController(text: '10');
  String? _classroomId;
  DateTime? _dueAt;
  bool _graded = false;
  bool _saving = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _classroomId =
        widget.initialClassroomId ??
        (widget.classes.length == 1 ? widget.classes.single.id : null);
  }

  @override
  void dispose() {
    _title.dispose();
    _instructions.dispose();
    _maxScore.dispose();
    super.dispose();
  }

  Future<void> _pickDue() async {
    final now = DateTime.now();
    final date = await showDatePicker(
      context: context,
      initialDate: _dueAt ?? now.add(const Duration(days: 7)),
      firstDate: now.subtract(const Duration(days: 1)),
      lastDate: now.add(const Duration(days: 365)),
    );
    if (date == null || !mounted) return;
    final time = await showTimePicker(
      context: context,
      initialTime: const TimeOfDay(hour: 23, minute: 59),
    );
    if (!mounted) return;
    setState(() {
      _dueAt = DateTime(
        date.year,
        date.month,
        date.day,
        time?.hour ?? 23,
        time?.minute ?? 59,
      );
    });
  }

  Future<void> _create() async {
    if (_saving) return;
    final l10n = AppL10n.of(context);
    final classroomId = _classroomId;
    final dueAt = _dueAt;
    final score = double.tryParse(_maxScore.text.trim());

    // Checked in the order the form reads, so the first thing the teacher
    // still has to do is the thing they are told about.
    final String? problem = switch (null) {
      _ when classroomId == null => l10n.assignmentClassRequired,
      _ when _title.text.trim().isEmpty => l10n.assignmentTitleRequired,
      _ when dueAt == null => l10n.assignmentDueRequired,
      _ when _graded && (score == null || score <= 0) =>
        l10n.assignmentMaxScoreRequired,
      _ => null,
    };
    if (problem != null) {
      setState(() => _error = problem);
      return;
    }

    setState(() {
      _saving = true;
      _error = null;
    });
    final created = l10n.assignmentCreated;
    final failed = l10n.assignmentCreateFailed;
    try {
      if (_graded) {
        await widget.repository.createAssessment(
          AssessmentDraft(
            classroomId: classroomId!,
            title: _title.text.trim(),
            maximumScore: score!,
            questions: const [],
            // Filed as an assignment so the gradebook groups it with the
            // rest of the coursework rather than among exams.
            category: 'assignment',
            // The teacher marks it themselves; nothing is answered in-app.
            delivery: 'paper',
            scheduledAt: dueAt,
          ),
        );
      } else {
        await widget.repository.createAssignment(
          AssignmentDraft(
            classroomId: classroomId!,
            title: _title.text.trim(),
            instructions: _instructions.text.trim(),
            dueAt: dueAt!,
          ),
        );
      }
      if (!mounted) return;
      Navigator.of(context).pop(created);
    } on Object {
      if (!mounted) return;
      setState(() {
        _saving = false;
        _error = failed;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppL10n.of(context);
    final dueAt = _dueAt;
    return Scaffold(
      appBar: AppBar(title: Text(l10n.assignmentNewTitle)),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            DropdownButtonFormField<String>(
              initialValue: _classroomId,
              decoration: InputDecoration(
                labelText: l10n.assignmentClassLabel,
                border: const OutlineInputBorder(),
              ),
              items: [
                for (final classroom in widget.classes)
                  DropdownMenuItem(
                    value: classroom.id,
                    child: Text(classroom.name),
                  ),
              ],
              onChanged: _saving
                  ? null
                  : (value) => setState(() => _classroomId = value),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _title,
              enabled: !_saving,
              maxLength: 200,
              decoration: InputDecoration(
                labelText: l10n.assignmentTitleLabel,
                border: const OutlineInputBorder(),
              ),
            ),
            TextField(
              controller: _instructions,
              enabled: !_saving,
              minLines: 3,
              maxLines: 6,
              decoration: InputDecoration(
                labelText: l10n.assignmentInstructionsLabel,
                border: const OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            OutlinedButton.icon(
              onPressed: _saving ? null : _pickDue,
              icon: const Icon(Icons.event_outlined),
              label: Text(
                dueAt == null
                    ? l10n.assignmentPickDue
                    : '${l10n.assignmentDueLabel}: '
                          '${dueAt.year}-${dueAt.month.toString().padLeft(2, '0')}-'
                          '${dueAt.day.toString().padLeft(2, '0')} '
                          '${dueAt.hour.toString().padLeft(2, '0')}:'
                          '${dueAt.minute.toString().padLeft(2, '0')}',
              ),
            ),
            const SizedBox(height: 8),
            SwitchListTile(
              value: _graded,
              onChanged: _saving
                  ? null
                  : (value) => setState(() => _graded = value),
              title: Text(l10n.assignmentGradedLabel),
              subtitle: Text(
                _graded ? l10n.assignmentGradedOn : l10n.assignmentGradedOff,
              ),
            ),
            if (_graded)
              TextField(
                controller: _maxScore,
                enabled: !_saving,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                decoration: InputDecoration(
                  labelText: l10n.assignmentMaxScoreLabel,
                  border: const OutlineInputBorder(),
                ),
              ),
            if (_error != null) ...[
              const SizedBox(height: 12),
              Text(
                _error!,
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
            ],
            const SizedBox(height: 20),
            FilledButton(
              onPressed: _saving ? null : _create,
              child: Text(
                _saving ? l10n.assignmentCreating : l10n.assignmentCreate,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
