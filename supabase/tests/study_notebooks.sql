-- Study notebooks (202610070002). Transactional fixtures: everything rolls
-- back.
begin;
\set auth031_fixture_only true
\ir rls_access_seed.sql
\unset auth031_fixture_only
create extension if not exists pgtap with schema extensions;
set local search_path=public,extensions;
select plan(36);

\set other_student_user 'a0550000-0000-4000-8000-0000000000a1'
\set pdf_file 'a0550000-0000-4000-8000-0000000000f1'
\set png_file 'a0550000-0000-4000-8000-0000000000f2'

insert into auth.users (id, email, encrypted_password, aud, role, email_confirmed_at,
  created_at, updated_at, instance_id, confirmation_token, recovery_token, email_change,
  email_change_token_new, email_change_token_current, phone_change_token,
  raw_app_meta_data, raw_user_meta_data)
values (:'other_student_user', 'nb.other@synthetic.studafy.test', 'x', 'authenticated', 'authenticated',
  now(), now(), now(), '00000000-0000-0000-0000-000000000000', '', '', '', '', '', '', '{}', '{}');
insert into public.memberships (school_id, user_id, role, active)
values (:'school_id', :'other_student_user', 'student', true);

select set_config('studafy.school_id', :'school_id', true);
select set_config('studafy.request_id', 'study-notebooks-test', true);

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
create function pg_temp.nb(actor uuid, op text, input jsonb) returns jsonb
language plpgsql as $$
begin
  perform set_config('request.jwt.claim.sub', actor::text, true);
  return private.api055_study_notebooks(op, input);
end $$;
create function pg_temp.upload(file uuid, media text, name text) returns void
language plpgsql as $$
declare v_session uuid := gen_random_uuid();
begin
  insert into public.file_objects (id, school_id, bucket, object_key, uploader_id, size_bytes,
    declared_media_type, detected_media_type, sha256, stored_sha256, stored_size_bytes,
    scan_state, scanned_at, owner_id, purpose, display_name)
  values (file, current_setting('studafy.school_id')::uuid, 'legacy', 'nb/' || file,
    'aaaa0000-0000-4000-8000-000000000001', 10, media, media,
    encode(extensions.digest(file::text, 'sha256'), 'hex'),
    encode(extensions.digest(file::text, 'sha256'), 'hex'), 10, 'clean', now(),
    'aaaa0000-0000-4000-8000-000000000001', 'lesson_resource', name);
  insert into public.upload_sessions (id, school_id, uploader_id, purpose, expected_size_bytes,
    allowed_media_types, nonce_hash, expires_at, classroom_id)
  values (v_session, current_setting('studafy.school_id')::uuid,
    'aaaa0000-0000-4000-8000-000000000001', 'lesson_resource', 10,
    array[media], encode(extensions.digest('nonce' || file::text, 'sha256'), 'hex'),
    now() + interval '1 hour', 'abcd0000-0000-4000-8000-000000000007');
  insert into public.file_bindings (school_id, file_object_id, upload_session_id)
  values (current_setting('studafy.school_id')::uuid, file, v_session);
end $$;
create function pg_temp.read(file uuid) returns boolean language plpgsql as $$
declare v_doc uuid := (select id from private.ai_material_docs where file_object_id = file);
begin
  update private.ai_material_docs set state = 'processing', worker_id = 'test-worker',
    lease_until = now() + interval '10 minutes' where id = v_doc;
  return private.ai_material_finish('test-worker', v_doc, jsonb_build_object(
    'outcome', 'ready', 'extractor', 'test',
    'chunks', jsonb_build_array(jsonb_build_object('page', 1, 'body', 'Leaves make food from light.')),
    'detail', '{}'::jsonb, 'usage', '[]'::jsonb));
end $$;

select pg_temp.upload(:'pdf_file', 'application/pdf', 'Leaf.pdf');
select pg_temp.upload(:'png_file', 'image/png', 'Board.png');
create temporary table nbt(name text primary key, value jsonb);
insert into nbt select 'lesson', pg_temp.cmd(:'teacher_user', 'createResource', null, jsonb_build_object(
  'schoolId', :'school_id', 'classroomId', :'classroom_id', 'title', 'Photosynthesis',
  'resourceType', 'lesson_note', 'body', 'Plants make food from light.', 'audience', 'both',
  'attachmentFileIds', jsonb_build_array(:'pdf_file', :'png_file')));
select (value->'response'->>'id')::uuid as lesson_id from nbt where name = 'lesson' \gset
select is((pg_temp.cmd(:'teacher_user', 'publishResource', :'lesson_id', jsonb_build_object(
  'expectedVersion', (select version from public.resources where id = :'lesson_id'))))->>'outcome', 'ok',
  'the lesson is published to the class');

-- ---------------------------------------------------------------------------
-- Creating
-- ---------------------------------------------------------------------------
delete from private.study_plan_grants where user_id = :'student_user';
select is(pg_temp.nb(:'student_user', 'create', jsonb_build_object('classroomId', :'classroom_id',
  'resourceId', :'lesson_id', 'sourceIds', '[]'::jsonb))->>'outcome', 'plan_required',
  'a notebook needs Plus or Max');
insert into private.study_plan_grants (user_id, plan, reason, ends_at)
values (:'student_user', 'plus', 'test', now() + interval '1 day'),
  (:'other_student_user', 'plus', 'test', now() + interval '1 day');

select is(pg_temp.nb(:'student_user', 'create', jsonb_build_object('classroomId', :'classroom_id',
  'resourceId', :'lesson_id', 'sourceIds', jsonb_build_array(:'pdf_file')))->>'outcome', 'material_processing',
  'a file still being read cannot be made into a notebook yet');
select ok(pg_temp.read(:'pdf_file'), 'the pdf is read');
select is(pg_temp.nb(:'student_user', 'create', jsonb_build_object('classroomId', :'classroom_id',
  'resourceId', :'lesson_id', 'sourceIds', '[]'::jsonb))->>'outcome', 'material_processing',
  'nor the whole lesson while one of its files is');
select is(pg_temp.nb(:'student_user', 'create', jsonb_build_object('classroomId', :'classroom_id',
  'resourceId', :'lesson_id', 'sourceIds', jsonb_build_array(gen_random_uuid())))->>'outcome', 'invalid',
  'a source that is not part of the lesson is refused');
select is(pg_temp.nb(:'student_user', 'create', jsonb_build_object('classroomId', gen_random_uuid(),
  'resourceId', :'lesson_id', 'sourceIds', '[]'::jsonb))->>'outcome', 'not_found',
  'the lesson must be in the class named');
select is(pg_temp.nb(:'other_student_user', 'create', jsonb_build_object('classroomId', :'classroom_id',
  'resourceId', :'lesson_id', 'sourceIds', '[]'::jsonb))->>'outcome', 'not_found',
  'a student outside the class cannot make one');

insert into nbt select 'created', pg_temp.nb(:'student_user', 'create', jsonb_build_object(
  'classroomId', :'classroom_id', 'resourceId', :'lesson_id', 'sourceIds', jsonb_build_array(:'pdf_file')));
select (value->>'notebookId')::uuid as nb_id from nbt where name = 'created' \gset
select is((select value->>'outcome' from nbt where name = 'created'), 'ok', 'a notebook from one file is made');
select is((select value->'summary'->>'status' from nbt where name = 'created'), 'creating',
  'and is being written');
select is((select value->>'lessonTitle' from nbt where name = 'created'), 'Photosynthesis',
  'it is titled after the lesson');
select is((select value->'summary'->>'sourceCount' from nbt where name = 'created'), '1',
  'and knows it reads one source');
select is((select owner_id from public.study_notebooks where id = :'nb_id'), :'student_user'::uuid,
  'the notebook belongs to the student who made it');

-- ---------------------------------------------------------------------------
-- Writing it
-- ---------------------------------------------------------------------------
select is(pg_temp.nb(:'student_user', 'finish', jsonb_build_object('id', :'nb_id', 'generation', 99,
  'content', '{"overview": "late"}'::jsonb))->>'outcome', 'stale',
  'an answer to a request that is not the latest is ignored');
select is(pg_temp.nb(:'student_user', 'finish', jsonb_build_object('id', :'nb_id', 'generation', 1,
  'model', 'test-model', 'content', jsonb_build_object('overview', 'Leaves make food.',
    'objectives', '[]'::jsonb, 'keyTerms', '[]'::jsonb, 'sections', '[]'::jsonb,
    'examples', '[]'::jsonb, 'facts', '[]'::jsonb, 'mistakes', '[]'::jsonb,
    'summary', '[]'::jsonb)))->'summary'->>'status', 'ready', 'the AI part is saved');
select is(pg_temp.nb(:'student_user', 'get', jsonb_build_object('id', :'nb_id'))->'notebook'->'content'->>'overview',
  'Leaves make food.', 'and read back');
select is(pg_temp.nb(:'student_user', 'get', jsonb_build_object('id', :'nb_id'))->'notebook'->'summary'->>'updateAvailable',
  'false', 'it is up to date with its file');
select is((select count(*) from jsonb_array_elements(pg_temp.nb(:'student_user', 'get',
  jsonb_build_object('id', :'nb_id'))->'notebook'->'sources') s where (s->>'chosen')::boolean), 1::bigint,
  'only the chosen file is marked as part of it');
select is(pg_temp.nb(:'other_student_user', 'get', jsonb_build_object('id', :'nb_id'))->>'outcome', 'not_found',
  'nobody else can open it');
select is(pg_temp.nb(:'teacher_user', 'get', jsonb_build_object('id', :'nb_id'))->>'outcome', 'not_found',
  'not even the teacher');

-- ---------------------------------------------------------------------------
-- The student's own part
-- ---------------------------------------------------------------------------
select is(pg_temp.nb(:'student_user', 'personal', jsonb_build_object('id', :'nb_id', 'expectedVersion', 1,
  'personal', '{"notes":[{"id":"n1","sectionKey":"overview","text":"Remember this"}],"sections":[],"bookmarks":["overview"],"highlights":[]}'::jsonb))
  ->'notebook'->>'personalVersion', '2', 'a note is saved');
select is(pg_temp.nb(:'student_user', 'personal', jsonb_build_object('id', :'nb_id', 'expectedVersion', 1,
  'personal', '{"notes":[],"sections":[],"bookmarks":[],"highlights":[]}'::jsonb))->>'outcome', 'version_conflict',
  'a save made on an older copy does not overwrite a newer one');
select is(pg_temp.nb(:'student_user', 'personal', jsonb_build_object('id', :'nb_id', 'expectedVersion', 2,
  'personal', '{"notes":"x"}'::jsonb))->>'outcome', 'invalid', 'a malformed save is refused');
select is(pg_temp.nb(:'student_user', 'settings', jsonb_build_object('id', :'nb_id', 'title', 'My leaves',
  'subtitle', 'Unit 3', 'color', 'teal', 'icon', 'science', 'pageStyle', 'grid',
  'headings', '[{"key":"overview","title":"The big picture"}]'::jsonb))->'summary'->>'pageStyle', 'grid',
  'the cover and pages can be changed');
select is(pg_temp.nb(:'student_user', 'settings', jsonb_build_object('id', :'nb_id', 'title', 'x',
  'color', 'gold', 'pageStyle', 'grid'))->>'outcome', 'invalid', 'only known colours');

-- ---------------------------------------------------------------------------
-- Updating
-- ---------------------------------------------------------------------------
update private.ai_material_docs set processed_at = now() + interval '1 minute'
where file_object_id = :'pdf_file';
select is(pg_temp.nb(:'student_user', 'list', jsonb_build_object('classroomId', :'classroom_id'))->'items'->0->>'updateAvailable',
  'true', 'a file read again since offers an update');
select is(pg_temp.nb(:'student_user', 'regenerate', jsonb_build_object('id', :'nb_id'))->'summary'->>'status',
  'creating', 'updating writes it again');
select is(pg_temp.nb(:'student_user', 'regenerate', jsonb_build_object('id', :'nb_id'))->>'outcome',
  'in_progress', 'but not twice at once');
select is(pg_temp.nb(:'student_user', 'fail', jsonb_build_object('id', :'nb_id', 'generation', 2,
  'reason', 'provider_unavailable'))->>'outcome', 'ok', 'a failed update is recorded');
select is((pg_temp.nb(:'student_user', 'get', jsonb_build_object('id', :'nb_id'))->'notebook'->'personal'->'notes'->0->>'text'),
  'Remember this', 'and the student''s notes are untouched');
select is((pg_temp.nb(:'student_user', 'get', jsonb_build_object('id', :'nb_id'))->'notebook'->'content'->>'overview'),
  'Leaves make food.', 'as is the last good AI part');

-- ---------------------------------------------------------------------------
-- Practice from it
-- ---------------------------------------------------------------------------
select is(pg_temp.nb(:'student_user', 'set', jsonb_build_object('id', :'nb_id', 'kind', 'quiz',
  'sectionKeys', '[]'::jsonb))->>'outcome', 'plan_required', 'quizzes from a notebook are on Max');
update private.study_plan_grants set plan = 'max' where user_id = :'student_user';
select is(pg_temp.nb(:'student_user', 'saveSet', jsonb_build_object('id', :'nb_id', 'kind', 'quiz',
  'sectionKeys', '["b","a","a"]'::jsonb, 'contentVersion', 1, 'model', 'test-model',
  'items', '[{"q":1}]'::jsonb))->'set'->'sectionKeys', '["a", "b"]'::jsonb, 'a quiz is kept against its sections');
select isnt(pg_temp.nb(:'student_user', 'set', jsonb_build_object('id', :'nb_id', 'kind', 'quiz',
  'sectionKeys', '["a","b"]'::jsonb))->'existing', 'null'::jsonb, 'and opening it again needs no new one');
select is(pg_temp.nb(:'student_user', 'delete', '{}'::jsonb || jsonb_build_object('id', :'nb_id'))->>'deleted',
  'true', 'the student can delete the notebook');
select is(jsonb_array_length(pg_temp.nb(:'student_user', 'list', jsonb_build_object('classroomId', :'classroom_id'))->'items'),
  0, 'and it is gone from the list');

select * from finish();
rollback;
