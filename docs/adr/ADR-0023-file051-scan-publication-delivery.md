# ADR-0023: FILE-051 scanning, publication, deduplication, retention and re-authorizing delivery

- Status: Accepted for local/disposable use
- Date: 2026-09-17
- Decision log: DL-044

## Context

FILE-050 built a pipeline with no exit. It accepted bytes into a private
bucket, verified their size, type and digest, and left them `quarantined`
with no path to `clean`, to a user, or out of storage except rejection.
Phase 5B (§11, §20) is that exit. Four requirements drive it:

1. Only a clean, scanned object may be published, and publication must
   derive access without copying bytes.
2. A signed delivery URL must re-check authorization when it is used. A
   leaked URL must not be a standing grant.
3. Deduplication must not let one school learn that another holds the same
   file.
4. The malicious-file response must be documented and rehearsed.

There is no malware scanning vendor yet (inputs.md Group 3, A6), no approved
retention schedule (§29), and no production environment.

## Decision

One forward-only migration, `202609170004_file051_scan_delivery_publication.sql`,
extends the FILE-050 chain: the same outbox, claim/finish shape,
rename-and-fallback authorization evaluator, idempotency and audit. The
route contract is in `docs/api/v1-file-contract.md`, the threat model in
`docs/security/file051-threat-model.md`, and the response procedure in
`docs/security/file051-malicious-file-runbook.md`.

**`clean` has exactly one writer, and it requires evidence.**
`api051_finish_scan` is the only code that sets `clean`. It requires a scan
policy version and a verified stored digest, and a table constraint repeats
the rule. Infrastructure failures return the object to quarantine with capped
backoff and dead-letter to `error`. There is no fail-open path.

**The scanner is a composition, and production requires both halves.**
The deterministic structural analyser lives in `@studafy/domain`: pure
functions with no I/O apart from bounded in-memory inflate. It walks JPEG,
PNG, WebP and PDF strictly and rejects:

- EICAR-signature content in any position, including metadata payloads;
- polyglot files and trailing bytes;
- CRC and size-accounting errors;
- animation;
- PDF actions, JavaScript, embedded files and encryption;
- decompression bombs.

`FileSecurityScanner` runs that analyser first and then the external
provider. A provider "malicious" verdict is terminal. Every
non-authoritative provider answer is `infrastructure`: network error,
timeout, non-2xx status, redirect, malformed body or rejected credential.
Local and disposable runs use the structural analyser alone. Production
refuses to scan without the provider, because structure is not
signature-grade detection. The provider client talks to one configured
origin with one request shape, and its API contract is provisional until a
vendor is chosen. Swapping in the real vendor is a reviewed change to that
adapter only.

**Transformation is deterministic metadata removal, and it is
write-ahead.** Images are rewritten without EXIF, XMP, ICC or text segments
by deterministic structural rewriting, not by decoding and re-encoding
pixels. The rewrite is idempotent, so a retried scan converges. PDFs are
stored unchanged, and content disarm and reconstruction (CDR) is deferred
until fidelity and accessibility have been evaluated (§11 control 7).

The worker follows a strict order:

1. record the stored digest (`api051_record_transform`);
2. overwrite the object;
3. read it back and require an exact match;
4. only then report `clean`.

Recording the digest first means a retry after a lost finish recognises its
own write instead of treating it as tampering. Recording `clean` last means
a torn sequence is never reported as clean. The row keeps the uploaded
SHA-256 as the content identity and records the stored digest separately.

**Publication derives access; it never copies bytes.**
`POST /v1/files/{id}/publish` accepts only an audience. It resolves the
classroom from the upload's own binding, authorizes the lead teacher,
co-teacher or admin *before* revealing any state, and requires a clean,
never-published `lesson_resource`. In one transaction it creates one
resource, one immutable version, one classroom publication and one binding.
Recipients reach the object through the existing DB-021 audience helper,
which also re-checks cleanliness. The pgTAP suite proves that thirty
enrolled students share one physical object. The existing
`withdrawResource` withdraws a publication.

**Delivery is a single-use grant, re-authorized when it is used, and
streamed through the API.** A download intent signs an HMAC token binding
the file, the recipient, a 256-bit nonce and a five-minute expiry. The grant
row stores only the nonce's SHA-256, so the table cannot be replayed into
links. `GET /delivery/v1/files/{id}/content` checks the token and that it
belongs to the session subject. Then `api051_consume_download_grant` spends
the grant atomically and re-derives access from **current** state, so
withdrawal, enrollment end, membership revocation or containment deny a link
that was valid when issued.

The API then streams the exact bytes whose size and digest match the scan
record, as a sandboxed, `nosniff`, `no-store` attachment. A redirect to a
Supabase signed URL was rejected because that URL is a standing grant for
its lifetime, and CI now fails if any code mints one. The endpoint sits
outside the JSON `/v1` catalogue because it returns bytes. It is
authenticated by the router, and its authorization is the consume command,
which uses the same `file051_authorize_download` that decides
`file.download`.

**Deduplication is school-scoped and invisible.** When a file is scanned
clean, the worker looks for a canonical root with the same school, purpose,
uploaded digest, transform policy and stored digest, which is clean and not
held. A match turns the new row into a dependent and queues exact-key
deletion of its redundant bytes. No query crosses schools, dedupe runs in
the background, and no response or audit field outside the owning school
reveals that it happened. Deduplication is also the reason the unit of
deletion is a *physical object*, not a row.

**Retention ships as a mechanism without a schedule.**
`retention_interval_days` stays `NULL` until the §29 decision. The sweep
claims a root and its dependents only when every member meets all of these
conditions:

- past its horizon;
- not held;
- no live reference;
- for dependents, redundant bytes already removed;
- no deletion already in flight.

Rows become `deleted` only after storage confirms the deletion. A
reconciliation check compares the bucket index with the rows across five
drift classes, and must report zero.

**Containment is an operator primitive.** `file051_contain_object` acts on
a whole dedupe group in one transaction. It moves every member out of
`clean`, withdraws its publications, expires outstanding grants, applies a
legal hold and writes an attributed audit event.
`file051_release_contained_object` lifts the hold and queues exact-key
deletion. Neither function is granted to a runtime role. The runbook is
rehearsed by `apps/api/scripts/file051-malware-drill.ts`.

**Least privilege holds, and one FILE-050 gap is closed.** The API gains
EXECUTE on three commands. The worker gains its own functions and `USAGE` on
`private`. FILE-050 had granted the worker its functions without schema
usage, so the cleanup worker could only ever run as a privileged role. That
gap was found by running the workers as `studafy_worker_runtime` for the
first time. Neither role gains a table grant.

**Everything defaults off.** `FILE051_PUBLISH_ENABLED`,
`FILE051_DELIVERY_ENABLED`, `FILE051_SCAN_ENABLED` and
`FILE051_RETENTION_ENABLED` all default to `false`. Production fails closed
on missing or reused keys, a non-HTTPS delivery origin, or a missing scanner.
`allowsRemoteFileUploads` stays `false`, and flipping it is a separate
reviewed change with its own decision-log entry.

## Consequences

- Phase 5's engineering gate conditions are met locally: all bytes are
  quarantined and scanned, publication derives access without copies,
  signed delivery re-authorizes, and quota, retention, reconciliation and
  the malicious-file response are verified. The human conditions are not
  met: an independent file penetration test, a real scanner vendor and
  approved retention periods.
- The local structural scanner can say "not well-formed" and "contains the
  EICAR signature". It cannot recognise a decoder exploit hidden in a
  well-formed file. Until a vendor is wired in, *clean* means
  *structurally sound and metadata-stripped*, not *malware-free*.
- Images keep their original pixel stream. A payload inside the image data
  itself is not neutralised.
- A spent grant is spent even if streaming then fails. The client asks for a
  new link. This favours single use over convenience.
- The idempotency record of a download intent stores the link it returned.
  That is bounded by the five-minute expiry, the single use, and the need
  for the recipient's own session.
- Every active teacher or admin in a school can view every publication in
  it, inherited from DB-021. Delivery is no narrower than that policy.
- Dependents cannot be rescanned in place because their bytes are gone. A
  policy change is handled by containing and re-uploading, not by requeueing
  files to clean.

## Alternatives considered

- **Redirecting to a storage-signed download URL.** Rejected: it is a
  standing grant for the URL's lifetime and cannot re-check authorization.
- **Per-recipient copies on publication.** Rejected by §11 control 9 and
  by the thirty-recipient acceptance test.
- **Global (cross-school) content-addressed dedupe.** Rejected: it creates
  a tenant-existence side channel, and the retention and legal-hold
  domains differ.
- **Re-encoding images through a native image library.** Deferred: it adds
  a native decoder, which is itself attack surface, to the worker. The
  deterministic strip meets the EXIF/GPS requirement now.
- **Scanning inline at completion.** Rejected in ADR-0022 and still
  rejected.
- **Treating structural validation as sufficient in production.** Rejected:
  it is not signature-grade detection, so production fails closed without
  the provider.
