# API-041 verification transcript and parity record

- Evidence date: 2026-09-15
- Target: local workspace and disposable local Supabase
- Data: generated synthetic identities and academic records only
- Remote deployment/change: none

## Delivered surface

- 40 authenticated academic `/v1` routes, each with one catalogue permission; 52
  total `/v1` routes including API-040/AUTH-030.
- Two forward-only migrations: academic invariants/attempt tables and the
  execute-only query/command surface.
- One shared generated Dart client plus typed API and synthetic preview ports.
- Seven fail-closed academic slice switches, including an assessment switch
  independent from assignments and grades. Uploads and attachments remain off.

## Executed verification

| Proof                                                                     |                                            Result |
| ------------------------------------------------------------------------- | ------------------------------------------------: |
| Clean `supabase db reset --local --no-seed`                               |                        all 30 migrations replayed |
| Current-schema pgTAP groups, in fixture-backed CI order                   |                        243 assertions, 0 failures |
| `supabase/tests/api041_academic_seed.sql`                                 |                   33 pgTAP assertions, 0 failures |
| Real Hono → AUTH-031 → API-040 → PostgreSQL academic integration          |            19 tests, 116 expectations, 0 failures |
| Focused contract/cursor/route/catalogue tests                             |            39 tests, 617 expectations, 0 failures |
| API-041 Flutter adapter/widget/preview/grade/architecture/drift selection |                              35 tests, 0 failures |
| Complete Bun app/package suite with PostgreSQL and Redis                  |         230 tests, 1,227 expectations, 0 failures |
| Complete Flutter suite                                                    |                             125 tests, 0 failures |
| Deno Edge suite                                                           |      4 tests, 0 failures; check/lint/format clean |
| `flutter analyze`                                                         |                                         no issues |
| `bun run typecheck`                                                       |                             all 9 workspaces pass |
| `bun run generate:check`                                                  |                     OpenAPI and Dart output clean |
| API-041 2,000-row-per-slice plan gate                                     | 7/7 cursor relations use a composite tenant index |

The pgTAP files are deliberately fixture-backed: seed runners include their
paired assertion files. CI therefore invokes the ten current-schema groups
explicitly after a clean reset instead of globbing seed and assertion files in
lexicographic order.

The integration suite covers active admin class/schedule creation and update;
teacher content version/publish/withdraw; assignment create/publish/withdraw,
student detail/submission/resubmission boundary and staff roster; online
assessment learner-safe questions, structured immutable attempt and staff
attempt roster; paper grade review/publish/correct/withdraw; attendance;
wellbeing; assistant read-only behavior; immediate membership revocation;
guardian/student timelines; cursor traversal; and cross-school concealment.

## Atomicity and idempotency proof

The pgTAP suite injects failing triggers on `audit_events` and
`notification_outbox`. In each case the domain mutation and idempotency
completion roll back. A successful command commits domain state, audit/history,
outbox (where required), and stored response together.

The real HTTP-style integration verifies response-loss replay, changed-payload
conflict, stale optimistic versions, and two concurrent identical publication
requests producing exactly one version increment, audit row, and outbox row. The
one-connection test observes actor/school/request settings inside a command
transaction and null settings immediately after commit.

`studafy_api_runtime` has zero public table grants, zero column grants, and zero
sequence grants. It can execute the narrow API-041 entry points; the mobile
`authenticated` role cannot execute the command function.

## Query-plan evidence

`DATABASE_URL=... bun run test:api041:plans` loads two interleaved schools with
2,000 rows per academic slice, runs `EXPLAIN (ANALYZE, BUFFERS, FORMAT JSON)`,
requires the named index, enforces a provisional 50 ms ceiling, and rolls the
fixture back.

| Relation           | Selected index                           | Execution ms |
| ------------------ | ---------------------------------------- | -----------: |
| classrooms         | `db020_classrooms_school_id_key`         |        0.039 |
| resources          | `db020_resources_school_id_key`          |        0.088 |
| assignments        | `db020_assignments_school_id_key`        |        0.033 |
| assessments        | `db020_assessments_school_id_key`        |        0.035 |
| grade_results      | `db020_grade_results_school_id_key`      |        0.039 |
| attendance_records | `db020_attendance_records_school_id_key` |        0.029 |
| wellbeing_events   | `db020_wellbeing_events_school_id_key`   |        0.031 |

The migration intentionally reuses DB-020's validated `(school_id, id)` unique
indexes. A first draft created duplicate indexes; executable plans showed the
existing indexes were equivalent, so the duplicates were removed.

## Edge parity matrix and cutover

| Former behavior        | `/v1` replacement                     | Parity evidence                                                                                                                        | Cutover statement                                        |
| ---------------------- | ------------------------------------- | -------------------------------------------------------------------------------------------------------------------------------------- | -------------------------------------------------------- |
| `approve-paper-grade`  | `POST /v1/grade-results/{id}/review`  | Frozen fixture, complete question coverage, score bounds/sum, linked ready draft, override reason, immutable event, optimistic version | Flutter invocation and source removed after tests passed |
| `publish-grade-result` | `POST /v1/grade-results/{id}/publish` | Reviewed-only transition, version lock, immutable event, audit, atomic minimal outbox, no direct notification                          | Flutter invocation and source removed after tests passed |

Both functions were source-only and not deployed in the inspected synthetic
project. No remote undeployment or production-traffic claim is made. The
contained `propose-paper-grade` source remains disabled until AI-072.

## Generated artifacts and direct-call scan

| Artifact                                        | SHA-256                                                            |
| ----------------------------------------------- | ------------------------------------------------------------------ |
| `202609150001_api041_academic_schema.sql`       | `6aade542c542eb45c69e6e18a78a4a91236f4a9d3f98ebf0aee11d40ec8cfb61` |
| `202609150002_api041_authoritative_surface.sql` | `b4753b6fa5e8fea61ef78354bdec3a43e06f83c80dd777fc456476136dd9a1c4` |
| `packages/contracts/openapi/v1.json`            | `222b0e4fdc557dd810e51df10e6cc11f51702275b454581019fec3612fa54b14` |
| `lib/data/contracts/v1_client.generated.dart`   | `6d9d5af28983a219de2d7d554390b13f8f687cb203de2232ad4df3462a937091` |

The architecture scan reports zero `StudafyDatabase`, direct PostgREST `.from`,
Supabase `.rpc`, or Edge `.functions.invoke` references in the remote academic
composition/adapters/screens. It also requires the removed grade Edge sources
and `ClassroomSummary.toLegacyMap` bridge to remain absent. SQLite opens only
`studafy_preview.db` and throws when the runtime is remote.

## Gate assessment

API-041's local engineering acceptance is met: no listed remote core mutation is
local-only, authoritative results converge in the real multi-actor test,
negative authorization passes, and Edge removal was parity-gated. Production
traffic is not enabled by this result. API-042, SAFE-043, OPS-061/090,
independent security review, hosted infrastructure, and production/device E2E
remain outside this part and keep the overall Phase 4/launch gate open.
