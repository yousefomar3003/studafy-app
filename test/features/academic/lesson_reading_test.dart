import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:studafy/core/attachment_policy.dart';
import 'package:studafy/features/academic/domain/academic_repository.dart';
import 'package:studafy/features/academic/presentation/lesson_reading_sheet.dart';

import '../../support/localized_app.dart';

/// How far a lesson's files and links have been read for the AI helper
/// (ADR-0037), as a teacher sees it. Who may see and retry is the server's
/// decision (supabase/tests/grounded_material.sql).
class _Reading implements LessonReadingRepository {
  final retried = <String>[];
  var sources = const [
    LessonReadingSource(
      id: 'f1',
      isLink: false,
      name: 'Leaf.pdf',
      state: ReadingState.ready,
      pages: 12,
    ),
    LessonReadingSource(
      id: 'f2',
      isLink: false,
      name: 'Scan.pdf',
      state: ReadingState.ready,
      pages: 80,
      skippedPages: 20,
      reason: 'partly_read',
    ),
    LessonReadingSource(
      id: 'l1',
      isLink: true,
      name: 'Video',
      state: ReadingState.unsupported,
      reason: 'link_video',
    ),
    LessonReadingSource(
      id: 'f3',
      isLink: false,
      name: 'Board.png',
      state: ReadingState.failed,
      reason: 'processing_failed',
    ),
    LessonReadingSource(
      id: 'f4',
      isLink: false,
      name: 'Slides.pptx',
      state: ReadingState.processing,
    ),
  ];

  @override
  Future<List<LessonReadingSource>> lessonReading(String resourceId) async =>
      sources;

  @override
  Future<List<LessonReadingSource>> retryLessonReading(
    String resourceId,
    String sourceId,
  ) async {
    retried.add(sourceId);
    sources = [
      for (final source in sources)
        source.id == sourceId
            ? LessonReadingSource(
                id: source.id,
                isLink: source.isLink,
                name: source.name,
                state: ReadingState.processing,
              )
            : source,
    ];
    return sources;
  }
}

void main() {
  Widget host(_Reading repository, {bool canRetry = true}) => localizedApp(
    home: Builder(
      builder: (context) => Scaffold(
        body: TextButton(
          onPressed: () => showLessonReadingSheet(
            context,
            repository: repository,
            resourceId: 'lesson-1',
            title: 'Photosynthesis',
            canRetry: canRetry,
          ),
          child: const Text('open'),
        ),
      ),
    ),
  );

  testWidgets('each file and link says how far it has been read', (
    tester,
  ) async {
    await tester.pumpWidget(host(_Reading()));
    await tester.tap(find.text('open'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    expect(find.text('Ready for the AI Tutor'), findsOne);
    expect(find.text('Partly read - some pages were not read'), findsOne);
    expect(find.text("Can't be read: it's a video"), findsOne);
    expect(find.text("Can't be read: it couldn't be read"), findsOne);
    expect(find.text('Reading…'), findsOne);
  });

  testWidgets('a teacher asks for one to be read again', (tester) async {
    final repository = _Reading();
    await tester.pumpWidget(host(repository));
    await tester.tap(find.text('open'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    await tester.tap(find.text('Read again').last);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    expect(repository.retried, ['f3']);
    expect(find.text('Reading…'), findsNWidgets(2));
  });

  testWidgets('without the right to retry there is no button', (tester) async {
    await tester.pumpWidget(host(_Reading(), canRetry: false));
    await tester.tap(find.text('open'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.text('Read again'), findsNothing);
  });

  test('Word and PowerPoint go on lessons, work and hand-ins', () {
    for (final policy in [
      AttachmentPolicy.lessonResource,
      AttachmentPolicy.assignmentMaterial,
      AttachmentPolicy.assignmentSubmission,
    ]) {
      expect(
        policy.refuse(mediaType: AttachmentPolicy.docx, sizeBytes: 100),
        isNull,
      );
      expect(
        policy.refuse(mediaType: AttachmentPolicy.pptx, sizeBytes: 100),
        isNull,
      );
      expect(policy.pickerExtensions, containsAll(['docx', 'pptx']));
    }
    expect(
      AttachmentPolicy.lessonResource.refuse(
        mediaType: 'application/msword',
        sizeBytes: 100,
      ),
      AttachmentRefusal.mediaType,
    );
  });
}
