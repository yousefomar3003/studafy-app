begin;
create extension if not exists pgtap with schema extensions;
set local search_path = public, extensions;
select plan(2);

select ok(
  not exists (
    select 1
    from pg_catalog.pg_policies
    where schemaname = 'storage'
      and tablename = 'objects'
      and policyname = 'private uploads own namespace'
  ),
  'SEC-001 removes direct authenticated private-file uploads'
);

set local role authenticated;
select set_config(
  'request.jwt.claim.sub',
  '00000000-0000-4000-8000-000000000001',
  true
);
select throws_like(
  $$
    insert into storage.objects (bucket_id, name)
    values (
      'private-school-files',
      'papers/00000000-0000-4000-8000-000000000001/blocked.pdf'
    )
  $$,
  '%row-level security policy%',
  'authenticated users cannot insert directly into the private bucket'
);

select * from finish();
rollback;
