import '../domain/academic_repository.dart';

/// Synthetic-only typed academic adapter. It deliberately keeps its state in
/// process and is never selected by a remote runtime policy.
class PreviewAcademicRepository implements AcademicRepository {
  PreviewAcademicRepository()
    : _records = {
        AcademicFeed.content: <AcademicRecord>[],
        AcademicFeed.assignments: <AcademicRecord>[],
        AcademicFeed.assessments: <AcademicRecord>[],
        AcademicFeed.grades: <AcademicRecord>[],
        AcademicFeed.attendance: <AcademicRecord>[],
        AcademicFeed.wellbeing: <AcademicRecord>[],
      };

  final Map<AcademicFeed, List<AcademicRecord>> _records;
  int _sequence = 0;

  String _id(String kind) => 'preview-$kind-${++_sequence}';

  @override
  Future<List<AcademicRecord>> load(
    AcademicFeed feed, {
    String? classroomId,
    String? studentId,
  }) async => List<AcademicRecord>.unmodifiable(_records[feed]!);

  @override
  Future<void> createResource(TextResourceDraft draft) async {
    _records[AcademicFeed.content]!.add(
      AcademicRecord(
        id: _id('resource'),
        title: draft.title,
        detail: draft.body,
        state: 'draft',
        version: 1,
      ),
    );
  }

  @override
  Future<void> reviseResource(
    String resourceId,
    int expectedVersion,
    String title,
    String body,
  ) => _replace(
    AcademicFeed.content,
    resourceId,
    expectedVersion,
    title: title,
    detail: body,
    state: 'draft',
  );

  @override
  Future<void> publishResource(String resourceId, int expectedVersion) =>
      _transition(
        AcademicFeed.content,
        resourceId,
        expectedVersion,
        'published',
      );

  @override
  Future<void> withdrawResource(String resourceId, int expectedVersion) =>
      _transition(
        AcademicFeed.content,
        resourceId,
        expectedVersion,
        'withdrawn',
      );

  @override
  Future<void> createAssignment(AssignmentDraft draft) async {
    _records[AcademicFeed.assignments]!.add(
      AcademicRecord(
        id: _id('assignment'),
        title: draft.title,
        detail: draft.instructions,
        state: 'draft',
        version: 1,
      ),
    );
  }

  @override
  Future<void> publishAssignment(String assignmentId, int expectedVersion) =>
      _transition(
        AcademicFeed.assignments,
        assignmentId,
        expectedVersion,
        'published',
      );

  @override
  Future<void> withdrawAssignment(String assignmentId, int expectedVersion) =>
      _transition(
        AcademicFeed.assignments,
        assignmentId,
        expectedVersion,
        'withdrawn',
      );

  @override
  Future<void> createAssessment(AssessmentDraft draft) async {
    _records[AcademicFeed.assessments]!.add(
      AcademicRecord(
        id: _id('assessment'),
        title: draft.title,
        detail: '${draft.maximumScore} points',
        state: 'draft',
        version: 1,
      ),
    );
  }

  @override
  Future<void> publishAssessment(String assessmentId, int expectedVersion) =>
      _transition(
        AcademicFeed.assessments,
        assessmentId,
        expectedVersion,
        'published',
      );

  @override
  Future<void> withdrawAssessment(String assessmentId, int expectedVersion) =>
      _transition(
        AcademicFeed.assessments,
        assessmentId,
        expectedVersion,
        'withdrawn',
      );

  @override
  Future<void> submitAssignment(
    String assignmentId,
    String answer, {
    List<String> attachmentFileIds = const [],
    String? studentId,
  }) async {}

  @override
  Future<void> submitAssessment(
    String assessmentId,
    Map<String, String> answers,
  ) async {}

  @override
  Future<List<ClassSessionSlot>> classroomSchedule(String classroomId) async =>
      const [];

  @override
  Future<List<SubmittedWork>> submissionsFor(String assignmentId) async =>
      const [];

  @override
  Future<void> replaceSchedule(
    String classroomId,
    int expectedVersion,
    List<ClassSessionSlot> slots,
  ) async => throw StateError('Editing a schedule needs the school service.');

  @override
  Future<List<LessonSession>> lessonSessions(String classroomId) async =>
      const [];

  @override
  Future<void> closeLessonSession(String lessonSessionId) async =>
      throw StateError('Closing a section needs the school service.');

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
    for (final entry in entries) {
      _records[AcademicFeed.attendance]!.add(
        AcademicRecord(
          id: _id('attendance'),
          title: entry.state,
          detail: entry.reason ?? '',
          state: entry.state,
          version: 1,
        ),
      );
    }
  }

  @override
  Future<void> reviewGrade(
    String gradeId,
    int expectedVersion,
    double score, {
    String? feedback,
  }) => _transition(AcademicFeed.grades, gradeId, expectedVersion, 'reviewed');

  @override
  Future<void> publishGrade(String gradeId, int expectedVersion) =>
      _transition(AcademicFeed.grades, gradeId, expectedVersion, 'published');

  @override
  Future<void> correctGrade(
    String gradeId,
    int expectedVersion,
    double score,
    String reason, {
    String? feedback,
  }) => _transition(AcademicFeed.grades, gradeId, expectedVersion, 'published');

  @override
  Future<void> withdrawGrade(String gradeId, int expectedVersion) =>
      _transition(AcademicFeed.grades, gradeId, expectedVersion, 'withdrawn');

  @override
  Future<void> createWellbeing(WellbeingDraft draft) async {
    _records[AcademicFeed.wellbeing]!.add(
      AcademicRecord(
        id: _id('wellbeing'),
        title: draft.title,
        detail: draft.context ?? '',
        state: draft.kind,
        version: 1,
      ),
    );
  }

  Future<void> _transition(
    AcademicFeed feed,
    String id,
    int expectedVersion,
    String state,
  ) => _replace(feed, id, expectedVersion, state: state);

  Future<void> _replace(
    AcademicFeed feed,
    String id,
    int expectedVersion, {
    String? title,
    String? detail,
    String? state,
  }) async {
    final values = _records[feed]!;
    final index = values.indexWhere((value) => value.id == id);
    if (index < 0) throw StateError('Preview record not found.');
    final current = values[index];
    if (current.version != expectedVersion) {
      throw StateError('Preview version conflict.');
    }
    values[index] = AcademicRecord(
      id: current.id,
      title: title ?? current.title,
      detail: detail ?? current.detail,
      state: state ?? current.state,
      version: current.version + 1,
    );
  }
}
