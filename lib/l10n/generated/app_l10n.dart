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

  /// In-app summary of docs/legal/privacy-policy.md, which governs. Update both together: this text names the AI provider disclosure and the processor list, so it goes stale the moment either changes. Not reviewed by counsel; the Arabic translation has not been reviewed by a native legal translator.
  ///
  /// In en, this message translates to:
  /// **'WHAT WE COLLECT\nYour name and email from the sign-in provider you choose; the school or class you belong to and your role in it; the work you are set and hand in, your marks, attendance and pastoral notes; messages, announcements and meetings inside the app; files you upload; and your notification settings.\n\nWHY\nTo run your classes, to keep your account secure, to bill subscriptions, and to meet legal duties. We do not sell personal data. We show no advertising. We do not use your data to train any AI model.\n\nTHE STUDY HELPER\nIf you use the study helper, the question you type is sent to an AI company outside Studafy so it can answer. Your name, school, marks, work and messages are never sent. Answers can be wrong, so check anything you hand in. Using the helper is optional.\n\nWHO SEES YOUR WORK\nStaff at your school whose role requires it, and a parent linked to you. Other students cannot see your marks, your submitted work or your private messages. Messages are stored on our servers and are not end-to-end encrypted.\n\nPARENTS AND CHILDREN\nA parent asks to be linked to a student, and the student approves or declines it on their own device. A parent can follow progress; a parent is not given your private messages.\n\nPAYMENTS\nSubscriptions are charged by Apple or Google under their own terms. We never see your card.\n\nWHO ELSE PROCESSES DATA\nSupabase hosts the database, sign-in and files; Amazon Web Services hosts the app and its technical logs; Redis holds short-lived counters; Google, Microsoft and Apple verify sign-in; Cloudflare runs a bot check; Resend sends email and Firebase sends push notifications. Each acts only on our instructions.\n\nWHERE YOUR DATA IS\nData may be processed outside your country, including outside the EEA, protected by Standard Contractual Clauses or an adequacy decision.\n\nWHAT WE CANNOT DELETE\nRecords of significant actions are append-only and cannot be edited or removed, including by us. Schools are often required to keep attendance, assessment and safeguarding records. The app shows you which records stay with your school before you confirm a deletion.\n\nHOW WE PROTECT IT\nAccess to a school\'s data is enforced in the database itself. Secrets are stripped from logs. IP addresses are stored only as a one-way hash. Administrator accounts require two-factor sign-in. Files are scanned before they can be downloaded.\n\nYOUR RIGHTS\nYou may ask for a copy of your data, correct it, delete your account, restrict or object to processing, or withdraw consent. Account deletion and data export are in Account settings, and deletion can be cancelled for 14 days. You may complain to the Data Protection Commission in Ireland at any time.\n\nIf your school controls your records, ask your school first; we will pass your request on and tell you we have.'**
  String get policyPrivacyBody;

  /// Placeholder legal copy. See policyPrivacyBody.
  ///
  /// In en, this message translates to:
  /// **'Use Studafy only for authorized school communication. Keep accounts secure, respect students and staff, and do not upload harmful or unlawful content. School policies continue to apply. Misuse may lead to account suspension.'**
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
  /// **'Join my Studafy class: {link}\nOr type the class code: {code}'**
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

  /// How many questions remain in today's allowance.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =0{No questions left today} =1{1 question left today} other{{count} questions left today}}'**
  String studyAssistantRemaining(int count);

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

  /// No description provided for @schoolAdminAdministrationRequiresTheRemoteBackend.
  ///
  /// In en, this message translates to:
  /// **'Administration requires the remote backend.'**
  String get schoolAdminAdministrationRequiresTheRemoteBackend;

  /// No description provided for @schoolAdminSchoolAdministration.
  ///
  /// In en, this message translates to:
  /// **'School administration'**
  String get schoolAdminSchoolAdministration;

  /// No description provided for @schoolAdminTerms.
  ///
  /// In en, this message translates to:
  /// **'Terms'**
  String get schoolAdminTerms;

  /// No description provided for @schoolAdminGuardians.
  ///
  /// In en, this message translates to:
  /// **'Guardians'**
  String get schoolAdminGuardians;

  /// No description provided for @schoolAdminUpdates.
  ///
  /// In en, this message translates to:
  /// **'Updates'**
  String get schoolAdminUpdates;

  /// No description provided for @schoolAdminAccount.
  ///
  /// In en, this message translates to:
  /// **'Account'**
  String get schoolAdminAccount;

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
  /// **'This month\'s AI allowance is used. It renews on the 1st.'**
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

  /// No description provided for @studyPlansQuestionsTodayAsktodayOfAskperday.
  ///
  /// In en, this message translates to:
  /// **'Questions today: {askToday} of {askPerDay}'**
  String studyPlansQuestionsTodayAsktodayOfAskperday(
    Object askToday,
    Object askPerDay,
  );

  /// No description provided for @studyPlansAiUsedThisMonthRound.
  ///
  /// In en, this message translates to:
  /// **'AI used this month: {round}%'**
  String studyPlansAiUsedThisMonthRound(Object round);

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

  /// No description provided for @guardianVerifyConfirmGuardianVerification.
  ///
  /// In en, this message translates to:
  /// **'Confirm guardian verification'**
  String get guardianVerifyConfirmGuardianVerification;

  /// No description provided for @guardianVerifyRevokeGuardianAccess.
  ///
  /// In en, this message translates to:
  /// **'Revoke guardian access?'**
  String get guardianVerifyRevokeGuardianAccess;

  /// No description provided for @guardianVerifyVerifyOnlyAfterCheckingThe.
  ///
  /// In en, this message translates to:
  /// **'Verify only after checking the guardian’s identity and relationship with the student.'**
  String get guardianVerifyVerifyOnlyAfterCheckingThe;

  /// No description provided for @guardianVerifyThisRemovesAccessGrantedBy.
  ///
  /// In en, this message translates to:
  /// **'This removes access granted by this family link.'**
  String get guardianVerifyThisRemovesAccessGrantedBy;

  /// No description provided for @guardianVerifyLinkStatus.
  ///
  /// In en, this message translates to:
  /// **'Link status'**
  String get guardianVerifyLinkStatus;

  /// No description provided for @guardianVerifyGuardianVerification.
  ///
  /// In en, this message translates to:
  /// **'Guardian verification'**
  String get guardianVerifyGuardianVerification;

  /// No description provided for @guardianVerifyEnterTheLinkIdSupplied.
  ///
  /// In en, this message translates to:
  /// **'Enter the link ID supplied with the verification request.'**
  String get guardianVerifyEnterTheLinkIdSupplied;

  /// No description provided for @guardianVerifyGuardianLinkId.
  ///
  /// In en, this message translates to:
  /// **'Guardian link ID'**
  String get guardianVerifyGuardianLinkId;

  /// No description provided for @guardianVerifyVerificationPeriod.
  ///
  /// In en, this message translates to:
  /// **'Verification period'**
  String get guardianVerifyVerificationPeriod;

  /// No description provided for @guardianVerifyDays.
  ///
  /// In en, this message translates to:
  /// **'days'**
  String get guardianVerifyDays;

  /// No description provided for @guardianVerifyVerifyLink.
  ///
  /// In en, this message translates to:
  /// **'Verify link'**
  String get guardianVerifyVerifyLink;

  /// No description provided for @guardianVerifyRevokeLink.
  ///
  /// In en, this message translates to:
  /// **'Revoke link'**
  String get guardianVerifyRevokeLink;

  /// No description provided for @termsAcademicTerms.
  ///
  /// In en, this message translates to:
  /// **'Academic terms'**
  String get termsAcademicTerms;

  /// No description provided for @termsCreateTerm.
  ///
  /// In en, this message translates to:
  /// **'Create term'**
  String get termsCreateTerm;

  /// No description provided for @termsNoTermsCreated.
  ///
  /// In en, this message translates to:
  /// **'No terms created.'**
  String get termsNoTermsCreated;

  /// No description provided for @termsCreateAcademicTerm.
  ///
  /// In en, this message translates to:
  /// **'Create academic term'**
  String get termsCreateAcademicTerm;

  /// No description provided for @termsName.
  ///
  /// In en, this message translates to:
  /// **'Name'**
  String get termsName;

  /// No description provided for @termsStarts.
  ///
  /// In en, this message translates to:
  /// **'Starts'**
  String get termsStarts;

  /// No description provided for @termsEnds.
  ///
  /// In en, this message translates to:
  /// **'Ends'**
  String get termsEnds;

  /// No description provided for @termsCreate.
  ///
  /// In en, this message translates to:
  /// **'Create'**
  String get termsCreate;

  /// No description provided for @termsTermCreated.
  ///
  /// In en, this message translates to:
  /// **'Term created.'**
  String get termsTermCreated;

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

  /// No description provided for @studyPlansFeatureTenQuestions.
  ///
  /// In en, this message translates to:
  /// **'10 questions a day to the study helper'**
  String get studyPlansFeatureTenQuestions;

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

  /// No description provided for @studyPlansFeatureFortyQuestions.
  ///
  /// In en, this message translates to:
  /// **'40 questions a day'**
  String get studyPlansFeatureFortyQuestions;

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

  /// No description provided for @studyPlansFeatureSixtyQuestions.
  ///
  /// In en, this message translates to:
  /// **'60 questions a day'**
  String get studyPlansFeatureSixtyQuestions;

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

  /// No description provided for @famApprovalsDetail.
  ///
  /// In en, this message translates to:
  /// **'{name} asked to subscribe to Student Notebook.'**
  String famApprovalsDetail(String name);

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

  /// No description provided for @accountExportReauth.
  ///
  /// In en, this message translates to:
  /// **'For your security, sign out and sign in again first.'**
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
  /// **'Work you have set'**
  String get todayWork;

  /// No description provided for @todayWorkEmpty.
  ///
  /// In en, this message translates to:
  /// **'You have not set any work yet.'**
  String get todayWorkEmpty;

  /// No description provided for @todaySections.
  ///
  /// In en, this message translates to:
  /// **'Sections needing content'**
  String get todaySections;

  /// No description provided for @todaySectionsEmpty.
  ///
  /// In en, this message translates to:
  /// **'Every section you have taught has its content filed.'**
  String get todaySectionsEmpty;

  /// No description provided for @todaySectionsOutstanding.
  ///
  /// In en, this message translates to:
  /// **'Content outstanding'**
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
