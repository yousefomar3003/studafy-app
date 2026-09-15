# ADR-0019: API-041 authoritative academic slices

- Status: Accepted for local/disposable use
- Date: 2026-09-15
- Decision log: DL-040

## Context

Core school, class, content, assignment, assessment, grade, attendance, and
wellbeing journeys were local-only or used prototype Edge Functions. That made
SQLite a second source of truth, split multi-row commands across transactions,
and allowed side effects to occur without durable command completion. API-040
and AUTH-031 provide the required platform and authorization foundations.

## Decision

All remote academic reads and writes use authenticated `/v1` routes generated
from strict Zod contracts. SQLite is selected only through synthetic preview
adapters. Remote failures are visible and never fall back to local persistence.

The API runtime retains zero table/column/sequence grants. Each API-041 command
runs one `private.api041_command` call inside a transaction whose local settings
contain the verified subject, server-derived school, and request ID. Mutation,
version/state check, audit/history, outbox insertion, and idempotency completion
commit or roll back together. Provider calls and direct notification creation
are forbidden in request handlers.

Collections use a default page of 50 (maximum 100) and signed opaque cursors
binding cursor/filter versions, operation, school, filter hash, and UUID sort
position. Mutable aggregates use optimistic versions and explicit transition
commands. Admin is the default authority for classroom creation; academic
writes otherwise require active lead/co-teacher assignment. Assistants,
students, and guardians retain the narrower read/submit relationships described
in the contract.

The `approve-paper-grade` and `publish-grade-result` source paths are removed
only after frozen fixtures, PostgreSQL command proofs, real Hono integration,
and Flutter adapter tests pass. Inspection showed both functions were source-
only in the synthetic project, so this is a source/invocation cutover—not a
claim of remote undeployment or production traffic movement.

## Consequences

- A successful mobile mutation means the school system of record acknowledged
  it; offline input may be retried but is never presented as saved.
- Notifications can lag without losing the academic commit because workers
  consume the durable outbox later under OPS-061.
- Runtime query/command functions are intentionally broad entry points but
  independently re-check operation, actor, tenant, relationship, state, and
  input; adding an operation requires contract, catalogue, SQL, and parity
  coverage together.
- Per-slice switches can stop unsafe traffic but cannot restore local remote
  writes.
- File uploads and AI proposals stay unavailable pending FILE-050/051 and
  AI-072. API-042 and SAFE-043 still block the overall Phase 4 gate.

## Recovery

Disable the affected API-041 slice and present read-only/unavailable UI. Repair
data through a forward migration or explicit forward correction command. Do
not restore the removed Edge invocation, grant tables to the runtime, bypass
authorization/idempotency, or enable a production SQLite queue.
