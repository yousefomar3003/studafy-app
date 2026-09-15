# `/v1` authoritative academic contract (API-041)

Status: implemented and verified for local/disposable synthetic use on
2026-09-15. This document does not authorize a production deployment or real
student data. OpenAPI remains the machine-readable source of truth at
`packages/contracts/openapi/v1.json`.

## Route inventory

All 40 routes authenticate a verified JWT and declare exactly one AUTH-031
permission. Every POST requires `Idempotency-Key`; create and submit operations
return 201, while transition commands return the canonical updated resource.

| Slice          | Reads                                                                                   | Commands                                                                             |
| -------------- | --------------------------------------------------------------------------------------- | ------------------------------------------------------------------------------------ |
| School context | `GET /v1/schools/{schoolId}`, `/terms`                                                  | —                                                                                    |
| Classes        | `GET /v1/classrooms`, `/{classroomId}`, `/staff`, `/students`                           | `POST /v1/classrooms`, `/{classroomId}/update`, `/schedule/replace`                  |
| Content        | `GET /v1/resources`, `/v1/lesson-sessions`                                              | `POST /v1/resources`, `/{resourceId}/revise`, `/publish`, `/withdraw`                |
| Assignments    | `GET /v1/assignments`, `/{assignmentId}`, `/{assignmentId}/submissions`                 | `POST /v1/assignments`, `/{assignmentId}/publish`, `/withdraw`, `/submit`            |
| Assessments    | `GET /v1/assessments`, `/{assessmentId}/questions`, `/authoring-questions`, `/attempts` | `POST /v1/assessments`, `/{assessmentId}/publish`, `/withdraw`, `/submit`            |
| Grades         | `GET /v1/grade-results`                                                                 | `POST /v1/grade-results/{gradeResultId}/review`, `/publish`, `/correct`, `/withdraw` |
| Attendance     | `GET /v1/attendance`, `/v1/classrooms/{classroomId}/attendance-roster`                  | `POST /v1/attendance/record`                                                         |
| Wellbeing      | `GET /v1/wellbeing`                                                                     | `POST /v1/wellbeing`                                                                 |

## Authorization and response safety

- The school is resolved from the stored resource and the actor's fresh active
  membership. A path, query, body, header, or JWT role claim cannot grant a
  tenant or role.
- Classroom creation is active-admin only. Academic writes require an active
  lead/co-teacher assignment (or active school admin). Assistants are read-only.
  Students submit only their own currently enrolled work. Guardians are
  read-only for verified linked students.
- Cross-school and denied object substitutions are concealed as 404.
- Learner assessment questions use a strict schema that cannot contain
  `preferredAnswer`. Preferred answers exist only on the separately authorized
  `/authoring-questions` staff route. Responses never include storage keys,
  audit bodies, internal membership roles, or answer text in outbox payloads.
- Wellbeing results are filtered by `class_staff`, `guardian_shared`, and
  `student_guardian_shared` rules. Safeguarding-restricted records are not part
  of this general academic contract.

## Pagination and concurrency

Every collection returns `{items, nextCursor}`. The default page size is 50 and
the maximum is 100. The opaque HMAC-SHA-256 cursor binds cursor version, filter
version, operation, server-visible school, exact filter hash, and the UUID sort
position. Invalid, tampered, cross-school, cross-operation, or filter-mismatched
cursors return `CURSOR_INVALID`.

Mutable classroom, content/publication, assignment, assessment, grade, lesson
session, and attendance aggregates carry optimistic versions. Commands accept
`expectedVersion`; stale requests return `VERSION_CONFLICT`. Invalid lifecycle
transitions return `INVALID_STATE`, and assignment submissions after the
server-enforced close time return `WINDOW_CLOSED`.

## Transactions, idempotency, and side effects

The API role has zero public table, column, and sequence grants. A request can
execute only the narrow `private.api041_query` and `private.api041_command`
surfaces (plus prerequisite AUTH/API-040 functions). Each command transaction
sets the verified actor, server-derived school, and request ID with transaction-
local settings, then performs the mutation, optimistic check, immutable history
or audit insert, required outbox insert, and idempotency completion atomically.

An exact completed retry returns the stored status/body with
`Idempotency-Replayed: true`. Reusing a key with different canonical input
returns `IDEMPOTENCY_KEY_REUSED`. Concurrent identical keys yield one domain
transition, audit event, and outbox event. Forced audit or outbox failures roll
back the domain change and idempotency completion.

Notification-worthy events insert minimal identifiers/template data into
`notification_outbox`. Request handlers never create notifications and never
call notification or other external providers.

## State transitions

| Aggregate  | Allowed command path                                                                                                   |
| ---------- | ---------------------------------------------------------------------------------------------------------------------- |
| Resource   | `draft → published → withdrawn`; revise creates an immutable version and returns to `draft`                            |
| Assignment | `draft → published → withdrawn`; each student resubmission creates an immutable attempt before close                   |
| Assessment | `draft → published → withdrawn`; online answers create immutable structured attempts                                   |
| Grade      | `draft → reviewed → published`; `published → published` correction requires a reason; `reviewed/published → withdrawn` |
| Attendance | scheduled occurrence version `0 → 1`, then optimistic set-based replacements                                           |

Reviewed/published grades require a bounded score and reviewer. Paper-grade
review additionally requires a linked ready draft, complete question coverage,
per-question bounds, score agreement, and a reason for every AI-score override.

## Rollout and deferred files

`API041_CLASSES_ENABLED`, `API041_CONTENT_ENABLED`,
`API041_ASSIGNMENTS_ENABLED`, `API041_ASSESSMENTS_ENABLED`,
`API041_GRADES_ENABLED`, `API041_ATTENDANCE_ENABLED`, and
`API041_WELLBEING_ENABLED` fail closed per slice. A disabled slice returns 503
and the client displays unavailable/read- only state; it never falls back to a
local production write.

Only text content and text assignment/assessment submissions are accepted. File
pickers, attachment publication, paper scan upload, and AI proposal remain
disabled until FILE-050/051 and AI-072. Invitations, staffing/enrollment
transitions, communications, meetings, and notification management remain
API-042/SAFE-043 scope.
