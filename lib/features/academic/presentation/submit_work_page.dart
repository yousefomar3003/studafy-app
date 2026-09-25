import 'package:flutter/material.dart';

import '../../../l10n/generated/app_l10n.dart';
import '../../../core/file_upload_repository.dart';
import '../../../core/attachment_field.dart';
import '../../../core/platform_attachment_source.dart';
import '../domain/academic_repository.dart';

/// A student handing work in against an assignment.
///
/// Text, plus documents and photos. Each attachment is uploaded while the
/// student is still typing, so pressing Send is not a wait, and the server
/// binds the finished uploads to the attempt this creates.
class SubmitWorkPage extends StatefulWidget {
  const SubmitWorkPage({
    super.key,
    required this.repository,
    required this.assignmentId,
    required this.assignmentTitle,
    this.canSubmit = true,
    this.uploads,
    this.schoolId,
    this.studentId,
    this.attachmentSource,
  });

  final AcademicRepository repository;
  final String assignmentId;
  final String assignmentTitle;

  /// Attachments are offered only when there is somewhere to send them and a
  /// school and student to file them under.
  final FileUploadRepository? uploads;
  final String? schoolId;

  /// The student this hand-in is for. A student's own record, or - when a
  /// guardian is acting for a child with no device - the child's.
  final String? studentId;

  /// Overrides the platform picker. Tests supply their own.
  final AttachmentSource? attachmentSource;

  /// False for work that is not open, so a student is told before typing
  /// rather than after.
  final bool canSubmit;

  @override
  State<SubmitWorkPage> createState() => _SubmitWorkPageState();
}

class _SubmitWorkPageState extends State<SubmitWorkPage> {
  final _answer = TextEditingController();
  bool _sending = false;
  String? _error;
  List<Attachment> _attachments = const [];

  bool get _uploading =>
      _attachments.any((a) => a.stage == AttachmentStage.uploading);

  /// Only files the server actually has. A failed upload is simply absent
  /// rather than blocking the hand-in.
  List<String> get _readyFileIds => [
    for (final item in _attachments) ?item.fileId,
  ];

  @override
  void dispose() {
    _answer.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_sending) return;
    final l10n = AppL10n.of(context);
    if (_answer.text.trim().isEmpty) {
      setState(() => _error = l10n.submitEmpty);
      return;
    }
    if (_uploading) return;
    setState(() {
      _sending = true;
      _error = null;
    });
    final done = l10n.submitDone;
    final failed = l10n.submitFailed;
    try {
      await widget.repository.submitAssignment(
        widget.assignmentId,
        _answer.text.trim(),
        attachmentFileIds: _readyFileIds,
        // The same field for both callers. A student naming their own record
        // takes the ordinary path; a guardian naming their child's is
        // authorised on the verified link and recorded against them.
        studentId: widget.studentId,
      );
      if (!mounted) return;
      Navigator.of(context).pop(done);
    } on Object {
      if (!mounted) return;
      setState(() {
        _sending = false;
        _error = failed;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppL10n.of(context);
    return Scaffold(
      appBar: AppBar(title: Text(l10n.submitTitle)),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Text(
              widget.assignmentTitle,
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 12),
            if (!widget.canSubmit)
              Text(
                l10n.submitClosed,
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              )
            else ...[
              TextField(
                controller: _answer,
                enabled: !_sending,
                minLines: 6,
                maxLines: 16,
                maxLength: 100000,
                decoration: InputDecoration(
                  labelText: l10n.submitAnswerLabel,
                  hintText: l10n.submitAnswerHint,
                  border: const OutlineInputBorder(),
                ),
              ),
              if (widget.uploads case final uploads?)
                if (widget.schoolId case final schoolId?)
                  AttachmentField(
                    purpose: FilePurpose.assignmentSubmission,
                    schoolId: schoolId,
                    assignmentId: widget.assignmentId,
                    studentId: widget.studentId,
                    uploads: uploads,
                    enabled: !_sending,
                    source: widget.attachmentSource ?? pickPlatformAttachment,
                    onChanged: (items) => setState(() => _attachments = items),
                  )
                else
                  Text(
                    l10n.submitAttachmentsSoon,
                    style: Theme.of(context).textTheme.bodySmall,
                  )
              else
                Text(
                  l10n.submitAttachmentsSoon,
                  style: Theme.of(context).textTheme.bodySmall,
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
                // Held while an upload is in flight: handing in now would
                // file the work without the file being waited on.
                onPressed: _sending || _uploading ? null : _submit,
                child: Text(_sending ? l10n.submitSending : l10n.submitSend),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
