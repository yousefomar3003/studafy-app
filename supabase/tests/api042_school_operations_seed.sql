-- API-042 S1 fixture: reuse the full DB-021/AUTH-031 multi-role graph, then
-- add a platform operator, a second teacher, an unenrolled student and a
-- second classroom so staffing/enrollment/transfer commands have real
-- targets that do not collide with the shared read-path fixtures.
\set auth031_fixture_only true
\ir rls_access_seed.sql
\ir db021_access_seed.sql
\unset auth031_fixture_only

\set operator_user 'f0420000-0000-4000-8000-000000000001'
\set second_teacher 'f0420000-0000-4000-8000-000000000002'
\set fresh_student_user 'f0420000-0000-4000-8000-000000000003'
\set fresh_student_id 'f0420000-0000-4000-8000-000000000004'
\set second_classroom_id 'f0420000-0000-4000-8000-000000000005'

\set QUIET on

insert into auth.users (
  id, email, encrypted_password, aud, role, email_confirmed_at, created_at,
  updated_at, instance_id, confirmation_token, recovery_token, email_change,
  email_change_token_new, email_change_token_current, phone_change_token,
  raw_app_meta_data, raw_user_meta_data
) values
  (:'operator_user', 'seed.operator@synthetic.studafy.test', 'synthetic-not-a-secret', 'authenticated', 'authenticated', now(), now(), now(), '00000000-0000-0000-0000-000000000000', '', '', '', '', '', '', '{}'::jsonb, '{"full_name":"Seed Platform Operator"}'::jsonb),
  (:'second_teacher', 'seed.second-teacher@synthetic.studafy.test', 'synthetic-not-a-secret', 'authenticated', 'authenticated', now(), now(), now(), '00000000-0000-0000-0000-000000000000', '', '', '', '', '', '', '{}'::jsonb, '{"full_name":"Seed Second Teacher"}'::jsonb),
  (:'fresh_student_user', 'seed.fresh-student@synthetic.studafy.test', 'synthetic-not-a-secret', 'authenticated', 'authenticated', now(), now(), now(), '00000000-0000-0000-0000-000000000000', '', '', '', '', '', '', '{}'::jsonb, '{"full_name":"Seed Fresh Student"}'::jsonb)
on conflict (id) do nothing;

update auth.users set
  instance_id = '00000000-0000-0000-0000-000000000000',
  updated_at = coalesce(updated_at, now()),
  confirmation_token = '', recovery_token = '', email_change = '',
  email_change_token_new = '', email_change_token_current = '', phone_change_token = ''
where id in (:'operator_user', :'second_teacher', :'fresh_student_user')
  and (instance_id is null or confirmation_token is null or recovery_token is null
    or email_change_token_new is null or updated_at is null);

insert into public.platform_operators (user_id, note) values
  (:'operator_user', 'api042 pgTAP fixture')
on conflict (user_id) do nothing;

insert into public.memberships (school_id, user_id, role, active, status, version) values
  (:'school_id', :'second_teacher', 'teacher', true, 'active', 1)
on conflict (school_id, user_id, role) do nothing;

insert into public.students (id, school_id, user_id, studafy_id, display_name, provisional, created_by) values
  (:'fresh_student_id', :'school_id', :'fresh_student_user', 'STU-SEED-F042', 'Seed Fresh Student', false, :'teacher_user')
on conflict (id) do nothing;

insert into public.classrooms (id, school_id, term_id, name, grade, section, teacher_id) values
  (:'second_classroom_id', :'school_id', :'term_id', 'Seed Second Classroom', 'G6', 'B', :'second_teacher')
on conflict (id) do nothing;

insert into public.classroom_staff (school_id, classroom_id, membership_id, user_id, role)
select :'school_id', :'second_classroom_id', m.id, :'second_teacher', 'lead_teacher'
from public.memberships m
where m.school_id = :'school_id' and m.user_id = :'second_teacher' and m.role = 'teacher'
on conflict do nothing;

\ir api042_school_operations.sql
