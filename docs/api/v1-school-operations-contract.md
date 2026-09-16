# `/v1` school operations contract (API-042)

Status: implemented and verified for local/disposable synthetic use on
2026-09-16. This document does not authorize a production deployment or real
school/student data. OpenAPI remains the machine-readable source of truth at
`packages/contracts/openapi/v1.json`.

API-042 makes every remaining launch product workflow authoritative: school
provisioning/closure, invitations and membership lifecycle, classroom
staffing and enrollment (including the roster prerequisites — terms and
student records — that classroom creation and enrollment themselves depend
on), family linking, communications, meetings, notifications, profile/account
rights, and time-bounded support access. It is additive to AUTH-031/API-040/
API-041: the same route catalogue, SQL-dispatcher, idempotency, audit/outbox
and permission-catalogue patterns are extended, not replaced.

## Route inventory

44 routes, indices 52–95 of `V1_ROUTE_CATALOGUE`. Every POST declares exactly
one AUTH-031 permission and requires `Idempotency-Key`; every GET is
cursor-paginated where the response has an `items` array. `/internal/*`
routes are authenticated exactly like `/v1/*` — same JWT verification, same
permission middleware — the prefix only marks them as not part of the
product-facing surface.

| Slice | Reads | Commands |
|---|---|---|
| Schools | — | `POST /v1/schools`, `/{schoolId}/suspend`, `/{schoolId}/close` |
| Roster (terms/students) | — | `POST /v1/schools/{schoolId}/terms`, `/v1/schools/{schoolId}/students` |
| Memberships | — | `POST /v1/schools/{schoolId}/memberships/grant`, `/v1/memberships/{membershipId}/activate`, `/suspend`, `/revoke` |
| Classroom staffing | — | `POST /v1/classrooms/{classroomId}/staff/assign`, `/staff/remove` |
| Enrollment | — | `POST /v1/classrooms/{classroomId}/enrollments/enroll`, `/withdraw`, `/transfer` |
| Invitations | `GET /v1/schools/{schoolId}/invitations` | `POST /v1/schools/{schoolId}/invitations`, `/v1/invitations/{invitationId}/revoke`, `/v1/invitations/accept` |
| Family | — | `POST /v1/students/locate`, `/v1/guardian-links`, `/{guardianLinkId}/verify`, `/revoke` |
| Communications | `GET /v1/conversations`, `/{conversationId}/messages`, `/v1/announcements` | `POST /v1/conversations`, `/{conversationId}/messages`, `/v1/announcements` |
| Meetings | `GET /v1/meetings/{meetingId}` | `POST /v1/classrooms/{classroomId}/meetings`, `/v1/meetings/{meetingId}/cancel` |
| Notifications | `GET /v1/notifications`, `/unread-count`, `/preferences` | `POST /v1/notifications/mark-read`, `/preferences` |
| Account rights | `GET /v1/account/export-status` | `POST /v1/account/profile`, `/v1/account/export-request` |
| Support access | `GET /internal/support-access` | `POST /internal/support-access`, `/{supportGrantId}/approve`, `/start`, `/revoke` |

## Authorization notes specific to API-042

- **Platform-operator/school-admin grants are never issued over any API.**
  `public.platform_operators` has no INSERT/UPDATE route; granting it is a
  deliberate, out-of-band, service-role-only operation (see the operator
  runbook). `school.provision`, `support_access.*` and the roster commands
  all check `is_platform_operator()`/`is_school_admin()` independently in
  SQL — the permission-catalogue entry only decides whether a request
  reaches that check.
- **A platform operator structurally has no `public.memberships` row.**
  Every permission a platform operator must be able to exercise
  (`school.suspend`, `school.close`, `support_access.*`) is declared
  `tenantRequired: false`; the SQL dispatcher's own role check is the real
  guard, not the membership-derived tenant cache. `school.suspend`/
  `school.close` shipped in S1 with the wrong default
  (`tenantRequired: true`) and were unreachable for a platform operator
  until this was found and fixed — see the ADR.
- **Support access requires AAL2 unconditionally**, not by role policy: the
  session must have actually presented a second factor this request, read
  from `RequestDbContext.aal2` (itself sourced from the verified token, never
  a client claim) and re-checked inside `private.api042_command`.
- **School closure/suspension and a data export require a fresh recent-auth
  grant** (`x-studafy-reauth`), consumed once, in addition to the role check
  — `school_admin_privileged` and `account_data_export` purposes on
  `public.auth_reauth_grants`. Closure/suspension deliberately does not also
  require a standing second factor (`requireAal2`): that check reads
  `Actor.mfaRequiredByPolicy`, which is derived only from the actor's own
  memberships, and the actor for these two commands is a platform operator
  who structurally has none.
- **Resource denials are concealed as 404** everywhere a resource-scoped
  permission is used (the `resource()` catalogue helper's default), so a
  stale or foreign id cannot become an existence oracle. `message.send`
  matches `message.list`'s 404-on-non-participant for the same reason.
- **Guardian-verified access requires an unexpired, `status = 'verified'`
  `guardian_links` row** — expired links are lazily re-evaluated rather than
  swept by a background job (no OPS-061 scheduler exists yet; documented as
  an explicit limitation, the same shape S8's `lazily_expire_support_access`
  documents for support-access grants).
- **Meeting recipient resolution is one set-based query**, not a per-student
  loop: enrolled students ∪ their verified non-expired guardians ∪ active
  classroom staff, deduplicated, with one bulk insert into
  `meeting_deliveries` and one bulk email-resolution call
  (`private.meeting_recipient_emails`, granted only to the worker runtime).
  This replaces the retired `create-google-meet` Edge Function's per-student-
  then-per-recipient loop.
- **Invitation acceptance is token-bound, not email-bound.** `profiles`
  deliberately carries no email to match against; the invitation's hashed
  token is the sole credential, matching an ordinary invitation-link model.
  The accepting identity must already be authenticated (any `auth.uid()`),
  which is what lets `acceptInvitation` create the membership atomically
  with no local-only "pending signup" state.
- **`createStudent`'s locator (`studafyId`) is always server-generated**
  (`STU-<10 hex chars>`), never client-selected — closing the same class of
  bug the legacy `lib/student_linking.dart` had with hard-coded literals
  (`'ST-4Q2R-58D'`, `'ST-2H9X-46B'`), which S3's real `locateStudent` route
  replaced.

## Roster prerequisite closed by this part

`createClassroom` (API-041) requires an existing term with status `active`
or `planned`; `enrollStudent` (API-042 S1) requires an existing `students`
row. Until `createTerm`/`createStudent` (S9), nothing in the catalogue could
create either — a freshly provisioned school could never reach a working
classroom or roster entry through the real API, only through test fixtures
that seeded both directly. `supabase/tests/api042_roster.sql` proves the
closed gap: a school with zero terms gets one via `createTerm`, and
`createClassroom` — previously `invalid_state` for that school — then
succeeds.

## Retired Edge Functions

| Function | Replacement | Disabled via |
|---|---|---|
| `create-google-meet` | `POST /v1/classrooms/{classroomId}/meetings` | SEC-001 `disabledFeatureResponse`, code `MEETINGS_DISABLED` |
| `cancel-google-meet` | `POST /v1/meetings/{meetingId}/cancel` | SEC-001 `disabledFeatureResponse`, code `MEETINGS_DISABLED` |
| `request-account-deletion` | `POST /v1/account/deletion-request` (AUTH-030, already shipped) | SEC-001 `disabledFeatureResponse`, code `ACCOUNT_DELETION_PROTOTYPE_DISABLED` |

All three are feature-flag hard returns, not deletions — the audit trail of
the decision stays in the repository (`docs/security/sec-001-containment.md`).
`request-account-deletion` also carried the JWT-`iat`-as-recent-auth defect
this whole phase's Hono routes replace with a real single-use grant; its
retirement was independent of the rest of this slice and could land first.

## Explicitly out of scope

- **SAFE-043** (report/block/moderation): communications ships
  conversations/messages/announcements only. Per the Phase 4 gate,
  communications is not launch-authorized without SAFE-043.
- **OPS-061** (a real queue): meeting/notification/export side effects are
  outbox rows (`public.notification_outbox`, `public.data_export_requests`),
  not a dispatched job. No production relay exists yet.
- **Flutter/mobile wiring**: this phase is backend-only (no Dart/Flutter SDK
  was available in this environment). Every new area has a real typed `/v1`
  surface to wire a client against; no existing screen was rewired.
