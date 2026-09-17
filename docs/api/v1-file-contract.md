# `/v1` file upload contract (FILE-050)

Status: implemented for local/disposable synthetic use. This document does
not authorize a production deployment, real school/student data, or any
remote upload. OpenAPI remains the machine-readable source of truth at
`packages/contracts/openapi/v1.json`.

FILE-050 builds the private upload pipeline and stops deliberately short of
delivery. The API authorizes an exact tenant/purpose/relationship, enforces
quotas, generates an opaque quarantine key, issues a path-bound signed upload
capability, verifies the uploaded bytes server-side, and atomically registers
immutable metadata, a durable binding, audit history, processing-outbox work,
and idempotency completion.

**Nothing in FILE-050 marks a file clean, publishes it, deduplicates it, or
makes it downloadable.** Those are FILE-051 responsibilities.
`allowsRemoteFileUploads` remains `false` in
`lib/core/runtime_environment.dart`, and `FILE050_NEW_INTENTS_ENABLED`
defaults to `false`.

This slice exists because of SEC-001, where a caller-selected file path was
signed by a service role. The controlling rule below is therefore not a
preference:

> **The server chooses the storage path. The client never supplies, names, or
> influences it — not in a request field, not in a header, not in a job
> payload.**

## Route inventory

Five routes, indices 119–123 of `V1_ROUTE_CATALOGUE`. Each declares exactly
one AUTH-031 permission; each POST requires `Idempotency-Key`.

| Route | Method | Permission | Success | Idempotency |
|---|---|---|---|---|
| `/v1/uploads` | POST | `upload.intent.create` | `201` | required |
| `/v1/uploads/{uploadId}` | GET | `upload.read` | `200` | — |
| `/v1/uploads/{uploadId}/complete` | POST | `upload.complete` | `200` | required |
| `/v1/files/{fileId}` | GET | `file.read` | `200` | — |
| `/v1/files/{fileId}/download-intent` | POST | `file.download` | `200` (FILE-051) | required |

`download-intent` ships as a contract and authorization boundary only. In
FILE-050 it returns `FILE_NOT_CLEAN` for quarantined or rejected objects and
`FILE_DELIVERY_DISABLED` for any legacy clean row that has no FILE-051 scan
policy behind it. It never returns a URL in this slice.

## Purposes and their targets

The intent request is a strict union by purpose. Common input is `schoolId`,
a normalized display name, the declared media type, the exact byte size, and
a lowercase SHA-256. Purpose-specific targets are exact:

| Purpose | Target field(s) | Who may upload |
|---|---|---|
| `profile_image` | none (actor derived server-side) | any active member, own profile image only |
| `lesson_resource` | `classroomId` | active admin, or exact active lead/co-teacher |
| `assignment_material` | `assignmentId` | active admin, or exact active lead/co-teacher |
| `assignment_submission` | `assignmentId`, `studentId` | the authenticated student, active enrollment, published assignment, open window |
| `paper_scan` | `gradeResultId` | active admin, or exact lead/co-teacher for the grade's class |
| `coach_attachment` | `studentId` | the authenticated student, for their own active school student record |

Assistants and guardians receive no file-upload authority beyond their own
profile image. A target belonging to a field that does not match the purpose
is a contract violation, not a silent ignore: `V1CreateUploadIntentRequest`
requires present-target-fields to equal exactly the set the purpose allows.

## What the client may not send

`V1CreateUploadIntentRequest` is a `strictObject`, so any unknown key is a
`400`. That covers every field resembling `path`, `key`, `objectKey`,
`bucket`, `ownerId`, `uploaderId`, `scanState`, a signed URL, or storage
metadata — none of them exist in the schema, so all of them are rejected
before authorization runs and long before anything is signed.

`V1CompleteUploadRequest` and `V1DownloadIntentRequest` are empty strict
objects. Completion resolves the server-owned path through a private
owner-only query; it accepts no path or URL from the client at all.

## Limits

Per-purpose maximum object size, seeded and versioned in
`public.file_purpose_policies` (`policy_version = 'file050-v1'`):

| Purpose | Maximum | Allowed types |
|---|---|---|
| `profile_image` | 5 MiB | JPEG, PNG, WebP |
| `assignment_material` | 10 MiB | PDF, JPEG, PNG |
| `assignment_submission` | 10 MiB | PDF, JPEG, PNG |
| `coach_attachment` | 10 MiB | PDF, JPEG, PNG |
| `lesson_resource` | 25 MiB | PDF, JPEG, PNG |
| `paper_scan` | 25 MiB | PDF, JPEG, PNG |

Only signature-detectable formats are admitted. SVG, HTML, Office/ZIP/archive
formats, executables, audio/video, and arbitrary text are rejected — the
declared type allowlist is a closed enum, and the bytes themselves must match
by magic number at completion.

Per-tenant quotas live in `public.file_quota_policies`, one row per school,
backfilled for existing schools and created automatically for new ones by the
`file050_seed_school_quota` trigger:

| Quota | Default |
|---|---|
| Per user, rolling 24h | 100 MiB |
| Per school, rolling 24h | 1 GiB |
| Per school, live stored | 20 GiB |
| Per school, live objects | 10,000 |
| Per user, intents per rolling hour | 30 |
| Per user, active sessions | 3 |

Quota decisions serialize on the school's quota-policy row. Active
reservations count against the byte, object, and storage limits; at
completion the reservation is replaced with the observed byte count. Rejected
uploaded bytes still count toward rolling ingress, and stop counting toward
stored quota only after storage confirms deletion.

## Problem codes

Added in this slice, on top of the API-040 catalogue:

| Code | Status | Meaning |
|---|---|---|
| `UPLOAD_QUOTA_EXCEEDED` | 429 | a byte, object, or intent quota is exhausted |
| `UPLOAD_CONCURRENCY_LIMIT` | 429 | the actor already holds the maximum active sessions |
| `UPLOAD_EXPIRED` | 409 | the capability's two-hour lifetime elapsed |
| `UPLOAD_ALREADY_COMPLETED` | 409 | the session is terminal |
| `UPLOAD_INCOMPLETE` | 409 | no object arrived at the server-owned key |
| `UPLOAD_SIZE_MISMATCH` | 422 | observed bytes differ from the reservation |
| `UPLOAD_TYPE_MISMATCH` | 422 | magic bytes contradict the declared type |
| `UPLOAD_CHECKSUM_MISMATCH` | 422 | server-computed digest differs from the declared SHA-256 |
| `FILE_NOT_CLEAN` | 409 | the object has not passed security processing |
| `FILE_DELIVERY_DISABLED` | 409 | delivery is off until FILE-051 |
| `STORAGE_UNAVAILABLE` | 503 | private storage could not be reached |

The three `422` mismatch outcomes are *deterministic* results of inspecting
the bytes, so they are persisted as idempotency completions: a retry with the
same key replays the same rejection rather than re-reserving.

## Request flow

### Intent — `POST /v1/uploads`

1. Authenticate; run a read-only preparation check for purpose, relationship,
   and policy. A cross-tenant or unauthorized target is concealed as
   `404` here, **before** the signing adapter is ever called.
2. Generate the session id and object key inside the storage abstraction, and
   ask Supabase for a signed upload capability.
3. In one request-context transaction: reauthorize, lock and recheck quota,
   insert the session/reservation and a redacted audit event, and atomically
   store the `201` idempotency response.
4. Return the signed capability only after that transaction commits.

A capability created before a failed transaction is never disclosed, never
logged, and expires without enabling an upload.

The response carries only an opaque `uploadUrl`, the HTTP method (`PUT`), the
exact required headers, the session, and the expiry. It never exposes a
separate reusable object key. Signed URLs are redacted from logs, audit
records, errors, and telemetry.

Supabase's signed-upload lifetime is a fixed two hours, and the database
session expiry matches it. A retry after expiry needs a **new** idempotency
key, because the old key's stored response points at a dead capability. See
the [Supabase signed-upload
contract](https://supabase.com/docs/reference/javascript/file-buckets-createsigneduploadurl).

### Object key

Generated internally, never from caller data:

```
quarantine/v1/{serverUploadId}/{cryptographicallyRandomSegment}
```

The random segment is 24 bytes from `crypto.getRandomValues`, base64url
encoded. The key contains no filename, tenant id, resource id, or anything
the caller supplied. The bucket is the fixed private `private-school-files`,
written with `upsert: false`. The adapter re-validates this exact shape on
every `inspect` and `delete`, so a malformed or foreign location throws
rather than being read or removed.

### Completion — `POST /v1/uploads/{uploadId}/complete`

1. Resolve the server-owned path through a private owner-only query.
2. Inspect the exact object's metadata; a missing or partial upload is
   `UPLOAD_INCOMPLETE`.
3. Reject size mismatches *before* downloading oversized content.
4. For correctly sized objects, stream with a hard byte bound, compute
   SHA-256 server-side, and detect PDF/JPEG/PNG/WebP from magic bytes.
5. Compare actual size, digest, and detected type against the reservation and
   the purpose policy.
6. In one transaction: reauthorize the current relationship, then create the
   object, the session binding, the audit record, the scan-or-delete outbox
   job, the canonical response or deterministic error, and the idempotency
   completion.

Valid objects land `quarantined`. Mismatches become `rejected` and enqueue an
exact-key deletion job. **Nothing becomes `clean`.**

## Database and privilege posture

`studafy_api_runtime`, `authenticated`, and `anon` hold **zero** direct
grants on file, session, quota, and outbox tables. The API receives EXECUTE
on narrowly scoped `private.api050_*` functions only. Each independently
validates the verified actor, the transaction-local school and request id,
active membership, the exact target relationship, purpose, state, and inputs
— the middleware's decision is never trusted as the only check.

The private bucket is tightened to the union MIME allowlist with a 25 MiB
outer limit. No authenticated insert, select, list, update, or download
policy is restored on `storage.objects`.

Forward-only migration: `202609170003_file050_upload_pipeline.sql`.

Immutability is enforced by trigger, not convention: ownership, bucket, key,
and every target relationship column are pinned after insert, and each
ownership/target pair carries a same-school composite constraint. A missing
SHA is permitted only for objects rejected before a safe bounded read;
quarantined, scanning, and clean objects all require a server-computed SHA.

## Cleanup

`public.file_job_outbox` is durable and carries `scan` and exact-key `delete`
jobs. FILE-050 consumes only deletions; scan jobs stay `pending` for
FILE-051.

The worker claims deletion jobs with `FOR UPDATE SKIP LOCKED`, obtains the
exact server-owned key from `private.api050_claim_cleanup` — **job payloads
carry no path** — deletes only that object, and records success or retry with
capped exponential backoff and a dead-letter state after ten attempts. The
same claim call sweeps abandoned sessions to `expired` and enqueues their
deletion. A database row is marked `deleted` only after storage confirms
removal.

## Client boundary

The generated Dart client, DTOs, and typed domain models exist, and the
transport consumes the complete server URL verbatim, sends only the declared
bytes and required headers, follows no redirects, and never accepts or
constructs a storage path. The client computes its SHA-256 locally before
requesting an intent, but the **server-computed digest is authoritative**.
One idempotency key is preserved per intent/completion attempt across auth
refresh, response loss, and explicit retry.

No production UI invokes this adapter. `allowsRemoteFileUploads` is `false`,
remote file controls stay disabled with FILE-050/051 messaging, and there is
no SQLite queue or local-success fallback.

`scripts/check-file050-boundaries.ts` enforces the boundary in CI: no direct
Supabase Storage call, no `quarantine/v1/` path construction, and no
service-role reference outside the server storage adapter and the composition
roots.

## Configuration

| Setting | Default | Notes |
|---|---|---|
| `FILE050_NEW_INTENTS_ENABLED` | `false` | off; disabling still allows completion, status, and cleanup of already-issued sessions |
| `SUPABASE_SERVICE_ROLE_KEY` | unset | server-only; production fails closed if intents are enabled without it |
| `FILE050_CLEANUP_ENABLED` | `false` | worker-side; requires `DATABASE_URL`, `SUPABASE_URL`, and the service-role key |

## What FILE-051 owns

Malware scanning, parser validation, image transformation and EXIF removal,
the transition to `clean`, publication, deduplication, retention
reconciliation, and actual signed download delivery. The `scan` outbox job,
the `download-intent` route shape, and the same-school clean-deduplication
index are already in place so FILE-051 can activate delivery without changing
the v1 wire shape.
