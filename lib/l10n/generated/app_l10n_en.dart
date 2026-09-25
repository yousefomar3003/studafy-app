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
  String get securitySignOutEverywhereFailed =>
      'This device is signed out, but your other devices could not be reached. Try again from a signed-in device.';

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
      'WHAT WE COLLECT\nYour name and email from the sign-in provider you choose; the school or class you belong to and your role in it; the work you are set and hand in, your marks, attendance and pastoral notes; messages, announcements and meetings inside the app; files you upload; and your notification settings.\n\nWHY\nTo run your classes, to keep your account secure, to bill subscriptions, and to meet legal duties. We do not sell personal data. We show no advertising. We do not use your data to train any AI model.\n\nTHE STUDY HELPER\nIf you use the study helper, the question you type is sent to an AI company outside Studafy so it can answer. Your name, school, marks, work and messages are never sent. Answers can be wrong, so check anything you hand in. Using the helper is optional.\n\nWHO SEES YOUR WORK\nStaff at your school whose role requires it, and a parent linked to you. Other students cannot see your marks, your submitted work or your private messages. Messages are stored on our servers and are not end-to-end encrypted.\n\nPARENTS AND CHILDREN\nA parent asks to be linked to a student, and the student approves or declines it on their own device. A parent can follow progress; a parent is not given your private messages.\n\nPAYMENTS\nSubscriptions are charged by Apple or Google under their own terms. We never see your card.\n\nWHO ELSE PROCESSES DATA\nSupabase hosts the database, sign-in and files; Amazon Web Services hosts the app and its technical logs; Redis holds short-lived counters; Google, Microsoft and Apple verify sign-in; Cloudflare runs a bot check; Resend sends email and Firebase sends push notifications. Each acts only on our instructions.\n\nWHERE YOUR DATA IS\nData may be processed outside your country, including outside the EEA, protected by Standard Contractual Clauses or an adequacy decision.\n\nWHAT WE CANNOT DELETE\nRecords of significant actions are append-only and cannot be edited or removed, including by us. Schools are often required to keep attendance, assessment and safeguarding records. The app shows you which records stay with your school before you confirm a deletion.\n\nHOW WE PROTECT IT\nAccess to a school\'s data is enforced in the database itself. Secrets are stripped from logs. IP addresses are stored only as a one-way hash. Administrator accounts require two-factor sign-in. Files are scanned before they can be downloaded.\n\nYOUR RIGHTS\nYou may ask for a copy of your data, correct it, delete your account, restrict or object to processing, or withdraw consent. Account deletion and data export are in Account settings, and deletion can be cancelled for 14 days. You may complain to the Data Protection Commission in Ireland at any time.\n\nIf your school controls your records, ask your school first; we will pass your request on and tell you we have.';

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
  String get notebookTitle => 'My notebook';

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
  String get submissionsByGuardian => 'Handed in by a parent';

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

  @override
  String get notebookActive => 'Notebook is active';

  @override
  String get notebookManage => 'Manage';

  @override
  String get notebookRefresh => 'Refresh';

  @override
  String get notebookHeroEyebrow => 'YOUR LEARNING, TOGETHER';

  @override
  String get notebookHeroTitle => 'A home for every lesson.';

  @override
  String get notebookHeroSubtitle =>
      'Keep your teachers’ lesson notes and learning materials close.';

  @override
  String get notebookPlanName => 'Notebook · Monthly';

  @override
  String notebookPricePerMonth(String price) {
    return '$price / month';
  }

  @override
  String notebookTrialThenPrice(String price) {
    return '1 month free, then $price each month.';
  }

  @override
  String get notebookNoTrial =>
      'Renews monthly. No free trial is confirmed for this store account.';

  @override
  String get notebookPriceUnconfirmed =>
      'Your store confirms the price before you subscribe.';

  @override
  String get notebookPriceUnconfirmedDetail =>
      'A one-month free trial is planned for eligible new subscribers. The store must confirm local pricing and eligibility before you can subscribe.';

  @override
  String get notebookScope =>
      'Only Notebook requires this subscription. Your assignments, grades and messages remain available.';

  @override
  String get notebookStatusUnavailable =>
      'We could not check your subscription. Retry to check access.';

  @override
  String get notebookSelfPurchaseDisabled =>
      'Student purchasing is not enabled for your account yet.';

  @override
  String get notebookApprovalRequired =>
      'A linked parent must approve before you subscribe. Approval does not start a trial or charge anyone.';

  @override
  String get notebookApprovalRequestSent =>
      'Request sent. Your parent can approve it from their home page.';

  @override
  String get notebookApprovalWaiting => 'Waiting for parent approval';

  @override
  String get notebookApprovalAsk => 'Ask my parent';

  @override
  String get notebookPurchaseStarted =>
      'Complete the store sheet. Access starts after your purchase is verified; refresh if needed.';

  @override
  String get notebookStartFreeMonth => 'Start my free month';

  @override
  String get notebookSubscribeMonthly => 'Subscribe monthly';

  @override
  String get notebookCheckoutUnavailable =>
      'Checkout opens once store terms, account approval and subscription policies are available.';

  @override
  String get notebookRestoreRequested =>
      'Restore requested. Access appears after store verification.';

  @override
  String get notebookRestore => 'Restore purchases';

  @override
  String get notebookManageOrCancel => 'Manage or cancel subscription';

  @override
  String get notebookRenewalDisclosure =>
      'Auto-renewing subscription. Payment is charged to your Apple or Google account. If a trial applies, billing starts when it ends. Cancel in store settings at least 24 hours before renewal or the trial ends to avoid the next charge. Deleting the app does not cancel your subscription.';

  @override
  String get notebookTermsOfUse => 'Terms of Use';

  @override
  String get notebookPrivacyPolicy => 'Privacy Policy';

  @override
  String get notebookActionFailed =>
      'Could not complete this step. Check your connection and your parent link, then try again.';

  @override
  String get notebookOpenPageFailed => 'Could not open the page.';

  @override
  String get joinClassTitle => 'Join a class';

  @override
  String get joinClassPrompt =>
      'Paste the class link your teacher shared with you.';

  @override
  String get joinClassField => 'Class link';

  @override
  String get joinClassAction => 'Join class';

  @override
  String get joinClassBusy => 'Joining…';

  @override
  String get joinClassInvalid => 'That does not look like a class link.';

  @override
  String joinClassDone(String className) {
    return 'You\'re in $className';
  }

  @override
  String get joinClassContinue => 'Done';

  @override
  String get onboardingStudentTitle => 'Join your first class';

  @override
  String get onboardingStudentBody =>
      'Ask your teacher for the class link, then paste it here to get started.';

  @override
  String get onboardingParentTitle => 'Link to your child';

  @override
  String get onboardingParentBody =>
      'Ask your child for their Studafy ID. They approve the request on their own device, so nobody else can see their work.';

  @override
  String get onboardingParentAction => 'Continue';

  @override
  String get onboardingTeacherTitle => 'Teacher accounts are almost ready';

  @override
  String get onboardingTeacherBody =>
      'Creating classes from a new teacher account is not switched on yet. Please check back shortly.';

  @override
  String get onboardingTeacherReadyTitle => 'Set up your teaching space';

  @override
  String get onboardingTeacherReadyBody =>
      'We\'ll get everything ready so you can create your first class and invite students to it.';

  @override
  String get onboardingTeacherReadyAction => 'Get started';

  @override
  String get onboardingNotReadyYet =>
      'Your account is ready, but we couldn\'t open it just yet. Please try again.';

  @override
  String get onboardingChangeRole => 'Choose a different role';

  @override
  String get onboardingSignOut => 'Sign out';

  @override
  String get studyAssistantTitle => 'Study helper';

  @override
  String get studyAssistantIntro =>
      'Ask about anything you are studying and get an explanation. Your question is sent to an AI service to answer it, so do not include your name, your school or anything private.';

  @override
  String get studyAssistantField => 'Your question';

  @override
  String get studyAssistantAsk => 'Ask';

  @override
  String get studyAssistantBusy => 'Thinking…';

  @override
  String get studyAssistantCheckWork =>
      'Answers can be wrong. Check anything you hand in.';

  @override
  String studyAssistantRemaining(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count questions left today',
      one: '1 question left today',
      zero: 'No questions left today',
    );
    return '$_temp0';
  }

  @override
  String get studyAssistantTab => 'Helper';

  @override
  String get joinClassAlreadyStaff =>
      'You already teach at this school, so you cannot join one of its classes as a student. Ask a student to open the link on their own account.';

  @override
  String get academicAllClasses => 'All classes';

  @override
  String get insightsTitle => 'Family+';

  @override
  String get insightsUnavailableTitle => 'Insights are not available';

  @override
  String get insightsUnavailableBody =>
      'Family+ is needed to see detailed insights, and the link to your child must be approved.';

  @override
  String get insightsNothingYetTitle => 'Nothing to report yet';

  @override
  String get insightsNothingYetBody =>
      'As your child\'s school records marks, attendance and work, insights will appear here. We only report what the records actually show.';

  @override
  String get insightsBySubject => 'By subject';

  @override
  String get insightsComingUp => 'Coming up';

  @override
  String get insightsFromSchool => 'From the school';

  @override
  String get insightsAverage => 'Average';

  @override
  String get insightsAttendance => 'Attendance';

  @override
  String get insightsOnTime => 'On time';

  @override
  String insightSubjectFocus(Object subject) {
    return '$subject is their weakest subject right now';
  }

  @override
  String insightTrendDown(Object subject) {
    return '$subject marks are going down';
  }

  @override
  String insightTrendUp(Object subject) {
    return '$subject marks are going up';
  }

  @override
  String insightRecovery(Object subject) {
    return '$subject has recovered';
  }

  @override
  String get insightHomework => 'How reliably work is handed in';

  @override
  String get insightHomeworkSlipping =>
      'Work is being handed in later than before';

  @override
  String get insightAttendancePattern =>
      'Absences fall on the same day of the week';

  @override
  String get insightDueSoon => 'Work due soon that has not been handed in';

  @override
  String get insightStrengthInsufficient =>
      'Not enough records yet to be confident';

  @override
  String get insightStrengthLow => 'Based on a small number of records';

  @override
  String get insightStrengthMedium => 'Based on a reasonable number of records';

  @override
  String get insightStrengthHigh => 'Based on a large number of records';

  @override
  String insightsDueOn(String date) {
    return 'Due $date';
  }

  @override
  String insightsFromMarks(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'From $count marks',
      one: 'From 1 mark',
      zero: 'No marks yet',
    );
    return '$_temp0';
  }

  @override
  String insightsAbsences(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count absences',
      one: '1 absence',
      zero: 'No absences',
    );
    return '$_temp0';
  }

  @override
  String insightsOfTasks(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Of $count tasks',
      one: 'Of 1 task',
      zero: 'No work set',
    );
    return '$_temp0';
  }

  @override
  String get insightsNoChildTitle => 'Choose a child first';

  @override
  String get insightsNoChildBody =>
      'Pick one of your children on the home tab to see their insights.';
}
