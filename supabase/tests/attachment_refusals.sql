-- A refused attachment or link says which one and why (202610150010,
-- launch plan 2.8). Every command that binds files or links through
-- private.coursework_attach_files or private.content_links_attach answers
-- {"outcome": "attachment_refused", "rows": [{path, reason}]}, keeps
-- nothing, and still answers 'forbidden' for a file the caller may not use.
-- Transactional fixtures: everything rolls back.
begin;
\set auth031_fixture_only true
\ir rls_access_seed.sql
\unset auth031_fixture_only
create extension if not exists pgtap with schema extensions;
set local search_path=public,extensions;
select plan(30);

\set other_teacher 'a2800000-0000-4000-8000-0000000000a1'
\set clean_file 'a2800000-0000-4000-8000-0000000000f1'
\set refused_file 'a2800000-0000-4000-8000-0000000000f2'
\set deleted_file 'a2800000-0000-4000-8000-0000000000f3'
\set homework_file 'a2800000-0000-4000-8000-0000000000f4'
\set foreign_refused 'a2800000-0000-4000-8000-0000000000f5'
\set foreign_clean 'a2800000-0000-4000-8000-0000000000f6'
\set second_clean 'a2800000-0000-4000-8000-0000000000f7'
\set question_refused 'a2800000-0000-4000-8000-0000000000f8'
\set scan_refused 'a2800000-0000-4000-8000-0000000000f9'
\set missing_file 'a2800000-0000-4000-8000-0000000000fa'

-- Another teacher in the same school, who teaches no class here.
insert into auth.users (id, email, encrypted_password, aud, role, email_confirmed_at,
  created_at, updated_at, instance_id, confirmation_token, recovery_token, email_change,
  email_change_token_new, email_change_token_current, phone_change_token,
  raw_app_meta_data, raw_user_meta_data)
values (:'other_teacher', 'ar.teacher2@synthetic.studafy.test', 'x', 'authenticated', 'authenticated',
  now(), now(), now(), '00000000-0000-0000-0000-000000000000', '', '', '', '', '', '', '{}', '{}');
insert into public.memberships (school_id, user_id, role, active)
values (:'school_id', :'other_teacher', 'teacher', true);

select set_config('studafy.school_id', :'school_id', true);
select set_config('studafy.request_id', 'attachment-refusals-test', true);

create function pg_temp.cmd(actor uuid, op text, resource uuid, body jsonb) returns jsonb
language plpgsql as $$
declare r jsonb;
begin
  perform set_config('request.jwt.claim.sub', actor::text, true);
  r := private.api_idempotency_reserve(current_setting('studafy.school_id')::uuid,
    op, gen_random_uuid()::text,
    encode(extensions.digest(gen_random_uuid()::text, 'sha256'), 'hex'), 3600, 60);
  return private.api041_command(op, resource,
    jsonb_build_object('responseStatus', 201, 'body', body),
    (r->>'id')::uuid, (r->>'generation')::bigint);
end $$;
create function pg_temp.upload(file uuid, owner uuid, purpose text, class uuid, state text default 'clean')
returns void language plpgsql as $$
declare v_session uuid := gen_random_uuid();
begin
  insert into public.file_objects (id, school_id, bucket, object_key, uploader_id, size_bytes,
    declared_media_type, sha256, scan_state, scanned_at, owner_id, purpose, display_name, deleted_at)
  values (file, current_setting('studafy.school_id')::uuid, 'legacy', 'ar/' || file, owner, 10,
    'application/pdf', encode(extensions.digest(file::text, 'sha256'), 'hex'),
    (case when state = 'gone' then 'clean' else state end)::public.file_scan_state, now(), owner,
    purpose::public.file_purpose, 'File.pdf', case when state = 'gone' then now() end);
  insert into public.upload_sessions (id, school_id, uploader_id, purpose, expected_size_bytes,
    allowed_media_types, nonce_hash, expires_at, classroom_id)
  values (v_session, current_setting('studafy.school_id')::uuid, owner, purpose::public.file_purpose, 10,
    array['application/pdf'], encode(extensions.digest('nonce' || file::text, 'sha256'), 'hex'),
    now() + interval '1 hour', class);
  insert into public.file_bindings (school_id, file_object_id, upload_session_id)
  values (current_setting('studafy.school_id')::uuid, file, v_session);
end $$;
-- A lesson body with the given files and links.
create function pg_temp.lesson(files jsonb, links jsonb default '[]') returns jsonb
language sql as $$
  select jsonb_build_object('schoolId', current_setting('studafy.school_id'),
    'classroomId', 'abcd0000-0000-4000-8000-000000000007', 'title', 'Cells',
    'resourceType', 'lesson_note', 'body', 'Notes', 'audience', 'both',
    'attachmentFileIds', files, 'links', links);
$$;
create function pg_temp.lessons() returns bigint language sql as $$
  select count(*) from public.resources r
  where r.school_id = current_setting('studafy.school_id')::uuid and r.title = 'Cells';
$$;

select pg_temp.upload(:'clean_file', :'teacher_user', 'lesson_resource', :'classroom_id');
select pg_temp.upload(:'second_clean', :'teacher_user', 'lesson_resource', :'classroom_id');
select pg_temp.upload(:'refused_file', :'teacher_user', 'lesson_resource', :'classroom_id', 'rejected');
select pg_temp.upload(:'deleted_file', :'teacher_user', 'lesson_resource', :'classroom_id', 'gone');
select pg_temp.upload(:'homework_file', :'teacher_user', 'assignment_material', :'classroom_id');
select pg_temp.upload(:'question_refused', :'teacher_user', 'assignment_material', :'classroom_id', 'rejected');
select pg_temp.upload(:'scan_refused', :'teacher_user', 'paper_scan', :'classroom_id', 'rejected');
select pg_temp.upload(:'foreign_refused', :'other_teacher', 'lesson_resource', :'classroom_id', 'rejected');
select pg_temp.upload(:'foreign_clean', :'other_teacher', 'lesson_resource', :'classroom_id');

create temporary table ar(name text primary key, value jsonb);

-- ---------------------------------------------------------------------------
-- A new lesson: the case seen on the test copy
-- ---------------------------------------------------------------------------

insert into ar select 'scan', pg_temp.cmd(:'teacher_user', 'createResource', null,
  pg_temp.lesson(jsonb_build_array(:'clean_file', :'refused_file')));
select is((select value->>'outcome' from ar where name = 'scan'), 'attachment_refused',
  'a lesson with a file the scan refused is refused as such, not as a bare invalid request');
select is((select value->'rows' from ar where name = 'scan'),
  '[{"path": "attachmentFileIds.1", "reason": "file_refused"}]'::jsonb,
  'it names the refused file by its place in the request, and why');
select is(pg_temp.lessons(), 0::bigint, 'and nothing was saved');
select is((select count(*) from public.file_bindings where file_object_id = :'clean_file'
  and resource_version_id is not null), 0::bigint, 'not even the file that was fine');

select is(pg_temp.cmd(:'teacher_user', 'createResource', null,
  pg_temp.lesson(jsonb_build_array(:'missing_file')))->'rows',
  '[{"path": "attachmentFileIds.0", "reason": "file_not_found"}]'::jsonb,
  'a file that does not exist is not found');
select is(pg_temp.cmd(:'teacher_user', 'createResource', null,
  pg_temp.lesson(jsonb_build_array(:'clean_file', :'deleted_file')))->'rows',
  '[{"path": "attachmentFileIds.1", "reason": "file_not_found"}]'::jsonb,
  'nor is one that was deleted');
select is(pg_temp.cmd(:'teacher_user', 'createResource', null,
  pg_temp.lesson(jsonb_build_array(:'homework_file')))->'rows',
  '[{"path": "attachmentFileIds.0", "reason": "file_wrong_purpose"}]'::jsonb,
  'a file uploaded for homework is the wrong kind for a lesson');
select is(pg_temp.cmd(:'teacher_user', 'createResource', null,
  pg_temp.lesson(jsonb_build_array(:'clean_file', :'second_clean', :'clean_file')))->'rows',
  '[{"path": "attachmentFileIds.2", "reason": "duplicate"}]'::jsonb,
  'the same file twice names the second');
select is(pg_temp.cmd(:'teacher_user', 'createResource', null,
  pg_temp.lesson('[]', jsonb_build_array(
    jsonb_build_object('title', 'Fine', 'url', 'https://video.example.org/cells'),
    jsonb_build_object('title', 'Creds', 'url', 'https://user:pw@evil.example.com/'))))->'rows',
  '[{"path": "links.1", "reason": "link_not_allowed"}]'::jsonb,
  'a link that may not be added is named before anything is created');

-- Someone else's files: what is refused stays what it was.
select is(pg_temp.cmd(:'teacher_user', 'createResource', null,
  pg_temp.lesson(jsonb_build_array(:'foreign_refused')))->'rows',
  '[{"path": "attachmentFileIds.0", "reason": "file_not_found"}]'::jsonb,
  'another teacher''s refused file is not found - never why it was refused');
select is(pg_temp.cmd(:'teacher_user', 'createResource', null,
  pg_temp.lesson(jsonb_build_array(:'foreign_clean')))->>'outcome',
  'forbidden', 'another teacher''s file is still forbidden');
select is(pg_temp.cmd(:'teacher_user', 'createResource', null,
  pg_temp.lesson(jsonb_build_array(:'foreign_clean')))->'rows', null,
  'and a forbidden answer names nothing');

insert into ar select 'lesson', pg_temp.cmd(:'teacher_user', 'createResource', null,
  pg_temp.lesson(jsonb_build_array(:'clean_file')));
select is((select value->>'outcome' from ar where name = 'lesson'), 'ok',
  'with the refused file taken off, the lesson is saved');
select (value->'response'->>'id')::uuid as lesson_id from ar where name = 'lesson' \gset
select is(pg_temp.cmd(:'teacher_user', 'createResource', null,
  pg_temp.lesson(jsonb_build_array(:'clean_file')))->'rows',
  '[{"path": "attachmentFileIds.0", "reason": "file_already_attached"}]'::jsonb,
  'a file already on a lesson cannot go on another');

-- ---------------------------------------------------------------------------
-- Editing the lesson
-- ---------------------------------------------------------------------------

select set_config('studafy.lesson_version',
  (select version::text from public.resources where id = :'lesson_id'), true);
select is(pg_temp.cmd(:'teacher_user', 'editResource', :'lesson_id', jsonb_build_object(
  'expectedVersion', current_setting('studafy.lesson_version')::bigint, 'body', 'More notes',
  'attachmentFileIds', jsonb_build_array(:'second_clean', :'refused_file'))),
  '{"outcome": "attachment_refused", "rows": [{"path": "attachmentFileIds.1", "reason": "file_refused"}]}'::jsonb,
  'an edit adding a refused file names it');
select is((select version::text from public.resources where id = :'lesson_id'),
  current_setting('studafy.lesson_version'), 'and the lesson is unchanged');
select is(pg_temp.cmd(:'teacher_user', 'editResource', :'lesson_id', jsonb_build_object(
  'expectedVersion', current_setting('studafy.lesson_version')::bigint,
  'links', jsonb_build_array(jsonb_build_object('title', 'Bad', 'url', 'https://nodot/'))))->'rows',
  '[{"path": "links.0", "reason": "link_not_allowed"}]'::jsonb,
  'an edit adding a bad link names it');

-- ---------------------------------------------------------------------------
-- Homework, assessments and paper grades
-- ---------------------------------------------------------------------------

select is(pg_temp.cmd(:'teacher_user', 'createAssignment', null, jsonb_build_object(
  'classroomId', :'classroom_id', 'title', 'Bad link', 'instructions', null,
  'dueAt', now() + interval '1 day', 'closesAt', null,
  'links', jsonb_build_array(jsonb_build_object('title', ' ', 'url', 'https://ok.example.org/'))))->'rows',
  '[{"path": "links.0", "reason": "link_title_invalid"}]'::jsonb,
  'homework with an untitled link names it');

insert into ar select 'homework', pg_temp.cmd(:'teacher_user', 'createAssignment', null, jsonb_build_object(
  'classroomId', :'classroom_id', 'title', 'Reading', 'instructions', null,
  'dueAt', now() + interval '1 day', 'closesAt', null));
select (value->'response'->>'id')::uuid as homework_id from ar where name = 'homework' \gset
select is(pg_temp.cmd(:'teacher_user', 'updateAssignmentMaterials', :'homework_id', jsonb_build_object(
  'expectedVersion', (select version from public.assignments where id = :'homework_id'),
  'detachFileIds', '[]'::jsonb,
  'links', jsonb_build_array(jsonb_build_object('title', 'x', 'url', 'https://a b.example.org/'))))->'rows',
  '[{"path": "links.0", "reason": "link_not_allowed"}]'::jsonb,
  'so does changing its materials');
select is((select count(*) from public.content_links where assignment_id = :'homework_id'), 0::bigint,
  'and no link was kept');

select is(pg_temp.cmd(:'teacher_user', 'createAssessment', null, jsonb_build_object(
  'classroomId', :'classroom_id', 'title', 'Quiz with a refused diagram', 'category', 'quiz',
  'maximumScore', 2, 'scheduledAt', null, 'delivery', 'online', 'questions', jsonb_build_array(
    jsonb_build_object('position', 1, 'kind', 'true_false', 'prompt', 'Sky is blue?',
      'maximumScore', 1, 'correctChoice', true, 'preferredAnswer', null),
    jsonb_build_object('position', 2, 'kind', 'true_false', 'prompt', 'Grass is red?',
      'maximumScore', 1, 'correctChoice', false, 'preferredAnswer', null,
      'attachmentFileIds', jsonb_build_array(:'question_refused'))))),
  '{"outcome": "attachment_refused", "rows": [{"path": "questions.1.attachmentFileIds.0", "reason": "file_refused"}]}'::jsonb,
  'a question''s refused file is named under its question');
select is((select count(*) from public.assessments where title = 'Quiz with a refused diagram'), 0::bigint,
  'and the quiz was not created');

insert into ar select 'quiz', pg_temp.cmd(:'teacher_user', 'createAssessment', null, jsonb_build_object(
  'classroomId', :'classroom_id', 'title', 'Draft quiz', 'category', 'quiz',
  'maximumScore', 1, 'scheduledAt', null, 'delivery', 'online', 'questions', jsonb_build_array(
    jsonb_build_object('position', 1, 'kind', 'true_false', 'prompt', 'Sky is blue?',
      'maximumScore', 1, 'correctChoice', true, 'preferredAnswer', null))));
select (value->'response'->>'id')::uuid as quiz_id from ar where name = 'quiz' \gset
select is(pg_temp.cmd(:'teacher_user', 'updateAssessmentDesign', :'quiz_id', jsonb_build_object(
  'expectedVersion', (select version from public.assessments where id = :'quiz_id'),
  'questions', jsonb_build_array(
    jsonb_build_object('id', (select id from public.assessment_questions where assessment_id = :'quiz_id'),
      'position', 1, 'kind', 'true_false', 'prompt', 'Sky is blue?',
      'maximumScore', 1, 'correctChoice', true, 'preferredAnswer', null,
      'links', jsonb_build_array(jsonb_build_object('title', 'Ok', 'url', 'https://ok.example.org/'),
        jsonb_build_object('title', 'Bad', 'url', 'ftp://files.example.org/'))))))->'rows',
  '[{"path": "questions.0.links.1", "reason": "link_not_allowed"}]'::jsonb,
  'editing a question names its refused link');
select is(pg_temp.cmd(:'teacher_user', 'updateAssessmentDesign', :'quiz_id', jsonb_build_object(
  'expectedVersion', (select version from public.assessments where id = :'quiz_id'),
  'attachmentFileIds', jsonb_build_array(:'homework_file', :'question_refused')))->'rows',
  '[{"path": "attachmentFileIds.1", "reason": "file_refused"}]'::jsonb,
  'and the quiz''s own material');
select is((select count(*) from public.file_bindings where assessment_id = :'quiz_id'), 0::bigint,
  'keeping none of it');

insert into ar select 'paper', pg_temp.cmd(:'teacher_user', 'createAssessment', null, jsonb_build_object(
  'classroomId', :'classroom_id', 'title', 'Paper test', 'category', 'test', 'maximumScore', 20,
  'scheduledAt', null, 'delivery', 'paper', 'questions', '[]'::jsonb));
select (value->'response'->>'id')::uuid as paper_id from ar where name = 'paper' \gset
select is(pg_temp.cmd(:'teacher_user', 'updateGradeAttachments', :'paper_id', jsonb_build_object(
  'studentId', :'student_id', 'attachmentFileIds', jsonb_build_array(:'scan_refused'))),
  '{"outcome": "attachment_refused", "rows": [{"path": "attachmentFileIds.0", "reason": "file_refused"}]}'::jsonb,
  'a refused marked sheet is named');
select is((select count(*) from public.grade_results where assessment_id = :'paper_id'), 0::bigint,
  'and no draft grade was left behind for it');

-- ---------------------------------------------------------------------------
-- The helpers are reached only through the dispatcher
-- ---------------------------------------------------------------------------

select ok(not has_function_privilege('authenticated', 'private.attachment_refuse(jsonb)', 'execute')
  and not has_function_privilege('studafy_api_runtime', 'private.attachment_refuse(jsonb)', 'execute'),
  'the refusal helper is not callable by clients or the API runtime');
select ok(not has_function_privilege('authenticated', 'private.content_links_refusals(jsonb,text)', 'execute')
  and not has_function_privilege('studafy_api_runtime', 'private.content_links_refusals(jsonb,text)', 'execute'),
  'nor is the link check');
select ok(has_function_privilege('studafy_api_runtime',
  'private.api041_command(text,uuid,jsonb,uuid,bigint)', 'execute'),
  'the dispatcher keeps its grant');

select * from finish();
rollback;
