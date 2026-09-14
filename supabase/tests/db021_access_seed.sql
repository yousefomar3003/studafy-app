-- DB-021 deterministic extension to rls_access_seed.sql. Run the base fixture
-- first; this file adds the roles, states, sensitive columns, and command rows
-- required by the complete policy matrix.

\set school_id '11111111-1111-1111-1111-111111111111'
\set other_school_id '22222222-2222-2222-2222-222222222222'
\set teacher_user 'aaaa0000-0000-4000-8000-000000000001'
\set student_user 'bbbb0000-0000-4000-8000-000000000002'
\set guardian_user 'cccc0000-0000-4000-8000-000000000003'
\set unverified_guardian 'dddd0000-0000-4000-8000-000000000004'
\set other_school_user 'eeee0000-0000-4000-8000-000000000005'
\set admin_user 'ffff0000-0000-4000-8000-000000000001'
\set co_teacher_user 'ffff0000-0000-4000-8000-000000000002'
\set second_student_user 'ffff0000-0000-4000-8000-000000000003'
\set expired_guardian_user 'ffff0000-0000-4000-8000-000000000004'
\set unassigned_teacher_user 'ffff0000-0000-4000-8000-000000000005'
\set suspended_teacher_user 'ffff0000-0000-4000-8000-000000000006'
\set term_id 'abce0000-0000-4000-8000-000000000006'
\set classroom_id 'abcd0000-0000-4000-8000-000000000007'
\set student_id 'abcf0000-0000-4000-8000-000000000008'
\set second_student_id 'abcf0000-0000-4000-8000-000000000208'
\set published_assessment_id 'abd00000-0000-4000-8000-000000000009'
\set draft_assessment_id 'abd10000-0000-4000-8000-00000000000a'
\set session_id 'abd20000-0000-4000-8000-00000000000b'
\set published_assignment_id 'abd40000-0000-4000-8000-000000000109'
\set alternate_assignment_id 'abd40000-0000-4000-8000-00000000010a'
\set submission_id 'abd50000-0000-4000-8000-00000000010b'
\set guardian_wellbeing_id 'abd30000-0000-4000-8000-00000000010c'
\set shared_wellbeing_id 'abd30000-0000-4000-8000-00000000010d'
\set restricted_wellbeing_id 'abd30000-0000-4000-8000-00000000010e'
\set clean_resource_id 'abd60000-0000-4000-8000-00000000010f'
\set dirty_resource_id 'abd60000-0000-4000-8000-000000000110'

do $fixture$
begin
  if not exists (
    select 1 from public.classrooms
    where id = 'abcd0000-0000-4000-8000-000000000007'
  ) then
    raise exception 'Run rls_access_seed.sql before db021_access_seed.sql';
  end if;
end
$fixture$;

insert into auth.users (
  id, email, encrypted_password, aud, role, email_confirmed_at, created_at,
  updated_at, instance_id, confirmation_token, recovery_token, email_change,
  email_change_token_new, email_change_token_current, phone_change_token,
  raw_app_meta_data, raw_user_meta_data
) values
  (:'admin_user', 'seed.admin@synthetic.studafy.test', 'synthetic-not-a-secret', 'authenticated', 'authenticated', now(), now(), now(), '00000000-0000-0000-0000-000000000000', '', '', '', '', '', '', '{}'::jsonb, '{"full_name":"Seed Administrator"}'::jsonb),
  (:'co_teacher_user', 'seed.coteacher@synthetic.studafy.test', 'synthetic-not-a-secret', 'authenticated', 'authenticated', now(), now(), now(), '00000000-0000-0000-0000-000000000000', '', '', '', '', '', '', '{}'::jsonb, '{"full_name":"Seed Co Teacher"}'::jsonb),
  (:'second_student_user', 'seed.student2@synthetic.studafy.test', 'synthetic-not-a-secret', 'authenticated', 'authenticated', now(), now(), now(), '00000000-0000-0000-0000-000000000000', '', '', '', '', '', '', '{}'::jsonb, '{"full_name":"Seed Second Student"}'::jsonb),
  (:'expired_guardian_user', 'seed.expired.guardian@synthetic.studafy.test', 'synthetic-not-a-secret', 'authenticated', 'authenticated', now(), now(), now(), '00000000-0000-0000-0000-000000000000', '', '', '', '', '', '', '{}'::jsonb, '{"full_name":"Seed Expired Guardian"}'::jsonb),
  (:'unassigned_teacher_user', 'seed.unassigned@synthetic.studafy.test', 'synthetic-not-a-secret', 'authenticated', 'authenticated', now(), now(), now(), '00000000-0000-0000-0000-000000000000', '', '', '', '', '', '', '{}'::jsonb, '{"full_name":"Seed Unassigned Teacher"}'::jsonb),
  (:'suspended_teacher_user', 'seed.suspended@synthetic.studafy.test', 'synthetic-not-a-secret', 'authenticated', 'authenticated', now(), now(), now(), '00000000-0000-0000-0000-000000000000', '', '', '', '', '', '', '{}'::jsonb, '{"full_name":"Seed Suspended Teacher"}'::jsonb)
on conflict (id) do nothing;

insert into public.memberships (school_id, user_id, role, active) values
  (:'school_id', :'admin_user', 'school_admin', true),
  (:'school_id', :'co_teacher_user', 'teacher', true),
  (:'school_id', :'second_student_user', 'student', true),
  (:'school_id', :'expired_guardian_user', 'guardian', true),
  (:'school_id', :'unassigned_teacher_user', 'teacher', true),
  (:'school_id', :'suspended_teacher_user', 'teacher', true)
on conflict (school_id, user_id, role) do nothing;

update public.profiles set status='suspended'
where id=:'suspended_teacher_user';

insert into public.classroom_staff (
  school_id, classroom_id, membership_id, user_id, role
)
select :'school_id', :'classroom_id', m.id, :'co_teacher_user', 'co_teacher'
from public.memberships m
where m.school_id=:'school_id' and m.user_id=:'co_teacher_user'
on conflict do nothing;

insert into public.students (
  id, school_id, user_id, studafy_id, display_name, provisional, created_by
) values (
  :'second_student_id', :'school_id', :'second_student_user',
  'STU-SEED-0002', 'Seed Second Student', false, :'teacher_user'
) on conflict (id) do nothing;

insert into public.enrollments (classroom_id, student_id, active) values
  (:'classroom_id', :'second_student_id', true)
on conflict (classroom_id, student_id) do nothing;

insert into public.guardian_links (
  student_id, guardian_id, status, relationship, verified_by,
  verified_at, expires_at
) values (
  :'student_id', :'expired_guardian_user', 'verified', 'parent',
  :'teacher_user', now() - interval '10 days', now() - interval '1 day'
) on conflict (student_id, guardian_id) do nothing;

update public.lesson_sessions
set status='completed', filed_at=coalesce(filed_at, now())
where id=:'session_id';

insert into public.assignments (
  id, classroom_id, title, due_at, state, created_by, published_at
) values
  (:'published_assignment_id', :'classroom_id', 'Published Assignment', now()+interval '2 days', 'published', :'teacher_user', now()),
  (:'alternate_assignment_id', :'classroom_id', 'Alternate Assignment', now()+interval '3 days', 'published', :'teacher_user', now())
on conflict (id) do nothing;

insert into public.submissions (
  id, assignment_id, student_id, submitted_at
) values (
  :'submission_id', :'published_assignment_id', :'student_id', now()
) on conflict (id) do nothing;

insert into public.assessment_questions (
  assessment_id, position, prompt, preferred_answer, maximum_score
) values (
  :'published_assessment_id', 1, 'Synthetic question?',
  'Sensitive answer key', 10
) on conflict (assessment_id, position) do nothing;

insert into public.wellbeing_events (
  id, student_id, classroom_id, kind, title, context, visibility, created_by
) values
  (:'guardian_wellbeing_id', :'student_id', :'classroom_id', 'note', 'Guardian shared', 'Synthetic context', 'guardian_shared', :'teacher_user'),
  (:'shared_wellbeing_id', :'student_id', :'classroom_id', 'note', 'Student and guardian shared', 'Synthetic context', 'student_guardian_shared', :'teacher_user'),
  (:'restricted_wellbeing_id', :'student_id', :'classroom_id', 'concern', 'Restricted', 'Synthetic context', 'safeguarding_restricted', :'teacher_user')
on conflict (id) do nothing;

insert into public.notifications (id, school_id, user_id, kind, title, body) values
  ('abd70000-0000-4000-8000-000000000111', :'school_id', :'student_user', 'test', 'Unread one', 'Synthetic'),
  ('abd70000-0000-4000-8000-000000000112', :'school_id', :'student_user', 'test', 'Unread two', 'Synthetic'),
  ('abd70000-0000-4000-8000-000000000113', :'school_id', :'guardian_user', 'test', 'Guardian unread', 'Synthetic')
on conflict (id) do nothing;

insert into public.file_objects (
  id, school_id, bucket, object_key, uploader_id, size_bytes,
  declared_media_type, detected_media_type, sha256, scan_state, scanned_at
) values
  ('abd80000-0000-4000-8000-000000000114', :'school_id', 'private-school-files', 'synthetic/clean.pdf', :'teacher_user', 128, 'application/pdf', 'application/pdf', repeat('a',64), 'clean', now()),
  ('abd80000-0000-4000-8000-000000000115', :'school_id', 'private-school-files', 'synthetic/dirty.pdf', :'teacher_user', 128, 'application/pdf', 'application/pdf', repeat('b',64), 'quarantined', null)
on conflict (id) do nothing;

insert into public.resources (
  id, school_id, title, resource_type, state, created_by
) values
  (:'clean_resource_id', :'school_id', 'Clean resource', 'document', 'published', :'teacher_user'),
  (:'dirty_resource_id', :'school_id', 'Quarantined resource', 'document', 'published', :'teacher_user')
on conflict (id) do nothing;

insert into public.resource_versions (
  id, school_id, resource_id, version, file_object_id, content_hash, created_by
) values
  ('abd90000-0000-4000-8000-000000000116', :'school_id', :'clean_resource_id', 1, 'abd80000-0000-4000-8000-000000000114', repeat('a',64), :'teacher_user'),
  ('abd90000-0000-4000-8000-000000000117', :'school_id', :'dirty_resource_id', 1, 'abd80000-0000-4000-8000-000000000115', repeat('b',64), :'teacher_user')
on conflict (id) do nothing;

insert into public.resource_publications (
  id, school_id, resource_version_id, classroom_id, audience, state,
  published_at, created_by
) values
  ('abda0000-0000-4000-8000-000000000118', :'school_id', 'abd90000-0000-4000-8000-000000000116', :'classroom_id', 'both', 'published', now(), :'teacher_user'),
  ('abda0000-0000-4000-8000-000000000119', :'school_id', 'abd90000-0000-4000-8000-000000000117', :'classroom_id', 'both', 'published', now(), :'teacher_user')
on conflict (id) do nothing;

\if :{?auth031_fixture_only}
\else
\ir db021_access.sql
\endif
