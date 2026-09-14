# AUTH-031 permission catalogue and tenant boundary

Status: implemented and verified locally on 2026-09-14. This document is the
reviewable catalogue for `apps/api/src/authorization/catalogue.ts`; the
TypeScript object is the executable source of permission names.

## Decision model

Every protected handler declares exactly one stable action. Authentication
establishes a verified global user. For a resource action, the handler passes
only the resource's opaque ID to `private.authz_authorize(action, id)`. The
database resolves the stored `school_id` and evaluates the same lifecycle, role,
relationship, audience and publication predicates as DB-021. The client cannot
establish tenant context through a header, JSON field, role selection, OAuth
metadata or JWT claim.

The middleware accepts a returned school only when the freshly loaded membership
context independently includes an active membership for it. It then builds
tenant context from those server rows. Cross-school, wrong-role, wrong-class and
wrong-child object denials return the same 404 response; an object ID is not an
existence oracle. Missing credentials return 401. A known non-object action
denied to an authenticated actor returns 403.

Tenant context is cached for at most 15 seconds under
`{user_id, school_id, membership_version}`. `membership_version` comes from the
database and changes on membership mutation. Old versions for the same
user/school are evicted when a new context is resolved, and explicit
invalidation is available for grant/revoke commands. Relationship decisions
(class staff, enrollment, guardian link, audience and publication state) are
never cached, so their revocation is checked on every action.

## Shipped protected handlers

| Method and path                     | Required permission        | Resource scope                                     |
| ----------------------------------- | -------------------------- | -------------------------------------------------- |
| `GET /v1/me`                        | `account.profile.read`     | authenticated self                                 |
| `GET /v1/auth/context`              | `account.context.read`     | authenticated self                                 |
| `GET /v1/auth/devices`              | `account.devices.read`     | authenticated self                                 |
| `POST /v1/auth/devices/revoke`      | `account.device.revoke`    | owned device; recent auth                          |
| `POST /v1/auth/sign-out`            | `account.session.revoke`   | authenticated self                                 |
| `POST /v1/auth/reauth/challenge`    | `account.reauth.challenge` | current session                                    |
| `POST /v1/auth/reauth/verify`       | `account.reauth.verify`    | current session; policy MFA                        |
| `POST /v1/auth/identities/link`     | `account.identity.link`    | authenticated self; MFA/recent auth where required |
| `POST /v1/auth/identities/unlink`   | `account.identity.unlink`  | authenticated self; MFA/recent auth where required |
| `GET /v1/account/deletion-impact`   | `account.deletion.impact`  | authenticated self                                 |
| `POST /v1/account/deletion-request` | `account.deletion.request` | authenticated self; recent auth                    |
| `POST /v1/account/deletion-cancel`  | `account.deletion.cancel`  | authenticated self; safe-direction exception       |

`AUTH_HANDLER_PERMISSIONS` is compared to Hono's actual route table. The test
requires one permission middleware per handler and sends an unauthenticated
request to every declared route to prove enforcement. Adding a protected handler
without extending the inventory fails the suite.

## DB-021 resource actions

| Permission                                                            | Resource relationship/state rule                                                                                                                      |
| --------------------------------------------------------------------- | ----------------------------------------------------------------------------------------------------------------------------------------------------- |
| `school.read`, `term.read`                                            | Active school membership; learner/guardian terms must be active                                                                                       |
| `student.read`                                                        | Admin, self student, verified guardian, or exact assigned class staff                                                                                 |
| `guardian_link.read`                                                  | Admin, linked guardian/student, or exact assigned class staff                                                                                         |
| `classroom.read`, `class_schedule.read`, `classroom_staff.read`       | Admin or exact staff/enrollment/verified-child relationship as applicable                                                                             |
| `lesson_session.read`, `lesson_material.read`                         | Staff see exact class; learners see completed/filed, non-deleted content                                                                              |
| `assignment.read`, `assessment.read`                                  | Staff see exact class; learners/guardians see published exact class                                                                                   |
| `submission.read`, `grade_result.read`, `attendance_record.read`      | Exact class/student relationship; learner grades must be published                                                                                    |
| `assessment_question.read`                                            | Exact staff class; learners only get published practice questions                                                                                     |
| `wellbeing_event.read`                                                | DB-021 visibility classification, creator and exact relationship                                                                                      |
| `announcement.read`, `meeting.read`                                   | Creator/admin/exact staff or matching published/scheduled audience                                                                                    |
| `notification.read`                                                   | Exact recipient                                                                                                                                       |
| `subscription_entitlement.read`, `consent_record.read`                | Authenticated owner; global rather than tenant-owned. Consent authorizes the profile collection because row IDs are bigint, then RLS filters its rows |
| `practice_session.read`                                               | Admin, exact staff, or exact enrolled student                                                                                                         |
| `resource.read`, `resource_version.read`, `resource_publication.read` | Admin/teacher or exact safe, clean, published audience                                                                                                |
| `membership.grant`, `membership.revoke`                               | Reserved for API-042 bounded commands; active admin in the resource-derived school, with self-last-admin revocation denied                            |

Composite child collections without a standalone UUID (for example an enrollment
or meeting delivery) must declare the parent resource permission and query
through a bounded repository whose returned rows remain filtered by RLS. They do
not accept a caller-supplied school as a substitute key.

## Proof and least privilege

- `supabase/tests/auth031_authorization_seed.sql` compares the private API
  decision with direct DB-021 RLS for assigned teacher, same-school unassigned
  teacher, cross-school substitution, student publication state,
  verified/expired guardian links and clean/quarantined resources.
- `apps/api/test/authorization/parity.integration.test.ts` runs an actual `/v1`
  Hono handler and the direct RLS query against the same local rows. It covers
  allow, cross-tenant denial, and membership revocation after a cached context
  was populated.
- `studafy_api_runtime` still has zero table, column and sequence grants. Its
  only AUTH-031 addition is EXECUTE on `private.authz_authorize(text, uuid)`.
- No DB-021 policy or client/service grant was weakened.

Future resource handlers must add their route declaration and an allow/deny test
before they can ship. If their semantics are not expressible by a catalogued
action, the catalogue, SQL decision and API/RLS parity fixture must be extended
together.
