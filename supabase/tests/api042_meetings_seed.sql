-- API-042 S5 fixture: reuse the shared graph, add a second enrolled student
-- with a verified guardian and a second unverified guardian, so recipient
-- resolution has more than one student/guardian pair to prove it is bulk,
-- not per-row.
\set auth031_fixture_only true
\ir rls_access_seed.sql
\ir db021_access_seed.sql
\unset auth031_fixture_only

\set second_student_user 'f0450000-0000-4000-8000-000000000001'
\set second_student_id 'f0450000-0000-4000-8000-000000000002'
\set second_guardian 'f0450000-0000-4000-8000-000000000003'
\set third_guardian_unverified 'f0450000-0000-4000-8000-000000000004'

\set QUIET on

insert into auth.users (
  id, email, encrypted_password, aud, role, email_confirmed_at, created_at,
  updated_at, instance_id, confirmation_token, recovery_token, email_change,
  email_change_token_new, email_change_token_current, phone_change_token,
  raw_app_meta_data, raw_user_meta_data
) values
  (:'second_student_user', 'seed.meetings-student2@synthetic.studafy.test', 'synthetic-not-a-secret', 'authenticated', 'authenticated', now(), now(), now(), '00000000-0000-0000-0000-000000000000', '', '', '', '', '', '', '{}'::jsonb, '{"full_name":"Seed Meetings Student 2"}'::jsonb),
  (:'second_guardian', 'seed.meetings-guardian2@synthetic.studafy.test', 'synthetic-not-a-secret', 'authenticated', 'authenticated', now(), now(), now(), '00000000-0000-0000-0000-000000000000', '', '', '', '', '', '', '{}'::jsonb, '{"full_name":"Seed Meetings Guardian 2"}'::jsonb),
  (:'third_guardian_unverified', 'seed.meetings-guardian3@synthetic.studafy.test', 'synthetic-not-a-secret', 'authenticated', 'authenticated', now(), now(), now(), '00000000-0000-0000-0000-000000000000', '', '', '', '', '', '', '{}'::jsonb, '{"full_name":"Seed Meetings Guardian 3"}'::jsonb)
on conflict (id) do nothing;

update auth.users set
  instance_id = '00000000-0000-0000-0000-000000000000',
  updated_at = coalesce(updated_at, now()),
  confirmation_token = '', recovery_token = '', email_change = '',
  email_change_token_new = '', email_change_token_current = '', phone_change_token = ''
where id in (:'second_student_user', :'second_guardian', :'third_guardian_unverified')
  and (instance_id is null or confirmation_token is null or recovery_token is null
    or email_change_token_new is null or updated_at is null);

insert into public.students (id, school_id, user_id, studafy_id, display_name, provisional, created_by) values
  (:'second_student_id', :'school_id', :'second_student_user', 'STU-SEED-MEET2', 'Seed Meetings Student 2', false, :'teacher_user')
on conflict (id) do nothing;

insert into public.enrollments (school_id, classroom_id, student_id, active, status, starts_on) values
  (:'school_id', :'classroom_id', :'second_student_id', true, 'active', current_date)
on conflict (school_id, classroom_id, student_id) do nothing;

insert into public.guardian_links (school_id, student_id, guardian_id, status, relationship, verified_by, verified_at) values
  (:'school_id', :'second_student_id', :'second_guardian', 'verified', 'parent', :'teacher_user', now()),
  (:'school_id', :'second_student_id', :'third_guardian_unverified', 'pending', 'parent', null, null)
on conflict (student_id, guardian_id) do nothing;

\ir api042_meetings.sql
