import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/material.dart';

import '../l10n/generated/app_l10n.dart';
import 'attachment_policy.dart';
import 'feedback.dart';
import 'file_upload_repository.dart';
import 'idempotency.dart';
import 'studafy_design.dart';

/// What the person chose, before anything has been sent.
@immutable
class PickedAttachment {
  const PickedAttachment({
    required this.displayName,
    required this.mediaType,
    required this.bytes,
    this.photoTakenAt,
  });

  final String displayName;
  final String mediaType;
  final Uint8List bytes;

  /// Set for a photo from the camera or the gallery, named by when it was
  /// picked: the picker's own file name ("scaled_21.jpg" on Android,
  /// "image_picker_….jpg" on iOS) means nothing to the sender or the
  /// teacher. Null for a file chosen by name.
  final DateTime? photoTakenAt;

  /// The same attachment, a photo named in [l10n]'s language
  /// ("Photo 2026-10-17 14.32.jpg"). Anything else keeps its own name.
  PickedAttachment localized(AppL10n l10n) {
    final at = photoTakenAt;
    if (at == null) return this;
    return PickedAttachment(
      displayName: photoAttachmentName(
        at,
        extension: _extensionOf(displayName),
        label: l10n.attachmentPhotoName,
      ),
      mediaType: mediaType,
      bytes: bytes,
      photoTakenAt: at,
    );
  }

  static String _extensionOf(String name) {
    final dot = name.lastIndexOf('.');
    return dot < 0 ? 'jpg' : name.substring(dot + 1);
  }
}

/// "Photo 2026-10-17 14.32.jpg": a camera or gallery photo, named by the
/// local time it was picked. [label] puts the stamp in a localized phrase;
/// the digits stay Latin, as they do in any file name.
String photoAttachmentName(
  DateTime at, {
  String extension = 'jpg',
  String Function(String stamp)? label,
}) {
  String two(int value) => value.toString().padLeft(2, '0');
  final local = at.toLocal();
  final stamp =
      '${local.year}-${two(local.month)}-${two(local.day)} '
      '${two(local.hour)}.${two(local.minute)}';
  final name = label == null ? 'Photo $stamp' : label(stamp);
  return sanitiseAttachmentName('$name.$extension', fallback: 'Photo.jpg');
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

/// The files of [items] a form sends, in order: uploaded and either clean
/// or still being checked. A failed upload, or a file the scan or the server
/// refused, is left out - sending it again would only be refused again.
List<String> sendableFileIds(Iterable<Attachment> items) => [
  for (final item in items)
    if (item.fileId != null &&
        (item.stage == AttachmentStage.ready ||
            item.stage == AttachmentStage.quarantined))
      item.fileId!,
];

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
      // As tall as its one row of choices, not half the screen.
      isScrollControlled: true,
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
                        mainAxisSize: MainAxisSize.min,
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
    final PickedAttachment? source;
    try {
      source = await widget.source(kind, _policy);
    } on Object {
      // The picker could not hand the file over (image_picker's
      // "no_valid_image_uri", a photo still in the cloud, ...).
      if (mounted) _say(AppL10n.of(context).attachmentPickFailed);
      return;
    }
    if (source == null || !mounted) return;
    final picked = source.localized(AppL10n.of(context));

    final refusal = _policy.refuse(
      mediaType: picked.mediaType,
      sizeBytes: picked.bytes.length,
    );
    if (refusal != null) {
      _say(_refusalText(refusal));
      return;
    }

    // Unique for every file picked, and kept through its retries: it is the
    // upload's idempotency key on the server, which remembers keys, so a
    // counter that starts again at 1 in the next attachment box sent the
    // same key with a different file and every later upload was refused.
    final localId = newIdempotencyKey('attachment');
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
      if (!ready) unawaited(_watchScan(localId, stored.id));
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

  /// Asks how the scan went until it decides, so a refused file says so
  /// and why, instead of "Checking" until the form fails on submit. Gives
  /// up quietly after about two minutes: the file is still attachable, and
  /// the server decides again on submit.
  Future<void> _watchScan(String localId, String fileId) async {
    final source = widget.uploads;
    if (source is! FileScanStatusSource) return;
    const waits = [1, 2, 2, 3, 3, 5, 5, 5, 8, 8, 10, 10, 15, 15, 15];
    for (final seconds in waits) {
      await Future<void>.delayed(Duration(seconds: seconds));
      if (!mounted) return;
      final current = _items.where((item) => item.localId == localId);
      if (current.isEmpty ||
          current.first.fileId != fileId ||
          current.first.stage != AttachmentStage.quarantined) {
        return;
      }
      final FileScanStatus status;
      try {
        status = await (source as FileScanStatusSource).scanStatus(fileId);
      } on Object {
        continue;
      }
      if (!mounted) return;
      if (status.isClean) {
        _replace(
          localId,
          (item) => item.copyWith(stage: AttachmentStage.ready),
        );
        return;
      }
      if (status.isRefused) {
        // The same bytes would be refused again, so no "try again".
        _picked.remove(localId);
        final reason = _scanRefusalText(status.failureCode);
        _replace(
          localId,
          (item) =>
              item.copyWith(stage: AttachmentStage.failed, message: reason),
        );
        return;
      }
    }
  }

  String _scanRefusalText(String? failureCode) {
    final l10n = AppL10n.of(context);
    return switch (failureCode) {
      'malware_detected' => l10n.attachmentRefusedUnsafe,
      'encrypted_document' ||
      'embedded_file' ||
      'active_content' ||
      'external_reference' => l10n.attachmentRefusedNotAllowed,
      'malformed_file' || 'polyglot_file' => l10n.attachmentRefusedDamaged,
      _ => l10n.attachmentRefusedOther,
    };
  }

  /// Marks the file the server would not attach as failed, with [message]
  /// saying why, so the form cannot be saved with it again until it is
  /// removed. No "try again": the server already has these bytes, and would
  /// refuse them the same way. Returns whether the file was on this list.
  bool markNotAccepted(String fileId, String message) {
    final index = _items.indexWhere((item) => item.fileId == fileId);
    if (index < 0) return false;
    _picked.remove(_items[index].localId);
    _replace(
      _items[index].localId,
      (item) => item.copyWith(stage: AttachmentStage.failed, message: message),
    );
    return true;
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
