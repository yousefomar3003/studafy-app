# Architecture Decision Records

ADR index for Studafy. Each record follows: Status, Context, Decision,
Consequences. Records are immutable once accepted; supersede with a new ADR
that references the old one.

| ADR | Title | Status | Decision-log entry |
|---|---|---|---|
| [ADR-0001](ADR-0001-modular-monolith-target.md) | Modular monolith target architecture | Accepted (provisional on Phase 1 proofs) | DL-005 |
| [ADR-0002](ADR-0002-school-tenant-boundary.md) | School as tenant boundary; global multi-role users | Accepted | DL-006 |
| [ADR-0003](ADR-0003-supported-platforms.md) | Supported platforms: Android and iOS only | Accepted | DL-003 |
| [ADR-0004](ADR-0004-environment-matrix.md) | Environment matrix and separation | Accepted (records current facts) | — |
| [ADR-0005](ADR-0005-region-and-data-residency.md) | Production region and data residency | Deferred (blocks pilot/Phase 6) | DL-009 |
| [ADR-0006](ADR-0006-time-and-time-zones.md) | UTC storage, per-school IANA rendering | Accepted | DL-007 |
| [ADR-0007](ADR-0007-rto-rpo-candidates.md) | RTO/RPO provisional candidates | Deferred (blocks Phase 6) | DL-010 |
| [ADR-0008](ADR-0008-data-classification-and-retention.md) | Data classification and retention | Deferred (blocks pilot/legal) | DL-011, DL-014 |
| [ADR-0009](ADR-0009-billing-and-entitlements.md) | Billing product and purchaser/beneficiary model | Deferred (blocks PAY-071) | DL-012 |
| [ADR-0010](ADR-0010-strangler-refactor-and-migrations.md) | Strangler refactor; forward-only migrations | Accepted | DL-008 |
| [ADR-0011](ADR-0011-monorepo-workspaces-and-toolchain.md) | Monorepo workspaces and pinned toolchain | Accepted | DL-016/017/018 |
| [ADR-0012](ADR-0012-flutter-feature-boundaries.md) | Flutter feature boundaries and the first typed vertical slice | Accepted | DL-019/020/021/022 |

Decision statuses are tracked in `docs/governance/decision-log.md`. Deferred
ADRs record the working assumption and the explicitly blocked later work, which
satisfies the ARC-001 acceptance rule that blocking open questions are either
decided or explicitly stop a later phase.
