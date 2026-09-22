import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:studafy/features/academic/domain/academic_repository.dart';
import 'package:studafy/features/academic/presentation/create_exam_page.dart';

import 'support/academic_repository_fake.dart';
import 'support/localized_app.dart';

const _classes = [ClassOption(id: 'c1', name: 'Grade 7 Science')];

Widget _page(CreateWorkFake fake, {Locale? locale}) => localizedApp(
  locale: locale,
  home: CreateExamPage(
    repository: fake,
    classes: _classes,
    initialClassroomId: 'c1',
  ),
);

void main() {
  testWidgets('an exam is recorded as gradeable work, not a paper to sit', (
    tester,
  ) async {
    // Exams are sat outside Studafy. The record exists so marks can be
    // entered against it, so it carries no questions and is never delivered
    // in the app.
    final fake = CreateWorkFake();
    await tester.pumpWidget(_page(fake));
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField).first, 'Unit 1 exam');
    await tester.enterText(find.widgetWithText(TextField, 'Total marks'), '20');
    await tester.tap(find.text('Create exam'));
    await tester.pumpAndSettle();

    final created = fake.assessments.single;
    expect(created.title, 'Unit 1 exam');
    expect(created.maximumScore, 20);
    expect(created.questions, isEmpty);
    expect(created.delivery, 'paper');
  });

  testWidgets('nothing offers to deliver the exam in the app', (tester) async {
    final fake = CreateWorkFake();
    await tester.pumpWidget(_page(fake));
    await tester.pumpAndSettle();

    expect(find.text('In the app'), findsNothing);
    expect(find.text('Add question'), findsNothing);
  });

  testWidgets('the kind is carried through for the gradebook', (tester) async {
    final fake = CreateWorkFake();
    await tester.pumpWidget(_page(fake));
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField).first, 'Unit 2 paper');
    await tester.tap(find.widgetWithText(ChoiceChip, 'Midterm'));
    await tester.pumpAndSettle();
    await tester.enterText(find.widgetWithText(TextField, 'Total marks'), '40');
    await tester.tap(find.text('Create exam'));
    await tester.pumpAndSettle();

    expect(fake.assessments.single.category, 'midterm');
  });

  testWidgets('a total above zero is required', (tester) async {
    // The database refuses maximum_score <= 0; naming the field beats
    // handing the teacher a failed request.
    final fake = CreateWorkFake();
    await tester.pumpWidget(_page(fake));
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField).first, 'Unit 1');
    await tester.enterText(find.widgetWithText(TextField, 'Total marks'), '0');
    await tester.tap(find.text('Create exam'));
    await tester.pumpAndSettle();

    expect(find.text('Set the total marks above zero.'), findsOneWidget);
    expect(fake.assessments, isEmpty);
  });

  testWidgets('a title is required', (tester) async {
    final fake = CreateWorkFake();
    await tester.pumpWidget(_page(fake));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Create exam'));
    await tester.pumpAndSettle();

    expect(find.text('Give the exam a title.'), findsOneWidget);
  });

  testWidgets('the exam form reads in Arabic', (tester) async {
    final fake = CreateWorkFake();
    await tester.pumpWidget(_page(fake, locale: const Locale('ar')));
    await tester.pumpAndSettle();

    expect(find.text('اختبار جديد'), findsWidgets);
    expect(find.text('مجموع الدرجات'), findsWidgets);
  });
}
