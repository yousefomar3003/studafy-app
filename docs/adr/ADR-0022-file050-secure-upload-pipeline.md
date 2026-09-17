# ADR-0022: FILE-050 secure upload pipeline

- Status: Accepted for local/disposable use
- Date: 2026-09-17
- Decision log: DL-043

## Context

SEC-001 was the worst vulnerability this repository has carried: a
caller-selected file path signed by a service role. A client named a location
and received write authority to it. The containment response disabled the
upload surface outright, and it has been disabled ever since —
`allowsRemoteFileUploads` is `false`, and the product has had no working file
capability at all.

That containment is not a design. Profile images, lesson resources,
assignment materials and submissions, paper scans, and coach attachments are
all real product requirements, and every one of them needs to move bytes.
FILE-050 rebuilds that capability with the vulnerable shape made
unrepresentable rather than merely validated against.

The slice deliberately stops before delivery. Accepting bytes safely and
serving bytes safely are different problems with different failure modes, and
combining them would mean shipping unscanned files to children on the same
day the pipeline first works.

## Decision

FILE-050 extends the already-shipped chain — route catalogue, one
`SECURITY DEFINER` dispatcher family per domain via the rename-and-fallback
pattern, one idempotency table, one audit/outbox mechanism, one permission
catalogue — rather than introducing its own transport or authorization. One
forward-only migration, `202609170003_file050_upload_pipeline.sql`. The route
contract is in `docs/api/v1-file-contract.md` and the attacker's-eye view is
in `docs/security/file050-threat-model.md`; this record covers the decisions
that are not evident from the routes alone.

**Server-owned paths, structurally.** The key is generated inside the storage
adapter as `quarantine/v1/{serverUploadId}/{24 cryptographically random
bytes}`, in the fixed private `private-school-files` bucket, with
`upsert: false`. It contains no filename, tenant id, resource id, or anything
caller-derived. The intent request schema has no path, key, bucket, owner, or
scan-state field, so those are not "rejected" so much as absent — a
`strictObject` turns every one of them into a `400` before authorization
runs. Completion resolves the path through a private owner-only query and
accepts nothing from the client. Job payloads carry no path either; the
worker's exact key comes from its claim. A CI boundary script fails the build
if a handler or Flutter file ever calls storage, builds a `quarantine/v1/`
path, or touches the service-role credential outside a composition root.

The alternative — validating a client-supplied path against an allowlist —
was rejected. It is the same shape as SEC-001 with a filter in front of it,
and filters are the part that gets bypassed.

**Ownership and binding are one model.** Every object row records owner,
tenant, authorizing membership, purpose, normalized display name, policy
version, size, declared and detected type, server-computed SHA-256, and scan
state. Default scan state is `quarantined`. Every registered object receives
an immediate durable binding to its upload session, so an object can never
exist unattached. Ownership, bucket, key, and every target relationship column
are pinned by immutable-column trigger, and each ownership and target pair
carries a same-school composite constraint — a cross-school pairing is
unrepresentable at the schema level rather than checked for.

A missing SHA is permitted only for objects rejected before a safe bounded
read. Anything quarantined, scanning, or clean must carry a server-computed
digest. The client computes a digest too, and it is treated as a declaration
to verify, never as the authority.

**Quotas are decided server-side, before signing, under a lock.** Six limits:
per-user rolling bytes, per-school rolling bytes, per-school stored bytes,
per-school live objects, per-user hourly intents, per-user active sessions.
Decisions serialize on the school's quota-policy row, so concurrent last-slot
and last-byte races resolve to exactly one winner — proven with two real
backends, not inferred. Active reservations count against the limits, so a
flood of unfinished intents cannot be used to bypass accounting. At
completion the reservation is replaced with observed bytes. Rejected bytes
still count toward rolling ingress and stop counting toward stored quota only
after storage confirms deletion.

**Two-hour capabilities, taken from the provider rather than chosen.**
Supabase's signed-upload lifetime is fixed at two hours and cannot be
configured, so the database session expiry matches it exactly rather than
inventing a second, drifting deadline. The consequence is documented rather
than hidden: a retry after expiry needs a **new** idempotency key, because the
old key's stored response points at a dead capability.

**The capability is minted before the transaction, and disclosed after it.**
Signing happens outside the commit; the session insert, quota re-check, audit
event, and idempotency response commit together; only then is the URL
returned. A capability created before a failed transaction is never logged and
expires without enabling an upload. This costs an occasional orphaned
signature and buys the guarantee that no client ever holds write authority the
database does not know about.

**Completion verifies bytes, and rejects deterministically.** Size mismatches
are caught before downloading oversized content. Correctly sized objects are
streamed under a hard byte bound, digested server-side, and type-detected from
magic bytes against a four-format allowlist. Valid objects stay
`quarantined`; mismatches become `rejected` and enqueue exact-key deletion.
**No code path sets `clean`.**

Because size, type, and checksum mismatches are deterministic properties of
the bytes, they are persisted as idempotency completions with a `422`, so a
retry replays the rejection instead of re-reserving quota. The shared
idempotency middleware was adjusted for exactly this: a domain transaction may
atomically persist a deterministic non-2xx outcome, and the middleware then
never releases that already-completed reservation. Transient `5xx` responses
remain ineligible.

**Least privilege is unchanged, not relaxed.** `studafy_api_runtime`,
`authenticated`, and `anon` keep zero direct grants on file, session, quota,
and outbox tables. The API receives EXECUTE on narrow `private.api050_*`
functions only, and each independently re-validates the verified actor,
transaction-local school and request id, active membership, exact target
relationship, purpose, state, and inputs. The middleware's decision is never
the only check. No authenticated insert, select, list, update, or download
policy is restored on `storage.objects`.

**Cleanup is an outbox, and deletion is confirmed before it is recorded.**
`public.file_job_outbox` carries `scan` and exact-key `delete` jobs;
FILE-050 consumes only deletions and leaves scan jobs pending for FILE-051.
The worker claims with `FOR UPDATE SKIP LOCKED`, and the same claim call
sweeps abandoned sessions to `expired` and enqueues their deletion. A row is
marked `deleted` only after storage confirms removal, so the database never
claims a deletion that did not happen.

**The client is a transport, not a participant.** The Flutter transport
consumes the complete server URL verbatim, sends only the declared bytes and
required headers, follows no redirects, and never accepts or constructs a
path. There is no SQLite queue and no local-success fallback: an upload
either reaches the server or fails visibly. No production UI invokes the
adapter.

## Consequences

- The SEC-001 class is closed structurally. Reintroducing it requires
  deleting a CI check, changing the adapter, and adding a schema field.
- The product still cannot show a file to a user. That is intentional and it
  is FILE-051's gate, but it means FILE-050 delivers no user-visible value on
  its own.
- Accepted objects are inert but **unexamined**. Magic-byte detection
  establishes format, not safety; a well-formed PDF carrying a payload passes
  FILE-050 and sits in quarantine. Anyone reading the scan state as a safety
  signal would be wrong.
- The two-hour ceiling is the provider's. If Supabase changes it, the
  database expiry and the retry guidance both have to move.
- Quota defaults are engineering estimates and have not been capacity
  planned.
- Storage-failure behaviour is proven against a fake, not an induced outage.

## Alternatives considered

- **Direct client upload with an RLS policy on `storage.objects`.** Rejected:
  it puts tenancy enforcement in storage policies rather than in the
  relationship checks that already exist, and it reopens a client-visible
  path surface.
- **Validating a client-supplied path.** Rejected as SEC-001 with a filter.
- **Scanning inline at completion.** Rejected: it couples ingress
  availability to scanner availability, and makes the completion transaction
  depend on an unbounded external call. The outbox already exists.
- **Marking small, image-only uploads clean immediately.** Rejected: it
  creates two safety classes and a reviewer has to reason about which files
  were examined.
- **A shorter capability lifetime.** Not available; the provider fixes it.
