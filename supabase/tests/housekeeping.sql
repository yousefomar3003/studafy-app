-- Expired idempotency records are pruned (202609290008).
-- Transactional fixtures: this test leaves existing local users/data intact.
begin;
\set auth031_fixture_only true
\ir rls_access_seed.sql
\unset auth031_fixture_only
create extension if not exists pgtap with schema extensions;
set local search_path=public,extensions;
select plan(4);

insert into public.idempotency_records (actor_id, scope, idempotency_key, request_hash, status,
  response_status, created_at, expires_at, lease_expires_at)
values
  (:'student_user', 'v1.pgtap', 'hk-expired-done', repeat('a',64), 'completed', 200,
    now() - interval '2 days', now() - interval '1 day', null),
  (:'student_user', 'v1.pgtap', 'hk-live-done', repeat('a',64), 'completed', 200,
    now() - interval '1 hour', now() + interval '1 day', null),
  (:'student_user', 'v1.pgtap', 'hk-expired-inflight', repeat('a',64), 'reserved', null,
    now() - interval '2 days', now() - interval '1 minute', now() + interval '1 minute'),
  (:'student_user', 'v1.pgtap', 'hk-expired-abandoned', repeat('a',64), 'reserved', null,
    now() - interval '2 days', now() - interval '1 day', now() - interval '1 day');

select ok(private.prune_expired_idempotency(50000) >= 2, 'expired records are removed');
select is((select array_agg(idempotency_key order by idempotency_key) from public.idempotency_records
  where scope = 'v1.pgtap'), array['hk-expired-inflight', 'hk-live-done'],
  'live records and a record still leased to a request are kept');
select is(private.prune_expired_idempotency(50000), 0, 'a second pass finds nothing');
select ok(has_function_privilege('studafy_worker_runtime', 'private.prune_expired_idempotency(integer)', 'execute')
  and not has_function_privilege('studafy_api_runtime', 'private.prune_expired_idempotency(integer)', 'execute')
  and not has_function_privilege('authenticated', 'private.prune_expired_idempotency(integer)', 'execute'),
  'only the worker prunes');

select * from finish();
rollback;
