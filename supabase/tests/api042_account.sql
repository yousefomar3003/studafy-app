begin;
create extension if not exists pgtap with schema extensions;
set local search_path = public, extensions;
select plan(14);

select ok(
  has_function_privilege('studafy_api_runtime', 'private.api042_command(text,uuid,jsonb,uuid,bigint)', 'execute')
  and has_function_privilege('studafy_api_runtime', 'private.api042_query(text,uuid,jsonb)', 'execute'),
  'runtime can execute the account query and command entry points'
);

create temporary table api042_acct_results(name text primary key, result jsonb);

-- --------------------------------------------------------------------------
-- updateProfile
-- --------------------------------------------------------------------------

select set_config('request.jwt.claim.sub', :'teacher_user', true);
select set_config('studafy.school_id', '', true);
select set_config('studafy.request_id', 'api042-update-profile-bad-locale', true);
insert into api042_acct_results values('profile-bad-locale-reservation', private.api_idempotency_reserve(
  null, 'v1.updateProfile', 'api042-profile-bad-locale-1', repeat('a', 64)));
insert into api042_acct_results values('profile-bad-locale', private.api042_command(
  'updateProfile', null, jsonb_build_object('responseStatus', 200, 'body', jsonb_build_object('locale', 'fr')),
  ((select result->>'id' from api042_acct_results where name = 'profile-bad-locale-reservation')::uuid), 1));
select is((select result->>'outcome' from api042_acct_results where name = 'profile-bad-locale'), 'invalid',
  'an unsupported locale is rejected');

select set_config('studafy.request_id', 'api042-update-profile', true);
insert into api042_acct_results values('profile-reservation', private.api_idempotency_reserve(
  null, 'v1.updateProfile', 'api042-profile-key-01', repeat('b', 64)));
insert into api042_acct_results values('profile', private.api042_command(
  'updateProfile', null, jsonb_build_object('responseStatus', 200, 'body', jsonb_build_object(
    'displayName', 'Updated Teacher Name', 'locale', 'ar')),
  ((select result->>'id' from api042_acct_results where name = 'profile-reservation')::uuid), 1));
select is((select result->'response'->>'displayName' from api042_acct_results where name = 'profile'), 'Updated Teacher Name',
  'the actor updates their own display name');
select is((select result->'response'->>'locale' from api042_acct_results where name = 'profile'), 'ar',
  'the actor updates their own locale');
select is((select display_name from public.profiles where id = :'teacher_user'), 'Updated Teacher Name',
  'the change is persisted on the profiles row');

-- Omitting a field leaves it unchanged rather than nulling it out.
select set_config('studafy.request_id', 'api042-update-profile-partial', true);
insert into api042_acct_results values('profile-partial-reservation', private.api_idempotency_reserve(
  null, 'v1.updateProfile', 'api042-profile-partial-1', repeat('c', 64)));
insert into api042_acct_results values('profile-partial', private.api042_command(
  'updateProfile', null, jsonb_build_object('responseStatus', 200, 'body', jsonb_build_object('locale', 'en')),
  ((select result->>'id' from api042_acct_results where name = 'profile-partial-reservation')::uuid), 1));
select is((select result->'response'->>'displayName' from api042_acct_results where name = 'profile-partial'), 'Updated Teacher Name',
  'updating only locale leaves the previously-set display name untouched');

-- A different actor's profile is never touched.
select is((select display_name from public.profiles where id = :'student_user') <> 'Updated Teacher Name', true,
  'a different user''s profile is unaffected');

-- --------------------------------------------------------------------------
-- requestDataExport / getExportStatus
-- --------------------------------------------------------------------------

select set_config('request.jwt.claim.sub', :'student_user', true);
select is(
  (private.api042_query('getExportStatus', null, '{}'::jsonb)->'request'),
  'null'::jsonb, 'a user with no export request yet has a null request in their status'
);

select set_config('studafy.request_id', 'api042-request-export', true);
insert into api042_acct_results values('export-reservation', private.api_idempotency_reserve(
  null, 'v1.requestDataExport', 'api042-export-key-01', repeat('d', 64)));
insert into api042_acct_results values('export', private.api042_command(
  'requestDataExport', null, jsonb_build_object('responseStatus', 201, 'body', '{}'::jsonb),
  ((select result->>'id' from api042_acct_results where name = 'export-reservation')::uuid), 1));
select is((select result->'response'->>'status' from api042_acct_results where name = 'export'), 'pending',
  'a fresh export request starts pending');
select (result->'response'->>'id')::uuid as export_id from api042_acct_results where name = 'export' \gset

select is(
  (private.api042_query('getExportStatus', null, '{}'::jsonb)->'request'->>'id'),
  :'export_id'::text, 'getExportStatus returns the just-created request'
);

-- Requesting again while one is still pending reuses the same request,
-- rather than creating a second live export.
select set_config('studafy.request_id', 'api042-request-export-again', true);
insert into api042_acct_results values('export-again-reservation', private.api_idempotency_reserve(
  null, 'v1.requestDataExport', 'api042-export-again-key-1', repeat('e', 64)));
insert into api042_acct_results values('export-again', private.api042_command(
  'requestDataExport', null, jsonb_build_object('responseStatus', 201, 'body', '{}'::jsonb),
  ((select result->>'id' from api042_acct_results where name = 'export-again-reservation')::uuid), 1));
select is((select result->'response'->>'id' from api042_acct_results where name = 'export-again'), :'export_id'::text,
  'a second request while one is pending returns the same request, not a duplicate');
select is((select count(*) from public.data_export_requests where user_id = :'student_user'), 1::bigint,
  'exactly one export request row exists for this user');

-- --------------------------------------------------------------------------
-- Transactional integrity, matching every other API-042 command surface.
-- --------------------------------------------------------------------------

create function pg_temp.reject_api042_acct_audit() returns trigger language plpgsql as $$
begin
  if new.request_id = 'api042-acct-force-audit' then raise exception 'API042_ACCT_FORCED_AUDIT'; end if;
  return new;
end $$;
create trigger api042_acct_force_audit before insert on public.audit_events
for each row execute function pg_temp.reject_api042_acct_audit();
select set_config('request.jwt.claim.sub', :'guardian_user', true);
select set_config('studafy.request_id', 'api042-acct-force-audit', true);
insert into api042_acct_results values('audit-reservation', private.api_idempotency_reserve(
  null, 'v1.updateProfile', 'api042-acct-audit-key-1', repeat('f', 64)));
create function pg_temp.api042_acct_audit_failure(p_reservation_id uuid) returns jsonb language sql as $$
  select private.api042_command('updateProfile', null,
    jsonb_build_object('responseStatus', 200, 'body', jsonb_build_object('displayName', 'Must roll back')),
    p_reservation_id, 1)
$$;
select throws_ok(
  format('select pg_temp.api042_acct_audit_failure(%L::uuid)',
    (select result->>'id' from api042_acct_results where name = 'audit-reservation')),
  'API042_ACCT_FORCED_AUDIT', 'forced audit failure escapes the command'
);
select isnt((select display_name from public.profiles where id = :'guardian_user'), 'Must roll back',
  'the forced-failure profile update never committed');
drop trigger api042_acct_force_audit on public.audit_events;

select * from finish();
rollback;
