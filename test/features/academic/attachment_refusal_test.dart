import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:studafy/core/attachment_field.dart';
import 'package:studafy/core/file_upload_repository.dart';
import 'package:studafy/core/studafy_domain.dart';
import 'package:studafy/data/contracts/v1_client.generated.dart';
import 'package:studafy/data/contracts/v1_http_transport.dart';
import 'package:studafy/features/academic/data/api_academic_repository.dart';
import 'package:studafy/features/academic/domain/academic_repository.dart';
import 'package:studafy/features/academic/presentation/create_assignment_page.dart';
import 'package:studafy/features/academic/presentation/create_lesson_page.dart';

import '../../support/academic_repository_fake.dart';
import '../../support/localized_app.dart';

/// A file or link the server would not attach is named, and the teacher is
/// told what to do (launch plan 2.8). On the test copy a teacher was told
/// only "The lesson could not be added. Please try again." four times while
/// the scanner refused their PDFs; every retry failed the same way.
void main() {
  const classes = [ClassOption(id: 'c1', name: 'Grade 7 Science')];
  const refusedText =
      'A file or link was not accepted, so nothing was saved. Remove the '
      'ones marked, then save again.';

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

  Widget lessonPage(AcademicRepository repository, {Locale? locale}) =>
      localizedApp(
        locale: locale,
        home: CreateLessonPage(
          repository: repository,
          classes: classes,
          initialClassroomId: 'c1',
          schoolId: 'school-1',
          uploads: _Files(),
          attachmentSource: (_, _) async => slides(),
        ),
      );

  Future<void> fillLessonWithTwoFiles(WidgetTester tester) async {
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).first, 'Cells');
    await tester.tap(find.byIcon(Icons.attach_file_rounded));
    await tester.pumpAndSettle();
    await tester.tap(find.byIcon(Icons.attach_file_rounded));
    await tester.pumpAndSettle();
  }

  testWidgets(
    'a file the scan refused is named on the lesson, and the lesson saves '
    'once it is removed',
    (tester) async {
      tall(tester);
      final repository = _RefusingWork([
        const CourseworkRefusal(
          CourseworkProblem.attachmentRefused,
          rows: {'attachmentFileIds.1': 'file_refused'},
        ),
      ]);
      await tester.pumpWidget(lessonPage(repository));
      await fillLessonWithTwoFiles(tester);

      await tester.tap(find.widgetWithText(FilledButton, 'Add lesson'));
      await tester.pumpAndSettle();

      expect(repository.lessonAttempts.single.attachmentFileIds, [
        'file-1',
        'file-2',
      ]);
      expect(find.text(refusedText), findsOne);
      // The second file, not the first, says why and what to do.
      expect(
        find.text(
          'This file did not pass the safety check. Remove it, then save '
          'again.',
        ),
        findsOne,
      );
      expect(find.text('Ready'), findsOne);
      expect(
        find.text('The lesson could not be added. Please try again.'),
        findsNothing,
      );
      // No "try again" on the refused file: the same bytes would be refused.
      expect(find.text('Retry'), findsNothing);

      // Saving again with it still there is stopped on the device.
      await tester.tap(find.widgetWithText(FilledButton, 'Add lesson'));
      await tester.pumpAndSettle();
      expect(repository.lessonAttempts, hasLength(1));

      await tester.tap(find.byIcon(Icons.close_rounded).at(1));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(FilledButton, 'Add lesson'));
      await tester.pumpAndSettle();

      expect(repository.lessons.single.attachmentFileIds, ['file-1']);
    },
  );

  testWidgets('every other failure keeps the general message', (tester) async {
    tall(tester);
    final repository = _RefusingWork([StateError('offline')]);
    await tester.pumpWidget(lessonPage(repository));
    await fillLessonWithTwoFiles(tester);

    await tester.tap(find.widgetWithText(FilledButton, 'Add lesson'));
    await tester.pumpAndSettle();

    expect(
      find.text('The lesson could not be added. Please try again.'),
      findsOne,
    );
    expect(find.text(refusedText), findsNothing);
    expect(find.text('Ready'), findsNWidgets(2));
  });

  testWidgets('the refusal is told in Arabic too', (tester) async {
    tall(tester);
    final repository = _RefusingWork([
      const CourseworkRefusal(
        CourseworkProblem.attachmentRefused,
        rows: {'attachmentFileIds.0': 'file_not_found'},
      ),
    ]);
    await tester.pumpWidget(lessonPage(repository, locale: const Locale('ar')));
    await fillLessonWithTwoFiles(tester);

    await tester.tap(find.byIcon(Icons.upload_file_rounded));
    await tester.pumpAndSettle();

    expect(
      find.text(
        'لم يُقبل ملف أو رابط، لذا لم يُحفظ شيء. أزِل ما هو مُعلَّم، ثم احفظ '
        'مرة أخرى.',
      ),
      findsOne,
    );
    expect(
      find.text('لم يعد هذا الملف متاحًا. أزِله وأرفقه مرة أخرى.'),
      findsOne,
    );
  });

  testWidgets('a link the server would not add is marked on new homework', (
    tester,
  ) async {
    tall(tester);
    final repository = _RefusingWork([
      const CourseworkRefusal(
        CourseworkProblem.attachmentRefused,
        rows: {'links.0': 'link_not_allowed'},
      ),
    ]);
    await tester.pumpWidget(
      localizedApp(
        home: CreateAssignmentPage(
          repository: repository,
          classes: classes,
          initialClassroomId: 'c1',
          schoolId: 'school-1',
          uploads: _Files(),
          attachmentSource: (_, _) async => slides(),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).first, 'Reading');
    await tester.tap(find.text('Pick a due date'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('OK'));
    await tester.pumpAndSettle();
    // The time picker follows the date picker.
    await tester.tap(find.text('OK'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Add link').first);
    await tester.pumpAndSettle();
    await tester.enterText(
      find.widgetWithText(TextField, 'Address (https://…)'),
      'https://reading.example.org/a',
    );
    await tester.enterText(
      find.widgetWithText(TextField, 'Title readers see'),
      'Article',
    );
    await tester.tap(find.widgetWithText(FilledButton, 'Add link'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Create assignment'));
    await tester.pumpAndSettle();

    expect(find.text(refusedText), findsOne);
    expect(
      find.text('This link can\'t be added. Remove it, then save again.'),
      findsOne,
    );
    expect(repository.assignmentAttempts.single.links.single.title, 'Article');

    await tester.tap(find.text('Create assignment'));
    await tester.pumpAndSettle();
    expect(repository.assignmentAttempts, hasLength(1));

    await tester.tap(find.byTooltip('Remove'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Create assignment'));
    await tester.pumpAndSettle();
    expect(repository.assignments.single.links, isEmpty);
  });

  group('the repository', () {
    setUp(() {
      ActiveContextController.instance.hydrate(
        authenticatedProfile: const UserProfile(
          id: 'actor',
          displayName: 'Teacher',
          email: 'teacher@example.test',
          memberships: [_membership],
        ),
        activeMembership: _membership,
      );
    });
    tearDown(ActiveContextController.instance.signOut);

    test('turns ATTACHMENT_REFUSED into a refusal naming the rows', () async {
      final repository = ApiAcademicRepository(
        V1ApiClient(
          _Refusing(
            const V1ApiException(
              status: 422,
              code: 'ATTACHMENT_REFUSED',
              message: 'An attachment was refused',
              fieldErrors: {
                'attachmentFileIds.1': 'file_refused',
                'links.0': 'link_not_allowed',
              },
            ),
          ),
        ),
        context: ActiveContextController.instance,
      );
      await expectLater(
        repository.createResource(
          const TextResourceDraft(
            classroomId: 'c1',
            title: 'Cells',
            body: 'Notes',
            audience: 'both',
          ),
        ),
        throwsA(
          isA<CourseworkRefusal>()
              .having(
                (r) => r.problem,
                'problem',
                CourseworkProblem.attachmentRefused,
              )
              .having((r) => r.rows, 'rows', {
                'attachmentFileIds.1': 'file_refused',
                'links.0': 'link_not_allowed',
              }),
        ),
      );
    });

    test('leaves any other failure as it was', () async {
      final repository = ApiAcademicRepository(
        V1ApiClient(
          _Refusing(
            const V1ApiException(
              status: 400,
              code: 'INVALID_REQUEST',
              message: 'Invalid request',
            ),
          ),
        ),
        context: ActiveContextController.instance,
      );
      await expectLater(
        repository.createResource(
          const TextResourceDraft(
            classroomId: 'c1',
            title: 'Cells',
            body: 'Notes',
            audience: 'both',
          ),
        ),
        throwsA(isA<V1ApiException>()),
      );
    });
  });
}

const _membership = SchoolMembership(
  id: 'membership',
  schoolId: '11111111-1111-4111-8111-111111111111',
  schoolName: 'School',
  role: StudafyRole.teacher,
  active: true,
);

/// Throws each of [failures] in turn, then saves.
class _RefusingWork extends CreateWorkFake {
  _RefusingWork(this.failures);

  final List<Object> failures;
  final lessonAttempts = <TextResourceDraft>[];
  final assignmentAttempts = <AssignmentDraft>[];

  @override
  Future<void> createResource(TextResourceDraft draft) async {
    lessonAttempts.add(draft);
    if (failures.isNotEmpty) throw failures.removeAt(0);
    lessons.add(draft);
  }

  @override
  Future<void> createAssignment(AssignmentDraft draft) async {
    assignmentAttempts.add(draft);
    if (failures.isNotEmpty) throw failures.removeAt(0);
    assignments.add(draft);
  }
}

/// Answers every write with [failure].
class _Refusing implements V1JsonTransport {
  _Refusing(this.failure);

  final V1ApiException failure;

  @override
  Future<Map<String, dynamic>> get(String path) async => throw failure;

  @override
  Future<Map<String, dynamic>> post(
    String path,
    Map<String, Object?> body, {
    String? idempotencyKey,
    bool requiresIdempotency = false,
  }) async => throw failure;
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
