-- A class code stays the same until the teacher changes it.
--
-- The join link's token and code were random and stored only as hashes, so
-- the one moment either existed in readable form was the create response.
-- Every time a teacher opened "invite", the app therefore minted a new link,
-- which revoked the one they had already shared - a code written on the
-- board on Monday stopped working the first time anyone looked it up again.
--
-- Now each link carries a random salt, and the API derives the token and the
-- code from it with a key held outside the database (CLASS_JOIN_CODE_KEY):
-- HMAC(key, salt). The database still never holds a token or a code - only
-- their hashes and the salt, and the salt alone is useless without the key.
-- The API can re-derive both for the class's own staff, so opening the
-- invite shows the same code every time; a new one exists only when the
-- teacher asks for it, or the old one has expired or been used up.

alter table public.class_join_links
  add column if not exists derivation_salt text
    check (derivation_salt is null or derivation_salt ~ '^[A-Za-z0-9_-]{22,64}$');

-- ---------------------------------------------------------------------------
-- Creating a link records its salt.
-- ---------------------------------------------------------------------------
do $$ begin
  if not exists (
    select 1 from pg_proc p join pg_namespace n on n.oid = p.pronamespace
    where n.nspname = 'private' and p.proname = 'api044_command_pre_salt'
  ) then
    alter function private.api044_command(text, uuid, jsonb, uuid, bigint)
      rename to api044_command_pre_salt;
  end if;
end $$;

create or replace function private.api044_command(
  p_operation text, p_resource_id uuid, p_input jsonb,
  p_idempotency_id uuid, p_idempotency_generation bigint)
returns jsonb language plpgsql security definer set search_path = '' as $$
declare
  v_salt text := nullif((p_input->'body')->>'derivationSalt', '');
  result jsonb;
begin
  result := private.api044_command_pre_salt(
    p_operation, p_resource_id,
    -- The delegate's body is strict about what it reads; the salt is this
    -- wrapper's alone.
    case when p_input ? 'body'
      then jsonb_set(p_input, array['body'], (p_input->'body') - 'derivationSalt')
      else p_input end,
    p_idempotency_id, p_idempotency_generation);
  if p_operation = 'createClassJoinLink' and v_salt is not null
    and coalesce(result->>'outcome', '') = 'ok' then
    update public.class_join_links set derivation_salt = v_salt
    where id = ((result->'response')->>'id')::uuid;
  end if;
  return result;
end;
$$;

alter function private.api044_command(text, uuid, jsonb, uuid, bigint)
  owner to postgres;
alter function private.api044_command_pre_salt(
  text, uuid, jsonb, uuid, bigint) owner to postgres;
revoke all on function private.api044_command_pre_salt(
  text, uuid, jsonb, uuid, bigint)
  from public, anon, authenticated, service_role, studafy_worker_runtime,
  studafy_api_runtime;
revoke all on function private.api044_command(text, uuid, jsonb, uuid, bigint)
  from public, anon, authenticated, service_role, studafy_worker_runtime;
grant execute on function private.api044_command(
  text, uuid, jsonb, uuid, bigint) to studafy_api_runtime;

-- ---------------------------------------------------------------------------
-- Reading the class's link hands the API the salt, for the staff only.
--
-- The API strips it before responding; it is here so the API can re-derive
-- the code, not so a client can see it. Only an active link that has not
-- expired or run out is worth re-deriving.
-- ---------------------------------------------------------------------------
do $$ begin
  if not exists (
    select 1 from pg_proc p join pg_namespace n on n.oid = p.pronamespace
    where n.nspname = 'private' and p.proname = 'api044_query_pre_salt'
  ) then
    alter function private.api044_query(text, uuid, jsonb)
      rename to api044_query_pre_salt;
  end if;
end $$;

create or replace function private.api044_query(
  p_operation text, p_resource_id uuid, p_input jsonb)
returns jsonb language plpgsql stable security definer set search_path = '' as $$
declare
  result jsonb;
  v_salt text;
begin
  result := private.api044_query_pre_salt(p_operation, p_resource_id, p_input);
  if p_operation <> 'getClassJoinLink' or result is null
    or result ? 'outcome' then
    return result;
  end if;
  select l.derivation_salt into v_salt
  from public.class_join_links l
  where l.id = (result->>'id')::uuid
    and l.status = 'active' and l.expires_at > now()
    and (l.max_uses is null or l.use_count < l.max_uses);
  return result || jsonb_build_object('derivationSalt', v_salt);
end;
$$;

alter function private.api044_query(text, uuid, jsonb) owner to postgres;
alter function private.api044_query_pre_salt(text, uuid, jsonb) owner to postgres;
revoke all on function private.api044_query_pre_salt(text, uuid, jsonb)
  from public, anon, authenticated, service_role, studafy_worker_runtime,
  studafy_api_runtime;
revoke all on function private.api044_query(text, uuid, jsonb)
  from public, anon, authenticated, service_role, studafy_worker_runtime;
grant execute on function private.api044_query(text, uuid, jsonb)
  to studafy_api_runtime;
