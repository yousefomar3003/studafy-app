# Studafy Privacy Policy

**Last updated:** 30 September 2026
**Version:** 1.2 (consent version `2026-09-30.2`)

> **BEFORE PUBLISHING — READ THIS**
>
> This policy was written from the application's actual data flows: every
> table, every third party and every transfer described below was taken from
> the code and the database, not from a template. That makes it accurate, but
> accuracy is not the same as legal sufficiency.
>
> **It has not been reviewed by a lawyer, and it must be before it is
> published.** Studafy processes the personal data of children, which is the
> most heavily regulated category of processing there is. Placeholders in
> `[SQUARE BRACKETS]` are facts only you can supply.
>
> Statements in §6 and §12 are **not yet true** and are marked. Do not
> publish this document until they are, or until those sections are corrected.
>
> The in-app summaries (`policyPrivacyBody` and `policyTermsBody` in
> `lib/l10n/app_en.arb` and `app_ar.arb`) must say the same things as this
> document and `terms-of-use.md`. Change them together, publish a new consent
> version, and bump `termsPolicyVersion` in `lib/core/account_lifecycle.dart`.

### What changed in version 1.1

- The study helper and the Studafy Plus and Max tools now send more than a
  typed question to the AI provider. §6 says exactly what.
- Paper marks, marks kept as drafts until the teacher publishes them, and
  corrections that keep the mark they replaced (§3.4, §9).
- Attendance corrections, the reason given for each, and the history kept
  of every change (§3.4, §9).
- Hand-in deadlines, extensions and late hand-ins (§3.4).
- Lessons and material that a teacher edits or replaces: the earlier files
  are kept for the school (§3.8, §9).
- Child accounts that a parent creates and manages, and several accounts on
  one device (§3.1, §5).
- Family+ insights for parents (§3.5).
- Voice notes in messages, meeting links, and read receipts (§3.6).
- Encrypted daily backups (§7.2, §10).
- There is no school administrator in this version of the app (§3.3, §7.1).

---

## 1. Who we are

Studafy is a school application used by teachers, students and parents. It
lets a teacher run classes, share lessons, set and mark work — including
work done on paper — record attendance, and communicate with students and
their guardians. It lets a student see and hand in that work and keep their
own notes, and it lets a parent follow their child's progress.

**Data controller:** [REGISTERED COMPANY NAME], a company registered in
Ireland under number [COMPANY NUMBER], with its registered office at
[REGISTERED ADDRESS].

**Contact for privacy questions:** [PRIVACY CONTACT EMAIL]

**Data Protection Officer:** [DPO NAME AND CONTACT, or the sentence "We have
not appointed a Data Protection Officer because we are not required to under
Article 37 GDPR." — take advice before choosing. Systematic monitoring of
children at scale is exactly the case where one is usually required.]

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
  advertising profiles. We show no third-party advertising.
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
  from inside the app.

---

## 3. The personal data we process

### 3.1 Account and identity

| What | Why | Where it comes from |
|---|---|---|
| Name (display name) | To show who you are to your class | Your sign-in provider, or you |
| Email address | To identify your account and send service messages | Your sign-in provider |
| Sign-in provider identifier | To recognise you on return | Google, Microsoft or Apple |
| Language preference | To show the app in your language (English or Arabic) | You |
| Gender (male, female or prefer not to answer), only if you choose to give it | To address you correctly; it is shown to nobody else, including your school | You |
| Account status and creation date | To operate the account | Generated |

**We do not store passwords.** You sign in with Google, Microsoft or Apple,
and only they verify your credential. We receive a confirmation that it was
you, plus your name and email.

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
used, and a coarse description of the device (for example "iPhone, Safari").
This is what lets you see where you are signed in and sign out a device you
no longer have.

We record security events on your account — sign-ins, sign-outs, session
revocations, two-factor enrolment and changes to linked sign-in identities.

**IP addresses.** We use your IP address to apply rate limits and to detect
abuse. We do **not** store it in readable form: it is converted to a keyed
one-way hash before it is written anywhere, so our records show that two
requests came from the same source without recording where that source is.
The same applies to our operational logs.

### 3.3 School, class and role

Which school or teaching space you belong to, your role in it (teacher,
student, parent or guardian), when that role was granted, and whether it is
currently active. A teacher who signs up on their own gets their own teaching
space. Changes to roles are recorded permanently — see §9.

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
  of the board they take, and study notes, quizzes and flashcards they make
  with the tools in §6.

Wellbeing notes and pastoral records can be sensitive. They are visible only
to the class's teachers, and to a family only where a teacher chooses to
share a note with them. They are never visible to other students.

### 3.5 Family links and Family+

A parent is connected to a student by a **guardian link**. To create one, a
parent enters the student's Studafy identifier; **the student then approves or
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

**Meetings:** Studafy does not host video calls. A teacher creates the call
in Google Meet and adds its link; we store the link and the invitation, and
the call itself takes place in Google Meet under Google's terms.

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

Files you upload — documents, photos and voice notes — what they are
attached to, their size and type, scan results, and time-limited grants
permitting a specific person to download a specific file.

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
occurred, and an opaque transaction identifier.

For a student subscription, where a parent's approval is required, we record
that a request was made and how it was decided. Where a parent buys a
subscription for a child, we record who paid and which child it is for.

### 3.10 AI usage

For the tools in §6, how much each account used them — the number of
requests and their cost — so that daily and monthly limits can be applied.
We store the notes, quizzes and flashcards a tool made, not the conversation
that produced them.

### 3.11 Consents

Which version of these terms and this policy you accepted, and when — and,
for a child account, that the parent accepted them on the child's behalf.

### 3.12 Operational data

- **Audit records** of significant actions — see §9.
- **Technical logs** of requests: the time, the route, whether it succeeded,
  how long it took, a request identifier, a hashed IP and a coarse client
  type. These are automatically stripped of passwords, tokens, keys and other
  secrets before they are written.
- **Short-lived cache and rate-limit records**, keyed by hashed identifiers.

---

## 4. Why we process it, and on what legal basis

| Purpose | Legal basis (GDPR Art. 6) |
|---|---|
| Providing the app to a school's teachers and students | Contract with the school; the school's public task or legitimate interests as controller |
| Providing the app to an individual account holder | Performance of our contract with you |
| Keeping marks private until published, and a history of changes to marks and attendance | The school's legal obligations and legitimate interests in accurate records; legitimate interests in accountability |
| Telling a family when a mark is published or changed | Contract; legitimate interests in keeping families informed |
| Keeping accounts secure; preventing abuse | Legitimate interests: protecting users, particularly children |
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

**We do not use your personal data to train any AI or machine-learning model,
and we do not permit our providers to.**

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
requires consent that was not given, contact us at
[PRIVACY CONTACT EMAIL] and we will investigate and, where appropriate,
delete it.

---

## 6. The AI study tools

**Read this section before allowing a student to use them.** All of them are
optional, and a student who does not use them has nothing sent to the AI
provider. They are switched on only where we have enabled them.

| Tool | Who can use it | What is sent to the AI provider |
|---|---|---|
| **Study helper** (ask a question) | Every student, with a daily limit | The question typed, and the most recent turns of the same chat so a follow-up makes sense. Where the student chooses to, the text of a lesson from their class or of their own notes. |
| **A photo in the study helper** | Studafy Plus and Max | The photo the student attaches, with their question |
| **Whiteboard to notes** | Studafy Plus and Max | The photo of the board the student takes |
| **Lesson to study notes** | Studafy Plus and Max | The text of the teacher's lesson |
| **Quizzes and flashcards** | Studafy Max | The text of the teacher's lesson |

**Before anything is sent**, we remove email addresses, long number sequences
and web links from typed text.

**What is never sent:** the student's name, email, account identifier,
school or class name, their marks, their attendance, their messages, or
anybody else's work.

**What we keep:** the notes, quizzes and flashcards a tool produced. Notes
and study sets made from a teacher's lesson are shared by the students of
that class, because they come from the teacher's lesson alone. Notes made
from a student's own photo belong to that student and are deleted when they
delete them. **Study helper chats are kept only on the student's device**,
and are deleted from it when the student signs out; we do not store them.

**Our provider:** Together Computer, Inc. (Together AI), using the model
`Qwen/Qwen3.5-9B`, processing on infrastructure located in
[PROVIDER PROCESSING LOCATIONS].

**Limits:** each account has a daily limit on questions. Each paid plan has a
monthly limit on how much AI it can use.

**Accuracy:** answers and notes are generated by a language model and **can
be wrong**. They are study support, not a source of truth, and should never
be handed in as a student's own work. **AI never marks a student's work** in
Studafy; marks come only from teachers.

> **OUTSTANDING — MUST BE RESOLVED BEFORE PUBLICATION**
>
> As at the date above, **no signed data processing agreement is in place
> with the AI provider, and no Data Protection Impact Assessment covering AI
> processing of children's data — including photos and lesson material — has
> been completed.** Both are required: a written processor contract by
> Article 28(3) GDPR, and a DPIA by Article 35 where processing is likely to
> result in high risk, which the combination of children's data and
> automated processing is understood to be.
>
> Until both exist, this section cannot honestly be published and these
> tools should not be offered to children.

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
| **Supabase** (database, authentication, file storage) | Substantially all application data | [CURRENTLY AWS ap-northeast-1, Tokyo — MOVING TO eu-central-1, Frankfurt. State the live region at publication.] |
| **Fly.io** (application hosting) | Requests passing through our servers while they are handled | Frankfurt, Germany |
| **Axiom** (operational logs) | Technical logs: request times, outcomes and error codes, with account ids and hashed network addresses. Most successful requests are not kept; logs are deleted after 30 days | [REGION — choose EU] |
| **Sentry** (error reports) | What broke and where in our code. No names, emails, message content or photos: we switch off its collection of personal data and mask anything that looks like it | [REGION — choose EU] |
| **Amazon Web Services** (optionally a backup copy) | Encrypted backups where enabled | [REGION] |
| **GitHub** (Microsoft) (backup storage) | Encrypted daily backups, which GitHub cannot read | [REGION] |
| **Redis** (rate limits, short-lived caches) | Hashed identifiers and counters | [REGION] |
| **Google** (Sign in with Google) | Your identity at sign-in | Global |
| **Microsoft** (Sign in with Microsoft) | Your identity at sign-in | Global |
| **Apple** (Sign in with Apple) | Your identity at sign-in | Global |
| **Cloudflare** (Turnstile) | A bot check when a parent looks up a student | Global |
| **Together AI** (AI study tools) | What §6 lists | [LOCATION] |
| **Resend** (email) | Your email address and the message | [REGION] |
| **Google Firebase Cloud Messaging** (push) | Your device token and the fixed notification text | Global |
| **Google Meet** (meeting links) | The call itself, when you join a meeting link | Global |
| **Apple** and **Google** (subscriptions) | Purchases, as independent controllers under their own policies | Global |

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

Your data may be processed outside the country you are in — including outside
the EEA, and outside Jordan.

Where data leaves the EEA we rely on the European Commission's **Standard
Contractual Clauses**, or on an adequacy decision where one covers the
destination. You may request a copy of the safeguards in place by writing to
[PRIVACY CONTACT EMAIL].

[CONFIRM the mechanism for each provider in §7.2 before publishing — the AI
provider and GitHub in particular. A provider located in the United States
without SCCs in its contract is a transfer without a legal basis.]

---

## 9. Records we cannot delete on request

Some records exist so that the service can be held to account, and they are
written in a way that prevents them being altered or removed.

**Audit records.** Every significant action — creating a class, granting or
removing a role, saving, publishing or correcting marks, changing attendance,
giving extra time, editing a lesson, deciding a safety report, accessing a
student's records under a support grant — is recorded with who did it, what
changed, and when. These records are append-only by design: they cannot be
edited or deleted, including by us.

**The history of a mark and of attendance.** When a published mark is
corrected, or an attendance mark is changed, the previous value, the new
value, who changed it, when and why are kept for as long as the record
itself. This is so that a student, a family and the school can rely on a
record being accurate, and see how it changed.

**Earlier attempts and replaced files.** Every hand-in a student made, and
every file a teacher replaced or took off a lesson or assignment, is kept for
the school.

**Membership history.** The record that a role was granted, suspended or
revoked is kept even after the role ends.

**Education records.** Where a school is the controller, the school is often
legally required to keep attendance, assessment and safeguarding records for
a defined period. These stay with the school when your account is deleted.
The app shows you which records these are before you confirm a deletion.

**Legal holds.** Where data is relevant to a legal claim or an investigation,
we may be required to preserve it until that concludes.

Audit and history records identify who acted. That is their purpose, and it
means a name may remain in them after an account is otherwise deleted.

---

## 10. How long we keep things

| Data | Retention |
|---|---|
| Account and profile | While the account exists |
| Deletion grace period | 14 days from request, during which you can cancel |
| Academic records, marks, their history and attendance where a school is controller | As the school's retention policy requires |
| Earlier hand-ins and replaced or removed files | As the school's retention policy requires |
| Messages and voice notes | While the conversation exists, subject to school policy |
| Audit records | [STATE A PERIOD — commonly 6–7 years. Must be defined.] |
| Technical logs | [STATE A PERIOD — currently 30 days in CloudWatch if configured as documented] |
| Rate-limit and cache records | Minutes to hours |
| Backups | Encrypted, taken daily, kept for 30 days, then overwritten |
| Study helper chats | On the student's device only, until they sign out; not kept by us. [CONFIRM AND STATE the provider's retention.] |
| Notes, quizzes and flashcards made by the AI tools | Until the student deletes them, or while the lesson they came from exists |
| Billing records | As tax and accounting law requires, typically 6–7 years |
| Files | While attached to something, subject to school policy |

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
Account, then Delete account or Download my data. A parent does this for a
child account they manage. For anything else, write to
[PRIVACY CONTACT EMAIL].

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
- Data is encrypted in transit. Files are stored privately and are reachable
  only through single-use grants that expire within minutes.
- Uploaded files are scanned before they can be downloaded, and photos and
  voice notes are rewritten to remove hidden metadata.
- Passwords, tokens, keys and other secrets are stripped from logs
  automatically before they are written.
- IP addresses are hashed with a keyed function rather than stored.
- Requests are rate-limited, and abuse-prone operations fail closed.
- Backups are encrypted before they leave our systems, with a key held
  outside every service that stores them.

No service can promise perfect security. **If a breach occurs that is likely
to put your rights at risk, we will notify our supervisory authority within
72 hours and tell affected users without undue delay.**

> **OUTSTANDING:** we have a documented breach-notification duty above but no
> written incident response procedure. Write one before publishing this.

---

## 13. Data on your device

The mobile app does not use advertising cookies or trackers. It stores on
your device: your session, your language choice, a cache of the content you
have opened and of files you have downloaded so the app works when your
connection is poor, your study helper chats, and your profile photo if you
add one. **A profile photo is never uploaded to our servers**: it stays on
the device where you chose it, nobody else sees it, and it is deleted when
that account signs out. An answer you are writing
is not saved until you hand it in. Each account's data is kept apart, and all of it is cleared from the
device when that account signs out.

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

[REGISTERED COMPANY NAME]
[REGISTERED ADDRESS]
[PRIVACY CONTACT EMAIL]

You may complain to the Data Protection Commission (Ireland) at
www.dataprotection.ie, or to your local supervisory authority, at any time.
You do not have to contact us first.

---

## Appendix A — What to complete before publishing

1. Every `[SQUARE BRACKET]` placeholder.
2. **§6** — the DPA with Together AI and the DPIA. Both are outstanding. The
   DPIA must cover photos of students' work and whiteboards, and lesson
   material.
3. **§8** — confirm the transfer mechanism for each provider individually,
   including Fly.io, Axiom and Sentry (ADR-0035). Sign each one's DPA and
   choose their EU data regions before production data reaches them.
4. **§10** — define the retention periods left open.
5. **§12** — write the incident response procedure.
6. **Legal review.** This document describes processing of children's data by
   an Irish-registered controller. It should not be published without a
   lawyer reading it.
7. **App Store and Play privacy declarations must match this document.** In
   particular, both stores require you to declare that user content —
   including photos — is sent to a third party for the AI tools. A
   declaration that contradicts this policy is treated as a false
   declaration, and apps are removed for it.
8. **The Arabic in-app text** must be reviewed by a native legal translator.
