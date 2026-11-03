import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import '../l10n/generated/app_l10n.dart';
import 'attachment_policy.dart';
import 'document_viewer.dart';
import 'failures.dart';
import 'feedback.dart';
import 'file_upload_repository.dart';
import 'navigation.dart';
import 'uploads_scope.dart';

/// Shows [file] to the person who tapped it.
///
/// A photo opens in the app, and so does a PDF (2026-11-03): full screen,
/// with pinch to zoom, the page number, and "Share or open in another app"
/// for whoever wants it in Files, Books or a PDF reader
/// (document_viewer.dart). Anything else - Word, PowerPoint, Excel, CSV -
/// goes on with [shareDownloadedFile]: to the system share sheet, which on
/// iOS previews it and offers to keep it in Files, and on Android first to
/// an app that views its type (Docs, Slides, Sheets).
///
/// Nothing is written to a place the app keeps: the bytes are fetched on a
/// single-use grant and shown from memory or handed straight on (on Android
/// through the cache folder, which the system may clear and the next opened
/// file replaces).
typedef AttachmentPresenter = Future<void> Function(
  BuildContext context,
  DownloadedFile file,
);

Future<void> presentDownloadedFile(
  BuildContext context,
  DownloadedFile file, {
  PdfRendererBuilder pdfRenderer = pdfiumRenderer,
}) async {
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
  if (file.isPdf) {
    await presentPdfDocument(
      context,
      title: file.displayName,
      bytes: file.bytes,
      onShare: () => shareDownloadedFile(file),
      renderer: pdfRenderer,
    );
    return;
  }
  await shareDownloadedFile(file);
}

/// Hands [file] to another app: on Android one that views its type, when
/// the phone has one; otherwise, and always on iOS, the system share sheet.
Future<void> shareDownloadedFile(DownloadedFile file) async {
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
    AttachmentPolicy.xlsx => 'xlsx',
    AttachmentPolicy.csv => 'csv',
    AttachmentPolicy.doc => 'doc',
    AttachmentPolicy.xls => 'xls',
    AttachmentPolicy.ppt => 'ppt',
    _ => null,
  };
  return extension == null ? name : '$name.$extension';
}

/// The icon a stored file is shown with: a picture, a spreadsheet (Excel,
/// old or new, or CSV), or any other document.
IconData attachmentTypeIcon(String? mediaType) => switch (mediaType) {
  AttachmentPolicy.xlsx ||
  AttachmentPolicy.xls ||
  AttachmentPolicy.csv => Icons.table_chart_outlined,
  final type? when type.startsWith('image/') => Icons.image_outlined,
  _ => Icons.description_outlined,
};

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
    this.pdfRenderer = pdfiumRenderer,
    this.color,
    this.dense = false,
  });

  final List<StoredAttachment> attachments;

  /// Falls back to the app's [UploadsScope]. Null in both places means the
  /// build has nowhere to fetch from, and the rows are shown but inert.
  final FileUploadRepository? uploads;
  final AttachmentPresenter present;

  /// Draws a document's PDF preview; replaced in tests.
  final PdfRendererBuilder pdfRenderer;

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
      // A Word, PowerPoint or Excel file opens in the app through the PDF
      // preview the server made of it (DL-078); its share action still
      // hands on the original. Without a preview it opens as before.
      final preview = item.hasDocumentPreview && uploads is FilePreviewSource
          ? await (uploads as FilePreviewSource).downloadPreview(item.id)
          : null;
      if (!mounted) return;
      if (preview != null) {
        await presentPdfDocument(
          context,
          title: item.displayName,
          bytes: preview.bytes,
          renderer: widget.pdfRenderer,
          onShare: () => unawaited(_shareOriginal(uploads, item, failed)),
        );
        return;
      }
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

  Future<void> _shareOriginal(
    FileUploadRepository uploads,
    StoredAttachment item,
    String failed,
  ) async {
    final messenger = ScaffoldMessenger.of(context);
    try {
      await shareDownloadedFile(await uploads.download(item.id));
    } on Object {
      messenger.showMessage(failed);
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
                          : attachmentTypeIcon(item.mediaType),
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
