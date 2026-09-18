# ADR-0024: OPS-060 rate limits and revocation-safe caches

- Status: Accepted for local/disposable use
- Date: 2026-09-17
- Decision log: DL-045

## Context

Phase 6 Part 6A (OPS-060) required three linked things the codebase had
deferred: a production Redis security posture, application-level rate
limits over the whole `/v1` surface, and a catalogued set of revocation-safe
caches. Until now Redis existed only as a BullMQ transport for the worker
smoke path and a readiness probe; nothing limited request rates, and the
session context (`private.auth_context()`) was read from PostgreSQL on every
authenticated request.

Two scope decisions were taken with the product owner before implementation:

1. **RPC flow.** The only public RPCs
   (`public.record_policy_consent`, `public.mark_notifications_read`) are
   called by the Flutter client through the Supabase SDK and are not fronted
   by the Hono API, so Hono middleware cannot intercept them. Decision: the
   rate-limit registry models an `rpc` flow, its budget is enforced on the
   Hono operations that back the same actions today
   (`/v1/notifications/mark-read`; consent is requested through the auth
   surface), and the raw PostgREST path is protected by a documented
   Cloudflare/edge rule enforced at Phase 8 (runbook section). No Hono proxy
   routes and no mobile rewiring.
2. **Auth-context cache at a zero revocation budget.** The strict rule
   "never cache an authorization decision longer than its revocation budget"
   would disable the session-context cache at the default
   `AUTH_REVOCATION_BUDGET_SECONDS=0`. Decision: the cache is **version-keyed**
   — the key embeds every mutating dimension (account generation bumped by
   every auth-state mutation, plus the loaded `membershipVersion`, revocation
   watermark and profile state) — so any revocation changes the key instantly
   and the cache is provably revocation-safe even at budget 0. When a budget
   is configured, the TTL additionally clamps to `min(30s, budget)`.

## Decision

### One Redis posture, enforced at boot

Production `REDIS_URL` must be `rediss://` (TLS) **and** carry AUTH
credentials; the API and the worker both refuse a plaintext or passwordless
production URL at startup (`redisUrlPostureProblems`, enforced by
`enforceApiFailClosed`/`enforceWorkerFailClosed` in `@studafy/config`). The
loopback passwordless `docker-compose.dev.yml` instance remains the
documented development posture; TLS and private networking land with Phase 8
IaC. Local development and integration tests run against Redis and assert
behavior, not topology.

### Rate limits: a registry, two middleware, one insertion point

- `apps/api/src/platform/rate-limit/policies.ts` holds `RATE_LIMIT_FLOWS`
  covering every §8 flow: `auth`, `registration`, `passwordReset`,
  `verification`, `rpc`, `linking`, `uploadIntent`, `search`, `aiCoach`,
  `aiGrading`, `publicDefault`, `authenticatedApi`, `adminApi`,
  `billingPurchase`, `storeWebhook`. Each declares subject (`ip`/`account`),
  policy, `failClosed` flag and rationale. The FILE-050/051 upload and
  download-intent routes enforce the declared `uploadIntent` flow; the
  remaining flows without a shipped route (search, AI, billing, store
  webhook) are declared so the owning surface enforces a reviewed policy the
  day it exists.
- `flowFor(method, path)` classifies the catalogue: `/internal/*` and
  school-admin command paths → `adminApi`; `/v1/students/locate` and
  guardian links → `linking` (enumeration-prone);
  `/v1/notifications/mark-read` → `rpc`; sensitive `/v1/auth/*` and
  `/v1/account/*` POSTs → `auth`; ordinary traffic → `authenticatedApi`.
  Collection reads cost weight 2, single reads weight 1; every catalogue
  route's classification is parity-tested against a live-path instantiation.
- `rateLimitEdge` mounts in `createApp` on `/v1/*` **before** authentication
  (IP-scoped `publicDefault` backstop; infrastructure probes excluded).
  `rateLimitAuto` mounts inside `createAuthRoutes` **after** the auth
  middleware and covers the session routes plus every catalogue module
  mounted there — one insertion point, account/tenant-keyed, weighted.
- Keys are namespaced `studafy:{env}:rl:…` and built from HMAC digests
  (`hmacSubject`): **no raw account identifier ever enters a Redis key**, so
  the key namespace itself is not an enumeration side channel. IP subjects
  are normalized: IPv4 (and IPv4-mapped IPv6) key on the address, IPv6 keys
  on its /64 aggregate; production trusts only Cloudflare's
  `cf-connecting-ip` (the origin's documented posture), while non-production
  accepts standard proxy headers for tests and tooling.
- Responses are uniform: `429` problem+json (`RATE_LIMITED`) with a bounded
  `Retry-After`, identical whether the subject exists or not — the limiter
  must not become an account oracle.

### Failure modes are part of the contract

- **Fail closed** (auth, rpc, linking, admin, upload intent, search, AI,
  billing, store webhook, registration/password-reset/verification): a Redis
  failure answers `503 SERVICE_UNAVAILABLE` (`rate_limit_degraded` log) —
  never 429, because a limiter outage must not look like user misbehavior.
- **Fail open with a bound**: only the edge backstop and ordinary
  authenticated traffic degrade, to a bounded in-process limiter
  (`LocalFallbackLimiter`, capped map, per-process budgets = the documented
  degradation, not a bypass).
- Development without Redis runs the limiter in local-only mode (the same
  in-process limiter), keeping dev usable without weakening the contract:
  production is boot-blocked without Redis.

### Engine: atomic Redis primitives

`packages/infrastructure/src/rate-limit.ts` provides three Lua-atomic
primitives — fixed window (edge, cheapest), exact sliding window over a
sorted set with weighted events (low-volume sensitive flows), and a token
bucket with continuous refill (bursty ordinary traffic). Every decision is a
single script invocation, so concurrent API instances share one budget
without overshoot (proved by a 50-way concurrency test). Time is caller-
supplied; Redis `TIME` is never read.

### Caches: catalogued, version-keyed, never an authorization decision

- `apps/api/src/platform/cache/cacheCatalogue.ts` is the catalogue: every
  entry declares key id, TTL rule, (optional) bounded stale-while-revalidate
  window, failure mode and status. `authContext` is `active`; the rest
  (`userSummary`, `classroomSummary`, `timetableWindow`, `publishedFeedPage`,
  `billingCatalog`, `entitlementRead`, `negativeNotFound`) are `declared`
  with the adapter-proven mechanics and land with their owning routes rather
  than being invented for read paths that have no hot query today.
- `authz_authorize` — the per-request permission decision (AUTH-031) — is
  **never cached**. The catalogue caches derived context, not authorization.
- The active entry wraps `AuthContextRepository.load`: `RedisAuthContextCache`
  keys on `HMAC(subject)` plus an **account generation** that every
  `AuthContextRepository` mutation bumps (`signOutAll`, `revokeDevice`,
  `touchDevice` on revocation, identity link/unlink, deletion request/
  cancel). Session revocation therefore takes effect on the very next
  request even with a zero budget. Loader runs inside
  `withVerifiedActor` exactly as before; a Redis failure falls back to the
  loader (fail closed to fresh state), never to stale state.
- TTL = `min(30s, AUTH_REVOCATION_BUDGET_SECONDS)` when a budget is set;
  30s at the default zero budget. The catalogue test asserts both the clamp
  and the bound.
- Accepted residual (documented, bounded): state changes applied to a
  subject **by another actor** (suspension, membership lifecycle by a school
  admin) or out-of-band (worker deletion sweeps) become visible to that
  subject's cached context within the TTL (≤30s). Authorization is unaffected
  because `authz_authorize` reads the database fresh per request; the
  practical window is bounded and cosmetic (display name, badges,
  `mfaRequiredByPolicy` for ≤30s after a role change).

### Namespacing and eviction isolation

Rate-limit (`studafy:{env}:rl`), cache (`studafy:{env}:cache`) and BullMQ
(`studafy-{env}`) namespaces are asserted pairwise non-overlapping. In
production the queue must live on a non-evicting allocation separate from
caches/limiters (runbook); locally the single dev instance is covered by the
disjoint prefixes.

### Credentials

`RATE_LIMIT_HMAC_SIGNING_KEY` (≥32 bytes) is required in production when
limiting is enabled and minted ephemerally per boot in development; the key
is per-environment and rotatable (rotation restarts counters — a documented,
acceptable disruption). Registered in `docs/security/credentials-map.md`.

## Consequences

- The whole `/v1` surface (≈120 catalogue routes + session routes) enforces
  reviewed budgets with two middleware insertions and no per-route wiring.
- The 4 previously Redis-gated tests run green against a real Redis, and the
  new suites add enforcement, failure-mode, false-positive-rate, catalogue
  drift and cache-invariant evidence.
- Out of scope by design: OPS-061 (queue engine/scheduler), the production
  Redis topology itself (Phase 8), RPC edge enforcement (Cloudflare rule at
  Phase 8), Flutter/mobile wiring, and the owning routes for the declared
  cache entries.

## References

- `docs/security/rate-limit-catalogue.md` — operator-facing policy + cache
  catalogue (kept in lockstep by drift tests)
- `docs/security/ops060-operator-runbook.md` — Redis posture, rotation,
  outage drills, queue isolation
- `docs/evidence/phase-6a/README.md` — verification transcript
