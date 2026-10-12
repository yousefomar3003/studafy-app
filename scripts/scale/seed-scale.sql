-- Synthetic school-system data at scale, for capacity testing
-- (docs/operations/capacity.md). Loads a scratch database made by
-- scripts/scale/prepare-scale-db.sh - never a real one.
--
-- Sizes are psql variables (defaults: 100 schools x 500 students):
--   psql -v schools=100 -v students=500 -f seed-scale.sql
--
-- Every id is md5(kind:school:n) as a uuid, so the benchmark can name any
-- student, teacher, parent or class without reading them back.
--
-- Triggers are off for the load (session_replication_role = replica): the
-- audit, notification and link-mirroring triggers would multiply the rows
-- and the time, and every row here is already consistent by construction.

\set ON_ERROR_STOP on
\if :{?schools} \else \set schools 100 \endif
\if :{?students} \else \set students 500 \endif
\if :{?teachers} \else \set teachers 40 \endif
\if :{?classes} \else \set classes 60 \endif
\if :{?enrol} \else \set enrol 3 \endif
\if :{?assignments} \else \set assignments 15 \endif
\if :{?assessments} \else \set assessments 5 \endif
\if :{?resources} \else \set resources 20 \endif
\if :{?sessions} \else \set sessions 20 \endif
\if :{?messages} \else \set messages 50 \endif
\if :{?notices} \else \set notices 20 \endif
\if :{?notes} \else \set notes 5 \endif
\if :{?exams} \else \set exams 2 \endif

select current_database() like '%scale%' as scratch \gset
\if :scratch
\else
  \echo 'Refusing: the database name must contain "scale".'
  \quit
\endif

set session_replication_role = replica;
set synchronous_commit = off;
set maintenance_work_mem = '512MB';

-- Shaped as a version 4 UUID (version and variant digits set), because the
-- API validates ids strictly; bench.ts and http-load.ts derive the same.
create or replace function pg_temp.sid(kind text, a bigint, b bigint default 0)
returns uuid language sql immutable as $$
  select (substr(h, 1, 12) || '4' || substr(h, 14, 3) || '8' || substr(h, 18, 15))::uuid
  from (select md5(kind || ':' || a || ':' || b) as h) x
$$;

\echo 'schools, terms'
insert into public.schools (id, name, status, timezone, locale)
select pg_temp.sid('school', s), 'School ' || s, 'active', 'Asia/Amman', 'en'
from generate_series(1, :schools) s;
insert into public.terms (id, school_id, name, starts_on, ends_on, active, status)
select pg_temp.sid('term', s), pg_temp.sid('school', s), '2026-27', '2026-09-01', '2027-06-30', true, 'active'
from generate_series(1, :schools) s;

\echo 'accounts'
create temporary table people as
  select 'su' as kind, s, n from generate_series(1, :schools) s, generate_series(1, :students) n
  union all select 'gu', s, n from generate_series(1, :schools) s, generate_series(1, :students) n
  union all select 'tu', s, n from generate_series(1, :schools) s, generate_series(1, :teachers) n;
insert into auth.users (id, email, encrypted_password, aud, role, email_confirmed_at, created_at,
  updated_at, instance_id, confirmation_token, recovery_token, email_change,
  email_change_token_new, email_change_token_current, phone_change_token,
  raw_app_meta_data, raw_user_meta_data)
select pg_temp.sid(kind, s, n), kind || '.' || s || '.' || n || '@scale.studafy.test',
  'synthetic-not-a-secret', 'authenticated', 'authenticated', now(), now(), now(),
  '00000000-0000-0000-0000-000000000000', '', '', '', '', '', '', '{}', '{}'
from people;
-- public_id is normally minted by a trigger, which is off for the load: a
-- unique ten-digit number per person instead (^[1-9][0-9]{9}$).
insert into public.profiles (id, display_name, locale, status, profile_completed_at, public_id)
select pg_temp.sid(kind, s, n), initcap(kind) || ' ' || s || '-' || n, 'en', 'active', now(),
  (1000000000 + row_number() over (order by kind, s, n))::text
from people;

\echo 'memberships'
insert into public.memberships (id, school_id, user_id, role, active, status)
select pg_temp.sid('tm', s, n), pg_temp.sid('school', s), pg_temp.sid('tu', s, n), 'teacher', true, 'active'
from generate_series(1, :schools) s, generate_series(1, :teachers) n;
insert into public.memberships (id, school_id, user_id, role, active, status)
select pg_temp.sid('sm', s, n), pg_temp.sid('school', s), pg_temp.sid('su', s, n), 'student', true, 'active'
from generate_series(1, :schools) s, generate_series(1, :students) n;
-- Most parents link by the child's ID and hold no membership at all.

\echo 'students, classes, staff, enrollments, guardians'
insert into public.students (id, school_id, user_id, studafy_id, display_name, provisional, created_by)
select pg_temp.sid('st', s, n), pg_temp.sid('school', s), pg_temp.sid('su', s, n),
  'STU-' || s || '-' || n, 'Student ' || s || '-' || n, false, pg_temp.sid('tu', s, 1)
from generate_series(1, :schools) s, generate_series(1, :students) n;
insert into public.classrooms (id, school_id, term_id, name, teacher_id, status)
select pg_temp.sid('cl', s, c), pg_temp.sid('school', s), pg_temp.sid('term', s),
  'Class ' || c, pg_temp.sid('tu', s, 1 + c % :teachers), 'active'
from generate_series(1, :schools) s, generate_series(0, :classes - 1) c;
insert into public.classroom_staff (school_id, classroom_id, membership_id, user_id, role)
select pg_temp.sid('school', s), pg_temp.sid('cl', s, c), pg_temp.sid('tm', s, 1 + c % :teachers),
  pg_temp.sid('tu', s, 1 + c % :teachers), 'lead_teacher'
from generate_series(1, :schools) s, generate_series(0, :classes - 1) c;
insert into public.enrollments (classroom_id, student_id, school_id, active, status)
select distinct pg_temp.sid('cl', s, (n * :enrol + e) % :classes), pg_temp.sid('st', s, n),
  pg_temp.sid('school', s), true, 'active'::public.enrollment_status
from generate_series(1, :schools) s, generate_series(1, :students) n, generate_series(0, :enrol - 1) e;
insert into public.guardian_links (student_id, guardian_id, school_id, status, relationship, verified_by, verified_at)
select pg_temp.sid('st', s, n), pg_temp.sid('gu', s, n), pg_temp.sid('school', s),
  'verified', 'parent', pg_temp.sid('gu', s, n), now()
from generate_series(1, :schools) s, generate_series(1, :students) n;

\echo 'lessons'
insert into public.resources (id, school_id, title, resource_type, state, current_version, created_by)
select pg_temp.sid('res', s, c * 1000 + r), pg_temp.sid('school', s), 'Lesson ' || r, 'lesson',
  'published', 1, pg_temp.sid('tu', s, 1 + c % :teachers)
from generate_series(1, :schools) s, generate_series(0, :classes - 1) c, generate_series(1, :resources) r;
insert into public.resource_versions (id, school_id, resource_id, version, body, created_by)
select pg_temp.sid('rv', s, c * 1000 + r), pg_temp.sid('school', s), pg_temp.sid('res', s, c * 1000 + r), 1,
  repeat('Lesson text about photosynthesis and cells. ', 20), pg_temp.sid('tu', s, 1 + c % :teachers)
from generate_series(1, :schools) s, generate_series(0, :classes - 1) c, generate_series(1, :resources) r;
insert into public.resource_publications (school_id, resource_version_id, classroom_id, audience, state,
  published_at, created_by)
select pg_temp.sid('school', s), pg_temp.sid('rv', s, c * 1000 + r), pg_temp.sid('cl', s, c), 'both',
  'published', now() - (r || ' days')::interval, pg_temp.sid('tu', s, 1 + c % :teachers)
from generate_series(1, :schools) s, generate_series(0, :classes - 1) c, generate_series(1, :resources) r;

\echo 'assignments and submissions'
insert into public.assignments (id, school_id, classroom_id, title, due_at, state, published_at, created_by)
select pg_temp.sid('as', s, c * 1000 + a), pg_temp.sid('school', s), pg_temp.sid('cl', s, c),
  'Homework ' || a, now() + ((a - 8) || ' days')::interval, 'published', now() - interval '20 days',
  pg_temp.sid('tu', s, 1 + c % :teachers)
from generate_series(1, :schools) s, generate_series(0, :classes - 1) c, generate_series(1, :assignments) a;
insert into public.submissions (assignment_id, student_id, school_id, status, submitted_at)
select pg_temp.sid('as', s, e.c * 1000 + a), pg_temp.sid('st', s, e.n), pg_temp.sid('school', s),
  'submitted', now() - interval '1 day'
from generate_series(1, :schools) s
cross join lateral (
  select distinct n, (n * :enrol + k) % :classes as c
  from generate_series(1, :students) n, generate_series(0, :enrol - 1) k
) e
cross join generate_series(1, :assignments) a;

\echo 'assessments and grades'
insert into public.assessments (id, school_id, classroom_id, title, category, maximum_score, state,
  published_at, created_by)
select pg_temp.sid('am', s, c * 1000 + a), pg_temp.sid('school', s), pg_temp.sid('cl', s, c),
  'Quiz ' || a, 'quiz', 100, 'published', now(), pg_temp.sid('tu', s, 1 + c % :teachers)
from generate_series(1, :schools) s, generate_series(0, :classes - 1) c, generate_series(1, :assessments) a;
insert into public.grade_results (assessment_id, student_id, school_id, score, state, reviewed_by,
  reviewed_at, published_at, published_by)
select pg_temp.sid('am', s, e.c * 1000 + a), pg_temp.sid('st', s, e.n), pg_temp.sid('school', s),
  60 + (e.n % 40), 'published', pg_temp.sid('tu', s, 1 + e.c % :teachers), now(), now(),
  pg_temp.sid('tu', s, 1 + e.c % :teachers)
from generate_series(1, :schools) s
cross join lateral (
  select distinct n, (n * :enrol + k) % :classes as c
  from generate_series(1, :students) n, generate_series(0, :enrol - 1) k
) e
cross join generate_series(1, :assessments) a;

\echo 'lesson sessions and attendance'
insert into public.lesson_sessions (id, school_id, classroom_id, starts_at, ends_at, status, filed_at)
select pg_temp.sid('ls', s, c * 1000 + d), pg_temp.sid('school', s), pg_temp.sid('cl', s, c),
  now() - (d || ' days')::interval, now() - (d || ' days')::interval + interval '45 minutes',
  'completed', now() - (d || ' days')::interval
from generate_series(1, :schools) s, generate_series(0, :classes - 1) c, generate_series(1, :sessions) d;
insert into public.attendance_records (session_id, student_id, school_id, state, recorded_by)
select pg_temp.sid('ls', s, e.c * 1000 + d), pg_temp.sid('st', s, e.n), pg_temp.sid('school', s),
  case when (e.n + d) % 17 = 0 then 'absent' else 'present' end::public.attendance_state,
  pg_temp.sid('tu', s, 1 + e.c % :teachers)
from generate_series(1, :schools) s
cross join lateral (
  select distinct n, (n * :enrol + k) % :classes as c
  from generate_series(1, :students) n, generate_series(0, :enrol - 1) k
) e
cross join generate_series(1, :sessions) d;

\echo 'class conversations and messages'
-- Messaging is off for a school until its admin turns it on.
insert into public.school_content_controls (school_id, messaging_enabled, support_contact, updated_by)
select pg_temp.sid('school', s), true, 'office@school' || s || '.test', pg_temp.sid('tu', s, 1)
from generate_series(1, :schools) s;
insert into public.conversations (id, school_id, subject, state, created_by)
select pg_temp.sid('cv', s, c), pg_temp.sid('school', s), 'Class ' || c, 'active', pg_temp.sid('tu', s, 1 + c % :teachers)
from generate_series(1, :schools) s, generate_series(0, :classes - 1) c;
insert into public.conversation_participants (school_id, conversation_id, user_id)
select pg_temp.sid('school', s), pg_temp.sid('cv', s, c), pg_temp.sid('tu', s, 1 + c % :teachers)
from generate_series(1, :schools) s, generate_series(0, :classes - 1) c
union
select pg_temp.sid('school', s), pg_temp.sid('cv', s, e.c), pg_temp.sid('su', s, e.n)
from generate_series(1, :schools) s
cross join lateral (
  select distinct n, (n * :enrol + k) % :classes as c
  from generate_series(1, :students) n, generate_series(0, :enrol - 1) k
) e;
insert into public.messages (school_id, conversation_id, sender_id, client_message_id, body, created_at)
select pg_temp.sid('school', s), pg_temp.sid('cv', s, c), pg_temp.sid('tu', s, 1 + c % :teachers),
  gen_random_uuid(), 'Message ' || m, now() - (m || ' hours')::interval
from generate_series(1, :schools) s, generate_series(0, :classes - 1) c, generate_series(1, :messages) m;

\echo 'notifications'
insert into public.notification_outbox (school_id, source_event_id, idempotency_key, channel,
  template_key, recipient_id, payload, state, created_at)
select pg_temp.sid('school', s), 'scale:' || s || ':' || n || ':' || k,
  'scale:' || s || ':' || n || ':' || k, 'in_app', 'academic.assignment_published',
  pg_temp.sid('su', s, n), '{}', 'completed', now() - (k || ' hours')::interval
from generate_series(1, :schools) s, generate_series(1, :students) n, generate_series(1, :notices) k;
insert into public.notification_deliveries (school_id, outbox_id, recipient_id, channel, attempt,
  state, delivered_at, read_at)
select o.school_id, o.id, o.recipient_id, 'in_app', 1, 'sent', o.created_at,
  case when o.id % 3 = 0 then null else o.created_at end
from public.notification_outbox o where o.source_event_id like 'scale:%';

\echo 'notebooks'
insert into public.notebook_entries (school_id, classroom_id, student_id, owner_id, title, body, source)
select pg_temp.sid('school', s), pg_temp.sid('cl', s, (n * :enrol) % :classes), pg_temp.sid('st', s, n),
  pg_temp.sid('su', s, n), 'Note ' || k, repeat('Notes. ', 40), 'typed'
from generate_series(1, :schools) s, generate_series(1, :students) n, generate_series(1, :notes) k;

\echo 'online exams (launch plan 4.8)'
-- Taken in the app, so a student can open, answer and hand one in. Up to 20
-- attempts each, so a benchmark can submit the same exam repeatedly.
insert into public.assessments (id, school_id, classroom_id, title, category, maximum_score, state,
  published_at, created_by, delivery, max_attempts, answer_release)
select pg_temp.sid('ex', s, c * 1000 + e), pg_temp.sid('school', s), pg_temp.sid('cl', s, c),
  'Online exam ' || e, 'exam', 10, 'published', now(), pg_temp.sid('tu', s, 1 + c % :teachers),
  'online', 20, 'after_close'
from generate_series(1, :schools) s, generate_series(0, :classes - 1) c, generate_series(1, :exams) e;
-- Five questions: three choice, one short answer, one essay (which needs marking).
insert into public.assessment_questions (id, school_id, assessment_id, position, prompt, maximum_score,
  kind, options, answer_key, required)
select pg_temp.sid('eq', s, (c * 1000 + e) * 10 + q), pg_temp.sid('school', s),
  pg_temp.sid('ex', s, c * 1000 + e), q, 'Question ' || q, 2,
  case when q <= 3 then 'single_choice' when q = 4 then 'short_answer' else 'essay' end,
  case when q <= 3 then '[{"id":"a","text":"Cells"},{"id":"b","text":"Atoms"},{"id":"c","text":"Rocks"}]'::jsonb
    else '[]'::jsonb end,
  case when q <= 3 then '["a"]'::jsonb when q = 4 then '["chlorophyll"]'::jsonb else null end,
  true
from generate_series(1, :schools) s, generate_series(0, :classes - 1) c, generate_series(1, :exams) e,
  generate_series(1, 5) q;

\echo 'study notebooks and paid plans (launch plan 4.8)'
-- A notebook as the API returns it (V1NotebookContent): two sections.
create or replace function pg_temp.notebook_content() returns jsonb language sql immutable as $$
  select jsonb_build_object(
    'overview', 'How living things are built from cells and make energy from light.',
    'objectives', jsonb_build_array('Describe a cell', 'Explain photosynthesis'),
    'keyTerms', jsonb_build_array(jsonb_build_object('term', 'Cell',
      'definition', 'The basic unit of life.', 'cite', null)),
    'sections', (select jsonb_agg(jsonb_build_object('key', k, 'heading', h,
        'paragraphs', jsonb_build_array(repeat('Notes about ' || h || '. ', 40)),
        'points', jsonb_build_array('Point one', 'Point two'),
        'cites', '[]'::jsonb, 'extra', false))
      from (values ('cells', 'Cells'), ('light', 'Photosynthesis')) v(k, h)),
    'examples', '[]'::jsonb, 'facts', '[]'::jsonb, 'mistakes', '[]'::jsonb,
    'summary', jsonb_build_array('Cells make up living things.', 'Plants use light to make food.'));
$$;
-- One ready notebook per student, from the first lesson of their first class.
insert into public.study_notebooks (id, school_id, owner_id, classroom_id, resource_id, title, status,
  content, content_version, generated_at, model, whole_lesson, include_text)
select pg_temp.sid('nb', s, n), pg_temp.sid('school', s), pg_temp.sid('su', s, n),
  pg_temp.sid('cl', s, (n * :enrol) % :classes), pg_temp.sid('res', s, ((n * :enrol) % :classes) * 1000 + 1),
  'Biology notebook', 'ready',
  pg_temp.notebook_content(),
  1, now(), 'scale-seed', true, true
from generate_series(1, :schools) s, generate_series(1, :students) n;
-- 30% of students on Max and 20% on Plus, as grants (no store purchase).
insert into private.study_plan_grants (user_id, plan, reason, ends_at)
select pg_temp.sid('su', s, n), case when n % 10 < 3 then 'max' else 'plus' end, 'capacity test',
  now() + interval '30 days'
from generate_series(1, :schools) s, generate_series(1, :students) n
where n % 10 < 5;

set session_replication_role = origin;
\echo 'analyze'
analyze;
select relname, n_live_tup from pg_stat_user_tables
where n_live_tup > 10000 order by n_live_tup desc limit 20;
