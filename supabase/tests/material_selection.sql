-- Exactly the chosen material (202610070003, ADR-0039). Transactional
-- fixtures: everything rolls back.
begin;
\set auth031_fixture_only true
\ir rls_access_seed.sql
\unset auth031_fixture_only
create extension if not exists pgtap with schema extensions;
set local search_path=public,extensions;
select plan(16);

\set pdf_file 'a0560000-0000-4000-8000-0000000000f1'
\set png_file 'a0560000-0000-4000-8000-0000000000f2'

select set_config('studafy.school_id', :'school_id', true);
select set_config('studafy.request_id', 'material-selection-test', true);

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
create function pg_temp.out(actor uuid, op text, input jsonb) returns jsonb
language plpgsql as $$
begin
  perform set_config('request.jwt.claim.sub', actor::text, true);
  return private.api056_material_outputs(op, input);
end $$;
create function pg_temp.upload(file uuid, media text, name text) returns void
language plpgsql as $$
declare v_session uuid := gen_random_uuid();
begin
  insert into public.file_objects (id, school_id, bucket, object_key, uploader_id, size_bytes,
    declared_media_type, detected_media_type, sha256, stored_sha256, stored_size_bytes,
    scan_state, scanned_at, owner_id, purpose, display_name)
  values (file, current_setting('studafy.school_id')::uuid, 'legacy', 'ms/' || file,
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
select pg_temp.read(:'pdf_file');
select pg_temp.read(:'png_file');
create temporary table mst(name text primary key, value jsonb);
insert into mst select 'lesson', pg_temp.cmd(:'teacher_user', 'createResource', null, jsonb_build_object(
  'schoolId', :'school_id', 'classroomId', :'classroom_id', 'title', 'Photosynthesis',
  'resourceType', 'lesson_note', 'body', 'Plants make food from light.', 'audience', 'both',
  'attachmentFileIds', jsonb_build_array(:'pdf_file', :'png_file')));
select (value->'response'->>'id')::uuid as lesson_id from mst where name = 'lesson' \gset
select is((pg_temp.cmd(:'teacher_user', 'publishResource', :'lesson_id', jsonb_build_object(
  'expectedVersion', (select version from public.resources where id = :'lesson_id'))))->>'outcome', 'ok',
  'the lesson is published');
insert into private.study_plan_grants (user_id, plan, reason, ends_at)
values (:'student_user', 'plus', 'test', now() + interval '1 day');

-- ---------------------------------------------------------------------------
-- A notebook keeps exactly what was chosen
-- ---------------------------------------------------------------------------
insert into mst select 'text', pg_temp.nb(:'student_user', 'create', jsonb_build_object(
  'classroomId', :'classroom_id', 'resourceId', :'lesson_id', 'sourceIds', '[]'::jsonb,
  'wholeLesson', false, 'includeText', true));
select is((select value->>'outcome' from mst where name = 'text'), 'ok', 'a notebook of the lesson''s text alone is made');
select is((select whole_lesson from public.study_notebooks where id = (select (value->>'notebookId')::uuid from mst where name = 'text')),
  false, 'and is not the whole lesson');
select is((select count(*) from jsonb_array_elements(pg_temp.nb(:'student_user', 'get', jsonb_build_object(
  'id', (select value->>'notebookId' from mst where name = 'text')))->'notebook'->'sources') s
  where (s->>'chosen')::boolean), 0::bigint, 'none of the lesson''s files is part of it');
select is(pg_temp.nb(:'student_user', 'create', jsonb_build_object(
  'classroomId', :'classroom_id', 'resourceId', :'lesson_id', 'sourceIds', '[]'::jsonb,
  'wholeLesson', false, 'includeText', false))->>'outcome', 'invalid', 'a notebook of nothing is refused');
insert into mst select 'old', pg_temp.nb(:'student_user', 'create', jsonb_build_object(
  'classroomId', :'classroom_id', 'resourceId', :'lesson_id', 'sourceIds', '[]'::jsonb));
select is((select whole_lesson from public.study_notebooks where id = (select (value->>'notebookId')::uuid from mst where name = 'old')),
  true, 'an older app naming no files still means the whole lesson');
insert into mst select 'one', pg_temp.nb(:'student_user', 'create', jsonb_build_object(
  'classroomId', :'classroom_id', 'resourceId', :'lesson_id', 'sourceIds', jsonb_build_array(:'pdf_file'),
  'wholeLesson', false, 'includeText', false));
select is(pg_temp.nb(:'student_user', 'get', jsonb_build_object('id', (select value->>'notebookId' from mst where name = 'one')))
  ->'notebook'->>'includeText', 'false', 'one file without the lesson text keeps the text out');

-- A file read again changes a notebook made from it, not one made without it.
select pg_temp.nb(:'student_user', 'finish', jsonb_build_object('id', value->>'notebookId', 'generation', 1,
  'model', 'm', 'content', '{"overview":"x","objectives":[],"keyTerms":[],"sections":[],"examples":[],"facts":[],"mistakes":[],"summary":[]}'::jsonb))
from mst where name in ('text', 'one');
update private.ai_material_docs set processed_at = now() + interval '1 minute' where file_object_id = :'png_file';
select is(pg_temp.nb(:'student_user', 'get', jsonb_build_object('id', (select value->>'notebookId' from mst where name = 'one')))
  ->'notebook'->'summary'->>'updateAvailable', 'false', 'a change to a file not chosen offers no update');
update private.ai_material_docs set processed_at = now() + interval '2 minutes' where file_object_id = :'pdf_file';
select is(pg_temp.nb(:'student_user', 'get', jsonb_build_object('id', (select value->>'notebookId' from mst where name = 'one')))
  ->'notebook'->'summary'->>'updateAvailable', 'true', 'a change to the chosen file does');

-- ---------------------------------------------------------------------------
-- Results kept per exact selection
-- ---------------------------------------------------------------------------
\set fp '''aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa'''
select is(pg_temp.out(:'student_user', 'get', jsonb_build_object('kind', 'quiz', 'fingerprint', :fp,
  'resourceIds', jsonb_build_array(:'lesson_id')))->>'outcome', 'plan_required', 'a kept quiz is Studafy Max');
select is(pg_temp.out(:'student_user', 'put', jsonb_build_object('kind', 'summary', 'fingerprint', :fp,
  'resourceIds', jsonb_build_array(:'lesson_id'), 'body', '# Notes', 'scope', '{}'::jsonb, 'model', 'm'))
  ->'output'->>'body', '# Notes', 'notes made from a selection are kept');
select is(pg_temp.out(:'student_user', 'get', jsonb_build_object('kind', 'summary', 'fingerprint', :fp,
  'resourceIds', jsonb_build_array(:'lesson_id')))->'output'->>'body', '# Notes', 'and found again for the same selection');
select is(pg_temp.out(:'student_user', 'get', jsonb_build_object('kind', 'summary',
  'fingerprint', 'bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb',
  'resourceIds', jsonb_build_array(:'lesson_id')))->'output', 'null'::jsonb, 'but not for another one');
insert into private.study_plan_grants (user_id, plan, reason, ends_at)
values (:'other_school_user', 'plus', 'test', now() + interval '1 day');
select is(pg_temp.out(:'other_school_user', 'get', jsonb_build_object('kind', 'summary', 'fingerprint', :fp,
  'resourceIds', jsonb_build_array(:'lesson_id')))->>'outcome', 'not_found',
  'someone who cannot see the lesson gets nothing from it');
select is(pg_temp.out(:'student_user', 'put', jsonb_build_object('kind', 'summary', 'fingerprint', 'not-a-hash',
  'resourceIds', jsonb_build_array(:'lesson_id'), 'body', 'x', 'scope', '{}'::jsonb, 'model', 'm'))
  ->>'outcome', 'invalid', 'a malformed fingerprint is refused');
select ok(not has_function_privilege('authenticated', 'private.api056_material_outputs(text, jsonb)', 'execute'),
  'only the API may call it');

select * from finish();
rollback;
