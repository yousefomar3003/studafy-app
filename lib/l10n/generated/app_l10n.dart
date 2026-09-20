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
