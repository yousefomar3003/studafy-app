-- AUTH-030 device registry and session revocation watermark.
--
-- Supabase revokes refresh tokens on sign-out, but an already-issued access
-- token stays cryptographically valid until it expires. Waiting out that
-- window is not an acceptable revocation bound for a school product, so the
-- API additionally rejects any token issued before the user's watermark.
-- "Sign out everywhere" therefore takes effect on the next request, not on
-- the next token expiry.

create table public.auth_devices (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references public.profiles(id) on delete cascade,
  -- Keyed digest of the client-generated installation identifier. The raw
  -- identifier is never stored, so this table cannot be joined to a device
  -- fingerprint held elsewhere.
  device_hash text not null,
  platform text not null check (platform in ('ios', 'android', 'other')),
  app_version text,
  display_label text,
  first_seen_at timestamptz not null default now(),
  last_seen_at timestamptz not null default now(),
  revoked_at timestamptz,
  revoked_by uuid references public.profiles(id) on delete set null,
  revocation_reason text check (
    revocation_reason is null or revocation_reason in (
      'user_revoked', 'all_device_sign_out', 'admin_revoked',
      'suspected_compromise', 'account_deleted'
    )
  ),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (user_id, device_hash),
  check (revoked_at is null or revoked_at >= first_seen_at),
  check (revoked_at is not null or revocation_reason is null),
  check (length(device_hash) = 64),
  check (display_label is null or length(display_label) <= 64)
);

create index auth_devices_active_idx
  on public.auth_devices (user_id, last_seen_at desc)
  where revoked_at is null;

-- One row per user. `revoked_before` is a not-before watermark: a verified
-- token whose `iat` precedes it is refused even though its signature and
-- expiry are still valid.
create table public.auth_session_revocations (
  user_id uuid primary key references public.profiles(id) on delete cascade,
  revoked_before timestamptz not null,
  reason text not null check (
    reason in (
      'all_device_sign_out', 'password_changed', 'mfa_changed',
      'admin_revoked', 'suspected_compromise', 'account_deleted'
    )
  ),
  actor_id uuid references public.profiles(id) on delete set null,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create trigger auth030_set_updated_at
before update on public.auth_devices
for each row execute function private.set_updated_at();

create trigger auth030_set_updated_at
before update on public.auth_session_revocations
for each row execute function private.set_updated_at();

alter table public.auth_devices enable row level security;
alter table public.auth_session_revocations enable row level security;
revoke all on table public.auth_devices from anon, authenticated;
revoke all on table public.auth_session_revocations from anon, authenticated;

-- Device rows are readable by their owner through the API's `authenticated`
-- role. There is no client grant, so this policy only takes effect for a
-- request the API has already authenticated and scoped.
create policy "auth devices own" on public.auth_devices for select
using (user_id = auth.uid() and private.is_active_user());
