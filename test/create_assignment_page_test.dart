import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:studafy/features/academic/domain/academic_repository.dart';
import 'package:studafy/features/academic/presentation/create_assignment_page.dart';

import 'support/academic_repository_fake.dart';
import 'support/localized_app.dart';

const _classes = [
  ClassOption(id: 'c1', name: 'Grade 7 Science'),
  ClassOption(id: 'c2', name: 'Grade 8 Physics'),
];

Widget _page(
  CreateWorkFake fake, {
  List<ClassOption>? classes,
  Locale? locale,
}) => localizedApp(
  locale: locale,
  home: CreateAssignmentPage(
    repository: fake,
    classes: classes ?? _classes,
    initialClassroomId: 'c1',
  ),
);

Future<void> _fillTitleAndDue(WidgetTester tester, String title) async {
  await tester.enterText(find.byType(TextField).first, title);
  await tester.tap(find.text('Pick a due date'));
  await tester.pumpAndSettle();
  await tester.tap(find.text('OK'));
  await tester.pumpAndSettle();
  // The time picker follows the date picker.
  await tester.tap(find.text('OK'));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('ungraded work is filed as an assignment', (tester) async {
    final fake = CreateWorkFake();
    await tester.pumpWidget(_page(fake));
    await tester.pumpAndSettle();

    await _fillTitleAndDue(tester, 'Read chapter 3');
    await tester.tap(find.text('Create assignment'));
    await tester.pumpAndSettle();

    expect(fake.assignments, hasLength(1));
    expect(fake.assessments, isEmpty);
    expect(fake.assignments.single.title, 'Read chapter 3');
    expect(fake.assignments.single.classroomId, 'c1');
  });

  testWidgets('graded work is filed as an assessment a grade can attach to', (
    tester,
  ) async {
    // grade_results.assessment_id is NOT NULL, so graded work has to be an
    // assessment or it could never be marked.
    final fake = CreateWorkFake();
    await tester.pumpWidget(_page(fake));
    await tester.pumpAndSettle();

    await _fillTitleAndDue(tester, 'Lab report');
    await tester.tap(find.text('Graded'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).last, '25');
    await tester.tap(find.text('Create assignment'));
    await tester.pumpAndSettle();

    expect(fake.assessments, hasLength(1));
    expect(fake.assignments, isEmpty);
    final created = fake.assessments.single;
    expect(created.title, 'Lab report');
    expect(created.maximumScore, 25);
    // Grouped with coursework rather than among exams, and marked by the
    // teacher rather than answered in the app.
    expect(created.category, 'assignment');
    expect(created.delivery, 'paper');
    expect(created.scheduledAt, isNotNull);
  });

  testWidgets('the maximum score is only asked for when graded', (
    tester,
  ) async {
    final fake = CreateWorkFake();
    await tester.pumpWidget(_page(fake));
    await tester.pumpAndSettle();

    expect(find.text('Maximum score'), findsNothing);
    await tester.tap(find.text('Graded'));
    await tester.pumpAndSettle();
    expect(find.text('Maximum score'), findsOneWidget);
  });

  testWidgets('a title is required before anything is created', (tester) async {
    final fake = CreateWorkFake();
    await tester.pumpWidget(_page(fake));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Create assignment'));
    await tester.pumpAndSettle();

    expect(find.text('Give the assignment a title.'), findsOneWidget);
    expect(fake.assignments, isEmpty);
    expect(fake.assessments, isEmpty);
  });

  testWidgets('a due date is required', (tester) async {
    final fake = CreateWorkFake();
    await tester.pumpWidget(_page(fake));
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField).first, 'Read chapter 3');
    await tester.tap(find.text('Create assignment'));
    await tester.pumpAndSettle();

    expect(find.text('Choose when it is due.'), findsOneWidget);
    expect(fake.assignments, isEmpty);
  });

  testWidgets('graded work refuses a zero maximum score', (tester) async {
    // The database rejects it too (maximum_score > 0); catching it here
    // means the teacher is told which field, not handed a failed request.
    final fake = CreateWorkFake();
    await tester.pumpWidget(_page(fake));
    await tester.pumpAndSettle();

    await _fillTitleAndDue(tester, 'Lab report');
    await tester.tap(find.text('Graded'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).last, '0');
    await tester.tap(find.text('Create assignment'));
    await tester.pumpAndSettle();

    expect(find.text('Set a maximum score above zero.'), findsOneWidget);
    expect(fake.assessments, isEmpty);
  });

  testWidgets('a failure keeps the form open and says so', (tester) async {
    final fake = CreateWorkFake(fail: true);
    await tester.pumpWidget(_page(fake));
    await tester.pumpAndSettle();

    await _fillTitleAndDue(tester, 'Read chapter 3');
    await tester.tap(find.text('Create assignment'));
    await tester.pumpAndSettle();

    expect(
      find.text('Could not create the assignment. Please try again.'),
      findsOneWidget,
    );
    expect(find.byType(CreateAssignmentPage), findsOneWidget);
  });

  testWidgets('the form reads in Arabic', (tester) async {
    final fake = CreateWorkFake();
    await tester.pumpWidget(_page(fake, locale: const Locale('ar')));
    await tester.pumpAndSettle();

    expect(find.text('واجب جديد'), findsOneWidget);
    expect(find.text('بدرجة'), findsOneWidget);
  });
}
