-- First-sign-in profile setup (202609280006): a chosen name and a gender.
-- Transactional fixtures: this test leaves existing local users/data intact.
begin;
\set auth031_fixture_only true
\ir rls_access_seed.sql
\unset auth031_fixture_only
create extension if not exists pgtap with schema extensions;
set local search_path=public,extensions;
select plan(8);

select set_config('request.jwt.claim.sub', :'student_user', true);
select set_config('studafy.request_id', 'profile-setup-test', true);

create function pg_temp.update(body jsonb) returns jsonb language plpgsql as $$
declare r jsonb;
begin
  r := private.api_idempotency_reserve(null, 'updateProfile', gen_random_uuid()::text,
    encode(extensions.digest(body::text || random()::text, 'sha256'), 'hex'), 3600, 60);
  return private.ops_command_account('updateProfile', null,
    jsonb_build_object('body', body), (r->>'id')::uuid, (r->>'generation')::bigint);
end $$;

select is(private.api042_query('getProfile', null, '{}')->>'setupComplete', 'false',
  'a new account has not set up its profile');
select is(pg_temp.update('{"displayName":"Sara","completeSetup":true}')->>'outcome',
  'invalid', 'setup needs a gender answer too');
select is(pg_temp.update('{"gender":"unknown"}')->>'outcome', 'invalid',
  'only girl, boy or prefer not to say');
select is(pg_temp.update('{"displayName":"  Sara  ","gender":"prefer_not_to_say","completeSetup":true}')
  ->'response'->>'displayName', 'Sara', 'the chosen name replaces the email-derived one');
select is(private.api042_query('getProfile', null, '{}')->>'setupComplete', 'true',
  'setup is then complete');
select is(private.api042_query('getProfile', null, '{}')->>'gender', 'prefer_not_to_say',
  'and the answer is kept');
select is(pg_temp.update('{"locale":"ar"}')->'response'->>'setupComplete', 'true',
  'a later change does not undo setup');
select ok(not has_function_privilege('authenticated', 'private.profile_json(uuid)', 'execute'),
  'clients cannot read profiles directly');

select * from finish();
rollback;
