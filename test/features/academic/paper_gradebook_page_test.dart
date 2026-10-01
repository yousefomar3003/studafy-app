import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:studafy/features/academic/domain/academic_repository.dart';
import 'package:studafy/features/academic/presentation/paper_gradebook_page.dart';

import '../../support/localized_app.dart';

/// The paper grade sheet: who may see what, and which marks are valid, are
/// the server's decisions (supabase/tests/paper_gradebook.sql and the API
/// integration suite). This is what the teacher is shown and what one save or
/// one publish sends.
class _SheetFake implements AcademicRepository {
  _SheetFake(this.sheet);

  PaperGradebook sheet;
  final saves = <(int, List<GradeDraft>)>[];
  final publishes = <int>[];
  final corrections = <(String, List<GradeCorrection>)>[];
  CourseworkRefusal? refuseSave;

  @override
  Future<PaperGradebook> paperGradebook(String assessmentId) async => sheet;

  @override
  Future<int> saveGradeDrafts(
    String assessmentId,
    int gradebookVersion,
    List<GradeDraft> entries,
  ) async {
    if (refuseSave case final refused?) throw refused;
    saves.add((gradebookVersion, entries));
    return gradebookVersion + 1;
  }

  @override
  Future<PublishedGrades> publishGrades(
    String assessmentId,
    int gradebookVersion,
  ) async {
    publishes.add(gradebookVersion);
    return const PublishedGrades(published: 1, unmarked: 1);
  }

  @override
  Future<void> correctGrades(
    String assessmentId,
    String reason,
    List<GradeCorrection> entries,
  ) async => corrections.add((reason, entries));

  @override
  Future<List<GradeChange>> gradeHistory(String gradeId) async => [
    GradeChange(
      change: 'published',
      at: DateTime(2026, 9, 20),
      nextMark: GradeMark.scored,
      nextScore: 15,
      actorName: 'Ms Rana',
    ),
  ];

  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw UnimplementedError('${invocation.memberName} is not faked');
}

PaperGradebookItem _item({int ready = 0, int published = 0}) =>
    PaperGradebookItem(
      id: 'exam-1',
      title: 'Term 1 exam',
      category: 'paper_exam',
      maximumScore: 20,
      state: 'draft',
      version: 1,
      gradebookVersion: 4,
      unmarked: 0,
      ready: ready,
      published: published,
      weight: 30,
    );

PaperGradebook _unmarkedSheet() => PaperGradebook(
  item: _item(),
  rows: const [
    PaperGradebookRow(studentId: 's1', displayName: 'Amal', enrolled: true),
    PaperGradebookRow(studentId: 's2', displayName: 'Bilal', enrolled: true),
  ],
);

Widget _page(_SheetFake fake, {Locale? locale}) => localizedApp(
  locale: locale,
  home: PaperGradebookPage(repository: fake, assessmentId: 'exam-1'),
);

void _tall(WidgetTester tester) {
  tester.view.physicalSize = const Size(1200, 2600);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
}

/// Gives [student] a mark. A score needs nothing chosen - its box is already
/// there; the other marks are in the row's "Other mark" menu.
Future<void> _choose(WidgetTester tester, String student, String mark) async {
  if (mark == 'Score') return;
  final row = find
      .ancestor(of: find.text(student), matching: find.byType(Container))
      .first;
  await tester.tap(
    find.descendant(of: row, matching: find.byTooltip('Other mark')),
  );
  await tester.pumpAndSettle();
  await tester.tap(find.text(mark).last);
}

void main() {
  testWidgets(
    'the whole class is saved as one draft, absence without a score',
    (tester) async {
      _tall(tester);
      final fake = _SheetFake(_unmarkedSheet());
      await tester.pumpWidget(_page(fake));
      await tester.pumpAndSettle();

      expect(find.text('Paper'), findsOneWidget);
      expect(find.text('Counts 30%'), findsOneWidget);
      await _choose(tester, 'Amal', 'Score');
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField).first, '17.5');
      await _choose(tester, 'Bilal', 'Missed the exam');
      await tester.pumpAndSettle();
      await tester.tap(find.text('Save draft'));
      await tester.pumpAndSettle();

      final (version, entries) = fake.saves.single;
      expect(version, 4, reason: 'saved against the sheet the teacher saw');
      expect(entries.map((e) => (e.studentId, e.mark, e.score)).toList(), [
        ('s1', GradeMark.scored, 17.5),
        ('s2', GradeMark.absent, null),
      ]);
      expect(
        find.text('Draft saved. Students and parents can\'t see it yet.'),
        findsOneWidget,
      );
    },
  );

  testWidgets('a mark above the maximum is pointed at and nothing is sent', (
    tester,
  ) async {
    _tall(tester);
    final fake = _SheetFake(_unmarkedSheet());
    await tester.pumpWidget(_page(fake));
    await tester.pumpAndSettle();

    await _choose(tester, 'Amal', 'Score');
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).first, '25');
    await tester.pumpAndSettle();
    await tester.tap(find.text('Save draft'));
    await tester.pumpAndSettle();

    expect(fake.saves, isEmpty);
    expect(find.text('Must be between 0 and 20'), findsOneWidget);
  });

  testWidgets('a row the server refuses is named, and nothing was saved', (
    tester,
  ) async {
    _tall(tester);
    final fake = _SheetFake(_unmarkedSheet())
      ..refuseSave = const CourseworkRefusal(
        CourseworkProblem.entriesInvalid,
        rows: {'s2': 'not_enrolled'},
      );
    await tester.pumpWidget(_page(fake));
    await tester.pumpAndSettle();

    await _choose(tester, 'Bilal', 'Missed the exam');
    await tester.pumpAndSettle();
    await tester.tap(find.text('Save draft'));
    await tester.pumpAndSettle();

    expect(find.text('Some rows need fixing. Nothing was saved.'), findsOne);
    expect(find.text('Not in this class'), findsOneWidget);
  });

  testWidgets('publishing says who will see it and sends the sheet version', (
    tester,
  ) async {
    _tall(tester);
    final fake = _SheetFake(
      PaperGradebook(
        item: _item(ready: 1),
        rows: const [
          PaperGradebookRow(
            studentId: 's1',
            displayName: 'Amal',
            enrolled: true,
            grade: PaperGrade(
              id: 'g1',
              state: PaperGradeState.ready,
              version: 2,
              mark: GradeMark.scored,
              score: 15,
            ),
          ),
          PaperGradebookRow(
            studentId: 's2',
            displayName: 'Bilal',
            enrolled: true,
          ),
        ],
      ),
    );
    await tester.pumpWidget(_page(fake));
    await tester.pumpAndSettle();

    await tester.tap(find.widgetWithText(OutlinedButton, 'Publish'));
    await tester.pumpAndSettle();
    expect(find.text('Publish marks?'), findsOneWidget);
    expect(find.textContaining('1 students without a mark stay'), findsOne);
    await tester.tap(find.widgetWithText(FilledButton, 'Publish'));
    await tester.pumpAndSettle();

    expect(fake.publishes, [4]);
    expect(find.text('1 marks published.'), findsOneWidget);
  });

  testWidgets('unsaved changes must be saved before publishing', (
    tester,
  ) async {
    _tall(tester);
    final fake = _SheetFake(
      PaperGradebook(item: _item(ready: 1), rows: _unmarkedSheet().rows),
    );
    await tester.pumpWidget(_page(fake));
    await tester.pumpAndSettle();

    await _choose(tester, 'Amal', 'Missed the exam');
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(OutlinedButton, 'Publish'));
    await tester.pumpAndSettle();

    expect(fake.publishes, isEmpty);
    expect(find.text('Save your changes before publishing.'), findsOne);
  });

  testWidgets('a published mark is corrected only with a reason', (
    tester,
  ) async {
    _tall(tester);
    final fake = _SheetFake(
      PaperGradebook(
        item: _item(published: 1),
        rows: const [
          PaperGradebookRow(
            studentId: 's1',
            displayName: 'Amal',
            enrolled: true,
            grade: PaperGrade(
              id: 'g1',
              state: PaperGradeState.published,
              version: 3,
              mark: GradeMark.scored,
              score: 15,
            ),
          ),
        ],
      ),
    );
    await tester.pumpWidget(_page(fake));
    await tester.pumpAndSettle();

    // Published marks are not edited in place.
    expect(find.text('15 out of 20'), findsOneWidget);
    await tester.tap(find.text('Correct'));
    await tester.pumpAndSettle();
    expect(find.textContaining('Ms Rana'), findsOneWidget);

    final score = find.widgetWithText(TextField, 'Score');
    await tester.enterText(score, '18');
    await tester.tap(find.text('Save correction'));
    await tester.pumpAndSettle();
    expect(fake.corrections, isEmpty);
    expect(find.text('Give a reason of at least 3 characters.'), findsOne);

    await tester.enterText(
      find.widgetWithText(TextField, 'Reason for the change'),
      'Added up page 3 again',
    );
    await tester.tap(find.text('Save correction'));
    await tester.pumpAndSettle();

    final (reason, entries) = fake.corrections.single;
    expect(reason, 'Added up page 3 again');
    expect(entries.single.gradeId, 'g1');
    expect(entries.single.expectedVersion, 3);
    expect(entries.single.score, 18);
  });

  testWidgets('the sheet reads in Arabic, right to left', (tester) async {
    _tall(tester);
    await tester.pumpWidget(
      _page(_SheetFake(_unmarkedSheet()), locale: const Locale('ar')),
    );
    await tester.pumpAndSettle();

    expect(find.text('حفظ كمسودة'), findsOneWidget);
    // Each row's other marks, in Arabic.
    expect(find.byTooltip('علامة أخرى'), findsNWidgets(2));
    expect(
      Directionality.of(tester.element(find.text('حفظ كمسودة'))),
      TextDirection.rtl,
    );
  });
}
