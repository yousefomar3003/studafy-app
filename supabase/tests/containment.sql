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
  not has_function_privilege(
    'anon',
    'public.is_school_member(uuid, public.app_role[])',
    'execute'
  ),
  'anonymous cannot execute is_school_member'
);

select ok(
  not has_function_privilege(
    'anon',
    'public.is_class_teacher(uuid)',
    'execute'
  ),
  'anonymous cannot execute is_class_teacher'
);

select ok(
  not has_function_privilege(
    'anon',
    'public.can_access_student(uuid)',
    'execute'
  ),
  'anonymous cannot execute can_access_student'
);

select ok(
  not has_function_privilege(
    'anon',
    'public.can_access_classroom(uuid)',
    'execute'
  ),
  'anonymous cannot execute can_access_classroom'
);

select ok(
  not has_function_privilege(
    'anon',
    'public.handle_new_auth_user()',
    'execute'
  ),
  'anonymous cannot execute handle_new_auth_user'
);

select ok(
  not has_function_privilege(
    'authenticated',
    'public.handle_new_auth_user()',
    'execute'
  ),
  'authenticated callers cannot invoke the auth trigger helper directly'
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
    'public.is_school_member(uuid, public.app_role[])',
    'execute'
  ),
  'authenticated RLS policies retain access to their membership helper'
);

select ok(
  has_function_privilege(
    'authenticated',
    'public.can_access_classroom(uuid)',
    'execute'
  ),
  'authenticated RLS policies retain access to their classroom helper'
);

select * from finish();
rollback;
