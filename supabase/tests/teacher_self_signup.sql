-- Self-serve teacher sign-up (private.api045_command).
--
-- Seeds its own fixtures and rolls back, so it leaves existing local data
-- alone and needs no separate _seed.sql wrapper.
begin;
create extension if not exists pgtap with schema extensions;
set local search_path = public, extensions;
select plan(20);

-- Grants first: the dispatcher must be reachable by the API's least-privilege
-- role and by nobody the client can be.
select ok(
  has_function_privilege('studafy_api_runtime',
    'private.api045_command(text,uuid,jsonb,uuid,bigint)', 'execute'),
  'the api runtime role may call the dispatcher');
select ok(
  not has_function_privilege('authenticated',
    'private.api045_command(text,uuid,jsonb,uuid,bigint)', 'execute'),
  'a signed-in client may not call the dispatcher directly');
select ok(
  not has_function_privilege('anon',
    'private.api045_command(text,uuid,jsonb,uuid,bigint)', 'execute'),
  'an anonymous client may not call the dispatcher directly');
-- Repaired here because a brand-new student's join depends on it.
select ok(
  has_function_privilege('studafy_api_runtime',
    'private.api044_command(text,uuid,jsonb,uuid,bigint)', 'execute'),
  'the class-join dispatcher is reachable by the api runtime role');

\set newcomer '5d000000-0000-4000-8000-000000000001'
\set existing '5d000000-0000-4000-8000-000000000002'
\set ghost    '5d000000-0000-4000-8000-000000000003'

insert into auth.users (id, email, aud, role)
values
  (:'newcomer', 'newcomer@synthetic.studafy.test', 'authenticated', 'authenticated'),
  (:'existing', 'existing@synthetic.studafy.test', 'authenticated', 'authenticated'),
  (:'ghost',    'ghost@synthetic.studafy.test',    'authenticated', 'authenticated')
on conflict (id) do nothing;

insert into public.profiles (id, display_name, locale, status)
values
  (:'newcomer', 'Rana Haddad', 'ar', 'active'),
  (:'existing', 'Already Placed', 'en', 'active')
on conflict (id) do update set display_name = excluded.display_name;

-- A profile is normally created by a trigger on auth.users, so the ghost's
-- has to be removed to reach the branch that refuses a nameless account.
delete from public.profiles where id = :'ghost';

select set_config('studafy.request_id', 'test-signup-request', true);

-- A helper that runs the command the way the API does: reserve, then call.
create or replace function pg_temp.signup(p_actor uuid, p_body jsonb)
returns jsonb language plpgsql as $$
declare
  reservation jsonb;
begin
  perform set_config('request.jwt.claim.sub', p_actor::text, true);
  -- No school: the caller has no tenant, which is the case under test.
  perform set_config('studafy.school_id', '', true);
  reservation := private.api_idempotency_reserve(
    null, 'createTeacherWorkspace',
    'key-' || p_actor::text || '-' || coalesce(p_body->>'name', 'default'),
    repeat('a', 64));
  if reservation->>'outcome' <> 'reserved' then
    return jsonb_build_object('outcome', 'reserve_' || (reservation->>'outcome'));
  end if;
  return private.api045_command(
    'createTeacherWorkspace', null,
    jsonb_build_object('body', p_body),
    (reservation->>'id')::uuid, (reservation->>'generation')::bigint);
end;
$$;

-- The happy path.
select is(pg_temp.signup(:'newcomer', '{}'::jsonb)->>'outcome', 'ok',
  'a signed-in account with no membership gets a workspace');

select is(
  (select count(*)::int from public.memberships where user_id = :'newcomer'),
  1, 'exactly one membership is created');
select is(
  (select role::text from public.memberships where user_id = :'newcomer'),
  'teacher',
  'the creator is a teacher, never a school_admin that would force MFA');
select is(
  (select status::text from public.memberships where user_id = :'newcomer'),
  'active', 'the membership is usable immediately');

-- Without a term, createClassroom returns invalid_state, so a workspace
-- without one is a teacher who can never make a class.
select is(
  (select count(*)::int from public.terms t
    join public.memberships m on m.school_id = t.school_id
   where m.user_id = :'newcomer' and t.status in ('active', 'planned')),
  1, 'a usable term exists from the first moment');

select is(
  (select s.name from public.schools s
    join public.memberships m on m.school_id = s.id
   where m.user_id = :'newcomer'),
  'Rana Haddad',
  'the container is named from the profile when the client sends nothing');

-- private.school_messaging_enabled coalesces a missing row to false, so a
-- workspace without one has messaging silently off and, with no school
-- administrator in this product, no way to turn it on.
select is(
  (select cc.messaging_enabled from public.school_content_controls cc
    join public.memberships m on m.school_id = cc.school_id
   where m.user_id = :'newcomer'),
  true, 'the workspace can hold a conversation from the first moment');
select is(
  (select cc.content_filter_level from public.school_content_controls cc
    join public.memberships m on m.school_id = cc.school_id
   where m.user_id = :'newcomer'),
  'strict',
  'only the switch that allows a conversation is relaxed, not the filter');

select is(
  (select count(*)::int from public.membership_events
    where actor_id = :'newcomer' and reason = 'teacher_workspace_created'),
  1, 'the grant is recorded in the append-only membership log');
select is(
  (select count(*)::int from public.audit_events
    where actor_id = :'newcomer' and action = 'teacher_workspace_created'),
  1, 'the creation is audited');

-- One workspace per account.
select is(pg_temp.signup(:'newcomer', '{"name":"Second"}'::jsonb)->>'outcome',
  'invalid_state', 'a second workspace is refused');
select is(
  (select count(*)::int from public.schools s
    join public.memberships m on m.school_id = s.id
   where m.user_id = :'newcomer'),
  1, 'the refusal creates no tenant');

-- A revoked membership still counts, or removal becomes a no-op.
insert into public.memberships (school_id, user_id, role, active, status)
select s.id, :'existing', 'teacher', false, 'revoked'
from public.schools s join public.memberships m on m.school_id = s.id
where m.user_id = :'newcomer';
select is(pg_temp.signup(:'existing', '{}'::jsonb)->>'outcome', 'invalid_state',
  'an account whose membership was revoked cannot mint a fresh tenant');

-- An account with no profile row is not a person we can name a workspace for.
-- It never reaches the dispatcher's own guard: api_idempotency_reserve calls
-- private.is_active_user() first and denies, so the refusal arrives a layer
-- earlier than the branch that also checks. Both are kept - what matters is
-- that no tenant appears either way.
select is(pg_temp.signup(:'ghost', '{}'::jsonb)->>'outcome', 'reserve_denied',
  'an account with no profile never reaches the command');
select is(
  (select count(*)::int from public.memberships where user_id = :'ghost'),
  0, 'and no workspace is created for it');

-- An unknown operation must not fall through to the audit insert.
select is(
  private.api045_command('deleteEverything', null, '{}'::jsonb,
    gen_random_uuid(), 1)->>'outcome',
  'forbidden',
  'an unknown operation without a live reservation is refused');

select * from finish();
rollback;
