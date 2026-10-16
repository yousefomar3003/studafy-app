-- Reviewer access (2026-10-15): email sign-up stays off; only accounts an
-- operator provisions can sign in with a password.
--
-- Google Play and App Review need demo accounts that sign in without a
-- third-party provider, so the app now offers "Sign in with email" in every
-- build (docs/store/reviewer-access.md). That needs Supabase Auth's email
-- provider on - and the email provider is also the sign-up provider. The
-- only switch Supabase offers for sign-up is the global "Allow new users to
-- sign up", which would also stop every new Google, Microsoft and Apple
-- account. So the refusal lives here, in front of auth.users.
--
-- An email identity can be created only when, minutes before, the service
-- role registered its address through
-- public.allow_provisioned_email_account. Each registration is single use
-- and lapses after ten minutes. Supabase Auth cannot be told apart from a
-- public sign-up at insert time - the admin API writes app_metadata only
-- after the row exists - which is why a registration is needed at all.
--
-- Untouched:
--   * OAuth identities (provider google, azure, apple);
--   * managed child accounts, created by the API under managed.studafy.invalid,
--     a reserved domain no mail reaches, so no one else can confirm one;
--   * rows written by SQL with no provider (the API's identity mirror, test
--     fixtures).
-- A refused sign-up reaches the caller as Supabase Auth's generic
-- "Database error saving new user"; the app never calls sign-up.

create table private.provisioned_email_accounts (
  email text primary key
    check (email = lower(email) and email ~ '^[^@[:space:]]+@[^@[:space:]]+$'),
  allowed_until timestamptz not null,
  created_at timestamptz not null default now()
);

comment on table private.provisioned_email_accounts is
  'Single-use, short-lived permission for the service role to create one '
  'email-and-password account (reviewer access, 202610150050).';

alter table private.provisioned_email_accounts enable row level security;

create function public.allow_provisioned_email_account(requested_email text)
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  normalized text := lower(btrim(coalesce(requested_email, '')));
begin
  if normalized !~ '^[^@[:space:]]+@[^@[:space:]]+$' then
    raise exception 'not an email address' using errcode = '22023';
  end if;
  insert into private.provisioned_email_accounts (email, allowed_until)
  values (normalized, now() + interval '10 minutes')
  on conflict (email) do update
    set allowed_until = excluded.allowed_until,
        created_at = now();
end;
$$;

comment on function public.allow_provisioned_email_account(text) is
  'Service role only: lets Supabase Auth create one email account for this '
  'address within ten minutes. Used by scripts/provision-reviewer-school.ts.';

create function private.refuse_unprovisioned_email_signup()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  if coalesce(new.raw_app_meta_data ->> 'provider', '') <> 'email' then
    return new;
  end if;
  if lower(coalesce(new.email, '')) like '%@managed.studafy.invalid' then
    return new;
  end if;
  delete from private.provisioned_email_accounts
  where email = lower(coalesce(new.email, ''))
    and allowed_until > now();
  if found then
    return new;
  end if;
  raise exception 'email sign-up is disabled' using errcode = '42501';
end;
$$;

create trigger refuse_unprovisioned_email_signup
before insert on auth.users
for each row execute function private.refuse_unprovisioned_email_signup();

alter function public.allow_provisioned_email_account(text) owner to postgres;
alter function private.refuse_unprovisioned_email_signup() owner to postgres;

revoke all on function public.allow_provisioned_email_account(text)
  from public, anon, authenticated, studafy_api_runtime, studafy_worker_runtime;
grant execute on function public.allow_provisioned_email_account(text)
  to service_role;

revoke all on function private.refuse_unprovisioned_email_signup()
  from public, anon, authenticated, service_role, studafy_api_runtime,
    studafy_worker_runtime;

revoke all on table private.provisioned_email_accounts
  from public, anon, authenticated, service_role, studafy_api_runtime,
    studafy_worker_runtime;
