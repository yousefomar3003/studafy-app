import 'package:flutter/material.dart';

import '../../../core/attachment_field.dart';
import '../../../core/content_links.dart';
import '../../../core/file_upload_repository.dart';
import '../../../core/platform_attachment_source.dart';
import '../../../core/uploads_scope.dart';
import '../../../l10n/generated/app_l10n.dart';
import '../domain/academic_repository.dart';

/// Adding a lesson to a class: its title, the teacher's notes, and the files
/// that go with it - slides, a worksheet, a photo of the board.
///
/// The notes are one piece of class material and each file is another, which
/// is how the server models it. They are filed together here so that, to the
/// teacher, a lesson is one thing. Students see it under Lessons, by date,
/// and with Studafy Max can make quizzes and flashcards from it.
class CreateLessonPage extends StatefulWidget {
  const CreateLessonPage({
    super.key,
    required this.repository,
    required this.classes,
    this.initialClassroomId,
    this.schoolId,
    this.uploads,
    this.attachmentSource,
  });

  final AcademicContentRepository repository;
  final List<ClassOption> classes;

  /// Preselected when opened from inside a class.
  final String? initialClassroomId;

  /// The school the files are filed under. Without one there is nowhere to
  /// upload to, and the attach control is not offered.
  final String? schoolId;

  /// Falls back to the app's [UploadsScope].
  final FileUploadRepository? uploads;

  /// Overrides the platform picker. Tests supply their own.
  final AttachmentSource? attachmentSource;

  @override
  State<CreateLessonPage> createState() => _CreateLessonPageState();
}

class _CreateLessonPageState extends State<CreateLessonPage> {
  final _title = TextEditingController();
  final _notes = TextEditingController();
  String? _classroomId;
  FileAudience _audience = FileAudience.both;
  bool _saving = false;
  String? _error;
  List<Attachment> _attachments = const [];
  List<Uri> _links = const [];

  /// Files are uploaded for one class, and the server refuses to publish them
  /// into another, so changing the class starts the files over.
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
    _notes.dispose();
    super.dispose();
  }

  Future<void> _save(FileUploadRepository? uploads) async {
    if (_saving || _uploading) return;
    final l10n = AppL10n.of(context);
    final classroomId = _classroomId;
    final fileIds = [for (final item in _attachments) ?item.fileId];
    final String? problem = switch (null) {
      _ when classroomId == null => l10n.lessonClassRequired,
      _ when _title.text.trim().isEmpty => l10n.lessonTitleRequired,
      _ when _notes.text.trim().isEmpty && fileIds.isEmpty && _links.isEmpty =>
        l10n.lessonContentRequired,
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
    final created = l10n.lessonCreated;
    final failed = l10n.lessonCreateFailed;
    try {
      await widget.repository.createResource(
        TextResourceDraft(
          classroomId: classroomId!,
          title: _title.text.trim(),
          body: textWithLinks(_notes.text, _links),
          audience: _audience.wireValue,
          // "Add lesson" means the class sees it now.
          publish: true,
        ),
      );
      // Each file becomes class material in its own right. One the scan
      // refused is simply not among them.
      if (uploads != null) {
        for (final fileId in fileIds) {
          await uploads.publishToClass(fileId: fileId, audience: _audience);
        }
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
    final uploads = widget.uploads ?? UploadsScope.maybeOf(context);
    return Scaffold(
      appBar: AppBar(title: Text(l10n.lessonNewTitle)),
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
                labelText: l10n.lessonTitleLabel,
                border: const OutlineInputBorder(),
              ),
            ),
            TextField(
              controller: _notes,
              enabled: !_saving,
              minLines: 4,
              maxLines: 10,
              maxLength: 30000,
              decoration: InputDecoration(
                labelText: l10n.lessonNotesLabel,
                helperText: l10n.lessonNotesHelp,
                border: const OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 8),
            if (uploads != null)
              if ((widget.schoolId, _classroomId) case (
                final schoolId?,
                final classroomId?,
              ))
                AttachmentField(
                  key: _attachmentsKey,
                  purpose: FilePurpose.lessonResource,
                  schoolId: schoolId,
                  classroomId: classroomId,
                  uploads: uploads,
                  enabled: !_saving,
                  source: widget.attachmentSource ?? pickPlatformAttachment,
                  onChanged: (items) => setState(() => _attachments = items),
                )
              else
                Text(l10n.lessonPickClassForFiles)
            else
              Text(l10n.academicAttachmentsUnavailable),
            LinksField(
              enabled: !_saving,
              onChanged: (links) => setState(() => _links = links),
            ),
            const SizedBox(height: 16),
            Text(
              l10n.lessonAudienceLabel,
              style: Theme.of(context).textTheme.titleSmall,
            ),
            const SizedBox(height: 8),
            SegmentedButton<FileAudience>(
              segments: [
                ButtonSegment(
                  value: FileAudience.both,
                  label: Text(l10n.lessonAudienceBoth),
                ),
                ButtonSegment(
                  value: FileAudience.students,
                  label: Text(l10n.lessonAudienceStudents),
                ),
                ButtonSegment(
                  value: FileAudience.guardians,
                  label: Text(l10n.lessonAudienceParents),
                ),
              ],
              selected: {_audience},
              onSelectionChanged: _saving
                  ? null
                  : (value) => setState(() => _audience = value.single),
            ),
            if (_error != null) ...[
              const SizedBox(height: 12),
              Text(
                _error!,
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
            ],
            const SizedBox(height: 20),
            FilledButton.icon(
              // Held while a file is uploading, so the lesson is never filed
              // without the file the teacher is still waiting on.
              onPressed: _saving || _uploading ? null : () => _save(uploads),
              icon: const Icon(Icons.upload_file_rounded),
              label: Text(_saving ? l10n.lessonSaving : l10n.lessonSave),
            ),
          ],
        ),
      ),
    );
  }
}
