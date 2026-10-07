import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:studafy/features/academic/domain/academic_repository.dart';
import 'package:studafy/features/academic/presentation/assessment_marking_page.dart';
import 'package:studafy/features/academic/presentation/gradebook_home_page.dart';
import 'package:studafy/features/academic/presentation/paper_gradebook_page.dart';

import '../../support/localized_app.dart';

/// The Gradebook tab is the one place for marks: by class, then by piece of
/// graded work, each saying whether it is a draft or published.
void main() {
  const maths = ClassChoice(id: 'class-maths', name: 'Maths 9A');
  const art = ClassChoice(id: 'class-art', name: 'Art 9A');

  Future<_Academic> open(
    WidgetTester tester, {
    void Function(AcademicRecord)? onOpenAssignment,
  }) async {
    tester.view.physicalSize = const Size(1200, 2600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final academic = _Academic();
    await tester.pumpWidget(
      localizedApp(
        home: GradebookHomePage(
          repository: academic,
          loadClassChoices: () async => const [maths, art],
          onOpenAssignment: onOpenAssignment,
        ),
      ),
    );
    await tester.pumpAndSettle();
    return academic;
  }

  testWidgets('online work opens its submissions; paper work its grade '
      'sheet', (tester) async {
    await open(tester);
    await tester.tap(find.text('Quiz 1'));
    await tester.pumpAndSettle();
    // Where each student's answers are read and marked - not a list of
    // bare score boxes.
    expect(find.byType(AssessmentMarkingPage), findsOneWidget);
    expect(find.text('No one has submitted yet.'), findsOneWidget);
    await tester.pageBack();
    await tester.pumpAndSettle();
    await tester.tap(find.text('Midterm (paper)'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.byType(PaperGradebookPage), findsOneWidget);
  });

  testWidgets('marks are grouped paper and online, draft or published', (
    tester,
  ) async {
    final academic = await open(tester);

    expect(academic.loads.first, (AcademicFeed.assessments, 'class-maths'));
    expect(find.text('Paper work'), findsOne);
    expect(find.text('Online work'), findsOne);
    expect(find.text('Midterm (paper)'), findsOne);
    expect(find.text('Quiz 1'), findsOne);
    // The state is in words, not colour alone.
    expect(find.text('Draft'), findsOne);
    expect(find.text('Published'), findsOne);
    expect(find.text('New paper grade'), findsOne);
    expect(find.text('Mark online work'), findsOne);
  });

  testWidgets('choosing another class reads that class', (tester) async {
    final academic = await open(tester);
    await tester.tap(find.text('Art 9A'));
    await tester.pumpAndSettle();
    expect(academic.loads.last.$2, 'class-art');
  });

  testWidgets('a mark links back to the hand-ins it grades', (tester) async {
    final opened = <AcademicRecord>[];
    await open(tester, onOpenAssignment: opened.add);
    await tester.tap(find.text('View hand-ins'));
    expect(opened.single.id, 'assignment-1');
  });
}

class _Academic implements AcademicRepository {
  @override
  Future<List<AttemptDetail>> attempts(String assessmentId) async => const [];

  /// Online work's roster is empty here; the paper sheet stays loading, as
  /// only its opening is under test.
  @override
  Future<PaperGradebook> paperGradebook(String assessmentId) =>
      assessmentId == 'assessment-paper'
      ? Completer<PaperGradebook>().future
      : Future.value(
          const PaperGradebook(
            item: PaperGradebookItem(
              id: 'assessment-online',
              title: 'Quiz 1',
              category: 'quiz',
              maximumScore: 10,
              state: 'published',
              version: 2,
              gradebookVersion: 1,
              unmarked: 0,
              ready: 0,
              published: 0,
            ),
            rows: [],
          ),
        );

  final loads = <(AcademicFeed, String?)>[];

  @override
  Future<List<AcademicRecord>> load(
    AcademicFeed feed, {
    String? classroomId,
    String? studentId,
  }) async {
    loads.add((feed, classroomId));
    return switch (feed) {
      AcademicFeed.assessments => const [
        AcademicRecord(
          id: 'assessment-paper',
          title: 'Midterm (paper)',
          detail: '',
          state: 'draft',
          version: 1,
          delivery: 'paper',
          maximumScore: 50,
        ),
        AcademicRecord(
          id: 'assessment-online',
          title: 'Quiz 1',
          detail: '',
          state: 'published',
          version: 2,
          delivery: 'online',
          maximumScore: 10,
          markedAssignmentId: 'assignment-1',
        ),
      ],
      AcademicFeed.assignments => const [
        AcademicRecord(
          id: 'assignment-1',
          title: 'Quiz 1 hand-in',
          detail: '',
          state: 'published',
          version: 1,
        ),
      ],
      _ => const [],
    };
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
