# ADR-0005: Production region and data residency

Status: **Decided in part** by [ADR-0035](ADR-0035-fly-sentry-axiom-and-alerts.md)
(2026-10-02): everything runs in Frankfurt, Germany (EU). The cross-border
transfer assessment for each provider remains open (see the update below).
Originally Deferred. Decision-log: DL-009. Date: 2026-09-10; reviewed
2026-10-12.

## Context

The only remote project (`eamewgaptdfqzpmayavx`) runs in AWS
`ap-northeast-1` (Tokyo) and contains synthetic data only. Studafy targets
Saudi schools; Saudi PDPL cross-border transfer assessment and hosting
constraints require qualified legal review (docs/planning/instructions.md explicitly marks
these as engineering prompts, not legal conclusions). ARC-001 requires the
region decision to be made or explicitly recorded as stopping later work.

## Decision

**Deferred.** Working assumptions until legal review:

- The production primary region hosts API, worker, Redis, and the primary
  Supabase project together in one approved region (docs/planning/instructions.md default).
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

## Update, 2026-10-12 (launch plan 7.2)

ADR-0035 chose the region: the API, worker and log shipper run on Fly.io in
Frankfurt (`fra`), the database, sign-in and file storage on Supabase in
`eu-central-1` (Frankfurt), and Sentry and Axiom in their EU regions. The
Tokyo project is retired. Studafy Limited is an Irish company and the GDPR
applies, with Jordan's Personal Data Protection Law for users there; the
Saudi framing above is out of date.

Still open, for counsel: the transfer mechanism (SCCs or an adequacy
decision) for each provider that may process outside the EEA. That means
Together AI, GitHub, Resend, Redis, the malware scanner once chosen, and
Google, Apple, Microsoft and Cloudflare. See `docs/legal/privacy-policy.md`
§7.2 and §8.
