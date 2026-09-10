# ADR-0005: Production region and data residency

Status: Deferred — blocks production provisioning, Phase 6 infrastructure, and
the Phase 7 pilot. Decision-log: DL-009. Date: 2026-09-10.

## Context

The only remote project (`eamewgaptdfqzpmayavx`) runs in AWS
`ap-northeast-1` (Tokyo) and contains synthetic data only. Studafy targets
Saudi schools; Saudi PDPL cross-border transfer assessment and hosting
constraints require qualified legal review (instructions.md explicitly marks
these as engineering prompts, not legal conclusions). ARC-001 requires the
region decision to be made or explicitly recorded as stopping later work.

## Decision

**Deferred.** Working assumptions until legal review:

- The production primary region hosts API, worker, Redis, and the primary
  Supabase project together in one approved region (instructions.md default).
- The current Tokyo synthetic project is not a production region commitment.
- Cross-border transfers (AI providers, Google Calendar, store verification,
  Cloudflare) must be inventoried in the threat model and assessed by counsel
  before any real student data flows.

## Consequences

- Phase 6 infrastructure selection and the Phase 7 pilot with approved school
  data **cannot start** until this ADR is decided.
- The data-flow inventory (`docs/inventory/data-flow-inventory.md`) flags every
  cross-border flow so the review has a complete input.
- No production Supabase project or paid infrastructure is provisioned in the
  meantime.
