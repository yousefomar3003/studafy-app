import 'package:flutter/material.dart';

import '../../../core/attachment_field.dart';
import '../../../core/coursework_attachments.dart';
import '../../../core/file_upload_repository.dart';
import '../../../core/platform_attachment_source.dart';
import '../../../l10n/generated/app_l10n.dart';
import '../domain/academic_repository.dart';
import 'coursework_messages.dart';

/// What a teacher's material on set work can be: files and titled links
/// taken off, and added. Anything taken off is kept for the school; the
/// class no longer sees it. Answers true once saved.
Future<bool?> showEditMaterialsSheet(
  BuildContext context, {
  required AcademicRepository repository,
  required AcademicRecord work,
  required bool isAssessment,
  FileUploadRepository? uploads,
  String? schoolId,
  AttachmentSource? attachmentSource,
}) => showModalBottomSheet<bool>(
  context: context,
  isScrollControlled: true,
  builder: (_) => _EditMaterialsSheet(
    repository: repository,
    work: work,
    isAssessment: isAssessment,
    uploads: uploads,
    schoolId: schoolId,
    attachmentSource: attachmentSource,
  ),
);

class _EditMaterialsSheet extends StatefulWidget {
  const _EditMaterialsSheet({
    required this.repository,
    required this.work,
    required this.isAssessment,
    this.uploads,
    this.schoolId,
    this.attachmentSource,
  });

  final AcademicRepository repository;
  final AcademicRecord work;
  final bool isAssessment;
  final FileUploadRepository? uploads;
  final String? schoolId;
  final AttachmentSource? attachmentSource;

  @override
  State<_EditMaterialsSheet> createState() => _EditMaterialsSheetState();
}

class _EditMaterialsSheetState extends State<_EditMaterialsSheet> {
  AttachmentsEditorValue _value = const AttachmentsEditorValue();
  bool _saving = false;
  String? _error;

  bool get _hasChanges => !_value.changes.isEmpty;

  Future<void> _save() async {
    final l10n = AppL10n.of(context);
    if (!_value.ready || !_hasChanges) return;
    final changes = _value.changes;
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      if (widget.isAssessment) {
        await widget.repository.updateAssessmentMaterials(
          widget.work.id,
          widget.work.version,
          detachFileIds: changes.detachFileIds,
          attachmentFileIds: changes.attachFileIds,
          addLinks: changes.addLinks,
          removeLinkIds: changes.removeLinkIds,
        );
      } else {
        await widget.repository.updateAssignmentMaterials(
          widget.work.id,
          widget.work.version,
          detachFileIds: changes.detachFileIds,
          attachmentFileIds: changes.attachFileIds,
          addLinks: changes.addLinks,
          removeLinkIds: changes.removeLinkIds,
        );
      }
      if (mounted) Navigator.of(context).pop(true);
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

  @override
  Widget build(BuildContext context) {
    final l10n = AppL10n.of(context);
    final theme = Theme.of(context);
    final classroomId = widget.work.classroomId;
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(l10n.materialsEditTitle, style: theme.textTheme.titleMedium),
              const SizedBox(height: 4),
              Text(l10n.materialsEditHint, style: theme.textTheme.bodySmall),
              const SizedBox(height: 8),
              if (widget.work.attachments.isEmpty && widget.work.links.isEmpty)
                Text(l10n.materialsEditNone),
              AttachmentsEditor(
                purpose: FilePurpose.assignmentMaterial,
                schoolId: classroomId == null ? null : widget.schoolId,
                classroomId: classroomId,
                uploads: widget.uploads,
                source: widget.attachmentSource ?? pickPlatformAttachment,
                existingAttachments: widget.work.attachments,
                existingLinks: widget.work.links,
                // Set work carries at most five files at a time.
                maxFiles: 5,
                enabled: !_saving,
                onChanged: (value) => setState(() => _value = value),
              ),
              if (_value.failed)
                Text(
                  l10n.attachmentsFailed,
                  style: TextStyle(color: theme.colorScheme.error),
                ),
              if (_error != null)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Text(
                    _error!,
                    style: TextStyle(color: theme.colorScheme.error),
                  ),
                ),
              const SizedBox(height: 12),
              FilledButton(
                onPressed: _saving || !_value.ready || !_hasChanges
                    ? null
                    : _save,
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
