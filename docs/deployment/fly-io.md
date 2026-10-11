# Running Studafy on Fly.io, with Sentry, Axiom and Telegram alerts

ADR-0035. This replaces `aws-app-runner.md` as the production plan.

```
Phone app ──► Fly.io: studafy-api ─┐            ┌─► Axiom (logs, pattern alerts) ─┐
                     studafy-worker ┼─ logs ─► log shipper                         ├─► relay ─► Telegram
                                    └─ errors ─────────────► Sentry (error alerts) ─┘          (+ email)
Phone app crashes ─────────────────────────────────────────► Sentry
Cloudflare Worker (relay) ── every minute ──► https://api.studafy.com/readyz ──► Telegram + email
```

Everything below is done once. Order matters only where noted.

## Test copy (running now)

Until production's blockers are cleared (malware scanner, TLS Redis, real
Turnstile keys on the domain), a development-mode copy runs on Fly in place
of the Mac-hosted API:

| App | Config | Address |
|---|---|---|
| `studafy-api-test` | `fly.test.api.toml` | https://studafy-api-test.fly.dev |
| `studafy-worker-test` | `fly.test.worker.toml` | (no HTTP) |

It uses the same Frankfurt Supabase project, Redis, Sentry and Cloudflare
test keys as `.env.hosted`. Secrets were piped from `.env.hosted` with
`fly secrets import`. The app's `config/dart-defines.device.json` points
`STUDAFY_API_URL` at it, which must equal its
`FILE051_DELIVERY_PUBLIC_BASE_URL` or the app refuses download links.
Redeploy with `fly deploy --config fly.test.api.toml` (and the worker's).

## 0. Move the database to Frankfurt first

Supabase cannot change a project's region. Create a **new project in
`eu-central-1` (Frankfurt)**, then:

1. `bunx supabase db push --db-url "<new project's database URL>"` applies
   every migration.
2. Copy the auth settings (sign-in providers, redirect URLs, email templates)
   from the old project.
3. Put the new URL and keys into `.env.hosted` and
   `config/dart-defines.*.json`.

The test data was wiped on 2026-10-01, so there is nothing to carry over.
Update the privacy policy's Supabase row (§7.2) to Frankfurt.

## 1. Accounts to create

| Service | Plan | Choose |
|---|---|---|
| Fly.io | Pay as you go | Organisation `personal` (or your own; set `ORG` in `fly.log-shipper.toml`) |
| Sentry | Developer (free) | **EU data region**. Two projects: `studafy-backend` (Bun) and `studafy-app` (Flutter) |
| Axiom | Free | **EU region** if offered. A dataset named `studafy-production`, and an API token that can only ingest into it |
| Telegram | Free | A bot from @BotFather, and the group or chat that receives alerts |
| Cloudflare | Free | Workers, for the alert relay |
| Redis | Free tier to start | Production refuses a Redis URL without TLS (`rediss://`) and a password. Check that your Redis Cloud database has TLS on, or use Upstash in `eu-central-1`, which has TLS on its free tier |

Sign each provider's data processing agreement (privacy policy, Appendix A).

## 2. Deploy the API and worker

From the repository root, with `flyctl` installed and `fly auth login` done:

```sh
fly apps create studafy-api
fly apps create studafy-worker
```

Secrets go in with `fly secrets import`, which reads `NAME=value` lines from
standard input. Nothing is pasted into chat, a ticket or the shell history.
Keep the file outside the repository and delete it afterwards.

**API**, from a file such as `~/studafy-api.secrets`:

```
DATABASE_URL=...            # Frankfurt project, pooler, as studafy_api_runtime (below)
DATABASE_CA_CERT=...        # optional: Supabase root CA PEM, verifies the server
REDIS_URL=rediss://...
SUPABASE_URL=...
SUPABASE_SERVICE_ROLE_KEY=...
API_CURSOR_SIGNING_KEY=...  # one random key per purpose, all different:
RATE_LIMIT_HMAC_SIGNING_KEY=...
CLASS_JOIN_CODE_KEY=...
FILE051_DELIVERY_SIGNING_KEY=...
TURNSTILE_SITE_KEY=...
TURNSTILE_SECRET=...
AI_API_KEY=...
AI_BASE_URL=https://api.together.xyz
SENTRY_DSN=...              # studafy-backend
```

```sh
fly secrets import --config fly.api.toml < ~/studafy-api.secrets
fly deploy --config fly.api.toml
```

**Database roles (ADR-0041).** Production refuses to start as `postgres` or
another Supabase administrative role. Once, in the SQL editor, give the
runtime roles their own passwords (generate them; never reuse):

```sql
alter role studafy_api_runtime login password '<generated>';
alter role studafy_worker_runtime login password '<generated>';
```

On the pooler their user names are `studafy_api_runtime.<project ref>` and
`studafy_worker_runtime.<project ref>`. Every non-local connection is
encrypted; set `DATABASE_CA_CERT` (Dashboard → Database → SSL) to verify the
certificate too, and turn on "Enforce SSL" there.

**Worker**, the same way, with `DATABASE_URL` (as `studafy_worker_runtime`), `REDIS_URL`, `SUPABASE_URL`,
`SUPABASE_SERVICE_ROLE_KEY`, `MALWARE_SCANNER_URL`,
`MALWARE_SCANNER_API_KEY` and `SENTRY_DSN`:

```sh
fly secrets import --config fly.worker.toml < ~/studafy-worker.secrets
fly deploy --config fly.worker.toml
```

The worker refuses to start in production without a malware scanner. The
vendor is still to be chosen (`docs/security/credentials-map.md`), so this is
a launch dependency.

**Scaling.** The API runs one warm machine and starts more as traffic grows
(`soft_limit` 200 concurrent requests per machine). Give it room once:

```sh
fly scale count 4 --config fly.api.toml   # up to 4; idle ones stay stopped
```

`DATABASE_POOL_MAX` (10) × API machines, plus the worker's 10, must stay
under the Supabase plan's connection limit.

**Domain.** `fly certs add api.studafy.com --config fly.api.toml`, then point
the DNS record at Fly as it instructs. If the record is proxied through
Cloudflare, client addresses come from Cloudflare's header, but only for
connections Fly saw arrive from Cloudflare's ranges (`CLIENT_IP_SOURCE`,
ADR-0041); anything else keys on `Fly-Client-IP`. Once proxied, set
`ORIGIN_REQUIRE_CLOUDFLARE = "true"` so `studafy-api.fly.dev` cannot be used
to step around Cloudflare's rules.

`scripts/fly-config.test.ts` checks in CI that both Fly configs pass the
same production validation the processes run at start-up.

## 3. Logs to Axiom

The dataset is `studafy-production`, in Axiom's **EU** region. An EU dataset
accepts data only through the EU edge
(`https://eu-central-1.aws.edge.axiom.co/v1/ingest/<dataset>`), and the log
shipper's built-in Axiom output always uses the US address. The shipper
therefore sends through its generic HTTP output, which `fly.log-shipper.toml`
points at the EU edge (`HTTP_URL`). Never set `AXIOM_TOKEN` or
`AXIOM_DATASET` on the shipper: that switches on the US output as well.

```sh
fly apps create studafy-log-shipper
fly secrets set --config fly.log-shipper.toml \
  ACCESS_TOKEN="$(fly tokens create readonly personal)"
fly secrets import --config fly.log-shipper.toml < ~/studafy-shipper.secrets  # HTTP_TOKEN=<Axiom ingest token>
fly deploy --config fly.log-shipper.toml
```

After the first deploy, check `['studafy-production'] | take 20` in Axiom
shows lines, then pin the image to its digest
(`fly image show --config fly.log-shipper.toml`).

**What is kept (OPS-090).** The API and worker keep every warning and error,
every failed (4xx/5xx) or slow (at least 2 s) request, sign-in refusals, the
per-minute heartbeats and money events. They keep 1 in 10 other successful
requests and routine job completions, and 1 in 100 unread-badge polls. Fly's
health checks are dropped. A sampled line carries `sample_rate`, so
`count / sample_rate` estimates the true number. Set the dataset's retention
to **30 days**.

Audit history (grade changes, attendance corrections, purchases) lives in
the database and is never affected by log sampling.

## 4. Errors to Sentry

- **API and worker:** the `SENTRY_DSN` secret above. A 500 is reported with
  its stack trace. Any error-level log line (a job that gave up, a failed
  poll) becomes one grouped issue per service, event and error code.
- **App:** add `"SENTRY_DSN": "<studafy-app DSN>"` to the release
  dart-defines. Builds without it report nothing.

Personal data is off at every layer:

- **Server (`packages/infrastructure/src/sentry.ts`):** Sentry's collection
  of user info, headers, cookies, query strings, bodies, database values,
  queue arguments, AI input/output and stack-frame variables is switched off.
  Console breadcrumbs are dropped, and emails, long numbers and tokens are
  masked.
- **App (`lib/core/crash_reports.dart`):** the same, plus no screenshots, no
  printed lines and no tap breadcrumbs.

In Sentry, under each project's **Settings → Security & Privacy**, also turn
on "Data Scrubber", "Use Default Scrubbers" and "Prevent Storing of IP
Addresses".

## 5. Telegram relay

The relay is a Cloudflare Worker in `ops/alert-relay`. Neither Sentry nor
Axiom posts to Telegram, so both send it their webhooks. It also checks
`/readyz` every minute, from outside Fly.

1. In Telegram, message **@BotFather** with `/newbot` and keep the token.
   Add the bot to your alerts group (or message it), then open
   `https://api.telegram.org/bot<TOKEN>/getUpdates` in a browser and copy
   `chat.id`.
2. Deploy the relay:
   ```sh
   cd ops/alert-relay
   npx wrangler kv namespace create STATE   # paste the id into wrangler.toml
   npx wrangler secret put RELAY_SECRET       # a long random string
   npx wrangler secret put TELEGRAM_BOT_TOKEN
   npx wrangler secret put TELEGRAM_CHAT_ID
   npx wrangler secret put RESEND_API_KEY     # for emailed uptime alerts
   npx wrangler secret put ALERT_EMAIL_TO     # your address
   npx wrangler deploy
   ```
   `ALERT_EMAIL_FROM` must be on a domain verified in Resend.
3. The two webhook addresses are then
   `https://studafy-alert-relay.studafy.workers.dev/sentry/<RELAY_SECRET>` and
   `.../axiom/<RELAY_SECRET>`. Both are kept in `.env.hosted`
   (`ALERT_WEBHOOK_SENTRY_URL`, `ALERT_WEBHOOK_AXIOM_URL`).

Deployed 2026-10-03 on the `studafy.workers.dev` subdomain. Until production
is live it watches the Fly test copy's `/readyz`.

An outage alerts once when it starts and once when it ends: two failed
checks 10 seconds apart count as down.

## 6. The alerts

Every alert goes to **email and Telegram**.

### Sentry

Each project → **Alerts → Create alert → Issues**:

| Alert | When | Actions |
|---|---|---|
| New error | A new issue is created | Email (you), and the webhook |
| Error spike | An issue is seen more than 50 times in 1 hour | Email, and the webhook |

The webhook comes from **Settings → Developer Settings → Custom
Integration** (internal), with its webhook URL set to the relay's `/sentry/`
address and "Alert Rule Action" on. Then choose it as an action in each rule.

### Axiom

Create two notifiers: **Email** (you), and **Custom webhook** pointing at
the relay's `/axiom/` address. Then create these as **threshold monitors**
on `studafy-production`, each notifying both.

The shipper stores each line in `message`, so the queries parse it first. If
Axiom already shows the fields as columns, drop the `extend` line and use
the fields directly.

**API server errors.** Above 5 in 5 minutes, checked every minute:

```kusto
['studafy-production']
| extend m = parse_json(message)
| where m.service == "api" and m.event == "http_request_completed"
    and toint(m.status) >= 500
| summarize count() by bin_auto(_time)
```

**API slow.** Above 20 in 10 minutes. Slow requests are never sampled, so
this count is exact:

```kusto
['studafy-production']
| extend m = parse_json(message)
| where m.service == "api" and m.event == "http_request_completed"
    and toint(m.duration_ms) >= 2000
| summarize count() by bin_auto(_time)
```

**Notifications stuck.** Above 0 in 10 minutes:

```kusto
['studafy-production']
| extend m = parse_json(message)
| where m.event == "outbox_backlog" and toint(m.oldest_pending_seconds) > 300
| summarize count() by bin_auto(_time)
```

**Uploads failing to scan.** Above 0 in 15 minutes:

```kusto
['studafy-production']
| extend m = parse_json(message)
| where m.event == "file_scan_backlog" and toint(m.scan_dead_letters) > 0
| summarize count() by bin_auto(_time)
```

**Worker silent.** Below 1 in 10 minutes. The worker logs a backlog
heartbeat every minute, so silence means it is down:

```kusto
['studafy-production']
| extend m = parse_json(message)
| where m.service == "worker" and m.event == "outbox_backlog"
| summarize count() by bin_auto(_time)
```

**API down** is the relay's uptime check (section 5). Errors that are not
patterns (a crash, a job that gave up) come from Sentry.

## 7. Check it works

- `curl https://api.studafy.com/readyz` returns 200.
- In Axiom, `['studafy-production'] | take 20` shows recent lines from both apps.
- Send a test from Sentry's alert rule ("Send Test Notification"): it arrives
  by email and in Telegram.
- `fly scale count 0 --config fly.api.toml` for two minutes: Telegram and
  email say the API is down. Scale back up: they say it recovered.

## Cost at launch

Fly about $10–20 a month (one warm API machine, the worker, the shipper).
Sentry, Axiom, Cloudflare and Telegram are free at this size. See the cost
estimate in ADR-0035.
