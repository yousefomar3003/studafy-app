import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:studafy/features/academic/domain/academic_repository.dart';
import 'package:studafy/features/academic/presentation/gradebook_home_page.dart';

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
