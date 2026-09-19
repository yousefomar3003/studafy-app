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
}
