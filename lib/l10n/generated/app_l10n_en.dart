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
  String get introSkip => 'Skip';

  @override
  String get introNext => 'Next';

  @override
  String get introStart => 'Get started';

  @override
  String introPageOf(int index, int total) {
    return 'Page $index of $total';
  }

  @override
  String get introTitleOne => 'Your whole school day in one place';

  @override
  String get introBodyOne =>
      'Lessons, homework, marks and attendance - teachers, students and parents, together.';

  @override
  String get introTitleTwo => 'Every mark counts, on paper or online';

  @override
  String get introBodyTwo =>
      'Teachers mark paper exams and online work in one gradebook. Families see a mark once it is published.';

  @override
  String get introTitleThree => 'Parents see what matters';

  @override
  String get introBodyThree =>
      'Follow progress and attendance - and with Family+, each class\'s trend and what to focus on this week. No ads, and your data is never sold.';

  @override
  String get roleWhatIsStudafy => 'What is Studafy?';

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
      'WHAT WE COLLECT\nYour name and email from the sign-in provider you choose, and your gender only if you choose to give it (it is shown to nobody else). The school or class you belong to and your role in it. Lessons, the work you are set and hand in, each earlier hand-in, your marks and the history of any change to them, your attendance, pastoral notes, and your own notebook. Messages, voice notes, announcements and meeting links inside the app. Files you upload. Your subscriptions and notification settings.\n\nWHY\nTo run your classes, to keep your account secure, to bill subscriptions, and to meet legal duties. We do not sell personal data. We show no advertising. We do not use your data to train any AI model.\n\nMARKS AND ATTENDANCE\nTeachers can mark work done on paper as well as work handed in online. A mark is a draft that only your teachers can see until the teacher publishes it; a missing mark is never counted as zero. If a published mark is corrected, we keep the old mark, the new one, who changed it, when and why, and you and your parents are told if the mark changed. Attendance changes after the lesson\'s day need a reason, only the class\'s lead teacher can change a register more than seven days old, and every change is kept. Deadlines are set in your school\'s time zone.\n\nWHO SEES YOUR WORK\nYour class\'s teachers, and a parent linked to you once a mark is published. There is no school administrator in this version of the app. Other students cannot see your marks, your work or your private messages. Messages are stored on our servers and are not end-to-end encrypted.\n\nPARENTS AND CHILDREN\nA parent asks to be linked to a student, and the student approves or declines it on their own device. A parent may also create and manage an account for a child with no email or phone, and accepts these terms for the child. A linked parent sees published marks, attendance, work and class material, and can hand work in for a young child, but cannot change marks or attendance and is not given the child\'s private messages. Family+ is a paid plan for parents that covers up to 4 or up to 8 linked children, earliest linked first. For each child it covers it summarises what the parent can already see - marks by class, trends, attendance, missing work and missed tests - compares the child only with their own earlier record, and uses no AI.\n\nAI STUDY TOOLS\nThese tools are optional. When you use them, what you give them is sent to Together AI, an AI company outside Studafy: the question you type and the recent turns of the same chat, and - if you choose - a lesson\'s text, your own notes, or a photo you add (the study helper, whiteboard notes, lesson notes, quizzes and flashcards). Your name, email, school and marks are never sent. Chats are kept only on your device. Answers can be wrong, so never hand them in as your own work. AI never marks your work.\n\nFILES\nFiles are stored privately, scanned before anyone can download them, and opened only through links that work once and expire within minutes. Hidden details are removed from photos and voice notes. If a teacher replaces or removes a file, the class no longer sees it, but it is kept for the school.\n\nPAYMENTS\nStudafy Plus, Studafy Max and Family+ are charged by Apple or Google under their own terms. We never see your card.\n\nWHO ELSE PROCESSES DATA\nSupabase hosts the database, sign-in and files; Amazon Web Services hosts the app and its technical logs; GitHub stores encrypted backups it cannot read; Redis holds short-lived counters; Google, Microsoft and Apple verify sign-in; Cloudflare runs a bot check; Together AI runs the AI study tools; Resend sends email and Firebase sends push notifications, which never contain your marks or messages; meetings happen in Google Meet. Each acts only on our instructions.\n\nWHERE YOUR DATA IS\nData may be processed outside your country, including outside the EEA, protected by Standard Contractual Clauses or an adequacy decision.\n\nWHAT WE CANNOT DELETE\nRecords of significant actions are append-only and cannot be edited or removed, including by us. This includes the history of marks and attendance, earlier hand-ins, and files a teacher replaced. Schools are often required to keep attendance, assessment and safeguarding records. The app shows you which records stay with your school before you confirm a deletion. Encrypted backups are kept for 30 days.\n\nON YOUR DEVICE\nThe app keeps your session, your language, a cache of what you opened and downloaded, your study helper chats and your profile photo, separately for each account. Your profile photo is never uploaded to our servers, so nobody else sees it. They are cleared when that account signs out.\n\nHOW WE PROTECT IT\nAccess to a class\'s data is enforced in the database itself, and only that class\'s teachers can change its marks and attendance. Secrets are stripped from logs. IP addresses are stored only as a one-way hash. Backups are encrypted before they leave our systems.\n\nYOUR RIGHTS\nYou may ask for a copy of your data, correct it, delete your account, restrict or object to processing, or withdraw consent. Account deletion and data export are in Account settings, and deletion can be cancelled for 14 days; a parent does this for a child account they manage. You may complain to the Data Protection Commission in Ireland at any time.\n\nIf your school controls your records, ask your school first; we will pass your request on and tell you we have.';

  @override
  String get policyTermsBody =>
      'WHO THIS IS FOR\nStudafy is for teachers, students and parents. There is no school administrator in this version of the app. By signing in you accept these terms and the Privacy Policy.\n\nYOUR ACCOUNT\nSign in with Google, Microsoft or Apple and keep that account secure. You can add several accounts to one device; sign out on a device you share. A parent may create an account for a child with no email or phone, accepts these terms for the child, and is responsible for how it is used. Do not impersonate anyone.\n\nUSE IT PROPERLY\nUse Studafy only for learning, teaching and school communication. Do not bully, harass or threaten anyone, share sexual, violent, hateful or unlawful content, upload files you have no right to share, try to see records that are not yours, or hand in someone else\'s work - or AI output - as your own. You can report or block anyone from inside the app. We may remove content and suspend accounts that break these rules.\n\nTEACHERS\nYou are responsible for the marks and attendance you record. Marks are drafts until you publish them. A published mark is changed only by correcting it with a reason, and the old mark is kept. Attendance changes after the lesson\'s day need a reason; after seven days only the class\'s lead teacher can change a register. Give students more time or reopen work with a reason. Files you replace or remove are kept for the school. Share only what you have the right to share.\n\nSTUDENTS\nHand in your own work. You can replace it until the deadline, which is in your school\'s time zone; earlier hand-ins are kept. After the deadline, or once a mark is published, you need your teacher\'s permission to hand in again. If a mark or attendance record looks wrong, ask your teacher.\n\nPARENTS\nYou can link to your child only with their approval, unless you created their account. You can see published marks, attendance, work and class material, and hand work in for a young child. You cannot change marks or attendance, and you do not see your child\'s private messages. Family+ is your own paid plan: one plan covers up to 4 linked children, a larger one up to 8, in the order you linked them. It summarises what you can already see, compares a child only with their own earlier record, and predicts nothing.\n\nYOUR CONTENT\nYou keep the rights in what you write and upload. You let us store and show it only to run Studafy for you and your school. Work handed in, marks, attendance and shared files become part of the school\'s records.\n\nAI STUDY TOOLS\nThey are optional and can be wrong. Check what they produce and never hand it in as your own work. AI never marks work. Daily and monthly limits apply.\n\nSUBSCRIPTIONS\nLessons, notebooks, work, marks and attendance are free. Studafy Plus and Studafy Max are for students; Family+ is for parents, for up to 4 or up to 8 linked children. All are billed monthly by Apple or Google at the price the store shows until you cancel in your store account, where refunds are also handled.\n\nMEETINGS\nStudafy does not host video calls. Meeting links open in Google Meet under Google\'s terms.\n\nCHANGES AND ENDING\nWe may change or withdraw features, and will tell you before a change to these terms that affects you. You can delete your account in Account settings and cancel within 14 days. Records the school must keep stay with the school.';

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
    return 'Join my Studafy class with the class code $code\nOr open this link: $link';
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
  String get scheduleDuplicate =>
      'Two lessons are on the same day and time. Change one of them.';

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
  String get insightMissingWork =>
      'Work missed its deadline and was never handed in';

  @override
  String insightMissingWorkIn(String subject) {
    return 'Work in $subject missed its deadline';
  }

  @override
  String get insightMissedTests => 'Tests were missed';

  @override
  String insightMissedTestsIn(String subject) {
    return 'A test in $subject was missed';
  }

  @override
  String get insightAttendanceLow => 'Attendance is below 90%';

  @override
  String insightStrength(String subject) {
    return '$subject is their strongest subject right now';
  }

  @override
  String insightEvClassAverage(String subject) {
    return '$subject average';
  }

  @override
  String get insightEvOverallAverage => 'Their average across all subjects';

  @override
  String get insightEvRecentTypical => 'Typical recent mark';

  @override
  String get insightEvEarlierTypical => 'Typical earlier mark';

  @override
  String get insightEvChange => 'Change (points)';

  @override
  String get insightEvOnTime => 'Handed in on time';

  @override
  String get insightEvLate => 'Handed in late';

  @override
  String get insightEvNotHandedIn => 'Not handed in';

  @override
  String insightEvWeekdayAbsences(String day) {
    return 'Absences on a $day';
  }

  @override
  String get insightEvAbsencesTotal => 'Absences in total';

  @override
  String get insightEvDueSoon => 'Due in the next 7 days, not handed in';

  @override
  String get insightEvMissed => 'Tests missed';

  @override
  String get insightEvAttendanceRate => 'Attended';

  @override
  String get insightEvSessions => 'Lessons counted';

  @override
  String get insightEvPastDue => 'Past the deadline, not handed in';

  @override
  String get insightsFocusTitle => 'What to focus on';

  @override
  String get insightsProgressTitle => 'Marks over time';

  @override
  String get insightsByClass => 'Class by class';

  @override
  String get insightsMissingTitle => 'Missing work';

  @override
  String get insightsRecentTitle => 'Latest marks';

  @override
  String get insightsMissedTests => 'Missed tests';

  @override
  String insightsTrendUp(int points) {
    return 'Up $points points compared with earlier';
  }

  @override
  String insightsTrendDown(int points) {
    return 'Down $points points compared with earlier';
  }

  @override
  String get insightsTrendSteady => 'Steady compared with earlier';

  @override
  String get insightsTrendUnknown => 'Not enough marks for a trend yet';

  @override
  String get insightsStrongest => 'Strongest';

  @override
  String get insightsWeakest => 'Weakest';

  @override
  String insightsClassAttendance(int rate) {
    return 'Attendance $rate%';
  }

  @override
  String insightsClassOnTime(int rate) {
    return 'On time $rate%';
  }

  @override
  String insightsMissingCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count missing',
      one: '1 missing',
      zero: 'Nothing missing',
    );
    return '$_temp0';
  }

  @override
  String insightsMissedCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count missed tests',
      one: '1 missed test',
    );
    return '$_temp0';
  }

  @override
  String get insightsMissed => 'Missed';

  @override
  String get insightsPaper => 'Paper';

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
      'You\'ve used your AI tokens. They renew on your plan\'s reset date.';

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
  String studyPlansRenewsRenews(Object renews) {
    return 'Renews $renews';
  }

  @override
  String get studyPlansTheStoreCouldNotBe =>
      'The store could not be reached. Try again later.';

  @override
  String get studyPlansPaymentsNotSetUp =>
      'Paid plans are not on sale yet. Everything free keeps working.';

  @override
  String get studyPlansCannotBuyYet =>
      'This plan cannot be bought yet - see the note under it.';

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
  String get studyPlansFeatureEverythingInFree => 'Everything in Free';

  @override
  String get studyPlansFeatureWhiteboard =>
      'Snap the whiteboard - get real notebook notes';

  @override
  String get studyPlansFeatureEverythingInPlus => 'Everything in Plus';

  @override
  String get studyPlansFeatureQuizzes => 'Quizzes made from your lessons';

  @override
  String get studyPlansFeatureFlashcards => 'Flashcards made from your lessons';

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
  String get notificationCopyAcademicGradesPublishedTitle => 'New marks';

  @override
  String get notificationCopyAcademicGradesPublishedDetail =>
      'Your teacher published new marks. Open Grades to view them.';

  @override
  String get notificationCopyAcademicGradesCorrectedTitle =>
      'A mark was updated';

  @override
  String get notificationCopyAcademicGradesCorrectedDetail =>
      'Your teacher corrected a published mark. Open Grades to see the new one.';

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
      'One subscription for the family. See how each child is really doing, where they need help, and what to do about it this week.';

  @override
  String get familyPlusFeatureTrends =>
      'What changed this term, with the records behind every claim';

  @override
  String get familyPlusFeatureSchool =>
      'Notes the school chose to share with you';

  @override
  String get familyPlusFeatureFocus =>
      'What to focus on this week, most urgent first';

  @override
  String get familyPlusFeatureClasses =>
      'Every class side by side - average, trend, attendance and homework, with the strongest and weakest named';

  @override
  String get familyPlusFeatureChart =>
      'Marks over time on a chart, and the latest marks - paper exams included';

  @override
  String get familyPlusFeatureMissing =>
      'Missing work and missed tests, so nothing slips';

  @override
  String familyPlusPlanName(int seats) {
    return 'Up to $seats children';
  }

  @override
  String familyPlusPlanDetail(int seats) {
    return 'One monthly price for the whole family: all your linked children, up to $seats.';
  }

  @override
  String get familyPlusYourPlan => 'Your plan';

  @override
  String familyPlusSubscribePlan(int seats) {
    return 'Subscribe for up to $seats children';
  }

  @override
  String familyPlusUpgrade(int seats) {
    return 'Upgrade to up to $seats children';
  }

  @override
  String get familyPlusCannotBuyYet =>
      'This plan cannot be bought in this version of the app yet.';

  @override
  String get familyPlusNotCoveredTitle => 'Not covered by your plan yet';

  @override
  String familyPlusNotCovered(int seats, String name) {
    return 'Your Family+ covers your first $seats linked children, and $name is not one of them. Move to the plan for up to 8 children to include $name.';
  }

  @override
  String get familyPlusCoversFamily =>
      'Your children are covered in the order you linked them. A child you link later is included straight away while the plan has room.';

  @override
  String familyPlusPrice(String price) {
    return '$price / month';
  }

  @override
  String familyPlusUsPrice(String price) {
    return '$price / month in the US - the store shows your price';
  }

  @override
  String familyPlusTrial(String trial, String price) {
    return 'If eligible, free for $trial, then $price / month';
  }

  @override
  String get familyPlusStartTrial => 'Start free trial';

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
  String get setupGenderMale => 'Male';

  @override
  String get setupGenderFemale => 'Female';

  @override
  String get setupGenderPrivate => 'Only you can see this.';

  @override
  String get setupGenderPreferNot => 'Prefer not to answer';

  @override
  String get setupGenderRequired =>
      'Choose an answer - \"Prefer not to answer\" is fine.';

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
  String get upgradeAllowanceBody =>
      'Your AI tokens are used. They renew on your plan\'s reset date, or with a bigger plan.';

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

  @override
  String get courseworkVersionConflict =>
      'Someone else changed this while you were working. Reload to see the latest, then try again.';

  @override
  String get courseworkNotAllowed =>
      'You don\'t have permission to do this for this class.';

  @override
  String get courseworkWindowClosed =>
      'The deadline for this work has passed. Ask your teacher for more time.';

  @override
  String get courseworkSubmissionLocked =>
      'Your teacher has already marked this work, so it can\'t be replaced. Ask your teacher if you need to hand it in again.';

  @override
  String get courseworkReasonRequired =>
      'Please give a reason. It is kept with the change.';

  @override
  String get courseworkAttendanceLocked =>
      'This register is locked by your school\'s attendance policy.';

  @override
  String get courseworkEntriesInvalid =>
      'Some rows need fixing. Nothing was saved.';

  @override
  String get courseworkFailed =>
      'That didn\'t work. Check your connection and try again.';

  @override
  String paperGradesTitle(String title) {
    return 'Grade sheet: $title';
  }

  @override
  String get paperGradesPaperLabel => 'Paper';

  @override
  String get paperGradesOnlineLabel => 'Online';

  @override
  String get paperGradesPaperSection => 'Paper work';

  @override
  String get paperGradesOnlineSection => 'Online work';

  @override
  String get paperGradesNew => 'New paper grade';

  @override
  String get paperGradesOpenSheet => 'Open the grade sheet';

  @override
  String get paperGradesSheetHint =>
      'This is paper work. Enter marks for the whole class on its grade sheet.';

  @override
  String paperGradesOutOf(String max) {
    return 'out of $max';
  }

  @override
  String paperGradesWeight(String weight) {
    return 'Counts $weight%';
  }

  @override
  String get paperGradesScore => 'Score';

  @override
  String get paperGradesAbsent => 'Missed the exam';

  @override
  String get paperGradesNotGraded => 'Not graded';

  @override
  String get paperGradesUnmarked => 'Not marked yet';

  @override
  String get paperGradesStateDraft => 'Draft';

  @override
  String get paperGradesStateReady => 'Ready';

  @override
  String get paperGradesStatePublished => 'Published';

  @override
  String get paperGradesStateChanged => 'Unsaved';

  @override
  String get paperGradesLeftClass => 'Left the class';

  @override
  String get paperGradesComment => 'Comment (optional)';

  @override
  String get paperGradesAddComment => 'Add comment';

  @override
  String get paperGradesSaveDraft => 'Save draft';

  @override
  String get paperGradesSaving => 'Saving…';

  @override
  String get paperGradesSaved =>
      'Draft saved. Students and parents can\'t see it yet.';

  @override
  String get paperGradesPublish => 'Publish';

  @override
  String get paperGradesSaveFirst => 'Save your changes before publishing.';

  @override
  String get paperGradesNothingToPublish =>
      'Nothing is ready to publish. Enter and save marks first.';

  @override
  String get paperGradesPublishTitle => 'Publish marks?';

  @override
  String paperGradesPublishBody(int ready, int unmarked) {
    return '$ready marks will be visible to students and their parents, who will be notified. $unmarked students without a mark stay unpublished.';
  }

  @override
  String paperGradesPublished(int count) {
    return '$count marks published.';
  }

  @override
  String get paperGradesCancel => 'Cancel';

  @override
  String paperGradesCounts(int ready, int published, int unmarked) {
    return '$ready ready · $published published · $unmarked not marked';
  }

  @override
  String get paperGradesEmpty => 'No students are enrolled in this class yet.';

  @override
  String get paperGradesLoadFailed => 'The grade sheet could not be loaded.';

  @override
  String get paperGradesRetry => 'Try again';

  @override
  String get paperGradesCorrect => 'Correct';

  @override
  String paperGradesCorrected(int count) {
    return 'Corrected $count×';
  }

  @override
  String get paperGradesRowNotEnrolled => 'Not in this class';

  @override
  String get paperGradesRowAlreadyPublished =>
      'Already published. Use Correct.';

  @override
  String get paperGradesRowScoreRequired => 'Enter a score';

  @override
  String paperGradesRowScoreOutOfRange(String max) {
    return 'Must be between 0 and $max';
  }

  @override
  String get paperGradesRowScoreNotAllowed =>
      'No score for absent or not graded';

  @override
  String get paperGradesRowConflict => 'Changed by someone else';

  @override
  String get paperGradesRowInvalid => 'Check this row';

  @override
  String get paperGradesEditItem => 'Edit details';

  @override
  String get paperItemTitle => 'Paper grade';

  @override
  String get paperItemName => 'Name';

  @override
  String get paperItemNameHint => 'e.g. Term 1 exam';

  @override
  String get paperItemCategory => 'Kind';

  @override
  String get paperItemCategoryExam => 'Paper exam';

  @override
  String get paperItemCategoryHomework => 'Homework';

  @override
  String get paperItemCategoryQuiz => 'Quiz';

  @override
  String get paperItemCategoryParticipation => 'Participation';

  @override
  String get paperItemCategoryOther => 'Other';

  @override
  String get paperItemCategoryCustom => 'Kind of work';

  @override
  String get paperItemMaximum => 'Out of';

  @override
  String get paperItemWeight => 'Weight % (optional)';

  @override
  String get paperItemDate => 'Date (optional)';

  @override
  String get paperItemPickDate => 'Pick a date';

  @override
  String get paperItemSave => 'Save';

  @override
  String get paperItemInvalid =>
      'Enter a name and a maximum above 0. A weight is between 0 and 100.';

  @override
  String gradeCorrectionTitle(String name) {
    return 'Correct $name\'s mark';
  }

  @override
  String get gradeCorrectionReason => 'Reason for the change';

  @override
  String get gradeCorrectionReasonHint => 'e.g. added up page 3 again';

  @override
  String get gradeCorrectionReasonTooShort =>
      'Give a reason of at least 3 characters.';

  @override
  String get gradeCorrectionSave => 'Save correction';

  @override
  String get gradeCorrectionNotifies =>
      'If the mark changes, the student and their parents are told. A comment-only change is recorded but not announced.';

  @override
  String get gradeCorrectionHistory => 'Changes';

  @override
  String get gradeCorrectionHistoryEmpty => 'No changes yet.';

  @override
  String get gradeCorrectionChangePublished => 'Published';

  @override
  String get gradeCorrectionChangeCorrected => 'Corrected';

  @override
  String gradeCorrectionBy(String name) {
    return 'by $name';
  }

  @override
  String get gradeCorrectionDone => 'Mark corrected.';

  @override
  String get attendanceRuleReasonRequired =>
      'This lesson is in the past. Changing a mark needs a reason, which is kept with it.';

  @override
  String get attendanceRuleLocked =>
      'This register is locked by your school\'s attendance policy.';

  @override
  String get attendanceRuleLockedOverride =>
      'This register is locked. As the class\'s lead teacher you can override the lock, with a reason.';

  @override
  String get attendanceOverride => 'Override the lock';

  @override
  String get attendanceCorrectionReason => 'Reason for the change';

  @override
  String get attendanceHistory => 'Changes';

  @override
  String get attendanceHistoryEmpty =>
      'No marks on this register have been changed.';

  @override
  String attendanceHistoryLine(String name, String from, String to) {
    return '$name: $from → $to';
  }

  @override
  String get attendanceHistoryOverride => 'Lock overridden';

  @override
  String deadlineDue(String when, String zone) {
    return 'Due $when ($zone)';
  }

  @override
  String deadlineExtended(String when) {
    return 'You have extra time until $when';
  }

  @override
  String get deadlineClosed => 'The deadline has passed.';

  @override
  String get deadlineGraded => 'Marked - it can no longer be replaced.';

  @override
  String get deadlineReplaceHint =>
      'You can replace your work until the deadline. Your earlier hand-ins are kept.';

  @override
  String get deadlineKeepFiles => 'Keep files from your last hand-in';

  @override
  String get deadlineExtend => 'Give more time';

  @override
  String get deadlineRemoveExtension => 'Remove extra time';

  @override
  String deadlineExtendedUntil(String when) {
    return 'Extra time until $when';
  }

  @override
  String get deadlineReopen => 'Reopen for the class';

  @override
  String get deadlineUntil => 'Until';

  @override
  String deadlineSchoolTime(String zone) {
    return 'School time ($zone)';
  }

  @override
  String get deadlineReason => 'Reason';

  @override
  String get deadlineSave => 'Save';

  @override
  String get deadlineSaved => 'Saved.';

  @override
  String get lessonEdit => 'Edit';

  @override
  String get lessonEditTitle => 'Edit lesson';

  @override
  String get lessonEditName => 'Title';

  @override
  String get lessonEditBody => 'Notes';

  @override
  String get lessonEditReplaceFile => 'Replace the file';

  @override
  String get lessonEditReplaceHint =>
      'The class sees only the new file. The old one is kept for the school.';

  @override
  String get lessonEditSave => 'Save';

  @override
  String get lessonEditSaved => 'Lesson updated.';

  @override
  String get downloadUnavailable =>
      'This file is no longer available. Pull down to refresh.';

  @override
  String get materialsEditTitle => 'Change the material';

  @override
  String get materialsEditHint =>
      'Files you take off are kept for the school but no longer shown to the class.';

  @override
  String get materialsEditNone => 'No files attached yet.';

  @override
  String get materialsEditRemoving => 'Will be taken off';

  @override
  String get materialsEditSaved => 'Material updated.';

  @override
  String get classesInviteCodeBody =>
      'Students join by typing this class code in Studafy. Read it out, write it on the board, or share it.';

  @override
  String get classesCopyCode => 'Copy code';

  @override
  String get classesInviteCodeCopied => 'Class code copied.';

  @override
  String get classesShareCode => 'Share code';

  @override
  String get teacherCreatePaperGrades => 'Paper grades';

  @override
  String get teacherCreatePaperGradesDetail =>
      'Marks for a paper exam, quiz or homework, for the whole class';

  @override
  String get profilePhotoChange => 'Change profile photo';

  @override
  String get profilePhotoOnDevice =>
      'Your photo is kept on this phone only. It is never uploaded, and it is removed when you sign out.';

  @override
  String get profilePhotoChoose => 'Choose a photo';

  @override
  String get profilePhotoTake => 'Take a photo';

  @override
  String get profilePhotoRemove => 'Remove photo';

  @override
  String get profilePhotoFailed =>
      'That photo could not be used. Try another one.';

  @override
  String todayStatClasses(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count classes',
      one: '1 class',
      zero: 'No classes',
    );
    return '$_temp0';
  }

  @override
  String get todayQuickActions => 'Quick actions';

  @override
  String get todaySeeAll => 'See all';

  @override
  String get wellbeingNewTitle => 'New wellbeing note';

  @override
  String get wellbeingIntro =>
      'Record how a student is doing - a strength to celebrate, a note, or a concern to follow up. You choose who else can read it.';

  @override
  String get wellbeingWhoAbout => 'Who is it about?';

  @override
  String get wellbeingClass => 'Class';

  @override
  String get wellbeingPickClass => 'Choose a class';

  @override
  String get wellbeingStudent => 'Student';

  @override
  String get wellbeingPickStudent => 'Choose a student';

  @override
  String get wellbeingNoStudents => 'No students have joined this class yet.';

  @override
  String get wellbeingStudentsFailed =>
      'The students could not load. Tap to try again.';

  @override
  String get wellbeingKind => 'Type of note';

  @override
  String get wellbeingKindStrength => 'Strength';

  @override
  String get wellbeingKindNote => 'Note';

  @override
  String get wellbeingKindConcern => 'Concern';

  @override
  String get wellbeingSeverity => 'How serious is it?';

  @override
  String get wellbeingSeverityLow => 'Low';

  @override
  String get wellbeingSeverityModerate => 'Moderate';

  @override
  String get wellbeingSeverityHigh => 'High';

  @override
  String get wellbeingDetails => 'Details';

  @override
  String get wellbeingTitle => 'Title';

  @override
  String get wellbeingTitleRequired => 'Give the note a short title.';

  @override
  String get wellbeingContext => 'What happened (optional)';

  @override
  String get wellbeingFollowUp => 'Follow-up (optional)';

  @override
  String get wellbeingWhoSees => 'Who can read it?';

  @override
  String get wellbeingSeeStaff => 'Only you';

  @override
  String get wellbeingSeeStaffDetail =>
      'Kept to you, as this class\'s teacher.';

  @override
  String get wellbeingSeeGuardians => 'You and the parents';

  @override
  String get wellbeingSeeGuardiansDetail =>
      'Also the student\'s linked parents.';

  @override
  String get wellbeingSeeStudent => 'You, the parents and the student';

  @override
  String get wellbeingSeeStudentDetail =>
      'Also the parents and the student themselves.';

  @override
  String get wellbeingSave => 'Save note';

  @override
  String get wellbeingSaving => 'Saving...';

  @override
  String get wellbeingSaved => 'Wellbeing note saved.';

  @override
  String get wellbeingSaveFailed =>
      'The note could not be saved. Please try again.';

  @override
  String get wellbeingAdd => 'New wellbeing note';

  @override
  String get gradebookHomeNoClasses =>
      'Create a class on the Classes tab, then its marks are kept here.';

  @override
  String get gradebookHomeNothing => 'Nothing to mark in this class yet';

  @override
  String get gradebookHomeNothingDetail =>
      'Add a paper grade for a test done on paper, or set graded work from the Teaching tab.';

  @override
  String gradebookHomeCounts(int total, int drafts) {
    String _temp0 = intl.Intl.pluralLogic(
      total,
      locale: localeName,
      other: '$total graded pieces',
      one: '1 graded piece',
      zero: 'No graded work',
    );
    return '$_temp0 · $drafts drafts';
  }

  @override
  String get gradebookMarkOnline => 'Mark online work';

  @override
  String get gradebookViewHandIns => 'View hand-ins';

  @override
  String get academicStateWithdrawn => 'Hidden';

  @override
  String get academicEmptyTeacherHint =>
      'Tap + to create something for your classes.';

  @override
  String get teacherCreateGroupTeaching => 'Teaching';

  @override
  String get teacherCreateGroupClass => 'Class records';

  @override
  String get teacherCreateGroupFamilies => 'Families';

  @override
  String get teacherCreateWellbeingDetail =>
      'A strength, note or concern about one student';

  @override
  String classesSummary(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count classes',
      one: '1 class',
      zero: 'No classes yet',
    );
    return '$_temp0';
  }

  @override
  String get classesEmptyDetail =>
      'Create your first class, then invite students with its class code.';

  @override
  String get attendanceMarkAllPresent => 'Mark all present';

  @override
  String get attendanceNotMarked => 'Not marked';

  @override
  String get attendanceUnsaved => 'Unsaved changes';

  @override
  String attendanceStatusFor(String name, String status) {
    return '$name: $status. Change attendance';
  }

  @override
  String attendanceCounts(int present, int absent, int late, int unmarked) {
    return '$present present · $absent absent · $late late · $unmarked not marked';
  }

  @override
  String get attachmentCamera => 'Camera';

  @override
  String get attachmentDocument => 'Document';

  @override
  String get attachmentAdd => 'Attach';

  @override
  String get msgOptions => 'Options';

  @override
  String get msgAnnouncements => 'Announcements';

  @override
  String get msgAnnouncementsEmpty => 'No announcements yet';

  @override
  String get msgAnnouncementsFailed => 'Announcements could not load';

  @override
  String get msgNewAnnouncement => 'New announcement';

  @override
  String get msgImportant => 'Important';

  @override
  String get msgUnread => 'Unread';

  @override
  String get msgBlockedIntro =>
      'People you block cannot message you, and you cannot message them. Unblock someone to talk again.';

  @override
  String get msgBlockedEmptyDetail =>
      'If someone makes you uncomfortable, you can block or report them from the conversation\'s options.';

  @override
  String get msgBlockedLabel => 'Blocked';

  @override
  String get accountSecurityDetailFull =>
      'Devices, two-step verification, sign out everywhere, delete account';

  @override
  String get securityDeleteHeading => 'Delete account';

  @override
  String get securityDeleteFooter =>
      'Deleting your account removes your personal data after 14 days, and you can cancel before then. Records your school must keep stay with the school.';

  @override
  String get securityDeleteTitle => 'Delete your account?';

  @override
  String get securityDeleteExplain =>
      'You will see exactly what is removed and what your school keeps, and you will be asked to confirm again. Deletion happens after 14 days and can be cancelled until then.';

  @override
  String get securityDeleteContinue => 'Continue';

  @override
  String get loginDidNotFinish =>
      'Sign-in did not finish - the connection may have dropped. Please try again.';

  @override
  String get filesSwitchedOff =>
      'Attachments and voice notes aren\'t switched on for your school yet.';

  @override
  String get attachmentRetry => 'Try again';

  @override
  String get attachmentRemove => 'Remove';

  @override
  String get msgVoiceSending => 'Sending voice note…';

  @override
  String get studentTodayLessonsShortcut => 'Lessons & notebooks';

  @override
  String get studentTodayLessonsShortcutDetail =>
      'Every class, with your own notes';

  @override
  String get studentTodayWorkShortcutDetail => 'Hand in and check deadlines';

  @override
  String get studentTodayFamilyShortcutDetail =>
      'Your Studafy ID and parent requests';

  @override
  String get studentTodayWorkSection => 'Work to do';

  @override
  String get studentLessonsSubtitle =>
      'Your classes, their lessons and your notebooks';

  @override
  String get studentClassLessonsDetail =>
      'Everything your teacher shared, by date';

  @override
  String get studentClassNotebook => 'Notebook';

  @override
  String get studentClassNotebookDetail =>
      'Your own notes for this class, each one dated';

  @override
  String get studentClassOpenNotebook => 'Open notebook';

  @override
  String planUpgradeTo(Object plan) {
    return 'Upgrade to $plan';
  }

  @override
  String planAdds(Object plan) {
    return '$plan adds:';
  }

  @override
  String get planEverything => 'You have every study feature.';

  @override
  String get planSeePlans => 'See plans';

  @override
  String get workSubtitle => 'Assignments, tests, grades and attendance';

  @override
  String get workSectionOpen => 'To do';

  @override
  String get workSectionClosed => 'Past the deadline';

  @override
  String get workSectionGraded => 'Marked';

  @override
  String get workStateOpen => 'Open';

  @override
  String get workStateClosed => 'Closed';

  @override
  String get workStateGraded => 'Marked';

  @override
  String get workView => 'View';

  @override
  String get submitInstructions => 'Instructions';

  @override
  String get submitHandInAgain => 'Hand in again';

  @override
  String get submitSaving => 'Your work is being handed in…';

  @override
  String get helperSubtitle => 'Ask about anything you\'re studying';

  @override
  String get helperRecentChats => 'Recent chats';

  @override
  String get helperSeeAll => 'See all';

  @override
  String get helperOffTitle => 'Not switched on yet';

  @override
  String get accountSectionProfile => 'Profile information';

  @override
  String get accountSectionNotifications => 'Notifications';

  @override
  String get accountSectionSubscription => 'Subscription';

  @override
  String get accountStudyPlan => 'Study plan';

  @override
  String get accountStudyPlanDetail =>
      'Your plan, what it includes, and upgrades';

  @override
  String get accountTechnicalId => 'Technical account ID';

  @override
  String get accountTechnicalIdDetail =>
      'Only needed if Studafy support asks for it. To link with a parent, share your Studafy ID instead.';

  @override
  String get accountChangePhoto => 'Change photo';

  @override
  String get loginWrongRoleStudentTitle => 'This email is a student account';

  @override
  String get loginWrongRoleStudentBody =>
      'A student account is only for learning, so it can\'t be used as a teacher or a parent. To teach or to follow a child, sign in with a different email.';

  @override
  String get loginWrongRoleAdultTitle => 'This email isn\'t a student account';

  @override
  String loginWrongRoleAdultBody(String role) {
    return 'It\'s already used as a $role, so it can\'t be a student too. A student needs an email of their own.';
  }

  @override
  String loginContinueAs(String role) {
    return 'Continue as $role';
  }

  @override
  String get loginUseDifferentEmail => 'Use a different email';

  @override
  String get accountSwitchRoleTeacherParent =>
      'Move between teaching and following your children.';

  @override
  String get accountName => 'Name';

  @override
  String get accountEditName => 'Edit name';

  @override
  String get accountEditNameTitle => 'Edit your name';

  @override
  String get accountNameHelp =>
      'This is how your teachers, classmates and family see you.';

  @override
  String get accountNameInvalid => 'Enter a name of up to 160 characters.';

  @override
  String get accountNameSaved => 'Name saved';

  @override
  String get accountNameFailed =>
      'Your name couldn\'t be saved. Please try again.';

  @override
  String get accountSaveAction => 'Save';

  @override
  String get accountCancelAction => 'Cancel';

  @override
  String get accountPublicIdDetail =>
      'Studafy support may ask for this number. It can\'t be used to see your account or to link to a child.';

  @override
  String get navAnnouncements => 'Announcements';

  @override
  String get announcementsSubtitle => 'News from your children\'s schools';

  @override
  String get announcementsAllChildren => 'All children';

  @override
  String get announcementsNoChildren =>
      'Link a child to see their school\'s announcements.';

  @override
  String announcementsFrom(String school, String children) {
    return '$school · $children';
  }

  @override
  String get learningSubtitle => 'Lessons, work, tests, grades and attendance';

  @override
  String get learningFilterByChild => 'Filter by child';

  @override
  String get learningNoChildrenTitle => 'No child linked yet';

  @override
  String get learningNoChildrenBody =>
      'Link a child from Today to follow their lessons, work and grades here.';

  @override
  String get parentTodaySubtitle => 'Your children\'s day at a glance';

  @override
  String get parentQuickLink => 'Link a child';

  @override
  String get parentQuickLearning => 'Learning';

  @override
  String get parentQuickAnnouncements => 'Announcements';

  @override
  String get parentQuickMessages => 'Message a teacher';

  @override
  String get parentChildrenSection => 'Your children';

  @override
  String get parentNoChildrenTitle => 'Link your first child';

  @override
  String get parentNoChildrenBody =>
      'Ask your child for their Studafy ID. They approve the request on their own device.';

  @override
  String get parentChildOpen => 'Open';

  @override
  String get parentLinkSearching => 'Checking…';

  @override
  String get familyPlusNoPlan => 'No Family+ plan yet';

  @override
  String familyPlusCoveredCount(int count) {
    return 'Covers $count of your children';
  }

  @override
  String familyPlusEnds(String date) {
    return 'Active until $date';
  }

  @override
  String get familyPlusWhatYouGet => 'What Family+ adds';

  @override
  String get familyPlusPlansTitle => 'Choose a plan';

  @override
  String get familyPlusManagePlan => 'Plan';

  @override
  String get famLinkCheckFailed =>
      'The security check didn\'t go through. Please try again.';

  @override
  String get famLinkAlready =>
      'You\'ve already asked to link this child, or they\'re linked already.';

  @override
  String get famLinkIdHelp =>
      'Your child finds it on their Profile, under Your Studafy ID.';

  @override
  String get familyPlusCurrentPlan => 'Current plan';

  @override
  String get paperGradesOtherMark => 'Other mark';

  @override
  String get paperGradesEnterScore => 'Enter a score instead';

  @override
  String get courseworkInvalidState =>
      'That can\'t be done for this right now.';

  @override
  String get attendanceNotOnTimetable =>
      'This lesson wasn\'t on the class\'s timetable on that date, so it has no register.';

  @override
  String get attendanceSaveFailed =>
      'The attendance couldn\'t be saved. Please try again.';

  @override
  String loginOtherRoleTitle(String role) {
    return 'This email is already a $role account';
  }

  @override
  String loginOtherRoleBody(String own, String chosen) {
    return 'Continue as a $own, or also use this account as a $chosen. You can switch between the two any time from your profile.';
  }

  @override
  String loginAlsoUseAs(String role) {
    return 'Also use it as a $role';
  }

  @override
  String get attachmentsTitle => 'Attachments';

  @override
  String get attachmentsLinks => 'Links';

  @override
  String get attachmentsFiles => 'Files';

  @override
  String get attachmentsAddLink => 'Add link';

  @override
  String get attachmentsLinkTitle => 'Title readers see';

  @override
  String get attachmentsLinkAddress => 'Address (https://…)';

  @override
  String get attachmentsLinkTitleRequired => 'Give the link a title.';

  @override
  String get attachmentsRemove => 'Remove';

  @override
  String get attachmentsKeep => 'Keep';

  @override
  String get attachmentsRemovedOnSave => 'Removed when you save';

  @override
  String get attachmentsUploading => 'Wait for the files to finish uploading.';

  @override
  String get attachmentsFailed =>
      'Retry or remove the files that failed to upload.';

  @override
  String attachmentsTooManyLinks(int count) {
    return 'You can add up to $count links.';
  }

  @override
  String get attachmentsImagePreview => 'Tap to view';

  @override
  String get attachmentsChecking => 'Being checked';

  @override
  String get attachmentsNotAvailable => 'Not available';

  @override
  String get questionKindSingle => 'Single answer';

  @override
  String get questionKindMultiple => 'Multiple answers';

  @override
  String get questionKindTrueFalse => 'True or false';

  @override
  String get questionKindShort => 'Short answer';

  @override
  String get questionKindEssay => 'Essay';

  @override
  String get builderNewTitle => 'New online assessment';

  @override
  String get builderEditTitle => 'Edit assessment';

  @override
  String get builderTitleLabel => 'Title';

  @override
  String get builderClassLabel => 'Class';

  @override
  String get builderCategoryLabel => 'Type';

  @override
  String get builderCategoryQuiz => 'Quiz';

  @override
  String get builderCategoryExam => 'Exam';

  @override
  String get builderCategoryAssessment => 'Assessment';

  @override
  String get builderQuestions => 'Questions';

  @override
  String get builderAddQuestion => 'Add question';

  @override
  String builderTotal(String points) {
    return 'Total points: $points';
  }

  @override
  String builderQuestionNumber(int number) {
    return 'Question $number';
  }

  @override
  String get builderPrompt => 'Question';

  @override
  String get builderPoints => 'Points';

  @override
  String get builderRequired => 'Required';

  @override
  String builderOption(int number) {
    return 'Option $number';
  }

  @override
  String get builderAddOption => 'Add option';

  @override
  String get builderRemoveOption => 'Remove option';

  @override
  String get builderMarkCorrectOne => 'Tick the correct answer.';

  @override
  String get builderMarkCorrectAll => 'Tick every correct answer.';

  @override
  String get builderTrue => 'True';

  @override
  String get builderFalse => 'False';

  @override
  String get builderCorrectIs => 'The correct answer is';

  @override
  String get builderAccepted => 'Accepted answers, one per line';

  @override
  String get builderAcceptedHint => 'Leave empty to mark it yourself.';

  @override
  String get builderModelAnswer => 'Model answer';

  @override
  String get builderGuidance => 'Marking guidance';

  @override
  String get builderPrivateHint =>
      'Only you see this until answers are released.';

  @override
  String get builderMoveUp => 'Move up';

  @override
  String get builderMoveDown => 'Move down';

  @override
  String get builderDuplicate => 'Duplicate';

  @override
  String get builderDelete => 'Delete';

  @override
  String get builderSettings => 'Settings';

  @override
  String get builderOpens => 'Opens';

  @override
  String get builderCloses => 'Closes';

  @override
  String get builderNotSet => 'Not set';

  @override
  String get builderNow => 'Now';

  @override
  String get builderAttempts => 'Attempts allowed';

  @override
  String get builderPolicy => 'Which attempt counts';

  @override
  String get builderPolicyBest => 'The best';

  @override
  String get builderPolicyLatest => 'The latest';

  @override
  String get builderRelease => 'When students see the answers';

  @override
  String get builderReleaseAfterClose => 'After it closes for everyone';

  @override
  String get builderReleaseAfterGrading =>
      'After marking is done and grades are published';

  @override
  String get builderReleaseManual => 'When I release them';

  @override
  String get builderReleaseNote =>
      'Answers are never shown while any student can still attempt it.';

  @override
  String get builderMaterial => 'Material for the whole assessment';

  @override
  String get builderPreview => 'Preview as a student';

  @override
  String get builderSaveDraft => 'Save draft';

  @override
  String get builderPublish => 'Publish';

  @override
  String get builderSaved => 'Saved.';

  @override
  String get builderPublished => 'Published to the class.';

  @override
  String get builderSaveFailed =>
      'Could not save. Check the questions and try again.';

  @override
  String get builderLocked =>
      'A student has already submitted, so the questions can no longer change. Settings still can.';

  @override
  String get builderNeedTitle => 'Give it a title.';

  @override
  String get builderNeedClass => 'Choose a class.';

  @override
  String get builderNeedQuestion => 'Add at least one question.';

  @override
  String get builderNeedClose => 'Set when it closes.';

  @override
  String get builderCloseAfterOpen => 'It must close after it opens.';

  @override
  String builderProblemPrompt(int number) {
    return 'Question $number: write the question.';
  }

  @override
  String builderProblemPoints(int number) {
    return 'Question $number: give it points.';
  }

  @override
  String builderProblemOptions(int number) {
    return 'Question $number: add at least two filled-in options.';
  }

  @override
  String builderProblemCorrect(int number) {
    return 'Question $number: mark the correct answer.';
  }

  @override
  String builderProblemTrueFalse(int number) {
    return 'Question $number: choose true or false as the answer.';
  }

  @override
  String builderProblemFiles(int number) {
    return 'Question $number: wait for its files to upload.';
  }

  @override
  String get builderOnlineChoice => 'Answered online';

  @override
  String get builderOnlineChoiceDetail =>
      'Students answer in the app; choice questions are marked for you.';

  @override
  String get builderPaperChoice => 'On paper';

  @override
  String get builderPaperChoiceDetail =>
      'Students sit it in class; you enter the marks.';

  @override
  String takeOpens(String time) {
    return 'Opens $time';
  }

  @override
  String takeCloses(String time) {
    return 'Closes $time';
  }

  @override
  String get takeClosed => 'Closed';

  @override
  String get takeNotOpen => 'Not open yet';

  @override
  String takeAttemptsLeft(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count attempts left',
      one: '1 attempt left',
      zero: 'No attempts left',
    );
    return '$_temp0';
  }

  @override
  String get takeStart => 'Start';

  @override
  String get takeAgain => 'Try again';

  @override
  String get takeSubmit => 'Submit answers';

  @override
  String get takeSubmitTitle => 'Submit your answers?';

  @override
  String get takeSubmitBody => 'You can\'t change them after submitting.';

  @override
  String get takeLeaveTitle => 'Leave without submitting?';

  @override
  String get takeLeaveBody => 'Your answers will not be kept.';

  @override
  String get takeLeave => 'Leave';

  @override
  String get takeStay => 'Stay';

  @override
  String takeMissing(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Answer the $count required questions that are left.',
      one: 'Answer the required question that is left.',
    );
    return '$_temp0';
  }

  @override
  String get takeSubmitted =>
      'Submitted. Your teacher will release the results.';

  @override
  String get takeSubmitFailed =>
      'Your answers were not sent. Check your connection and try again.';

  @override
  String get takeWindowClosed => 'This has closed, so it can\'t be submitted.';

  @override
  String get takeRequired => 'Required';

  @override
  String get takeOptional => 'Optional';

  @override
  String get takeTypeAnswer => 'Your answer';

  @override
  String get takeChooseOne => 'Choose one';

  @override
  String get takeChooseAll => 'Choose all that apply';

  @override
  String takePoints(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count points',
      one: '1 point',
    );
    return '$_temp0';
  }

  @override
  String get takeYourAttempts => 'Your attempts';

  @override
  String takeAttemptLine(int number, String time) {
    return 'Attempt $number · $time';
  }

  @override
  String get takeNotReleased =>
      'Answers will appear here once your teacher releases them.';

  @override
  String get takeGrade => 'Grade';

  @override
  String get takeGradePending => 'Not published yet';

  @override
  String get takeFeedback => 'Teacher\'s feedback';

  @override
  String get takeAnswers => 'Answers';

  @override
  String get takeYourAnswer => 'Your answer';

  @override
  String get takeCorrectAnswer => 'Correct answer';

  @override
  String get takeAcceptedAnswers => 'Accepted answers';

  @override
  String get takeNoAnswer => 'No answer';

  @override
  String get takeBeingMarked => 'Being marked';

  @override
  String takeScore(String score, String max) {
    return '$score of $max';
  }

  @override
  String get takeLoadFailed => 'This could not load.';

  @override
  String get takeRetry => 'Try again';

  @override
  String get takeReadOnly =>
      'You can see your child\'s results here. Only they can sit it.';

  @override
  String get takeOpenAssessment => 'Open';

  @override
  String get markSubmissions => 'Submissions';

  @override
  String get markNone => 'No one has submitted yet.';

  @override
  String get markNeeds => 'Needs marking';

  @override
  String markDone(String score, String max) {
    return 'Marked: $score of $max';
  }

  @override
  String get markAuto => 'Marked automatically';

  @override
  String markScoreLabel(String max) {
    return 'Score (out of $max)';
  }

  @override
  String get markAnswerFeedback => 'Comment on this answer';

  @override
  String get markOverallFeedback => 'Feedback for the student';

  @override
  String get markSave => 'Save marks';

  @override
  String get markSaved => 'Marks saved.';

  @override
  String get markSaveFailed =>
      'Marks were not saved. Check each score and try again.';

  @override
  String markScoreInvalid(String max) {
    return 'Enter a score from 0 to $max.';
  }

  @override
  String get markPublishGrades => 'Publish grades';

  @override
  String markPublished(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count grades published.',
      one: '1 grade published.',
    );
    return '$_temp0';
  }

  @override
  String get markNothingToPublish => 'Nothing is ready to publish yet.';

  @override
  String get markReleaseNow => 'Release answers now';

  @override
  String get markReleased => 'Answers released.';

  @override
  String get markReleaseRefused =>
      'Answers can only be released once it has closed for everyone.';

  @override
  String get markEditQuestions => 'Edit questions and settings';

  @override
  String get markGrantAccess => 'More time or attempts';

  @override
  String get markGrantStudent => 'Student';

  @override
  String get markGrantUntil => 'Open for them until';

  @override
  String get markGrantExtra => 'Extra attempts';

  @override
  String get markGrantGive => 'Give';

  @override
  String get markGranted => 'Done.';

  @override
  String get markGrantFailed => 'That could not be given.';

  @override
  String markAnswersCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count submissions',
      one: '1 submission',
    );
    return '$_temp0';
  }

  @override
  String get markOpenSubmissions => 'Submissions and marking';

  @override
  String get paperShared => 'For the whole class';

  @override
  String get paperSharedHint =>
      'The question paper, a mark scheme or general feedback. Each student sees these once their own mark is published.';

  @override
  String paperForStudent(String name) {
    return 'For $name';
  }

  @override
  String get paperForStudentHint =>
      'Only this student and their parents see these, once the mark is published.';

  @override
  String get paperAttachments => 'Attachments';

  @override
  String get paperAttachmentsSaved => 'Attachments saved.';

  @override
  String get paperAttachmentsFailed => 'Attachments were not saved.';

  @override
  String get paperAttachmentsSaveFirst =>
      'Save the marks first, then change attachments.';

  @override
  String get paperSave => 'Save';

  @override
  String get gradeYourFiles => 'Your files';

  @override
  String get gradeClassFiles => 'For the class';

  @override
  String helperTokensLeft(String remaining, String total, String date) {
    return '$remaining of $total AI tokens left · renews $date';
  }

  @override
  String get helperTokensUsed =>
      'You\'ve used your AI tokens. Your question is still here.';

  @override
  String helperTokensUsedUntil(String date) {
    return 'You\'ve used your AI tokens. They renew on $date - your question is still here.';
  }

  @override
  String helperTokensLow(String line) {
    return 'Running low: $line.';
  }

  @override
  String get helperStillAnswering => 'This question is still being answered.';

  @override
  String helperCouldNotRead(String name, String reason) {
    return 'Couldn\'t read $name: $reason.';
  }

  @override
  String get helperSources => 'Sources';

  @override
  String helperCitationPage(int n) {
    return 'p. $n';
  }

  @override
  String helperCitationSlide(int n) {
    return 'slide $n';
  }

  @override
  String helperCitationLesson(String name) {
    return '$name (lesson)';
  }

  @override
  String helperCitationNote(String name) {
    return '$name (your note)';
  }

  @override
  String get helperAskAboutLesson => 'Ask the AI helper';

  @override
  String get pickerOneFile => 'Or one file or link';

  @override
  String get tokensWhatAreThey => 'What are AI tokens?';

  @override
  String get tokensExplained =>
      'The AI reads and writes in small pieces of text called tokens - about three-quarters of a word each. Your question, the parts of your lessons it reads, the earlier messages in the chat and its answer all use tokens. The helper, notes, quizzes and flashcards share one allowance.';

  @override
  String get tokensGuideTitle => 'Roughly what things use';

  @override
  String get tokensGuideShortQuestion => 'A short question';

  @override
  String get tokensGuideLessonQuestion => 'A question about a lesson\'s files';

  @override
  String get tokensGuideNotes => 'Notes, a quiz or flashcards from a lesson';

  @override
  String get tokensGuidePhoto => 'A whiteboard or homework photo';

  @override
  String tokensAbout(String amount) {
    return 'about $amount';
  }

  @override
  String get tokensGuideEstimate =>
      'These are estimates. The exact count comes from the AI for each request: longer files, answers and chats use more.';

  @override
  String get readingTitle => 'Reading for the AI helper';

  @override
  String get readingExplained =>
      'Files and links are read once so the AI helper can answer from them. Scanned pages and pictures are read too, within the school\'s monthly reading limit.';

  @override
  String get readingReady => 'Ready for the AI helper';

  @override
  String get readingPartly => 'Partly read - some pages were not read';

  @override
  String get readingStateProcessing => 'Reading…';

  @override
  String readingStateCannot(String reason) {
    return 'Can\'t be read: $reason';
  }

  @override
  String get readingRetry => 'Read again';

  @override
  String get readingRetried => 'It will be read again shortly.';

  @override
  String get readingRetryFailed => 'That could not be done. Try again.';

  @override
  String get readingLoadFailed => 'Could not check the files.';

  @override
  String get readingNothing => 'This lesson has no files or links.';

  @override
  String get readingProcessing => 'it is still being read';

  @override
  String get readingScannedSkipped => 'its scanned pages weren\'t read';

  @override
  String get readingNoText => 'it has no readable text';

  @override
  String get readingUnsupportedType => 'this kind of file can\'t be read';

  @override
  String get readingLinkSignIn => 'the link needs a sign-in';

  @override
  String get readingLinkVideo => 'it\'s a video';

  @override
  String get readingLinkGone => 'the link no longer works';

  @override
  String get readingLinkUnreachable => 'the link couldn\'t be opened';

  @override
  String get readingFailed => 'it couldn\'t be read';

  @override
  String studyPlansTokensLeft(String remaining, String total) {
    return '$remaining of $total AI tokens left';
  }

  @override
  String studyPlansTokensRenewWeekly(String date) {
    return 'Renews every Monday · next on $date';
  }

  @override
  String get studyPlansTokensLow => 'Running low on AI tokens.';

  @override
  String get studyPlansFeatureAskLessons =>
      'Ask the AI helper about your lessons and their files';

  @override
  String get studyPlansFeatureFreeTokens =>
      '40,000 AI tokens a week - about 10 questions on your lessons (an estimate)';

  @override
  String get studyPlansFeaturePlusTokens =>
      '3,000,000 AI tokens a month - about 700 questions on your lessons (an estimate)';

  @override
  String get studyPlansFeatureMaxTokens =>
      '6,000,000 AI tokens a month - about 1,400 questions on your lessons (an estimate)';

  @override
  String get upgradeTokensTitle => 'You\'ve used your AI tokens';

  @override
  String upgradeTokensBody(String date) {
    return 'They renew on $date. A bigger plan has more tokens.';
  }

  @override
  String get studySetMaterialProcessing =>
      'The lesson\'s files are still being read. Try again in a minute so nothing is left out.';
}
