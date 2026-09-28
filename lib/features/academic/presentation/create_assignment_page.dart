import 'package:flutter/material.dart';

import '../../../core/attachment_field.dart';
import '../../../core/file_upload_repository.dart';
import '../../../core/platform_attachment_source.dart';
import '../../../core/uploads_scope.dart';
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
    this.schoolId,
    this.uploads,
    this.attachmentSource,
  });

  final AcademicRepository repository;

  /// Classes this teacher can set work for. A single-entry list still shows
  /// the field, so the teacher can see which class they are setting work for.
  final List<ClassOption> classes;

  /// Preselected when opened from inside a class.
  final String? initialClassroomId;

  /// The school the material is filed under. Without one there is nowhere
  /// to upload to, and the attach control is not offered.
  final String? schoolId;

  /// Falls back to the app's [UploadsScope].
  final FileUploadRepository? uploads;

  /// Overrides the platform picker. Tests supply their own.
  final AttachmentSource? attachmentSource;

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
  List<Attachment> _attachments = const [];

  /// Rebuilt when the class changes. Material is uploaded for one class and
  /// the server refuses to bind it to another, so switching class starts the
  /// attachments over rather than letting a doomed create be attempted.
  Key _attachmentsKey = UniqueKey();

  bool get _uploading =>
      _attachments.any((a) => a.stage == AttachmentStage.uploading);

  List<String> get _fileIds => [for (final item in _attachments) ?item.fileId];

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
    if (_saving || _uploading) return;
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
      // Graded or not, it is an assignment the class opens and hands in.
      // Graded work also gets a mark, out of [score], that the gradebook
      // records against it.
      await widget.repository.createAssignment(
        AssignmentDraft(
          classroomId: classroomId!,
          title: _title.text.trim(),
          instructions: _instructions.text.trim(),
          dueAt: dueAt!,
          attachmentFileIds: _fileIds,
          maximumScore: _graded ? score : null,
        ),
      );
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
                  : (value) => setState(() {
                      if (value == _classroomId) return;
                      _classroomId = value;
                      _attachments = const [];
                      _attachmentsKey = UniqueKey();
                    }),
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
            if (widget.uploads ?? UploadsScope.maybeOf(context)
                case final uploads?)
              if ((widget.schoolId, _classroomId) case (
                final schoolId?,
                final classroomId?,
              ))
                AttachmentField(
                  key: _attachmentsKey,
                  purpose: FilePurpose.assignmentMaterial,
                  schoolId: schoolId,
                  classroomId: classroomId,
                  uploads: uploads,
                  enabled: !_saving,
                  source: widget.attachmentSource ?? pickPlatformAttachment,
                  onChanged: (items) => setState(() => _attachments = items),
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
              // Held while a file is uploading, so the work is never created
              // without the sheet the teacher is still attaching.
              onPressed: _saving || _uploading ? null : _create,
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
