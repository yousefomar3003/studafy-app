# System inventory

ARC-001 deliverable: verified inventory of tables, policies, functions, Edge
Functions, storage, providers, products, secrets, and client touch points.
Evidence date: 2026-09-10. Source: repository migrations
`202609080001`–`202609090003`, `supabase/functions/`, `lib/data/`, CI config.
Remote reconciliation: see `docs/evidence/schema/reconciliation-report.md`.

## Database (7 forward-only migrations)

| Migration | Creates |
|---|---|
| `202609080001_production_foundation.sql` | `pgcrypto`; 5 enum types (`app_role`, `link_status`, `publication_state`, `attendance_state`, `meeting_audience`); 24 tables; helpers `is_school_member`, `can_access_student` (SECURITY DEFINER, `search_path=''`); RLS on all tables; 13 SELECT/UPDATE policies; private bucket `private-school-files` |
| `202609080002_access_policies.sql` | Helpers `can_access_classroom`, `is_class_teacher` (SECURITY DEFINER); ~22 read policies; 7 teacher/student write policies; anon/authenticated grants revoked on grading tables |
| `202609080003_workflows.sql` | Tables `meeting_deliveries`, `account_deletion_requests`; the only 2 explicit indexes (`meeting_deliveries_recipient_idx`, partial `account_deletion_due_idx`) |
| `202609080004_practice_activity.sql` | Table `practice_sessions` |
| `202609090001_tighten_student_access.sql` | Enrollment-scoped `can_access_student` redefinition; direct `can_access_classroom`; audience-enforced announcements/meetings policies (supersede 0002 versions); storage insert policy (later dropped) |
| `202609090002_identity_consent.sql` | `handle_new_auth_user` trigger (SECURITY DEFINER); `consent_records`; `record_policy_consent` (SECURITY INVOKER, granted to authenticated) |
| `202609090003_contain_unsafe_uploads.sql` | SEC-001: drops the `storage.objects` direct-upload policy |

### Tables (28)

Tenancy/identity: `schools`, `profiles`, `memberships`, `terms`, `students`,
`guardian_links`, `consent_records`, `account_deletion_requests`.
Classes/learning: `classrooms`, `enrollments`, `lesson_sessions`,
`lesson_materials`, `assignments`, `submissions`, `assessments`,
`assessment_questions`, `grade_results`, `practice_sessions`.
School life: `attendance_records`, `wellbeing_events`, `announcements`,
`meetings`, `meeting_deliveries`, `notifications`, `audit_events`.
AI/billing: `ai_grading_drafts`, `question_suggestions`,
`subscription_entitlements`.

### RLS policy inventory

43 `create policy` statements total; 2 superseded (announcements/meetings
re-created in `202609090001`) and 1 dropped (SEC-001 storage policy) → **40
effective policies**, all on public tables:

- Self-scoped: profiles (read/update), memberships, notifications
  (read/update), entitlements, consent (read/insert/update), deletion
  requests, audit (own actions).
- Relationship-scoped via `can_access_student`: students, guardian_links,
  grades (published only), attendance, wellbeing, submissions,
  practice_sessions.
- Classroom/role-scoped: schools, terms, classrooms, enrollments,
  lesson_sessions, lesson_materials, assignments, assessments,
  assessment_questions, announcements (audience), meetings (audience),
  meeting_deliveries, grading drafts/suggestions (teacher only).
- Client write paths: teacher session insert/update, materials insert,
  assignment draft insert/update, student submission insert/update
  (**the unsafe update flagged by DB-021**), guardian link request, consent
  writes, notification updates.
- Storage: **no client insert policy remains** (SEC-001); bucket is private.

### Functions (6) — security posture

| Function | Kind | Grant issue |
|---|---|---|
| `is_school_member` | SECURITY DEFINER, `search_path=''` | public/anon EXECUTE — advisor finding, fix in Phase 2 forward migration |
| `can_access_student` | SECURITY DEFINER (enrollment-scoped since `202609090001`) | same finding |
| `can_access_classroom` | SECURITY DEFINER | same finding |
| `is_class_teacher` | SECURITY DEFINER | same finding |
| `handle_new_auth_user` | SECURITY DEFINER trigger | same finding |
| `record_policy_consent` | SECURITY INVOKER | granted to authenticated only (acceptable) |

### Known schema gaps (open items for DB-020/021)

- `students.school_id` nullable; no composite same-school FKs.
- Only 2 explicit indexes; RLS/list paths unindexed.
- Most tables lack `updated_at`; no state-transition enforcement; multi-row
  updates non-atomic; `audit_events` not append-only-enforced.
- Platform `rls_auto_enable()` remains platform-managed; direct PUBLIC/anon/
  authenticated execution was removed by `202609090004` without altering the
  event trigger.

## Edge Functions (6 in source; 2 deployed synthetic, Deno)

Shared pattern: caller JWT forwarded to an anon-key client (`auth.getUser()`
→ 401) + separate service-role client for privileged writes. CORS: wildcard
`Access-Control-Allow-Origin: *` (registered as finding → API-040).
`supabase-js` pinned to `2.116.0` exactly (deno.lock integrity-verified).

| Function | Purpose | Required env/secrets | External provider | State |
|---|---|---|---|---|
| `propose-paper-grade` | SEC-001 kill-switch stub | none (deliberate) | none | Always 503 `AI_GRADING_DISABLED` |
| `study-coach` | Grounded Q&A/quiz/flashcards; writes `practice_sessions` | `SUPABASE_URL/ANON_KEY/SERVICE_ROLE_KEY`, `STUDY_COACH_URL`, `STUDY_COACH_KEY` | Study Coach AI endpoint | Active; rejects attachments |
| `approve-paper-grade` | Teacher review of AI draft → `reviewed` | — | none | Removed after API-041 parity; source-only and not deployed in inspected synthetic project |
| `publish-grade-result` | Publish reviewed grade + notification + audit | — | none | Removed after API-041 parity; source-only and not deployed in inspected synthetic project |
| `create-google-meet` | Calendar event + Meet + deliveries | SUPABASE trio, `GOOGLE_TOKEN_BROKER_URL/SECRET` | Token broker, googleapis Calendar | Source only; not deployed synthetic |
| `cancel-google-meet` | Delete event, cancel deliveries | SUPABASE trio, broker pair | Token broker, Calendar | Source only; not deployed synthetic |
| `verify-store-purchase` | Verify receipt → entitlement upsert | SUPABASE trio, `PURCHASE_VERIFIER_URL/SECRET` | Purchase verifier | Source only; not deployed synthetic |
| `request-account-deletion` | 14-day grace deletion request | SUPABASE trio | none | Source only; not deployed synthetic; JWT `iat` recent-auth finding → AUTH-030 |

`.env.example` lists all names above with placeholders (grading keys
deliberately absent).

## Storage

- One bucket: `private-school-files` (private, 50 MiB limit via config).
- No client upload path (SEC-001); objects reachable only via server-signed
  URLs inside functions. DB-020 introduced `file_objects` metadata, but no
  API-041 upload or attachment path is enabled; FILE-050/051 still owns that
  pipeline and its authorization/scanning evidence.

## Client touch points (Flutter)

- Tables read/written client-side: `profiles` (with memberships/schools
  joins), `guardian_links` (with students), `notifications` (count + mark
  read), `subscription_entitlements` (read only).
- RPC: `record_policy_consent` (policy version `2026-09-09`).
- Remaining Edge invocation adapters cover Study Coach, meetings and purchase
  verification; API-041 grade review/publication invocations are removed. The
  remote synthetic project deploys only the two contained functions
  (`propose-paper-grade` and `study-coach`). No other availability is claimed.
- API-041 academic context, class, content, assignment, assessment, grade,
  attendance and wellbeing traffic uses the generated `/v1` client.
- Auth: Supabase PKCE OAuth (Google, Microsoft, Apple) with redirect
  `io.studafy.app://login-callback`; no Realtime, no push, no direct storage
  use in the client.
- Local: SQLite `studafy_preview.db` is synthetic-only. Remote access fails
  closed and API-041 has no local production write queue.

## Providers and products

| Provider | Used by | Credential custody |
|---|---|---|
| Supabase (Auth/DB/Storage/Functions) | client + functions | publishable key in app; service-role key only in function secrets |
| Study Coach AI | `study-coach` | function secret |
| Google token broker (custom) + Calendar API | Meet functions | function secrets; per-user tokens via broker |
| Purchase verifier (custom) | `verify-store-purchase` | function secret |
| App Store Connect / Google Play Console | planned only | **no products or credentials exist yet** |

Store product (planned, single): `studafy_parent_insights_monthly`
(Parent Insights+). Purchaser/beneficiary model deferred (ADR-0009).

## Toolchain pins (verified in CI, 2026-09-10)

Bun 1.3.14 · Deno 2.9.6 · Flutter 3.47.1 (stable) · Dart ^3.13.1 ·
supabase CLI 2.117.0 (pinned devDependency, `bun.lock` frozen) ·
`@supabase/supabase-js` 2.116.0 (pinned URL + deno.lock integrity) ·
Java/Gradle 17 · iOS deployment target 15.0. Lockfiles verified in CI via
`--frozen-lockfile`/`--frozen=true`.
