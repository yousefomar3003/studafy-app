import 'package:flutter/material.dart';

import '../../../core/attachment_field.dart';
import '../../../core/coursework_attachments.dart';
import '../../../core/file_upload_repository.dart';
import '../../../core/platform_attachment_source.dart';
import '../../../core/studafy_domain.dart';
import '../../../core/uploads_scope.dart';
import '../../../l10n/generated/app_l10n.dart';
import '../domain/academic_repository.dart';

/// Edits the files and links on a paper grade (ADR-0036): the class's
/// shared ones when [studentId] is null, otherwise one student's own. They
/// stay private until that student's mark is published. Answers true once
/// saved.
Future<bool?> showGradeAttachmentsSheet(
  BuildContext context, {
  required OnlineAssessmentRepository repository,
  required String assessmentId,
  required String title,
  required String hint,
  String? studentId,
  String? classroomId,
  List<StoredAttachment> attachments = const [],
  List<ContentLink> links = const [],
  AttachmentSource? source,
}) => showModalBottomSheet<bool>(
  context: context,
  isScrollControlled: true,
  showDragHandle: true,
  builder: (_) => _GradeAttachmentsSheet(
    repository: repository,
    assessmentId: assessmentId,
    title: title,
    hint: hint,
    studentId: studentId,
    classroomId: classroomId,
    attachments: attachments,
    links: links,
    uploads: UploadsScope.maybeOf(context),
    source: source ?? pickPlatformAttachment,
  ),
);

class _GradeAttachmentsSheet extends StatefulWidget {
  const _GradeAttachmentsSheet({
    required this.repository,
    required this.assessmentId,
    required this.title,
    required this.hint,
    required this.studentId,
    required this.classroomId,
    required this.attachments,
    required this.links,
    required this.uploads,
    required this.source,
  });

  final OnlineAssessmentRepository repository;
  final String assessmentId;
  final String title;
  final String hint;
  final String? studentId;
  final String? classroomId;
  final List<StoredAttachment> attachments;
  final List<ContentLink> links;
  final FileUploadRepository? uploads;
  final AttachmentSource source;

  @override
  State<_GradeAttachmentsSheet> createState() => _GradeAttachmentsSheetState();
}

class _GradeAttachmentsSheetState extends State<_GradeAttachmentsSheet> {
  AttachmentsEditorValue _value = const AttachmentsEditorValue();
  bool _saving = false;
  String? _error;

  Future<void> _save() async {
    final l10n = AppL10n.of(context);
    if (!_value.ready) {
      setState(() => _error = l10n.attachmentsUploading);
      return;
    }
    if (_value.changes.isEmpty) {
      Navigator.of(context).pop(false);
      return;
    }
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      await widget.repository.updateGradeAttachments(
        widget.assessmentId,
        _value.changes,
        studentId: widget.studentId,
      );
      if (mounted) Navigator.of(context).pop(true);
    } on Object {
      if (!mounted) return;
      setState(() {
        _saving = false;
        _error = l10n.paperAttachmentsFailed;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppL10n.of(context);
    final theme = Theme.of(context);
    return Padding(
      padding: EdgeInsetsDirectional.only(
        start: 16,
        end: 16,
        bottom: 16 + MediaQuery.viewInsetsOf(context).bottom,
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(widget.title, style: theme.textTheme.titleMedium),
            const SizedBox(height: 4),
            Text(widget.hint, style: theme.textTheme.bodySmall),
            const SizedBox(height: 12),
            AttachmentsEditor(
              purpose: FilePurpose.paperScan,
              schoolId: ActiveContextController.instance.membership?.schoolId,
              uploads: widget.uploads,
              source: widget.source,
              classroomId: widget.classroomId,
              existingAttachments: widget.attachments,
              existingLinks: widget.links,
              maxFiles: 10,
              enabled: !_saving,
              onChanged: (value) => setState(() {
                _value = value;
                _error = null;
              }),
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
              onPressed: _saving || _value.uploading ? null : _save,
              child: _saving
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : Text(l10n.paperSave),
            ),
          ],
        ),
      ),
    );
  }
}
