# OPS-060 rate-limit and cache catalogue

The code is the authority: `apps/api/src/platform/rate-limit/policies.ts`
and `apps/api/src/platform/cache/cacheCatalogue.ts`. The drift tests
(`apps/api/test/platform/rate-limit.test.ts`, `apps/api/test/platform/cache.test.ts`)
fail if this document drifts from the registry. Rationale and decisions:
ADR-0024; operations: `docs/security/ops060-operator-runbook.md`.

## Rate-limit flows (§8 coverage)

| Flow | Subject | Policy | Fail closed | Covers today |
|---|---|---|---|---|
| `auth` | account | sliding window, 30 events / 5 min, cost ×2 per op | yes | `/v1/auth/*` and `/v1/account/*` POSTs (device revoke, sign-out, reauth, identity link/unlink, deletion request/cancel, profile write, export request) |
| `registration` | ip | sliding window, 5 / hour | yes | declared — Supabase-side; edge rule at Phase 8 |
| `passwordReset` | ip | sliding window, 5 / hour | yes | declared — Supabase-side; edge rule at Phase 8 |
| `verification` | ip | sliding window, 10 / hour | yes | declared — Supabase-side; edge rule at Phase 8 |
| `rpc` | account | fixed window, 60 / 5 min | yes | `/v1/notifications/mark-read` (the public RPC equivalent); raw PostgREST path is an edge rule at Phase 8 |
| `linking` | account | sliding window, 20 / 5 min, cost ×2 | yes | `/v1/students/locate`, `/v1/guardian-links*` (enumeration-prone) |
| `uploadIntent` | account | fixed window, 100 / hour | yes | `POST /v1/uploads` (create intent), `POST /v1/uploads/{id}/complete`, `POST /v1/files/{id}/download-intent` (FILE-050/051); publish stays an ordinary command |
| `search` | account | sliding window, 60 / 5 min | yes | declared — lands with ARC-011's route |
| `aiCoach` | account | fixed window, 50 / hour | yes | declared — study-coach gateway rule |
| `aiGrading` | account | fixed window, 100 / hour | yes | declared — study-grader gateway rule |
| `publicDefault` | ip | fixed window, 120 / min | **no** (bounded local fallback) | every `/v1/*` request, pre-auth (edge backstop) |
| `authenticatedApi` | account (+ tenant ceiling) | token bucket, 300 sustained / 5 min, burst 150 | **no** (bounded local fallback) | ordinary reads/collections (weight 1 / 2) and non-sensitive commands (weight 2); tenant ceiling 2000 / 5 min per school |
| `adminApi` | account | sliding window, 120 / 5 min, cost ×2 per op | yes | `/internal/*` (support access, moderation, legal holds), school-admin command surface (`/v1/schools*`, `/v1/memberships/*` POST), `/v1/control-panel/*` |
| `billingPurchase` | account | fixed window, 20 / hour | yes | declared — lands with BIL-051's surface |
| `storeWebhook` | ip | fixed window, 600 / min | yes | declared — store-webhook gateway rule (OPS-051) |

Subject scoping:

- `ip` subjects are keyed by a normalized network prefix — the address for
  IPv4 (and IPv4-mapped IPv6), a /64 aggregate for IPv6. Production trusts
  only `cf-connecting-ip`.
- `account` and `tenant` subjects are keyed by HMAC digests; **raw
  identifiers are never written to Redis keys**.
- `Retry-After` is always present on 429 and bounded to one hour.

Classification rules (`flowFor`), in evaluation order: `/internal/*` →
admin; locate/guardian links → linking; notifications mark-read → rpc;
`/v1/schools*` + `/v1/memberships/*` → admin on POST, ordinary read on GET;
`/v1/control-panel/*` → admin; `/v1/auth/*` + `/v1/account/*` POST → auth;
other POST → ordinary command; other GET → ordinary read (collections ×2).
Every `V1_ROUTE_CATALOGUE` entry is parity-tested against a live-path
instantiation of its canonical path.

## Cache catalogue (§9 coverage)

TTL is milliseconds × 1000 of the values below. "SWR" = bounded
stale-while-revalidate window. Status `active` = wired to a real read path.

| Entry | TTL | SWR | Failure mode | Invalidation event | Status |
|---|---|---|---|---|---|
| `authctx` — DB-loaded session context | min(30 s, revocation budget; 30 s at budget 0) | none | fall back to DB loader | generation bump on sign-out/device revoke/identity link-unlink/deletion request-cancel; key embeds membership version + watermark + profile state | **active** |
| `user-summary` | 300 s | none | fall back to loader | `account.profile.write` | declared |
| `classroom-summary` | 300 s | none | fall back to DB loader | classroom / school-admin write commands | declared |
| `timetable` | 300 s | none | fall back to DB loader | schedule replace / publish commands | declared |
| `feed-page` | 120 s | 60 s | fall back to DB loader | publish / withdraw commands | declared |
| `billing-catalog` | 3600 s | none | fall back to DB loader | catalog publish | declared |
| `entitlement` | min(30 s, budget) | none | **fail closed to DB** | entitlement grant/revoke | declared |
| `negative-404` | 5 s | none | fall back to DB loader | resource creation | declared |

Invariants asserted by tests:

1. Authorization-adjacent TTLs (`authctx`, `entitlement`) never exceed
   `min(30s, budget)`.
2. Entries with `fail_closed_to_db` never declare a stale window.
3. Key namespaces (`studafy:{env}:rl`, `studafy:{env}:cache`,
   `studafy-{env}`) are pairwise non-overlapping.
4. The session-context key never contains a raw subject identifier.
5. Every catalogue route classifies into a registered flow whose rationale
   and failure mode are documented (this table).
