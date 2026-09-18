# SAFE-043 verification transcript

- Evidence date: 2026-09-16
- Target: local workspace and disposable local Supabase
- Data: generated synthetic identities and school records only
- Remote deployment/change: none
- Flutter/mobile: not evaluated. No Dart/Flutter SDK was available in this
  environment; this phase is backend-only by explicit choice, recorded here
  rather than silently omitted.

## IMPORTANT — this slice could not be executed

This document is written **statically, from code inspection, with no toolchain
available**. The environment had no `bun`, no `node`, no `npx`, no `docker`,
and no `supabase` CLI: nothing here was run, nothing compiled, nothing was
reset, and no plan was explained away. Every suite was written by hand against
the already-shipped API-040/041/042 patterns and wired into CI; until CI (or
any environment with the pinned toolchain) runs them, the results in the
"Executed verification" tables below are **pending, not passing**.

This does not change what shipped. What shipped is code, contracts, tests and
a drill; what the release gate needs is the "Verification checklist" at the
bottom executed against a clean disposable stack. Ship nothing on this record.

## Delivered surface

- 23 authenticated `/v1`/`/internal` routes in one SAFE-043 cluster
  (indices 96–118 of `V1_ROUTE_CATALOGUE`): content controls, reporting +
  appeals, symmetric blocks, moderation queue/overview/triage/resolve/
  escalate/evidence, operator-only legal holds, and two-person MFA-gated JIT
  moderator sessions.
- Two forward-only migrations:
  `202609170001_safe043_safety_schema.sql` (nine tables, three enums, RLS
  policies, immutable/append-only triggers, indexes, sequence revokes) and
  `202609170002_safe043_surface.sql` (helpers, `authz_authorize` additions,
  `api042_query`/`api042_command` wrappers extended via the established
  rename-and-delegate chain, the always-on messaging block gate, per-operation
  audit/outbox tails).
- Contracts: `packages/contracts/src/v1/safety.ts` (all `V1*` schemas) and
  `packages/contracts/src/v1/routes.ts` (23 catalogue rows).
- API module: `apps/api/src/safety/{repository,routes}.ts` mounted into
  `apps/api/src/index.ts` after schoolRoster; 19 new AUTH-031 permission
  definitions in the catalogue.
- Config: `SAFE043_REPORTING/BLOCKS/MODERATION/CONTENT_CONTROLS_ENABLED`
  fail-closed switches. No `SAFE043_MESSAGING_ENABLED` — the block gate is
  always-on by design (ADR-0021).
- Test and operational surface: a pgTAP schema-suite (`safe043_safety_schema.sql`),
  a pgTAP surface-suite (`safe043_surface_seed.sql` including the surface
  file), a Bun HTTP integration suite (`apps/api/test/safety/safety.integration.test.ts`),
  a drill script (`scripts/moderation-drill.ts`), and CI wiring
  (`.github/workflows/ci.yml`).

## Contracts to decision

The SQL and the zod contracts were reconciled during this slice, so the
documented behaviour and the enforced shape agree:

| Contract | Decision |
|---|---|
| `V1HoldReportRequest` | `subjectUserId` + nullable `expiresAt` (yes/no explicit expiry), `appliedTo` defaults to `"report"` |
| `V1AddReportEvidenceRequest` | no `expectedVersion` (evidence is append-only history) |
| `V1ReportLifecycleRequest` | optional `priority` (triage reprioritization) |
| `V1EscalateReportRequest`, `V1ReportLifecycleRequest` | no `keepMasked` — escalation always unmasks (disclosure boundary) |
| Gate flag | removed; SQL block gate always on, no deployment switch |

## Defects found in code while writing, and fixed

1. **`holdReport` read the pre-alignment request shape.** It read
   `forUserId`/`durationHours`; it now reads `subjectUserId` + `expiresAt`
   (computed as `greatest(expiresAt, now()+1 hour)` when set, else null),
   matching the Swiss-contract `appliedTo: "report"` default.
2. **`addReportEvidence` enforced an `expectedVersion`** that the evidence
   append-only decision forbids; the version check was removed and the
   contract's evidence request carries none.
3. **Stale flag references.** `catalogue.ts`'s `block.manage` description and
   the migration's header both still said blocks turn on with a
   `SAFE043_MESSAGING_ENABLED` flag that no longer exists; both now state the
   gate is unconditional.
4. **Drill/tenant GUC scoping.** The drill's tenant-scoped reads
   (`getContentControls`, `getModerationOverview`) must set the
   `studafy.school_id` session variable (empty-school reads would create a
   missing-reservation mismatch identical to the API-042 S8 test-harness bug);
   the drill now passes the school for tenant reads.

## Negative-path and defense-in-depth matrix

| Risk | Executable evidence where it lives |
|---|---|
| Report flooding / duplicate reporting | `createReport` dedupes on the same 24h digest per reporter and enforces a 20/window cap inside the insert transaction |
| Reporter identity leak | Queue/overview/report reads return `reporterId: null` until escalation; only escalations unmask, permanently |
| Cross-school moderation | `safe043_can_access_report` requires the report's own school; cross-school/substitution denied as 404 |
| Non-moderator queue reads | A teacher without moderation standing gets 404, not a queue |
| Legal-hold bypass | A school admin passes `moderation.hold` authorization but the SQL `holdReport` demands `is_platform_operator()` → 403, asserted in the Bun suite as the backstop proof |
| Self-approved moderator session | `private.is_second_approver` refuses the requester; a second operator is required |
| MFA-less moderator session | Request/approve check `aal2` this *request* inside `api042_command`; an MFA-less operator request → 403 |
| Stale-version state-machine abuse | Triage/resolve/escalate/appeal/hold/release/unblock all consume `expectedVersion`; re-revoke returns 409 |
| Blocked pair messaging | `api042_command`'s messaging interception refuses `sendMessage`/`createConversation` in either block direction; cannot be disabled by config |
| Deletion under a hold | Subject user hold pauses an accounted deletion until release; release is operator-only |
| Message-attached report scope | Message/conversation reports require participant/admin standing at reporting time; snapshots captured at submission |
| Wellbeing leakage | No SAFE-043 function reads `public.wellbeing_events` (asserted by grep invariants in the schema suite) |

## Executed verification

Nothing executed. The results below are the **run-me checklist**; they are
written as if completed for readability and are **false until actually run**.
The drift statement in the next section is the honest framing.

| Proof | Result (pending) |
|---|---:|
| Clean `supabase db reset --local` | all migrations through `202609170002` replay |
| `bunx supabase db lint --local --level error --fail-on error` | no schema errors |
| `supabase/tests/safe043_safety_schema.sql` | 24 assertions, 0 failures |
| `supabase/tests/safe043_surface_seed.sql` | 68 assertions, 0 failures |
| `DATABASE_URL=… bun test apps/api/test/safety` | HTTP suite, 0 failures |
| `DATABASE_URL=… bun scripts/moderation-drill.ts` | full lifecycle drill passes, exits 0 |
| API-040/041/042 pgTAP regression (unchanged by this slice) | 0 failures |
| `bun run typecheck` | all workspaces pass |
| `bun run generate:check` | no OpenAPI/Dart drift |
| `bun run generate:db-types:check` | no drift |

## Drift statement

This record describes intended behaviour and pending results. It must not be
read as verification. Any difference between what CI actually reports and the
tables above is a real defect to fix before SAFE-043 can be re-approved — it
is **not** an excuse to edit the checklist. If the surface suite's plan count
or the integration suite's route contract drifts from this document, fix the
product first and re-record, exactly as API-042 did for its two named defects.

## Generated artifacts

| Artifact | SHA-256 (of the file as written this slice) |
|---|---|
| `supabase/migrations/202609170001_safe043_safety_schema.sql` | `d34117445f6999ca24b52f4ff0cd018403f6d0f45ef821faffbe8ad682b62bdd` |
| `supabase/migrations/202609170002_safe043_surface.sql` | `9a2843b2f55a7595e4fa6680bf467f5633552e2e7e8e28303a1faac2985a66e6` |
| `packages/contracts/src/v1/safety.ts` | `9c48dfdbd652d5fcd78ea96436c32b275cfa013f095dcc11ec774ee728bb44c8` |
| `packages/contracts/src/v1/routes.ts` | `0ab29efa2ee5e507804f34cece0ba55cafdb84f55da01bf51f9aee9691f4af06` |
| `apps/api/src/safety/routes.ts` | `fff80b945a7880970de571a107741cbcc378dc92b44a4e4c33f6c5df341ff82a` |
| `apps/api/src/safety/repository.ts` | `026aa32fa56fce8a5b7e5805f17988c77984f4a92a1d013b4578ffa0dad57c14` |
| `apps/api/test/safety/safety.integration.test.ts` | `04562fd8fa8a688192d4ddf1225bcd206152c3bfe53dd9f66e41c07387081e93` |
| `supabase/tests/safe043_surface.sql` | `0530c88d8cb609428e4e784f1b5d14f6dcf54710a80a7c6a7864fd5a104e8bd0` |
| `supabase/tests/safe043_safety_schema.sql` | `00e14123cdb68e6ff00faf76e74c89eb3d3967925f9967c8cf86923dbb10ed94` |
| `supabase/tests/safe043_surface_seed.sql` | `83c77f042b92834835b27b888a9ac671d248b6b7a8b0bcc9f2e1e3c973512780` |
| `scripts/moderation-drill.ts` | `992b92319340ff746f0aff6823b9758394683bcd509908c3b40b71cae539b96b` |

These hashes are of the working-tree files and will change with any honest
fix; they are recorded so a reviewer can prove this transcript matches the
exact artefact set it describes.

## Not evaluated

- **Execution of any kind** — see the top of this document.
- **Flutter/mobile wiring** — no Dart/Flutter SDK was available; no screen
  rewired, the typed contract surface is ready to be wired against.
- **A real scheduler (OPS-061).** Grant expiry and outbox delivery are lazy/
  outbox-only; no queue exists.
- **Query-plan/index proofs at scale.** New tables reuse
  `(school_id, id)`-style indexes by construction; not independently measured.

## Gate assessment

SAFE-043's local engineering **code** is complete; its local engineering
**verification** is not, because no toolchain could run in this environment.
"Code complete, verification pending" is the honest status; the release gate
stays open until the checklist above executes green. The two named later
transforms (safe-listing block pump; parallel platform-operator queue path),
OPS-061/090, independent security review, a second security-architecture
review of the release-gate pattern, production E2E, and the Flutter/mobile
wiring all remain as recorded gaps. Nothing in this document authorizes
remote deployment or real student data.

## Verification checklist (the actual requirement)

On any environment with the pinned toolchain, in this order, at least once:

1. `bun install --frozen-lockfile`
2. `bunx supabase start` — disposable stack
3. `bunx supabase db reset --local --no-seed` — clean replay of every
   migration including `202609170001/0002`
4. `bunx supabase db lint --local --level error --fail-on error`
5. `bunx supabase test db --local supabase/tests/safe043_safety_schema.sql`
6. `bunx supabase test db --local supabase/tests/safe043_surface_seed.sql`
7. `DATABASE_URL=postgresql://postgres:postgres@127.0.0.1:54322/postgres bun test apps/api/test/safety/safety.integration.test.ts`
8. `DATABASE_URL=… bun scripts/moderation-drill.ts`
9. Re-run the API-040/041/042 pgTAP and Bun suites to prove no regression
10. `bun run typecheck && bun run generate:check && bun run generate:db-types:check`

Only when 3–9 report the numbers in this transcript can this ADR/DL-042 entry
be re-recorded from "verification pending" to "Decided for local/disposable
use".