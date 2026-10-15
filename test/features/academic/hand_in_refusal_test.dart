import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:studafy/core/attachment_field.dart';
import 'package:studafy/core/coursework_attachments.dart';
import 'package:studafy/core/file_upload_repository.dart';
import 'package:studafy/features/academic/domain/academic_repository.dart';
import 'package:studafy/features/academic/presentation/submission_history_view.dart';
import 'package:studafy/features/academic/presentation/submit_work_page.dart';

import '../../support/academic_repository_fake.dart';
import '../../support/localized_app.dart';

/// A hand-in with a file the scan refused is refused by name, and the file
/// is marked (2026-10-15). A file the scan removed after it was handed in
/// says so to the student and the teacher, instead of "being checked" until
/// it silently disappeared.
void main() {
  const removed = 'Removed by the safety check';
  const refusedText =
      'This file did not pass the safety check. Remove it, then save again.';

  void tall(WidgetTester tester) {
    tester.view.physicalSize = const Size(1200, 2600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
  }

  final attempt = SubmissionAttempt(
    id: 'at1',
    submittedAt: DateTime(2026, 10, 14, 18),
    current: true,
    answerText: 'My essay',
    attachments: const [
      StoredAttachment(
        id: 'kept',
        displayName: 'essay.pdf',
        sizeBytes: 10,
        scanState: 'clean',
        mediaType: 'application/pdf',
      ),
      StoredAttachment(
        id: 'gone',
        displayName: 'diagram.pdf',
        sizeBytes: 10,
        scanState: 'deleted',
        mediaType: 'application/pdf',
      ),
    ],
  );

  testWidgets(
    'a refused file is marked on the hand-in, and the work goes in without it',
    (tester) async {
      tall(tester);
      final fake = _Refusing([
        const CourseworkRefusal(
          CourseworkProblem.attachmentRefused,
          rows: {
            'attachmentFileIds.0': 'file_refused',
            'attachmentFileIds.1': 'file_refused',
          },
        ),
      ])..history = [attempt];
      await tester.pumpWidget(
        localizedApp(
          home: SubmitWorkPage(
            repository: fake,
            assignmentId: 'a1',
            assignmentTitle: 'Essay',
            schoolId: 'school-1',
            uploads: _Files(),
            attachmentSource: (_, _) async => PickedAttachment(
              displayName: 'photo-of-work.pdf',
              mediaType: 'application/pdf',
              bytes: Uint8List(16),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // The removed file is not offered to carry over, and the history says
      // what happened to it.
      expect(find.widgetWithText(CheckboxListTile, 'essay.pdf'), findsOne);
      expect(
        find.widgetWithText(CheckboxListTile, 'diagram.pdf'),
        findsNothing,
      );
      expect(find.text(removed), findsOne);

      await tester.enterText(find.byType(TextField), 'Again');
      await tester.tap(find.byIcon(Icons.attach_file_rounded));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Hand in again'));
      await tester.pumpAndSettle();

      expect(fake.sentFiles.single, ['kept', 'file-1']);
      expect(
        find.text(
          'A file or link was not accepted, so nothing was saved. Remove the '
          'ones marked, then save again.',
        ),
        findsOne,
      );
      // Both are marked: the carried-over one, unticked, and the new one.
      expect(find.text(refusedText), findsNWidgets(2));
      final kept = tester.widget<CheckboxListTile>(
        find.widgetWithText(CheckboxListTile, 'essay.pdf'),
      );
      expect(kept.value, isFalse);
      expect(kept.onChanged, isNull);

      await tester.tap(find.text('Hand in again'));
      await tester.pumpAndSettle();
      expect(fake.submitted.single.attachments, isEmpty);
    },
  );

  testWidgets('the teacher sees the removed file on the hand-in, as removed', (
    tester,
  ) async {
    final fake = SubmitFake()..history = [attempt];
    await tester.pumpWidget(
      localizedApp(
        home: SubmissionHistoryPage(
          repository: fake,
          assignmentId: 'a1',
          studentId: 's1',
          studentName: 'Omar',
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('diagram.pdf'), findsOne);
    expect(find.text(removed), findsOne);
    await tester.tap(find.text('diagram.pdf'));
    await tester.pump();
    expect(find.text('This file was removed by the safety check.'), findsOne);
    expect(
      find.text('This file is still being checked. Try again shortly.'),
      findsNothing,
    );
  });

  testWidgets('material shows a removed photo with the documents, as removed', (
    tester,
  ) async {
    await tester.pumpWidget(
      localizedApp(
        home: const Scaffold(
          body: AttachmentsView(
            attachments: [
              StoredAttachment(
                id: 'p1',
                displayName: 'board.jpg',
                sizeBytes: 10,
                scanState: 'rejected',
                mediaType: 'image/jpeg',
              ),
            ],
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('board.jpg'), findsOne);
    expect(find.text(removed), findsOne);
  });

  testWidgets('a teacher editing material sees which file was removed', (
    tester,
  ) async {
    await tester.pumpWidget(
      localizedApp(
        home: const Scaffold(
          body: AttachmentsEditor(
            purpose: FilePurpose.assignmentMaterial,
            schoolId: 'school-1',
            existingAttachments: [
              StoredAttachment(
                id: 'w1',
                displayName: 'worksheet.pdf',
                sizeBytes: 10,
                scanState: 'error',
                mediaType: 'application/pdf',
              ),
            ],
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('worksheet.pdf'), findsOne);
    expect(find.text(removed), findsOne);
    expect(find.text('Remove'), findsOne);
  });
}

/// Throws each of [failures] in turn, then hands in.
class _Refusing extends SubmitFake {
  _Refusing(this.failures);

  final List<Object> failures;
  final sentFiles = <List<String>>[];

  @override
  Future<void> submitAssignment(
    String assignmentId,
    String answer, {
    List<String> attachmentFileIds = const [],
    String? studentId,
  }) async {
    sentFiles.add(attachmentFileIds);
    if (failures.isNotEmpty) throw failures.removeAt(0);
    await super.submitAssignment(
      assignmentId,
      answer,
      attachmentFileIds: attachmentFileIds,
      studentId: studentId,
    );
  }
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
  }) => throw UnimplementedError();
}
