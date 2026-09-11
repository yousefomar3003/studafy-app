# DB-020 schema and data dictionary

This dictionary describes the public schema after DB-020. It distinguishes
implemented database behavior from later authorization and retention work.
`school_id` is the tenant key unless a row is explicitly identified as global.
All timestamps are `timestamptz` (UTC at rest); school time zones are presentation
metadata.

## Identity, schools, and classrooms

| Relations | Keys and relationships | Lifecycle and invariants | Sensitive fields | Access and retention |
|---|---|---|---|---|
| `schools` | `id`; tenant root | status, locale, time zone, soft-delete timestamp | operational and residency metadata | Existing RLS remains; final admin policies are Phase 2B. Retention legally deferred. |
| `profiles` | `id → auth.users`; global identity | active/suspended/deletion states | name, locale | Existing RLS remains; deletion follows identity/legal policy. |
| `memberships` | `id`; unique school/user/role; composite tenant candidate key | invited/active/suspended/revoked/expired; positive version; bounded validity; legacy `active` synchronized | role and tenant affiliation | Existing policies remain pending Phase 2B hardening. |
| `membership_events` | identity key; same-school FK to membership | append-only grant/suspend/reactivate/revoke/expire events; tenant idempotency | actor/reason | RLS on, no client grants/policies. Audit retention is legally deferred. |
| `terms` | `id`; same-school classroom parent | planned/active/closed/cancelled; start ≤ end; one active per school; legacy `active` synchronized | low | Existing policies remain; no destructive contraction. |
| `classrooms` | `id`; same-school FK to term | draft/active/archived; archive timestamp consistency | class membership context | Existing policies remain. Legacy `teacher_id` is compatibility-only. |
| `classroom_staff` | `id`; same-school FKs to classroom and membership/user | lead/co-teacher/assistant; one active assignment per classroom/user; ended timestamp | staff assignment | RLS on, no client grants/policies until Phase 2B. |
| `class_schedules` | `id`; same-school classroom FK | valid weekday/time/effective range; unique slot | schedule | RLS on, no client grants/policies. |
| `students` | `id`; school root child; optional global user | non-null tenant; soft delete | student ID and name | Existing policies remain pending Phase 2B review. |
| `guardian_links` | `id`; same-school student FK; guardian is global identity | pending/verified/declined/revoked; verification and expiry consistency | family relationship and evidence reference | Existing policies remain; relationship-aware rewrite is Phase 2B. |

## Learning, assessment, and wellbeing

| Relations | Keys and relationships | Lifecycle and invariants | Sensitive fields | Access and retention |
|---|---|---|---|---|
| `lesson_sessions`, `lesson_materials` | same-school chain from classroom to session/material | scheduled/completed/cancelled session; valid time; soft-delete material | lesson text and legacy storage path | Existing RLS; legacy paths cannot enable uploads. |
| `assignments` | same-school classroom FK | draft/reviewed/published; publication timestamp; positive version; due/close order | instructions | Existing RLS pending Phase 2B; soft delete retained. |
| `submissions` | same-school FKs to assignment and student | open/submitted/excused/withdrawn; lifecycle consistency; positive version | student work | Existing policies remain known Phase 2B target. |
| `submission_attempts` | same-school submission FK; operation idempotency | immutable submitted attempt | answer text | RLS on, no client access. Retention legally deferred. |
| `assessments`, `assessment_questions` | same-school classroom/assessment chain | positive maximum/weight/version; publication consistency | questions and preferred answers | Existing RLS pending Phase 2B. |
| `grade_results` | same-school assessment/student FKs | non-negative and ≤ assessment maximum; review/publication actor/time consistency; positive version | grades and feedback | Existing RLS pending Phase 2B. |
| `grade_result_events` | same-school grade FK | append-only state transitions; tenant idempotency | grade change reason/actor | RLS on, no client grants/policies; academic retention deferred. |
| `attendance_records` | same-school session/student FKs | unique session/student record | attendance/reason | Existing RLS pending Phase 2B. |
| `wellbeing_events` | same-school student and optional classroom FKs | severity/status bounds; default `class_staff` visibility | highly sensitive wellbeing/context/follow-up | Existing RLS is not the final classification policy; Phase 2B must implement all visibility modes. |
| `resources`, `resource_versions`, `resource_publications` | same-school typed chain to optional classroom/file | immutable versions; publication/withdrawal consistency | learning content | RLS on, no client grants/policies. |
| `practice_sessions` | same-school student/classroom FKs | counts non-negative and correct ≤ total | learning performance | Existing RLS pending Phase 2B. |

## Communications, files, and asynchronous work

| Relations | Keys and relationships | Lifecycle and invariants | Sensitive fields | Access and retention |
|---|---|---|---|---|
| `announcements`, `meetings`, `meeting_deliveries` | same-school classroom/meeting chains | publication, valid meeting time, tenant idempotency, non-negative attempts | content, recipients, provider IDs | Existing RLS; service workflow redesign remains later work. |
| `conversations`, `conversation_participants`, `messages` | same-school conversation chain; global users as participants | closed timestamp consistency; participant interval; immutable messages and client-message dedupe | private message body/read state | RLS on, no client grants/policies until Phase 2B. |
| `file_objects` | `id`; tenant object; unique bucket/key | quarantine/scanning/clean/rejected/error/deleted; non-negative size; clean scan metadata; legal hold | object key, hashes, encryption key identifier | RLS on, no client grants/policies. Storage remains disabled; retention policy pending. |
| `file_bindings` | same-school file plus exactly one typed FK to resource version, attempt, message, or AI draft | `num_nonnulls(...) = 1` | ownership graph | RLS on, no client grants/policies. |
| `upload_sessions` | same-school file/uploader references | expiry and completion consistency; hashed nonce | nonce hash, purpose | RLS on, no client grants/policies. Schema presence does not re-enable uploads. |
| `notifications` | same-school notification; global recipient | tenant non-null; cursor/dedupe metadata | recipient/body/route | Existing RLS pending Phase 2B. |
| `notification_outbox`, `notification_deliveries` | same-school composite chain to optional notification | pending/processing/retry/completed/dead-letter/cancelled; one recipient or audience; attempt tracking | payload, recipient, provider result | RLS on, no client grants/policies; service-only. |

## Billing and governance

| Relations | Keys and relationships | Lifecycle and invariants | Sensitive fields | Access and retention |
|---|---|---|---|---|
| `store_products` | global product key; platform/environment external ID unique | effective interval and active flag | store identifiers | RLS on, no client grants/policies; service-only. |
| `store_transactions` | global immutable transaction; product/purchaser FKs | unique platform/environment transaction; lifecycle states | signed-data hash, external transaction IDs | RLS on, no client grants/policies; finance retention pending. |
| `store_events` | global webhook event | external/payload dedupe; outbox lifecycle | payload hash/error code | RLS on, no client grants/policies; service-only. |
| `entitlements` | global user, optional school beneficiary | derived lifecycle; positive version; one active/grace feature scope | purchase-derived access | RLS on, no client grants/policies. Legacy `subscription_entitlements` is unchanged. |
| `consent_policies` | global purpose/version/locale key | publish/effective/retire ordering | legal text hash | RLS on, no client grants/policies. |
| `consent_records` | global user consent plus optional policy FK | existing accepted/withdrawn record with update timestamp | consent evidence | Existing RLS; legal retention pending. |
| `idempotency_records` | global or school scope + actor/scope/key | reserved/completed/failed; expiry; completed response required | request hash and redacted response | RLS on, no client grants/policies; operational expiry policy pending. |
| `audit_events` | optional tenant scope for global events | append-only | actor, entity, request ID, details | Existing service model; audit retention and legal hold policy pending. |
| `ai_grading_drafts`, `question_suggestions` | same-school grade/question graph; optional typed file object | positive version and score bounds | legacy private path, AI rationale | AI grading remains disabled by SEC-001. Phase 2A adds integrity only. |

## Compatibility and deferred contraction

The columns `memberships.active`, `terms.active`, `enrollments.active`,
`classrooms.teacher_id`, legacy file-path fields, legacy `parent`, and
`subscription_entitlements` remain. They are not the target authority and may
be removed only after clients, repositories, and Phase 2B policies have migrated.
No automatic retention/deletion task is activated by DB-020.
