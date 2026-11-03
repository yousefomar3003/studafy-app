# Launch-day cutover

The order for moving Studafy from the test copy to production on launch day,
the owner's inputs, and how to roll back. It ties together:

- `scripts/production/cutover.ts`: creates the production Fly apps, imports
  their secrets, deploys scanner, converter, worker and API in order with
  health checks, and stops the test copy. A dry run unless `--execute`.
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
before real users arrive. The API is served at `api.studafy.com` (DL-067):
since 2026-11-03 studafy.com's DNS is on Vercel (nameservers
`ns1.vercel-dns.com` and `ns2.vercel-dns.com`), and `api` is a plain DNS
record pointing at Fly, with no Cloudflare proxy in front (DL-079).
Cloudflare is used only for Turnstile, the alert relay Worker, the backups
in R2 and a fallback copy of the legal site.

Nothing here has been run. Every step that touches Fly, Vercel, the stores
or the database is one approval: Claude shows the exact command (the dry
run prints them all), the owner says "go", Claude runs it and shows the
result. Secret values never appear in chat, in a command line or in the
scripts' output.

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
| Converter key | `openssl rand -hex 32` (at least 32 characters, or the converter refuses to start) | `CONVERTER_API_KEY`, one line | converter; the worker gets the same value under the same name |
| **Turnstile** | Cloudflare Turnstile: the real widget, whose Hostname management lists `studafy.com` (which covers `api.studafy.com`) (C9) | `TURNSTILE_SITE_KEY`, `TURNSTILE_SECRET` | API |
| Sentry | Project `studafy-backend` (EU) DSN | `SENTRY_DSN` | API, worker |
| Telegram | The alert relay's bot and chat (`fly-io.md` §5) | `TELEGRAM_BOT_TOKEN`, `TELEGRAM_CHAT_ID` | worker |
| **AI key** | Together AI. Required: AI is on from launch (DL-062) | `AI_API_KEY` | API, worker |
| **Resend** (optional) | A verified sending domain on studafy.com | `RESEND_API_KEY`, `EMAIL_FROM_ADDRESS` | worker |
| **Firebase** (optional) | The push project (`docs/deployment/push-notifications.md`) | `FCM_PROJECT_ID`, `FCM_SERVICE_ACCOUNT_JSON` | worker |
| **Billing** (optional) | App Store Connect and Play Console (C6, C15). For the App Store, `APPLE_ENVIRONMENT=Production` (never `Sandbox` here). For Play, `GOOGLE_PACKAGE_NAME=com.studafy.light`, `GOOGLE_PUBSUB_SERVICE_ACCOUNT_EMAIL=studafy-pubsub-push@studafy-lite.iam.gserviceaccount.com` and `GOOGLE_PUBSUB_AUDIENCE=https://api.studafy.com/webhooks/google` (step 12) | the full `APPLE_*` set and/or the full `GOOGLE_*` set (`PAY071_ENVIRONMENT` is in the Fly configs, not here) | API, worker |
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
contract also requires `TURNSTILE_ENABLED=true`). `TURNSTILE_HOSTNAMES`
stays `"api.studafy.com"` in `fly.api.toml`: it is the host the widget page
is served from, which the widget's `studafy.com` entry covers.

The converter's address is configuration, not a secret: `CONVERTER_URL =
"http://studafy-converter.internal:8080"` in `fly.worker.toml`, on Fly's
private network like the scanner's. Studafy AI Marking is on from launch
(DL-079): `MARKING_SUGGESTIONS_ENABLED = "true"` in `fly.api.toml` and
`fly.worker.toml`, and the migration
`202611030070_list_ai_marking_for_launch.sql` lists
`studafy_ai_marking_monthly` on both stores; it uses the same `AI_API_KEY`.

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

**1-5. Apps, secrets, scanner, converter** (one approval per step):

```sh
bun --no-env-file scripts/production/cutover.ts --secrets ~/studafy-secrets/production.env --execute
```

It asks before each step, and:

1. `preflight`: `fly version`, `fly auth whoami`, which apps exist.
2. `create-apps`: `fly apps create studafy-scanner`, `studafy-converter` and
   `studafy-worker` (`studafy-api` exists, suspended since 2026-10-03, and is
   not recreated). `--org` defaults to `personal`.
3. `import-secrets`: `fly secrets import --app <app> --stage`, each app only
   its own names, then `fly secrets list` to confirm the names arrived.
   Staged secrets take effect with each app's deploy.
4. `deploy-scanner`: `fly deploy --config fly.scanner.toml`, then refuses to
   go on if the scanner has a public IP, and waits (up to 6 minutes) for its
   `/healthz` machine check while ClamAV loads.
5. `deploy-converter`: `fly deploy --config fly.converter.toml --ha=false`
   (one machine, as on the test copy: while it is away renditions wait and
   are retried), then the same checks: no public IP, and the `/healthz`
   machine check passing once LibreOffice's self-test has converted a CSV to
   a PDF (up to 6 minutes).

**6. Stop the test copy.** The script asks here even with `--yes`:
`fly scale count 0` for `studafy-worker-test` first, then `studafy-api-test`,
`studafy-scanner-test` and `studafy-converter-test`, and waits until no
machine is running. From now until step 8 no worker runs. The test copy's
app builds stop working.

**7. Remove the test schools** (another terminal; the cutover script waits
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

**8-9. Worker, then API.** Answer yes at the checkpoint (or resume with
`--from deploy-worker`):

8. `deploy-worker`: `fly deploy --config fly.worker.toml`, then waits for
   `worker_ready` in `fly logs`, and stops on `database_privileged_role`,
   `redis_plaintext_remote` or a configuration refusal. Its start-up line
   shows `file051.documentConverterConfigured: true`.
9. `deploy-api`: `fly deploy --config fly.api.toml`, then waits for
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

**9b. Prove the scanner and the converter** (launch plan 4.4): an EICAR
test file is refused and a clean PDF passes, uploaded through production;
then a small .docx attached to a lesson opens in the app as a PDF preview
(`fly logs --app studafy-worker` shows the rendition `ready`).

**10. Domain (owner, in Fly and Vercel; printed by the script, not run).**
studafy.com's DNS is on Vercel, where the website (project `waitlist-app`)
and the legal site (project `studafy-legal`) already live:

1. `fly certs add api.studafy.com --app studafy-api`. It prints the records
   Fly needs.
2. Vercel → **Domains** → `studafy.com` → **DNS records**: add what it
   printed, either `A` and `AAAA` records for `api` to Fly's addresses, or
   `CNAME api → studafy-api.fly.dev`; plus the `_acme-challenge.api` CNAME
   it printed, so Fly can issue the certificate. If an old `api` record is
   still there (the Cloudflare Tunnel to the Mac,
   `docs/deployment/studafy-domain.md`), remove it first. Leave every other
   record (the website, `legal`, `app`, the email records) as it is.
3. `fly certs check api.studafy.com --app studafy-api` until the certificate
   is issued.
4. `https://api.studafy.com/readyz` returns 200.

There is no Cloudflare proxy in front of the API, so there is no SSL/TLS
mode, WAF rule or origin lock to set: `ORIGIN_REQUIRE_CLOUDFLARE` stays
`"false"` (on, it would refuse every request), and `CLIENT_IP_SOURCE =
"fly"` keys rate limits on Fly's own `Fly-Client-IP` header, which a caller
cannot write. Both are pinned by `scripts/fly-config.test.ts`. The API's own
rate limits and Turnstile are the edge protection.

**11. Uptime alert to production.** `ops/alert-relay/wrangler.toml` still
watches the test copy (`UPTIME_URL =
"https://studafy-api-test.fly.dev/readyz"`). A reviewed PR changes it to
`https://api.studafy.com/readyz`; deploy the relay (`cd ops/alert-relay &&
npx wrangler deploy`) only once step 10 answers, or it reports an outage at
once. Then send a test alert from the deployed worker
(`docs/deployment/queue-alerts.md`).

**12. Store notifications to production** (owner, in the consoles; once
step 10 answers). Billing runs only with a store's complete key set in the
secrets file, and its server notifications must reach production:

1. **App Store.** App Store Connect → the app → **App Information** → **App
   Store Server Notifications** → **Production Server URL**:
   `https://api.studafy.com/webhooks/apple`, **Version 2**. The Sandbox
   Server URL may keep pointing at the test copy. The App Store secrets in
   the file use `APPLE_ENVIRONMENT=Production` (the test copy's are
   `Sandbox`): the API and worker verify Apple's signed data for that one
   environment, and the dry run warns about any other value. Open question
   for the owner: App Review buys in Apple's sandbox with the production
   build, and the verifier has no sandbox fallback today
   (`packages/infrastructure/src/billing/appleVerifier.ts`), so a
   reviewer's purchase would be refused (DL-079).
2. **Google Play.** Google Cloud project `studafy-lite` → **Pub/Sub** →
   **Subscriptions** → **Create subscription**, mirroring the test copy's
   `play-billing-to-test-api`:
   - name `play-billing-to-production-api`, topic `play-billing` (the one
     Play Console's real-time developer notifications publish to);
   - delivery type **Push**, endpoint
     `https://api.studafy.com/webhooks/google`;
   - **Enable authentication**, service account
     `studafy-pubsub-push@studafy-lite.iam.gserviceaccount.com`, audience
     `https://api.studafy.com/webhooks/google` (exactly the endpoint).

   The same values are the secrets `GOOGLE_PUBSUB_SERVICE_ACCOUNT_EMAIL` and
   `GOOGLE_PUBSUB_AUDIENCE`. The API's start-up line reports
   `googlePushAudienceMatchesRoute: true`; with `false` every Play
   notification is refused with 403. Then **Send test notification** in Play
   Console → Monetization setup and see it accepted in `fly logs --app
   studafy-api`. `play-billing-to-test-api` can stay: while the test copy is
   stopped its pushes fail and Pub/Sub drops them after its retention.

**13. Store builds** (DL-069: none may be uploaded before step 10 answers).
The release apps are built from `config/dart-defines.production.json`, which
is git-ignored and never committed:

```sh
cp config/dart-defines.production.example.json config/dart-defines.production.json
```

Then fill the two placeholders in the copy, and nothing else:

- `SUPABASE_PUBLISHABLE_KEY`: Supabase dashboard → Project Settings → API
  Keys, the `sb_publishable_…` key of `cyrngoqnhqflzovlybbr` (publishable,
  never `sb_secret_` or the service-role key);
- `SENTRY_DSN`: the app's Sentry project DSN, or `""` for none.

The example already carries the launch values the production contract
(`lib/core/production_contract.dart`) requires: `APP_ENV` `production`,
`STUDAFY_API_URL` `https://api.studafy.com` (it must equal the API's
`FILE051_DELIVERY_PUBLIC_BASE_URL`, or the app refuses download links),
`STUDAFY_PRIVACY_URL` `https://legal.studafy.com/privacy`,
`STUDAFY_TERMS_URL` `https://legal.studafy.com/terms`, `TURNSTILE_ENABLED`
`true`, `APPLE_SIGN_IN_ENABLED` `true`. Push also needs the `FIREBASE_*`
defines (`push-notifications.md`). Build with the store script, which checks
the file against the contract first:

```sh
scripts/release/build-store.sh ios --build-number <N>
scripts/release/build-store.sh android --build-number <N>
```

It runs `flutter build ipa --release
--dart-define-from-file=config/dart-defines.production.json` and `flutter
build appbundle --release
--dart-define-from-file=config/dart-defines.production.json` with the build
number; `<N>` is above every earlier upload to that store, including
TestFlight builds of the test copy. The Gradle task
graph and the Xcode "Release Defines Check" phase refuse a release build
whose defines break the contract, however it is started.

**14. Checks.** Go through `docs/deployment/production-features.md`,
"After the deploy", with a build from step 13. Sign in with a real account
and with a reviewer account; `['studafy-production'] | take 20` in Axiom
shows `api` and `worker` lines; a Sentry "Send Test Notification" reaches
Telegram and email.

**15. Afterwards.** Move the secrets file's values into the password manager
and delete the plaintext file; rotate anything that passed through a chat or
screenshot (C12, `docs/security/credentials-map.md`). Retention purges stay
off until launch plan D3 (`RETENTION_SCHEDULE_ENABLED`).

A step that fails prints why (names only) and how to resume:
`--from <step>` re-runs the preflight and continues from that step. Every
step is safe to repeat: existing apps are not recreated, secrets are
re-staged, deploys redeploy, stopped apps stay stopped.

## 3. Rollback

**Before DNS (steps 1-9).** Stop production's worker first, so two workers
never run at once, then start the test copy again:

```sh
fly scale count 0 --app studafy-worker --yes
fly scale count 0 --app studafy-api --yes      # if deployed
fly scale count 1 --app studafy-scanner-test --yes
fly scale count 1 --app studafy-converter-test --yes
fly scale count 1 --app studafy-api-test --yes
fly scale count 1 --app studafy-worker-test --yes
```

The test copy's builds work again. Removed test schools do not come back by
themselves: restore them from step 0b's backup if they are needed
(`docs/deployment/backups.md`).

**After DNS (steps 10-12).** Revert DNS: remove the `api` records (or point
them back where they were) in Vercel → Domains → `studafy.com` → DNS
records, set the relay's `UPTIME_URL` back to the test copy, and point the
App Store's Production Server URL and the Pub/Sub push subscription away
from production (or delete it). Then as above. Store builds already
released keep calling `api.studafy.com`, so roll back before step 13's
builds reach users.

**One app.** `fly releases --app <app>` and `fly deploy --image <previous
image> --config <its config>`. The scanner, converter or worker can also be
stopped with `fly scale count 0` without losing work: uploads stay
quarantined, renditions and jobs wait in Redis and the database.

**Wrong secret.** Fix the file and resume with `--from import-secrets`; a
deploy applies the staged values.
