# Security audit, 2026-10-08

Scope: this branch's API, worker, shared packages, Supabase migrations and
policies, Edge Functions, CI workflows, Fly configuration, and what the Fly CLI
and public endpoints show of the hosted test copy. Decisions: ADR-0041.

This is a source review with local reproduction. It is not a penetration test
or a certification. Testing used synthetic data on a throwaway Supabase stack
(port 55722) and disposable containers. Against hosted services only these
were run:

- read-only Fly CLI listings (apps, IPs, secret names; no values);
- `GET /healthz` and `GET /version` on the test API;
- two unauthenticated `GET /v1/me` requests carrying forged `X-Forwarded-For`
  headers, then a read of their access-log lines with `fly logs`;
- a TLS handshake with the Supabase pooler (no login);
- `gh run list` and `gh run view` for the backup workflow.

No hosted data was read and nothing was deployed. No load or DDoS test was
run.

## Fixed and verified

| # | Severity | Component | Finding | Evidence | Fix | Verification |
|---|---|---|---|---|---|---|
| 1 | High | API rate limits, access log | Client address taken from caller-writable headers. Production trusted `CF-Connecting-IP` from anyone, while the origin is reachable at `*.fly.dev` and its own IPs. Other environments trusted `X-Forwarded-For`. Every IP-keyed limit (edge backstop 120/min, school sign-up 5/hour) could be bypassed. | Hosted test copy: two requests from one machine with forged `X-Forwarded-For` were logged with two different `ip_hash` values. Fly documents that `Fly-Client-IP` is always set by its proxy. | `platform/clientIp.ts`, `CLIENT_IP_SOURCE` (`cloudflare` trusts CF only from Cloudflare ranges; `fly`; `forwarded` refused in production). Opt-in `ORIGIN_REQUIRE_CLOUDFLARE`. `fly.test.api.toml` sets `fly`. | Real API process, 130 requests rotating `X-Forwarded-For` from one `Fly-Client-IP`: old setting 0 × 429; new setting 10 × 429 at the 120/min limit. Unit tests: rotating `CF-Connecting-IP` from a non-Cloudflare peer shares one budget; origin lock refuses direct traffic; production refuses `forwarded`. |
| 2 | High | API, worker, operator scripts → Postgres | Database traffic in plaintext over the internet. postgres.js defaults to `ssl: false`, and the hosted `DATABASE_URL` has no `sslmode`. The scheduled backup script was the same. | Source review (`node_modules/postgres` defaults). The pooler offers TLS 1.3 with Supabase's CA. | `databaseTls()` in `packages/database`: TLS for any non-loopback host; `DATABASE_CA_CERT` for full verification. Production refuses `sslmode=disable/allow`. Operator scripts use the same default. | Disposable SSL-enabled Postgres: `pg_stat_ssl` shows `TLSv1.3` for a LAN address and `ssl=false` for loopback. Unit and config tests. |
| 3 | High (defence in depth) | API, worker → Postgres | Services log in as `postgres` (owner, `BYPASSRLS`), so ADR-0014's least-privilege roles were unused. | Hosted and local `.env` user names (values not printed); `pg_roles`. | Production refuses administrative DB logins; elsewhere `database_privileged_role` is logged. | All 49 API and 41 worker function calls are granted to the runtime roles. `verify-auth-lifecycle.ts` as `studafy_api_runtime`: 26/26, including "cannot read tables directly". Config tests. **Hosted still uses `postgres` (see Still open).** |
| 4 | Medium | AI metering | A reply the provider produced and billed, but that was unusable, released its hold, and so did a timeout after sending. Repeating such calls cost the student nothing. The AI routes shared the fail-open general limit. | Source review of `AiMeter.run` and `complete()`. | Billed failures are settled (reported usage, else the hold). New `studyGeneration` flow: 30 per 5 min per account, fail-closed. | `metering-failures.test.ts` (quiz with too few questions → settled at reported usage; timeout → hold; 400 → released). Rate-limit tests cover every model route. |
| 5 | Medium | Upload scan, API photo path, worker readers | No pixel limit: a small file declaring a huge image is decoded in full. | 389 KB PNG (20,000 × 20,000): old decode path reached 481 MB resident memory (the test API has 512 MB). | `files/dimensions.ts`: 50 MP and 20,000 px per side, read from the header. The scan refuses larger images (`decompression_limit`); `prepareImage` refuses before decoding; pdf.js `maxImageSize`. | Same file: scan `policy_rejected`; `prepareImage` refuses in 1 ms at 44 MB. `dimensions.test.ts`. |
| 6 | Medium | RLS (`wellbeing_events`) | `can_view_wellbeing` let the author through with no membership check. A removed teacher could still read their safeguarding-restricted notes through PostgREST. | Throwaway DB, rolled back: after revoking the teacher's membership and ending the assignment, the restricted note's title and context were still readable. | Migration `202610080001`: the author also needs an active membership. | Same reproduction returns 0 rows. Two new pgTAP assertions in `db021_access.sql`. Grants unchanged. |
| 7 | Medium | Redis client | No command timeout, so a Redis that accepts connections but hangs stalled every rate-limited request until the 10 s request timeout. | Fake silent server: no answer after 8 s. | `commandTimeout` of 2 s. Startup warning for plaintext remote Redis. | The same server now fails in about 2 s, so the documented fallback or fail-closed applies. |

## Still open

| Severity | Item | Blocker / next step |
|---|---|---|
| High | Hosted Redis is plaintext `redis://` to a public Redis Cloud host. The password, rate-limit keys and BullMQ jobs cross the internet in clear. | Owner: a TLS endpoint (`rediss://`). The current free Redis Cloud database has no TLS; Upstash `eu-central-1` does. Production already refuses plaintext. |
| High | Hosted API and worker still log in as `postgres`. | Owner: set passwords for `studafy_api_runtime` and `studafy_worker_runtime` (the worker role also needs `alter role … login`). Update `DATABASE_URL` secrets (`<role>.<project ref>` on the pooler). Redeploy. |
| High | No working backups. The daily backup workflow failed on every run checked (2026-10-04 to 10-08) because `BACKUP_DATABASE_URL` and `BACKUP_AGE_RECIPIENTS` are not set, so no encrypted, restore-tested backup exists. | Owner: follow `docs/deployment/backups.md`. Decide on PITR. |
| Medium | Nothing above is deployed. The hosted test copy still trusts `X-Forwarded-For`, has no pixel cap, uses plaintext DB connections and has the wellbeing gap. | Apply `202610080001` and deploy once the owner decides whether the Frankfurt database is still a test target (handoff). |
| Medium | The test copy runs `ENVIRONMENT=development` against the planned production database: Turnstile test keys (always pass), no HSTS, structural file checks only (no malware engine), and `/version` shows the environment. | Do not admit real users to it. Production needs the scanner vendor, real Turnstile keys and Cloudflare. |
| Medium | Secret sprawl on Fly. The suspended `studafy-api` app still holds `AWS_ACCESS_KEY_ID`/`AWS_SECRET_ACCESS_KEY`, `FLY_API_TOKEN`, `TELEGRAM_BOT_TOKEN`, `SUPABASE_SECRET_KEY`, `AXIOM_TOKEN` and more. The stray `studafy` app (cdg, from `fly launch`) still has public IPs. | Owner: delete the IAM key; revoke that Fly token; `fly secrets unset` unused names on `studafy-api`; `fly apps destroy studafy`. |
| Low | `.github/workflows/fly-deploy.yml` (uncommitted) uses `superfly/flyctl-actions/setup-flyctl@master` (mutable), has no `permissions:` block, and deploys the stray `fly.toml` app on every push to `main`. | Delete it rather than commit it, or pin the action by SHA, add `permissions: contents: read` and target the right config. |
| Low | Log shipper image is `:latest` (unpinned). | Pin to a digest (`fly image show`). |
| Low | Link fetcher DNS rebinding: the address is checked before the request resolves it again. | Documented in `material/link.ts`. Fly's private network is blocked by range; pinning the resolved IP needs a custom TLS connect. |
| Low | One free replay per charged AI request key (`:replay`), so at most 2 calls for the price of 1. | Accept, or make replays return the stored answer. |
| Low | Each rejected bearer token writes a security event row: unauthenticated database writes, bounded only by the edge limit. | Sample or aggregate denial events. |
| Low | No minimum password length in `supabase/config.toml`; the hosted Auth settings are unknown. | Set at least 10 characters in the dashboard and in config. |
| Info | Cloudflare WAF, bot rules, edge rate limits and caching rules do not exist yet. The only Cloudflare use is the alert relay Worker and Turnstile. Redis-backed limits are not DDoS protection. | INFRA-080: proxy `api.studafy.com`, then set `ORIGIN_REQUIRE_CLOUDFLARE=true`. |

## Not inspected, or could not be checked

- **Hosted Supabase settings:**
  - RLS state on the hosted database;
  - whether `private-school-files` is private there;
  - Enforce SSL;
  - network restrictions;
  - Auth rate limits and password policy;
  - exposed schemas;
  - PITR.

  Auto mode blocks reads of that database.
- **Provider settings:**
  - Cloudflare zone settings;
  - Redis Cloud configuration (ACLs, eviction, persistence);
  - Sentry scrubbers;
  - Axiom retention;
  - Together AI spend limits.
- **Live prompt injection against the real model.** It was assessed by design
  review only:
  - material is wrapped as data;
  - retrieval is permission-checked in SQL before selection;
  - the model has no tools;
  - replies are not turned into tappable links.
- **Payments with real store credentials.** Billing is off on the test copy.
  Webhooks verify JWS/OIDC, and the worker re-reads authoritative store state.
- The Flutter app beyond link handling and secret placement, and native
  build settings.
- Load, burst and DDoS behaviour at scale.

## Checked and found sound

- JWT verification:
  - the algorithm comes from the key, never the header;
  - issuer, audience, `exp`, `nbf` and `iat` are checked.
- Every mounted `/v1` handler declares a permission (catalogue test), and
  SQL re-checks it.
- All 376 `SECURITY DEFINER` functions pin `search_path=""`, and `anon`
  executes no application function.
- Every `public` table has RLS. `storage.objects` has no client policies
  (deny all).
- Answer keys are released only once the assessment has closed for everyone.
- Guardian linking needs the child's approval; lookups are capped at
  10/hour over a space of 9×10⁹ IDs.
- Managed-child sign-in links are bound to the guardian in SQL and to the
  reserved domain.
- The SSRF guard blocks private, link-local, CGNAT, metadata and Fly 6PN
  ranges on every redirect, with a byte cap.
- OOXML zip limits cover entries, ratio and total inflate.
- Logs are redacted and Sentry scrubs users, headers, bodies and query
  strings.
- Store webhooks are verified and deduplicated.
- Edge Functions are retired stubs.
- Gitleaks over 160 commits: nothing found.
- `bun audit` and OSV (235 Bun and 186 Dart packages): nothing found.

## Checks run

- **pgTAP:** 56 suite files in CI order on a freshly reset throwaway stack,
  all pass.
- **Backend:** 1,010 pass, 1 skipped, 0 fail.
- **Static gates:** typecheck, lint, format, `check:bounds`,
  `check:migrations`, `generate:check` and `db lint --level error` are clean.
- **Flutter:** tests were not re-run, because no Dart code changed.
