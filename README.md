# Studafy

Studafy is a school app for teachers, students and parents, on Android and
iOS, made by Studafy Limited (Ireland). Teachers run classes, share lessons,
set and mark work (online exams and paper), take attendance and message
families. Students hand in work, sit exams, keep notebooks and use AI study
tools. Parents follow their children, and can subscribe to Family+.

**Status (2026-10-12): not launched.** A test copy runs on Fly.io and Supabase
in Frankfurt. Release builds are blocked on purpose (SEC-001) until the
launch plan lifts them; the one exception is an Android release of the test
copy (`APP_ENV=development`) for Play internal testing, signed with the
owner's upload key (ADR-0042).

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
- **pgTAP suites** (`supabase/tests/`) commit fixtures. Run them in CI order on
  a freshly reset throwaway stack.
- **Device tests:** `tools/ci/run-device-tests.sh <device id>` runs the smoke
  tests on a simulator or emulator. CI runs them on both
  (`.github/workflows/device-tests.yml`).
- **Capacity:** `bun run scale:prepare`, `scale:bench` and `scale:http`
  (`docs/capacity/`).

CI (`.github/workflows/ci.yml`) runs on pull requests to `main` and on
`main`. It runs every gate, all pgTAP suites, secret and dependency scans, and
an Android debug build. It deploys nothing.

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
