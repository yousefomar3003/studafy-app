import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:studafy/core/studafy_components.dart';
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
  Future<List<ClassStudent>> classStudents(String classroomId) async => const [
    ClassStudent(
      id: '55555555-5555-4555-8555-555555555555',
      displayName: 'Lina',
      studafyId: 'SJ-LINA0001',
    ),
  ];
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
    List<AttendanceDraft> entries, {
    String? correctionReason,
    bool override = false,
  }) async {
    drafts.add(classroomId);
  }

  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw UnimplementedError('${invocation.memberName} is not faked');

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
    // Each record says its state in words, with an icon.
    expect(find.byType(StatusPill), findsNWidgets(2));
    expect(find.text('Published'), findsOne);
    expect(find.text('Draft'), findsOne);
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

  testWidgets('lessons are added from the "+" menu, not a second button', (
    tester,
  ) async {
    await tester.pumpWidget(
      localizedApp(
        home: AcademicOverviewPage(
          repository: _FakeAcademicRepository(const []),
          classroomId: '22222222-2222-4222-8222-222222222222',
          title: 'Biology 7A',
          teacherTools: true,
          initialFeed: AcademicFeed.content,
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Add lesson'), findsNothing);
    expect(find.textContaining('Tap + to create'), findsOne);
  });

  testWidgets('a teacher writes a wellbeing note from the Wellbeing tab', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1200, 3000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final repository = _FakeAcademicRepository(const []);
    await tester.pumpWidget(
      localizedApp(
        home: AcademicOverviewPage(
          repository: repository,
          classroomId: '22222222-2222-4222-8222-222222222222',
          title: 'Biology 7A',
          teacherTools: true,
          initialFeed: AcademicFeed.wellbeing,
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('New wellbeing note'));
    await tester.pumpAndSettle();
    // Saving with nothing filled in says what is missing.
    await tester.tap(find.text('Save note'));
    await tester.pumpAndSettle();
    expect(find.text('Choose a student'), findsOne);
    expect(find.text('Give the note a short title.'), findsOne);
    expect(repository.drafts, isEmpty);

    await tester.tap(find.text('Student'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Lina').last);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Concern'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Moderate'));
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Title'),
      'Quiet this week',
    );
    await tester.tap(find.text('Staff and parents'));
    await tester.ensureVisible(find.text('Save note'));
    await tester.tap(find.text('Save note'));
    await tester.pumpAndSettle();

    final draft = repository.drafts.single as WellbeingDraft;
    expect(draft.classroomId, '22222222-2222-4222-8222-222222222222');
    expect(draft.studentId, '55555555-5555-4555-8555-555555555555');
    expect(draft.kind, 'concern');
    expect(draft.severity, 'moderate');
    expect(draft.visibility, 'guardian_shared');
    expect(draft.title, 'Quiet this week');
    // Back on the tab, with a confirmation.
    expect(find.text('Wellbeing note saved.'), findsOne);
  });

  testWidgets('students and parents get no wellbeing button', (tester) async {
    await tester.pumpWidget(
      localizedApp(
        home: AcademicOverviewPage(
          repository: _FakeAcademicRepository(const []),
          classroomId: '22222222-2222-4222-8222-222222222222',
          initialFeed: AcademicFeed.wellbeing,
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('New wellbeing note'), findsNothing);
  });

  testWidgets('a student sees work grouped by whether it can still be handed '
      'in, and what a tap does', (tester) async {
    AcademicRecord work(String id, String title, SubmissionWindow? window) =>
        AcademicRecord(
          id: id,
          title: title,
          detail: '',
          state: 'published',
          version: 1,
          deadline: window == null
              ? null
              : SubmissionDeadline(
                  state: window,
                  deadlineLocal: '2026-10-05T23:59',
                  timeZone: 'Asia/Riyadh',
                ),
        );
    final repository = _FakeAcademicRepository([
      work('a', 'Marked essay', SubmissionWindow.gradedLocked),
      work('b', 'Late worksheet', SubmissionWindow.closed),
      work('c', 'Open poster', SubmissionWindow.open),
      work('d', 'Reading log', null),
    ]);
    final opened = <String>[];
    await tester.pumpWidget(
      localizedApp(
        home: AcademicOverviewPage(
          repository: repository,
          title: 'Work',
          subtitle: 'Assignments, tests, grades and attendance',
          availableFeeds: const [AcademicFeed.assignments],
          onOpenRecord: (record) => opened.add(record.id),
        ),
      ),
    );
    await tester.pumpAndSettle();

    // A large title of its own, with no profile button.
    expect(find.text('Work'), findsOne);
    expect(find.byTooltip('Account'), findsNothing);
    // Open work first, then past the deadline, then marked.
    final order = [
      'To do',
      'Open poster',
      'Reading log',
      'Past the deadline',
      'Late worksheet',
    ];
    final tops = [
      for (final text in order) tester.getTopLeft(find.text(text)).dy,
    ];
    expect(tops, orderedEquals([...tops]..sort()));
    // "Published" means nothing to a student; whether it is open does.
    expect(find.text('Published'), findsNothing);
    expect(find.text('Hand in'), findsNWidgets(2));
    // Past the deadline and marked work can be looked at, not handed in.
    expect(find.text('View'), findsNWidgets(2));

    await tester.tap(find.text('Open poster'));
    expect(opened, ['c']);

    await tester.scrollUntilVisible(
      find.text('Marked essay'),
      200,
      scrollable: find
          .descendant(
            of: find.byType(RefreshIndicator),
            matching: find.byType(Scrollable),
          )
          .first,
    );
    expect(find.text('Marked'), findsWidgets);
  });

  testWidgets('a parent filters by child, or sees every child labelled', (
    tester,
  ) async {
    final repository = _FakeAcademicRepository([
      const AcademicRecord(
        id: 'w1',
        title: 'Fractions sheet',
        detail: '',
        state: 'published',
        version: 1,
      ),
    ]);
    final opened = <String?>[];
    await tester.pumpWidget(
      localizedApp(
        home: AcademicOverviewPage(
          repository: repository,
          title: 'Learning',
          subtitle: 'Lessons, work, tests, grades and attendance',
          availableFeeds: const [AcademicFeed.assignments],
          students: const [
            StudentChoice(id: 'layla', name: 'Layla', schoolName: 'Al-Noor'),
            StudentChoice(id: 'omar', name: 'Omar', schoolName: 'Riverside'),
          ],
          onOpenStudentRecord: (record, student) => opened.add(student?.id),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Filter by child'), findsOne);
    expect(find.text('All children'), findsOne);
    // Every child asked for, and every row says whose it is.
    expect({for (final load in repository.loads) load.$3}, {'layla', 'omar'});
    expect(find.text('Layla · Al-Noor'), findsOne);
    expect(find.text('Omar · Riverside'), findsOne);
    await tester.tap(find.text('Fractions sheet').last);
    expect(opened, ['omar']);

    repository.loads.clear();
    await tester.tap(find.text('Layla'));
    await tester.pumpAndSettle();
    expect(repository.loads.single.$3, 'layla');
    // One child shown: no per-row label repeating the filter.
    expect(find.text('Layla · Al-Noor'), findsNothing);
  });

  testWidgets('a class page has no row of tools - only its options menu', (
    tester,
  ) async {
    var deleted = 0;
    await tester.pumpWidget(
      localizedApp(
        home: AcademicOverviewPage(
          repository: _FakeAcademicRepository(records),
          classroomId: 'class-1',
          title: 'Biology 9A',
          teacherTools: true,
          appBarActions: [
            PopupMenuButton<VoidCallback>(
              tooltip: 'Options',
              onSelected: (action) => action(),
              itemBuilder: (_) => [
                PopupMenuItem(
                  value: () => deleted++,
                  child: const Text('Delete class'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
    await tester.pumpAndSettle();

    for (final gone in ['Roster', 'Schedule', 'Sections', 'Gradebook']) {
      expect(find.text(gone), findsNothing, reason: gone);
    }
    await tester.tap(find.byTooltip('Options'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Delete class'));
    await tester.pumpAndSettle();
    expect(deleted, 1);
  });
}
