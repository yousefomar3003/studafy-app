// ignore: unused_import
import 'package:intl/intl.dart' as intl;

import 'app_l10n.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppL10nEn extends AppL10n {
  AppL10nEn([String locale = 'en']) : super(locale);

  @override
  String get languagePickerTitle => 'App language';

  @override
  String get languagePickerSubtitle =>
      'The interface direction changes automatically.';

  @override
  String get languageSystemDefault => 'System default';

  @override
  String get languageSystemDefaultDetail => 'Follow this phone\'s language';

  @override
  String get languageEnglish => 'English';

  @override
  String get languageArabic => 'العربية';

  @override
  String get securityTitle => 'Account security';

  @override
  String get securityLoadFailed =>
      'Could not load your security settings. Try again.';

  @override
  String get securityTryAgain => 'Try again';

  @override
  String get securityCodeMismatch => 'That code did not match.';

  @override
  String get securitySetupFailed => 'Could not set up two-factor sign-in.';

  @override
  String get securitySignOutDeviceTitle => 'Sign out this device?';

  @override
  String securitySignOutDeviceBody(String device) {
    return '$device will need to sign in again.';
  }

  @override
  String get securityKeepIt => 'Keep it';

  @override
  String get securitySignItOut => 'Sign it out';

  @override
  String get securityRevokeFailed => 'Could not sign that device out.';

  @override
  String get securitySignOutEverywhereTitle => 'Sign out everywhere?';

  @override
  String get securitySignOutEverywhereBody =>
      'Every device signed in to this account will be signed out, including this one. Sessions stop working immediately.';

  @override
  String get securityCancel => 'Cancel';

  @override
  String get securitySignOutEverywhere => 'Sign out everywhere';

  @override
  String get securityTwoFactorHeading => 'TWO-FACTOR SIGN-IN';

  @override
  String get securityTwoFactorOn => 'Turned on';

  @override
  String get securityTwoFactorOff => 'Not set up';

  @override
  String get securityTwoFactorOnDetail =>
      'You use an authenticator app when signing in.';

  @override
  String get securityTwoFactorOffDetail =>
      'School administrators must turn this on before they can manage a school.';

  @override
  String get securitySetUp => 'Set up';

  @override
  String get securityDevicesHeading => 'WHERE YOU ARE SIGNED IN';

  @override
  String get securityNoOtherDevices => 'No other devices';

  @override
  String get securityOnlyThisDevice => 'Only this device is signed in.';

  @override
  String get securityThisDevice => 'this device';

  @override
  String get securityDeviceSignedOut => 'Signed out';

  @override
  String securityLastUsed(String when) {
    return 'Last used $when';
  }

  @override
  String get securitySignOut => 'Sign out';

  @override
  String get securityTotpTitle => 'Set up two-factor sign-in';

  @override
  String get securityTotpBody =>
      'Add this key to your authenticator app, then enter the six-digit code it shows.';

  @override
  String get securityVerify => 'Verify';

  @override
  String get securityJustNow => 'just now';

  @override
  String securityMinutesAgo(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count minutes ago',
      one: '1 minute ago',
    );
    return '$_temp0';
  }

  @override
  String securityHoursAgo(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count hours ago',
      one: '1 hour ago',
    );
    return '$_temp0';
  }

  @override
  String securityDaysAgo(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count days ago',
      one: '1 day ago',
    );
    return '$_temp0';
  }

  @override
  String get roleQuestion => 'How will you use Studafy?';

  @override
  String get roleChoosePrompt =>
      'Choose your role to personalize your experience.';

  @override
  String get roleContinue => 'Continue';

  @override
  String get roleTeacher => 'Teacher';

  @override
  String get roleTeacherDetail => 'Manage classes, attendance and learning';

  @override
  String get roleStudent => 'Student';

  @override
  String get roleStudentDetail => 'Learn, submit work and stay updated';

  @override
  String get roleParent => 'Parent';

  @override
  String get roleParentDetail => 'Follow progress and school updates';

  @override
  String loginWelcome(String role) {
    return 'Welcome, $role';
  }

  @override
  String get loginSubtitle =>
      'Use your school or personal account to continue.';

  @override
  String loginContinueWith(String provider) {
    return 'Continue with $provider';
  }

  @override
  String get loginConsentPrefix => 'I agree to the ';

  @override
  String get loginConsentAnd => ' and ';

  @override
  String get loginConsentSuffix => '.';

  @override
  String get loginTermsOfUse => 'Terms of Use';

  @override
  String get loginPrivacyPolicy => 'Privacy Policy';

  @override
  String get loginAcceptFirst => 'Please accept before signing in.';

  @override
  String get loginChangeRole => 'Change role';

  @override
  String get loginClose => 'Close';

  @override
  String get policyPrivacyBody =>
      'Studafy uses account, school, class, attendance, and communication data only to provide and secure the service. Schools control student records. We do not sell personal data. Contact your school to access, correct, or delete eligible records.';

  @override
  String get policyTermsBody =>
      'Use Studafy only for authorized school communication. Keep accounts secure, respect students and staff, and do not upload harmful or unlawful content. School policies continue to apply. Misuse may lead to account suspension.';

  @override
  String get deleteTitle => 'Delete account';

  @override
  String get deleteWarningTitle => 'This affects more than your profile';

  @override
  String get deleteWarningBody =>
      'Access to your profile, classes, messages, and personal files will end.';

  @override
  String get deleteWhatGoesHeading => 'WHAT WILL BE DELETED';

  @override
  String get deleteSchoolKeepsHeading => 'WHAT YOUR SCHOOL KEEPS';

  @override
  String get deleteSchoolKeepsBody =>
      'Schools are required to keep these education records. They stay with the school, not with your account, and deleting your account does not remove them. Ask your school if you need them corrected or erased.';

  @override
  String get deleteNoSchoolRecords =>
      'Your school holds no records for this account.';

  @override
  String get deleteSchoolAccessHeading => 'SCHOOL ACCESS THAT ENDS';

  @override
  String get deleteWhyHeading => 'TELL US WHY';

  @override
  String get deleteReasonLabel => 'Reason for leaving';

  @override
  String get deleteReasonNoLongerUsing => 'I no longer use Studafy';

  @override
  String get deleteReasonChangingSchools => 'I am changing schools';

  @override
  String get deleteReasonPrivacy => 'Privacy concerns';

  @override
  String get deleteReasonDuplicate => 'I have another account';

  @override
  String get deleteReasonUndisclosed => 'Prefer not to say';

  @override
  String get deleteAcknowledgementsHeading => 'ACKNOWLEDGEMENTS';

  @override
  String get deleteSavedWhatINeed => 'I saved what I need';

  @override
  String get deleteSavedWhatINeedDetail =>
      'Download a copy of personal data and files';

  @override
  String deleteUnderstandFinal(int days) {
    String _temp0 = intl.Intl.pluralLogic(
      days,
      locale: localeName,
      other: 'I understand this cannot be undone after $days days',
      one: 'I understand this cannot be undone after 1 day',
    );
    return '$_temp0';
  }

  @override
  String deleteCancelWindow(int days) {
    String _temp0 = intl.Intl.pluralLogic(
      days,
      locale: localeName,
      other: 'You can cancel in this app during the $days-day period',
      one: 'You can cancel in this app during the 1-day period',
    );
    return '$_temp0';
  }

  @override
  String get deleteUnderstandSchoolKeeps =>
      'I understand my school keeps some records';

  @override
  String deleteRetainedCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count education records stay with your school',
      one: '1 education record stays with your school',
      zero: 'No education records stay with your school',
    );
    return '$_temp0';
  }

  @override
  String deleteTypeToConfirm(String word, String email) {
    return 'Type $word to confirm deletion of $email.';
  }

  @override
  String get deleteWorking => 'Working…';

  @override
  String get deleteSchedule => 'Schedule account deletion';

  @override
  String get deleteConfirmIdentityNote =>
      'You will be asked to confirm it is you before this is scheduled.';

  @override
  String get deleteKeptSnack => 'Your account will be kept.';

  @override
  String get deleteScheduledTitle => 'Deletion scheduled';

  @override
  String deleteScheduledBody(String email, String date) {
    return '$email will be deleted after $date. Until then you can stop it here — you do not need to contact support.';
  }

  @override
  String get deleteKeepMyAccount => 'Keep my account';

  @override
  String get deleteTryAgain => 'Try again';

  @override
  String get recordProfile => 'Your profile';

  @override
  String get recordDevices => 'Signed-in devices';

  @override
  String get recordConsents => 'Consent records';

  @override
  String get recordNotifications => 'Notifications';

  @override
  String get recordAttendance => 'Attendance records';

  @override
  String get recordGrades => 'Grades';

  @override
  String get recordSubmissions => 'Submitted work';

  @override
  String get recordWellbeing => 'Wellbeing notes';

  @override
  String get academicTitle => 'Academic workspace';

  @override
  String get academicNoRecords => 'No records yet.';

  @override
  String get academicUnavailable =>
      'School data is unavailable. No local copy was saved.';

  @override
  String get academicRetry => 'Retry';

  @override
  String get academicFileNote => 'File text lesson note';

  @override
  String get academicNoteTitle => 'Text lesson note';

  @override
  String get academicNoteTitleLabel => 'Title';

  @override
  String get academicNoteBodyLabel => 'Note';

  @override
  String get academicAttachmentsUnavailable =>
      'Attachments are unavailable until file uploads are switched on.';

  @override
  String get academicNoteNotSaved =>
      'Not saved. Your text is kept here so you can retry.';

  @override
  String get academicCancel => 'Cancel';

  @override
  String get academicSaveToSchool => 'Save to school';

  @override
  String get feedContent => 'Lessons';

  @override
  String get feedAssignments => 'Assignments';

  @override
  String get feedAssessments => 'Assessments';

  @override
  String get feedGrades => 'Grades';

  @override
  String get feedAttendance => 'Attendance';

  @override
  String get feedWellbeing => 'Wellbeing';

  @override
  String get classesTitle => 'My classes';

  @override
  String get classesCreate => 'Create class';

  @override
  String get classesCreateTitle => 'Create a new classroom';

  @override
  String get classesNameLabel => 'Class name';

  @override
  String get classesRoomLabel => 'Room';

  @override
  String get classesGradeLabel => 'Grade';

  @override
  String classesGradeOption(int number) {
    return 'Grade $number';
  }

  @override
  String get classesSectionLabel => 'Section';

  @override
  String get classesWeeklyLabel => 'How many classes each week?';

  @override
  String classesWeeklyOption(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count classes',
      one: '1 class',
    );
    return '$_temp0';
  }

  @override
  String get classesChooseTimes => 'Choose the day and time for every class';

  @override
  String classesSessionNumber(int number) {
    return 'Class $number';
  }

  @override
  String get classesDayLabel => 'Day';

  @override
  String get classesTo => 'to';

  @override
  String get classesCancel => 'Cancel';

  @override
  String get classesCreateAction => 'Create classroom';

  @override
  String get classesInviteTitle => 'Invite students';

  @override
  String get classesInviteBody =>
      'Share this secure link. Students are added only after they open it and join the class.';

  @override
  String get classesInviteCopied => 'Invite link copied.';

  @override
  String get classesCopy => 'Copy';

  @override
  String get classesShareLink => 'Share link';

  @override
  String classesShareMessage(String link) {
    return 'Join my Studafy class: $link';
  }

  @override
  String classesGradeSection(String grade, String section) {
    return 'Grade $grade · Section $section';
  }

  @override
  String classesStudentCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count students',
      one: '1 student',
      zero: 'No students',
    );
    return '$_temp0';
  }

  @override
  String classesPerWeek(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count classes/week',
      one: '1 class/week',
    );
    return '$_temp0';
  }

  @override
  String get classesRoomTbd => 'Room to be decided';

  @override
  String get dashNotifications => 'Notifications';

  @override
  String get dashTakeAttendance => 'Take attendance';

  @override
  String get dashAddNotebook => 'Add lesson notebook';

  @override
  String get dashAttendanceRecorded => 'Attendance recorded';

  @override
  String get dashNotebookMissing => 'Notebook missing';

  @override
  String get attendancePresent => 'Present';

  @override
  String get attendanceAbsent => 'Absent';

  @override
  String get attendanceTardy => 'Tardy';

  @override
  String get attendanceExcused => 'Excused absence';

  @override
  String get attendanceExcusedReason => 'Reason for excused absence';

  @override
  String get attendanceSaved => 'Attendance saved successfully.';

  @override
  String get attendanceSave => 'Save attendance';

  @override
  String get notebookTitle => 'Lesson notebook';

  @override
  String get notebookLessonLabel => 'Lesson covered';

  @override
  String get notebookLessonHint => 'What did you teach today?';

  @override
  String get notebookHomeworkLabel => 'Homework (optional)';

  @override
  String get notebookSave => 'Save notebook';

  @override
  String get syntheticBanner => 'SYNTHETIC DATA — NOT FOR REAL SCHOOL USE';

  @override
  String get blockedTitle => 'Studafy is not production-ready';

  @override
  String get blockedDefaultReason =>
      'Production access is blocked until security and data-integrity gates pass.';

  @override
  String get blockedReference => 'Reference: SEC-001';

  @override
  String get blockedInvalidEnvironment =>
      'Invalid APP_ENV. This build has been blocked for safety.';

  @override
  String attendanceTitle(String className) {
    return 'Attendance · $className';
  }

  @override
  String get attendanceAction => 'Take attendance';

  @override
  String get attendanceWhichSession => 'Which session?';

  @override
  String get attendanceNoSessionThatDay =>
      'This class does not meet on the day you picked.';

  @override
  String get attendanceNoStudents => 'No students are enrolled in this class.';

  @override
  String get attendanceSaving => 'Saving…';

  @override
  String get attendanceMarkOne => 'Mark at least one student first.';

  @override
  String get attendanceLoadFailed =>
      'Could not load the register. Please try again.';

  @override
  String get attendanceReasonLabel => 'Reason (optional)';

  @override
  String rosterTitle(String className) {
    return 'Students · $className';
  }

  @override
  String get rosterAction => 'Students';

  @override
  String get rosterNoGuardian => 'No parent linked yet';

  @override
  String get rosterEmpty => 'No students are enrolled in this class yet.';

  @override
  String get rosterLoadFailed =>
      'Could not load the class list. Please try again.';

  @override
  String get rosterTryAgain => 'Try again';

  @override
  String attendanceSavedCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Register saved for $count students.',
      one: 'Register saved for 1 student.',
    );
    return '$_temp0';
  }

  @override
  String get assignmentNewTitle => 'New assignment';

  @override
  String get assignmentAction => 'New assignment';

  @override
  String get assignmentClassLabel => 'Class';

  @override
  String get assignmentTitleLabel => 'Title';

  @override
  String get assignmentInstructionsLabel => 'Instructions (optional)';

  @override
  String get assignmentDueLabel => 'Due';

  @override
  String get assignmentPickDue => 'Pick a due date';

  @override
  String get assignmentGradedLabel => 'Graded';

  @override
  String get assignmentGradedOn =>
      'Students receive a score out of the maximum you set.';

  @override
  String get assignmentGradedOff => 'Students hand work in, with no score.';

  @override
  String get assignmentMaxScoreLabel => 'Maximum score';

  @override
  String get assignmentCreate => 'Create assignment';

  @override
  String get assignmentCreating => 'Creating…';

  @override
  String get assignmentCreated => 'Assignment created.';

  @override
  String get assignmentTitleRequired => 'Give the assignment a title.';

  @override
  String get assignmentClassRequired => 'Choose which class this is for.';

  @override
  String get assignmentDueRequired => 'Choose when it is due.';

  @override
  String get assignmentMaxScoreRequired => 'Set a maximum score above zero.';

  @override
  String get assignmentCreateFailed =>
      'Could not create the assignment. Please try again.';

  @override
  String get announcementNewTitle => 'New announcement';

  @override
  String get announcementAction => 'Announce';

  @override
  String get announcementTitleLabel => 'Title';

  @override
  String get announcementBodyLabel => 'Message';

  @override
  String get announcementClassLabel => 'Class';

  @override
  String get announcementAudienceLabel => 'Who should see this';

  @override
  String get announcementAudienceStudents => 'Students';

  @override
  String get announcementAudienceGuardians => 'Parents and guardians';

  @override
  String get announcementAudienceBoth => 'Everyone';

  @override
  String get announcementImportantLabel => 'Mark as important';

  @override
  String get announcementImportantDetail =>
      'Use this for things that change what someone does today.';

  @override
  String get announcementPost => 'Post announcement';

  @override
  String get announcementPosting => 'Posting…';

  @override
  String get announcementPosted => 'Announcement posted.';

  @override
  String get announcementTitleRequired => 'Give the announcement a title.';

  @override
  String get announcementBodyRequired => 'Write the message.';

  @override
  String get announcementClassRequired => 'Choose which class to announce to.';

  @override
  String get announcementFailed =>
      'Could not post the announcement. Please try again.';

  @override
  String gradebookTitle(String className) {
    return 'Gradebook · $className';
  }

  @override
  String get gradebookAction => 'Gradebook';

  @override
  String get gradebookPickAssessment => 'Choose what to mark';

  @override
  String get gradebookNoAssessments =>
      'Nothing to mark yet. Create graded work first.';

  @override
  String get gradebookDraftNotice =>
      'This is still a draft. Publish it to open the register of marks.';

  @override
  String get gradebookPublishAssessment => 'Publish and start marking';

  @override
  String get gradebookNoStudents => 'No students are enrolled in this class.';

  @override
  String gradebookScoreOf(String max) {
    return 'out of $max';
  }

  @override
  String get gradebookSave => 'Save marks';

  @override
  String get gradebookSaving => 'Saving…';

  @override
  String get gradebookSaved => 'Marks saved.';

  @override
  String get gradebookNothingChanged => 'No marks were changed.';

  @override
  String get gradebookScoreTooHigh => 'A mark cannot be above the maximum.';

  @override
  String get gradebookLoadFailed =>
      'Could not load the gradebook. Please try again.';

  @override
  String get gradebookSaveFailed =>
      'Could not save the marks. Please try again.';

  @override
  String get gradebookRelease => 'Release to students';

  @override
  String get gradebookReleased => 'Marks released.';

  @override
  String sectionsTitle(String className) {
    return 'Sections · $className';
  }

  @override
  String get sectionsAction => 'Lesson content';

  @override
  String get sectionsNone =>
      'No sections have been taught yet. Take a register first.';

  @override
  String get sectionsOutstanding => 'Content outstanding';

  @override
  String get sectionsFiled => 'Closed';

  @override
  String get sectionsFileContent => 'File content';

  @override
  String get sectionsClose => 'Close section';

  @override
  String get sectionsClosed => 'Section closed.';

  @override
  String get sectionsCloseBlocked =>
      'File the content taught in this section before closing it.';

  @override
  String get sectionsContentTitle => 'What was taught';

  @override
  String get sectionsContentTitleLabel => 'Title';

  @override
  String get sectionsContentBodyLabel => 'Summary of the section';

  @override
  String get sectionsContentSave => 'File it';

  @override
  String get sectionsContentSaved => 'Content filed.';

  @override
  String get sectionsContentRequired =>
      'Write what was taught in this section.';

  @override
  String get sectionsLoadFailed =>
      'Could not load the sections. Please try again.';

  @override
  String get sectionsSaveFailed => 'Could not save. Please try again.';

  @override
  String get examNewTitle => 'New exam';

  @override
  String get examAction => 'New exam';

  @override
  String get examClassLabel => 'Class';

  @override
  String get examTitleLabel => 'Title';

  @override
  String get examCategoryLabel => 'Kind';

  @override
  String get examCategoryExam => 'Exam';

  @override
  String get examCategoryQuiz => 'Quiz';

  @override
  String get examCategoryMidterm => 'Midterm';

  @override
  String get examCategoryFinal => 'Final';

  @override
  String get examDeliveryLabel => 'How it is taken';

  @override
  String get examDeliveryPaper => 'On paper';

  @override
  String get examDeliveryPaperDetail =>
      'Sat in class; you enter the marks yourself.';

  @override
  String get examDeliveryOnline => 'In the app';

  @override
  String get examDeliveryOnlineDetail =>
      'Students answer the questions in Studafy.';

  @override
  String get examDeliveryPractice => 'Practice';

  @override
  String get examDeliveryPracticeDetail =>
      'Students practise freely; it does not count.';

  @override
  String get examScheduleLabel => 'When it is sat';

  @override
  String get examPickSchedule => 'Pick a date and time';

  @override
  String get examQuestionsLabel => 'Questions';

  @override
  String get examAddQuestion => 'Add question';

  @override
  String examQuestionPrompt(int number) {
    return 'Question $number';
  }

  @override
  String get examQuestionMarks => 'Marks';

  @override
  String get examQuestionAnswer => 'Model answer (optional)';

  @override
  String get examRemoveQuestion => 'Remove';

  @override
  String get examMoveUp => 'Move up';

  @override
  String get examMoveDown => 'Move down';

  @override
  String examTotalFromQuestions(String total, int count) {
    return 'Total: $total marks, from $count questions.';
  }

  @override
  String get examTotalLabel => 'Total marks';

  @override
  String get examNoQuestionsHint =>
      'No questions listed. Add them, or set the total marks and mark it on paper.';

  @override
  String get examCreate => 'Create exam';

  @override
  String get examCreating => 'Creating…';

  @override
  String get examCreated =>
      'Exam created as a draft. Publish it from the gradebook when you are ready.';

  @override
  String get examTitleRequired => 'Give the exam a title.';

  @override
  String get examClassRequired => 'Choose which class sits this exam.';

  @override
  String get examTotalRequired => 'Set the total marks above zero.';

  @override
  String get examQuestionPromptRequired => 'Every question needs its text.';

  @override
  String get examQuestionMarksRequired =>
      'Every question needs marks above zero.';

  @override
  String get examOnlineNeedsQuestions =>
      'An exam taken in the app needs at least one question.';

  @override
  String get examCreateFailed => 'Could not create the exam. Please try again.';

  @override
  String get examTotalHint =>
      'Students sit this outside the app. Enter the marks in the gradebook; each student sees their own.';

  @override
  String get gradeAwaiting => 'Not marked yet';

  @override
  String gradeScore(String score, String max) {
    return '$score out of $max';
  }

  @override
  String get submitTitle => 'Hand in work';

  @override
  String get submitAnswerLabel => 'Your work';

  @override
  String get submitAnswerHint => 'Type or paste your answer.';

  @override
  String get submitSend => 'Hand in';

  @override
  String get submitSending => 'Handing in…';

  @override
  String get submitDone => 'Work handed in.';

  @override
  String get submitEmpty => 'Write your answer before handing it in.';

  @override
  String get submitFailed => 'Could not hand in your work. Please try again.';

  @override
  String get submitClosed => 'This assignment is not open for work.';

  @override
  String get submitAttachmentsSoon =>
      'Attaching files is not available yet; paste a link if you need to share one.';

  @override
  String submissionsTitle(String title) {
    return 'Handed in · $title';
  }

  @override
  String get submissionsAction => 'Handed in';

  @override
  String get submissionsNone => 'Nobody has handed anything in yet.';

  @override
  String get submissionsWaiting => 'Not handed in';

  @override
  String submissionsOn(String when) {
    return 'Handed in $when';
  }

  @override
  String get submissionsLoadFailed =>
      'Could not load what was handed in. Please try again.';

  @override
  String submissionsCount(int done, int total) {
    return '$done of $total handed in';
  }

  @override
  String scheduleTitle(String className) {
    return 'Timetable · $className';
  }

  @override
  String get scheduleAction => 'Timetable';

  @override
  String get scheduleHint =>
      'The register follows this timetable, so a class that meets twice a week needs both here.';

  @override
  String get scheduleAddSlot => 'Add a meeting';

  @override
  String get scheduleWeekday => 'Day';

  @override
  String get scheduleStarts => 'Starts';

  @override
  String get scheduleEnds => 'Ends';

  @override
  String get scheduleRemove => 'Remove';

  @override
  String get scheduleSave => 'Save timetable';

  @override
  String get scheduleSaving => 'Saving…';

  @override
  String get scheduleSaved => 'Timetable saved.';

  @override
  String get scheduleEmpty =>
      'No meetings yet. Add one so the register knows when this class meets.';

  @override
  String get scheduleEndBeforeStart => 'A meeting cannot end before it starts.';

  @override
  String get scheduleSaveFailed =>
      'Could not save the timetable. Please try again.';

  @override
  String get weekdayMon => 'Monday';

  @override
  String get weekdayTue => 'Tuesday';

  @override
  String get weekdayWed => 'Wednesday';

  @override
  String get weekdayThu => 'Thursday';

  @override
  String get weekdayFri => 'Friday';

  @override
  String get weekdaySat => 'Saturday';

  @override
  String get weekdaySun => 'Sunday';

  @override
  String get joinLinkActive => 'A join link is live for this class.';

  @override
  String joinLinkUses(int count) {
    return 'Used $count times';
  }

  @override
  String joinLinkExpires(String when) {
    return 'Expires $when';
  }

  @override
  String get joinLinkRevoke => 'Revoke link';

  @override
  String get joinLinkRevoked =>
      'Link revoked. It no longer works for anyone holding it.';

  @override
  String get joinLinkRevokeFailed =>
      'Could not revoke the link. Please try again.';

  @override
  String get joinLinkNewReplaces => 'Creating a new link replaces this one.';
}
