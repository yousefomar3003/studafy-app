# ADR-0011: Monorepo workspaces and pinned toolchain

Status: Accepted. Decision-log: DL-016, DL-017, DL-018. Date: 2026-09-10.
Implements ARC-010 (Phase 1A) choices.

## Context

ARC-010 requires a Bun workspace with `apps/{api,worker}` and shared
`packages/*`, pinned dependencies, and architecture boundary checks, while
the repository root remains a Flutter project and the Deno Edge Functions
keep their own toolchain (`deno.json` scoped to `supabase/functions`).

## Decision

1. **Workspace**: root `package.json` declares `"workspaces": ["apps/*",
   "packages/*"]` with Bun 1.3.14 (`packageManager`). The supabase CLI stays a
   root devDependency for CI/local use. Flutter remains at the repository
   root; the mechanical move to `apps/mobile` is **deferred to its own
   reviewed change** after CI proves Flutter commands run from both locations
   (instructions.md:287; DL-017).
2. **Pinned runtime libraries** (exact versions, no ranges, lockfile frozen in
   CI): `hono` 4.13.7, `zod` 4.6.1, `postgres` (postgres.js) 3.4.9,
   `ioredis` 6.0.0, `bullmq` 6.3.4; dev tooling `typescript` 7.0.2,
   `@types/bun` 1.4.2. Local Redis is Docker `redis` (pinned tag in
   `docker-compose.dev.yml` and CI, DL-018). Local Postgres for the API is the
   disposable Supabase stack database (127.0.0.1:54322), not a second
   container.
3. **Observability**: a minimal built-in structured JSON logger in
   `@studafy/observability` (no logging dependency). Fields are chosen to be
   OpenTelemetry-compatible (timestamp, level, service, version, event,
   request_id); Phase 6 may extend or replace the sink, not the field
   contract.
4. **Boundary rules** enforced by `scripts/check-bounds.ts` in CI (src code
   only; tests may use `bun:test`):

   | Member | May import |
   |---|---|
   | `@studafy/domain` | nothing external |
   | `@studafy/contracts` | `zod` |
   | `@studafy/config` | `zod` |
   | `@studafy/observability` | nothing external |
   | `@studafy/database` | `postgres`, `@studafy/config`, `@studafy/observability` |
   | `@studafy/infrastructure` | `ioredis`, `bullmq`, `@studafy/config`, `@studafy/observability` |
   | `@studafy/test-support` | nothing external |
   | `@studafy/api` | `hono` + any `@studafy/*` package |
   | `@studafy/worker` | `bullmq` + `@studafy/*` packages |

   `node:*` builtins are always allowed; relative imports stay inside the
   member. No workspace member imports Supabase/Deno/Flutter code — the Deno
   Edge Functions and the Flutter app remain separate delivery units until
   migrated route-by-route (ADR-0001, ADR-0010).
5. **TypeScript**: shared `tsconfig.base.json` (strict, `noEmit`, bundler
   resolution, `types: ["bun"]`); every member has a `typecheck` script
   aggregated by the root `bun run --filter='@studafy/*' typecheck`.

## Consequences

- `deno.lock` now mirrors the workspace manifests (regenerated 2026-09-10);
   Deno commands stay scoped to `supabase/functions` and remain frozen-clean.
- Root `bun test` is explicitly scoped to `apps packages` so it never picks
  up Deno test files under `supabase/`.
- Adding the workspace changed no Flutter file; Phase 1A evidence records
  unchanged `flutter analyze`/`test`/build results.
- BullMQ/Redis semantics beyond enqueue→process→drain and graceful shutdown
  remain unproven under load; ADR-0001 stays provisional until the Phase 1/6
  queue proofs (reconnect, duplicated blocking connections, provider under
  load) pass.
