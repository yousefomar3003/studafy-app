begin;
create extension if not exists pgtap with schema extensions;
set local search_path = public, extensions;
select plan(38);

set local role authenticated;
select set_config('request.jwt.claim.sub', :'admin_user', true);
select is((select count(*) from public.enrollments where classroom_id=:'classroom_id'), 2::bigint,
  'school administrator sees the complete classroom roster');

select set_config('request.jwt.claim.sub', :'co_teacher_user', true);
select is((select count(*) from public.enrollments where classroom_id=:'classroom_id'), 2::bigint,
  'assigned co-teacher sees the complete classroom roster');
select is((select count(*) from public.grade_results where assessment_id=:'draft_assessment_id'), 1::bigint,
  'assigned co-teacher sees draft grades for the exact classroom');

select set_config('request.jwt.claim.sub', :'student_user', true);
select is((select count(*) from public.enrollments where classroom_id=:'classroom_id'), 1::bigint,
  'student sees only their own enrollment row');
select is((select count(*) from public.students where id=:'second_student_id'), 0::bigint,
  'student cannot enumerate a classmate profile');
select is((select count(*) from public.assessments where id=:'published_assessment_id'), 1::bigint,
  'student sees a published assessment');
select is((select count(*) from public.assessments where id=:'draft_assessment_id'), 0::bigint,
  'student cannot see a draft assessment');
select is((select count(*) from public.grade_results where assessment_id=:'published_assessment_id'), 1::bigint,
  'student sees their published grade');
select is((select count(*) from public.grade_results where assessment_id=:'draft_assessment_id'), 0::bigint,
  'student cannot see a draft grade');

select set_config('request.jwt.claim.sub', :'guardian_user', true);
select is((select count(*) from public.enrollments where classroom_id=:'classroom_id'), 1::bigint,
  'guardian sees only their linked child enrollment');
select is((select count(*) from public.students where id=:'second_student_id'), 0::bigint,
  'guardian cannot enumerate another child');
select is((select count(*) from public.wellbeing_events where id=:'guardian_wellbeing_id'), 1::bigint,
  'guardian sees guardian-shared wellbeing information');
select is((select count(*) from public.wellbeing_events where id=:'shared_wellbeing_id'), 1::bigint,
  'guardian sees student-and-guardian-shared wellbeing information');
select is((select count(*) from public.wellbeing_events where id=:'restricted_wellbeing_id'), 0::bigint,
  'guardian cannot see safeguarding-restricted wellbeing information');

select set_config('request.jwt.claim.sub', :'student_user', true);
select is((select count(*) from public.wellbeing_events where id=:'guardian_wellbeing_id'), 0::bigint,
  'student cannot see guardian-only wellbeing information');
select is((select count(*) from public.wellbeing_events where id=:'shared_wellbeing_id'), 1::bigint,
  'student sees explicitly student-shared wellbeing information');
select is((select count(*) from public.wellbeing_events where id=:'restricted_wellbeing_id'), 0::bigint,
  'student cannot see safeguarding-restricted wellbeing information');

select set_config('request.jwt.claim.sub', :'expired_guardian_user', true);
select is((select count(*) from public.students where id=:'student_id'), 0::bigint,
  'expired guardian link denies access');

select set_config('request.jwt.claim.sub', :'unassigned_teacher_user', true);
select is((select count(*) from public.grade_results where assessment_id=:'draft_assessment_id'), 0::bigint,
  'same-school unassigned teacher cannot access classroom grades');

select set_config('request.jwt.claim.sub', :'suspended_teacher_user', true);
select is((select count(*) from public.schools where id=:'school_id'), 0::bigint,
  'suspended profile loses school access');

select set_config('request.jwt.claim.sub', :'other_school_user', true);
select is((select count(*) from public.classrooms where id=:'classroom_id'), 0::bigint,
  'cross-school classroom identifier substitution is denied');

select set_config('request.jwt.claim.sub', :'student_user', true);
select is((select count(*) from public.resources where id=:'clean_resource_id'), 1::bigint,
  'student can read a clean published classroom resource');
select is((select count(*) from public.resources where id=:'dirty_resource_id'), 0::bigint,
  'quarantined resource remains unpublished to students');
select throws_like(
  $$select count(*) from public.file_objects$$,
  '%permission denied%',
  'authenticated users cannot access file metadata directly'
);
select throws_like(
  $$insert into public.submissions (assignment_id,student_id)
    values ('abd40000-0000-4000-8000-00000000010a','abcf0000-0000-4000-8000-000000000008')$$,
  '%permission denied%',
  'students cannot insert submissions directly'
);
select throws_like(
  $$update public.notifications set read_at=now() where user_id=auth.uid()$$,
  '%permission denied%',
  'clients cannot update notifications directly'
);

select is(public.mark_notifications_read(), 2,
  'notification RPC updates only the caller unread rows');
select is(public.mark_notifications_read(), 0,
  'notification RPC is idempotent when no unread rows remain');
select is((select count(*) from public.notifications where user_id=:'guardian_user' and read_at is null), 0::bigint,
  'RLS prevents student inspection of guardian notification state');

select lives_ok(
  $$select public.record_policy_consent('terms_and_privacy','2026-09-09','en')$$,
  'authenticated user can record a supported consent'
);
select lives_ok(
  $$select public.record_policy_consent('terms_and_privacy','2026-09-09','en')$$,
  'repeating the same consent is idempotent'
);
select is(
  (select count(*) from public.consent_records
   where purpose='terms_and_privacy' and policy_version='2026-09-09'),
  1::bigint,
  'repeated consent retains one caller-owned record'
);
select throws_like(
  $$select public.record_policy_consent('unknown','2026-09-09','en')$$,
  '%Unsupported consent purpose%',
  'consent RPC rejects unsupported purposes'
);
select throws_like(
  $$select public.record_policy_consent('terms_and_privacy','2026-09-09','fr')$$,
  '%Unsupported locale%',
  'consent RPC rejects unsupported locales'
);

reset role;
set local role anon;
select throws_like(
  $$select public.mark_notifications_read()$$,
  '%permission denied%',
  'anonymous caller cannot invoke notification mutation'
);
select throws_like(
  $$select public.record_policy_consent('terms_and_privacy','2026-09-09','en')$$,
  '%permission denied%',
  'anonymous caller cannot invoke consent mutation'
);

reset role;
select is(
  (select count(*) from public.notifications
   where user_id=:'guardian_user' and read_at is null),
  1::bigint,
  'student notification command does not mutate another recipient rows'
);
select throws_like(
  $$update public.submissions
    set assignment_id='abd40000-0000-4000-8000-00000000010a'
    where id='abd50000-0000-4000-8000-00000000010b'$$,
  '%Immutable relationship column cannot be changed%',
  'submission assignment identity is structurally immutable'
);

select * from finish();
rollback;
