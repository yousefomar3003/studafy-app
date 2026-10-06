import 'package:flutter/foundation.dart';

import '../../../core/file_upload_repository.dart';
import 'online_assessment.dart';

export 'online_assessment.dart';

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
    this.classroomId,
    this.attachments = const [],
    this.maximumScore,
    this.markedAssignmentId,
    this.date,
    this.delivery,
    this.mark,
    this.score,
    this.outOf,
    this.deadline,
    this.timeZone,
    this.links = const [],
    this.sharedAttachments = const [],
    this.sharedLinks = const [],
    this.feedback,
    this.assessmentId,
    this.resourceType,
  });

  /// A separate instance with the same values - so the same assignment,
  /// shown once for each of two siblings, is two rows that can each say
  /// whose they are.
  AcademicRecord copy() => AcademicRecord(
    id: id,
    title: title,
    detail: detail,
    state: state,
    version: version,
    classroomId: classroomId,
    attachments: attachments,
    maximumScore: maximumScore,
    markedAssignmentId: markedAssignmentId,
    date: date,
    delivery: delivery,
    mark: mark,
    score: score,
    outOf: outOf,
    deadline: deadline,
    timeZone: timeZone,
    links: links,
    sharedAttachments: sharedAttachments,
    sharedLinks: sharedLinks,
    feedback: feedback,
    assessmentId: assessmentId,
    resourceType: resourceType,
  );
  final String id;
  final String title;
  final String detail;
  final String state;
  final int version;

  /// Set on graded assignments: what the work is marked out of.
  final double? maximumScore;

  /// Set on an assessment that is the mark for an assignment: which one.
  /// Such an assessment is listed with its assignment, not among the tests,
  /// but the gradebook still needs it - it is where the mark is entered.
  final String? markedAssignmentId;

  /// When the record happened: a lesson's, work's or exam's publishing
  /// time, when a mark was released or a note written - and for an
  /// attendance mark, when the lesson it is for began. Null where the feed
  /// does not carry one.
  final DateTime? date;

  /// Files the teacher attached to the work. Empty for every other feed.
  final List<StoredAttachment> attachments;

  /// The class this record belongs to, so a list spanning several classes can
  /// say which one each row came from. Null where the record has no class -
  /// school-wide content, and feeds that are already pinned to one class.
  final String? classroomId;

  /// Grades only: 'paper' for work marked on paper, 'online' for work handed
  /// in or answered in the app. Paper marks are labelled as such.
  final String? delivery;

  /// Grades only: how the student did. Null while unmarked - never a zero.
  final GradeMark? mark;
  final double? score;
  final double? outOf;

  /// Assignments seen by a student or a guardian: until when the work can be
  /// handed in or replaced, on the school's clock.
  final SubmissionDeadline? deadline;

  /// Assignments: the school's time zone, in which deadlines are set.
  final String? timeZone;

  /// Titled links on a lesson, work or a grade.
  final List<ContentLink> links;

  /// Grades only: the class's shared attachments (the question paper), and
  /// the teacher's feedback. Present once the grade is published.
  final List<StoredAttachment> sharedAttachments;
  final List<ContentLink> sharedLinks;
  final String? feedback;

  /// Grades only: the assessment the mark is for.
  final String? assessmentId;

  /// Lessons only: 'file' for a lesson that is one file (replaced whole),
  /// otherwise notes with any number of files and links.
  final String? resourceType;
}

/// How a student did on marked work. Absent and not graded carry no score
/// and are never counted as zero.
enum GradeMark {
  scored('scored'),
  absent('absent'),
  notGraded('not_graded');

  const GradeMark(this.wire);
  final String wire;

  static GradeMark? fromWire(String? value) => switch (value) {
    'scored' => GradeMark.scored,
    'absent' => GradeMark.absent,
    'not_graded' => GradeMark.notGraded,
    _ => null,
  };
}

/// Whether a student can still hand work in, and until when.
enum SubmissionWindow { open, closed, gradedLocked }

@immutable
class SubmissionDeadline {
  const SubmissionDeadline({
    required this.state,
    required this.deadlineLocal,
    required this.timeZone,
    this.extendedUntilLocal,
  });

  final SubmissionWindow state;

  /// `2026-10-01T23:59` on the school's clock, shown as the school reads it
  /// whatever the device's own time zone.
  final String deadlineLocal;
  final String timeZone;

  /// Set when the teacher gave this student more time.
  final String? extendedUntilLocal;
}

/// One class a feed can be narrowed to.
///
/// Deliberately a plain pair rather than the classes slice's own summary
/// type: this page must not import another feature, so the shell that owns
/// both supplies the list.
/// A child whose record a guardian can read, for filtering by child.
@immutable
class StudentChoice {
  const StudentChoice({
    required this.id,
    required this.name,
    this.schoolName = '',
  });

  final String id;
  final String name;
  final String schoolName;
}

@immutable
class ClassChoice {
  const ClassChoice({required this.id, required this.name});

  final String id;
  final String name;
}

@immutable
class TextResourceDraft {
  const TextResourceDraft({
    required this.classroomId,
    required this.title,
    required this.body,
    this.lessonSessionId,
    this.audience = 'both',
    this.publish = false,
    this.attachmentFileIds = const [],
    this.links = const [],
  });
  final String classroomId;
  final String title;
  final String body;

  /// Completed `lesson_resource` uploads for [classroomId]: the lesson's own
  /// files, bound with it.
  final List<String> attachmentFileIds;
  final List<LinkDraft> links;

  /// Publish straight away, so the class sees it. Otherwise it is a draft
  /// only its teachers can see until they publish it.
  final bool publish;

  /// Who sees it: 'students', 'guardians' or 'both'.
  final String audience;

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
    this.attachmentFileIds = const [],
    this.publish = true,
    this.maximumScore,
    this.links = const [],
  });
  final String classroomId;
  final String title;
  final String instructions;

  /// Titled links on the work.
  final List<LinkDraft> links;
  final DateTime dueAt;
  final DateTime? closesAt;

  /// Completed `assignment_material` uploads for [classroomId]. The server
  /// binds them when the assignment is created, or creates nothing.
  final List<String> attachmentFileIds;

  /// Publish as soon as it is created, so the class can see it. Work is
  /// stored as a draft first; nothing a student can reach shows a draft.
  final bool publish;

  /// Set for graded work: what it is marked out of. The student still hands
  /// in this assignment; the mark is kept on a linked assessment.
  final double? maximumScore;
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
    this.attachmentFileIds = const [],
    this.publish = false,
    this.assignmentId,
    this.weight,
  });
  final String classroomId;
  final String title;
  final double maximumScore;

  /// How much this counts, 0-100, when the school weighs categories.
  final double? weight;
  final List<AssessmentQuestionDraft> questions;

  /// As on [AssignmentDraft]: material bound when the work is created.
  final List<String> attachmentFileIds;

  /// Publish on creation. Off by default: an exam is written, checked and
  /// released later. Graded coursework set from the assignment form is
  /// published at once, like any other assignment.
  final bool publish;

  /// The assignment this is the mark for, when it is graded coursework.
  final String? assignmentId;

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
    this.effectiveFrom,
    this.effectiveUntil,
  });

  /// ISO-8601 weekday: Monday is 1, Sunday is 7.
  final int weekday;

  /// Wall-clock start, `HH:mm` or `HH:mm:ss`, in the school's timezone.
  final String startsAt;
  final String endsAt;

  /// The days the class keeps this slot: from when the timetable said so,
  /// until it changed. Null is open-ended. A lesson outside them was never
  /// on the timetable, and the server refuses a register for it.
  final DateTime? effectiveFrom;
  final DateTime? effectiveUntil;

  /// Whether the class meets in this slot on [day].
  bool appliesOn(DateTime day) {
    if (day.weekday != weekday) return false;
    final date = DateTime(day.year, day.month, day.day);
    final from = effectiveFrom;
    final until = effectiveUntil;
    if (from != null && date.isBefore(from)) return false;
    if (until != null && date.isAfter(until)) return false;
    return true;
  }
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
    this.submittedByGuardianId,
  });

  final String id;
  final String assignmentId;
  final String studentId;

  /// open until the student hands in; then submitted, excused or withdrawn.
  final String status;
  final String? answerText;
  final DateTime? submittedAt;

  /// The guardian who handed this in for the child, if one did. Young children
  /// have no device of their own, so a teacher needs to know whose work they
  /// are marking.
  final String? submittedByGuardianId;
}

/// One hand-in of a piece of work. A resubmission is a new attempt; the
/// earlier ones stay exactly as they were handed in.
@immutable
class SubmissionAttempt {
  const SubmissionAttempt({
    required this.id,
    required this.submittedAt,
    required this.current,
    this.answerText,
    this.submittedByGuardianId,
    this.submittedByGuardianName,
    this.attachments = const [],
  });

  final String id;
  final DateTime submittedAt;

  /// The attempt being marked: the latest.
  final bool current;
  final String? answerText;

  /// Set when a guardian handed this attempt in for the child.
  final String? submittedByGuardianId;
  final String? submittedByGuardianName;
  final List<StoredAttachment> attachments;
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
  const AttendanceRegister({
    required this.entries,
    required this.version,
    this.sessionId,
    this.editRule = AttendanceEditRule.open,
  });

  final List<AttendanceRosterEntry> entries;

  /// The lesson, once its register has been saved at least once.
  final String? sessionId;

  /// What the school's policy lets this teacher do to this register.
  final AttendanceEditRule editRule;

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
    this.enrolled = true,
  });

  final String studentId;
  final String displayName;

  /// False for a student who has left the class but was marked for this
  /// lesson: shown so their mark can still be corrected.
  final bool enrolled;

  /// Null when this student has not been marked for the chosen session yet.
  final AttendanceState? state;
  final String? reason;
}

/// A wellbeing note about one student, written by one of their teachers.
///
/// [visibility] is who may read it besides the class's staff: `class_staff`
/// (staff only - the default), `guardian_shared` (also the student's linked
/// parents) or `student_guardian_shared` (also the student). [severity] is
/// `low`, `moderate` or `high`.
@immutable
class WellbeingDraft {
  const WellbeingDraft({
    required this.classroomId,
    required this.studentId,
    required this.kind,
    required this.title,
    this.context,
    this.followUp,
    this.visibility = 'class_staff',
    this.severity = 'low',
  });
  final String classroomId;
  final String studentId;
  final String kind;
  final String title;
  final String? context;
  final String? followUp;
  final String visibility;
  final String? severity;
}

/// What a school's attendance policy lets the caller do to one register.
enum AttendanceEditRule {
  /// The lesson's own day (or later): marks change freely.
  open,

  /// A past lesson: new marks are fine, a changed mark needs a reason.
  reasonRequired,

  /// Past the school's window: nothing changes.
  locked,

  /// Locked, but this caller (a lead teacher or admin) may override it.
  lockedOverride;

  static AttendanceEditRule fromWire(String? value) => switch (value) {
    'reason_required' => AttendanceEditRule.reasonRequired,
    'locked' => AttendanceEditRule.locked,
    'locked_override' => AttendanceEditRule.lockedOverride,
    _ => AttendanceEditRule.open,
  };
}

/// One change to one student's mark on a register.
@immutable
class AttendanceChange {
  const AttendanceChange({
    required this.studentName,
    required this.previous,
    required this.next,
    required this.at,
    this.reason,
    this.override = false,
    this.actorName,
  });

  final String studentName;
  final AttendanceState previous;
  final AttendanceState next;
  final DateTime at;
  final String? reason;
  final bool override;
  final String? actorName;
}

/// A paper gradebook item and the class's marks for it.
@immutable
class PaperGradebook {
  const PaperGradebook({required this.item, required this.rows});

  final PaperGradebookItem item;
  final List<PaperGradebookRow> rows;
}

@immutable
class PaperGradebookItem {
  const PaperGradebookItem({
    required this.id,
    required this.title,
    required this.category,
    required this.maximumScore,
    required this.state,
    required this.version,
    required this.gradebookVersion,
    required this.unmarked,
    required this.ready,
    required this.published,
    this.weight,
    this.scheduledAt,
    this.sharedAttachments = const [],
    this.sharedLinks = const [],
  });

  final String id;
  final String title;
  final String category;
  final double maximumScore;
  final String state;
  final int version;

  /// The class's shared attachments: the question paper, general feedback.
  /// Each student sees them once their own grade is published.
  final List<StoredAttachment> sharedAttachments;
  final List<ContentLink> sharedLinks;

  /// Sent back when saving and publishing, so the teacher publishes exactly
  /// the sheet they saw.
  final int gradebookVersion;
  final int unmarked;
  final int ready;
  final int published;
  final double? weight;
  final DateTime? scheduledAt;
}

@immutable
class PaperGradebookRow {
  const PaperGradebookRow({
    required this.studentId,
    required this.displayName,
    required this.enrolled,
    this.grade,
  });

  final String studentId;
  final String displayName;

  /// False for a student who left the class but already has a mark.
  final bool enrolled;
  final PaperGrade? grade;
}

/// Where one student's mark is: not marked, marked but private, or
/// published to the student and their family.
enum PaperGradeState { unmarked, ready, published, withdrawn }

@immutable
class PaperGrade {
  const PaperGrade({
    required this.id,
    required this.state,
    required this.version,
    this.mark,
    this.score,
    this.feedback,
    this.corrections = 0,
    this.attachments = const [],
    this.links = const [],
  });

  /// This student's own attachments: a marked sheet, personal feedback.
  final List<StoredAttachment> attachments;
  final List<ContentLink> links;

  final String id;
  final PaperGradeState state;
  final int version;
  final GradeMark? mark;
  final double? score;
  final String? feedback;

  /// How many times the published mark has been corrected.
  final int corrections;
}

/// One student's mark as the teacher enters it.
@immutable
class GradeDraft {
  const GradeDraft({
    required this.studentId,
    required this.expectedVersion,
    this.mark,
    this.score,
    this.feedback,
  });

  final String studentId;

  /// 0 for a student with no mark yet.
  final int expectedVersion;

  /// Null clears the mark back to "not marked yet".
  final GradeMark? mark;
  final double? score;
  final String? feedback;
}

@immutable
class GradeCorrection {
  const GradeCorrection({
    required this.gradeId,
    required this.expectedVersion,
    required this.mark,
    this.score,
    this.feedback,
  });

  final String gradeId;
  final int expectedVersion;
  final GradeMark mark;
  final double? score;
  final String? feedback;
}

/// One publication or correction of a mark.
@immutable
class GradeChange {
  const GradeChange({
    required this.change,
    required this.at,
    this.previousMark,
    this.previousScore,
    this.nextMark,
    this.nextScore,
    this.reason,
    this.actorName,
  });

  /// 'published' or 'corrected'.
  final String change;
  final DateTime at;
  final GradeMark? previousMark;
  final double? previousScore;
  final GradeMark? nextMark;
  final double? nextScore;
  final String? reason;
  final String? actorName;
}

@immutable
class PublishedGrades {
  const PublishedGrades({required this.published, required this.unmarked});

  final int published;

  /// Left as drafts: unmarked students are never published as zero.
  final int unmarked;
}

/// More time one student was given for one piece of work.
@immutable
class AssignmentExtension {
  const AssignmentExtension({
    required this.studentId,
    required this.untilLocal,
    required this.reason,
  });

  final String studentId;
  final String untilLocal;
  final String reason;
}

/// Why the server refused a coursework command, in terms a screen can act
/// on. [rows] names the refused rows (a student or grade id) with a reason
/// code, when a bulk command refused only some of them.
enum CourseworkProblem {
  versionConflict,

  /// The thing asked for does not exist in the state asked - a register
  /// for a lesson that was never on the class's timetable.
  invalidState,
  entriesInvalid,
  reasonRequired,
  attendanceLocked,
  submissionLocked,
  windowClosed,
  notAllowed,
  other,
}

class CourseworkRefusal implements Exception {
  const CourseworkRefusal(this.problem, {this.rows = const {}});

  final CourseworkProblem problem;
  final Map<String, String> rows;

  @override
  String toString() => 'CourseworkRefusal($problem)';
}

/// Lessons and class material: the content feed and its lifecycle.
abstract interface class AcademicContentRepository {
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

  /// Edits a lesson in place: it stays as visible as it was. With
  /// [replaceFileId] its file is replaced; the old one is kept for the
  /// school, and only staff can still open it.
  Future<void> editResource(
    String resourceId,
    int expectedVersion, {
    String? title,
    String? body,
    String? replaceFileId,
    AttachmentChanges attachments = const AttachmentChanges(),
  });
}

/// Assignments: setting work, handing it in and reviewing what came back.
abstract interface class AssignmentRepository {
  Future<void> createAssignment(AssignmentDraft draft);
  Future<void> publishAssignment(String assignmentId, int expectedVersion);
  Future<void> withdrawAssignment(String assignmentId, int expectedVersion);

  /// Hands work in. [attachmentFileIds] are the student's own completed
  /// uploads of purpose `assignment_submission`; the server binds them to the
  /// attempt this creates and refuses any that are not theirs to attach.
  Future<void> submitAssignment(
    String assignmentId,
    String answer, {
    List<String> attachmentFileIds = const [],
    String? studentId,
  });

  /// What students have handed in for [assignmentId].
  Future<List<SubmittedWork>> submissionsFor(String assignmentId);

  /// Every attempt one student made at [assignmentId], newest first.
  ///
  /// A student leaves [studentId] out and gets their own. A guardian names
  /// their child and a teacher names the student; the server refuses anyone
  /// who is none of those.
  Future<List<SubmissionAttempt>> submissionHistory(
    String assignmentId, {
    String? studentId,
  });

  /// The students given more time on [assignmentId].
  Future<List<AssignmentExtension>> assignmentExtensions(String assignmentId);

  /// Gives one student until [untilLocal] (school time, `YYYY-MM-DDTHH:mm`).
  Future<void> grantExtension(
    String assignmentId,
    String studentId,
    String untilLocal,
    String reason,
  );
  Future<void> revokeExtension(String assignmentId, String studentId);

  /// Changes the teacher's material on set work: [detachFileIds] are taken
  /// off (kept for the school, hidden from the class) and
  /// [attachmentFileIds] - completed `assignment_material` uploads for the
  /// class - are added.
  Future<void> updateAssignmentMaterials(
    String assignmentId,
    int expectedVersion, {
    List<String> detachFileIds = const [],
    List<String> attachmentFileIds = const [],
    List<LinkDraft> addLinks = const [],
    List<String> removeLinkIds = const [],
  });

  /// Reopens the work for the whole class until [closesAtLocal].
  Future<void> reopenAssignment(
    String assignmentId,
    int expectedVersion,
    String closesAtLocal,
    String reason,
  );
}

/// Assessments and exams.
abstract interface class AssessmentRepository {
  Future<void> createAssessment(AssessmentDraft draft);
  Future<void> publishAssessment(String assessmentId, int expectedVersion);
  Future<void> withdrawAssessment(String assessmentId, int expectedVersion);

  /// As [AssignmentRepository.updateAssignmentMaterials], for an exam.
  Future<void> updateAssessmentMaterials(
    String assessmentId,
    int expectedVersion, {
    List<String> detachFileIds = const [],
    List<String> attachmentFileIds = const [],
    List<LinkDraft> addLinks = const [],
    List<String> removeLinkIds = const [],
  });
  Future<void> submitAssessment(
    String assessmentId,
    Map<String, String> answers,
  );
}

/// A class's timetable, its lessons as taught, and who is in it.
abstract interface class ClassTimetableRepository {
  /// The class's weekly meetings, so the teacher can pick which one they are
  /// taking the register for.
  Future<List<ClassSessionSlot>> classroomSchedule(String classroomId);

  /// Replaces a classroom's weekly schedule.
  ///
  /// The schedule decides which sections a register can be taken for, so it
  /// has to be editable after the class is created rather than only at it.
  Future<void> replaceSchedule(
    String classroomId,
    int expectedVersion,
    List<ClassSessionSlot> slots,
  );

  /// Deletes a class. It is archived: it leaves every class list, and each
  /// student keeps their notebook for it.
  Future<void> archiveClassroom(String classroomId, int expectedVersion);

  /// Meetings of [classroomId] that have already happened.
  Future<List<LessonSession>> lessonSessions(String classroomId);

  /// Closes a section. Refused while nothing has been filed against it.
  Future<void> closeLessonSession(String lessonSessionId);

  /// Children enrolled in [classroomId], each with their verified guardians.
  Future<List<ClassStudent>> classStudents(String classroomId);
}

/// Attendance registers.
abstract interface class AttendanceRepository {
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
    List<AttendanceDraft> entries, {
    String? correctionReason,
    bool override = false,
  });

  /// Corrects a lesson that has a register, addressed by the lesson itself,
  /// so it works after the timetable changed or a student left.
  Future<void> correctAttendance(
    String sessionId,
    int expectedVersion,
    List<AttendanceDraft> entries, {
    String? reason,
    bool override = false,
  });

  /// Every change to an existing mark on the lesson's register, newest first.
  Future<List<AttendanceChange>> attendanceHistory(String sessionId);
}

/// Grades: review, publication and corrections.
abstract interface class GradeRepository {
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
}

/// Marks for paper work: a whole class at once, private until published,
/// corrected with a reason.
abstract interface class PaperGradebookRepository {
  /// Sets up a paper gradebook item in [classroomId] and answers its id. It
  /// stays private until marks for it are published.
  Future<String> createPaperGradebookItem(
    String classroomId, {
    required String title,
    required String category,
    required double maximumScore,
    double? weight,
    DateTime? scheduledAt,
  });

  Future<PaperGradebook> paperGradebook(String assessmentId);

  /// Saves marks as drafts and answers the sheet's new version.
  Future<int> saveGradeDrafts(
    String assessmentId,
    int gradebookVersion,
    List<GradeDraft> entries,
  );

  /// Publishes every marked row, all at once or not at all.
  Future<PublishedGrades> publishGrades(
    String assessmentId,
    int gradebookVersion,
  );
  Future<void> correctGrades(
    String assessmentId,
    String reason,
    List<GradeCorrection> entries,
  );
  Future<List<GradeChange>> gradeHistory(String gradeId);
  Future<void> updateGradebookItem(
    String assessmentId,
    int expectedVersion, {
    required String title,
    required String category,
    required double maximumScore,
    double? weight,
    DateTime? scheduledAt,
  });
}

/// Wellbeing notes.
abstract interface class WellbeingRepository {
  Future<void> createWellbeing(WellbeingDraft draft);
}

/// Typed mobile boundary for every API-041 slice. Remote implementations must
/// fail closed; preview implementations are the only adapters allowed to use
/// SQLite.
///
/// The union of the slice interfaces above. A screen that needs one slice
/// asks for that interface, so its tests fake only what it uses.
abstract interface class AcademicRepository
    implements
        AcademicContentRepository,
        AssignmentRepository,
        AssessmentRepository,
        ClassTimetableRepository,
        AttendanceRepository,
        GradeRepository,
        PaperGradebookRepository,
        WellbeingRepository,
        OnlineAssessmentRepository {}
