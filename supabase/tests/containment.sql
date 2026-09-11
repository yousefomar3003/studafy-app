begin;
create extension if not exists pgtap with schema extensions;
set local search_path = public, extensions;
select plan(11);

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

reset role;

select ok(
  to_regprocedure('public.is_school_member(uuid, public.app_role[])') is null,
  'legacy public is_school_member helper is removed'
);

select ok(
  to_regprocedure('public.is_class_teacher(uuid)') is null,
  'legacy public is_class_teacher helper is removed'
);

select ok(
  to_regprocedure('public.can_access_student(uuid)') is null,
  'legacy public can_access_student helper is removed'
);

select ok(
  to_regprocedure('public.can_access_classroom(uuid)') is null,
  'legacy public can_access_classroom helper is removed'
);

select ok(
  to_regprocedure('public.handle_new_auth_user()') is null,
  'auth trigger helper is absent from the public RPC schema'
);

select ok(
  not has_function_privilege(
    'authenticated',
    'private.handle_new_auth_user()',
    'execute'
  ),
  'authenticated callers cannot invoke the private auth trigger helper'
);

select ok(
  to_regprocedure('public.rls_auto_enable()') is null
  or not has_function_privilege(
    'anon',
    'public.rls_auto_enable()',
    'execute'
  ),
  'anonymous cannot execute the platform RLS event-trigger helper'
);

select ok(
  has_function_privilege(
    'authenticated',
    'private.has_active_membership(uuid, public.app_role[])',
    'execute'
  ),
  'authenticated policies can execute the private membership helper'
);

select ok(
  has_function_privilege(
    'authenticated',
    'private.can_view_classroom(uuid)',
    'execute'
  ),
  'authenticated policies can execute the private classroom helper'
);

select * from finish();
rollback;
