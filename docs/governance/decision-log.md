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
| DL-001 | 2026-09-10 | Initial Phase 0A evidence rows were owner-assigned for synthetic scope; later privilege and authenticated-smoke evidence reopened the human review items | Superseded by DL-024 | Did not close the expanded Phase 0A gate | `docs/security/sec-001-containment.md` evidence log |
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
| DL-016 | 2026-09-10 | Phase 1A toolchain and runtime library pins: Bun workspaces at root; hono 4.13.7, zod 4.6.1, postgres 3.4.9, ioredis 6.0.0, bullmq 6.3.4, typescript 7.0.2, @types/bun 1.4.2 (exact, lockfile-frozen); minimal built-in JSON logger in @studafy/observability | Decided | ADR-0011 |
| DL-017 | 2026-09-10 | Flutter relocation to apps/mobile deferred to its own reviewed change; Phase 1A introduces the workspace only and evidences zero Flutter impact | Decided (defers the move) | ADR-0011, instructions.md:287 |
| DL-018 | 2026-09-10 | Dev-stack data stores: Redis via pinned Docker container (compose + CI); API Postgres = disposable Supabase stack DB (127.0.0.1:54322), no second local database | Decided | ADR-0011 |
| DL-019 | 2026-09-10 | Phase 1B first slice: session (login→consent→profile→membership→term→immutable context, demo denial outside synthetic) + class read (typed ClassroomRepository with preview and Supabase adapters, ClassesPage replaces DatabaseClassesPage, legacy workspace bridged) | Decided | ADR-0012 |
| DL-020 | 2026-09-10 | Add dev-only sqflite_common_ffi so the real preview adapter runs in flutter tests against an ffi database | Decided | ADR-0012 |
| DL-021 | 2026-09-10 | Dart architecture boundary enforcement via tools/check_dart_bounds.dart (import allowlist matrix per feature zone, legacy exemption list, CI step) — mirrors the TS check-bounds.ts approach | Decided | ADR-0012 |
| DL-022 | 2026-09-10 | Contract drift detection: shared JSON fixture validated by both a bun test (zod schemas) and a flutter test (Dart DTOs); no OpenAPI codegen tooling yet | Decided | ADR-0012 |
| DL-023 | 2026-09-10 | Supersedes the no-codegen portion of DL-022: canonical OpenAPI 3.1 operations/schemas generate the checked-in Dart DTO/client; CI checks generated output, OpenAPI/Zod keys, paths, and shared fixtures | Decided | ADR-0012; closes ARC-011 client-generation gap |
| DL-024 | 2026-09-10 | SEC-001 repository, local-stack, and synthetic technical evidence passes through migration `202609090004`; Phase 0A remains open until a human reviews fresh Supabase logs, credential/session/MFA state, and explicitly approves the evidence log | Decided | Blocks Phase 0 closure, production/real-data use, and any claim that SEC-001 is closed; does not authorize deployment | `docs/security/sec-001-containment.md` evidence log |
| DL-025 | 2026-09-11 | Decompose Flutter hotspots without changing production authorization: keep startup/composition separate, inject parent/teacher/Study Coach ports, fail closed when remote repositories do not exist, modularize preview SQLite by responsibility, and enforce provider-symbol bans in presentation/application code | Decided | Extends ARC-011; reduces monolith and direct-persistence risk without activating an API or production path | ADR-0012; `docs/evidence/phase-1b/hotspot-refactor-2026-09-11.md` |
| DL-026 | 2026-09-11 | Replace the 4,690-line teacher feature monolith with a 34-line compatibility library and 14 responsibility-focused modules capped below 600 lines; retain and count its 62 direct preview-database calls under an explicit legacy boundary until repository-backed slices replace them | Decided | Removes the file-size hotspot without falsely declaring the teacher persistence boundary migrated | ADR-0012; `docs/evidence/phase-1b/hotspot-refactor-2026-09-11.md` |
| DL-027 | 2026-09-11 | DB-020 uses school-scoped composite foreign keys, compatibility lifecycle triggers, canonical `classroom_staff`, one active term per school, fail-closed new tables, forward-only recovery, and query-backed indexes; local completion does not authorize remote use or close Phase 2 | Decided for local/disposable scope | Unblocks DB-021 implementation after review; remote migration remains blocked by Phase 0 human gate and staging-size/backup approval | ADR-0013; `docs/evidence/phase-2a/README.md` |
| DL-028 | 2026-09-11 | DB-021 preserves only narrow column-scoped authenticated reads, permits two bounded RPCs, denies direct client writes, moves authorization/trigger helpers out of the Data API, restricts service-role operations, and structurally locks relationship identifiers | Decided for local/disposable scope | Completes local DB-021 engineering evidence; independent security review, Phase 0 human gate, staging-scale rehearsal, and backup/PITR approval still block Phase 2/remote use | ADR-0014; `docs/evidence/phase-2b/README.md` |
| DL-029 | 2026-09-11 | Permanent application identity is `io.studafy.app` on both platforms (bundle ID, Android application ID and namespace), display name `Studafy`; store accounts are Organization accounts under the registered legal entity. Identity is decided now and applied only at the REL-002 cutover — SEC-001 release guards stay in force | Decided | Resolves the identity portion of DL-015 and unblocks App ID registration, Sign in with Apple credentials (Apple guideline 4.8), and both store console setups. DL-015 remains open for signing material, privacy manifests, and store account completion; submission still blocked by Phases 3–10 | ADR-0015; `docs/release/rel-002-store-accounts.md` |

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
