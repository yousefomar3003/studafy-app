import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:studafy/core/studafy_formatting.dart';
import 'package:studafy/features/academic/data/preview_marking_repository.dart';
import 'package:studafy/features/academic/data/preview_online_assessments.dart';
import 'package:studafy/features/academic/domain/academic_repository.dart';
import 'package:studafy/features/academic/domain/marking.dart';
import 'package:studafy/features/academic/presentation/assessment_marking_page.dart';
import 'package:studafy/features/academic/presentation/marking_opt_out_switch.dart';
import 'package:studafy/features/academic/presentation/marking_plan_page.dart';
import 'package:studafy/features/academic/presentation/marking_references_page.dart';
import 'package:studafy/features/academic/presentation/marking_scope.dart';
import 'package:studafy/features/academic/presentation/paper_gradebook_page.dart';

import '../../support/accessibility.dart';
import '../../support/localized_app.dart';

/// Studafy AI Marking on the teacher's screens (ADR-0046). Who may read a
/// reference or a suggestion, the plan check and a student's opt-out are
/// the server's (supabase/tests/marking_suggestions.sql and the API's
/// marking routes); these check what the screens show and send - above all
/// that a suggestion only ever fills in the teacher's own fields.

MarkingPlan _plan({bool active = true, bool available = true}) => MarkingPlan(
  active: active,
  teacher: true,
  available: available,
  used: 1000,
  total: 4000000,
  resetsAt: DateTime.utc(2026, 11),
);

/// The preview repository, recording what the screens send.
class _Marking extends PreviewMarkingRepository {
  _Marking({super.plan, super.references, super.suggestions, this.stale = 0});

  /// What the next save says about suggestions made earlier.
  final int stale;
  final saves = <(MarkingStrictness?, List<MarkingReferenceUpdate>)>[];
  final requests = <(bool, List<String>?)>[];
  final dismissed = <String>[];
  final preferences = <bool>[];

  @override
  Future<MarkingReferencesSaved> saveReferences(
    String assessmentId, {
    MarkingStrictness? strictness,
    List<MarkingReferenceUpdate> updates = const [],
  }) async {
    saves.add((strictness, updates));
    final saved = await super.saveReferences(
      assessmentId,
      strictness: strictness,
      updates: updates,
    );
    return MarkingReferencesSaved(
      references: saved.references,
      changed: saved.changed,
      staleSuggestions: stale,
    );
  }

  @override
  Future<MarkingRun> requestSuggestions(
    String assessmentId, {
    bool all = false,
    List<String>? studentIds,
  }) async {
    requests.add((all, studentIds));
    await super.requestSuggestions(
      assessmentId,
      all: all,
      studentIds: studentIds,
    );
    return const MarkingRun(queued: 3, optedOut: 1, replaced: 0);
  }

  @override
  Future<void> dismiss(String suggestionId) async {
    dismissed.add(suggestionId);
    await super.dismiss(suggestionId);
  }

  @override
  Future<bool> setOptedOut(bool optedOut) async {
    preferences.add(optedOut);
    return super.setOptedOut(optedOut);
  }
}

const _choice = MarkingReference(
  questionId: 'q1',
  position: 1,
  kind: QuestionKind.singleChoice,
  prompt: 'What is 1/2 + 1/4?',
  maximumScore: 2,
  correctOptionIds: ['a'],
);

const _short = MarkingReference(
  questionId: 'q3',
  position: 3,
  kind: QuestionKind.shortAnswer,
  prompt: 'Name the denominator of 3/4.',
  maximumScore: 1,
  acceptedAnswers: ['4', 'four'],
);

const _essay = MarkingReference(
  questionId: 'q2',
  position: 2,
  kind: QuestionKind.essay,
  prompt: 'Explain how you added them.',
  maximumScore: 3,
  preferredAnswer: 'Make the denominators the same, then add.',
  keyPoints: [MarkingKeyPoint(text: 'Uses a common denominator', marks: 2)],
);

MarkingReferences _online() => const MarkingReferences(
  delivery: 'online',
  strictness: MarkingStrictness.balanced,
  referenceVersion: 1,
  references: [_choice, _essay, _short],
);

MarkingSuggestion _suggestion(
  String attemptId, {
  String studentId = 'student-1',
  String? questionId = 'q2',
  bool stale = false,
  MarkingSuggestionStatus status = MarkingSuggestionStatus.ready,
}) => MarkingSuggestion(
  id: 'suggestion-$studentId',
  studentId: studentId,
  attemptId: attemptId,
  questionId: questionId,
  status: status,
  maximumScore: 3,
  suggestedScore: 2,
  met: const ['Uses a common denominator'],
  missed: const ['Does not simplify the answer'],
  rationale: 'Quarters shows the common denominator but not the sum.',
  feedback: 'Good start: now add the quarters.',
  reviewReason: MarkingReviewReason.ambiguous,
  referenceVersion: 1,
  strictness: MarkingStrictness.balanced,
  stale: stale,
);

void _size(WidgetTester tester, Size size) {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
}

Widget _scoped(_Marking marking, Widget home, {Locale? locale}) => localizedApp(
  locale: locale,
  home: home,
  scopes: (child) => MarkingScope(
    services: MarkingServices(repository: marking, preference: marking),
    child: child,
  ),
);

/// A submitted attempt of a choice and an essay; answers the assessment's
/// id and the attempt's.
Future<(String, String)> _attempt(PreviewOnlineAssessments repository) async {
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
  return (created.id, (await repository.attempts(created.id)).single.id);
}

/// The preview assessments, counting every save of a mark.
class _Saves extends PreviewOnlineAssessments {
  _Saves() : super(onCreated: (_) {});

  int saves = 0;

  @override
  Future<AttemptDetail> markAttempt(
    String attemptId,
    List<AnswerMark> marks, {
    String? feedback,
    String? correctionReason,
  }) {
    saves++;
    return super.markAttempt(attemptId, marks, feedback: feedback);
  }
}

Future<(_Saves, _Marking, String)> _openReview(
  WidgetTester tester, {
  Locale? locale,
  bool stale = false,
}) async {
  final repository = _Saves();
  final (assessmentId, attemptId) = await _attempt(repository);
  final studentId = (await repository.attempt(attemptId)).studentId;
  final marking = _Marking(
    plan: _plan(),
    references: {assessmentId: _online()},
    suggestions: {
      assessmentId: [
        _suggestion(attemptId, studentId: studentId, stale: stale),
      ],
    },
  );
  await tester.pumpWidget(
    _scoped(
      marking,
      MarkAttemptPage(
        repository: repository,
        attemptId: attemptId,
        studentName: 'Amal',
        assessmentId: assessmentId,
      ),
      locale: locale,
    ),
  );
  await tester.pumpAndSettle();
  return (repository, marking, attemptId);
}

void main() {
  group('references', () {
    Future<_Marking> open(WidgetTester tester, {int stale = 0}) async {
      _size(tester, const Size(1000, 2600));
      final marking = _Marking(
        plan: _plan(),
        references: {'exam-1': _online()},
        stale: stale,
      );
      await tester.pumpWidget(
        _scoped(marking, const MarkingReferencesPage(assessmentId: 'exam-1')),
      );
      await tester.pumpAndSettle();
      return marking;
    }

    testWidgets('each kind of question asks for what marks it', (tester) async {
      await open(tester);
      // A choice question is marked by its key: nothing to write.
      expect(
        find.text('Marked automatically by its key. Nothing to add here.'),
        findsOneWidget,
      );
      // A short answer keeps its accepted answers and adds alternatives.
      expect(find.text('Accepted answers'), findsOneWidget);
      expect(find.text('4 / four'), findsOneWidget);
      expect(
        find.widgetWithText(TextField, 'Other accepted answers or methods'),
        findsOneWidget,
      );
      // An essay has the whole reference.
      expect(find.widgetWithText(TextField, 'Model answer'), findsNWidgets(2));
      expect(find.text('Key points'), findsOneWidget);
      expect(
        find.widgetWithText(TextField, 'Uses a common denominator'),
        findsOneWidget,
      );
      expect(
        find.widgetWithText(TextField, 'Other accepted methods'),
        findsOneWidget,
      );
      expect(find.widgetWithText(TextField, 'Partial credit'), findsOneWidget);
      expect(
        find.widgetWithText(TextField, 'Marking guidance'),
        findsNWidgets(2),
      );
      // How strictly to compare, each explained in a line.
      expect(find.text('Lenient'), findsOneWidget);
      expect(find.text('Balanced'), findsOneWidget);
      expect(find.text('Strict'), findsOneWidget);
      expect(
        find.text('Gives credit for each key point that is clearly there.'),
        findsOneWidget,
      );
    });

    testWidgets('key points may not add up to more than the question is '
        'worth', (tester) async {
      final marking = await open(tester);
      await tester.tap(find.text('Add key point'));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.widgetWithText(TextField, 'Key point 2'),
        'Adds the quarters',
      );
      await tester.enterText(find.widgetWithText(TextField, 'Marks').last, '2');
      await tester.pumpAndSettle();
      expect(
        find.text('Key points add up to 4, more than the 3 this is worth.'),
        findsOneWidget,
      );
      await tester.tap(find.text('Save references'));
      await tester.pumpAndSettle();
      expect(
        find.text('Fix the highlighted key points, then save.'),
        findsOneWidget,
      );
      expect(marking.saves, isEmpty, reason: 'nothing is sent');

      await tester.enterText(find.widgetWithText(TextField, 'Marks').last, '1');
      await tester.tap(find.text('Strict'));
      await tester.pumpAndSettle();
      expect(find.text('Key points add up to 3 of 3'), findsOneWidget);
      await tester.tap(find.text('Save references'));
      await tester.pumpAndSettle();
      final (strictness, updates) = marking.saves.single;
      expect(strictness, MarkingStrictness.strict);
      // Only the reference that changed, and only what changed in it.
      expect(updates.single.questionId, 'q2');
      expect(updates.single.preferredAnswer, isNull);
      expect(updates.single.keyPoints, const [
        MarkingKeyPoint(text: 'Uses a common denominator', marks: 2),
        MarkingKeyPoint(text: 'Adds the quarters', marks: 1),
      ]);
      expect(
        find.text('Saved. New suggestions use this reference.'),
        findsOneWidget,
      );
    });

    testWidgets('after a change, older suggestions are named and can be '
        'asked for again - never re-marked by themselves', (tester) async {
      final marking = await open(tester, stale: 2);
      expect(
        find.text(
          'Changing a reference never changes a mark or a suggestion by '
          'itself.',
        ),
        findsOneWidget,
      );
      await tester.enterText(
        find.widgetWithText(TextField, 'Partial credit'),
        '1 mark for the method.',
      );
      await tester.tap(find.text('Save references'));
      await tester.pumpAndSettle();
      expect(
        find.text('2 suggestions were made with an older reference.'),
        findsOneWidget,
      );
      expect(marking.requests, isEmpty);
      await tester.tap(find.text('Suggest again'));
      await tester.pumpAndSettle();
      expect(marking.requests.single.$1, isTrue);
      expect(find.text('3 suggestions are on their way.'), findsOneWidget);
    });
  });

  group('review', () {
    testWidgets('question, reference, answer and suggestion sit side by side '
        'on a wide screen', (tester) async {
      _size(tester, const Size(1400, 3000));
      await _openReview(tester);
      for (final text in [
        'Explain how you added them.',
        'Your reference',
        'Make the denominators the same, then add.',
        'Uses a common denominator (worth 2)',
        "Student's answer",
        'Suggested mark',
        '2 of 3',
        'Does not simplify the answer',
        'Quarters shows the common denominator but not the sum.',
        'Good start: now add the quarters.',
        'Needs your review',
        'The answer is unclear.',
      ]) {
        expect(find.text(text), findsWidgets, reason: text);
      }
      final reference = tester.getTopLeft(find.text('Your reference'));
      final answer = tester.getTopLeft(find.text("Student's answer").last);
      final suggestion = tester.getTopLeft(find.text('Suggested mark'));
      expect(reference.dy, answer.dy);
      expect(answer.dy, suggestion.dy);
      expect(reference.dx, lessThan(answer.dx));
      expect(answer.dx, lessThan(suggestion.dx));
    });

    testWidgets('on a phone they are one under the other', (tester) async {
      _size(tester, const Size(400, 4000));
      await _openReview(tester);
      final question = tester.getTopLeft(
        find.text('Explain how you added them.'),
      );
      final reference = tester.getTopLeft(find.text('Your reference'));
      final answer = tester.getTopLeft(find.text("Student's answer").last);
      final suggestion = tester.getTopLeft(find.text('Suggested mark'));
      expect(question.dy, lessThan(reference.dy));
      expect(reference.dy, lessThan(answer.dy));
      expect(answer.dy, lessThan(suggestion.dy));
    });

    testWidgets('Use suggestion fills in the fields and saves nothing', (
      tester,
    ) async {
      _size(tester, const Size(1400, 3000));
      final (repository, _, attemptId) = await _openReview(tester);
      expect(
        find.text(
          'Suggestions are drafts. Nothing is saved until you save it.',
        ),
        findsNothing,
        reason: 'the list page says it; here the fields do',
      );
      await tester.tap(find.text('Use suggestion'));
      await tester.pumpAndSettle();
      final score = find.widgetWithText(TextField, 'Score (out of 3)');
      expect(tester.widget<TextField>(score).controller!.text, '2');
      expect(
        tester
            .widget<TextField>(
              find.widgetWithText(TextField, 'Comment on this answer').last,
            )
            .controller!
            .text,
        'Good start: now add the quarters.',
      );
      expect(
        find.text('Filled in from the suggestion. Check it, then save.'),
        findsOneWidget,
      );
      expect(repository.saves, 0, reason: 'only the Save button saves');
      expect((await repository.attempt(attemptId)).awardedScore, isNull);

      // The teacher's own save is the one that writes the mark.
      await tester.tap(find.text('Save draft'));
      await tester.pumpAndSettle();
      expect(repository.saves, 1);
    });

    testWidgets('a suggestion can be dismissed', (tester) async {
      _size(tester, const Size(1400, 3000));
      final (_, marking, _) = await _openReview(tester);
      await tester.tap(find.text('Dismiss'));
      await tester.pumpAndSettle();
      expect(marking.dismissed, hasLength(1));
      expect(find.text('Suggested mark'), findsNothing);
      expect(find.text('Your reference'), findsOneWidget);
    });

    testWidgets('a suggestion from an older reference says so', (tester) async {
      _size(tester, const Size(1400, 3000));
      final (_, marking, _) = await _openReview(tester, stale: true);
      expect(find.text('Made with an older reference'), findsOneWidget);
      await tester.tap(find.text('Suggest again'));
      await tester.pumpAndSettle();
      expect(marking.requests.single.$1, isTrue);
      expect(marking.requests.single.$2, hasLength(1));
    });
  });

  group('Suggest marks', () {
    Future<_Marking> openList(
      WidgetTester tester,
      MarkingPlan plan, {
      bool scoped = true,
    }) async {
      _size(tester, const Size(1200, 2600));
      final repository = _Saves();
      final (assessmentId, _) = await _attempt(repository);
      final marking = _Marking(plan: plan);
      final page = _ListPage(repository, assessmentId);
      await tester.pumpWidget(
        scoped ? _scoped(marking, page) : localizedApp(home: page),
      );
      await tester.pumpAndSettle();
      return marking;
    }

    testWidgets('is not offered where the server cannot make suggestions', (
      tester,
    ) async {
      await openList(tester, _plan(available: false));
      expect(find.text('Suggest marks'), findsNothing);
      expect(find.text('Suggested marks'), findsNothing);
    });

    testWidgets('is not offered without the marking slice', (tester) async {
      await openList(tester, _plan(), scoped: false);
      expect(find.text('Suggest marks'), findsNothing);
    });

    testWidgets('without the plan it opens the plan, and asks nothing', (
      tester,
    ) async {
      final marking = await openList(tester, _plan(active: false));
      await tester.tap(find.text('Suggest marks'));
      await tester.pumpAndSettle();
      expect(find.byType(MarkingPlanPage), findsOneWidget);
      expect(find.text(studafyPlanName('Studafy AI Marking')), findsOneWidget);
      expect(find.text('Not subscribed'), findsOneWidget);
      expect(marking.requests, isEmpty);
    });

    testWidgets('with the plan it asks for unmarked work by default and says '
        'what happened', (tester) async {
      final marking = await openList(tester, _plan());
      expect(
        find.text(
          'Suggestions are drafts. Nothing is saved until you save it.',
        ),
        findsOneWidget,
      );
      await tester.tap(find.text('Suggest marks'));
      await tester.pumpAndSettle();
      expect(find.text('Work with no mark yet'), findsOneWidget);
      await tester.tap(find.widgetWithText(FilledButton, 'Suggest'));
      await tester.pumpAndSettle();
      expect(marking.requests.single, (false, null));
      expect(find.text('3 suggestions are on their way.'), findsOneWidget);
      expect(
        find.text(
          '1 was not sent because the student turned this off. Mark it by '
          'hand.',
        ),
        findsOneWidget,
      );
    });

    testWidgets('"all" replaces earlier suggestions', (tester) async {
      final marking = await openList(tester, _plan());
      await tester.tap(find.text('Suggest marks'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('All work, replacing earlier suggestions'));
      await tester.tap(find.widgetWithText(FilledButton, 'Suggest'));
      await tester.pumpAndSettle();
      expect(marking.requests.single.$1, isTrue);
    });
  });

  testWidgets('a hand-in suggestion fills in the row of the grade sheet and '
      'saves nothing', (tester) async {
    _size(tester, const Size(1200, 2600));
    final sheet = _Sheet();
    final marking = _Marking(
      plan: _plan(),
      suggestions: {
        'mark-1': [
          const MarkingSuggestion(
            id: 'hand-in-1',
            studentId: 's1',
            submissionAttemptId: 'sub-1',
            status: MarkingSuggestionStatus.ready,
            maximumScore: 20,
            suggestedScore: 15,
            feedback: 'Clear plan; check the last step.',
            referenceVersion: 1,
            strictness: MarkingStrictness.balanced,
          ),
        ],
      },
    );
    await tester.pumpWidget(
      _scoped(
        marking,
        PaperGradebookPage(
          repository: sheet,
          assessmentId: 'mark-1',
          handIn: true,
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('15 of 20'), findsOneWidget);
    await tester.tap(find.text('Use suggestion'));
    await tester.pumpAndSettle();
    expect(find.widgetWithText(TextField, '15'), findsOneWidget);
    expect(find.text('Clear plan; check the last step.'), findsWidgets);
    expect(sheet.saves, 0);
    await tester.tap(find.text('Save draft'));
    await tester.pumpAndSettle();
    expect(sheet.saves, 1);
    expect(sheet.saved.single.score, 15);
  });

  group('a student opting out', () {
    testWidgets('is on by default and the switch tells the server', (
      tester,
    ) async {
      final marking = _Marking();
      await tester.pumpWidget(
        localizedApp(
          home: Scaffold(body: MarkingOptOutSwitch(preference: marking)),
        ),
      );
      await tester.pumpAndSettle();
      expect(
        find.text('Let my teachers use AI to suggest marks on my work'),
        findsOneWidget,
      );
      final toggle = find.byKey(const ValueKey('marking-opt-out-switch'));
      expect(tester.widget<Switch>(toggle).value, isTrue);
      await tester.tap(toggle);
      await tester.pumpAndSettle();
      expect(marking.preferences, [true]);
      expect(tester.widget<Switch>(toggle).value, isFalse);
      expect(
        find.text(
          'Off: your work is never sent to AI. Your teacher marks it by hand.',
        ),
        findsOneWidget,
      );
      await tester.tap(toggle);
      await tester.pumpAndSettle();
      expect(marking.preferences, [true, false]);
    });
  });

  // Launch plan 7.1, in both languages. Contrast is checked in English with
  // the same colours: on CI's Linux test font some Arabic words render too
  // thin to sample.
  for (final locale in const [Locale('en'), Locale('ar')]) {
    final contrast = locale.languageCode == 'en';
    testWidgets('the review is accessible: ${locale.languageCode}', (
      tester,
    ) async {
      final semantics = tester.ensureSemantics();
      _size(tester, const Size(400, 4000));
      await _openReview(tester, locale: locale, stale: true);
      expect(tester.takeException(), isNull);
      await expectAccessible(tester, contrast: contrast);
      semantics.dispose();
    });

    testWidgets('the references are accessible: ${locale.languageCode}', (
      tester,
    ) async {
      final semantics = tester.ensureSemantics();
      _size(tester, const Size(400, 4000));
      await tester.pumpWidget(
        _scoped(
          _Marking(plan: _plan(), references: {'exam-1': _online()}),
          const MarkingReferencesPage(assessmentId: 'exam-1'),
          locale: locale,
        ),
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      await expectAccessible(tester, contrast: contrast);
      semantics.dispose();
    });

    testWidgets('the plan is accessible: ${locale.languageCode}', (
      tester,
    ) async {
      final semantics = tester.ensureSemantics();
      _size(tester, const Size(400, 2000));
      final marking = _Marking(plan: _plan());
      await tester.pumpWidget(
        localizedApp(
          locale: locale,
          home: MarkingPlanPage(services: MarkingServices(repository: marking)),
        ),
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      // Held: this month's allowance, as a bar and a label.
      expect(find.byType(MarkingAllowance), findsOneWidget);
      await expectAccessible(tester, contrast: contrast);
      semantics.dispose();
    });
  }
}

/// The marking list for one assessment, from preview assessments: the
/// attempts are theirs, and the class has nobody else.
class _ListPage extends StatelessWidget {
  const _ListPage(this.repository, this.assessmentId);

  final PreviewOnlineAssessments repository;
  final String assessmentId;

  @override
  Widget build(BuildContext context) => AssessmentMarkingPage(
    repository: _ListAcademic(repository),
    assessmentId: assessmentId,
    title: 'Fractions quiz',
    classroomId: 'class-1',
  );
}

class _ListAcademic implements AcademicRepository {
  _ListAcademic(this.online);

  final PreviewOnlineAssessments online;

  @override
  Future<List<AttemptDetail>> attempts(String assessmentId) =>
      online.attempts(assessmentId);

  @override
  Future<List<AcademicRecord>> load(
    AcademicFeed feed, {
    String? classroomId,
    String? studentId,
  }) async => const [];

  @override
  Future<PaperGradebook> paperGradebook(String assessmentId) async =>
      const PaperGradebook(
        item: PaperGradebookItem(
          id: 'exam-1',
          title: 'Fractions quiz',
          category: 'quiz',
          maximumScore: 5,
          state: 'published',
          version: 1,
          gradebookVersion: 1,
          unmarked: 1,
          ready: 0,
          published: 0,
        ),
        rows: [],
      );

  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw UnimplementedError('${invocation.memberName} is not faked');
}

/// A grade sheet for a graded assignment's hand-ins, counting saves.
class _Sheet implements AcademicRepository {
  int saves = 0;
  List<GradeDraft> saved = const [];

  @override
  Future<PaperGradebook> paperGradebook(String assessmentId) async =>
      const PaperGradebook(
        item: PaperGradebookItem(
          id: 'mark-1',
          title: 'Fractions project',
          category: 'assignment',
          maximumScore: 20,
          state: 'published',
          version: 1,
          gradebookVersion: 2,
          unmarked: 0,
          ready: 0,
          published: 0,
        ),
        rows: [
          PaperGradebookRow(
            studentId: 's1',
            displayName: 'Amal',
            enrolled: true,
          ),
        ],
      );

  @override
  Future<int> saveGradeDrafts(
    String assessmentId,
    int gradebookVersion,
    List<GradeDraft> entries,
  ) async {
    saves++;
    saved = entries;
    return gradebookVersion + 1;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw UnimplementedError('${invocation.memberName} is not faked');
}
