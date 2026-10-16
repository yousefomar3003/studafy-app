# Store listing copy (English and Arabic)

Launch plan item A4, drafted 2026-10-15 from the code on `main`. **Nothing
has been submitted.** The owner pastes these into Play Console and App Store
Connect (B12).

The copy has to agree with:
- the Google Play Data safety answers (`google-play-data-safety.md`);
- the App Store privacy labels (`app-store-privacy-labels.md`);
- the privacy policy (`docs/legal/privacy-policy.md`, version 1.4).

When one of them changes, re-read this file.

Every feature named below exists in the app. The table in
[Where each claim comes from](#where-each-claim-comes-from) gives the code for
each one. Run `bun scripts/store/check-listing.ts` after any edit; it fails if
a field is over its limit or the count table is out of date
(`--write` rewrites the table).

---

## Decisions (2026-10-16)

The owner asked Claude to choose. Each choice follows a decision already on
record; change any of them by editing this list and the app together.

1. **AI at launch: included** (DL-062, the owner's decision of 2026-10-16:
   AI is on from launch). Paste every `*.ai` block after "For students", so
   Studafy Plus and Max are on sale. The screenshots still show no AI screen;
   add one later if wanted.
2. **Messaging at launch: included** (DL-063, the owner's decision of
   2026-10-16: messaging launches, with the owner as the one report reviewer;
   this replaces the earlier "left out until its gate is met"). Keep the
   `[messages]` lines in the descriptions (messages in the opening line,
   "message students and parents", "Message your teachers", "message
   teachers") and paste them as written.
3. **Uploads: kept.** The listing goes out only with a build after the
   release-block change (D1), where uploads work.
4. **The name in Arabic: ستودافاي**, as the app spells it
   (`docs/l10n/arabic-glossary.md`).
5. **The title: "Studafy: Classes & Homework"** on both stores (27
   characters; the two words describe the app, which both stores allow).
6. **Family+ in Arabic: "Family+" in Latin letters**, like Studafy Plus and
   Max. The two app strings that said "العائلة+" now say "Family+".
7. **Screenshots: none that show AI or messages yet.** Google Play (8): 1,
   5, 4, 11, 9, 10, 12, 14. App Store (10): the same, then 13 and 2.
   `student-1-today` shows the Helper tab and `student-2-notebook`'s screen
   links to AI notes, so they stay out until retaken with AI on. Messaging
   launches (DL-063), so 6 and 15 (messages) can be added once they are
   taken: start the API and seed with `--messaging on` (see
   [Taking them again](#taking-them-again)). The current pictures were
   taken with messaging off, so their tab bars show Announcements where the
   app at launch shows Messages; retake 1, 9, 10, 12 and 14 the same way
   before submitting.
8. **Meetings: left out** until a teacher can create one in the app (B8).

## Rules this copy follows

- **Claims:** only what the code does. No "best", "#1" or other superlatives,
  and no competitor names.
- **Prices:** none in any description. The stores show them on the
  subscription list. The App Store text still gives the renewal terms and the
  links that guideline 3.1.2 asks for.
- **AI:** never in a title, subtitle or short description.
- **Families and children:** nothing that targets children with marketing
  language. "No ads" and "never sell your data" match Data safety Section 4
  and policy §2.
- **Sign-in:** Google and Microsoft on Android (Sign in with Apple is iOS
  only). Apple, Google and Microsoft on iOS, which needs C13
  (`APPLE_SIGN_IN_ENABLED`) done before submission.
- **Contact:** hello@studafy.com.
- **Arabic:** written as Modern Standard Arabic, not translated word for word,
  with the app's own terms:
  - معلم، طالب، ولي الأمر;
  - الدروس، الواجبات، الدرجات، الحضور;
  - سجل الدرجات، معرّف Studafy.

  The copy says الصف for a class, because the app uses it most
  (79 times, against 25 for الفصل).
- **Category and age:** the App Store category is Education, not Kids. The
  age settings declare under-13s (DL-056).

---

## Google Play: English

### App name

<!-- field: play.en.title max=30 -->
```text
Studafy: Classes & Homework
```

### Short description

<!-- field: play.en.short max=80 -->
```text
Lessons, homework, online exams, marks and attendance for teachers and families
```

### Full description

<!-- field: play.en.full max=4000 -->
```text
Studafy brings a class's everyday work into one app for teachers, students and parents: lessons, homework, online and paper tests, marks, attendance and messages, in English or Arabic.

FOR TEACHERS
• Start on your own: create your classes, set the timetable and invite students with a class code or link
• Share lessons with notes, files (PDF, Word, PowerPoint and images) and links
• Set homework with a due date, see who has handed in, and give extra time
• Build online exams with single-answer, multiple-answer, true or false, short-answer and essay questions. Questions with a set answer are marked automatically; you mark the rest
• Choose when students see the correct answers
• Keep marks for paper tests and online work in one gradebook
• Marks stay private until you publish them. A corrected mark keeps a record of the change and the reason
• Take attendance: present, absent, late or excused
• Keep wellbeing notes on a student's strengths and concerns
• Post announcements to a class, and message students and parents

FOR STUDENTS
• Join a class with the code from your teacher
• Read lessons by date and keep your own notebook for each class
• Hand in homework as typed answers, photos or documents
• Take online exams on your phone
• See your published marks, your teacher's feedback and your attendance
• Message your teachers

FOR PARENTS
• Link to your child with their Studafy ID. Your child approves the request on their own device
• Follow your child's published marks, homework and attendance
• Read class announcements and message teachers
• Create an account for a younger child who has no email address, and switch between accounts on one device
• Family+ (optional subscription): what to focus on this week, marks over time, each class at a glance, missing work and missed tests

PRIVACY AND SAFETY
• No ads, and we never sell your data
• Students and families see a mark only after the teacher publishes it
• Report or block someone from any conversation
• Download a copy of your data, or delete your account, from inside the app
• Sign in with your Google or Microsoft account: no new password to remember

ENGLISH AND ARABIC
The whole app works in English and in Arabic, with a right-to-left layout in Arabic. You can change the language at any time.

Lessons, homework, marks and attendance are free. Family+ is an optional monthly subscription for parents. It renews automatically until you cancel it, which you can do at any time in your Google Play subscriptions.

Questions or feedback: hello@studafy.com
Privacy policy: https://studafy-legal.studafy.workers.dev/privacy
Terms of use: https://studafy-legal.studafy.workers.dev/terms
```

**Optional AI block** (B1). If AI is on at launch, paste it after the "For
students" section:

<!-- field: play.en.ai max=4000 adds-to=play.en.full -->
```text
STUDY HELP
• Ask the study helper about your lessons and your own notes
• Studafy Plus: turn a lesson or a photo of the whiteboard into study notes, and keep study notebooks with highlights and bookmarks
• Studafy Max: quizzes and flashcards made from your lessons
The study helper uses an AI service, and its answers can be wrong, so check with your teacher. Names, email addresses and marks are never sent to it. Studafy Plus and Max are optional monthly subscriptions, and a student can ask a parent to approve the purchase.
```

### What's new (first internal-testing release)

Play allows 500 characters.

<!-- field: play.en.whatsnew max=500 -->
```text
The first test release of Studafy. Please try signing in, joining a class with a code, lessons, homework with a photo or a file, an online exam, marks, attendance and messages, in English and in Arabic. Tell us what breaks or confuses you: hello@studafy.com
```

---

## Google Play: Arabic

### App name

<!-- field: play.ar.title max=30 -->
```text
ستودافاي: الدروس والواجبات
```

### Short description

<!-- field: play.ar.short max=80 -->
```text
الدروس والواجبات والاختبارات والدرجات والحضور للمعلمين والطلاب وأولياء الأمور
```

### Full description

<!-- field: play.ar.full max=4000 -->
```text
يجمع ستودافاي العمل اليومي للصف في تطبيق واحد للمعلمين والطلاب وأولياء الأمور: الدروس والواجبات والاختبارات الإلكترونية والورقية والدرجات والحضور والرسائل، بالعربية أو بالإنجليزية.

للمعلمين
• ابدأ بنفسك: أنشئ صفوفك، ونظّم جدول الحصص، وادعُ طلابك برمز الصف أو برابط
• شارك الدروس مع ملاحظاتك وملفاتك (PDF وWord وPowerPoint والصور) والروابط
• حدّد الواجبات وموعد تسليمها، وتابع من سلّم، وامنح وقتًا إضافيًا عند الحاجة
• صمّم اختبارات إلكترونية بأسئلة اختيار من متعدد بإجابة واحدة أو أكثر، وصواب وخطأ، وإجابة قصيرة، ومقالية. تُصحَّح الأسئلة ذات الإجابة المحددة تلقائيًا، وتصحّح أنت الباقي
• اختر متى يرى الطلاب الإجابات الصحيحة
• ارصد درجات الاختبارات الورقية والأعمال الإلكترونية في سجل درجات واحد
• تبقى الدرجات خاصة حتى تنشرها، وأي تصحيح لدرجة منشورة يُحفظ مع سببه
• سجّل الحضور: حاضر أو غائب أو متأخر أو بعذر
• دوّن ملاحظات الرعاية عن نقاط قوة الطالب وما يقلقك بشأنه
• انشر الإعلانات لصفك، وراسل الطلاب وأولياء الأمور

للطلاب
• انضم إلى صفك بالرمز الذي يعطيك إياه معلمك
• اقرأ الدروس حسب التاريخ، واكتب في دفترك الخاص لكل صف
• سلّم واجباتك كتابةً أو بصورة أو بملف
• أدِّ الاختبارات الإلكترونية من هاتفك
• اطّلع على درجاتك المنشورة وملاحظات معلمك وسجل حضورك
• راسل معلميك

لأولياء الأمور
• اربط حسابك بطفلك عبر معرّف Studafy الخاص به، ويوافق طفلك على الطلب من جهازه
• تابع درجات طفلك المنشورة وواجباته وحضوره
• اقرأ إعلانات الصف وراسل المعلمين
• أنشئ حسابًا لطفلك الصغير الذي ليس لديه بريد إلكتروني، وتنقّل بين الحسابات على الجهاز نفسه
• Family+ (اشتراك اختياري): ما يجب التركيز عليه هذا الأسبوع، وتطور الدرجات مع الوقت، ونظرة على كل مادة، والواجبات الناقصة والاختبارات الفائتة

الخصوصية والأمان
• لا إعلانات، ولا نبيع بياناتك أبدًا
• لا يرى الطالب ولا عائلته الدرجة إلا بعد أن ينشرها المعلم
• أبلغ عن أي شخص أو احظره من داخل المحادثة
• نزّل نسخة من بياناتك أو احذف حسابك من داخل التطبيق
• سجّل الدخول بحساب Google أو Microsoft، دون كلمة مرور جديدة تحفظها

بالعربية والإنجليزية
يعمل التطبيق كاملًا بالعربية والإنجليزية، باتجاه من اليمين إلى اليسار في العربية، ويمكنك تغيير اللغة متى شئت.

الدروس والواجبات والدرجات والحضور مجانية. أما Family+ فاشتراك شهري اختياري لأولياء الأمور، يتجدد تلقائيًا حتى تلغيه، ويمكنك إلغاؤه في أي وقت من اشتراكاتك في Google Play.

للأسئلة والملاحظات: hello@studafy.com
سياسة الخصوصية: https://studafy-legal.studafy.workers.dev/ar/privacy
شروط الاستخدام: https://studafy-legal.studafy.workers.dev/ar/terms
```

**Optional AI block** (B1). If AI is on at launch, paste it after the
"للطلاب" section:

<!-- field: play.ar.ai max=4000 adds-to=play.ar.full -->
```text
المساعدة في المذاكرة
• اسأل مساعد الدراسة عن دروسك وملاحظاتك
• Studafy Plus: حوّل الدرس أو صورة السبورة إلى ملاحظات للمذاكرة، واحتفظ بدفاتر مذاكرة فيها التظليل والإشارات المرجعية
• Studafy Max: اختبارات وبطاقات مراجعة من دروسك
يعتمد مساعد الدراسة على خدمة ذكاء اصطناعي، وقد تخطئ إجاباته، فتحقّق منها مع معلمك. لا تُرسَل إليه الأسماء ولا عناوين البريد الإلكتروني ولا الدرجات. Studafy Plus وStudafy Max اشتراكان شهريان اختياريان، ويستطيع الطالب أن يطلب موافقة ولي أمره على الشراء.
```

### What's new (first internal-testing release)

<!-- field: play.ar.whatsnew max=500 -->
```text
أول إصدار تجريبي من ستودافاي. جرّب تسجيل الدخول، والانضمام إلى صف برمز، والدروس، وتسليم واجب بصورة أو ملف، واختبارًا إلكترونيًا، والدرجات والحضور والرسائل، بالعربية والإنجليزية. أخبرنا بأي خطأ أو أمر غير واضح: hello@studafy.com
```

---

## App Store: English

### Name and subtitle

<!-- field: ios.en.name max=30 -->
```text
Studafy: Classes & Homework
```

<!-- field: ios.en.subtitle max=30 -->
```text
School life, connected
```

"School life, connected." is the line on the app's launch screen
(`lib/features/session/presentation/splash_page.dart`).

### Promotional text

<!-- field: ios.en.promo max=170 -->
```text
Lessons, homework, online exams, marks and attendance in one place for teachers, students and parents. In English and Arabic, with no ads.
```

### Description

<!-- field: ios.en.description max=4000 -->
```text
Studafy brings a class's everyday work into one app for teachers, students and parents: lessons, homework, online and paper tests, marks, attendance and messages, in English or Arabic.

FOR TEACHERS
• Start on your own: create your classes, set the timetable and invite students with a class code or link
• Share lessons with notes, files (PDF, Word, PowerPoint and images) and links
• Set homework with a due date, see who has handed in, and give extra time
• Build online exams with single-answer, multiple-answer, true or false, short-answer and essay questions. Questions with a set answer are marked automatically; you mark the rest
• Choose when students see the correct answers
• Keep marks for paper tests and online work in one gradebook
• Marks stay private until you publish them. A corrected mark keeps a record of the change and the reason
• Take attendance: present, absent, late or excused
• Keep wellbeing notes on a student's strengths and concerns
• Post announcements to a class, and message students and parents

FOR STUDENTS
• Join a class with the code from your teacher
• Read lessons by date and keep your own notebook for each class
• Hand in homework as typed answers, photos or documents
• Take online exams on your phone
• See your published marks, your teacher's feedback and your attendance
• Message your teachers

FOR PARENTS
• Link to your child with their Studafy ID. Your child approves the request on their own device
• Follow your child's published marks, homework and attendance
• Read class announcements and message teachers
• Create an account for a younger child who has no email address, and switch between accounts on one device
• Family+ (optional subscription): what to focus on this week, marks over time, each class at a glance, missing work and missed tests

PRIVACY AND SAFETY
• No ads, and we never sell your data
• Students and families see a mark only after the teacher publishes it
• Report or block someone from any conversation
• Download a copy of your data, or delete your account, from inside the app
• Sign in with Apple, Google or Microsoft: no new password to remember

ENGLISH AND ARABIC
The whole app works in English and in Arabic, with a right-to-left layout in Arabic. You can change the language at any time.

SUBSCRIPTIONS
Lessons, homework, marks and attendance are free. Family+ is an optional monthly subscription for parents. Payment is charged to your Apple Account when you confirm the purchase. The subscription renews automatically unless you cancel it at least 24 hours before the end of the current period. You can manage or cancel it in your App Store account settings.

Questions or feedback: hello@studafy.com
Privacy policy: https://studafy-legal.studafy.workers.dev/privacy
Terms of use: https://studafy-legal.studafy.workers.dev/terms
```

**Optional AI block** (B1). If AI is on at launch, paste it after the "For
students" section:

<!-- field: ios.en.ai max=4000 adds-to=ios.en.description -->
```text
STUDY HELP
• Ask the study helper about your lessons and your own notes
• Studafy Plus: turn a lesson or a photo of the whiteboard into study notes, and keep study notebooks with highlights and bookmarks
• Studafy Max: quizzes and flashcards made from your lessons
The study helper uses an AI service, and its answers can be wrong, so check with your teacher. Names, email addresses and marks are never sent to it. Studafy Plus and Max are optional monthly subscriptions, billed and renewed like Family+, and a student can ask a parent to approve the purchase.
```

### Keywords

Apple searches the name, the subtitle and the keywords together, so no word
from the name or subtitle is repeated here.

<!-- field: ios.en.keywords max=100 unit=bytes -->
```text
teacher,student,parent,gradebook,attendance,exam,quiz,lesson,assignment,marks,grades,timetable
```

### What's new

Apple shows no "What's New" for an app's first version. Use this as the
TestFlight "What to Test" text, and as "What's New" from version 1.1.

<!-- field: ios.en.whatsnew max=4000 -->
```text
The first test release of Studafy. Please try signing in, joining a class with a code, lessons, homework with a photo or a file, an online exam, marks, attendance and messages, in English and in Arabic. Tell us what breaks or confuses you: hello@studafy.com
```

---

## App Store: Arabic

### Name and subtitle

<!-- field: ios.ar.name max=30 -->
```text
ستودافاي: الدروس والواجبات
```

<!-- field: ios.ar.subtitle max=30 -->
```text
يومك الدراسي في مكان واحد
```

This follows the app's first welcome slide, "يومك الدراسي كله في مكان واحد"
(`introTitleOne`).

### Promotional text

<!-- field: ios.ar.promo max=170 -->
```text
الدروس والواجبات والاختبارات الإلكترونية والدرجات والحضور في مكان واحد للمعلمين والطلاب وأولياء الأمور، بالعربية والإنجليزية ودون إعلانات.
```

### Description

<!-- field: ios.ar.description max=4000 -->
```text
يجمع ستودافاي العمل اليومي للصف في تطبيق واحد للمعلمين والطلاب وأولياء الأمور: الدروس والواجبات والاختبارات الإلكترونية والورقية والدرجات والحضور والرسائل، بالعربية أو بالإنجليزية.

للمعلمين
• ابدأ بنفسك: أنشئ صفوفك، ونظّم جدول الحصص، وادعُ طلابك برمز الصف أو برابط
• شارك الدروس مع ملاحظاتك وملفاتك (PDF وWord وPowerPoint والصور) والروابط
• حدّد الواجبات وموعد تسليمها، وتابع من سلّم، وامنح وقتًا إضافيًا عند الحاجة
• صمّم اختبارات إلكترونية بأسئلة اختيار من متعدد بإجابة واحدة أو أكثر، وصواب وخطأ، وإجابة قصيرة، ومقالية. تُصحَّح الأسئلة ذات الإجابة المحددة تلقائيًا، وتصحّح أنت الباقي
• اختر متى يرى الطلاب الإجابات الصحيحة
• ارصد درجات الاختبارات الورقية والأعمال الإلكترونية في سجل درجات واحد
• تبقى الدرجات خاصة حتى تنشرها، وأي تصحيح لدرجة منشورة يُحفظ مع سببه
• سجّل الحضور: حاضر أو غائب أو متأخر أو بعذر
• دوّن ملاحظات الرعاية عن نقاط قوة الطالب وما يقلقك بشأنه
• انشر الإعلانات لصفك، وراسل الطلاب وأولياء الأمور

للطلاب
• انضم إلى صفك بالرمز الذي يعطيك إياه معلمك
• اقرأ الدروس حسب التاريخ، واكتب في دفترك الخاص لكل صف
• سلّم واجباتك كتابةً أو بصورة أو بملف
• أدِّ الاختبارات الإلكترونية من هاتفك
• اطّلع على درجاتك المنشورة وملاحظات معلمك وسجل حضورك
• راسل معلميك

لأولياء الأمور
• اربط حسابك بطفلك عبر معرّف Studafy الخاص به، ويوافق طفلك على الطلب من جهازه
• تابع درجات طفلك المنشورة وواجباته وحضوره
• اقرأ إعلانات الصف وراسل المعلمين
• أنشئ حسابًا لطفلك الصغير الذي ليس لديه بريد إلكتروني، وتنقّل بين الحسابات على الجهاز نفسه
• Family+ (اشتراك اختياري): ما يجب التركيز عليه هذا الأسبوع، وتطور الدرجات مع الوقت، ونظرة على كل مادة، والواجبات الناقصة والاختبارات الفائتة

الخصوصية والأمان
• لا إعلانات، ولا نبيع بياناتك أبدًا
• لا يرى الطالب ولا عائلته الدرجة إلا بعد أن ينشرها المعلم
• أبلغ عن أي شخص أو احظره من داخل المحادثة
• نزّل نسخة من بياناتك أو احذف حسابك من داخل التطبيق
• سجّل الدخول بحساب Apple أو Google أو Microsoft، دون كلمة مرور جديدة تحفظها

بالعربية والإنجليزية
يعمل التطبيق كاملًا بالعربية والإنجليزية، باتجاه من اليمين إلى اليسار في العربية، ويمكنك تغيير اللغة متى شئت.

الاشتراكات
الدروس والواجبات والدرجات والحضور مجانية. أما Family+ فاشتراك شهري اختياري لأولياء الأمور. يُخصم المبلغ من حساب Apple عند تأكيد الشراء، ويتجدد الاشتراك تلقائيًا ما لم تلغه قبل نهاية الفترة الحالية بأربع وعشرين ساعة على الأقل. ويمكنك إدارته أو إلغاؤه من إعدادات حسابك في App Store.

للأسئلة والملاحظات: hello@studafy.com
سياسة الخصوصية: https://studafy-legal.studafy.workers.dev/ar/privacy
شروط الاستخدام: https://studafy-legal.studafy.workers.dev/ar/terms
```

**Optional AI block** (B1). If AI is on at launch, paste it after the
"للطلاب" section:

<!-- field: ios.ar.ai max=4000 adds-to=ios.ar.description -->
```text
المساعدة في المذاكرة
• اسأل مساعد الدراسة عن دروسك وملاحظاتك
• Studafy Plus: حوّل الدرس أو صورة السبورة إلى ملاحظات للمذاكرة، واحتفظ بدفاتر مذاكرة فيها التظليل والإشارات المرجعية
• Studafy Max: اختبارات وبطاقات مراجعة من دروسك
يعتمد مساعد الدراسة على خدمة ذكاء اصطناعي، وقد تخطئ إجاباته، فتحقّق منها مع معلمك. لا تُرسَل إليه الأسماء ولا عناوين البريد الإلكتروني ولا الدرجات. Studafy Plus وStudafy Max اشتراكان شهريان اختياريان يُدفعان ويتجددان مثل Family+، ويستطيع الطالب أن يطلب موافقة ولي أمره على الشراء.
```

### Keywords

An Arabic letter is two bytes, so the Arabic list holds fewer words.

<!-- field: ios.ar.keywords max=100 unit=bytes -->
```text
معلم,طالب,ولي أمر,مدرسة,صف,درجات,حضور,اختبار,واجب,تعليم
```

### What's new

<!-- field: ios.ar.whatsnew max=4000 -->
```text
أول إصدار تجريبي من ستودافاي. جرّب تسجيل الدخول، والانضمام إلى صف برمز، والدروس، وتسليم واجب بصورة أو ملف، واختبارًا إلكترونيًا، والدرجات والحضور والرسائل، بالعربية والإنجليزية. أخبرنا بأي خطأ أو أمر غير واضح: hello@studafy.com
```

---

## Character counts

Generated by `bun scripts/store/check-listing.ts --write`; do not edit by
hand. Characters are UTF-16 code units, as the consoles count them, so Arabic
diacritics count. Keywords are UTF-8 bytes, as Apple counts them. A row
`x + y.ai` is the description with the optional AI block added.

<!-- counts:start -->
| Field | Count | Limit | Unit | OK |
|---|---:|---:|---|---|
| `play.en.title` | 27 | 30 | characters | yes |
| `play.en.short` | 79 | 80 | characters | yes |
| `play.en.full` | 2669 | 4000 | characters | yes |
| `play.en.full + play.en.ai` | 3198 | 4000 | characters | yes |
| `play.en.whatsnew` | 257 | 500 | characters | yes |
| `play.ar.title` | 26 | 30 | characters | yes |
| `play.ar.short` | 77 | 80 | characters | yes |
| `play.ar.full` | 2334 | 4000 | characters | yes |
| `play.ar.full + play.ar.ai` | 2814 | 4000 | characters | yes |
| `play.ar.whatsnew` | 227 | 500 | characters | yes |
| `ios.en.name` | 27 | 30 | characters | yes |
| `ios.en.subtitle` | 22 | 30 | characters | yes |
| `ios.en.promo` | 138 | 170 | characters | yes |
| `ios.en.description` | 2819 | 4000 | characters | yes |
| `ios.en.description + ios.en.ai` | 3381 | 4000 | characters | yes |
| `ios.en.keywords` | 94 | 100 | UTF-8 bytes | yes |
| `ios.en.whatsnew` | 257 | 4000 | characters | yes |
| `ios.ar.name` | 26 | 30 | characters | yes |
| `ios.ar.subtitle` | 25 | 30 | characters | yes |
| `ios.ar.promo` | 138 | 170 | characters | yes |
| `ios.ar.description` | 2465 | 4000 | characters | yes |
| `ios.ar.description + ios.ar.ai` | 2974 | 4000 | characters | yes |
| `ios.ar.keywords` | 100 | 100 | UTF-8 bytes | yes |
| `ios.ar.whatsnew` | 227 | 4000 | characters | yes |
<!-- counts:end -->

---

## Screenshots

### What was taken

The real app (a debug build), signed in to a synthetic school, with **AI
off and messaging off**, as launch was planned when they were taken. Both
are now on at launch (DL-062, DL-063; decisions 1, 2 and 7 above). Since
PR #86 the app shows nothing the server has switched off, so these pictures
show what a user sees with both off:

- **No AI:** no Helper tab, no plans, no study tools, no AI buttons in the
  notebook. The API ran with no AI key, so nothing was sent to a provider.
- **No messaging:** the API ran with `MESSAGING_ENABLED` off (DL-061) and
  the school's own switch off. The student's and the teacher's last tab is
  the school's **Announcements**, and the parent has no Messages tab and no
  "Message a teacher".

Two sets, the same walk on each:

- **App Store:** an **iPhone 18 Pro Max simulator** (iOS 27), 1320 × 2868,
  the 6.9" size. The status bar is overridden to 9:41 with full bars.
  `ios/en/<name>-en.png` and `ios/ar/<name>-ar.png`.
- **Google Play:** an **Android 16 emulator** (Google APIs, arm64) set to a
  **1080 × 2160** phone screen at 420 dpi. That is exactly 2:1, the longest
  Play allows (the iPhone's 2868 / 1320 is 2.17, and the stock 1080 × 2400
  Pixel profiles are 2.22). The status bar is in Android's demo mode: 9:41,
  full battery and Wi-Fi, no notifications, no mobile icon. Navigation is
  by gesture, so only the thin handle shows. `android/en/<name>-en.png` and
  `android/ar/<name>-ar.png`, the Play launch set only.

Both:

- **Data:** the school is seeded through the real `/v1` API. Its local API
  runs on a throwaway Supabase stack, never the working database or the
  hosted one.
- **Names:** every name is fictional, and every email is at
  `synthetic.studafy.test`.
- **Arabic:** the Arabic school has its own Arabic content, so every Arabic
  picture is right to left throughout. "Family+" in the parent's tab bar
  reads correctly (it showed as "+Family" before PR #86), and the due-date
  time zone reads "(Asia/Amman)". The status bar stays in the device's
  language.
- **Format:** 24-bit RGB PNG with no alpha channel, as both stores ask.
  `scripts/store/compress-screenshots.ts` removed the simulator's alpha
  channel losslessly.

| # | Name | Shows |
|---|---|---|
| 1 | `teacher-1-today` | Teacher home: classes, students, quick actions |
| 2 | `teacher-2-classes` | Classes with students, sessions a week and rooms |
| 3 | `teacher-3-lessons` | Teaching: published lessons |
| 4 | `teacher-4-grade-sheet` | A paper test's grade sheet: published marks, weight, corrections |
| 5 | `teacher-5-online-exam` | An online exam's submissions to mark; absences never count as zero |
| 6 | `teacher-6-messages` | A conversation with a parent (not taken: messaging is off) |
| 7 | `student-1-today` | Student home: quick actions and classes |
| 8 | `student-2-notebook` | The student's own notebook for a class |
| 9 | `student-3-homework` | Homework to do, with due dates |
| 10 | `student-4-grades` | Published marks with the teacher's feedback |
| 11 | `student-5-exam` | Taking an online exam: single answer, true or false, multiple answers |
| 12 | `parent-1-today` | Parent home: the linked child |
| 13 | `parent-2-progress` | The child's average of published marks and attendance |
| 14 | `parent-3-announcements` | Class announcements, one marked important |
| 15 | `parent-4-messages` | The same conversation, from the parent's side (not taken: messaging is off) |

**Launch set** (decision 7). Google Play shows up to 8 phone screenshots;
the App Store takes up to 10 per language.

- **Google Play:** 1, 5, 4, 11, 9, 10, 12, 14, from `android/`.
- **App Store:** the same from `ios/`, then 13 and 2.

`ios/` also has 3, 7 and 8, which are not in the launch set. Messaging
launches (DL-063): take 6 and 15 (start the API and seed with
`--messaging on`), and retake the pictures whose tab bars change: 1, 9, 10,
12 and 14. AI launches too (DL-062): retake the student pictures if they
should show it.

### Taking them again

From the repo root:

1. Start a throwaway stack. Copy `supabase/config.toml` to
   `<dir>/supabase/config.toml` with its own `project_id` and ports, symlink
   `supabase/migrations` into it, then run
   `bunx supabase start --workdir <dir>` (or `db reset` on an existing one).
2. Start the API:
   `bun --no-env-file scripts/store/local-api.ts --workdir <dir> --port 8095`.
   It has no AI key, so the AI tools are off, and messaging is off unless
   you add `--messaging on`, which matches production (DL-063).
3. Seed:
   `bun --no-env-file scripts/store/seed-store-school.ts --workdir <dir>`
   (with `--messaging on` to match the API).
4. **App Store:** boot an iPhone Pro Max simulator, then run
   `scripts/store/capture-ios.sh <dir> <simulator udid> en`, and the same
   with `ar`.
5. **Google Play:** boot one phone emulator whose AVD `config.ini` has
   `hw.lcd.width=1080` and `hw.lcd.height=2160`. Give it a minute after
   booting, then run
   `scripts/store/capture-android.sh <dir> emulator-5554 en` (and `ar`).
   - It needs JAVA_HOME; Android Studio's `jbr` works.
   - It keeps every screen it walks: keep only the eight of the launch set.
6. **Between runs:** reset and re-seed between devices, because the student
   starts the exam. Each language's school is separate, so `en` then `ar`
   on one seed is fine. `STORE_ONLY=teacher` or `STORE_ONLY=parent` repeats
   a walk that changes nothing.
7. **Look at every picture.** On a loaded machine, a screen can be caught
   showing "could not be loaded", or with a "System UI isn't responding"
   dialog and no demo clock. Run that walk again.
8. **Remove the alpha channel** (App Store Connect refuses it):
   `bun add --no-save sharp@0.34 && bun scripts/store/compress-screenshots.ts`.
   Add `docs/store/screenshots/android` to do the Play set.

The seed makes one direct database write, explained in the script: it
moves the enrolment start dates back to the start of term, so past
attendance can be recorded. With `--messaging on` it makes a second: it
turns the school's own messaging switch on, which only a school
administrator may change through the API, and this release has none.

---

## Where each claim comes from

| Claim | Code |
|---|---|
| Teachers start on their own (no school setup) | `POST /v1/onboarding/teacher-workspace`; `lib/app/onboarding_page.dart` |
| Classes, timetable, class code or link | `lib/features/classes/presentation/classes_page.dart`, `create_class_dialog.dart`; `lib/features/academic/presentation/class_schedule_page.dart`; `join_class_page.dart` |
| Lessons with notes, files and links; PDF, Word, PowerPoint, images | `lib/app/teacher_create_actions.dart`; `lib/core/attachment_policy.dart` |
| Homework, due date, hand-ins, extra time | `create_assignment_page.dart`, `submissions_page.dart` (`deadlineExtend`) |
| Online exams, five question types, automatic marking where there is a key, answer release | `assessment_builder_page.dart`, `question_editor.dart`, `assessment_marking_page.dart`; `private.assessment_auto_mark` in `supabase/migrations/202610060001_online_assessments.sql` |
| One gradebook for paper and online; private until published; corrections with a reason and history | `gradebook_home_page.dart`, `paper_gradebook_page.dart`, `grade_correction_sheet.dart`; policy §2 |
| Attendance: present, absent, late, excused | `attendance_page.dart`; `POST /v1/attendance/record` |
| Wellbeing notes | `create_wellbeing_page.dart` (Data safety decision 6) |
| Announcements | `create_announcement_page.dart`, `announcements_page.dart` |
| [messages] Messages, report and block | `lib/features/messaging/`; `safety_sheets.dart`, `blocked_people_page.dart`; DL-049 (no student-to-student messages); on at launch (DL-063) |
| Lessons by date, own notebook per class (free) | `lib/app/student_lessons_page.dart`; `notebook_view.dart`; `policyTermsBody` |
| Hand-ins as text, photos or documents | `submit_work_page.dart`; `attachment_policy.dart` |
| Students see published marks, feedback, attendance | `lib/app/student_shell.dart` (Work tab feeds) |
| Parent links with Studafy ID; child approves | `family_home_page.dart`, `student_family_page.dart`; `onboardingParentBody` |
| Child accounts without email; switching accounts | `create_child_account_page.dart`; `lib/app/account/account_switching.dart`; ADR-0031; policy §3.1 |
| Family+ contents | `lib/features/family_insights/presentation/family_insights_page.dart` (`insightsFocusTitle`, `insightsProgressTitle`, `insightsByClass`, `insightsMissingTitle`, `insightsMissedTests`); computed from records, no AI (`apps/api/src/family-insights/analysis.ts`) |
| No ads, never sold | Data safety Section 4; policy §2 |
| Data download and account deletion in the app | `lib/app/account/data_export_tile.dart`; `delete_account_page.dart` |
| Sign-in providers | `lib/features/session/presentation/login_page.dart`; Apple only on iOS with `APPLE_SIGN_IN_ENABLED` |
| English and Arabic, right to left, change any time | `lib/core/language_picker.dart`, `locale_controller.dart` |
| Free: lessons, homework, marks, attendance | `policyTermsBody` ("Lessons, notebooks, work, marks and attendance are free") |
| AI block: helper, Plus (whiteboard and lesson notes, study notebooks), Max (quizzes, flashcards), parent approval, what is never sent | `lib/features/study/presentation/study_plan_copy.dart`, `study_plans_page.dart`; `study_notebook_shelf.dart`; policy §2 and §6 |
