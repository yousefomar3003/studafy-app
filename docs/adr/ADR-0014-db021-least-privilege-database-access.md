# ADR-0014: DB-021 least-privilege database access

- Status: Accepted for local/disposable use
- Date: 2026-09-11
- Decision log: DL-028

## Context

The inherited Supabase grants allowed anonymous and authenticated roles broad
table operations, with RLS as the primary guard. Legacy policies exposed whole
class rosters, inferred teacher access through `classrooms.teacher_id`, and did
not consistently enforce lifecycle state, exact classroom relationships, or
guardian expiry. Public helper functions also enlarged the RPC surface.

## Decision

Keep only the narrow direct reads needed by the current Flutter and contained
Edge Function flows. Authenticated clients receive column-level `SELECT`
grants and two bounded RPCs; they receive no direct table mutation privilege.
Anonymous clients receive no application table, column, sequence, or RPC
privilege. Privileged mutations remain in audited server functions until later
API command routes replace them.

Authorization helpers live in the non-exposed `private` schema, use qualified
names and empty search paths, and derive identity exclusively from `auth.uid()`.
They require active profiles, schools, memberships, validity windows, exact
enrollments, canonical `classroom_staff` assignments, and verified unexpired
guardian relationships. Sensitive columns such as storage paths, answer keys,
hashes, and processing metadata are not directly granted.

The service role keeps only operations observed in the contained Edge
Functions. Future API and worker roles are created as `NOLOGIN`, `NOINHERIT`,
`NOBYPASSRLS` roles with no object grants. Migration-owner default privileges
are fail-closed. Platform-owned `supabase_admin` defaults cannot be changed by
the application migration role and remain a provider configuration concern;
every application-owned object is nevertheless explicitly revoked at cutover.

Relationship and tenant identifiers are immutable after insertion, including
submission `school_id`, `assignment_id`, and `student_id`. File, conversation,
outbox, event, new billing, and AI relations remain inaccessible to clients.

## Consequences

- Existing Flutter profile, class, guardian, notification, entitlement, and
  Study Coach material reads remain supported.
- `markAllNotificationsRead` calls `mark_notifications_read()`; callers cannot
  provide ownership, timestamps, or row identifiers.
- Existing direct client writes fail even if a future policy is accidentally
  added without a matching grant.
- Policy correctness depends on canonical lifecycle data and the indexes
  established by DB-020/021.
- Support and safeguarding-specialist roles are not invented in this phase;
  safeguarding-restricted wellbeing is creator/school-admin only.
- This local decision does not authorize a remote migration or close Phase 2.

## Recovery

Each migration is transactional. A failed application rolls back. A defect
after application is corrected with a new forward migration that restores only
the last reviewed column/policy allowlist; broad grants and unsafe submission
writes are never restored. Remote use additionally requires independent policy
review, staging-scale rehearsal, backup/PITR approval, and explicit deployment
authorization.
