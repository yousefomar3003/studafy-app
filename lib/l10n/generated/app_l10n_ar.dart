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
      'تابع التقدّم والحضور - ومع Family+ اتجاه كل صف وما يجب التركيز عليه هذا الأسبوع. بلا إعلانات، ولا نبيع بياناتك أبدًا.';

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
      'ما الذي نجمعه\nاسمك وبريدك الإلكتروني من مزوّد تسجيل الدخول الذي تختاره، وجنسك فقط إذا اخترت ذكره (ولا يظهر لأي أحد آخر). المدرسة أو الصف الذي تنتمي إليه ودورك فيه. الدروس، والأعمال المطلوبة منك وما تسلّمه وكل تسليم سابق، ودرجاتك وسجل أي تعديل عليها، وحضورك، وملاحظات الرعاية، ودفتر ملاحظاتك الخاص. الرسائل والرسائل الصوتية والإعلانات وروابط الاجتماعات داخل التطبيق. الملفات التي ترفعها. اشتراكاتك وإعدادات الإشعارات.\n\nلماذا\nلتشغيل صفوفك، وحماية حسابك، وإدارة الاشتراكات، والوفاء بالالتزامات القانونية. لا نبيع البيانات الشخصية. لا نعرض أي إعلانات. ولا نستخدم بياناتك لتدريب أي نموذج ذكاء اصطناعي.\n\nالدرجات والحضور\nيمكن للمعلمين رصد درجات الأعمال الورقية إلى جانب الأعمال المسلَّمة إلكترونيًا. تبقى الدرجة مسودة لا يراها إلا معلموك حتى ينشرها المعلم، ولا تُحتسب الدرجة غير المرصودة صفرًا أبدًا. إذا صُحّحت درجة منشورة نحتفظ بالدرجة القديمة والجديدة ومن غيّرها ومتى ولماذا، ويُبلَّغ أنت ووالداك إذا تغيّرت الدرجة. تعديل الحضور بعد يوم الدرس يتطلب سببًا، ولا يستطيع تعديل سجل مضى عليه أكثر من سبعة أيام إلا المعلم الرئيسي للصف، ويُحفظ كل تعديل. تُحدَّد مواعيد التسليم بتوقيت مدرستك.\n\nمن يرى أعمالك\nمعلمو صفك، وولي الأمر المرتبط بك بعد نشر الدرجة. لا يوجد مسؤول مدرسة في هذا الإصدار من التطبيق. لا يستطيع الطلاب الآخرون الاطلاع على درجاتك أو أعمالك أو رسائلك الخاصة. تُخزَّن الرسائل على خوادمنا وليست مشفّرة طرفًا إلى طرف.\n\nأولياء الأمور والأبناء\nيطلب ولي الأمر الارتباط بالطالب، ويوافق الطالب أو يرفض من جهازه. ويمكن لولي الأمر أيضًا إنشاء حساب لطفل ليس لديه بريد إلكتروني أو هاتف وإدارته، ويقبل هذه الشروط نيابةً عن الطفل. يرى ولي الأمر المرتبط الدرجات المنشورة والحضور والأعمال ومواد الصف، ويمكنه تسليم العمل عن طفل صغير، لكنه لا يستطيع تعديل الدرجات أو الحضور ولا يُمنح رسائل الطفل الخاصة. Family+ خطة مدفوعة لأولياء الأمور تشمل حتى 4 أو حتى 8 أطفال مرتبطين، الأسبق ربطًا أولًا. ولكل طفل تشمله تلخّص ما يستطيع ولي الأمر رؤيته أصلًا - الدرجات حسب الصف والاتجاهات والحضور والواجبات غير المسلّمة والاختبارات الفائتة - وتقارن الطفل بسجله السابق فقط، ولا تستخدم الذكاء الاصطناعي.\n\nأدوات الدراسة بالذكاء الاصطناعي\nهذه الأدوات اختيارية. عند استخدامها يُرسل ما تقدّمه لها إلى Together AI، وهي شركة ذكاء اصطناعي خارج ستودافاي: السؤال الذي تكتبه وآخر الرسائل في المحادثة نفسها، وإذا اخترت ذلك نص درس أو ملاحظاتك الخاصة أو صورة تضيفها (مساعد الدراسة، وملاحظات السبورة، وملاحظات الدرس، والاختبارات والبطاقات التعليمية). لا يُرسل اسمك ولا بريدك ولا مدرستك ولا درجاتك أبدًا. تُحفظ المحادثات على جهازك فقط. قد تكون الإجابات خاطئة، فلا تسلّمها على أنها عملك أبدًا. الذكاء الاصطناعي لا يصحّح أعمالك أبدًا.\n\nالملفات\nتُخزَّن الملفات بشكل خاص، وتُفحص قبل أن يتمكن أحد من تنزيلها، ولا تُفتح إلا عبر روابط تعمل مرة واحدة وتنتهي خلال دقائق. تُزال التفاصيل المخفية من الصور والرسائل الصوتية. إذا استبدل المعلم ملفًا أو أزاله فلن يراه الصف، لكنه يُحفظ لدى المدرسة.\n\nالمدفوعات\nتُحصَّل اشتراكات Studafy Plus وStudafy Max وFamily+ عبر Apple أو Google وفق شروطهما. لا نطّلع على بطاقتك إطلاقًا.\n\nمن يعالج البيانات أيضًا\nتستضيف Supabase قاعدة البيانات وتسجيل الدخول والملفات؛ وتستضيف Amazon Web Services التطبيق وسجلاته التقنية؛ ويخزّن GitHub نسخًا احتياطية مشفّرة لا يستطيع قراءتها؛ ويحفظ Redis عدادات قصيرة الأجل؛ وتتحقق Google وMicrosoft وApple من تسجيل الدخول؛ وتشغّل Cloudflare فحص الروبوتات؛ وتشغّل Together AI أدوات الدراسة بالذكاء الاصطناعي؛ وترسل Resend البريد وترسل Firebase الإشعارات التي لا تتضمن درجاتك أو رسائلك أبدًا؛ وتُعقد الاجتماعات في Google Meet. ويعمل كل منهم وفق تعليماتنا فقط.\n\nأين تُعالَج بياناتك\nقد تُعالَج بياناتك خارج بلدك، بما في ذلك خارج المنطقة الاقتصادية الأوروبية، محميةً بالبنود التعاقدية القياسية أو بقرار كفاية.\n\nما لا يمكننا حذفه\nسجلات الإجراءات المهمة تُضاف ولا تُعدَّل ولا تُحذف، ولا حتى من قِبلنا. ويشمل ذلك سجل الدرجات والحضور، والتسليمات السابقة، والملفات التي استبدلها المعلم. وكثيرًا ما تكون المدارس ملزمة بالاحتفاظ بسجلات الحضور والتقييم وحماية الطفل. يعرض التطبيق السجلات التي تبقى لدى مدرستك قبل تأكيد الحذف. تُحفظ النسخ الاحتياطية المشفّرة لمدة ٣٠ يومًا.\n\nعلى جهازك\nيحتفظ التطبيق بجلستك ولغتك ونسخة مؤقتة مما فتحته ونزّلته ومحادثات مساعد الدراسة وصورتك الشخصية، لكل حساب على حدة. لا تُرفع صورتك الشخصية إلى خوادمنا أبدًا، فلا يراها أحد غيرك. وتُمسح عند تسجيل خروج ذلك الحساب.\n\nكيف نحميها\nيُفرض الوصول إلى بيانات كل صف داخل قاعدة البيانات نفسها، ولا يستطيع تعديل درجات الصف وحضوره إلا معلمو ذلك الصف. وتُزال الأسرار من السجلات. وتُخزَّن عناوين IP كبصمة أحادية الاتجاه فقط. وتُشفَّر النسخ الاحتياطية قبل أن تغادر أنظمتنا.\n\nحقوقك\nيمكنك طلب نسخة من بياناتك أو تصحيحها أو حذف حسابك أو تقييد المعالجة أو الاعتراض عليها أو سحب موافقتك. يوجد حذف الحساب وتصدير البيانات في إعدادات الحساب، ويمكن إلغاء الحذف خلال ١٤ يومًا؛ ويقوم ولي الأمر بذلك لحساب الطفل الذي يديره. ويمكنك تقديم شكوى إلى لجنة حماية البيانات في أيرلندا في أي وقت.\n\nإذا كانت مدرستك هي المتحكم في سجلاتك، فاسأل مدرستك أولًا؛ وسننقل طلبك إليها ونخبرك بذلك.';

  @override
  String get policyTermsBody =>
      'لمن هذا التطبيق\nستودافاي للمعلمين والطلاب وأولياء الأمور. لا يوجد مسؤول مدرسة في هذا الإصدار من التطبيق. بتسجيل الدخول فإنك تقبل هذه الشروط وسياسة الخصوصية.\n\nحسابك\nسجّل الدخول عبر Google أو Microsoft أو Apple وحافظ على أمان ذلك الحساب. يمكنك إضافة عدة حسابات إلى جهاز واحد؛ وسجّل الخروج من أي جهاز مشترك. يمكن لولي الأمر إنشاء حساب لطفل ليس لديه بريد إلكتروني أو هاتف، ويقبل هذه الشروط نيابةً عنه، ويكون مسؤولًا عن طريقة استخدامه. لا تنتحل شخصية أحد.\n\nالاستخدام السليم\nاستخدم ستودافاي للتعلّم والتدريس والتواصل المدرسي فقط. لا تتنمّر على أحد أو تضايقه أو تهدده، ولا تشارك محتوى جنسيًا أو عنيفًا أو يحض على الكراهية أو مخالفًا للقانون، ولا ترفع ملفات لا يحق لك مشاركتها، ولا تحاول الاطلاع على سجلات ليست لك، ولا تسلّم عمل غيرك أو ما ينتجه الذكاء الاصطناعي على أنه عملك. يمكنك الإبلاغ عن أي شخص أو حظره من داخل التطبيق. قد نزيل المحتوى ونعلّق الحسابات التي تخالف هذه القواعد.\n\nالمعلمون\nأنت مسؤول عن الدرجات والحضور الذي ترصده. تبقى الدرجات مسودات حتى تنشرها. لا تُعدَّل الدرجة المنشورة إلا بتصحيحها مع ذكر السبب، وتُحفظ الدرجة القديمة. تعديل الحضور بعد يوم الدرس يتطلب سببًا، وبعد سبعة أيام لا يستطيع تعديل السجل إلا المعلم الرئيسي للصف. امنح الطلاب وقتًا إضافيًا أو أعد فتح العمل مع ذكر السبب. تُحفظ الملفات التي تستبدلها أو تزيلها لدى المدرسة. لا تشارك إلا ما يحق لك مشاركته.\n\nالطلاب\nسلّم عملك بنفسك. يمكنك استبداله حتى موعد التسليم، وهو بتوقيت مدرستك، وتُحفظ التسليمات السابقة. بعد انتهاء الموعد، أو بعد نشر الدرجة، تحتاج إلى إذن معلمك لتسليم العمل من جديد. إذا بدت درجة أو سجل حضور غير صحيح فاسأل معلمك.\n\nأولياء الأمور\nلا يمكنك الارتباط بطفلك إلا بموافقته، إلا إذا كنت أنت من أنشأ حسابه. يمكنك رؤية الدرجات المنشورة والحضور والأعمال ومواد الصف، وتسليم العمل عن طفل صغير. لا يمكنك تعديل الدرجات أو الحضور، ولا ترى رسائل طفلك الخاصة. Family+ خطة مدفوعة خاصة بك: خطة تشمل حتى 4 أطفال مرتبطين، وخطة أكبر تشمل حتى 8، بترتيب ربطهم. تلخّص ما تستطيع رؤيته أصلًا، وتقارن الطفل بسجله السابق فقط، ولا تتنبأ بشيء.\n\nمحتواك\nتحتفظ بحقوقك فيما تكتبه وترفعه. وتسمح لنا بتخزينه وعرضه فقط لتشغيل ستودافاي لك ولمدرستك. تصبح الأعمال المسلَّمة والدرجات والحضور والملفات المشتركة جزءًا من سجلات المدرسة.\n\nأدوات الدراسة بالذكاء الاصطناعي\nهي اختيارية وقد تخطئ. تحقّق مما تنتجه ولا تسلّمه على أنه عملك أبدًا. الذكاء الاصطناعي لا يصحّح الأعمال أبدًا. تنطبق حدود يومية وشهرية.\n\nالاشتراكات\nالدروس ودفاتر الملاحظات والأعمال والدرجات والحضور مجانية. Studafy Plus وStudafy Max للطلاب، وFamily+ لأولياء الأمور لحتى 4 أو حتى 8 أطفال مرتبطين. تُحصَّل جميعها شهريًا عبر Apple أو Google بالسعر الذي يعرضه المتجر حتى تلغيها من حسابك في المتجر، حيث تُعالَج المبالغ المستردة أيضًا.\n\nالاجتماعات\nلا يستضيف ستودافاي مكالمات الفيديو. تُفتح روابط الاجتماعات في Google Meet وفق شروط Google.\n\nالتغييرات وإنهاء الاستخدام\nقد نغيّر الميزات أو نوقفها، وسنبلغك قبل أي تغيير في هذه الشروط يؤثر عليك. يمكنك حذف حسابك من إعدادات الحساب والتراجع خلال ١٤ يومًا. تبقى السجلات التي يجب على المدرسة الاحتفاظ بها لدى المدرسة.';

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
    return 'انضم إلى فصلي في ستودافاي برمز الصف $code\nأو افتح هذا الرابط: $link';
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
    return 'يشمل Family+ لديك أول $seats أطفال ربطتهم، و$name ليس منهم. انتقل إلى خطة حتى 8 أطفال لتشمل $name.';
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

  @override
  String get studySetMaxBadge => 'باقة Studafy Max';

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
  String get studyAssistantDailyLimit =>
      'لقد استخدمت كل أسئلة اليوم. يمكنك السؤال مرة أخرى غدًا.';

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
  String get studyToolsLocked => 'متاحة مع Studafy Max.';

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
      'عناوين ومصطلحات رئيسية وملخص - Studafy Plus';

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
  String get helperPhotoPlus => 'الصور متاحة مع Studafy Plus.';

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
  String get upgradeDailyLimitTitle => 'لقد استخدمت أسئلة اليوم';

  @override
  String upgradeDailyLimitBody(int count) {
    return 'تتضمن خطتك $count سؤالًا في اليوم. يمكنك السؤال مجددًا غدًا.';
  }

  @override
  String get upgradeAllowanceTitle =>
      'استُخدم رصيد الذكاء الاصطناعي لهذا الشهر';

  @override
  String get upgradeAllowanceBody =>
      'يتجدد رصيد الذكاء الاصطناعي في خطتك في اليوم الأول من الشهر القادم.';

  @override
  String upgradeFeatureTitle(String plan) {
    return 'هذه الميزة متاحة مع $plan';
  }

  @override
  String get upgradeFeatureBody => 'خطتك الحالية لا تتضمنها.';

  @override
  String upgradeWhatUnlocks(String plan) {
    return 'ما تتيحه $plan';
  }

  @override
  String get upgradeLargerAllowance => 'رصيد شهري أكبر للذكاء الاصطناعي';

  @override
  String get upgradeButton => 'ترقية';

  @override
  String get upgradeNotNow => 'ليس الآن';

  @override
  String get upgradeTopPlan => 'أنت على Studafy Max، أكبر خطة.';

  @override
  String get studyPlansIncludedInYourPlan => 'مضمّنة في خطتك';

  @override
  String studyPlansUpgradeToName(String name) {
    return 'الترقية إلى $name';
  }

  @override
  String studyPlansUpgradeReplaces(String current) {
    return 'يُستبدل اشتراكك في $current فورًا، ويحتسب المتجر ما دفعته مسبقًا.';
  }

  @override
  String studyPlansRenewsOn(String date) {
    return 'يتجدد في $date';
  }

  @override
  String studyPlansCancelledUntil(String plan, String date) {
    return 'أُلغي. تبقى لديك $plan حتى $date ولن تُحاسَب مرة أخرى.';
  }

  @override
  String get studyPlansPausedNote =>
      'متوقف مؤقتًا في Google Play. لا رسوم أثناء الإيقاف، ويُستأنف تلقائيًا.';

  @override
  String studyPlansPaymentIssue(String store, String plan) {
    return 'تعذّر على $store تحصيل الدفعة. حدّث طريقة الدفع للاحتفاظ بـ $plan.';
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
    return 'خذ استراحة من أسبوع إلى 3 أشهر. تبقى لديك $plan حتى $date. بعدها يتوقف مؤقتًا: لا ميزات $plan ولا رسوم حتى يُستأنف تلقائيًا. يمكنك الاستئناف مبكرًا.';
  }

  @override
  String get cancelPauseButton => 'إيقاف مؤقت في Google Play';

  @override
  String cancelCancelBody(String plan, String date) {
    return 'تبقى لديك $plan حتى $date ولن تُحاسَب مرة أخرى. بعد ذلك تنتقل إلى Studafy Free، وتبقى دفاترك ودروسك.';
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
  String get paperGradesAbsent => 'غائب';

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
    return 'الترقية إلى $plan';
  }

  @override
  String planAdds(Object plan) {
    return 'يضيف $plan:';
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
  String get helperLimitReached =>
      'لقد استخدمت أسئلة اليوم. قم بالترقية للحصول على المزيد يوميًا، أو اسأل مجددًا غدًا.';

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
  String get familyPlusNoPlan => 'لا توجد خطة Family+ بعد';

  @override
  String familyPlusCoveredCount(int count) {
    return 'تغطي $count من أطفالك';
  }

  @override
  String familyPlusEnds(String date) {
    return 'فعّالة حتى $date';
  }

  @override
  String get familyPlusWhatYouGet => 'ما تضيفه Family+';

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
}
