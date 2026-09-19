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
| [ADR-0009](ADR-0009-billing-and-entitlements.md) | Billing product and purchaser/beneficiary model | **Decided** 2026-09-14 — four products, store IAP only, purchaser/beneficiary separated | DL-012, DL-036, DL-037 |
| [ADR-0010](ADR-0010-strangler-refactor-and-migrations.md) | Strangler refactor; forward-only migrations | Accepted | DL-008 |
| [ADR-0011](ADR-0011-monorepo-workspaces-and-toolchain.md) | Monorepo workspaces and pinned toolchain | Accepted | DL-016/017/018 |
| [ADR-0012](ADR-0012-flutter-feature-boundaries.md) | Flutter feature boundaries and the first typed vertical slice | Accepted | DL-019/020/021/022 |
| [ADR-0013](ADR-0013-db020-tenant-lifecycle-foundation.md) | DB-020 tenant and lifecycle foundation | Accepted for local/disposable use | DL-027 |
| [ADR-0014](ADR-0014-db021-least-privilege-database-access.md) | DB-021 least-privilege database access | Accepted for local/disposable use | DL-028 |
| [ADR-0015](ADR-0015-application-identity-and-store-accounts.md) | Application identity and store accounts | Accepted (identity); signing and privacy manifests open | DL-029 |
| [ADR-0016](ADR-0016-auth030-session-lifecycle.md) | AUTH-030 session lifecycle, token verification and Apple 4.8 posture | Accepted for local/disposable use | DL-032/033/034 |
| [ADR-0017](ADR-0017-auth031-server-authorization.md) | AUTH-031 action/resource authorization and server-derived tenant context | Accepted for local/disposable use | DL-038 |
| [ADR-0018](ADR-0018-api040-platform-controls.md) | API-040 shared validation, problem, durable idempotency and egress controls | Accepted for local/disposable use | DL-039 |
| [ADR-0019](ADR-0019-api041-authoritative-academic-slices.md) | API-041 authoritative academic slices, atomic commands, signed cursors and parity-gated Edge removal | Accepted for local/disposable use | DL-040 |
| [ADR-0020](ADR-0020-api042-school-operations.md) | API-042 school operations, invitations, family, communications, meetings, notifications, account rights and support access | Accepted for local/disposable use | DL-041 |
| [ADR-0021](ADR-0021-safe043-safety-and-safeguarding.md) | SAFE-043 reporting, moderation, blocks, legal holds and two-person moderator access | Accepted for local/disposable use | DL-042 |
| [ADR-0022](ADR-0022-file050-secure-upload-pipeline.md) | FILE-050 server-owned upload paths, purpose-bound intents, quotas, quarantine and outbox cleanup | Accepted for local/disposable use | DL-043 |
| [ADR-0023](ADR-0023-file051-scan-publication-delivery.md) | FILE-051 fail-closed scanning, deterministic metadata stripping, single-object publication, school-scoped dedupe, retention units and single-use re-authorizing delivery | Accepted for local/disposable use | DL-044 |
| [ADR-0024](ADR-0024-ops060-rate-limits-and-caches.md) | OPS-060 Redis security posture, rate-limit registry/middleware and revocation-safe version-keyed caches | Accepted for local/disposable use | DL-045 |
| [ADR-0025](ADR-0025-ops061-bullmq-outbox-platform.md) | OPS-061 BullMQ queue platform and transactional outbox drain | Accepted for local/disposable use | DL-046 |
| [ADR-0026](ADR-0026-ai072-remove-ai-capability.md) | AI-072 removes the AI capability: no signed DPA or extended DPIA exists | Accepted for local/disposable use | DL-047 |
| [ADR-0027](ADR-0027-messaging-safeguards-and-mobile-safety-controls.md) | Messaging contact policy, content-free notifications, enforced messaging switch, and mobile report/block controls | Accepted for local/disposable use | DL-049 |

Decision statuses are tracked in `docs/governance/decision-log.md`. Deferred
ADRs record the working assumption and the explicitly blocked later work, which
satisfies the ARC-001 acceptance rule that blocking open questions are either
decided or explicitly stop a later phase.
