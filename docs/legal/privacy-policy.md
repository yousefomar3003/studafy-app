# Studafy Privacy Policy

**Last updated:** 21 October 2026\
**Version:** 1.7

<!--
BEFORE PUBLISHING ON THE OWN DOMAIN - READ THIS (never rendered: the legal
site's build strips every HTML comment).

This policy was written from the application's actual data flows: every
table, every third party and every transfer described below was taken from
the code and the database, not from a template. That makes it accurate, but
accuracy is not the same as legal sufficiency. It has not been reviewed by a
lawyer, and it must be. Studafy processes the personal data of children.

It is published temporarily at /privacy (ops/legal-site, launch plan 4.3)
because Google Play needs a link. The open items are in TODO(legal)
comments next to the text they affect, and in the list at the end.

The in-app summaries (policyPrivacyBody and policyTermsBody in
lib/l10n/app_en.arb and app_ar.arb) must say the same things as this
document and terms-of-use.md. Version 1.3 corrected facts (regions,
providers, what deletion removes) without a new consent version. Version 1.4
(approved by counsel for publication, 14 October 2026) sets the retention
periods (DL-057) and changes what the app says about deleting records, so
it is consent version 2026-10-14 (termsPolicyVersion in
lib/core/account_lifecycle.dart). A substantive change needs a new consent
version and a bump of termsPolicyVersion.

Version 1.5 (17 October 2026) was published by the owner's decision WITHOUT
legal review (DL-068), to make the policy match what the app does at launch:
AI on (DL-062, ADR-0043), messaging with one report reviewer (DL-063,
DL-066), no meeting creation (DL-065), backups in Cloudflare R2 (PR #69),
the export (DL-060, PR #72), helper photos kept 30 days (DL-060) and the
inactive-account warning (PR #73). It is consent version 2026-10-17
(migration 202610170010). Counsel is to review it later; the questions are
in docs/legal/questions-for-counsel-2026-10.md.

Version 1.6 (21 October 2026), consent version 2026-10-21 (migration
202610210020), with terms of use 1.4: students subscribe to Studafy Plus or
Max themselves, with no approval step in Studafy, and the app no longer
records a parent's approval of a purchase (DL-071). §2, §3.9 and the list
of changes; nothing else. Published by the owner's decision without legal
review, like 1.5.

TODO(legal): DL-071. Review §3.9 and the summary: a child's purchases are
paid from a store account a parent should own or control, approved (if at
all) with Google Family Link or Apple Ask to Buy, which Studafy does not
see; approval requests recorded before 21 October 2026 are kept as billing
records. Confirm the wording and that nothing else in the policy needs to
change for purchases by children.

Version 1.7 (21 October 2026), consent version 2026-10-22 (migration
202610210040_terms_and_privacy_2026_10_22.sql), with terms of use 1.5 and
AI notice 2026-10-22: students no longer need a class (DL-072, ADR-0045).
The AI study tools are for every student account, in a class or not, after
the AI consent; the study helper is now called the AI Tutor; a student has
a personal notebook that belongs to no class; photos and screenshots from a
student in no class are read once and not stored; Studafy Max students can
practise with quizzes and flashcards made from their own notes, which are
not stored on our servers. §1, §1.1, §2, §3.3, §3.4, §3.8, §3.10, §5, §6,
§7.1, §9, §10, §11, §13 and the list of changes. This reverses version
1.6's "The AI study tools are only for students in a class" (§5) and
ADR-0043's decision to limit AI to students in a class. Published by the
owner's decision without legal review, like 1.5 and 1.6.

TODO(legal): DL-072. A child can now sign up and use Studafy, including the
AI study tools, with no school and no class, so no school stands between
the child and us. Review §5 (the opening bullets replace "We do not
knowingly permit a child to create an account outside a school context
where their country requires parental consent for it"), §1.1 (Studafy as
controller for students with no class and for personal notes), §6 (who can
use the tools; photos not stored for students with no class) and §10. The
age and parental-consent questions in §5 are now more pressing
(questions-for-counsel 9.1).

The Arabic translation is docs/legal/ar/privacy-policy.md. Change both
together.
-->

### What changed in version 1.7

- A student does not need a class to use Studafy. Joining a class is
  optional; a student can join one later with a code or link from a
  teacher (§3.3, §5).
- The AI study tools are for every student account, in a class or not,
  after the separate AI consent (a parent's, for a child account the parent
  manages). Parent and teacher accounts still cannot use them. Names Studafy
  knows are still replaced before anything is sent, and photos are still
  sent as they are (§2, §5, §6).
- The study helper is now called the **AI Tutor** (§6).
- A student has a **personal notebook** that belongs to no class. Only the
  student can see it, not a teacher and not a parent. Typed notes are free;
  notes made by AI from a photo or screenshot need Studafy Plus. A student
  can now edit and rename their notes. Personal notes are in the data export
  and are deleted with the account (§3.4, §6, §7.1, §9, §11).
- A photo or screenshot from a student who belongs to no class, sent to the
  AI Tutor, and any photo or screenshot turned into a personal note, is
  **not stored**: it is checked and redrawn on our servers, sent once to the
  AI provider, and discarded. Photos students in a class send to the AI
  Tutor are kept for 30 days, as before (§3.8, §6, §10).
- Studafy Max students can make quizzes and flashcards from their own
  notes. These are not stored on our servers; the app holds them while the
  student practises (§3.10, §6, §10).

### What changed in version 1.6

- Students subscribe to Studafy Plus or Studafy Max themselves, in the app.
  Payment comes from the store account on the phone; Studafy no longer asks
  a parent to approve a purchase, and no longer records such approvals. For
  a child, a parent controls purchases with the store's own tools (§2,
  §3.9).

### What changed in version 1.5

- The AI study tools are switched on, for students in a class only, after a
  separate consent (a parent's, for a child account the parent manages).
  Names Studafy knows are replaced before anything is sent; photos are sent
  as they are. Photos sent with a study helper question are kept for 30
  days. Our agreement with the AI provider is not yet in place (§6, §8).
- Safety reports are reviewed by Studafy, which may act on them; each new
  report sends an alert, without its content, to our private Telegram chat
  (§3.6, §3.7).
- Studafy does not create meetings. A meeting link a teacher shares opens in
  Google Meet, under Google's terms; Google Calendar is no longer one of our
  providers (§3.6, §7.2).
- Our providers: Cloudflare stores our encrypted backups in the EU, relays
  our alerts, runs the bot check and serves these pages; Telegram carries
  our alerts; GitHub no longer stores backups; the outside malware scanner
  is gone, because we scan files ourselves (§7.2, §8).
- Inactive accounts: the warning before deletion is always emailed, and
  shown in the app too for people in a school. If it cannot reach the
  person, we do not delete the account (§10).
- The data export: what it contains, how to get your files, and what it
  leaves out (§11).

### What changed in version 1.4

- How long we keep things: fixed periods for academic records, messages and
  files (12 months after a class is closed, unless the school sets its
  own), security and access logs (2 years), consent and account-deletion
  records (6 years after the account), billing records (6 years after the
  tax year), inactive accounts (deleted after 2 years without a sign-in,
  with a warning 30 days before), sign-in IP addresses held by Supabase,
  and error reports (§3.2, §10).
- Role changes are kept for 2 years rather than permanently (§3.3, §9).
- When an account is deleted, the record of what it agreed to is kept for
  6 years, and audit records are deleted when their period ends (§9).
- Uploaded files are checked for malware on our own infrastructure in
  Frankfurt, not by an outside provider (§7.2).

---

## 1. Who we are

Studafy is a school application used by teachers, students and parents. It
lets a teacher run classes, share lessons, set and mark work — including
work done on paper — record attendance, and communicate with students and
their guardians. It lets a student see and hand in that work and keep their
own notes, and it lets a parent follow their child's progress. A student can
also use Studafy on their own, without a class: their personal notebook and
the AI study tools need no class.

**Data controller:** Studafy Limited, a company registered in Ireland under
number 822430, with its registered office at 4/5 The Square, Cahir,
Co. Tipperary, Ireland.

**Contact for privacy questions:** hello@studafy.com

**Where to find this policy:** legal.studafy.com/privacy, in English and
Arabic, with the Terms of Use at legal.studafy.com/terms.

<!-- TODO(legal): Data Protection Officer. Either name one, or state "We have
not appointed a Data Protection Officer because we are not required to under
Article 37 GDPR." Take advice first: systematic monitoring of children at
scale is exactly the case where one is usually required. -->

**EU/EEA supervisory authority:** The Data Protection Commission (Ireland),
21 Fitzwilliam Square South, Dublin 2, D02 RD28. www.dataprotection.ie

**Jordan:** Users in Jordan are additionally protected by the Personal Data
Protection Law No. 24 of 2023. Where that law gives you stronger rights than
this policy describes, those stronger rights apply.

### 1.1 Who is the controller of what

This distinction matters, and it is not a technicality.

- **Where a school uses Studafy**, the school generally decides what student
  records exist and why. In those cases the school is the **controller** and
  we act as a **processor** on its instructions. Your first point of contact
  for records about a student is your school.
- **Where an individual teacher signs up on their own** and creates their own
  classes, we act as the **controller** for that account, because there is no
  school instructing us.
- **Where a student uses Studafy without a class**, and for every student's
  **personal notebook**, which belongs to no class, we act as the
  **controller**, for the same reason.
- **For our own operation of the service** — security, fraud prevention,
  safety reports, billing, backups, keeping the service working — we are
  the controller regardless.

If you are unsure which applies to you, ask us and we will tell you.

<!-- TODO(legal): whether reviewing safety reports (§3.7) and the AI study
tools (§6) make Studafy a controller even where a school is controller of
the class's records (DPIA draft §5). -->

<!-- TODO(legal): DL-072. Confirm that Studafy is the controller for a
student with no class and for personal notes, including those of a student
whose class belongs to a school that is itself the controller. -->

---

## 2. A short summary

The long version follows, and it governs. This summary is for orientation.

- We collect what the app needs to work: who you are, which class you are in
  (if any), the lessons and work in it, your marks and attendance, your own
  notes, and the messages you send inside the app.
- Teachers' marks stay **private until the teacher publishes them**. A
  published mark that is later corrected keeps a record of the old mark, who
  changed it, when and why, and the family is told when the mark changes.
- We do **not** sell personal data, use it for advertising, or build
  advertising profiles. We show no advertising, and the app contains no
  advertising or analytics software.
- Subscriptions are billed by **Apple** and **Google**, not by us, from the
  store account on the phone. A student can subscribe in the app; for a
  child, a parent controls purchases with Google Family Link or Apple's Ask
  to Buy. We never see card details.
- **Optional AI study tools send content to an AI provider outside the
  app**, Together AI: the question a student types and the recent turns of
  the same chat, and — where a student uses them — a photo they attach, a
  lesson's text, or their own notes. Any student account can use them,
  whether or not it belongs to a class, but only after agreeing to them
  separately (for a child account a parent manages, the parent agrees).
  Parent and teacher accounts cannot use them. Names Studafy knows are
  replaced before anything is sent, and email addresses and marks are never
  sent; **photos are sent as they are**. A photo from a student who belongs
  to no class is not kept. See §6 and read it before using those tools.
- If someone reports a message or a person, **Studafy reviews the report**
  and may act on it (§3.7).
- Children's data is treated as sensitive in practice, whatever its formal
  classification.
- You can ask for a copy of your data, or for your account to be deleted,
  from inside the app or by writing to us.

<!-- TODO(legal): photos are sent to the AI provider unchanged
(questions-for-counsel 1.4; ADR-0043). Version 1.5 says so here and in §6,
and asks everyone to accept again (consent version 2026-10-17). Confirm the
wording, and whether the separate AI notice (aiConsentNoticeBody, version
2026-10-15, which already says so) is enough on its own. -->

---

## 3. The personal data we process

### 3.1 Account and identity

| What | Why | Where it comes from |
|---|---|---|
| Name (display name) | To show who you are to your class | Your sign-in provider, or you |
| Email address | To identify your account and send service messages | Your sign-in provider |
| Sign-in provider identifier | To recognise you on return | Google, Microsoft or Apple |
| Studafy ID (a number) | So a parent can ask to link to a student | Generated |
| Language preference | To show the app in your language (English or Arabic) | You |
| Gender (male, female or prefer not to answer) | To address you correctly; it is shown to nobody else, including your school | You |
| Account status and creation date | To operate the account | Generated |

**We do not store passwords.** You sign in with Google, Microsoft or Apple,
and only they verify your credential. We receive a confirmation that it was
you, plus your name and email. If Apple shares your full name, the app does
not pass it on to us.

**Child accounts a parent manages.** A parent can create a student account
for a child who has no email address or phone of their own. The parent gives
the child's name and accepts these terms on the child's behalf; the account
has an internal address that receives no email. The parent opens the child's
account from their own, using a single-use sign-in we issue only to that
parent. We record which parent manages which child account.

**Several accounts on one device.** You can add more than one account to the
app on the same device and switch between them. Each account's session and
cached data are kept apart, and signing one out clears its data from the
device.

### 3.2 Devices and sessions

We record which devices hold a session for your account, when each was last
used, and a coarse description of the device (for example "iPhone, version
2.3"). This is what lets you see where you are signed in and sign out a
device you no longer have. If you allow notifications, we also hold your
device's push token.

We record security events on your account — sign-ins, sign-outs, session
revocations, two-factor enrolment and changes to linked sign-in identities.

**IP addresses.** We use your IP address to apply rate limits and to detect
abuse. In our own records, logs and rate-limit counters we do **not** store
it in readable form: it is converted to a keyed one-way hash first, so our
records show that two requests came from the same source without recording
where that source is. The service that handles sign-in for us (Supabase)
keeps the IP address of sign-in events in its own security logs for up to 7
days, and stores it with an active session until that session ends.

### 3.3 School, class and role

Which school or teaching space you belong to, your role in it (teacher,
student, parent or guardian), when that role was granted, and whether it is
currently active. A teacher who signs up on their own gets their own teaching
space. Changes to roles are recorded and kept for 2 years — see §9 and §10.

**There is no school administrator in this version of Studafy.** Nobody
holds that role, and no school administrator can see or change a class's
work, marks or attendance. A class's records are read and changed by that
class's own teachers.

For students we also hold a class roster entry, your enrolment in each class,
the class code or link you joined with, and an internal student identifier
used to link a parent to their child.

**A student does not have to join a class.** A student can sign up and use
Studafy on their own, and join a class later with a code or link from a
teacher. Until then we hold no school, class or roster entry for them.

### 3.4 Academic records

This is the substance of the service.

- **Timetable and lessons:** each class's weekly schedule, the lessons taught,
  and when a lesson's content was filed.
- **Lesson content:** lessons, notes and files a teacher shares, every
  version of them, and when each was published.
- **Work set:** assignments, exams and quizzes (answered in the app or done
  on paper), their questions, due times, closing times, the files the teacher
  attached, and how much each kind of work counts where a teacher sets a
  weight.
- **Work handed in:** each hand-in (attempt), the text and files in it, when
  it was handed in, whether it was late, and — where a parent handed it in
  for a child — which parent did. A student can replace their work until the
  deadline; every earlier attempt is kept.
- **Deadlines and extensions:** when the teacher reopened work for the class,
  and any extra time given to one student, with the reason the teacher gave.
  Deadlines are set and shown in your school's time zone.
- **Marks:** for work done online and on paper — a score, "absent" or "not
  graded", and the teacher's comment. **A mark is a draft, visible only to
  the class's teachers, until the teacher publishes it.** A student with no
  mark is shown as not marked, never as zero.
- **Changes to marks:** every publication and every correction of a mark,
  with the previous mark and comment, the new ones, who made the change, when,
  and the reason the teacher gave — see §9.
- **Attendance:** present, absent, late or excused for each lesson, with any
  reason the teacher recorded. After the lesson's day a changed mark needs a
  reason; after seven days only the class's lead teacher can change it. Every
  change is kept with the previous mark, who changed it, when, the reason, and
  whether a lock was overridden — see §9.
- **Wellbeing notes:** pastoral observations recorded by teachers.
- **A student's own notebook:** notes a student writes for each class, photos
  of the board they take, and study notebooks, notes, quizzes and flashcards
  they make with the tools in §6, with their own notes, highlights and
  bookmarks.
- **A student's personal notebook:** notes that belong to no class — notes
  the student types, and notes made by AI from a photo or screenshot the
  student adds (§6). A student can edit and rename any of their own notes.

**Personal notes are visible only to the student.** No teacher and no
parent can see them, and joining a class later does not change them. They
are included in the data export (§11) and deleted with the account (§9).

Wellbeing notes and pastoral records can be sensitive. They are visible only
to the class's teachers, and to a family only where a teacher chooses to
share a note with them. They are never visible to other students.

### 3.5 Family links and Family+

A parent is connected to a student by a **guardian link**. To create one, a
parent enters the student's Studafy ID; **the student then approves or
declines the request on their own device**. We record who asked, who
approved, when, and the stated relationship. A child account a parent
created is linked to that parent automatically.

A parent who is linked to a student can see that student's published marks,
attendance, set work and hand-ins, and the class material shared with
families, and can download the files in them. A parent can hand work in for
a young child who has no device of their own; the teacher sees that a parent
handed it in. A parent cannot change a child's marks or attendance, and is
**not** given access to the student's private messages.

**Family+** is an optional paid plan for parents, held by the parent who
buys it. One plan covers up to 4 linked children and a larger plan up to 8,
in the order the children were linked; a child linked later is included
while the plan has room. For each child it covers, it summarises what the
parent can already see: marks by class with each class's trend, the child's
strongest and weakest class, marks over time, attendance, missing work and
tests the child missed, and what to focus on first. It compares a child only
with their own earlier record, never with other children. It is calculated
by our own software, not by AI, and it predicts or diagnoses nothing. Which
children a plan covers is worked out from the parent's own links each time
it is read; nothing extra about the children is stored for it.

### 3.6 Communication

Conversations and the messages in them, including voice notes, who is in
each conversation, when a message was delivered and read, announcements sent
to a class, and links to meetings that teachers share.

**Meetings:** Studafy does not host video calls and does not create
meetings. A teacher may share a link to a Google Meet call, for example in
an announcement. When you open it, the call takes place in Google Meet,
under Google's own terms and privacy policy; Studafy sends Google nothing
about you.

<!-- TODO(legal): creating Google Meet meetings through Google Workspace is
off (DL-065, MEETINGS_PROCESSOR_ENABLED unset). If it is ever switched on,
attendee email addresses go to Google: add Google Calendar and Meet back to
§7.2 and publish a new consent version first. -->

We also hold your notification preferences, your registered push devices, and
a record of which notifications were sent and delivered. Push and email
notifications carry fixed wording only — for example "New marks" — never a
name, a mark or a message.

**Messages are stored on our servers and are not end-to-end encrypted.** When
someone reports a message, a conversation or a person, Studafy's reviewer
reads what was reported in order to decide the report (§3.7). We may also
have to disclose messages where the law requires it, or where a child is at
risk (§7.3). Do not use Studafy messaging for anything you would not want
Studafy to be able to read if it were reported.

<!-- TODO(legal): version 1.4 said messages could also be read "by school
staff acting under school safeguarding policies". This release has no
school administrator and no school-side moderation, so 1.5 drops it.
Confirm that schools acting as controllers need no access route here. -->

### 3.7 Safety and moderation

Anyone can report a message, a conversation or a person, and block someone,
from inside the app. We hold the reports, the evidence attached to them,
what was decided, blocks between users, and the grants that allow a
reviewer to open a report.

**Studafy reviews reports.** There is no school administrator in this
version of the app, so reports come to us. A named person at Studafy, who
can be reached at hello@studafy.com, reviews each report. To open one, the
reviewer needs a time-limited access grant and a second sign-in factor, and
every grant, every opening of a report and every decision is recorded. The
reviewer does not see who made a report unless it has to be escalated.
After reviewing a report we may remove content, warn someone, or suspend or
close an account, and where a child is at risk we may tell those who need
to know in order to protect them (§7.3). The person who made the report is
told when it has been resolved.

**Alerts.** When a report is made, an alert goes to a private Telegram chat
used by our reviewer. It carries only the report's reference number, its
kind (message, conversation or person), its priority, the time, and a coded
(hashed) reference to the school — never the reported content, a name or an
account identifier. The reviewer reads the report itself in the app.

<!-- TODO(legal): for now one person reviews every report, with no second
person checking a grant or a decision (DL-063, DL-066; single-reviewer
mode). Confirm the response times we should commit to publicly, and whether
the reporter must be told the outcome rather than only that the report was
resolved (questions-for-counsel 5.1). -->

### 3.8 Files

Files you upload — documents (PDF, Word and PowerPoint), photos and voice
notes — what they are attached to, their size and type, scan results, and
time-limited grants permitting a specific person to download a specific
file. Every uploaded file is checked for malware, on our own servers, before
anyone can download it (§7.2).

**When a teacher replaces or removes a file.** If a teacher replaces a
lesson's file, or takes a file off an assignment, the class no longer sees
it, but **the file is kept for the school** and the class's teachers can still
open it. It is not deleted.

**Some photos are not stored.** A photo or screenshot that a student turns
into a personal note, and one that a student who belongs to no class adds
to an AI Tutor question, is not uploaded as a file. It is checked on our
servers, sent once to the AI provider and discarded (§6).

### 3.9 Billing

Whether you hold a subscription (Studafy Plus, Studafy Max or Family+), when
it started, renews and ends, and records of store transactions.

**We never receive your card number, bank details or billing address.**
Payment is taken by Apple or Google under their own terms and their own
privacy policies. We receive only a confirmation that a purchase or renewal
occurred, and an opaque transaction identifier. So that a purchase is
credited to the right account, the app gives the store an identifier for
your account that means nothing outside Studafy.

A student can subscribe to Studafy Plus or Studafy Max in the app. Payment
is made through Google Play or the App Store with the payment method on that
store account; Studafy does not ask a parent to approve the purchase and
records no approval. For a child, that account and its payment method should
belong to, or be controlled by, a parent or guardian, who is responsible for
purchases made with it. Google Family Link and Apple's Ask to Buy let a
parent approve purchases; that approval happens in the store, and Studafy
does not see it. Subscriptions renew until cancelled in the store, and
refunds follow the store's rules.

Before 21 October 2026 the app asked a parent to approve a student's
purchase. Those requests and decisions are kept as billing records (§10).
Where a parent buys a subscription for a child, we record who paid and which
child it is for.

### 3.10 AI usage

For the tools in §6, how much each account used them (the tool, the plan,
the amount used, the model and the date), so that the plan's allowance can
be applied. We store the notes, quizzes, flashcards and study notebooks a
tool made, not the conversation that produced them. Quizzes and flashcards
a student makes from their own notes are not stored on our servers. A photo
sent to the AI Tutor by a student in a class is kept for 30 days; one from
a student who belongs to no class is not kept (§6, §10).

### 3.11 Consents

Which version of these terms and this policy you accepted, and when — and,
for a child account, that the parent accepted them on the child's behalf.
Separately, whether the AI study tools were agreed to (§6): who agreed, for
whom, to which version of the notice, in which language and when, and who
withdrew that agreement and when.

### 3.12 Operational data

- **Audit records** of significant actions — see §9.
- **Technical logs** of requests: the time, the route, whether it succeeded,
  how long it took, a request identifier, your account identifier, a hashed
  IP and a coarse client type. Most successful requests are not logged at
  all. Logs are automatically stripped of passwords, tokens, keys and other
  secrets, and of message and file content, before they are written.
- **Error reports** when the app or our servers fail: what broke and where in
  the code, the device model, operating system and app version. They carry no
  name, email, account identifier, message content or photos.
- **Operations alerts** to our private Telegram chat when something in the
  service fails or falls behind: what failed, and counts. They carry no
  name, email address or message content.
- **Short-lived cache and rate-limit records**, keyed by hashed identifiers.

---

## 4. Why we process it, and on what legal basis

| Purpose | Legal basis (GDPR Art. 6) |
|---|---|
| Providing the app to a school's teachers and students | Contract with the school; the school's public task or legitimate interests as controller |
| Providing the app to an individual account holder | Performance of our contract with you |
| Keeping marks private until published, and a history of changes to marks and attendance | The school's legal obligations and legitimate interests in accurate records; legitimate interests in accountability |
| Telling a family when a mark is published or changed | Contract; legitimate interests in keeping families informed |
| Keeping accounts secure; preventing abuse; checking files for malware | Legitimate interests: protecting users, particularly children |
| Sending service messages you need to receive, including the warning before an inactive account is deleted | Contract; legitimate interests |
| Sending optional notifications | Consent, withdrawable in settings |
| Billing and subscription management | Contract |
| Keeping audit records and backups | Legal obligation; legitimate interests in accountability and recovery |
| Reviewing and acting on safety reports, and alerting our reviewer | Legitimate interests in protecting children; legal obligation where one applies |
| The AI study tools | Consent, given separately before first use — see §6 |
| Complying with the law, and defending legal claims | Legal obligation; legitimate interests |

Where we rely on **legitimate interests**, we have considered whether our
interest is overridden by your rights, and given particular weight to the
fact that many of our users are children. You may object to processing based
on legitimate interests — see §11.

**We do not use your personal data to train any AI or machine-learning
model.**

<!-- TODO(legal): once the data processing agreement with the AI provider is
signed and forbids training on our data, add: "and we do not permit our
providers to." Do not add it before. -->

---

## 5. Children

Studafy is designed for school use and most of its students are children.
A student can also use it on their own, without a class.

- A student's account is normally created by the student. **Joining a class
  is optional:** a student can use their personal notebook and the AI study
  tools without one, and join a class later using a code or link a teacher
  gives them. Belonging to a class is what makes a student's work visible to
  that class's teachers.
- We do not knowingly permit a child to use Studafy without a parent's
  consent where their country requires it. Where a child is too young to
  agree for themselves, a parent should create and manage the child's
  account (below).
- **A parent may create and manage an account for their child** who has no
  email or phone. The parent accepts these terms for the child and is
  responsible for how the account is used. The child's work in class is still
  the child's own record, visible to their teachers.
- **A parent cannot attach themselves to a child without the child's
  approval**, except to a child account that parent created. The request goes
  to the student, who accepts or declines it.
- **The AI study tools are for student accounts, in a class or not**, and
  need their own consent: a parent gives it for a child account they manage
  (§6).
- We do not profile children for advertising, and we show no advertising.
- Where a school is the controller, questions about a child's records should
  go to the school first.

If you believe a child has provided us with personal data in a way that
requires consent that was not given, contact us at hello@studafy.com and we
will investigate and, where appropriate, delete it.

<!-- TODO(legal): the age of digital consent (Ireland: 16) and whether a
parent's consent is needed for students under it outside a school
(decision log DL-037). -->

<!-- TODO(legal): Studafy holds no date of birth and has no age gate (DPIA
D3). A student who signs in themselves gives their own AI consent, whatever
their age; only managed child accounts get a parent's
(questions-for-counsel 1.3). Confirm, or give the age below which a parent
must consent and whether a linked parent should see or withdraw it. -->

<!-- TODO(legal): DL-072 (21 October 2026). Version 1.6 said children used
Studafy through a school ("We do not knowingly permit a child to create an
account outside a school context where their country requires parental
consent for it"). Students can now sign up and use Studafy, the AI study
tools included, without joining a class, so a child may use it with no
school involved at all. With no age gate and no date of birth, the two
TODOs above are now more pressing. Counsel to advise: the age of digital
consent that applies to a student with no school (Ireland: 16; and in
Jordan), when
a parent's consent is needed for the account and for the AI consent, whether
an age gate or age band is needed (DPIA M8), and whether the replacement
wording above is acceptable (questions-for-counsel 9.1). -->

---

## 6. The AI study tools

**Read this section before allowing a student to use them.** The AI study
tools are switched on. All of them are optional, and a student who does not
use them has nothing sent to the AI provider.

**Who can use them.** Every student account, whether or not it belongs to
a class, including a child account a parent manages. Parent and teacher
accounts cannot use them.

**A separate consent.** Before a student first uses any of these tools, the
app shows a short notice about them and asks the student to agree. This is
separate from accepting these terms. For a child account a parent manages,
the parent agrees, or declines, from their own account; the child cannot.
We record who agreed, for whom, to which version of the notice, in which
language, and when. The tools can be turned off at any time in Account,
or, for a child account, by the parent from that child's card in the
parent's own account. That withdraws the consent: nothing more is sent
after that. When we change the notice, everyone is
asked again.

| Tool | Who can use it | What is sent to the AI provider |
|---|---|---|
| **AI Tutor** (ask a question) | Every student, within their plan's allowance | The question typed, and the most recent turns of the same chat so a follow-up makes sense. Where the student chooses to, the text of the lessons and files they pick from their class, or of their own notes. |
| **Photos in the AI Tutor** (up to 3 a question) | Studafy Plus and Max | The photos or screenshots the student adds, with their question |
| **Whiteboard to notes** | Studafy Plus and Max | The photo of the board the student takes |
| **Notes from a photo or screenshot**, in the personal notebook | Studafy Plus and Max | The photo or screenshot the student adds |
| **Lesson summaries and study notebooks** | Studafy Plus and Max | The text of the lessons and files the student picks |
| **Quizzes and flashcards** | Studafy Max | The text of the lessons and files the student picks, or of their own notes |

With every request we also send the class's grade level (for example
"grade 7"), where the student is in a class, and the app's language, so
that the answer suits the student.

**Reading a teacher's file.** So that these tools can use a lesson's files,
we extract their text. Where a file is scanned or made of pictures, images of
its pages are sent to the AI provider to read the text from them.

**Before anything is sent**, we replace the names Studafy knows — the
student's own, their classmates', their teachers' and their parents' — with
words such as [student] or [teacher]. This applies to the question, the
chat, the lesson and note text, and their titles and file names. We also
remove email addresses, long number sequences and web links. If the names
cannot be checked, the request is not sent. Replacing names is done as well
as we can, not perfectly: a nickname, a misspelling or a name Studafy does
not hold can still get through, so do not type other people's personal
details.

**Photos are sent as they are.** A photo or screenshot added to a question
or turned into notes, a photo of the board and the images of a scanned
teacher's file go to the AI provider with what they show unchanged, so any
name or face in them is sent too. Do not photograph names or faces.

**Photos that are not stored.** When a student turns a photo or screenshot
into a personal note, or a student who belongs to no class adds one to an
AI Tutor question, we check it on our servers and redraw it as a new
picture, at most 1,600 pixels on its longest side, which leaves out hidden
details such as where it was taken. Only that copy is sent to the AI
provider, once. Then it is discarded: it is never saved as a file, and we
keep no copy. A photo a student in a class adds to an AI Tutor question,
and a photo of the board, are uploaded and kept as described below.

**What Studafy does not send:** the student's email, account identifier,
school or class name, their marks, their attendance, their messages, or
another student's work. No identifier of the student is attached to a
request.

**What we keep:** the notes, quizzes, flashcards and study notebooks a tool
produced. Notes and study sets made from a teacher's lesson are shared by the
students of that class, because they come from the teacher's lesson alone.
Notes and notebooks a student made belong to that student and are deleted
when they delete them or their account; notes in the personal notebook are
seen by nobody else. **Quizzes and flashcards a Studafy Max student makes
from their own notes are not stored on our servers**: the app holds them
while the student practises. **A photo a student in a class sends to the
AI Tutor is kept on our servers for 30 days after it was uploaded, then
deleted.** The photos described above as not stored are not kept at all. **AI Tutor chats are kept only on the student's device**, and
are deleted from it when the student signs out; we do not store them. An
answer is kept on our servers for about a day so that a request that is
sent twice gets the same answer.

**Our provider:** Together Computer, Inc. (Together AI), a company in the
United States, using the model `Qwen/Qwen3.5-9B`. Its processing may take
place outside the EEA, including in the United States. Our data processing
agreement with Together AI is not yet in place (see §8).

<!-- TODO(legal): state the provider's processing locations and its retention
of requests, from the signed DPA. -->

**Limits:** each plan has an allowance of how much AI it can use, shown in
the app as a bar. The free allowance renews every week and the paid plans'
every month.

**Accuracy:** answers and notes are generated by a language model and **can
be wrong**. They are study support, not a source of truth, and should never
be handed in as a student's own work. **AI never marks a student's work** in
Studafy; marks come only from teachers.

<!-- TODO(legal) - OUTSTANDING: the AI study tools are LIVE for children
from launch (DL-062, an accepted risk the owner took on 2026-10-16), but as
at the date above no data processing agreement is signed with the AI
provider, and no Data Protection Impact Assessment covering AI processing
of children's data (including photos and lesson material) has been
completed. Both are required: a written processor contract by Article 28(3)
GDPR, and a DPIA by Article 35. Both are pending: the owner is to accept
Together AI's DPA (questions-for-counsel 1.1), and counsel is to review the
DPIA draft (docs/legal/dpia-draft.md). The visible text above and §8 say
that the agreement is not yet in place; never claim it is signed until it
is. Counsel to review this section, the 30 days for helper photos (DL-060),
and the AI notice (aiConsentNoticeBody, version 2026-10-15). -->

<!-- TODO(legal): DL-072, ADR-0045. The AI notice is now version 2026-10-22:
it names the AI Tutor and says a photo from a student in no class is read
once and not kept, so every student is asked again. Counsel to review this
section's new text on who can use the tools (every student account, in a
class or not), photos that are not stored, and practice sets that are not
stored, together with the notice in English and Arabic. -->

---

## 7. Who we share data with

We do not sell personal data. We share it only as set out here.

### 7.1 Within your class

Your work, marks and attendance are visible to your class's teachers, and to
a parent linked to you once a mark is published. Draft marks are visible to
the class's teachers only. There is no school administrator in this version
of the app. Other students cannot see your marks, your submitted work or your
private messages. Your personal notebook is visible to you only: not to a
teacher, and not to a parent.

### 7.2 Our processors

Each of these acts on our instructions and may not use your data for their
own purposes.

| Provider | What they process | Where |
|---|---|---|
| **Supabase** (database, sign-in, file storage) | Substantially all application data | Frankfurt, Germany |
| **Fly.io** (application hosting) | Requests passing through our servers while they are handled | Frankfurt, Germany |
| **Axiom** (operational logs) | Technical logs: request times, outcomes and error codes, with account identifiers and hashed network addresses. Most successful requests are not kept; logs are deleted after 30 days | Frankfurt, Germany |
| **Sentry** (error reports) | What broke and where in our code, with the device model and versions. No names, emails, message content or photos | Germany |
| **Cloudflare** (backup storage, alerts, bot check, network, these pages) | Our encrypted daily backups, which Cloudflare cannot read, in its R2 storage; the relay that forwards our operations alerts; the Turnstile bot check when a parent looks up a student; requests to our API and to these pages as they pass through its network | Backups: EU (Cloudflare's EU jurisdiction). Otherwise global |
| **Telegram** (alerts) | Alerts to our own private chat: for a safety report, its reference number, kind, priority and a hashed reference to the school; for operations, what failed and counts. Never message content, names or account identifiers | Global |
| **GitHub** (Microsoft) (backup job) | Runs our daily backup job: the backup is made and encrypted on a temporary GitHub machine and sent to Cloudflare. GitHub keeps no copy of it | See §8 |
| **Redis** (rate limits, short-lived caches, background jobs) | Counters and cache entries keyed by hashed identifiers (including hashed IP addresses), background job references, and, for up to 30 seconds, a copy of your session details (name, language and roles) | See §8 |
| **Google** (Sign in with Google) | Your identity at sign-in | Global |
| **Microsoft** (Sign in with Microsoft) | Your identity at sign-in | Global |
| **Apple** (Sign in with Apple) | Your identity at sign-in | Global |
| **Together AI** (AI study tools) | What §6 lists | United States; see §8 |
| **Resend** (email) | Your email address and the fixed message | See §8 |
| **Google Firebase Cloud Messaging** (push) | Your device's push token and the fixed notification text | Global |
| **Apple** and **Google** (subscriptions) | Purchases, as independent controllers under their own policies | Global |

Uploaded files are checked for malware by a scanner we run ourselves, on our
own infrastructure in the EU (Frankfurt). Files are not sent to any outside
scanning provider.

<!-- TODO(legal): the role of Telegram (a recipient of alerts that carry no
content, names or account ids: processor, or not personal data at all?) and
Cloudflare's terms for R2, Workers and Turnstile (DPIA §4.2, D10). If the
optional second backup copy in AWS (EU regions only, .github/workflows/
backup.yml) is ever switched on, add Amazon Web Services to this table.
Requests to the API pass through Cloudflare once api.studafy.com is
proxied (launch plan C8, ORIGIN_REQUIRE_CLOUDFLARE in fly.api.toml); the
row already says so. -->

### 7.3 Others

- **Where the law requires it**, to a court, regulator or law enforcement
  body — and we will tell you unless we are prohibited from doing so.
- **Where a child is at risk**, to those who need to know in order to protect
  them.
- **To professional advisers** bound by confidentiality.
- **If our business is transferred**, to the acquirer, with notice to you and
  subject to this policy.

**Google Meet** is not one of our processors: when you open a meeting link,
Google provides the call under its own terms and privacy policy.

---

## 8. International transfers

Our main systems — the database, file storage, application servers, logs,
error reports and backups — are in the EU (Germany, and Cloudflare's EU
storage for backups). Some providers in §7.2 may process data outside the
EEA, and outside Jordan.

Where data leaves the EEA we rely on the European Commission's **Standard
Contractual Clauses**, or on an adequacy decision (such as the EU–US Data
Privacy Framework) where one covers the destination. You may request a copy
of the safeguards in place by writing to hello@studafy.com.

**The AI study tools are the exception for now.** Together AI is in the
United States. Our data processing agreement with it, and the transfer
safeguard that goes with it, are not yet in place; we will update this
policy when they are. Until then, if you do not want this data to go to
Together AI, do not turn the AI study tools on, or turn them off in your
account at any time (§6).

<!-- TODO(legal): confirm the mechanism for each provider in §7.2 before
publishing on the own domain - the AI provider, GitHub, Resend and the
scanner in particular. A provider in the United States without SCCs or
DPF certification is a transfer without a legal basis. -->

<!-- TODO(legal): version 1.5 note. The scanner is now self-hosted (no
transfer), and GitHub only runs the backup job (it keeps no copy). Add
Cloudflare (R2 EU jurisdiction, Workers, Turnstile) and Telegram to the
check. Together AI has no DPA and no transfer mechanism yet: the paragraph
above says so publicly, as the owner decided (DL-062, DL-068). Replace it
with the real mechanism once the DPA is accepted. -->

---

## 9. What deleting an account removes, and what it keeps

**When an account is deleted** (14 days after the request, see §11), we:

- remove the ability to sign in and erase the email address, name and
  sign-in details;
- replace the name on the profile, and on class rosters, with "Deleted user"
  or "Deleted student", and clear the gender;
- end every membership, guardian link and conversation the account was in;
- delete its devices and push registrations, notification settings and
  notifications, blocks, data exports, notebooks (personal notes included)
  and study notebooks, AI usage records, and personal photos (photos for
  the notebook or the AI Tutor);
- remove its email address from invitations;
- delete, in the same way, every child account the person manages: nobody
  else can sign in to a child account, so it cannot outlive its parent. The
  deletion screen names these accounts before the parent confirms.

Some records exist so that the service can be held to account, or belong to
the school, and are kept:

**Audit records.** Every significant action — creating a class, granting or
removing a role, saving, publishing or correcting marks, changing attendance,
giving extra time, editing a lesson, opening or deciding a safety report,
accessing a student's records under a support grant — is recorded with who
did it, what changed, and when. These records are append-only by design:
nobody can edit them, including us, and they are deleted only when their
period in §10 ends.

**Consent records.** The record of what you agreed to, and when — including
the AI consent — is kept for 6 years after the account is deleted (§10).

**The history of a mark and of attendance.** When a published mark is
corrected, or an attendance mark is changed, the previous value, the new
value, who changed it, when and why are kept for as long as the record
itself. This is so that a student, a family and the school can rely on a
record being accurate, and see how it changed.

**Earlier attempts and replaced files.** Every hand-in a student made, and
every file a teacher replaced or took off a lesson or assignment, is kept for
the school.

**Messages already sent.** A message you sent stays with the people you sent
it to, shown as from "Deleted user".

**Membership history.** The record that a role was granted, suspended or
revoked is kept even after the role ends, for 2 years from the change (§10).

**Education records.** Where a school is the controller, the school is often
legally required to keep attendance, assessment and safeguarding records for
a defined period. These stay with the school when your account is deleted.
The app shows you which records these are before you confirm a deletion.

**Payment records** are kept as tax and accounting law requires.

**Legal holds.** Where data is relevant to a legal claim or an investigation,
we may be required to preserve it until that concludes.

---

## 10. How long we keep things

| Data | Retention |
|---|---|
| Account and profile | While the account exists |
| Deletion grace period | 14 days from request, during which you can cancel |
| Academic records, marks, their history and attendance | Where a school is the controller: as the school's retention policy requires. Otherwise, or where the school has given no instruction: deleted 12 months after the class is closed or the teacher's account is deleted |
| Earlier hand-ins and replaced or removed files | As for academic records above |
| Messages and voice notes | While the conversation exists, subject to school policy; in any case deleted 12 months after the class is closed |
| Security and access logs (sign-ins, role changes, access to records) | 2 years |
| Consent records and records of account deletion | For the life of the account, then 6 years |
| Technical logs | 30 days |
| Rate-limit and cache records | Minutes to hours |
| Data exports | 7 days after they are ready |
| Backups | Encrypted, taken daily, kept for 30 days, then deleted |
| AI Tutor chats | On the student's device only, until they sign out; not kept by us |
| Photos sent to the AI Tutor by a student in a class | 30 days after upload, then deleted |
| Photos and screenshots turned into personal notes, and those a student who belongs to no class adds to an AI Tutor question | Not stored: sent once to the AI provider, then discarded |
| A student's personal notes | Until the student deletes them or their account |
| Notes, quizzes, flashcards and study notebooks made by the AI tools | Until the student deletes them or their account, or while the lesson they came from exists |
| Quizzes and flashcards made from a student's own notes | Not stored by us; the app holds them while the student practises |
| Billing records | 6 years after the end of the tax year they relate to |
| Files | While attached to something, subject to school policy; in any case deleted 12 months after the class is closed |
| Inactive accounts | Deleted after 2 years without use. At least 30 days before, we warn the account holder by email, whatever their email settings, and also in the app if they belong to a school. The 30 days count from when the warning reached them. If the warning cannot reach them, we do not delete the account |
| Sign-in IP addresses held by Supabase | Up to 7 days in its security logs, and with an active session until it ends |
| Error reports (Sentry) | Up to 90 days |

<!-- TODO(legal): the AI provider's retention of requests, pending the AI
data processing agreement. All periods above are proposed defaults for
counsel to confirm. -->

<!-- TODO(legal): still without a period (B10; DL-060 (3);
questions-for-counsel 3.2): wellbeing notes where Studafy is controller;
school-wide announcements; notifications not tied to a class; roster rows
with no account; safety reports, their evidence and events; invitations
nobody accepted (they hold an email address); the AI usage ledger (kept
until the account is deleted); data-export request rows after the file
expires; files whose malware scan ended in an error. Also confirm keeping an
inactive account whose warning could not be delivered, possibly past 2
years (questions-for-counsel 3.3; PR #73). The timed purges run only once
RETENTION_SCHEDULE_ENABLED is switched on in fly.worker.toml (DPIA D5). -->

---

## 11. Your rights

Under the GDPR, and under Jordan's Personal Data Protection Law where it
applies, you have the right to:

- **Be told** how your data is used — this document.
- **Access** a copy of your data. The app can produce an export.
- **Correct** data that is wrong. For a mark or an attendance record, ask the
  teacher: a correction is recorded alongside the original, not in place of
  it.
- **Delete** your account and data, subject to §9.
- **Restrict** processing while a dispute is resolved.
- **Portability** — receive your data in a machine-readable form.
- **Object** to processing based on legitimate interests.
- **Withdraw consent** at any time, where we relied on consent — for the AI
  study tools, by turning them off in Account. Withdrawing does not affect
  what was lawful before.
- **Complain** to your supervisory authority — in Ireland, the Data
  Protection Commission.

**How to exercise them:** for account deletion and data export, use the app —
Account, then Sign-in and security, then Delete account; or Account, then
Download my data. A parent does this for a
child account they manage. You can also ask for deletion without the app:
see [Delete your account](delete-account). For anything else, write to
hello@studafy.com.

**What the export contains.** The export is one file in JSON, a
machine-readable format, with your own data, including your profile,
classes and family links, your work and the answers you gave, your marks
and their history, your attendance and its history, your notebooks
(including your personal notes), the
messages you sent and received, the reports you made, your consents, your
purchases and your AI usage. **It lists your files — each one's name, type, size and date
— rather than including them.** You can open your files in the app, or write
to hello@studafy.com for a copy. Messages, files and AI usage hold the newest
5,000 entries each; write to us for the rest. A parent's export names the
child accounts they manage; each child's own data is exported from that
child's account.

**What the export leaves out:**

- exam questions, marks and feedback that the teacher has not yet released
  (your own answers are always included);
- wellbeing notes, which are the school's safeguarding records: write to
  hello@studafy.com and we will pass your request to the school;
- messages in conversations you have left;
- AI Tutor chats, which are kept only on your device;
- quizzes and flashcards made from your own notes, which we do not store.

<!-- TODO(legal): is each omission above acceptable under the right of
access (questions-for-counsel 4.1, 4.2; DL-060)? -->

We respond within **one month**. If a request is complex we may extend by two
further months and will tell you why.

**If your school is the controller**, we will pass your request to the school
and tell you we have done so, because it is the school's decision to make.

---

## 12. How we protect data

- Every request is authenticated, and a token is verified against the
  identity provider's published keys on each use.
- Access to a class's data is enforced **in the database itself**, so a fault
  in application code cannot expose another school's or another class's
  records. A class's marks, attendance and hand-ins can be read and changed
  only by that class's own teachers.
- Sensitive operations require recent re-authentication. Opening a safety
  report requires a time-limited grant, approved with a second sign-in
  factor, and is recorded.
- Data is encrypted in transit, including between our own servers and the
  database. Files are stored privately and are reachable only through
  single-use grants that expire within minutes.
- Uploaded files are scanned on our own servers before they can be
  downloaded, and photos and voice notes are rewritten to remove hidden
  metadata.
- Passwords, tokens, keys and other secrets are stripped from logs
  automatically before they are written.
- IP addresses are hashed with a keyed function rather than stored in our
  records, including in rate-limit counters.
- Requests are rate-limited, and abuse-prone operations fail closed.
- Backups are encrypted before they leave our systems, with a key held
  outside every service that stores them.

No service can promise perfect security. **If a breach occurs that is likely
to put your rights at risk, we will notify our supervisory authority within
72 hours and tell affected users without undue delay.**

<!-- TODO(legal): the breach-notification duty above is documented, but there
is no written incident response procedure yet. Write one. -->

---

## 13. Data on your device

The mobile app does not use advertising cookies or trackers. It stores on
your device: your session, your language choice, a cache of the content you
have opened and of files you have downloaded so the app works when your
connection is poor, your AI Tutor chats (with a small copy of any photo you
sent in them), quizzes and flashcards made from your own notes while you
practise them, and your profile photo if you add one. **A profile photo
is never uploaded to our servers**: it stays on the device where you chose
it, nobody else sees it, and it is deleted when that account signs out. An
answer you are writing is not saved until you hand it in. Each account's
data is kept apart, and all of it is cleared from the device when that
account signs out. **On Android, none of this is copied to your phone's
cloud backup.**

Cloudflare Turnstile sets what is needed to complete its bot check.

---

## 14. Automated decision-making

We do not make decisions producing legal or similarly significant effects
about you by automated means alone. **Marks and attendance are decided by
teachers.** The AI tools generate study material; they do not mark work, and
they make no decision about any student. Family+ summarises records; it does
not score, rank or predict. Safety reports are decided by a person.

---

## 15. Changes to this policy

We will post any change here and update the date above. Where a change
materially affects you, we will tell you in the app or by email before it
takes effect, and where the law requires it we will ask for your consent
again.

---

## 16. Contact

Studafy Limited\
4/5 The Square, Cahir, Co. Tipperary, Ireland\
Company number 822430\
hello@studafy.com

This policy and our other legal pages are at legal.studafy.com.

You may complain to the Data Protection Commission (Ireland) at
www.dataprotection.ie, or to your local supervisory authority, at any time.
You do not have to contact us first.

<!--
WHAT TO COMPLETE BEFORE PUBLISHING ON THE OWN DOMAIN

1. Every TODO(legal) comment above.
2. §6: the DPA with Together AI and the DPIA. Both are outstanding. The DPIA
   must cover photos of students' work and whiteboards, and lesson material.
3. §8: the transfer mechanism for each provider individually, including
   Fly.io, Axiom and Sentry (ADR-0035). Sign each one's DPA.
4. §10: the retention periods left open.
5. §12: the incident response procedure.
6. Legal review. This document describes processing of children's data by
   an Irish-registered controller.
7. The store declarations (docs/store/google-play-data-safety.md and
   docs/store/app-store-privacy-labels.md) must match this document.
8. The Arabic translation (docs/legal/ar/privacy-policy.md) and the Arabic
   in-app text must be reviewed by a native legal translator.

Version 1.5 was published on 17 October 2026 without that review, by the
owner's decision (DL-068). Items 1 to 8 still stand. Version 1.6 (21 October
2026, DL-071) was published the same way, and so was version 1.7 (21
October 2026, DL-072).
-->
