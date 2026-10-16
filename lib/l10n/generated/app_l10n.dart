// ignore_for_file: text_direction_code_point_in_literal, text_direction_code_point_in_comment
import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_l10n_ar.dart';
import 'app_l10n_en.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of AppL10n
/// returned by `AppL10n.of(context)`.
///
/// Applications need to include `AppL10n.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'generated/app_l10n.dart';
///
/// return MaterialApp(
///   localizationsDelegates: AppL10n.localizationsDelegates,
///   supportedLocales: AppL10n.supportedLocales,
///   home: MyApplicationHome(),
/// );
/// ```
///
/// ## Update pubspec.yaml
///
/// Please make sure to update your pubspec.yaml to include the following
/// packages:
///
/// ```yaml
/// dependencies:
///   # Internationalization support.
///   flutter_localizations:
///     sdk: flutter
///   intl: any # Use the pinned version from flutter_localizations
///
///   # Rest of dependencies
/// ```
///
/// ## iOS Applications
///
/// iOS applications define key application metadata, including supported
/// locales, in an Info.plist file that is built into the application bundle.
/// To configure the locales supported by your app, you’ll need to edit this
/// file.
///
/// First, open your project’s ios/Runner.xcworkspace Xcode workspace file.
/// Then, in the Project Navigator, open the Info.plist file under the Runner
/// project’s Runner folder.
///
/// Next, select the Information Property List item, select Add Item from the
/// Editor menu, then select Localizations from the pop-up menu.
///
/// Select and expand the newly-created Localizations item then, for each
/// locale your application supports, add a new item and select the locale
/// you wish to add from the pop-up menu in the Value field. This list should
/// be consistent with the languages listed in the AppL10n.supportedLocales
/// property.
abstract class AppL10n {
  AppL10n(String locale)
    : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static AppL10n of(BuildContext context) {
    return Localizations.of<AppL10n>(context, AppL10n)!;
  }

  static const LocalizationsDelegate<AppL10n> delegate = _AppL10nDelegate();

  /// A list of this localizations delegate along with the default localizations
  /// delegates.
  ///
  /// Returns a list of localizations delegates containing this delegate along with
  /// GlobalMaterialLocalizations.delegate, GlobalCupertinoLocalizations.delegate,
  /// and GlobalWidgetsLocalizations.delegate.
  ///
  /// Additional delegates can be added by appending to this list in
  /// MaterialApp. This list does not have to be used at all if a custom list
  /// of delegates is preferred or required.
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates =
      <LocalizationsDelegate<dynamic>>[
        delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
      ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[
    Locale('ar'),
    Locale('en'),
  ];

  /// Heading of the bottom sheet that switches the interface language.
  ///
  /// In en, this message translates to:
  /// **'App language'**
  String get languagePickerTitle;

  /// Explains that choosing Arabic also flips the layout to right-to-left.
  ///
  /// In en, this message translates to:
  /// **'The interface direction changes automatically.'**
  String get languagePickerSubtitle;

  /// Option that follows the phone's own language instead of an explicit choice.
  ///
  /// In en, this message translates to:
  /// **'System default'**
  String get languageSystemDefault;

  /// Subtitle for the system-default language option.
  ///
  /// In en, this message translates to:
  /// **'Follow this phone\'s language'**
  String get languageSystemDefaultDetail;

  /// The English language option. Always written in English, in both locales, so a speaker can find their own language.
  ///
  /// In en, this message translates to:
  /// **'English'**
  String get languageEnglish;

  /// The Arabic language option. Always written in Arabic, in both locales, so a speaker can find their own language.
  ///
  /// In en, this message translates to:
  /// **'العربية'**
  String get languageArabic;

  /// No description provided for @securityTitle.
  ///
  /// In en, this message translates to:
  /// **'Account security'**
  String get securityTitle;

  /// No description provided for @securityLoadFailed.
  ///
  /// In en, this message translates to:
  /// **'Could not load your security settings. Try again.'**
  String get securityLoadFailed;

  /// No description provided for @securityTryAgain.
  ///
  /// In en, this message translates to:
  /// **'Try again'**
  String get securityTryAgain;

  /// No description provided for @securityCodeMismatch.
  ///
  /// In en, this message translates to:
  /// **'That code did not match.'**
  String get securityCodeMismatch;

  /// No description provided for @securitySetupFailed.
  ///
  /// In en, this message translates to:
  /// **'Could not set up two-factor sign-in.'**
  String get securitySetupFailed;

  /// No description provided for @securitySignOutDeviceTitle.
  ///
  /// In en, this message translates to:
  /// **'Sign out this device?'**
  String get securitySignOutDeviceTitle;

  /// No description provided for @securitySignOutDeviceBody.
  ///
  /// In en, this message translates to:
  /// **'{device} will need to sign in again.'**
  String securitySignOutDeviceBody(String device);

  /// No description provided for @securityKeepIt.
  ///
  /// In en, this message translates to:
  /// **'Keep it'**
  String get securityKeepIt;

  /// No description provided for @securitySignItOut.
  ///
  /// In en, this message translates to:
  /// **'Sign it out'**
  String get securitySignItOut;

  /// No description provided for @securityRevokeFailed.
  ///
  /// In en, this message translates to:
  /// **'Could not sign that device out.'**
  String get securityRevokeFailed;

  /// No description provided for @securitySignOutEverywhereTitle.
  ///
  /// In en, this message translates to:
  /// **'Sign out everywhere?'**
  String get securitySignOutEverywhereTitle;

  /// No description provided for @securitySignOutEverywhereBody.
  ///
  /// In en, this message translates to:
  /// **'Every device signed in to this account will be signed out, including this one. Sessions stop working immediately.'**
  String get securitySignOutEverywhereBody;

  /// No description provided for @securityCancel.
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get securityCancel;

  /// No description provided for @securitySignOutEverywhere.
  ///
  /// In en, this message translates to:
  /// **'Sign out everywhere'**
  String get securitySignOutEverywhere;

  /// No description provided for @securitySignOutEverywhereFailed.
  ///
  /// In en, this message translates to:
  /// **'This device is signed out, but your other devices could not be reached. Try again from a signed-in device.'**
  String get securitySignOutEverywhereFailed;

  /// No description provided for @securityTwoFactorHeading.
  ///
  /// In en, this message translates to:
  /// **'TWO-FACTOR SIGN-IN'**
  String get securityTwoFactorHeading;

  /// No description provided for @securityTwoFactorOn.
  ///
  /// In en, this message translates to:
  /// **'Turned on'**
  String get securityTwoFactorOn;

  /// No description provided for @securityTwoFactorOff.
  ///
  /// In en, this message translates to:
  /// **'Not set up'**
  String get securityTwoFactorOff;

  /// No description provided for @securityTwoFactorOnDetail.
  ///
  /// In en, this message translates to:
  /// **'You use an authenticator app when signing in.'**
  String get securityTwoFactorOnDetail;

  /// No description provided for @securityTwoFactorOffDetail.
  ///
  /// In en, this message translates to:
  /// **'School administrators must turn this on before they can manage a school.'**
  String get securityTwoFactorOffDetail;

  /// No description provided for @securitySetUp.
  ///
  /// In en, this message translates to:
  /// **'Set up'**
  String get securitySetUp;

  /// No description provided for @securityDevicesHeading.
  ///
  /// In en, this message translates to:
  /// **'WHERE YOU ARE SIGNED IN'**
  String get securityDevicesHeading;

  /// No description provided for @securityNoOtherDevices.
  ///
  /// In en, this message translates to:
  /// **'No other devices'**
  String get securityNoOtherDevices;

  /// No description provided for @securityOnlyThisDevice.
  ///
  /// In en, this message translates to:
  /// **'Only this device is signed in.'**
  String get securityOnlyThisDevice;

  /// No description provided for @securityThisDevice.
  ///
  /// In en, this message translates to:
  /// **'this device'**
  String get securityThisDevice;

  /// No description provided for @securityDeviceSignedOut.
  ///
  /// In en, this message translates to:
  /// **'Signed out'**
  String get securityDeviceSignedOut;

  /// No description provided for @securityLastUsed.
  ///
  /// In en, this message translates to:
  /// **'Last used {when}'**
  String securityLastUsed(String when);

  /// No description provided for @securitySignOut.
  ///
  /// In en, this message translates to:
  /// **'Sign out'**
  String get securitySignOut;

  /// No description provided for @securityTotpTitle.
  ///
  /// In en, this message translates to:
  /// **'Set up two-factor sign-in'**
  String get securityTotpTitle;

  /// No description provided for @securityTotpBody.
  ///
  /// In en, this message translates to:
  /// **'Add this key to your authenticator app, then enter the six-digit code it shows.'**
  String get securityTotpBody;

  /// No description provided for @securityVerify.
  ///
  /// In en, this message translates to:
  /// **'Verify'**
  String get securityVerify;

  /// No description provided for @securityJustNow.
  ///
  /// In en, this message translates to:
  /// **'just now'**
  String get securityJustNow;

  /// No description provided for @securityMinutesAgo.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 minute ago} other{{count} minutes ago}}'**
  String securityMinutesAgo(int count);

  /// No description provided for @securityHoursAgo.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 hour ago} other{{count} hours ago}}'**
  String securityHoursAgo(int count);

  /// No description provided for @securityDaysAgo.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 day ago} other{{count} days ago}}'**
  String securityDaysAgo(int count);

  /// No description provided for @roleQuestion.
  ///
  /// In en, this message translates to:
  /// **'How will you use Studafy?'**
  String get roleQuestion;

  /// No description provided for @roleChoosePrompt.
  ///
  /// In en, this message translates to:
  /// **'Choose your role to personalize your experience.'**
  String get roleChoosePrompt;

  /// No description provided for @roleContinue.
  ///
  /// In en, this message translates to:
  /// **'Continue'**
  String get roleContinue;

  /// No description provided for @roleTeacher.
  ///
  /// In en, this message translates to:
  /// **'Teacher'**
  String get roleTeacher;

  /// No description provided for @roleTeacherDetail.
  ///
  /// In en, this message translates to:
  /// **'Manage classes, attendance and learning'**
  String get roleTeacherDetail;

  /// No description provided for @roleStudent.
  ///
  /// In en, this message translates to:
  /// **'Student'**
  String get roleStudent;

  /// No description provided for @roleStudentDetail.
  ///
  /// In en, this message translates to:
  /// **'Learn, submit work and stay updated'**
  String get roleStudentDetail;

  /// No description provided for @roleParent.
  ///
  /// In en, this message translates to:
  /// **'Parent'**
  String get roleParent;

  /// No description provided for @roleParentDetail.
  ///
  /// In en, this message translates to:
  /// **'Follow progress and school updates'**
  String get roleParentDetail;

  /// No description provided for @introSkip.
  ///
  /// In en, this message translates to:
  /// **'Skip'**
  String get introSkip;

  /// No description provided for @introNext.
  ///
  /// In en, this message translates to:
  /// **'Next'**
  String get introNext;

  /// No description provided for @introStart.
  ///
  /// In en, this message translates to:
  /// **'Get started'**
  String get introStart;

  /// No description provided for @introPageOf.
  ///
  /// In en, this message translates to:
  /// **'Page {index} of {total}'**
  String introPageOf(int index, int total);

  /// No description provided for @introTitleOne.
  ///
  /// In en, this message translates to:
  /// **'Your whole school day in one place'**
  String get introTitleOne;

  /// No description provided for @introBodyOne.
  ///
  /// In en, this message translates to:
  /// **'Lessons, homework, marks and attendance - teachers, students and parents, together.'**
  String get introBodyOne;

  /// No description provided for @introTitleTwo.
  ///
  /// In en, this message translates to:
  /// **'Every mark counts, on paper or online'**
  String get introTitleTwo;

  /// No description provided for @introBodyTwo.
  ///
  /// In en, this message translates to:
  /// **'Teachers mark paper exams and online work in one gradebook. Families see a mark once it is published.'**
  String get introBodyTwo;

  /// No description provided for @introTitleThree.
  ///
  /// In en, this message translates to:
  /// **'Parents see what matters'**
  String get introTitleThree;

  /// No description provided for @introBodyThree.
  ///
  /// In en, this message translates to:
  /// **'Follow progress and attendance - and with Family+, each class\'s trend and what to focus on this week. No ads, and your data is never sold.'**
  String get introBodyThree;

  /// No description provided for @roleWhatIsStudafy.
  ///
  /// In en, this message translates to:
  /// **'What is Studafy?'**
  String get roleWhatIsStudafy;

  /// No description provided for @loginWelcome.
  ///
  /// In en, this message translates to:
  /// **'Welcome, {role}'**
  String loginWelcome(String role);

  /// No description provided for @loginSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Use your school or personal account to continue.'**
  String get loginSubtitle;

  /// No description provided for @loginContinueWith.
  ///
  /// In en, this message translates to:
  /// **'Continue with {provider}'**
  String loginContinueWith(String provider);

  /// The consent sentence is assembled from fragments in this order: prefix, Terms link, connector, Privacy link, suffix. Keep that order workable in the target language.
  ///
  /// In en, this message translates to:
  /// **'I agree to the '**
  String get loginConsentPrefix;

  /// No description provided for @loginConsentAnd.
  ///
  /// In en, this message translates to:
  /// **' and '**
  String get loginConsentAnd;

  /// No description provided for @loginConsentSuffix.
  ///
  /// In en, this message translates to:
  /// **'.'**
  String get loginConsentSuffix;

  /// No description provided for @loginTermsOfUse.
  ///
  /// In en, this message translates to:
  /// **'Terms of Use'**
  String get loginTermsOfUse;

  /// No description provided for @loginPrivacyPolicy.
  ///
  /// In en, this message translates to:
  /// **'Privacy Policy'**
  String get loginPrivacyPolicy;

  /// No description provided for @loginAcceptFirst.
  ///
  /// In en, this message translates to:
  /// **'Please accept before signing in.'**
  String get loginAcceptFirst;

  /// No description provided for @loginChangeRole.
  ///
  /// In en, this message translates to:
  /// **'Change role'**
  String get loginChangeRole;

  /// No description provided for @loginClose.
  ///
  /// In en, this message translates to:
  /// **'Close'**
  String get loginClose;

  /// In-app summary of docs/legal/privacy-policy.md (version 1.4, consent version 2026-10-14), which governs. Update both together, publish a new consent version and bump termsPolicyVersion. Not reviewed by counsel; the Arabic translation has not been reviewed by a native legal translator.
  ///
  /// In en, this message translates to:
  /// **'WHAT WE COLLECT\nYour name and email from the sign-in provider you choose, and your gender only if you choose to give it (it is shown to nobody else). The school or class you belong to and your role in it. Lessons, the work you are set and hand in, each earlier hand-in, your marks and the history of any change to them, your attendance, pastoral notes, and your own notebook. Messages, voice notes, announcements and meeting links inside the app. Files you upload. Your subscriptions and notification settings.\n\nWHY\nTo run your classes, to keep your account secure, to bill subscriptions, and to meet legal duties. We do not sell personal data. We show no advertising. We do not use your data to train any AI model.\n\nMARKS AND ATTENDANCE\nTeachers can mark work done on paper as well as work handed in online. A mark is a draft that only your teachers can see until the teacher publishes it; a missing mark is never counted as zero. If a published mark is corrected, we keep the old mark, the new one, who changed it, when and why, and you and your parents are told if the mark changed. Attendance changes after the lesson\'s day need a reason, only the class\'s lead teacher can change a register more than seven days old, and every change is kept. Deadlines are set in your school\'s time zone.\n\nWHO SEES YOUR WORK\nYour class\'s teachers, and a parent linked to you once a mark is published. There is no school administrator in this version of the app. Other students cannot see your marks, your work or your private messages. Messages are stored on our servers and are not end-to-end encrypted.\n\nPARENTS AND CHILDREN\nA parent asks to be linked to a student, and the student approves or declines it on their own device. A parent may also create and manage an account for a child with no email or phone, and accepts these terms for the child. A linked parent sees published marks, attendance, work and class material, and can hand work in for a young child, but cannot change marks or attendance and is not given the child\'s private messages. Family+ is a paid plan for parents that covers up to 4 or up to 8 linked children, earliest linked first. For each child it covers it summarises what the parent can already see - marks by class, trends, attendance, missing work and missed tests - compares the child only with their own earlier record, and uses no AI.\n\nAI STUDY TOOLS\nThese tools are optional. When you use them, what you give them is sent to Together AI, an AI company outside Studafy: the question you type and the recent turns of the same chat, and - if you choose - a lesson\'s text, your own notes, or a photo you add (the study helper, whiteboard notes, lesson notes, quizzes and flashcards). Your name, email, school and marks are never sent. Chats are kept only on your device. Answers can be wrong, so never hand them in as your own work. AI never marks your work.\n\nFILES\nFiles are stored privately, scanned before anyone can download them, and opened only through links that work once and expire within minutes. Hidden details are removed from photos and voice notes. If a teacher replaces or removes a file, the class no longer sees it, but it is kept for the school.\n\nPAYMENTS\nStudafy Plus, Studafy Max and Family+ are charged by Apple or Google under their own terms. We never see your card.\n\nWHO ELSE PROCESSES DATA\nSupabase hosts the database, sign-in and files; Fly.io hosts the app; Axiom keeps its technical logs and Sentry its error reports; GitHub stores encrypted backups it cannot read; Redis holds short-lived counters; Google, Microsoft and Apple verify sign-in; Cloudflare runs a bot check; Together AI runs the AI study tools; Resend sends email and Firebase sends push notifications, which never contain your marks or messages; meetings happen in Google Meet. Each acts only on our instructions.\n\nWHERE YOUR DATA IS\nData may be processed outside your country, including outside the EEA, protected by Standard Contractual Clauses or an adequacy decision.\n\nWHAT WE CANNOT DELETE\nRecords of significant actions are append-only: nobody can edit them, including us, and they are deleted only when their retention period ends. This includes the history of marks and attendance, earlier hand-ins, and files a teacher replaced. Schools are often required to keep attendance, assessment and safeguarding records. The app shows you which records stay with your school before you confirm a deletion. Encrypted backups are kept for 30 days.\n\nON YOUR DEVICE\nThe app keeps your session, your language, a cache of what you opened and downloaded, your study helper chats and your profile photo, separately for each account. Your profile photo is never uploaded to our servers, so nobody else sees it. They are cleared when that account signs out.\n\nHOW WE PROTECT IT\nAccess to a class\'s data is enforced in the database itself, and only that class\'s teachers can change its marks and attendance. Secrets are stripped from logs. In our own records IP addresses are stored only as a one-way hash; the sign-in service (Supabase) keeps the IP address of a sign-in for up to 7 days. Backups are encrypted before they leave our systems.\n\nYOUR RIGHTS\nYou may ask for a copy of your data, correct it, delete your account, restrict or object to processing, or withdraw consent. Account deletion and data export are in Account settings, and deletion can be cancelled for 14 days; a parent does this for a child account they manage. You may complain to the Data Protection Commission in Ireland at any time.\n\nIf your school controls your records, ask your school first; we will pass your request on and tell you we have.'**
  String get policyPrivacyBody;

  /// In-app summary of docs/legal/terms-of-use.md (consent version 2026-10-14), which governs. See policyPrivacyBody.
  ///
  /// In en, this message translates to:
  /// **'WHO THIS IS FOR\nStudafy is for teachers, students and parents. There is no school administrator in this version of the app. By signing in you accept these terms and the Privacy Policy.\n\nYOUR ACCOUNT\nSign in with Google, Microsoft or Apple and keep that account secure. You can add several accounts to one device; sign out on a device you share. A parent may create an account for a child with no email or phone, accepts these terms for the child, and is responsible for how it is used. Do not impersonate anyone.\n\nUSE IT PROPERLY\nUse Studafy only for learning, teaching and school communication. Do not bully, harass or threaten anyone, share sexual, violent, hateful or unlawful content, upload files you have no right to share, try to see records that are not yours, or hand in someone else\'s work - or AI output - as your own. You can report or block anyone from inside the app. We may remove content and suspend accounts that break these rules.\n\nTEACHERS\nYou are responsible for the marks and attendance you record. Marks are drafts until you publish them. A published mark is changed only by correcting it with a reason, and the old mark is kept. Attendance changes after the lesson\'s day need a reason; after seven days only the class\'s lead teacher can change a register. Give students more time or reopen work with a reason. Files you replace or remove are kept for the school. Share only what you have the right to share.\n\nSTUDENTS\nHand in your own work. You can replace it until the deadline, which is in your school\'s time zone; earlier hand-ins are kept. After the deadline, or once a mark is published, you need your teacher\'s permission to hand in again. If a mark or attendance record looks wrong, ask your teacher.\n\nPARENTS\nYou can link to your child only with their approval, unless you created their account. You can see published marks, attendance, work and class material, and hand work in for a young child. You cannot change marks or attendance, and you do not see your child\'s private messages. Family+ is your own paid plan: one plan covers up to 4 linked children, a larger one up to 8, in the order you linked them. It summarises what you can already see, compares a child only with their own earlier record, and predicts nothing.\n\nYOUR CONTENT\nYou keep the rights in what you write and upload. You let us store and show it only to run Studafy for you and your school. Work handed in, marks, attendance and shared files become part of the school\'s records.\n\nAI STUDY TOOLS\nThey are optional and can be wrong. Check what they produce and never hand it in as your own work. AI never marks work. Daily and monthly limits apply.\n\nSUBSCRIPTIONS\nLessons, notebooks, work, marks and attendance are free. Studafy Plus and Studafy Max are for students; Family+ is for parents, for up to 4 or up to 8 linked children. All are billed monthly by Apple or Google at the price the store shows until you cancel in your store account, where refunds are also handled.\n\nMEETINGS\nStudafy does not host video calls. Meeting links open in Google Meet under Google\'s terms.\n\nCHANGES AND ENDING\nWe may change or withdraw features, and will tell you before a change to these terms that affects you. You can delete your account in Account settings and cancel within 14 days. Records the school must keep stay with the school.'**
  String get policyTermsBody;

  /// No description provided for @deleteTitle.
  ///
  /// In en, this message translates to:
  /// **'Delete account'**
  String get deleteTitle;

  /// No description provided for @deleteWarningTitle.
  ///
  /// In en, this message translates to:
  /// **'This affects more than your profile'**
  String get deleteWarningTitle;

  /// No description provided for @deleteWarningBody.
  ///
  /// In en, this message translates to:
  /// **'Access to your profile, classes, messages, and personal files will end.'**
  String get deleteWarningBody;

  /// No description provided for @deleteWhatGoesHeading.
  ///
  /// In en, this message translates to:
  /// **'WHAT WILL BE DELETED'**
  String get deleteWhatGoesHeading;

  /// No description provided for @deleteSchoolKeepsHeading.
  ///
  /// In en, this message translates to:
  /// **'WHAT YOUR SCHOOL KEEPS'**
  String get deleteSchoolKeepsHeading;

  /// No description provided for @deleteSchoolKeepsBody.
  ///
  /// In en, this message translates to:
  /// **'Schools are required to keep these education records. They stay with the school, not with your account, and deleting your account does not remove them. Ask your school if you need them corrected or erased.'**
  String get deleteSchoolKeepsBody;

  /// No description provided for @deleteNoSchoolRecords.
  ///
  /// In en, this message translates to:
  /// **'Your school holds no records for this account.'**
  String get deleteNoSchoolRecords;

  /// No description provided for @deleteSchoolAccessHeading.
  ///
  /// In en, this message translates to:
  /// **'SCHOOL ACCESS THAT ENDS'**
  String get deleteSchoolAccessHeading;

  /// No description provided for @deleteChildAccountsHeading.
  ///
  /// In en, this message translates to:
  /// **'CHILD ACCOUNTS DELETED TOO'**
  String get deleteChildAccountsHeading;

  /// No description provided for @deleteChildAccountsBody.
  ///
  /// In en, this message translates to:
  /// **'You manage these child accounts. Nobody else can sign in to them, so they are deleted with your account, after the same 14 days.'**
  String get deleteChildAccountsBody;

  /// No description provided for @deleteWhyHeading.
  ///
  /// In en, this message translates to:
  /// **'TELL US WHY'**
  String get deleteWhyHeading;

  /// No description provided for @deleteReasonLabel.
  ///
  /// In en, this message translates to:
  /// **'Reason for leaving'**
  String get deleteReasonLabel;

  /// No description provided for @deleteReasonNoLongerUsing.
  ///
  /// In en, this message translates to:
  /// **'I no longer use Studafy'**
  String get deleteReasonNoLongerUsing;

  /// No description provided for @deleteReasonChangingSchools.
  ///
  /// In en, this message translates to:
  /// **'I am changing schools'**
  String get deleteReasonChangingSchools;

  /// No description provided for @deleteReasonPrivacy.
  ///
  /// In en, this message translates to:
  /// **'Privacy concerns'**
  String get deleteReasonPrivacy;

  /// No description provided for @deleteReasonDuplicate.
  ///
  /// In en, this message translates to:
  /// **'I have another account'**
  String get deleteReasonDuplicate;

  /// No description provided for @deleteReasonUndisclosed.
  ///
  /// In en, this message translates to:
  /// **'Prefer not to say'**
  String get deleteReasonUndisclosed;

  /// No description provided for @deleteAcknowledgementsHeading.
  ///
  /// In en, this message translates to:
  /// **'ACKNOWLEDGEMENTS'**
  String get deleteAcknowledgementsHeading;

  /// No description provided for @deleteSavedWhatINeed.
  ///
  /// In en, this message translates to:
  /// **'I saved what I need'**
  String get deleteSavedWhatINeed;

  /// No description provided for @deleteSavedWhatINeedDetail.
  ///
  /// In en, this message translates to:
  /// **'Download a copy of personal data and files'**
  String get deleteSavedWhatINeedDetail;

  /// No description provided for @deleteUnderstandFinal.
  ///
  /// In en, this message translates to:
  /// **'{days, plural, =1{I understand this cannot be undone after 1 day} other{I understand this cannot be undone after {days} days}}'**
  String deleteUnderstandFinal(int days);

  /// No description provided for @deleteCancelWindow.
  ///
  /// In en, this message translates to:
  /// **'{days, plural, =1{You can cancel in this app during the 1-day period} other{You can cancel in this app during the {days}-day period}}'**
  String deleteCancelWindow(int days);

  /// No description provided for @deleteUnderstandSchoolKeeps.
  ///
  /// In en, this message translates to:
  /// **'I understand my school keeps some records'**
  String get deleteUnderstandSchoolKeeps;

  /// No description provided for @deleteRetainedCount.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =0{No education records stay with your school} =1{1 education record stays with your school} other{{count} education records stay with your school}}'**
  String deleteRetainedCount(int count);

  /// {word} is the literal confirmation token the user must type. It stays untranslated on purpose: it is compared character for character, so translating it would break the check.
  ///
  /// In en, this message translates to:
  /// **'Type {word} to confirm deletion of {email}.'**
  String deleteTypeToConfirm(String word, String email);

  /// No description provided for @deleteWorking.
  ///
  /// In en, this message translates to:
  /// **'Working…'**
  String get deleteWorking;

  /// No description provided for @deleteSchedule.
  ///
  /// In en, this message translates to:
  /// **'Schedule account deletion'**
  String get deleteSchedule;

  /// No description provided for @deleteConfirmIdentityNote.
  ///
  /// In en, this message translates to:
  /// **'You will be asked to confirm it is you before this is scheduled.'**
  String get deleteConfirmIdentityNote;

  /// No description provided for @deleteKeptSnack.
  ///
  /// In en, this message translates to:
  /// **'Your account will be kept.'**
  String get deleteKeptSnack;

  /// No description provided for @deleteScheduledTitle.
  ///
  /// In en, this message translates to:
  /// **'Deletion scheduled'**
  String get deleteScheduledTitle;

  /// No description provided for @deleteScheduledBody.
  ///
  /// In en, this message translates to:
  /// **'{email} will be deleted after {date}. Until then you can stop it here — you do not need to contact support.'**
  String deleteScheduledBody(String email, String date);

  /// No description provided for @deleteKeepMyAccount.
  ///
  /// In en, this message translates to:
  /// **'Keep my account'**
  String get deleteKeepMyAccount;

  /// No description provided for @deleteTryAgain.
  ///
  /// In en, this message translates to:
  /// **'Try again'**
  String get deleteTryAgain;

  /// No description provided for @recordProfile.
  ///
  /// In en, this message translates to:
  /// **'Your profile'**
  String get recordProfile;

  /// No description provided for @recordDevices.
  ///
  /// In en, this message translates to:
  /// **'Signed-in devices'**
  String get recordDevices;

  /// No description provided for @recordConsents.
  ///
  /// In en, this message translates to:
  /// **'Consent records'**
  String get recordConsents;

  /// No description provided for @recordNotifications.
  ///
  /// In en, this message translates to:
  /// **'Notifications'**
  String get recordNotifications;

  /// No description provided for @recordAttendance.
  ///
  /// In en, this message translates to:
  /// **'Attendance records'**
  String get recordAttendance;

  /// No description provided for @recordGrades.
  ///
  /// In en, this message translates to:
  /// **'Grades'**
  String get recordGrades;

  /// No description provided for @recordSubmissions.
  ///
  /// In en, this message translates to:
  /// **'Submitted work'**
  String get recordSubmissions;

  /// No description provided for @recordWellbeing.
  ///
  /// In en, this message translates to:
  /// **'Wellbeing notes'**
  String get recordWellbeing;

  /// No description provided for @academicTitle.
  ///
  /// In en, this message translates to:
  /// **'Academic workspace'**
  String get academicTitle;

  /// No description provided for @academicNoRecords.
  ///
  /// In en, this message translates to:
  /// **'No records yet.'**
  String get academicNoRecords;

  /// No description provided for @academicUnavailable.
  ///
  /// In en, this message translates to:
  /// **'School data is unavailable. No local copy was saved.'**
  String get academicUnavailable;

  /// No description provided for @academicRetry.
  ///
  /// In en, this message translates to:
  /// **'Retry'**
  String get academicRetry;

  /// No description provided for @academicFileNote.
  ///
  /// In en, this message translates to:
  /// **'File text lesson note'**
  String get academicFileNote;

  /// No description provided for @academicNoteTitle.
  ///
  /// In en, this message translates to:
  /// **'Text lesson note'**
  String get academicNoteTitle;

  /// No description provided for @academicNoteTitleLabel.
  ///
  /// In en, this message translates to:
  /// **'Title'**
  String get academicNoteTitleLabel;

  /// No description provided for @academicNoteBodyLabel.
  ///
  /// In en, this message translates to:
  /// **'Note'**
  String get academicNoteBodyLabel;

  /// No description provided for @academicAttachmentsUnavailable.
  ///
  /// In en, this message translates to:
  /// **'Attachments are unavailable until file uploads are switched on.'**
  String get academicAttachmentsUnavailable;

  /// No description provided for @academicNoteNotSaved.
  ///
  /// In en, this message translates to:
  /// **'Not saved. Your text is kept here so you can retry.'**
  String get academicNoteNotSaved;

  /// No description provided for @academicCancel.
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get academicCancel;

  /// No description provided for @academicSaveToSchool.
  ///
  /// In en, this message translates to:
  /// **'Save to school'**
  String get academicSaveToSchool;

  /// No description provided for @feedContent.
  ///
  /// In en, this message translates to:
  /// **'Lessons'**
  String get feedContent;

  /// No description provided for @feedAssignments.
  ///
  /// In en, this message translates to:
  /// **'Assignments'**
  String get feedAssignments;

  /// No description provided for @feedAssessments.
  ///
  /// In en, this message translates to:
  /// **'Assessments'**
  String get feedAssessments;

  /// No description provided for @feedGrades.
  ///
  /// In en, this message translates to:
  /// **'Grades'**
  String get feedGrades;

  /// No description provided for @feedAttendance.
  ///
  /// In en, this message translates to:
  /// **'Attendance'**
  String get feedAttendance;

  /// No description provided for @feedWellbeing.
  ///
  /// In en, this message translates to:
  /// **'Wellbeing'**
  String get feedWellbeing;

  /// No description provided for @classesTitle.
  ///
  /// In en, this message translates to:
  /// **'My classes'**
  String get classesTitle;

  /// No description provided for @classesCreate.
  ///
  /// In en, this message translates to:
  /// **'Create class'**
  String get classesCreate;

  /// No description provided for @classesCreateTitle.
  ///
  /// In en, this message translates to:
  /// **'Create a new classroom'**
  String get classesCreateTitle;

  /// No description provided for @classesNameLabel.
  ///
  /// In en, this message translates to:
  /// **'Class name'**
  String get classesNameLabel;

  /// No description provided for @classesRoomLabel.
  ///
  /// In en, this message translates to:
  /// **'Room'**
  String get classesRoomLabel;

  /// No description provided for @classesGradeLabel.
  ///
  /// In en, this message translates to:
  /// **'Grade'**
  String get classesGradeLabel;

  /// No description provided for @classesGradeOption.
  ///
  /// In en, this message translates to:
  /// **'Grade {number}'**
  String classesGradeOption(int number);

  /// No description provided for @classesSectionLabel.
  ///
  /// In en, this message translates to:
  /// **'Section'**
  String get classesSectionLabel;

  /// No description provided for @classesWeeklyLabel.
  ///
  /// In en, this message translates to:
  /// **'How many classes each week?'**
  String get classesWeeklyLabel;

  /// No description provided for @classesWeeklyOption.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 class} other{{count} classes}}'**
  String classesWeeklyOption(int count);

  /// No description provided for @classesChooseTimes.
  ///
  /// In en, this message translates to:
  /// **'Choose the day and time for every class'**
  String get classesChooseTimes;

  /// No description provided for @classesSessionNumber.
  ///
  /// In en, this message translates to:
  /// **'Class {number}'**
  String classesSessionNumber(int number);

  /// No description provided for @classesDayLabel.
  ///
  /// In en, this message translates to:
  /// **'Day'**
  String get classesDayLabel;

  /// No description provided for @classesTo.
  ///
  /// In en, this message translates to:
  /// **'to'**
  String get classesTo;

  /// No description provided for @classesCancel.
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get classesCancel;

  /// No description provided for @classesCreateAction.
  ///
  /// In en, this message translates to:
  /// **'Create classroom'**
  String get classesCreateAction;

  /// No description provided for @classesInviteTitle.
  ///
  /// In en, this message translates to:
  /// **'Invite students'**
  String get classesInviteTitle;

  /// No description provided for @classesInviteBody.
  ///
  /// In en, this message translates to:
  /// **'Share this secure link. Students are added only after they open it and join the class.'**
  String get classesInviteBody;

  /// Label above the short class code a teacher reads out or writes on the board.
  ///
  /// In en, this message translates to:
  /// **'Class code'**
  String get classesInviteCodeLabel;

  /// Label above the class join link, shown when a code is also available.
  ///
  /// In en, this message translates to:
  /// **'Or send this link'**
  String get classesInviteLinkLabel;

  /// No description provided for @classesInviteCopied.
  ///
  /// In en, this message translates to:
  /// **'Invite link copied.'**
  String get classesInviteCopied;

  /// No description provided for @classesCopy.
  ///
  /// In en, this message translates to:
  /// **'Copy'**
  String get classesCopy;

  /// No description provided for @classesShareLink.
  ///
  /// In en, this message translates to:
  /// **'Share link'**
  String get classesShareLink;

  /// No description provided for @classesShareMessage.
  ///
  /// In en, this message translates to:
  /// **'Join my Studafy class: {link}'**
  String classesShareMessage(String link);

  /// Message shared with students when the class has both a link and a code.
  ///
  /// In en, this message translates to:
  /// **'Join my Studafy class with the class code {code}\nOr open this link: {link}'**
  String classesShareMessageWithCode(String link, String code);

  /// No description provided for @classesGradeSection.
  ///
  /// In en, this message translates to:
  /// **'Grade {grade} · Section {section}'**
  String classesGradeSection(String grade, String section);

  /// No description provided for @classesStudentCount.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =0{No students} =1{1 student} other{{count} students}}'**
  String classesStudentCount(int count);

  /// No description provided for @classesPerWeek.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 class/week} other{{count} classes/week}}'**
  String classesPerWeek(int count);

  /// No description provided for @classesRoomTbd.
  ///
  /// In en, this message translates to:
  /// **'Room to be decided'**
  String get classesRoomTbd;

  /// No description provided for @attendancePresent.
  ///
  /// In en, this message translates to:
  /// **'Present'**
  String get attendancePresent;

  /// No description provided for @attendanceAbsent.
  ///
  /// In en, this message translates to:
  /// **'Absent'**
  String get attendanceAbsent;

  /// No description provided for @attendanceTardy.
  ///
  /// In en, this message translates to:
  /// **'Tardy'**
  String get attendanceTardy;

  /// No description provided for @attendanceExcused.
  ///
  /// In en, this message translates to:
  /// **'Excused absence'**
  String get attendanceExcused;

  /// No description provided for @attendanceExcusedReason.
  ///
  /// In en, this message translates to:
  /// **'Reason for excused absence'**
  String get attendanceExcusedReason;

  /// No description provided for @attendanceSaved.
  ///
  /// In en, this message translates to:
  /// **'Attendance saved successfully.'**
  String get attendanceSaved;

  /// No description provided for @attendanceSave.
  ///
  /// In en, this message translates to:
  /// **'Save attendance'**
  String get attendanceSave;

  /// No description provided for @syntheticBanner.
  ///
  /// In en, this message translates to:
  /// **'SYNTHETIC DATA — NOT FOR REAL SCHOOL USE'**
  String get syntheticBanner;

  /// No description provided for @blockedTitle.
  ///
  /// In en, this message translates to:
  /// **'Studafy is not production-ready'**
  String get blockedTitle;

  /// No description provided for @blockedDefaultReason.
  ///
  /// In en, this message translates to:
  /// **'Production access is blocked until security and data-integrity gates pass.'**
  String get blockedDefaultReason;

  /// No description provided for @blockedReference.
  ///
  /// In en, this message translates to:
  /// **'Reference: SEC-001'**
  String get blockedReference;

  /// No description provided for @blockedInvalidEnvironment.
  ///
  /// In en, this message translates to:
  /// **'Invalid APP_ENV. This build has been blocked for safety.'**
  String get blockedInvalidEnvironment;

  /// No description provided for @attendanceTitle.
  ///
  /// In en, this message translates to:
  /// **'Attendance · {className}'**
  String attendanceTitle(String className);

  /// No description provided for @attendanceAction.
  ///
  /// In en, this message translates to:
  /// **'Take attendance'**
  String get attendanceAction;

  /// No description provided for @attendanceWhichSession.
  ///
  /// In en, this message translates to:
  /// **'Which session?'**
  String get attendanceWhichSession;

  /// No description provided for @attendanceNoSessionThatDay.
  ///
  /// In en, this message translates to:
  /// **'This class does not meet on the day you picked.'**
  String get attendanceNoSessionThatDay;

  /// No description provided for @attendanceNoStudents.
  ///
  /// In en, this message translates to:
  /// **'No students are enrolled in this class.'**
  String get attendanceNoStudents;

  /// No description provided for @attendanceSaving.
  ///
  /// In en, this message translates to:
  /// **'Saving…'**
  String get attendanceSaving;

  /// No description provided for @attendanceMarkOne.
  ///
  /// In en, this message translates to:
  /// **'Mark at least one student first.'**
  String get attendanceMarkOne;

  /// No description provided for @attendanceLoadFailed.
  ///
  /// In en, this message translates to:
  /// **'Could not load the register. Please try again.'**
  String get attendanceLoadFailed;

  /// No description provided for @attendanceReasonLabel.
  ///
  /// In en, this message translates to:
  /// **'Reason (optional)'**
  String get attendanceReasonLabel;

  /// No description provided for @rosterTitle.
  ///
  /// In en, this message translates to:
  /// **'Students · {className}'**
  String rosterTitle(String className);

  /// No description provided for @rosterAction.
  ///
  /// In en, this message translates to:
  /// **'Students'**
  String get rosterAction;

  /// No description provided for @rosterNoGuardian.
  ///
  /// In en, this message translates to:
  /// **'No parent linked yet'**
  String get rosterNoGuardian;

  /// No description provided for @rosterEmpty.
  ///
  /// In en, this message translates to:
  /// **'No students are enrolled in this class yet.'**
  String get rosterEmpty;

  /// No description provided for @rosterLoadFailed.
  ///
  /// In en, this message translates to:
  /// **'Could not load the class list. Please try again.'**
  String get rosterLoadFailed;

  /// No description provided for @rosterTryAgain.
  ///
  /// In en, this message translates to:
  /// **'Try again'**
  String get rosterTryAgain;

  /// No description provided for @attendanceSavedCount.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{Register saved for 1 student.} other{Register saved for {count} students.}}'**
  String attendanceSavedCount(int count);

  /// No description provided for @assignmentNewTitle.
  ///
  /// In en, this message translates to:
  /// **'New assignment'**
  String get assignmentNewTitle;

  /// No description provided for @assignmentAction.
  ///
  /// In en, this message translates to:
  /// **'New assignment'**
  String get assignmentAction;

  /// No description provided for @assignmentClassLabel.
  ///
  /// In en, this message translates to:
  /// **'Class'**
  String get assignmentClassLabel;

  /// No description provided for @assignmentTitleLabel.
  ///
  /// In en, this message translates to:
  /// **'Title'**
  String get assignmentTitleLabel;

  /// No description provided for @assignmentInstructionsLabel.
  ///
  /// In en, this message translates to:
  /// **'Instructions (optional)'**
  String get assignmentInstructionsLabel;

  /// No description provided for @assignmentDueLabel.
  ///
  /// In en, this message translates to:
  /// **'Due'**
  String get assignmentDueLabel;

  /// No description provided for @assignmentPickDue.
  ///
  /// In en, this message translates to:
  /// **'Pick a due date'**
  String get assignmentPickDue;

  /// No description provided for @assignmentGradedLabel.
  ///
  /// In en, this message translates to:
  /// **'Graded'**
  String get assignmentGradedLabel;

  /// No description provided for @assignmentGradedOn.
  ///
  /// In en, this message translates to:
  /// **'Students receive a score out of the maximum you set.'**
  String get assignmentGradedOn;

  /// No description provided for @assignmentGradedOff.
  ///
  /// In en, this message translates to:
  /// **'Students hand work in, with no score.'**
  String get assignmentGradedOff;

  /// No description provided for @assignmentMaxScoreLabel.
  ///
  /// In en, this message translates to:
  /// **'Maximum score'**
  String get assignmentMaxScoreLabel;

  /// No description provided for @assignmentCreate.
  ///
  /// In en, this message translates to:
  /// **'Create assignment'**
  String get assignmentCreate;

  /// No description provided for @assignmentCreating.
  ///
  /// In en, this message translates to:
  /// **'Creating…'**
  String get assignmentCreating;

  /// No description provided for @assignmentCreated.
  ///
  /// In en, this message translates to:
  /// **'Assignment created.'**
  String get assignmentCreated;

  /// No description provided for @assignmentTitleRequired.
  ///
  /// In en, this message translates to:
  /// **'Give the assignment a title.'**
  String get assignmentTitleRequired;

  /// No description provided for @assignmentClassRequired.
  ///
  /// In en, this message translates to:
  /// **'Choose which class this is for.'**
  String get assignmentClassRequired;

  /// No description provided for @assignmentDueRequired.
  ///
  /// In en, this message translates to:
  /// **'Choose when it is due.'**
  String get assignmentDueRequired;

  /// No description provided for @assignmentMaxScoreRequired.
  ///
  /// In en, this message translates to:
  /// **'Set a maximum score above zero.'**
  String get assignmentMaxScoreRequired;

  /// No description provided for @assignmentCreateFailed.
  ///
  /// In en, this message translates to:
  /// **'Could not create the assignment. Please try again.'**
  String get assignmentCreateFailed;

  /// No description provided for @announcementNewTitle.
  ///
  /// In en, this message translates to:
  /// **'New announcement'**
  String get announcementNewTitle;

  /// No description provided for @announcementAction.
  ///
  /// In en, this message translates to:
  /// **'Announce'**
  String get announcementAction;

  /// No description provided for @announcementTitleLabel.
  ///
  /// In en, this message translates to:
  /// **'Title'**
  String get announcementTitleLabel;

  /// No description provided for @announcementBodyLabel.
  ///
  /// In en, this message translates to:
  /// **'Message'**
  String get announcementBodyLabel;

  /// No description provided for @announcementClassLabel.
  ///
  /// In en, this message translates to:
  /// **'Class'**
  String get announcementClassLabel;

  /// No description provided for @announcementAudienceLabel.
  ///
  /// In en, this message translates to:
  /// **'Who should see this'**
  String get announcementAudienceLabel;

  /// No description provided for @announcementAudienceStudents.
  ///
  /// In en, this message translates to:
  /// **'Students'**
  String get announcementAudienceStudents;

  /// No description provided for @announcementAudienceGuardians.
  ///
  /// In en, this message translates to:
  /// **'Parents and guardians'**
  String get announcementAudienceGuardians;

  /// No description provided for @announcementAudienceBoth.
  ///
  /// In en, this message translates to:
  /// **'Everyone'**
  String get announcementAudienceBoth;

  /// No description provided for @announcementImportantLabel.
  ///
  /// In en, this message translates to:
  /// **'Mark as important'**
  String get announcementImportantLabel;

  /// No description provided for @announcementImportantDetail.
  ///
  /// In en, this message translates to:
  /// **'Use this for things that change what someone does today.'**
  String get announcementImportantDetail;

  /// No description provided for @announcementPost.
  ///
  /// In en, this message translates to:
  /// **'Post announcement'**
  String get announcementPost;

  /// No description provided for @announcementPosting.
  ///
  /// In en, this message translates to:
  /// **'Posting…'**
  String get announcementPosting;

  /// No description provided for @announcementPosted.
  ///
  /// In en, this message translates to:
  /// **'Announcement posted.'**
  String get announcementPosted;

  /// No description provided for @announcementTitleRequired.
  ///
  /// In en, this message translates to:
  /// **'Give the announcement a title.'**
  String get announcementTitleRequired;

  /// No description provided for @announcementBodyRequired.
  ///
  /// In en, this message translates to:
  /// **'Write the message.'**
  String get announcementBodyRequired;

  /// No description provided for @announcementClassRequired.
  ///
  /// In en, this message translates to:
  /// **'Choose which class to announce to.'**
  String get announcementClassRequired;

  /// No description provided for @announcementFailed.
  ///
  /// In en, this message translates to:
  /// **'Could not post the announcement. Please try again.'**
  String get announcementFailed;

  /// No description provided for @gradebookTitle.
  ///
  /// In en, this message translates to:
  /// **'Gradebook · {className}'**
  String gradebookTitle(String className);

  /// No description provided for @gradebookAction.
  ///
  /// In en, this message translates to:
  /// **'Gradebook'**
  String get gradebookAction;

  /// No description provided for @gradebookPickAssessment.
  ///
  /// In en, this message translates to:
  /// **'Choose what to mark'**
  String get gradebookPickAssessment;

  /// No description provided for @gradebookNoAssessments.
  ///
  /// In en, this message translates to:
  /// **'Nothing to mark yet. Create graded work first.'**
  String get gradebookNoAssessments;

  /// No description provided for @gradebookDraftNotice.
  ///
  /// In en, this message translates to:
  /// **'This is still a draft. Publish it to open the register of marks.'**
  String get gradebookDraftNotice;

  /// No description provided for @gradebookPublishAssessment.
  ///
  /// In en, this message translates to:
  /// **'Publish and start marking'**
  String get gradebookPublishAssessment;

  /// No description provided for @gradebookNoStudents.
  ///
  /// In en, this message translates to:
  /// **'No students are enrolled in this class.'**
  String get gradebookNoStudents;

  /// No description provided for @gradebookScoreOf.
  ///
  /// In en, this message translates to:
  /// **'out of {max}'**
  String gradebookScoreOf(String max);

  /// No description provided for @gradebookSave.
  ///
  /// In en, this message translates to:
  /// **'Save marks'**
  String get gradebookSave;

  /// No description provided for @gradebookSaving.
  ///
  /// In en, this message translates to:
  /// **'Saving…'**
  String get gradebookSaving;

  /// No description provided for @gradebookSaved.
  ///
  /// In en, this message translates to:
  /// **'Marks saved.'**
  String get gradebookSaved;

  /// No description provided for @gradebookNothingChanged.
  ///
  /// In en, this message translates to:
  /// **'No marks were changed.'**
  String get gradebookNothingChanged;

  /// No description provided for @gradebookScoreTooHigh.
  ///
  /// In en, this message translates to:
  /// **'A mark cannot be above the maximum.'**
  String get gradebookScoreTooHigh;

  /// No description provided for @gradebookLoadFailed.
  ///
  /// In en, this message translates to:
  /// **'Could not load the gradebook. Please try again.'**
  String get gradebookLoadFailed;

  /// No description provided for @gradebookSaveFailed.
  ///
  /// In en, this message translates to:
  /// **'Could not save the marks. Please try again.'**
  String get gradebookSaveFailed;

  /// No description provided for @gradebookRelease.
  ///
  /// In en, this message translates to:
  /// **'Release to students'**
  String get gradebookRelease;

  /// No description provided for @gradebookReleased.
  ///
  /// In en, this message translates to:
  /// **'Marks released.'**
  String get gradebookReleased;

  /// No description provided for @sectionsTitle.
  ///
  /// In en, this message translates to:
  /// **'Sections · {className}'**
  String sectionsTitle(String className);

  /// No description provided for @sectionsAction.
  ///
  /// In en, this message translates to:
  /// **'Lesson content'**
  String get sectionsAction;

  /// No description provided for @sectionsNone.
  ///
  /// In en, this message translates to:
  /// **'No sections have been taught yet. Take a register first.'**
  String get sectionsNone;

  /// No description provided for @sectionsOutstanding.
  ///
  /// In en, this message translates to:
  /// **'Content outstanding'**
  String get sectionsOutstanding;

  /// No description provided for @sectionsFiled.
  ///
  /// In en, this message translates to:
  /// **'Closed'**
  String get sectionsFiled;

  /// No description provided for @sectionsFileContent.
  ///
  /// In en, this message translates to:
  /// **'File content'**
  String get sectionsFileContent;

  /// No description provided for @sectionsClose.
  ///
  /// In en, this message translates to:
  /// **'Close section'**
  String get sectionsClose;

  /// No description provided for @sectionsClosed.
  ///
  /// In en, this message translates to:
  /// **'Section closed.'**
  String get sectionsClosed;

  /// No description provided for @sectionsCloseBlocked.
  ///
  /// In en, this message translates to:
  /// **'File the content taught in this section before closing it.'**
  String get sectionsCloseBlocked;

  /// No description provided for @sectionsContentTitle.
  ///
  /// In en, this message translates to:
  /// **'What was taught'**
  String get sectionsContentTitle;

  /// No description provided for @sectionsContentTitleLabel.
  ///
  /// In en, this message translates to:
  /// **'Title'**
  String get sectionsContentTitleLabel;

  /// No description provided for @sectionsContentBodyLabel.
  ///
  /// In en, this message translates to:
  /// **'Summary of the section'**
  String get sectionsContentBodyLabel;

  /// No description provided for @sectionsContentSave.
  ///
  /// In en, this message translates to:
  /// **'File it'**
  String get sectionsContentSave;

  /// No description provided for @sectionsContentSaved.
  ///
  /// In en, this message translates to:
  /// **'Content filed.'**
  String get sectionsContentSaved;

  /// No description provided for @sectionsContentRequired.
  ///
  /// In en, this message translates to:
  /// **'Write what was taught in this section.'**
  String get sectionsContentRequired;

  /// No description provided for @sectionsLoadFailed.
  ///
  /// In en, this message translates to:
  /// **'Could not load the sections. Please try again.'**
  String get sectionsLoadFailed;

  /// No description provided for @sectionsSaveFailed.
  ///
  /// In en, this message translates to:
  /// **'Could not save. Please try again.'**
  String get sectionsSaveFailed;

  /// No description provided for @examNewTitle.
  ///
  /// In en, this message translates to:
  /// **'New exam'**
  String get examNewTitle;

  /// No description provided for @examAction.
  ///
  /// In en, this message translates to:
  /// **'New exam'**
  String get examAction;

  /// No description provided for @examClassLabel.
  ///
  /// In en, this message translates to:
  /// **'Class'**
  String get examClassLabel;

  /// No description provided for @examTitleLabel.
  ///
  /// In en, this message translates to:
  /// **'Title'**
  String get examTitleLabel;

  /// No description provided for @examCategoryLabel.
  ///
  /// In en, this message translates to:
  /// **'Kind'**
  String get examCategoryLabel;

  /// No description provided for @examCategoryExam.
  ///
  /// In en, this message translates to:
  /// **'Exam'**
  String get examCategoryExam;

  /// No description provided for @examCategoryQuiz.
  ///
  /// In en, this message translates to:
  /// **'Quiz'**
  String get examCategoryQuiz;

  /// No description provided for @examCategoryMidterm.
  ///
  /// In en, this message translates to:
  /// **'Midterm'**
  String get examCategoryMidterm;

  /// No description provided for @examCategoryFinal.
  ///
  /// In en, this message translates to:
  /// **'Final'**
  String get examCategoryFinal;

  /// No description provided for @examDeliveryLabel.
  ///
  /// In en, this message translates to:
  /// **'How it is taken'**
  String get examDeliveryLabel;

  /// No description provided for @examDeliveryPaper.
  ///
  /// In en, this message translates to:
  /// **'On paper'**
  String get examDeliveryPaper;

  /// No description provided for @examDeliveryPaperDetail.
  ///
  /// In en, this message translates to:
  /// **'Sat in class; you enter the marks yourself.'**
  String get examDeliveryPaperDetail;

  /// No description provided for @examDeliveryOnline.
  ///
  /// In en, this message translates to:
  /// **'In the app'**
  String get examDeliveryOnline;

  /// No description provided for @examDeliveryOnlineDetail.
  ///
  /// In en, this message translates to:
  /// **'Students answer the questions in Studafy.'**
  String get examDeliveryOnlineDetail;

  /// No description provided for @examDeliveryPractice.
  ///
  /// In en, this message translates to:
  /// **'Practice'**
  String get examDeliveryPractice;

  /// No description provided for @examDeliveryPracticeDetail.
  ///
  /// In en, this message translates to:
  /// **'Students practise freely; it does not count.'**
  String get examDeliveryPracticeDetail;

  /// No description provided for @examScheduleLabel.
  ///
  /// In en, this message translates to:
  /// **'When it is sat'**
  String get examScheduleLabel;

  /// No description provided for @examPickSchedule.
  ///
  /// In en, this message translates to:
  /// **'Pick a date and time'**
  String get examPickSchedule;

  /// No description provided for @examQuestionsLabel.
  ///
  /// In en, this message translates to:
  /// **'Questions'**
  String get examQuestionsLabel;

  /// No description provided for @examAddQuestion.
  ///
  /// In en, this message translates to:
  /// **'Add question'**
  String get examAddQuestion;

  /// No description provided for @examQuestionPrompt.
  ///
  /// In en, this message translates to:
  /// **'Question {number}'**
  String examQuestionPrompt(int number);

  /// No description provided for @examQuestionMarks.
  ///
  /// In en, this message translates to:
  /// **'Marks'**
  String get examQuestionMarks;

  /// No description provided for @examQuestionAnswer.
  ///
  /// In en, this message translates to:
  /// **'Model answer (optional)'**
  String get examQuestionAnswer;

  /// No description provided for @examRemoveQuestion.
  ///
  /// In en, this message translates to:
  /// **'Remove'**
  String get examRemoveQuestion;

  /// No description provided for @examMoveUp.
  ///
  /// In en, this message translates to:
  /// **'Move up'**
  String get examMoveUp;

  /// No description provided for @examMoveDown.
  ///
  /// In en, this message translates to:
  /// **'Move down'**
  String get examMoveDown;

  /// No description provided for @examTotalFromQuestions.
  ///
  /// In en, this message translates to:
  /// **'Total: {total} marks, from {count} questions.'**
  String examTotalFromQuestions(String total, int count);

  /// No description provided for @examTotalLabel.
  ///
  /// In en, this message translates to:
  /// **'Total marks'**
  String get examTotalLabel;

  /// No description provided for @examNoQuestionsHint.
  ///
  /// In en, this message translates to:
  /// **'No questions listed. Add them, or set the total marks and mark it on paper.'**
  String get examNoQuestionsHint;

  /// No description provided for @examCreate.
  ///
  /// In en, this message translates to:
  /// **'Create exam'**
  String get examCreate;

  /// No description provided for @examCreating.
  ///
  /// In en, this message translates to:
  /// **'Creating…'**
  String get examCreating;

  /// No description provided for @examCreated.
  ///
  /// In en, this message translates to:
  /// **'Exam created as a draft. Publish it from the gradebook when you are ready.'**
  String get examCreated;

  /// No description provided for @examTitleRequired.
  ///
  /// In en, this message translates to:
  /// **'Give the exam a title.'**
  String get examTitleRequired;

  /// No description provided for @examClassRequired.
  ///
  /// In en, this message translates to:
  /// **'Choose which class sits this exam.'**
  String get examClassRequired;

  /// No description provided for @examTotalRequired.
  ///
  /// In en, this message translates to:
  /// **'Set the total marks above zero.'**
  String get examTotalRequired;

  /// No description provided for @examQuestionPromptRequired.
  ///
  /// In en, this message translates to:
  /// **'Every question needs its text.'**
  String get examQuestionPromptRequired;

  /// No description provided for @examQuestionMarksRequired.
  ///
  /// In en, this message translates to:
  /// **'Every question needs marks above zero.'**
  String get examQuestionMarksRequired;

  /// No description provided for @examOnlineNeedsQuestions.
  ///
  /// In en, this message translates to:
  /// **'An exam taken in the app needs at least one question.'**
  String get examOnlineNeedsQuestions;

  /// No description provided for @examCreateFailed.
  ///
  /// In en, this message translates to:
  /// **'Could not create the exam. Please try again.'**
  String get examCreateFailed;

  /// No description provided for @examTotalHint.
  ///
  /// In en, this message translates to:
  /// **'Students sit this outside the app. Enter the marks in the gradebook; each student sees their own.'**
  String get examTotalHint;

  /// No description provided for @gradeAwaiting.
  ///
  /// In en, this message translates to:
  /// **'Not marked yet'**
  String get gradeAwaiting;

  /// No description provided for @gradeScore.
  ///
  /// In en, this message translates to:
  /// **'{score} out of {max}'**
  String gradeScore(String score, String max);

  /// No description provided for @submitTitle.
  ///
  /// In en, this message translates to:
  /// **'Hand in work'**
  String get submitTitle;

  /// Heading above the files a teacher attached to an assignment, on the hand-in screen.
  ///
  /// In en, this message translates to:
  /// **'From your teacher'**
  String get submitMaterialHeading;

  /// No description provided for @submitAnswerLabel.
  ///
  /// In en, this message translates to:
  /// **'Your work'**
  String get submitAnswerLabel;

  /// No description provided for @submitAnswerHint.
  ///
  /// In en, this message translates to:
  /// **'Type or paste your answer.'**
  String get submitAnswerHint;

  /// No description provided for @submitSend.
  ///
  /// In en, this message translates to:
  /// **'Hand in'**
  String get submitSend;

  /// No description provided for @submitSending.
  ///
  /// In en, this message translates to:
  /// **'Handing in…'**
  String get submitSending;

  /// No description provided for @submitDone.
  ///
  /// In en, this message translates to:
  /// **'Work handed in.'**
  String get submitDone;

  /// No description provided for @submitEmpty.
  ///
  /// In en, this message translates to:
  /// **'Write your answer before handing it in.'**
  String get submitEmpty;

  /// No description provided for @submitFailed.
  ///
  /// In en, this message translates to:
  /// **'Could not hand in your work. Please try again.'**
  String get submitFailed;

  /// No description provided for @submitClosed.
  ///
  /// In en, this message translates to:
  /// **'This assignment is not open for work.'**
  String get submitClosed;

  /// No description provided for @submitAttachmentsSoon.
  ///
  /// In en, this message translates to:
  /// **'Attaching files is not available yet; paste a link if you need to share one.'**
  String get submitAttachmentsSoon;

  /// No description provided for @submissionsTitle.
  ///
  /// In en, this message translates to:
  /// **'Handed in · {title}'**
  String submissionsTitle(String title);

  /// No description provided for @submissionsAction.
  ///
  /// In en, this message translates to:
  /// **'Handed in'**
  String get submissionsAction;

  /// No description provided for @submissionsNone.
  ///
  /// In en, this message translates to:
  /// **'Nobody has handed anything in yet.'**
  String get submissionsNone;

  /// No description provided for @submissionsWaiting.
  ///
  /// In en, this message translates to:
  /// **'Not handed in'**
  String get submissionsWaiting;

  /// No description provided for @submissionsByGuardian.
  ///
  /// In en, this message translates to:
  /// **'Handed in by a parent'**
  String get submissionsByGuardian;

  /// No description provided for @submissionsOn.
  ///
  /// In en, this message translates to:
  /// **'Handed in {when}'**
  String submissionsOn(String when);

  /// No description provided for @submissionsLoadFailed.
  ///
  /// In en, this message translates to:
  /// **'Could not load what was handed in. Please try again.'**
  String get submissionsLoadFailed;

  /// No description provided for @submissionsCount.
  ///
  /// In en, this message translates to:
  /// **'{done} of {total} handed in'**
  String submissionsCount(int done, int total);

  /// No description provided for @scheduleTitle.
  ///
  /// In en, this message translates to:
  /// **'Timetable · {className}'**
  String scheduleTitle(String className);

  /// No description provided for @scheduleAction.
  ///
  /// In en, this message translates to:
  /// **'Timetable'**
  String get scheduleAction;

  /// No description provided for @scheduleHint.
  ///
  /// In en, this message translates to:
  /// **'The register follows this timetable, so a class that meets twice a week needs both here.'**
  String get scheduleHint;

  /// No description provided for @scheduleAddSlot.
  ///
  /// In en, this message translates to:
  /// **'Add a meeting'**
  String get scheduleAddSlot;

  /// No description provided for @scheduleWeekday.
  ///
  /// In en, this message translates to:
  /// **'Day'**
  String get scheduleWeekday;

  /// No description provided for @scheduleStarts.
  ///
  /// In en, this message translates to:
  /// **'Starts'**
  String get scheduleStarts;

  /// No description provided for @scheduleEnds.
  ///
  /// In en, this message translates to:
  /// **'Ends'**
  String get scheduleEnds;

  /// No description provided for @scheduleRemove.
  ///
  /// In en, this message translates to:
  /// **'Remove'**
  String get scheduleRemove;

  /// No description provided for @scheduleSave.
  ///
  /// In en, this message translates to:
  /// **'Save timetable'**
  String get scheduleSave;

  /// No description provided for @scheduleSaving.
  ///
  /// In en, this message translates to:
  /// **'Saving…'**
  String get scheduleSaving;

  /// No description provided for @scheduleSaved.
  ///
  /// In en, this message translates to:
  /// **'Timetable saved.'**
  String get scheduleSaved;

  /// No description provided for @scheduleEmpty.
  ///
  /// In en, this message translates to:
  /// **'No meetings yet. Add one so the register knows when this class meets.'**
  String get scheduleEmpty;

  /// No description provided for @scheduleDuplicate.
  ///
  /// In en, this message translates to:
  /// **'Two lessons are on the same day and time. Change one of them.'**
  String get scheduleDuplicate;

  /// No description provided for @scheduleEndBeforeStart.
  ///
  /// In en, this message translates to:
  /// **'A meeting cannot end before it starts.'**
  String get scheduleEndBeforeStart;

  /// No description provided for @scheduleSaveFailed.
  ///
  /// In en, this message translates to:
  /// **'Could not save the timetable. Please try again.'**
  String get scheduleSaveFailed;

  /// No description provided for @weekdayMon.
  ///
  /// In en, this message translates to:
  /// **'Monday'**
  String get weekdayMon;

  /// No description provided for @weekdayTue.
  ///
  /// In en, this message translates to:
  /// **'Tuesday'**
  String get weekdayTue;

  /// No description provided for @weekdayWed.
  ///
  /// In en, this message translates to:
  /// **'Wednesday'**
  String get weekdayWed;

  /// No description provided for @weekdayThu.
  ///
  /// In en, this message translates to:
  /// **'Thursday'**
  String get weekdayThu;

  /// No description provided for @weekdayFri.
  ///
  /// In en, this message translates to:
  /// **'Friday'**
  String get weekdayFri;

  /// No description provided for @weekdaySat.
  ///
  /// In en, this message translates to:
  /// **'Saturday'**
  String get weekdaySat;

  /// No description provided for @weekdaySun.
  ///
  /// In en, this message translates to:
  /// **'Sunday'**
  String get weekdaySun;

  /// No description provided for @joinLinkActive.
  ///
  /// In en, this message translates to:
  /// **'A join link is live for this class.'**
  String get joinLinkActive;

  /// No description provided for @joinLinkUses.
  ///
  /// In en, this message translates to:
  /// **'Used {count} times'**
  String joinLinkUses(int count);

  /// No description provided for @joinLinkExpires.
  ///
  /// In en, this message translates to:
  /// **'Expires {when}'**
  String joinLinkExpires(String when);

  /// No description provided for @joinLinkRevoke.
  ///
  /// In en, this message translates to:
  /// **'Revoke link'**
  String get joinLinkRevoke;

  /// No description provided for @joinLinkRevoked.
  ///
  /// In en, this message translates to:
  /// **'Link revoked. It no longer works for anyone holding it.'**
  String get joinLinkRevoked;

  /// No description provided for @joinLinkRevokeFailed.
  ///
  /// In en, this message translates to:
  /// **'Could not revoke the link. Please try again.'**
  String get joinLinkRevokeFailed;

  /// No description provided for @joinLinkNewReplaces.
  ///
  /// In en, this message translates to:
  /// **'Creating a new link replaces this one.'**
  String get joinLinkNewReplaces;

  /// Title of the screen where a student enters a class link.
  ///
  /// In en, this message translates to:
  /// **'Join a class'**
  String get joinClassTitle;

  /// Instruction above the class link field.
  ///
  /// In en, this message translates to:
  /// **'Type the class code your teacher gave you, or paste the class link.'**
  String get joinClassPrompt;

  /// Label of the text field that takes the class link or code.
  ///
  /// In en, this message translates to:
  /// **'Class code or link'**
  String get joinClassField;

  /// Button beside the class code field that pastes from the clipboard.
  ///
  /// In en, this message translates to:
  /// **'Paste'**
  String get joinClassPaste;

  /// Shown when the student taps Paste and the clipboard is empty.
  ///
  /// In en, this message translates to:
  /// **'Nothing has been copied. Type the class code, or open the link from your teacher\'s message - the app fills it in for you.'**
  String get joinClassNothingToPaste;

  /// Button that redeems the pasted class link.
  ///
  /// In en, this message translates to:
  /// **'Join class'**
  String get joinClassAction;

  /// Label of the join button while the request is in flight.
  ///
  /// In en, this message translates to:
  /// **'Joining…'**
  String get joinClassBusy;

  /// Shown when the pasted text contains no recognisable join token.
  ///
  /// In en, this message translates to:
  /// **'That is not a class code or link. A code looks like K7QM-4XTR.'**
  String get joinClassInvalid;

  /// Confirmation after joining, naming the class.
  ///
  /// In en, this message translates to:
  /// **'You\'re in {className}'**
  String joinClassDone(String className);

  /// Dismisses the confirmation after joining a class.
  ///
  /// In en, this message translates to:
  /// **'Done'**
  String get joinClassContinue;

  /// Heading for a newly signed-in student who is in no class yet.
  ///
  /// In en, this message translates to:
  /// **'Join your first class'**
  String get onboardingStudentTitle;

  /// Explains where a new student gets a class link.
  ///
  /// In en, this message translates to:
  /// **'Ask your teacher for the class link, then paste it here to get started.'**
  String get onboardingStudentBody;

  /// Heading for a newly signed-in parent who has no children linked.
  ///
  /// In en, this message translates to:
  /// **'Link to your child'**
  String get onboardingParentTitle;

  /// Explains how a parent links to a student and that the student approves.
  ///
  /// In en, this message translates to:
  /// **'Ask your child for their Studafy ID. They approve the request on their own device, so nobody else can see their work.'**
  String get onboardingParentBody;

  /// Takes the parent to the screen where they look up their child.
  ///
  /// In en, this message translates to:
  /// **'Continue'**
  String get onboardingParentAction;

  /// Heading shown to a new teacher before teacher sign-up ships.
  ///
  /// In en, this message translates to:
  /// **'Teacher accounts are almost ready'**
  String get onboardingTeacherTitle;

  /// Explains that self-serve teacher sign-up is not available yet.
  ///
  /// In en, this message translates to:
  /// **'Creating classes from a new teacher account is not switched on yet. Please check back shortly.'**
  String get onboardingTeacherBody;

  /// Heading for a new teacher who is about to get their workspace.
  ///
  /// In en, this message translates to:
  /// **'Set up your teaching space'**
  String get onboardingTeacherReadyTitle;

  /// Explains what happens when a new teacher continues.
  ///
  /// In en, this message translates to:
  /// **'We\'ll get everything ready so you can create your first class and invite students to it.'**
  String get onboardingTeacherReadyBody;

  /// Creates the teacher's workspace and opens the teacher home.
  ///
  /// In en, this message translates to:
  /// **'Get started'**
  String get onboardingTeacherReadyAction;

  /// Shown when setup succeeded but the account's new access has not arrived yet.
  ///
  /// In en, this message translates to:
  /// **'Your account is ready, but we couldn\'t open it just yet. Please try again.'**
  String get onboardingNotReadyYet;

  /// Returns to the role picker from the onboarding screen.
  ///
  /// In en, this message translates to:
  /// **'Choose a different role'**
  String get onboardingChangeRole;

  /// Signs out from the onboarding screen.
  ///
  /// In en, this message translates to:
  /// **'Sign out'**
  String get onboardingSignOut;

  /// Title of the student's AI study helper tab.
  ///
  /// In en, this message translates to:
  /// **'Study helper'**
  String get studyAssistantTitle;

  /// Explains what the helper does and warns that questions leave the app.
  ///
  /// In en, this message translates to:
  /// **'Ask about anything you are studying and get an explanation. Your question is sent to an AI service to answer it, so do not include your name, your school or anything private.'**
  String get studyAssistantIntro;

  /// Label of the question field.
  ///
  /// In en, this message translates to:
  /// **'Your question'**
  String get studyAssistantField;

  /// Sends the question.
  ///
  /// In en, this message translates to:
  /// **'Ask'**
  String get studyAssistantAsk;

  /// Shown on the button while an answer is being fetched.
  ///
  /// In en, this message translates to:
  /// **'Thinking…'**
  String get studyAssistantBusy;

  /// Reminder shown under every answer.
  ///
  /// In en, this message translates to:
  /// **'Answers can be wrong. Check anything you hand in.'**
  String get studyAssistantCheckWork;

  /// Short navigation label for the study helper tab.
  ///
  /// In en, this message translates to:
  /// **'Helper'**
  String get studyAssistantTab;

  /// Shown when redeeming a class link is refused because the account already holds a non-student role at that school - typically a teacher opening their own link.
  ///
  /// In en, this message translates to:
  /// **'You already teach at this school, so you cannot join one of its classes as a student. Ask a student to open the link on their own account.'**
  String get joinClassAlreadyStaff;

  /// Chip that clears the class filter so every class is shown.
  ///
  /// In en, this message translates to:
  /// **'All classes'**
  String get academicAllClasses;

  /// Family+ insights: insightsTitle.
  ///
  /// In en, this message translates to:
  /// **'Family+'**
  String get insightsTitle;

  /// Family+ insights: insightsUnavailableTitle.
  ///
  /// In en, this message translates to:
  /// **'Insights are not available'**
  String get insightsUnavailableTitle;

  /// Family+ insights: insightsUnavailableBody.
  ///
  /// In en, this message translates to:
  /// **'Family+ is needed to see detailed insights, and the link to your child must be approved.'**
  String get insightsUnavailableBody;

  /// Family+ insights: insightsNothingYetTitle.
  ///
  /// In en, this message translates to:
  /// **'Nothing to report yet'**
  String get insightsNothingYetTitle;

  /// Family+ insights: insightsNothingYetBody.
  ///
  /// In en, this message translates to:
  /// **'As your child\'s school records marks, attendance and work, insights will appear here. We only report what the records actually show.'**
  String get insightsNothingYetBody;

  /// Family+ insights: insightsBySubject.
  ///
  /// In en, this message translates to:
  /// **'By subject'**
  String get insightsBySubject;

  /// Family+ insights: insightsComingUp.
  ///
  /// In en, this message translates to:
  /// **'Coming up'**
  String get insightsComingUp;

  /// Family+ insights: insightsFromSchool.
  ///
  /// In en, this message translates to:
  /// **'From the school'**
  String get insightsFromSchool;

  /// Family+ insights: insightsAverage.
  ///
  /// In en, this message translates to:
  /// **'Average'**
  String get insightsAverage;

  /// Family+ insights: insightsAttendance.
  ///
  /// In en, this message translates to:
  /// **'Attendance'**
  String get insightsAttendance;

  /// Family+ insights: insightsOnTime.
  ///
  /// In en, this message translates to:
  /// **'On time'**
  String get insightsOnTime;

  /// Family+ insights: insightSubjectFocus.
  ///
  /// In en, this message translates to:
  /// **'{subject} is their weakest subject right now'**
  String insightSubjectFocus(Object subject);

  /// Family+ insights: insightTrendDown.
  ///
  /// In en, this message translates to:
  /// **'{subject} marks are going down'**
  String insightTrendDown(Object subject);

  /// Family+ insights: insightTrendUp.
  ///
  /// In en, this message translates to:
  /// **'{subject} marks are going up'**
  String insightTrendUp(Object subject);

  /// Family+ insights: insightRecovery.
  ///
  /// In en, this message translates to:
  /// **'{subject} has recovered'**
  String insightRecovery(Object subject);

  /// Family+ insights: insightHomework.
  ///
  /// In en, this message translates to:
  /// **'How reliably work is handed in'**
  String get insightHomework;

  /// Family+ insights: insightHomeworkSlipping.
  ///
  /// In en, this message translates to:
  /// **'Work is being handed in later than before'**
  String get insightHomeworkSlipping;

  /// Family+ insights: insightAttendancePattern.
  ///
  /// In en, this message translates to:
  /// **'Absences fall on the same day of the week'**
  String get insightAttendancePattern;

  /// Family+ insights: insightDueSoon.
  ///
  /// In en, this message translates to:
  /// **'Work due soon that has not been handed in'**
  String get insightDueSoon;

  /// Family+ insights: insightStrengthInsufficient.
  ///
  /// In en, this message translates to:
  /// **'Not enough records yet to be confident'**
  String get insightStrengthInsufficient;

  /// Family+ insights: insightStrengthLow.
  ///
  /// In en, this message translates to:
  /// **'Based on a small number of records'**
  String get insightStrengthLow;

  /// Family+ insights: insightStrengthMedium.
  ///
  /// In en, this message translates to:
  /// **'Based on a reasonable number of records'**
  String get insightStrengthMedium;

  /// Family+ insights: insightStrengthHigh.
  ///
  /// In en, this message translates to:
  /// **'Based on a large number of records'**
  String get insightStrengthHigh;

  /// No description provided for @insightMissingWork.
  ///
  /// In en, this message translates to:
  /// **'Work missed its deadline and was never handed in'**
  String get insightMissingWork;

  /// No description provided for @insightMissingWorkIn.
  ///
  /// In en, this message translates to:
  /// **'Work in {subject} missed its deadline'**
  String insightMissingWorkIn(String subject);

  /// No description provided for @insightMissedTests.
  ///
  /// In en, this message translates to:
  /// **'Tests were missed'**
  String get insightMissedTests;

  /// No description provided for @insightMissedTestsIn.
  ///
  /// In en, this message translates to:
  /// **'A test in {subject} was missed'**
  String insightMissedTestsIn(String subject);

  /// No description provided for @insightAttendanceLow.
  ///
  /// In en, this message translates to:
  /// **'Attendance is below 90%'**
  String get insightAttendanceLow;

  /// No description provided for @insightStrength.
  ///
  /// In en, this message translates to:
  /// **'{subject} is their strongest subject right now'**
  String insightStrength(String subject);

  /// No description provided for @insightEvClassAverage.
  ///
  /// In en, this message translates to:
  /// **'{subject} average'**
  String insightEvClassAverage(String subject);

  /// No description provided for @insightEvOverallAverage.
  ///
  /// In en, this message translates to:
  /// **'Their average across all subjects'**
  String get insightEvOverallAverage;

  /// No description provided for @insightEvRecentTypical.
  ///
  /// In en, this message translates to:
  /// **'Typical recent mark'**
  String get insightEvRecentTypical;

  /// No description provided for @insightEvEarlierTypical.
  ///
  /// In en, this message translates to:
  /// **'Typical earlier mark'**
  String get insightEvEarlierTypical;

  /// No description provided for @insightEvChange.
  ///
  /// In en, this message translates to:
  /// **'Change (points)'**
  String get insightEvChange;

  /// No description provided for @insightEvOnTime.
  ///
  /// In en, this message translates to:
  /// **'Handed in on time'**
  String get insightEvOnTime;

  /// No description provided for @insightEvLate.
  ///
  /// In en, this message translates to:
  /// **'Handed in late'**
  String get insightEvLate;

  /// No description provided for @insightEvNotHandedIn.
  ///
  /// In en, this message translates to:
  /// **'Not handed in'**
  String get insightEvNotHandedIn;

  /// No description provided for @insightEvWeekdayAbsences.
  ///
  /// In en, this message translates to:
  /// **'Absences on a {day}'**
  String insightEvWeekdayAbsences(String day);

  /// No description provided for @insightEvAbsencesTotal.
  ///
  /// In en, this message translates to:
  /// **'Absences in total'**
  String get insightEvAbsencesTotal;

  /// No description provided for @insightEvDueSoon.
  ///
  /// In en, this message translates to:
  /// **'Due in the next 7 days, not handed in'**
  String get insightEvDueSoon;

  /// No description provided for @insightEvMissed.
  ///
  /// In en, this message translates to:
  /// **'Tests missed'**
  String get insightEvMissed;

  /// No description provided for @insightEvAttendanceRate.
  ///
  /// In en, this message translates to:
  /// **'Attended'**
  String get insightEvAttendanceRate;

  /// No description provided for @insightEvSessions.
  ///
  /// In en, this message translates to:
  /// **'Lessons counted'**
  String get insightEvSessions;

  /// No description provided for @insightEvPastDue.
  ///
  /// In en, this message translates to:
  /// **'Past the deadline, not handed in'**
  String get insightEvPastDue;

  /// No description provided for @insightsFocusTitle.
  ///
  /// In en, this message translates to:
  /// **'What to focus on'**
  String get insightsFocusTitle;

  /// No description provided for @insightsProgressTitle.
  ///
  /// In en, this message translates to:
  /// **'Marks over time'**
  String get insightsProgressTitle;

  /// No description provided for @insightsByClass.
  ///
  /// In en, this message translates to:
  /// **'Class by class'**
  String get insightsByClass;

  /// No description provided for @insightsMissingTitle.
  ///
  /// In en, this message translates to:
  /// **'Missing work'**
  String get insightsMissingTitle;

  /// No description provided for @insightsRecentTitle.
  ///
  /// In en, this message translates to:
  /// **'Latest marks'**
  String get insightsRecentTitle;

  /// No description provided for @insightsMissedTests.
  ///
  /// In en, this message translates to:
  /// **'Missed tests'**
  String get insightsMissedTests;

  /// No description provided for @insightsTrendUp.
  ///
  /// In en, this message translates to:
  /// **'Up {points} points compared with earlier'**
  String insightsTrendUp(int points);

  /// No description provided for @insightsTrendDown.
  ///
  /// In en, this message translates to:
  /// **'Down {points} points compared with earlier'**
  String insightsTrendDown(int points);

  /// No description provided for @insightsTrendSteady.
  ///
  /// In en, this message translates to:
  /// **'Steady compared with earlier'**
  String get insightsTrendSteady;

  /// No description provided for @insightsTrendUnknown.
  ///
  /// In en, this message translates to:
  /// **'Not enough marks for a trend yet'**
  String get insightsTrendUnknown;

  /// No description provided for @insightsStrongest.
  ///
  /// In en, this message translates to:
  /// **'Strongest'**
  String get insightsStrongest;

  /// No description provided for @insightsWeakest.
  ///
  /// In en, this message translates to:
  /// **'Weakest'**
  String get insightsWeakest;

  /// No description provided for @insightsClassAttendance.
  ///
  /// In en, this message translates to:
  /// **'Attendance {rate}%'**
  String insightsClassAttendance(int rate);

  /// No description provided for @insightsClassOnTime.
  ///
  /// In en, this message translates to:
  /// **'On time {rate}%'**
  String insightsClassOnTime(int rate);

  /// No description provided for @insightsMissingCount.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =0{Nothing missing} =1{1 missing} other{{count} missing}}'**
  String insightsMissingCount(int count);

  /// No description provided for @insightsMissedCount.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 missed test} other{{count} missed tests}}'**
  String insightsMissedCount(int count);

  /// No description provided for @insightsMissed.
  ///
  /// In en, this message translates to:
  /// **'Missed'**
  String get insightsMissed;

  /// No description provided for @insightsPaper.
  ///
  /// In en, this message translates to:
  /// **'Paper'**
  String get insightsPaper;

  /// Family+ insights: insightsDueOn.
  ///
  /// In en, this message translates to:
  /// **'Due {date}'**
  String insightsDueOn(String date);

  /// Family+ insights: insightsFromMarks.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =0{No marks yet} =1{From 1 mark} other{From {count} marks}}'**
  String insightsFromMarks(int count);

  /// Family+ insights: insightsAbsences.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =0{No absences} =1{1 absence} other{{count} absences}}'**
  String insightsAbsences(int count);

  /// Family+ insights: insightsOfTasks.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =0{No work set} =1{Of 1 task} other{Of {count} tasks}}'**
  String insightsOfTasks(int count);

  /// Family+ with no child selected.
  ///
  /// In en, this message translates to:
  /// **'Choose a child first'**
  String get insightsNoChildTitle;

  /// Tells a parent how to select a child for Family+.
  ///
  /// In en, this message translates to:
  /// **'Pick one of your children on the home tab to see their insights.'**
  String get insightsNoChildBody;

  /// Title of the screen listing every attempt a student made at one assignment.
  ///
  /// In en, this message translates to:
  /// **'Hand-in history'**
  String get historyTitle;

  /// Heading above earlier hand-ins on the hand-in screen.
  ///
  /// In en, this message translates to:
  /// **'Hand-in history'**
  String get historyYours;

  /// Chip on the attempt that is being marked.
  ///
  /// In en, this message translates to:
  /// **'Latest'**
  String get historyLatest;

  /// Chip on an attempt that has been replaced by a later one.
  ///
  /// In en, this message translates to:
  /// **'Earlier'**
  String get historyEarlier;

  /// Which parent handed this attempt in for the child.
  ///
  /// In en, this message translates to:
  /// **'Handed in by {name}'**
  String historyByGuardian(String name);

  /// Shown when a parent handed it in but their name is unknown.
  ///
  /// In en, this message translates to:
  /// **'Handed in by a parent'**
  String get historyByParent;

  /// Empty history.
  ///
  /// In en, this message translates to:
  /// **'Nothing handed in yet.'**
  String get historyNone;

  /// History failed to load.
  ///
  /// In en, this message translates to:
  /// **'The history could not be loaded. Please try again.'**
  String get historyLoadFailed;

  /// An attempt with no text.
  ///
  /// In en, this message translates to:
  /// **'No written answer.'**
  String get historyNoText;

  /// Button on a draft assignment that makes it visible to the class.
  ///
  /// In en, this message translates to:
  /// **'Publish'**
  String get academicPublish;

  /// Shown after publishing.
  ///
  /// In en, this message translates to:
  /// **'Published. The class can see it now.'**
  String get academicPublished;

  /// Shown when publishing fails.
  ///
  /// In en, this message translates to:
  /// **'That could not be published. Please try again.'**
  String get academicPublishFailed;

  /// Label on a graded assignment: what it is marked out of.
  ///
  /// In en, this message translates to:
  /// **'Graded · out of {score}'**
  String academicGradedOutOf(String score);

  /// Button in the class invite that replaces the class code.
  ///
  /// In en, this message translates to:
  /// **'New code'**
  String get classesNewCode;

  /// Title of the confirmation before replacing a class code.
  ///
  /// In en, this message translates to:
  /// **'Make a new code?'**
  String get classesNewCodeTitle;

  /// Explains what replacing the class code does.
  ///
  /// In en, this message translates to:
  /// **'The current code and link will stop working. Anyone who has not joined yet will need the new one.'**
  String get classesNewCodeBody;

  /// Confirms replacing the class code.
  ///
  /// In en, this message translates to:
  /// **'Make new code'**
  String get classesNewCodeConfirm;

  /// Button: go to the class's previous lesson day in the register.
  ///
  /// In en, this message translates to:
  /// **'Previous lesson'**
  String get attendancePreviousLesson;

  /// Button: go to the class's next lesson day in the register.
  ///
  /// In en, this message translates to:
  /// **'Next lesson'**
  String get attendanceNextLesson;

  /// Button on a graded assignment's hand-ins: open the gradebook to mark it.
  ///
  /// In en, this message translates to:
  /// **'Grade'**
  String get submissionsGrade;

  /// No description provided for @attachmentThatFileCouldNotBe.
  ///
  /// In en, this message translates to:
  /// **'That file could not be uploaded.'**
  String get attachmentThatFileCouldNotBe;

  /// No description provided for @attachmentThatFileIsEmpty.
  ///
  /// In en, this message translates to:
  /// **'That file is empty.'**
  String get attachmentThatFileIsEmpty;

  /// No description provided for @attachmentOnlyPdfAndPhotosCan.
  ///
  /// In en, this message translates to:
  /// **'Only PDF and photos can be attached.'**
  String get attachmentOnlyPdfAndPhotosCan;

  /// No description provided for @attachmentThatFileIsLargerThan.
  ///
  /// In en, this message translates to:
  /// **'That file is larger than {maximumSizeBytes} MB.'**
  String attachmentThatFileIsLargerThan(Object maximumSizeBytes);

  /// No description provided for @attachmentAttachFile.
  ///
  /// In en, this message translates to:
  /// **'Attach file'**
  String get attachmentAttachFile;

  /// No description provided for @attachmentPhoto.
  ///
  /// In en, this message translates to:
  /// **'Photo'**
  String get attachmentPhoto;

  /// No description provided for @attachmentUpToMaximumcountAttachments.
  ///
  /// In en, this message translates to:
  /// **'Up to {maximumCount} attachments.'**
  String attachmentUpToMaximumcountAttachments(Object maximumCount);

  /// No description provided for @attachmentUploading.
  ///
  /// In en, this message translates to:
  /// **'Uploading'**
  String get attachmentUploading;

  /// No description provided for @attachmentChecking.
  ///
  /// In en, this message translates to:
  /// **'Checking'**
  String get attachmentChecking;

  /// No description provided for @attachmentRefusedDamaged.
  ///
  /// In en, this message translates to:
  /// **'This file can\'t be used: it looks damaged or unusual. Remove it, or save it again as a PDF and attach that.'**
  String get attachmentRefusedDamaged;

  /// No description provided for @attachmentRefusedUnsafe.
  ///
  /// In en, this message translates to:
  /// **'This file was blocked because it may be harmful. Remove it.'**
  String get attachmentRefusedUnsafe;

  /// No description provided for @attachmentRefusedNotAllowed.
  ///
  /// In en, this message translates to:
  /// **'This file has a password, scripts or other files inside it, which aren\'t allowed. Remove it.'**
  String get attachmentRefusedNotAllowed;

  /// No description provided for @attachmentRefusedOther.
  ///
  /// In en, this message translates to:
  /// **'This file can\'t be used. Remove it and try another.'**
  String get attachmentRefusedOther;

  /// Under a file the server refused on save because its security scan refused it.
  ///
  /// In en, this message translates to:
  /// **'This file did not pass the safety check. Remove it, then save again.'**
  String get attachmentNotAcceptedScan;

  /// No description provided for @attachmentNotAcceptedGone.
  ///
  /// In en, this message translates to:
  /// **'This file is no longer available. Remove it and attach it again.'**
  String get attachmentNotAcceptedGone;

  /// Shown in place of an attached file that the security scan refused after it was attached; it cannot be opened.
  ///
  /// In en, this message translates to:
  /// **'This file was removed by the safety check.'**
  String get attachmentRemovedBySafetyCheck;

  /// Short label under an attached file name, or on a photo, that the security scan removed.
  ///
  /// In en, this message translates to:
  /// **'Removed by the safety check'**
  String get attachmentRemovedShort;

  /// No description provided for @attachmentNotAcceptedInUse.
  ///
  /// In en, this message translates to:
  /// **'This file is already attached. Remove it, then save again.'**
  String get attachmentNotAcceptedInUse;

  /// No description provided for @attachmentNotAcceptedHere.
  ///
  /// In en, this message translates to:
  /// **'This file can\'t be added here. Remove it, then save again.'**
  String get attachmentNotAcceptedHere;

  /// No description provided for @linkNotAccepted.
  ///
  /// In en, this message translates to:
  /// **'This link can\'t be added. Remove it, then save again.'**
  String get linkNotAccepted;

  /// No description provided for @attachmentReady.
  ///
  /// In en, this message translates to:
  /// **'Ready'**
  String get attachmentReady;

  /// No description provided for @attachmentFailed.
  ///
  /// In en, this message translates to:
  /// **'Failed'**
  String get attachmentFailed;

  /// No description provided for @attachmentThisFileIsStillBeing.
  ///
  /// In en, this message translates to:
  /// **'This file is still being checked. Try again shortly.'**
  String get attachmentThisFileIsStillBeing;

  /// No description provided for @attachmentThatFileCouldNotBe2.
  ///
  /// In en, this message translates to:
  /// **'That file could not be opened.'**
  String get attachmentThatFileCouldNotBe2;

  /// No description provided for @studentTodayALittleProgressEveryDay.
  ///
  /// In en, this message translates to:
  /// **'A LITTLE PROGRESS, EVERY DAY'**
  String get studentTodayALittleProgressEveryDay;

  /// No description provided for @studentTodayYourClassesYourIdeasYour.
  ///
  /// In en, this message translates to:
  /// **'Your classes, your ideas, your next big thing.'**
  String get studentTodayYourClassesYourIdeasYour;

  /// No description provided for @studentTodayMyNotebook.
  ///
  /// In en, this message translates to:
  /// **'My notebook'**
  String get studentTodayMyNotebook;

  /// No description provided for @studentTodayLessonNotesSubscription.
  ///
  /// In en, this message translates to:
  /// **'Lesson notes · Subscription'**
  String get studentTodayLessonNotesSubscription;

  /// No description provided for @studentTodayMyWork.
  ///
  /// In en, this message translates to:
  /// **'My work'**
  String get studentTodayMyWork;

  /// No description provided for @studentTodayTakeTheNextStep.
  ///
  /// In en, this message translates to:
  /// **'Take the next step'**
  String get studentTodayTakeTheNextStep;

  /// No description provided for @studentTodayMyIdFamily.
  ///
  /// In en, this message translates to:
  /// **'My ID & family'**
  String get studentTodayMyIdFamily;

  /// No description provided for @studentTodayShareYourIdReviewParent.
  ///
  /// In en, this message translates to:
  /// **'Share your ID. Review parent requests.'**
  String get studentTodayShareYourIdReviewParent;

  /// No description provided for @studentTodayYourClasses.
  ///
  /// In en, this message translates to:
  /// **'Your classes'**
  String get studentTodayYourClasses;

  /// No description provided for @studentTodayReadyWhenYouAre.
  ///
  /// In en, this message translates to:
  /// **'Ready when you are'**
  String get studentTodayReadyWhenYouAre;

  /// No description provided for @studentTodayYourWorkCouldNotLoad.
  ///
  /// In en, this message translates to:
  /// **'Your work could not load. Open My work to retry.'**
  String get studentTodayYourWorkCouldNotLoad;

  /// No description provided for @studentTodayALittleBreathingRoom.
  ///
  /// In en, this message translates to:
  /// **'A little breathing room'**
  String get studentTodayALittleBreathingRoom;

  /// No description provided for @studentTodayNewAssignmentsWillAppearHere.
  ///
  /// In en, this message translates to:
  /// **'New assignments will appear here when your teacher shares them.'**
  String get studentTodayNewAssignmentsWillAppearHere;

  /// No description provided for @teacherShellManageRosterStaffAndMeetings.
  ///
  /// In en, this message translates to:
  /// **'Manage roster, staff and meetings'**
  String get teacherShellManageRosterStaffAndMeetings;

  /// No description provided for @teacherShellClasses.
  ///
  /// In en, this message translates to:
  /// **'Classes'**
  String get teacherShellClasses;

  /// No description provided for @teacherShellMessages.
  ///
  /// In en, this message translates to:
  /// **'Messages'**
  String get teacherShellMessages;

  /// No description provided for @schoolAdminGuardians.
  ///
  /// In en, this message translates to:
  /// **'Guardians'**
  String get schoolAdminGuardians;

  /// No description provided for @teacherTodaySpaceToInspireADay.
  ///
  /// In en, this message translates to:
  /// **'Space to inspire. A day to make a difference.'**
  String get teacherTodaySpaceToInspireADay;

  /// No description provided for @studentLessonsPlans.
  ///
  /// In en, this message translates to:
  /// **'Plans'**
  String get studentLessonsPlans;

  /// No description provided for @studentLessonsYourClassesCouldNotBe.
  ///
  /// In en, this message translates to:
  /// **'Your classes could not be loaded. Try again'**
  String get studentLessonsYourClassesCouldNotBe;

  /// No description provided for @studentLessonsJoinAClassToSee.
  ///
  /// In en, this message translates to:
  /// **'Join a class to see its lessons here.'**
  String get studentLessonsJoinAClassToSee;

  /// No description provided for @studentLessonsLessonsAndYourNotebook.
  ///
  /// In en, this message translates to:
  /// **'Lessons and your notebook'**
  String get studentLessonsLessonsAndYourNotebook;

  /// No description provided for @studentLessonsMyNotebook.
  ///
  /// In en, this message translates to:
  /// **'My notebook'**
  String get studentLessonsMyNotebook;

  /// No description provided for @studySetQuizzesAndFlashcardsComeWith.
  ///
  /// In en, this message translates to:
  /// **'Quizzes and flashcards come with Studafy Max.'**
  String get studySetQuizzesAndFlashcardsComeWith;

  /// No description provided for @studySetThisMonthSAiAllowance.
  ///
  /// In en, this message translates to:
  /// **'You\'ve reached your AI usage limit. It resets on your plan\'s reset date.'**
  String get studySetThisMonthSAiAllowance;

  /// No description provided for @studySetThisLessonHasNoText.
  ///
  /// In en, this message translates to:
  /// **'This lesson has no text to study from.'**
  String get studySetThisLessonHasNoText;

  /// No description provided for @studySetThisIsNotAvailableYet.
  ///
  /// In en, this message translates to:
  /// **'This is not available yet.'**
  String get studySetThisIsNotAvailableYet;

  /// No description provided for @studySetThatDidNotWorkPlease.
  ///
  /// In en, this message translates to:
  /// **'That did not work. Please try again.'**
  String get studySetThatDidNotWorkPlease;

  /// No description provided for @studySetYouScoredScoreOfQuestionscount.
  ///
  /// In en, this message translates to:
  /// **'You scored {score} of {questionsCount}'**
  String studySetYouScoredScoreOfQuestionscount(
    Object score,
    Object questionsCount,
  );

  /// No description provided for @studySetAnswerscountOfQuestionscountAnswered.
  ///
  /// In en, this message translates to:
  /// **'{answersCount} of {questionsCount} answered'**
  String studySetAnswerscountOfQuestionscountAnswered(
    Object answersCount,
    Object questionsCount,
  );

  /// No description provided for @studySetTryAgain.
  ///
  /// In en, this message translates to:
  /// **'Try again'**
  String get studySetTryAgain;

  /// No description provided for @studySetCardPageOfCardscountTap.
  ///
  /// In en, this message translates to:
  /// **'Card {page} of {cardsCount} - tap to turn over'**
  String studySetCardPageOfCardscountTap(Object page, Object cardsCount);

  /// No description provided for @studyPlansRenewsRenews.
  ///
  /// In en, this message translates to:
  /// **'Renews {renews}'**
  String studyPlansRenewsRenews(Object renews);

  /// No description provided for @studyPlansTheStoreCouldNotBe.
  ///
  /// In en, this message translates to:
  /// **'The store could not be reached. Try again later.'**
  String get studyPlansTheStoreCouldNotBe;

  /// No description provided for @studyPlansPaymentsNotSetUp.
  ///
  /// In en, this message translates to:
  /// **'Paid plans are not on sale yet. Everything free keeps working.'**
  String get studyPlansPaymentsNotSetUp;

  /// No description provided for @studyPlansCannotBuyYet.
  ///
  /// In en, this message translates to:
  /// **'This plan cannot be bought yet - see the note under it.'**
  String get studyPlansCannotBuyYet;

  /// No description provided for @studyPlansBuyingIsNotEnabledFor.
  ///
  /// In en, this message translates to:
  /// **'Buying is not enabled for your account yet.'**
  String get studyPlansBuyingIsNotEnabledFor;

  /// No description provided for @studyPlansWeAskedYourParentTo.
  ///
  /// In en, this message translates to:
  /// **'We asked your parent to approve.'**
  String get studyPlansWeAskedYourParentTo;

  /// No description provided for @studyPlansWaitingForAParent.
  ///
  /// In en, this message translates to:
  /// **'Waiting for a parent'**
  String get studyPlansWaitingForAParent;

  /// No description provided for @studyPlansAskAParentToApprove.
  ///
  /// In en, this message translates to:
  /// **'Ask a parent to approve'**
  String get studyPlansAskAParentToApprove;

  /// No description provided for @studyPlansOpeningTheStore.
  ///
  /// In en, this message translates to:
  /// **'Opening the store…'**
  String get studyPlansOpeningTheStore;

  /// No description provided for @studyPlansStartAFreeMonth.
  ///
  /// In en, this message translates to:
  /// **'Start a free month'**
  String get studyPlansStartAFreeMonth;

  /// No description provided for @studyPlansSubscribeToName.
  ///
  /// In en, this message translates to:
  /// **'Subscribe to {name}'**
  String studyPlansSubscribeToName(Object name);

  /// No description provided for @studyPlansFree.
  ///
  /// In en, this message translates to:
  /// **'Free'**
  String get studyPlansFree;

  /// No description provided for @studyPlansPriceMonth.
  ///
  /// In en, this message translates to:
  /// **'{price} / month'**
  String studyPlansPriceMonth(Object price);

  /// No description provided for @studyPlansUspriceMonthInTheUs.
  ///
  /// In en, this message translates to:
  /// **'{usPrice} / month in the US - the store shows your price'**
  String studyPlansUspriceMonthInTheUs(Object usPrice);

  /// No description provided for @studyPlansYourPlan.
  ///
  /// In en, this message translates to:
  /// **'Your plan'**
  String get studyPlansYourPlan;

  /// No description provided for @studyPlansManageOrCancel.
  ///
  /// In en, this message translates to:
  /// **'Manage or cancel'**
  String get studyPlansManageOrCancel;

  /// No description provided for @studyPlansRestoringPurchases.
  ///
  /// In en, this message translates to:
  /// **'Restoring purchases…'**
  String get studyPlansRestoringPurchases;

  /// No description provided for @studyPlansRestorePurchases.
  ///
  /// In en, this message translates to:
  /// **'Restore purchases'**
  String get studyPlansRestorePurchases;

  /// No description provided for @studyPlansAutoRenewingMonthlySubscriptionsPayment.
  ///
  /// In en, this message translates to:
  /// **'Auto-renewing monthly subscriptions. Payment is charged to your Apple or Google account. If a trial applies, billing starts when it ends. Cancel in store settings at least 24 hours before renewal to avoid the next charge. Deleting the app does not cancel a subscription.'**
  String get studyPlansAutoRenewingMonthlySubscriptionsPayment;

  /// No description provided for @studyPlansTermsOfUse.
  ///
  /// In en, this message translates to:
  /// **'Terms of use'**
  String get studyPlansTermsOfUse;

  /// No description provided for @studyPlansPrivacyPolicy.
  ///
  /// In en, this message translates to:
  /// **'Privacy policy'**
  String get studyPlansPrivacyPolicy;

  /// No description provided for @notebookThisNeedsStudafyPlus.
  ///
  /// In en, this message translates to:
  /// **'This needs Studafy Plus.'**
  String get notebookThisNeedsStudafyPlus;

  /// No description provided for @notebookNoWritingCouldBeRead.
  ///
  /// In en, this message translates to:
  /// **'No writing could be read in that photo. Try a clearer one.'**
  String get notebookNoWritingCouldBeRead;

  /// No description provided for @notebookThePhotoIsTakingLonger.
  ///
  /// In en, this message translates to:
  /// **'The photo is taking longer than usual to check. Try again shortly.'**
  String get notebookThePhotoIsTakingLonger;

  /// No description provided for @notebookNewNote.
  ///
  /// In en, this message translates to:
  /// **'New note'**
  String get notebookNewNote;

  /// No description provided for @notebookSave.
  ///
  /// In en, this message translates to:
  /// **'Save'**
  String get notebookSave;

  /// No description provided for @notebookAddATitleAndSome.
  ///
  /// In en, this message translates to:
  /// **'Add a title and some text.'**
  String get notebookAddATitleAndSome;

  /// No description provided for @notebookChooseAJpegOrPng.
  ///
  /// In en, this message translates to:
  /// **'Choose a JPEG or PNG photo under 10 MB.'**
  String get notebookChooseAJpegOrPng;

  /// No description provided for @notebookUploadingThePhoto.
  ///
  /// In en, this message translates to:
  /// **'Uploading the photo…'**
  String get notebookUploadingThePhoto;

  /// No description provided for @notebookReadingTheWhiteboard.
  ///
  /// In en, this message translates to:
  /// **'Reading the whiteboard…'**
  String get notebookReadingTheWhiteboard;

  /// No description provided for @notebookNotesAddedToYourNotebook.
  ///
  /// In en, this message translates to:
  /// **'Notes added to your notebook.'**
  String get notebookNotesAddedToYourNotebook;

  /// No description provided for @notebookThePhotoCouldNotBe.
  ///
  /// In en, this message translates to:
  /// **'The photo could not be uploaded.'**
  String get notebookThePhotoCouldNotBe;

  /// No description provided for @notebookDeleteThisNote.
  ///
  /// In en, this message translates to:
  /// **'Delete this note?'**
  String get notebookDeleteThisNote;

  /// No description provided for @notebookDelete.
  ///
  /// In en, this message translates to:
  /// **'Delete'**
  String get notebookDelete;

  /// No description provided for @notebookToday.
  ///
  /// In en, this message translates to:
  /// **'Today'**
  String get notebookToday;

  /// No description provided for @notebookYesterday.
  ///
  /// In en, this message translates to:
  /// **'Yesterday'**
  String get notebookYesterday;

  /// No description provided for @notebookAddNote.
  ///
  /// In en, this message translates to:
  /// **'Add note'**
  String get notebookAddNote;

  /// No description provided for @notebookSnapTheWhiteboard.
  ///
  /// In en, this message translates to:
  /// **'Snap the whiteboard'**
  String get notebookSnapTheWhiteboard;

  /// No description provided for @notebookFromPhotos.
  ///
  /// In en, this message translates to:
  /// **'From photos'**
  String get notebookFromPhotos;

  /// No description provided for @notebookWhiteboardNotesComeWithStudafy.
  ///
  /// In en, this message translates to:
  /// **'Whiteboard notes come with Studafy Plus.'**
  String get notebookWhiteboardNotesComeWithStudafy;

  /// No description provided for @notebookTheNotebookCouldNotBe.
  ///
  /// In en, this message translates to:
  /// **'The notebook could not be loaded. Try again'**
  String get notebookTheNotebookCouldNotBe;

  /// No description provided for @notebookYourNotebookForThisClass.
  ///
  /// In en, this message translates to:
  /// **'Your notebook for this class is empty. Add a note, or snap the whiteboard.'**
  String get notebookYourNotebookForThisClass;

  /// No description provided for @notebookFromTheWhiteboard.
  ///
  /// In en, this message translates to:
  /// **'From the whiteboard'**
  String get notebookFromTheWhiteboard;

  /// No description provided for @familyHomeTogetherEveryDay.
  ///
  /// In en, this message translates to:
  /// **'TOGETHER, EVERY DAY'**
  String get familyHomeTogetherEveryDay;

  /// No description provided for @familyHomeTheirWorldIsGrowingBe.
  ///
  /// In en, this message translates to:
  /// **'Their world is growing. Be part of it.'**
  String get familyHomeTheirWorldIsGrowingBe;

  /// No description provided for @childSwitcherChooseChild.
  ///
  /// In en, this message translates to:
  /// **'Choose child'**
  String get childSwitcherChooseChild;

  /// No description provided for @familyChallengeSecurityCheck.
  ///
  /// In en, this message translates to:
  /// **'Security check'**
  String get familyChallengeSecurityCheck;

  /// No description provided for @familyChallengeTheCheckCouldNotLoad.
  ///
  /// In en, this message translates to:
  /// **'The check could not load. Go back and try again.'**
  String get familyChallengeTheCheckCouldNotLoad;

  /// No description provided for @studentFamilyIsThisYourParent.
  ///
  /// In en, this message translates to:
  /// **'Is this your parent?'**
  String get studentFamilyIsThisYourParent;

  /// No description provided for @studentFamilyConfirmYourChoice.
  ///
  /// In en, this message translates to:
  /// **'Confirm your choice'**
  String get studentFamilyConfirmYourChoice;

  /// No description provided for @studentFamilyOnlyApproveGuardiannameIfYou.
  ///
  /// In en, this message translates to:
  /// **'Only approve {guardianName} if you know this is your parent or guardian. They will be able to see your grades, attendance and shared school updates.'**
  String studentFamilyOnlyApproveGuardiannameIfYou(Object guardianName);

  /// No description provided for @studentFamilyThisPersonWillNotHave.
  ///
  /// In en, this message translates to:
  /// **'This person will not have access through this family link.'**
  String get studentFamilyThisPersonWillNotHave;

  /// No description provided for @studentFamilyConfirm.
  ///
  /// In en, this message translates to:
  /// **'Confirm'**
  String get studentFamilyConfirm;

  /// No description provided for @studentFamilyMyFamily.
  ///
  /// In en, this message translates to:
  /// **'My family'**
  String get studentFamilyMyFamily;

  /// No description provided for @studentFamilyYourConnections.
  ///
  /// In en, this message translates to:
  /// **'YOUR CONNECTIONS'**
  String get studentFamilyYourConnections;

  /// No description provided for @studentFamilyYourFamilyYourChoice.
  ///
  /// In en, this message translates to:
  /// **'Your family.\nYour choice.'**
  String get studentFamilyYourFamilyYourChoice;

  /// No description provided for @studentFamilyShareYourStudafyIdWith.
  ///
  /// In en, this message translates to:
  /// **'Share your Studafy ID with your parent. You decide who can follow your progress.'**
  String get studentFamilyShareYourStudafyIdWith;

  /// No description provided for @studentFamilyCouldNotLoadRequests.
  ///
  /// In en, this message translates to:
  /// **'Could not load requests'**
  String get studentFamilyCouldNotLoadRequests;

  /// No description provided for @studentFamilyMyStudafyId.
  ///
  /// In en, this message translates to:
  /// **'MY STUDAFY ID'**
  String get studentFamilyMyStudafyId;

  /// No description provided for @studentFamilyCopyId.
  ///
  /// In en, this message translates to:
  /// **'Copy ID'**
  String get studentFamilyCopyId;

  /// No description provided for @studentFamilyIdCopied.
  ///
  /// In en, this message translates to:
  /// **'ID copied'**
  String get studentFamilyIdCopied;

  /// No description provided for @studentFamilyJoinAClassToActivate.
  ///
  /// In en, this message translates to:
  /// **'Join a class to activate your student ID.'**
  String get studentFamilyJoinAClassToActivate;

  /// No description provided for @studentFamilyParentRequests.
  ///
  /// In en, this message translates to:
  /// **'Parent requests'**
  String get studentFamilyParentRequests;

  /// No description provided for @studentFamilyAllCaughtUp.
  ///
  /// In en, this message translates to:
  /// **'All caught up'**
  String get studentFamilyAllCaughtUp;

  /// No description provided for @studentFamilyNewParentRequestsWillAppear.
  ///
  /// In en, this message translates to:
  /// **'New parent requests will appear here.'**
  String get studentFamilyNewParentRequestsWillAppear;

  /// No description provided for @studentFamilyAccountId.
  ///
  /// In en, this message translates to:
  /// **'Account ID'**
  String get studentFamilyAccountId;

  /// No description provided for @studentFamilyThisIsMyParent.
  ///
  /// In en, this message translates to:
  /// **'This is my parent'**
  String get studentFamilyThisIsMyParent;

  /// No description provided for @studentFamilyDecline.
  ///
  /// In en, this message translates to:
  /// **'Decline'**
  String get studentFamilyDecline;

  /// No description provided for @studentFamilyConnected.
  ///
  /// In en, this message translates to:
  /// **'Connected'**
  String get studentFamilyConnected;

  /// No description provided for @studentFamilyRemoveAccess.
  ///
  /// In en, this message translates to:
  /// **'Remove access'**
  String get studentFamilyRemoveAccess;

  /// No description provided for @studentFamilyDeclined.
  ///
  /// In en, this message translates to:
  /// **'Declined'**
  String get studentFamilyDeclined;

  /// No description provided for @studentFamilyAccessRemoved.
  ///
  /// In en, this message translates to:
  /// **'Access removed'**
  String get studentFamilyAccessRemoved;

  /// No description provided for @lessonsUndated.
  ///
  /// In en, this message translates to:
  /// **'Undated'**
  String get lessonsUndated;

  /// No description provided for @lessonsLessonsCouldNotBeLoaded.
  ///
  /// In en, this message translates to:
  /// **'Lessons could not be loaded.'**
  String get lessonsLessonsCouldNotBeLoaded;

  /// No description provided for @lessonsNoLessonsYetTheyAppear.
  ///
  /// In en, this message translates to:
  /// **'No lessons yet. They appear here as your teacher shares them.'**
  String get lessonsNoLessonsYetTheyAppear;

  /// No description provided for @meetingsGoogleMeetCouldNotBe.
  ///
  /// In en, this message translates to:
  /// **'Google Meet could not be opened.'**
  String get meetingsGoogleMeetCouldNotBe;

  /// No description provided for @meetingsUpcomingMeetings.
  ///
  /// In en, this message translates to:
  /// **'Upcoming meetings'**
  String get meetingsUpcomingMeetings;

  /// No description provided for @meetingsCancelled.
  ///
  /// In en, this message translates to:
  /// **'Cancelled'**
  String get meetingsCancelled;

  /// No description provided for @meetingsTheLinkWillAppearHere.
  ///
  /// In en, this message translates to:
  /// **'The link will appear here.'**
  String get meetingsTheLinkWillAppearHere;

  /// No description provided for @meetingsJoin.
  ///
  /// In en, this message translates to:
  /// **'Join'**
  String get meetingsJoin;

  /// No description provided for @conversationSent.
  ///
  /// In en, this message translates to:
  /// **'Sent'**
  String get conversationSent;

  /// No description provided for @conversationDelivered.
  ///
  /// In en, this message translates to:
  /// **'Delivered'**
  String get conversationDelivered;

  /// No description provided for @conversationRead.
  ///
  /// In en, this message translates to:
  /// **'Read'**
  String get conversationRead;

  /// No description provided for @notificationsNotificationPreferences.
  ///
  /// In en, this message translates to:
  /// **'Notification preferences'**
  String get notificationsNotificationPreferences;

  /// No description provided for @notificationPrefsAddPreference.
  ///
  /// In en, this message translates to:
  /// **'Add preference'**
  String get notificationPrefsAddPreference;

  /// No description provided for @notificationPrefsChannel.
  ///
  /// In en, this message translates to:
  /// **'Channel'**
  String get notificationPrefsChannel;

  /// No description provided for @notificationPrefsInApp.
  ///
  /// In en, this message translates to:
  /// **'In app'**
  String get notificationPrefsInApp;

  /// No description provided for @notificationPrefsEmail.
  ///
  /// In en, this message translates to:
  /// **'Email'**
  String get notificationPrefsEmail;

  /// No description provided for @notificationPrefsPush.
  ///
  /// In en, this message translates to:
  /// **'Push'**
  String get notificationPrefsPush;

  /// No description provided for @notificationPrefsCategory.
  ///
  /// In en, this message translates to:
  /// **'Category'**
  String get notificationPrefsCategory;

  /// No description provided for @notificationPrefsAcademic.
  ///
  /// In en, this message translates to:
  /// **'Academic'**
  String get notificationPrefsAcademic;

  /// No description provided for @notificationPrefsMessagesAndAnnouncements.
  ///
  /// In en, this message translates to:
  /// **'Messages and announcements'**
  String get notificationPrefsMessagesAndAnnouncements;

  /// No description provided for @notificationPrefsMeetings.
  ///
  /// In en, this message translates to:
  /// **'Meetings'**
  String get notificationPrefsMeetings;

  /// No description provided for @notificationPrefsFamily.
  ///
  /// In en, this message translates to:
  /// **'Family'**
  String get notificationPrefsFamily;

  /// No description provided for @notificationPrefsBilling.
  ///
  /// In en, this message translates to:
  /// **'Billing'**
  String get notificationPrefsBilling;

  /// No description provided for @notificationPrefsAdd.
  ///
  /// In en, this message translates to:
  /// **'Add'**
  String get notificationPrefsAdd;

  /// No description provided for @notificationPrefsPushPreferencesAreSavedBut.
  ///
  /// In en, this message translates to:
  /// **'Push preferences are saved, but push delivery is not available on this device yet.'**
  String get notificationPrefsPushPreferencesAreSavedBut;

  /// No description provided for @notificationPrefsNoPreferencesSavedAddOne.
  ///
  /// In en, this message translates to:
  /// **'No preferences saved. Add one to choose a channel and category.'**
  String get notificationPrefsNoPreferencesSavedAddOne;

  /// No description provided for @classroomAdminStaff.
  ///
  /// In en, this message translates to:
  /// **'Staff'**
  String get classroomAdminStaff;

  /// No description provided for @classroomAdminCreateAndEnrolStudent.
  ///
  /// In en, this message translates to:
  /// **'Create and enrol student'**
  String get classroomAdminCreateAndEnrolStudent;

  /// No description provided for @classroomAdminCreatedStudentAwaitingEnrolment.
  ///
  /// In en, this message translates to:
  /// **'Created student awaiting enrolment'**
  String get classroomAdminCreatedStudentAwaitingEnrolment;

  /// No description provided for @classroomAdminStudentEnrolled.
  ///
  /// In en, this message translates to:
  /// **'Student enrolled.'**
  String get classroomAdminStudentEnrolled;

  /// No description provided for @classroomAdminRetryEnrolment.
  ///
  /// In en, this message translates to:
  /// **'Retry enrolment'**
  String get classroomAdminRetryEnrolment;

  /// No description provided for @classroomAdminEnrolByStudentId.
  ///
  /// In en, this message translates to:
  /// **'Enrol by student ID'**
  String get classroomAdminEnrolByStudentId;

  /// No description provided for @classroomAdminNoEnrolledStudents.
  ///
  /// In en, this message translates to:
  /// **'No enrolled students.'**
  String get classroomAdminNoEnrolledStudents;

  /// No description provided for @classroomAdminTransfer.
  ///
  /// In en, this message translates to:
  /// **'Transfer'**
  String get classroomAdminTransfer;

  /// No description provided for @classroomAdminWithdraw.
  ///
  /// In en, this message translates to:
  /// **'Withdraw'**
  String get classroomAdminWithdraw;

  /// No description provided for @classroomAdminAssignStaff.
  ///
  /// In en, this message translates to:
  /// **'Assign staff'**
  String get classroomAdminAssignStaff;

  /// No description provided for @classroomAdminNoStaffAssignments.
  ///
  /// In en, this message translates to:
  /// **'No staff assignments.'**
  String get classroomAdminNoStaffAssignments;

  /// No description provided for @classroomAdminRemove.
  ///
  /// In en, this message translates to:
  /// **'Remove'**
  String get classroomAdminRemove;

  /// No description provided for @classroomAdminRemoveDisplaynameFromThisClass.
  ///
  /// In en, this message translates to:
  /// **'Remove {displayName} from this class?'**
  String classroomAdminRemoveDisplaynameFromThisClass(Object displayName);

  /// No description provided for @classroomAdminStaffRemoved.
  ///
  /// In en, this message translates to:
  /// **'Staff removed.'**
  String get classroomAdminStaffRemoved;

  /// No description provided for @classroomAdminWholeClass.
  ///
  /// In en, this message translates to:
  /// **'Whole class'**
  String get classroomAdminWholeClass;

  /// No description provided for @classroomAdminScheduleMeeting.
  ///
  /// In en, this message translates to:
  /// **'Schedule meeting'**
  String get classroomAdminScheduleMeeting;

  /// No description provided for @classroomAdminCreateTheMeetingInGoogle.
  ///
  /// In en, this message translates to:
  /// **'Create the meeting in Google Meet, then paste its link here. Everyone invited is told in the app and can join from it.'**
  String get classroomAdminCreateTheMeetingInGoogle;

  /// No description provided for @classroomAdminNoUpcomingMeetings.
  ///
  /// In en, this message translates to:
  /// **'No upcoming meetings.'**
  String get classroomAdminNoUpcomingMeetings;

  /// No description provided for @classroomAdminRecipientcountInvited.
  ///
  /// In en, this message translates to:
  /// **'{recipientCount} invited'**
  String classroomAdminRecipientcountInvited(Object recipientCount);

  /// No description provided for @classroomAdminLinkCopied.
  ///
  /// In en, this message translates to:
  /// **'Link copied.'**
  String get classroomAdminLinkCopied;

  /// No description provided for @classroomAdminCopyLink.
  ///
  /// In en, this message translates to:
  /// **'Copy link'**
  String get classroomAdminCopyLink;

  /// No description provided for @classroomAdminMeetingCancelled.
  ///
  /// In en, this message translates to:
  /// **'Meeting cancelled.'**
  String get classroomAdminMeetingCancelled;

  /// No description provided for @classroomAdminCancelMeeting.
  ///
  /// In en, this message translates to:
  /// **'Cancel meeting'**
  String get classroomAdminCancelMeeting;

  /// No description provided for @classroomAdminCreateStudent.
  ///
  /// In en, this message translates to:
  /// **'Create student'**
  String get classroomAdminCreateStudent;

  /// No description provided for @classroomAdminDisplayName.
  ///
  /// In en, this message translates to:
  /// **'Display name'**
  String get classroomAdminDisplayName;

  /// No description provided for @classroomAdminAccountUuidOptional.
  ///
  /// In en, this message translates to:
  /// **'Account UUID (optional)'**
  String get classroomAdminAccountUuidOptional;

  /// No description provided for @classroomAdminStudentCreatedAndEnrolled.
  ///
  /// In en, this message translates to:
  /// **'Student created and enrolled.'**
  String get classroomAdminStudentCreatedAndEnrolled;

  /// No description provided for @classroomAdminEnrolStudent.
  ///
  /// In en, this message translates to:
  /// **'Enrol student'**
  String get classroomAdminEnrolStudent;

  /// No description provided for @classroomAdminStudentRecordId.
  ///
  /// In en, this message translates to:
  /// **'Student record ID'**
  String get classroomAdminStudentRecordId;

  /// No description provided for @classroomAdminWithdrawDisplaynameFromThisClass.
  ///
  /// In en, this message translates to:
  /// **'Withdraw {displayName} from this class?'**
  String classroomAdminWithdrawDisplaynameFromThisClass(Object displayName);

  /// No description provided for @classroomAdminStudentWithdrawn.
  ///
  /// In en, this message translates to:
  /// **'Student withdrawn.'**
  String get classroomAdminStudentWithdrawn;

  /// No description provided for @classroomAdminTransferDisplayname.
  ///
  /// In en, this message translates to:
  /// **'Transfer {displayName}'**
  String classroomAdminTransferDisplayname(Object displayName);

  /// No description provided for @classroomAdminTargetClass.
  ///
  /// In en, this message translates to:
  /// **'Target class'**
  String get classroomAdminTargetClass;

  /// No description provided for @classroomAdminStudentTransferred.
  ///
  /// In en, this message translates to:
  /// **'Student transferred.'**
  String get classroomAdminStudentTransferred;

  /// No description provided for @classroomAdminTeacherAccountUuid.
  ///
  /// In en, this message translates to:
  /// **'Teacher account UUID'**
  String get classroomAdminTeacherAccountUuid;

  /// No description provided for @classroomAdminRole.
  ///
  /// In en, this message translates to:
  /// **'Role'**
  String get classroomAdminRole;

  /// No description provided for @classroomAdminCoTeacher.
  ///
  /// In en, this message translates to:
  /// **'Co-teacher'**
  String get classroomAdminCoTeacher;

  /// No description provided for @classroomAdminLeadTeacher.
  ///
  /// In en, this message translates to:
  /// **'Lead teacher'**
  String get classroomAdminLeadTeacher;

  /// No description provided for @classroomAdminAssign.
  ///
  /// In en, this message translates to:
  /// **'Assign'**
  String get classroomAdminAssign;

  /// No description provided for @classroomAdminStaffAssigned.
  ///
  /// In en, this message translates to:
  /// **'Staff assigned.'**
  String get classroomAdminStaffAssigned;

  /// No description provided for @classroomAdminStarts.
  ///
  /// In en, this message translates to:
  /// **'Starts'**
  String get classroomAdminStarts;

  /// No description provided for @classroomAdminTime.
  ///
  /// In en, this message translates to:
  /// **'Time'**
  String get classroomAdminTime;

  /// No description provided for @classroomAdminDuration.
  ///
  /// In en, this message translates to:
  /// **'Duration'**
  String get classroomAdminDuration;

  /// No description provided for @classroomAdminMinutes.
  ///
  /// In en, this message translates to:
  /// **'minutes'**
  String get classroomAdminMinutes;

  /// No description provided for @classroomAdminAudience.
  ///
  /// In en, this message translates to:
  /// **'Audience'**
  String get classroomAdminAudience;

  /// No description provided for @classroomAdminCreateItInGoogleMeet.
  ///
  /// In en, this message translates to:
  /// **'Create it in Google Meet'**
  String get classroomAdminCreateItInGoogleMeet;

  /// No description provided for @classroomAdminGoogleMeetLink.
  ///
  /// In en, this message translates to:
  /// **'Google Meet link'**
  String get classroomAdminGoogleMeetLink;

  /// No description provided for @classroomAdminPasteALinkThatStarts.
  ///
  /// In en, this message translates to:
  /// **'Paste a link that starts with https://meet.google.com/'**
  String get classroomAdminPasteALinkThatStarts;

  /// No description provided for @classroomAdminSchedule.
  ///
  /// In en, this message translates to:
  /// **'Schedule'**
  String get classroomAdminSchedule;

  /// No description provided for @classroomAdminMeetingScheduledEveryoneInvitedHas.
  ///
  /// In en, this message translates to:
  /// **'Meeting scheduled. Everyone invited has been told.'**
  String get classroomAdminMeetingScheduledEveryoneInvitedHas;

  /// No description provided for @rolesYourSpaceToGrow.
  ///
  /// In en, this message translates to:
  /// **'YOUR SPACE TO GROW'**
  String get rolesYourSpaceToGrow;

  /// No description provided for @studyPlansFeatureLessons.
  ///
  /// In en, this message translates to:
  /// **'Lessons from every class, by date'**
  String get studyPlansFeatureLessons;

  /// No description provided for @studyPlansFeatureNotebook.
  ///
  /// In en, this message translates to:
  /// **'Your own notebook for each class'**
  String get studyPlansFeatureNotebook;

  /// No description provided for @studyPlansFeatureEverythingInFree.
  ///
  /// In en, this message translates to:
  /// **'Everything in Free'**
  String get studyPlansFeatureEverythingInFree;

  /// No description provided for @studyPlansFeatureWhiteboard.
  ///
  /// In en, this message translates to:
  /// **'Snap the whiteboard - get real notebook notes'**
  String get studyPlansFeatureWhiteboard;

  /// No description provided for @studyPlansFeatureEverythingInPlus.
  ///
  /// In en, this message translates to:
  /// **'Everything in Plus'**
  String get studyPlansFeatureEverythingInPlus;

  /// No description provided for @studyPlansFeatureQuizzes.
  ///
  /// In en, this message translates to:
  /// **'Quizzes made from your lessons'**
  String get studyPlansFeatureQuizzes;

  /// No description provided for @studyPlansFeatureFlashcards.
  ///
  /// In en, this message translates to:
  /// **'Flashcards made from your lessons'**
  String get studyPlansFeatureFlashcards;

  /// No description provided for @studentTodayMakeTodayYours.
  ///
  /// In en, this message translates to:
  /// **'Make today yours.'**
  String get studentTodayMakeTodayYours;

  /// No description provided for @studentTodayMakeTodayYoursName.
  ///
  /// In en, this message translates to:
  /// **'Make today yours, {name}.'**
  String studentTodayMakeTodayYoursName(Object name);

  /// No description provided for @studySetQuiz.
  ///
  /// In en, this message translates to:
  /// **'Quiz'**
  String get studySetQuiz;

  /// No description provided for @studySetFlashcards.
  ///
  /// In en, this message translates to:
  /// **'Flashcards'**
  String get studySetFlashcards;

  /// No description provided for @studentTodayClassesCouldNotLoad.
  ///
  /// In en, this message translates to:
  /// **'Your classes could not load. Pull down to retry.'**
  String get studentTodayClassesCouldNotLoad;

  /// No description provided for @studentTodayNoClassesYet.
  ///
  /// In en, this message translates to:
  /// **'No classes yet'**
  String get studentTodayNoClassesYet;

  /// No description provided for @studentTodayPasteClassLink.
  ///
  /// In en, this message translates to:
  /// **'Paste the class link your teacher shared to join your first class.'**
  String get studentTodayPasteClassLink;

  /// No description provided for @studentTodayGradeSection.
  ///
  /// In en, this message translates to:
  /// **'Grade {grade} · {section}'**
  String studentTodayGradeSection(Object grade, Object section);

  /// No description provided for @msgTitle.
  ///
  /// In en, this message translates to:
  /// **'Messages'**
  String get msgTitle;

  /// No description provided for @msgEmptyTitle.
  ///
  /// In en, this message translates to:
  /// **'No conversations yet'**
  String get msgEmptyTitle;

  /// No description provided for @msgEmptyMessage.
  ///
  /// In en, this message translates to:
  /// **'Start a conversation with your school.'**
  String get msgEmptyMessage;

  /// No description provided for @msgEmptyAwaitingLink.
  ///
  /// In en, this message translates to:
  /// **'Once a child is linked to you, you can message their teachers here.'**
  String get msgEmptyAwaitingLink;

  /// No description provided for @msgNew.
  ///
  /// In en, this message translates to:
  /// **'New message'**
  String get msgNew;

  /// No description provided for @msgNoSchool.
  ///
  /// In en, this message translates to:
  /// **'Choose a school to see messages.'**
  String get msgNoSchool;

  /// No description provided for @msgRetry.
  ///
  /// In en, this message translates to:
  /// **'Try again'**
  String get msgRetry;

  /// No description provided for @msgErrorTitle.
  ///
  /// In en, this message translates to:
  /// **'Messages could not load'**
  String get msgErrorTitle;

  /// No description provided for @msgComposeHint.
  ///
  /// In en, this message translates to:
  /// **'Write a message'**
  String get msgComposeHint;

  /// No description provided for @msgSend.
  ///
  /// In en, this message translates to:
  /// **'Send'**
  String get msgSend;

  /// No description provided for @msgSendFailed.
  ///
  /// In en, this message translates to:
  /// **'Not sent. Tap send to try again.'**
  String get msgSendFailed;

  /// No description provided for @msgLoadOlder.
  ///
  /// In en, this message translates to:
  /// **'Load earlier messages'**
  String get msgLoadOlder;

  /// No description provided for @msgYou.
  ///
  /// In en, this message translates to:
  /// **'You'**
  String get msgYou;

  /// No description provided for @msgUnknownPerson.
  ///
  /// In en, this message translates to:
  /// **'Someone'**
  String get msgUnknownPerson;

  /// No description provided for @msgMenuReportConversation.
  ///
  /// In en, this message translates to:
  /// **'Report conversation'**
  String get msgMenuReportConversation;

  /// No description provided for @msgMenuReportPerson.
  ///
  /// In en, this message translates to:
  /// **'Report {name}'**
  String msgMenuReportPerson(String name);

  /// No description provided for @msgMenuBlockPerson.
  ///
  /// In en, this message translates to:
  /// **'Block {name}'**
  String msgMenuBlockPerson(String name);

  /// No description provided for @msgMenuBlocked.
  ///
  /// In en, this message translates to:
  /// **'Blocked people'**
  String get msgMenuBlocked;

  /// No description provided for @msgMessageReport.
  ///
  /// In en, this message translates to:
  /// **'Report message'**
  String get msgMessageReport;

  /// No description provided for @msgReportTitle.
  ///
  /// In en, this message translates to:
  /// **'Report'**
  String get msgReportTitle;

  /// No description provided for @msgReportIntro.
  ///
  /// In en, this message translates to:
  /// **'Your report goes to your school\'s safeguarding team. The person you report is not told who reported them.'**
  String get msgReportIntro;

  /// No description provided for @msgReportReason.
  ///
  /// In en, this message translates to:
  /// **'What is the problem?'**
  String get msgReportReason;

  /// No description provided for @msgReasonHarassment.
  ///
  /// In en, this message translates to:
  /// **'Bullying or harassment'**
  String get msgReasonHarassment;

  /// No description provided for @msgReasonInappropriate.
  ///
  /// In en, this message translates to:
  /// **'Inappropriate content'**
  String get msgReasonInappropriate;

  /// No description provided for @msgReasonSafety.
  ///
  /// In en, this message translates to:
  /// **'I am worried about someone\'s safety'**
  String get msgReasonSafety;

  /// No description provided for @msgReasonSpam.
  ///
  /// In en, this message translates to:
  /// **'Spam'**
  String get msgReasonSpam;

  /// No description provided for @msgReasonOther.
  ///
  /// In en, this message translates to:
  /// **'Something else'**
  String get msgReasonOther;

  /// No description provided for @msgReportDetails.
  ///
  /// In en, this message translates to:
  /// **'Tell us more (optional)'**
  String get msgReportDetails;

  /// No description provided for @msgReportConsent.
  ///
  /// In en, this message translates to:
  /// **'The school may contact me about this report'**
  String get msgReportConsent;

  /// No description provided for @msgReportAlsoBlock.
  ///
  /// In en, this message translates to:
  /// **'Also block this person'**
  String get msgReportAlsoBlock;

  /// No description provided for @msgReportSubmit.
  ///
  /// In en, this message translates to:
  /// **'Send report'**
  String get msgReportSubmit;

  /// No description provided for @msgReportSent.
  ///
  /// In en, this message translates to:
  /// **'Report sent. Thank you for telling us.'**
  String get msgReportSent;

  /// No description provided for @msgReportUrgent.
  ///
  /// In en, this message translates to:
  /// **'If someone is in immediate danger, contact emergency services or a trusted adult now.'**
  String get msgReportUrgent;

  /// No description provided for @msgBlockTitle.
  ///
  /// In en, this message translates to:
  /// **'Block {name}?'**
  String msgBlockTitle(String name);

  /// No description provided for @msgBlockMessage.
  ///
  /// In en, this message translates to:
  /// **'You will not be able to message each other. Messages already sent stay visible to the school.'**
  String get msgBlockMessage;

  /// No description provided for @msgBlockConfirm.
  ///
  /// In en, this message translates to:
  /// **'Block'**
  String get msgBlockConfirm;

  /// No description provided for @msgBlockDone.
  ///
  /// In en, this message translates to:
  /// **'{name} is blocked.'**
  String msgBlockDone(String name);

  /// No description provided for @msgCancel.
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get msgCancel;

  /// No description provided for @msgBlockedTitle.
  ///
  /// In en, this message translates to:
  /// **'Blocked people'**
  String get msgBlockedTitle;

  /// No description provided for @msgBlockedEmpty.
  ///
  /// In en, this message translates to:
  /// **'You have not blocked anyone.'**
  String get msgBlockedEmpty;

  /// No description provided for @msgUnblock.
  ///
  /// In en, this message translates to:
  /// **'Unblock'**
  String get msgUnblock;

  /// No description provided for @msgUnblockDone.
  ///
  /// In en, this message translates to:
  /// **'Unblocked.'**
  String get msgUnblockDone;

  /// No description provided for @msgBlockedBanner.
  ///
  /// In en, this message translates to:
  /// **'You blocked someone in this conversation. Unblock them to send messages.'**
  String get msgBlockedBanner;

  /// No description provided for @msgNewTitle.
  ///
  /// In en, this message translates to:
  /// **'New message'**
  String get msgNewTitle;

  /// No description provided for @msgNewEmpty.
  ///
  /// In en, this message translates to:
  /// **'No one is available to message.'**
  String get msgNewEmpty;

  /// No description provided for @msgNewSearch.
  ///
  /// In en, this message translates to:
  /// **'Search people'**
  String get msgNewSearch;

  /// No description provided for @msgSubjectHint.
  ///
  /// In en, this message translates to:
  /// **'Subject (optional)'**
  String get msgSubjectHint;

  /// No description provided for @msgStart.
  ///
  /// In en, this message translates to:
  /// **'Start conversation'**
  String get msgStart;

  /// No description provided for @msgRoleStaff.
  ///
  /// In en, this message translates to:
  /// **'School staff'**
  String get msgRoleStaff;

  /// No description provided for @msgRoleStudent.
  ///
  /// In en, this message translates to:
  /// **'Student'**
  String get msgRoleStudent;

  /// No description provided for @msgRoleGuardian.
  ///
  /// In en, this message translates to:
  /// **'Parent or guardian'**
  String get msgRoleGuardian;

  /// No description provided for @msgGuardianOf.
  ///
  /// In en, this message translates to:
  /// **'Guardian of {names}'**
  String msgGuardianOf(String names);

  /// No description provided for @msgErrorMessagingDisabled.
  ///
  /// In en, this message translates to:
  /// **'Your school has not turned on messaging yet.'**
  String get msgErrorMessagingDisabled;

  /// No description provided for @msgErrorContactNotAllowed.
  ///
  /// In en, this message translates to:
  /// **'You cannot message this person.'**
  String get msgErrorContactNotAllowed;

  /// No description provided for @msgErrorForbidden.
  ///
  /// In en, this message translates to:
  /// **'You cannot send messages here. You may have blocked someone, or someone may have blocked you.'**
  String get msgErrorForbidden;

  /// No description provided for @msgErrorNotFound.
  ///
  /// In en, this message translates to:
  /// **'This conversation is no longer available.'**
  String get msgErrorNotFound;

  /// No description provided for @msgErrorInvalidState.
  ///
  /// In en, this message translates to:
  /// **'You already reported this in the last day. The school has it.'**
  String get msgErrorInvalidState;

  /// No description provided for @msgErrorWindowClosed.
  ///
  /// In en, this message translates to:
  /// **'You have sent many reports today. Please contact the school directly.'**
  String get msgErrorWindowClosed;

  /// No description provided for @msgErrorRateLimited.
  ///
  /// In en, this message translates to:
  /// **'Too many attempts. Wait a moment and try again.'**
  String get msgErrorRateLimited;

  /// No description provided for @msgErrorNetwork.
  ///
  /// In en, this message translates to:
  /// **'Studafy could not reach the school. Check your connection.'**
  String get msgErrorNetwork;

  /// No description provided for @msgErrorUnauthorized.
  ///
  /// In en, this message translates to:
  /// **'Please sign in again.'**
  String get msgErrorUnauthorized;

  /// No description provided for @msgErrorValidation.
  ///
  /// In en, this message translates to:
  /// **'Write a message first.'**
  String get msgErrorValidation;

  /// No description provided for @msgErrorUnknown.
  ///
  /// In en, this message translates to:
  /// **'Something went wrong. Please try again.'**
  String get msgErrorUnknown;

  /// Error when the server refused a file attached to a message or announcement; the refused file is marked.
  ///
  /// In en, this message translates to:
  /// **'A file was not accepted, so nothing was sent. Remove the file marked, then try again.'**
  String get msgErrorAttachmentRefused;

  /// No description provided for @famTitle.
  ///
  /// In en, this message translates to:
  /// **'My family'**
  String get famTitle;

  /// No description provided for @famChildren.
  ///
  /// In en, this message translates to:
  /// **'My children'**
  String get famChildren;

  /// No description provided for @famEmptyTitle.
  ///
  /// In en, this message translates to:
  /// **'No children linked yet'**
  String get famEmptyTitle;

  /// No description provided for @famEmptyMessage.
  ///
  /// In en, this message translates to:
  /// **'Ask your child for their Studafy ID. They approve your request before you can follow their progress.'**
  String get famEmptyMessage;

  /// No description provided for @famLink.
  ///
  /// In en, this message translates to:
  /// **'Link a child'**
  String get famLink;

  /// No description provided for @famLinkTitle.
  ///
  /// In en, this message translates to:
  /// **'Link a child'**
  String get famLinkTitle;

  /// No description provided for @famLinkHint.
  ///
  /// In en, this message translates to:
  /// **'Studafy ID'**
  String get famLinkHint;

  /// No description provided for @famLinkFind.
  ///
  /// In en, this message translates to:
  /// **'Find'**
  String get famLinkFind;

  /// No description provided for @famLinkNotFound.
  ///
  /// In en, this message translates to:
  /// **'No student has that Studafy ID. Check it and try again.'**
  String get famLinkNotFound;

  /// No description provided for @famLinkConfirm.
  ///
  /// In en, this message translates to:
  /// **'Request link to {name}'**
  String famLinkConfirm(String name);

  /// No description provided for @famLinkSent.
  ///
  /// In en, this message translates to:
  /// **'Request sent. {name} must approve it before you can see their records.'**
  String famLinkSent(String name);

  /// No description provided for @famStatusPending.
  ///
  /// In en, this message translates to:
  /// **'Waiting for your child'**
  String get famStatusPending;

  /// No description provided for @famStatusVerified.
  ///
  /// In en, this message translates to:
  /// **'Linked'**
  String get famStatusVerified;

  /// No description provided for @famStatusDeclined.
  ///
  /// In en, this message translates to:
  /// **'Request declined'**
  String get famStatusDeclined;

  /// No description provided for @famStatusRevoked.
  ///
  /// In en, this message translates to:
  /// **'No longer linked'**
  String get famStatusRevoked;

  /// No description provided for @famView.
  ///
  /// In en, this message translates to:
  /// **'View progress'**
  String get famView;

  /// No description provided for @famProgressTitle.
  ///
  /// In en, this message translates to:
  /// **'{name}\'s progress'**
  String famProgressTitle(String name);

  /// No description provided for @famProgressAverage.
  ///
  /// In en, this message translates to:
  /// **'Average of published grades'**
  String get famProgressAverage;

  /// No description provided for @famProgressGraded.
  ///
  /// In en, this message translates to:
  /// **'{count} published grades'**
  String famProgressGraded(String count);

  /// No description provided for @famProgressAttendance.
  ///
  /// In en, this message translates to:
  /// **'Attendance'**
  String get famProgressAttendance;

  /// No description provided for @famProgressSessions.
  ///
  /// In en, this message translates to:
  /// **'{count} recorded sessions'**
  String famProgressSessions(String count);

  /// No description provided for @famProgressNone.
  ///
  /// In en, this message translates to:
  /// **'No data yet'**
  String get famProgressNone;

  /// No description provided for @famProgressBreakdown.
  ///
  /// In en, this message translates to:
  /// **'Present {present} · Late {late} · Absent {absent} · Excused {excused}'**
  String famProgressBreakdown(
    String present,
    String late,
    String absent,
    String excused,
  );

  /// No description provided for @famProgressSource.
  ///
  /// In en, this message translates to:
  /// **'Calculated from grades the school has published and attendance it has recorded. Ask the school if something looks wrong.'**
  String get famProgressSource;

  /// No description provided for @famApprovalsTitle.
  ///
  /// In en, this message translates to:
  /// **'Waiting for your approval'**
  String get famApprovalsTitle;

  /// A child asked a parent to approve a student plan. {plan} is the plan's feature key from the server (studafy_plus or studafy_max); any other key falls back to a generic plan name. Keep "Studafy Plus" and "Studafy Max" as product names.
  ///
  /// In en, this message translates to:
  /// **'{name} asked to subscribe to {plan, select, studafy_plus{Studafy Plus} studafy_max{Studafy Max} other{a Studafy plan}}.'**
  String famApprovalsDetail(String name, String plan);

  /// No description provided for @famApprovalsApprove.
  ///
  /// In en, this message translates to:
  /// **'Approve'**
  String get famApprovalsApprove;

  /// No description provided for @famApprovalsDecline.
  ///
  /// In en, this message translates to:
  /// **'Decline'**
  String get famApprovalsDecline;

  /// No description provided for @famApprovalsDone.
  ///
  /// In en, this message translates to:
  /// **'Your decision was sent.'**
  String get famApprovalsDone;

  /// No description provided for @famRetry.
  ///
  /// In en, this message translates to:
  /// **'Try again'**
  String get famRetry;

  /// No description provided for @famCancel.
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get famCancel;

  /// No description provided for @famErrorTitle.
  ///
  /// In en, this message translates to:
  /// **'Your family could not load'**
  String get famErrorTitle;

  /// No description provided for @famErrorReauthRequired.
  ///
  /// In en, this message translates to:
  /// **'For your security, sign out and sign in again, then approve.'**
  String get famErrorReauthRequired;

  /// No description provided for @famErrorForbidden.
  ///
  /// In en, this message translates to:
  /// **'You do not have access to this.'**
  String get famErrorForbidden;

  /// No description provided for @famErrorNotFound.
  ///
  /// In en, this message translates to:
  /// **'This is no longer available.'**
  String get famErrorNotFound;

  /// No description provided for @famErrorInvalidState.
  ///
  /// In en, this message translates to:
  /// **'This request has already been decided.'**
  String get famErrorInvalidState;

  /// No description provided for @famErrorRateLimited.
  ///
  /// In en, this message translates to:
  /// **'Too many attempts. Wait a moment and try again.'**
  String get famErrorRateLimited;

  /// No description provided for @famErrorNetwork.
  ///
  /// In en, this message translates to:
  /// **'Studafy could not reach the school. Check your connection.'**
  String get famErrorNetwork;

  /// No description provided for @famErrorUnauthorized.
  ///
  /// In en, this message translates to:
  /// **'Please sign in again.'**
  String get famErrorUnauthorized;

  /// No description provided for @famErrorValidation.
  ///
  /// In en, this message translates to:
  /// **'Enter the Studafy ID.'**
  String get famErrorValidation;

  /// No description provided for @famErrorUnknown.
  ///
  /// In en, this message translates to:
  /// **'Something went wrong. Please try again.'**
  String get famErrorUnknown;

  /// No description provided for @accountAccountId.
  ///
  /// In en, this message translates to:
  /// **'Account ID'**
  String get accountAccountId;

  /// No description provided for @accountAccountIdDetail.
  ///
  /// In en, this message translates to:
  /// **'Share this with your school to link your account.'**
  String get accountAccountIdDetail;

  /// No description provided for @accountAccountIdCopied.
  ///
  /// In en, this message translates to:
  /// **'Account ID copied'**
  String get accountAccountIdCopied;

  /// No description provided for @accountSwitchRole.
  ///
  /// In en, this message translates to:
  /// **'Switch role'**
  String get accountSwitchRole;

  /// No description provided for @accountSwitchRoleDetail.
  ///
  /// In en, this message translates to:
  /// **'You belong to this school in more than one role.'**
  String get accountSwitchRoleDetail;

  /// No description provided for @accountTitle.
  ///
  /// In en, this message translates to:
  /// **'Account'**
  String get accountTitle;

  /// No description provided for @accountSectionAccount.
  ///
  /// In en, this message translates to:
  /// **'Account'**
  String get accountSectionAccount;

  /// No description provided for @accountSectionPreferences.
  ///
  /// In en, this message translates to:
  /// **'Preferences'**
  String get accountSectionPreferences;

  /// No description provided for @accountSectionPrivacy.
  ///
  /// In en, this message translates to:
  /// **'Privacy and data'**
  String get accountSectionPrivacy;

  /// No description provided for @accountStudafyId.
  ///
  /// In en, this message translates to:
  /// **'Your Studafy ID'**
  String get accountStudafyId;

  /// No description provided for @accountStudafyIdDetail.
  ///
  /// In en, this message translates to:
  /// **'Give this to a parent so they can ask to link.'**
  String get accountStudafyIdDetail;

  /// No description provided for @accountStudafyIdCopy.
  ///
  /// In en, this message translates to:
  /// **'Copy your Studafy ID'**
  String get accountStudafyIdCopy;

  /// No description provided for @accountStudafyIdCopied.
  ///
  /// In en, this message translates to:
  /// **'Studafy ID copied.'**
  String get accountStudafyIdCopied;

  /// No description provided for @accountUnknown.
  ///
  /// In en, this message translates to:
  /// **'Your account'**
  String get accountUnknown;

  /// No description provided for @accountLanguage.
  ///
  /// In en, this message translates to:
  /// **'Language'**
  String get accountLanguage;

  /// No description provided for @accountSecurity.
  ///
  /// In en, this message translates to:
  /// **'Sign-in and security'**
  String get accountSecurity;

  /// No description provided for @accountSecurityDetail.
  ///
  /// In en, this message translates to:
  /// **'Devices, two-step verification, sign out everywhere'**
  String get accountSecurityDetail;

  /// No description provided for @accountSignOut.
  ///
  /// In en, this message translates to:
  /// **'Sign out'**
  String get accountSignOut;

  /// No description provided for @accountDelete.
  ///
  /// In en, this message translates to:
  /// **'Delete account'**
  String get accountDelete;

  /// No description provided for @accountRoleSchoolAdmin.
  ///
  /// In en, this message translates to:
  /// **'School administrator'**
  String get accountRoleSchoolAdmin;

  /// No description provided for @accountRoleTeacher.
  ///
  /// In en, this message translates to:
  /// **'Teacher'**
  String get accountRoleTeacher;

  /// No description provided for @accountRoleParent.
  ///
  /// In en, this message translates to:
  /// **'Parent or guardian'**
  String get accountRoleParent;

  /// No description provided for @accountRoleStudent.
  ///
  /// In en, this message translates to:
  /// **'Student'**
  String get accountRoleStudent;

  /// No description provided for @accountExport.
  ///
  /// In en, this message translates to:
  /// **'Download my data'**
  String get accountExport;

  /// No description provided for @accountExportDetail.
  ///
  /// In en, this message translates to:
  /// **'Get a copy of the information Studafy holds about you.'**
  String get accountExportDetail;

  /// No description provided for @accountExportRequest.
  ///
  /// In en, this message translates to:
  /// **'Request'**
  String get accountExportRequest;

  /// No description provided for @accountExportPending.
  ///
  /// In en, this message translates to:
  /// **'Preparing your copy. This can take a few minutes.'**
  String get accountExportPending;

  /// No description provided for @accountExportCheck.
  ///
  /// In en, this message translates to:
  /// **'Check'**
  String get accountExportCheck;

  /// No description provided for @accountExportReady.
  ///
  /// In en, this message translates to:
  /// **'Your copy is ready for 7 days.'**
  String get accountExportReady;

  /// No description provided for @accountExportDownload.
  ///
  /// In en, this message translates to:
  /// **'Download'**
  String get accountExportDownload;

  /// No description provided for @accountExportRequested.
  ///
  /// In en, this message translates to:
  /// **'Request received. We are preparing your copy.'**
  String get accountExportRequested;

  /// A destructive account action needs a fresh sign-in, which was cancelled or came back as another account.
  ///
  /// In en, this message translates to:
  /// **'Sign in again to confirm it\'s you, then try once more.'**
  String get accountRecentSignInNeeded;

  /// No description provided for @accountExportReauth.
  ///
  /// In en, this message translates to:
  /// **'Sign in again to confirm it\'s you, then try once more.'**
  String get accountExportReauth;

  /// No description provided for @accountExportExpired.
  ///
  /// In en, this message translates to:
  /// **'That copy has expired. Request a new one.'**
  String get accountExportExpired;

  /// No description provided for @accountExportFailed.
  ///
  /// In en, this message translates to:
  /// **'That did not work. Please try again.'**
  String get accountExportFailed;

  /// No description provided for @todayWork.
  ///
  /// In en, this message translates to:
  /// **'Work you have to set'**
  String get todayWork;

  /// No description provided for @todayWorkEmpty.
  ///
  /// In en, this message translates to:
  /// **'Nothing to set right now. Drafts, and work that is open or coming up, appear here.'**
  String get todayWorkEmpty;

  /// No description provided for @todaySections.
  ///
  /// In en, this message translates to:
  /// **'Sections needing content'**
  String get todaySections;

  /// No description provided for @todaySectionsEmpty.
  ///
  /// In en, this message translates to:
  /// **'Every section you have taught has a lesson your class can see.'**
  String get todaySectionsEmpty;

  /// No description provided for @todaySectionsOutstanding.
  ///
  /// In en, this message translates to:
  /// **'No lesson yet'**
  String get todaySectionsOutstanding;

  /// No description provided for @todayTitle.
  ///
  /// In en, this message translates to:
  /// **'Today'**
  String get todayTitle;

  /// No description provided for @todayHello.
  ///
  /// In en, this message translates to:
  /// **'Hello'**
  String get todayHello;

  /// No description provided for @todayHelloName.
  ///
  /// In en, this message translates to:
  /// **'Hello, {name}'**
  String todayHelloName(String name);

  /// No description provided for @todayClasses.
  ///
  /// In en, this message translates to:
  /// **'My classes'**
  String get todayClasses;

  /// No description provided for @todayStudents.
  ///
  /// In en, this message translates to:
  /// **'{count} students'**
  String todayStudents(String count);

  /// No description provided for @todayEmpty.
  ///
  /// In en, this message translates to:
  /// **'No classes yet'**
  String get todayEmpty;

  /// No description provided for @todayEmptyDetail.
  ///
  /// In en, this message translates to:
  /// **'Create your first class from the Classes tab.'**
  String get todayEmptyDetail;

  /// No description provided for @todayError.
  ///
  /// In en, this message translates to:
  /// **'Classes could not load'**
  String get todayError;

  /// No description provided for @todayErrorDetail.
  ///
  /// In en, this message translates to:
  /// **'Check your connection and try again.'**
  String get todayErrorDetail;

  /// No description provided for @todayRetry.
  ///
  /// In en, this message translates to:
  /// **'Try again'**
  String get todayRetry;

  /// No description provided for @todayMessages.
  ///
  /// In en, this message translates to:
  /// **'Messages'**
  String get todayMessages;

  /// No description provided for @todayNotifications.
  ///
  /// In en, this message translates to:
  /// **'Notifications'**
  String get todayNotifications;

  /// No description provided for @navToday.
  ///
  /// In en, this message translates to:
  /// **'Today'**
  String get navToday;

  /// No description provided for @navClasses.
  ///
  /// In en, this message translates to:
  /// **'Classes'**
  String get navClasses;

  /// No description provided for @navTeaching.
  ///
  /// In en, this message translates to:
  /// **'Teaching'**
  String get navTeaching;

  /// No description provided for @navGradebook.
  ///
  /// In en, this message translates to:
  /// **'Gradebook'**
  String get navGradebook;

  /// No description provided for @navInbox.
  ///
  /// In en, this message translates to:
  /// **'Inbox'**
  String get navInbox;

  /// No description provided for @navLearning.
  ///
  /// In en, this message translates to:
  /// **'Learning'**
  String get navLearning;

  /// No description provided for @navInsights.
  ///
  /// In en, this message translates to:
  /// **'Insights+'**
  String get navInsights;

  /// No description provided for @navUpdates.
  ///
  /// In en, this message translates to:
  /// **'Updates'**
  String get navUpdates;

  /// No description provided for @navMessages.
  ///
  /// In en, this message translates to:
  /// **'Messages'**
  String get navMessages;

  /// No description provided for @navNotebook.
  ///
  /// In en, this message translates to:
  /// **'Notebook'**
  String get navNotebook;

  /// No description provided for @navWork.
  ///
  /// In en, this message translates to:
  /// **'Work'**
  String get navWork;

  /// No description provided for @navGrades.
  ///
  /// In en, this message translates to:
  /// **'Grades'**
  String get navGrades;

  /// No description provided for @notificationsFeedTitle.
  ///
  /// In en, this message translates to:
  /// **'Notifications'**
  String get notificationsFeedTitle;

  /// No description provided for @notificationsFeedMarkAllRead.
  ///
  /// In en, this message translates to:
  /// **'Mark all read'**
  String get notificationsFeedMarkAllRead;

  /// No description provided for @notificationsFeedErrorTitle.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t load notifications'**
  String get notificationsFeedErrorTitle;

  /// No description provided for @notificationsFeedRetry.
  ///
  /// In en, this message translates to:
  /// **'Try again'**
  String get notificationsFeedRetry;

  /// No description provided for @notificationsFeedOfflineBanner.
  ///
  /// In en, this message translates to:
  /// **'Showing your last saved notifications — reconnect to update.'**
  String get notificationsFeedOfflineBanner;

  /// No description provided for @notificationsFeedEmptyTitle.
  ///
  /// In en, this message translates to:
  /// **'No notifications yet'**
  String get notificationsFeedEmptyTitle;

  /// No description provided for @notificationsFeedEmptyMessage.
  ///
  /// In en, this message translates to:
  /// **'You\'ll see updates here as they happen.'**
  String get notificationsFeedEmptyMessage;

  /// No description provided for @notificationsFeedLoading.
  ///
  /// In en, this message translates to:
  /// **'Loading…'**
  String get notificationsFeedLoading;

  /// No description provided for @notificationsFeedLoadMore.
  ///
  /// In en, this message translates to:
  /// **'Load more'**
  String get notificationsFeedLoadMore;

  /// No description provided for @notificationCopyAcademicAssessmentPublishedTitle.
  ///
  /// In en, this message translates to:
  /// **'Assessment published'**
  String get notificationCopyAcademicAssessmentPublishedTitle;

  /// No description provided for @notificationCopyAcademicAssessmentPublishedDetail.
  ///
  /// In en, this message translates to:
  /// **'A new assessment is ready for one of your classes.'**
  String get notificationCopyAcademicAssessmentPublishedDetail;

  /// No description provided for @notificationCopyAcademicAssignmentPublishedTitle.
  ///
  /// In en, this message translates to:
  /// **'Assignment published'**
  String get notificationCopyAcademicAssignmentPublishedTitle;

  /// No description provided for @notificationCopyAcademicAssignmentPublishedDetail.
  ///
  /// In en, this message translates to:
  /// **'A new assignment is ready for one of your classes.'**
  String get notificationCopyAcademicAssignmentPublishedDetail;

  /// No description provided for @notificationCopyAcademicGradePublishedTitle.
  ///
  /// In en, this message translates to:
  /// **'New grade'**
  String get notificationCopyAcademicGradePublishedTitle;

  /// No description provided for @notificationCopyAcademicGradePublishedDetail.
  ///
  /// In en, this message translates to:
  /// **'A grade was published. Open Grades to view it.'**
  String get notificationCopyAcademicGradePublishedDetail;

  /// No description provided for @notificationCopyAcademicGradesPublishedTitle.
  ///
  /// In en, this message translates to:
  /// **'New marks'**
  String get notificationCopyAcademicGradesPublishedTitle;

  /// No description provided for @notificationCopyAcademicGradesPublishedDetail.
  ///
  /// In en, this message translates to:
  /// **'Your teacher published new marks. Open Grades to view them.'**
  String get notificationCopyAcademicGradesPublishedDetail;

  /// No description provided for @notificationCopyAcademicGradesCorrectedTitle.
  ///
  /// In en, this message translates to:
  /// **'A mark was updated'**
  String get notificationCopyAcademicGradesCorrectedTitle;

  /// No description provided for @notificationCopyAcademicGradesCorrectedDetail.
  ///
  /// In en, this message translates to:
  /// **'Your teacher corrected a published mark. Open Grades to see the new one.'**
  String get notificationCopyAcademicGradesCorrectedDetail;

  /// No description provided for @notificationCopyAcademicResourcePublishedTitle.
  ///
  /// In en, this message translates to:
  /// **'New class material'**
  String get notificationCopyAcademicResourcePublishedTitle;

  /// No description provided for @notificationCopyAcademicResourcePublishedDetail.
  ///
  /// In en, this message translates to:
  /// **'Your teacher shared new material for one of your classes.'**
  String get notificationCopyAcademicResourcePublishedDetail;

  /// No description provided for @notificationCopyAcademicWellbeingSharedTitle.
  ///
  /// In en, this message translates to:
  /// **'Wellbeing note shared'**
  String get notificationCopyAcademicWellbeingSharedTitle;

  /// No description provided for @notificationCopyAcademicWellbeingSharedDetail.
  ///
  /// In en, this message translates to:
  /// **'A wellbeing note was shared with you.'**
  String get notificationCopyAcademicWellbeingSharedDetail;

  /// No description provided for @notificationCopyBillingPurchaseApprovalRequestedTitle.
  ///
  /// In en, this message translates to:
  /// **'Purchase approval needed'**
  String get notificationCopyBillingPurchaseApprovalRequestedTitle;

  /// No description provided for @notificationCopyBillingPurchaseApprovalRequestedDetail.
  ///
  /// In en, this message translates to:
  /// **'Your child asked you to approve a subscription.'**
  String get notificationCopyBillingPurchaseApprovalRequestedDetail;

  /// No description provided for @notificationCopyBillingPurchaseApprovalApprovedTitle.
  ///
  /// In en, this message translates to:
  /// **'Purchase approved'**
  String get notificationCopyBillingPurchaseApprovalApprovedTitle;

  /// No description provided for @notificationCopyBillingPurchaseApprovalApprovedDetail.
  ///
  /// In en, this message translates to:
  /// **'A guardian approved your subscription request.'**
  String get notificationCopyBillingPurchaseApprovalApprovedDetail;

  /// No description provided for @notificationCopyBillingPurchaseApprovalDeclinedTitle.
  ///
  /// In en, this message translates to:
  /// **'Purchase declined'**
  String get notificationCopyBillingPurchaseApprovalDeclinedTitle;

  /// No description provided for @notificationCopyBillingPurchaseApprovalDeclinedDetail.
  ///
  /// In en, this message translates to:
  /// **'A guardian declined your subscription request.'**
  String get notificationCopyBillingPurchaseApprovalDeclinedDetail;

  /// No description provided for @notificationCopyMeetingsScheduledTitle.
  ///
  /// In en, this message translates to:
  /// **'Meeting confirmed'**
  String get notificationCopyMeetingsScheduledTitle;

  /// No description provided for @notificationCopyMeetingsScheduledDetail.
  ///
  /// In en, this message translates to:
  /// **'A meeting was scheduled. Check your calendar for the invitation.'**
  String get notificationCopyMeetingsScheduledDetail;

  /// No description provided for @notificationCopyMeetingsFailedTitle.
  ///
  /// In en, this message translates to:
  /// **'Meeting not scheduled'**
  String get notificationCopyMeetingsFailedTitle;

  /// No description provided for @notificationCopyMeetingsFailedDetail.
  ///
  /// In en, this message translates to:
  /// **'A meeting you requested could not be scheduled. Please try again.'**
  String get notificationCopyMeetingsFailedDetail;

  /// No description provided for @notificationCopyCommunicationsAnnouncementCreatedTitle.
  ///
  /// In en, this message translates to:
  /// **'New announcement'**
  String get notificationCopyCommunicationsAnnouncementCreatedTitle;

  /// No description provided for @notificationCopyCommunicationsAnnouncementCreatedDetail.
  ///
  /// In en, this message translates to:
  /// **'A new announcement was posted.'**
  String get notificationCopyCommunicationsAnnouncementCreatedDetail;

  /// No description provided for @notificationCopyCommunicationsMessageSentTitle.
  ///
  /// In en, this message translates to:
  /// **'New message'**
  String get notificationCopyCommunicationsMessageSentTitle;

  /// No description provided for @notificationCopyCommunicationsMessageSentDetail.
  ///
  /// In en, this message translates to:
  /// **'You received a new message.'**
  String get notificationCopyCommunicationsMessageSentDetail;

  /// No description provided for @notificationCopyFamilyGuardianLinkRequestedTitle.
  ///
  /// In en, this message translates to:
  /// **'Connection request'**
  String get notificationCopyFamilyGuardianLinkRequestedTitle;

  /// No description provided for @notificationCopyFamilyGuardianLinkRequestedDetail.
  ///
  /// In en, this message translates to:
  /// **'Someone requested to connect as a guardian.'**
  String get notificationCopyFamilyGuardianLinkRequestedDetail;

  /// No description provided for @notificationCopyFamilyGuardianLinkRevokedTitle.
  ///
  /// In en, this message translates to:
  /// **'Connection removed'**
  String get notificationCopyFamilyGuardianLinkRevokedTitle;

  /// No description provided for @notificationCopyFamilyGuardianLinkRevokedDetail.
  ///
  /// In en, this message translates to:
  /// **'A family connection was removed.'**
  String get notificationCopyFamilyGuardianLinkRevokedDetail;

  /// No description provided for @notificationCopyFamilyGuardianLinkVerifiedTitle.
  ///
  /// In en, this message translates to:
  /// **'Connection verified'**
  String get notificationCopyFamilyGuardianLinkVerifiedTitle;

  /// No description provided for @notificationCopyFamilyGuardianLinkVerifiedDetail.
  ///
  /// In en, this message translates to:
  /// **'A family connection was verified.'**
  String get notificationCopyFamilyGuardianLinkVerifiedDetail;

  /// No description provided for @notificationCopyInvitationsIssuedTitle.
  ///
  /// In en, this message translates to:
  /// **'Invitation sent'**
  String get notificationCopyInvitationsIssuedTitle;

  /// No description provided for @notificationCopyInvitationsIssuedDetail.
  ///
  /// In en, this message translates to:
  /// **'An invitation was issued.'**
  String get notificationCopyInvitationsIssuedDetail;

  /// No description provided for @notificationCopyMeetingsCancelledTitle.
  ///
  /// In en, this message translates to:
  /// **'Meeting cancelled'**
  String get notificationCopyMeetingsCancelledTitle;

  /// No description provided for @notificationCopyMeetingsCancelledDetail.
  ///
  /// In en, this message translates to:
  /// **'A scheduled meeting was cancelled.'**
  String get notificationCopyMeetingsCancelledDetail;

  /// No description provided for @notificationCopyMeetingsRequestedTitle.
  ///
  /// In en, this message translates to:
  /// **'Meeting requested'**
  String get notificationCopyMeetingsRequestedTitle;

  /// No description provided for @notificationCopyMeetingsRequestedDetail.
  ///
  /// In en, this message translates to:
  /// **'A meeting was requested.'**
  String get notificationCopyMeetingsRequestedDetail;

  /// No description provided for @notificationCopySchoolAdminClassroomStaffAssignedTitle.
  ///
  /// In en, this message translates to:
  /// **'Staff assigned'**
  String get notificationCopySchoolAdminClassroomStaffAssignedTitle;

  /// No description provided for @notificationCopySchoolAdminClassroomStaffAssignedDetail.
  ///
  /// In en, this message translates to:
  /// **'A staff member was assigned to a class.'**
  String get notificationCopySchoolAdminClassroomStaffAssignedDetail;

  /// No description provided for @notificationCopySchoolAdminClassroomStaffRemovedTitle.
  ///
  /// In en, this message translates to:
  /// **'Staff removed'**
  String get notificationCopySchoolAdminClassroomStaffRemovedTitle;

  /// No description provided for @notificationCopySchoolAdminClassroomStaffRemovedDetail.
  ///
  /// In en, this message translates to:
  /// **'A staff member was removed from a class.'**
  String get notificationCopySchoolAdminClassroomStaffRemovedDetail;

  /// No description provided for @notificationCopySchoolAdminMembershipGrantedTitle.
  ///
  /// In en, this message translates to:
  /// **'Access granted'**
  String get notificationCopySchoolAdminMembershipGrantedTitle;

  /// No description provided for @notificationCopySchoolAdminMembershipGrantedDetail.
  ///
  /// In en, this message translates to:
  /// **'School access was granted.'**
  String get notificationCopySchoolAdminMembershipGrantedDetail;

  /// No description provided for @notificationCopySchoolAdminStudentEnrolledTitle.
  ///
  /// In en, this message translates to:
  /// **'Student enrolled'**
  String get notificationCopySchoolAdminStudentEnrolledTitle;

  /// No description provided for @notificationCopySchoolAdminStudentEnrolledDetail.
  ///
  /// In en, this message translates to:
  /// **'A student was enrolled.'**
  String get notificationCopySchoolAdminStudentEnrolledDetail;

  /// No description provided for @notificationCopySchoolAdminStudentTransferredTitle.
  ///
  /// In en, this message translates to:
  /// **'Student transferred'**
  String get notificationCopySchoolAdminStudentTransferredTitle;

  /// No description provided for @notificationCopySchoolAdminStudentTransferredDetail.
  ///
  /// In en, this message translates to:
  /// **'A student was transferred between classes.'**
  String get notificationCopySchoolAdminStudentTransferredDetail;

  /// No description provided for @notificationCopySchoolAdminStudentWithdrawnTitle.
  ///
  /// In en, this message translates to:
  /// **'Student withdrawn'**
  String get notificationCopySchoolAdminStudentWithdrawnTitle;

  /// No description provided for @notificationCopySchoolAdminStudentWithdrawnDetail.
  ///
  /// In en, this message translates to:
  /// **'A student was withdrawn.'**
  String get notificationCopySchoolAdminStudentWithdrawnDetail;

  /// No description provided for @notificationCopySupportAccessApprovedTitle.
  ///
  /// In en, this message translates to:
  /// **'Support access approved'**
  String get notificationCopySupportAccessApprovedTitle;

  /// No description provided for @notificationCopySupportAccessApprovedDetail.
  ///
  /// In en, this message translates to:
  /// **'A support access request was approved.'**
  String get notificationCopySupportAccessApprovedDetail;

  /// No description provided for @notificationCopySupportAccessRequestedTitle.
  ///
  /// In en, this message translates to:
  /// **'Support access requested'**
  String get notificationCopySupportAccessRequestedTitle;

  /// No description provided for @notificationCopySupportAccessRequestedDetail.
  ///
  /// In en, this message translates to:
  /// **'Support access was requested.'**
  String get notificationCopySupportAccessRequestedDetail;

  /// No description provided for @notificationCopySupportAccessRevokedTitle.
  ///
  /// In en, this message translates to:
  /// **'Support access revoked'**
  String get notificationCopySupportAccessRevokedTitle;

  /// No description provided for @notificationCopySupportAccessRevokedDetail.
  ///
  /// In en, this message translates to:
  /// **'Support access was revoked.'**
  String get notificationCopySupportAccessRevokedDetail;

  /// No description provided for @notificationCopySupportAccessStartedTitle.
  ///
  /// In en, this message translates to:
  /// **'Support session started'**
  String get notificationCopySupportAccessStartedTitle;

  /// No description provided for @notificationCopySupportAccessStartedDetail.
  ///
  /// In en, this message translates to:
  /// **'A support session has started.'**
  String get notificationCopySupportAccessStartedDetail;

  /// No description provided for @notificationCopyGenericTitle.
  ///
  /// In en, this message translates to:
  /// **'Notification'**
  String get notificationCopyGenericTitle;

  /// No description provided for @notificationCopyGenericDetail.
  ///
  /// In en, this message translates to:
  /// **'You have a new update.'**
  String get notificationCopyGenericDetail;

  /// No description provided for @familyPlusHeadline.
  ///
  /// In en, this message translates to:
  /// **'Family+ for {name}'**
  String familyPlusHeadline(String name);

  /// No description provided for @familyPlusIntro.
  ///
  /// In en, this message translates to:
  /// **'One subscription for the family. See how each child is really doing, where they need help, and what to do about it this week.'**
  String get familyPlusIntro;

  /// No description provided for @familyPlusFeatureTrends.
  ///
  /// In en, this message translates to:
  /// **'What changed this term, with the records behind every claim'**
  String get familyPlusFeatureTrends;

  /// No description provided for @familyPlusFeatureSchool.
  ///
  /// In en, this message translates to:
  /// **'Notes the school chose to share with you'**
  String get familyPlusFeatureSchool;

  /// No description provided for @familyPlusFeatureFocus.
  ///
  /// In en, this message translates to:
  /// **'What to focus on this week, most urgent first'**
  String get familyPlusFeatureFocus;

  /// No description provided for @familyPlusFeatureClasses.
  ///
  /// In en, this message translates to:
  /// **'Every class side by side - average, trend, attendance and homework, with the strongest and weakest named'**
  String get familyPlusFeatureClasses;

  /// No description provided for @familyPlusFeatureChart.
  ///
  /// In en, this message translates to:
  /// **'Marks over time on a chart, and the latest marks - paper exams included'**
  String get familyPlusFeatureChart;

  /// No description provided for @familyPlusFeatureMissing.
  ///
  /// In en, this message translates to:
  /// **'Missing work and missed tests, so nothing slips'**
  String get familyPlusFeatureMissing;

  /// No description provided for @familyPlusPlanName.
  ///
  /// In en, this message translates to:
  /// **'Up to {seats} children'**
  String familyPlusPlanName(int seats);

  /// No description provided for @familyPlusPlanDetail.
  ///
  /// In en, this message translates to:
  /// **'One monthly price for the whole family: all your linked children, up to {seats}.'**
  String familyPlusPlanDetail(int seats);

  /// No description provided for @familyPlusYourPlan.
  ///
  /// In en, this message translates to:
  /// **'Your plan'**
  String get familyPlusYourPlan;

  /// No description provided for @familyPlusSubscribePlan.
  ///
  /// In en, this message translates to:
  /// **'Subscribe for up to {seats} children'**
  String familyPlusSubscribePlan(int seats);

  /// No description provided for @familyPlusUpgrade.
  ///
  /// In en, this message translates to:
  /// **'Upgrade to up to {seats} children'**
  String familyPlusUpgrade(int seats);

  /// No description provided for @familyPlusCannotBuyYet.
  ///
  /// In en, this message translates to:
  /// **'This plan cannot be bought in this version of the app yet.'**
  String get familyPlusCannotBuyYet;

  /// No description provided for @familyPlusNotCoveredTitle.
  ///
  /// In en, this message translates to:
  /// **'Not covered by your plan yet'**
  String get familyPlusNotCoveredTitle;

  /// No description provided for @familyPlusNotCovered.
  ///
  /// In en, this message translates to:
  /// **'Your Family+ covers your first {seats} linked children, and {name} is not one of them. Move to the plan for up to 8 children to include {name}.'**
  String familyPlusNotCovered(int seats, String name);

  /// No description provided for @familyPlusCoversFamily.
  ///
  /// In en, this message translates to:
  /// **'Your children are covered in the order you linked them. A child you link later is included straight away while the plan has room.'**
  String get familyPlusCoversFamily;

  /// No description provided for @familyPlusPrice.
  ///
  /// In en, this message translates to:
  /// **'{price} / month'**
  String familyPlusPrice(String price);

  /// No description provided for @familyPlusUsPrice.
  ///
  /// In en, this message translates to:
  /// **'{price} / month in the US - the store shows your price'**
  String familyPlusUsPrice(String price);

  /// No description provided for @familyPlusTrial.
  ///
  /// In en, this message translates to:
  /// **'If eligible, free for {trial}, then {price} / month'**
  String familyPlusTrial(String trial, String price);

  /// No description provided for @familyPlusStartTrial.
  ///
  /// In en, this message translates to:
  /// **'Start free trial'**
  String get familyPlusStartTrial;

  /// No description provided for @familyPlusCheckingStore.
  ///
  /// In en, this message translates to:
  /// **'Checking the store price...'**
  String get familyPlusCheckingStore;

  /// No description provided for @familyPlusStoreUnavailable.
  ///
  /// In en, this message translates to:
  /// **'The store could not be reached. Try again later.'**
  String get familyPlusStoreUnavailable;

  /// No description provided for @familyPlusNotInThisBuild.
  ///
  /// In en, this message translates to:
  /// **'Family+ cannot be bought in this version of the app.'**
  String get familyPlusNotInThisBuild;

  /// No description provided for @familyPlusOpeningStore.
  ///
  /// In en, this message translates to:
  /// **'Opening the store...'**
  String get familyPlusOpeningStore;

  /// No description provided for @familyPlusRestore.
  ///
  /// In en, this message translates to:
  /// **'Restore purchases'**
  String get familyPlusRestore;

  /// No description provided for @familyPlusRestoring.
  ///
  /// In en, this message translates to:
  /// **'Checking your purchases...'**
  String get familyPlusRestoring;

  /// No description provided for @familyPlusFailed.
  ///
  /// In en, this message translates to:
  /// **'That did not work. Please try again.'**
  String get familyPlusFailed;

  /// No description provided for @familyPlusManage.
  ///
  /// In en, this message translates to:
  /// **'Manage or cancel'**
  String get familyPlusManage;

  /// No description provided for @familyPlusDisclosure.
  ///
  /// In en, this message translates to:
  /// **'Auto-renewing monthly subscription, paid through your app store account. It renews unless cancelled at least 24 hours before the end of the period; cancel any time in your store subscription settings. Studafy never sees your card details.'**
  String get familyPlusDisclosure;

  /// No description provided for @familyPlusTerms.
  ///
  /// In en, this message translates to:
  /// **'Terms of use'**
  String get familyPlusTerms;

  /// No description provided for @familyPlusPrivacy.
  ///
  /// In en, this message translates to:
  /// **'Privacy policy'**
  String get familyPlusPrivacy;

  /// Badge beside locked quiz and flashcard buttons naming the plan that unlocks them. Keep "Studafy Max" as the product name; the Arabic says "the Studafy Max plan".
  ///
  /// In en, this message translates to:
  /// **'Studafy Max'**
  String get studySetMaxBadge;

  /// No description provided for @studySetSwitchedOff.
  ///
  /// In en, this message translates to:
  /// **'Quizzes and flashcards are not switched on yet.'**
  String get studySetSwitchedOff;

  /// No description provided for @studyAssistantOff.
  ///
  /// In en, this message translates to:
  /// **'The study helper is not switched on yet. Your lessons and notebook work as usual.'**
  String get studyAssistantOff;

  /// No description provided for @studyAssistantUnavailable.
  ///
  /// In en, this message translates to:
  /// **'The study helper could not answer just now. Please try again in a moment.'**
  String get studyAssistantUnavailable;

  /// Account screen row that opens the list of accounts on this device.
  ///
  /// In en, this message translates to:
  /// **'Switch account'**
  String get accountsSwitchAccount;

  /// No description provided for @accountsSwitchAccountDetail.
  ///
  /// In en, this message translates to:
  /// **'Accounts on this device, and your children\'s accounts'**
  String get accountsSwitchAccountDetail;

  /// No description provided for @accountsSheetTitle.
  ///
  /// In en, this message translates to:
  /// **'Accounts'**
  String get accountsSheetTitle;

  /// Signs in to another account without signing out of this one.
  ///
  /// In en, this message translates to:
  /// **'Add account'**
  String get accountsAddAccount;

  /// No description provided for @accountsCreateChild.
  ///
  /// In en, this message translates to:
  /// **'Create a child account'**
  String get accountsCreateChild;

  /// No description provided for @accountsCreateChildDetail.
  ///
  /// In en, this message translates to:
  /// **'For a child with no email or phone'**
  String get accountsCreateChildDetail;

  /// Label for a child account that a parent manages.
  ///
  /// In en, this message translates to:
  /// **'Sub-account'**
  String get accountsSubAccount;

  /// Shown on a child account; name is the parent who manages it.
  ///
  /// In en, this message translates to:
  /// **'Sub-account · managed by {name}'**
  String accountsSubAccountOf(String name);

  /// No description provided for @accountsCurrent.
  ///
  /// In en, this message translates to:
  /// **'Current account'**
  String get accountsCurrent;

  /// No description provided for @accountsSwitching.
  ///
  /// In en, this message translates to:
  /// **'Switching account…'**
  String get accountsSwitching;

  /// No description provided for @accountsSwitch.
  ///
  /// In en, this message translates to:
  /// **'Switch'**
  String get accountsSwitch;

  /// No description provided for @accountsSwitchFailed.
  ///
  /// In en, this message translates to:
  /// **'That account could not be opened. Sign in to it again with Add account.'**
  String get accountsSwitchFailed;

  /// No description provided for @accountsNeedsParent.
  ///
  /// In en, this message translates to:
  /// **'This child account opens from the parent\'s account. Sign in to the parent\'s account on this device first.'**
  String get accountsNeedsParent;

  /// No description provided for @childAccountTitle.
  ///
  /// In en, this message translates to:
  /// **'Create a child account'**
  String get childAccountTitle;

  /// No description provided for @childAccountIntro.
  ///
  /// In en, this message translates to:
  /// **'For a young child with no email or phone. You open their account from yours and switch back any time. Their teachers see their work under their own name.'**
  String get childAccountIntro;

  /// No description provided for @childAccountName.
  ///
  /// In en, this message translates to:
  /// **'Child\'s name'**
  String get childAccountName;

  /// No description provided for @childAccountNameHelp.
  ///
  /// In en, this message translates to:
  /// **'As their teachers will see it'**
  String get childAccountNameHelp;

  /// No description provided for @childAccountConsent.
  ///
  /// In en, this message translates to:
  /// **'I am this child\'s parent or legal guardian, and I accept the Terms of Use and Privacy Policy on their behalf.'**
  String get childAccountConsent;

  /// No description provided for @childAccountCreate.
  ///
  /// In en, this message translates to:
  /// **'Create account'**
  String get childAccountCreate;

  ///
  ///
  /// In en, this message translates to:
  /// **'{name}\'s account is ready.'**
  String childAccountCreated(String name);

  /// No description provided for @childAccountNextStep.
  ///
  /// In en, this message translates to:
  /// **'Next, switch to their account and join their class with the link or code from their teacher.'**
  String get childAccountNextStep;

  ///
  ///
  /// In en, this message translates to:
  /// **'Switch to {name}'**
  String childAccountOpenNow(String name);

  /// No description provided for @childAccountLimit.
  ///
  /// In en, this message translates to:
  /// **'You can manage up to six child accounts.'**
  String get childAccountLimit;

  /// No description provided for @childAccountUnavailable.
  ///
  /// In en, this message translates to:
  /// **'Child accounts are not available on this server yet.'**
  String get childAccountUnavailable;

  /// No description provided for @childAccountFailed.
  ///
  /// In en, this message translates to:
  /// **'The account could not be created. Please try again.'**
  String get childAccountFailed;

  /// Tooltip on the microphone button in a chat.
  ///
  /// In en, this message translates to:
  /// **'Record a voice note'**
  String get msgVoiceRecord;

  /// No description provided for @msgVoiceRecording.
  ///
  /// In en, this message translates to:
  /// **'Recording'**
  String get msgVoiceRecording;

  /// No description provided for @msgVoiceDiscard.
  ///
  /// In en, this message translates to:
  /// **'Discard'**
  String get msgVoiceDiscard;

  /// No description provided for @msgVoiceSend.
  ///
  /// In en, this message translates to:
  /// **'Send voice note'**
  String get msgVoiceSend;

  /// Read out for a message that is only a voice note.
  ///
  /// In en, this message translates to:
  /// **'Voice message'**
  String get msgVoiceMessage;

  /// No description provided for @msgVoicePlay.
  ///
  /// In en, this message translates to:
  /// **'Play voice message'**
  String get msgVoicePlay;

  /// No description provided for @msgVoicePause.
  ///
  /// In en, this message translates to:
  /// **'Pause'**
  String get msgVoicePause;

  /// Shown while the uploaded voice note is being scanned.
  ///
  /// In en, this message translates to:
  /// **'Checking voice message…'**
  String get msgVoiceChecking;

  /// No description provided for @msgVoiceUnavailable.
  ///
  /// In en, this message translates to:
  /// **'This voice message could not be played.'**
  String get msgVoiceUnavailable;

  /// No description provided for @msgVoiceNoPermission.
  ///
  /// In en, this message translates to:
  /// **'Allow microphone access in Settings to record voice notes.'**
  String get msgVoiceNoPermission;

  /// No description provided for @msgVoiceTooShort.
  ///
  /// In en, this message translates to:
  /// **'That was too short to send.'**
  String get msgVoiceTooShort;

  /// No description provided for @msgVoiceFailed.
  ///
  /// In en, this message translates to:
  /// **'The voice note could not be sent. Please try again.'**
  String get msgVoiceFailed;

  /// No description provided for @msgVoiceLimit.
  ///
  /// In en, this message translates to:
  /// **'Voice notes can be up to 5 minutes, so this one was sent.'**
  String get msgVoiceLimit;

  /// No description provided for @lessonNewTitle.
  ///
  /// In en, this message translates to:
  /// **'New lesson'**
  String get lessonNewTitle;

  /// No description provided for @lessonTitleLabel.
  ///
  /// In en, this message translates to:
  /// **'Lesson title'**
  String get lessonTitleLabel;

  /// No description provided for @lessonNotesLabel.
  ///
  /// In en, this message translates to:
  /// **'Lesson notes'**
  String get lessonNotesLabel;

  /// No description provided for @lessonNotesHelp.
  ///
  /// In en, this message translates to:
  /// **'What you taught. Students read this under Lessons.'**
  String get lessonNotesHelp;

  /// No description provided for @lessonPickClassForFiles.
  ///
  /// In en, this message translates to:
  /// **'Choose the class first to attach files.'**
  String get lessonPickClassForFiles;

  /// No description provided for @lessonAudienceLabel.
  ///
  /// In en, this message translates to:
  /// **'Who can see it'**
  String get lessonAudienceLabel;

  /// No description provided for @lessonAudienceBoth.
  ///
  /// In en, this message translates to:
  /// **'Everyone'**
  String get lessonAudienceBoth;

  /// No description provided for @lessonAudienceStudents.
  ///
  /// In en, this message translates to:
  /// **'Students'**
  String get lessonAudienceStudents;

  /// No description provided for @lessonAudienceParents.
  ///
  /// In en, this message translates to:
  /// **'Parents'**
  String get lessonAudienceParents;

  /// No description provided for @lessonClassRequired.
  ///
  /// In en, this message translates to:
  /// **'Choose the class this lesson is for.'**
  String get lessonClassRequired;

  /// No description provided for @lessonTitleRequired.
  ///
  /// In en, this message translates to:
  /// **'Give the lesson a title.'**
  String get lessonTitleRequired;

  /// No description provided for @lessonContentRequired.
  ///
  /// In en, this message translates to:
  /// **'Write some notes or attach a file.'**
  String get lessonContentRequired;

  /// No description provided for @lessonSave.
  ///
  /// In en, this message translates to:
  /// **'Add lesson'**
  String get lessonSave;

  /// No description provided for @lessonSaving.
  ///
  /// In en, this message translates to:
  /// **'Adding…'**
  String get lessonSaving;

  /// No description provided for @lessonCreated.
  ///
  /// In en, this message translates to:
  /// **'Lesson added.'**
  String get lessonCreated;

  /// No description provided for @lessonCreateFailed.
  ///
  /// In en, this message translates to:
  /// **'The lesson could not be added. Please try again.'**
  String get lessonCreateFailed;

  /// Button on the teacher's Lessons feed that opens the new-lesson form.
  ///
  /// In en, this message translates to:
  /// **'Add lesson'**
  String get academicAddLesson;

  /// No description provided for @examMaterialHelp.
  ///
  /// In en, this message translates to:
  /// **'Attach the exam paper, a revision sheet or anything students need.'**
  String get examMaterialHelp;

  /// The teacher's main button that opens the list of things they can create.
  ///
  /// In en, this message translates to:
  /// **'Create'**
  String get teacherCreateAction;

  /// No description provided for @teacherCreateTitle.
  ///
  /// In en, this message translates to:
  /// **'Create'**
  String get teacherCreateTitle;

  /// No description provided for @teacherCreateLesson.
  ///
  /// In en, this message translates to:
  /// **'Lesson'**
  String get teacherCreateLesson;

  /// No description provided for @teacherCreateLessonDetail.
  ///
  /// In en, this message translates to:
  /// **'Notes and files for a class'**
  String get teacherCreateLessonDetail;

  /// No description provided for @teacherCreateAssignment.
  ///
  /// In en, this message translates to:
  /// **'Assignment'**
  String get teacherCreateAssignment;

  /// No description provided for @teacherCreateAssignmentDetail.
  ///
  /// In en, this message translates to:
  /// **'Work students hand in, graded or not'**
  String get teacherCreateAssignmentDetail;

  /// No description provided for @teacherCreateExam.
  ///
  /// In en, this message translates to:
  /// **'Exam or assessment'**
  String get teacherCreateExam;

  /// No description provided for @teacherCreateExamDetail.
  ///
  /// In en, this message translates to:
  /// **'Marked in the gradebook, with its paper attached'**
  String get teacherCreateExamDetail;

  /// No description provided for @teacherCreateAnnouncement.
  ///
  /// In en, this message translates to:
  /// **'Announcement'**
  String get teacherCreateAnnouncement;

  /// No description provided for @teacherCreateAnnouncementDetail.
  ///
  /// In en, this message translates to:
  /// **'Tell a class or its parents something'**
  String get teacherCreateAnnouncementDetail;

  /// No description provided for @teacherCreateAttendance.
  ///
  /// In en, this message translates to:
  /// **'Attendance'**
  String get teacherCreateAttendance;

  /// No description provided for @teacherCreateAttendanceDetail.
  ///
  /// In en, this message translates to:
  /// **'Take today\'s register for a class'**
  String get teacherCreateAttendanceDetail;

  /// No description provided for @teacherPickClass.
  ///
  /// In en, this message translates to:
  /// **'Which class?'**
  String get teacherPickClass;

  /// No description provided for @teacherNoClassesYet.
  ///
  /// In en, this message translates to:
  /// **'Create a class first, from the Classes tab.'**
  String get teacherNoClassesYet;

  /// No description provided for @academicThisClass.
  ///
  /// In en, this message translates to:
  /// **'This class'**
  String get academicThisClass;

  /// No description provided for @studyAssistantNewChat.
  ///
  /// In en, this message translates to:
  /// **'New chat'**
  String get studyAssistantNewChat;

  /// No description provided for @studyAssistantHistory.
  ///
  /// In en, this message translates to:
  /// **'Chat history'**
  String get studyAssistantHistory;

  /// No description provided for @studyAssistantHistoryEmpty.
  ///
  /// In en, this message translates to:
  /// **'No chats yet. Your chats are kept on this device only.'**
  String get studyAssistantHistoryEmpty;

  /// No description provided for @studyAssistantOnDevice.
  ///
  /// In en, this message translates to:
  /// **'Kept on this device only'**
  String get studyAssistantOnDevice;

  /// No description provided for @studyAssistantDeleteChat.
  ///
  /// In en, this message translates to:
  /// **'Delete chat'**
  String get studyAssistantDeleteChat;

  /// No description provided for @studyAssistantDeleteAll.
  ///
  /// In en, this message translates to:
  /// **'Delete all chats'**
  String get studyAssistantDeleteAll;

  /// No description provided for @studyAssistantDeleteAllConfirm.
  ///
  /// In en, this message translates to:
  /// **'Delete every chat on this device? This cannot be undone.'**
  String get studyAssistantDeleteAllConfirm;

  /// No description provided for @studyAssistantDelete.
  ///
  /// In en, this message translates to:
  /// **'Delete'**
  String get studyAssistantDelete;

  /// No description provided for @studyAssistantCancel.
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get studyAssistantCancel;

  /// No description provided for @studyAssistantSend.
  ///
  /// In en, this message translates to:
  /// **'Send'**
  String get studyAssistantSend;

  /// No description provided for @studyAssistantMessageHint.
  ///
  /// In en, this message translates to:
  /// **'Ask a question…'**
  String get studyAssistantMessageHint;

  /// No description provided for @studyAssistantTooShort.
  ///
  /// In en, this message translates to:
  /// **'Write a little more first.'**
  String get studyAssistantTooShort;

  ///
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 message} other{{count} messages}}'**
  String studyAssistantMessageCount(int count);

  /// No description provided for @studyAssistantYou.
  ///
  /// In en, this message translates to:
  /// **'You'**
  String get studyAssistantYou;

  /// No description provided for @studyAssistantHelperName.
  ///
  /// In en, this message translates to:
  /// **'Study helper'**
  String get studyAssistantHelperName;

  /// No description provided for @setupTitle.
  ///
  /// In en, this message translates to:
  /// **'Tell us about you'**
  String get setupTitle;

  /// No description provided for @setupIntro.
  ///
  /// In en, this message translates to:
  /// **'We ask this once, the first time you sign in.'**
  String get setupIntro;

  /// No description provided for @setupNameLabel.
  ///
  /// In en, this message translates to:
  /// **'Your name'**
  String get setupNameLabel;

  /// No description provided for @setupNameHelp.
  ///
  /// In en, this message translates to:
  /// **'How your teachers, classmates and school will see you'**
  String get setupNameHelp;

  /// No description provided for @setupNameRequired.
  ///
  /// In en, this message translates to:
  /// **'Enter your name.'**
  String get setupNameRequired;

  /// No description provided for @setupGenderLabel.
  ///
  /// In en, this message translates to:
  /// **'Gender'**
  String get setupGenderLabel;

  /// No description provided for @setupGenderMale.
  ///
  /// In en, this message translates to:
  /// **'Male'**
  String get setupGenderMale;

  /// No description provided for @setupGenderFemale.
  ///
  /// In en, this message translates to:
  /// **'Female'**
  String get setupGenderFemale;

  /// No description provided for @setupGenderPrivate.
  ///
  /// In en, this message translates to:
  /// **'Only you can see this.'**
  String get setupGenderPrivate;

  /// No description provided for @setupGenderPreferNot.
  ///
  /// In en, this message translates to:
  /// **'Prefer not to answer'**
  String get setupGenderPreferNot;

  /// No description provided for @setupGenderRequired.
  ///
  /// In en, this message translates to:
  /// **'Choose an answer - \"Prefer not to answer\" is fine.'**
  String get setupGenderRequired;

  /// No description provided for @setupContinue.
  ///
  /// In en, this message translates to:
  /// **'Continue'**
  String get setupContinue;

  /// No description provided for @setupSaving.
  ///
  /// In en, this message translates to:
  /// **'Saving…'**
  String get setupSaving;

  /// No description provided for @setupFailed.
  ///
  /// In en, this message translates to:
  /// **'That could not be saved. Please try again.'**
  String get setupFailed;

  /// No description provided for @studyToolsTitle.
  ///
  /// In en, this message translates to:
  /// **'Quizzes & flashcards'**
  String get studyToolsTitle;

  /// No description provided for @studyToolsReady.
  ///
  /// In en, this message translates to:
  /// **'Make a quiz or flashcards from any lesson below.'**
  String get studyToolsReady;

  /// No description provided for @studyToolsNoLessons.
  ///
  /// In en, this message translates to:
  /// **'They appear under each lesson once your teacher adds one.'**
  String get studyToolsNoLessons;

  /// No description provided for @studyToolsLocked.
  ///
  /// In en, this message translates to:
  /// **'Included with Studafy Max.'**
  String get studyToolsLocked;

  /// No description provided for @linksAdd.
  ///
  /// In en, this message translates to:
  /// **'Add link'**
  String get linksAdd;

  /// No description provided for @linksAddTitle.
  ///
  /// In en, this message translates to:
  /// **'Add a link'**
  String get linksAddTitle;

  /// No description provided for @linksInvalid.
  ///
  /// In en, this message translates to:
  /// **'Enter a full web address starting with https://'**
  String get linksInvalid;

  /// No description provided for @linksRemove.
  ///
  /// In en, this message translates to:
  /// **'Remove link'**
  String get linksRemove;

  /// No description provided for @linksCancel.
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get linksCancel;

  /// No description provided for @linksOpenTitle.
  ///
  /// In en, this message translates to:
  /// **'Open this link?'**
  String get linksOpenTitle;

  /// No description provided for @linksOpen.
  ///
  /// In en, this message translates to:
  /// **'Open'**
  String get linksOpen;

  /// No description provided for @notebookFromLesson.
  ///
  /// In en, this message translates to:
  /// **'From a lesson'**
  String get notebookFromLesson;

  /// No description provided for @notebookPickLesson.
  ///
  /// In en, this message translates to:
  /// **'Choose a lesson'**
  String get notebookPickLesson;

  /// No description provided for @notebookNoLessons.
  ///
  /// In en, this message translates to:
  /// **'This class has no lessons yet.'**
  String get notebookNoLessons;

  /// No description provided for @notebookCopyLesson.
  ///
  /// In en, this message translates to:
  /// **'Copy into my notebook'**
  String get notebookCopyLesson;

  /// No description provided for @notebookCopyLessonDetail.
  ///
  /// In en, this message translates to:
  /// **'The lesson as your teacher wrote it'**
  String get notebookCopyLessonDetail;

  /// No description provided for @notebookLessonNotes.
  ///
  /// In en, this message translates to:
  /// **'Turn into study notes'**
  String get notebookLessonNotes;

  /// No description provided for @notebookLessonNotesDetail.
  ///
  /// In en, this message translates to:
  /// **'Headings, key terms and a summary - Studafy Plus'**
  String get notebookLessonNotesDetail;

  /// No description provided for @notebookLessonCopied.
  ///
  /// In en, this message translates to:
  /// **'Added to your notebook.'**
  String get notebookLessonCopied;

  /// No description provided for @notebookFromLessonBadge.
  ///
  /// In en, this message translates to:
  /// **'From a lesson'**
  String get notebookFromLessonBadge;

  /// No description provided for @notebookMyNotebooks.
  ///
  /// In en, this message translates to:
  /// **'My notebooks'**
  String get notebookMyNotebooks;

  /// No description provided for @notebookClassGone.
  ///
  /// In en, this message translates to:
  /// **'This class no longer exists - your notes are kept'**
  String get notebookClassGone;

  /// No description provided for @notebookNoNotebooks.
  ///
  /// In en, this message translates to:
  /// **'No notes yet. Notes you write in a class appear here, by class.'**
  String get notebookNoNotebooks;

  ///
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 note} other{{count} notes}}'**
  String notebookNoteCount(int count);

  /// No description provided for @classDeleteAction.
  ///
  /// In en, this message translates to:
  /// **'Delete class'**
  String get classDeleteAction;

  ///
  ///
  /// In en, this message translates to:
  /// **'Delete {name}?'**
  String classDeleteTitle(String name);

  /// No description provided for @classDeleteBody.
  ///
  /// In en, this message translates to:
  /// **'The class disappears for you and your students, and its join link stops working. Students keep every note in their notebook for it - it will show that the class no longer exists.'**
  String get classDeleteBody;

  /// No description provided for @classDeleteConfirm.
  ///
  /// In en, this message translates to:
  /// **'Delete class'**
  String get classDeleteConfirm;

  /// No description provided for @classDeleteCancel.
  ///
  /// In en, this message translates to:
  /// **'Keep it'**
  String get classDeleteCancel;

  /// No description provided for @classDeleted.
  ///
  /// In en, this message translates to:
  /// **'Class deleted. Students keep their notes.'**
  String get classDeleted;

  /// No description provided for @classDeleteFailed.
  ///
  /// In en, this message translates to:
  /// **'The class could not be deleted. Please try again.'**
  String get classDeleteFailed;

  /// No description provided for @helperAdd.
  ///
  /// In en, this message translates to:
  /// **'Add material or a photo'**
  String get helperAdd;

  /// No description provided for @helperAddMaterial.
  ///
  /// In en, this message translates to:
  /// **'Class material'**
  String get helperAddMaterial;

  /// No description provided for @helperAddMaterialDetail.
  ///
  /// In en, this message translates to:
  /// **'A lesson or one of your notes to answer from'**
  String get helperAddMaterialDetail;

  /// No description provided for @helperAddPhoto.
  ///
  /// In en, this message translates to:
  /// **'Photo from library'**
  String get helperAddPhoto;

  /// No description provided for @helperTakePhoto.
  ///
  /// In en, this message translates to:
  /// **'Take a photo'**
  String get helperTakePhoto;

  /// No description provided for @helperPhotoPlus.
  ///
  /// In en, this message translates to:
  /// **'Photos come with Studafy Plus.'**
  String get helperPhotoPlus;

  /// No description provided for @helperPhotoChecking.
  ///
  /// In en, this message translates to:
  /// **'Checking the photo…'**
  String get helperPhotoChecking;

  /// No description provided for @helperPhotoFailed.
  ///
  /// In en, this message translates to:
  /// **'The photo could not be sent. Please try again.'**
  String get helperPhotoFailed;

  /// No description provided for @helperAnsweringFrom.
  ///
  /// In en, this message translates to:
  /// **'Answering from'**
  String get helperAnsweringFrom;

  /// No description provided for @helperRemove.
  ///
  /// In en, this message translates to:
  /// **'Remove'**
  String get helperRemove;

  /// No description provided for @helperPickTitle.
  ///
  /// In en, this message translates to:
  /// **'Choose class material'**
  String get helperPickTitle;

  /// No description provided for @helperPickClass.
  ///
  /// In en, this message translates to:
  /// **'Which class?'**
  String get helperPickClass;

  /// No description provided for @helperLessons.
  ///
  /// In en, this message translates to:
  /// **'Lessons'**
  String get helperLessons;

  /// No description provided for @helperMyNotes.
  ///
  /// In en, this message translates to:
  /// **'My notes'**
  String get helperMyNotes;

  /// No description provided for @helperPickDone.
  ///
  /// In en, this message translates to:
  /// **'Use these'**
  String get helperPickDone;

  /// No description provided for @helperPickLimit.
  ///
  /// In en, this message translates to:
  /// **'Up to 5 at a time.'**
  String get helperPickLimit;

  /// No description provided for @helperNothingInClass.
  ///
  /// In en, this message translates to:
  /// **'This class has no lessons or notes yet.'**
  String get helperNothingInClass;

  /// No description provided for @helperNoClasses.
  ///
  /// In en, this message translates to:
  /// **'Join a class to use its lessons here.'**
  String get helperNoClasses;

  /// No description provided for @upgradeAllowanceBody.
  ///
  /// In en, this message translates to:
  /// **'You\'ve reached your AI usage limit. It resets on your plan\'s reset date, or a bigger plan gives you more.'**
  String get upgradeAllowanceBody;

  /// No description provided for @upgradeFeatureTitle.
  ///
  /// In en, this message translates to:
  /// **'This comes with {plan}'**
  String upgradeFeatureTitle(String plan);

  /// No description provided for @upgradeFeatureBody.
  ///
  /// In en, this message translates to:
  /// **'Your current plan does not include it.'**
  String get upgradeFeatureBody;

  /// No description provided for @upgradeWhatUnlocks.
  ///
  /// In en, this message translates to:
  /// **'What {plan} unlocks'**
  String upgradeWhatUnlocks(String plan);

  /// No description provided for @upgradeButton.
  ///
  /// In en, this message translates to:
  /// **'Upgrade'**
  String get upgradeButton;

  /// No description provided for @upgradeNotNow.
  ///
  /// In en, this message translates to:
  /// **'Not now'**
  String get upgradeNotNow;

  /// No description provided for @upgradeTopPlan.
  ///
  /// In en, this message translates to:
  /// **'You\'re on Studafy Max, the largest plan.'**
  String get upgradeTopPlan;

  /// No description provided for @studyPlansIncludedInYourPlan.
  ///
  /// In en, this message translates to:
  /// **'Included in your plan'**
  String get studyPlansIncludedInYourPlan;

  /// No description provided for @studyPlansUpgradeToName.
  ///
  /// In en, this message translates to:
  /// **'Upgrade to {name}'**
  String studyPlansUpgradeToName(String name);

  /// No description provided for @studyPlansUpgradeReplaces.
  ///
  /// In en, this message translates to:
  /// **'Your {current} subscription is replaced right away, and the store credits what you have already paid for.'**
  String studyPlansUpgradeReplaces(String current);

  /// No description provided for @studyPlansRenewsOn.
  ///
  /// In en, this message translates to:
  /// **'Renews on {date}'**
  String studyPlansRenewsOn(String date);

  /// No description provided for @studyPlansCancelledUntil.
  ///
  /// In en, this message translates to:
  /// **'Cancelled. You keep {plan} until {date} and won\'t be charged again.'**
  String studyPlansCancelledUntil(String plan, String date);

  /// No description provided for @studyPlansPausedNote.
  ///
  /// In en, this message translates to:
  /// **'Paused in Google Play. No charges while it is paused, and it resumes on its own.'**
  String get studyPlansPausedNote;

  /// No description provided for @studyPlansPaymentIssue.
  ///
  /// In en, this message translates to:
  /// **'{store} couldn\'t take the payment. Update your payment method to keep {plan}.'**
  String studyPlansPaymentIssue(String store, String plan);

  /// No description provided for @studyPlansUpdatePayment.
  ///
  /// In en, this message translates to:
  /// **'Update payment method'**
  String get studyPlansUpdatePayment;

  /// No description provided for @studyPlansManageSubscription.
  ///
  /// In en, this message translates to:
  /// **'Manage subscription'**
  String get studyPlansManageSubscription;

  /// No description provided for @studyPlansCancelSubscription.
  ///
  /// In en, this message translates to:
  /// **'Cancel subscription'**
  String get studyPlansCancelSubscription;

  /// No description provided for @studyPlansPaidByParent.
  ///
  /// In en, this message translates to:
  /// **'A parent pays for this plan. Only they can change or cancel it, from their own {store} account.'**
  String studyPlansPaidByParent(String store);

  /// No description provided for @studyPlansBilledBy.
  ///
  /// In en, this message translates to:
  /// **'Billed monthly through {store}'**
  String studyPlansBilledBy(String store);

  /// No description provided for @studyPlansEndOfPeriod.
  ///
  /// In en, this message translates to:
  /// **'the end of this billing period'**
  String get studyPlansEndOfPeriod;

  /// No description provided for @studyPlansPayWithApple.
  ///
  /// In en, this message translates to:
  /// **'You pay with the payment method in your Apple Account, such as a card, or Apple Pay where Apple offers it. Studafy never sees your card.'**
  String get studyPlansPayWithApple;

  /// No description provided for @studyPlansPayWithGoogle.
  ///
  /// In en, this message translates to:
  /// **'You pay with the payment method in your Google Play account, such as a card, or Google Pay where Google offers it. Studafy never sees your card.'**
  String get studyPlansPayWithGoogle;

  /// No description provided for @studyPlansBuyInMobileApp.
  ///
  /// In en, this message translates to:
  /// **'Plans are bought in the Studafy app for iPhone or Android. A plan bought there works here when you sign in with the same account.'**
  String get studyPlansBuyInMobileApp;

  /// No description provided for @studyPlansBlockedAlready.
  ///
  /// In en, this message translates to:
  /// **'You already have this plan.'**
  String get studyPlansBlockedAlready;

  /// No description provided for @studyPlansBlockedParent.
  ///
  /// In en, this message translates to:
  /// **'A parent pays for your current plan, so only they can change it.'**
  String get studyPlansBlockedParent;

  /// No description provided for @studyPlansBlockedOtherStore.
  ///
  /// In en, this message translates to:
  /// **'Your current plan is billed by {store}. Change it there, on the device you bought it with.'**
  String studyPlansBlockedOtherStore(String store);

  /// No description provided for @studyPlansBlockedOriginalAccount.
  ///
  /// In en, this message translates to:
  /// **'Google Play can only upgrade your plan from the Google account that bought it. Use that account in the Play Store, or cancel your current plan first.'**
  String get studyPlansBlockedOriginalAccount;

  /// No description provided for @cancelSheetTitle.
  ///
  /// In en, this message translates to:
  /// **'Before you cancel'**
  String get cancelSheetTitle;

  /// No description provided for @cancelPauseTitle.
  ///
  /// In en, this message translates to:
  /// **'Pause instead'**
  String get cancelPauseTitle;

  /// No description provided for @cancelPauseBody.
  ///
  /// In en, this message translates to:
  /// **'Take a break for 1 week to 3 months. You keep {plan} until {date}. Then it pauses: no {plan} features and no charges until it resumes on its own. You can resume early.'**
  String cancelPauseBody(String plan, String date);

  /// No description provided for @cancelPauseButton.
  ///
  /// In en, this message translates to:
  /// **'Pause in Google Play'**
  String get cancelPauseButton;

  /// No description provided for @cancelCancelBody.
  ///
  /// In en, this message translates to:
  /// **'You keep {plan} until {date} and won\'t be charged again. After that you\'re on Studafy Free, and your notebook and lessons stay.'**
  String cancelCancelBody(String plan, String date);

  /// No description provided for @cancelInStore.
  ///
  /// In en, this message translates to:
  /// **'Cancel in {store}'**
  String cancelInStore(String store);

  /// No description provided for @cancelStoreNote.
  ///
  /// In en, this message translates to:
  /// **'{store} handles your subscription, so this opens its subscriptions page. Choose Studafy there.'**
  String cancelStoreNote(String store);

  /// No description provided for @cancelKeepPlan.
  ///
  /// In en, this message translates to:
  /// **'Keep my plan'**
  String get cancelKeepPlan;

  /// No description provided for @notificationCopyBillingSubscriptionActiveTitle.
  ///
  /// In en, this message translates to:
  /// **'Subscription active'**
  String get notificationCopyBillingSubscriptionActiveTitle;

  /// No description provided for @notificationCopyBillingSubscriptionActiveDetail.
  ///
  /// In en, this message translates to:
  /// **'Your subscription is active. Apple or Google Play emails your receipt.'**
  String get notificationCopyBillingSubscriptionActiveDetail;

  /// No description provided for @notificationCopyBillingSubscriptionRenewedTitle.
  ///
  /// In en, this message translates to:
  /// **'Subscription renewed'**
  String get notificationCopyBillingSubscriptionRenewedTitle;

  /// No description provided for @notificationCopyBillingSubscriptionRenewedDetail.
  ///
  /// In en, this message translates to:
  /// **'Your subscription renewed. Apple or Google Play emails your receipt.'**
  String get notificationCopyBillingSubscriptionRenewedDetail;

  /// No description provided for @notificationCopyBillingPaymentProblemTitle.
  ///
  /// In en, this message translates to:
  /// **'Payment problem'**
  String get notificationCopyBillingPaymentProblemTitle;

  /// No description provided for @notificationCopyBillingPaymentProblemDetail.
  ///
  /// In en, this message translates to:
  /// **'Your subscription could not be renewed. Check your payment method in the App Store or Google Play.'**
  String get notificationCopyBillingPaymentProblemDetail;

  /// No description provided for @notificationCopyBillingSubscriptionEndedTitle.
  ///
  /// In en, this message translates to:
  /// **'Subscription ended'**
  String get notificationCopyBillingSubscriptionEndedTitle;

  /// No description provided for @notificationCopyBillingSubscriptionEndedDetail.
  ///
  /// In en, this message translates to:
  /// **'Your subscription has ended. You can subscribe again from Plans.'**
  String get notificationCopyBillingSubscriptionEndedDetail;

  /// No description provided for @notificationCopySystemPushTestTitle.
  ///
  /// In en, this message translates to:
  /// **'Test notification'**
  String get notificationCopySystemPushTestTitle;

  /// No description provided for @notificationCopySystemPushTestDetail.
  ///
  /// In en, this message translates to:
  /// **'Notifications are working on this device.'**
  String get notificationCopySystemPushTestDetail;

  /// No description provided for @notificationCopyAccountInactiveDeletionWarningTitle.
  ///
  /// In en, this message translates to:
  /// **'Your account will be deleted'**
  String get notificationCopyAccountInactiveDeletionWarningTitle;

  /// No description provided for @notificationCopyAccountInactiveDeletionWarningDetail.
  ///
  /// In en, this message translates to:
  /// **'This account has not been used for nearly two years, so it will be deleted in about a month. Using the app keeps it.'**
  String get notificationCopyAccountInactiveDeletionWarningDetail;

  /// No description provided for @famLinkHasAccount.
  ///
  /// In en, this message translates to:
  /// **'My child has a Studafy account'**
  String get famLinkHasAccount;

  /// No description provided for @famLinkHasAccountBody.
  ///
  /// In en, this message translates to:
  /// **'Find them by the Studafy ID on their profile. They approve the link from their account.'**
  String get famLinkHasAccountBody;

  /// No description provided for @famLinkCreateAccount.
  ///
  /// In en, this message translates to:
  /// **'Create an account for my child'**
  String get famLinkCreateAccount;

  /// No description provided for @famLinkCreateAccountBody.
  ///
  /// In en, this message translates to:
  /// **'For a child with no email or phone. You manage the account and open it from yours. No approval from your child is needed.'**
  String get famLinkCreateAccountBody;

  /// No description provided for @famManagedTitle.
  ///
  /// In en, this message translates to:
  /// **'Child accounts you manage'**
  String get famManagedTitle;

  /// No description provided for @famManagedHint.
  ///
  /// In en, this message translates to:
  /// **'Open your child\'s account to join their class with the class code. Their progress then shows here.'**
  String get famManagedHint;

  /// No description provided for @famManagedOpen.
  ///
  /// In en, this message translates to:
  /// **'Open account'**
  String get famManagedOpen;

  /// No description provided for @courseworkVersionConflict.
  ///
  /// In en, this message translates to:
  /// **'Someone else changed this while you were working. Reload to see the latest, then try again.'**
  String get courseworkVersionConflict;

  /// No description provided for @courseworkNotAllowed.
  ///
  /// In en, this message translates to:
  /// **'You don\'t have permission to do this for this class.'**
  String get courseworkNotAllowed;

  /// No description provided for @courseworkWindowClosed.
  ///
  /// In en, this message translates to:
  /// **'The deadline for this work has passed. Ask your teacher for more time.'**
  String get courseworkWindowClosed;

  /// No description provided for @courseworkSubmissionLocked.
  ///
  /// In en, this message translates to:
  /// **'Your teacher has already marked this work, so it can\'t be replaced. Ask your teacher if you need to hand it in again.'**
  String get courseworkSubmissionLocked;

  /// No description provided for @courseworkReasonRequired.
  ///
  /// In en, this message translates to:
  /// **'Please give a reason. It is kept with the change.'**
  String get courseworkReasonRequired;

  /// No description provided for @courseworkAttendanceLocked.
  ///
  /// In en, this message translates to:
  /// **'This register is locked by your school\'s attendance policy.'**
  String get courseworkAttendanceLocked;

  /// No description provided for @courseworkEntriesInvalid.
  ///
  /// In en, this message translates to:
  /// **'Some rows need fixing. Nothing was saved.'**
  String get courseworkEntriesInvalid;

  /// No description provided for @courseworkFailed.
  ///
  /// In en, this message translates to:
  /// **'That didn\'t work. Check your connection and try again.'**
  String get courseworkFailed;

  /// Form error when the server refused a file or link being attached; the refused ones are marked in the form.
  ///
  /// In en, this message translates to:
  /// **'A file or link was not accepted, so nothing was saved. Remove the ones marked, then save again.'**
  String get courseworkAttachmentRefused;

  /// No description provided for @paperGradesTitle.
  ///
  /// In en, this message translates to:
  /// **'Grade sheet: {title}'**
  String paperGradesTitle(String title);

  /// No description provided for @paperGradesPaperLabel.
  ///
  /// In en, this message translates to:
  /// **'Paper'**
  String get paperGradesPaperLabel;

  /// No description provided for @paperGradesOnlineLabel.
  ///
  /// In en, this message translates to:
  /// **'Online'**
  String get paperGradesOnlineLabel;

  /// No description provided for @paperGradesPaperSection.
  ///
  /// In en, this message translates to:
  /// **'Paper work'**
  String get paperGradesPaperSection;

  /// No description provided for @paperGradesOnlineSection.
  ///
  /// In en, this message translates to:
  /// **'Online work'**
  String get paperGradesOnlineSection;

  /// No description provided for @paperGradesNew.
  ///
  /// In en, this message translates to:
  /// **'New paper grade'**
  String get paperGradesNew;

  /// No description provided for @paperGradesOpenSheet.
  ///
  /// In en, this message translates to:
  /// **'Open the grade sheet'**
  String get paperGradesOpenSheet;

  /// No description provided for @paperGradesSheetHint.
  ///
  /// In en, this message translates to:
  /// **'This is paper work. Enter marks for the whole class on its grade sheet.'**
  String get paperGradesSheetHint;

  /// No description provided for @paperGradesOutOf.
  ///
  /// In en, this message translates to:
  /// **'out of {max}'**
  String paperGradesOutOf(String max);

  /// No description provided for @paperGradesWeight.
  ///
  /// In en, this message translates to:
  /// **'Counts {weight}%'**
  String paperGradesWeight(String weight);

  /// No description provided for @paperGradesScore.
  ///
  /// In en, this message translates to:
  /// **'Score'**
  String get paperGradesScore;

  /// No description provided for @paperGradesAbsent.
  ///
  /// In en, this message translates to:
  /// **'Missed the exam'**
  String get paperGradesAbsent;

  /// No description provided for @paperGradesNotGraded.
  ///
  /// In en, this message translates to:
  /// **'Not graded'**
  String get paperGradesNotGraded;

  /// No description provided for @paperGradesUnmarked.
  ///
  /// In en, this message translates to:
  /// **'Not marked yet'**
  String get paperGradesUnmarked;

  /// No description provided for @paperGradesStateDraft.
  ///
  /// In en, this message translates to:
  /// **'Draft'**
  String get paperGradesStateDraft;

  /// No description provided for @paperGradesStateReady.
  ///
  /// In en, this message translates to:
  /// **'Ready'**
  String get paperGradesStateReady;

  /// No description provided for @paperGradesStatePublished.
  ///
  /// In en, this message translates to:
  /// **'Published'**
  String get paperGradesStatePublished;

  /// No description provided for @paperGradesStateChanged.
  ///
  /// In en, this message translates to:
  /// **'Unsaved'**
  String get paperGradesStateChanged;

  /// No description provided for @paperGradesLeftClass.
  ///
  /// In en, this message translates to:
  /// **'Left the class'**
  String get paperGradesLeftClass;

  /// No description provided for @paperGradesComment.
  ///
  /// In en, this message translates to:
  /// **'Comment (optional)'**
  String get paperGradesComment;

  /// No description provided for @paperGradesAddComment.
  ///
  /// In en, this message translates to:
  /// **'Add comment'**
  String get paperGradesAddComment;

  /// No description provided for @paperGradesSaveDraft.
  ///
  /// In en, this message translates to:
  /// **'Save draft'**
  String get paperGradesSaveDraft;

  /// No description provided for @paperGradesSaving.
  ///
  /// In en, this message translates to:
  /// **'Saving…'**
  String get paperGradesSaving;

  /// No description provided for @paperGradesSaved.
  ///
  /// In en, this message translates to:
  /// **'Draft saved. Students and parents can\'t see it yet.'**
  String get paperGradesSaved;

  /// No description provided for @paperGradesPublish.
  ///
  /// In en, this message translates to:
  /// **'Publish'**
  String get paperGradesPublish;

  /// No description provided for @paperGradesSaveFirst.
  ///
  /// In en, this message translates to:
  /// **'Save your changes before publishing.'**
  String get paperGradesSaveFirst;

  /// No description provided for @paperGradesNothingToPublish.
  ///
  /// In en, this message translates to:
  /// **'Nothing is ready to publish. Enter and save marks first.'**
  String get paperGradesNothingToPublish;

  /// No description provided for @paperGradesPublishTitle.
  ///
  /// In en, this message translates to:
  /// **'Publish marks?'**
  String get paperGradesPublishTitle;

  /// No description provided for @paperGradesPublishBody.
  ///
  /// In en, this message translates to:
  /// **'{ready} marks will be visible to students and their parents, who will be notified. {unmarked} students without a mark stay unpublished.'**
  String paperGradesPublishBody(int ready, int unmarked);

  /// No description provided for @paperGradesPublished.
  ///
  /// In en, this message translates to:
  /// **'{count} marks published.'**
  String paperGradesPublished(int count);

  /// No description provided for @paperGradesCancel.
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get paperGradesCancel;

  /// No description provided for @paperGradesCounts.
  ///
  /// In en, this message translates to:
  /// **'{ready} ready · {published} published · {unmarked} not marked'**
  String paperGradesCounts(int ready, int published, int unmarked);

  /// No description provided for @paperGradesEmpty.
  ///
  /// In en, this message translates to:
  /// **'No students are enrolled in this class yet.'**
  String get paperGradesEmpty;

  /// No description provided for @paperGradesLoadFailed.
  ///
  /// In en, this message translates to:
  /// **'The grade sheet could not be loaded.'**
  String get paperGradesLoadFailed;

  /// No description provided for @paperGradesRetry.
  ///
  /// In en, this message translates to:
  /// **'Try again'**
  String get paperGradesRetry;

  /// No description provided for @paperGradesCorrect.
  ///
  /// In en, this message translates to:
  /// **'Correct'**
  String get paperGradesCorrect;

  /// No description provided for @paperGradesCorrected.
  ///
  /// In en, this message translates to:
  /// **'Corrected {count}×'**
  String paperGradesCorrected(int count);

  /// No description provided for @paperGradesRowNotEnrolled.
  ///
  /// In en, this message translates to:
  /// **'Not in this class'**
  String get paperGradesRowNotEnrolled;

  /// No description provided for @paperGradesRowAlreadyPublished.
  ///
  /// In en, this message translates to:
  /// **'Already published. Use Correct.'**
  String get paperGradesRowAlreadyPublished;

  /// No description provided for @paperGradesRowScoreRequired.
  ///
  /// In en, this message translates to:
  /// **'Enter a score'**
  String get paperGradesRowScoreRequired;

  /// No description provided for @paperGradesRowScoreOutOfRange.
  ///
  /// In en, this message translates to:
  /// **'Must be between 0 and {max}'**
  String paperGradesRowScoreOutOfRange(String max);

  /// No description provided for @paperGradesRowScoreNotAllowed.
  ///
  /// In en, this message translates to:
  /// **'No score for absent or not graded'**
  String get paperGradesRowScoreNotAllowed;

  /// No description provided for @paperGradesRowConflict.
  ///
  /// In en, this message translates to:
  /// **'Changed by someone else'**
  String get paperGradesRowConflict;

  /// No description provided for @paperGradesRowInvalid.
  ///
  /// In en, this message translates to:
  /// **'Check this row'**
  String get paperGradesRowInvalid;

  /// No description provided for @paperGradesEditItem.
  ///
  /// In en, this message translates to:
  /// **'Edit details'**
  String get paperGradesEditItem;

  /// No description provided for @paperItemTitle.
  ///
  /// In en, this message translates to:
  /// **'Paper grade'**
  String get paperItemTitle;

  /// No description provided for @paperItemName.
  ///
  /// In en, this message translates to:
  /// **'Name'**
  String get paperItemName;

  /// No description provided for @paperItemNameHint.
  ///
  /// In en, this message translates to:
  /// **'e.g. Term 1 exam'**
  String get paperItemNameHint;

  /// No description provided for @paperItemCategory.
  ///
  /// In en, this message translates to:
  /// **'Kind'**
  String get paperItemCategory;

  /// No description provided for @paperItemCategoryExam.
  ///
  /// In en, this message translates to:
  /// **'Paper exam'**
  String get paperItemCategoryExam;

  /// No description provided for @paperItemCategoryHomework.
  ///
  /// In en, this message translates to:
  /// **'Homework'**
  String get paperItemCategoryHomework;

  /// No description provided for @paperItemCategoryQuiz.
  ///
  /// In en, this message translates to:
  /// **'Quiz'**
  String get paperItemCategoryQuiz;

  /// No description provided for @paperItemCategoryParticipation.
  ///
  /// In en, this message translates to:
  /// **'Participation'**
  String get paperItemCategoryParticipation;

  /// No description provided for @paperItemCategoryOther.
  ///
  /// In en, this message translates to:
  /// **'Other'**
  String get paperItemCategoryOther;

  /// No description provided for @paperItemCategoryCustom.
  ///
  /// In en, this message translates to:
  /// **'Kind of work'**
  String get paperItemCategoryCustom;

  /// No description provided for @paperItemMaximum.
  ///
  /// In en, this message translates to:
  /// **'Out of'**
  String get paperItemMaximum;

  /// No description provided for @paperItemWeight.
  ///
  /// In en, this message translates to:
  /// **'Weight % (optional)'**
  String get paperItemWeight;

  /// No description provided for @paperItemDate.
  ///
  /// In en, this message translates to:
  /// **'Date (optional)'**
  String get paperItemDate;

  /// No description provided for @paperItemPickDate.
  ///
  /// In en, this message translates to:
  /// **'Pick a date'**
  String get paperItemPickDate;

  /// No description provided for @paperItemSave.
  ///
  /// In en, this message translates to:
  /// **'Save'**
  String get paperItemSave;

  /// No description provided for @paperItemInvalid.
  ///
  /// In en, this message translates to:
  /// **'Enter a name and a maximum above 0. A weight is between 0 and 100.'**
  String get paperItemInvalid;

  /// No description provided for @gradeCorrectionTitle.
  ///
  /// In en, this message translates to:
  /// **'Correct {name}\'s mark'**
  String gradeCorrectionTitle(String name);

  /// No description provided for @gradeCorrectionReason.
  ///
  /// In en, this message translates to:
  /// **'Reason for the change'**
  String get gradeCorrectionReason;

  /// No description provided for @gradeCorrectionReasonHint.
  ///
  /// In en, this message translates to:
  /// **'e.g. added up page 3 again'**
  String get gradeCorrectionReasonHint;

  /// Helper under the correction reason: a comment-only change needs no reason.
  ///
  /// In en, this message translates to:
  /// **'Needed only when the mark or score changes.'**
  String get gradeCorrectionReasonWhen;

  /// No description provided for @gradeCorrectionReasonTooShort.
  ///
  /// In en, this message translates to:
  /// **'Give a reason of at least 3 characters.'**
  String get gradeCorrectionReasonTooShort;

  /// No description provided for @gradeCorrectionSave.
  ///
  /// In en, this message translates to:
  /// **'Save correction'**
  String get gradeCorrectionSave;

  /// No description provided for @gradeCorrectionNotifies.
  ///
  /// In en, this message translates to:
  /// **'If the mark changes, the student and their parents are told. A comment-only change is recorded but not announced.'**
  String get gradeCorrectionNotifies;

  /// No description provided for @gradeCorrectionHistory.
  ///
  /// In en, this message translates to:
  /// **'Changes'**
  String get gradeCorrectionHistory;

  /// No description provided for @gradeCorrectionHistoryEmpty.
  ///
  /// In en, this message translates to:
  /// **'No changes yet.'**
  String get gradeCorrectionHistoryEmpty;

  /// No description provided for @gradeCorrectionChangePublished.
  ///
  /// In en, this message translates to:
  /// **'Published'**
  String get gradeCorrectionChangePublished;

  /// No description provided for @gradeCorrectionChangeCorrected.
  ///
  /// In en, this message translates to:
  /// **'Corrected'**
  String get gradeCorrectionChangeCorrected;

  /// No description provided for @gradeCorrectionBy.
  ///
  /// In en, this message translates to:
  /// **'by {name}'**
  String gradeCorrectionBy(String name);

  /// No description provided for @gradeCorrectionDone.
  ///
  /// In en, this message translates to:
  /// **'Mark corrected.'**
  String get gradeCorrectionDone;

  /// No description provided for @attendanceRuleReasonRequired.
  ///
  /// In en, this message translates to:
  /// **'This lesson is in the past. Changing a mark needs a reason, which is kept with it.'**
  String get attendanceRuleReasonRequired;

  /// No description provided for @attendanceRuleLocked.
  ///
  /// In en, this message translates to:
  /// **'This register is locked by your school\'s attendance policy.'**
  String get attendanceRuleLocked;

  /// No description provided for @attendanceRuleLockedOverride.
  ///
  /// In en, this message translates to:
  /// **'This register is locked. As the class\'s lead teacher you can override the lock, with a reason.'**
  String get attendanceRuleLockedOverride;

  /// No description provided for @attendanceOverride.
  ///
  /// In en, this message translates to:
  /// **'Override the lock'**
  String get attendanceOverride;

  /// No description provided for @attendanceCorrectionReason.
  ///
  /// In en, this message translates to:
  /// **'Reason for the change'**
  String get attendanceCorrectionReason;

  /// No description provided for @attendanceHistory.
  ///
  /// In en, this message translates to:
  /// **'Changes'**
  String get attendanceHistory;

  /// No description provided for @attendanceHistoryEmpty.
  ///
  /// In en, this message translates to:
  /// **'No marks on this register have been changed.'**
  String get attendanceHistoryEmpty;

  /// No description provided for @attendanceHistoryLine.
  ///
  /// In en, this message translates to:
  /// **'{name}: {from} → {to}'**
  String attendanceHistoryLine(String name, String from, String to);

  /// No description provided for @attendanceHistoryOverride.
  ///
  /// In en, this message translates to:
  /// **'Lock overridden'**
  String get attendanceHistoryOverride;

  /// No description provided for @deadlineDue.
  ///
  /// In en, this message translates to:
  /// **'Due {when} ({zone})'**
  String deadlineDue(String when, String zone);

  /// No description provided for @deadlineExtended.
  ///
  /// In en, this message translates to:
  /// **'You have extra time until {when}'**
  String deadlineExtended(String when);

  /// No description provided for @deadlineClosed.
  ///
  /// In en, this message translates to:
  /// **'The deadline has passed.'**
  String get deadlineClosed;

  /// No description provided for @deadlineGraded.
  ///
  /// In en, this message translates to:
  /// **'Marked - it can no longer be replaced.'**
  String get deadlineGraded;

  /// No description provided for @deadlineReplaceHint.
  ///
  /// In en, this message translates to:
  /// **'You can replace your work until the deadline. Your earlier hand-ins are kept.'**
  String get deadlineReplaceHint;

  /// No description provided for @deadlineKeepFiles.
  ///
  /// In en, this message translates to:
  /// **'Keep files from your last hand-in'**
  String get deadlineKeepFiles;

  /// No description provided for @deadlineExtend.
  ///
  /// In en, this message translates to:
  /// **'Give more time'**
  String get deadlineExtend;

  /// No description provided for @deadlineRemoveExtension.
  ///
  /// In en, this message translates to:
  /// **'Remove extra time'**
  String get deadlineRemoveExtension;

  /// No description provided for @deadlineExtendedUntil.
  ///
  /// In en, this message translates to:
  /// **'Extra time until {when}'**
  String deadlineExtendedUntil(String when);

  /// No description provided for @deadlineReopen.
  ///
  /// In en, this message translates to:
  /// **'Reopen for the class'**
  String get deadlineReopen;

  /// No description provided for @deadlineUntil.
  ///
  /// In en, this message translates to:
  /// **'Until'**
  String get deadlineUntil;

  /// No description provided for @deadlineSchoolTime.
  ///
  /// In en, this message translates to:
  /// **'School time ({zone})'**
  String deadlineSchoolTime(String zone);

  /// No description provided for @deadlineReason.
  ///
  /// In en, this message translates to:
  /// **'Reason'**
  String get deadlineReason;

  /// No description provided for @deadlineSave.
  ///
  /// In en, this message translates to:
  /// **'Save'**
  String get deadlineSave;

  /// No description provided for @deadlineSaved.
  ///
  /// In en, this message translates to:
  /// **'Saved.'**
  String get deadlineSaved;

  /// No description provided for @lessonEdit.
  ///
  /// In en, this message translates to:
  /// **'Edit'**
  String get lessonEdit;

  /// No description provided for @lessonEditTitle.
  ///
  /// In en, this message translates to:
  /// **'Edit lesson'**
  String get lessonEditTitle;

  /// No description provided for @lessonEditName.
  ///
  /// In en, this message translates to:
  /// **'Title'**
  String get lessonEditName;

  /// No description provided for @lessonEditBody.
  ///
  /// In en, this message translates to:
  /// **'Notes'**
  String get lessonEditBody;

  /// No description provided for @lessonEditReplaceFile.
  ///
  /// In en, this message translates to:
  /// **'Replace the file'**
  String get lessonEditReplaceFile;

  /// No description provided for @lessonEditReplaceHint.
  ///
  /// In en, this message translates to:
  /// **'The class sees only the new file. The old one is kept for the school.'**
  String get lessonEditReplaceHint;

  /// No description provided for @lessonEditSave.
  ///
  /// In en, this message translates to:
  /// **'Save'**
  String get lessonEditSave;

  /// No description provided for @lessonEditSaved.
  ///
  /// In en, this message translates to:
  /// **'Lesson updated.'**
  String get lessonEditSaved;

  /// No description provided for @downloadUnavailable.
  ///
  /// In en, this message translates to:
  /// **'This file is no longer available. Pull down to refresh.'**
  String get downloadUnavailable;

  /// No description provided for @materialsEditTitle.
  ///
  /// In en, this message translates to:
  /// **'Change the material'**
  String get materialsEditTitle;

  /// No description provided for @materialsEditHint.
  ///
  /// In en, this message translates to:
  /// **'Files you take off are kept for the school but no longer shown to the class.'**
  String get materialsEditHint;

  /// No description provided for @materialsEditNone.
  ///
  /// In en, this message translates to:
  /// **'No files attached yet.'**
  String get materialsEditNone;

  /// No description provided for @materialsEditRemoving.
  ///
  /// In en, this message translates to:
  /// **'Will be taken off'**
  String get materialsEditRemoving;

  /// No description provided for @materialsEditSaved.
  ///
  /// In en, this message translates to:
  /// **'Material updated.'**
  String get materialsEditSaved;

  /// No description provided for @classesInviteCodeBody.
  ///
  /// In en, this message translates to:
  /// **'Students join by typing this class code in Studafy. Read it out, write it on the board, or share it.'**
  String get classesInviteCodeBody;

  /// No description provided for @classesCopyCode.
  ///
  /// In en, this message translates to:
  /// **'Copy code'**
  String get classesCopyCode;

  /// No description provided for @classesInviteCodeCopied.
  ///
  /// In en, this message translates to:
  /// **'Class code copied.'**
  String get classesInviteCodeCopied;

  /// No description provided for @classesShareCode.
  ///
  /// In en, this message translates to:
  /// **'Share code'**
  String get classesShareCode;

  /// No description provided for @teacherCreatePaperGrades.
  ///
  /// In en, this message translates to:
  /// **'Paper grades'**
  String get teacherCreatePaperGrades;

  /// No description provided for @teacherCreatePaperGradesDetail.
  ///
  /// In en, this message translates to:
  /// **'Marks for a paper exam, quiz or homework, for the whole class'**
  String get teacherCreatePaperGradesDetail;

  /// No description provided for @profilePhotoChange.
  ///
  /// In en, this message translates to:
  /// **'Change profile photo'**
  String get profilePhotoChange;

  /// No description provided for @profilePhotoOnDevice.
  ///
  /// In en, this message translates to:
  /// **'Your photo is kept on this phone only. It is never uploaded, and it is removed when you sign out.'**
  String get profilePhotoOnDevice;

  /// No description provided for @profilePhotoChoose.
  ///
  /// In en, this message translates to:
  /// **'Choose a photo'**
  String get profilePhotoChoose;

  /// No description provided for @profilePhotoTake.
  ///
  /// In en, this message translates to:
  /// **'Take a photo'**
  String get profilePhotoTake;

  /// No description provided for @profilePhotoRemove.
  ///
  /// In en, this message translates to:
  /// **'Remove photo'**
  String get profilePhotoRemove;

  /// No description provided for @profilePhotoFailed.
  ///
  /// In en, this message translates to:
  /// **'That photo could not be used. Try another one.'**
  String get profilePhotoFailed;

  /// No description provided for @todayStatClasses.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =0{No classes} =1{1 class} other{{count} classes}}'**
  String todayStatClasses(int count);

  /// No description provided for @todayQuickActions.
  ///
  /// In en, this message translates to:
  /// **'Quick actions'**
  String get todayQuickActions;

  /// No description provided for @todaySeeAll.
  ///
  /// In en, this message translates to:
  /// **'See all'**
  String get todaySeeAll;

  /// No description provided for @wellbeingNewTitle.
  ///
  /// In en, this message translates to:
  /// **'New wellbeing note'**
  String get wellbeingNewTitle;

  /// No description provided for @wellbeingIntro.
  ///
  /// In en, this message translates to:
  /// **'Record how a student is doing - a strength to celebrate, a note, or a concern to follow up. You choose who else can read it.'**
  String get wellbeingIntro;

  /// No description provided for @wellbeingWhoAbout.
  ///
  /// In en, this message translates to:
  /// **'Who is it about?'**
  String get wellbeingWhoAbout;

  /// No description provided for @wellbeingClass.
  ///
  /// In en, this message translates to:
  /// **'Class'**
  String get wellbeingClass;

  /// No description provided for @wellbeingPickClass.
  ///
  /// In en, this message translates to:
  /// **'Choose a class'**
  String get wellbeingPickClass;

  /// No description provided for @wellbeingStudent.
  ///
  /// In en, this message translates to:
  /// **'Student'**
  String get wellbeingStudent;

  /// No description provided for @wellbeingPickStudent.
  ///
  /// In en, this message translates to:
  /// **'Choose a student'**
  String get wellbeingPickStudent;

  /// No description provided for @wellbeingNoStudents.
  ///
  /// In en, this message translates to:
  /// **'No students have joined this class yet.'**
  String get wellbeingNoStudents;

  /// No description provided for @wellbeingStudentsFailed.
  ///
  /// In en, this message translates to:
  /// **'The students could not load. Tap to try again.'**
  String get wellbeingStudentsFailed;

  /// No description provided for @wellbeingKind.
  ///
  /// In en, this message translates to:
  /// **'Type of note'**
  String get wellbeingKind;

  /// No description provided for @wellbeingKindStrength.
  ///
  /// In en, this message translates to:
  /// **'Strength'**
  String get wellbeingKindStrength;

  /// No description provided for @wellbeingKindNote.
  ///
  /// In en, this message translates to:
  /// **'Note'**
  String get wellbeingKindNote;

  /// No description provided for @wellbeingKindConcern.
  ///
  /// In en, this message translates to:
  /// **'Concern'**
  String get wellbeingKindConcern;

  /// No description provided for @wellbeingSeverity.
  ///
  /// In en, this message translates to:
  /// **'How serious is it?'**
  String get wellbeingSeverity;

  /// No description provided for @wellbeingSeverityLow.
  ///
  /// In en, this message translates to:
  /// **'Low'**
  String get wellbeingSeverityLow;

  /// No description provided for @wellbeingSeverityModerate.
  ///
  /// In en, this message translates to:
  /// **'Moderate'**
  String get wellbeingSeverityModerate;

  /// No description provided for @wellbeingSeverityHigh.
  ///
  /// In en, this message translates to:
  /// **'High'**
  String get wellbeingSeverityHigh;

  /// No description provided for @wellbeingDetails.
  ///
  /// In en, this message translates to:
  /// **'Details'**
  String get wellbeingDetails;

  /// No description provided for @wellbeingTitle.
  ///
  /// In en, this message translates to:
  /// **'Title'**
  String get wellbeingTitle;

  /// No description provided for @wellbeingTitleRequired.
  ///
  /// In en, this message translates to:
  /// **'Give the note a short title.'**
  String get wellbeingTitleRequired;

  /// No description provided for @wellbeingContext.
  ///
  /// In en, this message translates to:
  /// **'What happened (optional)'**
  String get wellbeingContext;

  /// No description provided for @wellbeingFollowUp.
  ///
  /// In en, this message translates to:
  /// **'Follow-up (optional)'**
  String get wellbeingFollowUp;

  /// No description provided for @wellbeingWhoSees.
  ///
  /// In en, this message translates to:
  /// **'Who can read it?'**
  String get wellbeingWhoSees;

  /// No description provided for @wellbeingSeeStaff.
  ///
  /// In en, this message translates to:
  /// **'Only you'**
  String get wellbeingSeeStaff;

  /// No description provided for @wellbeingSeeStaffDetail.
  ///
  /// In en, this message translates to:
  /// **'Kept to you, as this class\'s teacher.'**
  String get wellbeingSeeStaffDetail;

  /// No description provided for @wellbeingSeeGuardians.
  ///
  /// In en, this message translates to:
  /// **'You and the parents'**
  String get wellbeingSeeGuardians;

  /// No description provided for @wellbeingSeeGuardiansDetail.
  ///
  /// In en, this message translates to:
  /// **'Also the student\'s linked parents.'**
  String get wellbeingSeeGuardiansDetail;

  /// No description provided for @wellbeingSeeStudent.
  ///
  /// In en, this message translates to:
  /// **'You, the parents and the student'**
  String get wellbeingSeeStudent;

  /// No description provided for @wellbeingSeeStudentDetail.
  ///
  /// In en, this message translates to:
  /// **'Also the parents and the student themselves.'**
  String get wellbeingSeeStudentDetail;

  /// No description provided for @wellbeingSave.
  ///
  /// In en, this message translates to:
  /// **'Save note'**
  String get wellbeingSave;

  /// No description provided for @wellbeingSaving.
  ///
  /// In en, this message translates to:
  /// **'Saving...'**
  String get wellbeingSaving;

  /// No description provided for @wellbeingSaved.
  ///
  /// In en, this message translates to:
  /// **'Wellbeing note saved.'**
  String get wellbeingSaved;

  /// No description provided for @wellbeingSaveFailed.
  ///
  /// In en, this message translates to:
  /// **'The note could not be saved. Please try again.'**
  String get wellbeingSaveFailed;

  /// No description provided for @wellbeingAdd.
  ///
  /// In en, this message translates to:
  /// **'New wellbeing note'**
  String get wellbeingAdd;

  /// No description provided for @gradebookHomeNoClasses.
  ///
  /// In en, this message translates to:
  /// **'Create a class on the Classes tab, then its marks are kept here.'**
  String get gradebookHomeNoClasses;

  /// No description provided for @gradebookHomeNothing.
  ///
  /// In en, this message translates to:
  /// **'Nothing to mark in this class yet'**
  String get gradebookHomeNothing;

  /// No description provided for @gradebookHomeNothingDetail.
  ///
  /// In en, this message translates to:
  /// **'Add a paper grade for a test done on paper, or set graded work from the Teaching tab.'**
  String get gradebookHomeNothingDetail;

  /// No description provided for @gradebookHomeCounts.
  ///
  /// In en, this message translates to:
  /// **'{total, plural, =0{No graded work} =1{1 graded piece} other{{total} graded pieces}} · {drafts} drafts'**
  String gradebookHomeCounts(int total, int drafts);

  /// No description provided for @gradebookMarkOnline.
  ///
  /// In en, this message translates to:
  /// **'Mark online work'**
  String get gradebookMarkOnline;

  /// No description provided for @gradebookViewHandIns.
  ///
  /// In en, this message translates to:
  /// **'View hand-ins'**
  String get gradebookViewHandIns;

  /// No description provided for @academicStateWithdrawn.
  ///
  /// In en, this message translates to:
  /// **'Hidden'**
  String get academicStateWithdrawn;

  /// No description provided for @academicEmptyTeacherHint.
  ///
  /// In en, this message translates to:
  /// **'Tap + to create something for your classes.'**
  String get academicEmptyTeacherHint;

  /// No description provided for @teacherCreateGroupTeaching.
  ///
  /// In en, this message translates to:
  /// **'Teaching'**
  String get teacherCreateGroupTeaching;

  /// No description provided for @teacherCreateGroupClass.
  ///
  /// In en, this message translates to:
  /// **'Class records'**
  String get teacherCreateGroupClass;

  /// No description provided for @teacherCreateGroupFamilies.
  ///
  /// In en, this message translates to:
  /// **'Families'**
  String get teacherCreateGroupFamilies;

  /// No description provided for @teacherCreateWellbeingDetail.
  ///
  /// In en, this message translates to:
  /// **'A strength, note or concern about one student'**
  String get teacherCreateWellbeingDetail;

  /// No description provided for @classesSummary.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =0{No classes yet} =1{1 class} other{{count} classes}}'**
  String classesSummary(int count);

  /// No description provided for @classesEmptyDetail.
  ///
  /// In en, this message translates to:
  /// **'Create your first class, then invite students with its class code.'**
  String get classesEmptyDetail;

  /// No description provided for @attendanceMarkAllPresent.
  ///
  /// In en, this message translates to:
  /// **'Mark all present'**
  String get attendanceMarkAllPresent;

  /// No description provided for @attendanceNotMarked.
  ///
  /// In en, this message translates to:
  /// **'Not marked'**
  String get attendanceNotMarked;

  /// No description provided for @attendanceUnsaved.
  ///
  /// In en, this message translates to:
  /// **'Unsaved changes'**
  String get attendanceUnsaved;

  /// No description provided for @attendanceStatusFor.
  ///
  /// In en, this message translates to:
  /// **'{name}: {status}. Change attendance'**
  String attendanceStatusFor(String name, String status);

  /// No description provided for @attendanceCounts.
  ///
  /// In en, this message translates to:
  /// **'{present} present · {absent} absent · {late} late · {unmarked} not marked'**
  String attendanceCounts(int present, int absent, int late, int unmarked);

  /// No description provided for @attachmentCamera.
  ///
  /// In en, this message translates to:
  /// **'Camera'**
  String get attachmentCamera;

  /// No description provided for @attachmentDocument.
  ///
  /// In en, this message translates to:
  /// **'Document'**
  String get attachmentDocument;

  /// No description provided for @attachmentAdd.
  ///
  /// In en, this message translates to:
  /// **'Attach'**
  String get attachmentAdd;

  /// No description provided for @msgOptions.
  ///
  /// In en, this message translates to:
  /// **'Options'**
  String get msgOptions;

  /// No description provided for @msgAnnouncements.
  ///
  /// In en, this message translates to:
  /// **'Announcements'**
  String get msgAnnouncements;

  /// No description provided for @msgAnnouncementsEmpty.
  ///
  /// In en, this message translates to:
  /// **'No announcements yet'**
  String get msgAnnouncementsEmpty;

  /// No description provided for @msgAnnouncementsFailed.
  ///
  /// In en, this message translates to:
  /// **'Announcements could not load'**
  String get msgAnnouncementsFailed;

  /// No description provided for @msgNewAnnouncement.
  ///
  /// In en, this message translates to:
  /// **'New announcement'**
  String get msgNewAnnouncement;

  /// No description provided for @msgImportant.
  ///
  /// In en, this message translates to:
  /// **'Important'**
  String get msgImportant;

  /// No description provided for @msgUnread.
  ///
  /// In en, this message translates to:
  /// **'Unread'**
  String get msgUnread;

  /// No description provided for @msgBlockedIntro.
  ///
  /// In en, this message translates to:
  /// **'People you block cannot message you, and you cannot message them. Unblock someone to talk again.'**
  String get msgBlockedIntro;

  /// No description provided for @msgBlockedEmptyDetail.
  ///
  /// In en, this message translates to:
  /// **'If someone makes you uncomfortable, you can block or report them from the conversation\'s options.'**
  String get msgBlockedEmptyDetail;

  /// No description provided for @msgBlockedLabel.
  ///
  /// In en, this message translates to:
  /// **'Blocked'**
  String get msgBlockedLabel;

  /// No description provided for @accountSecurityDetailFull.
  ///
  /// In en, this message translates to:
  /// **'Devices, two-step verification, sign out everywhere, delete account'**
  String get accountSecurityDetailFull;

  /// No description provided for @securityDeleteHeading.
  ///
  /// In en, this message translates to:
  /// **'Delete account'**
  String get securityDeleteHeading;

  /// No description provided for @securityDeleteFooter.
  ///
  /// In en, this message translates to:
  /// **'Deleting your account removes your personal data after 14 days, and you can cancel before then. Records your school must keep stay with the school.'**
  String get securityDeleteFooter;

  /// No description provided for @securityDeleteTitle.
  ///
  /// In en, this message translates to:
  /// **'Delete your account?'**
  String get securityDeleteTitle;

  /// No description provided for @securityDeleteExplain.
  ///
  /// In en, this message translates to:
  /// **'You will see exactly what is removed and what your school keeps, and you will be asked to confirm again. Deletion happens after 14 days and can be cancelled until then.'**
  String get securityDeleteExplain;

  /// No description provided for @securityDeleteContinue.
  ///
  /// In en, this message translates to:
  /// **'Continue'**
  String get securityDeleteContinue;

  /// No description provided for @loginDidNotFinish.
  ///
  /// In en, this message translates to:
  /// **'Sign-in did not finish - the connection may have dropped. Please try again.'**
  String get loginDidNotFinish;

  /// No description provided for @filesSwitchedOff.
  ///
  /// In en, this message translates to:
  /// **'Attachments and voice notes aren\'t switched on for your school yet.'**
  String get filesSwitchedOff;

  /// No description provided for @attachmentRetry.
  ///
  /// In en, this message translates to:
  /// **'Try again'**
  String get attachmentRetry;

  /// No description provided for @attachmentRemove.
  ///
  /// In en, this message translates to:
  /// **'Remove'**
  String get attachmentRemove;

  /// No description provided for @msgVoiceSending.
  ///
  /// In en, this message translates to:
  /// **'Sending voice note…'**
  String get msgVoiceSending;

  /// No description provided for @studentTodayLessonsShortcut.
  ///
  /// In en, this message translates to:
  /// **'Lessons & notebooks'**
  String get studentTodayLessonsShortcut;

  /// No description provided for @studentTodayLessonsShortcutDetail.
  ///
  /// In en, this message translates to:
  /// **'Every class, with your own notes'**
  String get studentTodayLessonsShortcutDetail;

  /// No description provided for @studentTodayWorkShortcutDetail.
  ///
  /// In en, this message translates to:
  /// **'Hand in and check deadlines'**
  String get studentTodayWorkShortcutDetail;

  /// No description provided for @studentTodayFamilyShortcutDetail.
  ///
  /// In en, this message translates to:
  /// **'Your Studafy ID and parent requests'**
  String get studentTodayFamilyShortcutDetail;

  /// No description provided for @studentTodayWorkSection.
  ///
  /// In en, this message translates to:
  /// **'Work to do'**
  String get studentTodayWorkSection;

  /// No description provided for @studentLessonsSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Your classes, their lessons and your notebooks'**
  String get studentLessonsSubtitle;

  /// No description provided for @studentClassLessonsDetail.
  ///
  /// In en, this message translates to:
  /// **'Everything your teacher shared, by date'**
  String get studentClassLessonsDetail;

  /// No description provided for @studentClassNotebook.
  ///
  /// In en, this message translates to:
  /// **'Notebook'**
  String get studentClassNotebook;

  /// No description provided for @studentClassNotebookDetail.
  ///
  /// In en, this message translates to:
  /// **'Your own notes for this class, each one dated'**
  String get studentClassNotebookDetail;

  /// No description provided for @studentClassOpenNotebook.
  ///
  /// In en, this message translates to:
  /// **'Open notebook'**
  String get studentClassOpenNotebook;

  /// No description provided for @planUpgradeTo.
  ///
  /// In en, this message translates to:
  /// **'Upgrade to {plan}'**
  String planUpgradeTo(Object plan);

  /// No description provided for @planAdds.
  ///
  /// In en, this message translates to:
  /// **'{plan} adds:'**
  String planAdds(Object plan);

  /// No description provided for @planEverything.
  ///
  /// In en, this message translates to:
  /// **'You have every study feature.'**
  String get planEverything;

  /// No description provided for @planSeePlans.
  ///
  /// In en, this message translates to:
  /// **'See plans'**
  String get planSeePlans;

  /// No description provided for @workSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Assignments, tests, grades and attendance'**
  String get workSubtitle;

  /// No description provided for @workSectionOpen.
  ///
  /// In en, this message translates to:
  /// **'To do'**
  String get workSectionOpen;

  /// No description provided for @workSectionClosed.
  ///
  /// In en, this message translates to:
  /// **'Past the deadline'**
  String get workSectionClosed;

  /// No description provided for @workSectionGraded.
  ///
  /// In en, this message translates to:
  /// **'Marked'**
  String get workSectionGraded;

  /// No description provided for @workStateOpen.
  ///
  /// In en, this message translates to:
  /// **'Open'**
  String get workStateOpen;

  /// No description provided for @workStateClosed.
  ///
  /// In en, this message translates to:
  /// **'Closed'**
  String get workStateClosed;

  /// No description provided for @workStateGraded.
  ///
  /// In en, this message translates to:
  /// **'Marked'**
  String get workStateGraded;

  /// No description provided for @workView.
  ///
  /// In en, this message translates to:
  /// **'View'**
  String get workView;

  /// No description provided for @submitInstructions.
  ///
  /// In en, this message translates to:
  /// **'Instructions'**
  String get submitInstructions;

  /// No description provided for @submitHandInAgain.
  ///
  /// In en, this message translates to:
  /// **'Hand in again'**
  String get submitHandInAgain;

  /// No description provided for @submitSaving.
  ///
  /// In en, this message translates to:
  /// **'Your work is being handed in…'**
  String get submitSaving;

  /// No description provided for @helperSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Ask about anything you\'re studying'**
  String get helperSubtitle;

  /// No description provided for @helperRecentChats.
  ///
  /// In en, this message translates to:
  /// **'Recent chats'**
  String get helperRecentChats;

  /// No description provided for @helperSeeAll.
  ///
  /// In en, this message translates to:
  /// **'See all'**
  String get helperSeeAll;

  /// No description provided for @helperOffTitle.
  ///
  /// In en, this message translates to:
  /// **'Not switched on yet'**
  String get helperOffTitle;

  /// No description provided for @accountSectionProfile.
  ///
  /// In en, this message translates to:
  /// **'Profile information'**
  String get accountSectionProfile;

  /// No description provided for @accountSectionNotifications.
  ///
  /// In en, this message translates to:
  /// **'Notifications'**
  String get accountSectionNotifications;

  /// No description provided for @accountSectionSubscription.
  ///
  /// In en, this message translates to:
  /// **'Subscription'**
  String get accountSectionSubscription;

  /// No description provided for @accountStudyPlan.
  ///
  /// In en, this message translates to:
  /// **'Study plan'**
  String get accountStudyPlan;

  /// No description provided for @accountStudyPlanDetail.
  ///
  /// In en, this message translates to:
  /// **'Your plan, what it includes, and upgrades'**
  String get accountStudyPlanDetail;

  /// No description provided for @accountTechnicalId.
  ///
  /// In en, this message translates to:
  /// **'Technical account ID'**
  String get accountTechnicalId;

  /// No description provided for @accountTechnicalIdDetail.
  ///
  /// In en, this message translates to:
  /// **'Only needed if Studafy support asks for it. To link with a parent, share your Studafy ID instead.'**
  String get accountTechnicalIdDetail;

  /// No description provided for @accountChangePhoto.
  ///
  /// In en, this message translates to:
  /// **'Change photo'**
  String get accountChangePhoto;

  /// No description provided for @loginWrongRoleStudentTitle.
  ///
  /// In en, this message translates to:
  /// **'This email is a student account'**
  String get loginWrongRoleStudentTitle;

  /// No description provided for @loginWrongRoleStudentBody.
  ///
  /// In en, this message translates to:
  /// **'A student account is only for learning, so it can\'t be used as a teacher or a parent. To teach or to follow a child, sign in with a different email.'**
  String get loginWrongRoleStudentBody;

  /// No description provided for @loginWrongRoleAdultTitle.
  ///
  /// In en, this message translates to:
  /// **'This email isn\'t a student account'**
  String get loginWrongRoleAdultTitle;

  /// No description provided for @loginWrongRoleAdultBody.
  ///
  /// In en, this message translates to:
  /// **'It\'s already used as a {role}, so it can\'t be a student too. A student needs an email of their own.'**
  String loginWrongRoleAdultBody(String role);

  /// No description provided for @loginContinueAs.
  ///
  /// In en, this message translates to:
  /// **'Continue as {role}'**
  String loginContinueAs(String role);

  /// No description provided for @loginUseDifferentEmail.
  ///
  /// In en, this message translates to:
  /// **'Use a different email'**
  String get loginUseDifferentEmail;

  /// No description provided for @accountSwitchRoleTeacherParent.
  ///
  /// In en, this message translates to:
  /// **'Move between teaching and following your children.'**
  String get accountSwitchRoleTeacherParent;

  /// No description provided for @accountName.
  ///
  /// In en, this message translates to:
  /// **'Name'**
  String get accountName;

  /// No description provided for @accountEditName.
  ///
  /// In en, this message translates to:
  /// **'Edit name'**
  String get accountEditName;

  /// No description provided for @accountEditNameTitle.
  ///
  /// In en, this message translates to:
  /// **'Edit your name'**
  String get accountEditNameTitle;

  /// No description provided for @accountNameHelp.
  ///
  /// In en, this message translates to:
  /// **'This is how your teachers, classmates and family see you.'**
  String get accountNameHelp;

  /// No description provided for @accountNameInvalid.
  ///
  /// In en, this message translates to:
  /// **'Enter a name of up to 160 characters.'**
  String get accountNameInvalid;

  /// No description provided for @accountNameSaved.
  ///
  /// In en, this message translates to:
  /// **'Name saved'**
  String get accountNameSaved;

  /// No description provided for @accountNameFailed.
  ///
  /// In en, this message translates to:
  /// **'Your name couldn\'t be saved. Please try again.'**
  String get accountNameFailed;

  /// No description provided for @accountSaveAction.
  ///
  /// In en, this message translates to:
  /// **'Save'**
  String get accountSaveAction;

  /// No description provided for @accountCancelAction.
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get accountCancelAction;

  /// No description provided for @accountPublicIdDetail.
  ///
  /// In en, this message translates to:
  /// **'Studafy support may ask for this number. It can\'t be used to see your account or to link to a child.'**
  String get accountPublicIdDetail;

  /// No description provided for @navAnnouncements.
  ///
  /// In en, this message translates to:
  /// **'Announcements'**
  String get navAnnouncements;

  /// No description provided for @announcementsSubtitle.
  ///
  /// In en, this message translates to:
  /// **'News from your children\'s schools'**
  String get announcementsSubtitle;

  /// No description provided for @announcementsAllChildren.
  ///
  /// In en, this message translates to:
  /// **'All children'**
  String get announcementsAllChildren;

  /// No description provided for @announcementsNoChildren.
  ///
  /// In en, this message translates to:
  /// **'Link a child to see their school\'s announcements.'**
  String get announcementsNoChildren;

  /// No description provided for @announcementsFrom.
  ///
  /// In en, this message translates to:
  /// **'{school} · {children}'**
  String announcementsFrom(String school, String children);

  /// No description provided for @learningSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Lessons, work, tests, grades and attendance'**
  String get learningSubtitle;

  /// No description provided for @learningFilterByChild.
  ///
  /// In en, this message translates to:
  /// **'Filter by child'**
  String get learningFilterByChild;

  /// No description provided for @learningNoChildrenTitle.
  ///
  /// In en, this message translates to:
  /// **'No child linked yet'**
  String get learningNoChildrenTitle;

  /// No description provided for @learningNoChildrenBody.
  ///
  /// In en, this message translates to:
  /// **'Link a child from Today to follow their lessons, work and grades here.'**
  String get learningNoChildrenBody;

  /// No description provided for @parentTodaySubtitle.
  ///
  /// In en, this message translates to:
  /// **'Your children\'s day at a glance'**
  String get parentTodaySubtitle;

  /// No description provided for @parentQuickLink.
  ///
  /// In en, this message translates to:
  /// **'Link a child'**
  String get parentQuickLink;

  /// No description provided for @parentQuickLearning.
  ///
  /// In en, this message translates to:
  /// **'Learning'**
  String get parentQuickLearning;

  /// No description provided for @parentQuickAnnouncements.
  ///
  /// In en, this message translates to:
  /// **'Announcements'**
  String get parentQuickAnnouncements;

  /// No description provided for @parentQuickMessages.
  ///
  /// In en, this message translates to:
  /// **'Message a teacher'**
  String get parentQuickMessages;

  /// No description provided for @parentChildrenSection.
  ///
  /// In en, this message translates to:
  /// **'Your children'**
  String get parentChildrenSection;

  /// No description provided for @parentNoChildrenTitle.
  ///
  /// In en, this message translates to:
  /// **'Link your first child'**
  String get parentNoChildrenTitle;

  /// No description provided for @parentNoChildrenBody.
  ///
  /// In en, this message translates to:
  /// **'Ask your child for their Studafy ID. They approve the request on their own device.'**
  String get parentNoChildrenBody;

  /// No description provided for @parentChildOpen.
  ///
  /// In en, this message translates to:
  /// **'Open'**
  String get parentChildOpen;

  /// No description provided for @parentLinkSearching.
  ///
  /// In en, this message translates to:
  /// **'Checking…'**
  String get parentLinkSearching;

  /// No description provided for @familyPlusNoPlan.
  ///
  /// In en, this message translates to:
  /// **'No Family+ plan yet'**
  String get familyPlusNoPlan;

  /// No description provided for @familyPlusCoveredCount.
  ///
  /// In en, this message translates to:
  /// **'Covers {count} of your children'**
  String familyPlusCoveredCount(int count);

  /// No description provided for @familyPlusEnds.
  ///
  /// In en, this message translates to:
  /// **'Active until {date}'**
  String familyPlusEnds(String date);

  /// No description provided for @familyPlusWhatYouGet.
  ///
  /// In en, this message translates to:
  /// **'What Family+ adds'**
  String get familyPlusWhatYouGet;

  /// No description provided for @familyPlusPlansTitle.
  ///
  /// In en, this message translates to:
  /// **'Choose a plan'**
  String get familyPlusPlansTitle;

  /// No description provided for @familyPlusManagePlan.
  ///
  /// In en, this message translates to:
  /// **'Plan'**
  String get familyPlusManagePlan;

  /// No description provided for @famLinkCheckFailed.
  ///
  /// In en, this message translates to:
  /// **'The security check didn\'t go through. Please try again.'**
  String get famLinkCheckFailed;

  /// No description provided for @famLinkAlready.
  ///
  /// In en, this message translates to:
  /// **'You\'ve already asked to link this child, or they\'re linked already.'**
  String get famLinkAlready;

  /// No description provided for @famLinkIdHelp.
  ///
  /// In en, this message translates to:
  /// **'Your child finds it on their Profile, under Your Studafy ID.'**
  String get famLinkIdHelp;

  /// No description provided for @familyPlusCurrentPlan.
  ///
  /// In en, this message translates to:
  /// **'Current plan'**
  String get familyPlusCurrentPlan;

  /// No description provided for @paperGradesOtherMark.
  ///
  /// In en, this message translates to:
  /// **'Other mark'**
  String get paperGradesOtherMark;

  /// No description provided for @paperGradesEnterScore.
  ///
  /// In en, this message translates to:
  /// **'Enter a score instead'**
  String get paperGradesEnterScore;

  /// No description provided for @courseworkInvalidState.
  ///
  /// In en, this message translates to:
  /// **'That can\'t be done for this right now.'**
  String get courseworkInvalidState;

  /// No description provided for @attendanceNotOnTimetable.
  ///
  /// In en, this message translates to:
  /// **'This lesson wasn\'t on the class\'s timetable on that date, so it has no register.'**
  String get attendanceNotOnTimetable;

  /// No description provided for @attendanceSaveFailed.
  ///
  /// In en, this message translates to:
  /// **'The attendance couldn\'t be saved. Please try again.'**
  String get attendanceSaveFailed;

  /// No description provided for @loginOtherRoleTitle.
  ///
  /// In en, this message translates to:
  /// **'This email is already a {role} account'**
  String loginOtherRoleTitle(String role);

  /// No description provided for @loginOtherRoleBody.
  ///
  /// In en, this message translates to:
  /// **'Continue as a {own}, or also use this account as a {chosen}. You can switch between the two any time from your profile.'**
  String loginOtherRoleBody(String own, String chosen);

  /// No description provided for @loginAlsoUseAs.
  ///
  /// In en, this message translates to:
  /// **'Also use it as a {role}'**
  String loginAlsoUseAs(String role);

  /// No description provided for @attachmentsTitle.
  ///
  /// In en, this message translates to:
  /// **'Attachments'**
  String get attachmentsTitle;

  /// No description provided for @attachmentsLinks.
  ///
  /// In en, this message translates to:
  /// **'Links'**
  String get attachmentsLinks;

  /// No description provided for @attachmentsFiles.
  ///
  /// In en, this message translates to:
  /// **'Files'**
  String get attachmentsFiles;

  /// No description provided for @attachmentsAddLink.
  ///
  /// In en, this message translates to:
  /// **'Add link'**
  String get attachmentsAddLink;

  /// No description provided for @attachmentsLinkTitle.
  ///
  /// In en, this message translates to:
  /// **'Title readers see'**
  String get attachmentsLinkTitle;

  /// No description provided for @attachmentsLinkAddress.
  ///
  /// In en, this message translates to:
  /// **'Address (https://…)'**
  String get attachmentsLinkAddress;

  /// No description provided for @attachmentsLinkTitleRequired.
  ///
  /// In en, this message translates to:
  /// **'Give the link a title.'**
  String get attachmentsLinkTitleRequired;

  /// No description provided for @attachmentsRemove.
  ///
  /// In en, this message translates to:
  /// **'Remove'**
  String get attachmentsRemove;

  /// No description provided for @attachmentsKeep.
  ///
  /// In en, this message translates to:
  /// **'Keep'**
  String get attachmentsKeep;

  /// No description provided for @attachmentsRemovedOnSave.
  ///
  /// In en, this message translates to:
  /// **'Removed when you save'**
  String get attachmentsRemovedOnSave;

  /// No description provided for @attachmentsUploading.
  ///
  /// In en, this message translates to:
  /// **'Wait for the files to finish uploading.'**
  String get attachmentsUploading;

  /// No description provided for @attachmentsFailed.
  ///
  /// In en, this message translates to:
  /// **'Retry or remove the files and links marked as failed or not accepted.'**
  String get attachmentsFailed;

  /// No description provided for @attachmentsTooManyLinks.
  ///
  /// In en, this message translates to:
  /// **'You can add up to {count} links.'**
  String attachmentsTooManyLinks(int count);

  /// No description provided for @attachmentsImagePreview.
  ///
  /// In en, this message translates to:
  /// **'Tap to view'**
  String get attachmentsImagePreview;

  /// No description provided for @attachmentsChecking.
  ///
  /// In en, this message translates to:
  /// **'Being checked'**
  String get attachmentsChecking;

  /// No description provided for @attachmentsNotAvailable.
  ///
  /// In en, this message translates to:
  /// **'Not available'**
  String get attachmentsNotAvailable;

  /// No description provided for @questionKindSingle.
  ///
  /// In en, this message translates to:
  /// **'Single answer'**
  String get questionKindSingle;

  /// No description provided for @questionKindMultiple.
  ///
  /// In en, this message translates to:
  /// **'Multiple answers'**
  String get questionKindMultiple;

  /// No description provided for @questionKindTrueFalse.
  ///
  /// In en, this message translates to:
  /// **'True or false'**
  String get questionKindTrueFalse;

  /// No description provided for @questionKindShort.
  ///
  /// In en, this message translates to:
  /// **'Short answer'**
  String get questionKindShort;

  /// No description provided for @questionKindEssay.
  ///
  /// In en, this message translates to:
  /// **'Essay'**
  String get questionKindEssay;

  /// No description provided for @builderNewTitle.
  ///
  /// In en, this message translates to:
  /// **'New online assessment'**
  String get builderNewTitle;

  /// No description provided for @builderEditTitle.
  ///
  /// In en, this message translates to:
  /// **'Edit assessment'**
  String get builderEditTitle;

  /// No description provided for @builderTitleLabel.
  ///
  /// In en, this message translates to:
  /// **'Title'**
  String get builderTitleLabel;

  /// No description provided for @builderClassLabel.
  ///
  /// In en, this message translates to:
  /// **'Class'**
  String get builderClassLabel;

  /// No description provided for @builderCategoryLabel.
  ///
  /// In en, this message translates to:
  /// **'Type'**
  String get builderCategoryLabel;

  /// No description provided for @builderCategoryQuiz.
  ///
  /// In en, this message translates to:
  /// **'Quiz'**
  String get builderCategoryQuiz;

  /// No description provided for @builderCategoryExam.
  ///
  /// In en, this message translates to:
  /// **'Exam'**
  String get builderCategoryExam;

  /// No description provided for @builderCategoryAssessment.
  ///
  /// In en, this message translates to:
  /// **'Assessment'**
  String get builderCategoryAssessment;

  /// No description provided for @builderQuestions.
  ///
  /// In en, this message translates to:
  /// **'Questions'**
  String get builderQuestions;

  /// No description provided for @builderAddQuestion.
  ///
  /// In en, this message translates to:
  /// **'Add question'**
  String get builderAddQuestion;

  /// No description provided for @builderTotal.
  ///
  /// In en, this message translates to:
  /// **'Total points: {points}'**
  String builderTotal(String points);

  /// No description provided for @builderQuestionNumber.
  ///
  /// In en, this message translates to:
  /// **'Question {number}'**
  String builderQuestionNumber(int number);

  /// No description provided for @builderPrompt.
  ///
  /// In en, this message translates to:
  /// **'Question'**
  String get builderPrompt;

  /// No description provided for @builderPoints.
  ///
  /// In en, this message translates to:
  /// **'Points'**
  String get builderPoints;

  /// No description provided for @builderRequired.
  ///
  /// In en, this message translates to:
  /// **'Required'**
  String get builderRequired;

  /// No description provided for @builderOption.
  ///
  /// In en, this message translates to:
  /// **'Option {number}'**
  String builderOption(int number);

  /// No description provided for @builderAddOption.
  ///
  /// In en, this message translates to:
  /// **'Add option'**
  String get builderAddOption;

  /// No description provided for @builderRemoveOption.
  ///
  /// In en, this message translates to:
  /// **'Remove option'**
  String get builderRemoveOption;

  /// No description provided for @builderMarkCorrectOne.
  ///
  /// In en, this message translates to:
  /// **'Tick the correct answer.'**
  String get builderMarkCorrectOne;

  /// No description provided for @builderMarkCorrectAll.
  ///
  /// In en, this message translates to:
  /// **'Tick every correct answer.'**
  String get builderMarkCorrectAll;

  /// No description provided for @builderTrue.
  ///
  /// In en, this message translates to:
  /// **'True'**
  String get builderTrue;

  /// No description provided for @builderFalse.
  ///
  /// In en, this message translates to:
  /// **'False'**
  String get builderFalse;

  /// No description provided for @builderCorrectIs.
  ///
  /// In en, this message translates to:
  /// **'The correct answer is'**
  String get builderCorrectIs;

  /// No description provided for @builderAccepted.
  ///
  /// In en, this message translates to:
  /// **'Accepted answers, one per line'**
  String get builderAccepted;

  /// No description provided for @builderAcceptedHint.
  ///
  /// In en, this message translates to:
  /// **'Leave empty to mark it yourself.'**
  String get builderAcceptedHint;

  /// No description provided for @builderModelAnswer.
  ///
  /// In en, this message translates to:
  /// **'Model answer'**
  String get builderModelAnswer;

  /// No description provided for @builderGuidance.
  ///
  /// In en, this message translates to:
  /// **'Marking guidance'**
  String get builderGuidance;

  /// No description provided for @builderPrivateHint.
  ///
  /// In en, this message translates to:
  /// **'Only you see this until answers are released.'**
  String get builderPrivateHint;

  /// No description provided for @builderMoveUp.
  ///
  /// In en, this message translates to:
  /// **'Move up'**
  String get builderMoveUp;

  /// No description provided for @builderMoveDown.
  ///
  /// In en, this message translates to:
  /// **'Move down'**
  String get builderMoveDown;

  /// No description provided for @builderDuplicate.
  ///
  /// In en, this message translates to:
  /// **'Duplicate'**
  String get builderDuplicate;

  /// No description provided for @builderDelete.
  ///
  /// In en, this message translates to:
  /// **'Delete'**
  String get builderDelete;

  /// No description provided for @builderSettings.
  ///
  /// In en, this message translates to:
  /// **'Settings'**
  String get builderSettings;

  /// No description provided for @builderOpens.
  ///
  /// In en, this message translates to:
  /// **'Opens'**
  String get builderOpens;

  /// No description provided for @builderCloses.
  ///
  /// In en, this message translates to:
  /// **'Closes'**
  String get builderCloses;

  /// No description provided for @builderNotSet.
  ///
  /// In en, this message translates to:
  /// **'Not set'**
  String get builderNotSet;

  /// No description provided for @builderNow.
  ///
  /// In en, this message translates to:
  /// **'Now'**
  String get builderNow;

  /// No description provided for @builderAttempts.
  ///
  /// In en, this message translates to:
  /// **'Attempts allowed'**
  String get builderAttempts;

  /// No description provided for @builderPolicy.
  ///
  /// In en, this message translates to:
  /// **'Which attempt counts'**
  String get builderPolicy;

  /// No description provided for @builderPolicyBest.
  ///
  /// In en, this message translates to:
  /// **'The best'**
  String get builderPolicyBest;

  /// No description provided for @builderPolicyLatest.
  ///
  /// In en, this message translates to:
  /// **'The latest'**
  String get builderPolicyLatest;

  /// No description provided for @builderRelease.
  ///
  /// In en, this message translates to:
  /// **'When students see the answers'**
  String get builderRelease;

  /// No description provided for @builderReleaseAfterClose.
  ///
  /// In en, this message translates to:
  /// **'After it closes for everyone'**
  String get builderReleaseAfterClose;

  /// No description provided for @builderReleaseAfterGrading.
  ///
  /// In en, this message translates to:
  /// **'After marking is done and grades are published'**
  String get builderReleaseAfterGrading;

  /// No description provided for @builderReleaseManual.
  ///
  /// In en, this message translates to:
  /// **'When I release them'**
  String get builderReleaseManual;

  /// No description provided for @builderReleaseNote.
  ///
  /// In en, this message translates to:
  /// **'Answers are never shown while any student can still attempt it.'**
  String get builderReleaseNote;

  /// No description provided for @builderMaterial.
  ///
  /// In en, this message translates to:
  /// **'Material for the whole assessment'**
  String get builderMaterial;

  /// No description provided for @builderPreview.
  ///
  /// In en, this message translates to:
  /// **'Preview as a student'**
  String get builderPreview;

  /// No description provided for @builderSaveDraft.
  ///
  /// In en, this message translates to:
  /// **'Save draft'**
  String get builderSaveDraft;

  /// No description provided for @builderPublish.
  ///
  /// In en, this message translates to:
  /// **'Publish'**
  String get builderPublish;

  /// No description provided for @builderSaved.
  ///
  /// In en, this message translates to:
  /// **'Saved.'**
  String get builderSaved;

  /// No description provided for @builderPublished.
  ///
  /// In en, this message translates to:
  /// **'Published to the class.'**
  String get builderPublished;

  /// No description provided for @builderSaveFailed.
  ///
  /// In en, this message translates to:
  /// **'Could not save. Check the questions and try again.'**
  String get builderSaveFailed;

  /// No description provided for @builderQuestionAttachmentRefused.
  ///
  /// In en, this message translates to:
  /// **'Question {number}: a file or link was not accepted. Remove it, then save again.'**
  String builderQuestionAttachmentRefused(int number);

  /// No description provided for @builderLocked.
  ///
  /// In en, this message translates to:
  /// **'A student has already submitted, so the questions can no longer change. Settings still can.'**
  String get builderLocked;

  /// No description provided for @builderNeedTitle.
  ///
  /// In en, this message translates to:
  /// **'Give it a title.'**
  String get builderNeedTitle;

  /// No description provided for @builderNeedClass.
  ///
  /// In en, this message translates to:
  /// **'Choose a class.'**
  String get builderNeedClass;

  /// No description provided for @builderNeedQuestion.
  ///
  /// In en, this message translates to:
  /// **'Add at least one question.'**
  String get builderNeedQuestion;

  /// No description provided for @builderNeedClose.
  ///
  /// In en, this message translates to:
  /// **'Set when it closes.'**
  String get builderNeedClose;

  /// No description provided for @builderCloseAfterOpen.
  ///
  /// In en, this message translates to:
  /// **'It must close after it opens.'**
  String get builderCloseAfterOpen;

  /// No description provided for @builderProblemPrompt.
  ///
  /// In en, this message translates to:
  /// **'Question {number}: write the question.'**
  String builderProblemPrompt(int number);

  /// No description provided for @builderProblemPoints.
  ///
  /// In en, this message translates to:
  /// **'Question {number}: give it points.'**
  String builderProblemPoints(int number);

  /// No description provided for @builderProblemOptions.
  ///
  /// In en, this message translates to:
  /// **'Question {number}: add at least two filled-in options.'**
  String builderProblemOptions(int number);

  /// No description provided for @builderProblemCorrect.
  ///
  /// In en, this message translates to:
  /// **'Question {number}: mark the correct answer.'**
  String builderProblemCorrect(int number);

  /// No description provided for @builderProblemTrueFalse.
  ///
  /// In en, this message translates to:
  /// **'Question {number}: choose true or false as the answer.'**
  String builderProblemTrueFalse(int number);

  /// No description provided for @builderProblemFiles.
  ///
  /// In en, this message translates to:
  /// **'Question {number}: wait for its files to upload.'**
  String builderProblemFiles(int number);

  /// No description provided for @builderOnlineChoice.
  ///
  /// In en, this message translates to:
  /// **'Answered online'**
  String get builderOnlineChoice;

  /// No description provided for @builderOnlineChoiceDetail.
  ///
  /// In en, this message translates to:
  /// **'Students answer in the app; choice questions are marked for you.'**
  String get builderOnlineChoiceDetail;

  /// No description provided for @builderPaperChoice.
  ///
  /// In en, this message translates to:
  /// **'On paper'**
  String get builderPaperChoice;

  /// No description provided for @builderPaperChoiceDetail.
  ///
  /// In en, this message translates to:
  /// **'Students sit it in class; you enter the marks.'**
  String get builderPaperChoiceDetail;

  /// No description provided for @takeOpens.
  ///
  /// In en, this message translates to:
  /// **'Opens {time}'**
  String takeOpens(String time);

  /// No description provided for @takeCloses.
  ///
  /// In en, this message translates to:
  /// **'Closes {time}'**
  String takeCloses(String time);

  /// No description provided for @takeClosed.
  ///
  /// In en, this message translates to:
  /// **'Closed'**
  String get takeClosed;

  /// No description provided for @takeNotOpen.
  ///
  /// In en, this message translates to:
  /// **'Not open yet'**
  String get takeNotOpen;

  /// No description provided for @takeAttemptsLeft.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =0{No attempts left} =1{1 attempt left} other{{count} attempts left}}'**
  String takeAttemptsLeft(int count);

  /// No description provided for @takeStart.
  ///
  /// In en, this message translates to:
  /// **'Start'**
  String get takeStart;

  /// No description provided for @takeAgain.
  ///
  /// In en, this message translates to:
  /// **'Try again'**
  String get takeAgain;

  /// No description provided for @takeSubmit.
  ///
  /// In en, this message translates to:
  /// **'Submit answers'**
  String get takeSubmit;

  /// No description provided for @takeSubmitTitle.
  ///
  /// In en, this message translates to:
  /// **'Submit your answers?'**
  String get takeSubmitTitle;

  /// No description provided for @takeSubmitBody.
  ///
  /// In en, this message translates to:
  /// **'You can\'t change them after submitting.'**
  String get takeSubmitBody;

  /// No description provided for @takeLeaveTitle.
  ///
  /// In en, this message translates to:
  /// **'Leave without submitting?'**
  String get takeLeaveTitle;

  /// No description provided for @takeLeaveBody.
  ///
  /// In en, this message translates to:
  /// **'Your answers will not be kept.'**
  String get takeLeaveBody;

  /// No description provided for @takeLeave.
  ///
  /// In en, this message translates to:
  /// **'Leave'**
  String get takeLeave;

  /// No description provided for @takeStay.
  ///
  /// In en, this message translates to:
  /// **'Stay'**
  String get takeStay;

  /// No description provided for @takeMissing.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{Answer the required question that is left.} other{Answer the {count} required questions that are left.}}'**
  String takeMissing(int count);

  /// No description provided for @takeSubmitted.
  ///
  /// In en, this message translates to:
  /// **'Submitted. Your teacher will release the results.'**
  String get takeSubmitted;

  /// No description provided for @takeSubmitFailed.
  ///
  /// In en, this message translates to:
  /// **'Your answers were not sent. Check your connection and try again.'**
  String get takeSubmitFailed;

  /// No description provided for @takeWindowClosed.
  ///
  /// In en, this message translates to:
  /// **'This has closed, so it can\'t be submitted.'**
  String get takeWindowClosed;

  /// No description provided for @takeRequired.
  ///
  /// In en, this message translates to:
  /// **'Required'**
  String get takeRequired;

  /// No description provided for @takeOptional.
  ///
  /// In en, this message translates to:
  /// **'Optional'**
  String get takeOptional;

  /// No description provided for @takeTypeAnswer.
  ///
  /// In en, this message translates to:
  /// **'Your answer'**
  String get takeTypeAnswer;

  /// No description provided for @takeChooseOne.
  ///
  /// In en, this message translates to:
  /// **'Choose one'**
  String get takeChooseOne;

  /// No description provided for @takeChooseAll.
  ///
  /// In en, this message translates to:
  /// **'Choose all that apply'**
  String get takeChooseAll;

  /// No description provided for @takePoints.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 point} other{{count} points}}'**
  String takePoints(num count);

  /// No description provided for @takeYourAttempts.
  ///
  /// In en, this message translates to:
  /// **'Your attempts'**
  String get takeYourAttempts;

  /// No description provided for @takeAttemptLine.
  ///
  /// In en, this message translates to:
  /// **'Attempt {number} · {time}'**
  String takeAttemptLine(int number, String time);

  /// No description provided for @takeNotReleased.
  ///
  /// In en, this message translates to:
  /// **'Answers will appear here once your teacher releases them.'**
  String get takeNotReleased;

  /// No description provided for @takeGrade.
  ///
  /// In en, this message translates to:
  /// **'Grade'**
  String get takeGrade;

  /// No description provided for @takeGradePending.
  ///
  /// In en, this message translates to:
  /// **'Not published yet'**
  String get takeGradePending;

  /// No description provided for @takeFeedback.
  ///
  /// In en, this message translates to:
  /// **'Teacher\'s feedback'**
  String get takeFeedback;

  /// No description provided for @takeAnswers.
  ///
  /// In en, this message translates to:
  /// **'Answers'**
  String get takeAnswers;

  /// No description provided for @takeYourAnswer.
  ///
  /// In en, this message translates to:
  /// **'Your answer'**
  String get takeYourAnswer;

  /// No description provided for @takeCorrectAnswer.
  ///
  /// In en, this message translates to:
  /// **'Correct answer'**
  String get takeCorrectAnswer;

  /// No description provided for @takeAcceptedAnswers.
  ///
  /// In en, this message translates to:
  /// **'Accepted answers'**
  String get takeAcceptedAnswers;

  /// No description provided for @takeNoAnswer.
  ///
  /// In en, this message translates to:
  /// **'No answer'**
  String get takeNoAnswer;

  /// No description provided for @takeBeingMarked.
  ///
  /// In en, this message translates to:
  /// **'Being marked'**
  String get takeBeingMarked;

  /// No description provided for @takeScore.
  ///
  /// In en, this message translates to:
  /// **'{score} of {max}'**
  String takeScore(String score, String max);

  /// No description provided for @takeLoadFailed.
  ///
  /// In en, this message translates to:
  /// **'This could not load.'**
  String get takeLoadFailed;

  /// No description provided for @takeRetry.
  ///
  /// In en, this message translates to:
  /// **'Try again'**
  String get takeRetry;

  /// No description provided for @takeReadOnly.
  ///
  /// In en, this message translates to:
  /// **'You can see your child\'s results here. Only they can sit it.'**
  String get takeReadOnly;

  /// No description provided for @takeOpenAssessment.
  ///
  /// In en, this message translates to:
  /// **'Open'**
  String get takeOpenAssessment;

  /// No description provided for @markSubmissions.
  ///
  /// In en, this message translates to:
  /// **'Submissions'**
  String get markSubmissions;

  /// No description provided for @markNone.
  ///
  /// In en, this message translates to:
  /// **'No one has submitted yet.'**
  String get markNone;

  /// No description provided for @markNeeds.
  ///
  /// In en, this message translates to:
  /// **'Needs marking'**
  String get markNeeds;

  /// No description provided for @markDone.
  ///
  /// In en, this message translates to:
  /// **'Marked: {score} of {max}'**
  String markDone(String score, String max);

  /// No description provided for @markAuto.
  ///
  /// In en, this message translates to:
  /// **'Marked automatically'**
  String get markAuto;

  /// No description provided for @markScoreLabel.
  ///
  /// In en, this message translates to:
  /// **'Score (out of {max})'**
  String markScoreLabel(String max);

  /// No description provided for @markAnswerFeedback.
  ///
  /// In en, this message translates to:
  /// **'Comment on this answer'**
  String get markAnswerFeedback;

  /// No description provided for @markOverallFeedback.
  ///
  /// In en, this message translates to:
  /// **'Feedback for the student'**
  String get markOverallFeedback;

  /// No description provided for @markSave.
  ///
  /// In en, this message translates to:
  /// **'Save marks'**
  String get markSave;

  /// No description provided for @markSaved.
  ///
  /// In en, this message translates to:
  /// **'Marks saved.'**
  String get markSaved;

  /// No description provided for @markSaveFailed.
  ///
  /// In en, this message translates to:
  /// **'Marks were not saved. Check each score and try again.'**
  String get markSaveFailed;

  /// No description provided for @markScoreInvalid.
  ///
  /// In en, this message translates to:
  /// **'Enter a score from 0 to {max}.'**
  String markScoreInvalid(String max);

  /// No description provided for @markPublishGrades.
  ///
  /// In en, this message translates to:
  /// **'Publish grades'**
  String get markPublishGrades;

  /// No description provided for @markPublished.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 grade published.} other{{count} grades published.}}'**
  String markPublished(int count);

  /// No description provided for @markNothingToPublish.
  ///
  /// In en, this message translates to:
  /// **'Nothing is ready to publish yet.'**
  String get markNothingToPublish;

  /// No description provided for @markReleaseNow.
  ///
  /// In en, this message translates to:
  /// **'Release answers now'**
  String get markReleaseNow;

  /// No description provided for @markReleased.
  ///
  /// In en, this message translates to:
  /// **'Answers released.'**
  String get markReleased;

  /// No description provided for @markReleaseRefused.
  ///
  /// In en, this message translates to:
  /// **'Answers can only be released once it has closed for everyone.'**
  String get markReleaseRefused;

  /// No description provided for @markEditQuestions.
  ///
  /// In en, this message translates to:
  /// **'Edit questions and settings'**
  String get markEditQuestions;

  /// No description provided for @markGrantAccess.
  ///
  /// In en, this message translates to:
  /// **'More time or attempts'**
  String get markGrantAccess;

  /// No description provided for @markGrantStudent.
  ///
  /// In en, this message translates to:
  /// **'Student'**
  String get markGrantStudent;

  /// No description provided for @markGrantUntil.
  ///
  /// In en, this message translates to:
  /// **'Open for them until'**
  String get markGrantUntil;

  /// No description provided for @markGrantExtra.
  ///
  /// In en, this message translates to:
  /// **'Extra attempts'**
  String get markGrantExtra;

  /// No description provided for @markGrantGive.
  ///
  /// In en, this message translates to:
  /// **'Give'**
  String get markGrantGive;

  /// No description provided for @markGranted.
  ///
  /// In en, this message translates to:
  /// **'Done.'**
  String get markGranted;

  /// No description provided for @markGrantFailed.
  ///
  /// In en, this message translates to:
  /// **'That could not be given.'**
  String get markGrantFailed;

  /// No description provided for @markAnswersCount.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 submission} other{{count} submissions}}'**
  String markAnswersCount(int count);

  /// No description provided for @markOpenSubmissions.
  ///
  /// In en, this message translates to:
  /// **'Submissions and marking'**
  String get markOpenSubmissions;

  /// No description provided for @paperShared.
  ///
  /// In en, this message translates to:
  /// **'For the whole class'**
  String get paperShared;

  /// No description provided for @paperSharedHint.
  ///
  /// In en, this message translates to:
  /// **'The question paper, a mark scheme or general feedback. Each student sees these once their own mark is published.'**
  String get paperSharedHint;

  /// No description provided for @paperForStudent.
  ///
  /// In en, this message translates to:
  /// **'For {name}'**
  String paperForStudent(String name);

  /// No description provided for @paperForStudentHint.
  ///
  /// In en, this message translates to:
  /// **'Only this student and their parents see these, once the mark is published.'**
  String get paperForStudentHint;

  /// No description provided for @paperAttachments.
  ///
  /// In en, this message translates to:
  /// **'Attachments'**
  String get paperAttachments;

  /// No description provided for @paperAttachmentsSaved.
  ///
  /// In en, this message translates to:
  /// **'Attachments saved.'**
  String get paperAttachmentsSaved;

  /// No description provided for @paperAttachmentsFailed.
  ///
  /// In en, this message translates to:
  /// **'Attachments were not saved.'**
  String get paperAttachmentsFailed;

  /// No description provided for @paperAttachmentsSaveFirst.
  ///
  /// In en, this message translates to:
  /// **'Save the marks first, then change attachments.'**
  String get paperAttachmentsSaveFirst;

  /// No description provided for @paperSave.
  ///
  /// In en, this message translates to:
  /// **'Save'**
  String get paperSave;

  /// No description provided for @gradeYourFiles.
  ///
  /// In en, this message translates to:
  /// **'Your files'**
  String get gradeYourFiles;

  /// No description provided for @gradeClassFiles.
  ///
  /// In en, this message translates to:
  /// **'For the class'**
  String get gradeClassFiles;

  /// No description provided for @helperTokensUsed.
  ///
  /// In en, this message translates to:
  /// **'You\'ve reached your AI usage limit. Your question is still here.'**
  String get helperTokensUsed;

  /// No description provided for @helperTokensUsedUntil.
  ///
  /// In en, this message translates to:
  /// **'You\'ve reached your AI usage limit. It resets on {date} - your question is still here.'**
  String helperTokensUsedUntil(String date);

  /// No description provided for @helperStillAnswering.
  ///
  /// In en, this message translates to:
  /// **'This question is still being answered.'**
  String get helperStillAnswering;

  /// No description provided for @helperCouldNotRead.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t read {name}: {reason}.'**
  String helperCouldNotRead(String name, String reason);

  /// No description provided for @helperSources.
  ///
  /// In en, this message translates to:
  /// **'Sources'**
  String get helperSources;

  /// No description provided for @helperCitationPage.
  ///
  /// In en, this message translates to:
  /// **'p. {n}'**
  String helperCitationPage(int n);

  /// No description provided for @helperCitationSlide.
  ///
  /// In en, this message translates to:
  /// **'slide {n}'**
  String helperCitationSlide(int n);

  /// No description provided for @helperCitationLesson.
  ///
  /// In en, this message translates to:
  /// **'{name} (lesson)'**
  String helperCitationLesson(String name);

  /// No description provided for @helperCitationNote.
  ///
  /// In en, this message translates to:
  /// **'{name} (your note)'**
  String helperCitationNote(String name);

  /// No description provided for @helperAskAboutLesson.
  ///
  /// In en, this message translates to:
  /// **'Ask the AI helper'**
  String get helperAskAboutLesson;

  /// No description provided for @pickerOneFile.
  ///
  /// In en, this message translates to:
  /// **'Or one file or link'**
  String get pickerOneFile;

  /// No description provided for @tokensWhatAreThey.
  ///
  /// In en, this message translates to:
  /// **'How does AI usage work?'**
  String get tokensWhatAreThey;

  /// No description provided for @tokensExplained.
  ///
  /// In en, this message translates to:
  /// **'Every question, summary, quiz, flashcard set and notebook uses some of your plan\'s AI usage. Longer files, longer chats and photos use more. Everything shares one allowance, shown as a bar, and it resets on a set date. When it runs out, your work is kept and you can carry on after it resets.'**
  String get tokensExplained;

  /// No description provided for @tokensGuideTitle.
  ///
  /// In en, this message translates to:
  /// **'What uses a little, and what uses more'**
  String get tokensGuideTitle;

  /// No description provided for @tokensGuideShortQuestion.
  ///
  /// In en, this message translates to:
  /// **'A short question'**
  String get tokensGuideShortQuestion;

  /// No description provided for @tokensGuideLessonQuestion.
  ///
  /// In en, this message translates to:
  /// **'A question about a lesson\'s files'**
  String get tokensGuideLessonQuestion;

  /// No description provided for @tokensGuideNotes.
  ///
  /// In en, this message translates to:
  /// **'Notes, a quiz or flashcards from a lesson'**
  String get tokensGuideNotes;

  /// No description provided for @tokensGuidePhoto.
  ///
  /// In en, this message translates to:
  /// **'A whiteboard or homework photo'**
  String get tokensGuidePhoto;

  /// No description provided for @tokensGuideEstimate.
  ///
  /// In en, this message translates to:
  /// **'Your usage is shown as a bar - there is nothing to count.'**
  String get tokensGuideEstimate;

  /// No description provided for @readingTitle.
  ///
  /// In en, this message translates to:
  /// **'Reading for the AI helper'**
  String get readingTitle;

  /// No description provided for @readingExplained.
  ///
  /// In en, this message translates to:
  /// **'Files and links are read once so the AI helper can answer from them. Scanned pages and pictures are read too, within the school\'s monthly reading limit.'**
  String get readingExplained;

  /// No description provided for @readingReady.
  ///
  /// In en, this message translates to:
  /// **'Ready for the AI helper'**
  String get readingReady;

  /// No description provided for @readingPartly.
  ///
  /// In en, this message translates to:
  /// **'Partly read - some pages were not read'**
  String get readingPartly;

  /// No description provided for @readingStateProcessing.
  ///
  /// In en, this message translates to:
  /// **'Reading…'**
  String get readingStateProcessing;

  /// No description provided for @readingStateCannot.
  ///
  /// In en, this message translates to:
  /// **'Can\'t be read: {reason}'**
  String readingStateCannot(String reason);

  /// No description provided for @readingRetry.
  ///
  /// In en, this message translates to:
  /// **'Read again'**
  String get readingRetry;

  /// No description provided for @readingRetried.
  ///
  /// In en, this message translates to:
  /// **'It will be read again shortly.'**
  String get readingRetried;

  /// No description provided for @readingRetryFailed.
  ///
  /// In en, this message translates to:
  /// **'That could not be done. Try again.'**
  String get readingRetryFailed;

  /// No description provided for @readingLoadFailed.
  ///
  /// In en, this message translates to:
  /// **'Could not check the files.'**
  String get readingLoadFailed;

  /// No description provided for @readingNothing.
  ///
  /// In en, this message translates to:
  /// **'This lesson has no files or links.'**
  String get readingNothing;

  /// No description provided for @readingProcessing.
  ///
  /// In en, this message translates to:
  /// **'it is still being read'**
  String get readingProcessing;

  /// No description provided for @readingScannedSkipped.
  ///
  /// In en, this message translates to:
  /// **'its scanned pages weren\'t read'**
  String get readingScannedSkipped;

  /// No description provided for @readingNoText.
  ///
  /// In en, this message translates to:
  /// **'it has no readable text'**
  String get readingNoText;

  /// No description provided for @readingUnsupportedType.
  ///
  /// In en, this message translates to:
  /// **'this kind of file can\'t be read'**
  String get readingUnsupportedType;

  /// No description provided for @readingLinkSignIn.
  ///
  /// In en, this message translates to:
  /// **'the link needs a sign-in'**
  String get readingLinkSignIn;

  /// No description provided for @readingLinkVideo.
  ///
  /// In en, this message translates to:
  /// **'it\'s a video'**
  String get readingLinkVideo;

  /// No description provided for @readingLinkGone.
  ///
  /// In en, this message translates to:
  /// **'the link no longer works'**
  String get readingLinkGone;

  /// No description provided for @readingLinkUnreachable.
  ///
  /// In en, this message translates to:
  /// **'the link couldn\'t be opened'**
  String get readingLinkUnreachable;

  /// No description provided for @readingFailed.
  ///
  /// In en, this message translates to:
  /// **'it couldn\'t be read'**
  String get readingFailed;

  /// No description provided for @studyPlansTokensRenewWeekly.
  ///
  /// In en, this message translates to:
  /// **'Resets every Monday · next on {date}'**
  String studyPlansTokensRenewWeekly(String date);

  /// No description provided for @studyPlansTokensLow.
  ///
  /// In en, this message translates to:
  /// **'Running low on AI usage.'**
  String get studyPlansTokensLow;

  /// No description provided for @studyPlansFeatureAskLessons.
  ///
  /// In en, this message translates to:
  /// **'Ask the AI helper about your lessons and their files'**
  String get studyPlansFeatureAskLessons;

  /// No description provided for @studyPlansFeatureFreeTokens.
  ///
  /// In en, this message translates to:
  /// **'Light AI use - a few questions about your lessons each week'**
  String get studyPlansFeatureFreeTokens;

  /// No description provided for @studyPlansFeaturePlusTokens.
  ///
  /// In en, this message translates to:
  /// **'Regular AI use - questions, notes and notebooks on most days'**
  String get studyPlansFeaturePlusTokens;

  /// No description provided for @studyPlansFeatureMaxTokens.
  ///
  /// In en, this message translates to:
  /// **'Heavy AI use - twice Plus, for daily quizzes, flashcards and notebooks'**
  String get studyPlansFeatureMaxTokens;

  /// No description provided for @upgradeTokensTitle.
  ///
  /// In en, this message translates to:
  /// **'You\'ve reached your AI usage limit'**
  String get upgradeTokensTitle;

  /// No description provided for @upgradeTokensBody.
  ///
  /// In en, this message translates to:
  /// **'It resets on {date}. Your work is kept. A bigger plan gives you more.'**
  String upgradeTokensBody(String date);

  /// No description provided for @studySetMaterialProcessing.
  ///
  /// In en, this message translates to:
  /// **'The lesson\'s files are still being read. Try again in a minute so nothing is left out.'**
  String get studySetMaterialProcessing;

  /// No description provided for @nbCreate.
  ///
  /// In en, this message translates to:
  /// **'Create notebook'**
  String get nbCreate;

  /// No description provided for @nbCreating.
  ///
  /// In en, this message translates to:
  /// **'Creating…'**
  String get nbCreating;

  /// No description provided for @nbOpen.
  ///
  /// In en, this message translates to:
  /// **'Open notebook'**
  String get nbOpen;

  /// No description provided for @nbUpdateAvailable.
  ///
  /// In en, this message translates to:
  /// **'Update available'**
  String get nbUpdateAvailable;

  /// No description provided for @nbFailedShort.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t be made'**
  String get nbFailedShort;

  /// No description provided for @nbRetry.
  ///
  /// In en, this message translates to:
  /// **'Try again'**
  String get nbRetry;

  /// No description provided for @nbUpdate.
  ///
  /// In en, this message translates to:
  /// **'Update notebook'**
  String get nbUpdate;

  /// No description provided for @nbNewVersion.
  ///
  /// In en, this message translates to:
  /// **'Create another version'**
  String get nbNewVersion;

  /// No description provided for @nbMore.
  ///
  /// In en, this message translates to:
  /// **'More'**
  String get nbMore;

  /// No description provided for @nbStarted.
  ///
  /// In en, this message translates to:
  /// **'Your notebook is being written. It takes about a minute.'**
  String get nbStarted;

  /// No description provided for @nbShelfTitle.
  ///
  /// In en, this message translates to:
  /// **'Study notebooks'**
  String get nbShelfTitle;

  /// No description provided for @nbShelfEmpty.
  ///
  /// In en, this message translates to:
  /// **'Make an organised notebook from any lesson: tap Create notebook under it in Lessons.'**
  String get nbShelfEmpty;

  /// No description provided for @nbShelfLocked.
  ///
  /// In en, this message translates to:
  /// **'Study notebooks made from your lessons come with Studafy Plus.'**
  String get nbShelfLocked;

  /// No description provided for @nbShelfFailed.
  ///
  /// In en, this message translates to:
  /// **'Your notebooks could not be loaded. Try again'**
  String get nbShelfFailed;

  /// No description provided for @nbSheetTitle.
  ///
  /// In en, this message translates to:
  /// **'New study notebook'**
  String get nbSheetTitle;

  /// No description provided for @nbSheetClass.
  ///
  /// In en, this message translates to:
  /// **'Class'**
  String get nbSheetClass;

  /// No description provided for @nbSheetLesson.
  ///
  /// In en, this message translates to:
  /// **'Lesson'**
  String get nbSheetLesson;

  /// No description provided for @nbSheetName.
  ///
  /// In en, this message translates to:
  /// **'Notebook name'**
  String get nbSheetName;

  /// No description provided for @nbSheetSources.
  ///
  /// In en, this message translates to:
  /// **'Made from'**
  String get nbSheetSources;

  /// No description provided for @nbSheetWhole.
  ///
  /// In en, this message translates to:
  /// **'The whole lesson'**
  String get nbSheetWhole;

  /// No description provided for @nbSheetWholeDetail.
  ///
  /// In en, this message translates to:
  /// **'Its text and every file and link that can be read'**
  String get nbSheetWholeDetail;

  /// No description provided for @nbSheetNoFiles.
  ///
  /// In en, this message translates to:
  /// **'This lesson has no files or links; the notebook is made from its text.'**
  String get nbSheetNoFiles;

  /// No description provided for @nbSheetChoose.
  ///
  /// In en, this message translates to:
  /// **'Only the files and links I choose'**
  String get nbSheetChoose;

  /// No description provided for @nbSheetPickOne.
  ///
  /// In en, this message translates to:
  /// **'Choose at least one file or link.'**
  String get nbSheetPickOne;

  /// No description provided for @nbSheetWaitReading.
  ///
  /// In en, this message translates to:
  /// **'Some of the lesson\'s files are still being read. Wait a minute, or choose only the ones that are ready.'**
  String get nbSheetWaitReading;

  /// No description provided for @nbSheetTokens.
  ///
  /// In en, this message translates to:
  /// **'Writing a notebook uses some of your plan\'s AI usage. Opening it again is free.'**
  String get nbSheetTokens;

  /// No description provided for @nbSourceReading.
  ///
  /// In en, this message translates to:
  /// **'Still being read'**
  String get nbSourceReading;

  /// No description provided for @nbSourceUnreadable.
  ///
  /// In en, this message translates to:
  /// **'Can\'t be read'**
  String get nbSourceUnreadable;

  /// No description provided for @nbUpdateConfirmTitle.
  ///
  /// In en, this message translates to:
  /// **'Update this notebook?'**
  String get nbUpdateConfirmTitle;

  /// No description provided for @nbUpdateConfirmBody.
  ///
  /// In en, this message translates to:
  /// **'The AI part is written again from the lesson as it is now. Your notes, highlights, bookmarks and sections stay as they are.'**
  String get nbUpdateConfirmBody;

  /// No description provided for @nbUpdateBanner.
  ///
  /// In en, this message translates to:
  /// **'The lesson has changed since this notebook was written.'**
  String get nbUpdateBanner;

  /// No description provided for @nbDeleteTitle.
  ///
  /// In en, this message translates to:
  /// **'Delete notebook'**
  String get nbDeleteTitle;

  /// No description provided for @nbDeleteBody.
  ///
  /// In en, this message translates to:
  /// **'The notebook and your notes in it are deleted. This can\'t be undone.'**
  String get nbDeleteBody;

  /// No description provided for @nbWriting.
  ///
  /// In en, this message translates to:
  /// **'Writing your notebook…'**
  String get nbWriting;

  /// No description provided for @nbWritingDetail.
  ///
  /// In en, this message translates to:
  /// **'This takes about a minute. You can leave this page - it keeps going.'**
  String get nbWritingDetail;

  /// No description provided for @nbFailedTitle.
  ///
  /// In en, this message translates to:
  /// **'The notebook could not be written'**
  String get nbFailedTitle;

  /// No description provided for @nbFailNoMaterial.
  ///
  /// In en, this message translates to:
  /// **'The lesson has nothing that can be read to make a notebook from.'**
  String get nbFailNoMaterial;

  /// No description provided for @nbFailTokens.
  ///
  /// In en, this message translates to:
  /// **'You\'ve reached your AI usage limit. It resets with your plan; your notes are kept.'**
  String get nbFailTokens;

  /// No description provided for @nbFailPlan.
  ///
  /// In en, this message translates to:
  /// **'Study notebooks come with Studafy Plus.'**
  String get nbFailPlan;

  /// No description provided for @nbFailGeneric.
  ///
  /// In en, this message translates to:
  /// **'Something went wrong while writing it. Nothing was charged.'**
  String get nbFailGeneric;

  /// No description provided for @nbLoadFailed.
  ///
  /// In en, this message translates to:
  /// **'The notebook could not be opened.'**
  String get nbLoadFailed;

  /// No description provided for @nbCoverPage.
  ///
  /// In en, this message translates to:
  /// **'Cover'**
  String get nbCoverPage;

  /// No description provided for @nbCoverFrom.
  ///
  /// In en, this message translates to:
  /// **'From: {lesson}'**
  String nbCoverFrom(String lesson);

  /// No description provided for @nbCoverWritten.
  ///
  /// In en, this message translates to:
  /// **'Written {date}'**
  String nbCoverWritten(String date);

  /// No description provided for @nbOpenContents.
  ///
  /// In en, this message translates to:
  /// **'Contents'**
  String get nbOpenContents;

  /// No description provided for @nbContents.
  ///
  /// In en, this message translates to:
  /// **'Contents'**
  String get nbContents;

  /// No description provided for @nbPageOf.
  ///
  /// In en, this message translates to:
  /// **'Page {page} of {count}'**
  String nbPageOf(String page, String count);

  /// No description provided for @nbOverview.
  ///
  /// In en, this message translates to:
  /// **'Overview'**
  String get nbOverview;

  /// No description provided for @nbObjectives.
  ///
  /// In en, this message translates to:
  /// **'Learning objectives'**
  String get nbObjectives;

  /// No description provided for @nbKeyTerms.
  ///
  /// In en, this message translates to:
  /// **'Key terms'**
  String get nbKeyTerms;

  /// No description provided for @nbExamples.
  ///
  /// In en, this message translates to:
  /// **'Worked examples'**
  String get nbExamples;

  /// No description provided for @nbFacts.
  ///
  /// In en, this message translates to:
  /// **'Facts, rules and formulas'**
  String get nbFacts;

  /// No description provided for @nbMistakes.
  ///
  /// In en, this message translates to:
  /// **'Common mistakes'**
  String get nbMistakes;

  /// No description provided for @nbSummary.
  ///
  /// In en, this message translates to:
  /// **'Revision summary'**
  String get nbSummary;

  /// No description provided for @nbPractice.
  ///
  /// In en, this message translates to:
  /// **'Practice'**
  String get nbPractice;

  /// No description provided for @nbExtra.
  ///
  /// In en, this message translates to:
  /// **'Extra explanation - not from the lesson\'s files'**
  String get nbExtra;

  /// No description provided for @nbExtraShort.
  ///
  /// In en, this message translates to:
  /// **'extra explanation'**
  String get nbExtraShort;

  /// No description provided for @nbCitePage.
  ///
  /// In en, this message translates to:
  /// **'{name}, page {page}'**
  String nbCitePage(String name, String page);

  /// No description provided for @nbCiteSlide.
  ///
  /// In en, this message translates to:
  /// **'{name}, slide {slide}'**
  String nbCiteSlide(String name, String slide);

  /// No description provided for @nbUnreadableTitle.
  ///
  /// In en, this message translates to:
  /// **'Not in this notebook - these could not be read:'**
  String get nbUnreadableTitle;

  /// No description provided for @nbReadAgain.
  ///
  /// In en, this message translates to:
  /// **'Update to try again'**
  String get nbReadAgain;

  /// No description provided for @nbAddNote.
  ///
  /// In en, this message translates to:
  /// **'Add a note'**
  String get nbAddNote;

  /// No description provided for @nbEditNote.
  ///
  /// In en, this message translates to:
  /// **'Edit note'**
  String get nbEditNote;

  /// No description provided for @nbNoteHint.
  ///
  /// In en, this message translates to:
  /// **'In your own words (leave empty to delete)'**
  String get nbNoteHint;

  /// No description provided for @nbMyNote.
  ///
  /// In en, this message translates to:
  /// **'My note'**
  String get nbMyNote;

  /// No description provided for @nbHighlight.
  ///
  /// In en, this message translates to:
  /// **'Highlight'**
  String get nbHighlight;

  /// No description provided for @nbRemoveHighlight.
  ///
  /// In en, this message translates to:
  /// **'Remove highlight'**
  String get nbRemoveHighlight;

  /// No description provided for @nbColorYellow.
  ///
  /// In en, this message translates to:
  /// **'Yellow'**
  String get nbColorYellow;

  /// No description provided for @nbColorGreen.
  ///
  /// In en, this message translates to:
  /// **'Green'**
  String get nbColorGreen;

  /// No description provided for @nbColorBlue.
  ///
  /// In en, this message translates to:
  /// **'Blue'**
  String get nbColorBlue;

  /// No description provided for @nbColorPink.
  ///
  /// In en, this message translates to:
  /// **'Pink'**
  String get nbColorPink;

  /// No description provided for @nbBookmark.
  ///
  /// In en, this message translates to:
  /// **'Bookmark this page'**
  String get nbBookmark;

  /// No description provided for @nbRemoveBookmark.
  ///
  /// In en, this message translates to:
  /// **'Remove bookmark'**
  String get nbRemoveBookmark;

  /// No description provided for @nbBookmarked.
  ///
  /// In en, this message translates to:
  /// **'Bookmarked'**
  String get nbBookmarked;

  /// No description provided for @nbAddSection.
  ///
  /// In en, this message translates to:
  /// **'Add my own section'**
  String get nbAddSection;

  /// No description provided for @nbArrange.
  ///
  /// In en, this message translates to:
  /// **'Arrange my sections'**
  String get nbArrange;

  /// No description provided for @nbSectionTitle.
  ///
  /// In en, this message translates to:
  /// **'Section title'**
  String get nbSectionTitle;

  /// No description provided for @nbSectionBody.
  ///
  /// In en, this message translates to:
  /// **'Write anything'**
  String get nbSectionBody;

  /// No description provided for @nbSectionEmpty.
  ///
  /// In en, this message translates to:
  /// **'Nothing here yet. Tap Write to start.'**
  String get nbSectionEmpty;

  /// No description provided for @nbEditSection.
  ///
  /// In en, this message translates to:
  /// **'Write'**
  String get nbEditSection;

  /// No description provided for @nbDeleteSection.
  ///
  /// In en, this message translates to:
  /// **'Delete section'**
  String get nbDeleteSection;

  /// No description provided for @nbMySection.
  ///
  /// In en, this message translates to:
  /// **'My section'**
  String get nbMySection;

  /// No description provided for @nbRenameHeading.
  ///
  /// In en, this message translates to:
  /// **'Rename heading'**
  String get nbRenameHeading;

  /// No description provided for @nbResetHeading.
  ///
  /// In en, this message translates to:
  /// **'Use the original'**
  String get nbResetHeading;

  /// No description provided for @nbSettings.
  ///
  /// In en, this message translates to:
  /// **'Cover and pages'**
  String get nbSettings;

  /// No description provided for @nbSettingsTitle.
  ///
  /// In en, this message translates to:
  /// **'Name'**
  String get nbSettingsTitle;

  /// No description provided for @nbSettingsSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Subtitle'**
  String get nbSettingsSubtitle;

  /// No description provided for @nbColor.
  ///
  /// In en, this message translates to:
  /// **'Colour'**
  String get nbColor;

  /// No description provided for @nbIcon.
  ///
  /// In en, this message translates to:
  /// **'Icon'**
  String get nbIcon;

  /// No description provided for @nbPageStyle.
  ///
  /// In en, this message translates to:
  /// **'Pages'**
  String get nbPageStyle;

  /// No description provided for @nbLined.
  ///
  /// In en, this message translates to:
  /// **'Lined'**
  String get nbLined;

  /// No description provided for @nbPlain.
  ///
  /// In en, this message translates to:
  /// **'Plain'**
  String get nbPlain;

  /// No description provided for @nbGrid.
  ///
  /// In en, this message translates to:
  /// **'Grid'**
  String get nbGrid;

  /// No description provided for @nbSaving.
  ///
  /// In en, this message translates to:
  /// **'Saving…'**
  String get nbSaving;

  /// No description provided for @nbSaved.
  ///
  /// In en, this message translates to:
  /// **'Saved'**
  String get nbSaved;

  /// No description provided for @nbSaveFailed.
  ///
  /// In en, this message translates to:
  /// **'Not saved - tap to try again'**
  String get nbSaveFailed;

  /// No description provided for @nbPracticeIntro.
  ///
  /// In en, this message translates to:
  /// **'Test yourself on this notebook - all of it, or the sections you choose.'**
  String get nbPracticeIntro;

  /// No description provided for @nbPracticeLocked.
  ///
  /// In en, this message translates to:
  /// **'Quizzes and flashcards come with Studafy Max'**
  String get nbPracticeLocked;

  /// No description provided for @nbQuizWhole.
  ///
  /// In en, this message translates to:
  /// **'Quiz on the whole notebook'**
  String get nbQuizWhole;

  /// No description provided for @nbCardsWhole.
  ///
  /// In en, this message translates to:
  /// **'Flashcards for the whole notebook'**
  String get nbCardsWhole;

  /// No description provided for @nbChooseSections.
  ///
  /// In en, this message translates to:
  /// **'Choose sections'**
  String get nbChooseSections;

  /// No description provided for @nbChooseSectionsTitle.
  ///
  /// In en, this message translates to:
  /// **'Practise these sections'**
  String get nbChooseSectionsTitle;

  /// No description provided for @nbMakeQuiz.
  ///
  /// In en, this message translates to:
  /// **'Quiz'**
  String get nbMakeQuiz;

  /// No description provided for @nbMakeCards.
  ///
  /// In en, this message translates to:
  /// **'Flashcards'**
  String get nbMakeCards;

  /// No description provided for @nbMadeSets.
  ///
  /// In en, this message translates to:
  /// **'Made from this notebook'**
  String get nbMadeSets;

  /// No description provided for @nbSetWhole.
  ///
  /// In en, this message translates to:
  /// **'Whole notebook'**
  String get nbSetWhole;

  /// No description provided for @nbSetOutdated.
  ///
  /// In en, this message translates to:
  /// **'from an older version - opens a new one'**
  String get nbSetOutdated;

  /// No description provided for @setMakingQuiz.
  ///
  /// In en, this message translates to:
  /// **'Making your quiz…'**
  String get setMakingQuiz;

  /// No description provided for @setMakingCards.
  ///
  /// In en, this message translates to:
  /// **'Making your flashcards…'**
  String get setMakingCards;

  /// No description provided for @setMakingDetail.
  ///
  /// In en, this message translates to:
  /// **'This takes a few seconds. Once made, it opens straight away next time.'**
  String get setMakingDetail;

  /// No description provided for @setEmpty.
  ///
  /// In en, this message translates to:
  /// **'There was not enough in the lesson to make this from.'**
  String get setEmpty;

  /// No description provided for @setFailed.
  ///
  /// In en, this message translates to:
  /// **'That did not work'**
  String get setFailed;

  /// No description provided for @setFailedDetail.
  ///
  /// In en, this message translates to:
  /// **'Nothing was charged. Try again in a moment.'**
  String get setFailedDetail;

  /// No description provided for @setSeePlans.
  ///
  /// In en, this message translates to:
  /// **'See plans'**
  String get setSeePlans;

  /// No description provided for @quizQuestionOf.
  ///
  /// In en, this message translates to:
  /// **'Question {number} of {count}'**
  String quizQuestionOf(String number, String count);

  /// No description provided for @quizSubmit.
  ///
  /// In en, this message translates to:
  /// **'Check my answers'**
  String get quizSubmit;

  /// No description provided for @quizAnswerAll.
  ///
  /// In en, this message translates to:
  /// **'Answer every question, then check.'**
  String get quizAnswerAll;

  /// No description provided for @quizScoreLine.
  ///
  /// In en, this message translates to:
  /// **'You got {score} of {count} right'**
  String quizScoreLine(String score, String count);

  /// No description provided for @quizCorrect.
  ///
  /// In en, this message translates to:
  /// **'Correct'**
  String get quizCorrect;

  /// No description provided for @quizWrong.
  ///
  /// In en, this message translates to:
  /// **'Not quite'**
  String get quizWrong;

  /// No description provided for @cardsProgress.
  ///
  /// In en, this message translates to:
  /// **'Card {number} of {count}'**
  String cardsProgress(String number, String count);

  /// No description provided for @cardsTapToFlip.
  ///
  /// In en, this message translates to:
  /// **'Tap the card to turn it over'**
  String get cardsTapToFlip;

  /// No description provided for @cardsDidYouKnow.
  ///
  /// In en, this message translates to:
  /// **'Did you know it?'**
  String get cardsDidYouKnow;

  /// No description provided for @cardsKnew.
  ///
  /// In en, this message translates to:
  /// **'I knew it'**
  String get cardsKnew;

  /// No description provided for @cardsLearning.
  ///
  /// In en, this message translates to:
  /// **'Still learning'**
  String get cardsLearning;

  /// No description provided for @cardsDone.
  ///
  /// In en, this message translates to:
  /// **'All done!'**
  String get cardsDone;

  /// No description provided for @cardsKnewCount.
  ///
  /// In en, this message translates to:
  /// **'You knew {known} of {count}'**
  String cardsKnewCount(String known, String count);

  /// No description provided for @cardsLearningOnly.
  ///
  /// In en, this message translates to:
  /// **'Practise the ones I\'m learning'**
  String get cardsLearningOnly;

  /// No description provided for @cardsAgain.
  ///
  /// In en, this message translates to:
  /// **'Go through them all again'**
  String get cardsAgain;

  /// No description provided for @cardsPrevious.
  ///
  /// In en, this message translates to:
  /// **'Previous'**
  String get cardsPrevious;

  /// No description provided for @cardsNext.
  ///
  /// In en, this message translates to:
  /// **'Next'**
  String get cardsNext;

  /// No description provided for @cardsQuestion.
  ///
  /// In en, this message translates to:
  /// **'Question'**
  String get cardsQuestion;

  /// No description provided for @cardsAnswer.
  ///
  /// In en, this message translates to:
  /// **'Answer'**
  String get cardsAnswer;

  /// No description provided for @pickTitle.
  ///
  /// In en, this message translates to:
  /// **'Choose material'**
  String get pickTitle;

  /// No description provided for @pickSearch.
  ///
  /// In en, this message translates to:
  /// **'Search lessons and files'**
  String get pickSearch;

  /// No description provided for @pickAllClasses.
  ///
  /// In en, this message translates to:
  /// **'All classes'**
  String get pickAllClasses;

  /// No description provided for @pickSelectClass.
  ///
  /// In en, this message translates to:
  /// **'Select entire class'**
  String get pickSelectClass;

  /// No description provided for @pickSelectClassTitle.
  ///
  /// In en, this message translates to:
  /// **'Select all of {name}?'**
  String pickSelectClassTitle(String name);

  /// No description provided for @pickSelectClassBody.
  ///
  /// In en, this message translates to:
  /// **'This chooses all {lessons} lessons and their {files} files and links that can be read. You can review and remove anything before continuing.'**
  String pickSelectClassBody(int lessons, int files);

  /// No description provided for @pickSelectClassConfirm.
  ///
  /// In en, this message translates to:
  /// **'Select all'**
  String get pickSelectClassConfirm;

  /// No description provided for @pickTooManyLessons.
  ///
  /// In en, this message translates to:
  /// **'Up to {max} lessons can be used at once.'**
  String pickTooManyLessons(int max);

  /// No description provided for @pickSingleLesson.
  ///
  /// In en, this message translates to:
  /// **'A notebook is made from one lesson: choose its text and the files to use.'**
  String get pickSingleLesson;

  /// No description provided for @pickLessonText.
  ///
  /// In en, this message translates to:
  /// **'Lesson text'**
  String get pickLessonText;

  /// No description provided for @pickWholeLesson.
  ///
  /// In en, this message translates to:
  /// **'whole lesson'**
  String get pickWholeLesson;

  /// No description provided for @pickWholeLessonDetail.
  ///
  /// In en, this message translates to:
  /// **'Whole lesson, all attachments'**
  String get pickWholeLessonDetail;

  /// No description provided for @pickPartOfLesson.
  ///
  /// In en, this message translates to:
  /// **'Part of the lesson'**
  String get pickPartOfLesson;

  /// No description provided for @pickAllAttachments.
  ///
  /// In en, this message translates to:
  /// **'all attachments'**
  String get pickAllAttachments;

  /// No description provided for @pickAttachments.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =0{no attachments} =1{1 attachment} other{{count} attachments}}'**
  String pickAttachments(int count);

  /// No description provided for @pickLessons.
  ///
  /// In en, this message translates to:
  /// **'{count} lessons'**
  String pickLessons(int count);

  /// No description provided for @pickClasses.
  ///
  /// In en, this message translates to:
  /// **'{count} classes'**
  String pickClasses(int count);

  /// No description provided for @pickLessonNamed.
  ///
  /// In en, this message translates to:
  /// **'Lesson: {title}'**
  String pickLessonNamed(String title);

  /// No description provided for @pickTextOnly.
  ///
  /// In en, this message translates to:
  /// **'lesson text only'**
  String get pickTextOnly;

  /// No description provided for @pickNotes.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 note} other{{count} notes}}'**
  String pickNotes(int count);

  /// No description provided for @pickNothing.
  ///
  /// In en, this message translates to:
  /// **'Nothing chosen yet'**
  String get pickNothing;

  /// No description provided for @pickReview.
  ///
  /// In en, this message translates to:
  /// **'Review'**
  String get pickReview;

  /// No description provided for @pickReviewTitle.
  ///
  /// In en, this message translates to:
  /// **'What will be used'**
  String get pickReviewTitle;

  /// No description provided for @pickRemove.
  ///
  /// In en, this message translates to:
  /// **'Remove'**
  String get pickRemove;

  /// No description provided for @pickSelected.
  ///
  /// In en, this message translates to:
  /// **'Selected'**
  String get pickSelected;

  /// No description provided for @pickShowFiles.
  ///
  /// In en, this message translates to:
  /// **'Show its text and files'**
  String get pickShowFiles;

  /// No description provided for @pickStillReading.
  ///
  /// In en, this message translates to:
  /// **'Still being read'**
  String get pickStillReading;

  /// No description provided for @pickWaitingNotIncluded.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 file is still being read and is not included yet.} other{{count} files are still being read and are not included yet.}}'**
  String pickWaitingNotIncluded(int count);

  /// No description provided for @pickNoMatch.
  ///
  /// In en, this message translates to:
  /// **'Nothing matches your search.'**
  String get pickNoMatch;

  /// No description provided for @pickLoadFailed.
  ///
  /// In en, this message translates to:
  /// **'Your lessons could not be loaded.'**
  String get pickLoadFailed;

  /// No description provided for @pickActionSummary.
  ///
  /// In en, this message translates to:
  /// **'Summarise selected materials'**
  String get pickActionSummary;

  /// No description provided for @pickActionQuiz.
  ///
  /// In en, this message translates to:
  /// **'Create quiz from selection'**
  String get pickActionQuiz;

  /// No description provided for @pickActionFlashcards.
  ///
  /// In en, this message translates to:
  /// **'Create flashcards from selection'**
  String get pickActionFlashcards;

  /// No description provided for @pickActionNotebook.
  ///
  /// In en, this message translates to:
  /// **'Create notebook from selection'**
  String get pickActionNotebook;

  /// No description provided for @pickActionHelper.
  ///
  /// In en, this message translates to:
  /// **'Use selection in AI Helper'**
  String get pickActionHelper;

  /// No description provided for @madeFrom.
  ///
  /// In en, this message translates to:
  /// **'Made from: {sources}'**
  String madeFrom(String sources);

  /// No description provided for @unavailableTitle.
  ///
  /// In en, this message translates to:
  /// **'Some chosen files can\'t be used right now'**
  String get unavailableTitle;

  /// No description provided for @unavailableBody.
  ///
  /// In en, this message translates to:
  /// **'Nothing has been made yet. Try again later, or continue without these:'**
  String get unavailableBody;

  /// No description provided for @unavailableFile.
  ///
  /// In en, this message translates to:
  /// **'A chosen file'**
  String get unavailableFile;

  /// No description provided for @unavailableLater.
  ///
  /// In en, this message translates to:
  /// **'Try again later'**
  String get unavailableLater;

  /// No description provided for @unavailableContinue.
  ///
  /// In en, this message translates to:
  /// **'Continue without them'**
  String get unavailableContinue;

  /// No description provided for @helperNoMaterial.
  ///
  /// In en, this message translates to:
  /// **'Not using class material'**
  String get helperNoMaterial;

  /// No description provided for @helperChooseMaterial.
  ///
  /// In en, this message translates to:
  /// **'Choose'**
  String get helperChooseMaterial;

  /// No description provided for @helperChangeMaterial.
  ///
  /// In en, this message translates to:
  /// **'Change'**
  String get helperChangeMaterial;

  /// No description provided for @helperMaterialChangedMark.
  ///
  /// In en, this message translates to:
  /// **'From here: {label}'**
  String helperMaterialChangedMark(String label);

  /// No description provided for @helperMaterialRemovedMark.
  ///
  /// In en, this message translates to:
  /// **'From here: no class material'**
  String get helperMaterialRemovedMark;

  /// No description provided for @notebookMakingNotes.
  ///
  /// In en, this message translates to:
  /// **'Making your notes…'**
  String get notebookMakingNotes;

  /// No description provided for @usageSectionTitle.
  ///
  /// In en, this message translates to:
  /// **'AI usage'**
  String get usageSectionTitle;

  /// No description provided for @usagePlan.
  ///
  /// In en, this message translates to:
  /// **'{plan} plan'**
  String usagePlan(String plan);

  /// No description provided for @usagePlenty.
  ///
  /// In en, this message translates to:
  /// **'Plenty available'**
  String get usagePlenty;

  /// No description provided for @usageLow.
  ///
  /// In en, this message translates to:
  /// **'Running low'**
  String get usageLow;

  /// No description provided for @usageReached.
  ///
  /// In en, this message translates to:
  /// **'Limit reached'**
  String get usageReached;

  /// No description provided for @usageReachedDetail.
  ///
  /// In en, this message translates to:
  /// **'Your chats, notes and notebooks are kept. You can carry on when it resets, or upgrade now.'**
  String get usageReachedDetail;

  /// No description provided for @usageLine.
  ///
  /// In en, this message translates to:
  /// **'{level} · resets {date}'**
  String usageLine(String level, String date);

  /// No description provided for @usageBarLabel.
  ///
  /// In en, this message translates to:
  /// **'AI usage: {level}'**
  String usageBarLabel(String level);

  /// No description provided for @usageResets.
  ///
  /// In en, this message translates to:
  /// **'Resets on {date}'**
  String usageResets(String date);

  /// No description provided for @usageResetsWeekly.
  ///
  /// In en, this message translates to:
  /// **'Resets every Monday · next on {date}'**
  String usageResetsWeekly(String date);

  /// No description provided for @usageUpgrade.
  ///
  /// In en, this message translates to:
  /// **'Upgrade and compare plans'**
  String get usageUpgrade;

  /// No description provided for @usageComparePlans.
  ///
  /// In en, this message translates to:
  /// **'Compare plans'**
  String get usageComparePlans;

  /// No description provided for @usageLoadFailed.
  ///
  /// In en, this message translates to:
  /// **'Your AI usage could not be loaded. Try again'**
  String get usageLoadFailed;

  /// No description provided for @usageCostLight.
  ///
  /// In en, this message translates to:
  /// **'uses a little'**
  String get usageCostLight;

  /// No description provided for @usageCostMedium.
  ///
  /// In en, this message translates to:
  /// **'uses some'**
  String get usageCostMedium;

  /// No description provided for @usageCostMore.
  ///
  /// In en, this message translates to:
  /// **'uses more'**
  String get usageCostMore;

  /// No description provided for @markPublishTitle.
  ///
  /// In en, this message translates to:
  /// **'Publish grades?'**
  String get markPublishTitle;

  /// No description provided for @markPublishFailed.
  ///
  /// In en, this message translates to:
  /// **'Grades were not published. Check your connection and try again.'**
  String get markPublishFailed;

  /// No description provided for @markSummary.
  ///
  /// In en, this message translates to:
  /// **'{toMark} to mark · {marked} ready to publish · {published} published'**
  String markSummary(int toMark, int marked, int published);

  /// No description provided for @markRefreshFailed.
  ///
  /// In en, this message translates to:
  /// **'The list could not be refreshed. Pull down to try again.'**
  String get markRefreshFailed;

  /// No description provided for @markStatusNotMarked.
  ///
  /// In en, this message translates to:
  /// **'Submitted · not graded'**
  String get markStatusNotMarked;

  /// No description provided for @markStatusPartly.
  ///
  /// In en, this message translates to:
  /// **'Submitted · partly graded'**
  String get markStatusPartly;

  /// No description provided for @markStatusMarked.
  ///
  /// In en, this message translates to:
  /// **'Graded · not published'**
  String get markStatusMarked;

  /// No description provided for @markStatusPublished.
  ///
  /// In en, this message translates to:
  /// **'Published'**
  String get markStatusPublished;

  /// No description provided for @markScoreNeededForComment.
  ///
  /// In en, this message translates to:
  /// **'Give a score with each comment, or clear the comment.'**
  String get markScoreNeededForComment;

  /// No description provided for @markNothingChanged.
  ///
  /// In en, this message translates to:
  /// **'Nothing has changed since the last save.'**
  String get markNothingChanged;

  /// No description provided for @markCorrected.
  ///
  /// In en, this message translates to:
  /// **'Correction saved. The student and their parents see the new mark.'**
  String get markCorrected;

  /// No description provided for @markDraftSaved.
  ///
  /// In en, this message translates to:
  /// **'Saved as a draft. Students and parents can\'t see it until you publish the grades.'**
  String get markDraftSaved;

  /// No description provided for @markUnsavedTitle.
  ///
  /// In en, this message translates to:
  /// **'Leave without saving?'**
  String get markUnsavedTitle;

  /// No description provided for @markUnsavedBody.
  ///
  /// In en, this message translates to:
  /// **'Marks and comments you have not saved will be lost.'**
  String get markUnsavedBody;

  /// No description provided for @markUnsavedKeep.
  ///
  /// In en, this message translates to:
  /// **'Keep marking'**
  String get markUnsavedKeep;

  /// No description provided for @markUnsavedDiscard.
  ///
  /// In en, this message translates to:
  /// **'Discard changes'**
  String get markUnsavedDiscard;

  /// No description provided for @markStillToMark.
  ///
  /// In en, this message translates to:
  /// **'Still being marked'**
  String get markStillToMark;

  /// No description provided for @markPublishedNotice.
  ///
  /// In en, this message translates to:
  /// **'Published: the student and their parents see this grade. A change is saved as a correction, with a reason.'**
  String get markPublishedNotice;

  /// No description provided for @markDraftNotice.
  ///
  /// In en, this message translates to:
  /// **'Not published yet: only the class\'s teachers can see these marks.'**
  String get markDraftNotice;

  /// No description provided for @markAutoScore.
  ///
  /// In en, this message translates to:
  /// **'Marked automatically: {score} of {max}'**
  String markAutoScore(String score, String max);

  /// No description provided for @markOverallFeedbackHelp.
  ///
  /// In en, this message translates to:
  /// **'Shown with the grade once it is published.'**
  String get markOverallFeedbackHelp;

  /// No description provided for @markSaveCorrection.
  ///
  /// In en, this message translates to:
  /// **'Save correction'**
  String get markSaveCorrection;

  /// No description provided for @markSaveDraft.
  ///
  /// In en, this message translates to:
  /// **'Save draft'**
  String get markSaveDraft;

  /// No description provided for @markCorrectionTitle.
  ///
  /// In en, this message translates to:
  /// **'Correct a published grade'**
  String get markCorrectionTitle;

  /// No description provided for @markCorrectionBody.
  ///
  /// In en, this message translates to:
  /// **'The student and their parents already see this grade. Say why it is changing; the reason is kept with the change.'**
  String get markCorrectionBody;

  /// No description provided for @markCorrectionReason.
  ///
  /// In en, this message translates to:
  /// **'Reason for the change'**
  String get markCorrectionReason;

  /// No description provided for @markOutOf.
  ///
  /// In en, this message translates to:
  /// **'out of {max}'**
  String markOutOf(String max);

  /// No description provided for @markStudentAnswer.
  ///
  /// In en, this message translates to:
  /// **'Student\'s answer'**
  String get markStudentAnswer;

  /// No description provided for @gradebookOnlineHint.
  ///
  /// In en, this message translates to:
  /// **'This work is answered in the app. Mark it from each student\'s answers.'**
  String get gradebookOnlineHint;

  /// No description provided for @gradebookOpenAnswers.
  ///
  /// In en, this message translates to:
  /// **'Open submissions'**
  String get gradebookOpenAnswers;

  /// No description provided for @todayWorkDraft.
  ///
  /// In en, this message translates to:
  /// **'Draft · not set yet'**
  String get todayWorkDraft;

  /// No description provided for @todayWorkExamOn.
  ///
  /// In en, this message translates to:
  /// **'Exam on {date}'**
  String todayWorkExamOn(String date);

  /// No description provided for @todayWorkOpens.
  ///
  /// In en, this message translates to:
  /// **'Opens {date}'**
  String todayWorkOpens(String date);

  /// No description provided for @todayWorkScheduled.
  ///
  /// In en, this message translates to:
  /// **'Scheduled'**
  String get todayWorkScheduled;

  /// No description provided for @todayWorkDue.
  ///
  /// In en, this message translates to:
  /// **'Due {date}'**
  String todayWorkDue(String date);

  /// No description provided for @todayWorkCloses.
  ///
  /// In en, this message translates to:
  /// **'Closes {date}'**
  String todayWorkCloses(String date);

  /// No description provided for @todayWorkOpen.
  ///
  /// In en, this message translates to:
  /// **'Open'**
  String get todayWorkOpen;

  /// No description provided for @todayWorkKindAssignment.
  ///
  /// In en, this message translates to:
  /// **'Assignment'**
  String get todayWorkKindAssignment;

  /// No description provided for @todayWorkKindOnlineExam.
  ///
  /// In en, this message translates to:
  /// **'Online exam'**
  String get todayWorkKindOnlineExam;

  /// No description provided for @todayWorkKindPaperExam.
  ///
  /// In en, this message translates to:
  /// **'Paper exam'**
  String get todayWorkKindPaperExam;

  /// No description provided for @todayWorkFinish.
  ///
  /// In en, this message translates to:
  /// **'Publish'**
  String get todayWorkFinish;

  /// No description provided for @todayWorkUnknown.
  ///
  /// In en, this message translates to:
  /// **'Some classes could not be loaded, so work may be missing here.'**
  String get todayWorkUnknown;

  /// No description provided for @todayPartlyLoaded.
  ///
  /// In en, this message translates to:
  /// **'Some classes could not be loaded.'**
  String get todayPartlyLoaded;

  /// No description provided for @todaySectionsUnknown.
  ///
  /// In en, this message translates to:
  /// **'Some classes could not be loaded, so sections may be missing here.'**
  String get todaySectionsUnknown;

  /// No description provided for @todaySectionDraft.
  ///
  /// In en, this message translates to:
  /// **'Lesson in draft · not visible to students'**
  String get todaySectionDraft;

  /// No description provided for @todaySectionPublish.
  ///
  /// In en, this message translates to:
  /// **'Publish'**
  String get todaySectionPublish;

  /// No description provided for @todaySectionAdd.
  ///
  /// In en, this message translates to:
  /// **'Add lesson'**
  String get todaySectionAdd;

  /// No description provided for @todayMore.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{and 1 more} other{and {count} more}}'**
  String todayMore(int count);

  /// No description provided for @lessonForSection.
  ///
  /// In en, this message translates to:
  /// **'For the lesson on {when}'**
  String lessonForSection(String when);

  /// No description provided for @markFixHighlighted.
  ///
  /// In en, this message translates to:
  /// **'Fix the highlighted marks, then save again.'**
  String get markFixHighlighted;

  /// No description provided for @sectionsPublished.
  ///
  /// In en, this message translates to:
  /// **'Lesson published'**
  String get sectionsPublished;

  /// No description provided for @scheduleLoadFailed.
  ///
  /// In en, this message translates to:
  /// **'The timetable could not be loaded. Try again.'**
  String get scheduleLoadFailed;

  /// No description provided for @markSavedPublished.
  ///
  /// In en, this message translates to:
  /// **'Saved. Nothing about the published grade needed a correction.'**
  String get markSavedPublished;

  /// No description provided for @markCorrectionCancelled.
  ///
  /// In en, this message translates to:
  /// **'Not saved. A change to a published mark needs a reason; your marks are still here.'**
  String get markCorrectionCancelled;

  /// No description provided for @markPublishedAbsentNotice.
  ///
  /// In en, this message translates to:
  /// **'Published as absent, but this student handed work in afterwards. Save to replace the absence with this mark; you will be asked why.'**
  String get markPublishedAbsentNotice;

  /// No description provided for @markReplaceAbsence.
  ///
  /// In en, this message translates to:
  /// **'Replace the absence'**
  String get markReplaceAbsence;

  /// No description provided for @markSaveChanges.
  ///
  /// In en, this message translates to:
  /// **'Save changes'**
  String get markSaveChanges;

  /// No description provided for @markAbsenceCorrected.
  ///
  /// In en, this message translates to:
  /// **'Correction saved. The student and their parents see the change.'**
  String get markAbsenceCorrected;

  /// No description provided for @markAbsenceRemoved.
  ///
  /// In en, this message translates to:
  /// **'Absence removed.'**
  String get markAbsenceRemoved;

  /// No description provided for @markAbsenceSaved.
  ///
  /// In en, this message translates to:
  /// **'Marked absent. Nobody sees it until you publish the grades.'**
  String get markAbsenceSaved;

  /// No description provided for @markAbsenceRefused.
  ///
  /// In en, this message translates to:
  /// **'This student has handed work in, so they can\'t be marked absent.'**
  String get markAbsenceRefused;

  /// No description provided for @markAbsenceFailed.
  ///
  /// In en, this message translates to:
  /// **'That wasn\'t saved. Check your connection and try again.'**
  String get markAbsenceFailed;

  /// No description provided for @markNotSubmittedSection.
  ///
  /// In en, this message translates to:
  /// **'Not submitted'**
  String get markNotSubmittedSection;

  /// No description provided for @markNotSubmittedHint.
  ///
  /// In en, this message translates to:
  /// **'Tap a student to mark them absent. An absence is never counted as zero.'**
  String get markNotSubmittedHint;

  /// No description provided for @markRosterSummary.
  ///
  /// In en, this message translates to:
  /// **'{notSubmitted} not submitted · {absent} absent'**
  String markRosterSummary(int notSubmitted, int absent);

  /// No description provided for @markStatusNotSubmitted.
  ///
  /// In en, this message translates to:
  /// **'Not submitted'**
  String get markStatusNotSubmitted;

  /// No description provided for @markStatusAbsent.
  ///
  /// In en, this message translates to:
  /// **'Absent'**
  String get markStatusAbsent;

  /// No description provided for @markStatusAbsentPublished.
  ///
  /// In en, this message translates to:
  /// **'Absent · published'**
  String get markStatusAbsentPublished;

  /// No description provided for @markStatusNotGradedPublished.
  ///
  /// In en, this message translates to:
  /// **'Not graded · published'**
  String get markStatusNotGradedPublished;

  /// No description provided for @markAbsenceBody.
  ///
  /// In en, this message translates to:
  /// **'Record that this student was absent. It stays private until you publish the grades, and it is not a zero.'**
  String get markAbsenceBody;

  /// No description provided for @markAbsencePublishedBody.
  ///
  /// In en, this message translates to:
  /// **'This absence is published. Changing it is a correction: say why, and it is kept with the change.'**
  String get markAbsencePublishedBody;

  /// No description provided for @markAbsenceExcused.
  ///
  /// In en, this message translates to:
  /// **'Not graded (excused)'**
  String get markAbsenceExcused;

  /// No description provided for @markAbsenceNotes.
  ///
  /// In en, this message translates to:
  /// **'Notes (optional)'**
  String get markAbsenceNotes;

  /// No description provided for @markAbsenceRemove.
  ///
  /// In en, this message translates to:
  /// **'Remove absence'**
  String get markAbsenceRemove;

  /// No description provided for @markAbsenceSaveNotes.
  ///
  /// In en, this message translates to:
  /// **'Save notes'**
  String get markAbsenceSaveNotes;

  /// No description provided for @markAbsenceMark.
  ///
  /// In en, this message translates to:
  /// **'Mark absent'**
  String get markAbsenceMark;

  /// No description provided for @takeChildAttempts.
  ///
  /// In en, this message translates to:
  /// **'Attempts'**
  String get takeChildAttempts;

  /// Secondary sign-in for accounts Studafy provisions itself, such as app store reviewers'. There is no sign-up or password reset on this path.
  ///
  /// In en, this message translates to:
  /// **'Sign in with email'**
  String get loginWithEmail;

  /// No description provided for @loginEmailNote.
  ///
  /// In en, this message translates to:
  /// **'For accounts set up by Studafy.'**
  String get loginEmailNote;

  /// No description provided for @loginEmailLabel.
  ///
  /// In en, this message translates to:
  /// **'Email'**
  String get loginEmailLabel;

  /// No description provided for @loginPasswordLabel.
  ///
  /// In en, this message translates to:
  /// **'Password'**
  String get loginPasswordLabel;

  /// No description provided for @loginShowPassword.
  ///
  /// In en, this message translates to:
  /// **'Show password'**
  String get loginShowPassword;

  /// No description provided for @loginHidePassword.
  ///
  /// In en, this message translates to:
  /// **'Hide password'**
  String get loginHidePassword;

  /// No description provided for @loginEmailSubmit.
  ///
  /// In en, this message translates to:
  /// **'Sign in'**
  String get loginEmailSubmit;

  /// No description provided for @loginEmailMissing.
  ///
  /// In en, this message translates to:
  /// **'Enter your email address.'**
  String get loginEmailMissing;

  /// No description provided for @loginEmailInvalid.
  ///
  /// In en, this message translates to:
  /// **'Enter a valid email address.'**
  String get loginEmailInvalid;

  /// No description provided for @loginPasswordMissing.
  ///
  /// In en, this message translates to:
  /// **'Enter your password.'**
  String get loginPasswordMissing;

  /// No description provided for @loginEmailWrong.
  ///
  /// In en, this message translates to:
  /// **'That email and password don\'t match an account set up by Studafy.'**
  String get loginEmailWrong;

  /// No description provided for @loginEmailTooMany.
  ///
  /// In en, this message translates to:
  /// **'Too many attempts. Wait a few minutes, then try again.'**
  String get loginEmailTooMany;

  /// No description provided for @loginEmailOffline.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t reach Studafy. Check your connection and try again.'**
  String get loginEmailOffline;

  /// No description provided for @loginEmailUnavailable.
  ///
  /// In en, this message translates to:
  /// **'Email sign-in isn\'t available right now. Please try again later.'**
  String get loginEmailUnavailable;

  /// No description provided for @reauthPasswordTitle.
  ///
  /// In en, this message translates to:
  /// **'Confirm it\'s you'**
  String get reauthPasswordTitle;

  /// No description provided for @reauthPasswordBody.
  ///
  /// In en, this message translates to:
  /// **'Enter the password for {email}.'**
  String reauthPasswordBody(String email);

  /// No description provided for @reauthPasswordConfirm.
  ///
  /// In en, this message translates to:
  /// **'Confirm'**
  String get reauthPasswordConfirm;

  /// No description provided for @reauthPasswordCancel.
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get reauthPasswordCancel;

  /// No description provided for @aiConsentTitle.
  ///
  /// In en, this message translates to:
  /// **'AI study tools'**
  String get aiConsentTitle;

  /// No description provided for @aiConsentNoticeBody.
  ///
  /// In en, this message translates to:
  /// **'The study helper, lesson notes, study notebooks, quizzes and flashcards use AI from Together AI, a company outside Studafy. They are optional.\n\nWHAT IS SENT\nWhat you type, the recent turns of the same chat, and - if you choose - a lesson\'s text, your own notes or a photo you add.\n\nWHAT IS NOT SENT\nYour email, school, marks or account details. Names Studafy knows - yours, your classmates\', your teachers\' and your parents\' - are replaced with words like [student] before anything is sent. A photo is sent as it is, so do not photograph names or faces.\n\nGOOD TO KNOW\nAnswers can be wrong: check them, and never hand them in as your own work. Chats stay on your device. AI never marks your work.\n\nYou can turn the AI tools off at any time in your account.'**
  String get aiConsentNoticeBody;

  /// No description provided for @aiConsentAgree.
  ///
  /// In en, this message translates to:
  /// **'I agree'**
  String get aiConsentAgree;

  /// No description provided for @aiConsentNotNow.
  ///
  /// In en, this message translates to:
  /// **'Not now'**
  String get aiConsentNotNow;

  /// No description provided for @aiConsentForChild.
  ///
  /// In en, this message translates to:
  /// **'You are agreeing for {name}, whose account you manage.'**
  String aiConsentForChild(String name);

  /// No description provided for @aiConsentGuardianNeeded.
  ///
  /// In en, this message translates to:
  /// **'A parent turns on the AI study tools for this account, from their own account.'**
  String get aiConsentGuardianNeeded;

  /// No description provided for @aiConsentStudentsOnly.
  ///
  /// In en, this message translates to:
  /// **'The AI study tools are for students in a class.'**
  String get aiConsentStudentsOnly;

  /// No description provided for @aiConsentSwitchOn.
  ///
  /// In en, this message translates to:
  /// **'On. You can turn them off at any time.'**
  String get aiConsentSwitchOn;

  /// No description provided for @aiConsentSwitchOff.
  ///
  /// In en, this message translates to:
  /// **'Off. Turn on to use the study helper, notes, notebooks, quizzes and flashcards.'**
  String get aiConsentSwitchOff;

  /// No description provided for @aiConsentChildSwitch.
  ///
  /// In en, this message translates to:
  /// **'AI study tools for {name}'**
  String aiConsentChildSwitch(String name);

  /// No description provided for @aiConsentWithdrawTitle.
  ///
  /// In en, this message translates to:
  /// **'Turn off the AI study tools?'**
  String get aiConsentWithdrawTitle;

  /// No description provided for @aiConsentWithdrawBody.
  ///
  /// In en, this message translates to:
  /// **'The study helper, notes, notebooks, quizzes and flashcards stop until they are turned on again. What was already made stays.'**
  String get aiConsentWithdrawBody;

  /// No description provided for @aiConsentWithdrawAction.
  ///
  /// In en, this message translates to:
  /// **'Turn off'**
  String get aiConsentWithdrawAction;

  /// No description provided for @aiConsentSaveFailed.
  ///
  /// In en, this message translates to:
  /// **'That was not saved. Check your connection and try again.'**
  String get aiConsentSaveFailed;

  /// No description provided for @aiConsentReadNotice.
  ///
  /// In en, this message translates to:
  /// **'Read what is sent'**
  String get aiConsentReadNotice;

  /// No description provided for @aiConsentNeeded.
  ///
  /// In en, this message translates to:
  /// **'The AI study tools are off for this account. A student turns them on in their account; a parent does it for a child account.'**
  String get aiConsentNeeded;

  /// Heading of the account-screen group that only platform operators see.
  ///
  /// In en, this message translates to:
  /// **'Platform'**
  String get safetyReviewSection;

  /// Title of the platform operator's safety-report review area, and of its row on the account screen.
  ///
  /// In en, this message translates to:
  /// **'Safety reports'**
  String get safetyReviewTitle;

  /// No description provided for @safetyReviewEntrySubtitle.
  ///
  /// In en, this message translates to:
  /// **'Review reports filed on Studafy. Only platform operators see this.'**
  String get safetyReviewEntrySubtitle;

  /// No description provided for @safetyReviewLoadFailed.
  ///
  /// In en, this message translates to:
  /// **'Could not load the reports.'**
  String get safetyReviewLoadFailed;

  /// No description provided for @safetyReviewUnavailable.
  ///
  /// In en, this message translates to:
  /// **'Could not reach Studafy. Check your connection and try again.'**
  String get safetyReviewUnavailable;

  /// No description provided for @safetyReviewTryAgain.
  ///
  /// In en, this message translates to:
  /// **'Try again'**
  String get safetyReviewTryAgain;

  /// No description provided for @safetyReviewEmptyTitle.
  ///
  /// In en, this message translates to:
  /// **'No open reports'**
  String get safetyReviewEmptyTitle;

  /// No description provided for @safetyReviewEmptyBody.
  ///
  /// In en, this message translates to:
  /// **'New reports also arrive in the safety alert chat.'**
  String get safetyReviewEmptyBody;

  /// No description provided for @safetyReviewNotOperator.
  ///
  /// In en, this message translates to:
  /// **'This account is not a platform operator.'**
  String get safetyReviewNotOperator;

  /// No description provided for @safetyReviewListFooter.
  ///
  /// In en, this message translates to:
  /// **'Only what the alert shows is listed here. A report\'s content opens only with access you ask for, and every step is recorded.'**
  String get safetyReviewListFooter;

  /// No description provided for @safetyReviewSecondApproverBanner.
  ///
  /// In en, this message translates to:
  /// **'A second reviewer now has to approve each access request. Ask them, or follow the operator runbook.'**
  String get safetyReviewSecondApproverBanner;

  /// No description provided for @safetyReviewKindMessage.
  ///
  /// In en, this message translates to:
  /// **'Message report'**
  String get safetyReviewKindMessage;

  /// No description provided for @safetyReviewKindConversation.
  ///
  /// In en, this message translates to:
  /// **'Conversation report'**
  String get safetyReviewKindConversation;

  /// No description provided for @safetyReviewKindUser.
  ///
  /// In en, this message translates to:
  /// **'Report about a person'**
  String get safetyReviewKindUser;

  /// No description provided for @safetyReviewPriorityCritical.
  ///
  /// In en, this message translates to:
  /// **'Critical'**
  String get safetyReviewPriorityCritical;

  /// No description provided for @safetyReviewPriorityHigh.
  ///
  /// In en, this message translates to:
  /// **'High'**
  String get safetyReviewPriorityHigh;

  /// No description provided for @safetyReviewPriorityMedium.
  ///
  /// In en, this message translates to:
  /// **'Medium'**
  String get safetyReviewPriorityMedium;

  /// No description provided for @safetyReviewPriorityLow.
  ///
  /// In en, this message translates to:
  /// **'Low'**
  String get safetyReviewPriorityLow;

  /// The first block of a report's id, as the Telegram alert shows it.
  ///
  /// In en, this message translates to:
  /// **'Report {id}'**
  String safetyReviewReportId(String id);

  /// No description provided for @safetyReviewFiledJustNow.
  ///
  /// In en, this message translates to:
  /// **'Filed just now'**
  String get safetyReviewFiledJustNow;

  /// No description provided for @safetyReviewFiledMinutes.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{Filed 1 minute ago} other{Filed {count} minutes ago}}'**
  String safetyReviewFiledMinutes(int count);

  /// No description provided for @safetyReviewFiledHours.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{Filed 1 hour ago} other{Filed {count} hours ago}}'**
  String safetyReviewFiledHours(int count);

  /// No description provided for @safetyReviewFiledDays.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{Filed 1 day ago} other{Filed {count} days ago}}'**
  String safetyReviewFiledDays(int count);

  /// Shown on a report the operator already holds an active grant for.
  ///
  /// In en, this message translates to:
  /// **'Access open'**
  String get safetyReviewAccessOpen;

  /// No description provided for @safetyReviewStatusSubmitted.
  ///
  /// In en, this message translates to:
  /// **'New'**
  String get safetyReviewStatusSubmitted;

  /// No description provided for @safetyReviewStatusQueued.
  ///
  /// In en, this message translates to:
  /// **'Waiting'**
  String get safetyReviewStatusQueued;

  /// No description provided for @safetyReviewStatusUnderReview.
  ///
  /// In en, this message translates to:
  /// **'Under review'**
  String get safetyReviewStatusUnderReview;

  /// No description provided for @safetyReviewStatusOnHold.
  ///
  /// In en, this message translates to:
  /// **'On hold'**
  String get safetyReviewStatusOnHold;

  /// No description provided for @safetyReviewStatusEscalated.
  ///
  /// In en, this message translates to:
  /// **'Escalated'**
  String get safetyReviewStatusEscalated;

  /// No description provided for @safetyReviewStatusResolved.
  ///
  /// In en, this message translates to:
  /// **'Resolved'**
  String get safetyReviewStatusResolved;

  /// No description provided for @safetyReviewStatusWithdrawn.
  ///
  /// In en, this message translates to:
  /// **'Withdrawn'**
  String get safetyReviewStatusWithdrawn;

  /// No description provided for @safetyReviewReasonTitle.
  ///
  /// In en, this message translates to:
  /// **'Why are you opening this report?'**
  String get safetyReviewReasonTitle;

  /// No description provided for @safetyReviewReasonBody.
  ///
  /// In en, this message translates to:
  /// **'Opening a report gives you access to it for 60 minutes. Your reason is recorded with the access, and every read and decision is recorded too.'**
  String get safetyReviewReasonBody;

  /// No description provided for @safetyReviewReasonLabel.
  ///
  /// In en, this message translates to:
  /// **'Reason'**
  String get safetyReviewReasonLabel;

  /// No description provided for @safetyReviewReasonHint.
  ///
  /// In en, this message translates to:
  /// **'For example: alert received in the safety chat'**
  String get safetyReviewReasonHint;

  /// No description provided for @safetyReviewTextTooShort.
  ///
  /// In en, this message translates to:
  /// **'Write at least 8 characters.'**
  String get safetyReviewTextTooShort;

  /// No description provided for @safetyReviewContinue.
  ///
  /// In en, this message translates to:
  /// **'Continue'**
  String get safetyReviewContinue;

  /// No description provided for @safetyReviewCodeTitle.
  ///
  /// In en, this message translates to:
  /// **'Confirm it is you'**
  String get safetyReviewCodeTitle;

  /// No description provided for @safetyReviewCodeBody.
  ///
  /// In en, this message translates to:
  /// **'Enter the 6-digit code from your authenticator app.'**
  String get safetyReviewCodeBody;

  /// No description provided for @safetyReviewCodeLabel.
  ///
  /// In en, this message translates to:
  /// **'Authenticator code'**
  String get safetyReviewCodeLabel;

  /// No description provided for @safetyReviewCodeDigits.
  ///
  /// In en, this message translates to:
  /// **'Enter the 6 digits.'**
  String get safetyReviewCodeDigits;

  /// No description provided for @safetyReviewOpenReport.
  ///
  /// In en, this message translates to:
  /// **'Open report'**
  String get safetyReviewOpenReport;

  /// No description provided for @safetyReviewWrongCode.
  ///
  /// In en, this message translates to:
  /// **'That code did not match. Check that your phone\'s clock is right, then try the newest code.'**
  String get safetyReviewWrongCode;

  /// No description provided for @safetyReviewNotEnrolledTitle.
  ///
  /// In en, this message translates to:
  /// **'Set up two-factor sign-in first'**
  String get safetyReviewNotEnrolledTitle;

  /// No description provided for @safetyReviewNotEnrolledBody.
  ///
  /// In en, this message translates to:
  /// **'Reviewing reports needs a code from an authenticator app. Set one up in Account, Security, then come back.'**
  String get safetyReviewNotEnrolledBody;

  /// No description provided for @safetyReviewOpenSecurity.
  ///
  /// In en, this message translates to:
  /// **'Open account security'**
  String get safetyReviewOpenSecurity;

  /// No description provided for @safetyReviewWorking.
  ///
  /// In en, this message translates to:
  /// **'Opening the report'**
  String get safetyReviewWorking;

  /// No description provided for @safetyReviewGrantEndedTitle.
  ///
  /// In en, this message translates to:
  /// **'Your access has ended'**
  String get safetyReviewGrantEndedTitle;

  /// No description provided for @safetyReviewGrantEndedBody.
  ///
  /// In en, this message translates to:
  /// **'Access to a report lasts 60 minutes, or until it is revoked. Ask again to keep reviewing.'**
  String get safetyReviewGrantEndedBody;

  /// No description provided for @safetyReviewAskAgain.
  ///
  /// In en, this message translates to:
  /// **'Ask for access again'**
  String get safetyReviewAskAgain;

  /// No description provided for @safetyReviewSecondApproverTitle.
  ///
  /// In en, this message translates to:
  /// **'A second reviewer has to approve'**
  String get safetyReviewSecondApproverTitle;

  /// No description provided for @safetyReviewSecondApproverBody.
  ///
  /// In en, this message translates to:
  /// **'There is now more than one reviewer, so another reviewer must approve your access. Ask them to approve it, or follow the operator runbook.'**
  String get safetyReviewSecondApproverBody;

  /// No description provided for @safetyReviewChangedTitle.
  ///
  /// In en, this message translates to:
  /// **'This report changed'**
  String get safetyReviewChangedTitle;

  /// No description provided for @safetyReviewChangedBody.
  ///
  /// In en, this message translates to:
  /// **'Someone else updated it, or it was escalated. Reload to see where it stands.'**
  String get safetyReviewChangedBody;

  /// No description provided for @safetyReviewReload.
  ///
  /// In en, this message translates to:
  /// **'Reload'**
  String get safetyReviewReload;

  /// No description provided for @safetyReviewDetailsHeading.
  ///
  /// In en, this message translates to:
  /// **'What the reporter wrote'**
  String get safetyReviewDetailsHeading;

  /// No description provided for @safetyReviewSnapshotHeading.
  ///
  /// In en, this message translates to:
  /// **'What was reported'**
  String get safetyReviewSnapshotHeading;

  /// No description provided for @safetyReviewSnapshotMessage.
  ///
  /// In en, this message translates to:
  /// **'Message'**
  String get safetyReviewSnapshotMessage;

  /// No description provided for @safetyReviewSnapshotSubject.
  ///
  /// In en, this message translates to:
  /// **'Conversation subject'**
  String get safetyReviewSnapshotSubject;

  /// No description provided for @safetyReviewSnapshotSentAt.
  ///
  /// In en, this message translates to:
  /// **'Sent'**
  String get safetyReviewSnapshotSentAt;

  /// No description provided for @safetyReviewSnapshotSender.
  ///
  /// In en, this message translates to:
  /// **'Sender account'**
  String get safetyReviewSnapshotSender;

  /// No description provided for @safetyReviewSnapshotConversation.
  ///
  /// In en, this message translates to:
  /// **'Conversation'**
  String get safetyReviewSnapshotConversation;

  /// No description provided for @safetyReviewSnapshotState.
  ///
  /// In en, this message translates to:
  /// **'Conversation state'**
  String get safetyReviewSnapshotState;

  /// No description provided for @safetyReviewNothingCaptured.
  ///
  /// In en, this message translates to:
  /// **'Nothing was captured with this report.'**
  String get safetyReviewNothingCaptured;

  /// No description provided for @safetyReviewEvidenceHeading.
  ///
  /// In en, this message translates to:
  /// **'Evidence'**
  String get safetyReviewEvidenceHeading;

  /// No description provided for @safetyReviewEvidenceMessage.
  ///
  /// In en, this message translates to:
  /// **'Message'**
  String get safetyReviewEvidenceMessage;

  /// No description provided for @safetyReviewEvidenceAttachment.
  ///
  /// In en, this message translates to:
  /// **'File'**
  String get safetyReviewEvidenceAttachment;

  /// No description provided for @safetyReviewEvidenceNote.
  ///
  /// In en, this message translates to:
  /// **'Note'**
  String get safetyReviewEvidenceNote;

  /// No description provided for @safetyReviewNoEvidence.
  ///
  /// In en, this message translates to:
  /// **'No evidence attached.'**
  String get safetyReviewNoEvidence;

  /// No description provided for @safetyReviewHistoryHeading.
  ///
  /// In en, this message translates to:
  /// **'History'**
  String get safetyReviewHistoryHeading;

  /// No description provided for @safetyReviewEventSubmitted.
  ///
  /// In en, this message translates to:
  /// **'Filed'**
  String get safetyReviewEventSubmitted;

  /// No description provided for @safetyReviewEventQueued.
  ///
  /// In en, this message translates to:
  /// **'Queued'**
  String get safetyReviewEventQueued;

  /// No description provided for @safetyReviewEventTriage.
  ///
  /// In en, this message translates to:
  /// **'Opened for review'**
  String get safetyReviewEventTriage;

  /// No description provided for @safetyReviewEventResolve.
  ///
  /// In en, this message translates to:
  /// **'Decided'**
  String get safetyReviewEventResolve;

  /// No description provided for @safetyReviewEventAppeal.
  ///
  /// In en, this message translates to:
  /// **'Appealed'**
  String get safetyReviewEventAppeal;

  /// No description provided for @safetyReviewEventEscalate.
  ///
  /// In en, this message translates to:
  /// **'Escalated'**
  String get safetyReviewEventEscalate;

  /// No description provided for @safetyReviewReporterMasked.
  ///
  /// In en, this message translates to:
  /// **'The reporter\'s identity stays hidden unless the report is escalated.'**
  String get safetyReviewReporterMasked;

  /// No description provided for @safetyReviewDecisionHeading.
  ///
  /// In en, this message translates to:
  /// **'Your decision'**
  String get safetyReviewDecisionHeading;

  /// No description provided for @safetyReviewOutcomeUpheld.
  ///
  /// In en, this message translates to:
  /// **'Upheld'**
  String get safetyReviewOutcomeUpheld;

  /// No description provided for @safetyReviewOutcomeUpheldDetail.
  ///
  /// In en, this message translates to:
  /// **'The rules were broken and action was taken.'**
  String get safetyReviewOutcomeUpheldDetail;

  /// No description provided for @safetyReviewOutcomePartial.
  ///
  /// In en, this message translates to:
  /// **'Partly upheld'**
  String get safetyReviewOutcomePartial;

  /// No description provided for @safetyReviewOutcomePartialDetail.
  ///
  /// In en, this message translates to:
  /// **'Part of the report was upheld.'**
  String get safetyReviewOutcomePartialDetail;

  /// No description provided for @safetyReviewOutcomeNotUpheld.
  ///
  /// In en, this message translates to:
  /// **'Not upheld'**
  String get safetyReviewOutcomeNotUpheld;

  /// No description provided for @safetyReviewOutcomeNotUpheldDetail.
  ///
  /// In en, this message translates to:
  /// **'The rules were not broken.'**
  String get safetyReviewOutcomeNotUpheldDetail;

  /// No description provided for @safetyReviewOutcomeNoAction.
  ///
  /// In en, this message translates to:
  /// **'No action'**
  String get safetyReviewOutcomeNoAction;

  /// No description provided for @safetyReviewOutcomeNoActionDetail.
  ///
  /// In en, this message translates to:
  /// **'Nothing here to act on.'**
  String get safetyReviewOutcomeNoActionDetail;

  /// No description provided for @safetyReviewNoteLabel.
  ///
  /// In en, this message translates to:
  /// **'Note'**
  String get safetyReviewNoteLabel;

  /// No description provided for @safetyReviewNoteHint.
  ///
  /// In en, this message translates to:
  /// **'What you decided and why. Do not copy the reported content.'**
  String get safetyReviewNoteHint;

  /// No description provided for @safetyReviewRecord.
  ///
  /// In en, this message translates to:
  /// **'Record decision'**
  String get safetyReviewRecord;

  /// No description provided for @safetyReviewConfirmTitle.
  ///
  /// In en, this message translates to:
  /// **'Record this decision?'**
  String get safetyReviewConfirmTitle;

  /// No description provided for @safetyReviewConfirmBody.
  ///
  /// In en, this message translates to:
  /// **'The report closes as \"{outcome}\" and the reporter is told it was resolved. It cannot be undone here.'**
  String safetyReviewConfirmBody(String outcome);

  /// No description provided for @safetyReviewCancel.
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get safetyReviewCancel;

  /// No description provided for @safetyReviewRecorded.
  ///
  /// In en, this message translates to:
  /// **'Decision recorded.'**
  String get safetyReviewRecorded;

  /// No description provided for @safetyReviewNotDecidable.
  ///
  /// In en, this message translates to:
  /// **'This report cannot be decided here: it is escalated or closed. Follow the operator runbook.'**
  String get safetyReviewNotDecidable;

  /// No description provided for @safetyReviewResolvedAs.
  ///
  /// In en, this message translates to:
  /// **'Resolved: {outcome}'**
  String safetyReviewResolvedAs(String outcome);
}

class _AppL10nDelegate extends LocalizationsDelegate<AppL10n> {
  const _AppL10nDelegate();

  @override
  Future<AppL10n> load(Locale locale) {
    return SynchronousFuture<AppL10n>(lookupAppL10n(locale));
  }

  @override
  bool isSupported(Locale locale) =>
      <String>['ar', 'en'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppL10nDelegate old) => false;
}

AppL10n lookupAppL10n(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'ar':
      return AppL10nAr();
    case 'en':
      return AppL10nEn();
  }

  throw FlutterError(
    'AppL10n.delegate failed to load unsupported locale "$locale". This is likely '
    'an issue with the localizations generation tool. Please file an issue '
    'on GitHub with a reproducible sample app and the gen-l10n configuration '
    'that was used.',
  );
}
