begin;
select plan(8);

-- These tests intentionally prove both sides of the security boundary.
-- supabase/tests/rls_access_seed.sql must run first in the same psql
-- session: it defines :student_user, :guardian_user, :unverified_guardian,
-- :teacher_user, :other_school_user, :student_id, :classroom_id and
-- :school_id as synthetic cross-school fixtures, then includes this file.
set local role authenticated;
select set_config('request.jwt.claim.sub', :'student_user', true);
select is(
  (select count(*) from public.students where id=:'student_id'),
  1::bigint,
  'student can access self'
);
select is(
  (select count(*) from public.classrooms where id=:'classroom_id'),
  1::bigint,
  'enrolled student can access classroom'
);

select set_config('request.jwt.claim.sub', :'guardian_user', true);
select is(
  (select count(*) from public.grade_results where student_id=:'student_id' and state='published'),
  1::bigint,
  'verified guardian sees published grade'
);
select is(
  (select count(*) from public.grade_results where student_id=:'student_id' and state='draft'),
  0::bigint,
  'guardian cannot see draft grade'
);

select set_config('request.jwt.claim.sub', :'unverified_guardian', true);
select is((select count(*) from public.students where id=:'student_id'), 0::bigint,
  'unverified guardian cannot access student');

select set_config('request.jwt.claim.sub', :'other_school_user', true);
select is((select count(*) from public.attendance_records where student_id=:'student_id'), 0::bigint,
  'cross-school user cannot access attendance');
select is((select count(*) from public.wellbeing_events where student_id=:'student_id'), 0::bigint,
  'cross-school user cannot access wellbeing');
select throws_like(
  $$select count(*) from public.audit_events$$,
  '%permission denied%',
  'authenticated clients have no direct audit-table privilege'
);

select * from finish();
rollback;
