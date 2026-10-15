# Zero-difference proofs for list and access rewrites

A rewrite of an access check or a list query ships only after it gives the same
answers as the code it replaces (ADR-0030; capacity fixes of 2026-09-29 and
2026-10-14). These scripts are how that is checked. Local throwaway databases
only: they plant and change data, always inside a transaction that is rolled
back.

| Script                    | What it proves                                                                                                                                                                                                                                                                                                                                                                                                                                                   |
| ------------------------- | ---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| `differential.sql`        | Every academic list (`private.api041_query`: classes, lessons held, lessons, homework, exams, grades, attendance), for every sampled person, in every school they belong to and on the tenant-less guardian path, unfiltered and filtered by class and by student, page by page: the same JSON before and after a migration                                                                                                                                      |
| `access-differential.sql` | The per-call access sets in `api041_query_before_notebook` against `is_class_staff`, `can_view_classroom` and `can_view_class_student`, for every class and enrolment a sampled person could ask about, after planting edge cases (withdrawn, ended and future enrolments, expired and pending links, lapsed and suspended memberships, archived classes, closed terms, ended and future staff assignments, suspended profiles, deleted students, school admins) |
| `plant-homework.sql`      | Homework extras the synthetic seed lacks (links, files, extensions, closing times, homework marked through an assessment), planted before a homework proof and analysed so the planner sees them                                                                                                                                                                                                                                                                 |

Each proof runs in **one transaction**: record, apply the migration, record
again, compare, roll back. `now()` is fixed inside a transaction, so fields that
depend on the time (whether work is still open) compare fairly.

```sh
# The scale database (scripts/scale/prepare-scale-db.sh) or a database
# loaded with the pgTAP fixtures (the CI order in .github/workflows/ci.yml).
DB=postgresql://postgres:postgres@127.0.0.1:55822/studafy_scale

# One migration, on a 1-in-1000 sample of people (sample=1 for everyone):
psql "$DB" -X -v migration=supabase/migrations/<file>.sql -v sample=1000 \
  -f scripts/scale/proof/differential.sql

# A migration that builds on earlier unshipped ones, with planted homework:
psql "$DB" -X -v pre1=<first>.sql -v pre2=<second>.sql \
  -v plant=scripts/scale/proof/plant-homework.sql \
  -v migration=<third>.sql -v sample=1000 -f scripts/scale/proof/differential.sql

# The access rules themselves, with edge cases planted:
psql "$DB" -X -v sample=100 -f scripts/scale/proof/access-differential.sql
```

Ship only with `differences = 0` and `error_cases = 0`. The homework proof also
prints what the compared rows contained; a zero is meaningful only if those
counts are not.
