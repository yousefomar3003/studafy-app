# ADR-0004: Environment matrix and separation

Status: Accepted (records current facts; not a deployment approval).
Date: 2026-09-10.

## Context

ARC-001 requires every environment and its owner to be known. As of 2026-09-10
only synthetic environments exist; no development, staging, or production
Supabase project has been created, and CI is deliberately read-only with no
deployment credentials.

## Decision

Record and maintain the environment matrix in
`docs/inventory/environment-matrix.md` as the single source of truth. Current
facts:

| Environment | Type | Exists | Data | Owner |
|---|---|---|---|---|
| Local disposable Supabase stack (CI and developer machines) | Ephemeral, Docker | Yes | Migrations + synthetic pgTAP fixtures only | Repository owner |
| Local synthetic Edge Function serving | Ephemeral | Yes | Synthetic values only | Repository owner |
| Remote synthetic Supabase project `eamewgaptdfqzpmayavx` ("studafy light", ap-northeast-1) | Remote | Yes | 8 migrations applied through `202609090004`; zero users/rows/objects; 2 contained functions deployed | Repository owner |
| Development | Remote | **No** | — | — |
| Staging | Remote | **No** | — | — |
| Production | Remote | **No** | — | — |

Rules:

- No production or real-data environment may be created until the Phase 0A
  evidence log is re-evidenced with named, separated owners and the deferred
  ADR-0005/0007/0008 decisions are resolved.
- Environment-specific configuration lives in each environment's secret
  manager; the repository holds only examples and non-secret dart-defines
  (`APP_ENV`, `SUPABASE_URL`, `SUPABASE_PUBLISHABLE_KEY`).
- `APP_ENV=production` intentionally blocks application startup (SEC-001).

## Consequences

- The "reconcile live schema with migrations" deliverable is satisfied against
  the synthetic remote project (read-only) plus the local disposable stack;
  production reconciliation is N/A until production exists.
- Creating a new environment requires updating the matrix and decision log
  first.
