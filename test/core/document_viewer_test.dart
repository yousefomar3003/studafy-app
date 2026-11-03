import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:studafy/core/attachment_opener.dart';
import 'package:studafy/core/document_viewer.dart';
import 'package:studafy/core/file_upload_repository.dart';

import '../support/localized_app.dart';

/// A PDF opens inside the app (2026-11-03). PDFium cannot run in a widget
/// test, so the renderer is a fake that reports what a real one would.
void main() {
  final pdfBytes = Uint8List.fromList('%PDF-1.7\n%fake\n'.codeUnits);

  /// Draws a placeholder and hands the test the request, so it can play
  /// the renderer's part: pages loaded, page turned, drawing failed.
  PdfRendererBuilder fakeRenderer(List<PdfRenderRequest> requests) =>
      (context, request) {
        requests.add(request);
        return const ColoredBox(key: ValueKey('fake-pdf'), color: Colors.white);
      };

  Future<void> openFrom(
    WidgetTester tester,
    DownloadedFile file, {
    required PdfRendererBuilder renderer,
    Locale locale = const Locale('en'),
  }) async {
    await tester.pumpWidget(
      localizedApp(
        locale: locale,
        home: Builder(
          builder: (context) => TextButton(
            onPressed: () =>
                presentDownloadedFile(context, file, pdfRenderer: renderer),
            child: const Text('open'),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    // The spinner turns until the renderer reports, so the route's
    // animation is waited out rather than settled.
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 600));
  }

  testWidgets('a PDF attachment opens in the app, with a share action', (
    tester,
  ) async {
    final requests = <PdfRenderRequest>[];
    await openFrom(
      tester,
      DownloadedFile(
        displayName: 'Worksheet.pdf',
        mediaType: 'application/pdf',
        bytes: pdfBytes,
      ),
      renderer: fakeRenderer(requests),
    );

    expect(find.byType(DocumentViewerPage), findsOneWidget);
    expect(find.byKey(const ValueKey('fake-pdf')), findsOneWidget);
    expect(find.text('Worksheet.pdf'), findsOneWidget);
    expect(find.byTooltip('Share or open in another app'), findsOneWidget);
    expect(find.byType(CloseButton), findsOneWidget);
    // Still opening: a spinner, and no page label yet.
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    expect(find.byKey(const ValueKey('document-viewer-page')), findsNothing);
    expect(requests.single.bytes, pdfBytes);

    requests.single.onLoaded(12);
    await tester.pump();
    expect(find.byType(CircularProgressIndicator), findsNothing);
    expect(find.text('1 / 12'), findsOneWidget);
    expect(find.bySemanticsLabel('Page 1 of 12'), findsOneWidget);

    requests.single.onPageChanged(3);
    await tester.pump();
    expect(find.text('3 / 12'), findsOneWidget);
    // A page turn does not build the document again.
    expect(requests, hasLength(1));

    await tester.tap(find.byType(CloseButton));
    await tester.pumpAndSettle();
    expect(find.byType(DocumentViewerPage), findsNothing);
  });

  testWidgets('bytes that are not a PDF show the error, never the renderer', (
    tester,
  ) async {
    final requests = <PdfRenderRequest>[];
    var shared = 0;
    await tester.pumpWidget(
      localizedApp(
        home: DocumentViewerPage(
          title: 'Broken.pdf',
          bytes: Uint8List.fromList('<html>not a pdf</html>'.codeUnits),
          onShare: () => shared++,
          renderer: fakeRenderer(requests),
        ),
      ),
    );

    expect(requests, isEmpty);
    expect(find.text('This file could not be shown'), findsOneWidget);
    expect(find.text('You can still open it in another app.'), findsOneWidget);
    await tester.tap(find.text('Open in another app'));
    await tester.tap(find.byTooltip('Share or open in another app'));
    expect(shared, 2);
  });

  testWidgets('a renderer that fails shows the error', (tester) async {
    final requests = <PdfRenderRequest>[];
    await tester.pumpWidget(
      localizedApp(
        home: DocumentViewerPage(
          title: 'Locked.pdf',
          bytes: pdfBytes,
          onShare: () {},
          renderer: fakeRenderer(requests),
        ),
      ),
    );
    requests.single.onFailed(StateError('password'));
    await tester.pump();

    expect(find.byKey(const ValueKey('fake-pdf')), findsNothing);
    expect(find.text('This file could not be shown'), findsOneWidget);
    expect(find.text('Open in another app'), findsOneWidget);
  });

  testWidgets('without a share action the error offers none', (tester) async {
    await tester.pumpWidget(
      localizedApp(
        home: DocumentViewerPage(
          title: 'Empty',
          bytes: Uint8List(0),
          renderer: fakeRenderer([]),
        ),
      ),
    );
    expect(find.text('This file could not be shown'), findsOneWidget);
    expect(find.text('Open in another app'), findsNothing);
    expect(find.byTooltip('Share or open in another app'), findsNothing);
  });

  testWidgets('in Arabic the page reads right to left', (tester) async {
    final requests = <PdfRenderRequest>[];
    await openFrom(
      tester,
      DownloadedFile(
        displayName: 'ورقة عمل',
        mediaType: 'application/pdf',
        bytes: pdfBytes,
      ),
      renderer: fakeRenderer(requests),
      locale: const Locale('ar'),
    );
    requests.single
      ..onLoaded(5)
      ..onPageChanged(2);
    await tester.pump();

    final label = find.byKey(const ValueKey('document-viewer-page'));
    expect(tester.widget<Text>(label).data, '2 من 5');
    expect(directionOf(tester, label), TextDirection.rtl);
    expect(find.byTooltip('مشاركة أو فتح في تطبيق آخر'), findsOneWidget);
  });

  test('looksLikePdf finds the header within the first kilobyte', () {
    expect(looksLikePdf(pdfBytes), isTrue);
    expect(
      looksLikePdf(Uint8List.fromList([...List.filled(40, 0x20), ...pdfBytes])),
      isTrue,
    );
    expect(looksLikePdf(Uint8List.fromList('PK\x03\x04'.codeUnits)), isFalse);
    expect(looksLikePdf(Uint8List(0)), isFalse);
  });

  test('a PDF is shown in the app; other documents are not images', () {
    final pdf = DownloadedFile(
      displayName: 'a',
      mediaType: 'application/pdf',
      bytes: pdfBytes,
    );
    expect(pdf.isPdf, isTrue);
    expect(pdf.isImage, isFalse);
    expect(
      DownloadedFile(
        displayName: 'b',
        mediaType: 'text/csv',
        bytes: Uint8List(1),
      ).isPdf,
      isFalse,
    );
  });
}
