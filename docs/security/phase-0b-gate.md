# Phase 0B gate record (ARC-001)

Status: **complete — Phase 0 exits for Phase 1 purposes.** Date: 2026-09-10.
Owner: repository owner (GitHub `@yousefomar3003`), single-owner project.
Entry condition satisfied: Phase 0A evidence log assigned and approved
2026-09-10 (`sec-001-containment.md`).

## ARC-001 deliverables → evidence

| Deliverable (instructions.md:1007) | Evidence |
|---|---|
| Approved ADR set | `docs/adr/` — 10 ADRs + index; statuses mirrored in the decision log |
| Live-vs-repo diff | `docs/evidence/schema/reconciliation-report.md` (+ local/remote dumps, diff; remote confirmed empty, schemas identical except platform `rls_auto_enable()`) |
| Inventory | `docs/inventory/system-inventory.md` (tables/policies/functions/Edge Functions/bucket/providers/products/secrets/pins) |
| Threat model | `docs/inventory/data-flow-inventory.md` (25 flows, sensitivity classes, weakness register linked to roadmap tasks) |
| SLO and data-governance decision log | `docs/governance/decision-log.md` (DL-001…DL-015 + provisional SLO section) |

## ARC-001 acceptance criteria → status

**"Every environment/integration/data owner is known"** — environment matrix
(`docs/inventory/environment-matrix.md`) records the local disposable stack,
local function serving, and the single remote synthetic project with owner and
credential custody; system inventory covers every integration; no
dev/staging/prod environment exists (documented as such). **Met** (single-owner
model; production creation is gated).

**"Blocking open questions are decided or explicitly stop later phase"** —
decision log: decided/bounded/accepted-default: DL-001–DL-008; explicitly
deferred with the phase each stops: region/residency (pilot, Phase 6),
RTO/RPO (Phase 6), retention/legal (pilot), billing purchaser/beneficiary
(PAY-071), notification vendors (Phase 6), family/age/provisioning questions
(Phase 3 detail design), final app identity (REL-002). **Met.**

## Phase 0 gate (instructions.md:1013) → status

| Gate item | Status | Evidence |
|---|---|---|
| Critical containment verified | Passed | SEC-001 evidence log approved 2026-09-10; kill switches re-proven in the function smoke (substituted path → stable 503, no echo) |
| Git/owners/environments known | Passed | 2-commit bounded history; owners recorded in evidence log + decision log; environment matrix |
| Historical secret scan completed or formally bounded | Passed (bounded) | `git-history-boundary.md` (DL-002); gitleaks covers 100% of bounded history — 0 leaks |
| Live schema reconciled | Passed | `reconciliation-report.md` — remote synthetic project matches migration replay exactly (delta: platform `rls_auto_enable()` only); all tables 0 rows |
| Tenant, platform, region, data, billing, SLO decisions approved | Passed with explicit deferrals | Tenant accepted (ADR-0002); platform decided Android+iOS (ADR-0003); region/data/billing/SLO recorded as deferred, each explicitly stopping a named later phase — Phase 1 entry is unaffected |
| Reproducible Flutter checks run | Passed | `analyze-test-2026-09-10.txt`: analyze clean, 22/22 tests; synthetic debug APK builds (10.2 s) |
| Disposable Supabase checks run | Passed | `db reset --local --no-seed` + `db lint` clean; pgTAP suite: 2 containment + 8 RLS access tests green from clean state; negative validation proved the suite fails when RLS is disabled; wired into CI |

## Verification performed during 0B

Flutter format/analyze/test; Deno fmt/lint/check (frozen)/test; `bun audit`
(clean); tracked-filename secret check; gitleaks; osv-scanner; schema dumps +
diff; `inspect db table-stats --linked` (read-only); local Edge Function smoke
(23 requests, all expected outcomes) + remote read-only smoke (4 requests,
401s); query-plan baseline; licence inventories; frozen installs verified.

## Conditions and limits for Phase 1

1. Phase 1 (ARC-010/011) may start: monorepo skeleton, Hono API/worker
   scaffolding, typed contracts, first vertical slice.
2. Deferred decisions (DL-009…DL-015) must be resolved before their named
   phases; none are unblocked silently.
3. Any production or real-data environment requires re-evidencing the Phase 0A
   log with named, separated owners first.
4. Findings registered during 0B (wildcard CORS, definer EXECUTE grants,
   unindexed RLS paths, `iat` recent-auth weakness, licence review backlog)
   remain tracked in the data-flow inventory and scan summary as inputs to
   DB-020/021, API-040/041, AUTH-030, and supply-chain work.
