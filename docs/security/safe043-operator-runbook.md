# SAFE-043 moderation operator runbook

Covers the reporting queue, escalation/unmasking, legal holds, moderator JIT
sessions, and content-controls troubleshooting. Written for a **local or
disposable** environment. No production environment exists yet (DL-009,
DL-024); when one does, safeguarding procedures need a named, separated
on-call owner and an approval path before they are used against real accounts
or real minors' data.

Owner: repository owner (`@yousefomar3003`), single-owner project. Production
use requires re-recording with named, separated owners.

## Vocabulary

| Term | Meaning |
|---|---|
| Platform operator | `public.platform_operators` row. Never granted through any API — a deliberate, out-of-band, service-role-only SQL operation |
| Safe moderator | A school admin, a platform operator, or the holder of an **active** moderation-session grant whose sessions are all `active` or grant-shared for that school (`private.safe043_can_access_reports`) |
| AAL2 (moderation) | The session must have actually presented a second factor *this request* for `request`/`approve` — not merely be MFA-enrolled. Checked unconditionally inside `api042_command`, not by role policy |
| Two-person moderation access | A `moderation_access_grants` row can only be approved by a platform operator who is not its own requester (`private.is_second_approver`) |
| Legal hold | A report- or user-scoped `legal_holds` row applied by a platform operator. A user hold pauses an active account deletion of the subject until released |

## Reviewing a report (DPIA D7)

> **Needs named reviewers (B9).** This procedure assumes at least two
> named platform operators: one reviews, a different one approves the
> grant. Until they are named and recorded here (and in the decision log),
> the repository owner is the only reviewer and the two-person approval
> cannot be met without a second operator. Do not invent a second identity
> to satisfy it.
>
> | Role | Name | Telegram | Since |
> |---|---|---|---|
> | Reviewer 1 | *to be named (B9)* | | |
> | Reviewer 2 | *to be named (B9)* | | |

This release has **no school administrator**, so nobody inside a school
can open the moderation queue. A filed report reaches people only through
this procedure. Never add a school-admin role or route to work around it.

### 1. The alert

Every new report (and, once, every report still open when migration
`202610150080` ran) puts a row in `private.report_alerts`. The worker
(`REPORT_ALERTS_ENABLED`, on in `fly.worker.toml`) sends it to the alert
Telegram chat within about 30 seconds:

```text
SAFETY REPORT Studafy production: a new report needs review.
Report: 3f6c...-...
Kind: message, priority: high
School: #9a0c51e2b7d4f018
Filed: 2026-10-15 09:30 UTC
Review with scripts/review-report.ts under a moderation grant (safe043 runbook).
```

That is everything it carries: the report id, its kind (message,
conversation or user), the priority the content rules assigned, and a
16-character hash of the school id. Never the text, a name, or an account
id. A failed send is retried with a backoff (1, 2, 4 ... up to 30 minutes)
until it goes through; `report_alert_send_failed` and
`report_alert_backlog` in the worker log say it is stuck. To check by hand:

```sql
select private.report_alerts_backlog();  -- {"unsent": n, "oldestSeconds": s}
```

### 2. Response times

Clock starts at the alert. "Triage" means the report is opened and moved
to `under_review`; "resolve" means a recorded resolution.

| Priority | Acknowledge in the chat | Triage | Resolve (the queue SLA, `safe043_sla_hours`) |
|---|---|---|---|
| critical | 1 hour | 4 hours | 4 hours |
| high | 4 hours | 24 hours | 24 hours |
| medium | 24 hours | 48 hours | 48 hours |
| low | 24 hours | 72 hours | 72 hours |

Acknowledge by replying in the Telegram chat with the report id and who
takes it, so two reviewers do not both start. If a report names an
imminent risk to someone, go straight to **Incident response order**
below; the clock for that is now, not the table.

### 3. Get a grant (two people, MFA)

The reviewer needs an *active* moderation grant for the report's school,
best scoped to the report itself. Run `show` first: without a grant it
records the refused attempt and prints the school id to request one for.

```sh
REVIEW_DATABASE_URL='postgresql://postgres.<ref>:<pw>@aws-0-eu-central-1.pooler.supabase.com:5432/postgres' \
OPERATOR_USER_ID=<your account id> \
bun --no-env-file scripts/review-report.ts show <reportId>
```

Then, through the API with your own MFA session (the **Moderator JIT
sessions** steps above): request with `schoolId` from the output,
`resourceScope: {"reportIds": ["<reportId>"]}`, the alert's report id as
`ticketRef`, a reason, and `durationMinutes` 60; the **other** reviewer
approves; you start it.

### 4. Read and decide

```sh
bun --no-env-file scripts/review-report.ts show <reportId>
```

prints the report as the moderation queue would: details, evidence
snapshot, events, reporter masked (`reporterId: null`) unless the report was
escalated. Read it in your terminal only; do not paste it into the chat or a
ticket. Each `show` writes `report_review_opened` (or `_refused`) to
`audit_events`.

Decide:

- **A resolution**: `upheld` (the rules were broken and action was
  taken), `partial`, `not_upheld`, or `no_action`. Record it.

  ```sh
  bun --no-env-file scripts/review-report.ts resolve <reportId> \
    --resolution upheld --note "Message removed from class chat; sender warned."
  ```

  The script triages the report first if it is still queued, then resolves
  it, both through the API's own commands: `report_events`, `audit_events`
  (`report_triaged`, `report_resolved`) and the reporter's "your report was
  resolved" notification follow. The note is required (8-2000 characters):
  what was decided and why, without copying the reported content.
- **Escalate** (unmasks the reporter, permanently) or **hold**: use the
  API routes in the sections above. The script deliberately does not do
  these.

### 5. Close out

Revoke the grant when done (`POST .../revoke`) rather than waiting for it
to expire, and reply in the chat with the resolution (`upheld`, `not_upheld`,
`partial` or `no_action`, nothing more).

Audit one review:

```sql
select action, actor_id, created_at from public.audit_events
where entity_type = 'report' and entity_id = :report_id order by id;
select report_id, created_at, attempts, sent_at, last_error
from private.report_alerts where report_id = :report_id;
```

## Reporting queue triage

Reports never expose themselves through any `/v1` read. In this release
there is no school administrator, so the queue is opened only by a platform
operator under a grant (see **Reviewing a report** above); the routes are `/internal/moderation/overview` (health counts) and
`/internal/moderation/queue` (rows). Reporter identity is **masked**
(`reporterId: null`) until the report is escalated — this is deliberate, so
an admin who can see what was reported cannot see who reported it unless the
report was escalated.

1. Any report that names a life-safety phrase files at `critical`/`high`
   priority automatically; verify the assigned priority on triage.
2. `POST /internal/moderation/reports/{reportId}/triage` with
   `expectedVersion` (the version the route returned), an optional
   `priority`, and a note. The report moves to `under_review`.
3. When the review concludes, `POST .../resolve` with `expectedVersion`, a
   `resolution` (`upheld`, `not_upheld`, `partial` or `no_action`) and a note; the reporter is notified
   via the outbox.
4. The reporter can `POST /v1/reports/{reportId}/appeal` with a reason (≥8
   chars); this returns the report to `under_review`.
5. `POST .../escalate` unmasks the reporter **permanently** for that report
   and routes it to platform operators. Do not escalate "to take a look":
   escalation is the irreversible disclosure of the reporter's identity.
6. `addReportEvidence` appends snapshots/notes (append-only, no version
   check — history is not a state cell).

To audit the state of one report:

```sql
select id, school_id, status, kind, priority, created_at
from public.reports where id = :report_id;
select message, from_status, to_status, note, by_user_id, transitioned_at
from public.report_events where report_id = :report_id order by transitioned_at;
```

## Legal holds

`POST /internal/moderation/reports/{reportId}/hold` is **platform-operator
only**. The permission catalogue alone would admit a school admin; the SQL
dispatcher refuses them with 403 after authorization — a real, tested
backstop. Hold with `appliedTo: "report"` or `"subject"` (default `report`),
a reason, and an optional `ticketRef`; a `subject` hold pauses an active
account deletion of the held user until `POST /internal/legal-holds/{id}/release`.

Release is the same operator-only SQL check. Audit holds:

```sql
select id, school_id, subject_user_id, report_id, held_open_report_id,
       reason, ticket_ref, held_by, released_by, created_at, released_at
from public.legal_holds where school_id = :school_id order by created_at desc;
```

## Moderator JIT sessions

DAILY DRIVE FOR EVERY MODERATOR SESSION — the two-person, MFA-gated request
keeps operational "I need to look" access an audited, time-bounded event
rather than a standing role.

1. The requester calls `POST /internal/moderation/access` as a platform
   operator or the school's admin with `aal2` true **this request**, a reason
   (8–2000 chars), and a ticket reference; `requiresSecondApprover` defaults
   to true and should stay true unless the release gate explicitly approved
   otherwise.
2. A **different** platform operator — verified out of band — reviews the
   reason/ticket and calls `POST /internal/moderation/access/{id}/approve`
   with `aal2` true this request. The original requester can never approve
   their own grant; there is no override.
3. Only the original requester calls `.../start` (once approved).
4. Any platform operator or the affected school's admin calls `.../revoke`
   at any point. Double-revoke returns 409.
5. Grants expire on their own (`expiresAt`, 15–480 minutes) but **only
   lazily** — the next command touching that school's grants runs the expiry
   sweep. There is no OPS-061 scheduler. If a grant must be dead *right now*,
   revoke it explicitly rather than waiting.

Audit a school's grant history:

```sql
select id, school_id, requested_by, approved_by, status, resource_scope,
       reason, ticket_ref, expires_at, started_at, ended_at
from public.moderation_access_grants where school_id = :school_id
order by created_at desc;
```

## Block and reporting troubleshooting

| Symptom | Likely cause / check |
|---|---|
| A message send is refused that the caller does not understand | An active `user_blocks` row in either direction in that school (`safe043_is_blocked_pair`). The block gate runs **unconditionally**, with no flag to disable it — confirm the block, then unblock it |
| "You cannot report this again" | 24-hour dedupe on the same digest per reporter — intentional, prevents report flooding |
| "Report window closed" | 20 report attempts in a rolling 24-hour window — check `report_attempts` for the reporter |
| "Too soon" / an actor cannot report a message | `createReport` requires an active membership in the school; a message report also requires the actor to be a participant or a moderator of that conversation |
| Reporter id shows `null` in the queue | Working as designed: it stays masked until escalation. Check `report_events` for an escalation transition before treating this as a bug |
| The queue cannot be opened | `safe043_can_access_reports` requires school-admin standing or an *active* grant. A revoked/expired/rescinded grant removes access immediately |

## Rolling back the SAFE-043 surface

Every cluster mounts behind its own `SAFE043_*_ENABLED` flag
(`packages/config/src/index.ts`): `SAFE043_REPORTING_ENABLED`,
`SAFE043_BLOCKS_ENABLED`, `SAFE043_MODERATION_ENABLED`,
`SAFE043_CONTENT_CONTROLS_ENABLED`. Flipping one to `false` and restarting the
API makes that cluster return `SERVICE_UNAVAILABLE` without touching any other
module (including AUTH-030/API-040/API-041/API-042). It does not repair
already-written data — use a forward migration or an explicit correction
command, never by editing an applied migration or granting the runtime a
table/column grant to patch around it.

The messaging block gate is **not** flag-gated. If blocks must stop being
enforced while messaging continues, the only sanctioned path is unblocking the
affected pair(s), not turning the control off.

## Incident response order

1. Assess, don't scrub: read the report's `report_events`, the masks, and the
   school's grants before touching anything.
2. If a report names an imminent risk, `escalate` immediately (this, not the
   queue, is the irreversible disclosure step — the school's safeguarding
   owner is presumed authorized for it).
3. `hold` anything subject to a deletion request — a user hold pauses it
   server-side.
4. If a moderator session must never exist, `revoke` it now; do not wait for
   lazy expiry.
5. Re-tune only through flags after the immediate response; record the
   post-mortem in the decision log.