# Phase 5 / FILE-050 local evidence

- Evidence date: 2026-09-17
- Target: local workspace and disposable local Supabase only
- Data: deterministic synthetic fixtures only
- Remote changes or deployment: none

Phase 5 covers file storage. Part 5A (**FILE-050**) builds the private upload
pipeline: server-issued signed upload intents bound to an authenticated
owner, tenant and purpose; immutable object metadata rows; and quarantine on
arrival. Part 5B (**FILE-051**) owns scanning and delivery and has not
started.

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
scans. The pre-existing SAFE-043 failures below are unrelated to this slice
and are documented in the transcript.

## Known carry-over

Two SAFE-043 items, both found while running the suites for this phase, both
diagnosed in the transcript and neither caused by this branch:

- `POST /v1/blocks/{blockId}/unblock` returns `500` in every environment: the
  dispatcher returns the raw snake-case row where the contract expects the
  camelCase `V1Block` projection. Left for SAFE-043 to fix forward-only,
  because the correction means re-emitting its dispatcher.
- `supabase/tests/safe043_surface_seed.sql` has never passed. DL-042 recorded
  that SAFE-043's suites were written but never executed for want of a
  toolchain. Two unbalanced-paren syntax errors are fixed here as partial
  progress; the remaining failures are authorization mismatches in the
  dispatcher and are not attempted.

## Still blocking Phase 5 and launch

FILE-051 (scanning, parser validation, EXIF removal, clean transitions,
publication, deduplication, retention, delivery), independent security
review, OPS-061/090, production E2E, and the remaining launch gates.
