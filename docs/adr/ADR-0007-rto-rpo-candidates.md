# ADR-0007: RTO/RPO provisional candidates

Status: Deferred — formal approval blocks Phase 6 and any production data
commitment. Decision-log: DL-010. Date: 2026-09-10.

## Context

ARC-001 requires SLO/RTO/RPO targets to be approved or explicitly recorded.
Product/operations approval does not exist yet (single-owner project, no
production environment). instructions.md §"Resilience targets" supplies
planning candidates.

## Decision

**Deferred.** Recorded planning candidates (not commitments) in
`docs/governance/decision-log.md`:

- Near-zero loss for committed grades, memberships, and store transactions via
  PostgreSQL durability + PITR.
- Bounded minutes for notification/outbox recovery.
- Caches and queues rebuildable where a durable source exists.
- File-object recovery matching academic retention.
- Quarterly recovery exercises reporting achieved restore time, data gap,
  consistency validation, and follow-ups.

## Consequences

- Phase 6 (Redis, queues, Cloudflare, observability, backup/restore work)
  **cannot complete** without converting these candidates into approved
  RTO/RPO by data class.
- No backup/restore claim may be made today; the SEC-001 record already notes
  no backup is claimed for the synthetic project.
- Recovery rehearsals become mandatory Phase 2/6 gate evidence once approved.
