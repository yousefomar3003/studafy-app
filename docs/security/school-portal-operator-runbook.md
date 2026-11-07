# School Portal: operator runbook

What Studafy's operator does when a teacher reports a school
(docs/planning/school-portal.md, 9.5). Anyone can create a school's page and
Studafy does not check schools, so suspension is the safeguard: a suspended
school sees nothing at once, its group codes join nobody, and its
announcements stop reaching anyone.

Both actions need an account in `public.platform_operators` (the same
operators as the safety-report review). The database checks it on every
call; for anyone else the API answers 403.

## When a report arrives

The operators' Telegram chat gets the report's id, the school's id and the
reason, never the teacher's words. Read the report in the database
(`private.school_portal_reports`) and decide.

## Suspend or restore a school

```
POST /v1/school-portal/orgs/{orgId}/suspend
Idempotency-Key: <new uuid>
{"suspend": true, "reason": "Reported by a teacher: pressure to link"}
```

`{"suspend": false}` restores it. The reason is kept with the school and in
the audit record. A closed school cannot be restored.

## Remove an announcement

```
POST /v1/school-portal/announcements/{announcementId}/remove
Idempotency-Key: <new uuid>
{}
```

It disappears for every student, parent and teacher at once. The school
still sees it in its own list, marked removed.

## Calling the API

Sign in to the portal website as the operator account and use its session's
access token as `Authorization: Bearer <token>`, against `api.studafy.com`.
Never paste the token into a chat or a ticket.
