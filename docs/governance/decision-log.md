# SLO and data-governance decision log

Living register required by ARC-001 ("SLO and data-governance decision log").
Every entry records a decision, its status, the accountable owner, the date,
and which later work it unblocks or blocks. Add new entries at the end; never
rewrite decided entries — supersede them with a new entry that references the
old one.

Statuses: **Decided** (binding unless superseded), **Accepted default**
(instructions.md default adopted as the working assumption), **Deferred**
(open; lists the phase it blocks), **Bounded** (a limitation formally accepted).

Owner: repository owner (GitHub `@yousefomar3003`), single-owner project.
Production or real-data environments require re-recording with named, separated
owners.

## Decisions

| ID | Date | Decision | Status | Blocks/unblocks | Evidence |
|---|---|---|---|---|---|
| DL-001 | 2026-09-10 | Phase 0A evidence log: all rows owner-assigned and approved (synthetic scope) | Decided | Unblocks Phase 0B | `docs/security/sec-001-containment.md` evidence log |
| DL-002 | 2026-09-10 | Secret/history scanning formally bounded to the two-commit baseline; original history unrecoverable | Bounded | Closes the SEC-001 history gate item | `docs/governance/git-history-boundary.md` |
| DL-003 | 2026-09-10 | Supported platforms: Android and iOS only; generated web/desktop scaffolds are non-production | Decided | Unblocks REL-002 planning; ADR-0003 | ADR-0003 |
| DL-004 | 2026-09-10 | Read-only remote inspection of synthetic project `eamewgaptdfqzpmayavx` permitted for 0B schema reconciliation (no writes, no data copying) | Decided | Unblocks the live-vs-repo diff deliverable | `docs/evidence/schema/reconciliation-report.md` |
| DL-005 | 2026-09-10 | Target architecture: modular monolith (Bun/Hono API + BullMQ workers, Supabase authoritative, Redis, Cloudflare) | Accepted default | Unblocks Phase 1; provisional on Phase 0/1 pinning proofs (queue semantics, reconnect, graceful shutdown) | ADR-0001 |
| DL-006 | 2026-09-10 | School is the tenant boundary; users are global identities with multi-school, multi-role memberships; `guardian` is the authorization role, `parent` a display term | Accepted default | Unblocks DB-020/021 and AUTH-031 design | ADR-0002 |
| DL-007 | 2026-09-10 | Store timestamps in UTC (`timestamptz`); render per school IANA time zone, initially `Asia/Riyadh` where configured | Accepted default | Unblocks schema work | ADR-0006 |
| DL-008 | 2026-09-10 | Strangler-style refactor; forward-only migrations; never edit applied migrations; no whole-client rewrite | Accepted default | Governs all later phases | ADR-0010 |
| DL-009 | 2026-09-10 | Production region and Saudi hosting/data-transfer constraints | Deferred — requires qualified legal review; blocks production provisioning, Phase 6 infrastructure, and the Phase 7 pilot | ADR-005 |
| DL-010 | 2026-09-10 | RTO/RPO by data class | Deferred — provisional candidates recorded in ADR-0007; formal approval blocks Phase 6 and any production data commitments | ADR-0007 |
| DL-011 | 2026-09-10 | Record retention periods, legal bases, and export/correction policy (Saudi PDPL, children's data) | Deferred — requires qualified counsel; blocks the Phase 7 pilot and any real student data | ADR-0008, `docs/inventory/data-classification-retention-draft.md` |
| DL-012 | 2026-09-10 | Paid-product purchaser/beneficiary rules, multi-product lifecycle, webhook reconciliation model | Deferred — blocks PAY-071 (Phase 6) | ADR-009 |
| DL-013 | 2026-09-10 | Notification/push vendors and channels | Deferred — blocks Phase 6 notifications work | Environment matrix (`docs/inventory/environment-matrix.md`) |
| DL-014 | 2026-09-10 | Student age ranges, guardian verification authority, and school provisioning workflow | Deferred — blocks detailed Phase 3 (AUTH-030/031) design | ADR-008 |
| DL-015 | 2026-09-10 | Final application identity (bundle ID / application ID), signing, privacy manifests, store accounts | Deferred — blocks REL-002 and any store submission | ADR-0003 |

## SLO section

No production environment exists, so no production SLO is enforceable today.
This section records provisional targets (planning candidates, not
commitments) so Phase 6 can convert them into approved SLOs with alerting:

| Target class | Provisional target | Basis | Status |
|---|---|---|---|
| Committed grades, memberships, store transactions | Near-zero loss (PostgreSQL durability + PITR) | instructions.md resilience targets | Candidate — pending ops approval (DL-010) |
| Notification/outbox recovery | Bounded minutes | instructions.md resilience targets | Candidate — pending ops approval (DL-010) |
| Caches/queues | Rebuildable from durable source | instructions.md resilience targets | Candidate — pending ops approval (DL-010) |
| File objects | Recovery matches academic retention | instructions.md resilience targets | Candidate — pending ops approval (DL-010) |
| Recovery exercises | Quarterly, reporting achieved restore time, data gap, consistency validation, follow-ups | instructions.md resilience targets | Candidate — pending ops approval (DL-010) |

Known observability gap: there is no production metrics, tracing, alerting, or
central logging pipeline (OPS-090). Baseline query-plan and latency evidence
for the synthetic environment is recorded in `docs/evidence/baselines/`.
