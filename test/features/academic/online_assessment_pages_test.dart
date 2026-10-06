import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:studafy/features/academic/data/preview_academic_repository.dart';
import 'package:studafy/features/academic/data/preview_online_assessments.dart';
import 'package:studafy/features/academic/domain/academic_repository.dart';
import 'package:studafy/features/academic/presentation/assessment_builder_page.dart';
import 'package:studafy/features/academic/presentation/assessment_marking_page.dart';
import 'package:studafy/features/academic/presentation/assessment_page.dart';
import 'package:studafy/features/academic/presentation/take_assessment_page.dart';

import '../../support/localized_app.dart';

/// Online assessments as each role sees them (ADR-0036). Who may read a key,
/// when answers are released, and what a parent may do are the server's
/// decisions (supabase/tests/online_assessments.sql and the API integration
/// suite); these check that the screens show and send what they should.

void _tall(WidgetTester tester) {
  tester.view.physicalSize = const Size(1200, 3000);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
}

/// A published assessment with a required choice and an optional essay.
Future<(PreviewOnlineAssessments, String)> _assessment({
  AnswerRelease release = AnswerRelease.manual,
  int attempts = 1,
}) async {
  final repository = PreviewOnlineAssessments(onCreated: (_) {});
  final created = await repository.createOnlineAssessment(
    OnlineAssessmentDraft(
      classroomId: 'class-1',
      title: 'Fractions quiz',
      category: 'quiz',
      settings: AssessmentSettings(
        closesAt: DateTime.now().add(const Duration(days: 1)),
        maxAttempts: attempts,
        answerRelease: release,
      ),
      questions: const [
        QuestionDraft(
          id: 'q1',
          kind: QuestionKind.singleChoice,
          prompt: 'What is 1/2 + 1/4?',
          maximumScore: 2,
          options: [
            QuestionOption(id: 'a', text: '3/4'),
            QuestionOption(id: 'b', text: '2/6'),
          ],
          correctOptionIds: ['a'],
        ),
        QuestionDraft(
          id: 'q2',
          kind: QuestionKind.essay,
          prompt: 'Explain how you added them.',
          maximumScore: 3,
          required: false,
        ),
      ],
    ),
  );
  return (repository, created.id);
}

void main() {
  group('building', () {
    Widget builder(PreviewAcademicRepository repository) => localizedApp(
      home: AssessmentBuilderPage(
        repository: repository,
        classes: const [ClassOption(id: 'class-1', name: '7B')],
      ),
    );

    testWidgets('nothing is saved until every question is complete', (
      tester,
    ) async {
      _tall(tester);
      final repository = PreviewAcademicRepository();
      await tester.pumpWidget(builder(repository));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Save draft'));
      await tester.pumpAndSettle();
      expect(find.textContaining('Give it a title.'), findsOneWidget);
      expect(
        find.textContaining('Question 1: write the question.'),
        findsOneWidget,
      );
      expect(
        await repository.load(AcademicFeed.assessments),
        isEmpty,
        reason: 'an incomplete assessment is never sent',
      );
    });

    testWidgets('the total is the sum of every question', (tester) async {
      _tall(tester);
      await tester.pumpWidget(builder(PreviewAcademicRepository()));
      await tester.pumpAndSettle();

      expect(find.textContaining('Total points: 1'), findsOneWidget);
      await tester.tap(find.text('Add question'));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.widgetWithText(TextField, 'Points').last,
        '4',
      );
      await tester.pumpAndSettle();
      expect(find.textContaining('Total points: 5'), findsOneWidget);
    });
  });

  group('sitting', () {
    testWidgets('a required question must be answered, then it is sent', (
      tester,
    ) async {
      _tall(tester);
      final (repository, id) = await _assessment();
      AttemptConfirmation? confirmed;
      await tester.pumpWidget(
        localizedApp(
          home: Builder(
            builder: (context) => TextButton(
              onPressed: () async {
                confirmed = await Navigator.of(context)
                    .push<AttemptConfirmation>(
                      MaterialPageRoute(
                        builder: (_) => TakeAssessmentPage(
                          title: 'Fractions quiz',
                          repository: repository,
                          assessmentId: id,
                        ),
                      ),
                    );
              },
              child: const Text('open'),
            ),
          ),
        ),
      );
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();

      // The student never sees which option is right.
      expect(find.text('What is 1/2 + 1/4?'), findsOneWidget);
      expect(find.text('Correct answer'), findsNothing);

      await tester.tap(find.text('Submit answers'));
      await tester.pumpAndSettle();
      expect(
        find.text('Answer the required question that is left.'),
        findsOneWidget,
      );

      await tester.tap(find.text('3/4'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Submit answers'));
      await tester.pumpAndSettle();
      expect(find.text('Submit your answers?'), findsOneWidget);
      await tester.tap(
        find.descendant(
          of: find.byType(AlertDialog),
          matching: find.text('Submit answers'),
        ),
      );
      await tester.pumpAndSettle();

      expect(confirmed?.attemptNumber, 1);
      final attempt = (await repository.attempts(id)).single;
      expect(attempt.answers.first.selectedOptionIds, ['a']);
    });

    testWidgets('a preview shows the questions and cannot be submitted', (
      tester,
    ) async {
      _tall(tester);
      await tester.pumpWidget(
        localizedApp(
          home: const TakeAssessmentPage(
            title: 'Fractions quiz',
            preview: true,
            questions: [
              AssessmentQuestion(
                id: 'q1',
                position: 1,
                prompt: 'True or false: 1/2 > 1/3',
                maximumScore: 1,
                kind: QuestionKind.trueFalse,
              ),
            ],
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('True or false: 1/2 > 1/3'), findsOneWidget);
      expect(find.text('Submit answers'), findsNothing);
    });
  });

  group('results', () {
    Widget results(
      PreviewOnlineAssessments repository,
      String id, {
      String? studentId,
    }) => localizedApp(
      home: AssessmentPage(
        repository: repository,
        assessmentId: id,
        title: 'Fractions quiz',
        studentId: studentId,
        childName: studentId == null ? null : 'Amal',
      ),
    );

    testWidgets('a submission is confirmed; answers wait for release', (
      tester,
    ) async {
      _tall(tester);
      final (repository, id) = await _assessment(attempts: 2);
      await repository.submitAnswers(id, const [
        StudentAnswer(questionId: 'q1', selectedOptionIds: ['b']),
      ]);
      await tester.pumpWidget(results(repository, id));
      await tester.pumpAndSettle();

      expect(find.textContaining('Attempt 1'), findsOneWidget);
      expect(find.text('Try again'), findsOneWidget);
      expect(find.text('Not published yet'), findsOneWidget);
      expect(
        find.text('Answers will appear here once your teacher releases them.'),
        findsOneWidget,
      );
      expect(find.text('Correct answer'), findsNothing);
      expect(find.text('3/4'), findsNothing);
    });

    testWidgets('released answers show beside the student\'s own', (
      tester,
    ) async {
      _tall(tester);
      final (repository, id) = await _assessment();
      await repository.submitAnswers(id, const [
        StudentAnswer(questionId: 'q1', selectedOptionIds: ['b']),
      ]);
      await repository.updateAssessmentDesign(id, 1, releaseAnswersNow: true);
      await tester.pumpWidget(results(repository, id));
      await tester.pumpAndSettle();

      expect(find.text('Correct answer'), findsOneWidget);
      expect(find.text('3/4'), findsOneWidget);
      expect(find.text('2/6'), findsOneWidget);
      expect(find.text('0 of 2'), findsOneWidget);
      // The essay is waiting for the teacher.
      expect(find.text('Being marked'), findsOneWidget);
      // One attempt allowed, and it is used.
      expect(find.text('Try again'), findsNothing);
      expect(find.text('Start'), findsNothing);
    });

    testWidgets('a parent reads their child\'s results and cannot sit it', (
      tester,
    ) async {
      _tall(tester);
      final (repository, id) = await _assessment();
      await tester.pumpWidget(results(repository, id, studentId: 'child-1'));
      await tester.pumpAndSettle();

      expect(find.text('Amal'), findsOneWidget);
      expect(
        find.text(
          "You can see your child's results here. Only they can sit it.",
        ),
        findsOneWidget,
      );
      expect(find.text('Start'), findsNothing);
    });
  });

  group('marking', () {
    testWidgets('the teacher sees the key and marks the essay in range', (
      tester,
    ) async {
      _tall(tester);
      final (repository, id) = await _assessment();
      await repository.submitAnswers(id, const [
        StudentAnswer(questionId: 'q1', selectedOptionIds: ['a']),
        StudentAnswer(questionId: 'q2', text: 'Quarters'),
      ]);
      final attempt = (await repository.attempts(id)).single;
      await tester.pumpWidget(
        localizedApp(
          home: MarkAttemptPage(
            repository: repository,
            attemptId: attempt.id,
            studentName: 'Amal',
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Correct answer'), findsOneWidget);
      expect(find.text('Marked automatically'), findsOneWidget);
      expect(find.text('Being marked'), findsOneWidget);

      final essay = find.widgetWithText(TextField, 'Score (out of 3)');
      await tester.enterText(essay, '4');
      await tester.tap(find.text('Save marks'));
      await tester.pumpAndSettle();
      expect(find.text('Enter a score from 0 to 3.'), findsOneWidget);
      expect((await repository.attempt(attempt.id)).awardedScore, isNull);

      await tester.enterText(essay, '2.5');
      await tester.tap(find.text('Save marks'));
      await tester.pumpAndSettle();
      final marked = await repository.attempt(attempt.id);
      expect(marked.awardedScore, 4.5);
      expect(marked.needsMarking, isFalse);
    });
  });
}
