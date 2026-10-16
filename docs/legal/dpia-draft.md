# Data Protection Impact Assessment: children's data and AI (DRAFT)

**Status: DRAFT for the owner and counsel. Not legal advice. Not approved.**\
**Prepared:** 15 October 2026, from the code and documents on `main` at
`4f18c85`\
**Launch-plan item:** A5 / launch work plan 6.2\
**Controller:** Studafy Limited, Ireland, company 822430
(`docs/legal/privacy-policy.md` §1)

<!--
READ FIRST

- Written from the code and the repository's own documents, not from a
  template. Every factual claim cites the file it comes from. Where a fact
  could not be checked from the repository (provider settings, dashboards,
  contracts), it says so and is marked UNKNOWN or TODO(legal).
- Nothing here decides a legal question. Lawful bases, controller/processor
  roles, transfer mechanisms and retention periods are framed as questions
  for counsel, in TODO(legal) comments, the same convention as
  privacy-policy.md and terms-of-use.md.
- This file is NOT published by the legal site: ops/legal-site/src/site.ts
  builds only the pages in its PAGES list. The repository itself is public
  (GitHub yousefomar3003/studafy-app), so this draft is readable by anyone.
  Counsel's annotated version should be kept outside the repository.
- The structure follows GDPR Article 35(7) and the ICO DPIA template, with
  the ICO Age Appropriate Design Code (Children's Code) standards checked in
  section 8, and the DPC's guidance "Fundamentals for a Child-Oriented
  Approach to Data Processing" as the Irish equivalent.
-->

## Contents

1. Why a DPIA is needed
2. Description of the processing
3. Data inventory
4. Data flows, processors and transfers
5. Controller roles and lawful bases (questions for counsel)
6. Necessity and proportionality
7. Retention
8. Children's Code check
9. Data subject rights: how they work in the code
10. Risk register
11. AI risks in detail
12. Where the code and the privacy policy disagree
13. Open questions that block sign-off
14. Consultation
15. Measures to take, and sign-off

---

## 1. Why a DPIA is needed

Studafy processes the school records, messages, photos and voice notes of
children, including children under 13. The owner decided to declare the real
student ages, under-13s included (`docs/governance/decision-log.md` DL-056).
Three things on the EDPB/DPC lists of high-risk processing apply together:

- **Vulnerable data subjects at scale:** pupils aged roughly 5 to 17
  (`docs/store/google-play-data-safety.md`, "Needs Yousef's decision", item 3).
- **Innovative technology:** a large language model receives children's
  questions, photos and class material (`docs/legal/privacy-policy.md` §6;
  ADR-0037).
- **Sensitive data:** wellbeing and pastoral notes that may contain health or
  safeguarding information (`docs/inventory/data-classification-retention-draft.md`,
  `wellbeing_events`, "P0 special-category candidate").

The privacy policy itself says a DPIA covering AI processing of children's
data is required before the AI tools are offered to children
(`docs/legal/privacy-policy.md` lines 464-469). DL-047 removed AI in
September for the same reason, and ADR-0034 and ADR-0037 make a signed
provider DPA and this DPIA the conditions for turning AI on in production.

**Scope.** The whole app (teacher, student, parent/guardian), with a deeper
treatment of the AI study tools. There is **no school administrator role**
in this release (`docs/legal/privacy-policy.md` §3.3; `docs/legal/terms-of-use.md` §1).

---

## 2. Description of the processing

### 2.1 Nature

A Flutter mobile app (Android and iOS) talks to a TypeScript API and a
background worker on Fly.io in Frankfurt, which use a Supabase database,
sign-in service and private file storage in Frankfurt (ADR-0035;
ADR-0005, update of 2026-10-12). Access to a class's data is enforced in the
database by row-level security as well as by the API
(`docs/evidence/launch-readiness/2026-10-08-security-audit.md`, "Checked and
found sound": every `public` table has RLS; `storage.objects` has no client
policies). Files are uploaded to quarantine, scanned and delivered only
through single-use grants that expire within five minutes (DL-044; ADR-0023).

How data is collected:

- **from the person:** sign-in through Google, Microsoft or Apple (no
  passwords are stored, `privacy-policy.md` §3.1); typed content, photos,
  voice notes and files;
- **from teachers, about students:** marks, attendance, wellbeing notes,
  extensions;
- **from parents, about children:** a managed child account's name, given by
  the parent (ADR-0031; `privacy-policy.md` §3.1);
- **generated:** IDs, audit and security events, AI outputs.

### 2.2 Scope, by feature area

| Area | What happens | Main data | Evidence |
|---|---|---|---|
| Accounts and sign-in | OAuth sign-in, profile set-up, device sessions, several accounts per device, managed child accounts | Name, email, provider ID, gender (optional), language, Studafy ID, devices | `privacy-policy.md` §3.1-3.2; ADR-0031; DL-034 |
| Schools, classes, rosters | A teacher creates a teaching space and classes; students join by code or link | Memberships, roster rows, class codes | `privacy-policy.md` §3.3; `supabase/migrations/202609240001_workspace_messaging_controls.sql` |
| Lessons and material | Teachers publish lessons with PDF, Word, PowerPoint, images and links | Teaching material (may contain personal data, e.g. a worksheet with names) | ADR-0037 §1; `privacy-policy.md` §3.4 |
| Work, exams, marking | Assignments, online exams, hand-ins, marks (draft until published), corrections with history | Student answers, files, scores, feedback, history | ADR-0033; ADR-0036; ADR-0040; `privacy-policy.md` §3.4 |
| Attendance | Registers with reasons, lock after 7 days, every change kept | Attendance states and reasons (may be health-related) | `privacy-policy.md` §3.4 |
| Wellbeing notes | Teachers record strengths, notes and concerns about a student | Pastoral and possibly safeguarding or health information | `privacy-policy.md` §3.4; `docs/store/google-play-data-safety.md` decision 6 |
| Family links and Family+ | A parent links to a student with the student's approval; Family+ summarises the child's own record (no AI) | Guardian links, relationship, published marks, attendance | `privacy-policy.md` §3.5; DL-050 |
| Messaging and meetings | Staff-to-anyone and guardian-to-own-child messaging, voice notes, announcements; meetings through Google Calendar and Meet | Message bodies, voice notes, read receipts, attendee emails | DL-049; DL-052; `privacy-policy.md` §3.6 |
| Safety | Reports, blocks, moderation, legal holds | Reports with evidence, block pairs | ADR-0021; DL-042 |
| Files | Upload, scan, metadata strip, delivery | Documents, photos, voice notes | DL-043; DL-044; `infra/scanner/` |
| AI study tools | Study helper chat, photo questions, whiteboard-to-notes, lesson notes and study notebooks, quizzes and flashcards; background reading of lesson files | Questions, recent chat turns, photos, lesson passages, class grade level, language | `privacy-policy.md` §6; ADR-0029; ADR-0037; ADR-0038; ADR-0039 |
| Plans and billing | Plus and Max for students, Family+ for parents, through the stores; a student's purchase needs a guardian's approval | Entitlements, store transactions, approvals | DL-048; ADR-0032; ADR-0034 |
| Notifications | In-app, push (FCM) and email (Resend) with fixed, content-free wording | Push token, email address | DL-053; `privacy-policy.md` §3.6 |
| Operations | Request logs (Axiom), error reports (Sentry), alerts (Telegram via a Cloudflare Worker), backups (GitHub Actions) | Account UUID, hashed IP, stack traces, encrypted database copies | ADR-0035; `docs/operations/observability-review-2026-10.md`; `docs/deployment/backups.md` |

**Scale.** Not known yet. The production database size is deferred until
pilot numbers exist (DL-056). `docs/capacity/` holds load estimates only.
TODO: fill in expected schools, students and parents at launch and after a
year.

### 2.3 Context

- **Data subjects:** students (children, including under-13s), parents and
  guardians, teachers. Managed child accounts belong to children without an
  email or phone, usually the youngest (ADR-0031).
- **Markets:** Ireland/EEA and Jordan (`privacy-policy.md` §1; Jordan PDPL
  No. 24 of 2023). The interface is English and Arabic (ADR-0028).
- **Reasonable expectations:** families expect a school app to hold marks
  and attendance; they may not expect a child's questions or photos to reach
  an AI company in another country. The app shows a notice before the helper
  is used ("Your question is sent to an AI service ... do not include your
  name, your school or anything private", `lib/l10n/app_en.arb` key
  `studyAssistantIntro`) and an accuracy warning (`studyAssistantCheckWork`).
- **Control:** children have little say over what teachers record about
  them. Parents cannot change marks or attendance and do not see the child's
  private messages (`privacy-policy.md` §3.5).
- **No school administrator,** so nobody at a school can see across classes,
  but also nobody at a school can review safety reports (see R7).
- **Public concern:** AI and children's data, and school safeguarding
  records, are both areas of active regulatory attention.
- **State of the product:** feature-complete, running on a test copy; release
  builds are blocked on purpose (SEC-001) until the launch gates pass
  (`docs/planning/launch-work-plan.md`, "Where things stand").

### 2.4 Purposes

1. Running classes: lessons, set work, hand-ins, marking, attendance.
2. Keeping families informed: published marks, attendance, Family+ summaries.
3. School communication and safeguarding: messages, reports, blocks.
4. Optional study support with AI.
5. Selling plans through the app stores.
6. Security, abuse prevention, reliability, backups and accountability
   (audit records).

Studafy shows no advertising, has no analytics or advertising SDK and builds
no advertising profiles (`privacy-policy.md` §2, §5; `pubspec.yaml` as
checked in `docs/store/google-play-data-safety.md` §4).

---

## 3. Data inventory

The full table-by-table classification is
`docs/inventory/data-classification-retention-draft.md` (P0 = children's or
special-category, P1 = personal and education records, P2 = operational).
The summary below groups it for this assessment.

| Category | Examples (tables, flows) | Whose | Class | Notes |
|---|---|---|---|---|
| Identity | `profiles`, `students` (display name, `studafy_id`), auth identities, email (Supabase Auth) | All | P0 for children | Managed child accounts have no real email (ADR-0031) |
| Optional profile | Gender (male, female, prefer not to say), language | All | P1 | Gender is shown to nobody else (`privacy-policy.md` §3.1). Profile photos never leave the device (`lib/core/profile_photo.dart`) |
| Education records | `grade_results` and their events, `submissions`, `submission_attempts`, assessments, answers, `attendance_records` and revisions | Students | P1 (attendance reasons possibly P0) | Mark and attendance history is append-only (`privacy-policy.md` §9) |
| **Wellbeing notes** | `wellbeing_events` (strength, note, concern, incident) | Students | **P0 special-category candidate** | Health or safeguarding content likely. RLS fixed on 2026-10-08 so a removed teacher cannot read restricted notes (security audit finding 6, migration `202610080001`) |
| Family relationships | `guardian_links`, `private.managed_accounts` | Parents, students | P0/P1 | |
| Communications | `conversations`, `messages`, voice notes, announcements, meetings | All | P1 | Not end-to-end encrypted (`privacy-policy.md` §3.6) |
| Safety | Reports, evidence, blocks, moderation grants, legal holds | All | P1, possibly P0 | Reporter identity masked until escalation (ADR-0021) |
| Files | `file_objects` and storage bytes: PDF, DOCX, PPTX, JPEG, PNG, m4a | All | P0/P1 | Photos of children's work, whiteboards, possibly faces |
| Student's own notes | `notebook_entries`, `study_notebooks` | Students | P1 | |
| **AI inputs** | Question text, last chat turns, photos, lesson passages, class grade level, language | Students (and see R12) | P0/P1 | Sent to Together AI; chats stored only on the device (`lib/features/study_assistant/data/file_study_chat_store.dart`) |
| **AI outputs** | Answers (device only), notes, quizzes, flashcards, study notebooks (server) | Students | P1 | Shared study sets are made from a teacher's lesson alone (`privacy-policy.md` §6) |
| AI usage ledger | User, feature, plan, model, tokens, cost, time; never prompts or answers | Students | P2 | ADR-0037 §3 ("Metering") |
| Billing | Store transactions, entitlements, guardian purchase approvals | Students, parents | P2 | No card data (`privacy-policy.md` §3.9) |
| Consent | `consent_records` (purpose `terms_and_privacy`, version, locale) | All | P1 | Only one consent purpose exists (`lib/features/session/data/api_session_repository.dart:271`) |
| Security and audit | `audit_events`, `membership_events`, `auth_security_events` with keyed IP hashes | All | P2 | `apps/api/src/platform/middleware.ts` |
| Technical logs | Route, status, duration, `user_id`, `ip_hash`, user-agent family | All | P2 | Redacted by key (`apps/api/src/platform/logging.ts`); about 10% of successes kept (ADR-0035) |
| Error reports | Stack traces, device model, OS, app version | All | P2 | Personal data scrubbed (`packages/infrastructure/src/sentry.ts`; `lib/core/crash_reports.dart`) |
| Short-lived caches (Redis) | Rate-limit counters; a session cache of up to 30 s holding user ID, display name, locale and memberships under an HMAC key; BullMQ jobs carrying IDs | All | P2 | `apps/api/src/platform/cache/authContextCache.ts`; `apps/worker/src/outbox/dispatcher.ts`. Rate limits before sign-in are keyed by the **raw IPv4 address** or IPv6 /64 prefix (`apps/api/src/platform/rate-limit/middleware.ts:168-173`) |
| Device data | Push token, Firebase Installation ID, device label | All | P2 | `docs/store/google-play-data-safety.md`, "Device or other IDs" |

**Not collected:** date of birth or age, phone number, location, contacts,
calendar, browsing history, health data as a category, advertising ID
(`docs/store/google-play-data-safety.md` §2; no date-of-birth field exists
anywhere in `lib/`, `apps/`, `packages/` or `supabase/migrations/`).

<!-- TODO(legal): are wellbeing notes special-category data (Art. 9) where
they record health matters, and are some of them criminal-offence data (Art.
10) where they record incidents? If yes, an Art. 9(2) condition is needed
and the store answers must declare "Health info"
(google-play-data-safety.md decision 6). -->

---

## 4. Data flows, processors and transfers

### 4.1 Main flows

```
Phone app ──HTTPS──> Fly API (fra) ──TLS──> Supabase Postgres, Auth, Storage (Frankfurt)
                         │                      ▲
                         │                      │
                         ├──> Redis (rate limits, BullMQ jobs; hashed keys)
                         └──HTTPS──> Together AI  (questions, photos, lesson passages)

Fly worker (fra) ──> ClamAV scanner (Fly private network, fra)
                 ──> Together AI (scanned pages of teacher files)
                 ──> FCM / Resend / Google Calendar (when switched on)
Logs ──> Fly log shipper ──> Axiom (EU)        Errors ──> Sentry (EU)
Alerts ──> Cloudflare Worker ──> Telegram, email
Backups ──> GitHub Actions artifact (encrypted with age), optional S3
```

Sources: ADR-0035; `docs/security/credentials-map.md`; `fly.*.toml`;
`packages/infrastructure/src/studyAssistant.ts`;
`apps/worker/src/processors/materialIndex.ts`; `ops/alert-relay/src/index.ts`;
`.github/workflows/backup.yml`.

### 4.2 Processors and recipients

"Location" is what the repository records. UNKNOWN means it could not be
checked from the repository. No DPA is recorded as signed for any provider
(`privacy-policy.md` closing comment, item 3; `docs/evidence/launch-readiness/2026-10-11-production-readiness.md` §E).

| Recipient | Role (to confirm) | Data | Location | Transfer basis | DPA |
|---|---|---|---|---|---|
| Supabase | Processor | Substantially all data | Frankfurt (eu-central-1) | None needed if EU-only; sub-processors UNKNOWN | TODO |
| Fly.io | Processor | Data in transit through API and worker; scanner | Frankfurt (`fra`) | Fly.io is a US company: SCCs or DPF to confirm | TODO |
| Redis provider (Redis Cloud today; Upstash proposed) | Processor | Counters keyed by HMAC digests or, before sign-in, by raw IP address; a 30-second session cache with display names; job references. The test copy's Redis is plaintext `redis://` over the internet; production refuses it (security audit, "Still open") | Frankfurt per owner notes; UNKNOWN in repo | TODO | TODO |
| Axiom | Processor | Technical logs with account UUID and IP hash | EU region (`fly.log-shipper.toml`) | US company: TODO | TODO |
| Sentry | Processor | Error reports, scrubbed | EU (Germany) | US company: TODO | TODO |
| **Together AI** (Together Computer, Inc.) | Processor if a DPA is signed | AI inputs (section 11) | **UNKNOWN; likely US** | **None in place** | **Not signed** (launch-work-plan 6.1) |
| GitHub (Microsoft) | Processor | age-encrypted backups as Actions artifacts | UNKNOWN (GitHub-hosted) | TODO | TODO |
| AWS S3 (optional backup copy) | Processor | Encrypted backups | Default region `il-central-1` (Israel) in `.github/workflows/backup.yml` if enabled | Israel has an adequacy decision; confirm if used | TODO |
| Google (Sign in), Microsoft (Sign in), Apple (Sign in) | Independent controllers or processors: TODO | Identity at sign-in | Global | TODO | — |
| Cloudflare (Turnstile; alert relay Worker) | Processor | Bot check when a parent looks up a student; alert titles | Global | TODO | TODO |
| Telegram | Recipient of alerts | Alert titles and code locations only ("Alerts carry titles and links only", `ops/alert-relay/src/index.ts`) | UNKNOWN | TODO | — |
| Resend | Processor (when email is on) | Email address, fixed text | UNKNOWN | TODO | TODO |
| Firebase Cloud Messaging | Processor (when push is on) | Push token, fixed text | Global | TODO | TODO |
| Google Calendar and Meet | Processor (when meetings are on, B8) | Meeting title, times, attendee emails | Global | Workspace terms needed (DL-052) | TODO |
| Apple and Google stores | Independent controllers | Purchases | Global | — | — |
| ClamAV scanner | Run by Studafy (no third party) | Uploaded files | Fly `fra`, private network only (`fly.scanner.test.toml`) | — | — |

<!-- TODO(legal): confirm the role and the transfer mechanism (SCCs, DPF,
adequacy) for each row, sign each DPA, and record a transfer impact
assessment for Together AI in particular. ADR-0005 (update 2026-10-12) and
privacy-policy.md §8 leave this open. -->

<!-- TODO(legal): Jordan. PDPL No. 24 of 2023 has its own cross-border rules.
Confirm what applies to Jordanian users' data held in Germany and sent to
the US. -->

---

## 5. Controller roles and lawful bases (questions for counsel)

This section states what the policy says and what the code does. It does not
decide.

### 5.1 Who is the controller

The policy says (`privacy-policy.md` §1.1): a school using Studafy is the
controller and Studafy its processor; for a teacher who signs up alone,
Studafy is the controller; for its own operations Studafy is the controller.

What the code does:

- Any teacher can create a teaching space for their own classes with no
  school's involvement (`createTeacherWorkspace`,
  `supabase/migrations/202609240001_workspace_messaging_controls.sql`).
  There is no school administrator and no school contract flow in the app.
  In practice, at launch, **most or all use may be teacher-led, with Studafy
  as controller**.
- A school's retention instruction can be recorded, but only by Studafy on
  the school's written instruction (`private.school_retention_instructions`,
  DL-057).
- The AI tools are offered by Studafy, sold by Studafy (Plus, Max) and
  chosen by the student. They are hard to fit inside a school's
  instructions.

<!-- TODO(legal): Q1. Is Studafy a controller for teacher-led use, and for
the AI tools in every case, even where a school is the controller of the
class records? Q2. Is a teacher who signs up alone acting for their school
(so the school is controller without knowing it)? Q3. What Art. 28 contract
do schools sign, and through what flow? None exists in the product. -->

### 5.2 Lawful bases claimed in the policy

From `privacy-policy.md` §4:

| Purpose | Basis the policy claims | Question |
|---|---|---|
| Running the app for a school | Contract with the school; school's public task or legitimate interests | No school contract flow exists yet |
| Running the app for an individual | Contract with the person | **Can a child under 16 (Ireland) enter this contract?** Art. 8 GDPR is about consent, but contract capacity is national law |
| Marks history, attendance locks | School's legal obligations; legitimate interests | |
| Security, malware scanning | Legitimate interests | A balancing test record is needed |
| Optional notifications | Consent, withdrawable in settings | |
| **AI study tools** | **Consent** (`privacy-policy.md` §4, §6) | See below |
| Safety reports | Legitimate interests; legal obligation | |
| Audit records, backups | Legal obligation; legitimate interests | |

**AI and consent.** The code records one consent purpose,
`terms_and_privacy`, accepted at sign-in
(`lib/features/session/data/api_session_repository.dart:271`). There is no
separate AI consent record, no withdrawal switch for AI other than not using
it, and no parental consent step for children under the age of digital
consent. Using the tool is the opt-in, after the notice in
`studyAssistantIntro`. If consent is the basis, Art. 7 (demonstrable,
specific, withdrawable) and Art. 8 (parental consent under 16 in Ireland,
under 13 elsewhere in some states) may not be met.

<!-- TODO(legal): Q4. What is the lawful basis for the AI tools: consent
(then a recorded, specific, withdrawable consent, with a parent's for
children under the threshold), or contract for paid plans, or legitimate
interests? Q5. Is Art. 8 engaged, i.e. is Studafy an information society
service offered directly to a child? If yes, what verification of parental
responsibility is "reasonable"? DL-037 left the threshold age configurable;
privacy-policy.md §5 has the same open TODO(legal). -->

<!-- TODO(legal): Q6. A DPO. The policy's §1 TODO(legal) notes that
large-scale processing of children's data is the usual case for a mandatory
DPO under Art. 37. -->

---

## 6. Necessity and proportionality

| Question | Answer from the code | Evidence |
|---|---|---|
| Is each data item needed? | Mostly yes. No DOB, phone, location, contacts or advertising IDs. Gender is optional and shown to nobody. Profile photos stay on the device | `privacy-policy.md` §3.1, §13; `docs/store/google-play-data-safety.md` §2 |
| Is there a less intrusive way? | Messaging is limited to staff-to-anyone, anyone-to-staff and guardian-to-own-child; no student-to-student messaging | DL-049 |
| Function creep | No analytics, ads or profiling SDKs. Family+ is computed by Studafy's own code, compares a child only with themselves, no AI | `privacy-policy.md` §3.5, §14 |
| Minimisation in logs | Bodies, names, emails and tokens are redacted by key; IPs are keyed hashes; about 10% of successes kept, 30 days | `apps/api/src/platform/logging.ts`; ADR-0035 |
| Minimisation for AI | No name, account ID, school or class name is put into the request; emails, links and long numbers are removed from text; material passages are capped per plan (6,000 / 16,000 / 24,000 characters) | `packages/infrastructure/src/studyAssistant.ts`; `packages/domain/src/study/studyContent.ts:44`; ADR-0037 §2 |
| Data quality | Marks are drafts until published; corrections need a reason and keep history | ADR-0033; ADR-0040 |
| Transparency | Privacy policy 1.4 in English and Arabic; in-app summary; AI notice before use | `docs/legal/`; `lib/l10n/app_en.arb` |
| Processors | Listed in policy §7.2; DPAs not signed (section 4.2) | |
| Transfers | Main systems in Germany; AI provider location unknown | Section 4.2 |

**Is the AI processing necessary?** It is not needed for the school service;
it is an optional add-on. Lessons, the notebook, set work, marks and
attendance are free and work without AI (`docs/legal/terms-of-use.md` §9).
The basic helper's free allowance is 40,000 tokens a week (ADR-0037 §3). The
proportionality case rests on: optional use, notice before use, no
identifiers sent, no server-side chat storage, grounded answers with
citations, and no AI in marking (`allowsAiGrading => false` kept on purpose,
DL-047).

---

## 7. Retention

From DL-057 (decided 2026-10-14 as proposed defaults for counsel) and
`docs/inventory/data-classification-retention-draft.md`. Enforcement is in
`supabase/migrations/202610140001_retention_schedule.sql` and
`apps/worker/src/processors/retentionSweep.ts`.

| Data | Period |
|---|---|
| Academic records, marks, attendance, hand-ins, files, messages, voice notes | School's policy where a school is controller; otherwise 12 months after the class is closed or its last teacher's account is deleted |
| Conversations (no class) | Deleted once the participants share no class and the last message is 12 months old; reported conversations kept |
| Wellbeing notes | **School's safeguarding policy; not purged with the class; no default** |
| Security and access logs | 2 years |
| Consent and account-deletion records | Life of the account plus 6 years |
| Billing | 6 years after the end of the tax year |
| Inactive accounts | Deleted after 2 years without sign-in or token refresh, after a warning that reached the person |
| Data exports | 7 days |
| Technical logs (Axiom) | 30 days (dataset setting still to be made, B7) |
| Error reports (Sentry) | Up to 90 days |
| Backups | 30 days |
| Supabase sign-in IPs | Up to 7 days, and with a session until it ends |
| AI study helper chats | On the device only, until sign-out |
| AI notes, quizzes, notebooks | Until the student deletes them or their account, or while the lesson exists |
| **AI provider's copy of requests** | **UNKNOWN, pending the DPA** |

**State of enforcement.** `RETENTION_SCHEDULE_ENABLED` is off everywhere: it
is not set in `fly.worker.toml` or `fly.test.worker.toml` and defaults to
false. It is to be switched on only after the store release carrying consent
version `2026-10-14` (launch plan D3). Until then the periods in policy §10
are not enforced by the database.

**Gaps without a timed purge (B10, from PR #47):**

1. Wellbeing notes where Studafy is the controller.
2. School-wide announcements (only class announcements are purged).
3. Notifications not tied to a class (kept until the account is deleted).
4. Roster rows with no account (a name a teacher typed that nobody claimed).

<!-- TODO(legal): confirm every period above, the 12-month class-closure
default where Studafy is controller, and a default for each of the four
gaps. Wellbeing notes most of all: a safeguarding record kept forever by
default is hard to justify; deleting one too early can harm a child. -->

---

## 8. Children's Code check

The ICO Age Appropriate Design Code applies to UK users; the DPC's
"Fundamentals" apply in Ireland. Status is from the code.

| Standard | Status | Evidence / gap |
|---|---|---|
| 1. Best interests of the child | Partly | No ads, no profiling, no student-to-student messaging. Gap: safety reports have no reviewer (R7) |
| 2. DPIA | This document | Draft |
| 3. Age-appropriate application | **Gap** | No age or date of birth is collected and there is no age gate (DL-037; `google-play-data-safety.md` decision 3). The same design applies to a 6-year-old and a 17-year-old |
| 4. Transparency | Partly | Policy in English and Arabic; in-app summary. No child-friendly version written for younger readers |
| 5. Detrimental use | Met | No ads, streaks, leaderboards or nudges found; notifications carry fixed wording |
| 6. Policies and community standards | Partly | Terms §3 rules exist; enforcement depends on moderation (R7) |
| 7. Default settings | Partly | Messaging off by default in the schema, but **on at creation for a teacher's workspace** (`202609240001_workspace_messaging_controls.sql`); content filter level `strict` is stored but no filter is applied to message text (only stored and returned in `202609170002_safe043_surface.sql`) |
| 8. Data minimisation | Largely met | Section 6 |
| 9. Data sharing | Met in design | Not sold; processors only. DPAs unsigned |
| 10. Geolocation | Met | None collected |
| 11. Parental controls | Partly | A parent sees published marks and attendance, not private messages, and a child approves a link (`privacy-policy.md` §3.5). The child is not told when a parent views their record. Consider an age-appropriate signal |
| 12. Profiling | Met for ads; AI see section 11 | Family+ compares a child only with themselves; AI is study help, not decisions |
| 13. Nudge techniques | Met | Low-allowance warning under 20% leads to the store upgrade flow (ADR-0037 §4). A student's purchase needs a guardian's approval (DL-048) |
| 14. Connected toys and devices | Not applicable | |
| 15. Online tools (rights) | Partly | Deletion and export in the app (section 9) |

---

## 9. Data subject rights: how they work in the code

| Right | Implementation | Evidence | Gap |
|---|---|---|---|
| Information (Arts. 13-14) | Privacy policy 1.4; in-app summary; AI notice before use | `docs/legal/privacy-policy.md`; `lib/l10n/app_en.arb` | No version for young children |
| Access (Art. 15) and portability (Art. 20) | Account → Download my data, behind a fresh sign-in; worker builds a JSON document of the requester's own data; kept 7 days | DL-051; `private.data_export_document` in `supabase/migrations/202610110004_account_deletion_gaps.sql` | The export holds profile, memberships, guardian links, published grades, attendance, submission titles and status, notebooks, study notebooks, devices, messages sent, reports filed, blocks, consents, purchases, entitlements, notifications. **It leaves out** online exam answers, hand-in text and files, messages received, mark and attendance history, wellbeing notes shared with the family, and the AI usage ledger |
| Rectification (Art. 16) | Profile fields in the app; marks and attendance through the teacher, recorded as a correction | `privacy-policy.md` §11; ADR-0033 | Manual by email otherwise |
| Erasure (Art. 17) | Account → Delete account after a fresh sign-in (within 600 s); 14-day grace; worker de-identifies; managed children are deleted with their parent; legal holds pause it | DL-051; launch-work-plan 2.10; `docs/legal/delete-account.md`; `privacy-policy.md` §9 | Deletion is de-identification, not erasure, for records kept for the school (messages already sent, marks, audit) |
| Restriction (Art. 18), objection (Art. 21) | By email to hello@studafy.com | `privacy-policy.md` §11 | No tooling; manual |
| Withdraw consent | Notifications in settings; AI by not using it | | No AI consent to withdraw (section 5.2). No endpoint sets `consent_records.withdrawn_at` |
| Automated decisions (Art. 22) | None with legal or similar effect; AI never marks work | `privacy-policy.md` §14; DL-047 | |
| Requests where the school is controller | Passed to the school | `privacy-policy.md` §11 | No process or contact list for schools yet |

---

## 10. Risk register

Scale (ICO template): **likelihood** Remote / Possible / Probable;
**severity** Minimal / Significant / Severe; **overall** Low / Medium / High.
"Inherent" is before the measures already in the code; "Residual" is after
them, with the open measures in section 15 not yet done.

| # | Risk to people | Likelihood × severity (inherent) | Measures already in the code, with evidence | Residual |
|---|---|---|---|---|
| R1 | **A child's data is sent to an AI provider with no processor contract**, may be kept, used to train models, or moved outside the EEA without a transfer basis | Probable × Severe = **High** | AI off in production: `AI_LESSON_TOOLS_ENABLED="false"` (`fly.api.toml:43`) and `AI_API_KEY` to stay unset (DL-056); pinned HTTPS origin; no identifiers sent; redaction (section 11) | **High until the DPA is signed.** The basic helper runs whenever `AI_API_KEY` is set, whatever the flag says (`docs/security/credentials-map.md`; `apps/api/src/study/routes.ts` `available()`). Two documents point the other way: `docs/deployment/fly-io.md` (production API secrets list, around line 120) tells the operator to set `AI_API_KEY`, and ADR-0034 says production runs with `AI_LESSON_TOOLS_ENABLED=true`. One wrong step turns the helper on for real children |
| R2 | **Wellbeing and safeguarding notes are seen by the wrong person** or kept too long | Possible × Severe = **High** | Visible only to the class's teachers and, if shared, the family; never other students (`privacy-policy.md` §3.4); RLS fix for removed authors (migration `202610080001`) | Medium. No default retention where Studafy is controller (B10) |
| R3 | **Unauthorised access to another class's or family's records** (broken access control) | Possible × Severe = **High** | Database RLS on every table; server-derived tenants; permission catalogue tested; guardian link needs the child's approval; Studafy-ID lookups capped at 10 an hour with Turnstile | Low-Medium. Not penetration-tested (security audit, scope note). A valid Studafy ID returns the student's display name to the adult who entered it, before the student approves (`packages/contracts/src/v1/family.ts`) |
| R4 | **A child is contacted by an adult who should not reach them** through messaging | Possible × Severe = **High** | Contact policy: staff to anyone, anyone to staff, guardian to own verified child only (DL-049); blocks with no off switch (ADR-0021); content-free notifications | Medium. Any adult can create a teacher workspace and invite children to join a class; staff can message anyone with a membership in their school, not only their own class (`private.can_contact`, `supabase/migrations/202609190005_messaging_safeguards.sql`); no message content filter is applied; messaging is on by default in a teacher's workspace |
| R5 | **Account takeover or a stolen phone** exposes a child's records, or deletes the account | Possible × Significant = Medium | Provider sign-in only; session in the platform keystore (DL-034); fresh sign-in within 600 s before deletion, export and device sign-out (launch-work-plan 2.10); 14-day grace | Low-Medium. With push and email off, the owner is not told of a deletion request |
| R6 | **Malicious files** reach children | Possible × Significant = Medium | Quarantine, structural analysis (polyglots, macros, PDF JavaScript, bombs), self-hosted ClamAV, image metadata strip, single-use download grants (DL-044; ADR-0037 §1; `infra/scanner/`) | Low. Production scanner app `studafy-scanner` not yet deployed (A6) |
| R7 | **A safety report about a child is never reviewed** | Probable × Severe = **High** | Reports, evidence, masking and escalation exist (ADR-0021) | **High.** Report queues are visible only to a school administrator or a holder of a two-person, MFA-gated operator grant (`private.safe043_can_access_reports`, `supabase/migrations/202609170002_safe043_surface.sql:49`). No school administrator exists, and no operator console was found (readiness PR-28). B9 names no reviewer yet |
| R8 | **Children cannot understand or use their rights**, or a parent controls a child's account beyond the child's interest | Possible × Significant = Medium | Deletion and export in the app; child approves a parent's link | Medium. No age-appropriate explanations; a parent fully controls a managed child's account (ADR-0031) |
| R9 | **Inaccurate records** (a wrong mark or attendance) harm a child | Possible × Significant = Medium | Draft until published; corrections need a reason; full history; family told of changes (ADR-0033, ADR-0040) | Low |
| R10 | **Data kept longer than needed** | Probable × Significant = **Medium** | Schedule built and tested (DL-057) | Medium until `RETENTION_SCHEDULE_ENABLED` is on in production (D3) and B10 is answered |
| R11 | **A leak through logs, errors or alerts** | Possible × Significant = Medium | Key-based log redaction; keyed IP hashes; Sentry personal data off and scrubbed (ADR-0035; `packages/infrastructure/src/sentry.ts`; `lib/core/crash_reports.dart`) | Low-Medium. Native crash path not checked yet (observability review, recommendation 2; B6). Test and production share one Axiom dataset (`studafy-production`). `user_id` is logged in clear (recommendation 4 left this to the DPIA: see measure M11). The worker's logger has no redaction wrapper; its log calls carry IDs only (`apps/worker/src/index.ts`). Raw IPv4 addresses are in Redis rate-limit keys (D12) |
| R12 | **Backups exposed** | Remote × Severe = Medium | Encrypted with age before leaving the runner; private key held outside every service (`docs/deployment/backups.md`) | Medium. The repository is **public**, and the backups are GitHub Actions artifacts (`.github/workflows/backup.yml`, `actions/upload-artifact`). Artifacts of a public repository can be downloaded by any signed-in GitHub user, so the ciphertext of the database is effectively public, and its safety rests on the one key. Move backups to a private repository or private storage |
| R13 | **Transfers without a legal basis** (Fly.io, Axiom, Sentry, GitHub, Resend, Cloudflare, Google, Together) | Probable × Significant = **Medium** | EU regions chosen where offered (ADR-0035) | Medium until each DPA and mechanism is confirmed |
| R14 | **Test copy holds real people's data** in a weaker configuration | Possible × Significant = Medium | Separate production project recommended (B2) | Medium. The test copy runs in development mode (test Turnstile keys, no HSTS) and the AI is on there (`fly.test.api.toml`, `fly.test.worker.toml`); use only synthetic material and the owner's own test accounts until production is separate |
| R15 | **Breach not handled within 72 hours** | Possible × Severe = **High** | Alerts by Telegram and email (ADR-0035) | High. No written incident procedure (`privacy-policy.md` §12 TODO(legal)); no named on-call (B9) |

AI-specific risks are in section 11 (R1 above is the summary).

---

## 11. AI risks in detail

### 11.1 What the provider receives

From `packages/infrastructure/src/studyAssistant.ts` (one outbound call to
`/v1/chat/completions` on the pinned origin, `https://api.together.xyz`,
model `Qwen/Qwen3.5-9B`, `fly.test.api.toml`), `apps/api/src/study-assistant/routes.ts`,
`packages/domain/src/study/grounding.ts` and
`apps/worker/src/processors/materialIndex.ts`:

| Input | When | Redacted? |
|---|---|---|
| The question typed | Every helper request | Emails, links, long numbers removed (`redactForProvider`) |
| Earlier turns of the same chat (up to the plan's memory budget) | Follow-ups | Same; each turn cut to a maximum length |
| Passages of the student's chosen lessons, files, links or own notes | Behind `AI_LESSON_TOOLS_ENABLED`; read server-side with the lesson's own visibility rule | Same redaction; wrapped as labelled data with markers neutralised |
| Photos the student attaches (up to 3) | Plus and Max only; resized to at most 1,600 px | **Not redacted: image content goes as is.** The photo is also kept on Studafy's servers as an `assistant_attachment` file until the account is deleted (`supabase/migrations/202610140001_retention_schedule.sql`, personal files released on deletion) |
| Whiteboard photos | Plus and Max | Not redacted |
| Images of scanned teacher file pages | Worker, background reading | Not redacted |
| Class grade level and app language | Every request | Grade text redacted and cut to 20 characters |
| API key | Header | — |

**Not sent:** the student's name, account ID, school or class name, marks,
attendance, messages (`studyAssistant.ts` header comment;
`privacy-policy.md` §6). No `user` field or other identifier is in the
request body. The provider still sees Studafy's API key and the server's IP
address, so all requests are linkable to Studafy, not to a student.

File names, lesson titles and note titles are sent (redacted, but they can contain names). Generated replies are also held for about 24 hours in `public.idempotency_records` so a retried request gets the same answer (`apps/api/src/platform/idempotency.ts`).

**Not sent: any no-training or no-retention instruction.** The request body
carries `model`, `max_tokens`, `temperature`, `reasoning` and `messages`
only. Whether Together AI keeps or trains on API inputs depends on its terms
and account settings, which the repository cannot show.

### 11.2 AI risk register

| # | Risk | L × S (inherent) | Measures in the code | Residual | Needs the DPA? |
|---|---|---|---|---|---|
| AI1 | **Children's data sent to the provider is retained, used for training, or accessed by its staff** | Probable × Severe = High | No identifiers; redaction; chats not stored by Studafy | **High** until a DPA forbids training and sets retention | **Yes**: training ban, retention period, sub-processors, deletion, audit, breach notice. `privacy-policy.md` lines 378-380 already wait on this |
| AI2 | **Transfer to the US** without a mechanism | Probable × Significant = Medium-High | None technical | High | **Yes**: SCCs or DPF certification; a transfer impact assessment. Or an EU-hosted provider (ADR-0034 allows switching provider) |
| AI3 | **Identifying content gets through redaction**: a name typed in a question, a face or a name on a photo, a class list in a teacher's file | Probable × Significant = Medium | Notice before use (`studyAssistantIntro`); redaction of emails, links, numbers; EXIF stripped from uploads (DL-044) | Medium. Redaction is "best effort" by design (`studyContent.ts` comment) | Partly: the DPA covers what the provider does with it |
| AI4 | **Hallucination**: wrong facts in notes, quizzes or answers that a child learns from | Probable × Significant = Medium | Answers grounded on the lesson's material with citations; labels the model invents are dropped; "Beyond your materials" marks general knowledge; unread sources named; accuracy warning (`studyAssistantCheckWork`); terms §8; AI never marks work (ADR-0037 §2) | Medium. No way for a student or teacher to flag a wrong answer; shared lesson notes and quizzes are seen by the whole class, so one error spreads | No |
| AI5 | **Harmful or age-inappropriate output**, or a child disclosing harm to the helper | Possible × Severe = Medium-High | System prompts limit the helper to schoolwork and say "Never ask for personal details" (`studyContent.ts` `STUDY_PROMPTS`); temperature 0.3 | **Medium-High.** No moderation or safety classifier on input or output; a disclosure of abuse to the helper goes nowhere, because chats are not stored and nobody is alerted | Partly: ask the provider what safety filtering it applies |
| AI6 | **Prompt injection** through teacher files or links | Possible × Significant = Medium | Material wrapped as labelled data the model is told not to obey; markers neutralised; the model has no tools; replies are not made into links (security audit, "Live prompt injection" note) | Low-Medium. Assessed by design review only | No |
| AI7 | **Profiling or automated decisions** about children | Remote × Significant = Low | No AI in marking; Family+ uses no AI; the usage ledger holds counts, not content (ADR-0037 §3) | Low | No |
| AI8 | **Cost pressure leads to nudging** a child to buy | Possible × Minimal = Low | Allowance shown; the upgrade goes through the store with a guardian's approval (DL-048) | Low | No |
| AI9 | **Access beyond what the child may see**: exam papers, answer keys, other students' work fed to the model | Remote × Significant = Low | Retrieval re-checks the lesson's visibility on every request; exam papers, answer keys, grades, submissions and other students' notes are never indexed (ADR-0037 §2) | Low | No |
| AI10 | **AI used by people the policy does not describe** (parents, teachers) or by children with no school | Possible × Minimal = Low | The basic helper needs only a signed-in account: `study_assistant.ask` has `scope: "self"` and `tenantRequired: false` (`apps/api/src/authorization/catalogue.ts:581-591`) | Low; correct the policy or restrict the route | No |

### 11.3 What the provider agreement must say

<!-- TODO(legal): the Together AI DPA (or another provider's) must cover, at
least:
- processor role only; processing on Studafy's documented instructions;
- no training, fine-tuning or evaluation on Studafy's inputs or outputs;
- retention of prompts and outputs: none, or a stated short period for
  abuse monitoring, then deletion;
- processing locations and sub-processors, with notice of changes;
- transfer mechanism (SCCs Module 2, or DPF) and a transfer impact
  assessment;
- that inputs may contain children's data and images of children;
- security measures, breach notice within a fixed time, audit rights;
- deletion or return at the end;
- whether any safety filtering is applied, and whether flagged content is
  reviewed by humans.
Then record an ADR superseding ADR-0026 (launch-work-plan 6.3) and add to
privacy-policy.md §4: "and we do not permit our providers to." -->

---

## 12. Where the code and the privacy policy disagree

Found while writing this draft. Each needs either a code change or a policy
change; a policy change that is substantive needs a new consent version
(`privacy-policy.md` header comment).

| # | The policy says | The code does | Files |
|---|---|---|---|
| D1 | "Names, email addresses and marks are never sent" to the AI provider (§2); "What is never sent: the student's name ..." (§6) | Studafy never adds a name, but redaction removes only emails, links and long numbers. A name typed in a question, written on a photographed page, or in a teacher's file is sent | `privacy-policy.md` §2, §6; `packages/domain/src/study/studyContent.ts:44-49` |
| D2 | AI study tools: lawful basis "Consent" (§4) | Only a bundled `terms_and_privacy` consent is recorded; no AI-specific consent, no parental consent, no withdrawal record | `privacy-policy.md` §4; `lib/features/session/data/api_session_repository.dart:271` |
| D3 | "We do not knowingly permit a child to create an account outside a school context where their country requires parental consent" (§5) | No age or date of birth is collected and there is no age gate; any person can sign in with Google, Microsoft or Apple and use the basic AI helper without joining a class | `privacy-policy.md` §5; `apps/api/src/authorization/catalogue.ts:581-591`; DL-037 |
| D4 | Study helper: "Every student" (§6 table) | Any signed-in account can call `POST` on the helper, including parents and teachers | `apps/api/src/authorization/catalogue.ts:581-591`; `apps/api/src/authorization/middleware.ts:99-106` |
| D5 | Retention periods in §10 stated as what happens ("deleted 12 months after ...") | The purges are off everywhere (`RETENTION_SCHEDULE_ENABLED` unset; launch plan D3). Axiom's 30-day retention is a dashboard setting not yet made (B7) | `privacy-policy.md` §10; `fly.worker.toml`; `docs/operations/observability-review-2026-10.md` |
| D6 | "Access a copy of your data ... Portability" (§11) | The export leaves out online exam answers, hand-in contents and files, voice notes, messages received, mark and attendance history, and AI usage | `privacy-policy.md` §11; `supabase/migrations/202610110004_account_deletion_gaps.sql` (`private.data_export_document`) |
| D7 | "Anyone can report a message or a person ... it can be acted on" (§3.7; terms §3) | Only a school administrator (none exists) or a two-person operator grant can see reports | `privacy-policy.md` §3.7; `docs/legal/terms-of-use.md` §3; `supabase/migrations/202609170002_safe043_surface.sql:49-53` |
| D8 | Error reports "carry no name, email, account identifier" (§3.12) | True for Dart errors; not yet checked for native iOS and Android crashes, which bypass the Dart scrubber | `privacy-policy.md` §3.12; `docs/operations/observability-review-2026-10.md` recommendation 2; launch plan B6 |
| D9 | §7.2 table lists "A malware-scanning service ... See §8" as a processor | The text below the table and §1.4's change list say the scanner is self-hosted in Frankfurt. The table row is stale | `privacy-policy.md` §7.2; `fly.scanner.test.toml`; `infra/scanner/` |
| D10 | §7.2 lists processors | Telegram (alert titles), Cloudflare Workers (the alert relay) and the optional AWS S3 backup copy (default region `il-central-1`) are not listed. Alerts carry titles and code locations only, so this may not be personal data; confirm | `ops/alert-relay/src/index.ts`; `.github/workflows/backup.yml` |
| D11 | §12: "Files are stored privately"; GitHub "cannot read" backups (§7.2) | True for content, but the encrypted backups are artifacts of a public repository, downloadable by any signed-in GitHub user | `.github/workflows/backup.yml`; `gh repo view` (visibility PUBLIC) |
| D12 | IP addresses are not stored "in readable form" in "our own records and logs" (§3.2); Redis holds "hashed identifiers" (§7.2, §3.12) | Rate limits before sign-in use the raw IPv4 address (or IPv6 /64) in the Redis key, for the length of the rate-limit window. The code comment itself says "never the raw address" while doing this for IPv4 | `privacy-policy.md` §3.2, §3.12, §7.2; `apps/api/src/platform/rate-limit/middleware.ts:168-173`; `apps/api/src/platform/rate-limit/policies.ts:9-13` |
| D13 | §6 "What we keep": notes, quizzes, flashcards and notebooks; chats only on the device | Photos sent with a helper question are also stored on the server until the account is deleted; §10 gives them no period. §9 does mention deleting them with the account | `privacy-policy.md` §6, §9, §10; `supabase/migrations/202610140001_retention_schedule.sql` (`assistant_attachment`) |

Not disagreements, but worth noting: the in-app summary
(`policyPrivacyBody`) and the policy agree on the points above, so D1-D4
apply to the in-app text too. `docs/inventory/data-flow-inventory.md` is
dated 2026-09-10 and predates the AI rebuild; it still says "No AI egress
exists".

---

## 13. Open questions that block sign-off

| # | Question | Owner | Blocks |
|---|---|---|---|
| Q-A | **AI DPA** with Together AI or another provider: training ban, retention, location, transfer mechanism (section 11.3) | Owner, counsel (launch-work-plan 6.1; B1) | AI on in production; R1, AI1, AI2 |
| Q-B | **Decide AI at launch** (B1): without Plus/Max, Plus/Max without AI, or DPA and DPIA first | Owner | This DPIA's AI conclusion |
| Q-C | **Retention questions from PR #47** (B10): wellbeing notes where Studafy is controller, school-wide announcements, other notifications, roster rows with no account | Counsel | R2, R10 |
| Q-D | **Named owners** (B9): security, privacy, safeguarding contact, report reviewer, incident on-call | Owner | R7, R15; sign-off section |
| Q-E | Controller/processor roles and lawful bases (section 5, Q1-Q5); a school contract | Counsel | Section 5 |
| Q-F | Age threshold and parental consent (Art. 8; DL-037; policy §5 TODO) | Counsel | D2, D3 |
| Q-G | Are wellbeing notes special-category or criminal-offence data? | Counsel | R2, store answers |
| Q-H | DPO: appoint or record why not | Owner, counsel | Policy §1 |
| Q-I | Transfer mechanisms and DPAs for every processor (section 4.2); Jordan PDPL | Counsel | R13 |
| Q-J | Meetings at launch (B8): attendee emails go to Google | Owner | Section 4.2 |
| Q-K | Incident response procedure (policy §12 TODO) | Owner | R15 |

---

## 14. Consultation

| Who | How | Status |
|---|---|---|
| Counsel | Review this draft and the TODO(legal) items | Not started |
| Data Protection Officer (if appointed) | Art. 35(2) advice | No DPO (Q-H) |
| Schools and teachers | Pilot schools: what records they expect, retention instructions, who handles reports | Not started. TODO |
| Parents | A short survey or pilot feedback on the AI tools and family visibility | Not started. TODO |
| Children | Age-appropriate feedback through pilot schools (Children's Code standard 2 expects children's views where possible) | Not started. TODO |
| Processors | Together AI (DPA terms, safety filtering, retention); others' DPAs | Not started |
| Data Protection Commission | Prior consultation under Art. 36 if a high residual risk remains | **Likely needed for the AI tools** if R1/AI1 stay High. TODO(legal) |

<!-- TODO(legal): decide whether Art. 36 prior consultation with the DPC is
required for any residual high risk, in particular AI processing of
children's data, before turning the AI tools on. -->

---

## 15. Measures to take, and sign-off

### 15.1 Measures

Measures M1-M5 are needed before real children use the app; M6 onwards
before the AI tools are switched on or soon after launch, as marked.

| # | Measure | Reduces | Who | When |
|---|---|---|---|---|
| M1 | Name a report reviewer and give them a working way to see and act on reports (operator console or a teacher-level queue), with a response time | R7, D7 | Owner (B9), then Claude | Before launch |
| M2 | Write the incident response procedure; name the on-call | R15 | Owner | Before launch |
| M3 | Move backups out of public GitHub artifacts (private repository, or private object storage in the EU) | R12, D11 | Owner, then Claude | Before real data |
| M4 | Keep AI off in production (`AI_API_KEY` unset) until the DPA is signed and this DPIA is approved | R1, AI1, AI2 | Owner | Until Q-A, Q-B |
| M5 | Separate production from the test copy (new Supabase project, own Axiom dataset or an environment filter on monitors) | R11, R14 | Owner (B2), Claude | Before launch |
| M6 | Correct the policy where it overstates (D1, D4, D9, D10), in a new consent version if counsel says the change is substantive | D1, D4, D9, D10 | Claude, counsel | Before AI on |
| M7 | Decide and build the AI lawful basis: a specific AI consent with a parent's consent below the threshold, recorded and withdrawable; or another basis counsel prefers | D2, AI1 | Counsel, then Claude | Before AI on |
| M8 | An age signal: ask a student's age band (not a date of birth), use it to decide parental consent for AI and the default settings | D3, Children's Code 3 | Counsel, then Claude | Before AI on |
| M9 | A "report this answer" control on AI answers and shared study sets, reviewed by the teacher or the report reviewer | AI4, AI5 | Claude | Before AI on |
| M10 | An input/output safety check on the helper (provider moderation or a classifier), and signposting to a trusted adult and the school's safeguarding contact when a disclosure is detected | AI5 | Claude, owner | Before AI on |
| M11 | Log a keyed hash of `user_id` instead of the raw UUID, or keep the raw UUID and record the reason here | R11 | Owner decides; Claude | Soon after launch |
| M12 | Turn on the retention purges after the consent-version release (D3), and answer B10 | R10, D5 | Owner, counsel | Launch day |
| M13 | Complete the export: exam answers, hand-in contents, messages received, mark history, AI usage | D6 | Claude | Soon after launch |
| M14 | Child-friendly privacy information (short, plain, Arabic and English), and a note to the child when a parent links or views | Children's Code 4, 11 | Claude, counsel | Soon after launch |
| M15 | Apply an actual message content filter, or remove the `content_filter_level` setting so it does not suggest one exists | R4 | Claude | Soon after launch |
| M16 | Check one native crash in Sentry shows the user as anonymous (B6) | R11, D8 | Owner | Before launch |
| M17 | Independent penetration test of access control | R3 | Owner | Before or soon after launch |
| M18 | Correct `docs/deployment/fly-io.md` and ADR-0034 so neither tells an operator to turn AI on in production before sign-off; add a startup refusal for `AI_API_KEY` in production until an explicit approval flag is set | R1 | Claude | Before launch |
| M19 | Key pre-sign-in rate limits by an HMAC of the IP prefix, like the account and tenant keys | D12 | Claude | Before launch |
| M20 | Delete helper photos after a short period (for example 30 days), and state it in §6 and §10 | D13, AI3 | Claude, counsel | Before AI on |

### 15.2 Sign-off

| Item | Name | Date | Notes |
|---|---|---|---|
| Measures approved by | | | |
| Residual risks approved by | | | If any High remains, consider Art. 36 consultation |
| DPO advice provided | | | |
| DPO advice accepted or overruled (with reasons) | | | |
| Consultation responses reviewed by | | | |
| AI tools: approved to switch on | | | Requires Q-A, Q-B, M4, M7, M9, M10 |
| This DPIA will be reviewed by | | | At least yearly, and on any change of AI provider, model, data sent, or new feature handling children's data |

---

## Change history

- 2026-10-15: first draft (launch plan A5 / work plan 6.2).
