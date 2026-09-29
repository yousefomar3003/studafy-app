import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:studafy/features/academic/domain/academic_repository.dart';
import 'package:studafy/features/academic/presentation/academic_overview_page.dart';

import '../../support/localized_app.dart';

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
  Future<void> submitAssignment(
    String assignmentId,
    String answer, {
    List<String> attachmentFileIds = const [],
    String? studentId,
  }) async {
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
  Future<List<ClassSessionSlot>> classroomSchedule(String classroomId) async =>
      const [];
  @override
  Future<List<SubmittedWork>> submissionsFor(String assignmentId) async =>
      const [];
  @override
  Future<List<SubmissionAttempt>> submissionHistory(
    String assignmentId, {
    String? studentId,
  }) async => const [];
  @override
  Future<void> replaceSchedule(
    String classroomId,
    int expectedVersion,
    List<ClassSessionSlot> slots,
  ) async {}
  @override
  Future<void> archiveClassroom(
    String classroomId,
    int expectedVersion,
  ) async {}
  @override
  Future<List<LessonSession>> lessonSessions(String classroomId) async =>
      const [];
  @override
  Future<void> closeLessonSession(String lessonSessionId) async {}
  @override
  Future<List<GradeEntry>> gradeEntries(String classroomId) async => const [];
  @override
  Future<List<ClassStudent>> classStudents(String classroomId) async =>
      const [];
  @override
  Future<AttendanceRegister> attendanceRoster(
    String classroomId,
    DateTime date, {
    DateTime? startsAt,
  }) async => const AttendanceRegister(entries: [], version: 0);
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
      localizedApp(home: AcademicOverviewPage(repository: repository)),
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
      localizedApp(home: AcademicOverviewPage(repository: repository)),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Grades'));
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
      localizedApp(home: AcademicOverviewPage(repository: repository)),
    );
    await tester.pumpAndSettle();

    expect(find.textContaining('No local copy was saved'), findsOneWidget);

    repository.error = null;
    repository.records.addAll(records);
    await tester.tap(find.text('Retry'));
    await tester.pumpAndSettle();
    expect(find.text('Atomic models'), findsOneWidget);
  });

  testWidgets('inside a class, a teacher adds a lesson to it', (tester) async {
    final repository = _FakeAcademicRepository(const []);
    await tester.pumpWidget(
      localizedApp(
        home: AcademicOverviewPage(
          repository: repository,
          classroomId: '22222222-2222-4222-8222-222222222222',
          title: 'Biology 7A',
          teacherTools: true,
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Lessons'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Add lesson'));
    await tester.pumpAndSettle();

    await tester.enterText(
      find.widgetWithText(TextField, 'Lesson title'),
      'Photosynthesis',
    );
    await tester.enterText(
      find.widgetWithText(TextField, 'Lesson notes'),
      'Light in.',
    );
    await tester.ensureVisible(find.widgetWithText(FilledButton, 'Add lesson'));
    await tester.tap(find.widgetWithText(FilledButton, 'Add lesson'));
    await tester.pumpAndSettle();

    final draft = repository.drafts.single as TextResourceDraft;
    expect(draft.title, 'Photosynthesis');
    expect(draft.body, 'Light in.');
    expect(draft.classroomId, '22222222-2222-4222-8222-222222222222');
    expect(draft.audience, 'both');
    expect(find.text('Lesson added.'), findsOne);
  });

  testWidgets('on the all-classes tab, the class being viewed is preselected', (
    tester,
  ) async {
    // The reported bug: here the button was always disabled, so a teacher
    // had nowhere to add a lesson at all.
    final repository = _FakeAcademicRepository(const []);
    await tester.pumpWidget(
      localizedApp(
        home: AcademicOverviewPage(
          repository: repository,
          teacherTools: true,
          initialFeed: AcademicFeed.content,
          loadClassChoices: () async => const [
            ClassChoice(
              id: '33333333-3333-4333-8333-333333333333',
              name: 'Maths',
            ),
            ClassChoice(
              id: '44444444-4444-4444-8444-444444444444',
              name: 'Art',
            ),
          ],
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Art'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Add lesson'));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.widgetWithText(TextField, 'Lesson title'),
      'Colour wheel',
    );
    await tester.enterText(
      find.widgetWithText(TextField, 'Lesson notes'),
      'Primary colours.',
    );
    await tester.ensureVisible(find.widgetWithText(FilledButton, 'Add lesson'));
    await tester.tap(find.widgetWithText(FilledButton, 'Add lesson'));
    await tester.pumpAndSettle();

    final draft = repository.drafts.single as TextResourceDraft;
    expect(draft.classroomId, '44444444-4444-4444-8444-444444444444');
  });

  testWidgets('with no class at all, the lesson control is disabled', (
    tester,
  ) async {
    await tester.pumpWidget(
      localizedApp(
        home: AcademicOverviewPage(
          repository: _FakeAcademicRepository(const []),
          teacherTools: true,
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Lessons'));
    await tester.pumpAndSettle();

    final button = tester.widget<FilledButton>(
      find.widgetWithText(FilledButton, 'Add lesson'),
    );
    expect(button.onPressed, isNull);
  });
}
