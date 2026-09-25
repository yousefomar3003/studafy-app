-- Who a notification reaches.
--
-- Until now the answer was "staff, and only staff", for every event in the
-- product. These assertions pin the two halves of the fix: families are now
-- told about the things that concern them, and the events that were always
-- staff-only still are. Seeds its own fixtures and rolls back.
begin;
create extension if not exists pgtap with schema extensions;
set local search_path = public, extensions;
select plan(17);

select ok(
  has_function_privilege('studafy_worker_runtime',
    'private.api061_finish_notification(bigint)', 'execute'),
  'the worker runtime may finish a notification');
select ok(
  not has_function_privilege('studafy_api_runtime',
    'private.api061_finish_notification(bigint)', 'execute'),
  'the api runtime may not');
-- The resolver decides who is told about a child. It is reachable only from
-- inside the finisher, which runs as its owner.
select ok(
  not has_function_privilege('authenticated',
    'private.api061_notification_recipients(uuid,text,text,jsonb)', 'execute'),
  'a signed-in client may not resolve an audience directly');
select ok(
  not has_function_privilege('studafy_worker_runtime',
    'private.api061_notification_recipients(uuid,text,text,jsonb)', 'execute'),
  'and neither may the worker, which only ever calls the finisher');

\set school   '7b000000-0000-4000-8000-000000000001'
\set term     '7b000000-0000-4000-8000-000000000002'
\set class    '7b000000-0000-4000-8000-000000000003'
\set admin    '7b000000-0000-4000-8000-0000000000a1'
\set teacher  '7b000000-0000-4000-8000-0000000000a2'
\set kid      '7b000000-0000-4000-8000-0000000000a3'
\set parent   '7b000000-0000-4000-8000-0000000000a4'
\set expired  '7b000000-0000-4000-8000-0000000000a5'
\set other    '7b000000-0000-4000-8000-0000000000a6'
\set otherkid '7b000000-0000-4000-8000-0000000000a7'
\set student  '7b000000-0000-4000-8000-0000000000b1'
\set student2 '7b000000-0000-4000-8000-0000000000b2'
\set link     '7b000000-0000-4000-8000-0000000000c1'
\set work     '7b000000-0000-4000-8000-0000000000d1'
\set exam     '7b000000-0000-4000-8000-0000000000d2'
\set mark     '7b000000-0000-4000-8000-0000000000d3'
\set shared   '7b000000-0000-4000-8000-0000000000e1'
\set secret   '7b000000-0000-4000-8000-0000000000e2'

insert into auth.users (id, email, aud, role) values
  (:'admin',    'na@synthetic.studafy.test', 'authenticated', 'authenticated'),
  (:'teacher',  'nt@synthetic.studafy.test', 'authenticated', 'authenticated'),
  (:'kid',      'nk@synthetic.studafy.test', 'authenticated', 'authenticated'),
  (:'parent',   'np@synthetic.studafy.test', 'authenticated', 'authenticated'),
  (:'expired',  'ne@synthetic.studafy.test', 'authenticated', 'authenticated'),
  (:'other',    'no@synthetic.studafy.test', 'authenticated', 'authenticated'),
  (:'otherkid', 'nz@synthetic.studafy.test', 'authenticated', 'authenticated')
on conflict (id) do nothing;
insert into public.profiles (id, display_name, status) values
  (:'admin', 'Admin', 'active'), (:'teacher', 'Teacher', 'active'),
  (:'kid', 'Kid', 'active'), (:'parent', 'Parent', 'active'),
  (:'expired', 'Expired guardian', 'active'),
  (:'other', 'Other parent', 'active'), (:'otherkid', 'Other kid', 'active')
on conflict (id) do update set status = 'active';

insert into public.schools (id, name, timezone, locale, status)
  values (:'school', 'Audience Test School', 'Asia/Amman', 'en', 'active');
insert into public.memberships (id, school_id, user_id, role, active, status) values
  ('7b000000-0000-4000-8000-0000000000f1', :'school', :'admin', 'school_admin', true, 'active'),
  ('7b000000-0000-4000-8000-0000000000f2', :'school', :'teacher', 'teacher', true, 'active'),
  ('7b000000-0000-4000-8000-0000000000f3', :'school', :'kid', 'student', true, 'active'),
  ('7b000000-0000-4000-8000-0000000000f4', :'school', :'otherkid', 'student', true, 'active');
insert into public.terms (id, school_id, name, starts_on, ends_on, active, status)
  values (:'term', :'school', 'T', current_date - 30, current_date + 300, true, 'active');
insert into public.classrooms (id, school_id, term_id, name, grade, section, room, teacher_id, status)
  values (:'class', :'school', :'term', 'C', '9', 'A', 'R', :'teacher', 'active');
insert into public.classroom_staff (school_id, classroom_id, membership_id, user_id, role, status)
  values (:'school', :'class', '7b000000-0000-4000-8000-0000000000f2', :'teacher',
          'lead_teacher', 'active');

insert into public.students (id, school_id, user_id, studafy_id, display_name, created_by) values
  (:'student',  :'school', :'kid',      'SJ-AUDIENCE1', 'Kid Student', :'teacher'),
  (:'student2', :'school', :'otherkid', 'SJ-AUDIENCE2', 'Other Student', :'teacher');
insert into public.enrollments (school_id, classroom_id, student_id, active, status, starts_on) values
  (:'school', :'class', :'student',  true, 'active', current_date - 20),
  (:'school', :'class', :'student2', true, 'active', current_date - 20);

-- One verified guardian, one whose link has expired, and one guardian of the
-- *other* child in the same class.
insert into public.guardian_links (
  id, school_id, student_id, guardian_id, status, relationship,
  verified_by, verified_at, expires_at) values
  (:'link', :'school', :'student', :'parent', 'verified', 'parent',
   :'kid', now(), now() + interval '30 days'),
  ('7b000000-0000-4000-8000-0000000000c2', :'school', :'student', :'expired',
   'verified', 'parent', :'kid', now() - interval '400 days',
   now() - interval '1 day'),
  ('7b000000-0000-4000-8000-0000000000c3', :'school', :'student2', :'other',
   'verified', 'parent', :'otherkid', now(), now() + interval '30 days');

insert into public.assignments (id, school_id, classroom_id, title, due_at, state, created_by, published_at)
  values (:'work', :'school', :'class', 'Homework', now() + interval '7 days',
          'published', :'teacher', now());
insert into public.assessments (id, school_id, classroom_id, title, category, maximum_score, state, created_by, published_at)
  values (:'exam', :'school', :'class', 'Test', 'exam', 100, 'published', :'teacher', now());
-- A published mark must carry its reviewer (api041 check constraint).
insert into public.grade_results (
  id, school_id, assessment_id, student_id, score, state,
  reviewed_by, reviewed_at, published_at, published_by)
  values (:'mark', :'school', :'exam', :'student', 80, 'published',
          :'teacher', now(), now(), :'teacher');
insert into public.wellbeing_events (
  id, school_id, student_id, classroom_id, kind, title, visibility, created_by) values
  (:'shared', :'school', :'student', :'class', 'note', 'Shared with home',
   'guardian_shared', :'teacher'),
  (:'secret', :'school', :'student', :'class', 'note', 'Restricted',
   'safeguarding_restricted', :'teacher');

create or replace function pg_temp.who(p_template text, p_source text, p_audience jsonb)
returns uuid[] language sql as $$
  select coalesce(
    (select array_agg(u order by u) from unnest(
      private.api061_notification_recipients(
        '7b000000-0000-4000-8000-000000000001'::uuid, p_template, p_source,
        p_audience)) as t(u)),
    array[]::uuid[]);
$$;

\set classaud '{"classroomId": "7b000000-0000-4000-8000-000000000003"}'
\set schoolaud '{"schoolId": "7b000000-0000-4000-8000-000000000001"}'

-- Published work: the class, their verified guardians, and the staff who
-- already received it. The expired link is not a link.
select set_eq(
  $$ select unnest(pg_temp.who('academic.assignment_published',
       '7b000000-0000-4000-8000-0000000000d1',
       '{"classroomId": "7b000000-0000-4000-8000-000000000003"}'::jsonb)) $$,
  array[:'teacher', :'kid', :'otherkid', :'parent', :'other']::uuid[],
  'published work reaches the class, their verified guardians and staff');
select ok(
  not (:'expired'::uuid = any(pg_temp.who('academic.assignment_published',
    '7b000000-0000-4000-8000-0000000000d1', :'classaud'::jsonb))),
  'a guardian whose link has expired is not told');

-- A mark is about one child. Telling the class would be a statement about
-- somebody else's child.
select set_eq(
  $$ select unnest(pg_temp.who('academic.grade_published',
       '7b000000-0000-4000-8000-0000000000d3',
       '{"classroomId": "7b000000-0000-4000-8000-000000000003"}'::jsonb)) $$,
  array[:'teacher', :'kid', :'parent']::uuid[],
  'a published mark reaches only that child, their guardian and staff');

-- Pastoral notes. "Shared with home" means the guardians, not the child;
-- restricted means neither, at any time.
select set_eq(
  $$ select unnest(pg_temp.who('academic.wellbeing_shared',
       '7b000000-0000-4000-8000-0000000000e1',
       '{"classroomId": "7b000000-0000-4000-8000-000000000003"}'::jsonb)) $$,
  array[:'teacher', :'parent']::uuid[],
  'a note shared with home reaches the guardian, not the child');
select set_eq(
  $$ select unnest(pg_temp.who('academic.wellbeing_shared',
       '7b000000-0000-4000-8000-0000000000e2',
       '{"classroomId": "7b000000-0000-4000-8000-000000000003"}'::jsonb)) $$,
  array[:'teacher']::uuid[],
  'a safeguarding-restricted note reaches no family, even under this template');

-- A guardian link concerns the two people it is between.
select ok(
  :'parent'::uuid = any(pg_temp.who('family.guardian_link_verified',
    '7b000000-0000-4000-8000-0000000000c1', :'schoolaud'::jsonb)),
  'a verified link tells the guardian it concerns');
select ok(
  :'kid'::uuid = any(pg_temp.who('family.guardian_link_requested',
    '7b000000-0000-4000-8000-0000000000c1', :'schoolaud'::jsonb)),
  'a requested link tells the student, who is the one who decides');
select ok(
  not (:'other'::uuid = any(pg_temp.who('family.guardian_link_verified',
    '7b000000-0000-4000-8000-0000000000c1', :'schoolaud'::jsonb))),
  'and tells no other family');

-- The regression guard: everything that was staff-only stays staff-only.
select set_eq(
  $$ select unnest(pg_temp.who('school_admin.membership_granted', null,
       '{"schoolId": "7b000000-0000-4000-8000-000000000001"}'::jsonb)) $$,
  array[:'admin', :'teacher']::uuid[],
  'an administrative event still reaches admins and teachers only');
select set_eq(
  $$ select unnest(pg_temp.who('school_admin.classroom_staff_assigned',
       null, '{"classroomId": "7b000000-0000-4000-8000-000000000003"}'::jsonb)) $$,
  array[:'teacher']::uuid[],
  'a classroom staffing event still reaches that classroom''s staff only');

-- Unresolvable audiences still dead-letter rather than silently reaching
-- nobody: null is the caller's signal, an empty array is a real answer.
select is(
  private.api061_notification_recipients(:'school', 'academic.grade_published',
    :'mark', '{}'::jsonb),
  null, 'an audience with neither key is unresolvable');
select is(
  private.api061_notification_recipients(:'school', 'academic.grade_published',
    :'mark', '{"schoolId": "7b000000-0000-4000-8000-00000000ffff"}'::jsonb),
  null, 'a school audience for another school is unresolvable');

-- source_event_id is text and not every producer writes a uuid into it.
-- Casting it unconditionally raised inside the dispatcher, which fails the
-- job rather than the row and poisons the queue for everyone.
select set_eq(
  $$ select unnest(pg_temp.who('academic.grade_published', 'evt-not-a-uuid',
       '{"classroomId": "7b000000-0000-4000-8000-000000000003"}'::jsonb)) $$,
  array[:'teacher']::uuid[],
  'a source id that is not a uuid resolves to the staff audience, not an error');

select * from finish();
rollback;
