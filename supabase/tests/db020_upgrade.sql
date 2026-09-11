begin;
create extension if not exists pgtap with schema extensions;
set local search_path = public, extensions;
select plan(18);

select is((select count(*) from public.schools), 2::bigint,
  'legacy schools survive the DB-020 upgrade');
select is((select count(*) from public.profiles), 4::bigint,
  'legacy profiles and identifiers survive the DB-020 upgrade');
select is((select count(*) from public.memberships), 4::bigint,
  'legacy memberships survive the DB-020 upgrade');

select is(
  (select role::text || ':' || status::text
   from public.memberships
   where id = '71000000-0000-4000-8000-000000000013'),
  'parent:suspended',
  'legacy parent remains compatible and inactive membership becomes suspended'
);

select is(
  (select count(*) from public.terms where status = 'active'),
  2::bigint,
  'each synthetic school retains its active term'
);

select is(
  (select status::text from public.enrollments
   where classroom_id = '71000000-0000-4000-8000-000000000051'),
  'withdrawn',
  'inactive enrollment becomes withdrawn'
);

select is(
  (select status::text from public.lesson_sessions
   where id = '71000000-0000-4000-8000-000000000061'),
  'completed',
  'filed lesson session becomes completed'
);

select is(
  (select status::text from public.submissions
   where id = '71000000-0000-4000-8000-000000000091'),
  'excused',
  'excused submission keeps its lifecycle meaning'
);

select is(
  (select visibility::text from public.wellbeing_events
   where id = '71000000-0000-4000-8000-0000000000e1'),
  'class_staff',
  'wellbeing records default to class-staff visibility'
);

select is(
  (select published_by from public.grade_results
   where id = '71000000-0000-4000-8000-0000000000c1'),
  '71000000-0000-4000-8000-000000000001'::uuid,
  'published grade receives the legacy reviewer as publication actor'
);

select is(
  (select count(*) from public.classroom_staff where role = 'lead_teacher'),
  2::bigint,
  'legacy classroom teachers are backfilled as lead teachers'
);

select is(
  (select membership_id from public.classroom_staff
   where classroom_id = '71000000-0000-4000-8000-000000000051'),
  '71000000-0000-4000-8000-000000000011'::uuid,
  'classroom staff points to the matching same-school membership'
);

select is(
  (select school_id from public.notifications
   where id = '71000000-0000-4000-8000-000000000111'),
  '71111111-1111-4111-8111-111111111111'::uuid,
  'notification tenant is inferred from its only membership school'
);

select is(
  (select school_id from public.ai_grading_drafts
   where id = '71000000-0000-4000-8000-000000000121'),
  '71111111-1111-4111-8111-111111111111'::uuid,
  'AI draft tenant is inherited from its grade result'
);

select is(
  (select school_id from public.practice_sessions
   where id = '71000000-0000-4000-8000-000000000141'),
  '71111111-1111-4111-8111-111111111111'::uuid,
  'practice session tenant is inherited from its classroom'
);

select is(
  (select count(*) from public.subscription_entitlements),
  1::bigint,
  'legacy subscription entitlement remains untouched'
);

select is(
  (select count(*)
   from pg_constraint
   where conname like 'db020\_%' escape '\'
     and not convalidated),
  0::bigint,
  'every DB-020 constraint is validated'
);

select is(
  (select count(*)
   from information_schema.columns
   where table_schema = 'public'
     and table_name = any(array[
       'guardian_links', 'enrollments', 'lesson_sessions',
       'lesson_materials', 'assignments', 'submissions', 'assessments',
       'assessment_questions', 'grade_results', 'attendance_records',
       'wellbeing_events', 'meetings', 'meeting_deliveries',
       'notifications', 'ai_grading_drafts', 'question_suggestions',
       'practice_sessions'
     ])
     and column_name = 'school_id'
     and is_nullable <> 'NO'),
  0::bigint,
  'all upgraded school-owned aggregates have non-null tenant columns'
);

select * from finish();
rollback;
