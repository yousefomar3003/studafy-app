// ignore: unused_import
import 'package:intl/intl.dart' as intl;

import 'app_l10n.dart';

// ignore_for_file: type=lint

/// The translations for Arabic (`ar`).
class AppL10nAr extends AppL10n {
  AppL10nAr([String locale = 'ar']) : super(locale);

  @override
  String get languagePickerTitle => 'لغة التطبيق';

  @override
  String get languagePickerSubtitle => 'يتغيّر اتجاه الواجهة تلقائيًا.';

  @override
  String get languageSystemDefault => 'لغة النظام';

  @override
  String get languageSystemDefaultDetail => 'اتّباع لغة هذا الجهاز';

  @override
  String get languageEnglish => 'English';

  @override
  String get languageArabic => 'العربية';

  @override
  String get securityTitle => 'أمان الحساب';

  @override
  String get securityLoadFailed => 'تعذّر تحميل إعدادات الأمان. حاول مرة أخرى.';

  @override
  String get securityTryAgain => 'إعادة المحاولة';

  @override
  String get securityCodeMismatch => 'الرمز غير مطابق.';

  @override
  String get securitySetupFailed => 'تعذّر إعداد تسجيل الدخول بخطوتين.';

  @override
  String get securitySignOutDeviceTitle => 'تسجيل الخروج من هذا الجهاز؟';

  @override
  String securitySignOutDeviceBody(String device) {
    return 'سيحتاج $device إلى تسجيل الدخول من جديد.';
  }

  @override
  String get securityKeepIt => 'الإبقاء عليه';

  @override
  String get securitySignItOut => 'تسجيل الخروج';

  @override
  String get securityRevokeFailed => 'تعذّر تسجيل خروج هذا الجهاز.';

  @override
  String get securitySignOutEverywhereTitle => 'تسجيل الخروج من كل الأجهزة؟';

  @override
  String get securitySignOutEverywhereBody =>
      'سيتم تسجيل الخروج من كل جهاز مسجَّل الدخول بهذا الحساب، بما في ذلك هذا الجهاز. تتوقف الجلسات فورًا.';

  @override
  String get securityCancel => 'إلغاء';

  @override
  String get securitySignOutEverywhere => 'تسجيل الخروج من كل الأجهزة';

  @override
  String get securityTwoFactorHeading => 'تسجيل الدخول بخطوتين';

  @override
  String get securityTwoFactorOn => 'مُفعَّل';

  @override
  String get securityTwoFactorOff => 'غير مُعَد';

  @override
  String get securityTwoFactorOnDetail =>
      'تستخدم تطبيق المصادقة عند تسجيل الدخول.';

  @override
  String get securityTwoFactorOffDetail =>
      'على مديري المدارس تفعيل هذه الميزة قبل إدارة المدرسة.';

  @override
  String get securitySetUp => 'إعداد';

  @override
  String get securityDevicesHeading => 'الأجهزة المسجَّل دخولها';

  @override
  String get securityNoOtherDevices => 'لا توجد أجهزة أخرى';

  @override
  String get securityOnlyThisDevice => 'هذا الجهاز وحده مسجَّل الدخول.';

  @override
  String get securityThisDevice => 'هذا الجهاز';

  @override
  String get securityDeviceSignedOut => 'تم تسجيل الخروج';

  @override
  String securityLastUsed(String when) {
    return 'آخر استخدام $when';
  }

  @override
  String get securitySignOut => 'تسجيل الخروج';

  @override
  String get securityTotpTitle => 'إعداد تسجيل الدخول بخطوتين';

  @override
  String get securityTotpBody =>
      'أضف هذا المفتاح إلى تطبيق المصادقة، ثم أدخل الرمز المكوَّن من ستة أرقام الذي يعرضه.';

  @override
  String get securityVerify => 'تأكيد';

  @override
  String get securityJustNow => 'الآن';

  @override
  String securityMinutesAgo(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'قبل $count دقيقة',
      many: 'قبل $count دقيقة',
      few: 'قبل $count دقائق',
      two: 'قبل دقيقتين',
      one: 'قبل دقيقة',
      zero: 'الآن',
    );
    return '$_temp0';
  }

  @override
  String securityHoursAgo(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'قبل $count ساعة',
      many: 'قبل $count ساعة',
      few: 'قبل $count ساعات',
      two: 'قبل ساعتين',
      one: 'قبل ساعة',
      zero: 'الآن',
    );
    return '$_temp0';
  }

  @override
  String securityDaysAgo(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'قبل $count يوم',
      many: 'قبل $count يومًا',
      few: 'قبل $count أيام',
      two: 'قبل يومين',
      one: 'قبل يوم',
      zero: 'اليوم',
    );
    return '$_temp0';
  }

  @override
  String get roleQuestion => 'كيف ستستخدم ستودافاي؟';

  @override
  String get roleChoosePrompt => 'اختر دورك لتخصيص تجربتك.';

  @override
  String get roleContinue => 'متابعة';

  @override
  String get roleTeacher => 'معلم';

  @override
  String get roleTeacherDetail => 'إدارة الفصول والحضور والتعلّم';

  @override
  String get roleStudent => 'طالب';

  @override
  String get roleStudentDetail => 'التعلّم وتسليم الواجبات ومتابعة الجديد';

  @override
  String get roleParent => 'ولي أمر';

  @override
  String get roleParentDetail => 'متابعة التقدّم وأخبار المدرسة';

  @override
  String loginWelcome(String role) {
    return 'أهلًا بك، $role';
  }

  @override
  String get loginSubtitle => 'استخدم حساب مدرستك أو حسابك الشخصي للمتابعة.';

  @override
  String loginContinueWith(String provider) {
    return 'المتابعة باستخدام $provider';
  }

  @override
  String get loginConsentPrefix => 'أوافق على ';

  @override
  String get loginConsentAnd => ' و';

  @override
  String get loginConsentSuffix => '.';

  @override
  String get loginTermsOfUse => 'شروط الاستخدام';

  @override
  String get loginPrivacyPolicy => 'سياسة الخصوصية';

  @override
  String get loginAcceptFirst => 'يرجى الموافقة قبل تسجيل الدخول.';

  @override
  String get loginChangeRole => 'تغيير الدور';

  @override
  String get loginClose => 'إغلاق';

  @override
  String get policyPrivacyBody =>
      'تستخدم ستودافاي بيانات الحساب والمدرسة والفصل والحضور والتواصل لتقديم الخدمة وتأمينها فقط. تتحكم المدارس في سجلات الطلاب. لا نبيع البيانات الشخصية. تواصل مع مدرستك للاطلاع على السجلات المؤهَّلة أو تصحيحها أو حذفها.';

  @override
  String get policyTermsBody =>
      'استخدم ستودافاي للتواصل المدرسي المصرَّح به فقط. حافظ على أمان الحسابات، واحترم الطلاب والعاملين، ولا ترفع محتوى ضارًا أو مخالفًا للقانون. تظل سياسات المدرسة سارية. قد يؤدي سوء الاستخدام إلى تعليق الحساب.';

  @override
  String get deleteTitle => 'حذف الحساب';

  @override
  String get deleteWarningTitle => 'يؤثر هذا على أكثر من ملفك الشخصي';

  @override
  String get deleteWarningBody =>
      'سينتهي وصولك إلى ملفك الشخصي وفصولك ورسائلك وملفاتك الشخصية.';

  @override
  String get deleteWhatGoesHeading => 'ما الذي سيُحذف';

  @override
  String get deleteSchoolKeepsHeading => 'ما تحتفظ به مدرستك';

  @override
  String get deleteSchoolKeepsBody =>
      'المدارس ملزمة بالاحتفاظ بهذه السجلات التعليمية. تبقى لدى المدرسة لا مع حسابك، وحذف حسابك لا يزيلها. راجع مدرستك إذا احتجت إلى تصحيحها أو محوها.';

  @override
  String get deleteNoSchoolRecords => 'لا تحتفظ مدرستك بأي سجلات لهذا الحساب.';

  @override
  String get deleteSchoolAccessHeading => 'صلاحيات المدارس التي ستنتهي';

  @override
  String get deleteWhyHeading => 'أخبرنا بالسبب';

  @override
  String get deleteReasonLabel => 'سبب المغادرة';

  @override
  String get deleteReasonNoLongerUsing => 'لم أعد أستخدم ستودافاي';

  @override
  String get deleteReasonChangingSchools => 'أنا أنتقل إلى مدرسة أخرى';

  @override
  String get deleteReasonPrivacy => 'مخاوف تتعلق بالخصوصية';

  @override
  String get deleteReasonDuplicate => 'لديّ حساب آخر';

  @override
  String get deleteReasonUndisclosed => 'أفضّل عدم الإفصاح';

  @override
  String get deleteAcknowledgementsHeading => 'الإقرارات';

  @override
  String get deleteSavedWhatINeed => 'حفظت ما أحتاج إليه';

  @override
  String get deleteSavedWhatINeedDetail =>
      'تنزيل نسخة من بياناتك وملفاتك الشخصية';

  @override
  String deleteUnderstandFinal(int days) {
    String _temp0 = intl.Intl.pluralLogic(
      days,
      locale: localeName,
      other: 'أفهم أنه لا يمكن التراجع عن ذلك بعد $days يوم',
      many: 'أفهم أنه لا يمكن التراجع عن ذلك بعد $days يومًا',
      few: 'أفهم أنه لا يمكن التراجع عن ذلك بعد $days أيام',
      two: 'أفهم أنه لا يمكن التراجع عن ذلك بعد يومين',
      one: 'أفهم أنه لا يمكن التراجع عن ذلك بعد يوم واحد',
      zero: 'أفهم أنه لا يمكن التراجع عن ذلك',
    );
    return '$_temp0';
  }

  @override
  String deleteCancelWindow(int days) {
    String _temp0 = intl.Intl.pluralLogic(
      days,
      locale: localeName,
      other: 'يمكنك الإلغاء من داخل التطبيق خلال $days يوم',
      many: 'يمكنك الإلغاء من داخل التطبيق خلال $days يومًا',
      few: 'يمكنك الإلغاء من داخل التطبيق خلال $days أيام',
      two: 'يمكنك الإلغاء من داخل التطبيق خلال يومين',
      one: 'يمكنك الإلغاء من داخل التطبيق خلال يوم واحد',
      zero: 'يمكنك الإلغاء من داخل التطبيق',
    );
    return '$_temp0';
  }

  @override
  String get deleteUnderstandSchoolKeeps => 'أفهم أن مدرستي تحتفظ ببعض السجلات';

  @override
  String deleteRetainedCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'يبقى $count سجل تعليمي لدى مدرستك',
      many: 'يبقى $count سجلًا تعليميًا لدى مدرستك',
      few: 'تبقى $count سجلات تعليمية لدى مدرستك',
      two: 'يبقى سجلان تعليميان لدى مدرستك',
      one: 'يبقى سجل تعليمي واحد لدى مدرستك',
      zero: 'لا تبقى أي سجلات تعليمية لدى مدرستك',
    );
    return '$_temp0';
  }

  @override
  String deleteTypeToConfirm(String word, String email) {
    return 'اكتب $word لتأكيد حذف $email.';
  }

  @override
  String get deleteWorking => 'جارٍ التنفيذ…';

  @override
  String get deleteSchedule => 'جدولة حذف الحساب';

  @override
  String get deleteConfirmIdentityNote =>
      'سيُطلب منك تأكيد هويتك قبل جدولة الحذف.';

  @override
  String get deleteKeptSnack => 'سيتم الإبقاء على حسابك.';

  @override
  String get deleteScheduledTitle => 'تمت جدولة الحذف';

  @override
  String deleteScheduledBody(String email, String date) {
    return 'سيُحذف $email بعد $date. حتى ذلك الحين يمكنك إيقاف الحذف من هنا، دون الحاجة إلى مراسلة الدعم.';
  }

  @override
  String get deleteKeepMyAccount => 'الإبقاء على حسابي';

  @override
  String get deleteTryAgain => 'إعادة المحاولة';

  @override
  String get recordProfile => 'ملفك الشخصي';

  @override
  String get recordDevices => 'الأجهزة المسجَّل دخولها';

  @override
  String get recordConsents => 'سجلات الموافقة';

  @override
  String get recordNotifications => 'الإشعارات';

  @override
  String get recordAttendance => 'سجلات الحضور';

  @override
  String get recordGrades => 'الدرجات';

  @override
  String get recordSubmissions => 'الواجبات المسلَّمة';

  @override
  String get recordWellbeing => 'ملاحظات الرعاية';

  @override
  String get academicTitle => 'مساحة العمل الدراسية';

  @override
  String get academicNoRecords => 'لا توجد سجلات بعد.';

  @override
  String get academicUnavailable =>
      'بيانات المدرسة غير متاحة. لم تُحفظ أي نسخة محلية.';

  @override
  String get academicRetry => 'إعادة المحاولة';

  @override
  String get academicFileNote => 'تسجيل ملاحظة درس نصية';

  @override
  String get academicNoteTitle => 'ملاحظة درس نصية';

  @override
  String get academicNoteTitleLabel => 'العنوان';

  @override
  String get academicNoteBodyLabel => 'الملاحظة';

  @override
  String get academicAttachmentsUnavailable =>
      'المرفقات غير متاحة حتى تُفعَّل ميزة رفع الملفات.';

  @override
  String get academicNoteNotSaved =>
      'لم يتم الحفظ. نصّك محفوظ هنا حتى تعيد المحاولة.';

  @override
  String get academicCancel => 'إلغاء';

  @override
  String get academicSaveToSchool => 'حفظ في المدرسة';

  @override
  String get feedContent => 'الدروس';

  @override
  String get feedAssignments => 'الواجبات';

  @override
  String get feedAssessments => 'التقييمات';

  @override
  String get feedGrades => 'الدرجات';

  @override
  String get feedAttendance => 'الحضور';

  @override
  String get feedWellbeing => 'الرعاية';

  @override
  String get classesTitle => 'فصولي';

  @override
  String get classesCreate => 'إنشاء فصل';

  @override
  String get classesCreateTitle => 'إنشاء فصل جديد';

  @override
  String get classesNameLabel => 'اسم الفصل';

  @override
  String get classesRoomLabel => 'القاعة';

  @override
  String get classesGradeLabel => 'الصف';

  @override
  String classesGradeOption(int number) {
    return 'الصف $number';
  }

  @override
  String get classesSectionLabel => 'الشعبة';

  @override
  String get classesWeeklyLabel => 'كم حصة في الأسبوع؟';

  @override
  String classesWeeklyOption(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count حصة',
      many: '$count حصة',
      few: '$count حصص',
      two: 'حصتان',
      one: 'حصة واحدة',
      zero: 'لا حصص',
    );
    return '$_temp0';
  }

  @override
  String get classesChooseTimes => 'اختر يوم كل حصة ووقتها';

  @override
  String classesSessionNumber(int number) {
    return 'الحصة $number';
  }

  @override
  String get classesDayLabel => 'اليوم';

  @override
  String get classesTo => 'إلى';

  @override
  String get classesCancel => 'إلغاء';

  @override
  String get classesCreateAction => 'إنشاء الفصل';

  @override
  String get classesInviteTitle => 'دعوة الطلاب';

  @override
  String get classesInviteBody =>
      'شارك هذا الرابط الآمن. لا يُضاف الطلاب إلا بعد فتحه والانضمام إلى الفصل.';

  @override
  String get classesInviteCopied => 'تم نسخ رابط الدعوة.';

  @override
  String get classesCopy => 'نسخ';

  @override
  String get classesShareLink => 'مشاركة الرابط';

  @override
  String classesShareMessage(String link) {
    return 'انضم إلى فصلي في ستودافاي: $link';
  }

  @override
  String classesGradeSection(String grade, String section) {
    return 'الصف $grade · الشعبة $section';
  }

  @override
  String classesStudentCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count طالب',
      many: '$count طالبًا',
      few: '$count طلاب',
      two: 'طالبان',
      one: 'طالب واحد',
      zero: 'لا طلاب',
    );
    return '$_temp0';
  }

  @override
  String classesPerWeek(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count حصة أسبوعيًا',
      many: '$count حصة أسبوعيًا',
      few: '$count حصص أسبوعيًا',
      two: 'حصتان أسبوعيًا',
      one: 'حصة واحدة أسبوعيًا',
      zero: 'لا حصص أسبوعيًا',
    );
    return '$_temp0';
  }

  @override
  String get classesRoomTbd => 'القاعة لم تُحدَّد';

  @override
  String get dashNotifications => 'الإشعارات';

  @override
  String get dashTakeAttendance => 'تسجيل الحضور';

  @override
  String get dashAddNotebook => 'إضافة دفتر الدرس';

  @override
  String get dashAttendanceRecorded => 'تم تسجيل الحضور';

  @override
  String get dashNotebookMissing => 'دفتر الدرس ناقص';

  @override
  String get attendancePresent => 'حاضر';

  @override
  String get attendanceAbsent => 'غائب';

  @override
  String get attendanceTardy => 'متأخر';

  @override
  String get attendanceExcused => 'غياب بعذر';

  @override
  String get attendanceExcusedReason => 'سبب الغياب بعذر';

  @override
  String get attendanceSaved => 'تم حفظ الحضور بنجاح.';

  @override
  String get attendanceSave => 'حفظ الحضور';

  @override
  String get notebookTitle => 'دفتر الدرس';

  @override
  String get notebookLessonLabel => 'الدرس الذي شُرح';

  @override
  String get notebookLessonHint => 'ماذا درّست اليوم؟';

  @override
  String get notebookHomeworkLabel => 'الواجب المنزلي (اختياري)';

  @override
  String get notebookSave => 'حفظ الدفتر';

  @override
  String get syntheticBanner =>
      'بيانات تجريبية — ليست للاستخدام المدرسي الفعلي';

  @override
  String get blockedTitle => 'ستودافاي غير جاهز للإنتاج';

  @override
  String get blockedDefaultReason =>
      'الوصول إلى بيئة الإنتاج محظور حتى تُستوفى متطلبات الأمان وسلامة البيانات.';

  @override
  String get blockedReference => 'المرجع: SEC-001';

  @override
  String get blockedInvalidEnvironment =>
      'قيمة APP_ENV غير صحيحة. تم حظر هذه النسخة لدواعي السلامة.';

  @override
  String attendanceTitle(String className) {
    return 'الحضور · $className';
  }

  @override
  String get attendanceAction => 'تسجيل الحضور';

  @override
  String get attendanceWhichSession => 'أي حصة؟';

  @override
  String get attendanceNoSessionThatDay =>
      'لا تُعقد هذه الحصة في اليوم الذي اخترته.';

  @override
  String get attendanceNoStudents => 'لا يوجد طلاب مسجّلون في هذا الفصل.';

  @override
  String get attendanceSaving => 'جارٍ الحفظ…';

  @override
  String get attendanceMarkOne => 'حدّد طالبًا واحدًا على الأقل أولًا.';

  @override
  String get attendanceLoadFailed =>
      'تعذّر تحميل سجل الحضور. يُرجى المحاولة مرة أخرى.';

  @override
  String get attendanceReasonLabel => 'السبب (اختياري)';

  @override
  String rosterTitle(String className) {
    return 'الطلاب · $className';
  }

  @override
  String get rosterAction => 'الطلاب';

  @override
  String get rosterNoGuardian => 'لا يوجد وليّ أمر مرتبط بعد';

  @override
  String get rosterEmpty => 'لا يوجد طلاب مسجّلون في هذا الفصل بعد.';

  @override
  String get rosterLoadFailed =>
      'تعذّر تحميل قائمة الفصل. يُرجى المحاولة مرة أخرى.';

  @override
  String get rosterTryAgain => 'إعادة المحاولة';

  @override
  String attendanceSavedCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'تم حفظ الحضور لـ$count طالبًا.',
      few: 'تم حفظ الحضور لـ$count طلاب.',
      two: 'تم حفظ الحضور لطالبين.',
      one: 'تم حفظ الحضور لطالب واحد.',
    );
    return '$_temp0';
  }

  @override
  String get assignmentNewTitle => 'واجب جديد';

  @override
  String get assignmentAction => 'واجب جديد';

  @override
  String get assignmentClassLabel => 'الفصل';

  @override
  String get assignmentTitleLabel => 'العنوان';

  @override
  String get assignmentInstructionsLabel => 'التعليمات (اختياري)';

  @override
  String get assignmentDueLabel => 'تاريخ التسليم';

  @override
  String get assignmentPickDue => 'اختر تاريخ التسليم';

  @override
  String get assignmentGradedLabel => 'بدرجة';

  @override
  String get assignmentGradedOn =>
      'يحصل الطلاب على درجة من الحد الأقصى الذي تحدده.';

  @override
  String get assignmentGradedOff => 'يسلّم الطلاب العمل بدون درجة.';

  @override
  String get assignmentMaxScoreLabel => 'الدرجة القصوى';

  @override
  String get assignmentCreate => 'إنشاء الواجب';

  @override
  String get assignmentCreating => 'جارٍ الإنشاء…';

  @override
  String get assignmentCreated => 'تم إنشاء الواجب.';

  @override
  String get assignmentTitleRequired => 'أدخل عنوانًا للواجب.';

  @override
  String get assignmentClassRequired => 'اختر الفصل المخصص له هذا الواجب.';

  @override
  String get assignmentDueRequired => 'اختر موعد التسليم.';

  @override
  String get assignmentMaxScoreRequired => 'حدد درجة قصوى أكبر من صفر.';

  @override
  String get assignmentCreateFailed =>
      'تعذّر إنشاء الواجب. يُرجى المحاولة مرة أخرى.';

  @override
  String get announcementNewTitle => 'إعلان جديد';

  @override
  String get announcementAction => 'إعلان';

  @override
  String get announcementTitleLabel => 'العنوان';

  @override
  String get announcementBodyLabel => 'الرسالة';

  @override
  String get announcementClassLabel => 'الفصل';

  @override
  String get announcementAudienceLabel => 'من يمكنه رؤية هذا';

  @override
  String get announcementAudienceStudents => 'الطلاب';

  @override
  String get announcementAudienceGuardians => 'أولياء الأمور';

  @override
  String get announcementAudienceBoth => 'الجميع';

  @override
  String get announcementImportantLabel => 'وضع علامة مهم';

  @override
  String get announcementImportantDetail =>
      'استخدم هذا لما يغيّر ما يفعله الشخص اليوم.';

  @override
  String get announcementPost => 'نشر الإعلان';

  @override
  String get announcementPosting => 'جارٍ النشر…';

  @override
  String get announcementPosted => 'تم نشر الإعلان.';

  @override
  String get announcementTitleRequired => 'أدخل عنوانًا للإعلان.';

  @override
  String get announcementBodyRequired => 'اكتب نص الرسالة.';

  @override
  String get announcementClassRequired => 'اختر الفصل الذي تريد الإعلان فيه.';

  @override
  String get announcementFailed =>
      'تعذّر نشر الإعلان. يُرجى المحاولة مرة أخرى.';

  @override
  String gradebookTitle(String className) {
    return 'سجل الدرجات · $className';
  }

  @override
  String get gradebookAction => 'سجل الدرجات';

  @override
  String get gradebookPickAssessment => 'اختر ما تريد تصحيحه';

  @override
  String get gradebookNoAssessments =>
      'لا يوجد ما يُصحَّح بعد. أنشئ عملًا بدرجة أولًا.';

  @override
  String get gradebookDraftNotice =>
      'لا يزال هذا مسودة. انشره لفتح سجل الدرجات.';

  @override
  String get gradebookPublishAssessment => 'نشر وبدء التصحيح';

  @override
  String get gradebookNoStudents => 'لا يوجد طلاب مسجّلون في هذا الفصل.';

  @override
  String gradebookScoreOf(String max) {
    return 'من $max';
  }

  @override
  String get gradebookSave => 'حفظ الدرجات';

  @override
  String get gradebookSaving => 'جارٍ الحفظ…';

  @override
  String get gradebookSaved => 'تم حفظ الدرجات.';

  @override
  String get gradebookNothingChanged => 'لم تتغيّر أي درجة.';

  @override
  String get gradebookScoreTooHigh => 'لا يمكن أن تتجاوز الدرجة الحد الأقصى.';

  @override
  String get gradebookLoadFailed =>
      'تعذّر تحميل سجل الدرجات. يُرجى المحاولة مرة أخرى.';

  @override
  String get gradebookSaveFailed =>
      'تعذّر حفظ الدرجات. يُرجى المحاولة مرة أخرى.';

  @override
  String get gradebookRelease => 'إرسال الدرجات للطلاب';

  @override
  String get gradebookReleased => 'تم إرسال الدرجات.';

  @override
  String sectionsTitle(String className) {
    return 'الحصص · $className';
  }

  @override
  String get sectionsAction => 'محتوى الحصة';

  @override
  String get sectionsNone => 'لم تُعط أي حصة بعد. سجّل الحضور أولًا.';

  @override
  String get sectionsOutstanding => 'المحتوى غير مرفوع';

  @override
  String get sectionsFiled => 'مغلقة';

  @override
  String get sectionsFileContent => 'رفع المحتوى';

  @override
  String get sectionsClose => 'إغلاق الحصة';

  @override
  String get sectionsClosed => 'تم إغلاق الحصة.';

  @override
  String get sectionsCloseBlocked => 'ارفع محتوى هذه الحصة قبل إغلاقها.';

  @override
  String get sectionsContentTitle => 'ما تم تدريسه';

  @override
  String get sectionsContentTitleLabel => 'العنوان';

  @override
  String get sectionsContentBodyLabel => 'ملخّص الحصة';

  @override
  String get sectionsContentSave => 'رفع';

  @override
  String get sectionsContentSaved => 'تم رفع المحتوى.';

  @override
  String get sectionsContentRequired => 'اكتب ما تم تدريسه في هذه الحصة.';

  @override
  String get sectionsLoadFailed =>
      'تعذّر تحميل الحصص. يُرجى المحاولة مرة أخرى.';

  @override
  String get sectionsSaveFailed => 'تعذّر الحفظ. يُرجى المحاولة مرة أخرى.';

  @override
  String get examNewTitle => 'اختبار جديد';

  @override
  String get examAction => 'اختبار جديد';

  @override
  String get examClassLabel => 'الفصل';

  @override
  String get examTitleLabel => 'العنوان';

  @override
  String get examCategoryLabel => 'النوع';

  @override
  String get examCategoryExam => 'اختبار';

  @override
  String get examCategoryQuiz => 'اختبار قصير';

  @override
  String get examCategoryMidterm => 'منتصف الفصل';

  @override
  String get examCategoryFinal => 'نهائي';

  @override
  String get examDeliveryLabel => 'طريقة الأداء';

  @override
  String get examDeliveryPaper => 'ورقي';

  @override
  String get examDeliveryPaperDetail => 'يُؤدّى في الصف، وتُدخل الدرجات بنفسك.';

  @override
  String get examDeliveryOnline => 'داخل التطبيق';

  @override
  String get examDeliveryOnlineDetail => 'يجيب الطلاب على الأسئلة في ستدفاي.';

  @override
  String get examDeliveryPractice => 'تدريب';

  @override
  String get examDeliveryPracticeDetail => 'يتدرّب الطلاب بحرية ولا يُحتسب.';

  @override
  String get examScheduleLabel => 'موعد الأداء';

  @override
  String get examPickSchedule => 'اختر التاريخ والوقت';

  @override
  String get examQuestionsLabel => 'الأسئلة';

  @override
  String get examAddQuestion => 'إضافة سؤال';

  @override
  String examQuestionPrompt(int number) {
    return 'السؤال $number';
  }

  @override
  String get examQuestionMarks => 'الدرجات';

  @override
  String get examQuestionAnswer => 'الإجابة النموذجية (اختياري)';

  @override
  String get examRemoveQuestion => 'حذف';

  @override
  String get examMoveUp => 'تحريك لأعلى';

  @override
  String get examMoveDown => 'تحريك لأسفل';

  @override
  String examTotalFromQuestions(String total, int count) {
    return 'المجموع: $total درجة من $count سؤالًا.';
  }

  @override
  String get examTotalLabel => 'مجموع الدرجات';

  @override
  String get examNoQuestionsHint =>
      'لا توجد أسئلة. أضِف أسئلة، أو حدّد مجموع الدرجات وصحّحه ورقيًا.';

  @override
  String get examCreate => 'إنشاء الاختبار';

  @override
  String get examCreating => 'جارٍ الإنشاء…';

  @override
  String get examCreated =>
      'تم إنشاء الاختبار كمسودة. انشره من سجل الدرجات عندما تكون جاهزًا.';

  @override
  String get examTitleRequired => 'أدخل عنوانًا للاختبار.';

  @override
  String get examClassRequired => 'اختر الفصل الذي سيؤدي هذا الاختبار.';

  @override
  String get examTotalRequired => 'حدّد مجموع درجات أكبر من صفر.';

  @override
  String get examQuestionPromptRequired => 'كل سؤال يحتاج إلى نصّه.';

  @override
  String get examQuestionMarksRequired =>
      'كل سؤال يحتاج إلى درجات أكبر من صفر.';

  @override
  String get examOnlineNeedsQuestions =>
      'الاختبار داخل التطبيق يحتاج إلى سؤال واحد على الأقل.';

  @override
  String get examCreateFailed =>
      'تعذّر إنشاء الاختبار. يُرجى المحاولة مرة أخرى.';

  @override
  String get examTotalHint =>
      'يؤدي الطلاب هذا خارج التطبيق. أدخل الدرجات في سجل الدرجات، ويرى كل طالب درجته.';

  @override
  String get gradeAwaiting => 'لم تُصحَّح بعد';

  @override
  String gradeScore(String score, String max) {
    return '$score من $max';
  }

  @override
  String get submitTitle => 'تسليم العمل';

  @override
  String get submitAnswerLabel => 'عملك';

  @override
  String get submitAnswerHint => 'اكتب إجابتك أو الصقها.';

  @override
  String get submitSend => 'تسليم';

  @override
  String get submitSending => 'جارٍ التسليم…';

  @override
  String get submitDone => 'تم تسليم العمل.';

  @override
  String get submitEmpty => 'اكتب إجابتك قبل التسليم.';

  @override
  String get submitFailed => 'تعذّر تسليم العمل. يُرجى المحاولة مرة أخرى.';

  @override
  String get submitClosed => 'هذا الواجب غير مفتوح للتسليم.';

  @override
  String get submitAttachmentsSoon =>
      'إرفاق الملفات غير متاح بعد؛ الصق رابطًا إذا احتجت لمشاركة ملف.';

  @override
  String submissionsTitle(String title) {
    return 'المُسلَّم · $title';
  }

  @override
  String get submissionsAction => 'المُسلَّم';

  @override
  String get submissionsNone => 'لم يسلّم أحد شيئًا بعد.';

  @override
  String get submissionsWaiting => 'لم يُسلَّم';

  @override
  String submissionsOn(String when) {
    return 'سُلّم $when';
  }

  @override
  String get submissionsLoadFailed =>
      'تعذّر تحميل ما تم تسليمه. يُرجى المحاولة مرة أخرى.';

  @override
  String submissionsCount(int done, int total) {
    return '$done من $total سلّموا';
  }

  @override
  String scheduleTitle(String className) {
    return 'الجدول · $className';
  }

  @override
  String get scheduleAction => 'الجدول';

  @override
  String get scheduleHint =>
      'يتبع سجل الحضور هذا الجدول، فالفصل الذي يُعقد مرتين أسبوعيًا يحتاج إلى كليهما هنا.';

  @override
  String get scheduleAddSlot => 'إضافة حصة';

  @override
  String get scheduleWeekday => 'اليوم';

  @override
  String get scheduleStarts => 'تبدأ';

  @override
  String get scheduleEnds => 'تنتهي';

  @override
  String get scheduleRemove => 'حذف';

  @override
  String get scheduleSave => 'حفظ الجدول';

  @override
  String get scheduleSaving => 'جارٍ الحفظ…';

  @override
  String get scheduleSaved => 'تم حفظ الجدول.';

  @override
  String get scheduleEmpty =>
      'لا توجد حصص بعد. أضِف حصة ليعرف سجل الحضور موعد هذا الفصل.';

  @override
  String get scheduleEndBeforeStart => 'لا يمكن أن تنتهي الحصة قبل أن تبدأ.';

  @override
  String get scheduleSaveFailed => 'تعذّر حفظ الجدول. يُرجى المحاولة مرة أخرى.';

  @override
  String get weekdayMon => 'الاثنين';

  @override
  String get weekdayTue => 'الثلاثاء';

  @override
  String get weekdayWed => 'الأربعاء';

  @override
  String get weekdayThu => 'الخميس';

  @override
  String get weekdayFri => 'الجمعة';

  @override
  String get weekdaySat => 'السبت';

  @override
  String get weekdaySun => 'الأحد';

  @override
  String get joinLinkActive => 'يوجد رابط انضمام فعّال لهذا الفصل.';

  @override
  String joinLinkUses(int count) {
    return 'استُخدم $count مرة';
  }

  @override
  String joinLinkExpires(String when) {
    return 'ينتهي في $when';
  }

  @override
  String get joinLinkRevoke => 'إلغاء الرابط';

  @override
  String get joinLinkRevoked => 'تم إلغاء الرابط، ولم يعد يعمل لأي شخص يملكه.';

  @override
  String get joinLinkRevokeFailed =>
      'تعذّر إلغاء الرابط. يُرجى المحاولة مرة أخرى.';

  @override
  String get joinLinkNewReplaces => 'إنشاء رابط جديد يحلّ محلّ هذا الرابط.';
}
