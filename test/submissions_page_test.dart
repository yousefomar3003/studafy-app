import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:studafy/features/academic/domain/academic_repository.dart';
import 'package:studafy/features/academic/presentation/submissions_page.dart';

import 'support/academic_repository_fake.dart';
import 'support/localized_app.dart';

Widget _page(SubmissionsFake fake, {Locale? locale}) => localizedApp(
  locale: locale,
  home: SubmissionsPage(
    repository: fake,
    assignmentId: 'a1',
    assignmentTitle: 'Read chapter 3',
    classroomId: 'c1',
  ),
);

void main() {
  testWidgets('students who have not handed in are still listed', (
    tester,
  ) async {
    // A list of submissions alone omits exactly the students a teacher most
    // needs to see, so the roster is the spine.
    final fake = SubmissionsFake(
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
          answerText: 'My answer',
          submittedAt: DateTime(2026, 9, 21, 10, 30),
        ),
      ],
    );
    await tester.pumpWidget(_page(fake));
    await tester.pumpAndSettle();

    expect(find.text('Amal'), findsOneWidget);
    expect(find.text('Bilal'), findsOneWidget);
    expect(find.text('Not handed in'), findsOneWidget);
    expect(find.text('1 of 2 handed in'), findsOneWidget);
  });

  testWidgets('handed-in work can be read', (tester) async {
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
          answerText: 'The answer is 42',
          submittedAt: DateTime(2026, 9, 21, 10, 30),
        ),
      ],
    );
    await tester.pumpWidget(_page(fake));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Amal'));
    await tester.pumpAndSettle();
    expect(find.text('The answer is 42'), findsOneWidget);
  });

  testWidgets('an empty class says so', (tester) async {
    final fake = SubmissionsFake(students: const [], work: const []);
    await tester.pumpWidget(_page(fake));
    await tester.pumpAndSettle();

    expect(find.text('Nobody has handed anything in yet.'), findsOneWidget);
  });

  testWidgets('handed-in work reads in Arabic', (tester) async {
    final fake = SubmissionsFake(
      students: const [
        ClassStudent(id: 's1', displayName: 'أمل', studafyId: 'SJ-1'),
      ],
      work: const [],
    );
    await tester.pumpWidget(_page(fake, locale: const Locale('ar')));
    await tester.pumpAndSettle();

    expect(find.text('لم يُسلَّم'), findsOneWidget);
  });
}
