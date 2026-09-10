-- SEC-001 follow-up: SECURITY DEFINER helpers are implementation details of
-- RLS policies/triggers. Anonymous callers must not be able to invoke them as
-- RPCs. Existing migrations may already be applied, so this is forward-only.

revoke execute on function public.is_school_member(uuid, public.app_role[])
  from public, anon;
revoke execute on function public.is_class_teacher(uuid)
  from public, anon;
revoke execute on function public.can_access_student(uuid)
  from public, anon;
revoke execute on function public.can_access_classroom(uuid)
  from public, anon;
revoke execute on function public.handle_new_auth_user()
  from public, anon, authenticated;

-- Supabase creates this event-trigger helper outside repository migrations.
-- It is not an application RPC. Revoke direct invocation wherever it exists;
-- the event trigger itself continues to execute as its owner.
do $block$
begin
  if to_regprocedure('public.rls_auto_enable()') is not null then
    execute
      'revoke execute on function public.rls_auto_enable() '
      'from public, anon, authenticated';
  end if;
end
$block$;

-- PostgreSQL grants EXECUTE on new functions to PUBLIC by default and the
-- Supabase postgres role also had an explicit anon default grant. Remove both
-- defaults so future functions require an intentional grant.
alter default privileges for role postgres in schema public
  revoke execute on functions from public;
alter default privileges for role postgres in schema public
  revoke execute on functions from anon;
