# ADR-0002: School as the tenant boundary; global multi-role users

Status: Accepted. Decision-log: DL-006. Date: 2026-09-10.

## Context

The current schema has `schools` with memberships, but `students.school_id` is
nullable and foreign keys do not enforce same-school consistency. Users are
Supabase Auth identities that can hold different roles; the app currently has
`teacher`/`parent`/`student` app roles and no administrator role, while the
target requires administrators and trusted provisioning.

## Decision

- `schools` is the tenant boundary. If school groups later require consolidated
  billing/administration, add `organisations`/`organisation_schools` rather
  than overloading school membership.
- Every school-owned aggregate carries a **non-null `school_id`** (Phase 2 adds
  this through staged backfill and composite same-school foreign keys).
- Users are global Supabase Auth identities. Authorization is always derived
  from active memberships plus resource relationships. A user may be
  administrator in one school, teacher in another, and guardian in a third
  without copying identity.
- Authorization roles: `platform_support` (never an app membership;
  just-in-time privileged operations only), `school_admin`, `teacher`,
  `guardian`, `student`. `parent` remains an API/display term only.
- Permissions are server-defined; clients never submit roles or school IDs for
  authorization decisions. `studafy_id` is a public locator with throttled
  server-mediated verification, never proof of relationship.

## Consequences

- Phase 2 (DB-020/021) makes cross-school graphs structurally impossible and
  adds composite tenant foreign keys and indexes.
- Phase 3 (AUTH-031) derives tenant context from active membership with
  versioned invalidation on revoke.
- The client's role-selection screen remains a UI convenience only; every
  API/RLS path independently verifies membership and relationship.
- School provisioning and administrator workflows remain deferred
  (ADR-0008/DL-014) and block detailed Phase 3 design.
