# Capacity: how many users Studafy can serve

Measured on 2026-09-29 with the scale harness in `scripts/scale`, which
anyone can rerun (below). Numbers are for the database side, which is where
this system saturates first; the API scales out by adding instances.

## The short answer

On a database with 10 vCPUs, loaded with **100 schools, 50,000 students,
50,000 parents and 4,000 teachers (10.6 million rows)**:

| | Before the fixes | After |
| --- | --- | --- |
| Requests per second, sustained | 2–10 | **~500** |
| Response time at 10 simultaneous active users (median / 95%) | 6.2 s / 26 s | 31 ms / 112 ms |
| At 200 simultaneous active users | unusable (minutes) | 438 ms / 626 ms |
| Errors | 0 | 0 |

In people: a person using the app makes about one API request every
10 seconds (opening screens, each screen one to three requests). So **one
request per second ≈ 10 people using the app at the same moment**:

- **Comfortable** (95% of requests under 400 ms): about **4,400 people at
  the same moment** on 10 vCPUs.
- In schools, the busiest moment has roughly 10–20% of the day's users
  active at once, which is **about 25,000–40,000 daily active users** per
  database of this size. Registered users can be several times that.
- Before the fixes, the same database served about **20 people at once**
  before pages took longer than a few seconds.

### By database size (estimates)

The load is CPU-bound: about 50 requests per second per vCPU here. Scale by
cores, then confirm by running the harness against a staging project of
that size before relying on it.

| Database vCPUs | Requests/s | People at once | Daily active users (est.) |
| --- | --- | --- | --- |
| 2 | ~100 | ~1,000 | ~5,000–10,000 |
| 4 | ~200 | ~2,000 | ~10,000–20,000 |
| 8 | ~400 | ~4,000 | ~20,000–40,000 |

Other limits to keep in mind as you grow:

- **Connections.** Each API process holds `DATABASE_POOL_MAX` connections
  (default 20; it was a fixed 5, which alone capped one instance near 275
  requests per second). Keep (API instances x pool) + worker pool under the
  plan's connection limit, and connect through Supabase's session pooler.
- **API instances.** Each Bun process handles a few hundred requests per
  second. Run at least two for availability, and add more before the
  database is the limit.
- **Per-user rate limit.** About one request per second sustained, with
  bursts to 150, per account. Fine for people; it stops runaway clients.

## What was wrong, and what changed

The code and schema were well normalised (keys, foreign keys, tenant
separation), but several query shapes cost more as schools grew rather than
as a person's own data grew. That is what makes a system "collapse": each
user's request gets slower as the whole system gets bigger.

1. **Access checks walked every student in a class.** To answer "may this
   person see class X", the functions looped over every enrollment in X and
   asked, for each student, "is this the caller?". Each question found the
   caller's student record by `user_id`, which had **no index**, so it read
   the whole `students` table every time. The checks now start from the
   caller's own student records and links (usually one) and ask the same
   function about those. Migration `202609290007`.
2. **Lists checked every row in the school.** A student's grades list
   scanned all 7,500 grades in the school and ran an access function on
   each until it had a page (17 s). The lists now test, cheaply, whether a
   row can belong to the caller (a class they teach, or one of their own
   student records or children) before the same access check. The access
   functions run once per class instead of once per row.
3. **A parent's view scanned the whole database.** Listing a child's
   assignments had no school filter and checked every assignment in every
   school (14.7 s). It now looks only at the child's classes.
4. **Missing indexes on hot paths.** `students(user_id)`; notifications by
   recipient (every unread badge scanned all deliveries); the worker's
   fan-out; a lesson's latest publication (every lesson in a list scanned
   all publications).
5. **The connection pool** was fixed at 5 per API process. It is now
   `DATABASE_POOL_MAX`, default 20.
6. **Tables that grew for ever.** Expired idempotency records (one per
   write) were never removed; the worker now prunes them
   (`202609290008`, `DB_HOUSEKEEPING_ENABLED`, on by default).
7. **A per-school rate limit that would lock a school out.** 2,000 requests
   per 5 minutes for a whole school is about 3 list screens a second; a
   500-student school opening the app in the morning would spend it in
   minutes. It happens not to be enforced yet (the limiter runs before the
   school is known), but it is documented as active, so it is now 60,000
   per 5 minutes: a runaway backstop, not a budget.

**Correctness.** None of this changes who may see what. Every rewritten
access function and list was compared against the original on the full
dataset: 45,200 access decisions and 26 role-and-list combinations (admin,
teacher, student, parent; 4,925 rows), with **zero differences**. The 38
existing database test suites give identical results before and after.

## Rerunning it

```sh
# 1. A scratch database with today's schema and 100 synthetic schools
#    (local only; about 6 minutes, 3 GB):
SOURCE_DATABASE_URL=postgresql://supabase_admin:postgres@127.0.0.1:54322/postgres \
ADMIN_URL=postgresql://supabase_admin:postgres@127.0.0.1:54322/postgres \
bun run scale:prepare            # sizes: -v schools=200 -v students=800 ...

# 2. The load test (students 70%, parents 20%, teachers 10%):
SCALE_DATABASE_URL=postgresql://postgres:postgres@127.0.0.1:54322/studafy_scale \
bun run scale:bench -- --pool 20 --users 10,50,100,200 --seconds 20

# 3. Where the time went (statements inside the app's functions too):
psql postgresql://supabase_admin:postgres@127.0.0.1:54322/studafy_scale \
  -f scripts/scale/top-statements.sql

# Drop it when done:
psql postgresql://supabase_admin:postgres@127.0.0.1:54322/postgres \
  -c 'drop database studafy_scale with (force)'
```

`--max-p95 <ms>` makes the benchmark fail when any screen's 95th percentile
exceeds the limit or any request errors. Use it as a regression guard before
releases.

## What to do next, in order

1. **Before launch:** run the harness against a staging Supabase project of
   the size you will buy, to replace the estimates above with measurements.
2. **Grades and assignments lists** still scan a school's rows (cheaply:
   about 100–180 ms at 500 students per school). They grow with school
   size, so a 2,000-student school will be about four times slower. Driving
   them from the caller's classes first (keyset pagination per class) is
   the next improvement.
3. **Retention for audit events and old notifications** needs the data
   retention decision (ADR-0008) before rows can be removed; until then
   these tables grow with use.
4. Watch `pg_stat_statements` in production. A statement whose mean time
   grows over the weeks is the early warning of the next problem.
