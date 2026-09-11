# Studafy

Studafy is a Flutter school platform for teachers, parents, and students.
Supported platforms: Android and iOS. The repository is a contained
pre-production prototype: Supabase migrations, RLS, and Edge Functions exist,
but core feature screens still use the local synthetic SQLite preview, and the
only remote project in existence is synthetic and empty. Production is blocked
by the SEC-001 controls described in `docs/security/sec-001-containment.md`.

## Documentation

- Architecture decisions: `docs/adr/`
- System / data-flow / environment / data-classification inventories:
  `docs/inventory/`
- Governance and decision log: `docs/governance/`
- Phase 0 evidence (schema reconciliation, scans, baselines, smoke):
  `docs/evidence/`
- Current cross-phase verification and remaining gates:
  `docs/evidence/closing-verification-2026-09-10.md`
- Phase gates: `docs/security/sec-001-containment.md`,
  `docs/security/phase-0b-gate.md`

## Monorepo services (Phase 1A skeleton)

The repository root is a Bun workspace (`apps/*`, `packages/*`) alongside the
Flutter app, which stays at the root for now. Pinned toolchain and boundary
rules: `docs/adr/ADR-0011-monorepo-workspaces-and-toolchain.md`.

Flutter feature boundaries and the first typed vertical slice
(session + class read): `docs/adr/ADR-0012-flutter-feature-boundaries.md`.
Architecture is enforced by `dart run tools/check_dart_bounds.dart`.
The 2026-09-11 hotspot follow-up also separates startup, parent presentation,
teacher dashboard, preview SQLite modules, and Study Coach policy/adapters;
evidence is in `docs/evidence/phase-1b/hotspot-refactor-2026-09-11.md`.

The local-only DB-020 foundation is documented in ADR-0013, the schema data
dictionary, index catalogue, and `docs/evidence/phase-2a/`. It is not deployed
and does not activate Phase 2B policies or any production feature.

```sh
bun install --frozen-lockfile          # workspace install
cp .env.example .env                   # replace placeholders; file is ignored
bun run dev:stack                      # local Redis (Postgres = bunx supabase start, port 54322)
bun run format:check                   # deterministic TypeScript/JSON/YAML formatting
bun run lint                           # TypeScript lint
bun run generate:check                 # OpenAPI -> Dart client drift check
bun run generate:db-types:check        # local public schema -> TypeScript drift
bun run check:bounds                   # architecture boundary check
bun run typecheck                      # tsc for every workspace member
bun test apps packages                 # unit + integration tests (Redis/DB tests skip when unset)
ENVIRONMENT=development \
DATABASE_URL=postgresql://postgres:postgres@127.0.0.1:54322/postgres \
REDIS_URL=redis://127.0.0.1:6379 \
API_PORT=8080 bun apps/api/src/index.ts
ENVIRONMENT=development \
REDIS_URL=redis://127.0.0.1:6379 \
bun apps/worker/src/index.ts
```

The API exposes only `/healthz`, `/readyz` (reason codes), `/version`, and an
empty `/v1` router; production configuration fails closed. Containers:
`docker build -f apps/api/Dockerfile -t studafy-api .` (same for the worker,
non-root, pinned base).

## Run locally

```sh
flutter pub get
flutter run
```

Without Supabase defines, the app opens its synthetic preview experience. For
an authenticated synthetic-project development build, copy the sanitized
template and populate only its public project URL/key:

```sh
cp config/dart-defines.development.example.json \
  config/dart-defines.development.json
flutter run --dart-define-from-file=config/dart-defines.development.json
```

`APP_ENV=development` is mandatory for remote authentication. Omitting it
intentionally selects the isolated synthetic SQLite preview even when public
Supabase values are present.

Never put a Supabase service-role key, Calendar credential, AI provider secret,
or store verification secret in the application.

## Future backend deployment (not currently authorized)

The following is a later-phase checklist, not permission to deploy. The only
authorized remote environment so far is the contained synthetic project.

1. Link the explicitly approved Supabase project and apply every migration in
   `supabase/migrations` in filename order.
2. Configure `io.studafy.app://login-callback` as an allowed Supabase Auth
   redirect URL and configure Google, Microsoft, and Apple providers.
3. Keep the `private-school-files` storage bucket private. New uploads and AI
   grading remain disabled until immutable file ownership, scanning, and clean
   publication are implemented; do not restore the former path-signing flow.
4. Deploy the functions under `supabase/functions` and provide their server-side
   secrets. Google Meet creation requires a per-user Google token broker;
   purchase verification and AI generation require their corresponding trusted
   server endpoints.
5. Configure private Realtime channels for notifications, messages,
   publications, and meeting changes before enabling them for a pilot school.

The native OAuth callback is registered in AndroidManifest.xml and Info.plist.

## Store products

Parent Insights+ expects `studafy_parent_insights_monthly` in App Store Connect
and Google Play Console. The client never grants premium access from a local
purchase result: the receipt or purchase token must pass server verification,
which writes the `subscription_entitlements` record.

## Safety and records

- Students and verified guardians can read only authorized published records.
- Teachers can access only students enrolled in classes they own. Operational
  backend maintenance uses trusted service processes, not another app role.
- AI paper grading only creates proposals. A teacher reviews the result and a
  separate publish action is required before students or guardians see it.
- Grade suggestions, overrides, review, publication, guardian access changes,
  and deletion requests create audit records.
- Deletion uses recent authentication, an impact summary, typed confirmation,
  and a 14-day recoverable grace period.

Before production, configure the school's Saudi PDPL notices, lawful purposes,
retention periods, guardian processes, export/correction workflow, breach
procedure, and any cross-border transfer assessment with qualified counsel.

## Verification

```sh
flutter analyze
flutter test --concurrency=1
```

Database authorization tests are in `supabase/tests/`. Run them against a
disposable local stack (Docker required); never run authorization tests
against live student records:

```sh
bunx supabase start -x studio,imgproxy,inbucket,edge-runtime,logflare,vector,supavisor
bunx supabase db reset --local --no-seed
bunx supabase test db --local supabase/tests/containment.sql
bunx supabase test db --local supabase/tests/rls_access_seed.sql  # synthetic fixture + 8 RLS assertions
bunx supabase test db --local supabase/tests/db020_constraints.sql
DATABASE_URL=postgresql://postgres:postgres@127.0.0.1:54322/postgres \
  bun run test:db020:plans
```

CI (`.github/workflows/ci.yml`) runs the same checks read-only on every push,
including these pgTAP suites, gitleaks, and OSV scans. CI has no deployment
credentials and deploys nothing.
