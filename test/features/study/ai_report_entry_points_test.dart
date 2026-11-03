import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:studafy/core/ai_output_report.dart';
import 'package:studafy/features/study/domain/study.dart';
import 'package:studafy/features/study/domain/study_notebook.dart';
import 'package:studafy/features/study/presentation/note_page.dart';
import 'package:studafy/features/study/presentation/study_set_pages.dart';

import '../../support/localized_app.dart';

/// DL-076: every AI surface in the study slice offers Report - quizzes,
/// flashcards and notes the AI wrote - and a note the student typed does
/// not.
void main() {
  Widget scoped(Widget home, _Reports reports) => localizedApp(
    scopes: (child) => AiOutputReportScope(reporter: reports, child: child),
    home: home,
  );

  Future<void> sendReport(WidgetTester tester) async {
    await tester.pumpAndSettle();
    await tester.tap(find.text('Wrong or misleading'));
    await tester.pump();
    await tester.tap(find.widgetWithText(FilledButton, 'Send'));
    await tester.pumpAndSettle();
  }

  const question = QuizQuestion(
    question: 'What do plants make in light?',
    options: ['Glucose', 'Salt'],
    answerIndex: 0,
    explanation: 'Photosynthesis makes glucose.',
  );

  testWidgets('a quiz is reported with its questions and answers', (
    tester,
  ) async {
    final reports = _Reports();
    await tester.pumpWidget(
      scoped(const QuizPage(title: 'Plants', questions: [question]), reports),
    );
    await tester.tap(find.byTooltip('Report this AI answer'));
    await sendReport(tester);

    final report = reports.sent.single;
    expect(report.feature, AiOutputFeature.quiz);
    expect(report.reason, AiOutputReportReason.wrong);
    expect(report.excerpt, contains('What do plants make in light?'));
    expect(report.excerpt, contains('= Glucose'));
    expect(report.excerpt, contains('Photosynthesis makes glucose.'));
  });

  testWidgets('flashcards are reported with the card on screen', (
    tester,
  ) async {
    final reports = _Reports();
    await tester.pumpWidget(
      scoped(
        const FlashcardsPage(
          title: 'Cells',
          cards: [
            Flashcard(front: 'Nucleus', back: 'Holds the DNA'),
            Flashcard(front: 'Ribosome', back: 'Makes proteins'),
          ],
        ),
        reports,
      ),
    );
    await tester.tap(find.byTooltip('Report this AI answer'));
    await sendReport(tester);

    final report = reports.sent.single;
    expect(report.feature, AiOutputFeature.flashcards);
    expect(report.excerpt, 'Nucleus\nHolds the DNA');
  });

  NotebookEntry note({required bool fromWhiteboard}) => NotebookEntry(
    id: 'note-1',
    classroomId: null,
    title: 'Leaves',
    body: 'Leaves are where photosynthesis happens.',
    fromWhiteboard: fromWhiteboard,
    createdAt: DateTime(2026, 11, 3),
  );

  testWidgets('a note the AI wrote can be reported from its menu', (
    tester,
  ) async {
    final reports = _Reports();
    await tester.pumpWidget(
      scoped(
        NotePage(study: _NoStudy(), entry: note(fromWhiteboard: true)),
        reports,
      ),
    );
    await tester.tap(find.byType(PopupMenuButton<String>));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Report this AI answer'));
    await sendReport(tester);

    final report = reports.sent.single;
    expect(report.feature, AiOutputFeature.notes);
    expect(
      report.excerpt,
      'Leaves\n\nLeaves are where photosynthesis happens.',
    );
  });

  testWidgets('a note the student typed has nothing to report', (tester) async {
    await tester.pumpWidget(
      scoped(
        NotePage(study: _NoStudy(), entry: note(fromWhiteboard: false)),
        _Reports(),
      ),
    );
    await tester.tap(find.byType(PopupMenuButton<String>));
    await tester.pumpAndSettle();
    expect(find.text('Report this AI answer'), findsNothing);
  });

  test('a study notebook is reported as everything the AI wrote', () {
    const content = NotebookContent(
      overview: 'How plants feed.',
      objectives: ['Name the inputs'],
      summary: ['Light makes glucose.'],
    );
    expect(
      content.plainText,
      'How plants feed.\nName the inputs\nLight makes glucose.',
    );
    expect(const NotebookContent().plainText, isEmpty);
  });
}

class _Reports implements AiOutputReporter {
  final List<AiOutputReport> sent = [];

  @override
  Future<void> report(
    AiOutputReport report, {
    required String idempotencyKey,
  }) async => sent.add(report);
}

/// The note page's repository is not used by a report.
class _NoStudy implements StudyRepository {
  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw UnimplementedError(invocation.memberName.toString());
}
