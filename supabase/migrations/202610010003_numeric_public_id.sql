-- A numeric Studafy ID for every account (2026-10-01).
--
-- A parent's (and a teacher's) profile showed their internal account id - a
-- UUID - labelled "Account ID", which read like a link and meant nothing to
-- them. Every account now has a short public number instead: ten digits,
-- random, unique, and stable for the life of the account.
--
-- It is for people to read out - to Studafy support, or to tell two accounts
-- apart - and nothing else: no endpoint finds anyone by it, it grants no
-- access, and it is returned only on the person's own profile. A child is
-- still linked only by the child's own Studafy ID and the child's approval.
-- Students keep that ID (SJ-...) as the one they share; this number is the
-- account's own. Primary keys, auth ids, links and memberships are untouched.
--
-- Stored as text so leading digits and length never change in transit.

alter table public.profiles
  add column if not exists public_id text
    check (public_id ~ '^[1-9][0-9]{9}$');

create unique index if not exists profiles_public_id_key
  on public.profiles (public_id);

-- A fresh number no account holds. Nine billion possibilities, so a clash is
-- rare; the loop takes the next draw when one happens, and the unique index
-- stays the final word under concurrency.
create or replace function private.new_public_id()
returns text language plpgsql volatile security definer set search_path = '' as $$
declare
  candidate text;
begin
  loop
    candidate := (1000000000 + floor(random() * 9000000000)::bigint)::text;
    exit when not exists (
      select 1 from public.profiles p where p.public_id = candidate);
  end loop;
  return candidate;
end;
$$;

alter function private.new_public_id() owner to postgres;
revoke all on function private.new_public_id()
  from public, anon, authenticated, service_role, studafy_api_runtime,
  studafy_worker_runtime;

create or replace function private.profile_gets_public_id()
returns trigger language plpgsql security definer set search_path = '' as $$
begin
  if new.public_id is null then
    new.public_id := private.new_public_id();
  end if;
  -- Once given, the number is the account's: it never changes.
  if tg_op = 'UPDATE' and old.public_id is not null
     and new.public_id is distinct from old.public_id then
    new.public_id := old.public_id;
  end if;
  return new;
end;
$$;

alter function private.profile_gets_public_id() owner to postgres;
revoke all on function private.profile_gets_public_id()
  from public, anon, authenticated, service_role, studafy_api_runtime,
  studafy_worker_runtime;

drop trigger if exists profile_gets_public_id on public.profiles;
create trigger profile_gets_public_id
before insert or update of public_id on public.profiles
for each row execute function private.profile_gets_public_id();

-- Existing accounts, one at a time so each draw sees the ones before it.
do $$
declare r record;
begin
  for r in select id from public.profiles where public_id is null loop
    update public.profiles set public_id = private.new_public_id()
    where id = r.id;
  end loop;
end $$;

alter table public.profiles alter column public_id set not null;

-- The profile returns it to its owner. Re-issued from 202610010002.
create or replace function private.profile_json(p_user uuid)
returns jsonb language sql stable security definer set search_path = '' as $$
  select jsonb_build_object(
    'id', p.id,
    'displayName', p.display_name,
    'locale', p.locale,
    'gender', p.gender,
    'setupComplete', p.profile_completed_at is not null,
    'accountKind', private.account_kind(p.id),
    'publicId', p.public_id)
  from public.profiles p where p.id = p_user;
$$;
