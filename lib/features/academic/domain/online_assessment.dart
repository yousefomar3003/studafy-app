import 'package:flutter/foundation.dart';

import '../../../core/coursework_models.dart';
import '../../../core/file_upload_repository.dart';

export '../../../core/coursework_models.dart';

/// Online assessments and the attachments on coursework (ADR-0036).
///
/// The answer key, model answer and marking guidance arrive only where the
/// server allows them: always for the class's teachers, and for a student
/// or parent only once answers are released. Nothing here hides them; the
/// server never sends them.

enum QuestionKind {
  singleChoice('single_choice'),
  multipleChoice('multiple_choice'),
  trueFalse('true_false'),
  shortAnswer('short_answer'),
  essay('essay');

  const QuestionKind(this.wire);
  final String wire;

  static QuestionKind fromWire(String? value) => QuestionKind.values.firstWhere(
    (kind) => kind.wire == value,
    orElse: () => QuestionKind.essay,
  );

  bool get hasOptions => this == singleChoice || this == multipleChoice;

  /// Marked by the server the moment it is submitted, given its key.
  bool get isObjective =>
      this == singleChoice || this == multipleChoice || this == trueFalse;
}

@immutable
class QuestionOption {
  const QuestionOption({required this.id, required this.text});

  final String id;
  final String text;
}

/// A question as its reader may see it. The key fields are null unless the
/// reader is a teacher of the class, or answers are released.
@immutable
class AssessmentQuestion {
  const AssessmentQuestion({
    required this.id,
    required this.position,
    required this.prompt,
    required this.maximumScore,
    this.kind = QuestionKind.essay,
    this.required = true,
    this.options = const [],
    this.attachments = const [],
    this.links = const [],
    this.correctOptionIds,
    this.correctChoice,
    this.acceptedAnswers,
    this.preferredAnswer,
    this.markingGuidance,
  });

  final String id;
  final int position;
  final String prompt;
  final double maximumScore;
  final QuestionKind kind;
  final bool required;
  final List<QuestionOption> options;
  final List<StoredAttachment> attachments;
  final List<ContentLink> links;
  final List<String>? correctOptionIds;
  final bool? correctChoice;
  final List<String>? acceptedAnswers;
  final String? preferredAnswer;
  final String? markingGuidance;
}

/// A question as the teacher writes it.
@immutable
class QuestionDraft {
  const QuestionDraft({
    required this.prompt,
    required this.maximumScore,
    this.id,
    this.kind = QuestionKind.essay,
    this.required = true,
    this.options = const [],
    this.correctOptionIds = const [],
    this.correctChoice,
    this.acceptedAnswers = const [],
    this.preferredAnswer,
    this.markingGuidance,
    this.attachments = const AttachmentChanges(),
  });

  /// Set for a question that already exists, so it keeps its files.
  final String? id;
  final String prompt;
  final double maximumScore;
  final QuestionKind kind;
  final bool required;
  final List<QuestionOption> options;
  final List<String> correctOptionIds;
  final bool? correctChoice;
  final List<String> acceptedAnswers;
  final String? preferredAnswer;
  final String? markingGuidance;
  final AttachmentChanges attachments;
}

enum AnswerRelease {
  afterClose('after_close'),
  afterGrading('after_grading'),
  manual('manual');

  const AnswerRelease(this.wire);
  final String wire;

  static AnswerRelease fromWire(String? value) =>
      AnswerRelease.values.firstWhere(
        (x) => x.wire == value,
        orElse: () => AnswerRelease.afterClose,
      );
}

enum AttemptPolicy {
  best('best'),
  latest('latest');

  const AttemptPolicy(this.wire);
  final String wire;

  static AttemptPolicy fromWire(String? value) =>
      value == 'latest' ? AttemptPolicy.latest : AttemptPolicy.best;
}

/// When students may sit it, how often, and when answers are shown.
@immutable
class AssessmentSettings {
  const AssessmentSettings({
    this.opensAt,
    this.closesAt,
    this.maxAttempts = 1,
    this.attemptPolicy = AttemptPolicy.best,
    this.answerRelease = AnswerRelease.afterClose,
  });

  final DateTime? opensAt;
  final DateTime? closesAt;
  final int maxAttempts;
  final AttemptPolicy attemptPolicy;
  final AnswerRelease answerRelease;
}

/// An online assessment as a list or a builder shows it.
@immutable
class OnlineAssessment {
  const OnlineAssessment({
    required this.id,
    required this.classroomId,
    required this.title,
    required this.category,
    required this.maximumScore,
    required this.state,
    required this.version,
    required this.delivery,
    this.settings = const AssessmentSettings(),
    this.answersReleasedAt,
    this.questionCount = 0,
    this.attachments = const [],
    this.links = const [],
  });

  final String id;
  final String classroomId;
  final String title;
  final String category;
  final double maximumScore;
  final String state;
  final int version;
  final String delivery;
  final AssessmentSettings settings;
  final DateTime? answersReleasedAt;
  final int questionCount;
  final List<StoredAttachment> attachments;
  final List<ContentLink> links;

  bool get isOnline => delivery == 'online' || delivery == 'practice';
}

/// A new online assessment.
@immutable
class OnlineAssessmentDraft {
  const OnlineAssessmentDraft({
    required this.classroomId,
    required this.title,
    required this.questions,
    this.category = 'quiz',
    this.settings = const AssessmentSettings(),
    this.attachmentFileIds = const [],
    this.links = const [],
  });

  final String classroomId;
  final String title;
  final String category;
  final List<QuestionDraft> questions;
  final AssessmentSettings settings;
  final List<String> attachmentFileIds;
  final List<LinkDraft> links;

  double get maximumScore =>
      questions.fold(0, (sum, question) => sum + question.maximumScore);
}

/// One answer as a student gives it.
@immutable
class StudentAnswer {
  const StudentAnswer({
    required this.questionId,
    this.text,
    this.selectedOptionIds = const [],
    this.choice,
  });

  final String questionId;
  final String? text;
  final List<String> selectedOptionIds;
  final bool? choice;

  bool get isEmpty =>
      (text == null || text!.trim().isEmpty) &&
      selectedOptionIds.isEmpty &&
      choice == null;
}

/// The confirmation of an attempt. Never a mark.
@immutable
class AttemptConfirmation {
  const AttemptConfirmation({
    required this.id,
    required this.submittedAt,
    this.attemptNumber,
    this.attemptsRemaining,
  });

  final String id;
  final DateTime submittedAt;
  final int? attemptNumber;
  final int? attemptsRemaining;
}

/// One answer of an attempt with its question and marks.
@immutable
class AttemptAnswer {
  const AttemptAnswer({
    required this.question,
    this.answerText,
    this.selectedOptionIds,
    this.choice,
    this.autoScore,
    this.awardedScore,
    this.feedback,
  });

  final AssessmentQuestion question;
  final String? answerText;
  final List<String>? selectedOptionIds;
  final bool? choice;
  final double? autoScore;
  final double? awardedScore;
  final String? feedback;

  /// Waiting for a person to mark it.
  bool get awaitingMark => awardedScore == null;
}

/// Where a submission stands for the teacher marking it.
enum MarkingStatus {
  /// Written answers wait for a person and none is marked yet.
  notMarked,

  /// Some written answers are marked, others still wait.
  partlyMarked,

  /// Every answer has a mark; the grade is a draft nobody else can see.
  marked,

  /// The grade is published to the student and their parents.
  published,

  /// The rest are for a student with nothing handed in: nothing recorded
  /// yet; recorded absent, privately; published as absent; or, corrected
  /// after publication, not graded. Absence is never a score.
  notSubmitted,
  absent,
  absentPublished,
  notGradedPublished,
}

/// An attempt. [answers] is empty for a student or parent until released.
@immutable
class AttemptDetail {
  const AttemptDetail({
    required this.id,
    required this.studentId,
    required this.submittedAt,
    this.attemptNumber,
    this.studentName,
    this.needsMarking,
    this.awardedScore,
    this.feedback,
    this.answers = const [],
    this.gradeState,
    this.gradeMark,
    this.pendingAnswers,
    this.manualAnswers,
  });

  final String id;
  final String studentId;
  final DateTime submittedAt;
  final int? attemptNumber;
  final String? studentName;
  final bool? needsMarking;
  final double? awardedScore;
  final String? feedback;
  final List<AttemptAnswer> answers;

  /// For the class's teachers: the student's grade - 'draft', 'reviewed',
  /// 'published' or 'withdrawn' - or null before there is one.
  final String? gradeState;

  /// For the class's teachers: how the grade is marked - 'scored', 'absent'
  /// or 'not_graded' - or null while unmarked.
  final String? gradeMark;

  /// For the class's teachers, in the marking list: answers still waiting
  /// for a person, and how many need a person at all.
  final int? pendingAnswers;
  final int? manualAnswers;

  bool get published => gradeState == 'published';

  /// Published as absent, though this attempt was handed in afterwards:
  /// the teacher replaces the absence, as a correction, from here.
  bool get publishedAbsent => published && gradeMark == 'absent';

  MarkingStatus get markingStatus {
    if (published) return MarkingStatus.published;
    if (!(needsMarking ?? false)) return MarkingStatus.marked;
    final pending =
        pendingAnswers ?? answers.where((answer) => answer.awaitingMark).length;
    final manual =
        manualAnswers ??
        answers.where((answer) => answer.autoScore == null).length;
    return pending < manual
        ? MarkingStatus.partlyMarked
        : MarkingStatus.notMarked;
  }
}

/// A published grade with the teacher's feedback and attachments.
@immutable
class ReleasedGrade {
  const ReleasedGrade({
    required this.maximumScore,
    this.score,
    this.mark,
    this.feedback,
    this.publishedAt,
    this.attachments = const [],
    this.links = const [],
    this.sharedAttachments = const [],
    this.sharedLinks = const [],
  });

  final double? score;
  final double maximumScore;
  final String? mark;
  final String? feedback;
  final DateTime? publishedAt;
  final List<StoredAttachment> attachments;
  final List<ContentLink> links;
  final List<StoredAttachment> sharedAttachments;
  final List<ContentLink> sharedLinks;

  bool get hasAttachments =>
      attachments.isNotEmpty ||
      links.isNotEmpty ||
      sharedAttachments.isNotEmpty ||
      sharedLinks.isNotEmpty;
}

/// A student's own view of an online assessment, or a parent's of their
/// child's: each attempt's confirmation, the published grade, and - once
/// released - the answers.
@immutable
class AssessmentResults {
  const AssessmentResults({
    required this.assessment,
    required this.studentId,
    required this.attemptsAllowed,
    required this.attemptsUsed,
    required this.canAttempt,
    required this.answersReleased,
    this.opensAt,
    this.closesAt,
    this.attempts = const [],
    this.grade,
  });

  final OnlineAssessment assessment;
  final String studentId;
  final DateTime? opensAt;
  final DateTime? closesAt;
  final int attemptsAllowed;
  final int attemptsUsed;
  final bool canAttempt;
  final bool answersReleased;
  final List<AttemptDetail> attempts;
  final ReleasedGrade? grade;

  bool get notOpenYet {
    final opens = opensAt;
    return opens != null && DateTime.now().isBefore(opens);
  }
}

/// A teacher's mark for one answer.
@immutable
class AnswerMark {
  const AnswerMark({
    required this.questionId,
    required this.score,
    this.feedback,
  });

  final String questionId;
  final double score;
  final String? feedback;
}

/// A paper grade's attachments: the class's shared ones, or one student's.
@immutable
class GradeAttachments {
  const GradeAttachments({this.attachments = const [], this.links = const []});

  final List<StoredAttachment> attachments;
  final List<ContentLink> links;
}

/// Online assessments: building, sitting, marking and releasing them.
abstract interface class OnlineAssessmentRepository {
  Future<OnlineAssessment> createOnlineAssessment(OnlineAssessmentDraft draft);

  /// The questions with their keys, for the class's teachers.
  Future<List<AssessmentQuestion>> authoringQuestions(String assessmentId);

  /// The questions as a student sits them: never a key.
  Future<List<AssessmentQuestion>> questions(String assessmentId);

  /// Changes the questions (only before anyone has attempted it), the
  /// settings, the material, or releases the answers by hand.
  Future<OnlineAssessment> updateAssessmentDesign(
    String assessmentId,
    int expectedVersion, {
    String? title,
    List<QuestionDraft>? questions,
    AssessmentSettings? settings,
    bool releaseAnswersNow = false,
    AttachmentChanges attachments = const AttachmentChanges(),
  });

  Future<AttemptConfirmation> submitAnswers(
    String assessmentId,
    List<StudentAnswer> answers,
  );

  /// The caller's own results, or - for a parent - their child's.
  Future<AssessmentResults> results(String assessmentId, {String? studentId});

  /// Every attempt, for the class's staff.
  Future<List<AttemptDetail>> attempts(String assessmentId);
  Future<AttemptDetail> attempt(String attemptId);

  /// Saves marks and feedback. While the grade is unpublished they are a
  /// draft only the class's teachers see. Once it is published, a change is
  /// a correction and needs [correctionReason]; without one the server
  /// refuses it ([CourseworkProblem.reasonRequired]) and changes nothing.
  Future<AttemptDetail> markAttempt(
    String attemptId,
    List<AnswerMark> marks, {
    String? feedback,
    String? correctionReason,
  });

  /// More time ([closesAt]) or attempts for one student.
  Future<void> grantAccess(
    String assessmentId,
    String studentId, {
    DateTime? closesAt,
    int extraAttempts = 0,
    String? reason,
  });

  /// A paper grade's attachments: shared with the class when [studentId] is
  /// null, else that student's own.
  Future<GradeAttachments> updateGradeAttachments(
    String assessmentId,
    AttachmentChanges changes, {
    String? studentId,
  });
}
