# SEC-001 synthetic privilege-lockdown evidence

Date: 2026-09-10. Authorized target: synthetic project
`eamewgaptdfqzpmayavx` only. No staging or production project was accessed.

## Forward migration

- Local clean replay applied migrations `202609080001` through
  `202609090004` in order.
- `db lint --local --level error --fail-on error`: no schema errors.
- `supabase/tests/containment.sql`: 11/11 assertions passed.
- `supabase/tests/rls_access_seed.sql`: 8/8 assertions passed.
- The linked-project dry run listed exactly
  `202609090004_lock_down_function_execute.sql`.
- The migration was applied successfully to the synthetic project.
- The remote migration list subsequently showed all eight local/remote
  versions aligned through `202609090004`.

Recovery is forward-only: if an authenticated policy helper were accidentally
revoked, a reviewed new migration would restore EXECUTE only to the minimum
required role. The anonymous grants, trigger-helper grants, and unsafe default
grants must not be restored.

## Remote schema-only verification

A fresh schema-only remote dump contained no `GRANT ... TO anon` for:

- `is_school_member`
- `is_class_teacher`
- `can_access_student`
- `can_access_classroom`
- `handle_new_auth_user`
- `rls_auto_enable`

It also contained no postgres-role default FUNCTION grant to `anon`.
Authenticated execution remains available for the four RLS policy helpers;
direct execution of the auth trigger helper is denied.

## Remote anonymous negative probes

Read-only PostgREST RPC probes produced:

| Function | Status | Result |
|---|---:|---|
| `is_school_member` | 401 | denied |
| `is_class_teacher` | 401 | denied |
| `can_access_student` | 401 | denied |
| `can_access_classroom` | 401 | denied |
| `handle_new_auth_user` | 404 | not exposed |
| `rls_auto_enable` | 401 | denied |

No request body, token, key, or database contents are recorded here.
