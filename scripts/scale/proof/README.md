# Zero-difference proofs for list and access rewrites

A rewrite of an access check or a list query ships only after it gives the same
answers as the code it replaces (ADR-0030; capacity fixes of 2026-09-29 and
2026-10-14). These scripts are how that is checked. Local throwaway databases
only: they plant and change data, always inside a transaction that is rolled
back.

| Script                           | What it proves                                                                                                                                                                                                                                                                                                                                                                                                                                                   |
| -------------------------------- | ---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| `differential.sql`               | Every academic list (`private.api041_query`: classes, lessons held, lessons, homework, exams, grades, attendance), for every sampled person, in every school they belong to and on the tenant-less guardian path, unfiltered and filtered by class and by student, page by page: the same JSON before and after a migration                                                                                                                                      |
| `access-differential.sql`        | The per-call access sets in `api041_query_before_notebook` against `is_class_staff`, `can_view_classroom` and `can_view_class_student`, for every class and enrolment a sampled person could ask about, after planting edge cases (withdrawn, ended and future enrolments, expired and pending links, lapsed and suspended memberships, archived classes, closed terms, ended and future staff assignments, suspended profiles, deleted students, school admins) |
| `plant-homework.sql`             | Homework extras the synthetic seed lacks (links, files, extensions, closing times, homework marked through an assessment), planted before a homework proof and analysed so the planner sees them                                                                                                                                                                                                                                                                 |
| `plant-lessons.sql`              | Lesson extras the seed lacks (a newer current version with its own file, a version that is not current, bound, deleted and detached files, links, newer and older publications, drafts, deleted lessons, a missing current version, unpublished lessons), planted before the lessons proof (fix 4)                                                                                                                                                               |
| `conversations-differential.sql` | The conversations list (`private.api042_query('listConversations')`) for every sampled person, with pages of 20, 2 and 1 and a malformed position, page by page: the same JSON before and after a migration (fix 5)                                                                                                                                                                                                                                              |
| `plant-conversations.sql`        | Conversation extras the seed lacks (guardians and other schools' staff as participants, lapsed, suspended, ended and future teacher memberships, deleted student records, people who left, read markers, shared names, direct conversations and equal activity times for the keyset), planted before the conversations proof                                                                                                                                     |

| `plant-grades.sql` | Grade extras the seed lacks (a grade's own files and
links, its assessment's shared results files and links with material ones that
must not show, deleted files, detached bindings and links, ties in order, grades
in every state, absent / not-graded / zero marks, feedback, a category weight, a
class teacher whose membership is not a teacher's), planted before the grades
proof (fix 6) | | `grade-rows-differential.sql` | The grades page builder
against the single-grade builder: every grade, in any state, of every class a
sampled person teaches, is enrolled in or has a child in, built by
`api041_grade_json` one at a time and by `api041_grade_rows` a class at a time
and one at a time, as that person (fix 6) |

| Script                          | What it proves                                                                                                                                                                                                                                                                                                                                                                                                     |
| ------------------------------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------ |
| `study-lesson-differential.sql` | `private.study_lesson` (the lesson the AI study tools and notebooks read) for every sampled person and every lesson published to a class they are related to, a share of their schools' lessons, lessons of other schools, and signed-out and unknown callers: the same answer before and after a migration (2026-10-17)                                                                                           |
| `plant-study-lesson.sql`        | Access cases the seed lacks, on top of `plant-lessons.sql`: version files being scanned, rejected, deleted and clean; one-audience, withdrawn, tied, draft and class-less publications; parent and guardian memberships (and none, or one in another school); school admins who teach or are parents elsewhere; lapsed enrolments, links, memberships, classes, terms, profiles, students and schools (2026-10-17) |

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

# The lessons list (fix 4), with lessons planted (lesson_every=1 on the
# pgTAP fixtures, so every lesson gets an extra):
psql "$DB" -X -v plant=scripts/scale/proof/plant-lessons.sql \
  -v migration=supabase/migrations/202610150001_capacity_lessons_rows_per_page.sql \
  -v sample=1000 -f scripts/scale/proof/differential.sql

# The conversations list (fix 5), with conversations planted:
psql "$DB" -X -v plant=scripts/scale/proof/plant-conversations.sql \
  -v migration=supabase/migrations/202610150002_capacity_conversations_rows_per_page.sql \
  -v sample=100 -f scripts/scale/proof/conversations-differential.sql

# The grades list (fix 6), with grades planted (on the pgTAP fixtures add
# -v seed_grades=1 -v grade_every=1 -v assessment_every=1, and restore the
# original list functions first with -v pre1=<their old definitions>):
psql "$DB" -X -v plant=scripts/scale/proof/plant-grades.sql \
  -v migration=supabase/migrations/202610150040_capacity_grades_rows_per_page.sql \
  -v sample=1000 -f scripts/scale/proof/differential.sql
psql "$DB" -X -v plant=scripts/scale/proof/plant-grades.sql \
  -v migration=supabase/migrations/202610150040_capacity_grades_rows_per_page.sql \
  -v sample=100 -f scripts/scale/proof/grade-rows-differential.sql

# study_lesson (2026-10-17), with access cases planted (on the pgTAP
# fixtures add -v seed_lessons=1 -v lesson_every=1 -v access_every=1
# -v resource_every=1, and restore the original first with -v pre1=):
psql "$DB" -X -v plant=scripts/scale/proof/plant-study-lesson.sql \
  -v migration=supabase/migrations/202610160010_capacity_study_lesson_access.sql \
  -v sample=500 -f scripts/scale/proof/study-lesson-differential.sql

# The access rules themselves, with edge cases planted:
psql "$DB" -X -v sample=100 -f scripts/scale/proof/access-differential.sql
```

Ship only with `differences = 0` and `error_cases = 0`. The homework, lessons,
conversations and grades proofs also print what the compared rows contained; a
zero is meaningful only if those counts are not.
