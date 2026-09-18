# OPS-060 operator runbook — Redis, rate limits and caches

This runbook covers operating the rate-limit and cache layer introduced by
ADR-0024 (DL-045). The policy and cache catalogue itself lives in
`docs/security/rate-limit-catalogue.md`; the code is the authority and the
drift tests keep that document in lockstep.

## 1. Redis security posture

| Environment | Posture | Enforcement |
|---|---|---|
| Development | `redis://` on loopback via `docker-compose.dev.yml` (pinned Redis 7.4.4), passwordless | Documented local posture only; never exposed beyond loopback |
| Production | `rediss://` (TLS) with AUTH credentials, private network only, never public | **Boot-enforced**: the API and the worker refuse a plaintext or passwordless production URL (`redisUrlPostureProblems` in `@studafy/config`) |

Rules that have no exception:

1. Redis is never exposed to the public internet. The production instance
   must be reachable only from the private network.
2. The production connection URL always carries a password and uses TLS.
3. Local development instances are loopback-only and disposable; no
   production data ever passes through them.

Starting the local stack: `bun run dev:stack`. On podman-based hosts:
`podman machine start` and `export DOCKER_HOST='unix://…/podman/podman-machine-default-api.sock'`
first.

## 2. Key namespaces and eviction isolation

| Concern | Namespace | Eviction posture in production |
|---|---|---|
| BullMQ queue keys | `studafy-{env}:…` | **Non-evicting** (`noeviction`); job payloads must never be evicted |
| Rate-limit counters | `studafy:{env}:rl:…` | TTL-bounded; may live on an LRU-eligible instance |
| Caches | `studafy:{env}:cache:…` | TTL-bounded; rebuildable from durable source by definition |

The three namespaces are asserted pairwise non-overlapping by a test
(`cacheCatalogue` invariants). In production, run the queue on a **separate
Redis instance** from caches and limiters; if a single instance must be
shared, it must be `noeviction` with TTL bounds as the only reclaim path.

## 3. Rate limiting

### Where it runs

- Edge backstop: `rateLimitEdge` in `createApp`, on `/v1/*`, before
  authentication, IP-scoped (`publicDefault`).
- Authenticated flows: `rateLimitAuto` inside `createAuthRoutes`, after the
  auth middleware, account-keyed (+ per-tenant ceiling on ordinary reads),
  classified per route by `flowFor`.

### Failure modes

- Sensitive flows (auth, rpc, linking, admin, upload intent, search, AI,
  billing, store webhook): Redis failure → `503 SERVICE_UNAVAILABLE`,
  logged as `rate_limit_degraded`. **A limiter outage is never surfaced as
  429.**
- Ordinary traffic and the edge backstop: Redis failure → bounded
  in-process limiter (`LocalFallbackLimiter`). Per-process, so N instances
  allow N budgets during the outage window — the documented degradation.
- Development without Redis runs in local-only mode.

### Operational actions

- **A legitimate client is rate-limited wrongly.** Confirm the flow and key
  subject from the `rate_limit_rejected` log line (flow + subject class only,
  never an identifier). The counter expires with its window; there is no
  manual clear for one subject (keys are HMAC'd, not enumerable by design).
  If a whole address family is blocked, rotate the IP subject aggregation in
  a reviewed change, not an operator override.
- **Deploy a new policy.** Change `RATE_LIMIT_FLOWS` in
  `apps/api/src/platform/rate-limit/policies.ts`; the catalogue document and
  the drift tests will fail until the operator catalogue is updated in the
  same change. Budget changes take effect on the next deploy; counters are
  not migrated.
- **A flow without a route yet** (search, AI, billing, store
  webhook) is declared in the registry. The owning route must call
  `rateLimitFlow` (or the edge rule) with that flow — enforcement lands with
  the route, not later.

## 4. RPC and edge-path protection (enforced at Phase 8)

The two public PostgREST RPCs bypass Hono. Until the Hono surface owns them,
protect the raw path at the edge (Cloudflare WAF rule + gateway limits):

- `public.record_policy_consent` and `public.mark_notifications_read`:
  60 events / 5 minutes per authenticated principal, deny → 429.
- Supabase auth endpoints (login/registration/password reset/verification
  code send): per-IP budgets 5–10 / hour per the registry's
  `registration`/`passwordReset`/`verification` policies.
- Store webhook (`store-webhook` Edge Function): 600 / minute per source IP.

These rules are infrastructure (Phase 8, INFRA-080); the code side of the
contract (the `/v1` equivalents) is already enforced.

## 5. Caches

### The active entry: session context

`AuthContextRepository.load` is cached in Redis under a version-keyed entry:

- key: `studafy:{env}:cache:authctx:{HMAC(subject)}:{generation}` — the raw
  subject never appears in any key;
- TTL: `min(30s, AUTH_REVOCATION_BUDGET_SECONDS)`; 30s at the default
  budget of 0 (safe because any auth-state mutation bumps the generation,
  changing the key instantly);
- invalidation: automatic, at the source — `signOutAll`, `revokeDevice`,
  device revocation via `touchDevice`, identity link/unlink, deletion
  request/cancel all bump the generation;
- failure: Redis down → the DB loader answers fresh. Cache problems can only
  cost latency.

**Residual staleness (accepted, bounded):** a change applied *to* a user by
another actor (suspension, membership lifecycle) or out-of-band becomes
visible to that user's cached context within the TTL. Authorization is
unaffected (`authz_authorize` reads the database fresh per request).

### Declared entries

`userSummary`, `classroomSummary`, `timetableWindow`, `publishedFeedPage`,
`billingCatalog`, `entitlementRead`, `negativeNotFound` are declared with the
proven adapter; each becomes active only when its owning route lands and its
invalidation event is implemented. Do not populate them ad hoc — extend the
catalogue with the entry first.

**Never cache an `authz_authorize` decision.** The catalogue caches derived
context; permission decisions are read fresh per request. This is asserted
by the AUTH-031 suite and must not regress.

## 6. Key rotation

`RATE_LIMIT_HMAC_SIGNING_KEY` (≥32 bytes) is per-environment. To rotate:

1. Generate a new ≥32-byte random key in the secret manager.
2. Deploy with the new key. Old digests stop matching: all rate-limit
   counters reset and cache entries are orphaned (they expire by TTL).
   Counter reset is the accepted, documented disruption — prefer deploying
   during a low-traffic window.
3. Confirm `rate_limit_degraded` does not appear and counters rebuild.

If the secret was ever committed, screenshotted or pasted, treat it as
disclosed: rotate immediately and audit `rate_limit_rejected` spikes after
rotation.

## 7. Redis outage drill

1. Stop Redis (or point the API at an unreachable port).
2. Verify: sensitive flows answer `503 SERVICE_UNAVAILABLE`; ordinary reads
   still work inside the bounded local cap; no 429s are emitted; logs show
   `rate_limit_degraded`; session loads fall back to the database.
3. Restart Redis; verify budgets recover and caches rebuild from the loader.
4. The queue must be unaffected: no BullMQ keys were touched (namespace
   isolation).

`/readyz` reports `redis_unreachable` while the outage lasts; the API keeps
serving degraded (this is why the drill exists — Redis down must degrade the
non-sensitive surface, not black-hole the API).
