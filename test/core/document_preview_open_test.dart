import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:studafy/core/attachment_opener.dart';
import 'package:studafy/core/document_viewer.dart';
import 'package:studafy/core/file_upload_repository.dart';

import '../support/localized_app.dart';

/// A Word, PowerPoint or Excel attachment opens in the app through the PDF
/// preview the server made of it (DL-078), and as before without one.
void main() {
  final pdf = Uint8List.fromList('%PDF-1.7\n%%EOF\n'.codeUnits);
  final docx = Uint8List.fromList([0x50, 0x4b, 0x03, 0x04]);

  StoredAttachment attachment(String name, String? type) => StoredAttachment(
    id: 'f1',
    displayName: name,
    sizeBytes: 10,
    scanState: 'clean',
    mediaType: type,
  );

  Future<List<DownloadedFile>> open(
    WidgetTester tester,
    _Files files,
    StoredAttachment item,
    List<PdfRenderRequest> rendered,
  ) async {
    final presented = <DownloadedFile>[];
    await tester.pumpWidget(
      localizedApp(
        home: Scaffold(
          body: StoredAttachmentList(
            attachments: [item],
            uploads: files,
            present: (context, file) async => presented.add(file),
            pdfRenderer: (context, request) {
              rendered.add(request);
              return const SizedBox();
            },
          ),
        ),
      ),
    );
    await tester.tap(find.text(item.displayName));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 600));
    return presented;
  }

  testWidgets('a Word file opens its PDF preview in the app', (tester) async {
    final files = _Files(preview: pdf, original: docx);
    final rendered = <PdfRenderRequest>[];
    final presented = await open(
      tester,
      files,
      attachment(
        'Lesson.docx',
        'application/vnd.openxmlformats-officedocument.wordprocessingml.document',
      ),
      rendered,
    );
    expect(find.byType(DocumentViewerPage), findsOneWidget);
    expect(rendered.single.bytes, pdf);
    expect(presented, isEmpty);
    expect(files.originalDownloads, 0);
  });

  testWidgets('an old .ppt with no media type is recognised by its name', (
    tester,
  ) async {
    final files = _Files(preview: pdf, original: docx);
    await open(tester, files, attachment('Slides.PPT', null), []);
    expect(files.previewRequests, 1);
    expect(find.byType(DocumentViewerPage), findsOneWidget);
  });

  testWidgets('without a preview the file opens as before', (tester) async {
    final files = _Files(preview: null, original: docx);
    final presented = await open(
      tester,
      files,
      attachment('Sheet.xlsx', null),
      [],
    );
    expect(files.previewRequests, 1);
    expect(presented.single.bytes, docx);
    expect(find.byType(DocumentViewerPage), findsNothing);
  });

  testWidgets('a photo or PDF never asks for a preview', (tester) async {
    final files = _Files(preview: pdf, original: docx);
    await open(tester, files, attachment('Notes.pdf', 'application/pdf'), []);
    await open(tester, files, attachment('Board.jpg', 'image/jpeg'), []);
    expect(files.previewRequests, 0);
    expect(files.originalDownloads, 2);
  });
}

class _Files implements FileUploadRepository, FilePreviewSource {
  _Files({required this.preview, required this.original});

  final Uint8List? preview;
  final Uint8List original;
  int previewRequests = 0;
  int originalDownloads = 0;

  @override
  Future<DownloadedFile?> downloadPreview(String fileId) async {
    previewRequests += 1;
    final bytes = preview;
    return bytes == null
        ? null
        : DownloadedFile(
            displayName: 'Lesson.pdf',
            mediaType: 'application/pdf',
            bytes: bytes,
          );
  }

  @override
  Future<DownloadedFile> download(String fileId) async {
    originalDownloads += 1;
    return DownloadedFile(
      displayName: 'original',
      mediaType: 'application/octet-stream',
      bytes: original,
    );
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
