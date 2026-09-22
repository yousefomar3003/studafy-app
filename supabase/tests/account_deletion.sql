-- DL-051: an account deletion request is executed once its grace period
-- ends, as de-identification that keeps school, safety and financial
-- records intact, and never while cancelled, not yet due or legally held.
begin;
create extension if not exists pgtap with schema extensions;
set local search_path=public,extensions;
select plan(24);

\set school_id '11111111-1111-4111-8111-111111111111'
\set teacher_user 'aaaa0000-0000-4000-8000-000000000001'
\set leaver 'de1e0000-0000-4000-8000-000000000001'
\set held 'de1e0000-0000-4000-8000-000000000002'
\set early 'de1e0000-0000-4000-8000-000000000003'
\set student_id 'abcf0000-0000-4000-8000-000000000008'

insert into auth.users (
  id, email, encrypted_password, aud, role, email_confirmed_at, created_at,
  updated_at, instance_id, confirmation_token, recovery_token, email_change,
  email_change_token_new, email_change_token_current, phone_change_token,
  raw_app_meta_data, raw_user_meta_data
) values
  (:'leaver', 'leaver@synthetic.studafy.test', 'hash', 'authenticated', 'authenticated', now(), now(), now(), '00000000-0000-0000-0000-000000000000', '', '', '', '', '', '', '{"provider":"google"}'::jsonb, '{"full_name":"Lena Leaver"}'::jsonb),
  (:'held', 'held@synthetic.studafy.test', 'hash', 'authenticated', 'authenticated', now(), now(), now(), '00000000-0000-0000-0000-000000000000', '', '', '', '', '', '', '{}'::jsonb, '{"full_name":"Hana Held"}'::jsonb),
  (:'early', 'early@synthetic.studafy.test', 'hash', 'authenticated', 'authenticated', now(), now(), now(), '00000000-0000-0000-0000-000000000000', '', '', '', '', '', '', '{}'::jsonb, '{"full_name":"Eli Early"}'::jsonb);
insert into auth.identities (provider_id, user_id, identity_data, provider)
values (:'leaver', :'leaver', '{"sub":"x"}'::jsonb, 'google');

insert into public.memberships (school_id, user_id, role, active, status)
values (:'school_id', :'leaver', 'guardian', true, 'active');
insert into public.guardian_links (student_id, guardian_id, status, relationship, verified_by, verified_at)
values (:'student_id', :'leaver', 'verified', 'parent', :'teacher_user', now());

-- A conversation and a message the leaver sent: both must survive.
insert into public.conversations (id, school_id, subject, created_by)
values ('de1e0000-0000-4000-8000-0000000000c1', :'school_id', 'Homework', :'teacher_user');
insert into public.conversation_participants (school_id, conversation_id, user_id) values
  (:'school_id', 'de1e0000-0000-4000-8000-0000000000c1', :'teacher_user'),
  (:'school_id', 'de1e0000-0000-4000-8000-0000000000c1', :'leaver');
insert into public.messages (school_id, conversation_id, sender_id, client_message_id, body)
values (:'school_id', 'de1e0000-0000-4000-8000-0000000000c1', :'leaver', gen_random_uuid(), 'See you at the meeting');

insert into public.account_deletion_requests (user_id, execute_after, requested_at)
values
  (:'leaver', now() - interval '1 minute', now() - interval '15 days'),
  (:'held', now() - interval '1 minute', now() - interval '15 days'),
  (:'early', now() + interval '10 days', now());
insert into public.legal_holds (school_id, subject_user_id, reason, ticket_ref, granted_by)
values (:'school_id', :'held', 'Open safeguarding investigation', 'TICK-DL051', :'teacher_user');

-- The worker's privileges are exactly the two entry points.
select ok(has_function_privilege('studafy_worker_runtime', 'private.account_deletion_claim(integer)', 'execute'),
  'the worker can claim due requests');
select ok(not has_function_privilege('studafy_api_runtime', 'private.account_deletion_execute(uuid)', 'execute'),
  'the API cannot execute a deletion');

create temporary table dl051(claimed uuid[]) on commit drop;
insert into dl051 select private.account_deletion_claim(50);

select ok((select (select id from public.account_deletion_requests where user_id = :'leaver') = any(claimed) from dl051),
  'a request past its grace period is claimed');
select ok((select not ((select id from public.account_deletion_requests where user_id = :'held') = any(claimed)) from dl051),
  'a request whose subject is under legal hold is not claimed');
select ok((select not ((select id from public.account_deletion_requests where user_id = :'early') = any(claimed)) from dl051),
  'a request still in its grace period is not claimed');

select is(private.account_deletion_execute((select id from public.account_deletion_requests where user_id = :'leaver')),
  'completed', 'the executor completes the due request');

-- Sign-in is gone and the auth schema holds nothing identifying.
select is((select count(*) from auth.identities where user_id = :'leaver'), 0::bigint,
  'every sign-in identity is removed');
select is((select email from auth.users where id = :'leaver'),
  'deleted+de1e0000-0000-4000-8000-000000000001@deleted.invalid', 'the email is replaced');
select ok((select banned_until = 'infinity'::timestamptz from auth.users where id = :'leaver'),
  'the auth user is banned permanently');
select is((select raw_user_meta_data from auth.users where id = :'leaver'), '{}'::jsonb,
  'the name stored in auth metadata is erased');

-- The profile is a nameless tombstone.
select is((select display_name from public.profiles where id = :'leaver'), 'Deleted user',
  'the profile no longer carries a name');
select is((select status::text from public.profiles where id = :'leaver'), 'deleted',
  'the profile is marked deleted');

-- Authority ends.
select is((select count(*) from public.memberships where user_id = :'leaver' and active), 0::bigint,
  'no membership stays active');
select is((select status::text from public.guardian_links where guardian_id = :'leaver'), 'revoked',
  'the guardian link is revoked');
select ok((select left_at is not null from public.conversation_participants
  where user_id = :'leaver' and conversation_id = 'de1e0000-0000-4000-8000-0000000000c1'),
  'the leaver leaves every conversation');

-- Retained records stay intact and attributable only to the tombstone.
select is((select count(*) from public.messages where sender_id = :'leaver'), 1::bigint,
  'a message already sent is retained for the other participant and safeguarding');
select is((select state from public.account_deletion_requests where user_id = :'leaver'), 'completed',
  'the request is marked completed');
select is((select count(*) from public.audit_events
  where action = 'account_deleted'
    and entity_id = (select id from public.account_deletion_requests where user_id = :'leaver')), 1::bigint,
  'completion is audited against the request, not a name');
select ok((select not (after_value::text like '%Lena%') from public.audit_events
  where action = 'account_deleted'
    and entity_id = (select id from public.account_deletion_requests where user_id = :'leaver')),
  'the audit record carries no name');

-- Idempotent and inert on the other requests.
select is(private.account_deletion_execute((select id from public.account_deletion_requests where user_id = :'leaver')),
  'completed', 're-running a completed request changes nothing');
select is(private.account_deletion_execute((select id from public.account_deletion_requests where user_id = :'early')),
  'not_due', 'an early request is refused by the executor too');
select is(private.account_deletion_execute((select id from public.account_deletion_requests where user_id = :'held')),
  'held', 'a held request is refused by the executor too');
select is((select display_name from public.profiles where id = :'held'), 'Hana Held',
  'a held account is untouched');

update public.account_deletion_requests set state = 'cancelled', cancelled_at = now()
  where user_id = :'early';
select is(private.account_deletion_execute((select id from public.account_deletion_requests where user_id = :'early')),
  'cancelled', 'a cancelled request is never executed');

select * from finish();
rollback;
