-- DL-051: an export request becomes a document of the requester's own data,
-- downloadable only by them, and its payload is deleted when it expires.
begin;
create extension if not exists pgtap with schema extensions;
set local search_path=public,extensions;
select plan(12);

\set school_id '11111111-1111-4111-8111-111111111111'
\set teacher_user 'aaaa0000-0000-4000-8000-000000000001'
\set student_user 'bbbb0000-0000-4000-8000-000000000002'

insert into public.conversations (id, school_id, subject, created_by)
values ('e0e00000-0000-4000-8000-0000000000c1', :'school_id', 'Revision', :'teacher_user');
insert into public.conversation_participants (school_id, conversation_id, user_id) values
  (:'school_id', 'e0e00000-0000-4000-8000-0000000000c1', :'teacher_user'),
  (:'school_id', 'e0e00000-0000-4000-8000-0000000000c1', :'student_user');
insert into public.messages (school_id, conversation_id, sender_id, client_message_id, body) values
  (:'school_id', 'e0e00000-0000-4000-8000-0000000000c1', :'student_user', gen_random_uuid(), 'my own words'),
  (:'school_id', 'e0e00000-0000-4000-8000-0000000000c1', :'teacher_user', gen_random_uuid(), 'the teacher private reply');
insert into public.data_export_requests (id, user_id, status)
values ('e0e00000-0000-4000-8000-0000000000e1', :'student_user', 'pending');

select ok(has_function_privilege('studafy_worker_runtime', 'private.data_export_build(uuid)', 'execute'),
  'the worker can build exports');
select ok(not has_function_privilege('studafy_api_runtime', 'private.data_export_build(uuid)', 'execute'),
  'the API cannot build exports');
select ok('e0e00000-0000-4000-8000-0000000000e1'::uuid = any(private.data_export_claim(50)),
  'a pending request is claimed');
select is(private.data_export_build('e0e00000-0000-4000-8000-0000000000e1'), 'ready',
  'the export is built');
select is(private.data_export_build('e0e00000-0000-4000-8000-0000000000e1'), 'ready',
  'building again is a no-op');

select set_config('request.jwt.claim.sub', :'student_user', true);
select is(private.api042_query('downloadDataExport', null, '{}')->>'format', 'studafy-export/v1',
  'the owner downloads a versioned document');
select ok((private.api042_query('downloadDataExport', null, '{}')->'sections'->'messagesSent')::text like '%my own words%',
  'the document contains messages the owner sent');
select ok(not ((private.api042_query('downloadDataExport', null, '{}'))::text like '%teacher private reply%'),
  'the document never contains messages other people sent');
select is(private.api042_query('downloadDataExport', null, '{}')->'sections'->'profile'->>'displayName', 'Seed Student',
  'the document includes the profile');

select set_config('request.jwt.claim.sub', :'teacher_user', true);
select is(private.api042_query('downloadDataExport', null, '{}')->>'outcome', 'not_found',
  'nobody else can download it');

update public.data_export_requests set expires_at = now() - interval '1 minute'
  where id = 'e0e00000-0000-4000-8000-0000000000e1';
select ok(private.data_export_expire() >= 1, 'expired exports are swept');
select is((select count(*) from public.data_export_payloads
  where request_id = 'e0e00000-0000-4000-8000-0000000000e1'), 0::bigint,
  'the expired payload is deleted');

select * from finish();
rollback;
