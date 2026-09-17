# FILE-050 verification transcript

- Evidence date: 2026-09-17
- Target: local workspace and disposable local Supabase only
- Data: deterministic synthetic fixtures only
- Remote changes or deployment: none
- Migration: `202609170003_file050_upload_pipeline.sql` (forward-only)

Everything below was **executed** in this environment. Where a requirement
from the FILE-050 plan is not covered by an executed assertion, it is listed
under [Gaps](#gaps-against-the-plan) rather than implied to have passed.

## Gate assessment

| Gate | Result |
|---|---|
| Path substitution denied | **Pass** — contract, route, pgTAP, and live-storage proof |
| Cross-tenant binding denied | **Pass** — concealed as `404` before signing |
| Quota exhaustion enforced | **Pass** — sequential (pgTAP) and concurrent (two backends) |
| Oversized uploads denied | **Pass** — before signing and before download |
| Type-mismatched uploads denied | **Pass** — magic-byte detection, object `rejected` |
| Zero runtime table grants | **Pass** |
| Registration atomicity | **Pass** — forced outbox failure rolls back whole |
| `allowsRemoteFileUploads` still false | **Pass** |
| Nothing becomes `clean` | **Pass** — no code path sets it |

FILE-050 is complete as local engineering evidence. It does **not** authorize
deployment, remote use, or real school data, and it does not close Phase 5 —
FILE-051 (scanning and delivery) remains the gate.

## Executed verification

| Suite | Command | Result |
|---|---|---|
| TypeScript | `bun run typecheck` | 9/9 workspaces clean |
| Bun tests | `bun test apps packages` | 302 pass, 1 skip, 1 fail (pre-existing SAFE-043, below) |
| pgTAP | `bunx supabase test db --local supabase/tests/file050_upload_seed.sql` | 36/36 pass |
| Storage | `bun run test:file050:storage` | 1 pass, 5 assertions |
| Quota races | `bun test apps/api/test/files/quota.integration.test.ts` | 4 pass, 18 assertions |
| Query plans | `bun run test:file050:plans` | 5 queries, all index-backed |
| Boundaries | `bun run check:bounds` | 0 violations |
| OpenAPI/Dart drift | `bun run generate:check` | clean |
| DB type drift | `bun run generate:db-types:check` | `result: pass` |
| Lint | `bun run lint` | 141 files clean |
| Format | `bun run format:check` | 164 files clean |
| Build | `bun run build` | api + worker bundled |
| Flutter analyze | `flutter analyze` | no issues |
| Flutter tests | `flutter test` | 127 pass |
| Secret scan | `gitleaks detect` | no leaks in history; working-tree findings confined to gitignored `build/` |
| Database lint | `bunx supabase db lint --local --level error --fail-on error` | no errors |
| Full CI database job | replay from zero, then the eleven pgTAP suites in CI order | all pass |
| Edge Functions | `deno check --frozen=true`, `deno test --frozen=true`, `deno lint`, `deno fmt --check` | all clean |
| Dart format | `dart format --set-exit-if-changed lib test tools` | 148 files, 0 changed |
| Dart boundaries | `dart run tools/check_dart_bounds.dart` | 58 feature files, 0 violations |

### pgTAP coverage (36 assertions)

Grants and policy surface:

1. FILE-050 leaves API runtime with zero table grants
2. API runtime can execute only the narrow intent command
3. authenticated clients cannot invoke file commands directly
4. no direct authenticated storage insert policy is restored

Intent rejection before signing:

5. oversized intent is rejected before signing
6. purpose type allowlist is enforced
7. cross-tenant binding is concealed

Issuance and atomicity:

8. authorized upload intent is issued
9. intent reserves one active session
10. only the server-provided quarantine key is persisted
11. intent and idempotency response commit together
12. intent writes one redacted audit event

Quota:

13. active-session quota is serialized and enforced
14. failed quota check creates no second reservation
30. rolling intent quota is enforced before issuance

Completion:

15. matching object completes
16. completed object remains quarantined
17. object receives one durable session binding
18. completion emits one scan outbox job

Mismatch handling:

19. type-mismatch fixture receives an exact reservation
20. magic-type mismatch is rejected
21. type mismatch makes the session terminal
22. type-mismatched bytes never enter quarantine
23. type mismatch enqueues exact-object deletion
24. observed-size mismatch is rejected
25. deterministic mismatch and idempotency completion commit together

Cleanup:

26. cleanup worker claims only the two delete jobs
27. cleanup claim resolves the immutable server-owned exact key
28. cleanup acknowledgement succeeds only for the claiming worker
29. database deletion is recorded only after worker acknowledgement
33. a failed deletion is acknowledged without raising
34. a failed deletion is rescheduled for retry
35. the retry records why the deletion failed
36. a failed deletion never records the object as deleted

Delivery boundary:

31. quarantined objects cannot receive download intents
32. another tenant cannot resolve the server-owned object path

### Negative storage transcript

`bun run test:file050:storage` runs against the real local Supabase storage
service with a real service-role credential, refusing to run if the API
origin is not `http://127.0.0.1:`. It proves, in order:

1. A server-issued signed capability uploads successfully **to its own key**.
2. The same token used against a *substituted* object key is **denied**
   (`denied.ok === false`) — this is the direct SEC-001 regression test.
3. The registered bytes are inspectable server-side: existence, exact size,
   and `image/png` detected from magic bytes.

### Quota-race and atomicity transcript

The pgTAP suite runs inside a single transaction, so it can only demonstrate
*sequential* quota enforcement. `apps/api/test/files/quota.integration.test.ts`
was added to close that gap with real concurrency. Each contender records
`pg_backend_pid()` and the test asserts the two differ, so a pass cannot come
from two transactions sharing one pooled connection:

| Case | Setup | Assertion |
|---|---|---|
| Last session slot | `user_active_sessions = 1`, two intents race | outcomes are exactly `["concurrency_limit", "ok"]`; exactly 1 session row |
| Last quota byte | `user_rolling_bytes = 1 MiB`, two 1 MiB intents race | outcomes are exactly `["ok", "quota_exceeded"]`; exactly 1 session row |
| Concurrent completion | one session, two completions race | outcomes are exactly `["already_completed", "ok"]`; exactly 1 object, 1 binding, 1 scan job, 1 `upload_completed` audit event; object is `quarantined` |
| Forced outbox failure | trigger raises on `file_job_outbox` insert | completion throws; 0 objects, 0 bindings, session still `initiated`, reservation not `completed` |

The last case is the atomicity proof: the registration transaction writes the
object, binding, session update, outbox job, audit event, and idempotency
completion together, and a failure in any leg leaves none of them behind.

### Query plans

`bun run test:file050:plans` populates 2,000 target-tenant rows against
18,000 background rows and captures `EXPLAIN (ANALYZE, BUFFERS, FORMAT JSON)`
for every access path FILE-050 relies on:

| Query | Index | Execution | Plan nodes |
|---|---|---|---|
| `owner_status` | `file050_upload_owner_state_idx` | 0.088 ms | Limit → Index Only Scan |
| `school_rolling_quota` | `file050_upload_school_created_idx` | 0.054 ms | Aggregate → Index Scan |
| `expiry_sweep` | `file050_upload_expiry_active_idx` | 0.081 ms | Limit → Index Only Scan |
| `owner_file_status` | `file050_file_owner_created_idx` | 0.063 ms | Limit → Index Only Scan |
| `cleanup_claim` | `file050_file_job_claim_idx` | 0.474 ms | Limit → Sort → Bitmap Heap Scan → Bitmap Index Scan |

No sequential scan appears in any of the five. Latency figures are from a
local disposable database and are not a production commitment.

### Grant and policy scan

- `studafy_api_runtime` holds **zero** `information_schema.role_table_grants`
  rows (pgTAP assertion 1).
- `authenticated` cannot execute `private.api050_issue_intent` (assertion 3).
- `storage.objects` has **zero** INSERT policies (assertion 4); no
  authenticated select, list, update, or download policy was restored.
- The API role holds EXECUTE on the `private.api050_*` functions only.

### Boundary and direct-call scan

`scripts/check-file050-boundaries.ts` walks `apps/api/src` and `lib`, failing
on any direct `storage.from(` call, any `quarantine/v1/` path construction, or
any `SUPABASE_SERVICE_ROLE_KEY` reference outside a composition-root
`index.ts`. It also asserts the adapter still owns the server-generated key
and `upsert: false`.

Result: `FILE-050 boundary check passed: no client/handler path construction
or direct storage calls`, alongside the existing check
(`9 members, 82 source files, 0 violations`).

Storage-call distribution across tracked source:

| Location | Why it is allowed |
|---|---|
| `packages/infrastructure/src/privateFileStorage.ts` | the single storage adapter |
| `apps/api/src/index.ts`, `apps/worker/src/index.ts` | composition roots that inject the credential |
| `packages/config/src/index.ts` | schema and fail-closed validation only |
| `scripts/verify-file050-storage.ts`, `apps/api/test/files/storage.integration.test.ts` | synthetic local test support |

No Flutter file references storage, a credential, or a path.

### Generated artifact hashes

```
5c0b32e86a13b4e934b42c5786f4c85580bfab5805722b2977b00d807510f9e2  packages/contracts/openapi/v1.json
2773d05bb08dc6d9613fac243d3d3f9552d3ebaf3c45d5ab9384d98c6963bcab  lib/data/contracts/v1_client.generated.dart
9e1617d8c4f6e8898231a50fc60051a21741c4258c33ada80973a4c92d49e2ce  packages/database/src/database.types.generated.ts
348adb4352a6c20224d66610510fcd938190d30a0a37e8d70ca310bca0cc8323  supabase/migrations/202609170003_file050_upload_pipeline.sql
```

`bun run generate:check` and `bun run generate:db-types:check` both pass, so
the checked-in OpenAPI spec, Dart client, and database types match their
generators exactly.

### Route and authorization matrix

| Route | Index | Permission | Scope | Idempotency | FILE-050 behaviour |
|---|---|---|---|---|---|
| `POST /v1/uploads` | 119 | `upload.intent.create` | school | required | `201` with opaque capability; `503` while the switch is off |
| `GET /v1/uploads/{uploadId}` | 120 | `upload.read` | upload_session | — | owner-only session status |
| `POST /v1/uploads/{uploadId}/complete` | 121 | `upload.complete` | upload_session | required | verify and register; `422` on deterministic mismatch |
| `GET /v1/files/{fileId}` | 122 | `file.read` | file_object | — | owner-only safe metadata |
| `POST /v1/files/{fileId}/download-intent` | 123 | `file.download` | file_object | required | `FILE_NOT_CLEAN` / `FILE_DELIVERY_DISABLED` only |

Purpose authorization, verified in `private.file050_authorize_target`:

| Purpose | Authorized actor |
|---|---|
| `profile_image` | any active member, own image only |
| `lesson_resource` | active admin, or exact active lead/co-teacher |
| `assignment_material` | active admin, or exact active lead/co-teacher |
| `assignment_submission` | the student, active enrollment, published assignment, open window |
| `paper_scan` | active admin, or exact lead/co-teacher for the grade's class |
| `coach_attachment` | the student, own active school student record |

Assistants and guardians get no upload authority beyond their own profile
image.

## Defects found and fixed while verifying

1. **`normalizeDisplayName` failed `deno lint`.** The control-character strip
   tripped `no-control-regex`. Extracted to a named constant with an explicit
   ignore and a comment recording that the strip is deliberate — a display
   name is echoed to clients and must not carry path or terminal payloads.
2. **Twelve files were unformatted.** `deno fmt` applied; `format:check` now
   clean.
3. **Concurrency was asserted but never actually raced.** The original quota
   evidence was pgTAP-only, and pgTAP runs in one transaction. Added the
   four-case integration suite above, including the backend-PID assertion so
   the test cannot pass by accidentally serializing on one connection.
4. **`file_purpose_policies` and `file_quota_policies` had no RLS.** Both were
   created without `enable row level security`, breaking the repository
   invariant that every public application table has it. Caught by
   `db021_grants.sql` in the CI database job. Both tables already carry zero
   runtime grants, so this was defence in depth, but the invariant is
   fail-closed and explicitly tested. Fixed in the migration, which was
   unmerged and which CI replays from zero.
5. **The cleanup retry and dead-letter path could never run.** In
   `private.api050_finish_cleanup`, the CASE selecting `dead_letter` or
   `retry` produces `text`, and assigning `text` to the `outbox_state` column
   raises `42804`. A deletion that storage refused would therefore raise
   instead of backing off — precisely what the worker's failure branch calls.
   `supabase db lint --fail-on error` reports it; CI runs exactly that.
   The pgTAP suite had covered only the success path, so four assertions now
   cover the failure branch and the plan rose from 32 to 36.
6. **The reviewed API-runtime execute baseline was stale.**
   `auth030_grants.sql` pins the exact function set the API role may execute;
   FILE-050 adds five. The baseline now names them rather than being loosened.
7. **`deno.lock` was stale and two Dart files were unformatted.** Deno
   resolves npm dependencies across the whole bun workspace, so adding
   `@supabase/supabase-js` invalidated the frozen lockfile and failed the Edge
   Function job before it type-checked anything. `deno fmt` does not touch
   Dart, so `dart format --set-exit-if-changed` failed separately.

## Pre-existing failures, not caused by FILE-050

The Bun suite reports one failure:

> `SAFE-043 … > blocks are created and unblocked over the HTTP surface`

This was confirmed pre-existing by running the same suite from a clean
detached worktree at `HEAD` (`a05bf93`), where it fails identically. Four
SAFE-043 tests were failing there; three were straightforward test defects
and are fixed in this branch:

| Defect | Cause | Fix |
|---|---|---|
| `cleanup()` threw `Append-only relation cannot be updated or deleted` | `report_events`/`report_evidence` carry `safe043_reject_mutation`, which `cleanup()` never disabled, so the suite passed once against a fresh database and failed forever after | disable both triggers around the deletes, and delete `report_evidence` too |
| content-controls assert returned `400` | `V1UpdateContentControlsRequest` requires `schoolId` in the body; path params are not merged into the body, and the test only supplied it in the path | send `schoolId` in the body |
| moderator `start` returned `409` | the preceding `approve` moved the grant to version 2; `start`/`revoke` still sent the pre-approval versions | advance the expected versions |
| unblock returned `400`, then `500` | the test sent no JSON body at all; with a body it reaches the dispatcher, which returns the raw snake-case row | **not fixed — see below** |

### The SAFE-043 surface pgTAP suite has never passed

Separately, `supabase/tests/safe043_surface_seed.sql` fails. DL-042 recorded
why: SAFE-043 shipped with its suites written but never executed, because that
environment had no `bun`/`node`/`docker`/`supabase` toolchain. None of those
files are touched by this branch.

Two unbalanced-paren syntax errors are fixed here as partial progress — two
`api042_command` calls closed `jsonb_build_object` one paren too many, which
terminated the call early. With those corrected the script reaches further,
and what remains are authorization mismatches rather than syntax: "held report
leaves the queue" returns null, "teacher can block a student" returns
forbidden, and "operator request with MFA is accepted" returns forbidden. The
later `:'grant_id'` syntax error is a consequence, not a cause — the `\gset`
that binds it runs off a request that already failed.

Resolving those is SAFE-043 remediation and is not attempted here.

### The unblock route returns 500

The remaining Bun failure is a genuine SAFE-043 **product** defect, not a test
bug. In `202609170002_safe043_surface.sql`, the `unblockUser` branch sets
`response := before_value`, which is `to_jsonb(b)` — the raw row, with
snake_case columns. The route validates against `V1Block`, which is camelCase,
so `safeParse` fails and the handler returns `500`. Every other branch uses a
projection function (`private.safe043_block_json`); `unblockUser` cannot,
because it deletes the row first.

The fix is to capture the projection *before* the delete. It is left
unapplied here deliberately: the dispatcher is a single large PL/pgSQL
function, so a forward-only correction means re-emitting it in a new
migration, which is SAFE-043's scope and its own review. **`POST
/v1/blocks/{blockId}/unblock` currently returns `500` in every environment.**

## Gaps against the plan

Recorded rather than glossed:

- **No cross-tenant deduplication probe.** The plan asks for proof that
  cross-tenant hashes produce no dedup signal. No deduplication code path
  exists in FILE-050, so there is nothing to probe; assertion 32 covers the
  adjacent claim that another tenant cannot resolve the object path.
  FILE-051 must add the dedup probe when it adds dedup.
- **Expired and reused sessions are covered structurally, not end to end.**
  The expiry guard and sweeper are asserted in SQL; there is no wall-clock
  test that waits two hours.
- **Storage-failure injection is partial.** `StorageUnavailableError` maps to
  `503` in the route tests via a fake, but no test induces a real Supabase
  storage outage.
- **Flutter coverage is adapter-level.** Streaming checksum calculation,
  stable retry keys, and the no-redirect transport are asserted in
  `test/file_upload_repository_test.dart`; there is no widget-level test,
  because no production UI invokes the adapter by design.
- **Quota defaults are engineering estimates**, not capacity-planned values.

## Not evaluated

- Any remote or production environment. Nothing was deployed.
- Malware scanning, parser validation, EXIF handling, clean transitions,
  publication, deduplication, retention reconciliation, delivery — FILE-051.
- Independent security review of this slice.
- Production metrics, alerting, or central logging (OPS-090).
