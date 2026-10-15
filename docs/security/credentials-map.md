# Where each credential lives

`docs/planning/instructions.md` §22 is the register of *what* credentials
exist. This is the operational companion: **where each one is kept**, **who
reads it**, and **what is still to obtain**.

Updated 2026-10-12 (launch plan 7.2). The previous version (2026-09-19)
described a local-only prototype; since then the test copy runs on Fly and
Supabase (Frankfurt), AI is back behind its own switch (ADR-0037), and alerts,
logs, backups and the legal site exist.

**Never** commit a credential, paste one into a chat, a ticket or a shell
history, or put a server secret in a Flutter dart-define. Fly secrets go in
with `fly secrets import < file` from a file outside the repository, deleted
afterwards (`docs/deployment/fly-io.md`).

## The places

| Place | Holds | Committed? |
|---|---|---|
| Fly secrets (`studafy-api-test`, `studafy-worker-test`; production `studafy-api`, `studafy-worker`) | API and worker runtime secrets | Never |
| Fly secrets (`studafy-scanner-test`; production `studafy-scanner`) | The scanner's bearer key | Never |
| Fly secrets (`studafy-log-shipper`) | Axiom ingest and Fly read tokens | Never |
| Cloudflare Worker secrets (`studafy-alert-relay`) | Alert relay webhook secret, Telegram, Resend | Never |
| GitHub Actions environment `backups` (usable from `main` only) | Backup database login, storage key | Never |
| `~/studafy-backup.key` + the owner's Apple Passwords | The **private** key that decrypts backups | Never; an offline USB copy is still to do |
| `.env.hosted` (repo root, ignored, owner-only) | Hosted test credentials for `bun run dev:hosted` on the Mac | No |
| `.env` (repo root, ignored) | Local API and worker: local database, Redis, local keys | No |
| `supabase/.env` (ignored) | OAuth provider credentials for the **local** Supabase stack | No |
| `config/dart-defines.*.json` (ignored; `.example` committed) | Flutter **public** settings only: API URL, Supabase URL and publishable key, Sentry DSN, policy URLs | No |
| `sentry.properties` (repo root, ignored) | Sentry auth token for uploading app debug symbols | No |
| Supabase dashboard | OAuth providers (Google, Microsoft, Apple) for the hosted projects | — |

## In use now (test copy; the same names in production)

### API (`fly.api.toml` / `fly.test.api.toml`)

| Secret | What | Notes |
|---|---|---|
| `DATABASE_URL` | Pooler connection as `studafy_api_runtime` | Production refuses `postgres` (ADR-0041). The runtime role passwords are still to be set by the owner |
| `DATABASE_CA_CERT` | Supabase root CA | Verifies the database certificate |
| `REDIS_URL` | Redis | Production requires `rediss://` with a password; the test copy is still plaintext (owner to move) |
| `SUPABASE_URL`, `SUPABASE_SERVICE_ROLE_KEY` | Storage and admin calls | Server only, never in the app |
| `API_CURSOR_SIGNING_KEY`, `RATE_LIMIT_HMAC_SIGNING_KEY`, `CLASS_JOIN_CODE_KEY`, `FILE051_DELIVERY_SIGNING_KEY` | One random key per purpose | `openssl rand -hex 32`, all different |
| `TURNSTILE_SITE_KEY`, `TURNSTILE_SECRET` | Cloudflare Turnstile (parent looks up a student) | |
| `AI_API_KEY` (+ `AI_BASE_URL`, `AI_MODEL`) | Together AI | The study helper runs whenever this is set, whatever `AI_LESSON_TOOLS_ENABLED` says. Needs the provider DPA and the DPIA before real students (ADR-0037) |
| `SENTRY_DSN` | Sentry project `studafy-backend`, EU | Once PR #38 is merged, releases are tagged per deploy (`SENTRY_RELEASE` optional; Fly's deployment tag otherwise) |

### Worker (`fly.worker.toml` / `fly.test.worker.toml`)

| Secret | What | Notes |
|---|---|---|
| `DATABASE_URL`, `DATABASE_CA_CERT`, `REDIS_URL`, `SUPABASE_URL`, `SUPABASE_SERVICE_ROLE_KEY`, `SENTRY_DSN` | As the API, with `studafy_worker_runtime` | |
| `MALWARE_SCANNER_API_KEY` (+ `MALWARE_SCANNER_URL`) | File scanning by the self-hosted ClamAV scanner (below) | The key is the scanner's `SCANNER_API_KEY`. The URL is reachable only over Fly's private network: test `http://studafy-scanner-test.internal:8080/scan` (a secret there); production `http://studafy-scanner.internal:8080/scan`, set in `fly.worker.toml`, not a secret. A production worker refuses to start without both |
| `TELEGRAM_BOT_TOKEN`, `TELEGRAM_CHAT_ID` (+ `QUEUE_ALERTS_ENABLED=true`) | Background-work alerts (launch plan 4.7, PR #38) | The alert relay's bot can be reused. Off on the test copy until set; `fly.worker.toml` turns them on, so the production worker needs both |
| `AI_API_KEY` | Reading scanned teacher files (with `AI_MATERIAL_INDEX_ENABLED`) | Same provider and conditions as the API |

### Malware scanner (`fly.scanner.test.toml` / `fly.scanner.toml`)

Self-hosted ClamAV (`infra/scanner/`, PR #50): `studafy-scanner-test` and,
in production, `studafy-scanner` run on Fly's private network only and have
no IP addresses. Each has its own key.

| Secret | What | Notes |
|---|---|---|
| `SCANNER_API_KEY` | The bearer key `POST /scan` requires | `openssl rand -hex 32`, at least 32 characters or the scanner refuses to start. The same value is the worker's `MALWARE_SCANNER_API_KEY`; rotate both together (`fly secrets import --stage` on each, deploy the scanner, then `fly secrets deploy` the worker) |

Production's app, `studafy-scanner` (`fly.scanner.toml`), is configured but
not yet created; the order is in `docs/deployment/fly-io.md`, "Production
deploy checklist".

### Logs, alerts, backups, legal site

| Credential | Where | What |
|---|---|---|
| `ACCESS_TOKEN` (`fly tokens create readonly`), `HTTP_TOKEN` (Axiom ingest token for `studafy-production`, EU) | Fly secrets, `studafy-log-shipper` | Ships every app's logs to Axiom |
| `RELAY_SECRET`, `TELEGRAM_BOT_TOKEN`, `TELEGRAM_CHAT_ID`, `RESEND_API_KEY`, `ALERT_EMAIL_TO` | Cloudflare Worker secrets, `studafy-alert-relay` | Sentry and Axiom webhooks and the uptime check, to Telegram and email (`ops/alert-relay`) |
| Webhook URLs (`ALERT_WEBHOOK_SENTRY_URL`, `ALERT_WEBHOOK_AXIOM_URL`) | `.env.hosted` | They contain `RELAY_SECRET` |
| `BACKUP_DATABASE_URL` (secret), `BACKUP_AGE_RECIPIENTS` (variable), `SUPABASE_URL` and `SUPABASE_SERVICE_ROLE_KEY` (with `BACKUP_INCLUDE_STORAGE`) | GitHub environment `backups` | Daily encrypted backup with files (`docs/deployment/backups.md`) |
| Cloudflare login (`npx wrangler login`) | The owner's machine | Deploys the alert relay, and the legal site once PR #37 is merged and approved (`docs/deployment/legal-site.md`) |
| Sentry auth token | `sentry.properties` | Debug-symbol upload for release builds (not yet wired into CI) |

### The app (public by design)

| Setting | Notes |
|---|---|
| `STUDAFY_API_URL`, `SUPABASE_URL`, `SUPABASE_PUBLISHABLE_KEY`, `APP_ENV` | Public. RLS and the API are the controls |
| `SENTRY_DSN` (project `flutter`) | Public by design; personal data is off |
| `STUDAFY_PRIVACY_URL`, `STUDAFY_TERMS_URL` | The legal site's `/privacy` and `/terms` (PR #37) |
| `PUSH_ENABLED` and `FIREBASE_*` | Firebase's app config; not a secret |

## Local development

| Variable | Value |
|---|---|
| `DATABASE_URL` | `postgresql://postgres:postgres@127.0.0.1:54322/postgres` (the local stack) |
| `REDIS_URL` | `redis://127.0.0.1:6379` (`bun run dev:stack`) |
| `SUPABASE_URL` | `http://127.0.0.1:54321` |
| Signing keys | Generate locally; development mints an ephemeral rate-limit key without one |
| Google / Microsoft OAuth | `supabase/.env`, redirect `http://127.0.0.1:54321/auth/v1/callback` |

Tests that write fixtures run on a **throwaway** stack, never the local
database or the hosted one (`handoff.md`).

**BullMQ needs no credential of its own**: `REDIS_URL` is its whole
configuration.

## Still to obtain

| Credential | Blocked by / needed for |
|---|---|
| Runtime role passwords (`studafy_api_runtime`, `studafy_worker_runtime`) | Owner (SQL in `docs/deployment/fly-io.md`); production refuses `postgres` |
| A `rediss://` Redis | Owner; production refuses plaintext Redis |
| Production malware scanner: create `studafy-scanner` from `fly.scanner.toml` and give it its own key | Before the production worker (launch plan C11); a production worker refuses to start without one |
| Apple: Sign in with Apple, APNs key, App Store Connect API key (`.p8`, downloads once), store billing (`APPLE_*`) | The Apple Developer account (stage 5) |
| Google Play: upload keystore, Play service account (`GOOGLE_SERVICE_ACCOUNT_JSON`), Pub/Sub (`GOOGLE_PUBSUB_*`) | The app ID decision (Y5), then the Android track |
| FCM server credentials (`FCM_PROJECT_ID`, `FCM_SERVICE_ACCOUNT_JSON`) | Firebase project for push (`docs/deployment/push-notifications.md`) |
| Resend for users' email (`RESEND_API_KEY`, `EMAIL_FROM_ADDRESS`) | A verified sending domain |
| Google Calendar (`GOOGLE_CALENDAR_SERVICE_ACCOUNT_JSON`, `GOOGLE_CALENDAR_ORGANIZER_EMAIL`) | Workspace with domain-wide delegation and its processing terms |

## Cleanup still owed

- Delete the AWS IAM key (AWS is no longer used; ADR-0035).
- In the suspended `studafy-api` Fly app, revoke the stored `FLY_API_TOKEN`
  and unset unused secrets; destroy the stray `studafy` app.
- Delete the uncommitted `.github/workflows/fly-deploy.yml`.

## Rotation

Any credential that has passed through a chat message, a screenshot, a ticket
or a shared document is disclosed: rotate it. Rotation is cheap before a
credential is wired to anything and disruptive afterwards.

Azure client secrets expire on a schedule chosen at creation (24 months at
most), and expiry shows only as sign-in breaking: record the date.
