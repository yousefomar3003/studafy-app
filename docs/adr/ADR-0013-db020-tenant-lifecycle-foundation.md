# ADR-0013: DB-020 tenant and lifecycle foundation

- Status: Accepted for local/disposable use
- Date: 2026-09-11
- Decision log: DL-027

## Context

The original schema stored `school_id` on some roots but relied on ordinary
single-column foreign keys below them. A privileged defect could therefore
connect records owned by different schools. The schema also represented
membership, enrollment, terms, classrooms, submissions, files, delivery, and
billing without the lifecycle and immutable history required for reliable
server workflows.

## Decision

`school_id` is the structural tenant boundary. Every school-owned aggregate is
backfilled, made non-null, and joined to another school-owned aggregate through
a composite tenant foreign key. `(school_id, id)` candidate keys support those
relationships. Global identity, product, consent-policy, store-event, and
idempotency records may remain unscoped only where their meaning is genuinely
global.

The six DB-020 migrations use expand, backfill, constrain, validate, and index
steps. They fail with aggregate counts if ownership cannot be derived without
ambiguity. No row is reassigned between schools and no earlier migration is
edited.

Co-teaching is canonical in `classroom_staff`; `classrooms.teacher_id` remains
as a compatibility field. Exactly one active term is permitted per school.
`parent` remains a legacy application role while `guardian` is the future
authorization term. Existing boolean lifecycle columns remain and are kept in
sync by compatibility triggers.

Immutable attempts, versions, messages, store transactions, grade events,
membership events, and audit events reject update and delete. Files use a
tenant-owned immutable object plus exactly one typed binding. This is schema
foundation only: uploads and AI grading stay disabled.

All new public tables enable RLS immediately and expose no policies or client
grants. Phase 2B owns the complete policy/grant rewrite. No `/v1` route is
activated by this decision.

## Consequences

- Cross-school graph corruption is rejected at the database boundary, including
  privileged server writes.
- Legacy inserts can continue while dependent code migrates, but compatibility
  triggers and columns add temporary maintenance cost.
- Tenant backfill stops on ambiguous multi-school notification recipients or
  any missing/cross-tenant edge; operators must correct the source data through
  a reviewed forward migration.
- Indexes add write amplification and storage. Each is tied to a documented
  query and must be re-evaluated using production-safe telemetry before any
  production deployment.
- Legal retention durations, production backup/PITR approval, and Phase 2B
  authorization remain unresolved gates. This ADR does not authorize real data
  or a remote migration.

## Recovery

Each migration is transactional, so a failed application rolls back. After a
successful application, defects are repaired with a new forward migration;
applied files are never edited and tenant constraints are never broadly
removed. A pre-upgrade logical backup/restore rehearsal is automated for the
disposable stack. Real environments require separately approved backups, PITR
verification, maintenance coordination, and a staging-sized rehearsal.
