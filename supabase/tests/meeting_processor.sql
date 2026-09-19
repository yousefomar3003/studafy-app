-- DL-052: pending meetings are leased to one worker, scheduled with an https
-- link, retried then failed with the organiser told, and a cancelled
-- meeting's provider event is withdrawn.
begin;
create extension if not exists pgtap with schema extensions;
set local search_path=public,extensions;
select plan(17);

\set school_id '11111111-1111-1111-1111-111111111111'
\set classroom_id 'abcd0000-0000-4000-8000-000000000007'
\set teacher_user 'aaaa0000-0000-4000-8000-000000000001'
\set guardian_user 'cccc0000-0000-4000-8000-000000000003'

insert into public.meetings (id, school_id, classroom_id, title, starts_at, ends_at, audience, state, created_by) values
  ('4ee70000-0000-4000-8000-000000000001', :'school_id', :'classroom_id', 'Parent evening', now() + interval '2 days', now() + interval '2 days 1 hour', 'guardians', 'pending', :'teacher_user'),
  ('4ee70000-0000-4000-8000-000000000002', :'school_id', :'classroom_id', 'Flaky', now() + interval '2 days', now() + interval '2 days 1 hour', 'guardians', 'pending', :'teacher_user'),
  ('4ee70000-0000-4000-8000-000000000003', :'school_id', :'classroom_id', 'Too late', now() - interval '1 hour', now() + interval '1 hour', 'guardians', 'pending', :'teacher_user');
insert into public.meeting_deliveries (school_id, meeting_id, recipient_id, state) values
  (:'school_id', '4ee70000-0000-4000-8000-000000000001', :'guardian_user', 'queued'),
  (:'school_id', '4ee70000-0000-4000-8000-000000000002', :'guardian_user', 'queued');

select ok(has_function_privilege('studafy_worker_runtime', 'private.meeting_claim(integer)', 'execute'),
  'the worker can claim meetings');
select ok(not has_function_privilege('studafy_api_runtime', 'private.meeting_finish_schedule(uuid,text,text)', 'execute'),
  'the API cannot mark a meeting scheduled');

create temporary table jobs(j jsonb) on commit drop;
insert into jobs select private.meeting_claim(50);

select is((select state from public.meetings where id = '4ee70000-0000-4000-8000-000000000003'), 'failed',
  'a pending meeting whose start passed fails instead of being scheduled');
select ok((select j::text like '%4ee70000-0000-4000-8000-000000000001%' from jobs),
  'a due pending meeting is claimed');
select ok((select (e->>'action') = 'schedule' and (e->'attendees')::text like '%seed.guardian@%'
  from jobs, jsonb_array_elements(j) e where e->>'meetingId' = '4ee70000-0000-4000-8000-000000000001'),
  'a schedule job carries the attendee emails');
select is(jsonb_array_length(private.meeting_claim(50)), 0,
  'a leased meeting is not claimed twice');

select throws_ok($$ select private.meeting_finish_schedule('4ee70000-0000-4000-8000-000000000001', 'evt-1', 'http://insecure.example') $$,
  '22000', null, 'a non-https meeting link is refused');
select is(private.meeting_finish_schedule('4ee70000-0000-4000-8000-000000000001', 'evt-1', 'https://meet.example/abc'),
  'scheduled', 'the meeting is scheduled');
select is((select state from public.meeting_deliveries where meeting_id = '4ee70000-0000-4000-8000-000000000001'), 'sent',
  'its deliveries are marked sent');
select is((select count(*) from public.notification_outbox where template_key = 'meetings.scheduled'
  and recipient_id = :'guardian_user'), 1::bigint, 'the recipient is notified in the app');
select ok((select not (payload::text like '%meet.example%') from public.notification_outbox
  where template_key = 'meetings.scheduled' limit 1), 'the notification carries no link or title');

-- Retries then fails, telling the organiser.
select is(private.meeting_fail('4ee70000-0000-4000-8000-000000000002', 'PROVIDER_UNAVAILABLE', false), 'retry',
  'a transient provider failure retries');
update public.meetings set processing_attempts = 4 where id = '4ee70000-0000-4000-8000-000000000002';
select is(private.meeting_fail('4ee70000-0000-4000-8000-000000000002', 'PROVIDER_UNAVAILABLE', false), 'failed',
  'the fifth failure is terminal');
select is((select count(*) from public.notification_outbox where template_key = 'meetings.failed'
  and recipient_id = :'teacher_user'), 2::bigint, 'the organiser is told about each failed meeting');

-- Cancelling a scheduled meeting withdraws the provider event.
update public.meetings set state = 'cancelled', next_attempt_at = now()
  where id = '4ee70000-0000-4000-8000-000000000001';
delete from jobs;
insert into jobs select private.meeting_claim(50);
select ok((select (e->>'action') = 'cancel' and e->>'calendarEventId' = 'evt-1'
  from jobs, jsonb_array_elements(j) e where e->>'meetingId' = '4ee70000-0000-4000-8000-000000000001'),
  'a cancelled scheduled meeting yields a cancel job for its event');
select is(private.meeting_finish_cancel('4ee70000-0000-4000-8000-000000000001'), 'withdrawn',
  'the provider event is recorded as withdrawn');
update public.meetings set next_attempt_at = now() where id = '4ee70000-0000-4000-8000-000000000001';
select is(jsonb_array_length(private.meeting_claim(50)), 0, 'a withdrawn event is never cancelled again');

select * from finish();
rollback;
