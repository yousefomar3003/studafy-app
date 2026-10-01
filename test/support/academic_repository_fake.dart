import 'package:studafy/features/academic/domain/academic_repository.dart';

/// One call to [AcademicRepository.recordAttendance], or to
/// [AcademicRepository.correctAttendance] (which has no times).
class RecordedAttendance {
  RecordedAttendance(
    this.startsAt,
    this.endsAt,
    this.entries, {
    this.reason,
    this.override = false,
    this.sessionId,
  });
  final DateTime? startsAt;
  final DateTime? endsAt;
  final List<AttendanceDraft> entries;
  final String? reason;
  final bool override;
  final String? sessionId;
}

/// Implements only what the register needs; `noSuchMethod` absorbs the rest
/// of the port so this fake does not have to be rewritten every time an
/// unrelated academic method is added.
class AttendanceFake implements AcademicRepository {
  AttendanceFake({
    required this.schedule,
    required this.roster,
    this.version = 0,
    this.sessionId,
    this.editRule = AttendanceEditRule.open,
    this.refusal,
  });

  final List<ClassSessionSlot> schedule;
  final List<AttendanceRosterEntry> roster;
  final int version;
  final String? sessionId;
  final AttendanceEditRule editRule;

  /// Thrown by every save, when set.
  final CourseworkRefusal? refusal;
  final recorded = <RecordedAttendance>[];
  final recordedVersions = <int>[];

  @override
  Future<List<ClassSessionSlot>> classroomSchedule(String classroomId) async =>
      schedule;

  final rosterCalls = <DateTime?>[];

  @override
  Future<AttendanceRegister> attendanceRoster(
    String classroomId,
    DateTime date, {
    DateTime? startsAt,
  }) async {
    rosterCalls.add(startsAt);
    return AttendanceRegister(
      entries: roster,
      version: version,
      sessionId: sessionId,
      editRule: editRule,
    );
  }

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
    if (refusal case final refused?) throw refused;
    recordedVersions.add(expectedVersion);
    recorded.add(
      RecordedAttendance(
        startsAt,
        endsAt,
        entries,
        reason: correctionReason,
        override: override,
      ),
    );
  }

  @override
  Future<void> correctAttendance(
    String sessionId,
    int expectedVersion,
    List<AttendanceDraft> entries, {
    String? reason,
    bool override = false,
  }) async {
    if (refusal case final refused?) throw refused;
    recordedVersions.add(expectedVersion);
    recorded.add(
      RecordedAttendance(
        null,
        null,
        entries,
        reason: reason,
        override: override,
        sessionId: sessionId,
      ),
    );
  }

  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw UnimplementedError('${invocation.memberName} is not faked');
}

/// Serves a fixed class list; everything else on the port is absent.
class RosterFake implements AcademicRepository {
  RosterFake({required this.students, this.fail = false});

  final List<ClassStudent> students;
  final bool fail;

  @override
  Future<List<ClassStudent>> classStudents(String classroomId) async {
    if (fail) throw StateError('synthetic roster failure');
    return students;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw UnimplementedError('${invocation.memberName} is not faked');
}

/// Records what the "new assignment" form actually created, so a test can
/// tell an assignment from an assessment.
class CreateWorkFake implements AcademicRepository {
  CreateWorkFake({this.fail = false});

  final bool fail;
  final assignments = <AssignmentDraft>[];
  final assessments = <AssessmentDraft>[];
  final lessons = <TextResourceDraft>[];

  @override
  Future<void> createResource(TextResourceDraft draft) async {
    if (fail) throw StateError('synthetic create failure');
    lessons.add(draft);
  }

  @override
  Future<void> createAssignment(AssignmentDraft draft) async {
    if (fail) throw StateError('synthetic create failure');
    assignments.add(draft);
  }

  @override
  Future<void> createAssessment(AssessmentDraft draft) async {
    if (fail) throw StateError('synthetic create failure');
    assessments.add(draft);
  }

  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw UnimplementedError('${invocation.memberName} is not faked');
}

/// Sections plus the close call, for the "content before closing" rule.
class SectionsFake implements AcademicRepository {
  SectionsFake({required this.sessions, this.closeFails = false});

  final List<LessonSession> sessions;
  final bool closeFails;
  final closed = <String>[];
  final filed = <TextResourceDraft>[];

  @override
  Future<List<LessonSession>> lessonSessions(String classroomId) async =>
      sessions;

  @override
  Future<void> closeLessonSession(String lessonSessionId) async {
    if (closeFails) throw StateError('window_closed');
    closed.add(lessonSessionId);
  }

  @override
  Future<void> createResource(TextResourceDraft draft) async =>
      filed.add(draft);

  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw UnimplementedError('${invocation.memberName} is not faked');
}

/// Records a student's hand-in.
class SubmitFake implements AcademicRepository {
  SubmitFake({this.fail = false});

  final bool fail;
  final submitted =
      <({String assignmentId, String answer, List<String> attachments})>[];

  @override
  Future<void> submitAssignment(
    String assignmentId,
    String answer, {
    List<String> attachmentFileIds = const [],
    String? studentId,
  }) async {
    if (fail) throw StateError('synthetic submit failure');
    submitted.add((
      assignmentId: assignmentId,
      answer: answer,
      attachments: attachmentFileIds,
    ));
  }

  /// What the history read returns; each call is recorded.
  List<SubmissionAttempt> history = const [];
  final historyRequests = <({String assignmentId, String? studentId})>[];

  @override
  Future<List<SubmissionAttempt>> submissionHistory(
    String assignmentId, {
    String? studentId,
  }) async {
    historyRequests.add((assignmentId: assignmentId, studentId: studentId));
    return history;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw UnimplementedError('${invocation.memberName} is not faked');
}

/// Roster plus submissions, for the hand-in view.
class SubmissionsFake implements AcademicRepository {
  SubmissionsFake({required this.students, required this.work});

  final List<ClassStudent> students;
  final List<SubmittedWork> work;

  @override
  Future<List<ClassStudent>> classStudents(String classroomId) async =>
      students;

  @override
  Future<List<SubmittedWork>> submissionsFor(String assignmentId) async => work;

  /// Students given more time, and the calls that changed it.
  List<AssignmentExtension> extensions = const [];
  final granted = <(String studentId, String untilLocal, String reason)>[];

  @override
  Future<List<AssignmentExtension>> assignmentExtensions(
    String assignmentId,
  ) async => extensions;

  @override
  Future<void> grantExtension(
    String assignmentId,
    String studentId,
    String untilLocal,
    String reason,
  ) async => granted.add((studentId, untilLocal, reason));

  /// Earlier attempts per student, newest first. Without an entry a
  /// student's history is just their current work, which is what a server
  /// with one attempt returns.
  Map<String, List<SubmissionAttempt>> history = const {};
  final historyRequests = <String?>[];

  @override
  Future<List<SubmissionAttempt>> submissionHistory(
    String assignmentId, {
    String? studentId,
  }) async {
    historyRequests.add(studentId);
    return history[studentId] ??
        [
          for (final item in work)
            if (item.studentId == studentId && item.submittedAt != null)
              SubmissionAttempt(
                id: item.id,
                submittedAt: item.submittedAt!,
                current: true,
                answerText: item.answerText,
                submittedByGuardianId: item.submittedByGuardianId,
              ),
        ];
  }

  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw UnimplementedError('${invocation.memberName} is not faked');
}

/// Captures a replaced timetable.
class ScheduleFake implements AcademicRepository {
  ScheduleFake({this.fail = false});

  final bool fail;
  final saved = <List<ClassSessionSlot>>[];

  @override
  Future<void> replaceSchedule(
    String classroomId,
    int expectedVersion,
    List<ClassSessionSlot> slots,
  ) async {
    if (fail) throw StateError('synthetic schedule failure');
    saved.add(slots);
  }

  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw UnimplementedError('${invocation.memberName} is not faked');
}
