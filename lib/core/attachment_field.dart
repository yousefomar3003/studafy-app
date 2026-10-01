import 'dart:typed_data';

import 'package:flutter/material.dart';

import '../l10n/generated/app_l10n.dart';
import 'attachment_policy.dart';
import 'feedback.dart';
import 'file_upload_repository.dart';
import 'studafy_design.dart';

/// What the person chose, before anything has been sent.
@immutable
class PickedAttachment {
  const PickedAttachment({
    required this.displayName,
    required this.mediaType,
    required this.bytes,
  });

  final String displayName;
  final String mediaType;
  final Uint8List bytes;
}

enum AttachmentKind {
  photo,
  document,

  /// A new photo taken with the camera, for a whiteboard.
  camera,
}

/// Opens the platform picker. Injected so a test never touches a channel.
typedef AttachmentSource = Future<PickedAttachment?> Function(
  AttachmentKind kind,
  AttachmentPolicy policy,
);

enum AttachmentStage { uploading, quarantined, ready, failed }

/// One attachment as the screen knows it: what was picked, and how far the
/// pipeline has taken it.
@immutable
class Attachment {
  const Attachment({
    required this.localId,
    required this.displayName,
    required this.sizeBytes,
    required this.stage,
    this.fileId,
    this.message,
  });

  final String localId;
  final String displayName;
  final int sizeBytes;
  final AttachmentStage stage;

  /// The server's file id, once the upload completed. Null until then, and
  /// this is what a form submits - never a path or a bucket key.
  final String? fileId;
  final String? message;

  Attachment copyWith({
    AttachmentStage? stage,
    String? fileId,
    String? message,
  }) => Attachment(
    localId: localId,
    displayName: displayName,
    sizeBytes: sizeBytes,
    stage: stage ?? this.stage,
    fileId: fileId ?? this.fileId,
    message: message ?? this.message,
  );
}

/// Attach documents and photos to whatever is being written.
///
/// The widget owns the upload rather than the host form because the pipeline
/// wants the bytes early: an upload intent, the signed PUT and the scan all
/// happen while the person is still typing, so pressing Send is not a
/// thirty-second wait. The host is handed file ids through [onChanged] and
/// should refuse to submit while anything is still [AttachmentStage.uploading].
class AttachmentField extends StatefulWidget {
  const AttachmentField({
    super.key,
    required this.purpose,
    required this.schoolId,
    required this.uploads,
    required this.source,
    this.onChanged,
    this.classroomId,
    this.assignmentId,
    this.studentId,
    this.maximumCount = 5,
    this.enabled = true,
    this.showAddButtons = true,
  });

  final FilePurpose purpose;
  final String schoolId;
  final FileUploadRepository uploads;
  final AttachmentSource source;
  final ValueChanged<List<Attachment>>? onChanged;
  final String? classroomId;
  final String? assignmentId;
  final String? studentId;
  final int maximumCount;
  final bool enabled;

  /// False when the host offers its own attach button (the message
  /// composer's, WhatsApp-style) and calls [AttachmentFieldState.add] or
  /// [AttachmentFieldState.chooseAndAdd]; the field then shows only what
  /// has been attached, each with a remove button.
  final bool showAddButtons;

  @override
  State<AttachmentField> createState() => AttachmentFieldState();
}

class AttachmentFieldState extends State<AttachmentField> {
  final List<Attachment> _items = [];
  int _counter = 0;

  /// What was picked for each attachment still on the list, so a failed
  /// upload can be tried again without picking the file again.
  final Map<String, PickedAttachment> _picked = {};

  AttachmentPolicy get _policy => AttachmentPolicy.of(widget.purpose);

  void _publish() => widget.onChanged?.call(List.unmodifiable(_items));

  /// Whether another attachment may be added.
  bool get canAddMore => widget.enabled && _items.length < widget.maximumCount;

  /// Asks what to attach - a photo or a document - then adds it.
  Future<void> chooseAndAdd() async {
    if (!canAddMore) {
      _say(
        AppL10n.of(context)
            .attachmentUpToMaximumcountAttachments(widget.maximumCount),
      );
      return;
    }
    final l10n = AppL10n.of(context);
    final kind = await showModalBottomSheet<AttachmentKind>(
      context: context,
      builder: (sheetContext) => SafeArea(
        child: Padding(
          padding: const EdgeInsetsDirectional.fromSTEB(16, 0, 16, 16),
          child: Row(
            children: [
              for (final (kind, icon, label) in [
                (
                  AttachmentKind.photo,
                  Icons.photo_library_rounded,
                  l10n.attachmentPhoto,
                ),
                (
                  AttachmentKind.camera,
                  Icons.photo_camera_rounded,
                  l10n.attachmentCamera,
                ),
                (
                  AttachmentKind.document,
                  Icons.description_rounded,
                  l10n.attachmentDocument,
                ),
              ])
                Expanded(
                  child: InkWell(
                    borderRadius: BorderRadius.circular(18),
                    onTap: () => Navigator.pop(sheetContext, kind),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      child: Column(
                        children: [
                          CircleAvatar(
                            radius: 28,
                            backgroundColor: Theme.of(sheetContext)
                                .colorScheme
                                .primary
                                .withValues(alpha: .1),
                            child: Icon(
                              icon,
                              color: Theme.of(sheetContext).colorScheme.primary,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(label, textAlign: TextAlign.center),
                        ],
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
    if (kind == null || !mounted) return;
    await add(kind);
  }

  /// Adds one attachment of [kind] from the platform picker.
  Future<void> add(AttachmentKind kind) => _add(kind);

  Future<void> _add(AttachmentKind kind) async {
    final picked = await widget.source(kind, _policy);
    if (picked == null || !mounted) return;

    final refusal = _policy.refuse(
      mediaType: picked.mediaType,
      sizeBytes: picked.bytes.length,
    );
    if (refusal != null) {
      _say(_refusalText(refusal));
      return;
    }

    final localId = 'attachment-${++_counter}';
    final name = sanitiseAttachmentName(picked.displayName);
    _picked[localId] = picked;
    setState(() {
      _items.add(
        Attachment(
          localId: localId,
          displayName: name,
          sizeBytes: picked.bytes.length,
          stage: AttachmentStage.uploading,
        ),
      );
    });
    _publish();
    await _upload(localId, picked, name);
  }

  /// Tries a failed upload again, under the same attempt so the server
  /// never keeps two copies.
  Future<void> _retry(Attachment item) async {
    final picked = _picked[item.localId];
    if (picked == null) return;
    _replace(
      item.localId,
      (current) => current.copyWith(stage: AttachmentStage.uploading),
    );
    await _upload(item.localId, picked, item.displayName);
  }

  Future<void> _upload(
    String localId,
    PickedAttachment picked,
    String name,
  ) async {
    try {
      final stored = await widget.uploads.upload(
        FileUploadCommand(
          attemptId: localId,
          schoolId: widget.schoolId,
          purpose: widget.purpose,
          displayName: name,
          mediaType: picked.mediaType,
          bytes: picked.bytes,
          classroomId: widget.classroomId,
          assignmentId: widget.assignmentId,
          studentId: widget.studentId,
        ),
      );
      if (!mounted) return;
      // A clean verdict is the worker's to give and it is not instant. The
      // file is attachable either way; what it is not yet is downloadable.
      final ready = stored.scanState == 'clean';
      _replace(
        localId,
        (item) => item.copyWith(
          stage: ready ? AttachmentStage.ready : AttachmentStage.quarantined,
          fileId: stored.id,
        ),
      );
    } on FileServiceUnavailable {
      if (!mounted) return;
      // Not the file and not the connection: this school's server does not
      // take files yet, so trying again would not help.
      _picked.remove(localId);
      final reason = AppL10n.of(context).filesSwitchedOff;
      _replace(
        localId,
        (item) => item.copyWith(stage: AttachmentStage.failed, message: reason),
      );
    } catch (_) {
      if (!mounted) return;
      // The reason is deliberately not shown: upload failures carry server
      // detail that is not the person's to read, and the action is the same
      // whatever it was. The row says it failed and offers to try again, so
      // no snackbar is raised over the form - in a chat it would sit on top
      // of the send button.
      _replace(
        localId,
        (item) => item.copyWith(
          stage: AttachmentStage.failed,
          message: AppL10n.of(context).attachmentThatFileCouldNotBe,
        ),
      );
    }
  }

  void _replace(String localId, Attachment Function(Attachment) update) {
    final index = _items.indexWhere((item) => item.localId == localId);
    if (index < 0) return;
    setState(() => _items[index] = update(_items[index]));
    _publish();
  }

  void _remove(Attachment item) {
    _picked.remove(item.localId);
    setState(() => _items.removeWhere((x) => x.localId == item.localId));
    _publish();
  }

  void _say(String message) =>
      ScaffoldMessenger.of(context).showMessage(message);

  String _refusalText(AttachmentRefusal refusal) => switch (refusal) {
    AttachmentRefusal.empty => AppL10n.of(context).attachmentThatFileIsEmpty,
    AttachmentRefusal.mediaType => AppL10n.of(
      context,
    ).attachmentOnlyPdfAndPhotosCan,
    AttachmentRefusal.tooLarge => AppL10n.of(
      context,
    ).attachmentThatFileIsLargerThan(_megabytes(_policy.maximumSizeBytes)),
  };

  static String _megabytes(int bytes) =>
      (bytes / (1024 * 1024)).round().toString();

  @override
  Widget build(BuildContext context) {
    final full = _items.length >= widget.maximumCount;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (final item in _items)
          _AttachmentTile(
            item: item,
            onRemove: widget.enabled ? () => _remove(item) : null,
            onRetry:
                widget.enabled &&
                    item.stage == AttachmentStage.failed &&
                    _picked.containsKey(item.localId)
                ? () => _retry(item)
                : null,
            label: item.stage == AttachmentStage.failed && item.message != null
                ? item.message!
                : _stageLabel(item.stage),
          ),
        if (widget.showAddButtons && widget.enabled && !full)
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Row(
              children: [
                TextButton.icon(
                  onPressed: () => _add(AttachmentKind.document),
                  icon: const Icon(Icons.attach_file_rounded),
                  label: Text(AppL10n.of(context).attachmentAttachFile),
                ),
                TextButton.icon(
                  onPressed: () => _add(AttachmentKind.photo),
                  icon: const Icon(Icons.image_outlined),
                  label: Text(AppL10n.of(context).attachmentPhoto),
                ),
              ],
            ),
          ),
        if (full && widget.showAddButtons)
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Text(
              AppL10n.of(context)
                  .attachmentUpToMaximumcountAttachments(widget.maximumCount),
              style: Theme.of(context).textTheme.labelSmall,
            ),
          ),
      ],
    );
  }

  String _stageLabel(AttachmentStage stage) => switch (stage) {
    AttachmentStage.uploading => AppL10n.of(context).attachmentUploading,
    // Honest about what quarantine means: it is attached, and it is not
    // downloadable by anyone until the scan clears it.
    AttachmentStage.quarantined => AppL10n.of(context).attachmentChecking,
    AttachmentStage.ready => AppL10n.of(context).attachmentReady,
    AttachmentStage.failed => AppL10n.of(context).attachmentFailed,
  };
}

class _AttachmentTile extends StatelessWidget {
  const _AttachmentTile({
    required this.item,
    required this.label,
    this.onRemove,
    this.onRetry,
  });

  final Attachment item;
  final String label;
  final VoidCallback? onRemove;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    final failed = item.stage == AttachmentStage.failed;
    final error = Theme.of(context).colorScheme.error;
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Container(
        padding: const EdgeInsetsDirectional.fromSTEB(10, 6, 2, 6),
        decoration: BoxDecoration(
          color: failed ? error.withValues(alpha: .06) : Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: failed ? error.withValues(alpha: .3) : studafyHairline,
          ),
        ),
        child: Row(
          children: [
            SizedBox.square(
              dimension: 36,
              child: item.stage == AttachmentStage.uploading
                  ? const Padding(
                      padding: EdgeInsets.all(9),
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : Icon(switch (item.stage) {
                      AttachmentStage.ready =>
                        Icons.check_circle_outline_rounded,
                      AttachmentStage.quarantined =>
                        Icons.hourglass_empty_rounded,
                      AttachmentStage.failed => Icons.error_outline_rounded,
                      AttachmentStage.uploading => Icons.upload_rounded,
                    }, color: failed ? error : null),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // A filename is user content: it renders in its own
                  // direction, and it is already sanitised by now.
                  Text(
                    item.displayName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                  Text(
                    label,
                    style: TextStyle(
                      fontSize: 12,
                      color: failed ? error : Theme.of(context).hintColor,
                    ),
                  ),
                ],
              ),
            ),
            if (onRetry != null)
              TextButton(
                onPressed: onRetry,
                child: Text(AppL10n.of(context).attachmentRetry),
              ),
            if (onRemove != null)
              IconButton(
                icon: const Icon(Icons.close_rounded),
                onPressed: onRemove,
                tooltip: MaterialLocalizations.of(context).deleteButtonTooltip,
              ),
          ],
        ),
      ),
    );
  }
}
