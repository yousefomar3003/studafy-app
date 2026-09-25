import 'dart:typed_data';

import 'package:flutter/material.dart';

import 'attachment_policy.dart';
import 'file_upload_repository.dart';

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

enum AttachmentKind { photo, document }

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

  @override
  State<AttachmentField> createState() => _AttachmentFieldState();
}

class _AttachmentFieldState extends State<AttachmentField> {
  final List<Attachment> _items = [];
  int _counter = 0;

  AttachmentPolicy get _policy => AttachmentPolicy.of(widget.purpose);

  String _text(String en, String ar) =>
      Localizations.localeOf(context).languageCode == 'ar' ? ar : en;

  void _publish() => widget.onChanged?.call(List.unmodifiable(_items));

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
    } catch (_) {
      if (!mounted) return;
      // The reason is deliberately not shown: upload failures carry server
      // detail that is not the person's to read, and the action is the same
      // whatever it was.
      _replace(localId, (item) => item.copyWith(stage: AttachmentStage.failed));
      _say(_text('That file could not be uploaded.', 'تعذّر رفع هذا الملف.'));
    }
  }

  void _replace(String localId, Attachment Function(Attachment) update) {
    final index = _items.indexWhere((item) => item.localId == localId);
    if (index < 0) return;
    setState(() => _items[index] = update(_items[index]));
    _publish();
  }

  void _remove(Attachment item) {
    setState(() => _items.removeWhere((x) => x.localId == item.localId));
    _publish();
  }

  void _say(String message) =>
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(message)));

  String _refusalText(AttachmentRefusal refusal) => switch (refusal) {
    AttachmentRefusal.empty => _text('That file is empty.', 'هذا الملف فارغ.'),
    AttachmentRefusal.mediaType => _text(
      'Only PDF and photos can be attached.',
      'يمكن إرفاق ملفات PDF والصور فقط.',
    ),
    AttachmentRefusal.tooLarge => _text(
      'That file is larger than ${_megabytes(_policy.maximumSizeBytes)} MB.',
      'حجم الملف أكبر من ${_megabytes(_policy.maximumSizeBytes)} ميغابايت.',
    ),
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
            label: _stageLabel(item.stage),
          ),
        if (widget.enabled && !full)
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Row(
              children: [
                TextButton.icon(
                  onPressed: () => _add(AttachmentKind.document),
                  icon: const Icon(Icons.attach_file_rounded),
                  label: Text(_text('Attach file', 'إرفاق ملف')),
                ),
                TextButton.icon(
                  onPressed: () => _add(AttachmentKind.photo),
                  icon: const Icon(Icons.image_outlined),
                  label: Text(_text('Photo', 'صورة')),
                ),
              ],
            ),
          ),
        if (full)
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Text(
              _text(
                'Up to ${widget.maximumCount} attachments.',
                'حتى ${widget.maximumCount} مرفقات.',
              ),
              style: Theme.of(context).textTheme.labelSmall,
            ),
          ),
      ],
    );
  }

  String _stageLabel(AttachmentStage stage) => switch (stage) {
    AttachmentStage.uploading => _text('Uploading', 'جارٍ الرفع'),
    // Honest about what quarantine means: it is attached, and it is not
    // downloadable by anyone until the scan clears it.
    AttachmentStage.quarantined => _text('Checking', 'قيد الفحص'),
    AttachmentStage.ready => _text('Ready', 'جاهز'),
    AttachmentStage.failed => _text('Failed', 'فشل'),
  };
}

class _AttachmentTile extends StatelessWidget {
  const _AttachmentTile({
    required this.item,
    required this.label,
    this.onRemove,
  });

  final Attachment item;
  final String label;
  final VoidCallback? onRemove;

  @override
  Widget build(BuildContext context) => ListTile(
    dense: true,
    contentPadding: EdgeInsets.zero,
    leading: item.stage == AttachmentStage.uploading
        ? const SizedBox(
            width: 20,
            height: 20,
            child: CircularProgressIndicator(strokeWidth: 2),
          )
        : Icon(
            switch (item.stage) {
              AttachmentStage.ready => Icons.check_circle_outline_rounded,
              AttachmentStage.quarantined => Icons.hourglass_empty_rounded,
              AttachmentStage.failed => Icons.error_outline_rounded,
              AttachmentStage.uploading => Icons.upload_rounded,
            },
            color: item.stage == AttachmentStage.failed
                ? Theme.of(context).colorScheme.error
                : null,
          ),
    // A filename is user content: it renders in its own direction, and it is
    // already sanitised by the time it reaches here.
    title: Text(item.displayName, maxLines: 1, overflow: TextOverflow.ellipsis),
    subtitle: Text(label),
    trailing: onRemove == null
        ? null
        : IconButton(
            icon: const Icon(Icons.close_rounded),
            onPressed: onRemove,
            tooltip: MaterialLocalizations.of(context).deleteButtonTooltip,
          ),
  );
}
