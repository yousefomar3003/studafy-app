# ADR-0017: AUTH-031 server authorization and tenant context

- Status: Accepted for local/disposable use
- Date: 2026-09-14
- Decision log: DL-038
- Extends: ADR-0002, ADR-0014 and ADR-0016

## Context

AUTH-030 verified identity and loaded memberships, but protected route actions
were implicit and there was no reusable object-authorization or tenant
middleware. Copying role checks into handlers would drift from DB-021, and a
client-selected school context would turn multi-school identities into a BOLA
boundary.

## Decision

Every protected handler declares one action from a code-owned permission
catalogue. Self actions use the verified actor. Resource actions send only the
opaque resource ID to a narrow private database function. That function derives
tenant from the stored resource and applies DB-021's private helpers and policy
predicates. The middleware requires that decision and the freshly loaded
active-membership context to name the same school.

Tenant context is version-cached; resource relationships are not. Cache keys
contain the database membership version, and a new version or missing active
membership evicts the old user/school entry. This gives membership revocation
next-request behavior without allowing a cached classroom or guardian grant.

The API role receives EXECUTE on one new private function and still has no
table, column, sequence, public-schema, RLS-bypass or inheritance privilege.
Denied object requests are concealed as 404. Unknown actions and unavailable
authorization storage fail closed.

## Consequences

- A tenant header/body/JWT claim is irrelevant even if a caller supplies one.
- New handlers cannot use a string invented at the call site; TypeScript limits
  them to the reviewed catalogue and the route inventory test proves every
  shipped handler has middleware.
- The API and DB policy expressions remain two defence layers, so executable
  parity tests compare them rather than relying on review alone.
- Composite child rows without their own UUID authorize through a catalogued
  parent and remain RLS-filtered in the bounded query.
- Membership grant/revoke actions are reserved, but the API-042 commands and JIT
  platform-support workflow stay fail-closed until their product/operator
  decisions are approved.

## Recovery

Disable a resource route rather than bypassing its permission. A defect in the
private function is corrected by a forward migration. Rollback must never add
broad table grants, disable RLS, trust a client tenant, or cache relationship
decisions.

## Open

Independent BOLA/BFLA review is still required by §20. Platform-support JIT,
school membership command UX, and rate limiting are later gated work. This local
decision does not authorize remote deployment or close the Phase 3 gate.
