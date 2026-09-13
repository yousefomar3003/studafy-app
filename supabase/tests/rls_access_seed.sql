-- ARC-001 / TEST-006 synthetic fixture for supabase/tests/rls_access.sql.
--
-- This file is the synthetic data generator required by Part 0B: it creates a
-- disposable two-school fixture (identities, memberships, a classroom, an
-- enrolled student, guardian links, grades, attendance, wellbeing, audit) and
-- defines the psql variables the test file interpolates. It then includes the
-- test file in the same psql session so the variables resolve.
--
-- Run order (disposable local stack only; never against real data):
--   bunx supabase db reset --local --no-seed
--   bunx supabase test db --local supabase/tests/containment.sql \
--     supabase/tests/rls_access_seed.sql
--
-- All UUIDs, emails, and names below are synthetic constants.

\set school_id '11111111-1111-1111-1111-111111111111'
\set other_school_id '22222222-2222-2222-2222-222222222222'
\set teacher_user 'aaaa0000-0000-4000-8000-000000000001'
\set student_user 'bbbb0000-0000-4000-8000-000000000002'
\set guardian_user 'cccc0000-0000-4000-8000-000000000003'
\set unverified_guardian 'dddd0000-0000-4000-8000-000000000004'
\set other_school_user 'eeee0000-0000-4000-8000-000000000005'
\set term_id 'abce0000-0000-4000-8000-000000000006'
\set classroom_id 'abcd0000-0000-4000-8000-000000000007'
\set student_id 'abcf0000-0000-4000-8000-000000000008'
\set published_assessment_id 'abd00000-0000-4000-8000-000000000009'
\set draft_assessment_id 'abd10000-0000-4000-8000-00000000000a'
\set session_id 'abd20000-0000-4000-8000-00000000000b'
\set wellbeing_event_id 'abd30000-0000-4000-8000-00000000000c'

\set QUIET on

-- Synthetic identities. The on_auth_user_created trigger creates the
-- least-privileged profiles automatically. Every insert is idempotent so the
-- fixture can be replayed without a database reset. GoTrue resolves users by
-- sub only when instance_id matches the local stack's zero-uuid instance, and
-- its /user scan requires the varchar token columns to be '' rather than NULL
-- (phone stays NULL: it carries a full UNIQUE constraint). Both properties
-- are set explicitly and healed on replay.
insert into auth.users (
  id, email, encrypted_password, aud, role, email_confirmed_at, created_at,
  updated_at, instance_id, confirmation_token, recovery_token, email_change,
  email_change_token_new, email_change_token_current, phone_change_token,
  raw_app_meta_data, raw_user_meta_data
) values
  (:'teacher_user', 'seed.teacher@synthetic.studafy.test', 'synthetic-not-a-secret', 'authenticated', 'authenticated', now(), now(), now(), '00000000-0000-0000-0000-000000000000', '', '', '', '', '', '', '{}'::jsonb, '{"full_name":"Seed Teacher"}'::jsonb),
  (:'student_user', 'seed.student@synthetic.studafy.test', 'synthetic-not-a-secret', 'authenticated', 'authenticated', now(), now(), now(), '00000000-0000-0000-0000-000000000000', '', '', '', '', '', '', '{}'::jsonb, '{"full_name":"Seed Student"}'::jsonb),
  (:'guardian_user', 'seed.guardian@synthetic.studafy.test', 'synthetic-not-a-secret', 'authenticated', 'authenticated', now(), now(), now(), '00000000-0000-0000-0000-000000000000', '', '', '', '', '', '', '{}'::jsonb, '{"full_name":"Seed Guardian"}'::jsonb),
  (:'unverified_guardian', 'seed.unverified@synthetic.studafy.test', 'synthetic-not-a-secret', 'authenticated', 'authenticated', now(), now(), now(), '00000000-0000-0000-0000-000000000000', '', '', '', '', '', '', '{}'::jsonb, '{"full_name":"Seed Unverified Guardian"}'::jsonb),
  (:'other_school_user', 'seed.other@synthetic.studafy.test', 'synthetic-not-a-secret', 'authenticated', 'authenticated', now(), now(), now(), '00000000-0000-0000-0000-000000000000', '', '', '', '', '', '', '{}'::jsonb, '{"full_name":"Seed Other School Teacher"}'::jsonb)
on conflict (id) do nothing;

update auth.users set
  instance_id = '00000000-0000-0000-0000-000000000000',
  updated_at = coalesce(updated_at, now()),
  confirmation_token = '',
  recovery_token = '',
  email_change = '',
  email_change_token_new = '',
  email_change_token_current = '',
  phone_change_token = ''
where id in (:'teacher_user', :'student_user', :'guardian_user', :'unverified_guardian', :'other_school_user')
  and (instance_id is null or confirmation_token is null or recovery_token is null
    or email_change_token_new is null or updated_at is null);

insert into public.schools (id, name, status) values
  (:'school_id', 'Seed School A', 'active'),
  (:'other_school_id', 'Seed School B', 'active')
on conflict (id) do update set status = excluded.status;

insert into public.memberships (school_id, user_id, role, active) values
  (:'school_id', :'teacher_user', 'teacher', true),
  (:'school_id', :'student_user', 'student', true),
  (:'school_id', :'guardian_user', 'parent', true),
  (:'other_school_id', :'other_school_user', 'teacher', true)
on conflict (school_id, user_id, role) do nothing;

insert into public.terms (id, school_id, name, starts_on, ends_on, active) values
  (:'term_id', :'school_id', 'Seed Term 1', '2026-09-01', '2026-12-31', true)
on conflict (id) do nothing;

insert into public.students (id, school_id, user_id, studafy_id, display_name, provisional, created_by) values
  (:'student_id', :'school_id', :'student_user', 'STU-SEED-0001', 'Seed Student', false, :'teacher_user')
on conflict (id) do nothing;

insert into public.guardian_links (student_id, guardian_id, status, relationship, verified_by, verified_at) values
  (:'student_id', :'guardian_user', 'verified', 'parent', :'teacher_user', now()),
  (:'student_id', :'unverified_guardian', 'pending', 'parent', null, null)
on conflict (student_id, guardian_id) do nothing;

insert into public.classrooms (id, school_id, term_id, name, grade, section, teacher_id) values
  (:'classroom_id', :'school_id', :'term_id', 'Seed Classroom', 'G6', 'A', :'teacher_user')
on conflict (id) do nothing;

insert into public.classroom_staff (
  school_id, classroom_id, membership_id, user_id, role
)
select :'school_id', :'classroom_id', m.id, :'teacher_user', 'lead_teacher'
from public.memberships m
where m.school_id=:'school_id' and m.user_id=:'teacher_user' and m.role='teacher'
on conflict do nothing;

insert into public.enrollments (classroom_id, student_id, active) values
  (:'classroom_id', :'student_id', true)
on conflict (classroom_id, student_id) do nothing;

insert into public.lesson_sessions (id, classroom_id, starts_at, ends_at, title) values
  (:'session_id', :'classroom_id', '2026-09-10 08:00+00', '2026-09-10 09:00+00', 'Seed Session')
on conflict (id) do nothing;

insert into public.assessments (id, classroom_id, title, category, maximum_score, scheduled_at, state, delivery, created_by, published_at) values
  (:'published_assessment_id', :'classroom_id', 'Seed Published Quiz', 'quiz', 10, '2026-09-10 09:00+00', 'published', 'paper', :'teacher_user', now()),
  (:'draft_assessment_id', :'classroom_id', 'Seed Draft Quiz', 'quiz', 10, '2026-09-17 09:00+00', 'draft', 'paper', :'teacher_user', null)
on conflict (id) do nothing;

insert into public.grade_results (assessment_id, student_id, score, state, reviewed_by, reviewed_at, published_at) values
  (:'published_assessment_id', :'student_id', 8, 'published', :'teacher_user', now(), now()),
  (:'draft_assessment_id', :'student_id', 7, 'draft', null, null, null)
on conflict (assessment_id, student_id) do nothing;

insert into public.attendance_records (session_id, student_id, state, recorded_by) values
  (:'session_id', :'student_id', 'present', :'teacher_user')
on conflict (session_id, student_id) do nothing;

insert into public.wellbeing_events (id, student_id, classroom_id, kind, title, context, created_by) values
  (:'wellbeing_event_id', :'student_id', :'classroom_id', 'note', 'Seed wellbeing note', 'Synthetic fixture note', :'teacher_user')
on conflict (id) do nothing;

insert into public.audit_events (school_id, actor_id, action, entity_type, entity_id)
select :'school_id', :'teacher_user', 'fixture.seed', 'school', :'school_id'
where not exists (
  select 1 from public.audit_events
  where school_id=:'school_id' and action='fixture.seed'
);

-- The first two assertions in rls_access.sql run before that file switches to
-- the authenticated role, so the session identity must already be the student.
select set_config('request.jwt.claim.sub', :'student_user', false);

\set QUIET off

\ir rls_access.sql
