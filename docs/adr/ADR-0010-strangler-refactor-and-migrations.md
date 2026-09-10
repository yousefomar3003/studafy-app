# ADR-0010: Strangler-style refactor and forward-only migrations

Status: Accepted. Decision-log: DL-008. Date: 2026-09-10.

## Context

The Flutter prototype mixes UI, state, and direct SQLite access across
~15,000 lines of feature files, while a partial Supabase schema exists.
instructions.md recommends preserving the interaction design and tested
insight calculations rather than rewriting.

## Decision

- Use a **strangler-style refactor**: introduce typed domain/repository
  boundaries around vertical slices, move authoritative logic to the Hono API
  and PostgreSQL, and replace direct SQLite calls screen by screen.
- **Never edit applied migrations in place.** All schema changes are
  forward-only corrective migrations; superseded policies/objects are dropped
  and recreated in later files (as `202609090001` already does).
- Preserve the Flutter interaction design and the tested insight-engine
  calculations.
- Replace unsafe remote functions incrementally behind feature flags with
  compatible API contracts; never a big-bang cutover.
- SQLite remains only as an encrypted-at-rest-by-platform, user-scoped offline
  cache behind typed repositories; server state wins for authorization,
  grades, entitlements, memberships, and audit history.

## Consequences

- Each migration slice (Phase 2) and each vertical slice (Phase 1B) is
  independently reversible; no whole-client rewrite.
- Applied-migration immutability makes the migration history the audit trail;
  reconciliation reports (`docs/evidence/schema/`) document drift instead of
  rewriting files.
- The preview fixture, offline cache, and future sync metadata must be
  separated before production (per the studafy_database.dart audit).
