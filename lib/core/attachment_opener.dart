import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import '../l10n/generated/app_l10n.dart';
import 'attachment_policy.dart';
import 'failures.dart';
import 'feedback.dart';
import 'file_upload_repository.dart';
import 'navigation.dart';
import 'uploads_scope.dart';

/// Shows [file] to the person who tapped it.
///
/// A photo opens in the app. Anything else goes to the system share sheet,
/// which on iOS previews a PDF and offers to keep it in Files - the app has
/// no document viewer of its own, and a half-working one is worse than the
/// platform's. Android's share sheet only sends a file on, so there it opens
/// in an app that views its type (a PDF reader, Docs, Slides) first, and
/// falls back to the share sheet when the phone has none.
///
/// Nothing is written to a place the app keeps: the bytes are fetched on a
/// single-use grant and handed straight on (on Android through the cache
/// folder, which the system may clear and the next opened file replaces).
typedef AttachmentPresenter = Future<void> Function(
  BuildContext context,
  DownloadedFile file,
);

Future<void> presentDownloadedFile(
  BuildContext context,
  DownloadedFile file,
) async {
  if (file.isImage) {
    await Navigator.of(context).pushOnce<void>(
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
  final name = sharedFileName(file.displayName, file.mediaType);
  if (!kIsWeb && defaultTargetPlatform == TargetPlatform.android) {
    if (await openWithAndroidViewer(file, name)) return;
  }
  await SharePlus.instance.share(
    ShareParams(
      files: [XFile.fromData(file.bytes, name: name, mimeType: file.mediaType)],
      fileNameOverrides: [name],
    ),
  );
}

/// MainActivity.kt's handler for [openWithAndroidViewer].
const attachmentViewerChannel = MethodChannel('com.studafy.light/attachments');

/// Writes [file] to `attachments/` in the cache folder, the only folder
/// MainActivity hands to another app, and asks Android to open it there.
/// False when no app on the phone can, or anything else stops it, so the
/// caller can fall back to the share sheet. Earlier files are removed first.
@visibleForTesting
Future<bool> openWithAndroidViewer(
  DownloadedFile file,
  String name, {
  Future<Directory> Function() cacheDirectory = getTemporaryDirectory,
  MethodChannel channel = attachmentViewerChannel,
}) async {
  try {
    final folder = Directory(
      p.join((await cacheDirectory()).path, 'attachments'),
    );
    if (folder.existsSync()) await folder.delete(recursive: true);
    await folder.create(recursive: true);
    final saved = File(p.join(folder.path, sanitiseAttachmentName(name)));
    await saved.writeAsBytes(file.bytes, flush: true);
    return await channel.invokeMethod<bool>('open', {
          'path': saved.path,
          'type': file.mediaType,
        }) ??
        false;
  } on Object {
    return false;
  }
}

/// The name a shared file is saved under: the name it was uploaded with,
/// given an extension from its type when it has none, so the receiving app
/// knows how to open "Worksheet" as a PDF.
String sharedFileName(String displayName, String? mediaType) {
  final name = displayName.trim().isEmpty ? 'file' : displayName.trim();
  if (RegExp(r'\.[A-Za-z0-9]{1,5}$').hasMatch(name)) return name;
  final extension = switch (mediaType) {
    'application/pdf' => 'pdf',
    'image/jpeg' => 'jpg',
    'image/png' => 'png',
    'image/webp' => 'webp',
    'audio/mp4' => 'm4a',
    'application/vnd.openxmlformats-officedocument.wordprocessingml.document' =>
      'docx',
    'application/vnd.openxmlformats-officedocument.presentationml.presentation' =>
      'pptx',
    _ => null,
  };
  return extension == null ? name : '$name.$extension';
}

/// The files attached to something already stored, each one tappable.
///
/// Renders nothing when there are none, so a caller can place it without a
/// condition of its own. A file still being scanned is listed but cannot be
/// opened, and says so; one the scan removed after it was attached says
/// that instead, under its name.
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
    final messenger = ScaffoldMessenger.of(context);
    // Said wherever it is shown: there is nothing to fetch.
    if (item.isRemoved) {
      messenger.showMessage(AppL10n.of(context).attachmentRemovedBySafetyCheck);
      return;
    }
    final uploads = widget.uploads ?? UploadsScope.maybeOf(context);
    if (uploads == null || _opening != null) return;
    if (!item.isReady) {
      messenger.showMessage(AppL10n.of(context).attachmentThisFileIsStillBeing);
      return;
    }
    setState(() => _opening = item.id);
    final failed = AppL10n.of(context).attachmentThatFileCouldNotBe2;
    final gone = AppL10n.of(context).downloadUnavailable;
    try {
      final file = await uploads.download(item.id);
      if (!mounted) return;
      await widget.present(context, file);
    } on Object catch (error) {
      // A file replaced by a newer one, taken off the work, or deleted is
      // refused as not found: refreshing shows what is there now. Anything
      // else keeps its reason on the server.
      messenger.showMessage(
        Failure.fromError(error).code == Failure.notFound.code ? gone : failed,
      );
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
                      item.isRemoved
                          ? Icons.gpp_bad_outlined
                          : !item.isReady
                          ? Icons.hourglass_empty_rounded
                          : (item.mediaType ?? '').startsWith('image/')
                          ? Icons.image_outlined
                          : Icons.description_outlined,
                      size: widget.dense ? 16 : 20,
                      color: color,
                    ),
                  const SizedBox(width: 8),
                  Flexible(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          item.displayName,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: widget.dense ? 12 : 14,
                            color: color,
                            decoration: item.isReady
                                ? TextDecoration.underline
                                : item.isRemoved
                                ? TextDecoration.lineThrough
                                : null,
                            decorationColor: color,
                          ),
                        ),
                        if (item.isRemoved)
                          Text(
                            AppL10n.of(context).attachmentRemovedShort,
                            style: TextStyle(
                              fontSize: widget.dense ? 11 : 12,
                              color:
                                  color ?? Theme.of(context).colorScheme.error,
                            ),
                          ),
                      ],
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
