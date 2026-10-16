# Studafy

Studafy is a school app for teachers, students and parents, on Android and
iOS, made by Studafy Limited (Ireland). Teachers run classes, share lessons,
set and mark work (online exams and paper), take attendance and message
families. Students hand in work, sit exams, keep notebooks and use AI study
tools. Parents follow their children, and can subscribe to Family+.

**Status (2026-10-12): not launched.** A test copy runs on Fly.io and Supabase
in Frankfurt. Since the release cutover (2026-10-17, ADR-0044) store builds
can be made in production mode with `scripts/release/build-store.sh
android|ios`, only with values that pass the production defines contract;
none may be uploaded until `https://api.studafy.com` is live (DL-069).
Android releases of the test copy (`APP_ENV=development`) remain available
for Play internal testing (ADR-0042).

**Start here:** [`handoff.md`](handoff.md) for where work stands, then
[`docs/planning/launch-work-plan.md`](docs/planning/launch-work-plan.md) for
what is left and who does it.

## What is in the repository

| Part | Where | What |
|---|---|---|
| Mobile app | `lib/`, `android/`, `ios/` | Flutter; English and Arabic (RTL) |
| API | `apps/api` | Bun and Hono; every request authorized in Postgres |
| Worker | `apps/worker` | Bun; BullMQ queues and Postgres-polled jobs: notifications, file scanning, material reading, billing, account deletion and export, backlog alerts |
| Shared packages | `packages/` | Contracts (OpenAPI, generated Dart client), config, database, domain, infrastructure, observability |
| Database | `supabase/` | Migrations (forward only), RLS, pgTAP tests, Edge Functions |
| Operations | `ops/` | Alert relay (Cloudflare Worker), legal site |
| Scripts | `scripts/` | Code generation, gates, capacity harness (`scripts/scale`), backups |

## Documentation

| Topic | Where |
|---|---|
| Decisions | `docs/adr/` (ADR-0001 to ADR-0041) and `docs/governance/decision-log.md` |
| Deploying (Fly, Sentry, Axiom, Telegram) | `docs/deployment/fly-io.md` |
| Backups | `docs/deployment/backups.md` |
| Subscriptions and store products | `docs/deployment/subscriptions.md` |
| Background-work alerts | `docs/deployment/queue-alerts.md` |
| Legal site (privacy, terms, deletion) | `docs/deployment/legal-site.md`; texts in `docs/legal/` |
| Store privacy answers | `docs/store/` |
| Credentials | `docs/security/credentials-map.md` |
| Capacity | `docs/capacity/` and `docs/operations/capacity.md` |
| Observability review | `docs/operations/observability-review-2026-10.md` |
| Readiness assessment and audits | `docs/evidence/launch-readiness/` |

The store answers, legal site, queue alerts, capacity report, observability
review and device tests arrive with pull requests #34 to #42 (2026-10-12).
Until those are merged, some of these paths exist only on their branches.

## Running it locally

```sh
bun install --frozen-lockfile
cp .env.example .env              # local values; the file is ignored
bun run dev:stack                 # local Redis
bunx supabase start               # local Postgres, Auth and Storage (port 54322)

# API and worker against the local stack
ENVIRONMENT=development API_PORT=8080 bun apps/api/src/index.ts
ENVIRONMENT=development bun apps/worker/src/index.ts
```

The app:

```sh
flutter pub get
flutter run                       # synthetic preview data, no server
cp config/dart-defines.development.example.json config/dart-defines.development.json
flutter run --dart-define-from-file=config/dart-defines.development.json
```

`APP_ENV=development` is needed for real sign-in; without it the app opens
its synthetic preview. Against the hosted test copy, use `bun run dev:hosted`
and `bun run dev:hosted:worker` (credentials in the ignored `.env.hosted`).

## Checks

```sh
bun run format:check && bun run lint && bun run typecheck
bun run generate:check            # OpenAPI and the Dart client match the contracts
bun run check:bounds && bun run check:migrations
bun test apps packages scripts ops
flutter analyze && flutter test
```

- **Integration tests need a database. Use a throwaway one.** Bun loads `.env`,
  so set `DATABASE_URL` to a throwaway Supabase stack explicitly. Never point
  tests at the local working database or the hosted one.
- **Scripts never assume the default stack outside CI.** The Supabase CLI's
  default stack (API 54321, database 54322) is the one `supabase status`
  reports, and on a developer's machine that is the working stack, not the
  throwaway one beside it. So when `CI` is unset, every script or suite that
  needs Auth or Storage takes its stack explicitly - `SUPABASE_WORKDIR=<stack
  dir>` (or `--workdir`) for `test:uploads:storage`, `test:delivery:*`,
  `test:auth:lifecycle`, `tools/ci/run-backend-device-tests.sh`, the reviewer
  provisioning and `write-synthetic-mobile-config.ts --local`;
  `AUTH_INTEGRATION_SUPABASE_URL` for the password-session suite;
  `DB_TYPES_DB_URL` for `generate:db-types` - and refuses (non-zero exit) or
  skips without it. CI has one stack on the default ports and needs none of
  this.
  The rule lives in `packages/test-support/src/localStack.ts`.
- **pgTAP suites** (`supabase/tests/`) commit fixtures. Run them in CI order on
  a freshly reset throwaway stack.
- **Device tests:** `tools/ci/run-device-tests.sh <device id>` runs the smoke
  tests on a simulator or emulator. CI runs them on both
  (`.github/workflows/device-tests.yml`).
- **Device tests with a backend:** the online exam and the coursework files
  tests sign in to a local API. See below.
- **Capacity:** `bun run scale:prepare`, `scale:bench` and `scale:http`
  (`docs/capacity/`).

CI (`.github/workflows/ci.yml`) runs on pull requests to `main` and on
`main`. It runs every gate, all pgTAP suites, secret and dependency scans, and
an Android debug build. It deploys nothing.

### Device tests with a local backend

`integration_test/exam_workflow_device_test.dart` and
`integration_test/coursework_files_device_test.dart` drive the real screens
against a local API, worker, Supabase and Redis. They sign in to a synthetic
school (`dev.teacher`, `dev.student`, `dev.student2` and `dev.parent` at
`synthetic.studafy.test`, plus "Dev Absentee", who has no account), which
`scripts/seed-device-tests.ts` creates.

```sh
bunx supabase db reset --workdir <throwaway stack dir>   # empty stack
SUPABASE_WORKDIR=<throwaway stack dir> \
REDIS_URL=redis://127.0.0.1:<throwaway redis port> \
tools/ci/run-backend-device-tests.sh <device id>
```

- The script starts the API (port 8090) and the worker with settings it sets
  itself. It never reads `.env`. It uses no AI key, seeds the school, runs
  both tests and stops the API and worker.
- Outside CI, `SUPABASE_WORKDIR` is required; the script refuses without it.
  (`SUPABASE_WORKDIR=.` names this checkout's own stack, port 54322. Use that
  only if it is a stack you can reset.)
- Use a Redis that no other local API or worker is using.
- The seed refuses any URL that is not `127.0.0.1` or `localhost`. It also
  refuses a database that holds any other school. Re-running it on the same
  stack is safe.
- The Dart defines, including the generated password, go to the ignored
  `build/device-tests/defines.json`. Logs and screenshots go to
  `device-logs/backend/`.
- CI runs the tests on an Android emulator in
  `.github/workflows/device-tests-backend.yml`, using a fresh stack each run.

## Store products

- **Students:** `studafy_plus_monthly` (US$3.99) and `studafy_max_monthly`
  (US$5.99).
- **Parents (Family+):** `studafy_family_plus_monthly` (US$2.99, up to 4
  children) and `studafy_family_plus_8_monthly` (US$4.99, up to 8).
- Apple and Google bill them; the server verifies every purchase. Lessons,
  notebooks, set work, marks and attendance are free
  (`docs/deployment/subscriptions.md`).

## Safety and records

- **Tenancy is enforced in the database:** a class's records are read and
  changed only by its own teachers. There is no school administrator role in
  this release.
- **Marks are drafts until the teacher publishes them.** A correction to a
  published mark keeps the old one, who changed it, when and why.
- **AI never marks work.** The study tools send only what the privacy policy
  lists, under a per-plan allowance and spending cap. They need the
  provider's data processing agreement and a DPIA before real students use
  them (ADR-0037).
- **Account deletion** needs a fresh sign-in and has a 14-day grace period.
  Deleting a parent deletes the child accounts they manage (PR #35). School records
  stay with the school. People can download a copy of their data.
- **Privacy:** GDPR, with the Irish Data Protection Commission as regulator,
  plus Jordan's Personal Data Protection Law. The texts are in `docs/legal/`
  and await legal review.
