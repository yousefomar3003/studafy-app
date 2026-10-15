import 'package:flutter/material.dart';

import '../../../core/attachment_field.dart';
import '../../../core/coursework_attachments.dart';
import '../../../core/file_upload_repository.dart';
import '../../../core/platform_attachment_source.dart';
import '../../../l10n/generated/app_l10n.dart';
import '../domain/academic_repository.dart';
import 'coursework_messages.dart';

/// Editing a lesson a teacher put up: its title, its notes and their files
/// and links - or, for a lesson that is one file, the file itself.
///
/// The lesson stays exactly as visible as it was. A replaced file is kept for
/// the school; the class sees only the new one. Answers true once saved.
Future<bool?> showEditLessonSheet(
  BuildContext context, {
  required AcademicContentRepository repository,
  required AcademicRecord lesson,
  FileUploadRepository? uploads,
  String? schoolId,
  AttachmentSource? attachmentSource,
}) => showModalBottomSheet<bool>(
  context: context,
  isScrollControlled: true,
  builder: (_) => _EditLessonSheet(
    repository: repository,
    lesson: lesson,
    uploads: uploads,
    schoolId: schoolId,
    attachmentSource: attachmentSource,
  ),
);

class _EditLessonSheet extends StatefulWidget {
  const _EditLessonSheet({
    required this.repository,
    required this.lesson,
    this.uploads,
    this.schoolId,
    this.attachmentSource,
  });

  final AcademicContentRepository repository;
  final AcademicRecord lesson;
  final FileUploadRepository? uploads;
  final String? schoolId;
  final AttachmentSource? attachmentSource;

  @override
  State<_EditLessonSheet> createState() => _EditLessonSheetState();
}

class _EditLessonSheetState extends State<_EditLessonSheet> {
  late final _title = TextEditingController(text: widget.lesson.title);
  late final _body = TextEditingController(text: widget.lesson.detail);
  List<Attachment> _replacement = const [];
  AttachmentsEditorValue _attachments = const AttachmentsEditorValue();
  final _editor = GlobalKey<AttachmentsEditorState>();
  bool _saving = false;
  String? _error;

  /// A lesson that is one file has that file replaced whole. A notes lesson
  /// has its own files and links, added and removed here.
  bool get _hasFile => widget.lesson.resourceType == 'file';

  bool get _uploading =>
      _replacement.any((a) => a.stage == AttachmentStage.uploading) ||
      _attachments.uploading;

  @override
  void dispose() {
    _title.dispose();
    _body.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final l10n = AppL10n.of(context);
    if (_title.text.trim().isEmpty || _uploading) return;
    if (_attachments.failed) {
      setState(() => _error = l10n.attachmentsFailed);
      return;
    }
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      await widget.repository.editResource(
        widget.lesson.id,
        widget.lesson.version,
        title: _title.text.trim(),
        body: _hasFile ? null : _body.text,
        replaceFileId: _replacement.map((a) => a.fileId).nonNulls.firstOrNull,
        attachments: _attachments.changes,
      );
      if (mounted) Navigator.of(context).pop(true);
    } on CourseworkRefusal catch (refusal) {
      if (!mounted) return;
      if (refusal.problem == CourseworkProblem.attachmentRefused) {
        _editor.currentState?.markNotAccepted(refusal.rows);
      }
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

  @override
  Widget build(BuildContext context) {
    final l10n = AppL10n.of(context);
    final uploads = widget.uploads;
    final schoolId = widget.schoolId;
    final classroomId = widget.lesson.classroomId;
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                l10n.lessonEditTitle,
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _title,
                enabled: !_saving,
                maxLength: 200,
                decoration: InputDecoration(
                  labelText: l10n.lessonEditName,
                  border: const OutlineInputBorder(),
                ),
              ),
              if (!_hasFile)
                TextField(
                  controller: _body,
                  enabled: !_saving,
                  minLines: 3,
                  maxLines: 10,
                  maxLength: 30000,
                  decoration: InputDecoration(
                    labelText: l10n.lessonEditBody,
                    border: const OutlineInputBorder(),
                  ),
                ),
              if (!_hasFile)
                AttachmentsEditor(
                  key: _editor,
                  purpose: FilePurpose.lessonResource,
                  schoolId: classroomId == null ? null : schoolId,
                  classroomId: classroomId,
                  uploads: uploads,
                  source: widget.attachmentSource ?? pickPlatformAttachment,
                  existingAttachments: widget.lesson.attachments,
                  existingLinks: widget.lesson.links,
                  maxFiles: 10,
                  enabled: !_saving,
                  onChanged: (value) => setState(() => _attachments = value),
                ),
              if (_hasFile &&
                  uploads != null &&
                  schoolId != null &&
                  classroomId != null) ...[
                Text(
                  l10n.lessonEditReplaceFile,
                  style: Theme.of(context).textTheme.labelLarge,
                ),
                Text(
                  l10n.lessonEditReplaceHint,
                  style: Theme.of(context).textTheme.bodySmall,
                ),
                AttachmentField(
                  purpose: FilePurpose.lessonResource,
                  schoolId: schoolId,
                  classroomId: classroomId,
                  uploads: uploads,
                  maximumCount: 1,
                  enabled: !_saving,
                  source: widget.attachmentSource ?? pickPlatformAttachment,
                  onChanged: (items) => setState(() => _replacement = items),
                ),
              ],
              if (_error != null)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Text(
                    _error!,
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.error,
                    ),
                  ),
                ),
              const SizedBox(height: 12),
              FilledButton(
                onPressed: _saving || _uploading ? null : _save,
                child: Text(
                  _saving ? l10n.paperGradesSaving : l10n.lessonEditSave,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
