import 'package:flutter/material.dart';

import '../../../core/attachment_field.dart';
import '../../../core/file_upload_repository.dart';
import '../../../core/platform_attachment_source.dart';
import '../../../l10n/generated/app_l10n.dart';
import '../domain/academic_repository.dart';
import 'coursework_messages.dart';

/// What a teacher's material on set work can be: files taken off, and files
/// added. A file taken off is kept for the school; the class no longer sees
/// it. Answers true once saved.
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
  /// Current files the teacher chose to take off.
  final Set<String> _remove = {};
  List<Attachment> _added = const [];
  bool _saving = false;
  String? _error;

  bool get _uploading =>
      _added.any((a) => a.stage == AttachmentStage.uploading);

  List<String> get _addedIds => [for (final item in _added) ?item.fileId];

  /// Set work carries at most five files at a time.
  int get _room => 5 - (widget.work.attachments.length - _remove.length);

  Future<void> _save() async {
    final l10n = AppL10n.of(context);
    if (_uploading || (_remove.isEmpty && _addedIds.isEmpty)) return;
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      if (widget.isAssessment) {
        await widget.repository.updateAssessmentMaterials(
          widget.work.id,
          widget.work.version,
          detachFileIds: _remove.toList(),
          attachmentFileIds: _addedIds,
        );
      } else {
        await widget.repository.updateAssignmentMaterials(
          widget.work.id,
          widget.work.version,
          detachFileIds: _remove.toList(),
          attachmentFileIds: _addedIds,
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
    final uploads = widget.uploads;
    final schoolId = widget.schoolId;
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
              if (widget.work.attachments.isEmpty)
                Text(l10n.materialsEditNone)
              else
                for (final file in widget.work.attachments)
                  CheckboxListTile(
                    contentPadding: EdgeInsets.zero,
                    dense: true,
                    title: Text(file.displayName),
                    subtitle: _remove.contains(file.id)
                        ? Text(l10n.materialsEditRemoving)
                        : null,
                    value: !_remove.contains(file.id),
                    onChanged: _saving
                        ? null
                        : (keep) => setState(() {
                            if (keep ?? true) {
                              _remove.remove(file.id);
                            } else {
                              _remove.add(file.id);
                            }
                          }),
                  ),
              const SizedBox(height: 8),
              if (uploads != null &&
                  schoolId != null &&
                  classroomId != null &&
                  _room > 0)
                AttachmentField(
                  purpose: FilePurpose.assignmentMaterial,
                  schoolId: schoolId,
                  classroomId: classroomId,
                  uploads: uploads,
                  maximumCount: _room,
                  enabled: !_saving,
                  source: widget.attachmentSource ?? pickPlatformAttachment,
                  onChanged: (items) => setState(() => _added = items),
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
                onPressed:
                    _saving ||
                        _uploading ||
                        (_remove.isEmpty && _addedIds.isEmpty)
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
