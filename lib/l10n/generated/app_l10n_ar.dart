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
}
