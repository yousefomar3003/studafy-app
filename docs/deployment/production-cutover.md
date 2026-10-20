# Launch-day cutover

The order for moving Studafy from the test copy to production on launch day,
the owner's inputs, and how to roll back. It ties together:

- `scripts/production/cutover.ts`: creates the production Fly apps, imports
  their secrets, deploys scanner, worker and API in order with health checks,
  and stops the test copy. A dry run unless `--execute`.
- `scripts/production/clean-test-data.ts` with
  `supabase/cutover/clean-test-data.sql`: removes the owner's test schools
  from the shared database. A dry run (rolled back) unless `--execute
  --confirm-schools <ids>`.
- `docs/deployment/fly-io.md`, "Production deploy checklist": what each Fly
  config already sets, and the per-app secrets.
- `docs/deployment/production-features.md`: every feature, whether it is on
  in production, waiting on a key, or off by decision, what turns it on, and
  how to check it after this cutover.

Why a cutover and not a fresh start: production uses the existing Frankfurt
Supabase project `cyrngoqnhqflzovlybbr` (DL-064), the one the test copy uses
today. Two workers draining one database's queues conflict, so the test apps
stop before the production worker starts, and the test schools are removed
before real users arrive. The API is served at `api.studafy.com` through
Cloudflare (DL-067).

Nothing here has been run. Every step that touches Fly, Cloudflare or the
database is one approval: Claude shows the exact command (the dry run prints
them all), the owner says "go", Claude runs it and shows the result. Secret
values never appear in chat, in a command line or in the scripts' output.

## 1. Owner's inputs (before the day)

All of them go in one file, `~/studafy-secrets/production.env`
(`chmod 600`; the scripts refuse a file others can read), in the format
`fly secrets import` reads: `NAME=value` per line, a multi-line value between
`"""` lines, no quotes around a single-line value. Tell Claude the file path,
never a value.

| Input | Where it comes from | Names in the file | Goes to |
|---|---|---|---|
| Runtime database logins | SQL editor, once: `alter role studafy_api_runtime login password '<generated>'` and the same for `studafy_worker_runtime` (`fly-io.md`, "Database roles"). Pooler URLs as `studafy_api_runtime.cyrngoqnhqflzovlybbr` and `studafy_worker_runtime.cyrngoqnhqflzovlybbr`, without `sslmode` | `API__DATABASE_URL`, `WORKER__DATABASE_URL` | API, worker |
| Supabase root CA | Dashboard → Database → SSL (the PEM the test apps already use) | `DATABASE_CA_CERT` | API, worker |
| Supabase project | Dashboard → API: URL and service-role key | `SUPABASE_URL`, `SUPABASE_SERVICE_ROLE_KEY` | API, worker |
| **Redis** | A TLS Redis with a password, AOF persistence every second and `noeviction` (Redis Cloud paid plan, or Upstash `eu-central-1`; `docs/security/ops061-operator-runbook.md` §3) | `REDIS_URL` (`rediss://…`) | API, worker |
| Signing keys | `openssl rand -hex 32`, four times, all different | `API_CURSOR_SIGNING_KEY`, `RATE_LIMIT_HMAC_SIGNING_KEY`, `CLASS_JOIN_CODE_KEY`, `FILE051_DELIVERY_SIGNING_KEY` | API |
| Scanner key | `openssl rand -hex 32` | `SCANNER_API_KEY` | scanner; the worker gets the same value as `MALWARE_SCANNER_API_KEY` |
| **Turnstile** | Cloudflare Turnstile: the real widget with `api.studafy.com` under Hostname management (C9) | `TURNSTILE_SITE_KEY`, `TURNSTILE_SECRET` | API |
| Sentry | Project `studafy-backend` (EU) DSN | `SENTRY_DSN` | API, worker |
| Telegram | The alert relay's bot and chat (`fly-io.md` §5) | `TELEGRAM_BOT_TOKEN`, `TELEGRAM_CHAT_ID` | worker |
| **AI key** | Together AI. Required: AI is on from launch (DL-062) | `AI_API_KEY` | API, worker |
| **Resend** (optional) | A verified sending domain on studafy.com | `RESEND_API_KEY`, `EMAIL_FROM_ADDRESS` | worker |
| **Firebase** (optional) | The push project (`docs/deployment/push-notifications.md`) | `FCM_PROJECT_ID`, `FCM_SERVICE_ACCOUNT_JSON` | worker |
| **Billing** (optional) | App Store Connect and Play Console (C6, C15) | the full `APPLE_*` set and/or the full `GOOGLE_*` set (`PAY071_ENVIRONMENT` is in the Fly configs, not here) | API, worker |
| Admin database login | The `postgres` session connection (direct, or pooler on :5432), only for the cleanup script | `ADMIN_DATABASE_URL` | not imported into any app |

The optional features are already switched on in the Fly configs
(DL-070): `NOTIFICATION_CHANNELS_ENABLED`, `PAY071_BILLING_ENABLED`,
`PAY071_ENVIRONMENT = "production"` and `PAY071_RECONCILIATION_ENABLED`, all
pinned by `scripts/fly-config.test.ts`. So each starts as soon as its keys
are in this file and the app is deployed: email with the Resend pair, push
with the Firebase pair, billing with one store's complete set. Without them
the apps start normally and the feature stays off: nothing is fanned out to
a channel without a sender, and no billing route is mounted (the app says
payments are not set up). The dry run warns when a store's set is
incomplete. A name in both a Fly config's `[env]` and this file is refused.
Names it does not import (such as `ADMIN_DATABASE_URL`) are listed by name,
never by value.

Turnstile is the exception: `TURNSTILE_ENABLED = "true"` stays a hard
requirement, and the API refuses to start without `TURNSTILE_SITE_KEY`,
`TURNSTILE_SECRET` and the `api.studafy.com` hostname (the production build
contract also requires `TURNSTILE_ENABLED=true`).

The per-app lists are pinned in `scripts/production/cutover.ts`
(`REQUIRED_SECRETS`, `OPTIONAL_SECRETS`) and by its test against the config
schema. The dry run checks the file the same way the API and worker check
themselves at start-up (runtime roles, `rediss://`, the CA, distinct keys),
so a file that would make an app refuse to start is refused before anything
runs.

## 2. The day, in order

Run everything from the repository root on an up-to-date `main`.

**0. Dry run.** Nothing is run; the output lists every step and command, and
whether the secrets file is complete:

```sh
bun --no-env-file scripts/production/cutover.ts --secrets ~/studafy-secrets/production.env
```

**0b. A fresh backup** before anything is deleted: run the backup workflow
(`gh workflow run backup.yml`, `docs/deployment/backups.md`) and wait for
its restore check to pass.

**1-4. Apps, secrets, scanner** (one approval per step):

```sh
bun --no-env-file scripts/production/cutover.ts --secrets ~/studafy-secrets/production.env --execute
```

It asks before each step, and:

1. `preflight`: `fly version`, `fly auth whoami`, which apps exist.
2. `create-apps`: `fly apps create studafy-scanner` and `studafy-worker`
   (`studafy-api` exists, suspended since 2026-10-03, and is not recreated).
   `--org` defaults to `personal`.
3. `import-secrets`: `fly secrets import --app <app> --stage`, each app only
   its own names, then `fly secrets list` to confirm the names arrived.
   Staged secrets take effect with each app's deploy.
4. `deploy-scanner`: `fly deploy --config fly.scanner.toml`, then refuses to
   go on if the scanner has a public IP, and waits (up to 6 minutes) for its
   `/healthz` machine check while ClamAV loads.

**5. Stop the test copy.** The script asks here even with `--yes`:
`fly scale count 0` for `studafy-worker-test` first, then `studafy-api-test`
and `studafy-scanner-test`, and waits until no machine is running. From now
until step 7 no worker runs. The test copy's app builds stop working.

**6. Remove the test schools** (another terminal; the cutover script waits
at its checkpoint):

```sh
# Every school: id, name, members, classes; the reviewer school is marked.
bun --no-env-file scripts/production/clean-test-data.ts --secrets ~/studafy-secrets/production.env

# What removing the chosen ones does: run in full, verified, rolled back.
bun --no-env-file scripts/production/clean-test-data.ts --secrets ~/studafy-secrets/production.env \
  --schools <id>,<id>

# Do it.
bun --no-env-file scripts/production/clean-test-data.ts --secrets ~/studafy-secrets/production.env \
  --execute --confirm-schools <id>,<id>
```

The owner chooses the schools: the synthetic and test ones. What happens to
them (all in one transaction, `supabase/cutover/clean-test-data.sql`):

- Each class is closed and purged by the retention schedule's own function.
- Each **test-only** account (every tie it has is to the named schools; not
  a platform operator; not a reviewer account) goes through the
  account-deletion executor exactly as an in-app deletion would: sign-in
  removed, profile de-identified, personal data erased; its email is free to
  sign up again. The dry run lists them with masked emails: check that your
  own account is not among them.
- The schools' remaining rows and the school rows go. Then their stored files
  are deleted through the Storage API (the list is saved first; a failed
  deletion is retried with `--delete-objects <file>`).
- It never touches another school, an account with a tie anywhere else, or
  `platform_operators`. Before committing it compares an md5 of every kept
  row (all other schools' rows, platform operators, kept accounts' profiles
  and logins) and refuses if anything differs.
- **"Cedar Grove Review School"** (the store reviewers' school) is refused
  unless `--include-reviewer-school` is also given. Keep it: App Review and
  Google Play sign in to it, and after cutover it is served by production.
- An active legal hold in a named school refuses the run; `--release-legal-holds`
  removes those holds with the school.

**7-8. Worker, then API.** Answer yes at the checkpoint (or resume with
`--from deploy-worker`):

7. `deploy-worker`: `fly deploy --config fly.worker.toml`, then waits for
   `worker_ready` in `fly logs`, and stops on `database_privileged_role`,
   `redis_plaintext_remote` or a configuration refusal.
8. `deploy-api`: `fly deploy --config fly.api.toml`, then waits for
   `https://studafy-api.fly.dev/readyz` to return 200. Optionally
   `fly scale count 4 --config fly.api.toml` (`fly-io.md`, "Scaling"), but
   only once the session pooler's Pool Size fits it: 4 machines × 10 is 40
   `studafy_api_runtime` connections (`fly-io.md`, "Database connection
   budget").

Both apps run through Supabase's session pooler (`DATABASE_POOLER_MODE =
"session"` in their Fly configs): the `API__DATABASE_URL` and
`WORKER__DATABASE_URL` pooler URLs may be on 6543 or 5432, and are moved to
5432. The preflight runs the production start-up checks, which refuse a
6543 URL on any host but `*.pooler.supabase.com`. Before the day, check the
project's Pool Size (Dashboard → Database settings → Connection pooling):
at least 10 for each role at one machine per app.

**9. Prove the scanner** (launch plan 4.4): an EICAR test file is refused and
a clean PDF passes, uploaded through production.

**10. Domain (owner, in Cloudflare and Fly; printed by the script, not run):**

1. If `api.studafy.com` still has the old Cloudflare Tunnel route to the
   Mac (`docs/deployment/studafy-domain.md`), remove that route and record.
2. `fly certs add api.studafy.com --app studafy-api`.
3. Cloudflare DNS, zone `studafy.com`: `CNAME api → studafy-api.fly.dev`,
   **Proxied**; plus the `_acme-challenge` CNAME that `fly certs add` prints,
   **DNS only**, so Fly can issue the certificate behind the proxy.
4. Cloudflare SSL/TLS mode **Full (strict)**; the WAF and rate rules (C8).
5. `fly certs check api.studafy.com --app studafy-api` until issued;
   `https://api.studafy.com/readyz` returns 200.
6. A reviewed PR sets `ORIGIN_REQUIRE_CLOUDFLARE = "true"` in `fly.api.toml`
   and `scripts/fly-config.test.ts`; merge, `fly deploy --config
   fly.api.toml`. Check: `studafy-api.fly.dev` is refused, `api.studafy.com`
   answers.

**11. Uptime alert to production.** `ops/alert-relay/wrangler.toml` still
watches the test copy (`UPTIME_URL =
"https://studafy-api-test.fly.dev/readyz"`). A reviewed PR changes it to
`https://api.studafy.com/readyz`; deploy the relay (`cd ops/alert-relay &&
npx wrangler deploy`) only once step 10 answers, or it reports an outage at
once. Then send a test alert from the deployed worker
(`docs/deployment/queue-alerts.md`).

**12. Checks.** Go through `docs/deployment/production-features.md`,
"After the deploy". Sign in with a real account and with a reviewer account;
`['studafy-production'] | take 20` in Axiom shows `api` and `worker` lines;
a Sentry "Send Test Notification" reaches Telegram and email. The release
app's `STUDAFY_API_URL` is `https://api.studafy.com`, which must equal
`FILE051_DELIVERY_PUBLIC_BASE_URL` or the app refuses download links.

**13. Afterwards.** Move the secrets file's values into the password manager
and delete the plaintext file; rotate anything that passed through a chat or
screenshot (C12, `docs/security/credentials-map.md`). Retention purges stay
off until launch plan D3 (`RETENTION_SCHEDULE_ENABLED`).

A step that fails prints why (names only) and how to resume:
`--from <step>` re-runs the preflight and continues from that step. Every
step is safe to repeat: existing apps are not recreated, secrets are
re-staged, deploys redeploy, stopped apps stay stopped.

## 3. Rollback

**Before DNS (steps 1-8).** Stop production's worker first, so two workers
never run at once, then start the test copy again:

```sh
fly scale count 0 --app studafy-worker --yes
fly scale count 0 --app studafy-api --yes      # if deployed
fly scale count 1 --app studafy-scanner-test --yes
fly scale count 1 --app studafy-api-test --yes
fly scale count 1 --app studafy-worker-test --yes
```

The test copy's builds work again. Removed test schools do not come back by
themselves: restore them from step 0b's backup if they are needed
(`docs/deployment/backups.md`).

**After DNS (steps 10-11).** Revert DNS: remove the `api` CNAME (or point it
back where it was) in Cloudflare, set `ORIGIN_REQUIRE_CLOUDFLARE` back to
`"false"` if it was switched, and set the relay's `UPTIME_URL` back to the
test copy. Then as above.

**One app.** `fly releases --app <app>` and `fly deploy --image <previous
image> --config <its config>`. The scanner or worker can also be stopped
with `fly scale count 0` without losing work: uploads stay quarantined, jobs
wait in Redis and the database.

**Wrong secret.** Fix the file and resume with `--from import-secrets`; a
deploy applies the staged values.
