# FILE-050 threat model and malicious-upload response

Scope: the private upload pipeline delivered by FILE-050 — upload intents,
signed capabilities, object metadata, quarantine, and cleanup. Local and
disposable synthetic use only. This document does not authorize a deployment.

Out of scope, and owned by FILE-051: malware scanning, parser validation,
image transformation and EXIF removal, the transition to `clean`,
publication, deduplication, retention reconciliation, and signed download
delivery.

## Assets

| Asset | Why it matters |
|---|---|
| Uploaded bytes in quarantine | may contain minors' schoolwork, identifiable images, graded papers |
| Object metadata and bindings | reveal who uploaded what, for which class, assignment, or student |
| The service-role credential | full bypass of storage authorization if it escapes the server |
| Signed upload capabilities | short-lived write authority into the private bucket |
| Quota state | availability of the upload surface for an entire school |

## Trust boundaries

1. **Client → API.** Untrusted. Every field is validated against a strict
   contract; nothing in the request selects a location, an owner, or a state.
2. **API → database.** The API holds EXECUTE on `private.api050_*` functions
   and no table grant. Each function re-derives the actor, tenant, and
   relationship rather than trusting the caller.
3. **API → storage.** Only `SupabasePrivateFileStorage` holds the
   service-role credential and only it constructs keys. Handlers cannot
   reach either.
4. **Worker → storage.** The worker deletes only keys handed to it by a
   `SECURITY DEFINER` claim. Job payloads carry no path.

## The originating vulnerability

SEC-001 was a caller-selected file path signed by a service role. Any client
could name a location and receive write authority to it. FILE-050 exists to
make that class of bug unrepresentable, so the mitigations below are
structural rather than validating.

## Threats and mitigations

### T1 — Path substitution (the SEC-001 class)

*An attacker supplies or influences the storage path and has it signed.*

- The intent request is a `strictObject` with no path, key, bucket, or
  storage field of any kind. Unknown keys are a `400` before authorization.
- The key is generated inside the storage adapter as
  `quarantine/v1/{serverUploadId}/{24 random bytes}` — no filename, no tenant
  id, no resource id, nothing caller-derived.
- The adapter re-validates the exact key shape and bucket on every `inspect`
  and `delete`; a foreign or malformed location throws.
- Completion resolves the path through a private owner-only query. The client
  cannot pass a path or URL at completion either.
- `scripts/check-file050-boundaries.ts` fails CI if any handler or Flutter
  file calls storage directly, constructs a `quarantine/v1/` path, or
  references the service-role credential outside the composition roots.

Proven by: `apps/api/test/files/routes.test.ts` ("rejects caller-selected
paths before authorization or signing"), the pgTAP assertion "only the
server-provided quarantine key is persisted", and the live storage test that
uses a valid signed token against its intended path and then fails to
redirect it to another object.

### T2 — Cross-tenant binding

*An attacker names another school's classroom, assignment, student, or grade
result.*

- `private.file050_authorize_target` resolves an active membership in the
  named school first, then checks the exact purpose-specific relationship.
- Same-school composite foreign keys make a cross-school pairing
  unrepresentable at the schema level, not merely rejected.
- The failure is concealed as `404` during the read-only preparation step,
  **before** the signing adapter is called, so nothing is signed and no
  existence signal leaks.

Proven by: "conceals cross-tenant binding before the storage adapter is
called"; pgTAP "cross-tenant binding is concealed" and "another tenant cannot
resolve the server-owned object path".

### T3 — Content that is not what it claims

*A polyglot, a renamed executable, an SVG with script, an archive.*

- The declared type is a closed enum of four signature-detectable formats.
- The purpose policy narrows it further (profile images accept no PDF).
- At completion the server reads the bytes under a hard byte bound and
  detects PDF/JPEG/PNG/WebP by magic number. A declared/detected
  disagreement is `UPLOAD_TYPE_MISMATCH`, the object becomes `rejected`, and
  an exact-key deletion job is enqueued.
- Nothing is rendered, parsed, transformed, or served in this slice — the
  bytes are inert in a private bucket with no read policy.

Residual: magic-byte detection is not parser validation. A well-formed PDF
carrying a malicious payload passes FILE-050 and stays `quarantined`. That is
the intended boundary; FILE-051 owns scanning.

### T4 — Capability abuse

*Reusing, sharing, or outliving a signed upload URL.*

- Capabilities are written with `upsert: false`, so one key accepts one
  object.
- Lifetime is Supabase's fixed two hours, matched exactly by the database
  session expiry. Retry after expiry requires a new idempotency key.
- The URL is returned once, in the intent response, and is redacted from
  logs, audit records, errors, and telemetry.
- A capability minted before a failed transaction is never disclosed and
  expires unusable.
- The abandoned-session sweeper expires stale sessions and enqueues deletion.

### T5 — Quota exhaustion and denial of service

*One actor consuming a school's storage or blocking others.*

- Six independent limits: per-user rolling bytes, per-school rolling bytes,
  per-school stored bytes, per-school live objects, per-user hourly intents,
  per-user active sessions.
- Quota decisions serialize on the school's quota-policy row, so concurrent
  last-slot and last-byte races resolve to exactly one winner.
- Active reservations count against limits, so a flood of unfinished intents
  cannot be used to bypass accounting.
- Rejected bytes still count toward rolling ingress; they stop counting
  toward stored quota only after storage confirms deletion.

Proven by: pgTAP "active-session quota is serialized and enforced", "failed
quota check creates no second reservation", "rolling intent quota is enforced
before issuance".

### T6 — Credential escape

*The service-role key reaching a handler, a client, or a log.*

- It lives in one adapter, injected at the composition root.
- The boundary script fails CI on any other reference.
- `describeApiEnv`/`describeWorkerEnv` report only
  `serviceRoleConfigured: boolean`, never the value.
- The Flutter client has no storage credential and no storage SDK.

### T7 — Metadata leakage and deduplication side channels

*Learning that a file exists, or that another tenant holds the same bytes.*

- Safe responses omit object keys, hashes, signed URLs (outside the single
  intent response), internal roles, and child data.
- No deduplication happens in FILE-050, so a cross-tenant hash collision
  produces no signal at all. The same-school clean-dedup index exists but is
  unused until FILE-051.

Proven by: pgTAP "another tenant cannot resolve the server-owned object
path", and the contract tests asserting the safe response shape. Note that no
assertion yet *directly* probes a cross-tenant hash collision, because no
deduplication code path exists to probe; FILE-051 must add one when it
introduces dedup.

### T8 — Partial or torn state

*An object registered without audit, binding, or cleanup work.*

- Registration is one transaction: object, binding, audit record, outbox
  job, response, and idempotency completion commit together or not at all.
- Forced audit/outbox/idempotency failures roll the domain mutation back.
- Concurrent completion and response-loss retry produce exactly one object,
  one binding, one audit event, one scan job, and one stored response.
- Deterministic `422` mismatches are persisted as idempotency completions, so
  a retry replays the rejection instead of re-reserving. The shared
  middleware was adjusted for exactly this and never releases an
  already-completed reservation.

### T9 — Worker misuse

*Deleting the wrong object.*

- Jobs are claimed `FOR UPDATE SKIP LOCKED`; the exact bucket and key come
  from the claim, never from the payload.
- Acknowledgement succeeds only for the claiming worker.
- The database row is marked `deleted` only after storage confirms removal.
- Failures retry with capped exponential backoff and dead-letter after ten
  attempts.

## Malicious-upload response

What to do when an object in quarantine is believed hostile.

1. **Contain.** Nothing is required to stop delivery: quarantined objects are
   not downloadable in FILE-050, the bucket has no authenticated read policy,
   and `download-intent` returns `FILE_NOT_CLEAN`. Confirm rather than act.
2. **Stop new ingress if the pattern is broad.** Set
   `FILE050_NEW_INTENTS_ENABLED=false`. Already-issued completion, status
   reads, and cleanup keep working by design, so in-flight uploads settle
   instead of stranding.
3. **Identify.** From the file id, the object row gives owner, tenant,
   purpose, authorizing membership, declared and detected type, size,
   server-computed SHA-256, and policy version. The binding gives the upload
   session; audit events give the request ids for the whole chain.
4. **Scope.** Query other objects by the same owner, the same digest within
   the school, and the same rolling window. FILE-050 computes a trustworthy
   server-side digest for every quarantined object, so digest matching is
   reliable.
5. **Remove.** Enqueue a `delete` job for the exact object. Never hand a path
   to the worker; the claim resolves it. The row moves to `deleted` only
   after storage confirms.
6. **Preserve if it may be evidence.** Deletion is irreversible and the
   object is the only copy. Coordinate with the SAFE-043 legal-hold path
   before removing anything tied to a report or a safeguarding concern.
7. **Record.** Cleanup writes a `quarantine_object_deleted` audit event.
   Add a decision-log entry if intents were disabled or a policy changed.

## Known residual risk

- No malware or parser scanning exists yet. Every accepted object is
  `quarantined` and inert, but it is unexamined. FILE-051 is the gate.
- Magic-byte detection reads a prefix; it establishes format, not safety.
- Quota defaults are engineering estimates, not capacity-planned values.
- There is no production metrics, alerting, or central logging pipeline
  (OPS-090), so hostile-upload patterns would be found by query, not alert.
- None of this has been reviewed by an independent security assessor.
