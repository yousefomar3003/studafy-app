import 'package:flutter/material.dart';

import '../../../core/attachment_field.dart';
import '../../../core/file_upload_repository.dart';
import '../../../core/platform_attachment_source.dart';
import '../../../core/uploads_scope.dart';
import '../../../l10n/generated/app_l10n.dart';
import '../domain/academic_repository.dart';

/// Recording an exam so it can be graded.
///
/// An exam is sat outside Studafy. Nothing here asks for questions or offers
/// to deliver the paper in the app: the record exists so a teacher can enter
/// marks against it in the gradebook, and each student sees their own. The
/// surface can carry questions, and an earlier draft of this screen wrote
/// them, but no exam is taken on the platform — offering it only invited a
/// teacher to author a paper nobody would ever see.
///
/// The paper itself - or a revision sheet - can be attached, as with an
/// assignment, so students can open it from the exam.
///
/// Recorded as an assessment because grade_results attach to nothing else.
class CreateExamPage extends StatefulWidget {
  const CreateExamPage({
    super.key,
    required this.repository,
    required this.classes,
    this.initialClassroomId,
    this.schoolId,
    this.uploads,
    this.attachmentSource,
  });

  final AssessmentRepository repository;
  final List<ClassOption> classes;
  final String? initialClassroomId;

  /// The school the files are filed under; without one no attach control.
  final String? schoolId;

  /// Falls back to the app's [UploadsScope].
  final FileUploadRepository? uploads;

  /// Overrides the platform picker. Tests supply their own.
  final AttachmentSource? attachmentSource;

  @override
  State<CreateExamPage> createState() => _CreateExamPageState();
}

class _CreateExamPageState extends State<CreateExamPage> {
  final _title = TextEditingController();
  final _total = TextEditingController(text: '100');
  String? _classroomId;
  String _category = 'exam';
  DateTime? _scheduledAt;
  bool _saving = false;
  String? _error;
  List<Attachment> _attachments = const [];

  /// Files are uploaded for one class; changing it starts them over.
  Key _attachmentsKey = UniqueKey();

  bool get _uploading =>
      _attachments.any((a) => a.stage == AttachmentStage.uploading);

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
    _total.dispose();
    super.dispose();
  }

  Future<void> _pickSchedule() async {
    final now = DateTime.now();
    final date = await showDatePicker(
      context: context,
      initialDate: _scheduledAt ?? now.add(const Duration(days: 7)),
      firstDate: now.subtract(const Duration(days: 365)),
      lastDate: now.add(const Duration(days: 365)),
    );
    if (date == null || !mounted) return;
    final time = await showTimePicker(
      context: context,
      initialTime: const TimeOfDay(hour: 9, minute: 0),
    );
    if (!mounted) return;
    setState(() {
      _scheduledAt = DateTime(
        date.year,
        date.month,
        date.day,
        time?.hour ?? 9,
        time?.minute ?? 0,
      );
    });
  }

  Future<void> _create() async {
    if (_saving || _uploading) return;
    final l10n = AppL10n.of(context);
    final classroomId = _classroomId;
    final total = double.tryParse(_total.text.trim());

    final String? problem = switch (null) {
      _ when classroomId == null => l10n.examClassRequired,
      _ when _title.text.trim().isEmpty => l10n.examTitleRequired,
      _ when total == null || total <= 0 => l10n.examTotalRequired,
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
    final created = l10n.examCreated;
    final failed = l10n.examCreateFailed;
    try {
      await widget.repository.createAssessment(
        AssessmentDraft(
          classroomId: classroomId!,
          title: _title.text.trim(),
          maximumScore: total!,
          category: _category,
          // Sat on paper and marked by the teacher: the surface's other
          // delivery modes describe answering in the app, which Studafy
          // does not do.
          delivery: 'paper',
          scheduledAt: _scheduledAt,
          // No questions. With the paper offline there is nothing the app
          // could show a student, and an assessment carrying questions must
          // have their marks sum to its total — a rule with no purpose here.
          questions: const [],
          attachmentFileIds: [for (final item in _attachments) ?item.fileId],
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
    final scheduledAt = _scheduledAt;
    return Scaffold(
      appBar: AppBar(title: Text(l10n.examNewTitle)),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            DropdownButtonFormField<String>(
              initialValue: _classroomId,
              decoration: InputDecoration(
                labelText: l10n.examClassLabel,
                border: const OutlineInputBorder(),
              ),
              items: [
                for (final option in widget.classes)
                  DropdownMenuItem(value: option.id, child: Text(option.name)),
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
                labelText: l10n.examTitleLabel,
                border: const OutlineInputBorder(),
              ),
            ),
            Text(
              l10n.examCategoryLabel,
              style: Theme.of(context).textTheme.labelLarge,
            ),
            const SizedBox(height: 6),
            Wrap(
              spacing: 8,
              children: [
                for (final entry in {
                  'exam': l10n.examCategoryExam,
                  'quiz': l10n.examCategoryQuiz,
                  'midterm': l10n.examCategoryMidterm,
                  'final': l10n.examCategoryFinal,
                }.entries)
                  ChoiceChip(
                    label: Text(entry.value),
                    selected: _category == entry.key,
                    onSelected: _saving
                        ? null
                        : (_) => setState(() => _category = entry.key),
                  ),
              ],
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _total,
              enabled: !_saving,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              decoration: InputDecoration(
                labelText: l10n.examTotalLabel,
                helperText: l10n.examTotalHint,
                helperMaxLines: 3,
                border: const OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            OutlinedButton.icon(
              onPressed: _saving ? null : _pickSchedule,
              icon: const Icon(Icons.event_outlined),
              label: Text(
                scheduledAt == null
                    ? l10n.examPickSchedule
                    : '${l10n.examScheduleLabel}: '
                          '${scheduledAt.year}-'
                          '${scheduledAt.month.toString().padLeft(2, '0')}-'
                          '${scheduledAt.day.toString().padLeft(2, '0')} '
                          '${scheduledAt.hour.toString().padLeft(2, '0')}:'
                          '${scheduledAt.minute.toString().padLeft(2, '0')}',
              ),
            ),
            const SizedBox(height: 12),
            if (widget.uploads ?? UploadsScope.maybeOf(context)
                case final uploads?)
              if ((widget.schoolId, _classroomId) case (
                final schoolId?,
                final classroomId?,
              )) ...[
                Text(
                  l10n.examMaterialHelp,
                  style: Theme.of(context).textTheme.bodySmall,
                ),
                AttachmentField(
                  key: _attachmentsKey,
                  // The same purpose as an assignment's material: the server
                  // binds it to the exam when the exam is created.
                  purpose: FilePurpose.assignmentMaterial,
                  schoolId: schoolId,
                  classroomId: classroomId,
                  uploads: uploads,
                  enabled: !_saving,
                  source: widget.attachmentSource ?? pickPlatformAttachment,
                  onChanged: (items) => setState(() => _attachments = items),
                ),
              ],
            if (_error != null) ...[
              const SizedBox(height: 12),
              Text(
                _error!,
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
            ],
            const SizedBox(height: 20),
            FilledButton(
              // Held while a file uploads, so the exam is never created
              // without the paper the teacher is attaching.
              onPressed: _saving || _uploading ? null : _create,
              child: Text(_saving ? l10n.examCreating : l10n.examCreate),
            ),
          ],
        ),
      ),
    );
  }
}
