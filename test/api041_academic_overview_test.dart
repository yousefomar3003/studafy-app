import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:studafy/features/academic/domain/academic_repository.dart';
import 'package:studafy/features/academic/presentation/academic_overview_page.dart';

class _FakeAcademicRepository implements AcademicRepository {
  _FakeAcademicRepository(List<AcademicRecord> records, {this.error})
    : records = List<AcademicRecord>.of(records);

  final List<AcademicRecord> records;
  Object? error;
  final loads = <(AcademicFeed, String?, String?)>[];
  final drafts = <Object>[];

  @override
  Future<List<AcademicRecord>> load(
    AcademicFeed feed, {
    String? classroomId,
    String? studentId,
  }) async {
    loads.add((feed, classroomId, studentId));
    if (error != null) throw error!;
    return records;
  }

  @override
  Future<void> createResource(TextResourceDraft draft) async {
    drafts.add(draft);
  }

  @override
  Future<void> reviseResource(
    String resourceId,
    int expectedVersion,
    String title,
    String body,
  ) async {
    drafts.add(resourceId);
  }

  @override
  Future<void> publishResource(String resourceId, int expectedVersion) async {
    drafts.add(resourceId);
  }

  @override
  Future<void> withdrawResource(String resourceId, int expectedVersion) async {
    drafts.add(resourceId);
  }

  @override
  Future<void> createAssignment(AssignmentDraft draft) async {
    drafts.add(draft);
  }

  @override
  Future<void> publishAssignment(
    String assignmentId,
    int expectedVersion,
  ) async {
    drafts.add(assignmentId);
  }

  @override
  Future<void> withdrawAssignment(
    String assignmentId,
    int expectedVersion,
  ) async {
    drafts.add(assignmentId);
  }

  @override
  Future<void> createAssessment(AssessmentDraft draft) async {
    drafts.add(draft);
  }

  @override
  Future<void> publishAssessment(
    String assessmentId,
    int expectedVersion,
  ) async {
    drafts.add(assessmentId);
  }

  @override
  Future<void> withdrawAssessment(
    String assessmentId,
    int expectedVersion,
  ) async {
    drafts.add(assessmentId);
  }

  @override
  Future<void> submitAssignment(String assignmentId, String answer) async {
    drafts.add(assignmentId);
  }

  @override
  Future<void> submitAssessment(
    String assessmentId,
    Map<String, String> answers,
  ) async {
    drafts.add(assessmentId);
  }

  @override
  Future<void> recordAttendance(
    String classroomId,
    DateTime startsAt,
    DateTime endsAt,
    int expectedVersion,
    List<AttendanceDraft> entries,
  ) async {
    drafts.add(classroomId);
  }

  @override
  Future<void> reviewGrade(
    String gradeId,
    int expectedVersion,
    double score, {
    String? feedback,
  }) async {
    drafts.add(gradeId);
  }

  @override
  Future<void> publishGrade(String gradeId, int expectedVersion) async {
    drafts.add(gradeId);
  }

  @override
  Future<void> correctGrade(
    String gradeId,
    int expectedVersion,
    double score,
    String reason, {
    String? feedback,
  }) async {
    drafts.add(gradeId);
  }

  @override
  Future<void> withdrawGrade(String gradeId, int expectedVersion) async {
    drafts.add(gradeId);
  }

  @override
  Future<void> createWellbeing(WellbeingDraft draft) async {
    drafts.add(draft);
  }
}

const records = [
  AcademicRecord(
    id: '44444444-4444-4444-8444-444444444444',
    title: 'Atomic models',
    detail: 'Draw and label.',
    state: 'published',
    version: 2,
  ),
  AcademicRecord(
    id: '66666666-6666-4666-8666-666666666666',
    title: 'Cell diagrams',
    detail: 'Label the organelles.',
    state: 'draft',
    version: 1,
  ),
];

void main() {
  testWidgets('renders the authoritative feed with state chips', (
    tester,
  ) async {
    final repository = _FakeAcademicRepository(records);
    await tester.pumpWidget(
      MaterialApp(home: AcademicOverviewPage(repository: repository)),
    );
    await tester.pumpAndSettle();

    expect(find.text('Atomic models'), findsOneWidget);
    expect(find.text('Cell diagrams'), findsOneWidget);
    expect(find.byType(Chip), findsNWidgets(2));
    expect(repository.loads.single, (AcademicFeed.assignments, null, null));
  });

  testWidgets('switching feeds reloads through the repository', (tester) async {
    final repository = _FakeAcademicRepository(records);
    await tester.pumpWidget(
      MaterialApp(home: AcademicOverviewPage(repository: repository)),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('grades'));
    await tester.pumpAndSettle();

    expect(repository.loads, hasLength(2));
    expect(repository.loads.last.$1, AcademicFeed.grades);
  });

  testWidgets('a failed load shows the offline state, never a local copy', (
    tester,
  ) async {
    final repository = _FakeAcademicRepository(
      const [],
      error: StateError('offline'),
    );
    await tester.pumpWidget(
      MaterialApp(home: AcademicOverviewPage(repository: repository)),
    );
    await tester.pumpAndSettle();

    expect(find.textContaining('No local copy was saved'), findsOneWidget);

    repository.error = null;
    repository.records.addAll(records);
    await tester.tap(find.text('Retry'));
    await tester.pumpAndSettle();
    expect(find.text('Atomic models'), findsOneWidget);
  });

  testWidgets('teacher tools file a text note and keep input on failure', (
    tester,
  ) async {
    final repository = _FakeAcademicRepository(const []);
    await tester.pumpWidget(
      MaterialApp(
        home: AcademicOverviewPage(
          repository: repository,
          classroomId: '22222222-2222-4222-8222-222222222222',
          teacherTools: true,
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('content'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('File text lesson note'));
    await tester.pumpAndSettle();

    await tester.enterText(
      find.widgetWithText(TextField, 'Title'),
      'Photosynthesis',
    );
    await tester.enterText(find.widgetWithText(TextField, 'Note'), 'Light in.');
    await tester.tap(find.text('Save to school'));
    await tester.pump();

    expect(repository.drafts.single, isA<TextResourceDraft>());
    final draft = repository.drafts.single as TextResourceDraft;
    expect(draft.title, 'Photosynthesis');
    expect(draft.body, 'Light in.');
    expect(draft.classroomId, '22222222-2222-4222-8222-222222222222');
  });

  testWidgets('the note control is disabled without a classroom', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: AcademicOverviewPage(
          repository: _FakeAcademicRepository(const []),
          teacherTools: true,
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('content'));
    await tester.pumpAndSettle();

    final button = tester.widget<FilledButton>(
      find.widgetWithText(FilledButton, 'File text lesson note'),
    );
    expect(button.onPressed, isNull);
  });
}
