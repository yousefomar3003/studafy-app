import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:studafy/core/attachment_field.dart';
import 'package:studafy/core/file_upload_repository.dart';
import 'package:studafy/features/academic/domain/academic_repository.dart';
import 'package:studafy/features/academic/presentation/create_exam_page.dart';
import 'package:studafy/features/academic/presentation/create_lesson_page.dart';

import '../../support/academic_repository_fake.dart';
import '../../support/localized_app.dart';

/// A teacher files a lesson with its slides, and an exam with its paper.
/// Reported missing: there was nowhere to upload either.
void main() {
  const classes = [
    ClassOption(id: 'c1', name: 'Grade 7 Science'),
    ClassOption(id: 'c2', name: 'Grade 8 Physics'),
  ];

  PickedAttachment slides() => PickedAttachment(
    displayName: 'slides.pdf',
    mediaType: 'application/pdf',
    bytes: Uint8List(1024),
  );

  void tall(WidgetTester tester) {
    tester.view.physicalSize = const Size(1200, 2600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
  }

  Widget lessonPage(CreateWorkFake fake, _Files files) => localizedApp(
    home: CreateLessonPage(
      repository: fake,
      classes: classes,
      initialClassroomId: 'c1',
      schoolId: 'school-1',
      uploads: files,
      attachmentSource: (_, _) async => slides(),
    ),
  );

  testWidgets('a lesson is filed with its files, for the audience chosen', (
    tester,
  ) async {
    tall(tester);
    final fake = CreateWorkFake();
    final files = _Files();
    await tester.pumpWidget(lessonPage(fake, files));
    await tester.pumpAndSettle();

    await tester.enterText(
      find.widgetWithText(TextField, 'Lesson title'),
      'Cells',
    );
    await tester.tap(find.text('Attach file'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Students'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'Add lesson'));
    await tester.pumpAndSettle();

    final upload = files.uploads.single;
    expect(upload.purpose, FilePurpose.lessonResource);
    expect(upload.classroomId, 'c1');
    expect(fake.lessons.single.title, 'Cells');
    expect(fake.lessons.single.audience, 'students');
    // Published, not left as a draft the class never sees - the bug that
    // kept a teacher's lesson from reaching students and parents.
    expect(fake.lessons.single.publish, isTrue);
    // The file is the lesson's own, bound with it - not separate material.
    expect(fake.lessons.single.attachmentFileIds, ['file-1']);
    expect(files.published, isEmpty);
  });

  testWidgets('a lesson needs notes or a file', (tester) async {
    tall(tester);
    final fake = CreateWorkFake();
    await tester.pumpWidget(lessonPage(fake, _Files()));
    await tester.pumpAndSettle();

    await tester.enterText(
      find.widgetWithText(TextField, 'Lesson title'),
      'Empty',
    );
    await tester.tap(find.widgetWithText(FilledButton, 'Add lesson'));
    await tester.pumpAndSettle();

    expect(fake.lessons, isEmpty);
    expect(find.text('Write some notes or attach a file.'), findsOne);
  });

  testWidgets('an exam carries its paper', (tester) async {
    tall(tester);
    final fake = CreateWorkFake();
    final files = _Files();
    await tester.pumpWidget(
      localizedApp(
        home: CreateExamPage(
          repository: fake,
          classes: classes,
          initialClassroomId: 'c2',
          schoolId: 'school-1',
          uploads: files,
          attachmentSource: (_, _) async => slides(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField).first, 'Forces test');
    await tester.tap(find.text('Attach file'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'Create exam'));
    await tester.pumpAndSettle();

    final upload = files.uploads.single;
    expect(upload.purpose, FilePurpose.assignmentMaterial);
    expect(upload.classroomId, 'c2');
    expect(fake.assessments.single.attachmentFileIds, ['file-1']);
  });
}

class _Files implements FileUploadRepository {
  final uploads = <FileUploadCommand>[];
  final published = <(String, FileAudience)>[];

  @override
  Future<QuarantinedFile> upload(FileUploadCommand command) async {
    uploads.add(command);
    return QuarantinedFile(
      id: 'file-${uploads.length}',
      uploadId: 'upload-${uploads.length}',
      displayName: command.displayName,
      sizeBytes: command.bytes.length,
      scanState: 'clean',
    );
  }

  @override
  Future<DownloadedFile> download(String fileId) => throw UnimplementedError();

  @override
  Future<String> publishToClass({
    required String fileId,
    required FileAudience audience,
  }) async {
    published.add((fileId, audience));
    return 'resource-$fileId';
  }
}
