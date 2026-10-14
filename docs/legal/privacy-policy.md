# Studafy Privacy Policy

**Last updated:** 12 October 2026\
**Version:** 1.3

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
document and terms-of-use.md. Version 1.3 corrects facts (regions,
providers, what deletion removes); it does not change what anyone agreed
to, so the consent version is unchanged. A substantive change needs a new
consent version and a bump of termsPolicyVersion in
lib/core/account_lifecycle.dart.

The Arabic translation is docs/legal/ar/privacy-policy.md. Change both
together.
-->

### What changed in version 1.3

- Who we are: our company details (§1).
- Where our providers process data, and two providers added: the service
  that checks uploaded files for malware, and Google Calendar for meeting
  invitations (§7.2).
- What the AI study tools receive: also the class's grade level and the
  app's language, and, to read a teacher's scanned file, images of its
  pages (§6).
- What deleting an account removes (§9, §11).
- Android backups: the app's data on the phone is not copied to cloud
  backups (§13).

---

## 1. Who we are

Studafy is a school application used by teachers, students and parents. It
lets a teacher run classes, share lessons, set and mark work — including
work done on paper — record attendance, and communicate with students and
their guardians. It lets a student see and hand in that work and keep their
own notes, and it lets a parent follow their child's progress.

**Data controller:** Studafy Limited, a company registered in Ireland under
number 822430, with its registered office at 4/5 The Square, Cahir,
Co. Tipperary, Ireland.

**Contact for privacy questions:** hello@studafy.com

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
- **For our own operation of the service** — security, fraud prevention,
  billing, backups, keeping the service working — we are the controller
  regardless.

If you are unsure which applies to you, ask us and we will tell you.

---

## 2. A short summary

The long version follows, and it governs. This summary is for orientation.

- We collect what the app needs to work: who you are, which class you are in,
  the lessons and work in it, your marks and attendance, your own notes, and
  the messages you send inside the app.
- Teachers' marks stay **private until the teacher publishes them**. A
  published mark that is later corrected keeps a record of the old mark, who
  changed it, when and why, and the family is told when the mark changes.
- We do **not** sell personal data, use it for advertising, or build
  advertising profiles. We show no advertising, and the app contains no
  advertising or analytics software.
- Subscriptions are billed by **Apple** and **Google**, not by us. We never
  see your card.
- **Some optional study tools send content to an AI provider outside the
  app**: the question a student types and the recent turns of the same chat,
  and — where a student uses them — a photo they attach, a lesson's text, or
  their own notes. Names, email addresses and marks are never sent. See §6 and
  read it before using those tools.
- Children's data is treated as sensitive in practice, whatever its formal
  classification.
- You can ask for a copy of your data, or for your account to be deleted,
  from inside the app or by writing to us.

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
abuse. In our own records and logs we do **not** store it in readable form:
it is converted to a keyed one-way hash first, so our records show that two
requests came from the same source without recording where that source is.
The service that handles sign-in for us (Supabase) keeps the IP address of
sign-in events in its own security logs for up to 7 days, and stores it with
an active session until that session ends.

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
to a class, and meetings a teacher arranges with their invitations and
delivery records.

**Meetings:** Studafy does not host video calls. When a teacher arranges a
meeting, we create it in Google Calendar with a Google Meet link and Google
emails the invitations to the people invited. The call itself takes place in
Google Meet under Google's terms.

We also hold your notification preferences, your registered push devices, and
a record of which notifications were sent and delivered. Push and email
notifications carry fixed wording only — for example "New marks" — never a
name, a mark or a message.

**Messages are stored on our servers and are not end-to-end encrypted.** They
can be read by us where we are required to (see §9) and by school staff acting
under school safeguarding policies. Do not use Studafy messaging for anything
you would not want a school to be able to see.

### 3.7 Safety and moderation

Reports made about content or behaviour, the evidence attached to them, what
was decided, blocks between users, and grants of moderation access. This is
how a student can report something and how it can be acted on.

### 3.8 Files

Files you upload — documents (PDF, Word and PowerPoint), photos and voice
notes — what they are attached to, their size and type, scan results, and
time-limited grants permitting a specific person to download a specific
file. Every uploaded file is checked for malware before anyone can download
it (§7.2).

**When a teacher replaces or removes a file.** If a teacher replaces a
lesson's file, or takes a file off an assignment, the class no longer sees
it, but **the file is kept for the school** and the class's teachers can still
open it. It is not deleted.

### 3.9 Billing

Whether you hold a subscription (Studafy Plus, Studafy Max or Family+), when
it started, renews and ends, and records of store transactions.

**We never receive your card number, bank details or billing address.**
Payment is taken by Apple or Google under their own terms and their own
privacy policies. We receive only a confirmation that a purchase or renewal
occurred, and an opaque transaction identifier. So that a purchase is
credited to the right account, the app gives the store an identifier for
your account that means nothing outside Studafy.

For a student subscription, where a parent's approval is required, we record
that a request was made and how it was decided. Where a parent buys a
subscription for a child, we record who paid and which child it is for.

### 3.10 AI usage

For the tools in §6, how much each account used them, so that the plan's
allowance can be applied. We store the notes, quizzes, flashcards and study
notebooks a tool made, not the conversation that produced them.

### 3.11 Consents

Which version of these terms and this policy you accepted, and when — and,
for a child account, that the parent accepted them on the child's behalf.

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
| Sending service messages you need to receive | Contract |
| Sending optional notifications | Consent, withdrawable in settings |
| Billing and subscription management | Contract |
| Keeping audit records and backups | Legal obligation; legitimate interests in accountability and recovery |
| Responding to safety reports | Legitimate interests in protecting children; legal obligation where one applies |
| The AI study tools | Consent — see §6 |
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

- We do not knowingly permit a child to create an account outside a school
  context where their country requires parental consent for it.
- A student's account is normally created by the student, who then joins a
  class using a code or link their teacher gave them. Belonging to a class is
  what makes a student's work visible to that class's teachers.
- **A parent may create and manage an account for their child** who has no
  email or phone. The parent accepts these terms for the child and is
  responsible for how the account is used. The child's work in class is still
  the child's own record, visible to their teachers.
- **A parent cannot attach themselves to a child without the child's
  approval**, except to a child account that parent created. The request goes
  to the student, who accepts or declines it.
- We do not profile children for advertising, and we show no advertising.
- Where a school is the controller, questions about a child's records should
  go to the school first.

If you believe a child has provided us with personal data in a way that
requires consent that was not given, contact us at hello@studafy.com and we
will investigate and, where appropriate, delete it.

<!-- TODO(legal): the age of digital consent (Ireland: 16) and whether a
parent's consent is needed for students under it outside a school
(decision log DL-037). -->

---

## 6. The AI study tools

**Read this section before allowing a student to use them.** All of them are
optional, and a student who does not use them has nothing sent to the AI
provider. They are switched on only where we have enabled them.

| Tool | Who can use it | What is sent to the AI provider |
|---|---|---|
| **Study helper** (ask a question) | Every student, within their plan's allowance | The question typed, and the most recent turns of the same chat so a follow-up makes sense. Where the student chooses to, the text of the lessons and files they pick from their class, or of their own notes. |
| **A photo in the study helper** | Studafy Plus and Max | The photo the student attaches, with their question |
| **Whiteboard to notes** | Studafy Plus and Max | The photo of the board the student takes |
| **Lesson summaries and study notebooks** | Studafy Plus and Max | The text of the lessons and files the student picks |
| **Quizzes and flashcards** | Studafy Max | The text of the lessons and files the student picks |

With every request we also send the class's grade level (for example
"grade 7") and the app's language, so that the answer suits the student.

**Reading a teacher's file.** So that these tools can use a lesson's files,
we extract their text. Where a file is scanned or made of pictures, images of
its pages are sent to the AI provider to read the text from them.

**Before anything is sent**, we remove email addresses, long number sequences
and web links from typed text.

**What is never sent:** the student's name, email, account identifier,
school or class name, their marks, their attendance, their messages, or
anybody else's work.

**What we keep:** the notes, quizzes, flashcards and study notebooks a tool
produced. Notes and study sets made from a teacher's lesson are shared by the
students of that class, because they come from the teacher's lesson alone.
Notes and notebooks a student made belong to that student and are deleted
when they delete them or their account. **Study helper chats are kept only on
the student's device**, and are deleted from it when the student signs out;
we do not store them.

**Our provider:** Together Computer, Inc. (Together AI), using the model
`Qwen/Qwen3.5-9B`. Its processing may take place outside the EEA (see §8).

<!-- TODO(legal): state the provider's processing locations and its retention
of requests, from the signed DPA. -->

**Limits:** each plan has an allowance of how much AI it can use, shown in
the app as a bar.

**Accuracy:** answers and notes are generated by a language model and **can
be wrong**. They are study support, not a source of truth, and should never
be handed in as a student's own work. **AI never marks a student's work** in
Studafy; marks come only from teachers.

<!-- TODO(legal) - OUTSTANDING, MUST BE RESOLVED BEFORE THESE TOOLS ARE
OFFERED TO CHILDREN: as at the date above, no signed data processing
agreement is in place with the AI provider, and no Data Protection Impact
Assessment covering AI processing of children's data (including photos and
lesson material) has been completed. Both are required: a written processor
contract by Article 28(3) GDPR, and a DPIA by Article 35. -->

---

## 7. Who we share data with

We do not sell personal data. We share it only as set out here.

### 7.1 Within your class

Your work, marks and attendance are visible to your class's teachers, and to
a parent linked to you once a mark is published. Draft marks are visible to
the class's teachers only. There is no school administrator in this version
of the app. Other students cannot see your marks, your submitted work or your
private messages.

### 7.2 Our processors

Each of these acts on our instructions and may not use your data for their
own purposes.

| Provider | What they process | Where |
|---|---|---|
| **Supabase** (database, sign-in, file storage) | Substantially all application data | Frankfurt, Germany |
| **Fly.io** (application hosting) | Requests passing through our servers while they are handled | Frankfurt, Germany |
| **Axiom** (operational logs) | Technical logs: request times, outcomes and error codes, with account identifiers and hashed network addresses. Most successful requests are not kept; logs are deleted after 30 days | Frankfurt, Germany |
| **Sentry** (error reports) | What broke and where in our code, with the device model and versions. No names, emails, message content or photos | Germany |
| **A malware-scanning service** | Each uploaded file, to check it before anyone can download it | See §8 |
| **GitHub** (Microsoft) (backup storage) | Encrypted daily backups, which GitHub cannot read | See §8 |
| **Redis** (rate limits, short-lived caches, background jobs) | Hashed identifiers, counters and job references | See §8 |
| **Google** (Sign in with Google) | Your identity at sign-in | Global |
| **Microsoft** (Sign in with Microsoft) | Your identity at sign-in | Global |
| **Apple** (Sign in with Apple) | Your identity at sign-in | Global |
| **Cloudflare** (Turnstile) | A bot check when a parent looks up a student | Global |
| **Together AI** (AI study tools) | What §6 lists | See §8 |
| **Resend** (email) | Your email address and the fixed message | See §8 |
| **Google Firebase Cloud Messaging** (push) | Your device's push token and the fixed notification text | Global |
| **Google Calendar and Meet** (meetings) | The meeting's title and times, and the email addresses of the people invited; the call itself, when you join | Global |
| **Apple** and **Google** (subscriptions) | Purchases, as independent controllers under their own policies | Global |

Uploaded files are checked for malware by a scanner we run ourselves, on our
own infrastructure in the EU (Frankfurt). Files are not sent to any outside
scanning provider.

### 7.3 Others

- **Where the law requires it**, to a court, regulator or law enforcement
  body — and we will tell you unless we are prohibited from doing so.
- **Where a child is at risk**, to those who need to know in order to protect
  them.
- **To professional advisers** bound by confidentiality.
- **If our business is transferred**, to the acquirer, with notice to you and
  subject to this policy.

---

## 8. International transfers

Our main systems — the database, file storage, application servers, logs
and error reports — are in Germany. Some providers in §7.2 may process data
outside the EEA, and outside Jordan.

Where data leaves the EEA we rely on the European Commission's **Standard
Contractual Clauses**, or on an adequacy decision (such as the EU–US Data
Privacy Framework) where one covers the destination. You may request a copy
of the safeguards in place by writing to hello@studafy.com.

<!-- TODO(legal): confirm the mechanism for each provider in §7.2 before
publishing on the own domain - the AI provider, GitHub, Resend and the
scanner in particular. A provider in the United States without SCCs or
DPF certification is a transfer without a legal basis. -->

---

## 9. What deleting an account removes, and what it keeps

**When an account is deleted** (14 days after the request, see §11), we:

- remove the ability to sign in and erase the email address, name and
  sign-in details;
- replace the name on the profile, and on class rosters, with "Deleted user"
  or "Deleted student", and clear the gender;
- end every membership, guardian link and conversation the account was in;
- delete its devices and push registrations, notification settings and
  notifications, blocks, data exports, notebooks and study
  notebooks, AI usage records, and personal photos (photos for the notebook
  or the study helper);
- remove its email address from invitations;
- delete, in the same way, every child account the person manages: nobody
  else can sign in to a child account, so it cannot outlive its parent. The
  deletion screen names these accounts before the parent confirms.

Some records exist so that the service can be held to account, or belong to
the school, and are kept:

**Audit records.** Every significant action — creating a class, granting or
removing a role, saving, publishing or correcting marks, changing attendance,
giving extra time, editing a lesson, deciding a safety report, accessing a
student's records under a support grant — is recorded with who did it, what
changed, and when. These records are append-only by design: nobody can edit
them, including us, and they are deleted only when their period in §10 ends.

**Consent records.** The record of what you agreed to, and when, is kept for
6 years after the account is deleted (§10).

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
| Study helper chats | On the student's device only, until they sign out; not kept by us |
| Notes, quizzes, flashcards and study notebooks made by the AI tools | Until the student deletes them or their account, or while the lesson they came from exists |
| Billing records | 6 years after the end of the tax year they relate to |
| Files | While attached to something, subject to school policy; in any case deleted 12 months after the class is closed |
| Inactive accounts | Deleted after 2 years without a sign-in. We warn the account holder by email or in the app 30 days before |
| Sign-in IP addresses held by Supabase | Up to 7 days in its security logs, and with an active session until it ends |
| Error reports (Sentry) | Up to 90 days |

<!-- TODO(legal): the AI provider's retention of requests, pending the AI
data processing agreement. All periods above are proposed defaults for
counsel to confirm. -->

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
- **Withdraw consent** at any time, where we relied on consent. Withdrawing
  does not affect what was lawful before.
- **Complain** to your supervisory authority — in Ireland, the Data
  Protection Commission.

**How to exercise them:** for account deletion and data export, use the app —
Account, then Sign-in and security, then Delete account; or Account, then
Download my data. A parent does this for a
child account they manage. You can also ask for deletion without the app:
see [Delete your account](delete-account). For anything else, write to
hello@studafy.com.

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
- Sensitive operations require recent re-authentication.
- Data is encrypted in transit, including between our own servers and the
  database. Files are stored privately and are reachable only through
  single-use grants that expire within minutes.
- Uploaded files are scanned before they can be downloaded, and photos and
  voice notes are rewritten to remove hidden metadata.
- Passwords, tokens, keys and other secrets are stripped from logs
  automatically before they are written.
- IP addresses are hashed with a keyed function rather than stored in our
  records.
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
connection is poor, your study helper chats, and your profile photo if you
add one. **A profile photo is never uploaded to our servers**: it stays on
the device where you chose it, nobody else sees it, and it is deleted when
that account signs out. An answer you are writing is not saved until you
hand it in. Each account's data is kept apart, and all of it is cleared from
the device when that account signs out. **On Android, none of this is copied
to your phone's cloud backup.**

Cloudflare Turnstile sets what is needed to complete its bot check.

---

## 14. Automated decision-making

We do not make decisions producing legal or similarly significant effects
about you by automated means alone. **Marks and attendance are decided by
teachers.** The AI tools generate study material; they do not mark work, and
they make no decision about any student. Family+ summarises records; it does
not score, rank or predict.

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
-->
