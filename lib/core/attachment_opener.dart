import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';

import 'file_upload_repository.dart';
import 'uploads_scope.dart';
import '../l10n/generated/app_l10n.dart';
import 'feedback.dart';

/// Shows [file] to the person who tapped it.
///
/// A photo opens in the app. Anything else goes to the system share sheet,
/// which on iOS previews a PDF and offers to keep it in Files - the app has
/// no document viewer of its own, and a half-working one is worse than the
/// platform's.
///
/// Nothing is written to a place the app keeps: the bytes are fetched on a
/// single-use grant and handed straight on.
typedef AttachmentPresenter = Future<void> Function(
  BuildContext context,
  DownloadedFile file,
);

Future<void> presentDownloadedFile(
  BuildContext context,
  DownloadedFile file,
) async {
  if (file.isImage) {
    await Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (_) => Scaffold(
          appBar: AppBar(title: Text(file.displayName)),
          backgroundColor: Colors.black,
          body: Center(
            child: InteractiveViewer(child: Image.memory(file.bytes)),
          ),
        ),
      ),
    );
    return;
  }
  await SharePlus.instance.share(
    ShareParams(
      files: [
        XFile.fromData(
          file.bytes,
          name: file.displayName,
          mimeType: file.mediaType,
        ),
      ],
      fileNameOverrides: [file.displayName],
    ),
  );
}

/// The files attached to something already stored, each one tappable.
///
/// Renders nothing when there are none, so a caller can place it without a
/// condition of its own. A file still being scanned is listed but cannot be
/// opened, and says so.
class StoredAttachmentList extends StatefulWidget {
  const StoredAttachmentList({
    super.key,
    required this.attachments,
    this.uploads,
    this.present = presentDownloadedFile,
    this.color,
    this.dense = false,
  });

  final List<StoredAttachment> attachments;

  /// Falls back to the app's [UploadsScope]. Null in both places means the
  /// build has nowhere to fetch from, and the rows are shown but inert.
  final FileUploadRepository? uploads;
  final AttachmentPresenter present;

  /// Text and icon colour, for rows drawn on a coloured bubble.
  final Color? color;
  final bool dense;

  @override
  State<StoredAttachmentList> createState() => _StoredAttachmentListState();
}

class _StoredAttachmentListState extends State<StoredAttachmentList> {
  String? _opening;

  Future<void> _open(StoredAttachment item) async {
    final uploads = widget.uploads ?? UploadsScope.maybeOf(context);
    if (uploads == null || _opening != null) return;
    final messenger = ScaffoldMessenger.of(context);
    if (!item.isReady) {
      messenger.showMessage(AppL10n.of(context).attachmentThisFileIsStillBeing);
      return;
    }
    setState(() => _opening = item.id);
    final failed = AppL10n.of(context).attachmentThatFileCouldNotBe2;
    try {
      final file = await uploads.download(item.id);
      if (!mounted) return;
      await widget.present(context, file);
    } on Object {
      // As with uploads, the reason stays on the server: what the person can
      // do about it is the same whatever it was.
      messenger.showMessage(failed);
    } finally {
      if (mounted) setState(() => _opening = null);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (widget.attachments.isEmpty) return const SizedBox.shrink();
    final color = widget.color;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        for (final item in widget.attachments)
          InkWell(
            onTap: () => _open(item),
            child: Padding(
              padding: EdgeInsets.symmetric(vertical: widget.dense ? 3 : 8),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (_opening == item.id)
                    SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: color,
                      ),
                    )
                  else
                    Icon(
                      !item.isReady
                          ? Icons.hourglass_empty_rounded
                          : (item.mediaType ?? '').startsWith('image/')
                          ? Icons.image_outlined
                          : Icons.description_outlined,
                      size: widget.dense ? 16 : 20,
                      color: color,
                    ),
                  const SizedBox(width: 8),
                  Flexible(
                    child: Text(
                      item.displayName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: widget.dense ? 12 : 14,
                        color: color,
                        decoration: item.isReady
                            ? TextDecoration.underline
                            : null,
                        decorationColor: color,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }
}
