# Environment matrix

ARC-001 deliverable: every known environment, owner, credential custody, and
data posture. Evidence date: 2026-09-10. This file records facts; ADR-0004
holds the rules. The authoritative decision log is
`docs/governance/decision-log.md`.

## Environments

| Environment | Location | Data | Owner | Credential custody | Notes |
|---|---|---|---|---|---|
| Local disposable Supabase stack | Docker on developer machine / CI runner | Migrations + synthetic pgTAP fixtures only; `--no-seed` | Repository owner (`@yousefomar3003`) | None (ephemeral JWT secret regenerated per stack) | Started with `bunx supabase start -x studio,imgproxy,inbucket,edge-runtime,logflare,vector,supavisor`; stopped with `--no-backup` |
| Local synthetic Edge Function serving | `bunx supabase functions serve` | Synthetic values from ignored `.env` | Repository owner | Local `.env` (gitignored; examples only in repo) | Never with real provider secrets |
| Remote synthetic Supabase project | `eamewgaptdfqzpmayavx` ("studafy light"), AWS ap-northeast-1, org `tsnrgtfplfwtmnhydaof` | 8 migrations applied; ephemeral authenticated smoke user deleted; zero remaining users/schools/profiles/objects | Repository owner | Owner's Supabase account; CLI state in `supabase/.temp/` is gitignored; fresh MFA/session review pending | The only remote project in existence; **not** a production region commitment (ADR-0005) |
| Development | — | — | — | — | Does not exist |
| Staging | — | — | — | — | Does not exist |
| Production | — | — | — | — | Does not exist; creation gated on Phase 0A re-evidence + ADR-0005/0007/0008 |

## Application runtime environments (`APP_ENV`)

| `APP_ENV` | Behaviour |
|---|---|
| `synthetic` (default) | Local seeded SQLite preview, yellow synthetic banner, no Supabase |
| `development` / `staging` | Require `SUPABASE_URL` + `SUPABASE_PUBLISHABLE_KEY` or startup is blocked |
| `production` | Startup blocked entirely (SEC-001 `ProductionReadinessBlockedPage`) |

Permitted dart-defines are exactly `APP_ENV`, `SUPABASE_URL`,
`SUPABASE_PUBLISHABLE_KEY` (see `docs/security/sec-001-containment.md`).
The ignored `config/dart-defines.development.json` is locally configured with
the synthetic public URL/publishable key and mode 0600; it contains no server
secret. The ignored root `.env` contains only disposable local API/worker
Postgres and Redis connection settings.

`allowsRemoteFileUploads` is `false` in every runtime environment. FILE-050
built the upload pipeline but did not switch it on; FILE-051 owns that.

### Server-only settings (FILE-050)

| Setting | Default | Notes |
|---|---|---|
| `FILE050_NEW_INTENTS_ENABLED` | `false` | API. Turning it off still allows completion, status reads and cleanup of already-issued sessions, so ingress can be stopped without stranding in-flight uploads |
| `FILE050_CLEANUP_ENABLED` | `false` | Worker. Requires `DATABASE_URL`, `SUPABASE_URL` and the service-role key, validated at startup |
| `SUPABASE_SERVICE_ROLE_KEY` | unset | **Server and worker only.** Never a dart-define. Held by one storage adapter and injected at the composition root; production fails closed if intents are enabled without it |

## CI (`ci.yml`, "CI (no deployment)")

Read-only permissions, no deployment credentials, no linked-project state,
all actions pinned by SHA. Jobs: Flutter quality + synthetic debug APK · Edge
Function quality (fmt/lint/check/test, bun audit) · local database
reset/lint/pgTAP · secret scan (tracked filenames + gitleaks over complete
bounded history) · OSV dependency scan. **No deploy job exists by design.**

## Provider consoles

| Provider | Console state |
|---|---|
| Supabase | One org, one synthetic project; owner-only access |
| App Store Connect / Google Play Console | No accounts, products, or signing credentials exist (ADR-0009/DL-015) |
| Google Cloud (Calendar/token broker) | Not provisioned; broker is a planned custom service |
| Study Coach / purchase verifier endpoints | Synthetic placeholders only |

## Rules

1. Update this file and the decision log **before** creating any new
   environment.
2. New environments start empty: fresh credentials, migrations replayed from
   zero; never copy data between environments.
3. Production creation requires: Phase 0A evidence re-recorded with named,
   separated owners; ADR-0005 (region), ADR-0007 (RTO/RPO), ADR-0008
   (retention/legal) decided; backup/restore plan approved.
