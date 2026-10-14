-- DL-051: an account deletion request is executed once its grace period
-- ends, as de-identification that keeps school, safety and financial
-- records intact, and never while cancelled, not yet due or legally held.
begin;
create extension if not exists pgtap with schema extensions;
set local search_path=public,extensions;
select plan(44);

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

-- Personal data 3.6b removes, and school records it must keep.
\set leaver_student 'de1e0000-0000-4000-8000-0000000000a1'
\set classroom_id 'abcd0000-0000-4000-8000-000000000007'
\set resource_id 'abd60000-0000-4000-8000-00000000010f'
update public.profiles set gender = 'female' where id = :'leaver';
insert into public.students (id, school_id, user_id, studafy_id, display_name, created_by)
values (:'leaver_student', :'school_id', :'leaver', '4000000071', 'Lena Leaver', :'teacher_user');
insert into public.notebook_entries (school_id, classroom_id, student_id, owner_id, title, body, source)
values (:'school_id', :'classroom_id', :'leaver_student', :'leaver', 'My notes', 'Photosynthesis', 'typed');
insert into public.study_notebooks (school_id, owner_id, classroom_id, resource_id, title)
values (:'school_id', :'leaver', :'classroom_id', :'resource_id', 'Biology');
insert into private.ai_usage (user_id, feature, plan, month, reserved_micro_usd)
values (:'leaver', 'ask', 'free', date_trunc('month', now())::date, 0);
insert into public.consent_records (user_id, purpose, policy_version, locale)
values (:'leaver', 'terms_and_privacy', 'dl051-test', 'en');
insert into public.notifications (school_id, user_id, kind, title, body)
values (:'school_id', :'leaver', 'test', 'Lena, your grade is ready', 'Synthetic');
insert into public.push_devices (user_id, platform, token)
values (:'leaver', 'android', repeat('t', 40));
insert into private.managed_accounts (child_id, guardian_id) values (:'leaver', :'held');
insert into public.invitations (school_id, role, email, token_hash, invited_by, expires_at)
values (:'school_id', 'guardian', 'leaver@synthetic.studafy.test', 'dl051-invite', :'teacher_user', now() + interval '1 day');
insert into public.file_objects (id, school_id, bucket, object_key, uploader_id, size_bytes,
  declared_media_type, detected_media_type, sha256, stored_sha256, stored_size_bytes,
  scan_state, scanned_at, owner_id, purpose, display_name)
values
  ('de1e0000-0000-4000-8000-0000000000f1', :'school_id', 'legacy', 'dl051/photo', :'leaver', 10,
   'image/jpeg', 'image/jpeg', repeat('c', 64), repeat('c', 64), 10, 'clean', now(),
   :'leaver', 'notebook_photo', 'whiteboard.jpg'),
  ('de1e0000-0000-4000-8000-0000000000f2', :'school_id', 'legacy', 'dl051/handin', :'leaver', 10,
   'application/pdf', 'application/pdf', repeat('d', 64), repeat('d', 64), 10, 'clean', now(),
   :'leaver', 'assignment_submission', 'essay.pdf');

-- Two child accounts the leaver manages (ADR-0031); one is under legal hold.
\set kid 'de1e0000-0000-4000-8000-000000000004'
\set held_kid 'de1e0000-0000-4000-8000-000000000005'
insert into auth.users (
  id, email, encrypted_password, aud, role, email_confirmed_at, created_at,
  updated_at, instance_id, confirmation_token, recovery_token, email_change,
  email_change_token_new, email_change_token_current, phone_change_token,
  raw_app_meta_data, raw_user_meta_data
) values
  (:'kid', 'kid@managed.studafy.invalid', '', 'authenticated', 'authenticated', now(), now(), now(), '00000000-0000-0000-0000-000000000000', '', '', '', '', '', '', '{}'::jsonb, '{"full_name":"Kai Kid"}'::jsonb),
  (:'held_kid', 'heldkid@managed.studafy.invalid', '', 'authenticated', 'authenticated', now(), now(), now(), '00000000-0000-0000-0000-000000000000', '', '', '', '', '', '', '{}'::jsonb, '{"full_name":"Hal Kid"}'::jsonb);
update public.profiles set display_name = 'Kai Kid' where id = :'kid';
update public.profiles set display_name = 'Hal Kid' where id = :'held_kid';
insert into private.managed_accounts (child_id, guardian_id) values
  (:'kid', :'leaver'), (:'held_kid', :'leaver');
insert into public.legal_holds (school_id, subject_user_id, reason, ticket_ref, granted_by)
values (:'school_id', :'held_kid', 'Open safeguarding investigation', 'TICK-DL051-KID', :'teacher_user');

select set_config('request.jwt.claim.sub', :'leaver', true);
select is(private.auth_deletion_impact()->'managed_child_accounts', '["Hal Kid", "Kai Kid"]'::jsonb,
  'the deletion screen names the child accounts that will be deleted too');
select set_config('request.jwt.claim.sub', '', true);

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

-- 3.6b: nothing personal is left without a school, safety or legal purpose.
select is((select gender from public.profiles where id = :'leaver'), null,
  'the profile no longer carries a gender');
select is((select display_name from public.students where id = :'leaver_student'), 'Deleted student',
  'class rosters no longer carry the name');
select is((select count(*) from public.students where id = :'leaver_student'), 1::bigint,
  'the student row stays: the school''s grades and attendance hang from it');
select is((select count(*) from public.notebook_entries where owner_id = :'leaver'), 0::bigint,
  'notebook entries are deleted');
select is((select count(*) from public.study_notebooks where owner_id = :'leaver'), 0::bigint,
  'study notebooks are deleted');
select is((select count(*) from private.ai_usage where user_id = :'leaver'), 0::bigint,
  'the AI usage ledger is deleted');
select is((select count(*) from public.consent_records where user_id = :'leaver'), 1::bigint,
  'consent records are kept, for 6 years after the account (DL-057)');
select is((select count(*) from public.notifications where user_id = :'leaver'), 0::bigint,
  'notifications are deleted, as the deletion screen promises');
select is((select count(*) from public.push_devices where user_id = :'leaver'), 0::bigint,
  'push registrations are deleted, not only revoked');
select is((select count(*) from private.managed_accounts where child_id = :'leaver'), 0::bigint,
  'a managed child is no longer linked to the parent who managed it');
select is((select count(*) from public.invitations where email like 'leaver@%'), 0::bigint,
  'no invitation keeps the email');
select is((select status::text from public.invitations where token_hash = 'dl051-invite'), 'revoked',
  'an invitation still waiting for the account is revoked');
select ok((select retention_until <= now() from public.file_objects
  where id = 'de1e0000-0000-4000-8000-0000000000f1'),
  'a personal-only file is due for the retention sweep');
select is((select retention_until from public.file_objects
  where id = 'de1e0000-0000-4000-8000-0000000000f2'), null,
  'a hand-in stays: it is the school''s record');

-- A managed child goes with the parent; a held child waits for its hold.
select is((select status::text from public.profiles where id = :'kid'), 'deleted',
  'a child account the parent managed is deleted with the parent');
select is((select email from auth.users where id = :'kid'),
  'deleted+de1e0000-0000-4000-8000-000000000004@deleted.invalid', 'the child can no longer sign in');
select is((select impact_snapshot->>'cause' from public.account_deletion_requests
  where user_id = :'kid' and state = 'completed'), 'managing_guardian_deleted',
  'the child''s own request records why it was deleted');
select is((select display_name from public.profiles where id = :'held_kid'), 'Hal Kid',
  'a child under legal hold is not deleted yet');
select ok((select state = 'grace_period' and execute_after <= now() from public.account_deletion_requests
  where user_id = :'held_kid'), 'the held child''s deletion waits, due, for the hold to end');

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
