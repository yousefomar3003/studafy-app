-- AUTH-030 recent-authentication grants.
--
-- The contained Edge Function treats `iat` within ten minutes as proof of
-- recent authentication. That is wrong: Supabase reissues `iat` on every
-- silent refresh, so a session that last saw a human days ago presents a
-- fresh `iat`. Recent auth is therefore tracked explicitly: the user
-- re-authenticates, the server issues a single-use opaque grant, and the
-- privileged command consumes it.
--
-- Only the digest of the grant is stored. A database disclosure does not
-- yield a usable grant.

create table public.auth_reauth_grants (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references public.profiles(id) on delete cascade,
  purpose text not null check (
    purpose in (
      'account_deletion',
      'account_deletion_cancel',
      'account_link',
      'all_device_sign_out',
      'device_revoke',
      'school_admin_privileged'
    )
  ),
  grant_hash text not null unique,
  -- The session the grant was minted for. A grant lifted from one device
  -- cannot be replayed from another.
  session_id uuid not null,
  aal text not null check (aal in ('aal1', 'aal2')),
  issued_at timestamptz not null default now(),
  expires_at timestamptz not null,
  consumed_at timestamptz,
  consumed_request_id uuid,
  check (expires_at > issued_at),
  check (consumed_at is null or consumed_at >= issued_at),
  check (length(grant_hash) = 64)
);

-- At most one live grant per user and purpose: re-challenging replaces rather
-- than accumulates, so a stolen older grant cannot sit waiting.
create unique index auth_reauth_grants_live_idx
  on public.auth_reauth_grants (user_id, purpose)
  where consumed_at is null;

create index auth_reauth_grants_expiry_idx
  on public.auth_reauth_grants (expires_at)
  where consumed_at is null;

alter table public.auth_reauth_grants enable row level security;
revoke all on table public.auth_reauth_grants from anon, authenticated;

-- Provider identities linked to one canonical profile. The provider subject
-- is stored only as a keyed digest; the unique index is what makes a
-- collision (the same provider identity arriving for a second profile)
-- detectable and refusable.
create table public.auth_identity_links (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references public.profiles(id) on delete cascade,
  provider text not null check (
    provider in ('google', 'azure', 'apple', 'email')
  ),
  provider_subject_hash text not null,
  is_primary boolean not null default false,
  linked_at timestamptz not null default now(),
  linked_by uuid references public.profiles(id) on delete set null,
  unlinked_at timestamptz,
  unlinked_by uuid references public.profiles(id) on delete set null,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  check (unlinked_at is null or unlinked_at >= linked_at),
  check (length(provider_subject_hash) = 64)
);

-- A provider identity belongs to exactly one profile while it is linked.
create unique index auth_identity_links_subject_idx
  on public.auth_identity_links (provider, provider_subject_hash)
  where unlinked_at is null;

-- A profile keeps exactly one primary identity. Unlinking the primary
-- requires promoting another first.
create unique index auth_identity_links_primary_idx
  on public.auth_identity_links (user_id)
  where unlinked_at is null and is_primary;

create trigger auth030_set_updated_at
before update on public.auth_identity_links
for each row execute function private.set_updated_at();

alter table public.auth_identity_links enable row level security;
revoke all on table public.auth_identity_links from anon, authenticated;

create policy "auth identity links own" on public.auth_identity_links for select
using (user_id = auth.uid() and private.is_active_user());
