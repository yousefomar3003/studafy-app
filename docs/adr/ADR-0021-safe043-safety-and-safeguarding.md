# ADR-0021: SAFE-043 safety and safeguarding

- Status: Accepted for local/disposable use
- Date: 2026-09-16
- Decision log: DL-042

## Context

API-042 made communications authoritative (`conversations`, `messages`,
`announcements`), and every prior evidence document (AUTH-031, API-040,
API-041, API-042, the launch-readiness audit, and `instructions.md`) recorded
the same explicit dependency: **SAFE-043 is a mandatory gate before the
communications surface can be considered launchable.** The launch audit
(DL-030) named it for store-approval UGC/safeguarding reasons; the app's
users include children, and an unmoderated message surface with no reporting,
blocking, or hold mechanism was the single largest outstanding risk. This ADR
fixes the reporter/block/moderation/legal-hold layers as one authority
instead of layering them on later.

## Decision

SAFE-043 extends the exact already-shipped chain (route catalogue, one
`SECURITY DEFINER` dispatcher per domain via the rename-and-fallback pattern,
one idempotency table, one audit/outbox mechanism, one permission catalogue)
rather than introducing its own transport or authorization. Two migrations:
`202609170001_safe043_safety_schema.sql` (nine tables, enums, RLS, immutable/
append-only triggers, indexes) and `202609170002_safe043_surface.sql`
(helpers, authz additions, query/command wrappers, the messaging block gate,
per-operation audit/outbox tails). The full route contract is in
`docs/api/v1-safety-contract.md`; this record covers the decisions that are
not evident from the routes alone.

**Sensitive-definition reporting.** A report is self-scoped and
deduplicated/rate-limited in the same transaction as the insert (24-hour
dedupe on the same digest per reporter, 20 attempts per rolling window) —
there is no check-then-act window. Life-safety phrasing
("hurt you", "threats of violence") lands the report at `critical`/`high`
priority automatically. The reporter's identity is **masked in the queue and
overview until a moderator explicitly escalates**, at which point it is
unmasked permanently for that report — escalation is the irreversible
disclosure step, not "take a look".

**Moderation authority is a school's own admins, not a global team.** The
queue, triage, resolve, appeal, and evidence are all school-scoped by
`safe043_can_access_reports` (school admin or active grant) inside SQL. A
platform operator gets queue access only through a JIT, time-bounded,
two-person, MFA-gated `moderation_access_grants` session — never as a standing
role. Request and approve both require `aal2` this *request* (read from the
verified session, never a client claim); self-approval is structurally
impossible. Grants expire at `expiresAt`, swept lazily (no OPS-061 scheduler
yet) and revocable at any moment by a platform operator or the school admin.

**Legal holds are operator-only as a real SQL backstop, not just a catalogue
rule.** `moderation.hold`'s catalogue entry would admit a school admin, but
the SQL `holdReport` requires `is_platform_operator()` outright, so a school
admin is refused at 403 after authorization — deliberately asserted by a test
as proof that the dispatcher, not the permission catalogue, is the final
authority. A subject-scoped hold pauses an active account deletion of the
subject until the hold is released by the same operator check.

**Blocks are stored once and enforced symmetrically, unconditionally.** A
block is `(school_id, blocker_id, blocked_id)`, created by the actor who
wants to stop contact, and enforced by `api042_command`'s `intercept
sendMessage/createConversation` case through `safe043_is_blocked_pair` in
either direction. There is **no `SAFE043_MESSAGING_ENABLED` flag** and no way
to turn the gate off from a deployment-state switch: the whole point of the
release gate is that the block cannot be disabled by flipping configuration,
and a safeguarding control that could be silently switched off would be worse
than none. Reads of already-delivered messages keep working; a blocked pair
simply cannot start new contact. An unblock removes the row and immediately
re-enables messaging between the pair.

**Escalation always unmasks.** The "keepMasked on escalate" option in the
original slice spec was removed from the contracts because escalation is
defined as the disclosure boundary; a moderator who wants the platform
operators to see the reporter must accept that disclosure. `V1ReportLifecycleRequest`
gains `priority` (the triage reprioritization) instead.

**Evidence is append-only history, not a state cell.** `addReportEvidence`
carries no `expectedVersion` and is snapshot/append-only by trigger; evidence
rows are legally-relevant and irreplaceable, so they are not versioned, not
soft-deleted, and not overwritable.

**Content controls are one editable, versioned policy row.** `relaxed|moderate|strict`
filtering level (default `strict`), `messagingEnabled`, `classifierAssistEnabled`,
`supportContact`, plus a version — read by any active member, written by the
school's admin or an operator with `expectedVersion`. The spec's free-form
`customContacts`/`webhooks` repetition was dropped to avoid a second,
unversioned, not-audited store of the same policy.

**Wellbeing visibility is not widened.** No SAFE-043 function reads
`public.wellbeing_events`; a `safeguarding_restricted` record has no code path
into the moderation queue or the evidence table.

**Two later transforms are resolved by later slices, storage only here.** A
safe-listing block pump and a parallel platform-operator queue path were
explicitly out of scope and remain visible as gaps, not silently claimed.

## Consequences

- A school's admin can now triage, resolve, appeal, and — only by explicit
  escalation — attribute reports; a platform operator can hold legally-relevant
  data and pause an account deletion of the subject; a user can report and
  block; new contact across a block is refused by the data layer itself.
- Deleting/modifying shared history has no API path: report events and
  evidence are append-only by trigger, and there is no route that rewrites
  them.
- Operator-only operations are correct at the SQL level, so the catalogue's
  permission cannot be misused by a future route change.
- Messaging block enforcement ships always-on; there is deliberately no flag
  to disable it. Rolling back the *rest* of SAFE-043 is still just the four
  `SAFE043_*_ENABLED` switches.
- Outbox notification of resolution/appeal/evidence events is outbox-only
  (no OPS-061 queue), the same honest limitation API-042 records.
- Flutter/mobile wiring is fully deferred: no Dart/Flutter SDK was available.
  The typed contract surface is ready to be wired against; no screen was
  rewired.
- No verification could be run this slice: the environment had no `bun`/
  `node`/`docker`/`supabase` toolchain (recorded in the evidence doc). All
  suites are written statically and wired into CI; they must pass before this
  ADR is re-approved for staging, and the evidence doc carries the drift
  statement and the running-verification checklist.

## Recovery

Disable individual clusters via their `SAFE043_*_ENABLED` flags; the messaging
block gate cannot be disabled except by unblocking the affected pair. Repair
data through a forward migration or an explicit forward correction command;
granting `studafy_api_runtime` a table/column grant to patch around a gap is
the one prohibited recovery, exactly as in every prior ADR. Never "unmask"
reporter identity except through the escalation transition, and never restore
or edit appended evidence rows.