# Phase 2A / DB-020 local evidence

- Evidence date: 2026-09-11
- Database target: disposable local Supabase only (`127.0.0.1:54322`)
- Data: deterministic synthetic fixtures only
- Remote projects modified: none
- Phase 2B policies/routes/features started: no

## Migration set and recovery intent

The eight earlier migrations were not edited. DB-020 adds these ordered,
transactional forward migrations:

| Migration | Purpose | SHA-256 at evidence capture | Failure/recovery |
|---|---|---|---|
| `202609110001_db020_expand_types.sql` | Add roles and lifecycle enums without deleting legacy values | `8a92f0f683856e75b430e106be9153a76febf30a440bcf7fc8fdce5827bca595` | Transaction rollback; correct with a new forward migration after application. |
| `202609110002_db020_expand_schema.sql` | Add compatibility columns, lifecycle tables, RLS, revoked client grants, and update timestamps | `f4cd86f75ea0224da7a4295117063a4ddae8f2c8c4a3cc33f7ee6292b350c27d` | Transaction rollback; schema is additive. |
| `202609110003_db020_backfill.sql` | Derive tenants/lifecycle/co-teachers and stop on aggregate anomalies | `2b5100d2be720e6537d9c6ba2bd9582abd7a0fb3f59c3056667859f9626d2e1e` | Any ambiguity raises and rolls back; repair source data with reviewed forward SQL, then retry. |
| `202609110004_db020_constraints.sql` | Add same-school keys/FKs, state/score/file/idempotency constraints, compatibility and append-only triggers | `6e9d222e49528b64b6895dd42c2f40f5f32fcc2a44df08c06d4743bbd6ee36f2` | Transaction rollback; post-application correction is forward-only. |
| `202609110005_db020_validate_constraints.sql` | Validate DB-020 constraints, require tenants/lifecycle values, and enforce one active term | `e3d09f43860f1fcbe40f0a836b23512b0eafe60c9fdfbd626516dd2ae01cc405` | Transaction rollback; do not broadly drop validated tenant controls. |
| `202609110006_db020_indexes.sql` | Add query-linked composite, cursor, and partial indexes | `b21273857577023e2763f1a27826adc72152223fdee6fffb73abdd816bc3145f` | Transaction rollback; later removal requires query telemetry and a corrective migration. |

The source files are authoritative; `shasum -a 256
supabase/migrations/20260911000*.sql` reproduces the evidence.

## Upgrade and recovery rehearsal

At `2026-09-11T10:52:14Z`, the local database was reset only through
`202609090004`, then loaded with a two-school legacy fixture. A logical backup
of the application-owned `auth` and `public` schemas was created inside the
local database container and checksummed before the upgrade.

- Closing-run backup SHA-256: `160c068d82586980906f155a205406655159c016f2b27f6afe91c556f6ff776a`
- Restore destination: separate disposable database
  `studafy_db020_recovery`
- Compared relations: `auth.users`, schools, memberships, students,
  classrooms, enrollments, assignments, submissions, grades, notifications,
  and audit events
- Result: all source/restored row-count fingerprints matched; temporary dump
  and restore database were removed

The six migrations were then applied in order. `db020_upgrade.sql` passed 18
assertions covering row/identifier preservation, legacy role/flag mapping,
tenant propagation, active terms, classroom teacher backfill, published-grade
actor attribution, and complete constraint validation.

This is a disposable-stack recovery proof, not production backup approval.
Production requires PITR/storage-backup evidence, a staging-sized snapshot,
approved RTO/RPO, named operators, and an explicit deployment authorization.

## Integrity and negative tests

`db020_constraints.sql` passes 31 pgTAP assertions. It covers:

- new role compatibility, non-null tenants, new-table RLS, and absence of
  premature policies;
- cross-school terms, classrooms, staff, guardian links, enrollments,
  submissions, grades, attendance, wellbeing, resources/publications, files,
  conversations, and outbox/delivery records;
- one active term, co-teacher uniqueness, grade lower/upper bounds, invalid
  temporal/state combinations, exactly-one typed file owner, and idempotency;
- append-only update/delete rejection.

The pre-existing SEC-001 containment suite (11 assertions) and multi-school RLS
fixture (8 assertions) remain in the clean-reset CI sequence. Comprehensive
grants and authorization behavior for new relations remains DB-021 / Phase 2B.

## Query and generated-type evidence

The deterministic scale verifier creates its fixture inside one transaction and
forces rollback after measurement. It fails if a hot query sequentially scans
its populated target relation, if median local execution reaches 50 ms, or if
the worst of three runs reaches 150 ms.

Observed local results:

| Query | Median ms | Worst ms |
|---|---:|---:|
| active memberships by user | 0.015 | 0.032 |
| active enrollment by student | 0.009 | 0.014 |
| verified links by guardian | 0.008 | 0.012 |
| active classroom staff by user | 0.008 | 0.013 |
| active classrooms by school/term | 0.021 | 0.027 |
| published grades by student cursor | 0.012 | 0.013 |
| attendance by student timeline | 0.008 | 0.012 |
| unread notifications by user cursor | 0.014 | 0.027 |
| ready notification outbox | 0.019 | 0.025 |
| clean file deduplication | 0.011 | 0.017 |
| tenant audit cursor | 0.019 | 0.022 |

These measurements are machine-local regression evidence, not a production
capacity claim. The complete index rationale is in
`docs/database/db020-index-catalogue.md`.

Public-schema TypeScript types are generated into
`packages/database/src/database.types.generated.ts`, exported by the database
package, and reproduced deterministically by
`bun run generate:db-types:check` against the local schema.

## CI and operational boundaries

The database CI job now performs:

1. pre-DB-020 reset and synthetic legacy seed;
2. checksummed backup/restore comparison;
3. forward upgrade and preservation tests;
4. clean full migration replay and schema lint;
5. SEC-001, existing RLS, and DB-020 negative suites;
6. scale/query-plan verification and generated-type drift;
7. local stack cleanup even after a failure.

Every database command uses `--local` or a loopback-only script guard. CI has no
deployment job or remote credentials.

## Closing regression and security checks

The 2026-09-11 closing run passed:

- full clean migration replay and warning-level Supabase schema lint;
- 68 pgTAP assertions (18 upgrade, 11 containment, 8 existing RLS, 31 DB-020);
- 51 Bun workspace tests, type checks for all nine members, dependency-boundary
  checks, and API/worker builds;
- 4 Deno Edge Function tests plus format, lint, and frozen type checking;
- 56 Flutter tests plus Dart formatting and `flutter analyze` with no issues;
- GitHub Actions syntax/static shell validation with `actionlint`;
- generated database type drift and database connectivity;
- `bun audit` and OSV with no known vulnerabilities;
- sensitive-filename check and a 1.94 MB tracked/untracked, non-ignored source
  snapshot scan with no gitleaks findings.

A separate whole-working-directory scan reported one generic-key heuristic in
the ignored `config/dart-defines.development.json`. Only its category was
reviewed: `SUPABASE_PUBLISHABLE_KEY`, an intentionally client-public synthetic
configuration value. The file is covered by `.gitignore` and is not tracked.
No secret value was printed or copied into evidence. Generated build artifacts
over 50 MB were excluded from that broad scan; the source snapshot scan includes
everything eligible for commit.

## Gates that remain open

Local DB-020 implementation and its closing regression checks pass, but neither
Phase 2 nor SEC-001 is closed:

- human review of current Supabase/provider logs, credentials, MFA/session state,
  and the SEC-001 evidence log remains open;
- staging-sized migration duration/lock/backfill review and approved backup/PITR
  evidence are required before any real environment;
- Phase 2B must implement and negatively test complete policies, grants, helper
  functions, and relationship-aware authorization;
- retention schedules still require qualified legal/product approval;
- uploads, AI grading, payments, queues, and `/v1` routes remain disabled or
  unactivated.
