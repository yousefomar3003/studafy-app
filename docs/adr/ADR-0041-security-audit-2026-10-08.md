# ADR-0041: Client addresses, encrypted and least-privilege database connections, and AI failures that were billed

- Status: Accepted; deployed to the Fly test copy on 2026-10-08 (see
  "Rollout"; reviewed 2026-10-12). The owner actions under "Rollout" that
  remain open are listed in `handoff.md`
- Date: 2026-10-08
- Decision owner: repository owner
- Relates to: ADR-0014 (least-privilege database access), ADR-0024 (rate
  limits), ADR-0035 (Fly, Sentry, Axiom), ADR-0037 (token allowances)
- Evidence: `docs/evidence/launch-readiness/2026-10-08-security-audit.md`

## Context

A security audit on 2026-10-08 found five defaults that held only as long as
nobody tried to get around them:

1. **Client addresses came from request headers.** Production trusted
   `CF-Connecting-IP` from any caller, and every other environment trusted the
   first `X-Forwarded-For` entry. The Fly origin is reachable directly
   (`*.fly.dev` and the app's own IPs), so a caller could name a different
   address on every request and never meet an IP-keyed limit. The hosted
   test copy logged two different `ip_hash` values for two requests from
   one machine.
2. **Database connections were plaintext.** postgres.js defaults to
   `ssl: false`, and the hosted `DATABASE_URL` has no `sslmode`. The API,
   worker and operator scripts reach the Supabase pooler over the internet.
3. **The services logged in as `postgres`.** That role owns every object and
   has `BYPASSRLS`. The least-privilege roles of ADR-0014 existed but were
   never used outside local harnesses.
4. **Billed AI failures were free.** A reply that the provider produced and
   billed, but that could not be used (empty, unreadable, a quiz with too few
   questions), released its hold, as did a timeout after sending. Nothing but
   the general rate limit stopped repeating such calls.
5. **Images were decoded without a pixel limit.** A 389 KB PNG declaring
   20,000 × 20,000 pixels took the decoder to 481 MB resident memory. The
   test API machine has 512 MB.

## Decision

**Client address (`CLIENT_IP_SOURCE`).** One resolver,
`apps/api/src/platform/clientIp.ts`, feeds both the rate limiter and the
access log:

- `cloudflare` (the production default) trusts `CF-Connecting-IP` only when
  `Fly-Client-IP` is in Cloudflare's published ranges. Otherwise it uses
  `Fly-Client-IP`, which Fly's proxy always sets and a client cannot.
- `fly` (the test copy, which has no Cloudflare) uses `Fly-Client-IP` only.
- `forwarded` reads `X-Forwarded-For` and is for local work only. Production
  refuses to start with it.

`ORIGIN_REQUIRE_CLOUDFLARE=true` refuses every request except `/healthz` that
did not come through Cloudflare. It is off until `api.studafy.com` is
proxied, because turning it on earlier would refuse all traffic.

**Database transport.** `createDatabase` encrypts every connection to a host
other than loopback. With `DATABASE_CA_CERT` (the Supabase root CA, as PEM)
it also verifies the certificate. An explicit `sslmode` in the URL still
wins, and production refuses `sslmode=disable` or `allow`. The operator
scripts that reach hosted databases use the same default.

**Database role.** Production refuses a `DATABASE_URL` that logs in as
`postgres`, `supabase_admin` or another Supabase administrative role. The API
uses `studafy_api_runtime` and the worker `studafy_worker_runtime`. Other
environments start but log `database_privileged_role`. Every function the
API and worker call is already granted to these roles. The end-to-end auth
lifecycle check passes 26/26 as `studafy_api_runtime`.

**AI failures.** A provider error that carries reported usage is settled at
that usage. A timeout or dropped connection after sending is settled at the
hold, its upper bound. Only a call that never reached the provider, or that
the provider refused with an HTTP error, is released. Separately, every POST
that calls the model is on its own fail-closed limit, `studyGeneration`: 30
per account per 5 minutes. It is named without "ai" because of the AI-072
guard test.

**Images.** At most 50 megapixels and 20,000 pixels on a side, read from the
header without decoding:

- the scan refuses larger images as `decompression_limit`;
- `prepareImage` decodes nothing it cannot measure or that exceeds the cap;
- pdf.js gets `maxImageSize` at the same cap.

**Redis.** API clients get a 2 s command timeout, so a Redis that hangs
fails over like one that refuses. A plaintext `redis://` URL to a host other
than loopback logs `redis_plaintext_remote`. Production already refuses it.

**Wellbeing notes.** A note's author reads it only while they still hold an
active membership in its school (migration `202610080001`).

## Consequences

- Students are charged for timed-out and unusable replies. This is a product
  trade-off accepted for cost safety, and it changes ADR-0037's "a failed
  quiz costs nothing". The charge is what the provider reported, or the hold
  when it reported nothing.
- More than 30 study generations in 5 minutes returns 429 for that account.
  If Redis is down, these routes answer 503.
- A phone photo above 50 MP (rare; 48 MP fits) is refused at upload.
- Production cannot start until its secrets use the runtime roles and TLS.

## Rollout

Nothing here is deployed. The hosted test copy runs the old code against the
Frankfurt database, which the handoff notes is also the planned production
database. Before the next deploy:

1. Give each runtime role a password on the hosted database (the worker role
   also needs `login`). Point `DATABASE_URL` at
   `studafy_api_runtime.<ref>` and `studafy_worker_runtime.<ref>`.
2. Optionally set `DATABASE_CA_CERT` from Dashboard → Database → SSL, and
   turn on "Enforce SSL" there.
3. Move Redis to a TLS endpoint (`rediss://`). The free Redis Cloud database
   in use has no TLS.
4. Apply `202610080001`, then deploy the API (`fly.test.api.toml` now sets
   `CLIENT_IP_SOURCE=fly`) and the worker.
