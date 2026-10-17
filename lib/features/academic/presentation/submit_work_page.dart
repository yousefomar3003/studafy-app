import 'package:flutter/material.dart';

import '../../../core/attachment_field.dart';
import '../../../core/content_links.dart';
import '../../../core/coursework_attachments.dart';
import '../../../core/file_upload_repository.dart';
import '../../../core/platform_attachment_source.dart';
import '../../../core/studafy_components.dart';
import '../../../core/studafy_design.dart';
import '../../../core/studafy_formatting.dart';
import '../../../core/unsaved_changes.dart';
import '../../../core/uploads_scope.dart';
import '../../../core/user_content_text.dart';
import '../../../l10n/generated/app_l10n.dart';
import '../domain/academic_repository.dart';
import 'coursework_messages.dart';
import 'submission_history_view.dart';

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
    this.material = const [],
    this.links = const [],
    this.instructions,
    this.deadline,
  });

  final AssignmentRepository repository;
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

  /// What the teacher attached to the work - the worksheet, the reading.
  /// Shown above the answer, because it is usually what the answer is about.
  final List<StoredAttachment> material;

  /// Titled links the teacher put on the work.
  final List<ContentLink> links;

  /// The teacher's instructions, when the caller has them.
  final String? instructions;

  /// False for work that is not open, so a student is told before typing
  /// rather than after.
  final bool canSubmit;

  /// Until when the work can be handed in or replaced, and whether it still
  /// can be. The server enforces it either way; this only says so up front.
  final SubmissionDeadline? deadline;

  @override
  State<SubmitWorkPage> createState() => _SubmitWorkPageState();
}

class _SubmitWorkPageState extends State<SubmitWorkPage> {
  final _answer = TextEditingController();
  bool _sending = false;
  String? _error;
  List<Attachment> _attachments = const [];

  /// Files on the work being replaced, and which of them to keep. Kept
  /// files carry over without another upload.
  List<StoredAttachment> _previousFiles = const [];

  /// Keeps the history's state (and its one request) when the rows above it
  /// change.
  final _historyKey = GlobalKey<SubmissionHistoryViewState>();
  final Set<String> _keep = {};

  /// Carried-over files the server would not carry over (the scan has
  /// removed them since), and why. Unticked, and no longer sent.
  final Map<String, String> _refusedKept = {};

  final _attachmentsKey = GlobalKey<AttachmentFieldState>();

  /// Something has been handed in already, so sending replaces it.
  bool _handedIn = false;

  /// From the history the page already loads: the files on the work being
  /// replaced, all kept unless the student unticks one.
  void _previousLoaded(List<SubmissionAttempt> attempts) {
    final current = attempts.where((a) => a.current).firstOrNull;
    if (!mounted || current == null) return;
    setState(() {
      _handedIn = true;
      _previousFiles = current.attachments
          .where((file) => file.isReady)
          .toList();
      _keep
        ..clear()
        ..addAll(_previousFiles.map((file) => file.id));
    });
  }

  bool get _open =>
      widget.canSubmit &&
      (widget.deadline?.state ?? SubmissionWindow.open) ==
          SubmissionWindow.open;

  bool get _uploading =>
      _attachments.any((a) => a.stage == AttachmentStage.uploading);

  /// A typed answer or a file added, not yet handed in: leaving asks first.
  bool get _unsaved =>
      _open &&
      !_sending &&
      (_answer.text.trim().isNotEmpty || _attachments.isNotEmpty);

  /// Only files the server actually has, in the order sent. A failed
  /// upload, or a file the scan or the server refused, is simply absent
  /// rather than blocking the hand-in.
  List<String> get _readyFileIds => [
    ..._keep,
    ...sendableFileIds(_attachments),
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
    // A refusal names a file by its place in this list.
    final sent = _readyFileIds;
    try {
      await widget.repository.submitAssignment(
        widget.assignmentId,
        _answer.text.trim(),
        attachmentFileIds: sent,
        // The same field for both callers. A student naming their own record
        // takes the ordinary path; a guardian naming their child's is
        // authorised on the verified link and recorded against them.
        studentId: widget.studentId,
      );
      if (!mounted) return;
      Navigator.of(context).pop(done);
    } on CourseworkRefusal catch (refusal) {
      if (!mounted) return;
      // A refused file is marked where it is, and left out of the next
      // hand-in; nothing was handed in.
      if (refusal.problem == CourseworkProblem.attachmentRefused) {
        _markRefused(l10n, sent, refusal.rows);
      }
      setState(() {
        _sending = false;
        _error = courseworkMessage(l10n, refusal);
      });
    } on Object {
      if (!mounted) return;
      setState(() {
        _sending = false;
        _error = failed;
      });
    }
  }

  void _markRefused(AppL10n l10n, List<String> sent, Map<String, String> rows) {
    final kept = <String, String>{};
    for (final MapEntry(key: path, value: reason) in rows.entries) {
      final index = path.startsWith('attachmentFileIds.')
          ? int.tryParse(path.substring('attachmentFileIds.'.length))
          : null;
      if (index == null || index < 0 || index >= sent.length) continue;
      if (_keep.contains(sent[index])) {
        kept[sent[index]] = attachmentNotAcceptedText(l10n, reason);
      }
    }
    markRefusedFiles(l10n, _attachmentsKey.currentState, sent, rows);
    if (kept.isEmpty) return;
    setState(() {
      _refusedKept.addAll(kept);
      _keep.removeAll(kept.keys);
    });
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    // Follows typing without rebuilding the page.
    listenable: _answer,
    builder: (_, page) => UnsavedChangesScope(unsaved: _unsaved, child: page!),
    child: _page(context),
  );

  Widget _page(BuildContext context) {
    final l10n = AppL10n.of(context);
    final window = widget.canSubmit
        ? widget.deadline?.state ?? SubmissionWindow.open
        : SubmissionWindow.closed;
    final uploads = widget.uploads ?? UploadsScope.maybeOf(context);
    return Scaffold(
      backgroundColor: studafyCanvas,
      appBar: AppBar(title: Text(l10n.submitTitle)),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsetsDirectional.fromSTEB(16, 4, 16, 32),
          children: [
            // What the work is, whether it is open, and until when.
            FeatureCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const IconBadge(icon: Icons.assignment_rounded),
                      const SizedBox(width: 14),
                      Expanded(
                        child: UserContentText(
                          widget.assignmentTitle,
                          style: const TextStyle(
                            color: studafyInk,
                            fontSize: 18,
                            fontWeight: FontWeight.w800,
                            height: 1.25,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      switch (window) {
                        SubmissionWindow.open => StatusPill(
                          label: l10n.workStateOpen,
                          icon: Icons.edit_rounded,
                        ),
                        SubmissionWindow.closed => StatusPill(
                          label: l10n.workStateClosed,
                          icon: Icons.lock_clock_rounded,
                          color: studafyMuted,
                        ),
                        SubmissionWindow.gradedLocked => StatusPill(
                          label: l10n.workStateGraded,
                          icon: Icons.grading_rounded,
                          color: studafyTeal,
                        ),
                      },
                      if (widget.deadline case final deadline?)
                        _DeadlineLine(deadline: deadline),
                    ],
                  ),
                ],
              ),
            ),
            if (widget.instructions case final text? when text.isNotEmpty) ...[
              SectionHeader(l10n.submitInstructions),
              FeatureCard(child: LinkedText(text)),
            ],
            if (widget.material.isNotEmpty || widget.links.isNotEmpty) ...[
              SectionHeader(l10n.submitMaterialHeading),
              FeatureCard(
                padding: const EdgeInsetsDirectional.fromSTEB(14, 6, 8, 6),
                child: AttachmentsView(
                  attachments: widget.material,
                  links: widget.links,
                  uploads: widget.uploads,
                ),
              ),
            ],
            SectionHeader(l10n.submitAnswerLabel),
            if (!_open)
              _Notice(
                icon: window == SubmissionWindow.gradedLocked
                    ? Icons.grading_rounded
                    : Icons.lock_clock_rounded,
                text: switch (widget.deadline?.state) {
                  SubmissionWindow.closed => l10n.deadlineClosed,
                  SubmissionWindow.gradedLocked => l10n.deadlineGraded,
                  _ => l10n.submitClosed,
                },
              )
            else ...[
              if (_handedIn)
                Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: _Notice(
                    icon: Icons.history_rounded,
                    text: l10n.deadlineReplaceHint,
                  ),
                ),
              FeatureCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (_previousFiles.isNotEmpty) ...[
                      Text(
                        l10n.deadlineKeepFiles,
                        style: const TextStyle(
                          color: studafyInk,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      for (final file in _previousFiles)
                        CheckboxListTile(
                          contentPadding: EdgeInsets.zero,
                          dense: true,
                          controlAffinity: ListTileControlAffinity.leading,
                          value: _keep.contains(file.id),
                          title: Text(file.displayName),
                          subtitle: _refusedKept[file.id] == null
                              ? null
                              : Text(
                                  _refusedKept[file.id]!,
                                  style: const TextStyle(
                                    color: studafyDanger,
                                    fontSize: 12.5,
                                  ),
                                ),
                          onChanged:
                              _sending || _refusedKept.containsKey(file.id)
                              ? null
                              : (value) => setState(() {
                                  if (value ?? false) {
                                    _keep.add(file.id);
                                  } else {
                                    _keep.remove(file.id);
                                  }
                                }),
                        ),
                      const Divider(height: 24, color: studafyHairline),
                    ],
                    TextField(
                      controller: _answer,
                      enabled: !_sending,
                      minLines: 6,
                      maxLines: 16,
                      maxLength: 100000,
                      textCapitalization: TextCapitalization.sentences,
                      decoration: InputDecoration(
                        hintText: l10n.submitAnswerHint,
                        counterText: '',
                        filled: true,
                        fillColor: studafyCanvas,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(16),
                          borderSide: BorderSide.none,
                        ),
                      ),
                      onChanged: (_) {
                        if (_error != null) setState(() => _error = null);
                      },
                    ),
                    const SizedBox(height: 8),
                    // A guardian's route into this page has no uploads to
                    // hand it; the app-wide scope is the same pipeline
                    // either way.
                    if (uploads != null && widget.schoolId != null)
                      AttachmentField(
                        key: _attachmentsKey,
                        purpose: FilePurpose.assignmentSubmission,
                        schoolId: widget.schoolId!,
                        assignmentId: widget.assignmentId,
                        studentId: widget.studentId,
                        uploads: uploads,
                        enabled: !_sending,
                        source:
                            widget.attachmentSource ?? pickPlatformAttachment,
                        onChanged: (items) =>
                            setState(() => _attachments = items),
                      )
                    else
                      Text(
                        l10n.submitAttachmentsSoon,
                        style: const TextStyle(
                          color: studafyMuted,
                          fontSize: 12.5,
                        ),
                      ),
                  ],
                ),
              ),
              if (_error != null) ...[
                const SizedBox(height: 12),
                _Notice(
                  icon: Icons.error_outline_rounded,
                  text: _error!,
                  danger: true,
                ),
              ],
              const SizedBox(height: 16),
              FilledButton.icon(
                // Held while an upload is in flight: handing in now would
                // file the work without the file being waited on.
                onPressed: _sending || _uploading ? null : _submit,
                style: FilledButton.styleFrom(
                  minimumSize: const Size.fromHeight(54),
                ),
                icon: _sending
                    ? const SizedBox.square(
                        dimension: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Icon(Icons.send_rounded),
                label: Text(
                  _sending
                      ? l10n.submitSending
                      : _handedIn
                      ? l10n.submitHandInAgain
                      : l10n.submitSend,
                ),
              ),
            ],
            // What has already been handed in - including by a parent - so
            // a resubmission is made knowing what it replaces.
            const SizedBox(height: 12),
            SubmissionHistoryView(
              key: _historyKey,
              repository: widget.repository,
              assignmentId: widget.assignmentId,
              studentId: widget.studentId,
              uploads: widget.uploads,
              shrinkWrap: true,
              hideWhenEmpty: true,
              title: l10n.historyYours,
              onLoaded: _previousLoaded,
            ),
          ],
        ),
      ),
    );
  }
}

/// A calm line of information on a soft background - why work cannot be
/// handed in, or what handing it in again does. Errors use the same shape
/// in red.
class _Notice extends StatelessWidget {
  const _Notice({required this.icon, required this.text, this.danger = false});

  final IconData icon;
  final String text;
  final bool danger;

  @override
  Widget build(BuildContext context) => Semantics(
    liveRegion: danger,
    child: Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: danger ? studafyDanger.withValues(alpha: .08) : studafyWash,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 20, color: danger ? studafyDanger : studafySteel),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              text,
              style: TextStyle(
                color: danger ? studafyDanger : studafyInk,
                height: 1.4,
              ),
            ),
          ),
        ],
      ),
    ),
  );
}

/// "Due 1 Oct 2026 23:59 (Asia/Riyadh)" - on the school's clock, which is
/// the one the deadline is enforced on.
class _DeadlineLine extends StatelessWidget {
  const _DeadlineLine({required this.deadline});

  final SubmissionDeadline deadline;

  String _when(BuildContext context, String local) {
    final at = DateTime.tryParse(local);
    if (at == null) return local;
    return '${studafyMediumDate(context, at)} '
        '${studafyTimeOfDay(context, TimeOfDay.fromDateTime(at))}';
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppL10n.of(context);
    const style = TextStyle(color: studafyMuted, fontSize: 13);
    return Row(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Padding(
          padding: EdgeInsets.only(top: 1),
          child: Icon(Icons.schedule_rounded, size: 16, color: studafyMuted),
        ),
        const SizedBox(width: 5),
        Flexible(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                l10n.deadlineDue(
                  _when(context, deadline.deadlineLocal),
                  studafyTimeZone(deadline.timeZone),
                ),
                style: style.copyWith(
                  color: studafyInk,
                  fontWeight: FontWeight.w600,
                ),
              ),
              if (deadline.extendedUntilLocal case final until?)
                Text(
                  l10n.deadlineExtended(_when(context, until)),
                  style: style,
                ),
            ],
          ),
        ),
      ],
    );
  }
}
