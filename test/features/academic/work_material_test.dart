import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:studafy/core/attachment_field.dart';
import 'package:studafy/core/attachment_opener.dart';
import 'package:studafy/core/file_upload_repository.dart';
import 'package:studafy/features/academic/domain/academic_repository.dart';
import 'package:studafy/features/academic/presentation/create_assignment_page.dart';
import 'package:studafy/features/academic/presentation/submit_work_page.dart';

import '../../support/academic_repository_fake.dart';
import '../../support/localized_app.dart';

/// Material a teacher attaches to the work they set, and the student opening
/// it. The server's half - who may upload, bind and open - is proven against
/// real SQL in apps/api/test/academic; this is what the screens do with it.
void main() {
  const classes = [
    ClassOption(id: 'c1', name: 'Grade 7 Science'),
    ClassOption(id: 'c2', name: 'Grade 8 Physics'),
  ];

  PickedAttachment sheet() => PickedAttachment(
    displayName: 'worksheet.pdf',
    mediaType: 'application/pdf',
    bytes: Uint8List(1024),
  );

  Widget createPage(CreateWorkFake fake, _Files files) => localizedApp(
    home: CreateAssignmentPage(
      repository: fake,
      classes: classes,
      initialClassroomId: 'c1',
      schoolId: 'school-1',
      uploads: files,
      attachmentSource: (_, _) async => sheet(),
    ),
  );

  /// Tall enough that the whole form is built; a ListView leaves off-screen
  /// rows unbuilt, and the Create button is the last one.
  void tall(WidgetTester tester) {
    tester.view.physicalSize = const Size(1200, 2600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
  }

  Future<void> fillTitleAndDue(WidgetTester tester) async {
    await tester.enterText(find.byType(TextField).first, 'Worksheet');
    await tester.tap(find.text('Pick a due date'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('OK'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('OK'));
    await tester.pumpAndSettle();
  }

  testWidgets('a teacher attaches a worksheet to the work they set', (
    tester,
  ) async {
    tall(tester);
    final fake = CreateWorkFake();
    final files = _Files();
    await tester.pumpWidget(createPage(fake, files));
    await tester.pumpAndSettle();

    await fillTitleAndDue(tester);
    await tester.tap(find.text('Attach file'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Create assignment'));
    await tester.pumpAndSettle();

    // Uploaded for the class being written for, since the work does not
    // exist yet; the server binds it when it does.
    final command = files.uploads.single;
    expect(command.purpose, FilePurpose.assignmentMaterial);
    expect(command.classroomId, 'c1');
    expect(command.assignmentId, isNull);
    expect(fake.assignments.single.attachmentFileIds, ['file-1']);
    expect(fake.assignments.single.publish, isTrue);
  });

  testWidgets('changing class starts the attachments over', (tester) async {
    // Material is uploaded for one class and refused for another, so keeping
    // it across a class change would only produce a failed create.
    tall(tester);
    final fake = CreateWorkFake();
    final files = _Files();
    await tester.pumpWidget(createPage(fake, files));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Attach file'));
    await tester.pumpAndSettle();
    expect(find.text('worksheet.pdf'), findsOne);

    await tester.tap(find.text('Grade 7 Science'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Grade 8 Physics').last);
    await tester.pumpAndSettle();

    expect(find.text('worksheet.pdf'), findsNothing);
    await fillTitleAndDue(tester);
    await tester.tap(find.text('Create assignment'));
    await tester.pumpAndSettle();
    expect(fake.assignments.single.classroomId, 'c2');
    expect(fake.assignments.single.attachmentFileIds, isEmpty);
  });

  testWidgets('graded work carries its material too', (tester) async {
    tall(tester);
    final fake = CreateWorkFake();
    await tester.pumpWidget(createPage(fake, _Files()));
    await tester.pumpAndSettle();

    await fillTitleAndDue(tester);
    await tester.tap(find.byType(Switch));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Attach file'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Create assignment'));
    await tester.pumpAndSettle();

    // Graded work is an assignment, and its material is the assignment's.
    expect(fake.assignments.single.attachmentFileIds, ['file-1']);
    expect(fake.assignments.single.maximumScore, isNotNull);
    expect(fake.assessments, isEmpty);
  });

  testWidgets('the hand-in screen shows what the teacher attached', (
    tester,
  ) async {
    await tester.pumpWidget(
      localizedApp(
        home: SubmitWorkPage(
          repository: SubmitFake(),
          assignmentId: 'a1',
          assignmentTitle: 'Worksheet',
          instructions: 'Answer every question on the sheet.',
          uploads: _Files(),
          material: const [
            StoredAttachment(
              id: 'f1',
              displayName: 'worksheet.pdf',
              sizeBytes: 1024,
              scanState: 'clean',
              mediaType: 'application/pdf',
            ),
          ],
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('From your teacher'), findsOne);
    expect(find.text('worksheet.pdf'), findsOne);
    expect(find.text('Answer every question on the sheet.'), findsOne);
  });

  group('opening an attachment', () {
    Widget list(
      _Files files,
      List<StoredAttachment> items,
      AttachmentPresenter present,
    ) => localizedApp(
      home: Scaffold(
        body: StoredAttachmentList(
          attachments: items,
          uploads: files,
          present: present,
        ),
      ),
    );

    testWidgets('a clean file is fetched and shown', (tester) async {
      final files = _Files();
      final shown = <DownloadedFile>[];
      await tester.pumpWidget(
        list(files, const [
          StoredAttachment(
            id: 'f1',
            displayName: 'worksheet.pdf',
            sizeBytes: 1024,
            scanState: 'clean',
          ),
        ], (_, file) async => shown.add(file)),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('worksheet.pdf'));
      await tester.pumpAndSettle();

      expect(files.downloads, ['f1']);
      expect(shown.single.displayName, 'worksheet.pdf');
    });

    testWidgets('a file still being checked is not fetched', (tester) async {
      final files = _Files();
      await tester.pumpWidget(
        list(files, const [
          StoredAttachment(
            id: 'f1',
            displayName: 'worksheet.pdf',
            sizeBytes: 1024,
            scanState: 'quarantined',
          ),
        ], (_, _) async {}),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('worksheet.pdf'));
      await tester.pumpAndSettle();

      expect(files.downloads, isEmpty);
      expect(find.textContaining('still being checked'), findsOne);
    });

    testWidgets('a refusal says it could not be opened', (tester) async {
      final files = _Files(refuse: true);
      await tester.pumpWidget(
        list(files, const [
          StoredAttachment(
            id: 'f1',
            displayName: 'worksheet.pdf',
            sizeBytes: 1024,
            scanState: 'clean',
          ),
        ], (_, _) async {}),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('worksheet.pdf'));
      await tester.pumpAndSettle();

      expect(find.textContaining('could not be opened'), findsOne);
    });

    testWidgets('nothing attached renders nothing', (tester) async {
      await tester.pumpWidget(list(_Files(), const [], (_, _) async {}));
      expect(find.byType(InkWell), findsNothing);
    });
  });
}

class _Files implements FileUploadRepository {
  _Files({this.refuse = false});

  final bool refuse;
  final uploads = <FileUploadCommand>[];
  final downloads = <String>[];

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
  Future<DownloadedFile> download(String fileId) async {
    if (refuse) throw StateError('not allowed');
    downloads.add(fileId);
    return DownloadedFile(
      displayName: 'worksheet.pdf',
      mediaType: 'application/pdf',
      bytes: Uint8List(8),
    );
  }

  @override
  Future<String> publishToClass({
    required String fileId,
    required FileAudience audience,
  }) async => throw UnimplementedError();
}
