-- Why a dispatcher could not record its BullMQ job id (202610160030): the
-- notification outbox's and the billing events' `_v2` record functions answer
-- 'recorded', 'already_finished' (the row left `processing`: the job finished
-- it first, the usual race) or 'lease_lost' (another dispatcher's lease, or
-- no row). Transactional fixtures: leaves local data intact.
begin;
create extension if not exists pgtap with schema extensions;
set local search_path = public, extensions;
select plan(19);

\set school 'f0616000-0000-4000-8000-000000000001'
insert into public.schools (id, name, status)
values (:'school', 'Outbox record school', 'active');

create or replace function pg_temp.outbox_row(p_key text, p_state public.outbox_state, p_lease text)
returns bigint language sql as $$
  insert into public.notification_outbox(
    school_id, source_event_id, idempotency_key, channel, template_key,
    audience, state, lease_token, lease_until)
  values ('f0616000-0000-4000-8000-000000000001', p_key, p_key, 'in_app',
    'school_admin.membership_granted',
    jsonb_build_object('schoolId', 'f0616000-0000-4000-8000-000000000001'::uuid),
    p_state, p_lease, case when p_lease is null then null else now() + interval '120 seconds' end)
  returning id;
$$;
create or replace function pg_temp.store_event(p_hash text, p_state public.outbox_state, p_lease text)
returns bigint language sql as $$
  insert into public.store_events(platform, environment, payload_hash, state, lease_token, lease_until)
  values ('play_store', 'synthetic', p_hash, p_state, p_lease,
    case when p_lease is null then null else now() + interval '120 seconds' end)
  returning id;
$$;
create temporary table ids(name text primary key, id bigint);

-- ---------------------------------------------------------------------------
-- Notification outbox.
-- ---------------------------------------------------------------------------
insert into ids values
  ('mine', pg_temp.outbox_row('rec-mine', 'processing', 'worker-a')),
  ('finished', pg_temp.outbox_row('rec-finished', 'processing', 'worker-a')),
  ('dead', pg_temp.outbox_row('rec-dead', 'processing', 'worker-a')),
  ('handed_back', pg_temp.outbox_row('rec-retry', 'retry', null));

select is(private.api061_record_dispatched_v2('worker-a', (select id from ids where name = 'mine'),
    'outbox-' || (select id from ids where name = 'mine')),
  'recorded', 'the dispatcher holding the lease records its job id');
select ok((select bullmq_job_id = 'outbox-' || id and dispatched_at is not null
    and lease_until > now() + interval '60 seconds'
    from public.notification_outbox where id = (select id from ids where name = 'mine')),
  'the id is recorded and the lease extended');
select is(private.api061_record_dispatched_v2('worker-b', (select id from ids where name = 'mine'), 'outbox-x'),
  'lease_lost', 'another dispatcher''s lease: lease_lost');
select is((select bullmq_job_id from public.notification_outbox where id = (select id from ids where name = 'mine')),
  'outbox-' || (select id from ids where name = 'mine'), 'and nothing is overwritten');

-- The race this is about: the job runs and finishes the row before the
-- dispatcher records the id.
select is(private.api061_finish_notification((select id from ids where name = 'finished')), 'completed',
  'the processor finishes the row first');
select is(private.api061_record_dispatched_v2('worker-a', (select id from ids where name = 'finished'),
    'outbox-' || (select id from ids where name = 'finished')),
  'already_finished', 'a completed row: already_finished, not a lost lease');
select is((select bullmq_job_id from public.notification_outbox where id = (select id from ids where name = 'finished')),
  null, 'a finished row is not written to');
select is(private.api061_fail_dispatch((select id from ids where name = 'dead'), 'PGTAP'), true,
  'another row is dead-lettered first');
select is(private.api061_record_dispatched_v2('worker-a', (select id from ids where name = 'dead'), 'outbox-y'),
  'already_finished', 'a dead letter: already_finished');
select is(private.api061_record_dispatched_v2('worker-a', (select id from ids where name = 'handed_back'), 'outbox-z'),
  'already_finished', 'a row handed back for a retry has left processing too');
select is(private.api061_record_dispatched_v2('worker-a', -1, 'outbox-gone'),
  'lease_lost', 'no row: lease_lost');
select throws_ok($$select private.api061_record_dispatched_v2('', 1, 'outbox-1')$$,
  'OPS061_INVALID_DISPATCH_RECORD', 'arguments are still validated');

-- ---------------------------------------------------------------------------
-- Billing events.
-- ---------------------------------------------------------------------------
insert into ids values
  ('event_mine', pg_temp.store_event(repeat('1', 64), 'processing', 'pay-a')),
  ('event_done', pg_temp.store_event(repeat('2', 64), 'completed', 'pay-a')),
  ('event_retry', pg_temp.store_event(repeat('3', 64), 'retry', 'pay-a'));

select is(private.billing_record_event_dispatched_v2('pay-b', (select id from ids where name = 'event_mine'), 'billing-event-x'),
  'lease_lost', 'billing: another dispatcher''s lease');
select is(private.billing_record_event_dispatched_v2('pay-a', (select id from ids where name = 'event_mine'),
    'billing-event-' || (select id from ids where name = 'event_mine')),
  'recorded', 'billing: the lease holder records its job id');
select is(private.billing_record_event_dispatched_v2('pay-a', (select id from ids where name = 'event_done'), 'billing-event-y'),
  'already_finished', 'billing: a completed event');
select is(private.billing_record_event_dispatched_v2('pay-a', (select id from ids where name = 'event_retry'), 'billing-event-z'),
  'already_finished', 'billing: an event the processor handed back for a retry');
select is(private.billing_record_event_dispatched_v2('pay-a', -1, 'billing-event-gone'),
  'lease_lost', 'billing: no event');

-- ---------------------------------------------------------------------------
-- Grants: the worker runtime only, like the functions they sit beside.
-- ---------------------------------------------------------------------------
select ok(has_function_privilege('studafy_worker_runtime', 'private.api061_record_dispatched_v2(text, bigint, text)', 'execute')
  and has_function_privilege('studafy_worker_runtime', 'private.billing_record_event_dispatched_v2(text, bigint, text)', 'execute'),
  'the worker runtime can record dispatches');
select ok(not has_function_privilege('studafy_api_runtime', 'private.api061_record_dispatched_v2(text, bigint, text)', 'execute')
  and not has_function_privilege('authenticated', 'private.api061_record_dispatched_v2(text, bigint, text)', 'execute')
  and not has_function_privilege('service_role', 'private.billing_record_event_dispatched_v2(text, bigint, text)', 'execute')
  and not has_function_privilege('anon', 'private.billing_record_event_dispatched_v2(text, bigint, text)', 'execute'),
  'nobody else can');

select * from finish();
rollback;
