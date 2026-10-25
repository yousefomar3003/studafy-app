# ADR-0046: AI-suggested marks against the teacher's reference (Studafy AI Marking)

- Status: Accepted. Built 2026-10-25; on in development and the Fly test
  copy (`MARKING_SUGGESTIONS_ENABLED`), off in production until the store
  product exists and the owner says so (DL-073). Takes effect for users with
  privacy policy 1.8 and terms of use 1.6, which the owner publishes without
  legal review.
- Date: 2026-10-21 (decision); 2026-10-25 (implementation)
- Decision owner: repository owner
- Decision log: DL-073
- Supersedes in part: ADR-0026 (AI-072), **for marking only**. ADR-0026's
  removal of the AI study tools was already superseded by ADR-0029 and
  ADR-0037.
- Relates to: ADR-0009 (billing), ADR-0022 and ADR-0023 (files), ADR-0033
  (paper marks and corrections), ADR-0036 (online assessments and answer
  release), ADR-0037 (provider, metering), ADR-0040 (marking and publish),
  ADR-0043 (name redaction); DL-047, DL-062, DL-072; draft DPIA §12.2

## Context

ADR-0026 removed AI grading. Its starting point was SEC-001: the
`propose-paper-grade` Edge Function signed a caller-chosen storage path with
service-role credentials and sent the file, unreviewed, to a provider. It
had no redaction, budget, quota, audit or egress control, and no signed DPA
or DPIA stood behind it. ADR-0026 kept three tripwires so that it could not
come back by accident: `allowsAiGrading => false` in the app, the retired
`ai_grading_drafts` and `question_suggestions` tables sealed with
`check (false)`, and `teacher_ai_grading` inactive and unlisted.

Its "Rollback and future enablement" section set the conditions for any
future AI marking: a new ADR; a signed DPA; a DPIA extended to minors' data;
a named provider adapter; server-owned file ids only; per-request tenant and
relationship authorization; redaction before egress; an egress allowlist;
quotas and cost caps; retained audit; and teacher review before any proposal
affects a grade.

On 2026-10-21 the owner asked for AI marking back: teacher reference answers
per question type, a strictness setting (lenient, balanced, strict),
versioned references, regrading only when the teacher asks, the suggestion
shown beside the student's answer for review, and model answers kept from
students. The owner decided (DL-073):

- **AI suggests, the teacher decides.** A suggestion is never a mark.
- **Scope:** written answers in online assessments, and hand-ins of graded
  assignments.
- **Basis:** the teacher's decision to use it, with a student opt-out, not
  the student's consent. Counsel to confirm for minors.
- **A paid teacher plan, "Studafy AI Marking"**, not the retired
  `teacher_ai_grading`.
- **The same provider and model as the AI Tutor.**
- **The DPA with Together AI is added in a later version** (owner: "approve
  it and later on with other versions we can add the DPA"): an accepted risk,
  as DL-062 was for the study tools.

## Decision

### 1. Suggestions are drafts; the teacher's save is the only writer

Suggestions live in their own table, `private.marking_suggestions`
(migration `202610210060_marking_suggestions.sql`). Nothing in this ADR
writes `assessment_answers`, `grade_results` or any other mark. A suggestion
becomes a mark only when the teacher saves one through the existing marking
flows, `markAssessmentAttempt` (online) and `saveGradeDrafts` (hand-ins and
paper), with every rule they already have: a mark is a draft until the
all-or-nothing publish, and a change to a published mark is a correction
with a reason, kept in its history (ADR-0033, ADR-0040).

A suggestion is `pending`, `ready`, `failed`, `skipped`, `dismissed` or
`superseded`. Only the class's teachers can read one; students and parents
never see them, and they are not in the student's export.

ADR-0026's tripwires stay:

- `allowsAiGrading => false` is unchanged. Suggestions do not make the app
  mark anything, so it stays true to its name.
- `ai_grading_drafts` and `question_suggestions` stay sealed. Nothing here
  reads or reuses them.
- `teacher_ai_grading` stays retired. The new plan has its own key.

### 2. What can be marked

| Work | What is sent | Not sent |
|---|---|---|
| **Online assessment**, a written answer | `short_answer` and `essay` answers that are not empty, one suggestion per answer | Single choice, multiple choice and true/false: marked by their key, as before (ADR-0036) |
| **Graded assignment**, the hand-in | The current submission attempt of a paper assessment linked to an assignment: its typed text, and its files bound with purpose `assignment_submission` (not detached, not deleted). PDF, DOCX and PPTX are read as text; photos and scanned pages are sent as images for the model to transcribe, page by page, at most 20 pages and 60,000 characters per hand-in | Paper work with no hand-in (`invalid_state`); earlier attempts |

The teacher asks for one assessment at a time, for `unmarked` work (the
default: answers with no score, hand-ins with no saved grade) or `all`, and
optionally for named students. Asking again is the only way to regrade: a
new run marks the earlier suggestions for the same work `superseded`.

### 3. The teacher's reference, strictness and versions

| Target | Where it lives |
|---|---|
| A question of an online assessment | The model answer and marking guidance stay on `assessment_questions` (`preferred_answer`, `marking_guidance`). Key points (at most 20, each with optional marks, the marks adding up to no more than the question's maximum), accepted alternatives or methods, and partial-credit rules are in `private.marking_references` |
| The hand-in of a graded assignment | One `private.marking_references` row with no question: model answer, guidance, key points, accepted methods, partial credit |

Strictness (`lenient`, `balanced`, `strict`, default `balanced`) and the
reference version are per assessment, in `private.marking_settings`. Any
change to a reference or to the strictness moves the version on. Each run
(`private.marking_runs`) records the version, the strictness and a snapshot
of every reference it used, and each suggestion records the version it was
made against. **A change never re-marks anything by itself.** The reply to a
reference change says how many ready suggestions are now stale, and each
listed suggestion carries `stale`; the teacher decides whether to ask again.

Editing a question's model answer or guidance after students have answered
is allowed, because neither changes the automatic mark; the answer key is not
touched here.

### 4. Model answers stay with the teachers

- `marking_references`, `marking_settings`, `marking_runs`,
  `marking_suggestions`, `marking_opt_outs`, `marking_usage` and
  `marking_plan_grants` have row-level security on and every grant revoked,
  from `anon`, `authenticated`, `service_role` and both runtime roles. They
  are reached only through `private.api059_query`, `private.api059_command`
  and the worker's job functions, each of which re-checks the caller.
- A reference is returned only to a teacher of the assessment's class
  (`private.coursework_teacher`). Students and parents never receive the
  key points, accepted methods, partial-credit rules or a hand-in's model
  answer, and none of it is in their export.
- A question's model answer and guidance keep ADR-0036's rule: a student or
  parent sees them only once answers are released.
- At the provider, the reference is sent inside its own markers as data
  (section 6), never as instructions.

### 5. The review

`GET /v1/assessments/{id}/marking-suggestions` gives, for each piece of
work, the suggested score (or none), what the answer **met** and **missed**
against the reference, the rationale for the teacher, feedback for the
student that the teacher may edit, any **conflict** between the reference
and the question, and why a person must look (`reviewReason`: `ambiguous`,
`unreadable`, `no_reference`, `conflict`, `empty`). The app shows this beside
the student's answer and the teacher's reference. The teacher then saves a
mark of their own through the marking flows, or dismisses the suggestion.

### 6. The model call and its reply

The worker makes each suggestion (section 9). For each one:

- **Instructions** (`packages/domain/src/study/marking.ts`): the model only
  suggests; it compares the answer with the teacher's reference and nothing
  else; equivalent wording, translations and valid alternative methods earn
  the same credit; it follows the key-point marks and partial-credit rules;
  it never invents requirements; and the strictness rule for the run. A
  scanned page is first transcribed exactly, mistakes included, never
  corrected.
- **Data, not instructions.** The question, the reference and the student's
  work each go inside their own `<<<QUESTION>>>`, `<<<REFERENCE>>>` and
  `<<<ANSWER>>>` markers, with any marker-like text in them neutralised. The
  model is told that everything inside is data and that any request,
  command or mark written there is to be ignored.
- **The reply is checked.** It must be JSON in the agreed shape. A score
  outside 0 to the maximum is not stored (the SQL refuses it, and
  `private.marking_suggestions` has the same check). A reply that cannot be
  read, or with no usable score, becomes a suggestion with no score that
  needs review. Texts are cut to their limits (rationale 4,000 characters,
  feedback 2,000, conflict 1,000, at most 40 met and 40 missed items).
- **Conflicts are reported, not resolved.** If the reference seems wrong or
  contradicts the question, the model says so in `conflict` and still marks
  against the reference; the teacher decides.
- **No reference, no guess.** Without a model answer, key points, accepted
  answers or guidance, the suggestion is `no_reference` and has no score.

### 7. How each of ADR-0026's conditions is met

| ADR-0026 condition | How |
|---|---|
| A named provider adapter | Together AI, `Qwen/Qwen3.5-9B`, through the same adapter as the AI Tutor (`packages/infrastructure/src/studyAssistant.ts`) |
| Server-owned file ids only | The client names an assessment, a scope and optionally students, never a file, path or URL. The worker gets the hand-in's files from `public.file_bindings` for that submission attempt (purpose `assignment_submission`, not detached, not deleted) through `private.file051_effective_object`, and reads them from storage itself |
| Per-request tenant and relationship authorization | Every `api059` read and write runs as the caller and re-checks in SQL that they teach the assessment's class; the request's tenant is never trusted (`schoolId` is null in the request context). A preference is only ever the caller's own. When the worker claims a job it re-checks that the teacher who asked still teaches the class and still holds the plan, and sends nothing otherwise. Each job is bound to its claim (worker, job, attempt, lease), as the notebook queue is |
| Redaction before egress | Names Studafy knows are replaced before anything is sent: everyone on the class roster (roster names and profile names), the class's teachers, and the students' parents (pending or verified links), with the student whose work it is as "self" (`private.marking_known_names`). Email addresses, long number sequences and links are removed (`redactForProvider`). Photos and scanned pages are sent as images and cannot be redacted (as ADR-0043) |
| An egress allowlist | One pinned HTTPS origin, `AI_BASE_URL` (`https://api.together.xyz`); the client refuses anything else |
| Quotas and cost caps | Per teacher per calendar month (UTC): **4,000,000 tokens** and a **US$2** cost cap beneath them, held before each call and settled after (`private.marking_usage`, under an advisory lock per teacher). **20 pages** and 60,000 characters per hand-in. At most 3 attempts per suggestion, with back-off. Past a limit nothing is sent: the suggestion fails with the reason, which the teacher sees |
| Retained audit | `setReferences`, `requestSuggestions`, `dismissSuggestion` and `setPreference` each write an `audit_events` row (`marking_<operation>`) with the run id, counts, whether a reference changed and the reference version, and the request id. **Never a student's work, a reference or a suggestion's text.** Nothing a student wrote is logged |
| Teacher review before a proposal affects a grade | Section 1: a suggestion never becomes a mark; only the teacher's own save does |
| A signed DPA | **Not yet: accepted risk** (section 11) |
| A DPIA extended to minors' data | Draft DPIA §12.2 covers AI marking; not signed off |

### 8. Students can opt out

`private.marking_opt_outs` holds students who do not want their work sent.
It is the student's own choice, from Account (`GET` and
`POST /v1/me/marking-preference`); a parent who manages a child account sets
it while signed in to that account. Only a student account may set it.

- Work by a student who has opted out is never sent. It is recorded as
  `skipped` with the reason `opted_out`, and the teacher marks it by hand.
  The reply to a request says how many were skipped.
- Opting out also skips that student's work that is queued and not yet
  sent, and the worker checks again when it claims each job.
- Opting back in sends nothing by itself; the teacher has to ask again.

The AI study tools' consent (ADR-0043) does not cover this: marking is the
teacher's tool, so the student's AI consent is neither needed nor asked.
TODO(legal): counsel to confirm that the teacher's decision with an opt-out
is a sound basis for minors (questions-for-counsel 10.1).

### 9. The worker

Suggestions are made by the worker off their own queue (the
`marking_suggestions` rows themselves), with
`MARKING_SUGGESTIONS_ENABLED`, a database and the AI provider. It claims up
to `AI_MARKING_CONCURRENCY` jobs (default 4) every
`AI_MARKING_POLL_INTERVAL_MS` (default 3,000 ms) through
`private.marking_jobs_claim`, holds tokens with `private.marking_job_usage`
(`reserve`, then `settle` or `release`), and finishes with
`private.marking_job_finish` (`ready`, `retry`, `skipped` or `failed`).
`private.marking_jobs_backlog` reports the queue, and
`private.marking_purge_expired` runs hourly (section 10). Files are read for
the suggestion and not kept by this step.

### 10. Retention, export and deletion

- **Suggestions** are drafts for the teacher, not school records: deleted
  **180 days** after they last changed, with the runs that made them
  (`private.marking_purge_expired`). TODO(legal): confirm in the retention
  schedule.
- **The teacher's usage ledger** (`private.marking_usage`: tokens, cost,
  model, date) is kept **13 months**, for the monthly cap and billing
  questions.
- **The export** gains an `aiMarking` section: whether the person has opted
  out, and a teacher's Studafy AI Marking usage (newest 5,000 rows).
  Suggestions are not included; the student's marks are in their grades.
- **Account deletion** removes a student's opt-out and every suggestion
  about their work, and a teacher's usage ledger and comp grants
  (`dl073_marking_forget_deleted_profile`). The teacher's references stay
  with the school's assessment.

### 11. The plan: Studafy AI Marking

| | |
|---|---|
| Feature key | `studafy_ai_marking` (not `teacher_ai_grading`, which stays retired) |
| Store product | `studafy_ai_marking_monthly`, auto-renewing, monthly, on Google Play and the App Store |
| Who may buy | A teacher with an active teacher membership, for themselves (`private.billing_resolve_beneficiary`). No student is named |
| Allowance | 4,000,000 tokens and a US$2 cost cap per teacher per calendar month; 20 pages per hand-in (`private.marking_limits`) |
| Listed | `synthetic` and `development` only. `staging` and `production` rows exist but are unlisted until the owner creates the product in Play Console and App Store Connect and a later migration lists it |
| Price | Set by the owner in the stores; the app shows the store's price |
| Comp grants | `private.marking_plan_grants`, written by an operator with direct database access only (app review, pilots) |
| Notices | `billing_notify_entitlement_change` sends the usual subscription notices for the new key |

`private.marking_plan_active` reads verified store entitlements in the
runtime's billing environment, or a live comp grant.

### 12. The switch and the routes

`MARKING_SUGGESTIONS_ENABLED` (API and worker) is off unless set. On the
API, with it off, references can still be read and written, the plan read
says `available: false`, and asking for suggestions answers
`409 AI_FEATURE_DISABLED`. On the worker, with it off, nothing is sent. It is
on in `fly.test.api.toml` and `fly.test.worker.toml`, and off in production
until launch.

| Route | Who | Notes |
|---|---|---|
| `GET /v1/me/marking-plan` | Any signed-in account | `active`, `teacher`, `available` and this month's allowance |
| `GET /v1/assessments/{id}/marking-references` | The class's teachers | References, strictness and version |
| `POST /v1/assessments/{id}/marking-references` | The class's teachers | Writes references and strictness; idempotent; returns `staleSuggestions` |
| `GET /v1/assessments/{id}/marking-suggestions` | The class's teachers | Live suggestions with `stale` |
| `POST /v1/assessments/{id}/marking-suggestions` | The class's teachers, with the plan | Queues a run: `queued`, `optedOut`, `replaced`; `403 PLAN_REQUIRED` without the plan |
| `POST /v1/marking-suggestions/{id}/dismiss` | The class's teachers | |
| `GET`/`POST /v1/me/marking-preference` | A student | Their own opt-out |

Permissions: `marking_plan.read`, `marking_reference.read`,
`marking_reference.write`, `marking_suggestion.read`,
`marking_suggestion.request`, `marking_suggestion.dismiss`,
`marking_preference.read`, `marking_preference.write`
(`apps/api/src/authorization/catalogue.ts`).

## Consequences

- **Supersedes ADR-0026 for marking only.** The rest of ADR-0026 stands as
  amended by ADR-0029 and ADR-0037. The SEC-001 tripwires stay.
- **ADR-0043 D4** (no AI study tools for parents and teachers) stands: AI
  Marking is a separate teacher tool, not one of the study tools.
- **Policies.** Privacy policy 1.8 and terms of use 1.6, English and Arabic,
  effective 25 October 2026: a teacher may ask AI for suggested marks, the
  teacher decides, a student can turn it off in Account, Together AI is the
  processor, suggestions are kept 180 days, names are replaced. Studafy AI
  Marking is listed in the terms' paid plans. Published by the owner's
  decision without legal review, like 1.5 to 1.7. They need a new consent
  version, and the in-app summaries (`policyTermsBody`, `policyPrivacyBody`)
  to say the same (handoff).
- **Store answers.** No new data type: student work and files were already
  declared and already go to Together AI for the study tools. The listing
  gains an optional teacher block for when the product is listed
  (`docs/store/`).
- **Accepted risk: no DPA.** As DL-062: GDPR Art. 28 requires a processor
  contract before Together AI processes students' work, and Art. 35 a DPIA.
  Neither is signed. The policy says so publicly.
- **The provider's own retention of requests** is unknown until the DPA.
- **Photos and scans of handwritten work** are sent as they are, so a name
  or a face on the page reaches the provider.
- **Suggestions can be wrong**, including for work in Arabic or with
  formulas. The teacher reviews each one; nothing is marked without them.

## Open questions for counsel

- TODO(legal): the teacher's decision with a student opt-out, rather than
  consent, as the basis for sending minors' work to an AI provider; and
  whether a school that is controller must instruct it (questions-for-counsel
  10.1).
- TODO(legal): the Together AI DPA, now covering students' marked work and
  photos of handwritten pages (questions-for-counsel 1.1, 10.2).
- TODO(legal): 180 days for suggestions and 13 months for the teacher's
  ledger (questions-for-counsel 10.3).
- TODO(legal): whether a suggested mark that a teacher accepts unchanged is
  an automated decision under GDPR Art. 22 (policy §14).
