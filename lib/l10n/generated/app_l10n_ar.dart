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
  String get securitySignOutEverywhereFailed =>
      'تم تسجيل الخروج من هذا الجهاز، لكن تعذّر الوصول إلى أجهزتك الأخرى. حاول مرة أخرى من جهاز مسجَّل الدخول.';

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
      'ما الذي نجمعه\nاسمك وبريدك الإلكتروني من مزوّد تسجيل الدخول الذي تختاره؛ المدرسة أو الصف الذي تنتمي إليه ودورك فيه؛ الواجبات المطلوبة منك وما تسلّمه، ودرجاتك وحضورك وملاحظات الرعاية؛ الرسائل والإعلانات والاجتماعات داخل التطبيق؛ والملفات التي ترفعها؛ وإعدادات الإشعارات.\n\nلماذا\nلتشغيل صفوفك، وحماية حسابك، وإدارة الاشتراكات، والوفاء بالالتزامات القانونية. لا نبيع البيانات الشخصية. لا نعرض أي إعلانات. ولا نستخدم بياناتك لتدريب أي نموذج ذكاء اصطناعي.\n\nمساعد الدراسة\nإذا استخدمت مساعد الدراسة، يُرسل السؤال الذي تكتبه إلى شركة ذكاء اصطناعي خارج ستودافاي للإجابة عليه. لا يُرسل اسمك ولا مدرستك ولا درجاتك ولا أعمالك ولا رسائلك. قد تكون الإجابات خاطئة، فتحقق من أي شيء تسلّمه. استخدام المساعد اختياري.\n\nمن يرى أعمالك\nالعاملون في مدرستك ممن يقتضي دورهم ذلك، وولي الأمر المرتبط بك. لا يستطيع الطلاب الآخرون الاطلاع على درجاتك أو أعمالك المسلَّمة أو رسائلك الخاصة. تُخزَّن الرسائل على خوادمنا وليست مشفّرة طرفًا إلى طرف.\n\nأولياء الأمور والأبناء\nيطلب ولي الأمر الارتباط بالطالب، ويوافق الطالب أو يرفض من جهازه. يستطيع ولي الأمر متابعة التقدّم، ولا يُمنح رسائلك الخاصة.\n\nالمدفوعات\nتُحصَّل الاشتراكات عبر Apple أو Google وفق شروطهما. لا نطّلع على بطاقتك إطلاقًا.\n\nمن يعالج البيانات أيضًا\nتستضيف Supabase قاعدة البيانات وتسجيل الدخول والملفات؛ وتستضيف Amazon Web Services التطبيق وسجلاته التقنية؛ ويحفظ Redis عدادات قصيرة الأجل؛ وتتحقق Google وMicrosoft وApple من تسجيل الدخول؛ وتشغّل Cloudflare فحص الروبوتات؛ وترسل Resend البريد وترسل Firebase الإشعارات. ويعمل كل منهم وفق تعليماتنا فقط.\n\nأين تُعالَج بياناتك\nقد تُعالَج بياناتك خارج بلدك، بما في ذلك خارج المنطقة الاقتصادية الأوروبية، محميةً بالبنود التعاقدية القياسية أو بقرار كفاية.\n\nما لا يمكننا حذفه\nسجلات الإجراءات المهمة تُضاف ولا تُعدَّل ولا تُحذف، ولا حتى من قِبلنا. وكثيرًا ما تكون المدارس ملزمة بالاحتفاظ بسجلات الحضور والتقييم وحماية الطفل. يعرض التطبيق السجلات التي تبقى لدى مدرستك قبل تأكيد الحذف.\n\nكيف نحميها\nيُفرض الوصول إلى بيانات كل مدرسة داخل قاعدة البيانات نفسها. وتُزال الأسرار من السجلات. وتُخزَّن عناوين IP كبصمة أحادية الاتجاه فقط. وتتطلب حسابات المسؤولين تسجيل دخول بخطوتين. وتُفحص الملفات قبل السماح بتنزيلها.\n\nحقوقك\nيمكنك طلب نسخة من بياناتك أو تصحيحها أو حذف حسابك أو تقييد المعالجة أو الاعتراض عليها أو سحب موافقتك. يوجد حذف الحساب وتصدير البيانات في إعدادات الحساب، ويمكن إلغاء الحذف خلال ١٤ يومًا. ويمكنك تقديم شكوى إلى لجنة حماية البيانات في أيرلندا في أي وقت.\n\nإذا كانت مدرستك هي المتحكم في سجلاتك، فاسأل مدرستك أولًا؛ وسننقل طلبك إليها ونخبرك بذلك.';

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
  String get classesInviteCodeLabel => 'رمز الصف';

  @override
  String get classesInviteLinkLabel => 'أو أرسل هذا الرابط';

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
  String classesShareMessageWithCode(String link, String code) {
    return 'انضم إلى فصلي في ستودافاي: $link\nأو اكتب رمز الصف: $code';
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
  String get submitMaterialHeading => 'من المعلّم';

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
  String get submissionsByGuardian => 'سلّمه أحد الوالدين';

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

  @override
  String get joinClassTitle => 'الانضمام إلى صف';

  @override
  String get joinClassPrompt =>
      'اكتب رمز الصف الذي أعطاك إياه معلمك، أو الصق رابط الصف.';

  @override
  String get joinClassField => 'رمز الصف أو رابطه';

  @override
  String get joinClassPaste => 'لصق';

  @override
  String get joinClassNothingToPaste =>
      'لم يُنسخ شيء. اكتب رمز الصف، أو افتح الرابط من رسالة معلمك وسيملؤه التطبيق تلقائيًا.';

  @override
  String get joinClassAction => 'انضم إلى الصف';

  @override
  String get joinClassBusy => 'جارٍ الانضمام…';

  @override
  String get joinClassInvalid =>
      'هذا ليس رمز صف ولا رابطه. يبدو الرمز هكذا: K7QM-4XTR.';

  @override
  String joinClassDone(String className) {
    return 'أنت الآن في $className';
  }

  @override
  String get joinClassContinue => 'تم';

  @override
  String get onboardingStudentTitle => 'انضم إلى صفك الأول';

  @override
  String get onboardingStudentBody =>
      'اطلب رابط الصف من معلمك، ثم الصقه هنا للبدء.';

  @override
  String get onboardingParentTitle => 'اربط حسابك بابنك';

  @override
  String get onboardingParentBody =>
      'اطلب من ابنك معرّف Studafy الخاص به. سيوافق على الطلب من جهازه، فلا يطّلع أحد غيره على أعماله.';

  @override
  String get onboardingParentAction => 'متابعة';

  @override
  String get onboardingTeacherTitle => 'حسابات المعلمين على وشك الجاهزية';

  @override
  String get onboardingTeacherBody =>
      'إنشاء الصفوف من حساب معلم جديد غير مفعّل بعد. يرجى المحاولة بعد قليل.';

  @override
  String get onboardingTeacherReadyTitle => 'جهّز مساحتك للتدريس';

  @override
  String get onboardingTeacherReadyBody =>
      'سنجهّز كل شيء لتتمكن من إنشاء صفك الأول ودعوة الطلاب إليه.';

  @override
  String get onboardingTeacherReadyAction => 'لنبدأ';

  @override
  String get onboardingNotReadyYet =>
      'حسابك جاهز، لكن تعذّر فتحه الآن. حاول مرة أخرى من فضلك.';

  @override
  String get onboardingChangeRole => 'اختر دورًا آخر';

  @override
  String get onboardingSignOut => 'تسجيل الخروج';

  @override
  String get studyAssistantTitle => 'مساعد الدراسة';

  @override
  String get studyAssistantIntro =>
      'اسأل عن أي شيء تدرسه واحصل على شرح. يُرسل سؤالك إلى خدمة ذكاء اصطناعي للإجابة عليه، لذا لا تذكر اسمك أو مدرستك أو أي معلومات خاصة.';

  @override
  String get studyAssistantField => 'سؤالك';

  @override
  String get studyAssistantAsk => 'اسأل';

  @override
  String get studyAssistantBusy => 'جارٍ التفكير…';

  @override
  String get studyAssistantCheckWork =>
      'قد تكون الإجابات خاطئة. تحقق من أي شيء تسلّمه.';

  @override
  String studyAssistantRemaining(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'بقي $count سؤال اليوم',
      many: 'بقي $count سؤالًا اليوم',
      few: 'بقيت $count أسئلة اليوم',
      two: 'بقي سؤالان اليوم',
      one: 'بقي سؤال واحد اليوم',
      zero: 'لم تتبقَ أسئلة اليوم',
    );
    return '$_temp0';
  }

  @override
  String get studyAssistantTab => 'المساعد';

  @override
  String get joinClassAlreadyStaff =>
      'أنت معلم في هذه المدرسة، لذا لا يمكنك الانضمام إلى أحد صفوفها كطالب. اطلب من طالب فتح الرابط من حسابه.';

  @override
  String get academicAllClasses => 'كل الصفوف';

  @override
  String get insightsTitle => 'العائلة+';

  @override
  String get insightsUnavailableTitle => 'التحليلات غير متاحة';

  @override
  String get insightsUnavailableBody =>
      'تحتاج إلى اشتراك العائلة+ لعرض التحليلات التفصيلية، ويجب أن يكون ارتباطك بابنك مُعتمدًا.';

  @override
  String get insightsNothingYetTitle => 'لا يوجد ما نعرضه بعد';

  @override
  String get insightsNothingYetBody =>
      'مع تسجيل المدرسة للدرجات والحضور والأعمال، ستظهر التحليلات هنا. نعرض ما تُظهره السجلات فعلًا فقط.';

  @override
  String get insightsBySubject => 'حسب المادة';

  @override
  String get insightsComingUp => 'القادم';

  @override
  String get insightsFromSchool => 'من المدرسة';

  @override
  String get insightsAverage => 'المعدل';

  @override
  String get insightsAttendance => 'الحضور';

  @override
  String get insightsOnTime => 'في الوقت';

  @override
  String insightSubjectFocus(Object subject) {
    return '$subject هي أضعف مواده حاليًا';
  }

  @override
  String insightTrendDown(Object subject) {
    return 'درجات $subject في تراجع';
  }

  @override
  String insightTrendUp(Object subject) {
    return 'درجات $subject في تحسّن';
  }

  @override
  String insightRecovery(Object subject) {
    return 'تحسّنت $subject من جديد';
  }

  @override
  String get insightHomework => 'مدى الالتزام بتسليم الأعمال';

  @override
  String get insightHomeworkSlipping => 'يتأخر تسليم الأعمال أكثر من السابق';

  @override
  String get insightAttendancePattern =>
      'تتكرر الغيابات في اليوم نفسه من الأسبوع';

  @override
  String get insightDueSoon => 'أعمال يقترب موعدها ولم تُسلَّم';

  @override
  String get insightStrengthInsufficient => 'السجلات غير كافية بعد للتأكيد';

  @override
  String get insightStrengthLow => 'بناءً على عدد قليل من السجلات';

  @override
  String get insightStrengthMedium => 'بناءً على عدد معقول من السجلات';

  @override
  String get insightStrengthHigh => 'بناءً على عدد كبير من السجلات';

  @override
  String insightsDueOn(String date) {
    return 'الموعد $date';
  }

  @override
  String insightsFromMarks(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'من $count درجة',
      many: 'من $count درجة',
      few: 'من $count درجات',
      two: 'من درجتين',
      one: 'من درجة واحدة',
      zero: 'لا توجد درجات بعد',
    );
    return '$_temp0';
  }

  @override
  String insightsAbsences(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count غياب',
      many: '$count غيابًا',
      few: '$count غيابات',
      two: 'غيابان',
      one: 'غياب واحد',
      zero: 'لا غيابات',
    );
    return '$_temp0';
  }

  @override
  String insightsOfTasks(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'من $count عمل',
      many: 'من $count عملًا',
      few: 'من $count أعمال',
      two: 'من عملين',
      one: 'من عمل واحد',
      zero: 'لا توجد أعمال',
    );
    return '$_temp0';
  }

  @override
  String get insightsNoChildTitle => 'اختر ابنًا أولًا';

  @override
  String get insightsNoChildBody =>
      'اختر أحد أبنائك من الصفحة الرئيسية لعرض تحليلاته.';

  @override
  String get historyTitle => 'سجل التسليم';

  @override
  String get historyYours => 'سجل التسليم';

  @override
  String get historyLatest => 'الأحدث';

  @override
  String get historyEarlier => 'سابق';

  @override
  String historyByGuardian(String name) {
    return 'سلّمه $name';
  }

  @override
  String get historyByParent => 'سلّمه أحد الوالدين';

  @override
  String get historyNone => 'لم يُسلَّم شيء بعد.';

  @override
  String get historyLoadFailed => 'تعذّر تحميل السجل. يُرجى المحاولة مرة أخرى.';

  @override
  String get historyNoText => 'لا توجد إجابة مكتوبة.';

  @override
  String get academicPublish => 'نشر';

  @override
  String get academicPublished => 'تم النشر. يمكن للصف رؤيته الآن.';

  @override
  String get academicPublishFailed => 'تعذّر النشر. يُرجى المحاولة مرة أخرى.';

  @override
  String academicGradedOutOf(String score) {
    return 'بدرجة · من $score';
  }

  @override
  String get classesNewCode => 'رمز جديد';

  @override
  String get classesNewCodeTitle => 'إنشاء رمز جديد؟';

  @override
  String get classesNewCodeBody =>
      'سيتوقف الرمز والرابط الحاليان عن العمل. من لم ينضم بعد سيحتاج إلى الرمز الجديد.';

  @override
  String get classesNewCodeConfirm => 'إنشاء رمز جديد';

  @override
  String get attendancePreviousLesson => 'الحصة السابقة';

  @override
  String get attendanceNextLesson => 'الحصة التالية';

  @override
  String get submissionsGrade => 'وضع الدرجات';

  @override
  String get attachmentThatFileCouldNotBe => 'تعذّر رفع هذا الملف.';

  @override
  String get attachmentThatFileIsEmpty => 'هذا الملف فارغ.';

  @override
  String get attachmentOnlyPdfAndPhotosCan =>
      'يمكن إرفاق ملفات PDF والصور فقط.';

  @override
  String attachmentThatFileIsLargerThan(Object maximumSizeBytes) {
    return 'حجم الملف أكبر من $maximumSizeBytes ميغابايت.';
  }

  @override
  String get attachmentAttachFile => 'إرفاق ملف';

  @override
  String get attachmentPhoto => 'صورة';

  @override
  String attachmentUpToMaximumcountAttachments(Object maximumCount) {
    return 'حتى $maximumCount مرفقات.';
  }

  @override
  String get attachmentUploading => 'جارٍ الرفع';

  @override
  String get attachmentChecking => 'قيد الفحص';

  @override
  String get attachmentReady => 'جاهز';

  @override
  String get attachmentFailed => 'فشل';

  @override
  String get attachmentThisFileIsStillBeing =>
      'لا يزال هذا الملف قيد الفحص. حاول مرة أخرى بعد قليل.';

  @override
  String get attachmentThatFileCouldNotBe2 => 'تعذّر فتح هذا الملف.';

  @override
  String get studentTodayALittleProgressEveryDay => 'خطوة صغيرة كل يوم';

  @override
  String get studentTodayYourClassesYourIdeasYour =>
      'فصولك، أفكارك، وإنجازك القادم.';

  @override
  String get studentTodayMyNotebook => 'دفتر دروسي';

  @override
  String get studentTodayLessonNotesSubscription => 'ملاحظات الدروس · اشتراك';

  @override
  String get studentTodayMyWork => 'أعمالي';

  @override
  String get studentTodayTakeTheNextStep => 'خطوتك القادمة';

  @override
  String get studentTodayMyIdFamily => 'معرّفي وعائلتي';

  @override
  String get studentTodayShareYourIdReviewParent =>
      'شارك معرّفك وراجع طلبات أولياء الأمور.';

  @override
  String get studentTodayYourClasses => 'صفوفي';

  @override
  String get studentTodayReadyWhenYouAre => 'جاهز عندما تكون مستعدًا';

  @override
  String get studentTodayYourWorkCouldNotLoad =>
      'تعذر تحميل أعمالك. افتح أعمالي لإعادة المحاولة.';

  @override
  String get studentTodayALittleBreathingRoom => 'وقت لالتقاط الأنفاس';

  @override
  String get studentTodayNewAssignmentsWillAppearHere =>
      'ستظهر الواجبات الجديدة هنا عندما يشاركها معلمك.';

  @override
  String get teacherShellManageRosterStaffAndMeetings =>
      'إدارة الطلاب والمعلمين والاجتماعات';

  @override
  String get teacherShellClasses => 'الفصول';

  @override
  String get teacherShellMessages => 'الرسائل';

  @override
  String get schoolAdminGuardians => 'أولياء الأمور';

  @override
  String get teacherTodaySpaceToInspireADay =>
      'مساحة للإلهام. ويوم لصنع الفرق.';

  @override
  String get studentLessonsPlans => 'الخطط';

  @override
  String get studentLessonsYourClassesCouldNotBe =>
      'تعذّر تحميل صفوفك. حاول مرة أخرى';

  @override
  String get studentLessonsJoinAClassToSee => 'انضم إلى صف لترى دروسه هنا.';

  @override
  String get studentLessonsLessonsAndYourNotebook => 'الدروس ودفترك';

  @override
  String get studentLessonsMyNotebook => 'دفتري';

  @override
  String get studySetQuizzesAndFlashcardsComeWith =>
      'الاختبارات والبطاقات متاحة مع Studafy Max.';

  @override
  String get studySetThisMonthSAiAllowance =>
      'استُخدم رصيد الذكاء الاصطناعي لهذا الشهر. يتجدد في أول الشهر.';

  @override
  String get studySetThisLessonHasNoText =>
      'لا يحتوي هذا الدرس على نص للمراجعة.';

  @override
  String get studySetThisIsNotAvailableYet => 'هذه الميزة غير متاحة بعد.';

  @override
  String get studySetThatDidNotWorkPlease => 'لم تنجح العملية. حاول مرة أخرى.';

  @override
  String studySetYouScoredScoreOfQuestionscount(
    Object score,
    Object questionsCount,
  ) {
    return 'نتيجتك $score من $questionsCount';
  }

  @override
  String studySetAnswerscountOfQuestionscountAnswered(
    Object answersCount,
    Object questionsCount,
  ) {
    return 'أُجيب $answersCount من $questionsCount';
  }

  @override
  String get studySetTryAgain => 'حاول مرة أخرى';

  @override
  String studySetCardPageOfCardscountTap(Object page, Object cardsCount) {
    return 'البطاقة $page من $cardsCount - اضغط لقلبها';
  }

  @override
  String studyPlansQuestionsTodayAsktodayOfAskperday(
    Object askToday,
    Object askPerDay,
  ) {
    return 'أسئلة اليوم: $askToday من $askPerDay';
  }

  @override
  String studyPlansAiUsedThisMonthRound(Object round) {
    return 'الاستخدام هذا الشهر: $round٪';
  }

  @override
  String studyPlansRenewsRenews(Object renews) {
    return 'يتجدد في $renews';
  }

  @override
  String get studyPlansTheStoreCouldNotBe =>
      'تعذّر الوصول إلى المتجر. حاول لاحقًا.';

  @override
  String get studyPlansBuyingIsNotEnabledFor => 'الشراء غير مفعّل لحسابك بعد.';

  @override
  String get studyPlansWeAskedYourParentTo => 'طلبنا موافقة ولي أمرك.';

  @override
  String get studyPlansWaitingForAParent => 'بانتظار موافقة ولي الأمر';

  @override
  String get studyPlansAskAParentToApprove => 'اطلب موافقة ولي الأمر';

  @override
  String get studyPlansOpeningTheStore => 'جارٍ فتح المتجر…';

  @override
  String get studyPlansStartAFreeMonth => 'ابدأ شهرًا مجانيًا';

  @override
  String studyPlansSubscribeToName(Object name) {
    return 'اشترك في $name';
  }

  @override
  String get studyPlansFree => 'مجانًا';

  @override
  String studyPlansPriceMonth(Object price) {
    return '$price / شهريًا';
  }

  @override
  String studyPlansUspriceMonthInTheUs(Object usPrice) {
    return '$usPrice شهريًا في الولايات المتحدة - يعرض المتجر سعرك';
  }

  @override
  String get studyPlansYourPlan => 'خطتك الحالية';

  @override
  String get studyPlansManageOrCancel => 'إدارة أو إلغاء';

  @override
  String get studyPlansRestoringPurchases => 'جارٍ استعادة المشتريات…';

  @override
  String get studyPlansRestorePurchases => 'استعادة المشتريات';

  @override
  String get studyPlansAutoRenewingMonthlySubscriptionsPayment =>
      'اشتراكات شهرية تتجدد تلقائيًا. يُحصَّل المبلغ من حسابك في Apple أو Google. إذا كانت هناك فترة تجربة، يبدأ الدفع عند انتهائها. ألغِ من إعدادات المتجر قبل التجديد بـ 24 ساعة على الأقل لتجنب الدفعة التالية. حذف التطبيق لا يلغي الاشتراك.';

  @override
  String get studyPlansTermsOfUse => 'شروط الاستخدام';

  @override
  String get studyPlansPrivacyPolicy => 'سياسة الخصوصية';

  @override
  String get notebookThisNeedsStudafyPlus => 'هذه الميزة تتطلب Studafy Plus.';

  @override
  String get notebookNoWritingCouldBeRead =>
      'تعذّرت قراءة أي كتابة في الصورة. جرّب صورة أوضح.';

  @override
  String get notebookThePhotoIsTakingLonger =>
      'فحص الصورة يستغرق وقتًا أطول من المعتاد. حاول بعد قليل.';

  @override
  String get notebookNewNote => 'ملاحظة جديدة';

  @override
  String get notebookSave => 'حفظ';

  @override
  String get notebookAddATitleAndSome => 'أضف عنوانًا ونصًا.';

  @override
  String get notebookChooseAJpegOrPng =>
      'اختر صورة JPEG أو PNG أقل من 10 ميغابايت.';

  @override
  String get notebookUploadingThePhoto => 'جارٍ رفع الصورة…';

  @override
  String get notebookReadingTheWhiteboard => 'جارٍ قراءة السبورة…';

  @override
  String get notebookNotesAddedToYourNotebook => 'أُضيفت الملاحظات إلى دفترك.';

  @override
  String get notebookThePhotoCouldNotBe => 'تعذّر رفع الصورة.';

  @override
  String get notebookDeleteThisNote => 'حذف هذه الملاحظة؟';

  @override
  String get notebookDelete => 'حذف';

  @override
  String get notebookToday => 'اليوم';

  @override
  String get notebookYesterday => 'أمس';

  @override
  String get notebookAddNote => 'أضف ملاحظة';

  @override
  String get notebookSnapTheWhiteboard => 'صوّر السبورة';

  @override
  String get notebookFromPhotos => 'من الصور';

  @override
  String get notebookWhiteboardNotesComeWithStudafy =>
      'ملاحظات السبورة متاحة مع Studafy Plus.';

  @override
  String get notebookTheNotebookCouldNotBe =>
      'تعذّر تحميل الدفتر. حاول مرة أخرى';

  @override
  String get notebookYourNotebookForThisClass =>
      'دفترك لهذا الصف فارغ. أضف ملاحظة أو صوّر السبورة.';

  @override
  String get notebookFromTheWhiteboard => 'من السبورة';

  @override
  String get familyHomeTogetherEveryDay => 'معًا، كل يوم';

  @override
  String get familyHomeTheirWorldIsGrowingBe => 'عالمهم ينمو. كن جزءًا منه.';

  @override
  String get childSwitcherChooseChild => 'اختر الطفل';

  @override
  String get familyChallengeSecurityCheck => 'تحقق سريع';

  @override
  String get familyChallengeTheCheckCouldNotLoad =>
      'تعذر تحميل التحقق. ارجع وحاول مرة أخرى.';

  @override
  String get studentFamilyIsThisYourParent => 'هل هذا ولي أمرك؟';

  @override
  String get studentFamilyConfirmYourChoice => 'تأكيد اختيارك';

  @override
  String studentFamilyOnlyApproveGuardiannameIfYou(Object guardianName) {
    return 'وافق على $guardianName فقط إذا كنت تعرف أنه ولي أمرك. سيتمكن من الاطلاع على درجاتك وحضورك وتحديثاتك الدراسية المشتركة.';
  }

  @override
  String get studentFamilyThisPersonWillNotHave =>
      'لن يتمكن هذا الشخص من الوصول عبر هذا الربط العائلي.';

  @override
  String get studentFamilyConfirm => 'تأكيد';

  @override
  String get studentFamilyMyFamily => 'عائلتي';

  @override
  String get studentFamilyYourConnections => 'روابطك';

  @override
  String get studentFamilyYourFamilyYourChoice => 'عائلتك.\nقرارك.';

  @override
  String get studentFamilyShareYourStudafyIdWith =>
      'شارك معرّف Studafy مع ولي أمرك. أنت تقرر من يمكنه متابعة تقدمك.';

  @override
  String get studentFamilyCouldNotLoadRequests => 'تعذر تحميل الطلبات';

  @override
  String get studentFamilyMyStudafyId => 'معرّف STUDAFY';

  @override
  String get studentFamilyCopyId => 'نسخ المعرّف';

  @override
  String get studentFamilyIdCopied => 'تم نسخ المعرّف';

  @override
  String get studentFamilyJoinAClassToActivate =>
      'انضم إلى فصل لتفعيل معرّف الطالب.';

  @override
  String get studentFamilyParentRequests => 'طلبات أولياء الأمور';

  @override
  String get studentFamilyAllCaughtUp => 'أنت على اطلاع';

  @override
  String get studentFamilyNewParentRequestsWillAppear =>
      'ستظهر طلبات أولياء الأمور الجديدة هنا.';

  @override
  String get studentFamilyAccountId => 'معرّف الحساب';

  @override
  String get studentFamilyThisIsMyParent => 'هذا ولي أمري';

  @override
  String get studentFamilyDecline => 'رفض';

  @override
  String get studentFamilyConnected => 'مرتبط';

  @override
  String get studentFamilyRemoveAccess => 'إزالة الوصول';

  @override
  String get studentFamilyDeclined => 'مرفوض';

  @override
  String get studentFamilyAccessRemoved => 'تمت إزالة الوصول';

  @override
  String get lessonsUndated => 'بدون تاريخ';

  @override
  String get lessonsLessonsCouldNotBeLoaded => 'تعذّر تحميل الدروس.';

  @override
  String get lessonsNoLessonsYetTheyAppear =>
      'لا توجد دروس بعد. ستظهر هنا عندما يشاركها معلمك.';

  @override
  String get meetingsGoogleMeetCouldNotBe => 'تعذّر فتح Google Meet.';

  @override
  String get meetingsUpcomingMeetings => 'الاجتماعات القادمة';

  @override
  String get meetingsCancelled => 'أُلغي';

  @override
  String get meetingsTheLinkWillAppearHere => 'سيظهر الرابط هنا.';

  @override
  String get meetingsJoin => 'انضمام';

  @override
  String get conversationSent => 'أُرسلت';

  @override
  String get conversationDelivered => 'وصلت';

  @override
  String get conversationRead => 'قُرئت';

  @override
  String get notificationsNotificationPreferences => 'تفضيلات الإشعارات';

  @override
  String get notificationPrefsAddPreference => 'إضافة تفضيل';

  @override
  String get notificationPrefsChannel => 'القناة';

  @override
  String get notificationPrefsInApp => 'داخل التطبيق';

  @override
  String get notificationPrefsEmail => 'البريد الإلكتروني';

  @override
  String get notificationPrefsPush => 'إشعار فوري';

  @override
  String get notificationPrefsCategory => 'الفئة';

  @override
  String get notificationPrefsAcademic => 'أكاديمي';

  @override
  String get notificationPrefsMessagesAndAnnouncements => 'الرسائل والإعلانات';

  @override
  String get notificationPrefsMeetings => 'الاجتماعات';

  @override
  String get notificationPrefsFamily => 'العائلة';

  @override
  String get notificationPrefsBilling => 'الفوترة';

  @override
  String get notificationPrefsAdd => 'إضافة';

  @override
  String get notificationPrefsPushPreferencesAreSavedBut =>
      'يتم حفظ تفضيلات الإشعارات الفورية، لكن استقبالها غير متاح على هذا الجهاز بعد.';

  @override
  String get notificationPrefsNoPreferencesSavedAddOne =>
      'لا توجد تفضيلات محفوظة. أضف تفضيلًا لاختيار القناة والفئة.';

  @override
  String get classroomAdminStaff => 'المعلمون';

  @override
  String get classroomAdminCreateAndEnrolStudent => 'إنشاء طالب وتسجيله';

  @override
  String get classroomAdminCreatedStudentAwaitingEnrolment =>
      'طالب تم إنشاؤه بانتظار التسجيل';

  @override
  String get classroomAdminStudentEnrolled => 'تم تسجيل الطالب.';

  @override
  String get classroomAdminRetryEnrolment => 'إعادة محاولة التسجيل';

  @override
  String get classroomAdminEnrolByStudentId => 'تسجيل باستخدام معرّف الطالب';

  @override
  String get classroomAdminNoEnrolledStudents => 'لا يوجد طلاب مسجلون.';

  @override
  String get classroomAdminTransfer => 'نقل';

  @override
  String get classroomAdminWithdraw => 'سحب';

  @override
  String get classroomAdminAssignStaff => 'تعيين معلم';

  @override
  String get classroomAdminNoStaffAssignments => 'لا توجد تعيينات للمعلمين.';

  @override
  String get classroomAdminRemove => 'إزالة';

  @override
  String classroomAdminRemoveDisplaynameFromThisClass(Object displayName) {
    return 'إزالة $displayName من هذا الفصل؟';
  }

  @override
  String get classroomAdminStaffRemoved => 'تمت إزالة المعلم.';

  @override
  String get classroomAdminWholeClass => 'الفصل بالكامل';

  @override
  String get classroomAdminScheduleMeeting => 'جدولة اجتماع';

  @override
  String get classroomAdminCreateTheMeetingInGoogle =>
      'أنشئ الاجتماع في Google Meet ثم الصق رابطه هنا. سيُبلَّغ المدعوون في التطبيق ويمكنهم الانضمام منه.';

  @override
  String get classroomAdminNoUpcomingMeetings => 'لا توجد اجتماعات قادمة.';

  @override
  String classroomAdminRecipientcountInvited(Object recipientCount) {
    return 'المدعوون: $recipientCount';
  }

  @override
  String get classroomAdminLinkCopied => 'تم نسخ الرابط.';

  @override
  String get classroomAdminCopyLink => 'نسخ الرابط';

  @override
  String get classroomAdminMeetingCancelled => 'تم إلغاء الاجتماع.';

  @override
  String get classroomAdminCancelMeeting => 'إلغاء الاجتماع';

  @override
  String get classroomAdminCreateStudent => 'إنشاء طالب';

  @override
  String get classroomAdminDisplayName => 'الاسم الظاهر';

  @override
  String get classroomAdminAccountUuidOptional => 'معرّف الحساب UUID (اختياري)';

  @override
  String get classroomAdminStudentCreatedAndEnrolled =>
      'تم إنشاء الطالب وتسجيله.';

  @override
  String get classroomAdminEnrolStudent => 'تسجيل طالب';

  @override
  String get classroomAdminStudentRecordId => 'معرّف سجل الطالب';

  @override
  String classroomAdminWithdrawDisplaynameFromThisClass(Object displayName) {
    return 'سحب $displayName من هذا الفصل؟';
  }

  @override
  String get classroomAdminStudentWithdrawn => 'تم سحب الطالب.';

  @override
  String classroomAdminTransferDisplayname(Object displayName) {
    return 'نقل $displayName';
  }

  @override
  String get classroomAdminTargetClass => 'الفصل المستهدف';

  @override
  String get classroomAdminStudentTransferred => 'تم نقل الطالب.';

  @override
  String get classroomAdminTeacherAccountUuid => 'معرّف حساب المعلم UUID';

  @override
  String get classroomAdminRole => 'الدور';

  @override
  String get classroomAdminCoTeacher => 'معلم مشارك';

  @override
  String get classroomAdminLeadTeacher => 'المعلم الرئيسي';

  @override
  String get classroomAdminAssign => 'تعيين';

  @override
  String get classroomAdminStaffAssigned => 'تم تعيين المعلم.';

  @override
  String get classroomAdminStarts => 'يبدأ';

  @override
  String get classroomAdminTime => 'الوقت';

  @override
  String get classroomAdminDuration => 'المدة';

  @override
  String get classroomAdminMinutes => 'دقيقة';

  @override
  String get classroomAdminAudience => 'الحضور';

  @override
  String get classroomAdminCreateItInGoogleMeet => 'أنشئه في Google Meet';

  @override
  String get classroomAdminGoogleMeetLink => 'رابط Google Meet';

  @override
  String get classroomAdminPasteALinkThatStarts =>
      'الصق رابطًا يبدأ بـ https://meet.google.com/';

  @override
  String get classroomAdminSchedule => 'جدولة';

  @override
  String get classroomAdminMeetingScheduledEveryoneInvitedHas =>
      'تمت جدولة الاجتماع وإبلاغ المدعوين.';

  @override
  String get rolesYourSpaceToGrow => 'مساحتك للنمو';

  @override
  String get studyPlansFeatureLessons => 'دروس كل صف مرتبة حسب التاريخ';

  @override
  String get studyPlansFeatureNotebook => 'دفتر خاص بك لكل صف';

  @override
  String get studyPlansFeatureTenQuestions => '10 أسئلة يوميًا للمساعد الدراسي';

  @override
  String get studyPlansFeatureEverythingInFree => 'كل ما في الخطة المجانية';

  @override
  String get studyPlansFeatureWhiteboard =>
      'صوّر السبورة واحصل على ملاحظات حقيقية في دفترك';

  @override
  String get studyPlansFeatureFortyQuestions => '40 سؤالًا يوميًا';

  @override
  String get studyPlansFeatureEverythingInPlus => 'كل ما في Plus';

  @override
  String get studyPlansFeatureQuizzes => 'اختبارات من دروسك';

  @override
  String get studyPlansFeatureFlashcards => 'بطاقات مراجعة من دروسك';

  @override
  String get studyPlansFeatureSixtyQuestions => '60 سؤالًا يوميًا';

  @override
  String get studentTodayMakeTodayYours => 'اجعل اليوم يومك.';

  @override
  String studentTodayMakeTodayYoursName(Object name) {
    return 'اجعل اليوم يومك، $name.';
  }

  @override
  String get studySetQuiz => 'اختبار';

  @override
  String get studySetFlashcards => 'بطاقات مراجعة';

  @override
  String get studentTodayClassesCouldNotLoad =>
      'تعذّر تحميل صفوفك. اسحب للأسفل لإعادة المحاولة.';

  @override
  String get studentTodayNoClassesYet => 'لا توجد صفوف بعد';

  @override
  String get studentTodayPasteClassLink =>
      'الصق رابط الصف الذي شاركه معلمك للانضمام إلى صفك الأول.';

  @override
  String studentTodayGradeSection(Object grade, Object section) {
    return 'الصف $grade · $section';
  }

  @override
  String get msgTitle => 'الرسائل';

  @override
  String get msgEmptyTitle => 'لا توجد محادثات بعد';

  @override
  String get msgEmptyMessage => 'ابدأ محادثة مع مدرستك.';

  @override
  String get msgEmptyAwaitingLink =>
      'عند ربط طفل بك، يمكنك مراسلة معلميه من هنا.';

  @override
  String get msgNew => 'رسالة جديدة';

  @override
  String get msgNoSchool => 'اختر مدرسة لعرض الرسائل.';

  @override
  String get msgRetry => 'حاول مرة أخرى';

  @override
  String get msgErrorTitle => 'تعذر تحميل الرسائل';

  @override
  String get msgComposeHint => 'اكتب رسالة';

  @override
  String get msgSend => 'إرسال';

  @override
  String get msgSendFailed => 'لم يتم الإرسال. اضغط إرسال للمحاولة مرة أخرى.';

  @override
  String get msgLoadOlder => 'تحميل الرسائل السابقة';

  @override
  String get msgYou => 'أنت';

  @override
  String get msgUnknownPerson => 'شخص ما';

  @override
  String get msgMenuReportConversation => 'الإبلاغ عن المحادثة';

  @override
  String msgMenuReportPerson(String name) {
    return 'الإبلاغ عن $name';
  }

  @override
  String msgMenuBlockPerson(String name) {
    return 'حظر $name';
  }

  @override
  String get msgMenuBlocked => 'الأشخاص المحظورون';

  @override
  String get msgMessageReport => 'الإبلاغ عن الرسالة';

  @override
  String get msgReportTitle => 'إبلاغ';

  @override
  String get msgReportIntro =>
      'يصل بلاغك إلى فريق الحماية في مدرستك. لن يعرف الشخص المبلَّغ عنه هوية المبلِّغ.';

  @override
  String get msgReportReason => 'ما المشكلة؟';

  @override
  String get msgReasonHarassment => 'تنمر أو مضايقة';

  @override
  String get msgReasonInappropriate => 'محتوى غير لائق';

  @override
  String get msgReasonSafety => 'أنا قلق على سلامة شخص ما';

  @override
  String get msgReasonSpam => 'رسائل مزعجة';

  @override
  String get msgReasonOther => 'سبب آخر';

  @override
  String get msgReportDetails => 'أخبرنا بالمزيد (اختياري)';

  @override
  String get msgReportConsent => 'يمكن للمدرسة التواصل معي بشأن هذا البلاغ';

  @override
  String get msgReportAlsoBlock => 'حظر هذا الشخص أيضاً';

  @override
  String get msgReportSubmit => 'إرسال البلاغ';

  @override
  String get msgReportSent => 'تم إرسال البلاغ. شكراً لإخبارنا.';

  @override
  String get msgReportUrgent =>
      'إذا كان أحد في خطر مباشر، اتصل بخدمات الطوارئ أو بشخص بالغ تثق به الآن.';

  @override
  String msgBlockTitle(String name) {
    return 'حظر $name؟';
  }

  @override
  String get msgBlockMessage =>
      'لن تتمكنا من مراسلة بعضكما. تبقى الرسائل المرسلة سابقاً مرئية للمدرسة.';

  @override
  String get msgBlockConfirm => 'حظر';

  @override
  String msgBlockDone(String name) {
    return 'تم حظر $name.';
  }

  @override
  String get msgCancel => 'إلغاء';

  @override
  String get msgBlockedTitle => 'الأشخاص المحظورون';

  @override
  String get msgBlockedEmpty => 'لم تقم بحظر أي شخص.';

  @override
  String get msgUnblock => 'إلغاء الحظر';

  @override
  String get msgUnblockDone => 'تم إلغاء الحظر.';

  @override
  String get msgBlockedBanner =>
      'لقد حظرت شخصاً في هذه المحادثة. ألغِ الحظر لإرسال الرسائل.';

  @override
  String get msgNewTitle => 'رسالة جديدة';

  @override
  String get msgNewEmpty => 'لا يوجد أحد متاح للمراسلة.';

  @override
  String get msgNewSearch => 'ابحث عن الأشخاص';

  @override
  String get msgSubjectHint => 'الموضوع (اختياري)';

  @override
  String get msgStart => 'بدء المحادثة';

  @override
  String get msgRoleStaff => 'طاقم المدرسة';

  @override
  String get msgRoleStudent => 'طالب';

  @override
  String get msgRoleGuardian => 'ولي أمر';

  @override
  String msgGuardianOf(String names) {
    return 'ولي أمر $names';
  }

  @override
  String get msgErrorMessagingDisabled => 'لم تقم مدرستك بتفعيل المراسلة بعد.';

  @override
  String get msgErrorContactNotAllowed => 'لا يمكنك مراسلة هذا الشخص.';

  @override
  String get msgErrorForbidden =>
      'لا يمكنك إرسال رسائل هنا. ربما قمت بحظر شخص ما، أو قام أحدهم بحظرك.';

  @override
  String get msgErrorNotFound => 'هذه المحادثة لم تعد متاحة.';

  @override
  String get msgErrorInvalidState =>
      'لقد أبلغت عن هذا خلال اليوم الماضي. المدرسة تتابعه.';

  @override
  String get msgErrorWindowClosed =>
      'أرسلت عدداً كبيراً من البلاغات اليوم. يرجى التواصل مع المدرسة مباشرة.';

  @override
  String get msgErrorRateLimited =>
      'محاولات كثيرة. انتظر قليلاً ثم حاول مرة أخرى.';

  @override
  String get msgErrorNetwork =>
      'تعذر على Studafy الوصول إلى المدرسة. تحقق من اتصالك.';

  @override
  String get msgErrorUnauthorized => 'يرجى تسجيل الدخول مرة أخرى.';

  @override
  String get msgErrorValidation => 'اكتب رسالة أولاً.';

  @override
  String get msgErrorUnknown => 'حدث خطأ ما. يرجى المحاولة مرة أخرى.';

  @override
  String get famTitle => 'عائلتي';

  @override
  String get famChildren => 'أطفالي';

  @override
  String get famEmptyTitle => 'لم يتم ربط أي طفل بعد';

  @override
  String get famEmptyMessage =>
      'اطلب من طفلك معرّف Studafy الخاص به. يجب أن يوافق على طلبك قبل أن تتمكن من متابعة تقدمه.';

  @override
  String get famLink => 'ربط طفل';

  @override
  String get famLinkTitle => 'ربط طفل';

  @override
  String get famLinkHint => 'رقم Studafy';

  @override
  String get famLinkFind => 'بحث';

  @override
  String get famLinkNotFound =>
      'لا يوجد طالب بهذا الرقم. تحقق منه وحاول مرة أخرى.';

  @override
  String famLinkConfirm(String name) {
    return 'طلب الربط مع $name';
  }

  @override
  String famLinkSent(String name) {
    return 'تم إرسال الطلب. يجب أن يوافق $name قبل أن تتمكن من رؤية سجلاته.';
  }

  @override
  String get famStatusPending => 'بانتظار موافقة طفلك';

  @override
  String get famStatusVerified => 'مرتبط';

  @override
  String get famStatusDeclined => 'تم رفض الطلب';

  @override
  String get famStatusRevoked => 'لم يعد مرتبطاً';

  @override
  String get famView => 'عرض التقدم';

  @override
  String famProgressTitle(String name) {
    return 'تقدم $name';
  }

  @override
  String get famProgressAverage => 'متوسط الدرجات المنشورة';

  @override
  String famProgressGraded(String count) {
    return '$count درجات منشورة';
  }

  @override
  String get famProgressAttendance => 'الحضور';

  @override
  String famProgressSessions(String count) {
    return '$count حصص مسجلة';
  }

  @override
  String get famProgressNone => 'لا توجد بيانات بعد';

  @override
  String famProgressBreakdown(
    String present,
    String late,
    String absent,
    String excused,
  ) {
    return 'حاضر $present · متأخر $late · غائب $absent · بعذر $excused';
  }

  @override
  String get famProgressSource =>
      'محسوب من الدرجات التي نشرتها المدرسة والحضور الذي سجلته. تواصل مع المدرسة إذا بدا شيء غير صحيح.';

  @override
  String get famApprovalsTitle => 'بانتظار موافقتك';

  @override
  String famApprovalsDetail(String name) {
    return 'طلب $name الاشتراك في دفتر الطالب.';
  }

  @override
  String get famApprovalsApprove => 'موافقة';

  @override
  String get famApprovalsDecline => 'رفض';

  @override
  String get famApprovalsDone => 'تم إرسال قرارك.';

  @override
  String get famRetry => 'حاول مرة أخرى';

  @override
  String get famCancel => 'إلغاء';

  @override
  String get famErrorTitle => 'تعذر تحميل بيانات العائلة';

  @override
  String get famErrorReauthRequired =>
      'لحمايتك، سجّل الخروج ثم سجّل الدخول مرة أخرى، ثم وافق.';

  @override
  String get famErrorForbidden => 'ليس لديك صلاحية الوصول إلى هذا.';

  @override
  String get famErrorNotFound => 'لم يعد هذا متاحاً.';

  @override
  String get famErrorInvalidState => 'تم البت في هذا الطلب مسبقاً.';

  @override
  String get famErrorRateLimited =>
      'محاولات كثيرة. انتظر قليلاً ثم حاول مرة أخرى.';

  @override
  String get famErrorNetwork =>
      'تعذر على Studafy الوصول إلى المدرسة. تحقق من اتصالك.';

  @override
  String get famErrorUnauthorized => 'يرجى تسجيل الدخول مرة أخرى.';

  @override
  String get famErrorValidation => 'أدخل رقم Studafy.';

  @override
  String get famErrorUnknown => 'حدث خطأ ما. يرجى المحاولة مرة أخرى.';

  @override
  String get accountAccountId => 'معرّف الحساب';

  @override
  String get accountAccountIdDetail => 'شارك هذا المعرّف مع مدرستك لربط حسابك.';

  @override
  String get accountAccountIdCopied => 'تم نسخ معرّف الحساب';

  @override
  String get accountSwitchRole => 'تبديل الدور';

  @override
  String get accountSwitchRoleDetail => 'أنت مرتبط بهذه المدرسة بأكثر من دور.';

  @override
  String get accountTitle => 'الحساب';

  @override
  String get accountSectionAccount => 'الحساب';

  @override
  String get accountSectionPreferences => 'التفضيلات';

  @override
  String get accountSectionPrivacy => 'الخصوصية والبيانات';

  @override
  String get accountStudafyId => 'معرّف ستودافاي الخاص بك';

  @override
  String get accountStudafyIdDetail =>
      'أعطِ هذا لولي أمرك ليتمكن من طلب الارتباط.';

  @override
  String get accountStudafyIdCopy => 'نسخ معرّف ستودافاي';

  @override
  String get accountStudafyIdCopied => 'تم نسخ معرّف ستودافاي.';

  @override
  String get accountUnknown => 'حسابك';

  @override
  String get accountLanguage => 'اللغة';

  @override
  String get accountSecurity => 'تسجيل الدخول والأمان';

  @override
  String get accountSecurityDetail =>
      'الأجهزة، التحقق بخطوتين، تسجيل الخروج من كل الأجهزة';

  @override
  String get accountSignOut => 'تسجيل الخروج';

  @override
  String get accountDelete => 'حذف الحساب';

  @override
  String get accountRoleSchoolAdmin => 'مسؤول المدرسة';

  @override
  String get accountRoleTeacher => 'معلم';

  @override
  String get accountRoleParent => 'ولي أمر';

  @override
  String get accountRoleStudent => 'طالب';

  @override
  String get accountExport => 'تنزيل بياناتي';

  @override
  String get accountExportDetail =>
      'احصل على نسخة من المعلومات التي يحتفظ بها Studafy عنك.';

  @override
  String get accountExportRequest => 'طلب';

  @override
  String get accountExportPending => 'نجهّز نسختك. قد يستغرق ذلك بضع دقائق.';

  @override
  String get accountExportCheck => 'تحقق';

  @override
  String get accountExportReady => 'نسختك جاهزة لمدة 7 أيام.';

  @override
  String get accountExportDownload => 'تنزيل';

  @override
  String get accountExportRequested => 'تم استلام الطلب. نجهّز نسختك الآن.';

  @override
  String get accountExportReauth =>
      'لحمايتك، سجّل الخروج ثم سجّل الدخول مرة أخرى أولاً.';

  @override
  String get accountExportExpired =>
      'انتهت صلاحية تلك النسخة. اطلب نسخة جديدة.';

  @override
  String get accountExportFailed => 'لم ينجح ذلك. يرجى المحاولة مرة أخرى.';

  @override
  String get todayWork => 'الأعمال التي أسندتها';

  @override
  String get todayWorkEmpty => 'لم تُسند أي عمل بعد.';

  @override
  String get todaySections => 'حصص تنتظر المحتوى';

  @override
  String get todaySectionsEmpty => 'كل حصة درّستها تم رفع محتواها.';

  @override
  String get todaySectionsOutstanding => 'المحتوى غير مرفوع';

  @override
  String get todayTitle => 'اليوم';

  @override
  String get todayHello => 'مرحباً';

  @override
  String todayHelloName(String name) {
    return 'مرحباً، $name';
  }

  @override
  String get todayClasses => 'فصولي';

  @override
  String todayStudents(String count) {
    return '$count طلاب';
  }

  @override
  String get todayEmpty => 'لا توجد فصول بعد';

  @override
  String get todayEmptyDetail => 'أنشئ فصلك الأول من تبويب الفصول.';

  @override
  String get todayError => 'تعذر تحميل الفصول';

  @override
  String get todayErrorDetail => 'تحقق من اتصالك وحاول مرة أخرى.';

  @override
  String get todayRetry => 'حاول مرة أخرى';

  @override
  String get todayMessages => 'الرسائل';

  @override
  String get todayNotifications => 'الإشعارات';

  @override
  String get navToday => 'اليوم';

  @override
  String get navClasses => 'الفصول';

  @override
  String get navTeaching => 'التدريس';

  @override
  String get navGradebook => 'سجل الدرجات';

  @override
  String get navInbox => 'الوارد';

  @override
  String get navLearning => 'التعلّم';

  @override
  String get navInsights => 'رؤى+';

  @override
  String get navUpdates => 'التحديثات';

  @override
  String get navMessages => 'الرسائل';

  @override
  String get navNotebook => 'دفتر الدروس';

  @override
  String get navWork => 'الأعمال';

  @override
  String get navGrades => 'الدرجات';

  @override
  String get notificationsFeedTitle => 'الإشعارات';

  @override
  String get notificationsFeedMarkAllRead => 'تعليم الكل كمقروء';

  @override
  String get notificationsFeedErrorTitle => 'تعذّر تحميل الإشعارات';

  @override
  String get notificationsFeedRetry => 'إعادة المحاولة';

  @override
  String get notificationsFeedOfflineBanner =>
      'يتم عرض آخر الإشعارات المحفوظة — أعد الاتصال للتحديث.';

  @override
  String get notificationsFeedEmptyTitle => 'لا توجد إشعارات بعد';

  @override
  String get notificationsFeedEmptyMessage => 'ستظهر هنا التحديثات فور حدوثها.';

  @override
  String get notificationsFeedLoading => 'جارٍ التحميل…';

  @override
  String get notificationsFeedLoadMore => 'تحميل المزيد';

  @override
  String get notificationCopyAcademicAssessmentPublishedTitle =>
      'تم نشر التقييم';

  @override
  String get notificationCopyAcademicAssessmentPublishedDetail =>
      'أصبح تقييم جديد متاحًا لأحد فصولك.';

  @override
  String get notificationCopyAcademicAssignmentPublishedTitle =>
      'تم نشر الواجب';

  @override
  String get notificationCopyAcademicAssignmentPublishedDetail =>
      'أصبح واجب جديد متاحًا لأحد فصولك.';

  @override
  String get notificationCopyAcademicGradePublishedTitle => 'درجة جديدة';

  @override
  String get notificationCopyAcademicGradePublishedDetail =>
      'تم نشر درجة جديدة. افتح الدرجات للاطلاع عليها.';

  @override
  String get notificationCopyAcademicResourcePublishedTitle =>
      'مادة دراسية جديدة';

  @override
  String get notificationCopyAcademicResourcePublishedDetail =>
      'شارك معلمك مادة جديدة لأحد فصولك.';

  @override
  String get notificationCopyAcademicWellbeingSharedTitle => 'ملاحظة رفاهية';

  @override
  String get notificationCopyAcademicWellbeingSharedDetail =>
      'تمت مشاركة ملاحظة متعلقة بالرفاهية معك.';

  @override
  String get notificationCopyBillingPurchaseApprovalRequestedTitle =>
      'مطلوب الموافقة على شراء';

  @override
  String get notificationCopyBillingPurchaseApprovalRequestedDetail =>
      'طلب طفلك موافقتك على اشتراك.';

  @override
  String get notificationCopyBillingPurchaseApprovalApprovedTitle =>
      'تمت الموافقة على الشراء';

  @override
  String get notificationCopyBillingPurchaseApprovalApprovedDetail =>
      'وافق ولي الأمر على طلب اشتراكك.';

  @override
  String get notificationCopyBillingPurchaseApprovalDeclinedTitle =>
      'تم رفض الشراء';

  @override
  String get notificationCopyBillingPurchaseApprovalDeclinedDetail =>
      'رفض ولي الأمر طلب اشتراكك.';

  @override
  String get notificationCopyMeetingsScheduledTitle => 'تم تأكيد الاجتماع';

  @override
  String get notificationCopyMeetingsScheduledDetail =>
      'تمت جدولة اجتماع. تحقق من تقويمك لرؤية الدعوة.';

  @override
  String get notificationCopyMeetingsFailedTitle => 'لم تتم جدولة الاجتماع';

  @override
  String get notificationCopyMeetingsFailedDetail =>
      'تعذرت جدولة اجتماع طلبته. يرجى المحاولة مرة أخرى.';

  @override
  String get notificationCopyCommunicationsAnnouncementCreatedTitle =>
      'إعلان جديد';

  @override
  String get notificationCopyCommunicationsAnnouncementCreatedDetail =>
      'تم نشر إعلان جديد.';

  @override
  String get notificationCopyCommunicationsMessageSentTitle => 'رسالة جديدة';

  @override
  String get notificationCopyCommunicationsMessageSentDetail =>
      'وصلتك رسالة جديدة.';

  @override
  String get notificationCopyFamilyGuardianLinkRequestedTitle =>
      'طلب ربط عائلي';

  @override
  String get notificationCopyFamilyGuardianLinkRequestedDetail =>
      'طلب أحدهم الربط كولي أمر.';

  @override
  String get notificationCopyFamilyGuardianLinkRevokedTitle =>
      'إزالة ربط عائلي';

  @override
  String get notificationCopyFamilyGuardianLinkRevokedDetail =>
      'تمت إزالة ربط عائلي.';

  @override
  String get notificationCopyFamilyGuardianLinkVerifiedTitle =>
      'تم تأكيد الربط العائلي';

  @override
  String get notificationCopyFamilyGuardianLinkVerifiedDetail =>
      'تم تأكيد ربط عائلي.';

  @override
  String get notificationCopyInvitationsIssuedTitle => 'تم إرسال دعوة';

  @override
  String get notificationCopyInvitationsIssuedDetail => 'تم إصدار دعوة.';

  @override
  String get notificationCopyMeetingsCancelledTitle => 'تم إلغاء الاجتماع';

  @override
  String get notificationCopyMeetingsCancelledDetail =>
      'تم إلغاء اجتماع مجدول.';

  @override
  String get notificationCopyMeetingsRequestedTitle => 'طلب اجتماع';

  @override
  String get notificationCopyMeetingsRequestedDetail => 'تم طلب اجتماع.';

  @override
  String get notificationCopySchoolAdminClassroomStaffAssignedTitle =>
      'تعيين موظف';

  @override
  String get notificationCopySchoolAdminClassroomStaffAssignedDetail =>
      'تم تعيين موظف لأحد الفصول.';

  @override
  String get notificationCopySchoolAdminClassroomStaffRemovedTitle =>
      'إزالة موظف';

  @override
  String get notificationCopySchoolAdminClassroomStaffRemovedDetail =>
      'تمت إزالة موظف من أحد الفصول.';

  @override
  String get notificationCopySchoolAdminMembershipGrantedTitle =>
      'تم منح الصلاحية';

  @override
  String get notificationCopySchoolAdminMembershipGrantedDetail =>
      'تم منح صلاحية الوصول للمدرسة.';

  @override
  String get notificationCopySchoolAdminStudentEnrolledTitle => 'تسجيل طالب';

  @override
  String get notificationCopySchoolAdminStudentEnrolledDetail =>
      'تم تسجيل طالب جديد.';

  @override
  String get notificationCopySchoolAdminStudentTransferredTitle => 'نقل طالب';

  @override
  String get notificationCopySchoolAdminStudentTransferredDetail =>
      'تم نقل طالب بين الفصول.';

  @override
  String get notificationCopySchoolAdminStudentWithdrawnTitle => 'انسحاب طالب';

  @override
  String get notificationCopySchoolAdminStudentWithdrawnDetail =>
      'تم سحب طالب.';

  @override
  String get notificationCopySupportAccessApprovedTitle =>
      'تمت الموافقة على الدعم';

  @override
  String get notificationCopySupportAccessApprovedDetail =>
      'تمت الموافقة على طلب وصول الدعم.';

  @override
  String get notificationCopySupportAccessRequestedTitle => 'طلب وصول للدعم';

  @override
  String get notificationCopySupportAccessRequestedDetail =>
      'تم طلب وصول الدعم الفني.';

  @override
  String get notificationCopySupportAccessRevokedTitle => 'تم إلغاء وصول الدعم';

  @override
  String get notificationCopySupportAccessRevokedDetail =>
      'تم إلغاء وصول الدعم الفني.';

  @override
  String get notificationCopySupportAccessStartedTitle => 'بدأت جلسة الدعم';

  @override
  String get notificationCopySupportAccessStartedDetail => 'بدأت جلسة دعم فني.';

  @override
  String get notificationCopyGenericTitle => 'إشعار';

  @override
  String get notificationCopyGenericDetail => 'لديك تحديث جديد.';

  @override
  String familyPlusHeadline(String name) {
    return 'Family+ لـ $name';
  }

  @override
  String get familyPlusIntro =>
      'اعرف كيف يسير طفلك فعلًا، وما الخطوة المفيدة التي يمكنك القيام بها هذا الأسبوع.';

  @override
  String get familyPlusFeatureTrends =>
      'ما الذي تغيّر هذا الفصل، مع السجلات التي تثبت كل ملاحظة';

  @override
  String get familyPlusFeatureDue =>
      'الواجبات المطلوبة هذا الأسبوع حتى لا يفوت شيء';

  @override
  String get familyPlusFeatureSubjects =>
      'الدرجات حسب المادة والحضور بلمحة سريعة';

  @override
  String get familyPlusFeatureSchool => 'ملاحظات اختارت المدرسة مشاركتها معك';

  @override
  String familyPlusPrice(String price) {
    return '$price شهريًا';
  }

  @override
  String get familyPlusUsPrice =>
      '1.99 دولار أمريكي شهريًا في الولايات المتحدة - يعرض المتجر سعرك';

  @override
  String familyPlusTrial(String trial, String price) {
    return 'إن كنت مؤهلًا، مجانًا لمدة $trial، ثم $price شهريًا';
  }

  @override
  String familyPlusOneChild(String name) {
    return 'يشمل $name فقط. لكل طفل اشتراك Family+ خاص به.';
  }

  @override
  String get familyPlusStartTrial => 'ابدأ الفترة التجريبية المجانية';

  @override
  String familyPlusSubscribe(String name) {
    return 'اشترك لـ $name';
  }

  @override
  String get familyPlusCheckingStore => 'جارٍ التحقق من سعر المتجر...';

  @override
  String get familyPlusStoreUnavailable =>
      'تعذّر الوصول إلى المتجر. حاول مرة أخرى لاحقًا.';

  @override
  String get familyPlusNotInThisBuild =>
      'لا يمكن شراء Family+ في هذا الإصدار من التطبيق.';

  @override
  String get familyPlusOpeningStore => 'جارٍ فتح المتجر...';

  @override
  String get familyPlusRestore => 'استعادة المشتريات';

  @override
  String get familyPlusRestoring => 'جارٍ التحقق من مشترياتك...';

  @override
  String get familyPlusFailed => 'لم تنجح العملية. حاول مرة أخرى.';

  @override
  String get familyPlusManage => 'إدارة الاشتراك أو إلغاؤه';

  @override
  String get familyPlusDisclosure =>
      'اشتراك شهري يتجدد تلقائيًا ويُدفع عبر حسابك في متجر التطبيقات. يتجدد ما لم يُلغَ قبل 24 ساعة على الأقل من نهاية الفترة، ويمكنك الإلغاء في أي وقت من إعدادات الاشتراكات في المتجر. لا يطّلع Studafy على بيانات بطاقتك أبدًا.';

  @override
  String get familyPlusTerms => 'شروط الاستخدام';

  @override
  String get familyPlusPrivacy => 'سياسة الخصوصية';
}
