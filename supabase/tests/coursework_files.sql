-- Editing lessons and set-work material, and who may download what
-- (202609300004). Transactional fixtures: everything below rolls back.
begin;
\set auth031_fixture_only true
\ir rls_access_seed.sql
\unset auth031_fixture_only
create extension if not exists pgtap with schema extensions;
set local search_path=public,extensions;
select plan(30);

\set lesson_id 'a0440000-0000-4000-8000-000000000001'
\set lesson_v1 'a0440000-0000-4000-8000-000000000002'
\set lesson_file 'a0440000-0000-4000-8000-000000000003'
\set new_file 'a0440000-0000-4000-8000-000000000004'
\set upload_id 'a0440000-0000-4000-8000-000000000005'
\set work_id 'a0440000-0000-4000-8000-000000000006'
\set material_file 'a0440000-0000-4000-8000-000000000007'
\set answer_file 'a0440000-0000-4000-8000-000000000008'
\set other_class 'a0440000-0000-4000-8000-000000000009'
\set other_teacher 'aaaa0000-0000-4000-8000-0000000000c1'

insert into auth.users (id, email, encrypted_password, aud, role, email_confirmed_at,
  created_at, updated_at, instance_id, confirmation_token, recovery_token, email_change,
  email_change_token_new, email_change_token_current, phone_change_token,
  raw_app_meta_data, raw_user_meta_data)
values (:'other_teacher', 'files.other@synthetic.studafy.test', 'x', 'authenticated',
  'authenticated', now(), now(), now(), '00000000-0000-0000-0000-000000000000', '', '', '',
  '', '', '', '{}', '{"full_name":"Other Class Teacher"}');
insert into public.memberships (school_id, user_id, role, active)
values (:'school_id', :'other_teacher', 'teacher', true);
insert into public.classrooms (id, school_id, term_id, name, grade, section, teacher_id)
values (:'other_class', :'school_id', :'term_id', 'Other class', 'G7', 'B', :'other_teacher');
insert into public.classroom_staff (school_id, classroom_id, membership_id, user_id, role)
select :'school_id', :'other_class', m.id, :'other_teacher', 'lead_teacher'
from public.memberships m where m.user_id = :'other_teacher';

insert into public.file_objects (id, school_id, bucket, object_key, uploader_id, size_bytes,
  declared_media_type, sha256, scan_state, scanned_at, owner_id, purpose, display_name) values
  (:'lesson_file', :'school_id', 'legacy', 'files/lesson', :'teacher_user', 10, 'application/pdf',
    repeat('1', 64), 'clean', now(), :'teacher_user', 'lesson_resource', 'Fractions.pdf'),
  (:'new_file', :'school_id', 'legacy', 'files/new', :'teacher_user', 10, 'image/jpeg',
    repeat('2', 64), 'clean', now(), :'teacher_user', 'lesson_resource', 'Fractions board.jpg'),
  (:'material_file', :'school_id', 'legacy', 'files/material', :'teacher_user', 10, 'application/pdf',
    repeat('3', 64), 'clean', now(), :'teacher_user', 'assignment_material', 'Worksheet.pdf'),
  (:'answer_file', :'school_id', 'legacy', 'files/answer', :'student_user', 10, 'image/png',
    repeat('4', 64), 'clean', now(), :'student_user', 'assignment_submission', 'My answer.png');

-- A published lesson with its file.
insert into public.resources (id, school_id, title, resource_type, state, current_version, created_by, version)
values (:'lesson_id', :'school_id', 'Fractions.pdf', 'file', 'published', 1, :'teacher_user', 1);
insert into public.resource_versions (id, school_id, resource_id, version, file_object_id, created_by)
values (:'lesson_v1', :'school_id', :'lesson_id', 1, :'lesson_file', :'teacher_user');
insert into public.resource_publications (school_id, resource_version_id, classroom_id, audience,
  state, published_at, created_by)
values (:'school_id', :'lesson_v1', :'classroom_id', 'both', 'published', now(), :'teacher_user');
insert into public.file_bindings (school_id, file_object_id, resource_version_id)
values (:'school_id', :'lesson_file', :'lesson_v1');
-- Its replacement, uploaded for this class.
insert into public.upload_sessions (id, school_id, uploader_id, purpose, expected_size_bytes,
  allowed_media_types, nonce_hash, expires_at, classroom_id)
values (:'upload_id', :'school_id', :'teacher_user', 'lesson_resource', 10, array['image/jpeg'],
  repeat('n', 64), now() + interval '1 hour', :'classroom_id');
insert into public.file_bindings (school_id, file_object_id, upload_session_id)
values (:'school_id', :'new_file', :'upload_id');

-- Set work with material, and the student's answer to it.
insert into public.assignments (id, school_id, classroom_id, title, due_at, state, created_by, version, published_at)
values (:'work_id', :'school_id', :'classroom_id', 'Worksheet', now() + interval '1 day', 'published',
  :'teacher_user', 1, now());
insert into public.file_bindings (school_id, file_object_id, assignment_id)
values (:'school_id', :'material_file', :'work_id');
insert into public.submissions (school_id, assignment_id, student_id, submitted_at, status)
values (:'school_id', :'work_id', :'student_id', now(), 'submitted');
insert into public.submission_attempts (school_id, submission_id, operation_id, answer_text, submitted_at)
select :'school_id', s.id, gen_random_uuid(), 'See photo', now() from public.submissions s where s.assignment_id = :'work_id';
insert into public.file_bindings (school_id, file_object_id, submission_attempt_id)
select :'school_id', :'answer_file', sa.id from public.submission_attempts sa
join public.submissions s on s.id = sa.submission_id where s.assignment_id = :'work_id';

select set_config('studafy.school_id', :'school_id', true);
select set_config('studafy.request_id', 'coursework-files-test', true);

create function pg_temp.can_download(actor uuid, file uuid) returns boolean language plpgsql as $$
begin
  perform set_config('request.jwt.claim.sub', actor::text, true);
  return coalesce((private.file051_authorize_download(file)->>'allowed')::boolean, false);
end $$;
create function pg_temp.cmd(actor uuid, op text, resource uuid, body jsonb) returns jsonb
language plpgsql as $$
declare r jsonb;
begin
  perform set_config('request.jwt.claim.sub', actor::text, true);
  r := private.api_idempotency_reserve(current_setting('studafy.school_id')::uuid,
    op, gen_random_uuid()::text,
    encode(extensions.digest(gen_random_uuid()::text, 'sha256'), 'hex'), 3600, 60);
  return private.api041_command(op, resource,
    jsonb_build_object('responseStatus', 200, 'body', body),
    (r->>'id')::uuid, (r->>'generation')::bigint);
end $$;
create function pg_temp.lesson_version() returns bigint language sql as
  $$ select version from public.resources where id = 'a0440000-0000-4000-8000-000000000001' $$;

-- Lesson files reach the class and its families.
select is(private.api041_resource_json(:'lesson_id')->'attachments'->0->>'displayName', 'Fractions.pdf',
  'a lesson carries its file, so the app can offer it for download');
select ok(pg_temp.can_download(:'student_user', :'lesson_file'), 'a student downloads the lesson file');
select ok(pg_temp.can_download(:'guardian_user', :'lesson_file'), 'a linked parent downloads it');
select ok(not pg_temp.can_download(:'unverified_guardian', :'lesson_file'),
  'a parent whose link is not verified cannot');
select ok(not pg_temp.can_download(:'other_school_user', :'lesson_file'),
  'a teacher at another school cannot');

-- Editing a lesson keeps it visible.
select is(pg_temp.cmd(:'student_user', 'editResource', :'lesson_id', jsonb_build_object(
  'expectedVersion', pg_temp.lesson_version(), 'title', 'Mine now'))->>'outcome', 'forbidden',
  'a student cannot edit a lesson');
select is(pg_temp.cmd(:'teacher_user', 'editResource', :'lesson_id', jsonb_build_object(
  'expectedVersion', pg_temp.lesson_version(), 'title', 'Fractions (week 3)'))->'response'->>'state',
  'published', 'an edited lesson stays published');
select ok(pg_temp.can_download(:'student_user', :'lesson_file'),
  'the unchanged file is still the student''s to open');
select is(pg_temp.cmd(:'teacher_user', 'editResource', :'lesson_id', jsonb_build_object(
  'expectedVersion', 1, 'title', 'Stale'))->>'outcome', 'version_conflict',
  'an edit over someone else''s edit conflicts');

-- Replacing its file.
select is(pg_temp.cmd(:'teacher_user', 'editResource', :'lesson_id', jsonb_build_object(
  'expectedVersion', pg_temp.lesson_version(), 'replaceFileId', :'new_file'))
  ->'response'->'attachments'->0->>'displayName', 'Fractions board.jpg', 'the teacher replaces the file');
select ok(pg_temp.can_download(:'student_user', :'new_file'), 'the student downloads the new file');
select ok(pg_temp.can_download(:'guardian_user', :'new_file'), 'so does the parent');
select ok(not pg_temp.can_download(:'student_user', :'lesson_file'),
  'the replaced file is no longer offered to the student');
select ok(pg_temp.can_download(:'teacher_user', :'lesson_file'),
  'the school keeps the replaced file, and its staff can still open it');
select is((select deleted_at from public.file_objects where id = :'lesson_file'), null,
  'nothing was deleted');
select is((select count(*) from public.resource_versions where resource_id = :'lesson_id'), 3::bigint,
  'every version of the lesson is kept');
select is(pg_temp.cmd(:'other_teacher', 'editResource', :'lesson_id', jsonb_build_object(
  'expectedVersion', pg_temp.lesson_version(), 'title', 'Not my class'))->>'outcome', 'forbidden',
  'a teacher of another class cannot edit it');

-- Material on set work.
select ok(pg_temp.can_download(:'student_user', :'material_file'), 'a student downloads the worksheet');
select is(pg_temp.cmd(:'student_user', 'updateAssignmentMaterials', :'work_id', jsonb_build_object(
  'expectedVersion', 1, 'detachFileIds', jsonb_build_array(:'material_file'),
  'attachmentFileIds', '[]'::jsonb))->>'outcome', 'forbidden', 'a student cannot change the material');
select is(jsonb_array_length(pg_temp.cmd(:'teacher_user', 'updateAssignmentMaterials', :'work_id',
  jsonb_build_object('expectedVersion', 1, 'detachFileIds', jsonb_build_array(:'material_file'),
    'attachmentFileIds', '[]'::jsonb))->'response'->'attachments'), 0,
  'the teacher takes the worksheet off the work');
select ok(not pg_temp.can_download(:'student_user', :'material_file'),
  'a detached worksheet is no longer the class''s to download');
select ok(not pg_temp.can_download(:'guardian_user', :'material_file'), 'nor a parent''s');
select ok(pg_temp.can_download(:'teacher_user', :'material_file'), 'the class''s teacher still can');
select is((select deleted_at from public.file_objects where id = :'material_file'), null,
  'and the file itself is kept');

-- Handed-in work.
select ok(pg_temp.can_download(:'student_user', :'answer_file'), 'a student downloads their own answer');
select ok(pg_temp.can_download(:'guardian_user', :'answer_file'), 'their linked parent downloads it');
select ok(not pg_temp.can_download(:'unverified_guardian', :'answer_file'),
  'someone else''s parent cannot');
select ok(pg_temp.can_download(:'teacher_user', :'answer_file'), 'the class teacher downloads it to mark');
select ok(not pg_temp.can_download(:'other_teacher', :'answer_file'),
  'a teacher of another class at the same school cannot');
select ok(not pg_temp.can_download(:'other_school_user', :'answer_file'),
  'nor can a teacher at another school');

select * from finish();
rollback;
