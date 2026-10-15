-- Hand-ins, messages, announcements and work material refuse a file the
-- scan refused, and say which one (202610150020). private.file_attach_bind
-- answers through the dispatchers as {"outcome": "attachment_refused",
-- "rows": [{path, reason}]}, keeps nothing, and still answers 'forbidden'
-- for a file the caller may not use. A file refused after it was attached
-- stays listed, with the scan state that says so.
-- Transactional fixtures: everything rolls back.
begin;
\set auth031_fixture_only true
\ir rls_access_seed.sql
\unset auth031_fixture_only
create extension if not exists pgtap with schema extensions;
set local search_path=public,extensions;
select plan(33);

\set other_teacher 'a2810000-0000-4000-8000-0000000000a1'
\set hw_clean 'a2810000-0000-4000-8000-0000000000f1'
\set hw_rejected 'a2810000-0000-4000-8000-0000000000f2'
\set hw_error 'a2810000-0000-4000-8000-0000000000f3'
\set hw_scanning 'a2810000-0000-4000-8000-0000000000f4'
\set hw_foreign_clean 'a2810000-0000-4000-8000-0000000000f5'
\set hw_foreign_rejected 'a2810000-0000-4000-8000-0000000000f6'
\set ann_rejected 'a2810000-0000-4000-8000-0000000000f7'
\set ann_clean 'a2810000-0000-4000-8000-0000000000f8'
\set msg_rejected 'a2810000-0000-4000-8000-0000000000f9'
\set msg_quarantined 'a2810000-0000-4000-8000-0000000000fa'
\set sub_kept 'a2810000-0000-4000-8000-0000000000fb'
\set sub_rejected 'a2810000-0000-4000-8000-0000000000fc'
\set sub_clean 'a2810000-0000-4000-8000-0000000000fd'
\set sub_gone_after 'a2810000-0000-4000-8000-0000000000fe'
\set hw_later 'a2810000-0000-4000-8000-0000000000ff'
\set hw_retained 'a2810000-0000-4000-8000-0000000000e1'

insert into auth.users (id, email, encrypted_password, aud, role, email_confirmed_at,
  created_at, updated_at, instance_id, confirmation_token, recovery_token, email_change,
  email_change_token_new, email_change_token_current, phone_change_token,
  raw_app_meta_data, raw_user_meta_data)
values (:'other_teacher', 'br.teacher2@synthetic.studafy.test', 'x', 'authenticated', 'authenticated',
  now(), now(), now(), '00000000-0000-0000-0000-000000000000', '', '', '', '', '', '', '{}', '{}');
insert into public.memberships (school_id, user_id, role, active)
values (:'school_id', :'other_teacher', 'teacher', true);

select set_config('studafy.school_id', :'school_id', true);
select set_config('studafy.request_id', 'bind-refusals-test', true);

create function pg_temp.cmd(actor uuid, op text, resource uuid, body jsonb,
  dispatcher text default 'api041') returns jsonb
language plpgsql as $$
declare r jsonb;
begin
  perform set_config('request.jwt.claim.sub', actor::text, true);
  r := private.api_idempotency_reserve(current_setting('studafy.school_id')::uuid,
    op, gen_random_uuid()::text,
    encode(extensions.digest(gen_random_uuid()::text, 'sha256'), 'hex'), 3600, 60);
  if dispatcher = 'api042' then
    return private.api042_command(op, resource,
      jsonb_build_object('responseStatus', 201, 'body', body),
      (r->>'id')::uuid, (r->>'generation')::bigint);
  end if;
  return private.api041_command(op, resource,
    jsonb_build_object('responseStatus', 201, 'body', body),
    (r->>'id')::uuid, (r->>'generation')::bigint);
end $$;
create function pg_temp.upload(file uuid, owner uuid, purpose text, class uuid,
  state text default 'clean', assignment uuid default null)
returns void language plpgsql as $$
declare v_session uuid := gen_random_uuid();
begin
  insert into public.file_objects (id, school_id, bucket, object_key, uploader_id, size_bytes,
    declared_media_type, sha256, scan_state, scanned_at, owner_id, purpose, display_name,
    scan_error_code)
  values (file, current_setting('studafy.school_id')::uuid, 'legacy', 'br/' || file, owner, 10,
    'application/pdf', encode(extensions.digest(file::text, 'sha256'), 'hex'),
    state::public.file_scan_state, now(), owner, purpose::public.file_purpose, 'File.pdf',
    case when state in ('rejected', 'error') then 'malformed_file' end);
  insert into public.upload_sessions (id, school_id, uploader_id, purpose, expected_size_bytes,
    allowed_media_types, nonce_hash, expires_at, classroom_id, assignment_id)
  values (v_session, current_setting('studafy.school_id')::uuid, owner, purpose::public.file_purpose, 10,
    array['application/pdf'], encode(extensions.digest('nonce' || file::text, 'sha256'), 'hex'),
    now() + interval '1 hour', class, assignment);
  insert into public.file_bindings (school_id, file_object_id, upload_session_id)
  values (current_setting('studafy.school_id')::uuid, file, v_session);
end $$;
-- What the scan and the cleanup job do to a file, as they do it.
create function pg_temp.scan_refuses(file uuid) returns void language sql as $$
  update public.file_objects set scan_state = 'rejected', scan_error_code = 'malformed_file'
  where id = file;
$$;
create function pg_temp.cleanup(file uuid) returns void language sql as $$
  update public.file_objects set scan_state = 'deleted', deleted_at = now(),
    physical_deleted_at = now() where id = file and scan_state in ('rejected', 'error');
$$;

select pg_temp.upload(:'hw_clean', :'teacher_user', 'assignment_material', :'classroom_id');
select pg_temp.upload(:'hw_rejected', :'teacher_user', 'assignment_material', :'classroom_id', 'rejected');
select pg_temp.upload(:'hw_error', :'teacher_user', 'assignment_material', :'classroom_id', 'error');
select pg_temp.upload(:'hw_scanning', :'teacher_user', 'assignment_material', :'classroom_id', 'scanning');
select pg_temp.upload(:'hw_later', :'teacher_user', 'assignment_material', :'classroom_id');
select pg_temp.upload(:'hw_retained', :'teacher_user', 'assignment_material', :'classroom_id');
select pg_temp.upload(:'hw_foreign_clean', :'other_teacher', 'assignment_material', :'classroom_id');
select pg_temp.upload(:'hw_foreign_rejected', :'other_teacher', 'assignment_material', :'classroom_id', 'rejected');
select pg_temp.upload(:'ann_rejected', :'teacher_user', 'announcement_attachment', :'classroom_id', 'rejected');
select pg_temp.upload(:'ann_clean', :'teacher_user', 'announcement_attachment', :'classroom_id');
select pg_temp.upload(:'msg_rejected', :'teacher_user', 'message_attachment', null, 'rejected');
select pg_temp.upload(:'msg_quarantined', :'teacher_user', 'message_attachment', null, 'quarantined');

create temporary table br(name text primary key, value jsonb);

-- ---------------------------------------------------------------------------
-- Work material: a new assignment, and changing its material
-- ---------------------------------------------------------------------------

create function pg_temp.homework(title text, files jsonb) returns jsonb language sql as $$
  select jsonb_build_object('classroomId', 'abcd0000-0000-4000-8000-000000000007',
    'title', title, 'instructions', null, 'dueAt', now() + interval '1 day',
    'closesAt', null, 'attachmentFileIds', files);
$$;

select is(pg_temp.cmd(:'teacher_user', 'createAssignment', null,
  pg_temp.homework('Refused sheet', jsonb_build_array(:'hw_clean', :'hw_rejected'))),
  '{"outcome": "attachment_refused", "rows": [{"path": "attachmentFileIds.1", "reason": "file_refused"}]}'::jsonb,
  'new work with a file the scan refused names it');
select is((select count(*) from public.assignments where title = 'Refused sheet'), 0::bigint,
  'and the work was not created');
select is((select count(*) from public.file_bindings where file_object_id = :'hw_clean'
  and assignment_id is not null), 0::bigint, 'nor the good file bound');
select is(pg_temp.cmd(:'teacher_user', 'createAssignment', null,
  pg_temp.homework('Errored sheet', jsonb_build_array(:'hw_error')))->'rows',
  '[{"path": "attachmentFileIds.0", "reason": "file_refused"}]'::jsonb,
  'a file the scan gave up on is refused the same way');
select is(pg_temp.cmd(:'teacher_user', 'createAssignment', null,
  pg_temp.homework('Foreign refused', jsonb_build_array(:'hw_foreign_rejected')))->>'outcome',
  'forbidden', 'another teacher''s refused file is still forbidden, never why it was refused');
select is(pg_temp.cmd(:'teacher_user', 'createAssignment', null,
  pg_temp.homework('Mixed', jsonb_build_array(:'hw_rejected', :'hw_foreign_clean')))->>'outcome',
  'forbidden', 'a forbidden file anywhere in the request still answers forbidden');
select is(pg_temp.cmd(:'teacher_user', 'createAssignment', null,
  pg_temp.homework('Dupe', jsonb_build_array(:'hw_clean', :'hw_clean')))->'rows',
  '[{"path": "attachmentFileIds.1", "reason": "duplicate"}]'::jsonb,
  'the same file twice names the second');

insert into br select 'hw', pg_temp.cmd(:'teacher_user', 'createAssignment', null,
  pg_temp.homework('Reading', jsonb_build_array(:'hw_clean', :'hw_scanning')));
select is((select value->>'outcome' from br where name = 'hw'), 'ok',
  'a file still being scanned is attached: the scan finishes after');
select (value->'response'->>'id')::uuid as hw_id from br where name = 'hw' \gset

select is(pg_temp.cmd(:'teacher_user', 'updateAssignmentMaterials', :'hw_id', jsonb_build_object(
  'expectedVersion', (select version from public.assignments where id = :'hw_id'),
  'detachFileIds', '[]'::jsonb,
  'attachmentFileIds', jsonb_build_array(:'hw_later', :'hw_rejected'))),
  '{"outcome": "attachment_refused", "rows": [{"path": "attachmentFileIds.1", "reason": "file_refused"}]}'::jsonb,
  'adding a refused file to the material names it');
select is((select count(*) from public.file_bindings where file_object_id = :'hw_later'
  and assignment_id is not null), 0::bigint, 'and nothing is added');
select is(pg_temp.cmd(:'teacher_user', 'updateAssignmentMaterials', :'hw_id', jsonb_build_object(
  'expectedVersion', (select version from public.assignments where id = :'hw_id'),
  'detachFileIds', '[]'::jsonb, 'links', '[]'::jsonb,
  'attachmentFileIds', jsonb_build_array(:'hw_error')))->'rows',
  '[{"path": "attachmentFileIds.0", "reason": "file_refused"}]'::jsonb,
  'the same with links in the request');
select is(pg_temp.cmd(:'teacher_user', 'updateAssignmentMaterials', :'hw_id', jsonb_build_object(
  'expectedVersion', (select version from public.assignments where id = :'hw_id'),
  'detachFileIds', '[]'::jsonb,
  'attachmentFileIds', jsonb_build_array(:'hw_foreign_clean')))->>'outcome',
  'forbidden', 'another teacher''s file is still forbidden');

-- A file refused after it was attached stays on the work, as refused.
select pg_temp.scan_refuses(:'hw_scanning');
create function pg_temp.hw_files() returns jsonb language sql as $$
  select coalesce(jsonb_agg(jsonb_build_object('id', a->>'id', 'scanState', a->>'scanState')
    order by a->>'id'), '[]'::jsonb)
  from jsonb_array_elements(private.api041_assignment_json(
    (select id from public.assignments where title = 'Reading'))->'attachments') a;
$$;
select is(pg_temp.hw_files(), jsonb_build_array(
    jsonb_build_object('id', :'hw_clean', 'scanState', 'clean'),
    jsonb_build_object('id', :'hw_scanning', 'scanState', 'rejected')),
  'a file refused after it was attached is listed as refused, not as being checked');
select pg_temp.cleanup(:'hw_scanning');
select is(pg_temp.hw_files(), jsonb_build_array(
    jsonb_build_object('id', :'hw_clean', 'scanState', 'clean'),
    jsonb_build_object('id', :'hw_scanning', 'scanState', 'deleted')),
  'and once its bytes are deleted it is still listed, as deleted, rather than vanishing');
update public.file_objects set scan_state = 'deleted', deleted_at = now()
where id = :'hw_clean';
select is(pg_temp.hw_files(), jsonb_build_array(
    jsonb_build_object('id', :'hw_scanning', 'scanState', 'deleted')),
  'a file deleted for any other reason still drops out');
select is(private.file051_authorize_download(:'hw_scanning')->>'allowed', 'false',
  'and the refused file is never delivered');

-- ---------------------------------------------------------------------------
-- Announcements
-- ---------------------------------------------------------------------------

create function pg_temp.announcement(title text, files jsonb) returns jsonb language sql as $$
  select jsonb_build_object('schoolId', current_setting('studafy.school_id'),
    'classroomId', 'abcd0000-0000-4000-8000-000000000007', 'title', title,
    'body', 'Details attached.', 'audience', 'both', 'attachmentFileIds', files);
$$;
select is(pg_temp.cmd(:'teacher_user', 'createAnnouncement', null,
  pg_temp.announcement('Trip', jsonb_build_array(:'ann_clean', :'ann_rejected')), 'api042'),
  '{"outcome": "attachment_refused", "rows": [{"path": "attachmentFileIds.1", "reason": "file_refused"}]}'::jsonb,
  'an announcement with a refused file names it');
select is((select count(*) from public.announcements where title = 'Trip'), 0::bigint,
  'and the announcement was not posted without it');
select is(pg_temp.cmd(:'teacher_user', 'createAnnouncement', null,
  pg_temp.announcement('Trip', jsonb_build_array(:'ann_clean')), 'api042')->>'outcome', 'ok',
  'with it taken off, the announcement is posted');

-- ---------------------------------------------------------------------------
-- Messages
-- ---------------------------------------------------------------------------

insert into public.school_content_controls (school_id, messaging_enabled)
values (:'school_id', true)
on conflict (school_id) do update set messaging_enabled = true;
insert into br select 'convo', pg_temp.cmd(:'teacher_user', 'createConversation', null,
  jsonb_build_object('schoolId', :'school_id', 'subject', 'Files',
    'participantIds', jsonb_build_array(:'guardian_user')), 'api042');
select is((select value->>'outcome' from br where name = 'convo'), 'ok', 'a conversation to send in');
select (value->'response'->>'id')::uuid as convo_id from br where name = 'convo' \gset

select is(pg_temp.cmd(:'teacher_user', 'sendMessage', :'convo_id', jsonb_build_object(
  'clientMessageId', gen_random_uuid(), 'body', 'See attached',
  'attachmentFileIds', jsonb_build_array(:'msg_rejected')), 'api042'),
  '{"outcome": "attachment_refused", "rows": [{"path": "attachmentFileIds.0", "reason": "file_refused"}]}'::jsonb,
  'a message with a refused file names it');
select is((select count(*) from public.messages where conversation_id = :'convo_id'), 0::bigint,
  'and the message was not sent without it');
insert into br select 'msg', pg_temp.cmd(:'teacher_user', 'sendMessage', :'convo_id', jsonb_build_object(
  'clientMessageId', gen_random_uuid(), 'body', 'See attached',
  'attachmentFileIds', jsonb_build_array(:'msg_quarantined')), 'api042');
select is((select value->'response'->'attachments'->0->>'scanState' from br where name = 'msg'),
  'quarantined', 'a file still in quarantine is sent, and says so');
select pg_temp.scan_refuses(:'msg_quarantined');
select is(private.api042_message_json((select (value->'response'->>'id')::uuid from br where name = 'msg'))
  ->'attachments'->0->>'scanState', 'rejected',
  'when the scan then refuses it, the message says so');

-- ---------------------------------------------------------------------------
-- Handing work in
-- ---------------------------------------------------------------------------

select set_config('request.jwt.claim.sub', :'teacher_user', true);
insert into br select 'task', pg_temp.cmd(:'teacher_user', 'createAssignment', null,
  pg_temp.homework('Essay', '[]'::jsonb));
select (value->'response'->>'id')::uuid as task_id from br where name = 'task' \gset
select is(pg_temp.cmd(:'teacher_user', 'publishAssignment', :'task_id', jsonb_build_object(
  'expectedVersion', (select version from public.assignments where id = :'task_id')))->>'outcome',
  'ok', 'work to hand in');

select pg_temp.upload(:'sub_kept', :'student_user', 'assignment_submission', null, 'clean', :'task_id');
select pg_temp.upload(:'sub_gone_after', :'student_user', 'assignment_submission', null, 'clean', :'task_id');
select pg_temp.upload(:'sub_rejected', :'student_user', 'assignment_submission', null, 'rejected', :'task_id');
select pg_temp.upload(:'sub_clean', :'student_user', 'assignment_submission', null, 'clean', :'task_id');

select is(pg_temp.cmd(:'student_user', 'submitAssignment', :'task_id', jsonb_build_object(
  'answerText', 'My essay', 'attachmentFileIds', jsonb_build_array(:'sub_kept', :'sub_gone_after'))
  )->>'outcome', 'ok', 'a first hand-in with two files');
select is(pg_temp.cmd(:'student_user', 'submitAssignment', :'task_id', jsonb_build_object(
  'answerText', 'Again', 'attachmentFileIds',
  jsonb_build_array(:'sub_kept', :'sub_clean', :'sub_rejected'))),
  '{"outcome": "attachment_refused", "rows": [{"path": "attachmentFileIds.2", "reason": "file_refused"}]}'::jsonb,
  'handing in again with a refused file names it at its place in the request, after a carried-over file');
select is((select count(*) from public.submission_attempts sa join public.submissions s
  on s.id = sa.submission_id where s.assignment_id = :'task_id'), 1::bigint,
  'and no attempt was added');
select is(pg_temp.cmd(:'student_user', 'submitAssignment', :'task_id', jsonb_build_object(
  'answerText', 'Again', 'attachmentFileIds', jsonb_build_array(:'sub_clean', :'sub_clean')))->'rows',
  '[{"path": "attachmentFileIds.1", "reason": "duplicate"}]'::jsonb,
  'the same file twice names the second');

-- The teacher and the student see the removed file as removed.
select pg_temp.scan_refuses(:'sub_gone_after');
select pg_temp.cleanup(:'sub_gone_after');
select is((select jsonb_agg(a->>'scanState' order by a->>'id') from jsonb_array_elements(
    private.file_attachment_json(p_submission_attempt => (select s.current_attempt_id
      from public.submissions s where s.assignment_id = :'task_id'))) a),
  '["clean", "deleted"]'::jsonb,
  'a hand-in whose file the scan removed still lists it, as removed');
select is(pg_temp.cmd(:'student_user', 'submitAssignment', :'task_id', jsonb_build_object(
  'answerText', 'Again', 'attachmentFileIds', jsonb_build_array(:'sub_clean', :'sub_gone_after'))),
  '{"outcome": "attachment_refused", "rows": [{"path": "attachmentFileIds.1", "reason": "file_refused"}]}'::jsonb,
  'a carried-over file the scan has since removed is not carried over');
insert into br select 'again', pg_temp.cmd(:'student_user', 'submitAssignment', :'task_id',
  jsonb_build_object('answerText', 'Again',
    'attachmentFileIds', jsonb_build_array(:'sub_kept', :'sub_clean')));
select is((select jsonb_agg(a->>'id' order by a->>'id')
    from br, jsonb_array_elements(value->'response'->'attachments') a where name = 'again'),
  jsonb_build_array(:'sub_kept', :'sub_clean'),
  'without it the hand-in goes in, with the kept and the new file');

select ok(has_function_privilege('studafy_api_runtime',
  'private.api042_command(text,uuid,jsonb,uuid,bigint)', 'execute')
  and not has_function_privilege('studafy_api_runtime',
  'private.file_attach_bind(jsonb,public.file_purpose,uuid,uuid,uuid,uuid,uuid,uuid)', 'execute'),
  'the dispatcher keeps its grant and the binder stays private');

select * from finish();
rollback;
