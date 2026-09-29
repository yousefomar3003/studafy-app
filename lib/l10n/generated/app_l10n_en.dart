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
  String get classesInviteCodeLabel => 'Class code';

  @override
  String get classesInviteLinkLabel => 'Or send this link';

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
  String classesShareMessageWithCode(String link, String code) {
    return 'Join my Studafy class: $link\nOr type the class code: $code';
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
  String get submitMaterialHeading => 'From your teacher';

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
  String get joinClassTitle => 'Join a class';

  @override
  String get joinClassPrompt =>
      'Type the class code your teacher gave you, or paste the class link.';

  @override
  String get joinClassField => 'Class code or link';

  @override
  String get joinClassPaste => 'Paste';

  @override
  String get joinClassNothingToPaste =>
      'Nothing has been copied. Type the class code, or open the link from your teacher\'s message - the app fills it in for you.';

  @override
  String get joinClassAction => 'Join class';

  @override
  String get joinClassBusy => 'Joining…';

  @override
  String get joinClassInvalid =>
      'That is not a class code or link. A code looks like K7QM-4XTR.';

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

  @override
  String get historyTitle => 'Hand-in history';

  @override
  String get historyYours => 'Hand-in history';

  @override
  String get historyLatest => 'Latest';

  @override
  String get historyEarlier => 'Earlier';

  @override
  String historyByGuardian(String name) {
    return 'Handed in by $name';
  }

  @override
  String get historyByParent => 'Handed in by a parent';

  @override
  String get historyNone => 'Nothing handed in yet.';

  @override
  String get historyLoadFailed =>
      'The history could not be loaded. Please try again.';

  @override
  String get historyNoText => 'No written answer.';

  @override
  String get academicPublish => 'Publish';

  @override
  String get academicPublished => 'Published. The class can see it now.';

  @override
  String get academicPublishFailed =>
      'That could not be published. Please try again.';

  @override
  String academicGradedOutOf(String score) {
    return 'Graded · out of $score';
  }

  @override
  String get classesNewCode => 'New code';

  @override
  String get classesNewCodeTitle => 'Make a new code?';

  @override
  String get classesNewCodeBody =>
      'The current code and link will stop working. Anyone who has not joined yet will need the new one.';

  @override
  String get classesNewCodeConfirm => 'Make new code';

  @override
  String get attendancePreviousLesson => 'Previous lesson';

  @override
  String get attendanceNextLesson => 'Next lesson';

  @override
  String get submissionsGrade => 'Grade';

  @override
  String get attachmentThatFileCouldNotBe => 'That file could not be uploaded.';

  @override
  String get attachmentThatFileIsEmpty => 'That file is empty.';

  @override
  String get attachmentOnlyPdfAndPhotosCan =>
      'Only PDF and photos can be attached.';

  @override
  String attachmentThatFileIsLargerThan(Object maximumSizeBytes) {
    return 'That file is larger than $maximumSizeBytes MB.';
  }

  @override
  String get attachmentAttachFile => 'Attach file';

  @override
  String get attachmentPhoto => 'Photo';

  @override
  String attachmentUpToMaximumcountAttachments(Object maximumCount) {
    return 'Up to $maximumCount attachments.';
  }

  @override
  String get attachmentUploading => 'Uploading';

  @override
  String get attachmentChecking => 'Checking';

  @override
  String get attachmentReady => 'Ready';

  @override
  String get attachmentFailed => 'Failed';

  @override
  String get attachmentThisFileIsStillBeing =>
      'This file is still being checked. Try again shortly.';

  @override
  String get attachmentThatFileCouldNotBe2 => 'That file could not be opened.';

  @override
  String get studentTodayALittleProgressEveryDay =>
      'A LITTLE PROGRESS, EVERY DAY';

  @override
  String get studentTodayYourClassesYourIdeasYour =>
      'Your classes, your ideas, your next big thing.';

  @override
  String get studentTodayMyNotebook => 'My notebook';

  @override
  String get studentTodayLessonNotesSubscription =>
      'Lesson notes · Subscription';

  @override
  String get studentTodayMyWork => 'My work';

  @override
  String get studentTodayTakeTheNextStep => 'Take the next step';

  @override
  String get studentTodayMyIdFamily => 'My ID & family';

  @override
  String get studentTodayShareYourIdReviewParent =>
      'Share your ID. Review parent requests.';

  @override
  String get studentTodayYourClasses => 'Your classes';

  @override
  String get studentTodayReadyWhenYouAre => 'Ready when you are';

  @override
  String get studentTodayYourWorkCouldNotLoad =>
      'Your work could not load. Open My work to retry.';

  @override
  String get studentTodayALittleBreathingRoom => 'A little breathing room';

  @override
  String get studentTodayNewAssignmentsWillAppearHere =>
      'New assignments will appear here when your teacher shares them.';

  @override
  String get teacherShellManageRosterStaffAndMeetings =>
      'Manage roster, staff and meetings';

  @override
  String get teacherShellClasses => 'Classes';

  @override
  String get teacherShellMessages => 'Messages';

  @override
  String get schoolAdminGuardians => 'Guardians';

  @override
  String get teacherTodaySpaceToInspireADay =>
      'Space to inspire. A day to make a difference.';

  @override
  String get studentLessonsPlans => 'Plans';

  @override
  String get studentLessonsYourClassesCouldNotBe =>
      'Your classes could not be loaded. Try again';

  @override
  String get studentLessonsJoinAClassToSee =>
      'Join a class to see its lessons here.';

  @override
  String get studentLessonsLessonsAndYourNotebook =>
      'Lessons and your notebook';

  @override
  String get studentLessonsMyNotebook => 'My notebook';

  @override
  String get studySetQuizzesAndFlashcardsComeWith =>
      'Quizzes and flashcards come with Studafy Max.';

  @override
  String get studySetThisMonthSAiAllowance =>
      'This month\'s AI allowance is used. It renews on the 1st.';

  @override
  String get studySetThisLessonHasNoText =>
      'This lesson has no text to study from.';

  @override
  String get studySetThisIsNotAvailableYet => 'This is not available yet.';

  @override
  String get studySetThatDidNotWorkPlease =>
      'That did not work. Please try again.';

  @override
  String studySetYouScoredScoreOfQuestionscount(
    Object score,
    Object questionsCount,
  ) {
    return 'You scored $score of $questionsCount';
  }

  @override
  String studySetAnswerscountOfQuestionscountAnswered(
    Object answersCount,
    Object questionsCount,
  ) {
    return '$answersCount of $questionsCount answered';
  }

  @override
  String get studySetTryAgain => 'Try again';

  @override
  String studySetCardPageOfCardscountTap(Object page, Object cardsCount) {
    return 'Card $page of $cardsCount - tap to turn over';
  }

  @override
  String studyPlansQuestionsTodayAsktodayOfAskperday(
    Object askToday,
    Object askPerDay,
  ) {
    return 'Questions today: $askToday of $askPerDay';
  }

  @override
  String studyPlansAiUsedThisMonthRound(Object round) {
    return 'AI used this month: $round%';
  }

  @override
  String studyPlansRenewsRenews(Object renews) {
    return 'Renews $renews';
  }

  @override
  String get studyPlansTheStoreCouldNotBe =>
      'The store could not be reached. Try again later.';

  @override
  String get studyPlansBuyingIsNotEnabledFor =>
      'Buying is not enabled for your account yet.';

  @override
  String get studyPlansWeAskedYourParentTo =>
      'We asked your parent to approve.';

  @override
  String get studyPlansWaitingForAParent => 'Waiting for a parent';

  @override
  String get studyPlansAskAParentToApprove => 'Ask a parent to approve';

  @override
  String get studyPlansOpeningTheStore => 'Opening the store…';

  @override
  String get studyPlansStartAFreeMonth => 'Start a free month';

  @override
  String studyPlansSubscribeToName(Object name) {
    return 'Subscribe to $name';
  }

  @override
  String get studyPlansFree => 'Free';

  @override
  String studyPlansPriceMonth(Object price) {
    return '$price / month';
  }

  @override
  String studyPlansUspriceMonthInTheUs(Object usPrice) {
    return '$usPrice / month in the US - the store shows your price';
  }

  @override
  String get studyPlansYourPlan => 'Your plan';

  @override
  String get studyPlansManageOrCancel => 'Manage or cancel';

  @override
  String get studyPlansRestoringPurchases => 'Restoring purchases…';

  @override
  String get studyPlansRestorePurchases => 'Restore purchases';

  @override
  String get studyPlansAutoRenewingMonthlySubscriptionsPayment =>
      'Auto-renewing monthly subscriptions. Payment is charged to your Apple or Google account. If a trial applies, billing starts when it ends. Cancel in store settings at least 24 hours before renewal to avoid the next charge. Deleting the app does not cancel a subscription.';

  @override
  String get studyPlansTermsOfUse => 'Terms of use';

  @override
  String get studyPlansPrivacyPolicy => 'Privacy policy';

  @override
  String get notebookThisNeedsStudafyPlus => 'This needs Studafy Plus.';

  @override
  String get notebookNoWritingCouldBeRead =>
      'No writing could be read in that photo. Try a clearer one.';

  @override
  String get notebookThePhotoIsTakingLonger =>
      'The photo is taking longer than usual to check. Try again shortly.';

  @override
  String get notebookNewNote => 'New note';

  @override
  String get notebookSave => 'Save';

  @override
  String get notebookAddATitleAndSome => 'Add a title and some text.';

  @override
  String get notebookChooseAJpegOrPng =>
      'Choose a JPEG or PNG photo under 10 MB.';

  @override
  String get notebookUploadingThePhoto => 'Uploading the photo…';

  @override
  String get notebookReadingTheWhiteboard => 'Reading the whiteboard…';

  @override
  String get notebookNotesAddedToYourNotebook =>
      'Notes added to your notebook.';

  @override
  String get notebookThePhotoCouldNotBe => 'The photo could not be uploaded.';

  @override
  String get notebookDeleteThisNote => 'Delete this note?';

  @override
  String get notebookDelete => 'Delete';

  @override
  String get notebookToday => 'Today';

  @override
  String get notebookYesterday => 'Yesterday';

  @override
  String get notebookAddNote => 'Add note';

  @override
  String get notebookSnapTheWhiteboard => 'Snap the whiteboard';

  @override
  String get notebookFromPhotos => 'From photos';

  @override
  String get notebookWhiteboardNotesComeWithStudafy =>
      'Whiteboard notes come with Studafy Plus.';

  @override
  String get notebookTheNotebookCouldNotBe =>
      'The notebook could not be loaded. Try again';

  @override
  String get notebookYourNotebookForThisClass =>
      'Your notebook for this class is empty. Add a note, or snap the whiteboard.';

  @override
  String get notebookFromTheWhiteboard => 'From the whiteboard';

  @override
  String get familyHomeTogetherEveryDay => 'TOGETHER, EVERY DAY';

  @override
  String get familyHomeTheirWorldIsGrowingBe =>
      'Their world is growing. Be part of it.';

  @override
  String get childSwitcherChooseChild => 'Choose child';

  @override
  String get familyChallengeSecurityCheck => 'Security check';

  @override
  String get familyChallengeTheCheckCouldNotLoad =>
      'The check could not load. Go back and try again.';

  @override
  String get studentFamilyIsThisYourParent => 'Is this your parent?';

  @override
  String get studentFamilyConfirmYourChoice => 'Confirm your choice';

  @override
  String studentFamilyOnlyApproveGuardiannameIfYou(Object guardianName) {
    return 'Only approve $guardianName if you know this is your parent or guardian. They will be able to see your grades, attendance and shared school updates.';
  }

  @override
  String get studentFamilyThisPersonWillNotHave =>
      'This person will not have access through this family link.';

  @override
  String get studentFamilyConfirm => 'Confirm';

  @override
  String get studentFamilyMyFamily => 'My family';

  @override
  String get studentFamilyYourConnections => 'YOUR CONNECTIONS';

  @override
  String get studentFamilyYourFamilyYourChoice => 'Your family.\nYour choice.';

  @override
  String get studentFamilyShareYourStudafyIdWith =>
      'Share your Studafy ID with your parent. You decide who can follow your progress.';

  @override
  String get studentFamilyCouldNotLoadRequests => 'Could not load requests';

  @override
  String get studentFamilyMyStudafyId => 'MY STUDAFY ID';

  @override
  String get studentFamilyCopyId => 'Copy ID';

  @override
  String get studentFamilyIdCopied => 'ID copied';

  @override
  String get studentFamilyJoinAClassToActivate =>
      'Join a class to activate your student ID.';

  @override
  String get studentFamilyParentRequests => 'Parent requests';

  @override
  String get studentFamilyAllCaughtUp => 'All caught up';

  @override
  String get studentFamilyNewParentRequestsWillAppear =>
      'New parent requests will appear here.';

  @override
  String get studentFamilyAccountId => 'Account ID';

  @override
  String get studentFamilyThisIsMyParent => 'This is my parent';

  @override
  String get studentFamilyDecline => 'Decline';

  @override
  String get studentFamilyConnected => 'Connected';

  @override
  String get studentFamilyRemoveAccess => 'Remove access';

  @override
  String get studentFamilyDeclined => 'Declined';

  @override
  String get studentFamilyAccessRemoved => 'Access removed';

  @override
  String get lessonsUndated => 'Undated';

  @override
  String get lessonsLessonsCouldNotBeLoaded => 'Lessons could not be loaded.';

  @override
  String get lessonsNoLessonsYetTheyAppear =>
      'No lessons yet. They appear here as your teacher shares them.';

  @override
  String get meetingsGoogleMeetCouldNotBe => 'Google Meet could not be opened.';

  @override
  String get meetingsUpcomingMeetings => 'Upcoming meetings';

  @override
  String get meetingsCancelled => 'Cancelled';

  @override
  String get meetingsTheLinkWillAppearHere => 'The link will appear here.';

  @override
  String get meetingsJoin => 'Join';

  @override
  String get conversationSent => 'Sent';

  @override
  String get conversationDelivered => 'Delivered';

  @override
  String get conversationRead => 'Read';

  @override
  String get notificationsNotificationPreferences => 'Notification preferences';

  @override
  String get notificationPrefsAddPreference => 'Add preference';

  @override
  String get notificationPrefsChannel => 'Channel';

  @override
  String get notificationPrefsInApp => 'In app';

  @override
  String get notificationPrefsEmail => 'Email';

  @override
  String get notificationPrefsPush => 'Push';

  @override
  String get notificationPrefsCategory => 'Category';

  @override
  String get notificationPrefsAcademic => 'Academic';

  @override
  String get notificationPrefsMessagesAndAnnouncements =>
      'Messages and announcements';

  @override
  String get notificationPrefsMeetings => 'Meetings';

  @override
  String get notificationPrefsFamily => 'Family';

  @override
  String get notificationPrefsBilling => 'Billing';

  @override
  String get notificationPrefsAdd => 'Add';

  @override
  String get notificationPrefsPushPreferencesAreSavedBut =>
      'Push preferences are saved, but push delivery is not available on this device yet.';

  @override
  String get notificationPrefsNoPreferencesSavedAddOne =>
      'No preferences saved. Add one to choose a channel and category.';

  @override
  String get classroomAdminStaff => 'Staff';

  @override
  String get classroomAdminCreateAndEnrolStudent => 'Create and enrol student';

  @override
  String get classroomAdminCreatedStudentAwaitingEnrolment =>
      'Created student awaiting enrolment';

  @override
  String get classroomAdminStudentEnrolled => 'Student enrolled.';

  @override
  String get classroomAdminRetryEnrolment => 'Retry enrolment';

  @override
  String get classroomAdminEnrolByStudentId => 'Enrol by student ID';

  @override
  String get classroomAdminNoEnrolledStudents => 'No enrolled students.';

  @override
  String get classroomAdminTransfer => 'Transfer';

  @override
  String get classroomAdminWithdraw => 'Withdraw';

  @override
  String get classroomAdminAssignStaff => 'Assign staff';

  @override
  String get classroomAdminNoStaffAssignments => 'No staff assignments.';

  @override
  String get classroomAdminRemove => 'Remove';

  @override
  String classroomAdminRemoveDisplaynameFromThisClass(Object displayName) {
    return 'Remove $displayName from this class?';
  }

  @override
  String get classroomAdminStaffRemoved => 'Staff removed.';

  @override
  String get classroomAdminWholeClass => 'Whole class';

  @override
  String get classroomAdminScheduleMeeting => 'Schedule meeting';

  @override
  String get classroomAdminCreateTheMeetingInGoogle =>
      'Create the meeting in Google Meet, then paste its link here. Everyone invited is told in the app and can join from it.';

  @override
  String get classroomAdminNoUpcomingMeetings => 'No upcoming meetings.';

  @override
  String classroomAdminRecipientcountInvited(Object recipientCount) {
    return '$recipientCount invited';
  }

  @override
  String get classroomAdminLinkCopied => 'Link copied.';

  @override
  String get classroomAdminCopyLink => 'Copy link';

  @override
  String get classroomAdminMeetingCancelled => 'Meeting cancelled.';

  @override
  String get classroomAdminCancelMeeting => 'Cancel meeting';

  @override
  String get classroomAdminCreateStudent => 'Create student';

  @override
  String get classroomAdminDisplayName => 'Display name';

  @override
  String get classroomAdminAccountUuidOptional => 'Account UUID (optional)';

  @override
  String get classroomAdminStudentCreatedAndEnrolled =>
      'Student created and enrolled.';

  @override
  String get classroomAdminEnrolStudent => 'Enrol student';

  @override
  String get classroomAdminStudentRecordId => 'Student record ID';

  @override
  String classroomAdminWithdrawDisplaynameFromThisClass(Object displayName) {
    return 'Withdraw $displayName from this class?';
  }

  @override
  String get classroomAdminStudentWithdrawn => 'Student withdrawn.';

  @override
  String classroomAdminTransferDisplayname(Object displayName) {
    return 'Transfer $displayName';
  }

  @override
  String get classroomAdminTargetClass => 'Target class';

  @override
  String get classroomAdminStudentTransferred => 'Student transferred.';

  @override
  String get classroomAdminTeacherAccountUuid => 'Teacher account UUID';

  @override
  String get classroomAdminRole => 'Role';

  @override
  String get classroomAdminCoTeacher => 'Co-teacher';

  @override
  String get classroomAdminLeadTeacher => 'Lead teacher';

  @override
  String get classroomAdminAssign => 'Assign';

  @override
  String get classroomAdminStaffAssigned => 'Staff assigned.';

  @override
  String get classroomAdminStarts => 'Starts';

  @override
  String get classroomAdminTime => 'Time';

  @override
  String get classroomAdminDuration => 'Duration';

  @override
  String get classroomAdminMinutes => 'minutes';

  @override
  String get classroomAdminAudience => 'Audience';

  @override
  String get classroomAdminCreateItInGoogleMeet => 'Create it in Google Meet';

  @override
  String get classroomAdminGoogleMeetLink => 'Google Meet link';

  @override
  String get classroomAdminPasteALinkThatStarts =>
      'Paste a link that starts with https://meet.google.com/';

  @override
  String get classroomAdminSchedule => 'Schedule';

  @override
  String get classroomAdminMeetingScheduledEveryoneInvitedHas =>
      'Meeting scheduled. Everyone invited has been told.';

  @override
  String get rolesYourSpaceToGrow => 'YOUR SPACE TO GROW';

  @override
  String get studyPlansFeatureLessons => 'Lessons from every class, by date';

  @override
  String get studyPlansFeatureNotebook => 'Your own notebook for each class';

  @override
  String get studyPlansFeatureTenQuestions =>
      '10 questions a day to the study helper';

  @override
  String get studyPlansFeatureEverythingInFree => 'Everything in Free';

  @override
  String get studyPlansFeatureWhiteboard =>
      'Snap the whiteboard - get real notebook notes';

  @override
  String get studyPlansFeatureFortyQuestions => '40 questions a day';

  @override
  String get studyPlansFeatureEverythingInPlus => 'Everything in Plus';

  @override
  String get studyPlansFeatureQuizzes => 'Quizzes made from your lessons';

  @override
  String get studyPlansFeatureFlashcards => 'Flashcards made from your lessons';

  @override
  String get studyPlansFeatureSixtyQuestions => '60 questions a day';

  @override
  String get studentTodayMakeTodayYours => 'Make today yours.';

  @override
  String studentTodayMakeTodayYoursName(Object name) {
    return 'Make today yours, $name.';
  }

  @override
  String get studySetQuiz => 'Quiz';

  @override
  String get studySetFlashcards => 'Flashcards';

  @override
  String get studentTodayClassesCouldNotLoad =>
      'Your classes could not load. Pull down to retry.';

  @override
  String get studentTodayNoClassesYet => 'No classes yet';

  @override
  String get studentTodayPasteClassLink =>
      'Paste the class link your teacher shared to join your first class.';

  @override
  String studentTodayGradeSection(Object grade, Object section) {
    return 'Grade $grade · $section';
  }

  @override
  String get msgTitle => 'Messages';

  @override
  String get msgEmptyTitle => 'No conversations yet';

  @override
  String get msgEmptyMessage => 'Start a conversation with your school.';

  @override
  String get msgEmptyAwaitingLink =>
      'Once a child is linked to you, you can message their teachers here.';

  @override
  String get msgNew => 'New message';

  @override
  String get msgNoSchool => 'Choose a school to see messages.';

  @override
  String get msgRetry => 'Try again';

  @override
  String get msgErrorTitle => 'Messages could not load';

  @override
  String get msgComposeHint => 'Write a message';

  @override
  String get msgSend => 'Send';

  @override
  String get msgSendFailed => 'Not sent. Tap send to try again.';

  @override
  String get msgLoadOlder => 'Load earlier messages';

  @override
  String get msgYou => 'You';

  @override
  String get msgUnknownPerson => 'Someone';

  @override
  String get msgMenuReportConversation => 'Report conversation';

  @override
  String msgMenuReportPerson(String name) {
    return 'Report $name';
  }

  @override
  String msgMenuBlockPerson(String name) {
    return 'Block $name';
  }

  @override
  String get msgMenuBlocked => 'Blocked people';

  @override
  String get msgMessageReport => 'Report message';

  @override
  String get msgReportTitle => 'Report';

  @override
  String get msgReportIntro =>
      'Your report goes to your school\'s safeguarding team. The person you report is not told who reported them.';

  @override
  String get msgReportReason => 'What is the problem?';

  @override
  String get msgReasonHarassment => 'Bullying or harassment';

  @override
  String get msgReasonInappropriate => 'Inappropriate content';

  @override
  String get msgReasonSafety => 'I am worried about someone\'s safety';

  @override
  String get msgReasonSpam => 'Spam';

  @override
  String get msgReasonOther => 'Something else';

  @override
  String get msgReportDetails => 'Tell us more (optional)';

  @override
  String get msgReportConsent => 'The school may contact me about this report';

  @override
  String get msgReportAlsoBlock => 'Also block this person';

  @override
  String get msgReportSubmit => 'Send report';

  @override
  String get msgReportSent => 'Report sent. Thank you for telling us.';

  @override
  String get msgReportUrgent =>
      'If someone is in immediate danger, contact emergency services or a trusted adult now.';

  @override
  String msgBlockTitle(String name) {
    return 'Block $name?';
  }

  @override
  String get msgBlockMessage =>
      'You will not be able to message each other. Messages already sent stay visible to the school.';

  @override
  String get msgBlockConfirm => 'Block';

  @override
  String msgBlockDone(String name) {
    return '$name is blocked.';
  }

  @override
  String get msgCancel => 'Cancel';

  @override
  String get msgBlockedTitle => 'Blocked people';

  @override
  String get msgBlockedEmpty => 'You have not blocked anyone.';

  @override
  String get msgUnblock => 'Unblock';

  @override
  String get msgUnblockDone => 'Unblocked.';

  @override
  String get msgBlockedBanner =>
      'You blocked someone in this conversation. Unblock them to send messages.';

  @override
  String get msgNewTitle => 'New message';

  @override
  String get msgNewEmpty => 'No one is available to message.';

  @override
  String get msgNewSearch => 'Search people';

  @override
  String get msgSubjectHint => 'Subject (optional)';

  @override
  String get msgStart => 'Start conversation';

  @override
  String get msgRoleStaff => 'School staff';

  @override
  String get msgRoleStudent => 'Student';

  @override
  String get msgRoleGuardian => 'Parent or guardian';

  @override
  String msgGuardianOf(String names) {
    return 'Guardian of $names';
  }

  @override
  String get msgErrorMessagingDisabled =>
      'Your school has not turned on messaging yet.';

  @override
  String get msgErrorContactNotAllowed => 'You cannot message this person.';

  @override
  String get msgErrorForbidden =>
      'You cannot send messages here. You may have blocked someone, or someone may have blocked you.';

  @override
  String get msgErrorNotFound => 'This conversation is no longer available.';

  @override
  String get msgErrorInvalidState =>
      'You already reported this in the last day. The school has it.';

  @override
  String get msgErrorWindowClosed =>
      'You have sent many reports today. Please contact the school directly.';

  @override
  String get msgErrorRateLimited =>
      'Too many attempts. Wait a moment and try again.';

  @override
  String get msgErrorNetwork =>
      'Studafy could not reach the school. Check your connection.';

  @override
  String get msgErrorUnauthorized => 'Please sign in again.';

  @override
  String get msgErrorValidation => 'Write a message first.';

  @override
  String get msgErrorUnknown => 'Something went wrong. Please try again.';

  @override
  String get famTitle => 'My family';

  @override
  String get famChildren => 'My children';

  @override
  String get famEmptyTitle => 'No children linked yet';

  @override
  String get famEmptyMessage =>
      'Ask your child for their Studafy ID. They approve your request before you can follow their progress.';

  @override
  String get famLink => 'Link a child';

  @override
  String get famLinkTitle => 'Link a child';

  @override
  String get famLinkHint => 'Studafy ID';

  @override
  String get famLinkFind => 'Find';

  @override
  String get famLinkNotFound =>
      'No student has that Studafy ID. Check it and try again.';

  @override
  String famLinkConfirm(String name) {
    return 'Request link to $name';
  }

  @override
  String famLinkSent(String name) {
    return 'Request sent. $name must approve it before you can see their records.';
  }

  @override
  String get famStatusPending => 'Waiting for your child';

  @override
  String get famStatusVerified => 'Linked';

  @override
  String get famStatusDeclined => 'Request declined';

  @override
  String get famStatusRevoked => 'No longer linked';

  @override
  String get famView => 'View progress';

  @override
  String famProgressTitle(String name) {
    return '$name\'s progress';
  }

  @override
  String get famProgressAverage => 'Average of published grades';

  @override
  String famProgressGraded(String count) {
    return '$count published grades';
  }

  @override
  String get famProgressAttendance => 'Attendance';

  @override
  String famProgressSessions(String count) {
    return '$count recorded sessions';
  }

  @override
  String get famProgressNone => 'No data yet';

  @override
  String famProgressBreakdown(
    String present,
    String late,
    String absent,
    String excused,
  ) {
    return 'Present $present · Late $late · Absent $absent · Excused $excused';
  }

  @override
  String get famProgressSource =>
      'Calculated from grades the school has published and attendance it has recorded. Ask the school if something looks wrong.';

  @override
  String get famApprovalsTitle => 'Waiting for your approval';

  @override
  String famApprovalsDetail(String name) {
    return '$name asked to subscribe to Student Notebook.';
  }

  @override
  String get famApprovalsApprove => 'Approve';

  @override
  String get famApprovalsDecline => 'Decline';

  @override
  String get famApprovalsDone => 'Your decision was sent.';

  @override
  String get famRetry => 'Try again';

  @override
  String get famCancel => 'Cancel';

  @override
  String get famErrorTitle => 'Your family could not load';

  @override
  String get famErrorReauthRequired =>
      'For your security, sign out and sign in again, then approve.';

  @override
  String get famErrorForbidden => 'You do not have access to this.';

  @override
  String get famErrorNotFound => 'This is no longer available.';

  @override
  String get famErrorInvalidState => 'This request has already been decided.';

  @override
  String get famErrorRateLimited =>
      'Too many attempts. Wait a moment and try again.';

  @override
  String get famErrorNetwork =>
      'Studafy could not reach the school. Check your connection.';

  @override
  String get famErrorUnauthorized => 'Please sign in again.';

  @override
  String get famErrorValidation => 'Enter the Studafy ID.';

  @override
  String get famErrorUnknown => 'Something went wrong. Please try again.';

  @override
  String get accountAccountId => 'Account ID';

  @override
  String get accountAccountIdDetail =>
      'Share this with your school to link your account.';

  @override
  String get accountAccountIdCopied => 'Account ID copied';

  @override
  String get accountSwitchRole => 'Switch role';

  @override
  String get accountSwitchRoleDetail =>
      'You belong to this school in more than one role.';

  @override
  String get accountTitle => 'Account';

  @override
  String get accountSectionAccount => 'Account';

  @override
  String get accountSectionPreferences => 'Preferences';

  @override
  String get accountSectionPrivacy => 'Privacy and data';

  @override
  String get accountStudafyId => 'Your Studafy ID';

  @override
  String get accountStudafyIdDetail =>
      'Give this to a parent so they can ask to link.';

  @override
  String get accountStudafyIdCopy => 'Copy your Studafy ID';

  @override
  String get accountStudafyIdCopied => 'Studafy ID copied.';

  @override
  String get accountUnknown => 'Your account';

  @override
  String get accountLanguage => 'Language';

  @override
  String get accountSecurity => 'Sign-in and security';

  @override
  String get accountSecurityDetail =>
      'Devices, two-step verification, sign out everywhere';

  @override
  String get accountSignOut => 'Sign out';

  @override
  String get accountDelete => 'Delete account';

  @override
  String get accountRoleSchoolAdmin => 'School administrator';

  @override
  String get accountRoleTeacher => 'Teacher';

  @override
  String get accountRoleParent => 'Parent or guardian';

  @override
  String get accountRoleStudent => 'Student';

  @override
  String get accountExport => 'Download my data';

  @override
  String get accountExportDetail =>
      'Get a copy of the information Studafy holds about you.';

  @override
  String get accountExportRequest => 'Request';

  @override
  String get accountExportPending =>
      'Preparing your copy. This can take a few minutes.';

  @override
  String get accountExportCheck => 'Check';

  @override
  String get accountExportReady => 'Your copy is ready for 7 days.';

  @override
  String get accountExportDownload => 'Download';

  @override
  String get accountExportRequested =>
      'Request received. We are preparing your copy.';

  @override
  String get accountExportReauth =>
      'For your security, sign out and sign in again first.';

  @override
  String get accountExportExpired =>
      'That copy has expired. Request a new one.';

  @override
  String get accountExportFailed => 'That did not work. Please try again.';

  @override
  String get todayWork => 'Work you have set';

  @override
  String get todayWorkEmpty => 'You have not set any work yet.';

  @override
  String get todaySections => 'Sections needing content';

  @override
  String get todaySectionsEmpty =>
      'Every section you have taught has its content filed.';

  @override
  String get todaySectionsOutstanding => 'Content outstanding';

  @override
  String get todayTitle => 'Today';

  @override
  String get todayHello => 'Hello';

  @override
  String todayHelloName(String name) {
    return 'Hello, $name';
  }

  @override
  String get todayClasses => 'My classes';

  @override
  String todayStudents(String count) {
    return '$count students';
  }

  @override
  String get todayEmpty => 'No classes yet';

  @override
  String get todayEmptyDetail =>
      'Create your first class from the Classes tab.';

  @override
  String get todayError => 'Classes could not load';

  @override
  String get todayErrorDetail => 'Check your connection and try again.';

  @override
  String get todayRetry => 'Try again';

  @override
  String get todayMessages => 'Messages';

  @override
  String get todayNotifications => 'Notifications';

  @override
  String get navToday => 'Today';

  @override
  String get navClasses => 'Classes';

  @override
  String get navTeaching => 'Teaching';

  @override
  String get navGradebook => 'Gradebook';

  @override
  String get navInbox => 'Inbox';

  @override
  String get navLearning => 'Learning';

  @override
  String get navInsights => 'Insights+';

  @override
  String get navUpdates => 'Updates';

  @override
  String get navMessages => 'Messages';

  @override
  String get navNotebook => 'Notebook';

  @override
  String get navWork => 'Work';

  @override
  String get navGrades => 'Grades';

  @override
  String get notificationsFeedTitle => 'Notifications';

  @override
  String get notificationsFeedMarkAllRead => 'Mark all read';

  @override
  String get notificationsFeedErrorTitle => 'Couldn\'t load notifications';

  @override
  String get notificationsFeedRetry => 'Try again';

  @override
  String get notificationsFeedOfflineBanner =>
      'Showing your last saved notifications — reconnect to update.';

  @override
  String get notificationsFeedEmptyTitle => 'No notifications yet';

  @override
  String get notificationsFeedEmptyMessage =>
      'You\'ll see updates here as they happen.';

  @override
  String get notificationsFeedLoading => 'Loading…';

  @override
  String get notificationsFeedLoadMore => 'Load more';

  @override
  String get notificationCopyAcademicAssessmentPublishedTitle =>
      'Assessment published';

  @override
  String get notificationCopyAcademicAssessmentPublishedDetail =>
      'A new assessment is ready for one of your classes.';

  @override
  String get notificationCopyAcademicAssignmentPublishedTitle =>
      'Assignment published';

  @override
  String get notificationCopyAcademicAssignmentPublishedDetail =>
      'A new assignment is ready for one of your classes.';

  @override
  String get notificationCopyAcademicGradePublishedTitle => 'New grade';

  @override
  String get notificationCopyAcademicGradePublishedDetail =>
      'A grade was published. Open Grades to view it.';

  @override
  String get notificationCopyAcademicResourcePublishedTitle =>
      'New class material';

  @override
  String get notificationCopyAcademicResourcePublishedDetail =>
      'Your teacher shared new material for one of your classes.';

  @override
  String get notificationCopyAcademicWellbeingSharedTitle =>
      'Wellbeing note shared';

  @override
  String get notificationCopyAcademicWellbeingSharedDetail =>
      'A wellbeing note was shared with you.';

  @override
  String get notificationCopyBillingPurchaseApprovalRequestedTitle =>
      'Purchase approval needed';

  @override
  String get notificationCopyBillingPurchaseApprovalRequestedDetail =>
      'Your child asked you to approve a subscription.';

  @override
  String get notificationCopyBillingPurchaseApprovalApprovedTitle =>
      'Purchase approved';

  @override
  String get notificationCopyBillingPurchaseApprovalApprovedDetail =>
      'A guardian approved your subscription request.';

  @override
  String get notificationCopyBillingPurchaseApprovalDeclinedTitle =>
      'Purchase declined';

  @override
  String get notificationCopyBillingPurchaseApprovalDeclinedDetail =>
      'A guardian declined your subscription request.';

  @override
  String get notificationCopyMeetingsScheduledTitle => 'Meeting confirmed';

  @override
  String get notificationCopyMeetingsScheduledDetail =>
      'A meeting was scheduled. Check your calendar for the invitation.';

  @override
  String get notificationCopyMeetingsFailedTitle => 'Meeting not scheduled';

  @override
  String get notificationCopyMeetingsFailedDetail =>
      'A meeting you requested could not be scheduled. Please try again.';

  @override
  String get notificationCopyCommunicationsAnnouncementCreatedTitle =>
      'New announcement';

  @override
  String get notificationCopyCommunicationsAnnouncementCreatedDetail =>
      'A new announcement was posted.';

  @override
  String get notificationCopyCommunicationsMessageSentTitle => 'New message';

  @override
  String get notificationCopyCommunicationsMessageSentDetail =>
      'You received a new message.';

  @override
  String get notificationCopyFamilyGuardianLinkRequestedTitle =>
      'Connection request';

  @override
  String get notificationCopyFamilyGuardianLinkRequestedDetail =>
      'Someone requested to connect as a guardian.';

  @override
  String get notificationCopyFamilyGuardianLinkRevokedTitle =>
      'Connection removed';

  @override
  String get notificationCopyFamilyGuardianLinkRevokedDetail =>
      'A family connection was removed.';

  @override
  String get notificationCopyFamilyGuardianLinkVerifiedTitle =>
      'Connection verified';

  @override
  String get notificationCopyFamilyGuardianLinkVerifiedDetail =>
      'A family connection was verified.';

  @override
  String get notificationCopyInvitationsIssuedTitle => 'Invitation sent';

  @override
  String get notificationCopyInvitationsIssuedDetail =>
      'An invitation was issued.';

  @override
  String get notificationCopyMeetingsCancelledTitle => 'Meeting cancelled';

  @override
  String get notificationCopyMeetingsCancelledDetail =>
      'A scheduled meeting was cancelled.';

  @override
  String get notificationCopyMeetingsRequestedTitle => 'Meeting requested';

  @override
  String get notificationCopyMeetingsRequestedDetail =>
      'A meeting was requested.';

  @override
  String get notificationCopySchoolAdminClassroomStaffAssignedTitle =>
      'Staff assigned';

  @override
  String get notificationCopySchoolAdminClassroomStaffAssignedDetail =>
      'A staff member was assigned to a class.';

  @override
  String get notificationCopySchoolAdminClassroomStaffRemovedTitle =>
      'Staff removed';

  @override
  String get notificationCopySchoolAdminClassroomStaffRemovedDetail =>
      'A staff member was removed from a class.';

  @override
  String get notificationCopySchoolAdminMembershipGrantedTitle =>
      'Access granted';

  @override
  String get notificationCopySchoolAdminMembershipGrantedDetail =>
      'School access was granted.';

  @override
  String get notificationCopySchoolAdminStudentEnrolledTitle =>
      'Student enrolled';

  @override
  String get notificationCopySchoolAdminStudentEnrolledDetail =>
      'A student was enrolled.';

  @override
  String get notificationCopySchoolAdminStudentTransferredTitle =>
      'Student transferred';

  @override
  String get notificationCopySchoolAdminStudentTransferredDetail =>
      'A student was transferred between classes.';

  @override
  String get notificationCopySchoolAdminStudentWithdrawnTitle =>
      'Student withdrawn';

  @override
  String get notificationCopySchoolAdminStudentWithdrawnDetail =>
      'A student was withdrawn.';

  @override
  String get notificationCopySupportAccessApprovedTitle =>
      'Support access approved';

  @override
  String get notificationCopySupportAccessApprovedDetail =>
      'A support access request was approved.';

  @override
  String get notificationCopySupportAccessRequestedTitle =>
      'Support access requested';

  @override
  String get notificationCopySupportAccessRequestedDetail =>
      'Support access was requested.';

  @override
  String get notificationCopySupportAccessRevokedTitle =>
      'Support access revoked';

  @override
  String get notificationCopySupportAccessRevokedDetail =>
      'Support access was revoked.';

  @override
  String get notificationCopySupportAccessStartedTitle =>
      'Support session started';

  @override
  String get notificationCopySupportAccessStartedDetail =>
      'A support session has started.';

  @override
  String get notificationCopyGenericTitle => 'Notification';

  @override
  String get notificationCopyGenericDetail => 'You have a new update.';

  @override
  String familyPlusHeadline(String name) {
    return 'Family+ for $name';
  }

  @override
  String get familyPlusIntro =>
      'See how your child is really doing, and one useful thing to do this week.';

  @override
  String get familyPlusFeatureTrends =>
      'What changed this term, with the records behind every claim';

  @override
  String get familyPlusFeatureDue => 'Work due this week, so nothing slips';

  @override
  String get familyPlusFeatureSubjects =>
      'Marks by subject and attendance at a glance';

  @override
  String get familyPlusFeatureSchool =>
      'Notes the school chose to share with you';

  @override
  String familyPlusPrice(String price) {
    return '$price / month';
  }

  @override
  String get familyPlusUsPrice =>
      'US\$1.99 / month in the US - the store shows your price';

  @override
  String familyPlusTrial(String trial, String price) {
    return 'If eligible, free for $trial, then $price / month';
  }

  @override
  String familyPlusOneChild(String name) {
    return 'Covers $name only. Each child has their own Family+.';
  }

  @override
  String get familyPlusStartTrial => 'Start free trial';

  @override
  String familyPlusSubscribe(String name) {
    return 'Subscribe for $name';
  }

  @override
  String get familyPlusCheckingStore => 'Checking the store price...';

  @override
  String get familyPlusStoreUnavailable =>
      'The store could not be reached. Try again later.';

  @override
  String get familyPlusNotInThisBuild =>
      'Family+ cannot be bought in this version of the app.';

  @override
  String get familyPlusOpeningStore => 'Opening the store...';

  @override
  String get familyPlusRestore => 'Restore purchases';

  @override
  String get familyPlusRestoring => 'Checking your purchases...';

  @override
  String get familyPlusFailed => 'That did not work. Please try again.';

  @override
  String get familyPlusManage => 'Manage or cancel';

  @override
  String get familyPlusDisclosure =>
      'Auto-renewing monthly subscription, paid through your app store account. It renews unless cancelled at least 24 hours before the end of the period; cancel any time in your store subscription settings. Studafy never sees your card details.';

  @override
  String get familyPlusTerms => 'Terms of use';

  @override
  String get familyPlusPrivacy => 'Privacy policy';

  @override
  String get studySetMaxBadge => 'Studafy Max';

  @override
  String get studySetSwitchedOff =>
      'Quizzes and flashcards are not switched on yet.';

  @override
  String get studyAssistantOff =>
      'The study helper is not switched on yet. Your lessons and notebook work as usual.';

  @override
  String get studyAssistantUnavailable =>
      'The study helper could not answer just now. Please try again in a moment.';

  @override
  String get studyAssistantDailyLimit =>
      'You have used all of today\'s questions. You can ask again tomorrow.';

  @override
  String get accountsSwitchAccount => 'Switch account';

  @override
  String get accountsSwitchAccountDetail =>
      'Accounts on this device, and your children\'s accounts';

  @override
  String get accountsSheetTitle => 'Accounts';

  @override
  String get accountsAddAccount => 'Add account';

  @override
  String get accountsCreateChild => 'Create a child account';

  @override
  String get accountsCreateChildDetail => 'For a child with no email or phone';

  @override
  String get accountsSubAccount => 'Sub-account';

  @override
  String accountsSubAccountOf(String name) {
    return 'Sub-account · managed by $name';
  }

  @override
  String get accountsCurrent => 'Current account';

  @override
  String get accountsSwitching => 'Switching account…';

  @override
  String get accountsSwitch => 'Switch';

  @override
  String get accountsSwitchFailed =>
      'That account could not be opened. Sign in to it again with Add account.';

  @override
  String get accountsNeedsParent =>
      'This child account opens from the parent\'s account. Sign in to the parent\'s account on this device first.';

  @override
  String get childAccountTitle => 'Create a child account';

  @override
  String get childAccountIntro =>
      'For a young child with no email or phone. You open their account from yours and switch back any time. Their teachers see their work under their own name.';

  @override
  String get childAccountName => 'Child\'s name';

  @override
  String get childAccountNameHelp => 'As their teachers will see it';

  @override
  String get childAccountConsent =>
      'I am this child\'s parent or legal guardian, and I accept the Terms of Use and Privacy Policy on their behalf.';

  @override
  String get childAccountCreate => 'Create account';

  @override
  String childAccountCreated(String name) {
    return '$name\'s account is ready.';
  }

  @override
  String get childAccountNextStep =>
      'Next, switch to their account and join their class with the link or code from their teacher.';

  @override
  String childAccountOpenNow(String name) {
    return 'Switch to $name';
  }

  @override
  String get childAccountLimit => 'You can manage up to six child accounts.';

  @override
  String get childAccountUnavailable =>
      'Child accounts are not available on this server yet.';

  @override
  String get childAccountFailed =>
      'The account could not be created. Please try again.';

  @override
  String get msgVoiceRecord => 'Record a voice note';

  @override
  String get msgVoiceRecording => 'Recording';

  @override
  String get msgVoiceDiscard => 'Discard';

  @override
  String get msgVoiceSend => 'Send voice note';

  @override
  String get msgVoiceMessage => 'Voice message';

  @override
  String get msgVoicePlay => 'Play voice message';

  @override
  String get msgVoicePause => 'Pause';

  @override
  String get msgVoiceChecking => 'Checking voice message…';

  @override
  String get msgVoiceUnavailable => 'This voice message could not be played.';

  @override
  String get msgVoiceNoPermission =>
      'Allow microphone access in Settings to record voice notes.';

  @override
  String get msgVoiceTooShort => 'That was too short to send.';

  @override
  String get msgVoiceFailed =>
      'The voice note could not be sent. Please try again.';

  @override
  String get msgVoiceLimit =>
      'Voice notes can be up to 5 minutes, so this one was sent.';

  @override
  String get lessonNewTitle => 'New lesson';

  @override
  String get lessonTitleLabel => 'Lesson title';

  @override
  String get lessonNotesLabel => 'Lesson notes';

  @override
  String get lessonNotesHelp =>
      'What you taught. Students read this under Lessons.';

  @override
  String get lessonPickClassForFiles =>
      'Choose the class first to attach files.';

  @override
  String get lessonAudienceLabel => 'Who can see it';

  @override
  String get lessonAudienceBoth => 'Everyone';

  @override
  String get lessonAudienceStudents => 'Students';

  @override
  String get lessonAudienceParents => 'Parents';

  @override
  String get lessonClassRequired => 'Choose the class this lesson is for.';

  @override
  String get lessonTitleRequired => 'Give the lesson a title.';

  @override
  String get lessonContentRequired => 'Write some notes or attach a file.';

  @override
  String get lessonSave => 'Add lesson';

  @override
  String get lessonSaving => 'Adding…';

  @override
  String get lessonCreated => 'Lesson added.';

  @override
  String get lessonCreateFailed =>
      'The lesson could not be added. Please try again.';

  @override
  String get academicAddLesson => 'Add lesson';

  @override
  String get examMaterialHelp =>
      'Attach the exam paper, a revision sheet or anything students need.';

  @override
  String get teacherCreateAction => 'Create';

  @override
  String get teacherCreateTitle => 'Create';

  @override
  String get teacherCreateLesson => 'Lesson';

  @override
  String get teacherCreateLessonDetail => 'Notes and files for a class';

  @override
  String get teacherCreateAssignment => 'Assignment';

  @override
  String get teacherCreateAssignmentDetail =>
      'Work students hand in, graded or not';

  @override
  String get teacherCreateExam => 'Exam or assessment';

  @override
  String get teacherCreateExamDetail =>
      'Marked in the gradebook, with its paper attached';

  @override
  String get teacherCreateAnnouncement => 'Announcement';

  @override
  String get teacherCreateAnnouncementDetail =>
      'Tell a class or its parents something';

  @override
  String get teacherCreateAttendance => 'Attendance';

  @override
  String get teacherCreateAttendanceDetail =>
      'Take today\'s register for a class';

  @override
  String get teacherPickClass => 'Which class?';

  @override
  String get teacherNoClassesYet =>
      'Create a class first, from the Classes tab.';

  @override
  String get academicThisClass => 'This class';

  @override
  String get studyAssistantNewChat => 'New chat';

  @override
  String get studyAssistantHistory => 'Chat history';

  @override
  String get studyAssistantHistoryEmpty =>
      'No chats yet. Your chats are kept on this device only.';

  @override
  String get studyAssistantOnDevice => 'Kept on this device only';

  @override
  String get studyAssistantDeleteChat => 'Delete chat';

  @override
  String get studyAssistantDeleteAll => 'Delete all chats';

  @override
  String get studyAssistantDeleteAllConfirm =>
      'Delete every chat on this device? This cannot be undone.';

  @override
  String get studyAssistantDelete => 'Delete';

  @override
  String get studyAssistantCancel => 'Cancel';

  @override
  String get studyAssistantSend => 'Send';

  @override
  String get studyAssistantMessageHint => 'Ask a question…';

  @override
  String get studyAssistantTooShort => 'Write a little more first.';

  @override
  String studyAssistantMessageCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count messages',
      one: '1 message',
    );
    return '$_temp0';
  }

  @override
  String get studyAssistantYou => 'You';

  @override
  String get studyAssistantHelperName => 'Study helper';

  @override
  String get setupTitle => 'Tell us about you';

  @override
  String get setupIntro => 'We ask this once, the first time you sign in.';

  @override
  String get setupNameLabel => 'Your name';

  @override
  String get setupNameHelp =>
      'How your teachers, classmates and school will see you';

  @override
  String get setupNameRequired => 'Enter your name.';

  @override
  String get setupGenderLabel => 'Gender';

  @override
  String get setupGenderPrivate => 'Only you can see this.';

  @override
  String get setupGenderGirl => 'Girl';

  @override
  String get setupGenderBoy => 'Boy';

  @override
  String get setupGenderPreferNot => 'Prefer not to say';

  @override
  String get setupGenderRequired =>
      'Choose an answer - \"Prefer not to say\" is fine.';

  @override
  String get setupContinue => 'Continue';

  @override
  String get setupSaving => 'Saving…';

  @override
  String get setupFailed => 'That could not be saved. Please try again.';

  @override
  String get studyToolsTitle => 'Quizzes & flashcards';

  @override
  String get studyToolsReady =>
      'Make a quiz or flashcards from any lesson below.';

  @override
  String get studyToolsNoLessons =>
      'They appear under each lesson once your teacher adds one.';

  @override
  String get studyToolsLocked => 'Included with Studafy Max.';

  @override
  String get linksAdd => 'Add link';

  @override
  String get linksAddTitle => 'Add a link';

  @override
  String get linksInvalid => 'Enter a full web address starting with https://';

  @override
  String get linksRemove => 'Remove link';

  @override
  String get linksCancel => 'Cancel';

  @override
  String get linksOpenTitle => 'Open this link?';

  @override
  String get linksOpen => 'Open';

  @override
  String get notebookFromLesson => 'From a lesson';

  @override
  String get notebookPickLesson => 'Choose a lesson';

  @override
  String get notebookNoLessons => 'This class has no lessons yet.';

  @override
  String get notebookCopyLesson => 'Copy into my notebook';

  @override
  String get notebookCopyLessonDetail => 'The lesson as your teacher wrote it';

  @override
  String get notebookLessonNotes => 'Turn into study notes';

  @override
  String get notebookLessonNotesDetail =>
      'Headings, key terms and a summary - Studafy Plus';

  @override
  String get notebookLessonCopied => 'Added to your notebook.';

  @override
  String get notebookFromLessonBadge => 'From a lesson';

  @override
  String get notebookMyNotebooks => 'My notebooks';

  @override
  String get notebookClassGone =>
      'This class no longer exists - your notes are kept';

  @override
  String get notebookNoNotebooks =>
      'No notes yet. Notes you write in a class appear here, by class.';

  @override
  String notebookNoteCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count notes',
      one: '1 note',
    );
    return '$_temp0';
  }

  @override
  String get classDeleteAction => 'Delete class';

  @override
  String classDeleteTitle(String name) {
    return 'Delete $name?';
  }

  @override
  String get classDeleteBody =>
      'The class disappears for you and your students, and its join link stops working. Students keep every note in their notebook for it - it will show that the class no longer exists.';

  @override
  String get classDeleteConfirm => 'Delete class';

  @override
  String get classDeleteCancel => 'Keep it';

  @override
  String get classDeleted => 'Class deleted. Students keep their notes.';

  @override
  String get classDeleteFailed =>
      'The class could not be deleted. Please try again.';

  @override
  String get helperAdd => 'Add material or a photo';

  @override
  String get helperAddMaterial => 'Class material';

  @override
  String get helperAddMaterialDetail =>
      'A lesson or one of your notes to answer from';

  @override
  String get helperAddPhoto => 'Photo from library';

  @override
  String get helperTakePhoto => 'Take a photo';

  @override
  String get helperPhotoPlus => 'Photos come with Studafy Plus.';

  @override
  String get helperPhotoChecking => 'Checking the photo…';

  @override
  String get helperPhotoFailed =>
      'The photo could not be sent. Please try again.';

  @override
  String get helperAnsweringFrom => 'Answering from';

  @override
  String get helperRemove => 'Remove';

  @override
  String get helperPickTitle => 'Choose class material';

  @override
  String get helperPickClass => 'Which class?';

  @override
  String get helperLessons => 'Lessons';

  @override
  String get helperMyNotes => 'My notes';

  @override
  String get helperPickDone => 'Use these';

  @override
  String get helperPickLimit => 'Up to 5 at a time.';

  @override
  String get helperNothingInClass => 'This class has no lessons or notes yet.';

  @override
  String get helperNoClasses => 'Join a class to use its lessons here.';

  @override
  String get upgradeDailyLimitTitle => 'You\'ve used today\'s questions';

  @override
  String upgradeDailyLimitBody(int count) {
    return 'Your plan includes $count questions a day. You can ask again tomorrow.';
  }

  @override
  String get upgradeAllowanceTitle => 'This month\'s AI allowance is used';

  @override
  String get upgradeAllowanceBody =>
      'Your plan\'s AI allowance renews on the 1st of next month.';

  @override
  String upgradeFeatureTitle(String plan) {
    return 'This comes with $plan';
  }

  @override
  String get upgradeFeatureBody => 'Your current plan does not include it.';

  @override
  String upgradeWhatUnlocks(String plan) {
    return 'What $plan unlocks';
  }

  @override
  String get upgradeLargerAllowance => 'A larger monthly AI allowance';

  @override
  String get upgradeButton => 'Upgrade';

  @override
  String get upgradeNotNow => 'Not now';

  @override
  String get upgradeTopPlan => 'You\'re on Studafy Max, the largest plan.';

  @override
  String get studyPlansIncludedInYourPlan => 'Included in your plan';

  @override
  String studyPlansUpgradeToName(String name) {
    return 'Upgrade to $name';
  }

  @override
  String studyPlansUpgradeReplaces(String current) {
    return 'Your $current subscription is replaced right away, and the store credits what you have already paid for.';
  }

  @override
  String studyPlansRenewsOn(String date) {
    return 'Renews on $date';
  }

  @override
  String studyPlansCancelledUntil(String plan, String date) {
    return 'Cancelled. You keep $plan until $date and won\'t be charged again.';
  }

  @override
  String get studyPlansPausedNote =>
      'Paused in Google Play. No charges while it is paused, and it resumes on its own.';

  @override
  String studyPlansPaymentIssue(String store, String plan) {
    return '$store couldn\'t take the payment. Update your payment method to keep $plan.';
  }

  @override
  String get studyPlansUpdatePayment => 'Update payment method';

  @override
  String get studyPlansManageSubscription => 'Manage subscription';

  @override
  String get studyPlansCancelSubscription => 'Cancel subscription';

  @override
  String studyPlansPaidByParent(String store) {
    return 'A parent pays for this plan. Only they can change or cancel it, from their own $store account.';
  }

  @override
  String studyPlansBilledBy(String store) {
    return 'Billed monthly through $store';
  }

  @override
  String get studyPlansEndOfPeriod => 'the end of this billing period';

  @override
  String get studyPlansPayWithApple =>
      'You pay with the payment method in your Apple Account, such as a card, or Apple Pay where Apple offers it. Studafy never sees your card.';

  @override
  String get studyPlansPayWithGoogle =>
      'You pay with the payment method in your Google Play account, such as a card, or Google Pay where Google offers it. Studafy never sees your card.';

  @override
  String get studyPlansBuyInMobileApp =>
      'Plans are bought in the Studafy app for iPhone or Android. A plan bought there works here when you sign in with the same account.';

  @override
  String get studyPlansBlockedAlready => 'You already have this plan.';

  @override
  String get studyPlansBlockedParent =>
      'A parent pays for your current plan, so only they can change it.';

  @override
  String studyPlansBlockedOtherStore(String store) {
    return 'Your current plan is billed by $store. Change it there, on the device you bought it with.';
  }

  @override
  String get studyPlansBlockedOriginalAccount =>
      'Google Play can only upgrade your plan from the Google account that bought it. Use that account in the Play Store, or cancel your current plan first.';

  @override
  String get cancelSheetTitle => 'Before you cancel';

  @override
  String get cancelPauseTitle => 'Pause instead';

  @override
  String cancelPauseBody(String plan, String date) {
    return 'Take a break for 1 week to 3 months. You keep $plan until $date. Then it pauses: no $plan features and no charges until it resumes on its own. You can resume early.';
  }

  @override
  String get cancelPauseButton => 'Pause in Google Play';

  @override
  String cancelCancelBody(String plan, String date) {
    return 'You keep $plan until $date and won\'t be charged again. After that you\'re on Studafy Free, and your notebook and lessons stay.';
  }

  @override
  String cancelInStore(String store) {
    return 'Cancel in $store';
  }

  @override
  String cancelStoreNote(String store) {
    return '$store handles your subscription, so this opens its subscriptions page. Choose Studafy there.';
  }

  @override
  String get cancelKeepPlan => 'Keep my plan';

  @override
  String get notificationCopyBillingSubscriptionActiveTitle =>
      'Subscription active';

  @override
  String get notificationCopyBillingSubscriptionActiveDetail =>
      'Your subscription is active. Apple or Google Play emails your receipt.';

  @override
  String get notificationCopyBillingSubscriptionRenewedTitle =>
      'Subscription renewed';

  @override
  String get notificationCopyBillingSubscriptionRenewedDetail =>
      'Your subscription renewed. Apple or Google Play emails your receipt.';

  @override
  String get notificationCopyBillingPaymentProblemTitle => 'Payment problem';

  @override
  String get notificationCopyBillingPaymentProblemDetail =>
      'Your subscription could not be renewed. Check your payment method in the App Store or Google Play.';

  @override
  String get notificationCopyBillingSubscriptionEndedTitle =>
      'Subscription ended';

  @override
  String get notificationCopyBillingSubscriptionEndedDetail =>
      'Your subscription has ended. You can subscribe again from Plans.';

  @override
  String get notificationCopySystemPushTestTitle => 'Test notification';

  @override
  String get notificationCopySystemPushTestDetail =>
      'Notifications are working on this device.';

  @override
  String get famLinkHasAccount => 'My child has a Studafy account';

  @override
  String get famLinkHasAccountBody =>
      'Find them by the Studafy ID on their profile. They approve the link from their account.';

  @override
  String get famLinkCreateAccount => 'Create an account for my child';

  @override
  String get famLinkCreateAccountBody =>
      'For a child with no email or phone. You manage the account and open it from yours. No approval from your child is needed.';

  @override
  String get famManagedTitle => 'Child accounts you manage';

  @override
  String get famManagedHint =>
      'Open your child\'s account to join their class with the class code. Their progress then shows here.';

  @override
  String get famManagedOpen => 'Open account';
}
