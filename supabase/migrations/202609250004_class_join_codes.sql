-- JOIN-053: a short class code as a second way to redeem a join link.
--
-- JOIN-052's link is a 43-character token. It is the right shape to send in a
-- message and tap, and the wrong shape for a six-year-old to type on a
-- parent's phone, or for a teacher to write on a board. A class code is the
-- same link spelled eight characters long: one row, so it shares the link's
-- expiry, revocation, use budget, audit trail and supersede-on-reissue.
-- Issuing a new link kills the old code with it, because they are the same
-- thing.
--
-- Stored as an HMAC the API computes under a key that never enters this
-- database. The link's token is stored as a plain SHA-256 and that is safe
-- because it carries 256 bits; a code carries about 40, and an unkeyed hash
-- of 40 bits can be reversed offline in minutes by anyone who can read this
-- table. Keying it means reading the table recovers no code.
--
-- The guessing surface is closed at the API, which moves redemption onto the
-- rate-limit class built for probing exact codes (the "linking" flow).
--
-- Forward-only: api044_command is extended by renaming it and delegating, so
-- the JOIN-052 redemption arm - membership, student record, enrolment, audit -
-- runs unchanged for a code exactly as it does for a token.

alter table public.class_join_links
  add column if not exists code_hash text;

-- Lookup only. Deliberately not unique: two live links sharing a code is a
-- one-in-a-trillion collision, and redemption refuses an ambiguous code rather
-- than guessing which class was meant, so a collision fails safe instead of
-- failing a teacher's link creation.
create index if not exists class_join_links_active_code_idx
  on public.class_join_links (code_hash)
  where code_hash is not null and status = 'active';

do $$ begin
  if not exists (
    select 1 from pg_proc p join pg_namespace n on n.oid = p.pronamespace
    where n.nspname = 'private' and p.proname = 'api044_command_pre_codes'
  ) then
    alter function private.api044_command(text, uuid, jsonb, uuid, bigint)
      rename to api044_command_pre_codes;
  end if;
end $$;

create or replace function private.api044_command(
  p_operation text,
  p_resource_id uuid,
  p_input jsonb,
  p_idempotency_id uuid,
  p_idempotency_generation bigint
)
returns jsonb
language plpgsql
security definer
set search_path to ''
as $function$
declare
  body jsonb := coalesce(p_input->'body', '{}'::jsonb);
  v_code_hash text := nullif(body->>'codeHash', '');
  v_token_hash text;
  v_matches integer;
  result jsonb;
begin
  if p_operation = 'createClassJoinLink' then
    -- The predecessor supersedes the live link and inserts the new one; the
    -- code is attached to that same row inside the same transaction.
    result := private.api044_command_pre_codes(
      p_operation, p_resource_id, p_input #- '{body,codeHash}',
      p_idempotency_id, p_idempotency_generation);
    if v_code_hash is not null and coalesce(result->>'outcome', '') = 'ok' then
      update public.class_join_links
      set code_hash = v_code_hash
      where id = ((result->'response')->>'id')::uuid;
    end if;
    return result;
  end if;

  if p_operation = 'redeemClassJoinLink' and v_code_hash is not null then
    -- A code or a token, never both: two credentials in one request is not a
    -- thing a real client sends.
    if nullif(body->>'tokenHash', '') is not null then
      return jsonb_build_object('outcome', 'invalid');
    end if;
    select count(*), min(l.token_hash)
      into v_matches, v_token_hash
    from public.class_join_links l
    where l.code_hash = v_code_hash and l.status = 'active';
    -- Exactly one live link, or nothing. An ambiguous code joins nobody to
    -- anything rather than picking a class.
    if v_matches <> 1 then
      return jsonb_build_object('outcome', 'not_found');
    end if;
    -- Resolved to the link's own token hash, then handed to the JOIN-052 arm
    -- untouched: it re-locks the row and re-checks status, expiry and budget,
    -- so a link revoked between these two statements is still refused.
    return private.api044_command_pre_codes(
      p_operation, p_resource_id,
      jsonb_set(p_input #- '{body,codeHash}', '{body,tokenHash}',
        to_jsonb(v_token_hash)),
      p_idempotency_id, p_idempotency_generation);
  end if;

  return private.api044_command_pre_codes(
    p_operation, p_resource_id, p_input,
    p_idempotency_id, p_idempotency_generation);
end;
$function$;

-- Grants follow the function OID across a rename, so the runtime role would
-- otherwise keep EXECUTE on the predecessor - able to skip this wrapper - and
-- have none on the wrapper itself. auth030_grants.sql asserts the exact
-- surface, which is what caught this the last time.
alter function private.api044_command(text, uuid, jsonb, uuid, bigint)
  owner to postgres;
alter function private.api044_command_pre_codes(text, uuid, jsonb, uuid, bigint)
  owner to postgres;
revoke all on function private.api044_command_pre_codes(
  text, uuid, jsonb, uuid, bigint)
  from public, anon, authenticated, service_role, studafy_worker_runtime,
  studafy_api_runtime;
revoke all on function private.api044_command(text, uuid, jsonb, uuid, bigint)
  from public, anon, authenticated, service_role, studafy_worker_runtime;
grant execute on function private.api044_command(
  text, uuid, jsonb, uuid, bigint) to studafy_api_runtime;
