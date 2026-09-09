-- Create the least-privileged application profile after any OAuth or password
-- signup. School memberships remain an explicit trusted backend action.
create or replace function public.handle_new_auth_user()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  requested_locale text;
begin
  requested_locale := coalesce(new.raw_user_meta_data ->> 'locale', 'en');
  if requested_locale not in ('en', 'ar') then
    requested_locale := 'en';
  end if;

  insert into public.profiles (id, display_name, locale)
  values (
    new.id,
    coalesce(
      nullif(new.raw_user_meta_data ->> 'full_name', ''),
      nullif(new.raw_user_meta_data ->> 'name', ''),
      split_part(coalesce(new.email, 'Studafy user'), '@', 1)
    ),
    requested_locale
  )
  on conflict (id) do nothing;
  return new;
end;
$$;

drop trigger if exists on_auth_user_created on auth.users;
create trigger on_auth_user_created
after insert on auth.users
for each row execute procedure public.handle_new_auth_user();

-- Backfill identities that were created before this migration. This creates no
-- membership and therefore grants no school-record access by itself.
insert into public.profiles (id, display_name, locale)
select
  u.id,
  coalesce(
    nullif(u.raw_user_meta_data ->> 'full_name', ''),
    nullif(u.raw_user_meta_data ->> 'name', ''),
    split_part(coalesce(u.email, 'Studafy user'), '@', 1)
  ),
  case
    when u.raw_user_meta_data ->> 'locale' in ('en', 'ar')
      then u.raw_user_meta_data ->> 'locale'
    else 'en'
  end
from auth.users u
on conflict (id) do nothing;

create table public.consent_records (
  id bigint generated always as identity primary key,
  user_id uuid not null references public.profiles(id) on delete cascade,
  purpose text not null,
  policy_version text not null,
  locale text not null check (locale in ('en', 'ar')),
  accepted_at timestamptz not null default now(),
  withdrawn_at timestamptz,
  unique (user_id, purpose, policy_version)
);

alter table public.consent_records enable row level security;

create policy "consent read own" on public.consent_records for select
using (user_id = auth.uid());

create or replace function public.record_policy_consent(
  requested_purpose text,
  requested_version text,
  requested_locale text default 'en'
)
returns void
language plpgsql
security invoker
set search_path = public
as $$
begin
  if auth.uid() is null then
    raise exception 'Authentication required';
  end if;
  if requested_purpose not in ('terms_and_privacy', 'ai_features') then
    raise exception 'Unsupported consent purpose';
  end if;
  if requested_locale not in ('en', 'ar') then
    raise exception 'Unsupported locale';
  end if;

  insert into public.consent_records (
    user_id, purpose, policy_version, locale, accepted_at, withdrawn_at
  ) values (
    auth.uid(), requested_purpose, requested_version, requested_locale, now(), null
  )
  on conflict (user_id, purpose, policy_version)
  do update set accepted_at = excluded.accepted_at, withdrawn_at = null;
end;
$$;

grant execute on function public.record_policy_consent(text, text, text)
to authenticated;

create policy "consent insert own" on public.consent_records for insert
with check (user_id = auth.uid());

create policy "consent update own" on public.consent_records for update
using (user_id = auth.uid()) with check (user_id = auth.uid());
