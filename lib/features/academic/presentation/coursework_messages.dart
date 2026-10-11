import '../../../l10n/generated/app_l10n.dart';
import '../domain/academic_repository.dart';

/// What to tell the person when the server refused a coursework command:
/// the cause and, where there is one, the fix.
String courseworkMessage(AppL10n l10n, CourseworkRefusal refusal) =>
    switch (refusal.problem) {
      CourseworkProblem.versionConflict => l10n.courseworkVersionConflict,
      CourseworkProblem.invalidState => l10n.courseworkInvalidState,
      CourseworkProblem.entriesInvalid => l10n.courseworkEntriesInvalid,
      CourseworkProblem.reasonRequired => l10n.courseworkReasonRequired,
      CourseworkProblem.attendanceLocked => l10n.courseworkAttendanceLocked,
      CourseworkProblem.submissionLocked => l10n.courseworkSubmissionLocked,
      CourseworkProblem.windowClosed => l10n.courseworkWindowClosed,
      CourseworkProblem.notAllowed => l10n.courseworkNotAllowed,
      CourseworkProblem.other => l10n.courseworkFailed,
    };

/// One refused row of a grade sheet, from the server's fixed reason code.
String gradeRowMessage(AppL10n l10n, String reason, String maximum) =>
    switch (reason) {
      'not_enrolled' => l10n.paperGradesRowNotEnrolled,
      'already_published' => l10n.paperGradesRowAlreadyPublished,
      'score_required' => l10n.paperGradesRowScoreRequired,
      'score_out_of_range' => l10n.paperGradesRowScoreOutOfRange(maximum),
      'score_not_allowed' => l10n.paperGradesRowScoreNotAllowed,
      'version_conflict' => l10n.paperGradesRowConflict,
      _ => l10n.paperGradesRowInvalid,
    };
