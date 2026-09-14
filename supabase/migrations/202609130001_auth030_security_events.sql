-- AUTH-030 authentication security events.
--
-- Observability for the session lifecycle without storing an identifier that
-- re-identifies a person from the log alone. `account_hash` is a keyed digest
-- of the normalized account identifier; the key lives in the private schema
-- and is never granted to a client role. No email, display name, token,
-- provider subject, or raw IP address may be written to this relation.

create table private.auth_hash_keys (
  purpose text primary key,
  key bytea not null,
  created_at timestamptz not null default now()
);

-- One key per purpose, generated at migration time. Rotation is a forward
-- migration that inserts a new purpose and re-points the helper; existing
-- digests are deliberately not recomputable.
insert into private.auth_hash_keys (purpose, key)
values
  ('account', extensions.gen_random_bytes(32)),
  ('network', extensions.gen_random_bytes(32)),
  ('device', extensions.gen_random_bytes(32))
on conflict (purpose) do nothing;

create or replace function private.auth_normalized_hash(
  hash_purpose text,
  raw_value text
)
returns text
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  hash_key bytea;
  normalized text;
begin
  if raw_value is null or btrim(raw_value) = '' then
    return null;
  end if;
  select k.key into hash_key
  from private.auth_hash_keys k
  where k.purpose = hash_purpose;
  if hash_key is null then
    raise exception 'Unknown hash purpose';
  end if;
  normalized := lower(btrim(raw_value));
  return encode(
    extensions.hmac(normalized::bytea, hash_key, 'sha256'),
    'hex'
  );
end;
$$;

alter function private.auth_normalized_hash(text, text) owner to postgres;

-- `actor_id` and `school_id` deliberately carry no foreign key.
--
-- An append-only relation cannot participate in a referential action: an
-- `ON DELETE SET NULL` is an UPDATE, and the append-only trigger refuses it,
-- so a profile with security events could never be deleted — which would
-- break the very account-deletion flow this part delivers. A security log
-- must also outlive the account it describes; `account_hash` remains the
-- durable identifier once a profile is gone.
create table public.auth_security_events (
  id bigint generated always as identity primary key,
  actor_id uuid,
  account_hash text,
  school_id uuid,
  event_type text not null check (
    event_type in (
      'sign_in_succeeded',
      'sign_in_failed',
      'token_verification_failed',
      'token_refreshed',
      'session_expired',
      'session_revoked',
      'all_device_sign_out',
      'device_revoked',
      'identity_linked',
      'identity_unlinked',
      'identity_link_collision',
      'mfa_enrolled',
      'mfa_verified',
      'mfa_failed',
      'mfa_unenrolled',
      'reauth_challenged',
      'reauth_verified',
      'reauth_failed',
      'privileged_action_denied',
      'account_deletion_requested',
      'account_deletion_cancelled',
      'consent_recorded'
    )
  ),
  outcome text not null check (outcome in ('allowed', 'denied')),
  -- Stable machine reason. Deliberately coarse: the reason a client is shown
  -- is always the same regardless of which of these applies.
  reason_code text not null,
  method text check (
    method is null or method in (
      'password', 'google', 'azure', 'apple', 'otp', 'totp', 'recovery',
      'refresh_token', 'id_token'
    )
  ),
  aal text check (aal is null or aal in ('aal1', 'aal2')),
  ip_hash text,
  device_hash text,
  user_agent_family text,
  request_id uuid,
  created_at timestamptz not null default now(),
  -- Nothing that re-identifies a person belongs in this relation.
  check (account_hash is null or account_hash !~ '@'),
  check (user_agent_family is null or length(user_agent_family) <= 64),
  check (length(reason_code) <= 64)
);

create index auth_security_events_actor_idx
  on public.auth_security_events (actor_id, created_at desc);
create index auth_security_events_account_idx
  on public.auth_security_events (account_hash, created_at desc)
  where account_hash is not null;
create index auth_security_events_type_idx
  on public.auth_security_events (event_type, outcome, created_at desc);

alter table public.auth_security_events enable row level security;
revoke all on table public.auth_security_events from anon, authenticated;

create trigger auth030_reject_mutation
before update or delete on public.auth_security_events
for each row execute function private.reject_append_only_mutation();
