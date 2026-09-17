# Phase 6, Part 6A (OPS-060) — Redis security, limits and selective caches

Date: 2026-09-17 · ADR-0024 · DL-045 · Runbook:
`docs/security/ops060-operator-runbook.md` · Catalogue:
`docs/security/rate-limit-catalogue.md`

## Scope executed

1. **Redis security posture** — production `REDIS_URL` must be `rediss://`
   with AUTH (boot-enforced for API and worker); local posture unchanged and
   documented.
2. **Rate limits** — a registry covering every §8 flow, Lua-atomic engine
   primitives (fixed window, exact sliding window, token bucket), one edge
   insertion (`createApp`, `/v1/*`, pre-auth, IP-scoped) and one
   authenticated insertion (`createAuthRoutes`, covering session routes plus
   every catalogue module), HMAC-digested keys (never a raw identifier),
   documented failure modes (fail closed → 503; bounded local fallback for
   ordinary traffic).
3. **Caches** — a catalogue of revocation-safe entries with the active
   session-context cache (version-keyed on an account generation bumped by
   every auth mutation; TTL = min(30s, revocation budget); Redis-down → DB
   loader), and seven declared entries awaiting their owning routes.
4. **Env/ops** — `RATE_LIMIT_ENABLED`, `RATE_LIMIT_HMAC_SIGNING_KEY`
   (required in production, ephemeral per boot in dev, registered in the
   credentials map), `docker-compose.dev.yml` posture note, `dev:stack`
   fallback for podman hosts.

## Environment

- Redis 7.4.4 (pinned digest from `docker-compose.dev.yml`) started and
  reachable at `127.0.0.1:6379`. The dev-stack script now falls back to
  `docker-compose` (this host runs podman; `podman machine start` +
  `DOCKER_HOST` were needed).
- The local Supabase database (127.0.0.1:54322) was **not** running: the
  DB-gated integration suites fail with `ECONNREFUSED` exactly as before
  this part — 29 failing tests, every one showing
  `ECONNREFUSED 127.0.0.1:54322`. Out of scope; unchanged by 6A.

## Verification transcript

| Suite | Result |
|---|---|
| `bun test packages/config` | 24 pass / 0 fail (8 new: production rediss+AUTH posture, worker posture, rate-limit keys, redaction) |
| `bun test packages/infrastructure` | 20 pass / 0 fail (18 new: fixed/sliding/bucket enforcement, window expiry, weighted cost, 50-way concurrency without overshoot, reset, typed Redis-unavailable wrapper, cache adapter: envelopes, corruption, hit/miss/expire, stampede collapse, bounded SWR, config errors) |
| `bun test apps/api/test/platform` | 57 pass / 2 fail — the 2 are the pre-existing DB-gated idempotency integration tests (ECONNREFUSED 54322). New: 18 rate-limit + 7 cache tests |
| `bun test apps packages` (full) | 244 pass / 29 fail — all 29 `ECONNREFUSED 127.0.0.1:54322` (DB-gated, pre-existing); no new failures vs. the pre-6A state |
| `bun run typecheck` | 0 errors (9 packages) |
| `bun run lint` | clean (137 files) |
| `bun run format` | clean (160 files) |
| `bun run check:bounds` | passed — 9 members, 82 source files, 0 violations |
| `bun run generate:check` | passed (no contract change: no new routes) |

## Acceptance evidence per instructions.md (OPS-060)

**Limit enforcement, uniform responses, no false positives.**

- Every `/v1` route enforces a registry policy: 18 tests — catalogue
  coverage (each of ~120 routes maps to a registered flow), live-path vs
  canonical parity, collection-vs-single weighting, spot checks matching the
  operator catalogue, and end-to-end 429s with `Retry-After` and
  problem+json bodies through a Hono app against real Redis (edge
  `publicDefault` bucket spanning paths/methods; account-scoped `auth` and
  `linking` flows with per-subject isolation).
- False-positive rate: a legitimate student mix (100 single reads + 10
  collection pages + 2 commands in one window = 124 weighted units) yields
  **zero rejections** against the 300-sustained/150-burst ordinary budget,
  asserted repeatedly.
- Uniformity: every 429 carries the same `RATE_LIMITED` problem code and a
  `Retry-After`, regardless of subject existence; keys carry only HMAC
  digests, so the counter namespace cannot reveal whether an account exists
  (asserted: digests are stable per secret/namespace, differ across
  secrets, and Redis keys never contain the subject).

**Redis-down behavior.** With an unreachable Redis: fail-closed flows
(auth/rpc/linking/admin/upload/search/AI/billing/webhook) answer **503
SERVICE_UNAVAILABLE** (never 429); ordinary traffic degrades to the bounded
in-process cap (exactly 50 rejections after 150 allowed weighted units in a
200-request run); the queue keys are untouched. Cache: session-context
loads fall back to the DB loader.

**Redis security posture.** Config tests: production rejects plaintext
`redis://`, rejects `rediss://` without credentials, accepts
`rediss://:pw@…`; the worker is enforced by `enforceWorkerFailClosed`;
`RATE_LIMIT_HMAC_SIGNING_KEY` is required in production (≥32 bytes) and
never appears in `describeApiEnv`.

**Revocation-safe caches.** Cache tests: the loader runs once until
invalidation; invalidation (generation bump) forces a fresh load; the
cached key never contains the raw subject; the TTL clamps to a positive
budget (`pttl ≤ 5100` with a 5-second budget); Redis-down falls back to the
loader. The in-memory `VersionedTenantContextCache` (AUTH-031) remains the
derived-projection layer, and `authz_authorize` decisions stay uncached —
unchanged by this part and asserted by the existing authorization suite.

**No queue eviction.** The three key namespaces (`studafy:{env}:rl`,
`studafy:{env}:cache`, BullMQ's `studafy-{env}`) are asserted pairwise
non-overlapping; the runbook requires a separate non-evicting production
allocation for the queue. No BullMQ key is touched by limiter or cache code.

**Cache catalogue.** `docs/security/rate-limit-catalogue.md` documents every
entry (policy table + cache table) with drift tests keeping code and
document in lockstep; `authctx` is `active`, seven entries are `declared`
with the adapter-proven mechanics.

## Cache catalogue documentation

The catalogued set and its invariants (TTL clamps, failure modes, stale
bounds, namespace isolation, "never cache an authorization decision") are
maintained in `docs/security/rate-limit-catalogue.md`; the session-context
cache is wired in `apps/api/src/platform/cache/authContextCache.ts` over
`RedisCache` (`packages/infrastructure/src/cache.ts`) with invalidation at
the mutation source (`apps/api/src/auth/context.ts`).

## Out of scope (unchanged gates)

- Production Redis topology, TLS termination and private networking (Phase
  8 / INFRA-080); RPC edge enforcement is a Phase 8 Cloudflare rule
  (documented in the runbook).
- OPS-061 (queue engine/scheduler) — untouched.
- Owning surfaces for the remaining declared flows/entries: search
  (ARC-011), AI gateways (AI-072/edge rules), billing (BIL-051), store
  webhook (OPS-051). FILE-050/051's upload/download-intent routes landed
  during this part and enforce the declared `uploadIntent` flow.
- The 29 pre-existing DB-gated integration failures (local Supabase not
  started) — identical before and after this part.
