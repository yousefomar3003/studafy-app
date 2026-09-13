# DB-021 grants and function inventory

## Client roles

- `anon`: schema discovery only; zero application table, column, sequence, or
  public RPC privileges.
- `authenticated`: column-level `SELECT` on the 29 policy-protected relations
  listed by the policy matrix. No table-wide grants and no direct DML.
- Authenticated public RPCs: `record_policy_consent(text,text,text)` and
  `mark_notifications_read()` only.
- `studafy_api_runtime` and `studafy_worker_runtime`: `NOLOGIN`, `NOINHERIT`,
  `NOBYPASSRLS`, with no schema or object grants until their feature phases.

Excluded columns include `lesson_materials.storage_path`,
`assessment_questions.preferred_answer`, AI private paths, file object keys and
hashes, audit values, provider identifiers/errors, and queue payloads.

## Service role

| Privilege | Relations |
|---|---|
| Select | account deletion requests, AI drafts, assessment questions, enrollments, grades, guardian links, meetings, suggestions, students, legacy entitlements |
| Insert | account deletion requests, audit events, meeting deliveries, meetings, notifications, practice sessions, legacy entitlements |
| Update | account deletion requests, AI drafts, grades, meeting deliveries, meetings, suggestions, legacy entitlements |
| Sequence usage | `audit_events_id_seq` |

No service-role delete, truncate, reference, trigger, sequence-select, or
unactivated DB-020 table privilege is granted. The role continues to bypass RLS
by Supabase platform design, which makes this object allowlist mandatory.

## Functions and defaults

Policy and trigger helpers live in `private`; only policy-facing boolean helpers
are executable by `authenticated`, and that schema is not exposed by PostgREST.
Trigger helpers cannot be invoked by client roles. Every application
`SECURITY DEFINER` function has an empty search path and qualified references.

Application migrations run as `postgres`; its future public/private tables,
sequences, and functions are closed by default. Supabase platform objects may
be owned by `supabase_admin`, whose default ACLs are provider-managed and cannot
be altered by the application migration role. The grant snapshot test verifies
all current application objects after every clean replay.
