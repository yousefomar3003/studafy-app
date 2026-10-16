-- Grounded study AI and token allowances (202610070001, ADR-0037).
-- Transactional fixtures: everything rolls back.
begin;
\set auth031_fixture_only true
\ir rls_access_seed.sql
\unset auth031_fixture_only
create extension if not exists pgtap with schema extensions;
set local search_path=public,extensions;
select plan(53);

\set other_class 'a0470000-0000-4000-8000-0000000000c1'
\set other_student_user 'a0470000-0000-4000-8000-0000000000a1'
\set other_student 'a0470000-0000-4000-8000-0000000000a2'
\set pdf_file 'a0470000-0000-4000-8000-0000000000f1'
\set scan_file 'a0470000-0000-4000-8000-0000000000f2'
\set exam_file 'a0470000-0000-4000-8000-0000000000f3'
\set parents_file 'a0470000-0000-4000-8000-0000000000f4'

-- A second class in the school, with its own student.
insert into auth.users (id, email, encrypted_password, aud, role, email_confirmed_at,
  created_at, updated_at, instance_id, confirmation_token, recovery_token, email_change,
  email_change_token_new, email_change_token_current, phone_change_token,
  raw_app_meta_data, raw_user_meta_data)
values (:'other_student_user', 'gm.other@synthetic.studafy.test', 'x', 'authenticated', 'authenticated',
  now(), now(), now(), '00000000-0000-0000-0000-000000000000', '', '', '', '', '', '', '{}', '{}');
insert into public.memberships (school_id, user_id, role, active)
values (:'school_id', :'other_student_user', 'student', true);
insert into public.classrooms (id, school_id, term_id, name, grade, section, teacher_id, status)
values (:'other_class', :'school_id', :'term_id', 'Other class', '8', 'B', :'teacher_user', 'active');
insert into public.students (id, school_id, user_id, studafy_id, display_name, provisional, created_by)
values (:'other_student', :'school_id', :'other_student_user', 'STU-GM-0002', 'Other Student', false, :'teacher_user');
insert into public.enrollments (classroom_id, student_id, active) values (:'other_class', :'other_student', true);

select set_config('studafy.school_id', :'school_id', true);
select set_config('studafy.request_id', 'grounded-material-test', true);

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
create function pg_temp.m(actor uuid, op text, input jsonb) returns jsonb
language plpgsql as $$
begin
  perform set_config('request.jwt.claim.sub', actor::text, true);
  return private.api054_ai_material(op, input);
end $$;
create function pg_temp.usage(actor uuid, op text, input jsonb) returns jsonb
language plpgsql as $$
begin
  perform set_config('request.jwt.claim.sub', actor::text, true);
  return private.api047_ai_usage(op, input);
end $$;
create function pg_temp.allowed(actor uuid, action text, resource uuid) returns boolean
language plpgsql as $$
begin
  perform set_config('request.jwt.claim.sub', actor::text, true);
  return (private.authz_authorize(action, resource)->>'allowed')::boolean;
end $$;
create function pg_temp.upload(file uuid, purpose text, media text, name text) returns void
language plpgsql as $$
declare v_session uuid := gen_random_uuid();
begin
  insert into public.file_objects (id, school_id, bucket, object_key, uploader_id, size_bytes,
    declared_media_type, detected_media_type, sha256, stored_sha256, stored_size_bytes,
    scan_state, scanned_at, owner_id, purpose, display_name)
  values (file, current_setting('studafy.school_id')::uuid, 'legacy', 'gm/' || file,
    'aaaa0000-0000-4000-8000-000000000001', 10, media, media,
    encode(extensions.digest(file::text, 'sha256'), 'hex'),
    encode(extensions.digest(file::text, 'sha256'), 'hex'), 10, 'clean', now(),
    'aaaa0000-0000-4000-8000-000000000001', purpose::public.file_purpose, name);
  insert into public.upload_sessions (id, school_id, uploader_id, purpose, expected_size_bytes,
    allowed_media_types, nonce_hash, expires_at, classroom_id)
  values (v_session, current_setting('studafy.school_id')::uuid,
    'aaaa0000-0000-4000-8000-000000000001', purpose::public.file_purpose, 10,
    array[media], encode(extensions.digest('nonce' || file::text, 'sha256'), 'hex'),
    now() + interval '1 hour', 'abcd0000-0000-4000-8000-000000000007');
  insert into public.file_bindings (school_id, file_object_id, upload_session_id)
  values (current_setting('studafy.school_id')::uuid, file, v_session);
end $$;
-- The worker finishing one document with these passages.
create function pg_temp.read(doc uuid, chunks jsonb) returns boolean language plpgsql as $$
begin
  update private.ai_material_docs set state = 'processing', worker_id = 'test-worker',
    lease_until = now() + interval '10 minutes' where id = doc;
  return private.ai_material_finish('test-worker', doc, jsonb_build_object(
    'outcome', 'ready', 'extractor', 'test', 'chunks', chunks,
    'detail', jsonb_build_object('pages', 3),
    'usage', jsonb_build_array(jsonb_build_object('kind', 'ocr', 'pages', 1,
      'inputTokens', 900, 'outputTokens', 80, 'costMicroUsd', 173, 'model', 'Qwen/Qwen3.5-9B'))));
end $$;

-- ---------------------------------------------------------------------------
-- What is read
-- ---------------------------------------------------------------------------
select pg_temp.upload(:'pdf_file', 'lesson_resource', 'application/pdf', 'Leaf.pdf');
select pg_temp.upload(:'scan_file', 'lesson_resource', 'image/png', 'Board.png');
select pg_temp.upload(:'exam_file', 'paper_scan', 'application/pdf', 'Exam answers.pdf');

select is((select state from private.ai_material_docs where file_object_id = :'pdf_file'), 'pending',
  'a clean lesson file is queued to be read');
select is((select count(*) from private.ai_material_docs where file_object_id = :'exam_file'), 0::bigint,
  'a paper scan - exam answers - is never read for the AI');

create temporary table gm(name text primary key, value jsonb);
insert into gm select 'lesson', pg_temp.cmd(:'teacher_user', 'createResource', null, jsonb_build_object(
  'schoolId', :'school_id', 'classroomId', :'classroom_id', 'title', 'Photosynthesis',
  'resourceType', 'lesson_note', 'body', 'Plants make food from light.', 'audience', 'both',
  'attachmentFileIds', jsonb_build_array(:'pdf_file', :'scan_file'),
  'links', jsonb_build_array(jsonb_build_object('title', 'Article', 'url', 'https://example.org/leaf'))));
select (value->'response'->>'id')::uuid as lesson_id from gm where name = 'lesson' \gset
select is((select count(*) from private.ai_material_docs d join public.content_links l on l.id = d.content_link_id
  where l.url = 'https://example.org/leaf'), 1::bigint, 'a link on a lesson is queued too');
select is((pg_temp.cmd(:'teacher_user', 'publishResource', :'lesson_id', jsonb_build_object(
  'expectedVersion', (select version from public.resources where id = :'lesson_id'))))->>'outcome', 'ok',
  'the lesson is published to the class');

-- Nothing else in this database gets in the way of the claims below.
update private.ai_material_docs set next_attempt_at = now() + interval '1 year'
where file_object_id is distinct from :'pdf_file'::uuid;

select is((select count(*) from jsonb_array_elements(private.ai_material_claim('w1', 5)) j
  where j->>'kind' = 'file' and j->'file'->>'objectKey' = 'gm/' || :'pdf_file'
    and (j->'limits'->>'ocrPagesPerFile')::int = 60), 1::bigint,
  'the worker claims a file with its exact location and the limits to read it under');
select is((select state from private.ai_material_docs where file_object_id = :'pdf_file'), 'processing',
  'a claimed file is marked as being read');
select is(jsonb_array_length(private.ai_material_claim('w2', 5)), 0,
  'a file being read is not claimed twice');
select is(private.ai_material_ocr_allowance('w1', (select id from private.ai_material_docs
  where file_object_id = :'pdf_file'), 100), 60, 'the model reads at most 60 pages of one file');
insert into private.ai_processing_usage (school_id, kind, pages, month)
values (:'school_id', 'ocr', 2990, date_trunc('month', now() at time zone 'utc')::date);
select is(private.ai_material_ocr_allowance('w1', (select id from private.ai_material_docs
  where file_object_id = :'pdf_file'), 100), 10, 'and only what is left of the school''s month');
select is(private.ai_material_ocr_allowance('intruder', (select id from private.ai_material_docs
  where file_object_id = :'pdf_file'), 100), 0, 'a worker that did not claim the file gets nothing');
delete from private.ai_processing_usage where school_id = :'school_id';

select ok(pg_temp.read((select id from private.ai_material_docs where file_object_id = :'pdf_file'),
  jsonb_build_array(
    jsonb_build_object('page', 1, 'heading', 'Leaves', 'body', 'A leaf is the main site of photosynthesis in plants.'),
    jsonb_build_object('page', 2, 'body', 'Chloroplasts contain chlorophyll, which absorbs light.'),
    jsonb_build_object('page', 3, 'body', 'Stomata on the underside let carbon dioxide into the leaf.'))),
  'the worker''s passages are stored');
select is((select state from private.ai_material_docs where file_object_id = :'pdf_file'), 'ready',
  'and the file is ready');
select is((select count(*) from private.ai_material_chunks c join private.ai_material_docs d on d.id = c.doc_id
  where d.file_object_id = :'pdf_file'), 3::bigint, 'one passage per page');
select is((select sum(cost_micro_usd) from private.ai_processing_usage u join private.ai_material_docs d on d.id = u.doc_id
  where d.file_object_id = :'pdf_file'), 173::numeric,
  'reading it is costed apart from any student''s allowance');
select ok(pg_temp.read((select id from private.ai_material_docs where file_object_id = :'scan_file'),
  jsonb_build_array(jsonb_build_object('body', 'البناء الضوئي يحدث في الخلايا النباتية'))),
  'a scanned Arabic page is stored as read');

-- ---------------------------------------------------------------------------
-- Who may read it
-- ---------------------------------------------------------------------------
select is(jsonb_array_length(pg_temp.m(:'student_user', 'lessons',
  jsonb_build_object('resourceIds', jsonb_build_array(:'lesson_id')))->'lessons'->0->'sources'), 3,
  'a student in the class sees the lesson''s two files and its link');
select is(pg_temp.m(:'student_user', 'lessons',
  jsonb_build_object('resourceIds', jsonb_build_array(:'lesson_id')))->'lessons'->0->>'grade', 'G6',
  'with the class''s grade, to pitch the answer');
select is(pg_temp.m(:'student_user', 'retrieve', jsonb_build_object(
  'resourceIds', jsonb_build_array(:'lesson_id'), 'query', 'What does chlorophyll do?'))->'passages'->0->>'page', '2',
  'a question finds the page that answers it');
select is(pg_temp.m(:'student_user', 'retrieve', jsonb_build_object(
  'resourceIds', jsonb_build_array(:'lesson_id'), 'query', 'اشرح الخلايا'))->'passages'->0->>'text',
  'البناء الضوئي يحدث في الخلايا النباتية', 'an Arabic question finds Arabic material');
select is(pg_temp.m(:'student_user', 'retrieve', jsonb_build_object(
  'resourceIds', jsonb_build_array(:'lesson_id'), 'query', 'explain page 3', 'pages', jsonb_build_array(3)))
  ->'passages'->0->>'page', '3', 'a page the student names is the page sent');
select is(jsonb_array_length(pg_temp.m(:'student_user', 'retrieve', jsonb_build_object(
  'resourceIds', jsonb_build_array(:'lesson_id'), 'mode', 'coverage', 'budgetChars', 20000))->'passages'), 4,
  'a summary reads across every file');
select ok((select sum(length(p->>'text')) from jsonb_array_elements(pg_temp.m(:'student_user', 'retrieve',
  jsonb_build_object('resourceIds', jsonb_build_array(:'lesson_id'), 'mode', 'coverage', 'budgetChars', 500))
  ->'passages') p) < 600, 'and stays within its budget');
select is(jsonb_array_length(pg_temp.m(:'student_user', 'retrieve', jsonb_build_object(
  'resourceIds', jsonb_build_array(:'lesson_id'), 'sourceIds', jsonb_build_array(:'scan_file'),
  'query', 'chlorophyll'))->'passages'), 1, 'one file chosen: only that file is read');

select is(jsonb_array_length(pg_temp.m(:'other_student_user', 'lessons',
  jsonb_build_object('resourceIds', jsonb_build_array(:'lesson_id')))->'lessons'), 0,
  'a student of another class sees nothing of the lesson');
select is(jsonb_array_length(pg_temp.m(:'other_student_user', 'retrieve', jsonb_build_object(
  'resourceIds', jsonb_build_array(:'lesson_id'), 'query', 'chlorophyll'))->'passages'), 0,
  'and retrieves none of its passages');
select is(jsonb_array_length(pg_temp.m(:'other_school_user', 'retrieve', jsonb_build_object(
  'resourceIds', jsonb_build_array(:'lesson_id'), 'mode', 'coverage'))->'passages'), 0,
  'nor does anyone at another school');
select is(jsonb_array_length(pg_temp.m(:'unverified_guardian', 'retrieve', jsonb_build_object(
  'resourceIds', jsonb_build_array(:'lesson_id'), 'mode', 'coverage'))->'passages'), 0,
  'nor an unverified guardian');

insert into gm select 'draft', pg_temp.cmd(:'teacher_user', 'createResource', null, jsonb_build_object(
  'schoolId', :'school_id', 'classroomId', :'classroom_id', 'title', 'Unpublished', 'resourceType', 'lesson_note',
  'body', 'Tomorrow''s test answers: B, C, A.', 'audience', 'both'));
select is(jsonb_array_length(pg_temp.m(:'student_user', 'lessons', jsonb_build_object('resourceIds',
  jsonb_build_array((select value->'response'->>'id' from gm where name = 'draft'))))->'lessons'), 0,
  'a lesson the teacher has not published is never read');

select pg_temp.upload(:'parents_file', 'lesson_resource', 'application/pdf', 'For parents.pdf');
insert into gm select 'parents', pg_temp.cmd(:'teacher_user', 'createResource', null, jsonb_build_object(
  'schoolId', :'school_id', 'classroomId', :'classroom_id', 'title', 'Parents only', 'resourceType', 'lesson_note',
  'body', 'A note for parents.', 'audience', 'guardians', 'attachmentFileIds', jsonb_build_array(:'parents_file')));
select (value->'response'->>'id')::uuid as parents_lesson from gm where name = 'parents' \gset
select pg_temp.cmd(:'teacher_user', 'publishResource', :'parents_lesson', jsonb_build_object(
  'expectedVersion', (select version from public.resources where id = :'parents_lesson')));
select is(jsonb_array_length(pg_temp.m(:'student_user', 'lessons',
  jsonb_build_object('resourceIds', jsonb_build_array(:'parents_lesson')))->'lessons'), 0,
  'a lesson for parents only is not read for students');

-- ---------------------------------------------------------------------------
-- A teacher's view, and reading again
-- ---------------------------------------------------------------------------
select is(jsonb_array_length(pg_temp.m(:'teacher_user', 'status',
  jsonb_build_object('resourceId', :'lesson_id'))->'sources'), 3,
  'the teacher sees how far each file and link has been read');
select is(pg_temp.m(:'teacher_user', 'status', jsonb_build_object('resourceId', :'lesson_id'))->'sources'->0->>'state',
  'ready', 'with each one''s state');
select is(pg_temp.m(:'student_user', 'status', jsonb_build_object('resourceId', :'lesson_id'))->>'outcome',
  'not_found', 'a student does not get the teacher''s view');

update private.ai_material_docs set state = 'processing', worker_id = 'w9', attempts = 3
where file_object_id = :'scan_file';
select ok(private.ai_material_finish('w9', (select id from private.ai_material_docs where file_object_id = :'scan_file'),
  '{"outcome": "retry", "reason": "model_unavailable"}'), 'a passing failure on the last attempt');
select is((select state from private.ai_material_docs where file_object_id = :'scan_file'), 'failed',
  'marks the file failed, not pending forever');
select is(pg_temp.m(:'student_user', 'retry', jsonb_build_object('resourceId', :'lesson_id', 'sourceId', :'scan_file'))->>'outcome',
  'not_found', 'a student cannot ask for it to be read again');
select is(pg_temp.m(:'teacher_user', 'retry', jsonb_build_object('resourceId', :'lesson_id', 'sourceId', :'scan_file'))->>'outcome',
  'ok', 'its teacher can');
select is((select state from private.ai_material_docs where file_object_id = :'scan_file'), 'pending',
  'and it is queued again');
select is(pg_temp.m(:'teacher_user', 'retry', jsonb_build_object('resourceId', :'lesson_id', 'sourceId', :'pdf_file'))->>'outcome',
  'invalid_state', 'a file already read is not read again');
select ok((pg_temp.m(:'student_user', 'pending', jsonb_build_object('resourceId', :'lesson_id'))->>'pending')::boolean,
  'quizzes and notes wait while a file is being read');

-- ---------------------------------------------------------------------------
-- Changes to the lesson are followed
-- ---------------------------------------------------------------------------
insert into private.lesson_notes_cache (resource_version_id, body, model)
select rv.id, 'Old notes', 'Qwen/Qwen3.5-9B' from public.resources r
join public.resource_versions rv on rv.resource_id = r.id and rv.version = r.current_version
where r.id = :'lesson_id';
select pg_temp.read((select id from private.ai_material_docs where file_object_id = :'scan_file'),
  jsonb_build_array(jsonb_build_object('body', 'البناء الضوئي يحدث في الخلايا النباتية')));
select is((select count(*) from private.lesson_notes_cache c join public.resource_versions rv on rv.id = c.resource_version_id
  where rv.resource_id = :'lesson_id'), 0::bigint,
  'notes made before a file was read are dropped, to be made again from all of it');

update public.file_objects set deleted_at = now() where id = :'scan_file';
select is((select count(*) from private.ai_material_docs where file_object_id = :'scan_file'), 0::bigint,
  'a deleted file is removed from the index');
select is(jsonb_array_length(pg_temp.m(:'student_user', 'retrieve', jsonb_build_object(
  'resourceIds', jsonb_build_array(:'lesson_id'), 'query', 'الخلايا'))->'passages') = 0
  or not exists (select 1 from jsonb_array_elements(pg_temp.m(:'student_user', 'retrieve', jsonb_build_object(
  'resourceIds', jsonb_build_array(:'lesson_id'), 'query', 'الخلايا'))->'passages') p
  where p->>'name' = 'Board.png'), true, 'and its passages are never retrieved again');

update public.file_bindings set detached_at = now()
where file_object_id = :'pdf_file' and resource_version_id is not null;
select is((select count(*) from jsonb_array_elements(pg_temp.m(:'student_user', 'retrieve', jsonb_build_object(
  'resourceIds', jsonb_build_array(:'lesson_id'), 'mode', 'coverage'))->'passages') p where p->>'name' = 'Leaf.pdf'),
  0::bigint, 'a file removed from the lesson is no longer read for it');

-- ---------------------------------------------------------------------------
-- Token allowances
-- ---------------------------------------------------------------------------
delete from private.ai_usage where user_id = :'student_user';
delete from private.study_plan_grants where user_id = :'student_user';
-- The student has agreed to the AI notice (ADR-0043); without it the
-- ledger refuses before holding a token (ai_access_consent.sql).
insert into public.consent_records (user_id, purpose, policy_version, locale,
  policy_id, given_by, given_as)
select :'student_user', 'ai_features', p.policy_version, 'en', p.id,
  :'student_user', 'self'
from public.consent_policies p
where p.purpose = 'ai_features' and p.locale = 'en'
order by p.effective_at desc, p.policy_version desc limit 1
on conflict (user_id, purpose, policy_version) do update set withdrawn_at = null;
select is(pg_temp.usage(:'student_user', 'summary', '{}')->'allowance'->>'total', '40000',
  'Free has 40,000 tokens');
select is(pg_temp.usage(:'student_user', 'summary', '{}')->'allowance'->>'period', 'week',
  'a week at a time');
select is(pg_temp.usage(:'student_user', 'reserve', '{"feature": "quiz", "estimateMicroUsd": 10, "estimateTokens": 100}')->>'outcome',
  'plan_required', 'quizzes are not on Free');
select is(pg_temp.usage(:'student_user', 'reserve', '{"feature": "ask", "estimateMicroUsd": 10, "estimateTokens": 40001}')->>'outcome',
  'allowance_exhausted', 'a question bigger than what is left is refused before the provider is called');
insert into private.study_plan_grants (user_id, plan, reason, ends_at)
values (:'student_user', 'plus', 'test', now() + interval '1 day');
select is(pg_temp.usage(:'student_user', 'reserve', '{"feature": "notes", "estimateMicroUsd": 10, "estimateTokens": 100}')->>'outcome',
  'ok', 'lesson notes are on Plus');
select is(pg_temp.usage(:'student_user', 'summary', '{}')->'allowance'->>'total', '3000000',
  'Plus has 3,000,000 tokens a month');

-- ---------------------------------------------------------------------------
-- Boundaries
-- ---------------------------------------------------------------------------
select ok(pg_temp.allowed(:'student_user', 'lesson_reading.read', :'lesson_id'),
  'a student may see a lesson''s reading state');
select ok(not pg_temp.allowed(:'student_user', 'lesson_reading.retry', :'lesson_id'),
  'but not ask for a file to be read again');
select ok(not pg_temp.allowed(:'other_school_user', 'lesson_reading.read', :'lesson_id'),
  'nobody at another school sees it');
select ok(not has_function_privilege('studafy_api_runtime', 'private.ai_material_claim(text, integer)', 'execute')
  and not has_function_privilege('studafy_worker_runtime', 'private.api054_ai_material(text, jsonb)', 'execute'),
  'the API cannot claim files and the worker cannot read for a student');

select * from finish();
rollback;
