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

  /// Placeholder legal copy. REL-002 B5 replaces both policy bodies with hosted documents; this Arabic text has not been reviewed by counsel.
  ///
  /// In en, this message translates to:
  /// **'Studafy uses account, school, class, attendance, and communication data only to provide and secure the service. Schools control student records. We do not sell personal data. Contact your school to access, correct, or delete eligible records.'**
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

  /// No description provided for @dashNotifications.
  ///
  /// In en, this message translates to:
  /// **'Notifications'**
  String get dashNotifications;

  /// No description provided for @dashTakeAttendance.
  ///
  /// In en, this message translates to:
  /// **'Take attendance'**
  String get dashTakeAttendance;

  /// No description provided for @dashAddNotebook.
  ///
  /// In en, this message translates to:
  /// **'Add lesson notebook'**
  String get dashAddNotebook;

  /// No description provided for @dashAttendanceRecorded.
  ///
  /// In en, this message translates to:
  /// **'Attendance recorded'**
  String get dashAttendanceRecorded;

  /// No description provided for @dashNotebookMissing.
  ///
  /// In en, this message translates to:
  /// **'Notebook missing'**
  String get dashNotebookMissing;

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

  /// No description provided for @notebookTitle.
  ///
  /// In en, this message translates to:
  /// **'Lesson notebook'**
  String get notebookTitle;

  /// No description provided for @notebookLessonLabel.
  ///
  /// In en, this message translates to:
  /// **'Lesson covered'**
  String get notebookLessonLabel;

  /// No description provided for @notebookLessonHint.
  ///
  /// In en, this message translates to:
  /// **'What did you teach today?'**
  String get notebookLessonHint;

  /// No description provided for @notebookHomeworkLabel.
  ///
  /// In en, this message translates to:
  /// **'Homework (optional)'**
  String get notebookHomeworkLabel;

  /// No description provided for @notebookSave.
  ///
  /// In en, this message translates to:
  /// **'Save notebook'**
  String get notebookSave;

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
