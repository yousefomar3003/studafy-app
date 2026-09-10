begin;
select plan(8);

-- These tests intentionally prove both sides of the security boundary.
-- supabase/tests/rls_access_seed.sql must run first in the same psql
-- session: it defines :student_user, :guardian_user, :unverified_guardian,
-- :teacher_user, :other_school_user, :student_id, :classroom_id and
-- :school_id as synthetic cross-school fixtures, then includes this file.
select ok(public.can_access_student(:'student_id'), 'student can access self');
select ok(public.can_access_classroom(:'classroom_id'), 'enrolled user can access classroom');

set local role authenticated;
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
select is((select count(*) from public.audit_events where school_id=:'school_id'), 0::bigint,
  'non-admin cannot read audit records');

select * from finish();
rollback;
