# Arabic glossary

The Arabic words the app uses for its own terms. `lib/l10n/app_ar.arb` and
the Arabic store copy follow this list; change it here first, then the
strings.

The audience is Jordanian schools (school time zone `Asia/Amman`), written in
Modern Standard Arabic.

| English | Arabic | Notes |
| --- | --- | --- |
| Studafy (the app) | ستودافاي | In running Arabic text. Never ستدفاي or other spellings. |
| Studafy Plus, Studafy Max, Family+ | Studafy Plus, Studafy Max, Family+ | Plan names stay in Latin letters, as the store lists them. "a Studafy plan" is إحدى خطط ستودافاي. |
| class (a group of students and its teachers) | صف | Plural صفوف; my classes صفوفي; your classes صفوفك; this class هذا الصف; create a class إنشاء صف. |
| term, semester | الفصل (الدراسي) | Only for a school term: منتصف الفصل (midterm), امتحان الفصل الأول (Term 1 exam), هذا الفصل (this term). |
| chapter (of a book) | فصل | Only for a chapter, never for a class. |
| lesson | درس | Plural دروس. |
| period (one meeting of a class on the timetable) | حصة | Plural حصص. |
| notebook | دفتر | The student's own notebook for a class. There is no product called "Student Notebook" (دفتر الطالب) any more. |

## Why صف

صف is the usual word for a school class in Jordan, and the app already used
it far more often than فصل. On 2026-10-15 every Arabic string that used
فصل or فصول for a class was changed to صف or صفوف, so فصل now means only a
term or a chapter.

## Directional text

A Latin identifier inside an Arabic sentence, such as a time zone id
(`Asia/Amman`), is wrapped in a left-to-right isolate by the code that
inserts it (`studafyTimeZone` in `lib/core/studafy_formatting.dart`), not in
the translation. Keep the placeholder and its brackets in the translation as
they are: `({zone})`.
