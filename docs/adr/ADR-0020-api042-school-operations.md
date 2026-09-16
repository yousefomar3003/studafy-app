# ADR-0020: API-042 school operations, invitations, family, communications, meetings, notifications, account rights and support access

- Status: Accepted for local/disposable use
- Date: 2026-09-16
- Decision log: DL-041

## Context

API-041 made the academic content vertical (classes, resources, assignments,
assessments, grades, attendance, wellbeing) authoritative, but every one of
AUTH-031/API-040/API-041's own evidence documents recorded the same
dependency: there was still no way to create a school, invite anyone to it,
staff a classroom, enroll a student, link a guardian, send a message,
schedule a meeting, read a notification, or correct/export a profile through
the authoritative API. That work was either local-only Flutter state or two
legacy Deno Edge Functions (`create-google-meet`, `request-account-deletion`)
carrying the exact defects `instructions.md` names — meeting recipient N+1
and a JWT-`iat`-as-recent-auth check that Supabase's own refresh behavior
makes meaningless.

## Decision

API-042 extends AUTH-031/API-040/API-041's established patterns rather than
inventing new ones: one shared route catalogue, one `SECURITY DEFINER` SQL
dispatcher per domain extended via a rename-and-fallback chain
(`private.api042_query`/`api042_command`, `private.authz_authorize`), one
idempotency table, one audit/outbox mechanism, one permission catalogue. The
full route inventory and per-domain authorization notes are in
`docs/api/v1-school-operations-contract.md`; this record covers what would
not be evident from reading the routes alone.

**Platform-operator and school-admin privilege grants are never exposed
through any API.** `public.platform_operators` has no INSERT/UPDATE route.
Granting it is a deliberate, out-of-band, service-role-only SQL operation,
documented in the operator runbook — not an oversight.

**The "actor has no `memberships` row" gap, found and fixed at its root.**
AUTH-031's tenant cache can only derive a tenant from an active membership.
Platform operators and guardians (verified only through `guardian_links`,
not `memberships`) structurally never have one. Rather than patch each
symptom, this was fixed in the three places it actually lives:
`private.api_idempotency_reserve`'s own membership gate (widened with an
explicit allowlist), the permission catalogue (`tenantRequired: false` on
every permission a memberships-less actor legitimately exercises), and
`createCatalogueRoutes`'s GET handler (a tenant is only required when a
signed cursor is actually presented — a single-resource read for a
recipient with no membership, like a guardian reading meeting status, does
not need one). `school.suspend`/`school.close` initially shipped with the
wrong default here (`tenantRequired: true` via the generic `resource()`
helper) and were unreachable for a platform operator until integration-
testing the reauth requirement below against real HTTP — not the SQL
dispatcher directly, which the existing pgTAP suite already exercised and
which is exactly why this was invisible there — surfaced it.

**MFA/recent-auth for the mutations `instructions.md` section 7 names by
name.** Support access requires AAL2 *unconditionally*, checked from
`RequestDbContext.aal2` (sourced from the verified session, never a client
claim) inside the SQL dispatcher itself, because role-policy-gated
`requireAal2()` would never fire for a platform operator with no
memberships row to derive a policy from — the same gap as above, in a
different shape. School closure/suspension and account data export require
a fresh, single-use recent-auth grant, added by giving
`createCatalogueRoutes` an optional `reauth` option that applies
`requireRecentAuth()`/`requireAal2()` in the same position AUTH-030's own
hand-written routes already do (after idempotency reservation, before the
handler) — these two checks previously existed only in `auth/routes.ts` and
were unreachable from the generic dispatcher every API-042 module uses,
so this MFA/recent-auth requirement, though named in the source
requirements, had not actually been wired in until this was found.

**Two commands added that nothing in the catalogue could reach before now:
`createTerm` and `createStudent`.** `createClassroom` (API-041) requires an
existing term; `enrollStudent` (API-042 S1) requires an existing student
row. Until this ADR's slice, no command created either — a freshly
provisioned school could never reach a working classroom or roster entry
through the real API, only through test fixtures that seeded both directly
via SQL. This was found writing the reviewer-tenant seed script, whose job
is to prove the onboarding lifecycle works end to end on a school that
starts with nothing.

**Meeting recipient resolution is one set-based query.** Enrolled students ∪
their verified non-expired guardians ∪ active classroom staff, deduplicated,
one bulk insert into `meeting_deliveries`, one bulk email-resolution call
granted only to the worker runtime. This replaces the legacy per-student
loop and is asserted by an explicit "one Calendar call per meeting, not per
recipient" test.

**Recent auth replaces the JWT-`iat` check.** `POST /v1/account/deletion-
request` already used AUTH-030's single-use hashed recent-auth grant before
this phase; `request-account-deletion`'s retirement (which carried the
broken check) is this phase's cleanup of the now-fully-superseded legacy
path, independent of the rest of the slice.

**The reviewer/demo tenant is provisioned entirely through real commands,
never raw SQL inserts of product data**, so that the script succeeding is
itself end-to-end evidence: `scripts/seed-reviewer-tenant.ts` builds the
same Hono request pipeline `apps/api/src/index.ts` assembles in production
(factored into `apps/api/src/bootstrap/seedApp.ts` so the script — outside
every workspace package's own `node_modules` — never needs to resolve
`hono` directly), obtains real GoTrue-issued, JWKS-verifiable tokens for
each seeded account via password grant, and drives `provisionSchool` →
`createTerm`/`createClassroom` → `issueInvitation`/`acceptInvitation` ×3 →
`assignClassroomStaff` → `createStudent`/`enrollStudent` →
`requestGuardianLink`/`verifyGuardianLink` over real HTTP. The one direct-SQL
step is granting the seed-operator identity a `platform_operators` row —
the same sanctioned out-of-band operation named above, done by an
operational script running with the service role, not product code.

Legacy Edge Functions are replaced only after their equivalent Hono commands
pass authorization, transaction, idempotency and retry tests, per the SEC-001
containment pattern: a feature-flag hard return (`disabledFeatureResponse`),
never a deletion, so the decision's audit trail stays in the repository.

## Consequences

- A fresh, approved school can complete onboarding, staffing, enrollment,
  guardian linking, and account rights entirely through real `/v1` commands
  — proven by `scripts/seed-reviewer-tenant.ts` succeeding against the local
  stack, not merely by the code compiling.
- Communications ships conversations/messages/announcements only; SAFE-043
  (report/block/moderation) remains a separate, mandatory gate before launch.
- Meeting/notification/export side effects are outbox rows, not dispatched
  jobs — OPS-061 does not exist yet. This is the same honest limitation
  API-041's ADR records, extended to three more workflows.
- Flutter/mobile wiring is fully deferred: no Dart/Flutter SDK was available
  in this environment. Every new domain has a real typed `/v1` surface ready
  to be wired against; no existing screen was rewired, and this is not
  claimed as done.
- Query-plan/index proofs at scale (API-041's 2,000-row `EXPLAIN ANALYZE`
  gate) were not re-run for API-042's new tables. All new query paths reuse
  existing `(school_id, id)`-style indexes by construction, but this is not
  independently measured this phase.
- Two independent authorization gaps (the `tenantRequired` default on
  `school.suspend`/`school.close`, and the entirely-missing recent-auth
  wiring for the same two commands plus data export) existed in already-
  committed migrations for part of this phase before being found and fixed
  within it. Both are recorded here rather than quietly folded into the
  original commits, and both are covered by tests that would have failed
  before the fix.

## Recovery

Disable the affected API-042 slice via its `API042_<NAME>_ENABLED` flag and
present read-only/unavailable UI for that area only; every other module,
including AUTH-030/API-040/API-041, is unaffected. Repair data through a
forward migration or an explicit forward correction command. Do not restore
any of the three retired Edge Function invocations, grant the runtime a
table/column grant to patch around a gap, bypass the recent-auth/AAL2
checks added this phase, or run the reviewer-tenant script against a
production project.
