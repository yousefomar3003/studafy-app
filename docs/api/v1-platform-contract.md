# `/v1` platform contract and inventory

The canonical machine-readable contract is
[`packages/contracts/openapi/v1.json`](../../packages/contracts/openapi/v1.json).
It is generated from pinned Zod schemas plus `V1_ROUTE_CATALOGUE`; editing the
JSON or generated Dart client directly is rejected by `bun run generate:check`.

## Compatibility and wire rules

- `/v1` accepts additive compatible response fields. A breaking semantic or
  request change requires `/v2` plus a supported-client migration plan.
- JSON fields are camelCase, timestamps are UTC RFC 3339 and IDs are opaque.
- Request objects and declared query parameters are closed allowlists.
  Undeclared query fields are rejected before authorization.
- Errors are `application/problem+json` and use the documented top-level
  `ProblemDetails` schema. Internal exceptions are never a client detail.
- Browser CORS is disabled by default. Configured origins must match exactly;
  native bearer-token clients do not depend on CORS.
- Body limit: 65,536 bytes. JSON depth: 12. Total object keys: 128. Total
  request deadline: 10 seconds.

## Route catalogue

| Method and path | Permission | Idempotency |
|---|---|---|
| `GET /v1/me` | `account.profile.read` | none |
| `GET /v1/auth/context` | `account.context.read` | none |
| `GET /v1/auth/devices` | `account.devices.read` | none |
| `POST /v1/auth/devices/revoke` | `account.device.revoke` | required |
| `POST /v1/auth/sign-out` | `account.session.revoke` | required |
| `POST /v1/auth/reauth/challenge` | `account.reauth.challenge` | required |
| `POST /v1/auth/reauth/verify` | `account.reauth.verify` | forbidden |
| `POST /v1/auth/identities/link` | `account.identity.link` | required |
| `POST /v1/auth/identities/unlink` | `account.identity.unlink` | required |
| `GET /v1/account/deletion-impact` | `account.deletion.impact` | none |
| `POST /v1/account/deletion-request` | `account.deletion.request` | required |
| `POST /v1/account/deletion-cancel` | `account.deletion.cancel` | required |

The route-table test proves this catalogue equals the mounted Hono `/v1`
surface and that each entry agrees with the AUTH-031 permission declaration.
API-041 adds 40 academic routes; their human-readable inventory and state
semantics are in [`v1-academic-contract.md`](v1-academic-contract.md). The
generated OpenAPI catalogue is authoritative for the combined 52-route surface.

## Idempotency protocol

Required commands accept `Idempotency-Key` matching
`^[A-Za-z0-9][A-Za-z0-9._:-]{15,127}$`. A matching completed replay returns the
stored status/body and `Idempotency-Replayed: true`. A changed request or live
reservation returns 409; a live reservation also returns `Retry-After: 1`.
Keys are scoped by server-derived tenant (or global scope), verified actor and
operation. The key and canonical request hash are not authority: authentication
and AUTH-031 authorization still run before reservation.

## Cursor protocol and inventory boundary

Paginated operations use an opaque HMAC-SHA-256 cursor signed with the
independent `API_CURSOR_SIGNING_KEY`. It binds cursor version, filter version,
operation, server-visible school, filter hash and deterministic UUID position;
tampering or reuse with another operation/school/filter returns
`CURSOR_INVALID`. Page size defaults to 50 and is capped at 100.

The former `approve-paper-grade` and `publish-grade-result` Deno sources and
Flutter invocation paths were removed after API-041 parity. They were not
deployed in the inspected synthetic project, so no remote undeployment or
production traffic claim is made. Other Edge Functions stay outside this
inventory until their owning phases reach parity.
