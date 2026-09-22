-- API-040 durable idempotency, least-privilege, and lease assertions.
-- Requires the deterministic DB-021 fixture (use api040_idempotency_seed.sql).

\set school_id '11111111-1111-4111-8111-111111111111'
\set teacher_user 'aaaa0000-0000-4000-8000-000000000001'
\set other_school_user 'eeee0000-0000-4000-8000-000000000005'

begin;
create extension if not exists pgtap with schema extensions;
set local search_path = public, extensions;
select plan(25);

delete from public.idempotency_records
where scope like 'v1.api040_test%';

select columns_are(
  'public', 'idempotency_records',
  array[
    'id', 'school_id', 'actor_id', 'scope', 'idempotency_key',
    'request_hash', 'status', 'response_status', 'response_body',
    'expires_at', 'created_at', 'updated_at', 'generation', 'lease_expires_at'
  ],
  'the durable record has generation and lease columns without dropping DB-021 columns'
);

select is(
  (select count(*) from information_schema.role_table_grants
   where grantee = 'studafy_api_runtime'),
  0::bigint,
  'idempotency adds no API runtime table grants'
);

select is(
  (select count(*) from information_schema.column_privileges
   where grantee = 'studafy_api_runtime'),
  0::bigint,
  'idempotency adds no API runtime column grants'
);

select is(
  (select count(*) from pg_class c
   join pg_namespace n on n.oid = c.relnamespace
   where c.relkind = 'S' and n.nspname in ('public', 'private')
     and (has_sequence_privilege('studafy_api_runtime', c.oid, 'USAGE')
       or has_sequence_privilege('studafy_api_runtime', c.oid, 'SELECT')
       or has_sequence_privilege('studafy_api_runtime', c.oid, 'UPDATE'))),
  0::bigint,
  'idempotency adds no API runtime sequence grants'
);

select is(
  (select array_agg(p.proname::text order by p.proname)
   from pg_proc p join pg_namespace n on n.oid = p.pronamespace
   where n.nspname = 'private'
     and p.proname like 'api_idempotency_%'
     and has_function_privilege('studafy_api_runtime', p.oid, 'execute')),
  array['api_idempotency_complete', 'api_idempotency_fail', 'api_idempotency_reserve'],
  'the API role receives exactly three narrow idempotency function grants'
);

select is(
  (select count(*) from pg_proc p join pg_namespace n on n.oid = p.pronamespace
   where n.nspname = 'private' and p.proname like 'api_idempotency_%'
     and (has_function_privilege('anon', p.oid, 'execute')
       or has_function_privilege('authenticated', p.oid, 'execute')
       or has_function_privilege('service_role', p.oid, 'execute')
       or has_function_privilege('studafy_worker_runtime', p.oid, 'execute'))),
  0::bigint,
  'no client, service, or worker role can execute idempotency functions'
);

select is(
  (select count(*) from pg_proc p join pg_namespace n on n.oid = p.pronamespace
   where n.nspname = 'private' and p.proname like 'api_idempotency_%'
     and p.prosecdef
     and p.proconfig @> array['search_path=""']),
  3::bigint,
  'all idempotency functions are SECURITY DEFINER with an empty search path'
);

select set_config('request.jwt.claim.sub', '', true);
select is(
  private.api_idempotency_reserve(null, 'v1.api040_test', 'no-actor-key-0001', repeat('a', 64)) ->> 'outcome',
  'denied',
  'the actor is required and derived from auth.uid()'
);

select set_config('request.jwt.claim.sub', :'teacher_user', true);
create temporary table api040_results (name text primary key, result jsonb);
insert into api040_results values (
  'first', private.api_idempotency_reserve(
    null, 'v1.api040_test', 'replay-key-0000001', repeat('a', 64)
  )
);

select is((select result ->> 'outcome' from api040_results where name='first'), 'reserved',
  'the first request reserves a durable key');
select is(
  (select actor_id from public.idempotency_records
   where id = ((select result ->> 'id' from api040_results where name='first')::uuid)),
  :'teacher_user'::uuid,
  'the stored actor comes from the verified database claim'
);
select is(
  private.api_idempotency_reserve(null, 'v1.api040_test', 'replay-key-0000001', repeat('a', 64)) ->> 'outcome',
  'inProgress',
  'a live reservation is serialized'
);
select is(
  private.api_idempotency_reserve(null, 'v1.api040_test', 'replay-key-0000001', repeat('b', 64)) ->> 'outcome',
  'mismatch',
  'the same key cannot name a different request'
);
select ok(
  private.api_idempotency_complete(
    ((select result ->> 'id' from api040_results where name='first')::uuid), 1, 201,
    '{"created":true}'::jsonb
  ),
  'the current generation completes once'
);
insert into api040_results values (
  'replay', private.api_idempotency_reserve(
    null, 'v1.api040_test', 'replay-key-0000001', repeat('a', 64)
  )
);
select is((select result ->> 'outcome' from api040_results where name='replay'), 'replay',
  'a completed matching request replays');
select is((select (result ->> 'responseStatus')::integer from api040_results where name='replay'), 201,
  'the completed status is replayed exactly');
select is((select result -> 'responseBody' from api040_results where name='replay'), '{"created":true}'::jsonb,
  'the bounded safe response body is replayed exactly');

insert into api040_results values (
  'bounded', private.api_idempotency_reserve(
    null, 'v1.api040_test.bound', 'bounded-key-000001', repeat('c', 64)
  )
);
select ok(
  not private.api_idempotency_complete(
    ((select result ->> 'id' from api040_results where name='bounded')::uuid), 1, 200,
    jsonb_build_object('value', repeat('x', 70000))
  ),
  'oversized response bodies are never persisted'
);

select set_config('request.jwt.claim.sub', :'other_school_user', true);
select is(
  private.api_idempotency_reserve(null, 'v1.api040_test', 'replay-key-0000001', repeat('a', 64)) ->> 'outcome',
  'reserved',
  'the same operation and key are isolated by actor'
);
select is(
  private.api_idempotency_reserve(:'school_id', 'v1.api040_test', 'tenant-key-0000001', repeat('d', 64)) ->> 'outcome',
  'denied',
  'a client cannot reserve inside a tenant without active membership'
);

select set_config('request.jwt.claim.sub', :'teacher_user', true);
insert into api040_results values (
  'lease1', private.api_idempotency_reserve(
    null, 'v1.api040_test.lease', 'lease-key-00000001', repeat('e', 64), 86400, 15
  )
);
update public.idempotency_records set lease_expires_at = now() - interval '1 second'
where id = ((select result ->> 'id' from api040_results where name='lease1')::uuid);
insert into api040_results values (
  'lease2', private.api_idempotency_reserve(
    null, 'v1.api040_test.lease', 'lease-key-00000001', repeat('e', 64), 86400, 15
  )
);
select is((select (result ->> 'generation')::bigint from api040_results where name='lease2'), 2::bigint,
  'an expired lease is taken over with a new generation');
select ok(
  not private.api_idempotency_complete(
    ((select result ->> 'id' from api040_results where name='lease1')::uuid), 1, 200, '{}'::jsonb
  ),
  'a stale generation cannot complete after takeover'
);

insert into api040_results values (
  'failed1', private.api_idempotency_reserve(
    null, 'v1.api040_test.fail', 'failure-key-000001', repeat('f', 64)
  )
);
select ok(
  private.api_idempotency_fail(
    ((select result ->> 'id' from api040_results where name='failed1')::uuid), 1
  ),
  'a failed execution releases its reservation'
);
select is(
  private.api_idempotency_reserve(null, 'v1.api040_test.fail', 'failure-key-000001', repeat('f', 64)) ->> 'generation',
  '2',
  'a failed key is reservable by a new generation'
);

insert into public.idempotency_records (
  id, actor_id, scope, idempotency_key, request_hash, status,
  created_at, expires_at, lease_expires_at
) values (
  'a0400000-0000-4000-8000-000000000001', :'teacher_user',
  'v1.api040_test.expired', 'expired-key-000001', repeat('1', 64), 'reserved',
  now() - interval '2 days', now() - interval '1 day', now() - interval '1 day'
);
insert into api040_results values (
  'expired', private.api_idempotency_reserve(
    null, 'v1.api040_test.expired', 'expired-key-000001', repeat('1', 64)
  )
);
select isnt((select result ->> 'id' from api040_results where name='expired'),
  'a0400000-0000-4000-8000-000000000001',
  'only the exact expired key is opportunistically replaced');

select is(
  private.api_idempotency_reserve(null, 'v1.api040_test', 'short', repeat('a', 64)) ->> 'outcome',
  'invalid',
  'invalid key bounds fail closed'
);

select * from finish();
rollback;
