# API-042 verification transcript

- Evidence date: 2026-09-16
- Target: local workspace and disposable local Supabase
- Data: generated synthetic identities and school records only
- Remote deployment/change: none
- Flutter/mobile: not evaluated. No Dart/Flutter SDK was available in this
  environment; this phase is backend-only by explicit choice, recorded here
  rather than silently omitted.

## Delivered surface

- 44 authenticated `/v1`/`/internal` routes across 9 domain modules (schools,
  roster, memberships, classroom staffing, enrollment, invitations, family,
  communications, meetings, notifications, account rights, support access) —
  96 routes total including AUTH-030/API-040/API-041.
- 11 forward-only migrations (`202609160001`–`202609160011`), each extending
  the shared `private.authz_authorize`/`private.api042_query`/
  `private.api042_command` dispatcher via the established rename-and-fallback
  technique, plus one migration extending AUTH-030's recent-auth purpose
  allowlist.
- One deterministic, non-production reviewer-tenant seed script
  (`scripts/seed-reviewer-tenant.ts`) that provisions a full school through
  the real commands end to end.
- Twelve fail-closed per-slice switches
  (`API042_SCHOOLS_ENABLED` … `API042_SUPPORT_ACCESS_ENABLED`).
- Three legacy Edge Functions retired to `disabledFeatureResponse` (SEC-001
  containment pattern), never deleted — see the contract doc's retirement
  table.

## Executed verification

| Proof | Result |
|---|---:|
| Clean `supabase db reset --local` | all migrations through `202609160011` replayed |
| `bunx supabase db lint --local` | no new warnings from any API-042 function |
| API-042 pgTAP suites (9 files, run individually per their seed) | 195 assertions, 0 failures |
| — `api042_school_operations_seed.sql` | 45 assertions |
| — `api042_invitations_seed.sql` | 26 assertions |
| — `api042_family_seed.sql` | 21 assertions |
| — `api042_communications_seed.sql` | 21 assertions |
| — `api042_meetings_seed.sql` | 20 assertions |
| — `api042_notifications_seed.sql` | 16 assertions |
| — `api042_account_seed.sql` | 14 assertions |
| — `api042_support_access_seed.sql` | 20 assertions |
| — `api042_roster_seed.sql` | 12 assertions |
| AUTH-031/API-040/API-041 regression (unchanged by this phase) | 20 + 25 + 33 = 78 assertions, 0 failures |
| Full Bun workspace suite (`bun test apps packages`, real PostgreSQL + Redis) | 279 tests, 1,658 expectations, 0 failures |
| `bun run typecheck` | all 9 workspaces pass |
| `bun run generate:openapi` (regenerated, checked in) | clean, no `$ref` drift |
| `scripts/seed-reviewer-tenant.ts --local` | fresh provision, idempotent re-run, `--reset`, and the `ENVIRONMENT=production` refusal all verified manually |

The two legacy `db020_legacy_seed.sql`/`db021_upgrade_seed.sql` pgTAP files
report zero tests when run against the fully-migrated local stack; this
predates API-042 (they test a pre-DB-021 migration path this branch never
touches) and is unrelated to this phase's scope.

## Negative-path and defense-in-depth matrix

| Risk | Executable evidence |
|---|---|
| Expired/replayed invitations | `api042_invitations.sql`: expired token rejected, attempt budget enforced, already-accepted token rejected |
| Cross-school family/message/meeting substitution | Family/communications/meetings pgTAP and Bun suites assert 404 (concealed) for cross-school and non-participant resource ids |
| Membership status changing mid-request | `api042_school_operations.sql` reuses the AUTH-031 "live membership-revocation race" pattern for grant/activate/suspend/revoke |
| Duplicate provider/Calendar calls | Meetings integration tests assert exactly one Calendar call and one recipient query per meeting request, not per recipient |
| Two-person support-access approval | `api042_support_access.sql`: self-approval forbidden, no-MFA approval forbidden, stale-version rejected, double-approval rejected |
| Account deletion/export | `api042_account.sql` + `account.integration.test.ts`: export request/status round-trip, duplicate pending request reused, both gated by a fresh recent-auth grant |
| Reviewer-account E2E | `scripts/seed-reviewer-tenant.ts` run against the local stack: school → term → classroom → 3 invitations/accepts → staffing → roster → enrollment → guardian link, entirely through real commands |
| "Actor has no memberships row" architectural gap | Fixed at its root in `private.api_idempotency_reserve` (widened for platform operators and guardian-only actors), the permission catalogue (`tenantRequired: false` on the affected permissions), and `createCatalogueRoutes`'s GET handler (tenant only required when a cursor is presented) |
| MFA/recent-auth for sensitive admin mutations | `school-admin.integration.test.ts`: suspend/close refused without a grant (401 `REAUTH_REQUIRED`), succeed with one, a fabricated grant is refused; `account.integration.test.ts`: export request refused without a grant |

## Two named defects fixed (task-required)

**Meeting recipient N+1 / duplicate-event behavior.** The legacy
`create-google-meet` Edge Function resolved guardians per-student in a loop
and could double-insert delivery rows on retry. `requestMeeting`'s SQL
resolves the full recipient set (students ∪ verified guardians ∪ staff) in
one `UNION ALL` subquery and performs one bulk `INSERT … SELECT` into
`meeting_deliveries`; `cancelMeeting` uses a single bulk `UPDATE`. Integration
tests assert exactly one Calendar-adapter call per meeting.

**JWT-`iat`-as-recent-auth.** The legacy `request-account-deletion` function
treated a token issued within the last ten minutes as proof of recent
authentication — wrong, because Supabase reissues `iat` on every silent
refresh. `POST /v1/account/deletion-request` (AUTH-030, already shipped
before this phase) and the two admin mutations/export command this phase
adds all use `requireRecentAuth`: a single-use, hashed, session-bound grant
minted by `/v1/auth/reauth/challenge` and consumed exactly once. The Edge
Function is retired to `disabledFeatureResponse`.

## Bugs found during this phase's own verification, and fixed

Test rigor surfaced defects beyond the two named above. Each is recorded in
its commit message; summarized here:

1. **S8 pgTAP test fixture**: backdating `expires_at` alone without
   `created_at` violated `support_access_grants`' `expires_at > created_at`
   check — the same mistake, and the same fix, as S2's invitation-expiry
   fixture.
2. **S8 pgTAP test fixture**: the approve/start/revoke/list section never set
   the `studafy.school_id` session variable to the real school, so
   `private.api042_command`'s tenant-matched idempotency-reservation lookup
   never found the reservations those calls made — every one of them fell
   through to a generic `forbidden`. Not a product bug; a test-harness bug
   that made the real commands impossible to verify until fixed.
3. **`school.suspend`/`school.close` unreachable for a platform operator**:
   both used the `resource()` catalogue helper's `tenantRequired: true`
   default, which needs a membership-derived tenant a platform operator
   structurally never has. A platform operator could not suspend or close
   any school over the real API. Found integration-testing the reauth fix
   below against real HTTP (the existing pgTAP suite calls the SQL
   dispatcher directly and never exercised this layer).
4. **School closure/suspension and account data export had no MFA/recent-auth
   gate at all.** `requireRecentAuth`/`requireAal2` existed only as
   hand-written middleware in `auth/routes.ts`, unreachable from the generic
   catalogue dispatcher every API-042 module uses. `instructions.md` section
   7 names both explicitly. Fixed by adding an optional `reauth` option to
   `createCatalogueRoutes`.
5. **`createClassroom`/`enrollStudent` were unreachable for a fresh school.**
   Nothing in the catalogue could create a `terms` or `students` row.
   Found writing this evidence's own reviewer-tenant proof. Fixed by adding
   `createTerm`/`createStudent`.

## Atomicity and idempotency

Every API-042 command follows API-041's transaction shape exactly: one
`private.api042_command` call per request, inside a transaction whose local
settings carry the verified actor, server-derived school (where one exists),
and request id; mutation, audit-event insert, conditional outbox insert, and
idempotency completion commit or roll back together
(`private.api_idempotency_complete`; a failed completion raises and rolls
back the whole command). `studafy_api_runtime` retains zero table/column/
sequence grants throughout this phase; every new SQL function is
execute-only.

## Generated artifacts

| Artifact | SHA-256 |
|---|---|
| `202609160001_api042_foundation.sql` | `e0c735677ab2ddff28aef905120f4cc905ac4a178b32b8b642fbd52226312b68` |
| `202609160002_api042_school_operations.sql` | `b4494f6e4be9d071f6121ffb1806487b447cbcbf75d9359a9516e64f2878947d` |
| `202609160003_api042_invitations.sql` | `f56ce8a926444c8ec14fecdf09f9b9f24710d102eb5a5769d18c4b6b147e2ca0` |
| `202609160004_api042_family.sql` | `eacdd4c12fedc8a483399c07bf599e2872a6513162a7731b7729be63b2db0f46` |
| `202609160005_api042_communications.sql` | `4294eb43da6f5ca7f23ba921aee292f0307b9e9cd57ba913e7a3cf385453d579` |
| `202609160006_api042_meetings.sql` | `8ea5c37c07d42ceb90771829a0489778ff1311c89f5e3964c2b12bd8a3cfb040` |
| `202609160007_api042_notifications.sql` | `da3debe1f4cb3459913631aeb2704c6985d67cd6eb4aecb3926eff9a5d000537` |
| `202609160008_api042_account.sql` | `38e66fbc28beb2485c518d483be5df2c6c90fe714459ad8572d8c4f5272e5f8a` |
| `202609160009_api042_support_access.sql` | `58c5684b77a02fab2e66dcaac55c1f6eca2a0538e3d2cdd731c850b778e180f7` |
| `202609160010_api042_reauth_purposes.sql` | `6ff5ee07518ad40b4201e5e1f93d67b4eb1c4c95e300eb192d8a4d7b721eda89` |
| `202609160011_api042_terms_students.sql` | `a97c12777ceaca0a93ab1d35c6dc3883c13caec4d98bbd43f8fc63384bf24f96` |
| `packages/contracts/openapi/v1.json` | `f85c119aa6aa44476a909d11906a62e4e9f1bffccfcbfcf51c3f4d7d550c5d01` |

No Dart client artifact is listed: it was not regenerated this phase (see
"Not evaluated" below).

## Not evaluated this phase

- **Flutter/mobile.** No screen was rewired; the Dart client was not
  regenerated. Every new domain has a real typed `/v1` surface ready to be
  wired against once a Flutter/Dart SDK is available.
- **Query-plan/index proofs at scale.** API-041's 2,000-row-per-slice
  `EXPLAIN ANALYZE` gate was not re-run for API-042's new tables
  (`invitations`, `support_access_grants`, `notification_preferences`,
  `data_export_requests`, `guardian_links` additions). All new query paths
  use existing `(school_id, id)`-style indexes from DB-020/021 by
  construction, but this is not independently measured.
- **OPS-061.** No real queue exists. Meeting Calendar calls run
  synchronously behind the command transaction; notification/export fan-out
  is outbox-only. This is the same honest gap API-041's evidence records.

## Gate assessment

API-042's local engineering acceptance is met: every listed school-operations
workflow is authoritative through real `/v1` commands, the two named legacy
defects are fixed and their Edge Functions retired, and the reviewer-tenant
script proves a fresh school can complete onboarding end to end without
local-only state. Production traffic is not enabled by this result.
SAFE-043, OPS-061/090, independent security review, hosted infrastructure,
production/device E2E, and the Flutter/mobile wiring deferred this phase
remain outside this part and keep the overall Phase 4/launch gate open.
