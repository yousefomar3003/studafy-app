import 'package:flutter/material.dart';

import '../../../core/attachment_field.dart';
import '../../../core/coursework_attachments.dart';
import '../../../core/file_upload_repository.dart';
import '../../../core/platform_attachment_source.dart';
import '../../../core/studafy_formatting.dart';
import '../../../core/unsaved_changes.dart';
import '../../../core/uploads_scope.dart';
import '../../../l10n/generated/app_l10n.dart';
import '../domain/academic_repository.dart';
import 'coursework_messages.dart';

/// Adding a lesson to a class: its title, the teacher's notes, and the files
/// that go with it - slides, a worksheet, a photo of the board.
///
/// The notes, files and titled links are one lesson (ADR-0036): the files and
/// links are bound to it on the server, so they travel and are edited with
/// it. Students see it under Lessons, by date, and with Studafy Max can make
/// quizzes and flashcards from it.
class CreateLessonPage extends StatefulWidget {
  const CreateLessonPage({
    super.key,
    required this.repository,
    required this.classes,
    this.initialClassroomId,
    this.schoolId,
    this.uploads,
    this.attachmentSource,
    this.section,
  });

  final AcademicContentRepository repository;
  final List<ClassOption> classes;

  /// Preselected when opened from inside a class.
  final String? initialClassroomId;

  /// The section of [initialClassroomId] this lesson is for, when opened
  /// from a section still waiting for its lesson. The lesson is filed for
  /// it, so the section has its content once the lesson is published.
  final LessonSession? section;

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

  /// Dropped if the teacher picks another class: a section belongs to one.
  LessonSession? _section;
  FileAudience _audience = FileAudience.both;
  bool _saving = false;
  String? _error;
  AttachmentsEditorValue _attachments = const AttachmentsEditorValue();

  /// Files are uploaded for one class, and the server refuses to bind them
  /// to another, so changing the class starts the files over.
  GlobalKey<AttachmentsEditorState> _editor = GlobalKey();

  bool get _uploading => _attachments.uploading;

  /// Typed or added, and not yet saved: leaving asks first.
  bool get _unsaved =>
      !_saving &&
      (_title.text.trim().isNotEmpty ||
          _notes.text.trim().isNotEmpty ||
          !_attachments.changes.isEmpty ||
          _attachments.uploading ||
          _attachments.failed);

  @override
  void initState() {
    super.initState();
    _classroomId =
        widget.initialClassroomId ??
        (widget.classes.length == 1 ? widget.classes.single.id : null);
    _section = widget.initialClassroomId == null ? null : widget.section;
  }

  @override
  void dispose() {
    _title.dispose();
    _notes.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_saving || _uploading) return;
    final l10n = AppL10n.of(context);
    final classroomId = _classroomId;
    final changes = _attachments.changes;
    final String? problem = switch (null) {
      _ when classroomId == null => l10n.lessonClassRequired,
      _ when _title.text.trim().isEmpty => l10n.lessonTitleRequired,
      _ when _attachments.failed => l10n.attachmentsFailed,
      _
          when _notes.text.trim().isEmpty &&
              changes.attachFileIds.isEmpty &&
              changes.addLinks.isEmpty =>
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
          body: _notes.text.trim(),
          audience: _audience.wireValue,
          // "Add lesson" means the class sees it now.
          publish: true,
          attachmentFileIds: changes.attachFileIds,
          links: changes.addLinks,
          lessonSessionId: _section?.id,
        ),
      );
      if (!mounted) return;
      Navigator.of(context).pop(created);
    } on Object catch (error) {
      if (!mounted) return;
      // A refused file or link is named and marked, instead of "try again":
      // the same request would be refused the same way. Once the marked
      // ones are removed, the lesson saves.
      final refusal = attachmentRefusalIn(error);
      if (refusal != null) _editor.currentState?.markNotAccepted(refusal.rows);
      setState(() {
        _saving = false;
        _error = refusal != null ? l10n.courseworkAttachmentRefused : failed;
      });
    }
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    // Follows typing without rebuilding the page.
    listenable: Listenable.merge([_title, _notes]),
    builder: (_, page) => UnsavedChangesScope(unsaved: _unsaved, child: page!),
    child: _page(context),
  );

  Widget _page(BuildContext context) {
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
                      _section = null;
                      _attachments = const AttachmentsEditorValue();
                      _editor = GlobalKey();
                    }),
            ),
            if (_section case final section?)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: InputChip(
                  avatar: const Icon(Icons.event_note_rounded, size: 18),
                  label: Text(
                    l10n.lessonForSection(
                      studafyDateTime(context, section.startsAt),
                    ),
                  ),
                  onDeleted: _saving
                      ? null
                      : () => setState(() => _section = null),
                ),
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
            if (uploads == null) Text(l10n.academicAttachmentsUnavailable),
            AttachmentsEditor(
              key: _editor,
              purpose: FilePurpose.lessonResource,
              schoolId: _classroomId == null ? null : widget.schoolId,
              filesBlockedReason: _classroomId == null
                  ? l10n.lessonPickClassForFiles
                  : null,
              classroomId: _classroomId,
              uploads: uploads,
              source: widget.attachmentSource ?? pickPlatformAttachment,
              maxFiles: 10,
              enabled: !_saving,
              onChanged: (value) => setState(() => _attachments = value),
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
              onPressed: _saving || _uploading ? null : _save,
              icon: const Icon(Icons.upload_file_rounded),
              label: Text(_saving ? l10n.lessonSaving : l10n.lessonSave),
            ),
          ],
        ),
      ),
    );
  }
}
