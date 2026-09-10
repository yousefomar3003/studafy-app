# Phase 1A (ARC-010) — monorepo and delivery skeleton

Status: implementation complete and locally re-verified; the current change
set still requires a GitHub push/CI run before the external CI acceptance
evidence is current. Date: 2026-09-10. Decision-log: DL-016/017/018.
Architecture record: ADR-0011.

## What was delivered

- **Bun workspace** at the repository root (`apps/*`, `packages/*`) with exact
  dependency pins (hono 4.13.7, zod 4.6.1, postgres 3.4.9, ioredis 6.0.0,
  bullmq 6.3.4, typescript 7.0.2, @types/bun 1.4.2), frozen installs in CI.
- **`apps/api`**: Hono skeleton — request-id middleware (server-generated,
  inbound ids untrusted), `/healthz`, `/readyz` with reason codes, `/version`,
  empty `/v1` router (stable `NOT_IMPLEMENTED`), sanitized error handler,
  graceful SIGTERM/SIGINT shutdown, production fail-closed config.
- **`apps/worker`**: BullMQ skeleton — `smoke` queue + domain-free processor,
  environment-scoped key prefix, graceful drain/close shutdown.
- **Packages**: `contracts` (shared zod vocabulary + error codes), `config`
  (typed env, fail-closed, redaction), `observability` (JSON logger,
  startup/shutdown events, graceful-shutdown harness), `domain` (pure policy,
  zero imports), `database` (read-only postgres.js smoke), `infrastructure`
  (ioredis + BullMQ factories), `test-support` (fake clock/ids/log collector).
- **Containers/dev stack**: non-root Dockerfiles for both apps (pinned
  `oven/bun:1.3.14-slim` tag and manifest digest),
  `docker-compose.dev.yml` (Redis tag and manifest digest pinned;
  Postgres = Supabase stack, not duplicated), `.dockerignore`.
- **Boundary enforcement**: `scripts/check-bounds.ts` allowlist matrix
  (ADR-0011), wired into CI; negative-validated.
- **CI**: new `workspace` job (frozen install, boundaries, typecheck, tests
  with a Redis service, bundle builds, API+worker container health/shutdown
  smoke); `database` job gained the read-only `@studafy/database`
  connectivity test. All existing jobs untouched.
- **Workspace quality scripts**: Deno-backed deterministic formatting and
  TypeScript linting are first-class root scripts and blocking CI steps.

## Verification summary (full outputs in this directory)

| Check | Result |
|---|---|
| `flutter analyze` / `flutter test --concurrency=1` | No issues / 22-22 pass — **no Flutter behaviour change** (zero Flutter files touched; move to `apps/mobile` deferred, DL-017) |
| `deno fmt/lint/check --frozen/test --frozen` | green after one `deno.lock` regeneration mirroring the workspace manifests |
| pgTAP (containment + multi-school RLS) | 11 containment + 8 RLS assertions pass after clean eight-migration replay |
| Workspace frozen install | 53 installs, no changes |
| Boundary check | 9 members, 22 source files, 0 violations (+ negative validation) |
| Typecheck | 9/9 members |
| Workspace format/lint | 59 files format-clean; 36 TypeScript files linted; 0 findings |
| Workspace tests (live Redis + Postgres) | 51 pass, 0 fail |
| Bundle builds (api, worker) | exit 0 |
| Container smoke (full API + worker queue + SIGTERM) | Digest-pinned images built; API health/readiness 200; worker processed smoke job; both exited 0 after graceful shutdown |
| Production fail-closed | exit 1 with stable `ConfigError` (`fail-closed-2026-09-10.md`) |

## Acceptance criteria (instructions.md:1035) — met

- **Clean clone runs pinned installs, tests and containers**: CI `workspace`
  job proves install → tests → container build → health/shutdown on every
  push; local evidence recorded here.
- **No Flutter behaviour change**: Flutter jobs unchanged and green; the
  Flutter move is a separate future change after a dual-location CI rehearsal.
- **Deliverable "reproducible monorepo skeleton and architecture boundary
  checks"**: workspace + `check-bounds` in CI.

## Notes and follow-ups

- `bun test` is scoped to `apps packages` so Deno test files are never picked
  up by Bun.
- ADR-0001 remains provisional: only enqueue→process→drain and graceful
  shutdown are proven; reconnect, duplicated blocking connections, and Redis
  provider under load remain Phase 1/6 proofs.
- Phase 1B (ARC-011) was implemented locally. Push authorization and a green
  CI run for the combined closing change set are still required before Phase 1
  receives external CI evidence.
