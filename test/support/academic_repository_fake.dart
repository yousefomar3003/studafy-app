import 'package:studafy/features/academic/domain/academic_repository.dart';

/// One call to [AcademicRepository.recordAttendance].
class RecordedAttendance {
  RecordedAttendance(this.startsAt, this.endsAt, this.entries);
  final DateTime startsAt;
  final DateTime endsAt;
  final List<AttendanceDraft> entries;
}

/// Implements only what the register needs; `noSuchMethod` absorbs the rest
/// of the port so this fake does not have to be rewritten every time an
/// unrelated academic method is added.
class AttendanceFake implements AcademicRepository {
  AttendanceFake({
    required this.schedule,
    required this.roster,
    this.version = 0,
  });

  final List<ClassSessionSlot> schedule;
  final List<AttendanceRosterEntry> roster;
  final int version;
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
    return AttendanceRegister(entries: roster, version: version);
  }

  @override
  Future<void> recordAttendance(
    String classroomId,
    DateTime startsAt,
    DateTime endsAt,
    int expectedVersion,
    List<AttendanceDraft> entries,
  ) async {
    recordedVersions.add(expectedVersion);
    recorded.add(RecordedAttendance(startsAt, endsAt, entries));
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
