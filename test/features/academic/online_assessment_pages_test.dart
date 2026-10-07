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

      // The question, the student's answer, the key and the marks.
      expect(find.text('What is 1/2 + 1/4?'), findsOneWidget);
      expect(find.text("Student's answer"), findsNWidgets(2));
      expect(find.text('Correct answer'), findsOneWidget);
      expect(find.text('Marked automatically: 2 of 2'), findsOneWidget);
      expect(find.text('Submitted · not graded'), findsOneWidget);
      expect(
        find.text(
          "Not published yet: only the class's teachers can see these marks.",
        ),
        findsOneWidget,
      );

      final essay = find.widgetWithText(TextField, 'Score (out of 3)');
      await tester.enterText(essay, '4');
      await tester.tap(find.text('Save draft'));
      await tester.pumpAndSettle();
      expect(find.text('Enter a score from 0 to 3.'), findsOneWidget);
      expect(
        find.text('Fix the highlighted marks, then save again.'),
        findsOneWidget,
      );
      expect((await repository.attempt(attempt.id)).awardedScore, isNull);

      await tester.enterText(essay, '2.5');
      await tester.tap(find.text('Save draft'));
      await tester.pumpAndSettle();
      final marked = await repository.attempt(attempt.id);
      expect(marked.awardedScore, 4.5);
      expect(marked.needsMarking, isFalse);
      expect(
        find.text(
          "Saved as a draft. Students and parents can't see it until you "
          'publish the grades.',
        ),
        findsOneWidget,
      );
      expect(find.text('Graded · not published'), findsOneWidget);
    });

    Future<_Recording> openPublished(
      WidgetTester tester, {
      String gradeMark = 'scored',
    }) async {
      _tall(tester);
      final repository = _Recording(published: true, gradeMark: gradeMark);
      final id = await _seedAttempt(repository);
      await tester.pumpWidget(
        localizedApp(
          home: MarkAttemptPage(
            repository: repository,
            attemptId: id,
            studentName: 'Amal',
          ),
        ),
      );
      await tester.pumpAndSettle();
      return repository;
    }

    Finder dialogButton(String label) => find.descendant(
      of: find.byType(AlertDialog),
      matching: find.widgetWithText(FilledButton, label),
    );

    testWidgets('a changed published mark asks for a reason only when the '
        'server says it is a correction', (tester) async {
      final repository = await openPublished(tester);
      expect(find.text('Published'), findsOneWidget);

      await tester.enterText(
        find.widgetWithText(TextField, 'Score (out of 3)'),
        '1',
      );
      await tester.tap(find.widgetWithText(FilledButton, 'Save changes'));
      await tester.pumpAndSettle();
      // The save went first; the server refused it without a reason.
      expect(repository.reasons, [null]);
      expect(find.text('Correct a published grade'), findsOneWidget);
      // No reason, no correction.
      expect(
        tester.widget<FilledButton>(dialogButton('Save correction')).onPressed,
        isNull,
      );
      await tester.enterText(
        find.descendant(
          of: find.byType(AlertDialog),
          matching: find.byType(TextField),
        ),
        'Recounted the essay',
      );
      await tester.pump();
      await tester.tap(dialogButton('Save correction'));
      await tester.pumpAndSettle();
      expect(repository.reasons, [null, 'Recounted the essay']);
      expect(
        find.text(
          'Correction saved. The student and their parents see the new mark.',
        ),
        findsOneWidget,
      );
    });

    testWidgets('feedback alone on a published grade is saved without a '
        'reason', (tester) async {
      final repository = await openPublished(tester);
      await tester.enterText(
        find.widgetWithText(TextField, 'Feedback for the student'),
        'See the model answer.',
      );
      await tester.enterText(
        find.widgetWithText(TextField, 'Comment on this answer').first,
        'Well chosen.',
      );
      await tester.tap(find.widgetWithText(FilledButton, 'Save changes'));
      await tester.pumpAndSettle();
      expect(find.byType(AlertDialog), findsNothing);
      expect(repository.reasons, [null]);
      expect(
        find.text(
          'Saved. Nothing about the published grade needed a correction.',
        ),
        findsOneWidget,
      );
    });

    testWidgets('an unchanged save sends nothing', (tester) async {
      final repository = await openPublished(tester);
      await tester.tap(find.widgetWithText(FilledButton, 'Save changes'));
      await tester.pumpAndSettle();
      expect(repository.saves, 0);
      expect(
        find.text('Nothing has changed since the last save.'),
        findsOneWidget,
      );
    });

    testWidgets('backing out of the reason saves nothing and keeps the marks', (
      tester,
    ) async {
      final repository = await openPublished(tester);
      final essay = find.widgetWithText(TextField, 'Score (out of 3)');
      await tester.enterText(essay, '1');
      await tester.tap(find.widgetWithText(FilledButton, 'Save changes'));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(TextButton, 'Cancel'));
      await tester.pumpAndSettle();
      expect(repository.reasons, [null]);
      expect(tester.widget<TextField>(essay).controller!.text, '1');
      expect(
        find.text(
          'Not saved. A change to a published mark needs a reason; your '
          'marks are still here.',
        ),
        findsOneWidget,
      );
    });

    testWidgets('a published absence is replaced from the late attempt, with '
        'a reason', (tester) async {
      final repository = await openPublished(tester, gradeMark: 'absent');
      expect(
        find.textContaining('Published as absent, but this student handed'),
        findsOneWidget,
      );
      await tester.tap(
        find.widgetWithText(FilledButton, 'Replace the absence'),
      );
      await tester.pumpAndSettle();
      await tester.enterText(
        find.descendant(
          of: find.byType(AlertDialog),
          matching: find.byType(TextField),
        ),
        'Sat it late with permission',
      );
      await tester.pump();
      await tester.tap(dialogButton('Save correction'));
      await tester.pumpAndSettle();
      expect(repository.reasons, [null, 'Sat it late with permission']);
    });

    testWidgets('a failed save keeps every mark typed', (tester) async {
      _tall(tester);
      final repository = _Recording(failSaves: true);
      final id = await _seedAttempt(repository);
      await tester.pumpWidget(
        localizedApp(
          home: MarkAttemptPage(
            repository: repository,
            attemptId: id,
            studentName: 'Amal',
          ),
        ),
      );
      await tester.pumpAndSettle();
      final essay = find.widgetWithText(TextField, 'Score (out of 3)');
      await tester.enterText(essay, '2');
      await tester.enterText(
        find.widgetWithText(TextField, 'Feedback for the student'),
        'Clear working.',
      );
      await tester.tap(find.text('Save draft'));
      await tester.pumpAndSettle();
      expect(
        find.text('Marks were not saved. Check each score and try again.'),
        findsOneWidget,
      );
      expect(tester.widget<TextField>(essay).controller!.text, '2');
      expect(find.text('Clear working.'), findsOneWidget);
    });

    testWidgets('leaving with unsaved marks asks first', (tester) async {
      _tall(tester);
      final repository = _Recording();
      final id = await _seedAttempt(repository);
      await tester.pumpWidget(
        localizedApp(
          home: Builder(
            builder: (context) => TextButton(
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) => MarkAttemptPage(
                    repository: repository,
                    attemptId: id,
                    studentName: 'Amal',
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
        find.widgetWithText(TextField, 'Score (out of 3)'),
        '2',
      );
      await tester.pump();
      await tester.pageBack();
      await tester.pumpAndSettle();
      expect(find.text('Leave without saving?'), findsOneWidget);
      await tester.tap(find.text('Keep marking'));
      await tester.pumpAndSettle();
      expect(find.byType(MarkAttemptPage), findsOneWidget);

      await tester.pageBack();
      await tester.pumpAndSettle();
      await tester.tap(find.text('Discard changes'));
      await tester.pumpAndSettle();
      expect(find.byType(MarkAttemptPage), findsNothing);
      expect(repository.saves, 0);
    });

    testWidgets('submissions say where each stands; publishing asks first', (
      tester,
    ) async {
      _tall(tester);
      final academic = _MarkingList();
      await tester.pumpWidget(
        localizedApp(
          home: AssessmentMarkingPage(
            repository: academic,
            assessmentId: 'exam-1',
            title: 'Fractions quiz',
            classroomId: 'class-1',
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Submitted · not graded'), findsOneWidget);
      expect(find.text('Submitted · partly graded'), findsOneWidget);
      expect(find.text('Graded · not published'), findsOneWidget);
      expect(find.text('Published'), findsOneWidget);
      expect(
        find.text('2 to mark · 1 ready to publish · 1 published'),
        findsOneWidget,
      );
      // Everyone in the class is listed, not only those who handed in.
      expect(find.text('Not submitted'), findsNWidgets(2));
      expect(find.text('Absent'), findsOneWidget);
      expect(find.text('Absent · published'), findsOneWidget);
      expect(find.text('1 not submitted · 2 absent'), findsOneWidget);

      await tester.tap(find.widgetWithText(FilledButton, 'Publish grades'));
      await tester.pumpAndSettle();
      expect(find.text('Publish grades?'), findsOneWidget);
      await tester.tap(find.widgetWithText(FilledButton, 'Publish'));
      await tester.pumpAndSettle();
      expect(academic.published, [7]);
      expect(find.text('1 grade published.'), findsOneWidget);
    });

    testWidgets('a non-submitter is marked absent with a note, and the '
        'absence removed again', (tester) async {
      _tall(tester);
      final academic = _MarkingList();
      await tester.pumpWidget(
        localizedApp(
          home: AssessmentMarkingPage(
            repository: academic,
            assessmentId: 'exam-1',
            title: 'Fractions quiz',
            classroomId: 'class-1',
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Hana'));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.widgetWithText(TextField, 'Notes (optional)'),
        'Off sick',
      );
      await tester.tap(find.widgetWithText(FilledButton, 'Mark absent'));
      await tester.pumpAndSettle();
      expect(academic.drafts.single.studentId, 'student-hana');
      expect(academic.drafts.single.mark, GradeMark.absent);
      expect(academic.drafts.single.feedback, 'Off sick');
      expect(academic.drafts.single.expectedVersion, 0);
      expect(
        find.text(
          'Marked absent. Nobody sees it until you publish the grades.',
        ),
        findsOneWidget,
      );

      await tester.tap(find.text('Jad'));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(TextButton, 'Remove absence'));
      await tester.pumpAndSettle();
      expect(academic.drafts.last.studentId, 'student-jad');
      expect(academic.drafts.last.mark, isNull);
      expect(academic.drafts.last.expectedVersion, 3);
    });

    testWidgets('a published absence is corrected only with a reason', (
      tester,
    ) async {
      _tall(tester);
      final academic = _MarkingList();
      await tester.pumpWidget(
        localizedApp(
          home: AssessmentMarkingPage(
            repository: academic,
            assessmentId: 'exam-1',
            title: 'Fractions quiz',
            classroomId: 'class-1',
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Lina'));
      await tester.pumpAndSettle();
      final save = find.widgetWithText(FilledButton, 'Save correction');
      expect(tester.widget<FilledButton>(save).onPressed, isNull);
      await tester.tap(find.text('Not graded (excused)'));
      await tester.enterText(
        find.widgetWithText(TextField, 'Reason for the change'),
        'Excused by the office',
      );
      await tester.pump();
      await tester.tap(save);
      await tester.pumpAndSettle();
      final (reason, correction) = academic.corrections.single;
      expect(reason, 'Excused by the office');
      expect(correction.gradeId, 'grade-lina');
      expect(correction.mark, GradeMark.notGraded);
      expect(academic.drafts, isEmpty);
    });
  });
}

/// Seeds one submitted attempt - a choice and an essay - and answers its id.
Future<String> _seedAttempt(PreviewOnlineAssessments repository) async {
  final created = await repository.createOnlineAssessment(
    OnlineAssessmentDraft(
      classroomId: 'class-1',
      title: 'Fractions quiz',
      settings: AssessmentSettings(
        closesAt: DateTime.now().add(const Duration(days: 1)),
        answerRelease: AnswerRelease.manual,
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
        ),
      ],
    ),
  );
  await repository.submitAnswers(created.id, const [
    StudentAnswer(questionId: 'q1', selectedOptionIds: ['a']),
    StudentAnswer(questionId: 'q2', text: 'Quarters'),
  ]);
  return (await repository.attempts(created.id)).single.id;
}

AttemptDetail _withGrade(AttemptDetail a, String? gradeState, {String? mark}) =>
    AttemptDetail(
      id: a.id,
      studentId: a.studentId,
      submittedAt: a.submittedAt,
      attemptNumber: a.attemptNumber,
      studentName: a.studentName,
      needsMarking: a.needsMarking,
      awardedScore: a.awardedScore,
      feedback: a.feedback,
      answers: a.answers,
      gradeState: gradeState,
      gradeMark: mark,
    );

/// The preview repository, recording what marking sends, and optionally
/// holding a published grade or failing every save.
/// The preview repository, recording what marking sends, and optionally
/// holding a published grade - refusing, as the server does, a change to its
/// mark without a reason - or failing every save.
class _Recording extends PreviewOnlineAssessments {
  _Recording({
    this.published = false,
    this.failSaves = false,
    this.gradeMark = 'scored',
  }) : super(onCreated: (_) {});

  final bool published;
  final bool failSaves;
  final String gradeMark;
  final List<String?> reasons = [];
  int saves = 0;

  @override
  Future<AttemptDetail> attempt(String attemptId) async => _withGrade(
    await super.attempt(attemptId),
    published ? 'published' : null,
    mark: published ? gradeMark : null,
  );

  @override
  Future<AttemptDetail> markAttempt(
    String attemptId,
    List<AnswerMark> marks, {
    String? feedback,
    String? correctionReason,
  }) async {
    saves++;
    if (failSaves) throw StateError('offline');
    reasons.add(correctionReason);
    final current = await super.attempt(attemptId);
    final markChanges =
        gradeMark != 'scored' ||
        marks.any(
          (m) =>
              current.answers
                  .firstWhere((a) => a.question.id == m.questionId)
                  .awardedScore !=
              m.score,
        );
    if (published && markChanges && correctionReason == null) {
      throw const CourseworkRefusal(CourseworkProblem.reasonRequired);
    }
    return _withGrade(
      await super.markAttempt(attemptId, marks, feedback: feedback),
      published ? 'published' : 'reviewed',
      mark: published ? 'scored' : null,
    );
  }
}

/// A marking list with one submission in each state.
class _MarkingList implements AcademicRepository {
  final List<int> published = [];

  AttemptDetail _attempt(
    String id,
    String name, {
    required bool needsMarking,
    String? gradeState,
    int pending = 0,
    int manual = 2,
  }) => AttemptDetail(
    id: id,
    studentId: 'student-$id',
    studentName: name,
    submittedAt: DateTime(2026, 10, 7, 9),
    attemptNumber: 1,
    needsMarking: needsMarking,
    awardedScore: needsMarking ? null : 4,
    gradeState: gradeState,
    pendingAnswers: pending,
    manualAnswers: manual,
  );

  @override
  Future<List<AttemptDetail>> attempts(String assessmentId) async => [
    _attempt('1', 'Amal', needsMarking: true, gradeState: 'draft', pending: 2),
    _attempt('2', 'Badr', needsMarking: true, gradeState: 'draft', pending: 1),
    _attempt('3', 'Dana', needsMarking: false, gradeState: 'reviewed'),
    _attempt('4', 'Faris', needsMarking: false, gradeState: 'published'),
  ];

  @override
  Future<List<AcademicRecord>> load(
    AcademicFeed feed, {
    String? classroomId,
    String? studentId,
  }) async => const [];

  final List<GradeDraft> drafts = [];
  final List<(String, GradeCorrection)> corrections = [];

  @override
  Future<int> saveGradeDrafts(
    String assessmentId,
    int gradebookVersion,
    List<GradeDraft> entries,
  ) async {
    drafts.addAll(entries);
    return gradebookVersion + 1;
  }

  @override
  Future<void> correctGrades(
    String assessmentId,
    String reason,
    List<GradeCorrection> entries,
  ) async {
    for (final entry in entries) {
      corrections.add((reason, entry));
    }
  }

  static PaperGradebookRow _row(String id, String name, [PaperGrade? grade]) =>
      PaperGradebookRow(
        studentId: 'student-$id',
        displayName: name,
        enrolled: true,
        grade: grade,
      );

  @override
  Future<PaperGradebook> paperGradebook(String assessmentId) async =>
      PaperGradebook(
        item: const PaperGradebookItem(
          id: 'exam-1',
          title: 'Fractions quiz',
          category: 'quiz',
          maximumScore: 5,
          state: 'published',
          version: 2,
          gradebookVersion: 7,
          unmarked: 2,
          ready: 1,
          published: 1,
        ),
        rows: [
          for (final (id, name) in [
            ('1', 'Amal'),
            ('2', 'Badr'),
            ('3', 'Dana'),
            ('4', 'Faris'),
          ])
            _row(id, name),
          _row('hana', 'Hana'),
          _row(
            'jad',
            'Jad',
            const PaperGrade(
              id: 'grade-jad',
              state: PaperGradeState.ready,
              version: 3,
              mark: GradeMark.absent,
              feedback: 'Away',
            ),
          ),
          _row(
            'lina',
            'Lina',
            const PaperGrade(
              id: 'grade-lina',
              state: PaperGradeState.published,
              version: 5,
              mark: GradeMark.absent,
            ),
          ),
        ],
      );

  @override
  Future<PublishedGrades> publishGrades(
    String assessmentId,
    int gradebookVersion,
  ) async {
    published.add(gradebookVersion);
    return const PublishedGrades(published: 1, unmarked: 2);
  }

  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw UnimplementedError('${invocation.memberName} is not faked');
}
