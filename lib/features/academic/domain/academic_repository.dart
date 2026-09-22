import 'package:flutter/foundation.dart';

enum AcademicFeed {
  content,
  assignments,
  assessments,
  grades,
  attendance,
  wellbeing,
}

@immutable
class AcademicRecord {
  const AcademicRecord({
    required this.id,
    required this.title,
    required this.detail,
    required this.state,
    required this.version,
  });
  final String id;
  final String title;
  final String detail;
  final String state;
  final int version;
}

@immutable
class TextResourceDraft {
  const TextResourceDraft({
    required this.classroomId,
    required this.title,
    required this.body,
    this.lessonSessionId,
  });
  final String classroomId;
  final String title;
  final String body;

  /// The meeting this content was taught in. A section cannot be closed
  /// until something is filed against it, so this is the link that satisfies
  /// the school's rule.
  final String? lessonSessionId;
}

@immutable
class AssignmentDraft {
  const AssignmentDraft({
    required this.classroomId,
    required this.title,
    required this.instructions,
    required this.dueAt,
    this.closesAt,
  });
  final String classroomId;
  final String title;
  final String instructions;
  final DateTime dueAt;
  final DateTime? closesAt;
}

@immutable
class AssessmentDraft {
  const AssessmentDraft({
    required this.classroomId,
    required this.title,
    required this.maximumScore,
    required this.questions,
    this.category = 'assessment',
    this.delivery = 'online',
    this.scheduledAt,
  });
  final String classroomId;
  final String title;
  final double maximumScore;
  final List<AssessmentQuestionDraft> questions;

  /// Free-text grouping the gradebook reads. A graded assignment is filed
  /// under 'assignment': the schema already separates work that earns a
  /// score (an assessment, which grade_results attach to) from work that is
  /// only submitted (an assignment), so a graded assignment is the former
  /// wearing the right label rather than a new kind of record.
  final String category;

  /// 'paper' for work the teacher marks themselves, 'online' for work
  /// answered in the app, 'practice' for unscored drill.
  final String delivery;

  /// When the work is due or sat. Null leaves it unscheduled.
  final DateTime? scheduledAt;
}

@immutable
class AssessmentQuestionDraft {
  const AssessmentQuestionDraft({
    required this.prompt,
    required this.maximumScore,
    this.preferredAnswer,
  });
  final String prompt;
  final double maximumScore;
  final String? preferredAnswer;
}

@immutable
class AttendanceDraft {
  const AttendanceDraft({
    required this.studentId,
    required this.state,
    this.reason,
  });
  final String studentId;
  final String state;
  final String? reason;
}

/// One weekly meeting of a class, from its schedule.
///
/// A class commonly meets more than once a week, and attendance belongs to a
/// particular meeting rather than to a date, so the teacher picks the slot as
/// well as the day.
@immutable
class ClassSessionSlot {
  const ClassSessionSlot({
    required this.weekday,
    required this.startsAt,
    required this.endsAt,
  });

  /// ISO-8601 weekday: Monday is 1, Sunday is 7.
  final int weekday;

  /// Wall-clock start, `HH:mm` or `HH:mm:ss`, in the school's timezone.
  final String startsAt;
  final String endsAt;
}

/// How a student was marked for one session.
enum AttendanceState { present, absent, late, excused }

/// One student's hand-in against an assignment.
@immutable
class SubmittedWork {
  const SubmittedWork({
    required this.id,
    required this.assignmentId,
    required this.studentId,
    required this.status,
    this.answerText,
    this.submittedAt,
  });

  final String id;
  final String assignmentId;
  final String studentId;

  /// open until the student hands in; then submitted, excused or withdrawn.
  final String status;
  final String? answerText;
  final DateTime? submittedAt;
}

/// One meeting of a class that has taken place.
@immutable
class LessonSession {
  const LessonSession({
    required this.id,
    required this.startsAt,
    required this.endsAt,
    required this.filed,
    this.title,
  });

  final String id;
  final DateTime startsAt;
  final DateTime endsAt;

  /// Whether the content taught in it has been filed. An unfiled section is
  /// the one the school wants chased.
  final bool filed;
  final String? title;
}

/// One student's mark for one assessment.
///
/// grade_results rows are created when an assessment is published, one per
/// enrolled student, so the gradebook edits rows that already exist rather
/// than creating them.
@immutable
class GradeEntry {
  const GradeEntry({
    required this.id,
    required this.assessmentId,
    required this.studentId,
    required this.maximumScore,
    required this.state,
    required this.version,
    this.score,
    this.feedback,
  });

  final String id;
  final String assessmentId;
  final String studentId;
  final double maximumScore;

  /// 'draft' until a score is entered, 'reviewed' once it is, 'published'
  /// when the student may see it.
  final String state;
  final int version;

  /// Null while unmarked. Not the same as zero, which is a mark.
  final double? score;
  final String? feedback;
}

/// One class a teacher can set work for.
///
/// Deliberately not the classes slice's own summary type: features may not
/// import each other, so the composition root maps its list into this.
@immutable
class ClassOption {
  const ClassOption({required this.id, required this.name});

  final String id;
  final String name;
}

/// A guardian a teacher may contact about a child.
///
/// Carries no phone number or address: contact happens through Studafy's own
/// messaging, which is moderated and logged, rather than by handing a
/// teacher a family's personal details.
@immutable
class StudentGuardian {
  const StudentGuardian({required this.userId, required this.displayName});

  final String userId;
  final String displayName;
}

/// A child in a class, with the guardians linked to them.
@immutable
class ClassStudent {
  const ClassStudent({
    required this.id,
    required this.displayName,
    required this.studafyId,
    this.guardians = const [],
  });

  final String id;
  final String displayName;

  /// The school-facing identifier a teacher reads out or searches by.
  final String studafyId;

  /// Verified guardians only. Empty when nobody is linked yet, which is a
  /// fact worth showing: it means there is no one to contact.
  final List<StudentGuardian> guardians;
}

/// A register for one meeting: who is on it, and the version to save with.
@immutable
class AttendanceRegister {
  const AttendanceRegister({required this.entries, required this.version});

  final List<AttendanceRosterEntry> entries;

  /// What recordAttendance expects as its expectedVersion: zero when this
  /// lesson has never been recorded, the session's current version once it
  /// has. Sending a stale value is refused rather than silently overwriting
  /// a colleague's register.
  final int version;
}

/// A student on the register, with whatever was already recorded for them.
@immutable
class AttendanceRosterEntry {
  const AttendanceRosterEntry({
    required this.studentId,
    required this.displayName,
    this.state,
    this.reason,
  });

  final String studentId;
  final String displayName;

  /// Null when this student has not been marked for the chosen session yet.
  final AttendanceState? state;
  final String? reason;
}

@immutable
class WellbeingDraft {
  const WellbeingDraft({
    required this.classroomId,
    required this.studentId,
    required this.kind,
    required this.title,
    this.context,
  });
  final String classroomId;
  final String studentId;
  final String kind;
  final String title;
  final String? context;
}

/// Typed mobile boundary for every API-041 slice. Remote implementations must
/// fail closed; preview implementations are the only adapters allowed to use
/// SQLite.
abstract interface class AcademicRepository {
  Future<List<AcademicRecord>> load(
    AcademicFeed feed, {
    String? classroomId,
    String? studentId,
  });
  Future<void> createResource(TextResourceDraft draft);
  Future<void> reviseResource(
    String resourceId,
    int expectedVersion,
    String title,
    String body,
  );
  Future<void> publishResource(String resourceId, int expectedVersion);
  Future<void> withdrawResource(String resourceId, int expectedVersion);
  Future<void> createAssignment(AssignmentDraft draft);
  Future<void> publishAssignment(String assignmentId, int expectedVersion);
  Future<void> withdrawAssignment(String assignmentId, int expectedVersion);
  Future<void> createAssessment(AssessmentDraft draft);
  Future<void> publishAssessment(String assessmentId, int expectedVersion);
  Future<void> withdrawAssessment(String assessmentId, int expectedVersion);
  Future<void> submitAssignment(String assignmentId, String answer);
  Future<void> submitAssessment(
    String assessmentId,
    Map<String, String> answers,
  );

  /// The class's weekly meetings, so the teacher can pick which one they are
  /// taking the register for.
  Future<List<ClassSessionSlot>> classroomSchedule(String classroomId);

  /// Children enrolled in [classroomId], each with their verified guardians.
  Future<List<ClassStudent>> classStudents(String classroomId);

  /// The register for one meeting of [classroomId].
  ///
  /// [startsAt] names the meeting; a class that meets twice in a day has two
  /// separate registers, and a date alone cannot tell them apart.
  Future<AttendanceRegister> attendanceRoster(
    String classroomId,
    DateTime date, {
    DateTime? startsAt,
  });

  Future<void> recordAttendance(
    String classroomId,
    DateTime startsAt,
    DateTime endsAt,
    int expectedVersion,
    List<AttendanceDraft> entries,
  );

  /// What students have handed in for [assignmentId].
  Future<List<SubmittedWork>> submissionsFor(String assignmentId);

  /// Replaces a classroom's weekly schedule.
  ///
  /// The schedule decides which sections a register can be taken for, so it
  /// has to be editable after the class is created rather than only at it.
  Future<void> replaceSchedule(
    String classroomId,
    int expectedVersion,
    List<ClassSessionSlot> slots,
  );

  /// Meetings of [classroomId] that have already happened.
  Future<List<LessonSession>> lessonSessions(String classroomId);

  /// Closes a section. Refused while nothing has been filed against it.
  Future<void> closeLessonSession(String lessonSessionId);

  /// Every mark for [classroomId], across its assessments.
  Future<List<GradeEntry>> gradeEntries(String classroomId);

  Future<void> reviewGrade(
    String gradeId,
    int expectedVersion,
    double score, {
    String? feedback,
  });
  Future<void> publishGrade(String gradeId, int expectedVersion);
  Future<void> correctGrade(
    String gradeId,
    int expectedVersion,
    double score,
    String reason, {
    String? feedback,
  });
  Future<void> withdrawGrade(String gradeId, int expectedVersion);
  Future<void> createWellbeing(WellbeingDraft draft);
}
