# Baseline query plans — synthetic local stack

ARC-001 deliverable ("record baseline latency/errors/query plans and current
absence/gaps"). Evidence date: 2026-09-10. Raw plans:
`query-plans-raw-2026-09-10.txt`.

## Method

Disposable local Supabase stack, migrations replayed from zero, synthetic
two-school fixture from `supabase/tests/rls_access_seed.sql` (5 identities, 1
classroom, 1 student, 2 grades, 1 attendance/wellbeing/audit row). Plans
captured as `authenticated` with the guardian's JWT claim so every RLS policy
and `SECURITY DEFINER` helper executes. Fixture scale is tiny by design —
these plans record **shapes and scan strategies**, not production latency.

## Results

| Query (hot path) | Plan | Time | Observation |
|---|---|---|---|
| `grade_results` by student + published (guardian) | Bitmap Index Scan on the `(assessment_id, student_id)` **unique constraint** + per-row `can_access_student` filter | 4.1 ms | No dedicated `(student_id, state)` index; unique constraint doubles as the only index |
| `attendance_records` by student | Bitmap Index Scan on `(session_id, student_id)` unique constraint + `can_access_student` per row | 0.4 ms | Same pattern |
| `students` by id | Index Scan on PK + `can_access_student` | 0.2 ms | OK for exact lookups |
| `guardian_links` by guardian | Bitmap Index Scan on `(student_id, guardian_id)` unique constraint | 0.02 ms | OR-branch short-circuits for own links |
| `enrollments` by classroom (roster) | Bitmap Index Scan on PK + `can_access_classroom` | 0.8 ms | PK happens to lead with `classroom_id` |
| `notifications` unread by user (client polling path) | **Seq Scan** | 0.03 ms | No index on `(user_id, read_at)`; the client polls this on screens (see data-flow F4) |

## Gaps registered (input to DB-020)

1. `notifications` unread polling performs a sequential scan; needs a partial
   index (`where read_at is null`) or API-side count endpoint.
2. Every relationship check (`can_access_student`, `can_access_classroom`,
   `is_school_member`) runs nested `EXISTS` subqueries against
   `students`/`guardian_links`/`enrollments`/`memberships` with **no
   supporting indexes** beyond unique constraints; per-row invocation cost
   grows with table size at school scale.
3. Composite tenant indexes from the target schema (`(school_id, status, …)`
   prefixes) do not exist yet; they are Phase 2 work with query-plan tests at
   synthetic scale as the gate.
4. No production metrics/tracing/alerting pipeline exists to observe these
   paths in a live environment (OPS-090 gap; decision-log SLO section).

## Caveat

Plan costs at fixture scale are trivial; DB-020 acceptance requires re-running
this suite against the Phase 2 synthetic-scale generator and approved
scan/latency budgets.
