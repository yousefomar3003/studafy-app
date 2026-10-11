import '../domain/academic_repository.dart';
import 'preview_online_assessments.dart';

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

  late final _online = PreviewOnlineAssessments(
    onCreated: (record) => _records[AcademicFeed.assessments]!.add(record),
  );

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
  Future<List<SubmissionAttempt>> submissionHistory(
    String assignmentId, {
    String? studentId,
  }) async => const [];

  @override
  Future<void> replaceSchedule(
    String classroomId,
    int expectedVersion,
    List<ClassSessionSlot> slots,
  ) async => throw StateError('Editing a schedule needs the school service.');

  @override
  Future<void> archiveClassroom(
    String classroomId,
    int expectedVersion,
  ) async => throw StateError('Deleting a class needs the school service.');

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
    List<AttendanceDraft> entries, {
    String? correctionReason,
    bool override = false,
  }) async {
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

  // The paper gradebook, deadlines and history are server features: the
  // synthetic preview shows empty sheets and accepts commands as no-ops.
  @override
  Future<void> editResource(
    String resourceId,
    int expectedVersion, {
    String? title,
    String? body,
    String? replaceFileId,
    AttachmentChanges attachments = const AttachmentChanges(),
  }) => _replace(
    AcademicFeed.content,
    resourceId,
    expectedVersion,
    title: title,
    detail: body,
    state: 'published',
  );

  @override
  Future<List<AssignmentExtension>> assignmentExtensions(
    String assignmentId,
  ) async => const [];

  @override
  Future<void> grantExtension(
    String assignmentId,
    String studentId,
    String untilLocal,
    String reason,
  ) async {}

  @override
  Future<void> revokeExtension(String assignmentId, String studentId) async {}

  @override
  Future<void> updateAssignmentMaterials(
    String assignmentId,
    int expectedVersion, {
    List<String> detachFileIds = const [],
    List<String> attachmentFileIds = const [],
    List<LinkDraft> addLinks = const [],
    List<String> removeLinkIds = const [],
  }) async {}

  @override
  Future<void> updateAssessmentMaterials(
    String assessmentId,
    int expectedVersion, {
    List<String> detachFileIds = const [],
    List<String> attachmentFileIds = const [],
    List<LinkDraft> addLinks = const [],
    List<String> removeLinkIds = const [],
  }) async {}

  // Online assessments, in process (ADR-0036).

  @override
  Future<OnlineAssessment> createOnlineAssessment(
    OnlineAssessmentDraft draft,
  ) => _online.createOnlineAssessment(draft);

  @override
  Future<List<AssessmentQuestion>> authoringQuestions(String assessmentId) =>
      _online.authoringQuestions(assessmentId);

  @override
  Future<List<AssessmentQuestion>> questions(String assessmentId) =>
      _online.questions(assessmentId);

  @override
  Future<OnlineAssessment> updateAssessmentDesign(
    String assessmentId,
    int expectedVersion, {
    String? title,
    List<QuestionDraft>? questions,
    AssessmentSettings? settings,
    bool releaseAnswersNow = false,
    AttachmentChanges attachments = const AttachmentChanges(),
  }) => _online.updateAssessmentDesign(
    assessmentId,
    expectedVersion,
    title: title,
    questions: questions,
    settings: settings,
    releaseAnswersNow: releaseAnswersNow,
    attachments: attachments,
  );

  @override
  Future<AttemptConfirmation> submitAnswers(
    String assessmentId,
    List<StudentAnswer> answers,
  ) => _online.submitAnswers(assessmentId, answers);

  @override
  Future<AssessmentResults> results(String assessmentId, {String? studentId}) =>
      _online.results(assessmentId, studentId: studentId);

  @override
  Future<List<AttemptDetail>> attempts(String assessmentId) =>
      _online.attempts(assessmentId);

  @override
  Future<AttemptDetail> attempt(String attemptId) => _online.attempt(attemptId);

  @override
  Future<AttemptDetail> markAttempt(
    String attemptId,
    List<AnswerMark> marks, {
    String? feedback,
    String? correctionReason,
  }) => _online.markAttempt(
    attemptId,
    marks,
    feedback: feedback,
    correctionReason: correctionReason,
  );

  @override
  Future<void> grantAccess(
    String assessmentId,
    String studentId, {
    DateTime? closesAt,
    int extraAttempts = 0,
    String? reason,
  }) => _online.grantAccess(
    assessmentId,
    studentId,
    closesAt: closesAt,
    extraAttempts: extraAttempts,
    reason: reason,
  );

  @override
  Future<GradeAttachments> updateGradeAttachments(
    String assessmentId,
    AttachmentChanges changes, {
    String? studentId,
  }) => _online.updateGradeAttachments(
    assessmentId,
    changes,
    studentId: studentId,
  );

  @override
  Future<void> reopenAssignment(
    String assignmentId,
    int expectedVersion,
    String closesAtLocal,
    String reason,
  ) async {}

  @override
  Future<void> correctAttendance(
    String sessionId,
    int expectedVersion,
    List<AttendanceDraft> entries, {
    String? reason,
    bool override = false,
  }) async {}

  @override
  Future<List<AttendanceChange>> attendanceHistory(String sessionId) async =>
      const [];

  @override
  Future<String> createPaperGradebookItem(
    String classroomId, {
    required String title,
    required String category,
    required double maximumScore,
    double? weight,
    DateTime? scheduledAt,
  }) async => _id('paper');

  @override
  Future<PaperGradebook> paperGradebook(String assessmentId) async =>
      PaperGradebook(
        item: PaperGradebookItem(
          id: assessmentId,
          title: '',
          category: 'paper_exam',
          maximumScore: 100,
          state: 'draft',
          version: 1,
          gradebookVersion: 0,
          unmarked: 0,
          ready: 0,
          published: 0,
        ),
        rows: const [],
      );

  @override
  Future<int> saveGradeDrafts(
    String assessmentId,
    int gradebookVersion,
    List<GradeDraft> entries,
  ) async => gradebookVersion + 1;

  @override
  Future<PublishedGrades> publishGrades(
    String assessmentId,
    int gradebookVersion,
  ) async => const PublishedGrades(published: 0, unmarked: 0);

  @override
  Future<void> correctGrades(
    String assessmentId,
    String? reason,
    List<GradeCorrection> entries,
  ) async {}

  @override
  Future<List<GradeChange>> gradeHistory(String gradeId) async => const [];

  @override
  Future<void> updateGradebookItem(
    String assessmentId,
    int expectedVersion, {
    required String title,
    required String category,
    required double maximumScore,
    double? weight,
    DateTime? scheduledAt,
  }) async {}

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

  @override
  Future<List<LessonReadingSource>> lessonReading(String resourceId) async =>
      const [];

  @override
  Future<List<LessonReadingSource>> retryLessonReading(
    String resourceId,
    String sourceId,
  ) async => const [];
}
