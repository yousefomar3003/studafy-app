import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:studafy/core/attachment_field.dart';
import 'package:studafy/core/file_upload_repository.dart';
import 'package:studafy/features/academic/domain/academic_repository.dart';
import 'package:studafy/features/academic/presentation/create_lesson_page.dart';
import 'package:studafy/features/academic/presentation/edit_lesson_sheet.dart';

import '../../support/academic_repository_fake.dart';
import '../../support/localized_app.dart';
import '../../support/system_back.dart';

/// Back, on Android or in the app, used to throw away a file a teacher had
/// just uploaded to a lesson, and a lesson half written. Now it asks - and
/// only when there is something to lose.
void main() {
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

  group('the Edit lesson sheet', () {
    const lesson = AcademicRecord(
      id: 'lesson-1',
      title: 'Cells',
      detail: 'What a cell is made of.',
      state: 'published',
      version: 3,
      classroomId: 'c1',
    );

    Future<void> open(WidgetTester tester) async {
      tall(tester);
      await tester.pumpWidget(
        localizedApp(
          home: Builder(
            builder: (context) => Scaffold(
              body: TextButton(
                onPressed: () => showEditLessonSheet(
                  context,
                  repository: _Content(),
                  lesson: lesson,
                  uploads: _Files(),
                  schoolId: 'school-1',
                  attachmentSource: (_, _) async => slides(),
                ),
                child: const Text('open'),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();
      expect(find.text('Edit lesson'), findsOneWidget);
    }

    testWidgets('closes at once when nothing was changed', (tester) async {
      await open(tester);

      await systemBack(tester);

      expect(find.text('Edit lesson'), findsNothing);
      expect(find.text('Discard changes?'), findsNothing);
    });

    testWidgets('asks before losing a file just uploaded', (tester) async {
      await open(tester);
      await tester.tap(find.text('Attach file'));
      await tester.pumpAndSettle();
      expect(find.text('slides.pdf'), findsOneWidget);

      await systemBack(tester);
      expect(find.text('Discard changes?'), findsOneWidget);
      await tester.tap(find.text('Keep editing'));
      await tester.pumpAndSettle();
      expect(find.text('slides.pdf'), findsOneWidget);

      await systemBack(tester);
      await tester.tap(find.text('Discard'));
      await tester.pumpAndSettle();
      expect(find.text('Edit lesson'), findsNothing);
    });

    testWidgets('a tap outside asks too, once the title is changed', (
      tester,
    ) async {
      await open(tester);
      await tester.enterText(
        find.widgetWithText(TextField, 'Cells'),
        'Cells and tissues',
      );
      await tester.pump();

      // Above the sheet: the scrim.
      await tester.tapAt(const Offset(600, 20));
      await tester.pumpAndSettle();

      expect(find.text('Discard changes?'), findsOneWidget);
    });
  });

  testWidgets('a new lesson half written is not lost to back', (tester) async {
    tall(tester);
    final exits = AppExits(tester);
    await tester.pumpWidget(
      localizedApp(
        home: Builder(
          builder: (context) => TextButton(
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute<void>(
                builder: (_) => CreateLessonPage(
                  repository: CreateWorkFake(),
                  classes: const [ClassOption(id: 'c1', name: 'Science')],
                  initialClassroomId: 'c1',
                ),
              ),
            ),
            child: const Text('open'),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.widgetWithText(TextField, 'Lesson title'),
      'Cells',
    );
    await tester.pump();

    await systemBack(tester);

    expect(find.text('Discard changes?'), findsOneWidget);
    expect(find.text('New lesson'), findsOneWidget);
    expect(exits.count, 0);
  });
}

class _Content implements AcademicContentRepository {
  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw UnimplementedError('${invocation.memberName} is not faked');
}

class _Files implements FileUploadRepository {
  var _count = 0;

  @override
  Future<QuarantinedFile> upload(FileUploadCommand command) async {
    _count++;
    return QuarantinedFile(
      id: 'file-$_count',
      uploadId: 'upload-$_count',
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
  }) async => 'resource-$fileId';
}
