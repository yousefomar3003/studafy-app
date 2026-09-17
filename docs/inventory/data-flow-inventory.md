# Data-flow inventory and threat model (v0)

ARC-001 deliverable: every data flow with sensitivity, plus a register of
known weaknesses linked to roadmap tasks. This is threat-model v0: it inventories flows and known findings; a full STRIDE
pass per flow is Phase 3 entry work (AUTH-030 threat-model requirement).
Evidence date: 2026-09-10. No real personal data exists in any environment.

## Legend

Sensitivity: P0 = children's/special-category data, P1 = personal/education
records, P2 = operational/metadata, P3 = non-personal. Cross-border flows are
flagged for the ADR-0005 legal review.

## Data flows

### Mobile client → Supabase

| # | Flow | Content (sensitivity) | Notes |
|---|---|---|---|
| F1 | OAuth login (PKCE), Google/Microsoft/Apple | Identity tokens (P1) | Redirect `io.studafy.app://login-callback`; deep-link hijack tested in Phase 3 |
| F2 | `profiles`/`memberships`/`schools` reads | Own profile, memberships (P1) | Self-scoped RLS |
| F3 | `guardian_links` + `students` reads | Child identity, `studafy_id` locator (P0/P1) | Relationship-scoped RLS; `studafy_id` is public-locator, throttled verification only |
| F4 | `notifications` count + mark-read | Notification metadata (P2) | Client-side counting fetches every unread ID (perf finding → API phase) |
| F5 | `subscription_entitlements` read | Own entitlement (P2) | Read-only client access |
| F6 | `record_policy_consent` RPC | Consent purpose/version/locale (P1) | Hard-coded policy version `2026-09-09`; policy text is placeholder copy (finding) |
| F7 | SQLite preview (device-local) | Synthetic school dataset (P3 only) | `studafy_preview.db`; remote access throws and there is no production write queue (API-041) |

### Mobile client → Bun/Hono `/v1` API

| # | Flow | Content (sensitivity) | Notes |
|---|---|---|---|
| F26 | School/class context and rosters | Membership, staff, student summaries, schedules (P0/P1) | Server-derived tenant; relationship-scoped; cursor paginated |
| F27 | Content/assignment/assessment reads and text submissions | Teaching text, student answers (P0/P1) | Strict role-specific DTOs; learner responses exclude preferred answers and storage identifiers |
| F28 | Grade review/publish/correct/withdraw | Scores, feedback, reviewer action (P0/P1) | Optimistic state machine; immutable history; atomic outbox/idempotency |
| F29 | Attendance and wellbeing | Attendance reasons and classified wellbeing text (P0) | Exact class/student relationship and classification-specific visibility |

Every API-041 command reaches PostgreSQL through one transaction-local actor,
school, and request context. Notification-worthy actions write only a minimal
`notification_outbox` event; provider delivery is not part of the request.

### Mobile client → Edge Functions (JWT required)

| # | Flow | Content | Notes |
|---|---|---|---|
| F8 | `study-coach` ask/quiz/flashcards | Classroom ID, topic, question (P1/P2) | Attachment paths rejected (SEC-001); enrollment verified server-side |
| F9 | `create/cancel-google-meet` | Class, audience, times (P2) | Client never holds Google tokens |
| F10 | (Removed) `approve/publish-grade-result` | Draft/score review (P0/P1) | Replaced by transactional `/v1/grade-results/{id}:review/:publish`; sources were not deployed in inspected synthetic project |
| F11 | `verify-store-purchase` | Store receipt/purchase token (P2) | Forwarded to verifier; client never grants entitlement |
| F12 | `request-account-deletion` | Typed confirmation (P1) | Recent-auth via JWT `iat` (weak — finding) |

### Edge Functions → external providers (cross-border)

| # | Flow | Content | Notes |
|---|---|---|---|
| F13 | `study-coach` → Study Coach AI (cross-border) | Question, topic, up to 30 material bodies (P1/P0 if real) | No token budget/chunking/cost controls (finding); synthetic endpoint today |
| F14 | Meet functions → Google token broker → Calendar (cross-border) | Event title/times/attendees (P1) | N+1 recipient expansion; external side effect before durable idempotency (OPS-061) |
| F15 | `verify-store-purchase` → purchase verifier (cross-border) | Receipt data (P2) | Generic verifier; no official store webhook receivers (PAY-071) |

### Edge Functions → PostgreSQL (service role)

F16–F23: one privileged write path per function (drafts/results, meetings and
deliveries, entitlements, deletion requests, practice sessions, audit events).
Blast radius: service role bypasses RLS; lacks shared strict schemas,
idempotency, transactions, timeouts (API-040/041).

### Storage

| # | Flow | Content | Notes |
|---|---|---|---|
| F24 | (Removed) client → `private-school-files` | — | Dropped by SEC-001; the direct client upload policy has never been restored |
| F25 | Function-signed object URLs → AI provider | — | Only the disabled grading path ever did this; reinstatement requires FILE-050/051 metadata pipeline |
| F26 | Client → `POST /v1/uploads` → API → storage adapter | P2 (declared name, size, type, SHA-256) | FILE-050. The request carries no path, key, bucket, owner or scan state. The API authorizes purpose and relationship, enforces six quotas under a row lock, and the adapter generates `quarantine/v1/{uploadId}/{random}` and signs it for two hours. The URL is returned once and redacted from logs, audit records, errors and telemetry |
| F27 | Client → signed capability → `private-school-files` | P0/P1 (schoolwork, identifiable images, graded papers) | FILE-050. Direct `PUT` of the declared bytes only, to the server-chosen key, no redirects followed. One key accepts one object (`upsert: false`). Off by default: `FILE050_NEW_INTENTS_ENABLED=false`, `allowsRemoteFileUploads=false` |
| F28 | API → storage (service role) → API | P0/P1 | FILE-050 completion. The path comes from a private owner-only query, never the client. Bytes are streamed under a hard byte bound, digested server-side and type-detected from magic bytes; object, binding, audit event, outbox job and idempotency completion commit in one transaction. Objects land `quarantined`; mismatches land `rejected` |
| F29 | Worker → storage (service role) | P2 (object locations) | FILE-050 cleanup. Exact bucket/key come from a `SECURITY DEFINER` claim, never from the job payload. The database row is marked `deleted` only after storage confirms removal |
| F30 | (Not enabled) `POST /v1/files/{fileId}/download-intent` → client | — | Contract and authorization boundary only. FILE-050 returns `FILE_NOT_CLEAN` or `FILE_DELIVERY_DISABLED`; no object is downloadable until FILE-051 |

## Known-weakness register (linked to roadmap)

| Finding | Location | Task |
|---|---|---|
| Wildcard CORS on every function response | `supabase/functions/_shared/http.ts` | API-040 / INFRA-080 |
| JWT `iat` used as recent-auth proof for destructive deletion | `request-account-deletion` | AUTH-030 |
| Student submission update policy doesn't re-check assignment/enrollment on identifier change | migration `202609080002` | DB-021 |
| No composite same-school FKs; `students.school_id` nullable | migration `202609080001` | DB-020 |
| Public/anon EXECUTE on 5 SECURITY DEFINER helpers | migrations 0001/0002/0006 | DB-021 (advisor finding; forward migration required) |
| Only 2 explicit indexes; nested RLS paths unindexed | migration set | DB-020 |
| Client-side unread-notification counting; N+1 guardian/auth-admin loops in Meet creation | client + `create-google-meet` | API/OPS phases |
| Study Coach sends up to 30 material bodies without budget/chunking/cost controls | `study-coach` | later AI hardening |
| Sequential, non-transactional multi-row updates; duplicate-question weakness in grade approval | Removed `approve/publish-grade-result` sources | Resolved locally by API-041 transaction/parity tests; no remote cutover claim |
| Single-row entitlement table; no ledger/webhooks/reconciliation | `subscription_entitlements`, verifier | PAY-071 |
| QR scanner returns hard-coded ID; painter is not an interoperable encoder | `lib/student_linking.dart` | post-threat-model decision; never identity proof |
| Consent records a code-owned policy version; policy text/legal approval remains pending | `features/session/data/supabase_session_repository.dart`, migration 0006 | AUTH-030 |
| Demo-role fallback is restricted to synthetic runtime but full server role authorization remains future work | `features/session/application/session_interactor.dart`, `studafy_domain.dart` | ARC-011 / AUTH-030 |
| Local errors swallowed; raw server causes returned as 400s | feature files, functions | API-040 |
| No CI/CD deploy, central logging, metrics, tracing, alerting | repository-wide | INFRA-080/081, OPS-090 |
| Quarantined objects are inert but unexamined — magic-byte detection establishes format, not safety | FILE-050 pipeline | FILE-051 (scanning, parser validation, EXIF removal, clean transitions) |
| `POST /v1/blocks/{blockId}/unblock` returns 500: the dispatcher branch returns the raw snake_case row instead of the camelCase `V1Block` projection | migration `202609170002` | SAFE-043 follow-up (forward-only re-emit of the dispatcher) |

## Positive controls already in place

PKCE auth with publishable-key-only client; service role isolated from
Flutter; private bucket with no client insert policy; enrollment-scoped
`can_access_student`; reviewed-before-published grades; server-side purchase
verification; SEC-001 kill switches with no env bypass; read-only, fully
pinned CI.
