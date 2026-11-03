import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:pdfrx/pdfrx.dart';

import '../l10n/generated/app_l10n.dart';
import 'navigation.dart';
import 'user_content_text.dart';

/// Opens a PDF inside the app, full screen (2026-11-03).
///
/// Used for a PDF someone attached, on iOS and Android alike, and meant for
/// any document the server can turn into a PDF preview (a Word, PowerPoint
/// or Excel file) - the caller fetches the bytes, this only shows them.
/// The page scrolls and pinches to zoom, says which page is showing, and
/// offers [onShare] ("Share or open in another app") in its app bar and
/// under its error, so a file the viewer cannot draw is still one tap from
/// another app.
///
/// The bytes stay in memory: nothing is written to disk to show them.
Future<void> presentPdfDocument(
  BuildContext context, {
  required String title,
  required Uint8List bytes,
  VoidCallback? onShare,
  PdfRendererBuilder renderer = pdfiumRenderer,
}) => Navigator.of(context).pushOnce<void>(
  MaterialPageRoute<void>(
    builder: (_) => DocumentViewerPage(
      title: title,
      bytes: bytes,
      onShare: onShare,
      renderer: renderer,
    ),
  ),
);

/// What a renderer is given: the document, and where to report how it went.
@immutable
class PdfRenderRequest {
  const PdfRenderRequest({
    required this.bytes,
    required this.sourceName,
    required this.onLoaded,
    required this.onPageChanged,
    required this.onFailed,
  });

  final Uint8List bytes;

  /// Identifies this document to the renderer's caches.
  final String sourceName;

  /// The document opened and has this many pages.
  final ValueChanged<int> onLoaded;

  /// The page now mostly on screen, counted from 1.
  final ValueChanged<int> onPageChanged;

  /// The document could not be opened or drawn.
  final ValueChanged<Object> onFailed;
}

/// Draws a PDF. Injected so a widget test never loads PDFium.
typedef PdfRendererBuilder = Widget Function(
  BuildContext context,
  PdfRenderRequest request,
);

/// The real renderer: pdfrx, which draws with PDFium on both platforms.
///
/// Links inside the document are not tappable: a PDF from anyone in a class
/// should not be able to open a web page from inside the app.
Widget pdfiumRenderer(BuildContext context, PdfRenderRequest request) {
  void report(VoidCallback callback) =>
      WidgetsBinding.instance.addPostFrameCallback((_) => callback());
  return PdfViewer.data(
    request.bytes,
    sourceName: request.sourceName,
    // Attachments are at most 25 MB: read them into PDFium in one go
    // rather than in pieces.
    maxSizeToCacheOnMemory: request.bytes.length + 1,
    params: PdfViewerParams(
      backgroundColor: Theme.of(context).colorScheme.surfaceContainerHighest,
      onViewerReady: (document, _) => request.onLoaded(document.pages.length),
      onPageChanged: (page) {
        if (page != null) request.onPageChanged(page);
      },
      // The page shows its own spinner and error; pdfrx's are hidden.
      loadingBannerBuilder: (_, _, _) => const SizedBox.shrink(),
      errorBannerBuilder: (_, error, _, _) {
        report(() => request.onFailed(error));
        return const SizedBox.shrink();
      },
    ),
  );
}

/// True when [bytes] start like a PDF: `%PDF-` within the first kilobyte,
/// where readers look for it.
bool looksLikePdf(Uint8List bytes) {
  const marker = [0x25, 0x50, 0x44, 0x46, 0x2d]; // %PDF-
  final limit = bytes.length < 1024 ? bytes.length : 1024;
  for (var at = 0; at + marker.length <= limit; at++) {
    var match = true;
    for (var i = 0; i < marker.length; i++) {
      if (bytes[at + i] != marker[i]) {
        match = false;
        break;
      }
    }
    if (match) return true;
  }
  return false;
}

class DocumentViewerPage extends StatefulWidget {
  const DocumentViewerPage({
    super.key,
    required this.title,
    required this.bytes,
    this.onShare,
    this.renderer = pdfiumRenderer,
  });

  final String title;
  final Uint8List bytes;
  final VoidCallback? onShare;
  final PdfRendererBuilder renderer;

  @override
  State<DocumentViewerPage> createState() => _DocumentViewerPageState();
}

class _DocumentViewerPageState extends State<DocumentViewerPage> {
  late bool _failed = !looksLikePdf(widget.bytes);
  int _pageCount = 0;
  int _page = 1;

  /// Built once: a new viewer on every page change would lay the whole
  /// document out again.
  Widget? _document;
  late final PdfRenderRequest _request = PdfRenderRequest(
    bytes: widget.bytes,
    sourceName:
        'studafy-document:${identityHashCode(widget.bytes)}:'
        '${widget.bytes.length}',
    onLoaded: (count) => _update(() {
      _pageCount = count;
      if (count == 0) _failed = true;
    }),
    onPageChanged: (page) => _update(() => _page = page),
    onFailed: (_) => _update(() => _failed = true),
  );

  /// Applies [change] now, or after the frame when a renderer reports
  /// while the tree is being built.
  void _update(VoidCallback change) {
    if (!mounted) return;
    if (SchedulerBinding.instance.schedulerPhase ==
        SchedulerPhase.persistentCallbacks) {
      SchedulerBinding.instance.addPostFrameCallback((_) {
        if (mounted) setState(change);
      });
      return;
    }
    setState(change);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppL10n.of(context);
    final onShare = widget.onShare;
    final loading = !_failed && _pageCount == 0;
    return Scaffold(
      appBar: AppBar(
        leading: const CloseButton(),
        title: UserContentText(
          widget.title,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        actions: [
          if (onShare != null)
            IconButton(
              key: const ValueKey('document-viewer-share'),
              icon: Icon(Icons.adaptive.share),
              tooltip: l10n.viewerShareOrOpen,
              onPressed: onShare,
            ),
        ],
      ),
      body: _failed
          ? _ViewerError(onShare: onShare)
          : Stack(
              children: [
                Positioned.fill(
                  child: _document ??= widget.renderer(context, _request),
                ),
                if (loading)
                  Center(
                    child: Semantics(
                      label: l10n.viewerLoading,
                      child: const CircularProgressIndicator(),
                    ),
                  ),
                if (_pageCount > 0)
                  PositionedDirectional(
                    start: 0,
                    end: 0,
                    bottom: 16,
                    child: SafeArea(
                      top: false,
                      child: Center(
                        child: _PageLabel(
                          text: l10n.viewerPageIndicator(_page, _pageCount),
                          spoken: l10n.viewerPageOf(_page, _pageCount),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
    );
  }
}

class _PageLabel extends StatelessWidget {
  const _PageLabel({required this.text, required this.spoken});

  final String text;
  final String spoken;

  @override
  Widget build(BuildContext context) => Semantics(
    label: spoken,
    excludeSemantics: true,
    child: IgnorePointer(
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: Colors.black.withValues(alpha: .66),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          child: Text(
            text,
            key: const ValueKey('document-viewer-page'),
            style: const TextStyle(
              color: Colors.white,
              fontSize: 13,
              fontWeight: FontWeight.w600,
              fontFeatures: [FontFeature.tabularFigures()],
            ),
          ),
        ),
      ),
    ),
  );
}

class _ViewerError extends StatelessWidget {
  const _ViewerError({required this.onShare});

  final VoidCallback? onShare;

  @override
  Widget build(BuildContext context) {
    final l10n = AppL10n.of(context);
    final theme = Theme.of(context);
    final onShare = this.onShare;
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.insert_drive_file_outlined,
              size: 48,
              color: theme.colorScheme.onSurfaceVariant,
            ),
            const SizedBox(height: 16),
            Text(
              l10n.viewerCouldNotShow,
              textAlign: TextAlign.center,
              style: theme.textTheme.titleMedium,
            ),
            if (onShare != null) ...[
              const SizedBox(height: 8),
              Text(
                l10n.viewerCouldNotShowHint,
                textAlign: TextAlign.center,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 20),
              FilledButton.icon(
                onPressed: onShare,
                icon: const Icon(Icons.open_in_new),
                label: Text(l10n.viewerOpenElsewhere),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
