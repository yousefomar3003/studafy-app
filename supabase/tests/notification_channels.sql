-- DL-053: in-app notifications fan out to push for people with a device
-- (unless they opt out) and to email only for people who opted in; senders
-- get addresses and templates, never content; failures retry then stop.
begin;
create extension if not exists pgtap with schema extensions;
set local search_path=public,extensions;
select plan(37);

\set school_id '11111111-1111-4111-8111-111111111111'
\set teacher_user 'aaaa0000-0000-4000-8000-000000000001'
\set guardian_user 'cccc0000-0000-4000-8000-000000000003'
\set student_user 'bbbb0000-0000-4000-8000-000000000002'

insert into public.push_devices (user_id, platform, token) values
  (:'guardian_user', 'android', repeat('g', 40)),
  (:'student_user', 'ios', repeat('s', 40));
insert into public.notification_preferences (user_id, school_id, channel, category, enabled) values
  (:'teacher_user', null, 'email', 'communications', true),
  (:'student_user', null, 'push', 'communications', false);

select private.notify_recipient(:'school_id', r, 'communications.message_sent',
  jsonb_build_object('conversationId', gen_random_uuid()), 'dl053-evt', 'dl053:' || r)
from unnest(array[:'teacher_user', :'guardian_user', :'student_user']::uuid[]) r;

select ok(not has_function_privilege('studafy_api_runtime', 'private.channel_claim(text,integer)', 'execute'),
  'the API cannot read recipient addresses');
-- DL-070: the worker fans out only to channels it has a sender for.
select ok(has_function_privilege('studafy_worker_runtime', 'private.channel_fanout(integer,text[])', 'execute'),
  'the worker may fan out per channel');
select ok(not has_function_privilege('studafy_api_runtime', 'private.channel_fanout(integer,text[])', 'execute'),
  'the API may not fan out');
select is(private.channel_fanout(1000, array[]::text[]), 0, 'with no channel configured nothing is fanned out');
select throws_ok($$select private.channel_fanout(10, array['sms'])$$, '22023', 'Unknown channel',
  'an unknown channel is refused');
select ok(private.channel_fanout(1000, array['email']) >= 1, 'email only: the opted-in email delivery is created');
select is((select count(*) from public.notification_deliveries d join public.notification_outbox o on o.id = d.outbox_id
  where o.source_event_id = 'dl053-evt' and d.channel = 'push'), 0::bigint,
  'email only: no push delivery is created');
select ok(private.channel_fanout(1000) >= 1, 'the fan-out creates the remaining channel deliveries');

select is((select count(*) from public.notification_deliveries d join public.notification_outbox o on o.id = d.outbox_id
  where o.source_event_id = 'dl053-evt' and d.channel = 'push' and d.recipient_id = :'guardian_user'), 1::bigint,
  'a person with a device gets push by default');
select is((select count(*) from public.notification_deliveries d join public.notification_outbox o on o.id = d.outbox_id
  where o.source_event_id = 'dl053-evt' and d.channel = 'email' and d.recipient_id = :'guardian_user'), 0::bigint,
  'email is off unless the person opted in');
select is((select count(*) from public.notification_deliveries d join public.notification_outbox o on o.id = d.outbox_id
  where o.source_event_id = 'dl053-evt' and d.channel = 'email' and d.recipient_id = :'teacher_user'), 1::bigint,
  'a person who opted in to email for the category gets email');
select is((select count(*) from public.notification_deliveries d join public.notification_outbox o on o.id = d.outbox_id
  where o.source_event_id = 'dl053-evt' and d.channel = 'push' and d.recipient_id = :'student_user'), 0::bigint,
  'a person who turned push off for the category gets none');
select is(private.channel_fanout(1000), 0, 'running the fan-out again creates nothing new');

create temporary table claimed(channel text, j jsonb) on commit drop;
insert into claimed select 'push', private.channel_claim('push', 100);
insert into claimed select 'email', private.channel_claim('email', 100);
select ok((select j::text like '%' || repeat('g', 40) || '%' from claimed where channel = 'push'),
  'a push job carries the device token');
select ok((select j::text like '%seed.teacher@%' from claimed where channel = 'email'),
  'an email job carries the address');
select ok((select not (j::text like '%conversationId%') from claimed where channel = 'push'),
  'a job carries no notification payload');
-- A tapped push opens its notification: the job names the recipient's
-- in-app delivery, the id the app's notifications list uses.
select is((select e->>'notificationId' from claimed, jsonb_array_elements(j) e
    where channel = 'push' and e->'tokens' ? repeat('g', 40)),
  (select d.id::text from public.notification_deliveries d join public.notification_outbox o on o.id = d.outbox_id
    where o.source_event_id = 'dl053-evt' and d.channel = 'in_app' and d.recipient_id = :'guardian_user'),
  'a push job names the in-app notification a tap opens');
select ok((select bool_and(e->'notificationId' = 'null'::jsonb) from claimed, jsonb_array_elements(j) e
    where channel = 'email'),
  'an email job names no notification');
select is(jsonb_array_length(private.channel_claim('push', 100)), 0, 'a leased delivery is not claimed twice');

select is(private.channel_finish(
  (select (e->>'deliveryId')::bigint from claimed, jsonb_array_elements(j) e where channel = 'email' limit 1),
  true, null, false, 'provider-1'), 'sent', 'a delivered email is marked sent');
select is(private.channel_finish(
  (select (e->>'deliveryId')::bigint from claimed, jsonb_array_elements(j) e where channel = 'push' limit 1),
  false, 'UNREGISTERED', true, null), 'failed', 'a terminal push failure stops retrying');
-- DL-082: a phone signed in to several accounts is registered for each. The
-- same token is live for several accounts at once; unregistering removes
-- only the caller's row (and those of the child accounts the caller
-- manages, which leave the phone with them); a dead token goes for all.
create function pg_temp.push_command(p_actor uuid, p_operation text, p_token text)
returns text language plpgsql as $$
declare reservation jsonb;
begin
  perform set_config('request.jwt.claim.sub', p_actor::text, true);
  perform set_config('studafy.school_id', '', true);
  perform set_config('studafy.request_id', 'dl082-' || gen_random_uuid(), true);
  reservation := private.api_idempotency_reserve(
    null, 'v1.' || p_operation, 'dl082-' || gen_random_uuid(), repeat('b', 64));
  return private.api042_command(p_operation, null,
    jsonb_build_object('responseStatus', 200, 'body',
      jsonb_build_object('platform', 'ios', 'token', p_token)),
    (reservation->>'id')::uuid, (reservation->>'generation')::bigint)->>'outcome';
end;
$$;
create function pg_temp.live_on(p_token text)
returns uuid[] language sql as $$
  select coalesce(array_agg(user_id order by user_id), '{}'::uuid[])
  from public.push_devices where token = p_token and revoked_at is null;
$$;

\set shared_token 'dl082-shared-phone-token-0000000000000000'
select is(pg_temp.push_command(:'teacher_user', 'registerPushDevice', :'shared_token'), 'ok',
  'the first account on the phone registers');
select is(pg_temp.push_command(:'guardian_user', 'registerPushDevice', :'shared_token'), 'ok',
  'a second account on the same phone registers');
select is(pg_temp.live_on(:'shared_token'), array[:'teacher_user', :'guardian_user']::uuid[],
  'two accounts share the token and both stay registered');
select is(pg_temp.push_command(:'teacher_user', 'registerPushDevice', :'shared_token'), 'ok',
  'switching back registers the first account again');
select is((select count(*) from public.push_devices where token = :'shared_token'
    and user_id = :'teacher_user' and revoked_at is null), 1::bigint,
  'registering again keeps one row per account');
select is(pg_temp.push_command(:'teacher_user', 'unregisterPushDevice', :'shared_token'), 'ok',
  'one account signs out of the phone');
select is(pg_temp.live_on(:'shared_token'), array[:'guardian_user']::uuid[],
  'only the account that signed out loses its registration');

-- A parent's phone is their child account's phone: the child has no phone
-- of their own and is only ever entered through the parent.
insert into private.managed_accounts(child_id, guardian_id)
  values (:'student_user', :'guardian_user');
-- (Each command is asserted, not just run: a bare row would read as TAP.)
select is(pg_temp.push_command(:'teacher_user', 'registerPushDevice', :'shared_token'), 'ok',
  'the first account registers again');
select is(pg_temp.push_command(:'guardian_user', 'registerPushDevice', :'shared_token'), 'ok',
  'the parent registers again');
-- Ordered by id: teacher aaaa..., student bbbb..., guardian cccc....
select is(pg_temp.live_on(:'shared_token'),
  array[:'teacher_user', :'student_user', :'guardian_user']::uuid[],
  'a parent registering covers the child accounts they manage');
select is(pg_temp.push_command(:'guardian_user', 'unregisterPushDevice', :'shared_token'), 'ok',
  'the parent signs out of the phone');
select is(pg_temp.live_on(:'shared_token'), array[:'teacher_user']::uuid[],
  'the parent signing out takes their child accounts off the phone, and nobody else');
select is(pg_temp.push_command(:'guardian_user', 'registerPushDevice', :'shared_token'), 'ok',
  'the parent signs in on the phone again');
select is(private.push_device_revoke_token(:'shared_token'), 3,
  'a token the provider reports dead is revoked for every account on the phone');

select is(private.push_device_revoke_token(repeat('g', 40)), 1, 'an unregistered token is revoked');

update public.profiles set status = 'deleted' where id = :'student_user';
select is((select count(*) from public.push_devices where user_id = :'student_user' and revoked_at is null), 0::bigint,
  'a deleted account loses its push devices');

select * from finish();
rollback;
