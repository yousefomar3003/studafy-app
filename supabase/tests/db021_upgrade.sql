begin;
create extension if not exists pgtap with schema extensions;
set local search_path = public, extensions;
select plan(8);

select is((select count(*) from public.schools where id='b0211000-0000-4000-8000-000000000001'),1::bigint,
  'school survives the DB-021 policy/grant upgrade');
select is((select count(*) from public.memberships where school_id='b0211000-0000-4000-8000-000000000001'),2::bigint,
  'membership rows and identifiers survive the DB-021 upgrade');
select is((select count(*) from public.enrollments where classroom_id='b0215000-0000-4000-8000-000000000001'),1::bigint,
  'enrollment relationship survives the DB-021 upgrade');
select is((select count(*) from public.notifications where id='b0216000-0000-4000-8000-000000000001'),1::bigint,
  'notification survives the DB-021 upgrade');
select ok(to_regprocedure('public.can_access_classroom(uuid)') is null,
  'legacy public policy helper is removed after cutover');
select ok(to_regprocedure('public.mark_notifications_read()') is not null,
  'bounded notification RPC exists after upgrade');
select is((select count(*) from pg_policies where schemaname='public' and cmd <> 'SELECT'),0::bigint,
  'upgrade removes every direct client mutation policy');
select is((select count(*) from information_schema.role_table_grants where table_schema='public' and grantee='authenticated'),0::bigint,
  'upgrade removes broad authenticated table grants');

select * from finish();
rollback;
