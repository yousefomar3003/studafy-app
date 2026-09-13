# Phase 2B / DB-021 local evidence

- Evidence date: 2026-09-11
- Target: disposable local Supabase only (`127.0.0.1:54322`)
- Data: deterministic synthetic fixtures only
- Remote projects modified: none

## Implemented controls

Six forward migrations add private lifecycle-aware authorization helpers,
hardened consent and notification RPCs, complete read policies, explicit
column/service grants, relationship immutability, and query-backed indexes.
Earlier migrations remain unchanged. Flutter notification acknowledgement now
uses the bounded RPC without caller-controlled ownership fields.

| Migration | SHA-256 |
|---|---|
| `202609110007_db021_private_helpers.sql` | `ebbbd49103086e64a8c93c402a1f325781b5410cce5ab534e414b0d55b08ef9e` |
| `202609110008_db021_rpcs.sql` | `933dd26ebc52c3442cd353c484f735106eea65537973c033105a78c2d071afd6` |
| `202609110009_db021_policies.sql` | `52645b4390748fb37114957293cf86b06ead1508e8f67fb62db41109bdd8416d` |
| `202609110010_db021_grants.sql` | `1ccb9681b3a5176c03ad88ea96c0a749e60fc376d0b15e11c1f8ccdee25f6212` |
| `202609110011_db021_immutable_columns.sql` | `be058591cd4f407597035758b9e5bc60a9337b0399876e67512cfd3d20e471b4` |
| `202609110012_db021_policy_indexes.sql` | `c993b71ddd048a6116f2e115ce214aab0299bf760a0516d2db31998e15a50cbe` |

The executable grant snapshot proves anonymous access is zero, authenticated
access is column-read-only plus two RPCs, service-role access matches the
contained Edge Function inventory, future migration-owned objects are closed,
and public policy/trigger helpers are absent. The policy matrix proves exact
class/student relationships, lifecycle denial, co-teaching, tenant isolation,
guardian expiry, publication state, wellbeing visibility, clean-file
publication, RPC authentication/idempotency, and immutable submission identity.

## Upgrade and recovery

The local database is reset through `202609110006`, loaded with a synthetic
DB-020 fixture, upgraded through all six DB-021 migrations, and checked for row
and identifier preservation. Failed migrations rely on transaction rollback.
Post-application defects require a corrective forward migration; broad grants
or unsafe direct submission writes are not rollback options.

## Performance evidence

`bun run test:db021:plans` creates a three-school fixture inside a transaction,
measures RLS queries as student, guardian, teacher, cross-tenant teacher, and
school administrator, then forces rollback. It rejects a sequential scan on
the populated target relation, a median at or above 50 ms, or a worst run at or
above 150 ms. Machine-local results are regression evidence, not production
capacity claims.

| RLS query | Median ms | Worst ms |
|---|---:|---:|
| Student exact enrollment | 1.278 | 2.521 |
| Student classroom lookup | 1.196 | 1.261 |
| Student published grades | 3.896 | 4.053 |
| Guardian linked student | 0.533 | 0.830 |
| Teacher assessment grades | 10.279 | 10.394 |
| Cross-tenant teacher denial | 0.702 | 0.746 |
| Administrator classroom cursor | 6.090 | 6.124 |
| Student unread notifications | 0.265 | 0.274 |

The clean-reset database run passed 113 assertions: 11 SEC-001 containment,
8 legacy RLS compatibility, 31 DB-020 integrity, 38 DB-021 role/RPC tests, and
25 grant/function/default-ACL assertions. Schema lint reported no errors.

## Open gates

Local implementation does not close DB-021 or Phase 2. A named independent
security owner must approve the policy matrix, grants inventory, function
hardening, and tenant-isolation evidence. Phase 0 human review, staging-sized
migration rehearsal, production backup/PITR approval, and explicit remote
deployment authorization remain open. No upload, AI grading, payment, queue,
Hono route, Phase 3 feature, or remote environment was enabled.

## Independent re-verification (2026-09-11)

The committed evidence above was re-checked against a clean local database
rather than accepted from the implementation run. All six migration SHA-256
values match the table above byte-for-byte.

| Gate | Command | Result |
|---|---|---|
| Clean replay from zero | `supabase db reset --local --no-seed` | 21 migrations applied |
| Phase 2A + 2B pgTAP | `supabase test db --local` (5 files) | 113 assertions pass |
| Upgrade rehearsal | reset to `202609110006`, seed, `migration up` | 33 assertions pass |
| Schema lint | `supabase db lint --local` | no errors (`extensions`, `private`, `public`) |
| RLS plans and latency | `bun run test:db021:plans` | 8 queries, median 11.18 ms worst, all under bounds |
| Generated type drift | `bun run generate:db-types:check` | pass |
| Flutter | `flutter test`, `flutter analyze` | 57 tests pass, no issues |
| Bun typecheck / lint / format / bounds | `typecheck`, `lint`, `format:check`, `check:bounds` | pass, 0 boundary violations |
| Secret scan | `gitleaks detect` | no leaks |

Privilege surface queried directly from `pg_catalog` rather than through the
suite that ships with the migrations:

- `anon` holds zero `public` table privileges and cannot execute any function
  in `public` or `private`.
- `authenticated` holds no `INSERT`, `UPDATE`, `DELETE`, `TRUNCATE`,
  `REFERENCES`, or `TRIGGER` privilege on any `public` table, and no `CREATE`
  on `public`.
- `authenticated` may execute exactly two `public` functions:
  `mark_notifications_read()` and `record_policy_consent(text,text,text)`.
- `public` contains only those two functions; every authorization and trigger
  helper now lives in `private`, which `anon` cannot reach.
- No `preferred_answer`, `storage_path`, `file_hash`, `checksum`,
  `provider_response`, `audit_payload`, `raw_payload`, or `answer_key` column
  is granted to `authenticated`.
- `service_role` holds no `DELETE`, `TRUNCATE`, `REFERENCES`, or `TRIGGER`
  privilege.
- Every `SECURITY DEFINER` function in `public` and `private` pins
  `search_path`; row security is enabled on every `public` table.
- All 29 policied tables carry `SELECT`-only policies; no non-`SELECT` policy
  exists. 21 service-only and unactivated tables have row security enabled with
  no policy and therefore remain fail-closed.
- 106 relationship-immutability triggers and the 6 documented DB-021 policy
  indexes are installed.

Known unrelated failure: four `bun test` cases in the worker and Redis
connectivity suites fail with `ECONNREFUSED 127.0.0.1:6379` because no local
Redis is running. They are outside the DB-021 surface and were failing for the
same environmental reason before this phase.

Re-verification does not close any gate in "Open gates" above.
