# ADR-0018: API-040 shared API platform controls

- Status: Accepted for local/disposable use
- Date: 2026-09-14
- Decision log: DL-039
- Extends: ADR-0011, ADR-0016 and ADR-0017

## Context

The Hono bootstrap had server-generated request IDs and health/version routes,
but request parsing, errors, resource bounds, command replay handling and
outbound-provider safety were not uniform. AUTH-030 routes also used a legacy
nested error shape and snake_case wire fields. A process-local replay cache
would lose correctness on restart or across API replicas, while granting the
API direct table access would weaken DB-021's last line of defence.

## Decision

Every request inherits the ordered platform stack in the existing bootstrap:
server-generated correlation, hardened/no-store response headers, allowlisted
telemetry, exact-origin CORS and protocol checks, bounded body parsing, then a
10-second total deadline with an abort signal for downstream calls. JSON bodies
are limited to 64 KiB, 12 levels and 128 object keys. Compressed bodies,
ambiguous singleton headers, invalid UTF-8/JSON, unsupported methods/media and
unapproved origins fail before authentication or use-case execution.

All current `/v1` inputs use pinned Zod 4.6.1 strict objects and camelCase wire
fields. Handlers receive the parsed allowlist and explicitly pass named values;
they never spread an unvalidated body into a repository. A single route
catalogue records method, path, operation ID, permission, request/response
schema and idempotency mode. It generates OpenAPI 3.1 and the checked-in Dart
client, with drift checks in CI. `/v1/classrooms` is not published because no
API-041 handler exists.

Failures use top-level `application/problem+json` with `type`, `title`,
`status`, stable `code`, safe `detail` and `requestId`. Validation may expose at
most 16 declared-field `{path, code}` entries. Raw exceptions, SQL, stacks,
provider bodies, tokens, receipts, content, signed URLs and object paths are
excluded from responses and recursively redacted from API logs.

Mutating operations declare `required`, `forbidden` or `none` idempotency.
Device revocation, sign-out, reauth challenge, identity link/unlink, deletion
request and cancellation require a 16–128 character key. Reauth verification
forbids one so a one-time grant can never become a stored replay. Reservations
are PostgreSQL records scoped by tenant-or-global scope, verified actor,
server-owned operation and key, with a canonical SHA-256 request hash. A
24-hour retention window and 15-second lease exceed the request deadline;
generation tokens prevent stale completion after takeover. Matching completed
requests replay the bounded JSON response, mismatches and live reservations
return 409, and uncertain completion keeps the lease rather than permitting an
immediate duplicate.

The API runtime retains zero table/column/sequence grants and receives EXECUTE
only on three `private.api_idempotency_*` SECURITY DEFINER functions. Those
functions derive the actor from `auth.uid()` and independently validate active
tenant membership. No DB-021 RLS policy or existing grant is loosened.

Outbound provider integrations use configured origins plus relative paths.
The shared client requires HTTPS in production, rejects URL credentials,
IP literals and unsafe DNS answers, manually validates every redirect, and
bounds redirects, response bytes and total time. Supabase's configured local
JWKS development path remains separate and keeps its existing no-redirect
behavior.

## Consequences

- Protocol, validation and safe-error behavior no longer varies by handler.
- Mobile retries carry one key through the transport's single authentication
  refresh/retry; callers may supply a stable key for a wider retry lifecycle.
- Durable reservation adds a database round trip before and after successful
  commands, but remains available across processes and restarts.
- A command side effect and idempotency completion are not one transaction for
  every future provider-backed flow. Those use cases must add their own state
  machine/outbox invariant; an uncertain completion remains leased meanwhile.
- API-041 subsequently supplied the signed cursor/tamper implementation before
  mounting its first paginated route; see ADR-0019. This supersedes the local
  deferral without changing API-040's platform decision.

## Recovery

Disable the affected command or route rather than bypassing validation or
idempotency. Correct database behavior through a forward migration. Recovery
must not grant table access, disable RLS, trust a client tenant, accept an
arbitrary URL or revert to an in-memory replay map.

## Open

DNS validation cannot alone eliminate rebinding between resolution and socket
connection. Production requires the isolated egress/firewall control planned
later. Cloudflare provenance, distributed rate limits, production RED metrics,
tracing and log retention remain Phase 6 work. This local decision authorizes
no deployment or real-data processing.
