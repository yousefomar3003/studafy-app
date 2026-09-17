# FILE-051 threat model

This is the attacker's-eye view of scanning, transformation, publication,
deduplication, retention and delivery. It extends
[`file050-threat-model.md`](file050-threat-model.md), which covers ingress.
The response procedure is
[`file051-malicious-file-runbook.md`](file051-malicious-file-runbook.md).

Scope: local and disposable use only. This model has not been independently
reviewed.

## Assets

- The bytes children and parents receive.
- The rule that a file is `clean` only because a recorded verdict made it so.
- The relationship between a file and who may see it (publication,
  enrollment, ownership, grading staff).
- Whether a school holds a given file, which must stay secret from every
  other school.
- The delivery signing key and the scanner credential.

## Trust boundaries

| Boundary | Crossing |
|---|---|
| Client → API | `POST /v1/files/{id}/publish`, `POST /v1/files/{id}/download-intent`, and `GET /delivery/v1/files/{id}/content` |
| API → database | `studafy_api_runtime` may execute only `api051_publish_file`, `api051_create_download_grant` and `api051_consume_download_grant` (plus the earlier surfaces) |
| Worker → database | `studafy_worker_runtime` may execute only the scan, transform write-ahead, backlog, retention and cleanup functions |
| Worker → storage | exact keys taken from the worker's own claims; read, overwrite with sanitized bytes, and delete |
| Worker → scanner | one configured origin, one POST, redirects refused |
| Operator → database | the containment and release functions, callable by no runtime role |

## Threats and mitigations

### S1 — Unscanned or hostile bytes reach a user

- `clean` is written in exactly one place: `api051_finish_scan`. It
  requires a scan policy version and a stored digest, and a table
  constraint enforces the same rule.
- The worker never reports `clean` until four things hold, in this order:
  1. the stored bytes hash to the uploaded digest, or to a transform digest
     it recorded earlier;
  2. the transform digest has been recorded *before* overwriting;
  3. the overwrite has been read back;
  4. the read-back digest matches exactly.

  A read-back with no digest counts as a mismatch.
- Scanning uses the **detected** media type. The type the client declared
  is ignored.
- Structural analysis rejects:
  - EICAR-signature content in any format and in any metadata payload;
  - trailing or appended bytes (polyglots) in JPEG, PNG, WebP and PDF;
  - PNG files with bad CRCs;
  - WebP files whose size accounting disagrees with their length;
  - animation;
  - PDF JavaScript, launch and open actions, embedded files, encryption, and
    active content hidden inside compressed streams;
  - decompression past per-stream and total caps (bombs).

  Anything outside the four supported types is `malformed`.
- An external provider, when configured, must *also* agree. Every
  non-authoritative provider answer is `infrastructure`, and an
  infrastructure verdict retries and dead-letters to `error`, never to
  `clean`. The unauthoritative answers include:
  - network error;
  - timeout;
  - a non-2xx status;
  - a redirect;
  - a malformed body;
  - a rejected credential.
- Production refuses to start the scan worker without the provider,
  because structural validation alone is not signature-grade detection.
- Delivery serves only bytes whose size and SHA-256 match the stored digest
  the scan recorded. A swapped object answers `503`, never its bytes.
- Responses are always attachments, carry `nosniff`, a sandboxed CSP,
  `no-store`, `no-referrer` and `same-origin` CORP, and use one of the four
  scanned media types or `application/octet-stream`.

Residual: the local structural scanner is not an antivirus engine. It
cannot recognise a well-formed image or PDF that exploits a decoder bug.
Images are cleaned by removing metadata segments deterministically, not by
decoding and re-encoding pixels. PDF content disarm and reconstruction (CDR)
is deferred.

### S2 — A leaked or replayed download link

- The link carries an HMAC-signed payload binding the file, the recipient,
  a 256-bit random nonce, and an expiry of at most 10 minutes (the API
  uses 5).
- The database stores only the nonce's SHA-256. A copy of the grants table
  cannot be turned back into a link.
- Consumption spends the grant atomically, so it works once.
- Consumption requires the recipient's own authenticated session. The API
  compares the payload's user with the session subject, and the database
  compares the grant's recipient with `auth.uid()`.
- After spending the grant, consumption **re-derives authorization from
  current state**. A withdrawn publication, an ended enrollment, a revoked
  membership, a contained file or a deleted file each deny a link that was
  valid when issued.
- Delivery never redirects to a storage-signed URL. That would be a standing
  grant for the URL's lifetime. A CI boundary check fails the build if any
  code mints `createSignedUrl(s)`.
- Tokens never appear in logs: request telemetry records the route pattern,
  not the URL.

Residual: the idempotency record of a download intent stores the link it
returned. Anyone who can read that record inside the five-minute window
still needs the recipient's session and an unspent grant.

### S3 — Publication as a copy or an escalation

- Publication creates exactly one resource, one immutable version, one
  classroom publication and one binding, and never a file object. Access is
  derived from the publication, enrollment and audience. The suite proves
  that thirty recipients share one physical object.
- The target classroom comes from the upload's own immutable binding, never
  from the request. The request accepts only `audience`, and unknown fields
  are rejected before authorization runs.
- The publisher must be a lead or co-teacher of that classroom, or a school
  admin. Authorization is checked **before** any state is revealed, so a
  non-publisher learns nothing about the file's scan state.
- Only `lesson_resource` files can be published, and a file can be
  published once.

### S4 — Cross-tenant deduplication side channel

- Dedupe candidates are chosen inside `api051_finish_scan` by `school_id`
  equality. They must also share the purpose, the transform policy and the
  stored digest, be clean roots, and be unheld. No query crosses schools.
- Dedupe happens asynchronously in the worker. Upload, completion and status
  responses are byte-for-byte the same shape whether or not a duplicate
  exists. The end-to-end check asserts the other school's status keys.
- Audit events record `deduplicated: true/false` only within the owning
  school.

Residual: timing differences in background work are not observable through
any client API.

### S5 — Deletion that loses or strands data

- The unit of deletion is one physical object: a root plus its dependents.
  Retention claims a unit only when **every** member meets all of these:
  - past its retention horizon;
  - not under legal hold;
  - no live reference (a draft or published resource, an open submission, a
    message, or an AI draft);
  - no deletion already in flight;
  - for dependents, redundant bytes already removed.
- Rows move to `deleted` only after storage confirms the deletion.
- Reconciliation compares the bucket index with the rows and reports five
  drift classes. Every count must be zero.
- Retention durations are not configured, so nothing is deleted on a
  schedule until the §29 retention decision is made.

### S6 — Worker or operator misuse

- Worker functions take no keys from callers. Each claim resolves the
  bucket and key from the immutable session.
- A claim is bound to its worker id, and a finish, transform record or
  retention finish from a different worker is refused.
- The worker role has `USAGE` on `private` and EXECUTE only on its own
  functions. It has no table grants and cannot publish or deliver.
- Containment and release are granted to no runtime role. Both require an
  operator identity and write attributed audit events.

### S7 — Configuration mistakes

- Every FILE-051 switch defaults to off.
- Production refuses to start in any of these cases:
  - delivery is enabled without a signing key or HTTPS base URL, or with a
    signing key equal to the cursor key;
  - scanning is enabled without the external scanner;
  - any file worker is enabled without the database and storage
    configuration it needs.
- `allowsRemoteFileUploads` stays `false`. Flipping it is a separate
  reviewed change.

## Known residual risk

- No real malware engine has been exercised. The provider adapter's API
  shape is provisional until a vendor is chosen (inputs.md Group 3, A6).
- Image cleaning removes metadata but does not re-encode pixels. There is no
  PDF content disarm and reconstruction.
- Any active teacher or admin in a school can view any publication in that
  school. This is the existing DB-021 audience policy, and delivery inherits
  it.
- There is no production alerting (OPS-090). Detection is by query and log.
- There has been no independent penetration test of the file surface. That
  is a Phase 5 gate condition still open.
