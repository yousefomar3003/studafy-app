# `/v1` safety and safeguarding contract (SAFE-043)

Status: implemented for local/disposable synthetic use. This document does
not authorize a production deployment or real school/student data. OpenAPI
remains the machine-readable source of truth at
`packages/contracts/openapi/v1.json`.

SAFE-043 makes protection of people authoritative at the data layer: anyone
inside a school can report a concern about a message, a conversation or a
member; reports are deduplicated and rate-limited per reporter; blocked
members cannot start new contact in either direction; the school's admins
moderation queue, triage, resolve, appeal, attach evidence and — only on
escalation — see who reported what; a platform operator (two-person, MFA-
gated) can place a legal hold and pause an active account deletion; safety
config for the whole school lives in one versioned policy row. It extends the
AUTH-031/API-040/API-041/API-042 patterns — same route catalogue, same
`private.api042_query`/`api042_command` dispatcher, same idempotency, same
permission catalogue — and never widens wellbeing visibility: no SAFE-043 SQL
reads `public.wellbeing_events`.

## Route inventory

23 routes, indices 96–118 of `V1_ROUTE_CATALOGUE`. Every POST declares
exactly one AUTH-031 permission and requires `Idempotency-Key`; every GET is
cursor-paginated where the response has an `items` array. `/internal/*`
routes are authenticated and authorized exactly like `/v1/*`; the prefix only
marks them as outside the product-facing surface.

| Cluster | Reads | Commands |
|---|---|---|
| Content controls | `GET /v1/control-panel/content-controls/{schoolId}` | `POST /v1/control-panel/content-controls/{schoolId}` |
| Reporting | `GET /v1/reports`, `GET /v1/reports/{reportId}` | `POST /v1/reports`, `POST /v1/reports/{reportId}/appeal` |
| Blocks | `GET /v1/blocks` | `POST /v1/blocks`, `POST /v1/blocks/{blockId}/unblock` |
| Moderation | `GET /internal/moderation/overview`, `GET /internal/moderation/queue`, `GET /internal/moderation/reports/{reportId}` | `POST /internal/moderation/reports/{reportId}/triage`, `/resolve`, `/escalate`, `/evidence`, `/hold`; `POST /internal/legal-holds/{legalHoldId}/release` |
| Moderator access | `GET /internal/moderation/access` | `POST /internal/moderation/access`, `/{moderationGrantId}/approve`, `/start`, `/revoke` |

## Authorization notes

- **Reporter operations are self-scoped.** `report.create/read/appeal` and
  `block.manage` carry `scope: "self"` with `tenantRequired: false`: there is
  no resource id at the API layer (the reporter's own list, a pair of
  identities in the request body). The SQL dispatcher enforces ownership —
  `createReport` requires an active membership in the school it is filed
  against, `getReport`/`listReports` return only the authenticated reporter's
  own reports, and appeals may only come from the original reporter.
- **Right-hand side naming.** Blocks are stored as `(blocker_id, blocked_id)`
  of the action that created them, and both sides of the pair read back as
  their own identity in `getReport`-analogous views; an unblock removes the
  row. Symmetry is enforced at communication time (below), not by duplicating
  rows.
- **Moderation reads/writes are school-scoped in SQL, not in the catalogue.**
  The catalogue only opens the route; `private.safe043_can_access_reports`
  (school admin or active moderation-session grant holder) and
  `private.safe043_can_access_report` (the same, plus "must be the report's
  school") decide every queue read and every disposition. Cross-school and
  non-moderator denials are concealed as 404.
- **Reporter identity is masked until escalation.** `getModerationReport` and
  the queue return `reporterId: null` until an escalation unmasked it; the
  escalation command passes `p_unmask := true` to the report serializer.
  Moderators cannot read the reporter of a not-yet-escalated report through
  the API.
- **Platform operators are granted out of band.** `public.platform_operators`
  has no API route; granting it is a service-role-only SQL operation (see the
  operator runbook). Operator-only surface — the legal hold, and the
  moderation-session request/approve steps — re-checks `is_platform_operator()`
  inside the SQL dispatcher regardless of what the permission catalogue
  allowed.
- **The legal-hold backstop is defense in depth.** `moderation.hold` in the
  catalogue would admit a school admin, but the SQL `holdReport` requires
  `is_platform_operator()` outright, so a school admin holding a report
  returns 403 at the HTTP layer after already passing authorization — a
  deliberately-asserted proof that SQL remains the final authority.
- **Moderator sessions require unconditional AAL2 for request and approve.**
  `RequestDbContext.aal2` (from the verified session, never a client claim)
  is checked inside `api042_command` for `requestModerationAccess` and
  `approveModerationAccess`; start/revoke do not re-check MFA because the
  session was already MFA-approved. An MFA-less operator gets 403, not 404 —
  operator identity is not a secret.
- **Blocking gates new communication unconditionally.** `api042_command`
  refuses `sendMessage`/`createConversation` whenever `safe043_is_blocked_pair`
  is true in either direction. There is no deployment-state flag that
  disables this; see ADR-0021 for why. Reads of already-delivered messages are
  unaffected.

## Semantics

### Report lifecycle

`created` → every report begins `queued` with two `report_events`
(`submitted`, `queued`):

- `queued` → `triage` → `under_review` → `resolve` → `resolved` or `closed`
- `resolved`/`closed` → `appeal` (by the reporter) → `under_review`
- `under_review`/`on_hold` → `resolve`; `escalate` is blocked once resolved,
  closed or withdrawn
- `hold` (platform operator) → `on_hold`, with `resolved` → `hold` →
  `resolved` allowed
- `on_hold`/`under_review` → `escalate` → `escalated` (reporter unmasked,
  routed to platform operators)
- Reporter may `withdraw` a `queued` or `under_review` report (reserved for a
  later step; the state machine reserves the transition)

Every transition writes a `report_events` row with the acting user, the old
and new status, a note, and a server-side `transitioned_at`. If the subject
is a conversation participant, the event also notifies the reporter via the
outbox.

### Deduplication and rate limiting

A new report is rejected with `invalid_state` when the same reporter has
already filed a report with the same message/conversation/member in the
school within the last 24 hours, and with `window_closed` when the reporter
exceeds 20 report attempts in a rolling 24-hour window. Both are enforced
against `report_attempts` and the existing reports in the same transaction as
the insert — there is no check-then-act window.

### Evidence and holds

`addReportEvidence` appends content or a moderator note to an open report
(snapshot, append-only; it carries no `expectedVersion` — evidence is
irreplaceable history, not a state cell). `holdReport` requires the subject
user id or the report id (default `appliedTo: "report"`), a reason, and an
optional ticket reference, and — for a user hold — keeps an active account
deletion of the subject paused until the hold is released. Holds are released
explicitly via `releaseLegalHold` by the same SQL-dispatcher operator check.

### Content controls

A single versioned row per school holds `contentFilterLevel`
(`off|moderate|strict`, default `strict`), `messagingEnabled`,
`classifierAssistEnabled`, `supportContact`, and a `version`. Any active
member may read it; only the school's admin (or a platform operator) may
update it with `expectedVersion`. The row deliberately has no free-form
"customContacts"/"webhooks" repetition from the original design — one editable
policy, version-checked, audited.

### Blocks

`createBlock` takes `schoolId`, `blockedUserId`, a `scope` (default `messages`),
an optional `durationHours`, and an optional reason; the block is symmetric at
communication time and expires lazily (`expires_at is null or > now()`). A
blocked pair cannot start new conversations or messages in either direction
(see authorization notes); the blocking actor's own view of `listBlocks`
remains the source of truth for their blocks.

### Moderator JIT access

`requestModerationAccess` is a platform operator (or school admin) with a
verified second factor this session, a reason (8–2000 chars), a ticket
reference, optional `resourceScope` (`school` or explicit report ids; default
`school`), `durationMinutes` (15–480, default 60) and
`requiresSecondApprover` (default true). The grant is created `pending`,
approvable only by a *different* platform operator with AAL2
(`private.is_second_approver`); only the original requester may `start` the
approved grant; a platform operator or the affected school's admin may
`revoke` at any point. Grants expire at `expiresAt` but only lazily — the next
touch of that school's grants runs the one-off expiry sweep (no OPS-061
scheduler yet). `listModerationAccess` is cursor-paginated and shows a
school's grants to its admin or a platform operator.

## Reuse of the safety row in later steps

The `safety_config` row and the block/report tables are the storage for two
later, deferred transforms resolved by their own slices (see ADR-0021): a
safe-listing block pump and a parallel platform-operator queue path, both out
of scope here.