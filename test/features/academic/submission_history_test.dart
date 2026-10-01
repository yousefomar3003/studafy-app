import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:studafy/core/file_upload_repository.dart';
import 'package:studafy/features/academic/domain/academic_repository.dart';
import 'package:studafy/features/academic/presentation/submission_history_view.dart';
import 'package:studafy/features/academic/presentation/submissions_page.dart';
import 'package:studafy/features/academic/presentation/submit_work_page.dart';

import '../../support/academic_repository_fake.dart';
import '../../support/localized_app.dart';

/// Every attempt at a piece of work, for the student, a guardian and the
/// teacher. Who may read which history is the server's decision and is
/// proven against real SQL in apps/api/test/academic; this is what each
/// screen shows and which student it asks about.
void main() {
  final latest = SubmissionAttempt(
    id: 'at2',
    submittedAt: DateTime(2026, 9, 22, 18, 5),
    current: true,
    answerText: 'Second try, with the diagram.',
    submittedByGuardianId: 'g1',
    submittedByGuardianName: 'Huda Saleh',
    attachments: const [
      StoredAttachment(
        id: 'f1',
        displayName: 'diagram.jpg',
        sizeBytes: 2048,
        scanState: 'clean',
        mediaType: 'image/jpeg',
      ),
    ],
  );
  final earlier = SubmissionAttempt(
    id: 'at1',
    submittedAt: DateTime(2026, 9, 21, 9, 30),
    current: false,
    answerText: 'First try.',
  );

  Widget handIn(SubmitFake fake, {String? studentId}) => localizedApp(
    home: SubmitWorkPage(
      repository: fake,
      assignmentId: 'a1',
      assignmentTitle: 'Atoms',
      studentId: studentId,
    ),
  );

  void tall(WidgetTester tester) {
    tester.view.physicalSize = const Size(1200, 2600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
  }

  testWidgets('the hand-in screen shows every earlier attempt', (tester) async {
    tall(tester);
    final fake = SubmitFake()..history = [latest, earlier];
    await tester.pumpWidget(handIn(fake));
    await tester.pumpAndSettle();

    expect(find.text('Hand-in history'), findsOne);
    expect(find.text('Second try, with the diagram.'), findsOne);
    expect(find.text('First try.'), findsOne);
    expect(find.text('Latest'), findsOne);
    expect(find.text('Earlier'), findsOne);
    // A parent's hand-in is named as theirs.
    expect(find.text('Handed in by Huda Saleh'), findsOne);
    // Each attempt keeps its own files.
    expect(
      find.descendant(
        of: find.byType(SubmissionHistoryView),
        matching: find.text('diagram.jpg'),
      ),
      findsOne,
    );
    // Replacing the work offers to keep that file, without asking again.
    expect(find.widgetWithText(CheckboxListTile, 'diagram.jpg'), findsOne);
    // A student reading their own work does not name themselves.
    expect(fake.historyRequests.single.studentId, isNull);
  });

  testWidgets('a guardian reads the history of the child they act for', (
    tester,
  ) async {
    tall(tester);
    final fake = SubmitFake()..history = [earlier];
    await tester.pumpWidget(handIn(fake, studentId: 'child-1'));
    await tester.pumpAndSettle();

    expect(fake.historyRequests.single.studentId, 'child-1');
    expect(find.text('First try.'), findsOne);
  });

  testWidgets('with nothing handed in, no history section is shown', (
    tester,
  ) async {
    tall(tester);
    await tester.pumpWidget(handIn(SubmitFake()));
    await tester.pumpAndSettle();

    expect(find.text('Hand-in history'), findsNothing);
  });

  testWidgets('a teacher opens one student\'s full history', (tester) async {
    final fake =
        SubmissionsFake(
            students: const [
              ClassStudent(id: 's1', displayName: 'Amal', studafyId: 'SJ-1'),
              ClassStudent(id: 's2', displayName: 'Bilal', studafyId: 'SJ-2'),
            ],
            work: [
              SubmittedWork(
                id: 'w1',
                assignmentId: 'a1',
                studentId: 's1',
                status: 'submitted',
                answerText: 'Second try, with the diagram.',
                submittedAt: DateTime(2026, 9, 22, 18, 5),
              ),
            ],
          )
          ..history = {
            's1': [latest, earlier],
          };
    await tester.pumpWidget(
      localizedApp(
        home: SubmissionsPage(
          repository: fake,
          assignmentId: 'a1',
          assignmentTitle: 'Atoms',
          classroomId: 'c1',
        ),
      ),
    );
    await tester.pumpAndSettle();

    // Nothing to open for a student who has not handed in.
    await tester.tap(find.text('Bilal'));
    await tester.pumpAndSettle();
    expect(fake.historyRequests, isEmpty);

    await tester.tap(find.text('Amal'));
    await tester.pumpAndSettle();

    expect(fake.historyRequests, ['s1']);
    expect(find.text('First try.'), findsOne);
    expect(find.text('Handed in by Huda Saleh'), findsOne);
  });

  testWidgets('a history that fails to load says so', (tester) async {
    final fake = SubmissionsFake(
      students: const [
        ClassStudent(id: 's1', displayName: 'Amal', studafyId: 'SJ-1'),
      ],
      work: [
        SubmittedWork(
          id: 'w1',
          assignmentId: 'a1',
          studentId: 's1',
          status: 'submitted',
          submittedAt: DateTime(2026, 9, 22, 18, 5),
        ),
      ],
    );
    await tester.pumpWidget(
      localizedApp(
        home: SubmissionsPage(
          repository: _FailingHistory(fake),
          assignmentId: 'a1',
          assignmentTitle: 'Atoms',
          classroomId: 'c1',
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Amal'));
    await tester.pumpAndSettle();

    expect(find.textContaining('could not be loaded'), findsOne);
  });
}

class _FailingHistory implements AcademicRepository {
  _FailingHistory(this.inner);
  final SubmissionsFake inner;

  @override
  Future<List<ClassStudent>> classStudents(String classroomId) =>
      inner.classStudents(classroomId);

  @override
  Future<List<SubmittedWork>> submissionsFor(String assignmentId) =>
      inner.submissionsFor(assignmentId);

  @override
  Future<List<SubmissionAttempt>> submissionHistory(
    String assignmentId, {
    String? studentId,
  }) async => throw StateError('offline');

  @override
  dynamic noSuchMethod(Invocation invocation) => throw UnimplementedError();
}
