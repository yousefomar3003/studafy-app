-- The inactive-account warning by email (202610150091, DL-057, privacy
-- policy §10): who is warned and emailed, once, whatever their email
-- preferences; and deletion only 30 days or more after the warning reached
-- them. Transactional fixtures: leaves local data intact.
begin;
\set auth031_fixture_only true
\ir rls_access_seed.sql
\unset auth031_fixture_only
create extension if not exists pgtap with schema extensions;
set local search_path=public,extensions;
select plan(42);

\set idle_student 'f0570000-0000-4000-8000-000000000002'
\set idle_loner 'f0570000-0000-4000-8000-000000000003'
\set idle_parent 'f0570000-0000-4000-8000-000000000004'
\set idle_child 'f0570000-0000-4000-8000-000000000005'
\set idle_nomail 'f0570000-0000-4000-8000-000000000006'
\set active_user 'f0570000-0000-4000-8000-000000000007'

insert into auth.users (id, email, aud, role, created_at, updated_at, last_sign_in_at,
  instance_id, raw_app_meta_data, raw_user_meta_data)
select u.id::uuid, u.email, 'authenticated', 'authenticated',
  now() - u.age, now() - u.age, now() - u.age,
  '00000000-0000-0000-0000-000000000000', '{}'::jsonb,
  jsonb_build_object('full_name', 'Warning ' || u.n)
from (values
  (:'idle_student', 'student', 'idle.student@synthetic.studafy.test', interval '23 months 5 days'),
  (:'idle_loner', 'loner', 'idle.loner@synthetic.studafy.test', interval '23 months 5 days'),
  (:'idle_parent', 'parent', 'idle.parent@synthetic.studafy.test', interval '23 months 5 days'),
  (:'idle_child', 'child', null, interval '23 months 5 days'),
  (:'idle_nomail', 'no address', null, interval '23 months 5 days'),
  (:'active_user', 'active', 'active.user@synthetic.studafy.test', interval '3 months')
) as u(id, n, email, age);
update public.profiles set locale = 'ar' where id = :'idle_loner';
insert into public.students (school_id, user_id, studafy_id, display_name, provisional, created_by)
values (:'school_id', :'idle_student', 'STU-WARN-0002', 'Idle student', false, :'teacher_user');
insert into private.managed_accounts (child_id, guardian_id) values (:'idle_child', :'idle_parent');
-- The student turned `account` email on; the loner turned it off.
insert into public.notification_preferences (user_id, school_id, channel, category, enabled) values
  (:'idle_student', null, 'email', 'account', true),
  (:'idle_loner', null, 'email', 'account', false);

create or replace function pg_temp.warning(p_user uuid) returns private.inactive_account_warnings
language sql as $$ select * from private.inactive_account_warnings where user_id = p_user $$;
create or replace function pg_temp.claimed(p_jobs jsonb) returns text language sql as $$
  select coalesce(string_agg(j->>'userId', ',' order by j->>'userId'), '')
  from jsonb_array_elements(p_jobs) j;
$$;
create temporary table claim(n integer, jobs jsonb);

-- ---------------------------------------------------------------------------
-- Who is warned.
-- ---------------------------------------------------------------------------
select is(private.retention_inactive_accounts(100)->>'warned', '4',
  'the student, the person with no school, the parent and the one with no address are warned');
select ok((pg_temp.warning(:'idle_student')).notified_school_id = :'school_id',
  'the student is warned in the app, in their school');
select is((pg_temp.warning(:'idle_loner')).notified_school_id, null,
  'someone with no school is warned too, with no in-app channel');
select ok(pg_temp.warning(:'idle_child') is null,
  'a managed child is never warned on their own');
select ok(pg_temp.warning(:'active_user') is null, 'an active account is not warned');
select is(private.retention_inactive_accounts(100)->>'warned', '0', 'a warning is given once');
select is(private.inactive_warning_email_pending(), 4, 'four warnings wait for an email');

-- The general fan-out does not email the warning, even to someone who turned
-- `account` email on: the warning email goes only through the claim below.
select private.channel_fanout(1000);
select ok(not exists (select 1 from public.notification_deliveries d
    join public.notification_outbox o on o.id = d.outbox_id
    where o.template_key = 'account.inactive_deletion_warning' and d.channel = 'email'),
  'the fan-out leaves the warning email to the retention worker');

-- ---------------------------------------------------------------------------
-- The email: claimed whatever the preferences, sent once.
-- ---------------------------------------------------------------------------
insert into claim select 1, private.inactive_warning_email_claim(20);
select is(pg_temp.claimed((select jobs from claim where n = 1)),
  :'idle_student' || ',' || :'idle_loner' || ',' || :'idle_parent' || ',' || :'idle_nomail',
  'every warned person is due an email, with or without a school');
select is((select j->>'email' from claim, jsonb_array_elements(jobs) j
    where n = 1 and j->>'userId' = :'idle_loner'),
  'idle.loner@synthetic.studafy.test', 'email off for `account` does not stop the warning email');
select is((select j->>'locale' from claim, jsonb_array_elements(jobs) j
    where n = 1 and j->>'userId' = :'idle_loner'), 'ar', 'in the person''s language');
select is((select j->>'email' from claim, jsonb_array_elements(jobs) j
    where n = 1 and j->>'userId' = :'idle_nomail'), null, 'no address is handed over as none');
select is((pg_temp.warning(:'idle_loner')).email_attempts, 1, 'the claim counts an attempt');
select is(pg_temp.claimed(private.inactive_warning_email_claim(20)), '',
  'a claimed email is not handed to a second worker');

select is(private.inactive_warning_email_finish(:'idle_loner', true, null, false, 'resend-1'), 'sent',
  'the provider accepted the email');
select ok((pg_temp.warning(:'idle_loner')).emailed_at is not null, 'emailed_at is recorded');
select is((pg_temp.warning(:'idle_loner')).email_provider_message_id, 'resend-1',
  'with the provider''s message id');
select is((select count(*)::int from public.audit_events
    where action = 'inactive_account_warning_emailed' and entity_id = :'idle_loner'), 1,
  'and an audit record');
select is(private.inactive_warning_email_finish(:'idle_loner', true, null, false, 'resend-2'), 'unchanged',
  'reporting it again changes nothing');
select is((pg_temp.warning(:'idle_loner')).email_provider_message_id, 'resend-1',
  'the first send stands');

select is(private.inactive_warning_email_finish(:'idle_parent', true, null, false, 'resend-3'), 'sent',
  'the parent is emailed');
select is(private.inactive_warning_email_undeliverable(), 0,
  'nothing is undeliverable while every email may still go');
select is(private.inactive_warning_email_finish(:'idle_nomail', false, 'NO_ADDRESS', true, null), 'failed',
  'no address stops at once');
select is(private.inactive_warning_email_undeliverable(), 1,
  'a person with no school whose warning cannot be emailed is counted for the operator (202610160030)');
select is(private.inactive_warning_email_finish(:'idle_student', false, 'PROVIDER_UNAVAILABLE_503', false, null),
  'retry', 'a provider outage is retried');
select is(pg_temp.claimed(private.inactive_warning_email_claim(20)), '',
  'not before its backoff');
update private.inactive_account_warnings set email_claimed_at = now() - interval '1 hour'
  where user_id in (:'idle_student', :'idle_nomail', :'idle_loner');
select is(pg_temp.claimed(private.inactive_warning_email_claim(20)), :'idle_student',
  'after it only the retry is due: never a sent email, never a refused one');
select is(private.inactive_warning_email_pending(), 1, 'one warning still waits for its email');

-- Someone with a school warned in the app over a week ago is not emailed
-- late (the email would promise more time than is left).
update private.inactive_account_warnings
  set email_claimed_at = now() - interval '1 day', warned_at = now() - interval '8 days'
  where user_id = :'idle_student';
select is(pg_temp.claimed(private.inactive_warning_email_claim(20)), '',
  'an in-app warning more than a week old is not followed by a late email');

-- ---------------------------------------------------------------------------
-- Deletion counts from when the warning reached the person.
-- ---------------------------------------------------------------------------
update auth.users set last_sign_in_at = now() - interval '24 months 1 day',
  created_at = now() - interval '24 months 1 day'
where id in (:'idle_student', :'idle_loner', :'idle_parent', :'idle_child', :'idle_nomail');
update private.inactive_account_warnings set warned_at = now() - interval '40 days',
  last_active_at = now() - interval '24 months 1 day';
update private.inactive_account_warnings set emailed_at = now() - interval '3 days'
  where user_id = :'idle_loner';
update private.inactive_account_warnings set emailed_at = now() - interval '17 days'
  where user_id = :'idle_parent';

select is(private.retention_inactive_accounts(100)->>'deletion_requested', '2',
  'deletion is requested for the student and the parent');
select ok(exists (select 1 from public.account_deletion_requests
    where user_id = :'idle_student' and state = 'grace_period'),
  'the student: warned in the app 40 days ago');
select ok((select (impact_snapshot->>'emailedAt') is not null
    and impact_snapshot->>'cause' = 'inactive_account'
    from public.account_deletion_requests where user_id = :'idle_parent'),
  'the parent, with no school: emailed 17 days ago, and the request says so');
select ok(not exists (select 1 from public.account_deletion_requests where user_id = :'idle_loner'),
  'emailed only 3 days ago: not yet, although warned 40 days ago');
select ok(not exists (select 1 from public.account_deletion_requests where user_id = :'idle_nomail'),
  'never reached: never deleted');
select ok(not exists (select 1 from public.account_deletion_requests where user_id = :'idle_child'),
  'the managed child gets no request of their own; it goes with the parent''s deletion');

update private.inactive_account_warnings set emailed_at = now() - interval '16 days 1 minute'
  where user_id = :'idle_loner';
select is(private.retention_inactive_accounts(100)->>'deletion_requested', '1',
  '16 days after the email, the person with no school is in the same schedule');
select ok((select execute_after >= (pg_temp.warning(:'idle_loner')).emailed_at + interval '30 days'
    from public.account_deletion_requests where user_id = :'idle_loner'),
  'and is deleted 30 days or more after the email');
select is(private.inactive_warning_email_pending(), 0,
  'nobody with a deletion request is emailed the warning again');
select is(private.inactive_warning_email_undeliverable(), 1,
  'the account that was never reached is kept, and still counted');
-- Only people with no school: someone warned in the app was reached.
update private.inactive_account_warnings set notified_school_id = :'school_id'
  where user_id = :'idle_nomail';
select is(private.inactive_warning_email_undeliverable(), 0,
  'a failed email to someone warned in the app is not counted');

-- ---------------------------------------------------------------------------
-- Only the worker sends.
-- ---------------------------------------------------------------------------
select ok(has_function_privilege('studafy_worker_runtime', 'private.inactive_warning_email_claim(integer)', 'execute')
  and has_function_privilege('studafy_worker_runtime',
    'private.inactive_warning_email_finish(uuid,boolean,text,boolean,text)', 'execute')
  and has_function_privilege('studafy_worker_runtime', 'private.inactive_warning_email_pending()', 'execute')
  and has_function_privilege('studafy_worker_runtime', 'private.channel_fanout(integer)', 'execute')
  and has_function_privilege('studafy_worker_runtime', 'private.retention_inactive_accounts(integer)', 'execute')
  and has_function_privilege('studafy_worker_runtime', 'private.inactive_warning_email_undeliverable()', 'execute'),
  'the worker claims and finishes warning emails');
select ok(not has_function_privilege('studafy_api_runtime', 'private.inactive_warning_email_claim(integer)', 'execute')
  and not has_function_privilege('authenticated', 'private.inactive_warning_email_claim(integer)', 'execute')
  and not has_function_privilege('service_role',
    'private.inactive_warning_email_finish(uuid,boolean,text,boolean,text)', 'execute')
  and not has_function_privilege('studafy_worker_runtime',
    'private.inactive_warning_email_due(private.inactive_account_warnings)', 'execute')
  and not has_function_privilege('studafy_api_runtime', 'private.inactive_warning_email_undeliverable()', 'execute')
  and not has_function_privilege('authenticated', 'private.inactive_warning_email_undeliverable()', 'execute'),
  'nobody else does');

select * from finish();
rollback;
