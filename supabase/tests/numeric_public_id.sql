-- A numeric Studafy ID for every account (202610010003), and renaming.
-- Transactional fixtures: this test leaves existing local users/data intact.
begin;
\set auth031_fixture_only true
\ir rls_access_seed.sql
\ir db021_access_seed.sql
\unset auth031_fixture_only
create extension if not exists pgtap with schema extensions;
set local search_path=public,extensions;
select plan(10);

\set new_user 'abcf0000-0000-4000-8000-0000000003a1'

select is((select count(*) from public.profiles where public_id is null), 0::bigint,
  'every account has a Studafy number');
select is((select count(*) from public.profiles where public_id !~ '^[1-9][0-9]{9}$'), 0::bigint,
  'each is ten digits with no leading zero');
select is((select count(*) - count(distinct public_id) from public.profiles), 0::bigint,
  'no two accounts share one');

insert into auth.users (id, email, encrypted_password, aud, role, email_confirmed_at, created_at,
  updated_at, instance_id, confirmation_token, recovery_token, email_change,
  email_change_token_new, email_change_token_current, phone_change_token,
  raw_app_meta_data, raw_user_meta_data)
values (:'new_user', 'public-id.new@synthetic.studafy.test',
  'synthetic-not-a-secret', 'authenticated', 'authenticated', now(), now(), now(),
  '00000000-0000-0000-0000-000000000000', '', '', '', '', '', '', '{}', '{}');
select ok((select public_id from public.profiles where id = :'new_user') ~ '^[1-9][0-9]{9}$',
  'a new account is given one');

select public_id as kept from public.profiles where id = :'guardian_user' \gset
update public.profiles set public_id = '1234567890' where id = :'guardian_user';
select is((select public_id from public.profiles where id = :'guardian_user'), :'kept',
  'once given, it never changes');
select throws_ok(format($$insert into public.profiles(id, display_name, public_id)
  values (gen_random_uuid(), 'Dup', %L)$$, :'kept'),
  '23505', null, 'the database refuses a duplicate');

select is(private.profile_json(:'guardian_user') ->> 'publicId', :'kept',
  'the owner''s profile returns it');

-- Renaming: the person's own name, saved, whatever the script.
create temporary table results(name text primary key, result jsonb);
select set_config('request.jwt.claim.sub', :'guardian_user', true);
select set_config('studafy.school_id', '', true);
select set_config('studafy.request_id', 'public-id-rename', true);
insert into results values ('reservation', private.api_idempotency_reserve(
  null, 'v1.updateProfile', 'public-id-rename-name-1', repeat('a', 64)));
insert into results values ('rename', private.api042_command('updateProfile', null,
  jsonb_build_object('responseStatus', 200, 'body',
    jsonb_build_object('displayName', '  نادية حسن  ')),
  ((select result->>'id' from results where name = 'reservation')::uuid), 1));
select is((select result->'response'->>'displayName' from results where name = 'rename'),
  'نادية حسن', 'a name in any script is saved, trimmed');
select is((select display_name from public.profiles where id = :'guardian_user'), 'نادية حسن',
  'and is the name stored');
select is((select public_id from public.profiles where id = :'guardian_user'), :'kept',
  'renaming leaves the Studafy number alone');

select * from finish();
rollback;
