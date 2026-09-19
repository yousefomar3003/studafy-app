-- DL-053: in-app notifications fan out to push for people with a device
-- (unless they opt out) and to email only for people who opted in; senders
-- get addresses and templates, never content; failures retry then stop.
begin;
create extension if not exists pgtap with schema extensions;
set local search_path=public,extensions;
select plan(15);

\set school_id '11111111-1111-1111-1111-111111111111'
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
select ok(private.channel_fanout(1000) >= 2, 'the fan-out creates channel deliveries');

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
select is(jsonb_array_length(private.channel_claim('push', 100)), 0, 'a leased delivery is not claimed twice');

select is(private.channel_finish(
  (select (e->>'deliveryId')::bigint from claimed, jsonb_array_elements(j) e where channel = 'email' limit 1),
  true, null, false, 'provider-1'), 'sent', 'a delivered email is marked sent');
select is(private.channel_finish(
  (select (e->>'deliveryId')::bigint from claimed, jsonb_array_elements(j) e where channel = 'push' limit 1),
  false, 'UNREGISTERED', true, null), 'failed', 'a terminal push failure stops retrying');
select is(private.push_device_revoke_token(repeat('g', 40)), 1, 'an unregistered token is revoked');

update public.profiles set status = 'deleted' where id = :'student_user';
select is((select count(*) from public.push_devices where user_id = :'student_user' and revoked_at is null), 0::bigint,
  'a deleted account loses its push devices');

select * from finish();
rollback;
