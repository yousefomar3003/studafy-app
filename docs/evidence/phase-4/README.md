# Phase 4 / API-040 local evidence

- Evidence date: 2026-09-14
- Target: local workspace and disposable Supabase only
- Data: deterministic synthetic fixtures only
- Remote changes or deployment: none

## Delivered platform surface

The existing Hono bootstrap is extended, not replaced. Every route inherits
server request IDs, hardened/no-store headers, exact-origin CORS, method/header
checks, actual streamed-body measurement, strict UTF-8/JSON limits, a total
deadline and one allowlisted completion event. Every mounted `/v1` route is in
the shared route catalogue with a strict Zod request schema where applicable,
an AUTH-031 permission and an explicit idempotency mode.

OpenAPI 3.1 is generated from the Zod 4.6.1 schemas and catalogue. The Dart
client is generated from OpenAPI; its transport understands top-level problem
details and preserves one idempotency key across its internal auth refresh.
The published contract intentionally contains no `/v1/classrooms` operation.

Migration `202609140002_api040_platform_controls.sql` adds only generation and
lease state to the existing durable record plus three narrow private functions.
`studafy_api_runtime` still has zero table and column grants, cannot use the
public schema, does not inherit and cannot bypass RLS. DB-021 policies and
client grants are unchanged.

## Negative and contract matrix

| Risk | Executable evidence |
|---|---|
| Malformed input | Invalid UTF-8/JSON, non-finite numbers, wrong media type, compressed body, depth/key excess and unexpected fields are denied |
| Resource exhaustion | The middleware counts streamed bytes despite a false `Content-Length`; Bun has the same 64 KiB outer ceiling; total request timeout returns sanitized 504 and aborts downstream work |
| Header/origin injection | Ambiguous singleton values are denied, inbound request IDs are ignored, unapproved origins are not reflected and exact origins pass |
| Information leakage | SQL/stack/token/signed-URL exception content is absent from response/logs; recursive snake_case/camelCase sensitive fields are redacted |
| Replay | Sequential and concurrent requests execute once; exact response replay, mismatch, live reservation, retry-after, failure recovery, uncertain completion and recent-auth ordering are tested |
| Database durability | Real concurrent PostgreSQL reservations yield one winner; actor/tenant isolation, expiry takeover and stale-generation denial pass |
| SSRF | Loopback/RFC1918/link-local/metadata/reserved/IPv6, literal and encoded hosts, hostile DNS, cross-origin/metadata redirect, rebinding between hops, redirect count, byte overflow and timeout are denied |
| Contract drift | Mounted routes equal the catalogue; OpenAPI records permissions/idempotency/problem/security headers; request schemas disallow additional properties; Dart/OpenAPI/DB type drift checks pass |

## Recorded verification

| Command/suite | Result |
|---|---:|
| Clean `supabase db reset --local --no-seed` | all 28 migrations replayed, including API-040 |
| Full pgTAP regression sequence | 9 files, 210 assertions, 0 failures |
| `supabase/tests/api040_idempotency_seed.sql` | 25 assertions, 0 failures |
| Real DB/API integration selection | 18 tests, 55 expectations, 0 failures; API-040 idempotency subset 4/4 |
| API-040 platform unit tests | 30 tests, 137 expectations, 0 failures |
| Workspace unit tests without optional DB/Redis services | 173 passed, 27 skipped, 0 failed |
| `bun run typecheck` | all 9 workspaces pass |
| `bun run lint` | 79 files checked, 0 findings |
| `bun run check:bounds` | 9 members, 43 source files, 0 violations |
| API and worker builds | pass |
| Targeted Flutter transport + contract tests | 7 passed, 0 failed |
| Full `flutter test` | 106 passed, 0 failed |
| `flutter analyze` | no issues |
| Dart boundary checker | 47 feature files, 0 legacy exemptions, 0 violations |
| `bunx supabase db lint --local --level error --fail-on error` | no schema errors |
| `bun run generate:db-types:check` | pass |

| Artifact | SHA-256 |
|---|---|
| `202609140002_api040_platform_controls.sql` | `13f2c874d1ae0779d56c4df639623cf4050c544c130c4178e79ef193bed1430d` |
| `packages/contracts/openapi/v1.json` | `12f3c8e445bd50e6ee2ae0d989ad866d4147b518a7ed6eb89f2486f85cacbb44` |
| `lib/data/contracts/v1_client.generated.dart` | `77a5f0e9683ff40b57a9af505fae5cad53afcb4ebfdf3ad18f2a493ac9449ccc` |

`bun run generate:check` and `bun run generate:db-types:check` are the
release-blocking drift proofs.

## Defect found by executable proof

The first PostgreSQL repository implementation passed `JSON.stringify(body)`
through a typed `jsonb` parameter. postgres.js encoded that string again, so a
replay returned a JSON string rather than the original object. The real
integration assertion failed, the call now uses postgres.js's JSON value helper,
and structured status/body replay passes.

## API-040 and Phase 4 gate assessment

| Item | Assessment | Evidence or blocker |
|---|---|---|
| API-040 uniform controls | **Met locally for every mounted route** | Route catalogue equals the Hono table; negative suite passes |
| Strict contracts and generated clients | **Met locally** | Closed Zod schemas, generated OpenAPI/Dart, drift checks |
| Durable idempotency | **Met for the shipped commands** | PostgreSQL reservation/complete/fail functions, concurrency and lease tests; no broad grant |
| SSRF/provider boundary | **Met in application code; infrastructure control open** | Redirect/DNS/IP/byte/time tests pass; isolated production egress is not provisioned |
| Cursor tamper control | **Not applicable to the current mounted surface; deferred** | No paginated route exists; API-041 is blocked from adding one until signed cursor tests land |
| Production telemetry | **Partially met** | One safe per-route completion event supplies RED inputs; metrics backend, traces, retention and alerting are OPS-090 |
| Launch API contracts/adapters | **Not met** | API-041 and API-042 are not implemented; current academic/school journeys are not authoritative |
| Communications safety | **Not met** | SAFE-043 remains mandatory before communications launch |
| Transactions/outbox for all workflows | **Not met** | Idempotency is proven here; slice transactions/outbox/provider reconciliation remain API-041/042 |
| Deno traffic replacement | **Not met** | Prototype functions remain until endpoint parity and explicit cutover |

**API-040's selected local acceptance criteria pass. The overall Phase 4 gate
is open.** API-041, API-042, SAFE-043, authoritative Flutter journey adapters,
transactional outbox proofs, Deno parity/cutover, production RED telemetry and
isolated egress remain required. No result here authorizes remote deployment or
real student data.
