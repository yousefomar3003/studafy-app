// ignore_for_file: text_direction_code_point_in_literal, text_direction_code_point_in_comment

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
  String get securityTwoFactorOnDetail => 'تطبيق المصادقة لديك مُعدّ.';

  @override
  String get securityTwoFactorOffDetail =>
      'اختياري: يضيف رمزًا من تطبيق المصادقة عند تسجيل الدخول.';

  @override
  String get securityTwoFactorOffDetailReviewer =>
      'مطلوب لمراجعة البلاغات: تُدخل رمزًا من تطبيق المصادقة قبل فتح أي بلاغ.';

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
      'أضف ستودافاي إلى تطبيق مصادقة على هذا الهاتف (Google Authenticator أو Microsoft Authenticator أو تطبيق كلمات السر على iPhone).';

  @override
  String get securityTotpOpenApp => 'افتح في تطبيق المصادقة';

  @override
  String get securityTotpKeyLabel => 'أو أضف هذا المفتاح يدويًا';

  @override
  String get securityTotpCopyKey => 'نسخ المفتاح';

  @override
  String get securityTotpKeyCopied => 'تم نسخ المفتاح';

  @override
  String get securityTotpNoApp =>
      'لم يفتحه أي تطبيق مصادقة. ثبّت تطبيقًا (مثل Google Authenticator أو Microsoft Authenticator)، أو انسخ المفتاح وأضفه في التطبيق يدويًا.';

  @override
  String get securityTotpCodePrompt =>
      'ثم أدخل الرمز المكوّن من ستة أرقام الذي يعرضه التطبيق لستودافاي:';

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
  String get roleTeacherDetail => 'إدارة الصفوف والحضور والتعلّم';

  @override
  String get roleStudent => 'طالب';

  @override
  String get roleStudentDetail => 'التعلّم وتسليم الواجبات ومتابعة الجديد';

  @override
  String get roleParent => 'ولي أمر';

  @override
  String get roleParentDetail => 'متابعة التقدّم وأخبار المدرسة';

  @override
  String get introSkip => 'تخطي';

  @override
  String get introNext => 'التالي';

  @override
  String get introStart => 'ابدأ الآن';

  @override
  String introPageOf(int index, int total) {
    return 'الصفحة $index من $total';
  }

  @override
  String get introTitleOne => 'يومك الدراسي كله في مكان واحد';

  @override
  String get introBodyOne =>
      'الدروس والواجبات والدرجات والحضور - المعلمون والطلاب وأولياء الأمور معًا.';

  @override
  String get introTitleTwo => 'لكل درجة قيمتها، ورقية كانت أو إلكترونية';

  @override
  String get introBodyTwo =>
      'يرصد المعلمون درجات الاختبارات الورقية والأعمال الإلكترونية في سجل واحد، وترى العائلة الدرجة بعد نشرها.';

  @override
  String get introTitleThree => 'يرى أولياء الأمور ما يهمهم';

  @override
  String get introBodyThree =>
      'تابع التقدّم والحضور - ومع ⁦Family+⁩ اتجاه كل صف وما يجب التركيز عليه هذا الأسبوع. بلا إعلانات، ولا نبيع بياناتك أبدًا.';

  @override
  String get roleWhatIsStudafy => 'ما هو ستودافاي؟';

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
      'ما الذي نجمعه\nاسمك وبريدك الإلكتروني من مزوّد تسجيل الدخول الذي تختاره، وجنسك فقط إذا اخترت ذكره (ولا يظهر لأي أحد آخر). المدرسة أو الصف الذي تنتمي إليه ودورك فيه. الدروس، والأعمال المطلوبة منك وما تسلّمه وكل تسليم سابق، ودرجاتك وسجل أي تعديل عليها، وحضورك، وملاحظات الرعاية، ودفتر ملاحظاتك الخاص. الرسائل والرسائل الصوتية والإعلانات وروابط الاجتماعات داخل التطبيق، والبلاغات التي تقدّمها. الملفات التي ترفعها. اشتراكاتك وإعدادات الإشعارات وما وافقت عليه، ومنه أدوات الدراسة بالذكاء الاصطناعي.\n\nلماذا\nلتشغيل صفوفك، وحماية حسابك، وإدارة الاشتراكات، والوفاء بالالتزامات القانونية. لا نبيع البيانات الشخصية. لا نعرض أي إعلانات. ولا نستخدم بياناتك لتدريب أي نموذج ذكاء اصطناعي.\n\nالدرجات والحضور\nيمكن للمعلمين رصد درجات الأعمال الورقية إلى جانب الأعمال المسلَّمة إلكترونيًا. تبقى الدرجة مسودة لا يراها إلا معلموك حتى ينشرها المعلم، ولا تُحتسب الدرجة غير المرصودة صفرًا أبدًا. إذا صُحّحت درجة منشورة نحتفظ بالدرجة القديمة والجديدة ومن غيّرها ومتى ولماذا، ويُبلَّغ أنت ووالداك إذا تغيّرت الدرجة. تعديل الحضور بعد يوم الدرس يتطلب سببًا، ولا يستطيع تعديل سجل مضى عليه أكثر من سبعة أيام إلا المعلم الرئيسي للصف، ويُحفظ كل تعديل. تُحدَّد مواعيد التسليم بتوقيت مدرستك.\n\nمن يرى أعمالك\nمعلمو صفك، وولي الأمر المرتبط بك بعد نشر الدرجة. لا يوجد مسؤول مدرسة في هذا الإصدار من التطبيق. لا يستطيع الطلاب الآخرون الاطلاع على درجاتك أو أعمالك أو رسائلك الخاصة. تُخزَّن الرسائل على خوادمنا وليست مشفّرة طرفًا إلى طرف.\n\nالبلاغات\nيمكنك الإبلاغ عن أي شخص أو حظره من داخل التطبيق. يراجع ستودافاي البلاغات: يقرأ شخص مسمّى لدى ستودافاي، يمكن التواصل معه عبر hello@studafy.com، ما أُبلغ عنه، وقد يزيل المحتوى أو يعلّق الحسابات أو يغلقها. وكل بلاغ جديد يُرسل تنبيهًا إلى محادثتنا الخاصة على Telegram برقمه المرجعي ونوعه وأولويته - ولا يحمل أبدًا محتواه ولا اسمًا ولا معرّف حساب. ونبلغك حين يُبتّ في بلاغك.\n\nأولياء الأمور والأبناء\nيطلب ولي الأمر الارتباط بالطالب، ويوافق الطالب أو يرفض من جهازه. ويمكن لولي الأمر أيضًا إنشاء حساب لطفل ليس لديه بريد إلكتروني أو هاتف وإدارته، ويقبل هذه الشروط نيابةً عن الطفل. يرى ولي الأمر المرتبط الدرجات المنشورة والحضور والأعمال ومواد الصف، ويمكنه تسليم العمل عن طفل صغير، لكنه لا يستطيع تعديل الدرجات أو الحضور ولا يُمنح رسائل الطفل الخاصة. Family+ خطة مدفوعة لأولياء الأمور تشمل حتى 4 أو حتى 8 أطفال مرتبطين، الأسبق ربطًا أولًا. ولكل طفل تشمله تلخّص ما يستطيع ولي الأمر رؤيته أصلًا - الدرجات حسب الصف والاتجاهات والحضور والواجبات غير المسلّمة والاختبارات الفائتة - وتقارن الطفل بسجله السابق فقط، ولا تستخدم الذكاء الاصطناعي.\n\nأدوات الدراسة بالذكاء الاصطناعي\nهذه الأدوات اختيارية. وهي للطلاب المنتمين إلى صف فقط، وبعد أن توافق عليها موافقةً مستقلة؛ ويوافق ولي الأمر عن حساب الطفل الذي يديره. ويمكن إيقافها في أي وقت. يُرسل ما تقدّمه لها إلى Together AI، وهي شركة ذكاء اصطناعي في الولايات المتحدة: السؤال الذي تكتبه وآخر الرسائل في المحادثة نفسها، وإذا اخترت ذلك نص درس أو ملاحظاتك الخاصة أو صورة تضيفها (مساعد الدراسة، وملاحظات السبورة، وملاحظات الدرس، والاختبارات والبطاقات التعليمية). تُستبدل أولًا الأسماء التي يعرفها ستودافاي بكلمات مثل [student]، ولا يُرسل بريدك ولا مدرستك ولا درجاتك أبدًا. أما الصور فتُرسل كما هي، فلا تصوّر الأسماء أو الوجوه. تُحفظ الصورة التي ترسلها إلى مساعد الدراسة 30 يومًا، وتُحفظ المحادثات على جهازك فقط. ولم تُبرَم بعدُ اتفاقية معالجة البيانات بيننا وبين Together AI. قد تكون الإجابات خاطئة، فلا تسلّمها على أنها عملك أبدًا. الذكاء الاصطناعي لا يصحّح أعمالك أبدًا.\n\nالملفات\nتُخزَّن الملفات بشكل خاص، وتُفحص على خوادمنا نحن قبل أن يتمكن أحد من تنزيلها، ولا تُفتح إلا عبر روابط تعمل مرة واحدة وتنتهي خلال دقائق. تُزال التفاصيل المخفية من الصور والرسائل الصوتية. إذا استبدل المعلم ملفًا أو أزاله فلن يراه الصف، لكنه يُحفظ لدى المدرسة.\n\nالمدفوعات\nتُحصَّل اشتراكات Studafy Plus وStudafy Max وFamily+ عبر Apple أو Google وفق شروطهما. لا نطّلع على بطاقتك إطلاقًا.\n\nمن يعالج البيانات أيضًا\nتستضيف Supabase قاعدة البيانات وتسجيل الدخول والملفات؛ وتستضيف Fly.io التطبيق، وتحفظ Axiom سجلاته التقنية وSentry تقارير أخطائه؛ وتخزّن Cloudflare نسخنا الاحتياطية المشفّرة داخل الاتحاد الأوروبي، وتنقل تنبيهاتنا، وتشغّل فحص الروبوتات، وتستضيف صفحاتنا القانونية؛ وتشغّل GitHub مهمة النسخ الاحتياطي دون أن تحتفظ بنسخة؛ وتنقل Telegram تنبيهاتنا، وهي لا تحمل محتوى ولا أسماء؛ ويحفظ Redis عدادات قصيرة الأجل؛ وتتحقق Google وMicrosoft وApple من تسجيل الدخول؛ وتشغّل Together AI أدوات الدراسة بالذكاء الاصطناعي؛ وترسل Resend البريد وترسل Firebase الإشعارات التي لا تتضمن درجاتك أو رسائلك أبدًا. ويعمل كل منهم وفق تعليماتنا فقط. لا ينشئ ستودافاي اجتماعات: يُفتح رابط الاجتماع الذي يشاركه المعلم في Google Meet وفق شروط Google.\n\nأين تُعالَج بياناتك\nأنظمتنا الرئيسية ونسخنا الاحتياطية داخل الاتحاد الأوروبي. ويعالج بعض المزوّدين البيانات خارج المنطقة الاقتصادية الأوروبية، محميةً بالبنود التعاقدية القياسية أو بقرار كفاية؛ أما Together AI فلم تُعتمد معها هذه الضمانة بعد.\n\nما لا يمكننا حذفه\nسجلات الإجراءات المهمة تُضاف ولا يمكن لأحد تعديلها، ولا حتى نحن، ولا تُحذف إلا بانتهاء مدة الاحتفاظ بها. ويشمل ذلك سجل الدرجات والحضور، والتسليمات السابقة، والملفات التي استبدلها المعلم. وكثيرًا ما تكون المدارس ملزمة بالاحتفاظ بسجلات الحضور والتقييم وحماية الطفل. يعرض التطبيق السجلات التي تبقى لدى مدرستك قبل تأكيد الحذف. تُحفظ النسخ الاحتياطية المشفّرة لمدة ٣٠ يومًا.\n\nالحسابات غير النشطة\nيُحذف الحساب الذي لا يُستخدم مدة سنتين. ونُشعرك بالبريد الإلكتروني قبل ذلك بـ 30 يومًا على الأقل، وداخل التطبيق أيضًا إن كنت منتميًا إلى مدرسة. وإذا تعذّر وصول الإشعار إليك، لا نحذف الحساب.\n\nعلى جهازك\nيحتفظ التطبيق بجلستك ولغتك ونسخة مؤقتة مما فتحته ونزّلته ومحادثات مساعد الدراسة وصورتك الشخصية، لكل حساب على حدة. لا تُرفع صورتك الشخصية إلى خوادمنا أبدًا، فلا يراها أحد غيرك. وتُمسح عند تسجيل خروج ذلك الحساب.\n\nكيف نحميها\nيُفرض الوصول إلى بيانات كل صف داخل قاعدة البيانات نفسها، ولا يستطيع تعديل درجات الصف وحضوره إلا معلمو ذلك الصف. وتُزال الأسرار من السجلات. وفي سجلاتنا تُخزَّن عناوين IP كبصمة أحادية الاتجاه فقط، بينما تحتفظ خدمة تسجيل الدخول (Supabase) بعنوان IP لعملية تسجيل الدخول لمدة تصل إلى 7 أيام. وتُشفَّر النسخ الاحتياطية قبل أن تغادر أنظمتنا.\n\nحقوقك\nيمكنك طلب نسخة من بياناتك أو تصحيحها أو حذف حسابك أو تقييد المعالجة أو الاعتراض عليها أو سحب موافقتك. يوجد حذف الحساب وتصدير البيانات في إعدادات الحساب، ويمكن إلغاء الحذف خلال ١٤ يومًا؛ ويقوم ولي الأمر بذلك لحساب الطفل الذي يديره. التصدير ملف JSON ببياناتك أنت. ويسرد ملفاتك (الاسم والنوع والحجم والتاريخ) ولا يتضمّنها: افتحها في التطبيق، أو راسل hello@studafy.com للحصول على نسخة. ولا يتضمّن أسئلة الاختبارات ودرجاتها التي لم يتحها معلمك بعد، ولا ملاحظات الرعاية، ولا المحادثات التي غادرتها. ويمكنك تقديم شكوى إلى لجنة حماية البيانات في أيرلندا في أي وقت.\n\nإذا كانت مدرستك هي المتحكم في سجلاتك، فاسأل مدرستك أولًا؛ وسننقل طلبك إليها ونخبرك بذلك.\n\nالسياسة الكاملة على ⁦legal.studafy.com/ar/privacy⁩. وللاستفسار: hello@studafy.com.';

  @override
  String get policyTermsBody =>
      'لمن هذا التطبيق\nستودافاي للمعلمين والطلاب وأولياء الأمور. لا يوجد مسؤول مدرسة في هذا الإصدار من التطبيق. بتسجيل الدخول فإنك تقبل هذه الشروط وسياسة الخصوصية.\n\nحسابك\nسجّل الدخول عبر Google أو Microsoft أو Apple وحافظ على أمان ذلك الحساب. يمكنك إضافة عدة حسابات إلى جهاز واحد؛ وسجّل الخروج من أي جهاز مشترك. يمكن لولي الأمر إنشاء حساب لطفل ليس لديه بريد إلكتروني أو هاتف، ويقبل هذه الشروط نيابةً عنه، ويكون مسؤولًا عن طريقة استخدامه. لا تنتحل شخصية أحد.\n\nالاستخدام السليم\nاستخدم ستودافاي للتعلّم والتدريس والتواصل المدرسي فقط. لا تتنمّر على أحد أو تضايقه أو تهدده، ولا تشارك محتوى جنسيًا أو عنيفًا أو يحض على الكراهية أو مخالفًا للقانون، ولا ترفع ملفات لا يحق لك مشاركتها، ولا تحاول الاطلاع على سجلات ليست لك، ولا تسلّم عمل غيرك أو ما ينتجه الذكاء الاصطناعي على أنه عملك. يمكنك الإبلاغ عن أي شخص أو حظره من داخل التطبيق. يراجع ستودافاي البلاغات، وقد نزيل المحتوى ونعلّق الحسابات التي تخالف هذه القواعد أو نغلقها.\n\nالمعلمون\nأنت مسؤول عن الدرجات والحضور الذي ترصده. تبقى الدرجات مسودات حتى تنشرها. لا تُعدَّل الدرجة المنشورة إلا بتصحيحها مع ذكر السبب، وتُحفظ الدرجة القديمة. تعديل الحضور بعد يوم الدرس يتطلب سببًا، وبعد سبعة أيام لا يستطيع تعديل السجل إلا المعلم الرئيسي للصف. امنح الطلاب وقتًا إضافيًا أو أعد فتح العمل مع ذكر السبب. تُحفظ الملفات التي تستبدلها أو تزيلها لدى المدرسة. لا تشارك إلا ما يحق لك مشاركته.\n\nالطلاب\nسلّم عملك بنفسك. يمكنك استبداله حتى موعد التسليم، وهو بتوقيت مدرستك، وتُحفظ التسليمات السابقة. بعد انتهاء الموعد، أو بعد نشر الدرجة، تحتاج إلى إذن معلمك لتسليم العمل من جديد. إذا بدت درجة أو سجل حضور غير صحيح فاسأل معلمك.\n\nأولياء الأمور\nلا يمكنك الارتباط بطفلك إلا بموافقته، إلا إذا كنت أنت من أنشأ حسابه. يمكنك رؤية الدرجات المنشورة والحضور والأعمال ومواد الصف، وتسليم العمل عن طفل صغير. لا يمكنك تعديل الدرجات أو الحضور، ولا ترى رسائل طفلك الخاصة. Family+ خطة مدفوعة خاصة بك: خطة تشمل حتى 4 أطفال مرتبطين، وخطة أكبر تشمل حتى 8، بترتيب ربطهم. تلخّص ما تستطيع رؤيته أصلًا، وتقارن الطفل بسجله السابق فقط، ولا تتنبأ بشيء.\n\nمحتواك\nتحتفظ بحقوقك فيما تكتبه وترفعه. وتسمح لنا بتخزينه وعرضه فقط لتشغيل ستودافاي لك ولمدرستك. تصبح الأعمال المسلَّمة والدرجات والحضور والملفات المشتركة جزءًا من سجلات المدرسة.\n\nأدوات الدراسة بالذكاء الاصطناعي\nهي اختيارية، وللطلاب المنتمين إلى صف فقط، وبعد أن يوافق الطالب عليها موافقةً مستقلة؛ ويوافق ولي الأمر عن حساب الطفل الذي يديره. تُستبدل الأسماء قبل إرسال أي شيء، أما الصور فتُرسَل كما هي. وقد تخطئ هذه الأدوات: تحقّق مما تنتجه ولا تسلّمه على أنه عملك أبدًا. الذكاء الاصطناعي لا يصحّح الأعمال أبدًا. لكل خطة رصيد يتجدّد كل أسبوع أو كل شهر.\n\nالاشتراكات\nالدروس ودفاتر الملاحظات والأعمال والدرجات والحضور مجانية. Studafy Plus وStudafy Max للطلاب، وFamily+ لأولياء الأمور لحتى 4 أو حتى 8 أطفال مرتبطين. تُحصَّل جميعها شهريًا عبر Apple أو Google بالسعر الذي يعرضه المتجر حتى تلغيها من حسابك في المتجر، حيث تُعالَج المبالغ المستردة أيضًا.\n\nالاجتماعات\nلا يستضيف ستودافاي مكالمات الفيديو ولا ينشئ اجتماعات. يُفتح رابط الاجتماع الذي يشاركه المعلم في Google Meet وفق شروط Google.\n\nالتغييرات وإنهاء الاستخدام\nقد نغيّر الميزات أو نوقفها، وسنبلغك قبل أي تغيير في هذه الشروط يؤثر عليك. يمكنك حذف حسابك من إعدادات الحساب والتراجع خلال ١٤ يومًا. تبقى السجلات التي يجب على المدرسة الاحتفاظ بها لدى المدرسة.\n\nالشروط الكاملة على ⁦legal.studafy.com/ar/terms⁩. وللاستفسار: hello@studafy.com.';

  @override
  String get deleteTitle => 'حذف الحساب';

  @override
  String get deleteWarningTitle => 'يؤثر هذا على أكثر من ملفك الشخصي';

  @override
  String get deleteWarningBody =>
      'سينتهي وصولك إلى ملفك الشخصي وصفوفك ورسائلك وملفاتك الشخصية.';

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
  String get deleteChildAccountsHeading => 'حسابات الأطفال التي ستُحذف أيضًا';

  @override
  String get deleteChildAccountsBody =>
      'أنت تدير حسابات الأطفال هذه. لا يستطيع أحد غيرك تسجيل الدخول إليها، لذا تُحذف مع حسابك بعد الأيام الأربعة عشر نفسها.';

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
  String get classesTitle => 'صفوفي';

  @override
  String get classesCreate => 'إنشاء صف';

  @override
  String get classesCreateTitle => 'إنشاء صف جديد';

  @override
  String get classesNameLabel => 'اسم الصف';

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
  String get classesCreateAction => 'إنشاء الصف';

  @override
  String get classesInviteTitle => 'دعوة الطلاب';

  @override
  String get classesInviteBody =>
      'شارك هذا الرابط الآمن. لا يُضاف الطلاب إلا بعد فتحه والانضمام إلى الصف.';

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
    return 'انضم إلى صفي في ستودافاي: $link';
  }

  @override
  String classesShareMessageWithCode(String link, String code) {
    return 'انضم إلى صفي في ستودافاي برمز الصف $code\nأو افتح هذا الرابط: $link';
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
  String get attendanceNoStudents => 'لا يوجد طلاب مسجّلون في هذا الصف.';

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
  String get rosterEmpty => 'لا يوجد طلاب مسجّلون في هذا الصف بعد.';

  @override
  String get rosterLoadFailed =>
      'تعذّر تحميل قائمة الصف. يُرجى المحاولة مرة أخرى.';

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
  String get assignmentClassLabel => 'الصف';

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
  String get assignmentClassRequired => 'اختر الصف المخصص له هذا الواجب.';

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
  String get announcementClassLabel => 'الصف';

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
  String get announcementClassRequired => 'اختر الصف الذي تريد الإعلان فيه.';

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
  String get gradebookNoStudents => 'لا يوجد طلاب مسجّلون في هذا الصف.';

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
  String get examClassLabel => 'الصف';

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
  String get examDeliveryOnlineDetail => 'يجيب الطلاب على الأسئلة في ستودافاي.';

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
  String get examClassRequired => 'اختر الصف الذي سيؤدي هذا الاختبار.';

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
      'يتبع سجل الحضور هذا الجدول، فالصف الذي يجتمع مرتين أسبوعيًا يحتاج إلى كليهما هنا.';

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
      'لا توجد حصص بعد. أضِف حصة ليعرف سجل الحضور موعد هذا الصف.';

  @override
  String get scheduleDuplicate =>
      'حصتان في اليوم والوقت نفسيهما. غيّر إحداهما.';

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
  String get joinLinkActive => 'يوجد رابط انضمام فعّال لهذا الصف.';

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
  String get studyAssistantTab => 'المساعد';

  @override
  String get studyHelperNeedsClassTitle =>
      'انضم إلى صف لاستخدام المساعد الدراسي';

  @override
  String get studyHelperNeedsClassBody =>
      'يعمل المساعد الدراسي مع صفوفك ودروسها. انضم إلى صف معلمك، ثم اسأله ما تشاء هنا.';

  @override
  String get joinClassAlreadyStaff =>
      'أنت معلم في هذه المدرسة، لذا لا يمكنك الانضمام إلى أحد صفوفها كطالب. اطلب من طالب فتح الرابط من حسابه.';

  @override
  String get academicAllClasses => 'كل الصفوف';

  @override
  String get insightsTitle => '⁦Family+⁩';

  @override
  String get insightsUnavailableTitle => 'التحليلات غير متاحة';

  @override
  String get insightsUnavailableBody =>
      'تحتاج إلى اشتراك ⁦Family+⁩ لعرض التحليلات التفصيلية، ويجب أن يكون ارتباطك بابنك مُعتمدًا.';

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
  String get insightMissingWork => 'فاتت مواعيد تسليم بعض الواجبات ولم تُسلَّم';

  @override
  String insightMissingWorkIn(String subject) {
    return 'فات موعد تسليم واجب في $subject';
  }

  @override
  String get insightMissedTests => 'فاتته بعض الاختبارات';

  @override
  String insightMissedTestsIn(String subject) {
    return 'فاته اختبار في $subject';
  }

  @override
  String get insightAttendanceLow => 'نسبة الحضور أقل من 90%';

  @override
  String insightStrength(String subject) {
    return '$subject هي أقوى مادة لديه حاليًا';
  }

  @override
  String insightEvClassAverage(String subject) {
    return 'معدل $subject';
  }

  @override
  String get insightEvOverallAverage => 'معدله في جميع المواد';

  @override
  String get insightEvRecentTypical => 'الدرجة المعتادة مؤخرًا';

  @override
  String get insightEvEarlierTypical => 'الدرجة المعتادة سابقًا';

  @override
  String get insightEvChange => 'التغيّر (نقاط)';

  @override
  String get insightEvOnTime => 'سُلّم في الوقت';

  @override
  String get insightEvLate => 'سُلّم متأخرًا';

  @override
  String get insightEvNotHandedIn => 'لم يُسلَّم';

  @override
  String insightEvWeekdayAbsences(String day) {
    return 'الغياب يوم $day';
  }

  @override
  String get insightEvAbsencesTotal => 'مجموع الغياب';

  @override
  String get insightEvDueSoon => 'مطلوب خلال 7 أيام ولم يُسلَّم';

  @override
  String get insightEvMissed => 'اختبارات فائتة';

  @override
  String get insightEvAttendanceRate => 'نسبة الحضور';

  @override
  String get insightEvSessions => 'الحصص المحسوبة';

  @override
  String get insightEvPastDue => 'تجاوز الموعد ولم يُسلَّم';

  @override
  String get insightsFocusTitle => 'ما يجب التركيز عليه';

  @override
  String get insightsProgressTitle => 'الدرجات عبر الوقت';

  @override
  String get insightsByClass => 'حسب الصف';

  @override
  String get insightsMissingTitle => 'واجبات غير مسلّمة';

  @override
  String get insightsRecentTitle => 'آخر الدرجات';

  @override
  String get insightsMissedTests => 'اختبارات فائتة';

  @override
  String insightsTrendUp(int points) {
    return 'ارتفاع $points نقاط مقارنة بالسابق';
  }

  @override
  String insightsTrendDown(int points) {
    return 'انخفاض $points نقاط مقارنة بالسابق';
  }

  @override
  String get insightsTrendSteady => 'مستقر مقارنة بالسابق';

  @override
  String get insightsTrendUnknown => 'لا توجد درجات كافية لتحديد الاتجاه بعد';

  @override
  String get insightsStrongest => 'الأقوى';

  @override
  String get insightsWeakest => 'الأضعف';

  @override
  String insightsClassAttendance(int rate) {
    return 'الحضور $rate%';
  }

  @override
  String insightsClassOnTime(int rate) {
    return 'في الوقت $rate%';
  }

  @override
  String insightsMissingCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count واجب ناقص',
      many: '$count واجبًا ناقصًا',
      few: '$count واجبات ناقصة',
      two: 'واجبان ناقصان',
      one: 'واجب واحد ناقص',
      zero: 'لا شيء ناقص',
    );
    return '$_temp0';
  }

  @override
  String insightsMissedCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count اختبار فائت',
      many: '$count اختبارًا فائتًا',
      few: '$count اختبارات فائتة',
      two: 'اختباران فائتان',
      one: 'اختبار واحد فائت',
    );
    return '$_temp0';
  }

  @override
  String get insightsMissed => 'فائت';

  @override
  String get insightsPaper => 'ورقي';

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
  String attachmentPhotoName(String time) {
    return 'صورة $time';
  }

  @override
  String get splashTagline => 'الحياة المدرسية، متّصلة.';

  @override
  String get attachmentPickFailed => 'تعذّر فتح هذه الصورة. جرّب صورة أخرى.';

  @override
  String attachmentUpToMaximumcountAttachments(Object maximumCount) {
    return 'حتى $maximumCount مرفقات.';
  }

  @override
  String get attachmentUploading => 'جارٍ الرفع';

  @override
  String get attachmentChecking => 'قيد الفحص';

  @override
  String get attachmentRefusedDamaged =>
      'لا يمكن استخدام هذا الملف: يبدو تالفًا أو غير معتاد. أزِله، أو احفظه مجددًا بصيغة PDF وأرفقه.';

  @override
  String get attachmentRefusedUnsafe =>
      'حُظر هذا الملف لأنه قد يكون ضارًا. أزِله.';

  @override
  String get attachmentRefusedNotAllowed =>
      'يحتوي هذا الملف على كلمة مرور أو نصوص برمجية أو ملفات أخرى بداخله، وهذا غير مسموح. أزِله.';

  @override
  String get attachmentRefusedOther =>
      'لا يمكن استخدام هذا الملف. أزِله وجرّب ملفًا آخر.';

  @override
  String get attachmentNotAcceptedScan =>
      'لم يجتز هذا الملف فحص الأمان. أزِله، ثم احفظ مرة أخرى.';

  @override
  String get attachmentNotAcceptedGone =>
      'لم يعد هذا الملف متاحًا. أزِله وأرفقه مرة أخرى.';

  @override
  String get attachmentRemovedBySafetyCheck => 'أزال فحص الأمان هذا الملف.';

  @override
  String get attachmentRemovedShort => 'أزاله فحص الأمان';

  @override
  String get attachmentNotAcceptedInUse =>
      'هذا الملف مُرفق بالفعل. أزِله، ثم احفظ مرة أخرى.';

  @override
  String get attachmentNotAcceptedHere =>
      'لا يمكن إضافة هذا الملف هنا. أزِله، ثم احفظ مرة أخرى.';

  @override
  String get linkNotAccepted =>
      'لا يمكن إضافة هذا الرابط. أزِله، ثم احفظ مرة أخرى.';

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
      'صفوفك، أفكارك، وإنجازك القادم.';

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
  String get teacherShellClasses => 'الصفوف';

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
      'الاختبارات والبطاقات متاحة مع ⁦Studafy Max⁩.';

  @override
  String get studySetThisMonthSAiAllowance =>
      'وصلت إلى حد استخدام الذكاء الاصطناعي. يُعاد ضبطه في موعد تجديد خطتك.';

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
  String studyPlansRenewsRenews(Object renews) {
    return 'يتجدد في $renews';
  }

  @override
  String get studyPlansTheStoreCouldNotBe =>
      'تعذّر الوصول إلى المتجر. حاول لاحقًا.';

  @override
  String get studyPlansPaymentsNotSetUp =>
      'الخطط المدفوعة غير متاحة للبيع بعد. كل الميزات المجانية تعمل كالمعتاد.';

  @override
  String get studyPlansCannotBuyYet =>
      'لا يمكن شراء هذه الخطة بعد - اطّلع على الملاحظة أسفلها.';

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
    return 'اشترك في ⁦$name⁩';
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
  String get notebookThisNeedsStudafyPlus => 'هذه الميزة تتطلب ⁦Studafy Plus⁩.';

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
      'ملاحظات السبورة متاحة مع ⁦Studafy Plus⁩.';

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
      'انضم إلى صف لتفعيل معرّف الطالب.';

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
    return 'إزالة $displayName من هذا الصف؟';
  }

  @override
  String get classroomAdminStaffRemoved => 'تمت إزالة المعلم.';

  @override
  String get classroomAdminWholeClass => 'الصف بالكامل';

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
    return 'سحب $displayName من هذا الصف؟';
  }

  @override
  String get classroomAdminStudentWithdrawn => 'تم سحب الطالب.';

  @override
  String classroomAdminTransferDisplayname(Object displayName) {
    return 'نقل $displayName';
  }

  @override
  String get classroomAdminTargetClass => 'الصف المستهدف';

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
  String get studyPlansFeatureEverythingInFree => 'كل ما في الخطة المجانية';

  @override
  String get studyPlansFeatureWhiteboard =>
      'صوّر السبورة واحصل على ملاحظات حقيقية في دفترك';

  @override
  String get studyPlansFeatureEverythingInPlus => 'كل ما في Plus';

  @override
  String get studyPlansFeatureQuizzes => 'اختبارات من دروسك';

  @override
  String get studyPlansFeatureFlashcards => 'بطاقات مراجعة من دروسك';

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
  String get msgErrorAttachmentRefused =>
      'لم يُقبل ملف، لذا لم يُرسَل شيء. أزِل الملف المُعلَّم، ثم حاول مرة أخرى.';

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
  String famApprovalsDetail(String name, String plan) {
    String _temp0 = intl.Intl.selectLogic(plan, {
      'studafy_plus': '⁦Studafy Plus⁩',
      'studafy_max': '⁦Studafy Max⁩',
      'other': 'إحدى خطط ستودافاي',
    });
    return 'طلب $name الاشتراك في $_temp0.';
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
  String get accountRecentSignInNeeded =>
      'سجّل الدخول مرة أخرى للتأكد من هويتك، ثم حاول مرة أخرى.';

  @override
  String get accountExportReauth =>
      'سجّل الدخول مرة أخرى للتأكد من هويتك، ثم حاول مرة أخرى.';

  @override
  String get accountExportExpired =>
      'انتهت صلاحية تلك النسخة. اطلب نسخة جديدة.';

  @override
  String get accountExportFailed => 'لم ينجح ذلك. يرجى المحاولة مرة أخرى.';

  @override
  String get todayWork => 'أعمال عليك إسنادها';

  @override
  String get todayWorkEmpty =>
      'لا شيء لإسناده الآن. تظهر هنا المسودات والأعمال المفتوحة أو القادمة.';

  @override
  String get todaySections => 'حصص تنتظر المحتوى';

  @override
  String get todaySectionsEmpty => 'لكل حصة درّستها درس يراه طلاب الصف.';

  @override
  String get todaySectionsOutstanding => 'لا يوجد درس بعد';

  @override
  String get todayTitle => 'اليوم';

  @override
  String get todayHello => 'مرحباً';

  @override
  String todayHelloName(String name) {
    return 'مرحباً، $name';
  }

  @override
  String get todayClasses => 'صفوفي';

  @override
  String todayStudents(int count) {
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
  String get todayEmpty => 'لا توجد صفوف بعد';

  @override
  String get todayEmptyDetail => 'أنشئ صفك الأول من تبويب الصفوف.';

  @override
  String get todayError => 'تعذّر تحميل الصفوف';

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
  String get navClasses => 'الصفوف';

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
      'أصبح تقييم جديد متاحًا لأحد صفوفك.';

  @override
  String get notificationCopyAcademicAssignmentPublishedTitle =>
      'تم نشر الواجب';

  @override
  String get notificationCopyAcademicAssignmentPublishedDetail =>
      'أصبح واجب جديد متاحًا لأحد صفوفك.';

  @override
  String get notificationCopyAcademicGradePublishedTitle => 'درجة جديدة';

  @override
  String get notificationCopyAcademicGradePublishedDetail =>
      'تم نشر درجة جديدة. افتح الدرجات للاطلاع عليها.';

  @override
  String get notificationCopyAcademicGradesPublishedTitle => 'درجات جديدة';

  @override
  String get notificationCopyAcademicGradesPublishedDetail =>
      'نشر معلمك درجات جديدة. افتح الدرجات للاطلاع عليها.';

  @override
  String get notificationCopyAcademicGradesCorrectedTitle => 'تم تعديل درجة';

  @override
  String get notificationCopyAcademicGradesCorrectedDetail =>
      'صحّح معلمك درجة منشورة. افتح الدرجات لرؤية الدرجة الجديدة.';

  @override
  String get notificationCopyAcademicResourcePublishedTitle =>
      'مادة دراسية جديدة';

  @override
  String get notificationCopyAcademicResourcePublishedDetail =>
      'شارك معلمك مادة جديدة لأحد صفوفك.';

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
      'تم تعيين موظف لأحد الصفوف.';

  @override
  String get notificationCopySchoolAdminClassroomStaffRemovedTitle =>
      'إزالة موظف';

  @override
  String get notificationCopySchoolAdminClassroomStaffRemovedDetail =>
      'تمت إزالة موظف من أحد الصفوف.';

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
      'تم نقل طالب بين الصفوف.';

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
    return '⁦Family+⁩ لـ $name';
  }

  @override
  String get familyPlusIntro =>
      'اشتراك واحد للعائلة. اعرف كيف يسير كل طفل فعلًا، وأين يحتاج إلى المساعدة، وما الذي يمكنك فعله هذا الأسبوع.';

  @override
  String get familyPlusFeatureTrends =>
      'ما الذي تغيّر هذا الفصل، مع السجلات التي تثبت كل ملاحظة';

  @override
  String get familyPlusFeatureSchool => 'ملاحظات اختارت المدرسة مشاركتها معك';

  @override
  String get familyPlusFeatureFocus =>
      'ما الذي يجب التركيز عليه هذا الأسبوع، الأهم أولًا';

  @override
  String get familyPlusFeatureClasses =>
      'كل الصفوف جنبًا إلى جنب - المعدل والاتجاه والحضور والواجبات، مع تحديد الأقوى والأضعف';

  @override
  String get familyPlusFeatureChart =>
      'رسم بياني للدرجات عبر الوقت وآخر الدرجات - بما فيها الاختبارات الورقية';

  @override
  String get familyPlusFeatureMissing =>
      'الواجبات غير المسلّمة والاختبارات الفائتة حتى لا يفوت شيء';

  @override
  String familyPlusPlanName(int seats) {
    return 'حتى $seats أطفال';
  }

  @override
  String familyPlusPlanDetail(int seats) {
    return 'سعر شهري واحد للعائلة كلها: جميع أطفالك المرتبطين، حتى $seats.';
  }

  @override
  String get familyPlusYourPlan => 'خطتك';

  @override
  String familyPlusSubscribePlan(int seats) {
    return 'اشترك لحتى $seats أطفال';
  }

  @override
  String familyPlusUpgrade(int seats) {
    return 'الترقية إلى حتى $seats أطفال';
  }

  @override
  String get familyPlusCannotBuyYet =>
      'لا يمكن شراء هذه الخطة في هذا الإصدار من التطبيق بعد.';

  @override
  String get familyPlusNotCoveredTitle => 'غير مشمول في خطتك بعد';

  @override
  String familyPlusNotCovered(int seats, String name) {
    return 'يشمل ⁦Family+⁩ لديك أول $seats أطفال ربطتهم، و$name ليس منهم. انتقل إلى خطة حتى 8 أطفال لتشمل $name.';
  }

  @override
  String get familyPlusCoversFamily =>
      'يُشمل أطفالك بترتيب ربطهم. الطفل الذي تربطه لاحقًا يُضاف فورًا ما دام في الخطة مكان.';

  @override
  String familyPlusPrice(String price) {
    return '$price شهريًا';
  }

  @override
  String familyPlusUsPrice(String price) {
    return '$price شهريًا في الولايات المتحدة - يعرض المتجر سعرك';
  }

  @override
  String familyPlusTrial(String trial, String price) {
    return 'إن كنت مؤهلًا، مجانًا لمدة $trial، ثم $price شهريًا';
  }

  @override
  String get familyPlusStartTrial => 'ابدأ الفترة التجريبية المجانية';

  @override
  String get familyPlusCheckingStore => 'جارٍ التحقق من سعر المتجر...';

  @override
  String get familyPlusStoreUnavailable =>
      'تعذّر الوصول إلى المتجر. حاول مرة أخرى لاحقًا.';

  @override
  String get familyPlusNotInThisBuild =>
      'لا يمكن شراء ⁦Family+⁩ في هذا الإصدار من التطبيق.';

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

  @override
  String get studySetMaxBadge => 'باقة ⁦Studafy Max⁩';

  @override
  String get studySetSwitchedOff =>
      'الاختبارات وبطاقات المراجعة غير مفعّلة بعد.';

  @override
  String get studyAssistantOff =>
      'مساعد الدراسة غير مفعّل بعد. دروسك ودفترك يعملان كالمعتاد.';

  @override
  String get studyAssistantUnavailable =>
      'تعذّر على مساعد الدراسة الإجابة الآن. حاول مرة أخرى بعد قليل.';

  @override
  String get accountsSwitchAccount => 'تبديل الحساب';

  @override
  String get accountsSwitchAccountDetail =>
      'الحسابات على هذا الجهاز وحسابات أطفالك';

  @override
  String get accountsSheetTitle => 'الحسابات';

  @override
  String get accountsAddAccount => 'إضافة حساب';

  @override
  String get accountsCreateChild => 'إنشاء حساب لطفل';

  @override
  String get accountsCreateChildDetail => 'لطفل ليس لديه بريد إلكتروني أو هاتف';

  @override
  String get accountsSubAccount => 'حساب فرعي';

  @override
  String accountsSubAccountOf(String name) {
    return 'حساب فرعي · يديره $name';
  }

  @override
  String get accountsCurrent => 'الحساب الحالي';

  @override
  String get accountsSwitching => 'جارٍ تبديل الحساب…';

  @override
  String get accountsSwitch => 'تبديل';

  @override
  String get accountsSwitchFailed =>
      'تعذّر فتح هذا الحساب. سجّل الدخول إليه مرة أخرى من «إضافة حساب».';

  @override
  String get accountsNeedsParent =>
      'يُفتح حساب هذا الطفل من حساب ولي الأمر. سجّل الدخول إلى حساب ولي الأمر على هذا الجهاز أولًا.';

  @override
  String get childAccountTitle => 'إنشاء حساب لطفل';

  @override
  String get childAccountIntro =>
      'لطفل صغير ليس لديه بريد إلكتروني أو هاتف. تفتح حسابه من حسابك وتعود إلى حسابك في أي وقت. يرى معلموه عمله باسمه.';

  @override
  String get childAccountName => 'اسم الطفل';

  @override
  String get childAccountNameHelp => 'كما سيراه معلموه';

  @override
  String get childAccountConsent =>
      'أنا والد هذا الطفل أو وليّه القانوني، وأوافق على شروط الاستخدام وسياسة الخصوصية نيابةً عنه.';

  @override
  String get childAccountCreate => 'إنشاء الحساب';

  @override
  String childAccountCreated(String name) {
    return 'حساب $name جاهز.';
  }

  @override
  String get childAccountNextStep =>
      'الخطوة التالية: انتقل إلى حسابه وانضم إلى صفه بالرابط أو الرمز من معلمه.';

  @override
  String childAccountOpenNow(String name) {
    return 'الانتقال إلى $name';
  }

  @override
  String get childAccountLimit => 'يمكنك إدارة ستة حسابات أطفال كحد أقصى.';

  @override
  String get childAccountUnavailable =>
      'حسابات الأطفال غير متاحة على هذا الخادم بعد.';

  @override
  String get childAccountFailed => 'تعذّر إنشاء الحساب. حاول مرة أخرى.';

  @override
  String get msgVoiceRecord => 'تسجيل رسالة صوتية';

  @override
  String get msgVoiceRecording => 'جارٍ التسجيل';

  @override
  String get msgVoiceDiscard => 'حذف';

  @override
  String get msgVoiceSend => 'إرسال الرسالة الصوتية';

  @override
  String get msgVoiceMessage => 'رسالة صوتية';

  @override
  String get msgVoicePlay => 'تشغيل الرسالة الصوتية';

  @override
  String get msgVoicePause => 'إيقاف مؤقت';

  @override
  String get msgVoiceChecking => 'جارٍ فحص الرسالة الصوتية…';

  @override
  String get msgVoiceUnavailable => 'تعذّر تشغيل هذه الرسالة الصوتية.';

  @override
  String get msgVoiceNoPermission =>
      'اسمح بالوصول إلى الميكروفون من الإعدادات لتسجيل الرسائل الصوتية.';

  @override
  String get msgVoiceTooShort => 'كانت قصيرة جدًا لإرسالها.';

  @override
  String get msgVoiceFailed => 'تعذّر إرسال الرسالة الصوتية. حاول مرة أخرى.';

  @override
  String get msgVoiceLimit =>
      'يمكن أن تصل مدة الرسالة الصوتية إلى 5 دقائق، لذا أُرسلت هذه الرسالة.';

  @override
  String get lessonNewTitle => 'درس جديد';

  @override
  String get lessonTitleLabel => 'عنوان الدرس';

  @override
  String get lessonNotesLabel => 'ملاحظات الدرس';

  @override
  String get lessonNotesHelp => 'ما شرحته. يقرؤه الطلاب في قسم الدروس.';

  @override
  String get lessonPickClassForFiles => 'اختر الصف أولًا لإرفاق الملفات.';

  @override
  String get lessonAudienceLabel => 'من يمكنه رؤيته';

  @override
  String get lessonAudienceBoth => 'الجميع';

  @override
  String get lessonAudienceStudents => 'الطلاب';

  @override
  String get lessonAudienceParents => 'أولياء الأمور';

  @override
  String get lessonClassRequired => 'اختر الصف الذي يخصه هذا الدرس.';

  @override
  String get lessonTitleRequired => 'أضف عنوانًا للدرس.';

  @override
  String get lessonContentRequired => 'اكتب بعض الملاحظات أو أرفق ملفًا.';

  @override
  String get lessonSave => 'إضافة الدرس';

  @override
  String get lessonSaving => 'جارٍ الإضافة…';

  @override
  String get lessonCreated => 'تمت إضافة الدرس.';

  @override
  String get lessonCreateFailed => 'تعذّرت إضافة الدرس. حاول مرة أخرى.';

  @override
  String get academicAddLesson => 'إضافة درس';

  @override
  String get examMaterialHelp =>
      'أرفق ورقة الامتحان أو ورقة مراجعة أو أي شيء يحتاجه الطلاب.';

  @override
  String get teacherCreateAction => 'إنشاء';

  @override
  String get teacherCreateTitle => 'إنشاء';

  @override
  String get teacherCreateLesson => 'درس';

  @override
  String get teacherCreateLessonDetail => 'ملاحظات وملفات لصف';

  @override
  String get teacherCreateAssignment => 'واجب';

  @override
  String get teacherCreateAssignmentDetail =>
      'عمل يسلّمه الطلاب، مع درجة أو بدونها';

  @override
  String get teacherCreateExam => 'امتحان أو تقييم';

  @override
  String get teacherCreateExamDetail => 'يُرصد في دفتر الدرجات مع إرفاق ورقته';

  @override
  String get teacherCreateAnnouncement => 'إعلان';

  @override
  String get teacherCreateAnnouncementDetail =>
      'أخبر صفًا أو أولياء أموره بأمر ما';

  @override
  String get teacherCreateAttendance => 'الحضور';

  @override
  String get teacherCreateAttendanceDetail => 'سجّل حضور اليوم لصف';

  @override
  String get teacherPickClass => 'أي صف؟';

  @override
  String get teacherNoClassesYet => 'أنشئ صفًا أولًا من تبويب الصفوف.';

  @override
  String get academicThisClass => 'هذا الصف';

  @override
  String get studyAssistantNewChat => 'محادثة جديدة';

  @override
  String get studyAssistantHistory => 'سجل المحادثات';

  @override
  String get studyAssistantHistoryEmpty =>
      'لا توجد محادثات بعد. تُحفظ محادثاتك على هذا الجهاز فقط.';

  @override
  String get studyAssistantOnDevice => 'محفوظة على هذا الجهاز فقط';

  @override
  String get studyAssistantDeleteChat => 'حذف المحادثة';

  @override
  String get studyAssistantDeleteAll => 'حذف كل المحادثات';

  @override
  String get studyAssistantDeleteAllConfirm =>
      'حذف كل المحادثات على هذا الجهاز؟ لا يمكن التراجع عن ذلك.';

  @override
  String get studyAssistantDelete => 'حذف';

  @override
  String get studyAssistantCancel => 'إلغاء';

  @override
  String get studyAssistantSend => 'إرسال';

  @override
  String get studyAssistantMessageHint => 'اطرح سؤالًا…';

  @override
  String get studyAssistantTooShort => 'اكتب أكثر قليلًا أولًا.';

  @override
  String studyAssistantMessageCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count رسالة',
      many: '$count رسالة',
      few: '$count رسائل',
      two: 'رسالتان',
      one: 'رسالة واحدة',
      zero: 'لا رسائل',
    );
    return '$_temp0';
  }

  @override
  String get studyAssistantYou => 'أنت';

  @override
  String get studyAssistantHelperName => 'مساعد الدراسة';

  @override
  String get setupTitle => 'عرّفنا بنفسك';

  @override
  String get setupIntro => 'نسأل هذا مرة واحدة، عند تسجيل دخولك لأول مرة.';

  @override
  String get setupNameLabel => 'اسمك';

  @override
  String get setupNameHelp => 'كما سيراك معلموك وزملاؤك ومدرستك';

  @override
  String get setupNameRequired => 'أدخل اسمك.';

  @override
  String get setupGenderLabel => 'الجنس';

  @override
  String get setupGenderMale => 'ذكر';

  @override
  String get setupGenderFemale => 'أنثى';

  @override
  String get setupGenderPrivate => 'لا يراه أحد غيرك.';

  @override
  String get setupGenderPreferNot => 'أفضّل عدم الإجابة';

  @override
  String get setupGenderRequired => 'اختر إجابة - «أفضّل عدم الإجابة» مقبولة.';

  @override
  String get setupContinue => 'متابعة';

  @override
  String get setupSaving => 'جارٍ الحفظ…';

  @override
  String get setupFailed => 'تعذّر الحفظ. حاول مرة أخرى.';

  @override
  String get studyToolsTitle => 'الاختبارات وبطاقات المراجعة';

  @override
  String get studyToolsReady =>
      'أنشئ اختبارًا أو بطاقات مراجعة من أي درس أدناه.';

  @override
  String get studyToolsNoLessons => 'تظهر تحت كل درس بمجرد أن يضيفه معلمك.';

  @override
  String get studyToolsLocked => 'متاحة مع ⁦Studafy Max⁩.';

  @override
  String get linksAdd => 'إضافة رابط';

  @override
  String get linksAddTitle => 'إضافة رابط';

  @override
  String get linksInvalid => 'أدخل عنوانًا كاملًا يبدأ بـ https://';

  @override
  String get linksRemove => 'إزالة الرابط';

  @override
  String get linksCancel => 'إلغاء';

  @override
  String get linksOpenTitle => 'فتح هذا الرابط؟';

  @override
  String get linksOpen => 'فتح';

  @override
  String get notebookFromLesson => 'من درس';

  @override
  String get notebookPickLesson => 'اختر درسًا';

  @override
  String get notebookNoLessons => 'لا توجد دروس في هذا الصف بعد.';

  @override
  String get notebookCopyLesson => 'نسخ إلى دفتري';

  @override
  String get notebookCopyLessonDetail => 'الدرس كما كتبه معلمك';

  @override
  String get notebookLessonNotes => 'تحويله إلى ملاحظات دراسية';

  @override
  String get notebookLessonNotesDetail =>
      'عناوين ومصطلحات رئيسية وملخص - ⁦Studafy Plus⁩';

  @override
  String get notebookLessonCopied => 'أُضيف إلى دفترك.';

  @override
  String get notebookFromLessonBadge => 'من درس';

  @override
  String get notebookMyNotebooks => 'دفاتري';

  @override
  String get notebookClassGone => 'هذا الصف لم يعد موجودًا - ملاحظاتك محفوظة';

  @override
  String get notebookNoNotebooks =>
      'لا توجد ملاحظات بعد. تظهر هنا الملاحظات التي تكتبها في كل صف، مرتبة حسب الصف.';

  @override
  String notebookNoteCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count ملاحظة',
      many: '$count ملاحظة',
      few: '$count ملاحظات',
      two: 'ملاحظتان',
      one: 'ملاحظة واحدة',
      zero: 'لا ملاحظات',
    );
    return '$_temp0';
  }

  @override
  String get classDeleteAction => 'حذف الصف';

  @override
  String classDeleteTitle(String name) {
    return 'حذف $name؟';
  }

  @override
  String get classDeleteBody =>
      'سيختفي الصف لك ولطلابك، وسيتوقف رابط الانضمام إليه. يحتفظ الطلاب بكل ملاحظاتهم في دفاترهم لهذا الصف، وسيظهر أن الصف لم يعد موجودًا.';

  @override
  String get classDeleteConfirm => 'حذف الصف';

  @override
  String get classDeleteCancel => 'إبقاؤه';

  @override
  String get classDeleted => 'حُذف الصف. يحتفظ الطلاب بملاحظاتهم.';

  @override
  String get classDeleteFailed => 'تعذّر حذف الصف. حاول مرة أخرى.';

  @override
  String get helperAdd => 'إضافة مادة أو صورة';

  @override
  String get helperAddMaterial => 'مواد الصف';

  @override
  String get helperAddMaterialDetail => 'درس أو إحدى ملاحظاتك ليُجيب منها';

  @override
  String get helperAddPhoto => 'صورة من المعرض';

  @override
  String get helperTakePhoto => 'التقاط صورة';

  @override
  String get helperPhotoPlus => 'الصور متاحة مع ⁦Studafy Plus⁩.';

  @override
  String get helperPhotoChecking => 'جارٍ فحص الصورة…';

  @override
  String get helperPhotoFailed => 'تعذّر إرسال الصورة. حاول مرة أخرى.';

  @override
  String get helperAnsweringFrom => 'يجيب من';

  @override
  String get helperRemove => 'إزالة';

  @override
  String get helperPickTitle => 'اختر مواد الصف';

  @override
  String get helperPickClass => 'أي صف؟';

  @override
  String get helperLessons => 'الدروس';

  @override
  String get helperMyNotes => 'ملاحظاتي';

  @override
  String get helperPickDone => 'استخدام هذه';

  @override
  String get helperPickLimit => 'حتى 5 في المرة الواحدة.';

  @override
  String get helperNothingInClass => 'لا توجد دروس أو ملاحظات في هذا الصف بعد.';

  @override
  String get helperNoClasses => 'انضم إلى صف لتستخدم دروسه هنا.';

  @override
  String get upgradeAllowanceBody =>
      'وصلت إلى حد استخدام الذكاء الاصطناعي. يُعاد ضبطه في موعد تجديد خطتك، أو تمنحك خطة أكبر المزيد.';

  @override
  String upgradeFeatureTitle(String plan) {
    return 'هذه الميزة متاحة مع ⁦$plan⁩';
  }

  @override
  String get upgradeFeatureBody => 'خطتك الحالية لا تتضمنها.';

  @override
  String upgradeWhatUnlocks(String plan) {
    return 'ما تتيحه ⁦$plan⁩';
  }

  @override
  String get upgradeButton => 'ترقية';

  @override
  String get upgradeNotNow => 'ليس الآن';

  @override
  String get upgradeTopPlan => 'أنت على ⁦Studafy Max⁩، أكبر خطة.';

  @override
  String get studyPlansIncludedInYourPlan => 'مضمّنة في خطتك';

  @override
  String studyPlansUpgradeToName(String name) {
    return 'الترقية إلى ⁦$name⁩';
  }

  @override
  String studyPlansUpgradeReplaces(String current) {
    return 'يُستبدل اشتراكك في ⁦$current⁩ فورًا، ويحتسب المتجر ما دفعته مسبقًا.';
  }

  @override
  String studyPlansRenewsOn(String date) {
    return 'يتجدد في $date';
  }

  @override
  String studyPlansCancelledUntil(String plan, String date) {
    return 'أُلغي. تبقى لديك ⁦$plan⁩ حتى $date ولن تُحاسَب مرة أخرى.';
  }

  @override
  String get studyPlansPausedNote =>
      'متوقف مؤقتًا في Google Play. لا رسوم أثناء الإيقاف، ويُستأنف تلقائيًا.';

  @override
  String studyPlansPaymentIssue(String store, String plan) {
    return 'تعذّر على $store تحصيل الدفعة. حدّث طريقة الدفع للاحتفاظ بـ ⁦$plan⁩.';
  }

  @override
  String get studyPlansUpdatePayment => 'تحديث طريقة الدفع';

  @override
  String get studyPlansManageSubscription => 'إدارة الاشتراك';

  @override
  String get studyPlansCancelSubscription => 'إلغاء الاشتراك';

  @override
  String studyPlansPaidByParent(String store) {
    return 'يدفع أحد الوالدين ثمن هذه الخطة. يمكنه وحده تغييرها أو إلغاؤها من حسابه في $store.';
  }

  @override
  String studyPlansBilledBy(String store) {
    return 'تُحاسَب شهريًا عبر $store';
  }

  @override
  String get studyPlansEndOfPeriod => 'نهاية فترة الفوترة الحالية';

  @override
  String get studyPlansPayWithApple =>
      'تدفع بطريقة الدفع في حساب Apple، مثل البطاقة، أو Apple Pay حيث توفّره Apple. لا يرى Studafy بطاقتك أبدًا.';

  @override
  String get studyPlansPayWithGoogle =>
      'تدفع بطريقة الدفع في حساب Google Play، مثل البطاقة، أو Google Pay حيث توفّره Google. لا يرى Studafy بطاقتك أبدًا.';

  @override
  String get studyPlansBuyInMobileApp =>
      'تُشترى الخطط من تطبيق Studafy على iPhone أو Android. تعمل الخطة التي تشتريها هناك هنا عند تسجيل الدخول بالحساب نفسه.';

  @override
  String get studyPlansBlockedAlready => 'لديك هذه الخطة بالفعل.';

  @override
  String get studyPlansBlockedParent =>
      'يدفع أحد الوالدين ثمن خطتك الحالية، لذا يمكنه وحده تغييرها.';

  @override
  String studyPlansBlockedOtherStore(String store) {
    return 'تُحاسَب خطتك الحالية عبر $store. غيّرها هناك، من الجهاز الذي اشتريتها منه.';
  }

  @override
  String get studyPlansBlockedOriginalAccount =>
      'لا يمكن لـ Google Play ترقية خطتك إلا من حساب Google الذي اشتراها. استخدم ذلك الحساب في متجر Play، أو ألغِ خطتك الحالية أولًا.';

  @override
  String get cancelSheetTitle => 'قبل أن تلغي';

  @override
  String get cancelPauseTitle => 'أوقفه مؤقتًا بدلًا من ذلك';

  @override
  String cancelPauseBody(String plan, String date) {
    return 'خذ استراحة من أسبوع إلى 3 أشهر. تبقى لديك ⁦$plan⁩ حتى $date. بعدها يتوقف مؤقتًا: لا ميزات ⁦$plan⁩ ولا رسوم حتى يُستأنف تلقائيًا. يمكنك الاستئناف مبكرًا.';
  }

  @override
  String get cancelPauseButton => 'إيقاف مؤقت في Google Play';

  @override
  String cancelCancelBody(String plan, String date) {
    return 'تبقى لديك ⁦$plan⁩ حتى $date ولن تُحاسَب مرة أخرى. بعد ذلك تنتقل إلى ⁦Studafy Free⁩، وتبقى دفاترك ودروسك.';
  }

  @override
  String cancelInStore(String store) {
    return 'الإلغاء في $store';
  }

  @override
  String cancelStoreNote(String store) {
    return 'يدير $store اشتراكك، لذا يفتح هذا صفحة الاشتراكات فيه. اختر Studafy هناك.';
  }

  @override
  String get cancelKeepPlan => 'الإبقاء على خطتي';

  @override
  String get notificationCopyBillingSubscriptionActiveTitle => 'الاشتراك مفعّل';

  @override
  String get notificationCopyBillingSubscriptionActiveDetail =>
      'اشتراكك مفعّل. ترسل Apple أو Google Play الإيصال إلى بريدك الإلكتروني.';

  @override
  String get notificationCopyBillingSubscriptionRenewedTitle =>
      'تم تجديد الاشتراك';

  @override
  String get notificationCopyBillingSubscriptionRenewedDetail =>
      'تم تجديد اشتراكك. ترسل Apple أو Google Play الإيصال إلى بريدك الإلكتروني.';

  @override
  String get notificationCopyBillingPaymentProblemTitle => 'مشكلة في الدفع';

  @override
  String get notificationCopyBillingPaymentProblemDetail =>
      'تعذّر تجديد اشتراكك. تحقّق من طريقة الدفع في App Store أو Google Play.';

  @override
  String get notificationCopyBillingSubscriptionEndedTitle => 'انتهى الاشتراك';

  @override
  String get notificationCopyBillingSubscriptionEndedDetail =>
      'انتهى اشتراكك. يمكنك الاشتراك مرة أخرى من صفحة الخطط.';

  @override
  String get notificationCopySystemPushTestTitle => 'إشعار تجريبي';

  @override
  String get notificationCopySystemPushTestDetail =>
      'الإشعارات تعمل على هذا الجهاز.';

  @override
  String get notificationCopyAccountInactiveDeletionWarningTitle =>
      'سيُحذف حسابك';

  @override
  String get notificationCopyAccountInactiveDeletionWarningDetail =>
      'لم يُستخدم هذا الحساب منذ ما يقارب سنتين، لذلك سيُحذف بعد نحو شهر. استخدامك للتطبيق يُبقيه.';

  @override
  String get famLinkHasAccount => 'لدى طفلي حساب في Studafy';

  @override
  String get famLinkHasAccountBody =>
      'ابحث عنه برقم Studafy الموجود في ملفه. يوافق على الربط من حسابه.';

  @override
  String get famLinkCreateAccount => 'إنشاء حساب لطفلي';

  @override
  String get famLinkCreateAccountBody =>
      'لطفل ليس لديه بريد إلكتروني أو هاتف. تدير الحساب وتفتحه من حسابك. لا حاجة لموافقة طفلك.';

  @override
  String get famManagedTitle => 'حسابات الأطفال التي تديرها';

  @override
  String get famManagedHint =>
      'افتح حساب طفلك لينضم إلى صفه برمز الصف. يظهر تقدمه هنا بعد ذلك.';

  @override
  String get famManagedOpen => 'فتح الحساب';

  @override
  String get courseworkVersionConflict =>
      'غيّر شخص آخر هذا أثناء عملك. أعد التحميل لرؤية أحدث نسخة ثم حاول مرة أخرى.';

  @override
  String get courseworkNotAllowed =>
      'ليست لديك صلاحية للقيام بهذا في هذا الصف.';

  @override
  String get courseworkWindowClosed =>
      'انتهى موعد تسليم هذا العمل. اطلب من معلمك مزيدًا من الوقت.';

  @override
  String get courseworkSubmissionLocked =>
      'صحّح معلمك هذا العمل بالفعل، لذا لا يمكن استبداله. اسأل معلمك إذا كنت بحاجة إلى تسليمه مرة أخرى.';

  @override
  String get courseworkReasonRequired => 'يرجى ذكر السبب. سيُحفظ مع التعديل.';

  @override
  String get courseworkAttendanceLocked =>
      'هذا السجل مقفل وفق سياسة الحضور في مدرستك.';

  @override
  String get courseworkEntriesInvalid =>
      'بعض الصفوف تحتاج إلى تصحيح. لم يُحفظ شيء.';

  @override
  String get courseworkFailed =>
      'لم تنجح العملية. تحقق من اتصالك وحاول مرة أخرى.';

  @override
  String get courseworkAttachmentRefused =>
      'لم يُقبل ملف أو رابط، لذا لم يُحفظ شيء. أزِل ما هو مُعلَّم، ثم احفظ مرة أخرى.';

  @override
  String paperGradesTitle(String title) {
    return 'كشف الدرجات: $title';
  }

  @override
  String get paperGradesPaperLabel => 'ورقي';

  @override
  String get paperGradesOnlineLabel => 'إلكتروني';

  @override
  String get paperGradesPaperSection => 'أعمال ورقية';

  @override
  String get paperGradesOnlineSection => 'أعمال إلكترونية';

  @override
  String get paperGradesNew => 'درجة ورقية جديدة';

  @override
  String get paperGradesOpenSheet => 'فتح كشف الدرجات';

  @override
  String get paperGradesSheetHint =>
      'هذا عمل ورقي. أدخل درجات الصف كله في كشف الدرجات.';

  @override
  String paperGradesOutOf(String max) {
    return 'من $max';
  }

  @override
  String paperGradesWeight(String weight) {
    return 'يُحتسب $weight٪';
  }

  @override
  String get paperGradesScore => 'درجة';

  @override
  String get paperGradesAbsent => 'لم يحضر الاختبار';

  @override
  String get paperGradesNotGraded => 'بلا تقييم';

  @override
  String get paperGradesUnmarked => 'لم تُصحَّح بعد';

  @override
  String get paperGradesStateDraft => 'مسودة';

  @override
  String get paperGradesStateReady => 'جاهزة';

  @override
  String get paperGradesStatePublished => 'منشورة';

  @override
  String get paperGradesStateChanged => 'غير محفوظة';

  @override
  String get paperGradesLeftClass => 'غادر الصف';

  @override
  String get paperGradesComment => 'ملاحظة (اختيارية)';

  @override
  String get paperGradesAddComment => 'إضافة ملاحظة';

  @override
  String get paperGradesSaveDraft => 'حفظ كمسودة';

  @override
  String get paperGradesSaving => 'جارٍ الحفظ…';

  @override
  String get paperGradesSaved =>
      'حُفظت المسودة. لا يستطيع الطلاب وأولياء الأمور رؤيتها بعد.';

  @override
  String get paperGradesPublish => 'نشر';

  @override
  String get paperGradesSaveFirst => 'احفظ تغييراتك قبل النشر.';

  @override
  String get paperGradesNothingToPublish =>
      'لا يوجد شيء جاهز للنشر. أدخل الدرجات واحفظها أولًا.';

  @override
  String get paperGradesPublishTitle => 'نشر الدرجات؟';

  @override
  String paperGradesPublishBody(int ready, int unmarked) {
    return 'ستظهر $ready درجة للطلاب وأولياء أمورهم وسيصلهم إشعار. يبقى $unmarked طالبًا بلا درجة غير منشورين.';
  }

  @override
  String paperGradesPublished(int count) {
    return 'نُشرت $count درجة.';
  }

  @override
  String get paperGradesCancel => 'إلغاء';

  @override
  String paperGradesCounts(int ready, int published, int unmarked) {
    return '$ready جاهزة · $published منشورة · $unmarked بلا درجة';
  }

  @override
  String get paperGradesEmpty => 'لا يوجد طلاب مسجلون في هذا الصف بعد.';

  @override
  String get paperGradesLoadFailed => 'تعذّر تحميل كشف الدرجات.';

  @override
  String get paperGradesRetry => 'حاول مرة أخرى';

  @override
  String get paperGradesCorrect => 'تصحيح';

  @override
  String paperGradesCorrected(int count) {
    return 'صُحّحت $count مرة';
  }

  @override
  String get paperGradesRowNotEnrolled => 'ليس في هذا الصف';

  @override
  String get paperGradesRowAlreadyPublished => 'منشورة بالفعل. استخدم التصحيح.';

  @override
  String get paperGradesRowScoreRequired => 'أدخل درجة';

  @override
  String paperGradesRowScoreOutOfRange(String max) {
    return 'يجب أن تكون بين 0 و$max';
  }

  @override
  String get paperGradesRowScoreNotAllowed => 'لا درجة للغائب أو غير المقيَّم';

  @override
  String get paperGradesRowConflict => 'غيّرها شخص آخر';

  @override
  String get paperGradesRowInvalid => 'تحقق من هذا الصف';

  @override
  String get paperGradesEditItem => 'تعديل التفاصيل';

  @override
  String get paperItemTitle => 'درجة ورقية';

  @override
  String get paperItemName => 'الاسم';

  @override
  String get paperItemNameHint => 'مثال: امتحان الفصل الأول';

  @override
  String get paperItemCategory => 'النوع';

  @override
  String get paperItemCategoryExam => 'امتحان ورقي';

  @override
  String get paperItemCategoryHomework => 'واجب';

  @override
  String get paperItemCategoryQuiz => 'اختبار قصير';

  @override
  String get paperItemCategoryParticipation => 'مشاركة';

  @override
  String get paperItemCategoryOther => 'أخرى';

  @override
  String get paperItemCategoryCustom => 'نوع العمل';

  @override
  String get paperItemMaximum => 'الدرجة القصوى';

  @override
  String get paperItemWeight => 'الوزن ٪ (اختياري)';

  @override
  String get paperItemDate => 'التاريخ (اختياري)';

  @override
  String get paperItemPickDate => 'اختر تاريخًا';

  @override
  String get paperItemSave => 'حفظ';

  @override
  String get paperItemInvalid =>
      'أدخل اسمًا ودرجة قصوى أكبر من 0. الوزن بين 0 و100.';

  @override
  String gradeCorrectionTitle(String name) {
    return 'تصحيح درجة $name';
  }

  @override
  String get gradeCorrectionReason => 'سبب التعديل';

  @override
  String get gradeCorrectionReasonHint => 'مثال: أعدت جمع درجات الصفحة 3';

  @override
  String get gradeCorrectionReasonWhen =>
      'مطلوب فقط عند تغيير العلامة أو الدرجة.';

  @override
  String get gradeCorrectionReasonTooShort => 'اذكر سببًا من 3 أحرف على الأقل.';

  @override
  String get gradeCorrectionSave => 'حفظ التصحيح';

  @override
  String get gradeCorrectionNotifies =>
      'إذا تغيّرت الدرجة يُبلَّغ الطالب وأولياء أمره. يُسجَّل تعديل الملاحظة وحدها دون إشعار.';

  @override
  String get gradeCorrectionHistory => 'التعديلات';

  @override
  String get gradeCorrectionHistoryEmpty => 'لا تعديلات بعد.';

  @override
  String get gradeCorrectionChangePublished => 'نُشرت';

  @override
  String get gradeCorrectionChangeCorrected => 'صُحّحت';

  @override
  String gradeCorrectionBy(String name) {
    return 'بواسطة $name';
  }

  @override
  String get gradeCorrectionDone => 'صُحّحت الدرجة.';

  @override
  String get attendanceRuleReasonRequired =>
      'هذا الدرس مضى. تعديل أي علامة يتطلب سببًا يُحفظ معها.';

  @override
  String get attendanceRuleLocked =>
      'هذا السجل مقفل وفق سياسة الحضور في مدرستك.';

  @override
  String get attendanceRuleLockedOverride =>
      'هذا السجل مقفل. بصفتك المعلم الرئيسي للصف يمكنك تجاوز القفل مع ذكر السبب.';

  @override
  String get attendanceOverride => 'تجاوز القفل';

  @override
  String get attendanceCorrectionReason => 'سبب التعديل';

  @override
  String get attendanceHistory => 'التعديلات';

  @override
  String get attendanceHistoryEmpty => 'لم تُعدَّل أي علامة في هذا السجل.';

  @override
  String attendanceHistoryLine(String name, String from, String to) {
    return '$name: $from ← $to';
  }

  @override
  String get attendanceHistoryOverride => 'تم تجاوز القفل';

  @override
  String deadlineDue(String when, String zone) {
    return 'موعد التسليم $when ($zone)';
  }

  @override
  String deadlineExtended(String when) {
    return 'لديك وقت إضافي حتى $when';
  }

  @override
  String get deadlineClosed => 'انتهى موعد التسليم.';

  @override
  String get deadlineGraded => 'صُحّح - لم يعد بالإمكان استبداله.';

  @override
  String get deadlineReplaceHint =>
      'يمكنك استبدال عملك حتى موعد التسليم. تُحفظ تسليماتك السابقة.';

  @override
  String get deadlineKeepFiles => 'الاحتفاظ بملفات تسليمك الأخير';

  @override
  String get deadlineExtend => 'منح وقت إضافي';

  @override
  String get deadlineRemoveExtension => 'إزالة الوقت الإضافي';

  @override
  String deadlineExtendedUntil(String when) {
    return 'وقت إضافي حتى $when';
  }

  @override
  String get deadlineReopen => 'إعادة الفتح للصف';

  @override
  String get deadlineUntil => 'حتى';

  @override
  String deadlineSchoolTime(String zone) {
    return 'بتوقيت المدرسة ($zone)';
  }

  @override
  String get deadlineReason => 'السبب';

  @override
  String get deadlineSave => 'حفظ';

  @override
  String get deadlineSaved => 'تم الحفظ.';

  @override
  String get lessonEdit => 'تعديل';

  @override
  String get lessonEditTitle => 'تعديل الدرس';

  @override
  String get lessonEditName => 'العنوان';

  @override
  String get lessonEditBody => 'الملاحظات';

  @override
  String get lessonEditReplaceFile => 'استبدال الملف';

  @override
  String get lessonEditReplaceHint =>
      'يرى الصف الملف الجديد فقط. يُحفظ الملف القديم لدى المدرسة.';

  @override
  String get lessonEditSave => 'حفظ';

  @override
  String get lessonEditSaved => 'حُدّث الدرس.';

  @override
  String get downloadUnavailable =>
      'لم يعد هذا الملف متاحًا. اسحب للأسفل للتحديث.';

  @override
  String get materialsEditTitle => 'تغيير المرفقات';

  @override
  String get materialsEditHint =>
      'تُحفظ الملفات التي تزيلها لدى المدرسة لكنها لا تظهر للصف بعد الآن.';

  @override
  String get materialsEditNone => 'لا توجد ملفات مرفقة بعد.';

  @override
  String get materialsEditRemoving => 'ستُزال';

  @override
  String get materialsEditSaved => 'حُدّثت المرفقات.';

  @override
  String get classesInviteCodeBody =>
      'ينضم الطلاب بكتابة رمز الصف هذا في ستودافاي. اقرأه بصوت عالٍ أو اكتبه على السبورة أو شاركه.';

  @override
  String get classesCopyCode => 'نسخ الرمز';

  @override
  String get classesInviteCodeCopied => 'تم نسخ رمز الصف.';

  @override
  String get classesShareCode => 'مشاركة الرمز';

  @override
  String get teacherCreatePaperGrades => 'درجات ورقية';

  @override
  String get teacherCreatePaperGradesDetail =>
      'درجات امتحان أو اختبار أو واجب ورقي للصف كله';

  @override
  String get profilePhotoChange => 'تغيير صورة الملف الشخصي';

  @override
  String get profilePhotoOnDevice =>
      'تُحفظ صورتك على هذا الهاتف فقط، ولا تُرفع أبدًا، وتُحذف عند تسجيل الخروج.';

  @override
  String get profilePhotoChoose => 'اختيار صورة';

  @override
  String get profilePhotoTake => 'التقاط صورة';

  @override
  String get profilePhotoRemove => 'إزالة الصورة';

  @override
  String get profilePhotoFailed => 'تعذّر استخدام هذه الصورة. جرّب صورة أخرى.';

  @override
  String todayStatClasses(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count صف',
      many: '$count صفًا',
      few: '$count صفوف',
      two: 'صفان',
      one: 'صف واحد',
      zero: 'لا صفوف',
    );
    return '$_temp0';
  }

  @override
  String get todayQuickActions => 'إجراءات سريعة';

  @override
  String get todaySeeAll => 'عرض الكل';

  @override
  String get wellbeingNewTitle => 'ملاحظة رفاه جديدة';

  @override
  String get wellbeingIntro =>
      'سجّل حال الطالب - نقطة قوة تستحق الإشادة، أو ملاحظة، أو مصدر قلق للمتابعة. أنت تختار من يمكنه قراءتها أيضًا.';

  @override
  String get wellbeingWhoAbout => 'عمّن هذه الملاحظة؟';

  @override
  String get wellbeingClass => 'الصف';

  @override
  String get wellbeingPickClass => 'اختر صفًا';

  @override
  String get wellbeingStudent => 'الطالب';

  @override
  String get wellbeingPickStudent => 'اختر طالبًا';

  @override
  String get wellbeingNoStudents => 'لم ينضم أي طالب إلى هذا الصف بعد.';

  @override
  String get wellbeingStudentsFailed =>
      'تعذّر تحميل الطلاب. اضغط للمحاولة مجددًا.';

  @override
  String get wellbeingKind => 'نوع الملاحظة';

  @override
  String get wellbeingKindStrength => 'نقطة قوة';

  @override
  String get wellbeingKindNote => 'ملاحظة';

  @override
  String get wellbeingKindConcern => 'مصدر قلق';

  @override
  String get wellbeingSeverity => 'ما مدى خطورته؟';

  @override
  String get wellbeingSeverityLow => 'منخفض';

  @override
  String get wellbeingSeverityModerate => 'متوسط';

  @override
  String get wellbeingSeverityHigh => 'مرتفع';

  @override
  String get wellbeingDetails => 'التفاصيل';

  @override
  String get wellbeingTitle => 'العنوان';

  @override
  String get wellbeingTitleRequired => 'اكتب عنوانًا قصيرًا للملاحظة.';

  @override
  String get wellbeingContext => 'ما الذي حدث (اختياري)';

  @override
  String get wellbeingFollowUp => 'المتابعة (اختياري)';

  @override
  String get wellbeingWhoSees => 'من يمكنه قراءتها؟';

  @override
  String get wellbeingSeeStaff => 'أنت فقط';

  @override
  String get wellbeingSeeStaffDetail => 'تبقى لك بصفتك معلم هذا الصف.';

  @override
  String get wellbeingSeeGuardians => 'أنت وأولياء الأمور';

  @override
  String get wellbeingSeeGuardiansDetail =>
      'وأيضًا أولياء أمور الطالب المرتبطون.';

  @override
  String get wellbeingSeeStudent => 'أنت وأولياء الأمور والطالب';

  @override
  String get wellbeingSeeStudentDetail => 'وأيضًا أولياء الأمور والطالب نفسه.';

  @override
  String get wellbeingSave => 'حفظ الملاحظة';

  @override
  String get wellbeingSaving => 'جارٍ الحفظ...';

  @override
  String get wellbeingSaved => 'تم حفظ ملاحظة الرفاه.';

  @override
  String get wellbeingSaveFailed => 'تعذّر حفظ الملاحظة. حاول مرة أخرى.';

  @override
  String get wellbeingAdd => 'ملاحظة رفاه جديدة';

  @override
  String get gradebookHomeNoClasses =>
      'أنشئ صفًا من تبويب الصفوف، وستُحفظ درجاته هنا.';

  @override
  String get gradebookHomeNothing => 'لا يوجد ما يُرصد في هذا الصف بعد';

  @override
  String get gradebookHomeNothingDetail =>
      'أضف درجة ورقية لاختبار أُجري على الورق، أو عيّن عملًا مُقيّمًا من تبويب التدريس.';

  @override
  String gradebookHomeCounts(int total, int drafts) {
    String _temp0 = intl.Intl.pluralLogic(
      total,
      locale: localeName,
      other: '$total عمل مقيّم',
      many: '$total عملًا مقيّمًا',
      few: '$total أعمال مقيّمة',
      two: 'عملان مقيّمان',
      one: 'عمل مقيّم واحد',
      zero: 'لا أعمال مقيّمة',
    );
    return '$_temp0 · $drafts مسودات';
  }

  @override
  String get gradebookMarkOnline => 'رصد الأعمال الإلكترونية';

  @override
  String get gradebookViewHandIns => 'عرض التسليمات';

  @override
  String get academicStateWithdrawn => 'مخفي';

  @override
  String get academicEmptyTeacherHint => 'اضغط + لإنشاء محتوى لصفوفك.';

  @override
  String get teacherCreateGroupTeaching => 'التدريس';

  @override
  String get teacherCreateGroupClass => 'سجلات الصف';

  @override
  String get teacherCreateGroupFamilies => 'العائلات';

  @override
  String get teacherCreateWellbeingDetail =>
      'نقطة قوة أو ملاحظة أو مصدر قلق عن طالب واحد';

  @override
  String classesSummary(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count صف',
      many: '$count صفًا',
      few: '$count صفوف',
      two: 'صفان',
      one: 'صف واحد',
      zero: 'لا صفوف بعد',
    );
    return '$_temp0';
  }

  @override
  String get classesEmptyDetail => 'أنشئ صفك الأول، ثم ادعُ الطلاب برمز الصف.';

  @override
  String get attendanceMarkAllPresent => 'تحديد الجميع حاضرين';

  @override
  String get attendanceNotMarked => 'لم يُحدَّد';

  @override
  String get attendanceUnsaved => 'تغييرات غير محفوظة';

  @override
  String attendanceStatusFor(String name, String status) {
    return '$name: $status. تغيير الحضور';
  }

  @override
  String attendanceCounts(int present, int absent, int late, int unmarked) {
    return '$present حاضر · $absent غائب · $late متأخر · $unmarked دون تحديد';
  }

  @override
  String get attachmentCamera => 'الكاميرا';

  @override
  String get attachmentDocument => 'مستند';

  @override
  String get attachmentAdd => 'إرفاق';

  @override
  String get msgOptions => 'خيارات';

  @override
  String get msgAnnouncements => 'الإعلانات';

  @override
  String get msgAnnouncementsEmpty => 'لا توجد إعلانات بعد';

  @override
  String get msgAnnouncementsFailed => 'تعذّر تحميل الإعلانات';

  @override
  String get msgNewAnnouncement => 'إعلان جديد';

  @override
  String get msgImportant => 'مهم';

  @override
  String get msgUnread => 'غير مقروءة';

  @override
  String get msgBlockedIntro =>
      'لا يستطيع من تحظرهم مراسلتك، ولا تستطيع مراسلتهم. ألغِ الحظر للتواصل مجددًا.';

  @override
  String get msgBlockedEmptyDetail =>
      'إن أزعجك أحد، يمكنك حظره أو الإبلاغ عنه من خيارات المحادثة.';

  @override
  String get msgBlockedLabel => 'محظور';

  @override
  String get accountSecurityDetailFull =>
      'الأجهزة، التحقق بخطوتين، تسجيل الخروج من كل مكان، حذف الحساب';

  @override
  String get securityDeleteHeading => 'حذف الحساب';

  @override
  String get securityDeleteFooter =>
      'يؤدي حذف حسابك إلى إزالة بياناتك الشخصية بعد 14 يومًا، ويمكنك الإلغاء قبل ذلك. تبقى السجلات التي يجب على مدرستك الاحتفاظ بها لدى المدرسة.';

  @override
  String get securityDeleteTitle => 'حذف حسابك؟';

  @override
  String get securityDeleteExplain =>
      'سترى بالضبط ما سيُحذف وما تحتفظ به مدرستك، وسيُطلب منك التأكيد مرة أخرى. يتم الحذف بعد 14 يومًا ويمكن إلغاؤه حتى ذلك الحين.';

  @override
  String get securityDeleteContinue => 'متابعة';

  @override
  String get loginDidNotFinish =>
      'لم يكتمل تسجيل الدخول - ربما انقطع الاتصال. حاول مرة أخرى.';

  @override
  String get filesSwitchedOff =>
      'المرفقات والرسائل الصوتية غير مفعّلة لمدرستك بعد.';

  @override
  String get attachmentRetry => 'حاول مرة أخرى';

  @override
  String get attachmentRemove => 'إزالة';

  @override
  String get msgVoiceSending => 'جارٍ إرسال الرسالة الصوتية…';

  @override
  String get studentTodayLessonsShortcut => 'الدروس والدفاتر';

  @override
  String get studentTodayLessonsShortcutDetail => 'كل صفوفك مع ملاحظاتك';

  @override
  String get studentTodayWorkShortcutDetail => 'سلّم أعمالك وتابع المواعيد';

  @override
  String get studentTodayFamilyShortcutDetail => 'معرّف Studafy وطلبات الأهل';

  @override
  String get studentTodayWorkSection => 'أعمال مطلوبة';

  @override
  String get studentLessonsSubtitle => 'صفوفك ودروسها ودفاترك';

  @override
  String get studentClassLessonsDetail => 'كل ما شاركه معلمك، حسب التاريخ';

  @override
  String get studentClassNotebook => 'الدفتر';

  @override
  String get studentClassNotebookDetail =>
      'ملاحظاتك الخاصة لهذا الصف، كل منها بتاريخه';

  @override
  String get studentClassOpenNotebook => 'افتح الدفتر';

  @override
  String planUpgradeTo(Object plan) {
    return 'الترقية إلى ⁦$plan⁩';
  }

  @override
  String planAdds(Object plan) {
    return 'يضيف ⁦$plan⁩:';
  }

  @override
  String get planEverything => 'لديك كل ميزات الدراسة.';

  @override
  String get planSeePlans => 'عرض الخطط';

  @override
  String get workSubtitle => 'الواجبات والاختبارات والدرجات والحضور';

  @override
  String get workSectionOpen => 'مطلوب';

  @override
  String get workSectionClosed => 'انتهى موعدها';

  @override
  String get workSectionGraded => 'مصحّحة';

  @override
  String get workStateOpen => 'مفتوح';

  @override
  String get workStateClosed => 'مغلق';

  @override
  String get workStateGraded => 'مصحّح';

  @override
  String get workView => 'عرض';

  @override
  String get submitInstructions => 'التعليمات';

  @override
  String get submitHandInAgain => 'سلّم مرة أخرى';

  @override
  String get submitSaving => 'جارٍ تسليم عملك…';

  @override
  String get helperSubtitle => 'اسأل عن أي شيء تدرسه';

  @override
  String get helperRecentChats => 'المحادثات الأخيرة';

  @override
  String get helperSeeAll => 'عرض الكل';

  @override
  String get helperOffTitle => 'غير مفعّل بعد';

  @override
  String get accountSectionProfile => 'معلومات الملف الشخصي';

  @override
  String get accountSectionNotifications => 'الإشعارات';

  @override
  String get accountSectionSubscription => 'الاشتراك';

  @override
  String get accountStudyPlan => 'خطة الدراسة';

  @override
  String get accountStudyPlanDetail => 'خطتك وما تتضمنه وخيارات الترقية';

  @override
  String get accountTechnicalId => 'معرّف الحساب التقني';

  @override
  String get accountTechnicalIdDetail =>
      'لا تحتاجه إلا إذا طلبه دعم Studafy. للربط مع أحد الوالدين، شارك معرّف Studafy بدلًا منه.';

  @override
  String get accountChangePhoto => 'تغيير الصورة';

  @override
  String get loginWrongRoleStudentTitle => 'هذا البريد الإلكتروني لحساب طالب';

  @override
  String get loginWrongRoleStudentBody =>
      'حساب الطالب مخصص للتعلّم فقط، لذا لا يمكن استخدامه كمعلم أو ولي أمر. للتدريس أو لمتابعة طفل، سجّل الدخول ببريد إلكتروني آخر.';

  @override
  String get loginWrongRoleAdultTitle => 'هذا البريد الإلكتروني ليس لحساب طالب';

  @override
  String loginWrongRoleAdultBody(String role) {
    return 'إنه مستخدم بالفعل كـ$role، لذا لا يمكن أن يكون لطالب أيضًا. يحتاج الطالب إلى بريد إلكتروني خاص به.';
  }

  @override
  String loginContinueAs(String role) {
    return 'المتابعة كـ$role';
  }

  @override
  String get loginUseDifferentEmail => 'استخدام بريد إلكتروني آخر';

  @override
  String get accountSwitchRoleTeacherParent =>
      'التنقّل بين التدريس ومتابعة أطفالك.';

  @override
  String get accountName => 'الاسم';

  @override
  String get accountEditName => 'تعديل الاسم';

  @override
  String get accountEditNameTitle => 'تعديل اسمك';

  @override
  String get accountNameHelp => 'هكذا يراك معلموك وزملاؤك وعائلتك.';

  @override
  String get accountNameInvalid => 'أدخل اسمًا لا يزيد عن 160 حرفًا.';

  @override
  String get accountNameSaved => 'تم حفظ الاسم';

  @override
  String get accountNameFailed => 'تعذّر حفظ اسمك. يرجى المحاولة مرة أخرى.';

  @override
  String get accountSaveAction => 'حفظ';

  @override
  String get accountCancelAction => 'إلغاء';

  @override
  String get accountPublicIdDetail =>
      'قد يطلب دعم Studafy هذا الرقم. لا يمكن استخدامه لرؤية حسابك أو للارتباط بطفل.';

  @override
  String get navAnnouncements => 'الإعلانات';

  @override
  String get announcementsSubtitle => 'أخبار مدارس أطفالك';

  @override
  String get announcementsAllChildren => 'كل الأطفال';

  @override
  String get announcementsNoChildren => 'اربط طفلًا لرؤية إعلانات مدرسته.';

  @override
  String announcementsFrom(String school, String children) {
    return '$school · أطفالك: $children';
  }

  @override
  String get learningSubtitle =>
      'الدروس والواجبات والاختبارات والدرجات والحضور';

  @override
  String get learningFilterByChild => 'التصفية حسب الطفل';

  @override
  String get learningNoChildrenTitle => 'لا يوجد طفل مرتبط بعد';

  @override
  String get learningNoChildrenBody =>
      'اربط طفلًا من صفحة اليوم لمتابعة دروسه وواجباته ودرجاته هنا.';

  @override
  String get parentTodaySubtitle => 'يوم أطفالك في لمحة';

  @override
  String get parentQuickLink => 'ربط طفل';

  @override
  String get parentQuickLearning => 'التعلّم';

  @override
  String get parentQuickAnnouncements => 'الإعلانات';

  @override
  String get parentQuickMessages => 'مراسلة معلم';

  @override
  String get parentChildrenSection => 'أطفالك';

  @override
  String get parentNoChildrenTitle => 'اربط طفلك الأول';

  @override
  String get parentNoChildrenBody =>
      'اطلب من طفلك معرّف Studafy الخاص به. يوافق على الطلب من جهازه.';

  @override
  String get parentChildOpen => 'فتح';

  @override
  String get parentLinkSearching => 'جارٍ التحقق…';

  @override
  String get familyPlusNoPlan => 'لا توجد خطة ⁦Family+⁩ بعد';

  @override
  String familyPlusCoveredCount(int count) {
    return 'تغطي $count من أطفالك';
  }

  @override
  String familyPlusEnds(String date) {
    return 'فعّالة حتى $date';
  }

  @override
  String get familyPlusWhatYouGet => 'ما تضيفه ⁦Family+⁩';

  @override
  String get familyPlusPlansTitle => 'اختر خطة';

  @override
  String get familyPlusManagePlan => 'الخطة';

  @override
  String get famLinkCheckFailed =>
      'لم يكتمل التحقق الأمني. يرجى المحاولة مرة أخرى.';

  @override
  String get famLinkAlready =>
      'لقد طلبت ربط هذا الطفل من قبل، أو أنه مرتبط بالفعل.';

  @override
  String get famLinkIdHelp =>
      'يجده طفلك في ملفه الشخصي، تحت معرّف Studafy الخاص بك.';

  @override
  String get familyPlusCurrentPlan => 'الخطة الحالية';

  @override
  String get paperGradesOtherMark => 'علامة أخرى';

  @override
  String get paperGradesEnterScore => 'إدخال درجة بدلًا من ذلك';

  @override
  String get courseworkInvalidState => 'لا يمكن تنفيذ ذلك الآن.';

  @override
  String get attendanceNotOnTimetable =>
      'لم يكن هذا الدرس في جدول الصف في ذلك التاريخ، لذا لا يوجد له سجل حضور.';

  @override
  String get attendanceSaveFailed =>
      'تعذّر حفظ الحضور. يرجى المحاولة مرة أخرى.';

  @override
  String loginOtherRoleTitle(String role) {
    return 'هذا البريد مستخدم بالفعل كحساب $role';
  }

  @override
  String loginOtherRoleBody(String own, String chosen) {
    return 'تابع كـ$own، أو استخدم هذا الحساب أيضًا كـ$chosen. يمكنك التبديل بينهما في أي وقت من ملفك الشخصي.';
  }

  @override
  String loginAlsoUseAs(String role) {
    return 'استخدمه أيضًا كـ$role';
  }

  @override
  String get attachmentsTitle => 'المرفقات';

  @override
  String get attachmentsLinks => 'الروابط';

  @override
  String get attachmentsFiles => 'الملفات';

  @override
  String get attachmentsAddLink => 'إضافة رابط';

  @override
  String get attachmentsLinkTitle => 'العنوان الذي يراه القراء';

  @override
  String get attachmentsLinkAddress => 'العنوان (https://…)';

  @override
  String get attachmentsLinkTitleRequired => 'أضف عنوانًا للرابط.';

  @override
  String get attachmentsRemove => 'إزالة';

  @override
  String get attachmentsKeep => 'إبقاء';

  @override
  String get attachmentsRemovedOnSave => 'سيُزال عند الحفظ';

  @override
  String get attachmentsUploading => 'انتظر حتى يكتمل رفع الملفات.';

  @override
  String get attachmentsFailed =>
      'أعد المحاولة أو أزِل الملفات والروابط المُعلَّمة بأنها فشلت أو لم تُقبل.';

  @override
  String attachmentsTooManyLinks(int count) {
    return 'يمكنك إضافة $count روابط كحد أقصى.';
  }

  @override
  String get attachmentsImagePreview => 'اضغط للعرض';

  @override
  String get attachmentsChecking => 'قيد الفحص';

  @override
  String get attachmentsNotAvailable => 'غير متاح';

  @override
  String get questionKindSingle => 'إجابة واحدة';

  @override
  String get questionKindMultiple => 'إجابات متعددة';

  @override
  String get questionKindTrueFalse => 'صح أو خطأ';

  @override
  String get questionKindShort => 'إجابة قصيرة';

  @override
  String get questionKindEssay => 'مقال';

  @override
  String get builderNewTitle => 'تقييم إلكتروني جديد';

  @override
  String get builderEditTitle => 'تعديل التقييم';

  @override
  String get builderTitleLabel => 'العنوان';

  @override
  String get builderClassLabel => 'الصف';

  @override
  String get builderCategoryLabel => 'النوع';

  @override
  String get builderCategoryQuiz => 'اختبار قصير';

  @override
  String get builderCategoryExam => 'امتحان';

  @override
  String get builderCategoryAssessment => 'تقييم';

  @override
  String get builderQuestions => 'الأسئلة';

  @override
  String get builderAddQuestion => 'إضافة سؤال';

  @override
  String builderTotal(String points) {
    return 'المجموع: $points درجة';
  }

  @override
  String builderQuestionNumber(int number) {
    return 'السؤال $number';
  }

  @override
  String get builderPrompt => 'السؤال';

  @override
  String get builderPoints => 'الدرجات';

  @override
  String get builderRequired => 'إلزامي';

  @override
  String builderOption(int number) {
    return 'الخيار $number';
  }

  @override
  String get builderAddOption => 'إضافة خيار';

  @override
  String get builderRemoveOption => 'إزالة الخيار';

  @override
  String get builderMarkCorrectOne => 'حدد الإجابة الصحيحة.';

  @override
  String get builderMarkCorrectAll => 'حدد كل الإجابات الصحيحة.';

  @override
  String get builderTrue => 'صح';

  @override
  String get builderFalse => 'خطأ';

  @override
  String get builderCorrectIs => 'الإجابة الصحيحة هي';

  @override
  String get builderAccepted => 'الإجابات المقبولة، واحدة في كل سطر';

  @override
  String get builderAcceptedHint => 'اتركه فارغًا لتصححه بنفسك.';

  @override
  String get builderModelAnswer => 'الإجابة النموذجية';

  @override
  String get builderGuidance => 'إرشادات التصحيح';

  @override
  String get builderPrivateHint => 'لا يراه أحد غيرك حتى تُنشر الإجابات.';

  @override
  String get builderMoveUp => 'نقل لأعلى';

  @override
  String get builderMoveDown => 'نقل لأسفل';

  @override
  String get builderDuplicate => 'تكرار';

  @override
  String get builderDelete => 'حذف';

  @override
  String get builderSettings => 'الإعدادات';

  @override
  String get builderOpens => 'يفتح';

  @override
  String get builderCloses => 'يُغلق';

  @override
  String get builderNotSet => 'غير محدد';

  @override
  String get builderNow => 'الآن';

  @override
  String get builderAttempts => 'عدد المحاولات المسموحة';

  @override
  String get builderPolicy => 'أي محاولة تُحتسب';

  @override
  String get builderPolicyBest => 'الأفضل';

  @override
  String get builderPolicyLatest => 'الأخيرة';

  @override
  String get builderRelease => 'متى يرى الطلاب الإجابات';

  @override
  String get builderReleaseAfterClose => 'بعد إغلاقه للجميع';

  @override
  String get builderReleaseAfterGrading => 'بعد انتهاء التصحيح ونشر الدرجات';

  @override
  String get builderReleaseManual => 'عندما أنشرها بنفسي';

  @override
  String get builderReleaseNote =>
      'لا تظهر الإجابات أبدًا ما دام بإمكان أي طالب تقديمه.';

  @override
  String get builderMaterial => 'مواد للتقييم كله';

  @override
  String get builderPreview => 'معاينة كطالب';

  @override
  String get builderSaveDraft => 'حفظ كمسودة';

  @override
  String get builderPublish => 'نشر';

  @override
  String get builderSaved => 'تم الحفظ.';

  @override
  String get builderPublished => 'تم النشر للصف.';

  @override
  String get builderSaveFailed => 'تعذر الحفظ. راجع الأسئلة وحاول مرة أخرى.';

  @override
  String builderQuestionAttachmentRefused(int number) {
    return 'السؤال $number: لم يُقبل ملف أو رابط. أزِله، ثم احفظ مرة أخرى.';
  }

  @override
  String get builderLocked =>
      'قدّم أحد الطلاب بالفعل، لذا لم يعد بالإمكان تغيير الأسئلة. أما الإعدادات فيمكن تغييرها.';

  @override
  String get builderNeedTitle => 'أضف عنوانًا.';

  @override
  String get builderNeedClass => 'اختر صفًا.';

  @override
  String get builderNeedQuestion => 'أضف سؤالًا واحدًا على الأقل.';

  @override
  String get builderNeedClose => 'حدد موعد الإغلاق.';

  @override
  String get builderCloseAfterOpen => 'يجب أن يُغلق بعد أن يفتح.';

  @override
  String builderProblemPrompt(int number) {
    return 'السؤال $number: اكتب نص السؤال.';
  }

  @override
  String builderProblemPoints(int number) {
    return 'السؤال $number: حدد له درجات.';
  }

  @override
  String builderProblemOptions(int number) {
    return 'السؤال $number: أضف خيارين مكتملين على الأقل.';
  }

  @override
  String builderProblemCorrect(int number) {
    return 'السؤال $number: حدد الإجابة الصحيحة.';
  }

  @override
  String builderProblemTrueFalse(int number) {
    return 'السؤال $number: اختر صح أو خطأ كإجابة.';
  }

  @override
  String builderProblemFiles(int number) {
    return 'السؤال $number: انتظر حتى تُرفع ملفاته.';
  }

  @override
  String get builderOnlineChoice => 'يُجاب عنه إلكترونيًا';

  @override
  String get builderOnlineChoiceDetail =>
      'يجيب الطلاب في التطبيق، وتُصحَّح أسئلة الاختيار تلقائيًا.';

  @override
  String get builderPaperChoice => 'على الورق';

  @override
  String get builderPaperChoiceDetail =>
      'يؤديه الطلاب في الصف، وتُدخل أنت الدرجات.';

  @override
  String takeOpens(String time) {
    return 'يفتح $time';
  }

  @override
  String takeCloses(String time) {
    return 'يُغلق $time';
  }

  @override
  String get takeClosed => 'مغلق';

  @override
  String get takeNotOpen => 'لم يُفتح بعد';

  @override
  String takeAttemptsLeft(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count محاولة متبقية',
      many: '$count محاولة متبقية',
      few: '$count محاولات متبقية',
      two: 'محاولتان متبقيتان',
      one: 'محاولة واحدة متبقية',
      zero: 'لا توجد محاولات متبقية',
    );
    return '$_temp0';
  }

  @override
  String get takeStart => 'ابدأ';

  @override
  String get takeAgain => 'حاول مرة أخرى';

  @override
  String get takeSubmit => 'إرسال الإجابات';

  @override
  String get takeSubmitTitle => 'إرسال إجاباتك؟';

  @override
  String get takeSubmitBody => 'لا يمكنك تغييرها بعد الإرسال.';

  @override
  String get takeLeaveTitle => 'المغادرة دون إرسال؟';

  @override
  String get takeLeaveBody => 'لن يتم حفظ إجاباتك.';

  @override
  String get takeLeave => 'مغادرة';

  @override
  String get takeStay => 'البقاء';

  @override
  String takeMissing(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'أجب عن الأسئلة الإلزامية الـ$count المتبقية.',
      many: 'أجب عن الأسئلة الإلزامية الـ$count المتبقية.',
      few: 'أجب عن الأسئلة الإلزامية الـ$count المتبقية.',
      two: 'أجب عن السؤالين الإلزاميين المتبقيين.',
      one: 'أجب عن السؤال الإلزامي المتبقي.',
    );
    return '$_temp0';
  }

  @override
  String get takeSubmitted => 'تم الإرسال. سينشر معلمك النتائج.';

  @override
  String get takeSubmitFailed =>
      'لم تُرسل إجاباتك. تحقق من اتصالك وحاول مرة أخرى.';

  @override
  String get takeWindowClosed => 'أُغلق هذا التقييم، لذا لا يمكن إرساله.';

  @override
  String get takeRequired => 'إلزامي';

  @override
  String get takeOptional => 'اختياري';

  @override
  String get takeTypeAnswer => 'إجابتك';

  @override
  String get takeChooseOne => 'اختر واحدة';

  @override
  String get takeChooseAll => 'اختر كل ما ينطبق';

  @override
  String takePoints(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count درجة',
      many: '$count درجة',
      few: '$count درجات',
      two: 'درجتان',
      one: 'درجة واحدة',
    );
    return '$_temp0';
  }

  @override
  String get takeYourAttempts => 'محاولاتك';

  @override
  String takeAttemptLine(int number, String time) {
    return 'المحاولة $number · $time';
  }

  @override
  String get takeNotReleased => 'ستظهر الإجابات هنا بعد أن ينشرها معلمك.';

  @override
  String get takeGrade => 'الدرجة';

  @override
  String get takeGradePending => 'لم تُنشر بعد';

  @override
  String get takeFeedback => 'ملاحظات المعلم';

  @override
  String get takeAnswers => 'الإجابات';

  @override
  String get takeYourAnswer => 'إجابتك';

  @override
  String get takeCorrectAnswer => 'الإجابة الصحيحة';

  @override
  String get takeAcceptedAnswers => 'الإجابات المقبولة';

  @override
  String get takeNoAnswer => 'لا توجد إجابة';

  @override
  String get takeBeingMarked => 'قيد التصحيح';

  @override
  String takeScore(String score, String max) {
    return '$score من $max';
  }

  @override
  String get takeLoadFailed => 'تعذر التحميل.';

  @override
  String get takeRetry => 'حاول مرة أخرى';

  @override
  String get takeReadOnly =>
      'يمكنك رؤية نتائج طفلك هنا. هو وحده من يمكنه أداء التقييم.';

  @override
  String get takeOpenAssessment => 'فتح';

  @override
  String get markSubmissions => 'الإجابات المقدَّمة';

  @override
  String get markNone => 'لم يقدّم أحد بعد.';

  @override
  String get markNeeds => 'بحاجة إلى تصحيح';

  @override
  String markDone(String score, String max) {
    return 'مصحَّح: $score من $max';
  }

  @override
  String get markAuto => 'مصحَّح تلقائيًا';

  @override
  String markScoreLabel(String max) {
    return 'الدرجة (من $max)';
  }

  @override
  String get markAnswerFeedback => 'تعليق على هذه الإجابة';

  @override
  String get markOverallFeedback => 'ملاحظات للطالب';

  @override
  String get markSave => 'حفظ الدرجات';

  @override
  String get markSaved => 'تم حفظ الدرجات.';

  @override
  String get markSaveFailed =>
      'لم تُحفظ الدرجات. تحقق من كل درجة وحاول مرة أخرى.';

  @override
  String markScoreInvalid(String max) {
    return 'أدخل درجة من 0 إلى $max.';
  }

  @override
  String get markPublishGrades => 'نشر الدرجات';

  @override
  String markPublished(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'نُشرت $count درجة.',
      many: 'نُشرت $count درجة.',
      few: 'نُشرت $count درجات.',
      two: 'نُشرت درجتان.',
      one: 'نُشرت درجة واحدة.',
    );
    return '$_temp0';
  }

  @override
  String get markNothingToPublish => 'لا يوجد شيء جاهز للنشر بعد.';

  @override
  String get markReleaseNow => 'نشر الإجابات الآن';

  @override
  String get markReleased => 'تم نشر الإجابات.';

  @override
  String get markReleaseRefused =>
      'لا يمكن نشر الإجابات إلا بعد إغلاقه للجميع.';

  @override
  String get markEditQuestions => 'تعديل الأسئلة والإعدادات';

  @override
  String get markGrantAccess => 'وقت أو محاولات إضافية';

  @override
  String get markGrantStudent => 'الطالب';

  @override
  String get markGrantUntil => 'مفتوح له حتى';

  @override
  String get markGrantExtra => 'محاولات إضافية';

  @override
  String get markGrantGive => 'منح';

  @override
  String get markGranted => 'تم.';

  @override
  String get markGrantFailed => 'تعذر المنح.';

  @override
  String markAnswersCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count إجابة',
      many: '$count إجابة',
      few: '$count إجابات',
      two: 'إجابتان',
      one: 'إجابة واحدة',
    );
    return '$_temp0';
  }

  @override
  String get markOpenSubmissions => 'الإجابات والتصحيح';

  @override
  String get paperShared => 'للصف كله';

  @override
  String get paperSharedHint =>
      'ورقة الأسئلة أو مخطط التصحيح أو ملاحظات عامة. يراها كل طالب بعد نشر درجته.';

  @override
  String paperForStudent(String name) {
    return 'لـ$name';
  }

  @override
  String get paperForStudentHint =>
      'لا يراها إلا هذا الطالب ووالداه، بعد نشر الدرجة.';

  @override
  String get paperAttachments => 'المرفقات';

  @override
  String get paperAttachmentsSaved => 'تم حفظ المرفقات.';

  @override
  String get paperAttachmentsFailed => 'لم تُحفظ المرفقات.';

  @override
  String get paperAttachmentsSaveFirst =>
      'احفظ الدرجات أولًا، ثم عدّل المرفقات.';

  @override
  String get paperSave => 'حفظ';

  @override
  String get gradeYourFiles => 'ملفاتك';

  @override
  String get gradeClassFiles => 'للصف';

  @override
  String get helperTokensUsed =>
      'وصلت إلى حد استخدام الذكاء الاصطناعي. سؤالك ما زال هنا.';

  @override
  String helperTokensUsedUntil(String date) {
    return 'وصلت إلى حد استخدام الذكاء الاصطناعي. يُعاد ضبطه في $date، وسؤالك ما زال هنا.';
  }

  @override
  String get helperStillAnswering => 'ما زال يجري الرد على هذا السؤال.';

  @override
  String helperCouldNotRead(String name, String reason) {
    return 'تعذرت قراءة $name: $reason.';
  }

  @override
  String get helperSources => 'المصادر';

  @override
  String helperCitationPage(int n) {
    return 'ص $n';
  }

  @override
  String helperCitationSlide(int n) {
    return 'الشريحة $n';
  }

  @override
  String helperCitationLesson(String name) {
    return '$name (الدرس)';
  }

  @override
  String helperCitationNote(String name) {
    return '$name (ملاحظتك)';
  }

  @override
  String get helperAskAboutLesson => 'اسأل المساعد الذكي';

  @override
  String get pickerOneFile => 'أو ملف أو رابط واحد';

  @override
  String get tokensWhatAreThey => 'كيف يعمل استخدام الذكاء الاصطناعي؟';

  @override
  String get tokensExplained =>
      'كل سؤال وملخص واختبار ومجموعة بطاقات ودفتر يستهلك جزءًا من استخدام الذكاء الاصطناعي في خطتك. الملفات والمحادثات الأطول والصور تستهلك أكثر. كل ذلك يتشارك رصيدًا واحدًا يظهر كشريط، ويُعاد ضبطه في موعد محدد. عند نفاده يُحفظ عملك ويمكنك المتابعة بعد إعادة الضبط.';

  @override
  String get tokensGuideTitle => 'ما يستهلك قليلًا وما يستهلك أكثر';

  @override
  String get tokensGuideShortQuestion => 'سؤال قصير';

  @override
  String get tokensGuideLessonQuestion => 'سؤال عن ملفات درس';

  @override
  String get tokensGuideNotes => 'ملخص أو اختبار أو بطاقات من درس';

  @override
  String get tokensGuidePhoto => 'صورة سبورة أو واجب';

  @override
  String get tokensGuideEstimate => 'يظهر استخدامك كشريط - لا حاجة إلى العدّ.';

  @override
  String get readingTitle => 'القراءة للمساعد الذكي';

  @override
  String get readingExplained =>
      'تُقرأ الملفات والروابط مرة واحدة ليجيب المساعد الذكي منها. تُقرأ الصفحات الممسوحة والصور أيضًا ضمن الحد الشهري للقراءة في المدرسة.';

  @override
  String get readingReady => 'جاهز للمساعد الذكي';

  @override
  String get readingPartly => 'قُرئ جزئيًا - لم تُقرأ بعض الصفحات';

  @override
  String get readingStateProcessing => 'جارٍ القراءة…';

  @override
  String readingStateCannot(String reason) {
    return 'تتعذر القراءة: $reason';
  }

  @override
  String get readingRetry => 'اقرأ مجددًا';

  @override
  String get readingRetried => 'ستُقرأ مجددًا بعد قليل.';

  @override
  String get readingRetryFailed => 'تعذر ذلك. حاول مجددًا.';

  @override
  String get readingLoadFailed => 'تعذر التحقق من الملفات.';

  @override
  String get readingNothing => 'لا توجد ملفات أو روابط في هذا الدرس.';

  @override
  String get readingProcessing => 'ما زال قيد القراءة';

  @override
  String get readingScannedSkipped => 'لم تُقرأ صفحاته الممسوحة';

  @override
  String get readingNoText => 'لا يحتوي على نص مقروء';

  @override
  String get readingUnsupportedType => 'لا يمكن قراءة هذا النوع من الملفات';

  @override
  String get readingLinkSignIn => 'يحتاج الرابط إلى تسجيل دخول';

  @override
  String get readingLinkVideo => 'إنه فيديو';

  @override
  String get readingLinkGone => 'الرابط لم يعد يعمل';

  @override
  String get readingLinkUnreachable => 'تعذر فتح الرابط';

  @override
  String get readingFailed => 'تعذرت قراءته';

  @override
  String studyPlansTokensRenewWeekly(String date) {
    return 'يُعاد ضبطه كل اثنين · التالي في $date';
  }

  @override
  String get studyPlansTokensLow => 'استخدام الذكاء الاصطناعي يقترب من الحد.';

  @override
  String get studyPlansFeatureAskLessons =>
      'اسأل المساعد الذكي عن دروسك وملفاتها';

  @override
  String get studyPlansFeatureFreeTokens =>
      'استخدام خفيف للذكاء الاصطناعي - بضعة أسئلة عن دروسك كل أسبوع';

  @override
  String get studyPlansFeaturePlusTokens =>
      'استخدام منتظم للذكاء الاصطناعي - أسئلة وملاحظات ودفاتر في معظم الأيام';

  @override
  String get studyPlansFeatureMaxTokens =>
      'استخدام مكثف للذكاء الاصطناعي - ضعف Plus، لاختبارات وبطاقات ودفاتر يومية';

  @override
  String get upgradeTokensTitle => 'وصلت إلى حد استخدام الذكاء الاصطناعي';

  @override
  String upgradeTokensBody(String date) {
    return 'يُعاد ضبطه في $date. عملك محفوظ. تمنحك خطة أكبر المزيد.';
  }

  @override
  String get studySetMaterialProcessing =>
      'ما زالت ملفات الدرس قيد القراءة. حاول بعد دقيقة كي لا يفوتك شيء.';

  @override
  String get nbCreate => 'إنشاء دفتر';

  @override
  String get nbCreating => 'جارٍ الإنشاء…';

  @override
  String get nbOpen => 'فتح الدفتر';

  @override
  String get nbUpdateAvailable => 'يتوفر تحديث';

  @override
  String get nbFailedShort => 'تعذّر إنشاؤه';

  @override
  String get nbRetry => 'حاول مرة أخرى';

  @override
  String get nbUpdate => 'تحديث الدفتر';

  @override
  String get nbNewVersion => 'إنشاء نسخة أخرى';

  @override
  String get nbMore => 'المزيد';

  @override
  String get nbStarted => 'يُكتب دفترك الآن. يستغرق ذلك دقيقة تقريبًا.';

  @override
  String get nbShelfTitle => 'دفاتر المذاكرة';

  @override
  String get nbShelfEmpty =>
      'اصنع دفترًا منظّمًا من أي درس: اضغط «إنشاء دفتر» أسفله في الدروس.';

  @override
  String get nbShelfLocked =>
      'دفاتر المذاكرة المصنوعة من دروسك متاحة مع ⁦Studafy Plus⁩.';

  @override
  String get nbShelfFailed => 'تعذّر تحميل دفاترك. حاول مرة أخرى';

  @override
  String get nbSheetTitle => 'دفتر مذاكرة جديد';

  @override
  String get nbSheetClass => 'الصف';

  @override
  String get nbSheetLesson => 'الدرس';

  @override
  String get nbSheetName => 'اسم الدفتر';

  @override
  String get nbSheetSources => 'مصنوع من';

  @override
  String get nbSheetWhole => 'الدرس كاملًا';

  @override
  String get nbSheetWholeDetail => 'نصّه وكل ملف ورابط يمكن قراءته';

  @override
  String get nbSheetNoFiles =>
      'لا يحتوي هذا الدرس على ملفات أو روابط؛ يُصنع الدفتر من نصّه.';

  @override
  String get nbSheetChoose => 'الملفات والروابط التي أختارها فقط';

  @override
  String get nbSheetPickOne => 'اختر ملفًا أو رابطًا واحدًا على الأقل.';

  @override
  String get nbSheetWaitReading =>
      'لا تزال بعض ملفات الدرس قيد القراءة. انتظر دقيقة، أو اختر الجاهز منها فقط.';

  @override
  String get nbSheetTokens =>
      'كتابة الدفتر تستهلك جزءًا من استخدام الذكاء الاصطناعي في خطتك. فتحه مرة أخرى مجاني.';

  @override
  String get nbSourceReading => 'لا يزال قيد القراءة';

  @override
  String get nbSourceUnreadable => 'لا يمكن قراءته';

  @override
  String get nbUpdateConfirmTitle => 'تحديث هذا الدفتر؟';

  @override
  String get nbUpdateConfirmBody =>
      'يُعاد كتابة الجزء المصنوع بالذكاء الاصطناعي من الدرس بحالته الحالية. تبقى ملاحظاتك وتظليلاتك وإشاراتك وأقسامك كما هي.';

  @override
  String get nbUpdateBanner => 'تغيّر الدرس منذ كتابة هذا الدفتر.';

  @override
  String get nbDeleteTitle => 'حذف الدفتر';

  @override
  String get nbDeleteBody =>
      'سيُحذف الدفتر وملاحظاتك فيه. لا يمكن التراجع عن ذلك.';

  @override
  String get nbWriting => 'جارٍ كتابة دفترك…';

  @override
  String get nbWritingDetail =>
      'يستغرق ذلك دقيقة تقريبًا. يمكنك مغادرة هذه الصفحة وسيستمر العمل.';

  @override
  String get nbFailedTitle => 'تعذّرت كتابة الدفتر';

  @override
  String get nbFailNoMaterial =>
      'لا يحتوي الدرس على شيء يمكن قراءته لصنع دفتر منه.';

  @override
  String get nbFailTokens =>
      'وصلت إلى حد استخدام الذكاء الاصطناعي. يُعاد ضبطه مع خطتك، وملاحظاتك محفوظة.';

  @override
  String get nbFailPlan => 'دفاتر المذاكرة متاحة مع ⁦Studafy Plus⁩.';

  @override
  String get nbFailGeneric => 'حدث خطأ أثناء كتابته. لم يُخصم شيء.';

  @override
  String get nbLoadFailed => 'تعذّر فتح الدفتر.';

  @override
  String get nbCoverPage => 'الغلاف';

  @override
  String nbCoverFrom(String lesson) {
    return 'من: $lesson';
  }

  @override
  String nbCoverWritten(String date) {
    return 'كُتب في $date';
  }

  @override
  String get nbOpenContents => 'المحتويات';

  @override
  String get nbContents => 'المحتويات';

  @override
  String nbPageOf(String page, String count) {
    return 'صفحة $page من $count';
  }

  @override
  String get nbOverview => 'نظرة عامة';

  @override
  String get nbObjectives => 'أهداف التعلّم';

  @override
  String get nbKeyTerms => 'المصطلحات الأساسية';

  @override
  String get nbExamples => 'أمثلة محلولة';

  @override
  String get nbFacts => 'حقائق وقواعد وصيغ';

  @override
  String get nbMistakes => 'أخطاء شائعة';

  @override
  String get nbSummary => 'ملخص المراجعة';

  @override
  String get nbPractice => 'تدرّب';

  @override
  String get nbExtra => 'شرح إضافي - ليس من ملفات الدرس';

  @override
  String get nbExtraShort => 'شرح إضافي';

  @override
  String nbCitePage(String name, String page) {
    return '$name، صفحة $page';
  }

  @override
  String nbCiteSlide(String name, String slide) {
    return '$name، شريحة $slide';
  }

  @override
  String get nbUnreadableTitle =>
      'غير موجود في هذا الدفتر - تعذّرت قراءة ما يلي:';

  @override
  String get nbReadAgain => 'حدّث للمحاولة مجددًا';

  @override
  String get nbAddNote => 'إضافة ملاحظة';

  @override
  String get nbEditNote => 'تعديل الملاحظة';

  @override
  String get nbNoteHint => 'بكلماتك (اتركه فارغًا للحذف)';

  @override
  String get nbMyNote => 'ملاحظتي';

  @override
  String get nbHighlight => 'تظليل';

  @override
  String get nbRemoveHighlight => 'إزالة التظليل';

  @override
  String get nbColorYellow => 'أصفر';

  @override
  String get nbColorGreen => 'أخضر';

  @override
  String get nbColorBlue => 'أزرق';

  @override
  String get nbColorPink => 'وردي';

  @override
  String get nbBookmark => 'وضع إشارة على هذه الصفحة';

  @override
  String get nbRemoveBookmark => 'إزالة الإشارة';

  @override
  String get nbBookmarked => 'عليها إشارة';

  @override
  String get nbAddSection => 'إضافة قسم خاص بي';

  @override
  String get nbArrange => 'ترتيب أقسامي';

  @override
  String get nbSectionTitle => 'عنوان القسم';

  @override
  String get nbSectionBody => 'اكتب ما تشاء';

  @override
  String get nbSectionEmpty => 'لا شيء هنا بعد. اضغط «كتابة» للبدء.';

  @override
  String get nbEditSection => 'كتابة';

  @override
  String get nbDeleteSection => 'حذف القسم';

  @override
  String get nbMySection => 'قسمي';

  @override
  String get nbRenameHeading => 'إعادة تسمية العنوان';

  @override
  String get nbResetHeading => 'استخدام الأصلي';

  @override
  String get nbSettings => 'الغلاف والصفحات';

  @override
  String get nbSettingsTitle => 'الاسم';

  @override
  String get nbSettingsSubtitle => 'عنوان فرعي';

  @override
  String get nbColor => 'اللون';

  @override
  String get nbIcon => 'الأيقونة';

  @override
  String get nbPageStyle => 'الصفحات';

  @override
  String get nbLined => 'مسطّرة';

  @override
  String get nbPlain => 'سادة';

  @override
  String get nbGrid => 'مربعات';

  @override
  String get nbSaving => 'جارٍ الحفظ…';

  @override
  String get nbSaved => 'تم الحفظ';

  @override
  String get nbSaveFailed => 'لم يُحفظ - اضغط للمحاولة مجددًا';

  @override
  String get nbPracticeIntro =>
      'اختبر نفسك في هذا الدفتر - كله، أو الأقسام التي تختارها.';

  @override
  String get nbPracticeLocked => 'الاختبارات والبطاقات متاحة مع ⁦Studafy Max⁩';

  @override
  String get nbQuizWhole => 'اختبار في الدفتر كله';

  @override
  String get nbCardsWhole => 'بطاقات للدفتر كله';

  @override
  String get nbChooseSections => 'اختيار أقسام';

  @override
  String get nbChooseSectionsTitle => 'تدرّب على هذه الأقسام';

  @override
  String get nbMakeQuiz => 'اختبار';

  @override
  String get nbMakeCards => 'بطاقات';

  @override
  String get nbMadeSets => 'مصنوع من هذا الدفتر';

  @override
  String get nbSetWhole => 'الدفتر كله';

  @override
  String get nbSetOutdated => 'من نسخة أقدم - يفتح نسخة جديدة';

  @override
  String get setMakingQuiz => 'جارٍ إعداد اختبارك…';

  @override
  String get setMakingCards => 'جارٍ إعداد بطاقاتك…';

  @override
  String get setMakingDetail =>
      'يستغرق ذلك بضع ثوانٍ. بعد إعداده يُفتح فورًا في المرة القادمة.';

  @override
  String get setEmpty => 'لم يكن في الدرس ما يكفي لإعداد ذلك.';

  @override
  String get setFailed => 'لم ينجح ذلك';

  @override
  String get setFailedDetail => 'لم يُخصم شيء. حاول مرة أخرى بعد قليل.';

  @override
  String get setSeePlans => 'عرض الخطط';

  @override
  String quizQuestionOf(String number, String count) {
    return 'السؤال $number من $count';
  }

  @override
  String get quizSubmit => 'تحقّق من إجاباتي';

  @override
  String get quizAnswerAll => 'أجب عن كل الأسئلة، ثم تحقّق.';

  @override
  String quizScoreLine(String score, String count) {
    return 'أجبت $score من $count إجابة صحيحة';
  }

  @override
  String get quizCorrect => 'صحيح';

  @override
  String get quizWrong => 'ليس تمامًا';

  @override
  String cardsProgress(String number, String count) {
    return 'البطاقة $number من $count';
  }

  @override
  String get cardsTapToFlip => 'اضغط على البطاقة لقلبها';

  @override
  String get cardsDidYouKnow => 'هل كنت تعرفها؟';

  @override
  String get cardsKnew => 'عرفتها';

  @override
  String get cardsLearning => 'ما زلت أتعلمها';

  @override
  String get cardsDone => 'انتهيت!';

  @override
  String cardsKnewCount(String known, String count) {
    return 'عرفت $known من $count';
  }

  @override
  String get cardsLearningOnly => 'تدرّب على ما زلت أتعلمه';

  @override
  String get cardsAgain => 'راجعها كلها مرة أخرى';

  @override
  String get cardsPrevious => 'السابق';

  @override
  String get cardsNext => 'التالي';

  @override
  String get cardsQuestion => 'السؤال';

  @override
  String get cardsAnswer => 'الإجابة';

  @override
  String get pickTitle => 'اختر المواد';

  @override
  String get pickSearch => 'ابحث في الدروس والملفات';

  @override
  String get pickAllClasses => 'كل الصفوف';

  @override
  String get pickSelectClass => 'اختيار الصف كاملًا';

  @override
  String pickSelectClassTitle(String name) {
    return 'اختيار كل $name؟';
  }

  @override
  String pickSelectClassBody(int lessons, int files) {
    return 'يختار ذلك كل الدروس ($lessons) وملفاتها وروابطها القابلة للقراءة ($files). يمكنك المراجعة وإزالة أي شيء قبل المتابعة.';
  }

  @override
  String get pickSelectClassConfirm => 'اختيار الكل';

  @override
  String pickTooManyLessons(int max) {
    return 'يمكن استخدام $max دروس كحد أقصى في المرة الواحدة.';
  }

  @override
  String get pickSingleLesson =>
      'يُصنع الدفتر من درس واحد: اختر نصّه والملفات التي ستُستخدم.';

  @override
  String get pickLessonText => 'نص الدرس';

  @override
  String get pickWholeLesson => 'الدرس كاملًا';

  @override
  String get pickWholeLessonDetail => 'الدرس كاملًا بكل المرفقات';

  @override
  String get pickPartOfLesson => 'جزء من الدرس';

  @override
  String get pickAllAttachments => 'كل المرفقات';

  @override
  String pickAttachments(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count مرفق',
      many: '$count مرفقًا',
      few: '$count مرفقات',
      two: 'مرفقان',
      one: 'مرفق واحد',
      zero: 'بلا مرفقات',
    );
    return '$_temp0';
  }

  @override
  String pickLessons(int count) {
    return '$count دروس';
  }

  @override
  String pickClasses(int count) {
    return '$count صفوف';
  }

  @override
  String pickLessonNamed(String title) {
    return 'الدرس: $title';
  }

  @override
  String get pickTextOnly => 'نص الدرس فقط';

  @override
  String pickNotes(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count ملاحظة',
      many: '$count ملاحظة',
      few: '$count ملاحظات',
      two: 'ملاحظتان',
      one: 'ملاحظة واحدة',
    );
    return '$_temp0';
  }

  @override
  String get pickNothing => 'لم يُختر شيء بعد';

  @override
  String get pickReview => 'مراجعة';

  @override
  String get pickReviewTitle => 'ما سيُستخدم';

  @override
  String get pickRemove => 'إزالة';

  @override
  String get pickSelected => 'مختار';

  @override
  String get pickShowFiles => 'عرض نصّه وملفاته';

  @override
  String get pickStillReading => 'لا يزال قيد القراءة';

  @override
  String pickWaitingNotIncluded(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count ملفات لا تزال قيد القراءة ولم تُضمَّن بعد.',
      one: 'ملف واحد لا يزال قيد القراءة ولم يُضمَّن بعد.',
    );
    return '$_temp0';
  }

  @override
  String get pickNoMatch => 'لا شيء يطابق بحثك.';

  @override
  String get pickLoadFailed => 'تعذّر تحميل دروسك.';

  @override
  String get pickActionSummary => 'لخّص المواد المختارة';

  @override
  String get pickActionQuiz => 'أنشئ اختبارًا من المختار';

  @override
  String get pickActionFlashcards => 'أنشئ بطاقات من المختار';

  @override
  String get pickActionNotebook => 'أنشئ دفترًا من المختار';

  @override
  String get pickActionHelper => 'استخدم المختار في المساعد الذكي';

  @override
  String madeFrom(String sources) {
    return 'مصنوع من: $sources';
  }

  @override
  String get unavailableTitle => 'تعذّر استخدام بعض الملفات المختارة الآن';

  @override
  String get unavailableBody =>
      'لم يُصنع شيء بعد. حاول لاحقًا، أو تابع بدون ما يلي:';

  @override
  String get unavailableFile => 'ملف مختار';

  @override
  String get unavailableLater => 'حاول لاحقًا';

  @override
  String get unavailableContinue => 'تابع بدونها';

  @override
  String get helperNoMaterial => 'لا يستخدم مواد الصف';

  @override
  String get helperChooseMaterial => 'اختيار';

  @override
  String get helperChangeMaterial => 'تغيير';

  @override
  String helperMaterialChangedMark(String label) {
    return 'من هنا: $label';
  }

  @override
  String get helperMaterialRemovedMark => 'من هنا: بدون مواد الصف';

  @override
  String get notebookMakingNotes => 'جارٍ إعداد ملاحظاتك…';

  @override
  String get usageSectionTitle => 'استخدام الذكاء الاصطناعي';

  @override
  String usagePlan(String plan) {
    return 'خطة ⁦$plan⁩';
  }

  @override
  String get usagePlenty => 'متاح بوفرة';

  @override
  String get usageLow => 'يقترب من الحد';

  @override
  String get usageReached => 'تم بلوغ الحد';

  @override
  String get usageReachedDetail =>
      'محادثاتك وملاحظاتك ودفاترك محفوظة. يمكنك المتابعة بعد إعادة الضبط، أو الترقية الآن.';

  @override
  String usageLine(String level, String date) {
    return '$level · يُعاد ضبطه في $date';
  }

  @override
  String usageBarLabel(String level) {
    return 'استخدام الذكاء الاصطناعي: $level';
  }

  @override
  String usageResets(String date) {
    return 'يُعاد ضبطه في $date';
  }

  @override
  String usageResetsWeekly(String date) {
    return 'يُعاد ضبطه كل اثنين · التالي في $date';
  }

  @override
  String get usageUpgrade => 'الترقية ومقارنة الخطط';

  @override
  String get usageComparePlans => 'مقارنة الخطط';

  @override
  String get usageLoadFailed => 'تعذّر تحميل استخدامك. حاول مرة أخرى';

  @override
  String get usageCostLight => 'يستهلك قليلًا';

  @override
  String get usageCostMedium => 'يستهلك قدرًا متوسطًا';

  @override
  String get usageCostMore => 'يستهلك أكثر';

  @override
  String get markPublishTitle => 'نشر الدرجات؟';

  @override
  String get markPublishFailed =>
      'لم تُنشر الدرجات. تحقّق من اتصالك وحاول مرة أخرى.';

  @override
  String markSummary(int toMark, int marked, int published) {
    return '$toMark للتصحيح · $marked جاهزة للنشر · $published منشورة';
  }

  @override
  String get markRefreshFailed =>
      'تعذّر تحديث القائمة. اسحب للأسفل للمحاولة مرة أخرى.';

  @override
  String get markStatusNotMarked => 'مُسلَّم · لم يُصحَّح';

  @override
  String get markStatusPartly => 'مُسلَّم · صُحِّح جزئيًا';

  @override
  String get markStatusMarked => 'مُصحَّح · غير منشور';

  @override
  String get markStatusPublished => 'منشور';

  @override
  String get markScoreNeededForComment =>
      'ضع درجة مع كل تعليق، أو احذف التعليق.';

  @override
  String get markNothingChanged => 'لم يتغيّر شيء منذ آخر حفظ.';

  @override
  String get markCorrected =>
      'حُفظ التصحيح. يرى الطالب وأولياء أمره الدرجة الجديدة.';

  @override
  String get markDraftSaved =>
      'حُفظت كمسودة. لا يراها الطلاب وأولياء الأمور حتى تنشر الدرجات.';

  @override
  String get markUnsavedTitle => 'المغادرة دون حفظ؟';

  @override
  String get markUnsavedBody => 'ستضيع الدرجات والتعليقات التي لم تحفظها.';

  @override
  String get markUnsavedKeep => 'متابعة التصحيح';

  @override
  String get markUnsavedDiscard => 'تجاهل التغييرات';

  @override
  String get unsavedDiscardTitle => 'تجاهل التغييرات؟';

  @override
  String get unsavedDiscardBody => 'لم يُحفظ ما كتبته أو أضفته هنا، وسيضيع.';

  @override
  String get unsavedKeepEditing => 'متابعة التعديل';

  @override
  String get unsavedDiscard => 'تجاهل';

  @override
  String get markStillToMark => 'قيد التصحيح';

  @override
  String get markPublishedNotice =>
      'منشور: يرى الطالب وأولياء أمره هذه الدرجة. يُحفظ أي تغيير كتصحيح مع ذكر السبب.';

  @override
  String get markDraftNotice =>
      'لم تُنشر بعد: لا يرى هذه الدرجات إلا معلمو الصف.';

  @override
  String markAutoScore(String score, String max) {
    return 'صُحِّح تلقائيًا: $score من $max';
  }

  @override
  String get markOverallFeedbackHelp => 'تظهر مع الدرجة بعد نشرها.';

  @override
  String get markSaveCorrection => 'حفظ التصحيح';

  @override
  String get markSaveDraft => 'حفظ كمسودة';

  @override
  String get markCorrectionTitle => 'تصحيح درجة منشورة';

  @override
  String get markCorrectionBody =>
      'يرى الطالب وأولياء أمره هذه الدرجة بالفعل. اذكر سبب تغييرها؛ يُحفظ السبب مع التغيير.';

  @override
  String get markCorrectionReason => 'سبب التغيير';

  @override
  String markOutOf(String max) {
    return 'من $max';
  }

  @override
  String get markStudentAnswer => 'إجابة الطالب';

  @override
  String get gradebookOnlineHint =>
      'يُجاب عن هذا العمل في التطبيق. صحّحه من إجابات كل طالب.';

  @override
  String get gradebookOpenAnswers => 'فتح الإجابات المقدَّمة';

  @override
  String get todayWorkDraft => 'مسودة · لم يُسنَد بعد';

  @override
  String todayWorkExamOn(String date) {
    return 'الاختبار في $date';
  }

  @override
  String todayWorkOpens(String date) {
    return 'يُفتح في $date';
  }

  @override
  String get todayWorkScheduled => 'مجدول';

  @override
  String todayWorkDue(String date) {
    return 'موعد التسليم $date';
  }

  @override
  String todayWorkCloses(String date) {
    return 'يُغلق في $date';
  }

  @override
  String get todayWorkOpen => 'مفتوح';

  @override
  String get todayWorkKindAssignment => 'واجب';

  @override
  String get todayWorkKindOnlineExam => 'اختبار إلكتروني';

  @override
  String get todayWorkKindPaperExam => 'اختبار ورقي';

  @override
  String get todayWorkFinish => 'نشر';

  @override
  String get todayWorkUnknown =>
      'تعذّر تحميل بعض الصفوف، لذا قد تنقص هنا بعض الأعمال.';

  @override
  String get todayPartlyLoaded => 'تعذّر تحميل بعض الصفوف.';

  @override
  String get todaySectionsUnknown =>
      'تعذّر تحميل بعض الصفوف، لذا قد تنقص هنا بعض الحصص.';

  @override
  String get todaySectionDraft => 'الدرس مسودة · لا يراه الطلاب';

  @override
  String get todaySectionPublish => 'نشر';

  @override
  String get todaySectionAdd => 'إضافة درس';

  @override
  String todayMore(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'و$count عناصر أخرى',
      one: 'وعنصر آخر',
    );
    return '$_temp0';
  }

  @override
  String lessonForSection(String when) {
    return 'لحصة $when';
  }

  @override
  String get markFixHighlighted => 'صحّح الدرجات المحدَّدة، ثم احفظ مرة أخرى.';

  @override
  String get sectionsPublished => 'الدرس منشور';

  @override
  String get scheduleLoadFailed => 'تعذّر تحميل الجدول. حاول مرة أخرى.';

  @override
  String get markSavedPublished =>
      'حُفظ. لم يتطلّب أي تغيير في الدرجة المنشورة تصحيحًا.';

  @override
  String get markCorrectionCancelled =>
      'لم يُحفظ. يتطلّب تغيير درجة منشورة ذكر السبب؛ ما زالت درجاتك هنا.';

  @override
  String get markPublishedAbsentNotice =>
      'نُشر غيابه، لكن هذا الطالب سلّم عمله لاحقًا. احفظ لاستبدال الغياب بهذه الدرجة؛ سيُطلب منك ذكر السبب.';

  @override
  String get markReplaceAbsence => 'استبدال الغياب';

  @override
  String get markSaveChanges => 'حفظ التغييرات';

  @override
  String get markAbsenceCorrected =>
      'حُفظ التصحيح. يرى الطالب وأولياء أمره التغيير.';

  @override
  String get markAbsenceRemoved => 'أُزيل الغياب.';

  @override
  String get markAbsenceSaved => 'سُجّل غائبًا. لن يراه أحد حتى تنشر الدرجات.';

  @override
  String get markAbsenceRefused =>
      'سلّم هذا الطالب عمله، لذا لا يمكن تسجيله غائبًا.';

  @override
  String get markAbsenceFailed =>
      'لم يُحفظ ذلك. تحقّق من اتصالك وحاول مرة أخرى.';

  @override
  String get markNotSubmittedSection => 'لم يسلّموا';

  @override
  String get markNotSubmittedHint =>
      'اضغط على طالب لتسجيل غيابه. لا يُحتسب الغياب صفرًا أبدًا.';

  @override
  String markRosterSummary(int notSubmitted, int absent) {
    return '$notSubmitted لم يسلّموا · $absent غائبون';
  }

  @override
  String get markStatusNotSubmitted => 'لم يسلّم';

  @override
  String get markStatusAbsent => 'غائب';

  @override
  String get markStatusAbsentPublished => 'غائب · منشور';

  @override
  String get markStatusNotGradedPublished => 'بلا درجة · منشور';

  @override
  String get markAbsenceBody =>
      'سجّل أن هذا الطالب كان غائبًا. يبقى خاصًا حتى تنشر الدرجات، ولا يُحتسب صفرًا.';

  @override
  String get markAbsencePublishedBody =>
      'هذا الغياب منشور. تغييره تصحيح: اذكر السبب، ويُحفظ مع التغيير.';

  @override
  String get markAbsenceExcused => 'بلا درجة (معذور)';

  @override
  String get markAbsenceNotes => 'ملاحظات (اختياري)';

  @override
  String get markAbsenceRemove => 'إزالة الغياب';

  @override
  String get markAbsenceSaveNotes => 'حفظ الملاحظات';

  @override
  String get markAbsenceMark => 'تسجيل غائب';

  @override
  String get takeChildAttempts => 'المحاولات';

  @override
  String get loginWithEmail => 'تسجيل الدخول بالبريد الإلكتروني';

  @override
  String get loginEmailNote => 'للحسابات التي أعدّتها Studafy.';

  @override
  String get loginEmailLabel => 'البريد الإلكتروني';

  @override
  String get loginPasswordLabel => 'كلمة المرور';

  @override
  String get loginShowPassword => 'إظهار كلمة المرور';

  @override
  String get loginHidePassword => 'إخفاء كلمة المرور';

  @override
  String get loginEmailSubmit => 'تسجيل الدخول';

  @override
  String get loginEmailMissing => 'أدخل عنوان بريدك الإلكتروني.';

  @override
  String get loginEmailInvalid => 'أدخل عنوان بريد إلكتروني صحيحًا.';

  @override
  String get loginPasswordMissing => 'أدخل كلمة المرور.';

  @override
  String get loginEmailWrong =>
      'البريد الإلكتروني وكلمة المرور لا يطابقان حسابًا أعدّته Studafy.';

  @override
  String get loginEmailTooMany =>
      'محاولات كثيرة جدًا. انتظر بضع دقائق ثم حاول مرة أخرى.';

  @override
  String get loginEmailOffline =>
      'تعذّر الوصول إلى Studafy. تحقّق من اتصالك وحاول مرة أخرى.';

  @override
  String get loginEmailUnavailable =>
      'تسجيل الدخول بالبريد الإلكتروني غير متاح الآن. حاول مرة أخرى لاحقًا.';

  @override
  String get reauthPasswordTitle => 'تأكيد هويتك';

  @override
  String reauthPasswordBody(String email) {
    return 'أدخل كلمة المرور للحساب $email.';
  }

  @override
  String get reauthPasswordConfirm => 'تأكيد';

  @override
  String get reauthPasswordCancel => 'إلغاء';

  @override
  String get aiConsentTitle => 'أدوات الدراسة بالذكاء الاصطناعي';

  @override
  String get aiConsentNoticeBody =>
      'يستخدم مساعد الدراسة وملاحظات الدروس ودفاتر الدراسة والاختبارات والبطاقات التعليمية ذكاءً اصطناعيًا من Together AI، وهي شركة خارج ستودافاي. هذه الأدوات اختيارية.\n\nما الذي يُرسل\nما تكتبه، وآخر الرسائل في المحادثة نفسها، وإذا اخترت ذلك نص درس أو ملاحظاتك الخاصة أو صورة تضيفها.\n\nما الذي لا يُرسل\nبريدك الإلكتروني ومدرستك ودرجاتك وبيانات حسابك. تُستبدل الأسماء التي يعرفها ستودافاي - اسمك وأسماء زملائك ومعلميك ووالديك - بكلمات مثل [student] قبل إرسال أي شيء. تُرسل الصورة كما هي، فلا تصوّر الأسماء أو الوجوه.\n\nمن المفيد أن تعرف\nقد تكون الإجابات خاطئة: تحقّق منها، ولا تسلّمها على أنها عملك أبدًا. تبقى المحادثات على جهازك. الذكاء الاصطناعي لا يصحّح أعمالك أبدًا.\n\nيمكنك إيقاف أدوات الذكاء الاصطناعي في أي وقت من حسابك.';

  @override
  String get aiConsentAgree => 'أوافق';

  @override
  String get aiConsentNotNow => 'ليس الآن';

  @override
  String aiConsentForChild(String name) {
    return 'أنت توافق نيابةً عن $name، صاحب الحساب الذي تديره.';
  }

  @override
  String get aiConsentGuardianNeeded =>
      'يشغّل ولي الأمر أدوات الدراسة بالذكاء الاصطناعي لهذا الحساب من حسابه الخاص.';

  @override
  String get aiConsentStudentsOnly =>
      'أدوات الدراسة بالذكاء الاصطناعي مخصّصة للطلاب المسجّلين في صف.';

  @override
  String get aiConsentSwitchOn => 'مفعّلة. يمكنك إيقافها في أي وقت.';

  @override
  String get aiConsentSwitchOff =>
      'متوقفة. فعّلها لاستخدام مساعد الدراسة والملاحظات والدفاتر والاختبارات والبطاقات التعليمية.';

  @override
  String aiConsentChildSwitch(String name) {
    return 'أدوات الدراسة بالذكاء الاصطناعي لـ $name';
  }

  @override
  String get aiConsentWithdrawTitle => 'إيقاف أدوات الدراسة بالذكاء الاصطناعي؟';

  @override
  String get aiConsentWithdrawBody =>
      'يتوقف مساعد الدراسة والملاحظات والدفاتر والاختبارات والبطاقات التعليمية حتى تُفعَّل من جديد. ويبقى ما صُنع سابقًا.';

  @override
  String get aiConsentWithdrawAction => 'إيقاف';

  @override
  String get aiConsentSaveFailed =>
      'لم يُحفظ ذلك. تحقّق من اتصالك وحاول مرة أخرى.';

  @override
  String get aiConsentReadNotice => 'اقرأ ما الذي يُرسل';

  @override
  String get aiConsentNeeded =>
      'أدوات الدراسة بالذكاء الاصطناعي متوقفة لهذا الحساب. يفعّلها الطالب من حسابه، ويفعّلها ولي الأمر لحساب الطفل.';

  @override
  String get safetyReviewSection => 'المنصة';

  @override
  String get safetyReviewTitle => 'بلاغات السلامة';

  @override
  String get safetyReviewEntrySubtitle =>
      'مراجعة البلاغات المقدَّمة في ستودافاي. لا يرى هذا إلا مشغّلو المنصة.';

  @override
  String get safetyReviewLoadFailed => 'تعذّر تحميل البلاغات.';

  @override
  String get safetyReviewUnavailable =>
      'تعذّر الوصول إلى ستودافاي. تحقّق من اتصالك وحاول مرة أخرى.';

  @override
  String get safetyReviewTryAgain => 'حاول مرة أخرى';

  @override
  String get safetyReviewEmptyTitle => 'لا توجد بلاغات مفتوحة';

  @override
  String get safetyReviewEmptyBody =>
      'تصل البلاغات الجديدة أيضًا إلى محادثة تنبيهات السلامة.';

  @override
  String get safetyReviewNotOperator => 'هذا الحساب ليس من مشغّلي المنصة.';

  @override
  String get safetyReviewListFooter =>
      'لا يظهر هنا إلا ما يظهر في التنبيه. لا يُفتح محتوى البلاغ إلا بوصول تطلبه، وكل خطوة تُسجَّل.';

  @override
  String get safetyReviewSecondApproverBanner =>
      'يجب الآن أن يوافق مراجع ثانٍ على كل طلب وصول. اطلب منه ذلك، أو اتبع دليل تشغيل المشغّلين.';

  @override
  String get safetyReviewKindMessage => 'بلاغ عن رسالة';

  @override
  String get safetyReviewKindConversation => 'بلاغ عن محادثة';

  @override
  String get safetyReviewKindUser => 'بلاغ عن شخص';

  @override
  String get safetyReviewPriorityCritical => 'حرج';

  @override
  String get safetyReviewPriorityHigh => 'مرتفع';

  @override
  String get safetyReviewPriorityMedium => 'متوسط';

  @override
  String get safetyReviewPriorityLow => 'منخفض';

  @override
  String safetyReviewReportId(String id) {
    return 'البلاغ $id';
  }

  @override
  String get safetyReviewFiledJustNow => 'قُدِّم الآن';

  @override
  String safetyReviewFiledMinutes(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'قُدِّم قبل $count دقيقة',
      many: 'قُدِّم قبل $count دقيقة',
      few: 'قُدِّم قبل $count دقائق',
      two: 'قُدِّم قبل دقيقتين',
      one: 'قُدِّم قبل دقيقة',
      zero: 'قُدِّم الآن',
    );
    return '$_temp0';
  }

  @override
  String safetyReviewFiledHours(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'قُدِّم قبل $count ساعة',
      many: 'قُدِّم قبل $count ساعة',
      few: 'قُدِّم قبل $count ساعات',
      two: 'قُدِّم قبل ساعتين',
      one: 'قُدِّم قبل ساعة',
      zero: 'قُدِّم الآن',
    );
    return '$_temp0';
  }

  @override
  String safetyReviewFiledDays(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'قُدِّم قبل $count يوم',
      many: 'قُدِّم قبل $count يومًا',
      few: 'قُدِّم قبل $count أيام',
      two: 'قُدِّم قبل يومين',
      one: 'قُدِّم قبل يوم',
      zero: 'قُدِّم اليوم',
    );
    return '$_temp0';
  }

  @override
  String get safetyReviewAccessOpen => 'الوصول مفتوح';

  @override
  String get safetyReviewStatusSubmitted => 'جديد';

  @override
  String get safetyReviewStatusQueued => 'في الانتظار';

  @override
  String get safetyReviewStatusUnderReview => 'قيد المراجعة';

  @override
  String get safetyReviewStatusOnHold => 'معلّق';

  @override
  String get safetyReviewStatusEscalated => 'مُصعَّد';

  @override
  String get safetyReviewStatusResolved => 'تم البتّ فيه';

  @override
  String get safetyReviewStatusWithdrawn => 'مسحوب';

  @override
  String get safetyReviewReasonTitle => 'لماذا تفتح هذا البلاغ؟';

  @override
  String get safetyReviewReasonBody =>
      'فتح البلاغ يمنحك وصولًا إليه لمدة 60 دقيقة. يُسجَّل سببك مع الوصول، وتُسجَّل كذلك كل قراءة وكل قرار.';

  @override
  String get safetyReviewReasonLabel => 'السبب';

  @override
  String get safetyReviewReasonHint => 'مثال: وصل تنبيه في محادثة السلامة';

  @override
  String get safetyReviewTextTooShort => 'اكتب 8 أحرف على الأقل.';

  @override
  String get safetyReviewContinue => 'متابعة';

  @override
  String get safetyReviewCodeTitle => 'أكّد أنه أنت';

  @override
  String get safetyReviewCodeBody =>
      'أدخل الرمز المكوّن من 6 أرقام من تطبيق المصادقة.';

  @override
  String get safetyReviewCodeLabel => 'رمز المصادقة';

  @override
  String get safetyReviewCodeDigits => 'أدخل الأرقام الستة.';

  @override
  String get safetyReviewOpenReport => 'فتح البلاغ';

  @override
  String get safetyReviewWrongCode =>
      'لم يتطابق هذا الرمز. تأكّد من صحة الوقت في هاتفك، ثم جرّب أحدث رمز.';

  @override
  String get safetyReviewNotEnrolledTitle => 'فعّل التحقق بخطوتين أولًا';

  @override
  String get safetyReviewNotEnrolledBody =>
      'مراجعة البلاغات تحتاج إلى رمز من تطبيق مصادقة. فعّله من الحساب، ثم الأمان، وارجع بعد ذلك.';

  @override
  String get safetyReviewOpenSecurity => 'فتح أمان الحساب';

  @override
  String get safetyReviewWorking => 'جارٍ فتح البلاغ';

  @override
  String get safetyReviewGrantEndedTitle => 'انتهى وصولك';

  @override
  String get safetyReviewGrantEndedBody =>
      'يدوم الوصول إلى البلاغ 60 دقيقة، أو حتى يُلغى. اطلب الوصول من جديد لمواصلة المراجعة.';

  @override
  String get safetyReviewAskAgain => 'اطلب الوصول من جديد';

  @override
  String get safetyReviewSecondApproverTitle => 'يجب أن يوافق مراجع ثانٍ';

  @override
  String get safetyReviewSecondApproverBody =>
      'يوجد الآن أكثر من مراجع، لذا يجب أن يوافق مراجع آخر على وصولك. اطلب منه الموافقة، أو اتبع دليل تشغيل المشغّلين.';

  @override
  String get safetyReviewChangedTitle => 'تغيّر هذا البلاغ';

  @override
  String get safetyReviewChangedBody =>
      'حدّثه شخص آخر، أو صُعِّد. أعد التحميل لترى حالته.';

  @override
  String get safetyReviewReload => 'إعادة التحميل';

  @override
  String get safetyReviewDetailsHeading => 'ما كتبه المُبلِّغ';

  @override
  String get safetyReviewSnapshotHeading => 'ما تم الإبلاغ عنه';

  @override
  String get safetyReviewSnapshotMessage => 'الرسالة';

  @override
  String get safetyReviewSnapshotSubject => 'موضوع المحادثة';

  @override
  String get safetyReviewSnapshotSentAt => 'وقت الإرسال';

  @override
  String get safetyReviewSnapshotSender => 'حساب المرسل';

  @override
  String get safetyReviewSnapshotConversation => 'المحادثة';

  @override
  String get safetyReviewSnapshotState => 'حالة المحادثة';

  @override
  String get safetyReviewNothingCaptured => 'لم يُحفظ شيء مع هذا البلاغ.';

  @override
  String get safetyReviewEvidenceHeading => 'الأدلة';

  @override
  String get safetyReviewEvidenceMessage => 'رسالة';

  @override
  String get safetyReviewEvidenceAttachment => 'ملف';

  @override
  String get safetyReviewEvidenceNote => 'ملاحظة';

  @override
  String get safetyReviewNoEvidence => 'لا توجد أدلة مرفقة.';

  @override
  String get safetyReviewHistoryHeading => 'السجل';

  @override
  String get safetyReviewEventSubmitted => 'قُدِّم';

  @override
  String get safetyReviewEventQueued => 'أُدرج في القائمة';

  @override
  String get safetyReviewEventTriage => 'فُتح للمراجعة';

  @override
  String get safetyReviewEventResolve => 'تم البتّ فيه';

  @override
  String get safetyReviewEventAppeal => 'تم الاعتراض عليه';

  @override
  String get safetyReviewEventEscalate => 'صُعِّد';

  @override
  String get safetyReviewReporterMasked =>
      'تبقى هوية المُبلِّغ مخفية ما لم يُصعَّد البلاغ.';

  @override
  String get safetyReviewDecisionHeading => 'قرارك';

  @override
  String get safetyReviewOutcomeUpheld => 'مقبول';

  @override
  String get safetyReviewOutcomeUpheldDetail => 'خُولفت القواعد واتُّخذ إجراء.';

  @override
  String get safetyReviewOutcomePartial => 'مقبول جزئيًا';

  @override
  String get safetyReviewOutcomePartialDetail => 'قُبل جزء من البلاغ.';

  @override
  String get safetyReviewOutcomeNotUpheld => 'غير مقبول';

  @override
  String get safetyReviewOutcomeNotUpheldDetail => 'لم تُخالَف القواعد.';

  @override
  String get safetyReviewOutcomeNoAction => 'دون إجراء';

  @override
  String get safetyReviewOutcomeNoActionDetail => 'لا يوجد ما يستدعي إجراءً.';

  @override
  String get safetyReviewNoteLabel => 'ملاحظة';

  @override
  String get safetyReviewNoteHint =>
      'ما قررته ولماذا. لا تنسخ المحتوى المُبلَّغ عنه.';

  @override
  String get safetyReviewRecord => 'تسجيل القرار';

  @override
  String get safetyReviewConfirmTitle => 'تسجيل هذا القرار؟';

  @override
  String safetyReviewConfirmBody(String outcome) {
    return 'يُغلق البلاغ بقرار \"$outcome\" ويُبلَّغ المُبلِّغ بأنه تم البتّ فيه. لا يمكن التراجع عن ذلك هنا.';
  }

  @override
  String get safetyReviewCancel => 'إلغاء';

  @override
  String get safetyReviewRecorded => 'سُجّل القرار.';

  @override
  String get safetyReviewNotDecidable =>
      'لا يمكن البتّ في هذا البلاغ هنا: إنه مُصعَّد أو مغلق. اتبع دليل تشغيل المشغّلين.';

  @override
  String safetyReviewResolvedAs(String outcome) {
    return 'تم البتّ فيه: $outcome';
  }
}
