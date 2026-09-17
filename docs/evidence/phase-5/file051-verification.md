# FILE-051 verification transcript

- Evidence date: 2026-09-17
- Target: local workspace and disposable local Supabase only
- Data: deterministic synthetic fixtures only
- Remote changes or deployment: none
- Migration: `202609170004_file051_scan_delivery_publication.sql` (forward-only,
  sha256 `3827ab17ac15fdf5e1b957a56ce046ef3d66ed085e44b9e40137e1889e2c9699`)

Everything below was **executed** in this environment. Where a Part 5B
requirement is not covered by an executed check, it is listed under
[Gaps](#gaps-against-the-plan) rather than implied to have passed.

## Gate assessment

§20 Phase 5 gate: *arbitrary path signing eliminated, all bytes
quarantined/scanned, publication derives access without copies, signed
delivery reauthorizes, quotas/retention/reconciliation and malicious-file
response verified.*

| Gate item | Result |
|---|---|
| Arbitrary path signing eliminated | **Pass.** FILE-050 checks, plus a CI rule that fails on any `createSignedUrl(s)` call. |
| All bytes quarantined and scanned | **Pass.** `clean` has one writer and requires a scan policy and a verified stored digest; outages dead-letter to `error`. |
| Publication derives access without copies | **Pass.** Thirty recipients, one object; publication creates no file row. |
| Signed delivery re-authorizes | **Pass.** Single use, recipient-bound; withdrawal, enrollment end and containment each deny a link that was already issued. |
| Quotas | **Pass.** FILE-050 suites are unchanged and passing. |
| Retention | **Pass (mechanism).** Grouping and hold/reference blocking are proven. No durations are configured (§29). |
| Reconciliation | **Pass.** Zero drift after the end-to-end run and after the drills; a planted orphan is detected. |
| Malicious-file response | **Pass.** The drill reports `passed: true`. |

Part 5B **"conditions before proceeding"**:

| Condition | Result |
|---|---|
| File penetration tests | **Not done.** No independent tester is engaged; this is internal negative testing only. |
| Malware response exercise | **Pass** (local drill). |
| Cleanup reconciliation pass | **Pass** |

The engineering part of FILE-051 is complete as local evidence. It does
**not** authorize deployment, remote use or real school data, and it does
**not** flip `allowsRemoteFileUploads`. The flip remains a separate reviewed
change. It is blocked on:

- an independent file penetration test;
- a real scanner vendor and key (A6);
- retention periods (§29);
- OPS-061/090;
- production end-to-end testing.

## Executed verification

| Suite | Command | Result |
|---|---|---|
| TypeScript | `bun run typecheck` | 9/9 workspaces clean |
| Bun tests | `bun test apps packages` | 368 pass, 1 skip (Redis worker smoke without `REDIS_URL`), 0 fail |
| FILE-051 pgTAP | `bunx supabase test db --local supabase/tests/file051_scan_delivery_seed.sql` | 99/99 pass |
| Full CI database job | every step of the `database` job replayed from the pre-DB-020 boundary, in CI order | all steps pass (exit 0) |
| Query plans | `bun run test:file051:plans` | 6 queries, all index-backed, all under 2.2 ms |
| End-to-end | `bun run test:file051:e2e` | 30/30 checks |
| Malware drill | `bun run test:file051:drill` | 15/15 checks, `passed: true` |
| Reconciliation | `bun run test:file051:reconcile` | `drift: false`, all five counts 0 |
| Boundaries | `bun run check:bounds` | 0 violations; FILE-050/051 guard passes |
| OpenAPI/Dart drift | `bun run generate:check` | clean |
| DB type drift | `bun run generate:db-types:check` | `result: pass` |
| Database lint | `bunx supabase db lint --local --level error --fail-on error` | no errors (in CI replay) |
| Lint | `bun run lint` | 161 files clean |
| Format | `bun run format:check` | 184 files clean |
| Build | `bun run build` | api and worker bundled |
| Flutter analyze | `flutter analyze` | no issues |
| Flutter tests | `flutter test` | 127 pass |
| Dart format | `dart format --set-exit-if-changed lib test tools` | 148 files, 0 changed |
| Dart boundaries | `dart run tools/check_dart_bounds.dart` | 58 feature files, 0 violations |
| Edge Functions | `deno check`, `deno test`, `deno lint`, `deno fmt --check` | all clean (4 tests) |
| Secret scan | `gitleaks detect` (history) and `--no-git` over `apps packages scripts supabase/migrations supabase/tests docs` | no leaks. Full working-tree findings are confined to gitignored `.dart_tool/`, `build/`, `supabase/.temp/` and `config/dart-defines.*.json`. |
| AUTH-030 lifecycle | `bun run test:auth030:lifecycle` | 26/26 (in CI replay) |
| SAFE-043 drill | `bun scripts/moderation-drill.ts` | `passed: true` (in CI replay) |

### CI database replay (pgTAP counts)

| Suite | Tests |
|---|---|
| db020_upgrade | 18 |
| db021_upgrade + db021_grants | 33 |
| containment | 11 |
| rls_access_seed | 8 |
| db020_constraints | 31 |
| db021_access_seed | 38 |
| auth030_access | 36 |
| auth031_authorization_seed | 20 |
| db021_grants | 25 |
| auth030_grants | 16 (inventory updated for the three `api051_*` API functions) |
| api040_idempotency_seed | 25 |
| api041_academic_seed | 33 |
| file050_upload_seed | 36 (unchanged; still passes against the extended cleanup functions) |
| **file051_scan_delivery_seed** | **99** |
| safe043_safety_schema | 25 |
| safe043_surface_seed | 69 |

The integration suites passed in the same replay: database smoke 1,
AUTH-030 repository 100, AUTH-031 parity 3, API-040 idempotency 4, API-041
academic 19, FILE-050 storage 1, FILE-050 quota races 4, and SAFE-043 `/v1`
12.

### Part 5B "tests required" mapping

| Required test | Where | Result |
|---|---|---|
| EICAR-equivalent safe test | domain `verdict`/`containsBytes`; infrastructure scanner; worker processor; pgTAP §6; end-to-end; drill A1–A4 | Pass. The EICAR string is rejected in any format and inside metadata, never delivered, never published, and its bytes are deleted. |
| Polyglot / type mismatch | domain JPEG/PNG/WebP/PDF trailing-byte and size-accounting cases; `verdict` mismatch cases; worker "detected type only" | Pass |
| Archive / decompression bomb | domain PDF inflate caps (per-stream and total) | Pass. No archive type is admitted by FILE-050, so a PDF stream is the only compressed container. |
| Scanner outage | infrastructure: 500, malformed body, redirect, timeout, bad credential, unreachable; worker: outage and storage down; pgTAP: ten retries dead-letter to `error` | Pass. Never `clean`. |
| Malformed image / PDF | domain truncation, CRC, chunk-size (including top-bit sizes), missing EOF, appended document | Pass |
| Revocation / download expiry | route tests (expired, tampered, rebound, forged, unrecorded, replayed, revoked); pgTAP (expiry, enrollment end, withdrawal, containment); end-to-end (withdrawal after issue); drill B3 | Pass |
| 30-recipient one-object assertion | pgTAP §3: thirty enrolled students derive access, and exactly one object holds the content | Pass |

### pgTAP coverage (99 assertions)

1. **Privilege surface (9).**
   - No runtime table grant on delivery grants, and clients cannot read
     them.
   - The API/worker function split is exact.
   - The worker has `private` usage and nothing more.
   - Clients cannot call the commands.
   - Containment is operator-only.
2. **Scan state machine (11).**
   - Claims hand over the immutable key and move the object to `scanning`.
   - A foreign worker's transform record is refused.
   - `clean` is refused without a policy version or a stored digest; a
     rejection is refused without a reason.
   - A clean verdict records its evidence, invents no retention horizon, is
     audited, and cannot be finished twice.
3. **Publication (15).**
   - Students and other schools are refused.
   - Quarantined files cannot be published.
   - Publication creates exactly one resource, version, publication and
     binding, and no object; a second publication is refused.
   - Thirty students derive access, and there is one physical object.
   - Another school has no access.
   - The AUTH-031 evaluator matches for `file.download` and `file.publish`.
4. **Delivery grants (19).**
   - Over-long expiry and unreachable files are refused.
   - A grant stores only the nonce hash and commits together with its
     idempotency completion.
   - A second account, another file, and a second use are each refused.
   - Consumption returns the exact key and stored digest, and is audited
     once.
   - Expiry, the expiry sweep, enrollment end and withdrawal each deny.
5. **Deduplication (14).**
   - A same-school duplicate points at its root and queues deletion of its
     own key.
   - The other school's identical file is never linked and leaves no
     signal.
   - A different transform result is never merged.
   - A dependent publishes normally and is served from the root.
   - Dedupe deletion leaves the row `clean` with its physical deletion
     recorded.
6. **Rejection, hold, dead letter (9).**
   - The EICAR object is rejected with its reason and queued for deletion.
   - It can never be published or delivered, even to its owner.
   - A held rejection keeps its bytes.
   - Ten outages dead-letter to `error`.
7. **Retention (8).**
   - A lone root is claimable.
   - A live reference or a legal hold on any member blocks the whole unit.
   - A claim covers exactly the root and its dependent.
   - Nothing is marked deleted before confirmation; afterwards both rows
     are deleted together.
8. **Containment (12).**
   - Containment withdraws the publication and expires the grant, and the
     object is error, contained and held.
   - The outstanding link dies, and no new link can be issued.
   - Held evidence is skipped by the deleter.
   - Release queues deletion, and the object ends deleted.
   - Both steps are attributed to the operator.
9. **Observability (2).** The backlog report exposes the runbook signals,
   and dead letters are visible.

### End-to-end transcript (real Storage, least-privilege roles)

`scripts/verify-file051-delivery.ts` connects the API as
`studafy_api_runtime` and the workers as `studafy_worker_runtime`, each with
a throwaway password that is revoked on exit. The worker role is returned to
`nologin`. Only token verification is replaced: the actor's session context
is loaded from the database exactly as the auth middleware does.

```
PASS  a completed upload is quarantined
PASS  a quarantined file cannot be published
PASS  the scan worker marks a structurally valid image clean
PASS  the stored object no longer carries EXIF/GPS metadata
PASS  the row keeps the upload digest and records a different stored digest
PASS  an entitled student cannot download before publication
PASS  the assigned teacher publishes the clean file
PASS  publication stored no second object
PASS  an unenrolled student of the same school is refused a link
PASS  another school's teacher is refused a link
PASS  the enrolled student receives a delivery link
PASS  the link is useless to another account
PASS  the recipient downloads once
PASS  the delivered bytes are exactly the sanitized stored bytes
PASS  delivery is an attachment with nosniff and a sandbox policy
PASS  the same link never works twice
PASS  a link issued before withdrawal is denied at use
PASS  and no new link can be issued after withdrawal
PASS  the EICAR test file is rejected with a stable reason
PASS  a rejected file cannot be delivered, even to its owner
PASS  a rejected file cannot be published
PASS  the rejected object is physically deleted by exact key
PASS  the duplicate points at the same-school root
PASS  the duplicate's redundant bytes are physically removed
PASS  the root's bytes are untouched
PASS  the deduplicated file is delivered from the root's bytes
PASS  identical bytes in another school are never deduplicated
PASS  the other school's status response carries no dedupe signal
PASS  storage and rows reconcile with zero drift
PASS  reconciliation detects bytes with no session

30/30 checks passed
```

### Malicious-file response drill

```
PASS  A1 detection: the EICAR test file is rejected
PASS  A2 exposure: no link and no publication are possible
PASS  A3 signal: a file_scan_rejected audit event exists for triage
PASS  A4 eradication: the rejected bytes are deleted by exact key
PASS  B1 precondition: a student downloaded the file
PASS  B2 containment withdraws the publication and expires the outstanding link
PASS  B3 the outstanding link is dead immediately
PASS  B4 no new link can be issued to anyone, including the owner
PASS  B5 scoping: the audit trail names exactly the recipient who downloaded
PASS  B6 evidence: held bytes survive the cleanup worker
PASS  B7 release queues exact-key deletion
PASS  B8 eradication: bytes gone and the row settled only after storage confirmed
PASS  B9 storage reconciles with zero drift
PASS  B10 the audit trail tells the whole story in order
PASS  B11 containment and release are attributed to the operator
15/15 checks passed
{"event":"file051_malware_drill","target":"local_disposable","passed":true,"timings":{"contain_ms":4}}
```

### Query plans

The fixture has 2,000 target-school objects and 18,000 background objects,
1% quarantined, with one grant per clean object. It runs inside a
transaction that always rolls back.

| Query | Index | ms | Nodes |
|---|---|---|---|
| grant_consume | `file_delivery_grants_nonce_hash_key` | 0.023 | Index Scan |
| grant_expiry_sweep | `file051_delivery_grant_expiry_idx` | 0.009 | Limit / Index Only Scan |
| scan_claim | `file050_file_job_claim_idx` | 2.139 | Limit / Sort / Index Only Scan |
| dedupe_root_lookup | `file051_file_dedup_root_idx` | 0.023 | Limit / Index Only Scan |
| dedupe_dependents | `file051_file_dedup_source_idx` | 0.008 | Index Scan |
| retention_candidates | `file051_file_retention_idx` | 0.015 | Limit / Index Scan |

The first fixture draft made 20% of all jobs pending scans, and the planner
correctly chose a sequential scan for that. The fixture was corrected to a
realistic backlog; no index was changed to force the plan.

### Unit and route coverage added

| File | Tests | Covers |
|---|---|---|
| `packages/domain/test/files.test.ts` | 28 | format walkers and strippers; verdict composition; mismatch and unknown types; idempotent transform; unsigned WebP sizes; tokens (round trip, tamper, wrong key, malformed base64, oversize, nonce hashing, TTL bounds) |
| `packages/infrastructure/test/fileScanner.test.ts` | 11 | local scanner; provider clean/malicious; outage classes; structural rejection skips the provider |
| `apps/worker/test/fileScan.test.ts` | 11 | write-ahead, rewrite and read-back order; retry recognises its own write; digest and read-back mismatches; lost claim; malware; detected type only; outages |
| `apps/api/test/files/file051.routes.test.ts` | 15 | publish off by default and strict body; delivery off keeps the FILE-050 answer; the grant stores only the nonce hash; single use; foreign account; expired, tampered, rebound, malformed and forged links refused before the database; revocation after issue; stored-digest mismatch refused; headers; `Content-Disposition` safety |

### Generated artifact hashes

| File | sha256 |
|---|---|
| `packages/contracts/openapi/v1.json` | `506fe22b9574e87750ed39b63e797f72cadf8d6820a30ac59712bb09fb9dfa34` |
| `lib/data/contracts/v1_client.generated.dart` | `626129b9502ab27feb847fbfb7f4ed2a6ea747fb6333077639574fef4b55a9b6` |
| `packages/database/src/database.types.generated.ts` | `68045534beeb7d23177fc5f76d4e1552eb4b801c993cc12c1cb5af6b09f30a8b` |

## Defects found and fixed while verifying

This part was resumed from an uncommitted draft left by an interrupted
session. The draft had never been executed. Running it found the following
defects, all fixed before the checks above.

| # | Defect | Consequence if shipped | Fix |
|---|---|---|---|
| 1 | Scan read-back fell back to hashing the *original* bytes when storage returned no digest | the overwrite was never actually verified | a missing digest is a mismatch; retry |
| 2 | Five functions declared a row variable `f` and aliased the table `f` | every scan finish, grant, consume and publish call failed at runtime with `42702` | aliases renamed |
| 3 | `coalesce(…, '')` meant scan policy and error code were never null | `clean` accepted with an empty policy version; rejections without a reason accepted | `nullif` plus explicit guards |
| 4 | Retention grouped by `(school, sha256)` across different roots | only one root's bytes deleted while every row was marked deleted, stranding bytes | the unit is a root plus its dependents; dependents must have shed their bytes first |
| 5 | The dedupe check constraint required dependents to stay `clean` | every retention deletion of a deduplicated group would fail | dependents may move to `error` or `deleted` only |
| 6 | Grant and publish commands checked scan state before authorization | an existence and state oracle for unauthorized callers | authorize first |
| 7 | WebP chunk sizes were read as signed integers | a crafted size could walk the parser backwards (bounded by the chunk cap) | unsigned read, plus a test |
| 8 | A lost finish after an overwrite left the bytes matching no recorded digest | a clean file would dead-letter to `error` | transform digest recorded write-ahead; retries recognise it |
| 9 | Malformed base64 in a token signature threw | an unhandled `500` on a crafted link | the verifier returns `null` for every malformed input |
| 10 | The platform header middleware overwrote every CSP | the delivery `sandbox` directive was silently dropped | a handler-set `sandbox` policy survives |
| 11 | `studafy_worker_runtime` had no `USAGE` on `private` (inherited from FILE-050) | no file worker, including FILE-050 cleanup, could run least-privileged | granted, and asserted in pgTAP |
| 12 | Infrastructure retries were logged as `file_scan_rejected` | misleading incident signal | separate `file_scan_retry` event |

Other adjustments:

- `@studafy/infrastructure` now declares its `@studafy/domain` dependency
  (lockfile updated).
- The unneeded worker→domain bounds allowance was removed.
- The contract test's error-code list and the AUTH-030 grant inventory were
  deliberately updated for the new codes and functions.
- Synthetic signing constants in tests were reshaped so the secret scanner
  stays quiet without an allowlist.

## Gaps against the plan

- **No real malware engine.** The provider adapter is exercised against a
  local fake only. Its request and response shape is provisional until a
  vendor is chosen (inputs.md Group 3, A6). Locally, *clean* means
  structurally valid and metadata-stripped.
- **Image transformation is metadata removal, not pixel re-encoding.** A
  payload in the entropy-coded image data is not neutralised. PDF content
  disarm and reconstruction (CDR) is not implemented (§11 control 7 allows
  deferral pending fidelity and accessibility evaluation).
- **Scanner sandboxing is architectural, not deployed.** The analyser is
  pure, and the provider client has one origin and refuses redirects, but
  no container, egress policy or CPU/memory limit exists until INFRA-080.
- **Retention schedules are not set.** The mechanism is proven with
  synthetic horizons only.
- **Only `lesson_resource` can be published.** Assignment material,
  submissions, paper scans and coach attachments are deliverable through
  owner, own-submission and assigned-staff relationships, but no
  assignment- or submission-binding command exists yet. AI grading remains
  disabled (§11 immediate containment; the legal gate in §20).
- **No client UI.** The Dart client gained `publishFile`, but no screen
  calls it, and `allowsRemoteFileUploads` stays `false`.
- **Quarantine-age alerting** exists only as a structured log line. OPS-090
  owns the alerts.
- **No independent file penetration test** has been performed.

## Not evaluated

- Behaviour under a real storage outage while streaming (proven against a
  fake).
- Large-file memory behaviour near the 25 MiB ceiling: delivery and scanning
  buffer the whole object.
- Production networking, TLS and CDN caching (the responses are
  `no-store`).
