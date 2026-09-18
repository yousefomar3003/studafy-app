# Phase 5 / FILE-050 and FILE-051 local evidence

- Evidence date: 2026-09-17
- Target: local workspace and disposable local Supabase only
- Data: deterministic synthetic fixtures only
- Remote changes or deployment: none

Phase 5 covers file storage. Part 5A (**FILE-050**) builds the private upload
pipeline: server-issued signed upload intents bound to an authenticated
owner, tenant and purpose; immutable object metadata rows; and quarantine on
arrival. Part 5B (**FILE-051**) adds five things:
- fail-closed scanning and deterministic metadata stripping;
- copy-free publication;
- school-scoped deduplication;
- retention units with storage reconciliation;
- single-use delivery links that are re-authorized when used.

It also adds the malicious-file runbook and a drill that rehearses it.

## FILE-051 at a glance

The transcript is
[`file051-verification.md`](file051-verification.md). The decisions are
ADR-0023 and DL-044. The response procedure is
[`docs/security/file051-malicious-file-runbook.md`](../../security/file051-malicious-file-runbook.md),
and the threat model is
[`docs/security/file051-threat-model.md`](../../security/file051-threat-model.md).

| Gate | Result |
|---|---|
| Only clean, scanned objects publishable and deliverable | Pass |
| Publication derives access without copies (thirty recipients, one object) | Pass |
| Signed delivery re-authorizes at use; a leaked link is not a standing grant | Pass |
| No cross-tenant dedupe signal | Pass |
| Retention and reconciliation | Pass (mechanism; no durations set) |
| Malicious-file response exercise | Pass (local drill) |
| Independent file penetration test | **Not done** |
| `allowsRemoteFileUploads` | still `false`; flipping it is a separate reviewed change |

Executed for FILE-051:
- 99 pgTAP assertions;
- 30 end-to-end checks over real Storage, with the API and workers running
  as their least-privilege roles;
- a 15-check drill;
- 6 index-backed query plans;
- zero-drift reconciliation;
- a full CI database replay from the pre-DB-020 boundary.

The Bun suite is 368 pass, 1 skip, 0 fail. Twelve defects in the resumed,
never-executed draft were found and fixed. One of them came from FILE-050:
the worker role had no `USAGE` on `private`. The FILE-050 material below is
unchanged.

The full transcript, matrices, plans, scans, and gate assessment are in
[`file050-verification.md`](file050-verification.md). The route contract is
[`docs/api/v1-file-contract.md`](../../api/v1-file-contract.md); the threat
model and malicious-upload response are
[`docs/security/file050-threat-model.md`](../../security/file050-threat-model.md).
The decisions are ADR-0022 and DL-043.

## What this phase does and does not enable

FILE-050 is deliberately a pipeline without an exit. It accepts bytes into a
private bucket, verifies them server-side, and records what they are. It
never marks a file clean, never publishes one, never deduplicates, and never
makes one downloadable.

Two switches stay off:

- `allowsRemoteFileUploads` remains `false` in
  `lib/core/runtime_environment.dart`.
- `FILE050_NEW_INTENTS_ENABLED` defaults to `false`, and production fails
  closed if it is turned on without the storage configuration.

Turning the intent switch off still allows already-issued completion, status
reads, and cleanup, so disabling ingress settles in-flight uploads instead of
stranding them.

## The rule this phase exists to enforce

SEC-001 was a caller-selected file path signed by a service role. FILE-050's
controlling constraint is therefore structural, not advisory:

> The server chooses the storage path. The client never supplies, names, or
> influences it — not in a request field, not in a header, not in a job
> payload.

Keys are generated inside the storage adapter as
`quarantine/v1/{serverUploadId}/{24 random bytes}`, in the fixed private
`private-school-files` bucket, with `upsert: false`. The intent request
schema has no path, key, bucket, owner, or scan-state field at all, so those
are rejected as unknown keys before authorization runs. Completion resolves
the path through a private owner-only query and accepts nothing from the
client. The worker deletes only keys handed to it by a `SECURITY DEFINER`
claim.

`scripts/check-file050-boundaries.ts` fails CI if any of that erodes.

## Results summary

| Gate | Result |
|---|---|
| Path substitution denied | Pass |
| Cross-tenant binding denied | Pass |
| Quota exhaustion enforced (sequential and concurrent) | Pass |
| Oversized uploads denied | Pass |
| Type-mismatched uploads denied | Pass |
| Zero runtime table grants | Pass |
| Registration atomicity under forced failure | Pass |
| Remote uploads still disabled | Pass |
| Nothing becomes `clean` | Pass |

Executed: 302 Bun tests, 36 pgTAP assertions, 4 quota-race/atomicity
integration cases, 1 live signed-capability storage case, 5 query plans,
127 Flutter tests, the eleven-suite CI database sequence replayed from zero,
the Edge Function checks, plus typecheck, lint, format, build,
generation-drift, database-type-drift, database lint, boundary, and secret
scans. The full Bun suite is 303 pass / 0 fail and every pgTAP suite in the
CI database job passes from a clean replay.

## SAFE-043 debt cleared along the way

Running the real CI jobs for this phase surfaced that SAFE-043 had never
passed its own gates — DL-042 said as much, recording that its suites were
written but never executed for want of a toolchain. Three things were fixed
here so this branch's CI can go green:

- **`POST /v1/blocks/{blockId}/unblock` returned `500` in every
  environment.** Its dispatcher branch returned the raw snake-case row where
  the contract expects the camelCase `V1Block` projection. The projection is
  now taken before the row is deleted.
- **`safe043_surface_seed.sql` had never passed.** Five defects: three
  idempotency keys one character under the API-040 minimum, a blank tenant
  carried into the blocks phase, a held-report read performed as an operator
  with no JIT grant, a stale expected-version chain after approval, and an
  unclosed `insert`. All 69 assertions now pass.
- **The moderation drill had never run.** Transaction-local identity was set
  outside a transaction, payloads were double-encoded into jsonb, twelve
  request ids were below the idempotency key minimum, teardown could not
  clear append-only tables, and fixture emails collided across runs. It now
  reports `passed: true` end to end.

None of these were caused by FILE-050; all are diagnosed in the transcript.

## Still blocking Phase 5 and launch

- An independent file penetration test and security review.
- A real malware-scanner vendor and credential (inputs.md A6).
- Approved retention periods (§29).
- OPS-061/090.
- Production end-to-end testing.
- The separately reviewed `allowsRemoteFileUploads` change.
- The remaining launch gates.
