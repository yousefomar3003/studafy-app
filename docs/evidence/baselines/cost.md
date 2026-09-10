# Cost baseline

ARC-001 deliverable. Evidence date: 2026-09-10.

## Current state

| Resource | Cost | Basis |
|---|---|---|
| Supabase project `eamewgaptdfqzpmayavx` (synthetic, empty) | $0 | Free-tier project; zero users/rows/objects; only contained smoke traffic |
| Local development (Docker stack, CI minutes) | $0 material | Self-hosted/local; CI uses free-tier GitHub Actions runners with read-only permissions |
| Store products, signing, push, AI providers, Cloudflare, Redis | $0 | None provisioned (environment matrix) |

## Forecast boundary

No meaningful cost model exists yet because there is no usage: the audit
requires forecasting at current, 10x, and next launch-stage cohorts from
**observed active users and event rates**, which requires a pilot with
synthetic-then-approved school data (Phase 7) and the observability pipeline
(Phase 6, OPS-090). Per-tenant/provider cost tracking is registered as a
Phase 6 requirement, not a current claim.

## Decision-log linkage

Production provisioning (and therefore first real cost) is blocked by
ADR-0005 (region/residency) and ADR-0007 (RTO/RPO) per the decision log.
