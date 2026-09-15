-- API-042 foundation: new lifecycle types and tables that DB-020/DB-021 did
-- not need. Same discipline as DB-020/DB-021: RLS enabled, all direct grants
-- revoked from anon/authenticated/studafy_api_runtime, access only through
-- SECURITY DEFINER functions added in 202609160002_api042_school_operations.sql.

create type public.invitation_status as enum (
  'pending', 'accepted', 'revoked', 'expired'
);

create type public.support_access_status as enum (
  'pending', 'approved', 'active', 'expired', 'revoked', 'denied'
);

-- Schools become writable in API-042 (provision/suspend/close); every other
-- singleton domain object the command surface mutates uses an
-- expectedVersion-checked write, so schools needs the same optimistic
-- concurrency column. NOT VALID + a separate VALIDATE avoids a blocking
-- table scan, matching 202609150001_api041_academic_schema.sql's technique.
alter table public.schools add column if not exists version bigint not null default 1;
alter table public.schools
  add constraint api042_schools_version_check check (version > 0) not valid;
alter table public.schools validate constraint api042_schools_version_check;

-- Platform-operator allowlist. Deliberately has no API surface: granting or
-- revoking a row here is an out-of-band, audited manual database operation
-- performed by trusted ops, the same trust tier as issuing a service-role
-- key. This is what instructions.md section 7 means by "no public
-- school/role creation" for school provisioning -- there is no endpoint that
-- can create the first row that lets an actor provision a school.
create table public.platform_operators (
  user_id uuid primary key references public.profiles(id) on delete cascade,
  granted_by uuid references public.profiles(id) on delete set null,
  note text,
  created_at timestamptz not null default now()
);

create table public.invitations (
  id uuid primary key default gen_random_uuid(),
  school_id uuid not null references public.schools(id) on delete cascade,
  role public.app_role not null,
  email text not null check (email = lower(email)),
  classroom_id uuid references public.classrooms(id) on delete set null,
  token_hash text not null,
  status public.invitation_status not null default 'pending',
  invited_by uuid not null references public.profiles(id) on delete restrict,
  accepted_by uuid references public.profiles(id) on delete set null,
  revoked_by uuid references public.profiles(id) on delete set null,
  attempt_count integer not null default 0 check (attempt_count >= 0),
  max_attempts integer not null default 5 check (max_attempts > 0),
  expires_at timestamptz not null,
  accepted_at timestamptz,
  revoked_at timestamptz,
  version bigint not null default 1,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (token_hash),
  check (expires_at > created_at),
  check (status <> 'accepted' or accepted_at is not null and accepted_by is not null),
  check (status <> 'revoked' or revoked_at is not null)
);

-- Only one live (pending, unexpired) invitation per school/email/role so an
-- admin cannot be tricked into stacking invites the acceptance-rate limiter
-- would otherwise have to disambiguate.
create unique index invitations_live_unique
  on public.invitations (school_id, email, role)
  where status = 'pending';

create index invitations_school_status_idx
  on public.invitations (school_id, status);

create table public.notification_preferences (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references public.profiles(id) on delete cascade,
  school_id uuid references public.schools(id) on delete cascade,
  channel text not null check (channel in ('in_app', 'email', 'push')),
  category text not null,
  enabled boolean not null default true,
  updated_at timestamptz not null default now()
);

-- Postgres treats NULL as distinct in a plain unique constraint, so a
-- nullable school_id (global preference) needs two partial indexes rather
-- than one constraint that would silently allow duplicate global rows.
create unique index notification_preferences_school_unique
  on public.notification_preferences (user_id, school_id, channel, category)
  where school_id is not null;
create unique index notification_preferences_global_unique
  on public.notification_preferences (user_id, channel, category)
  where school_id is null;

create table public.support_access_grants (
  id uuid primary key default gen_random_uuid(),
  school_id uuid not null references public.schools(id) on delete cascade,
  requested_by uuid not null references public.profiles(id) on delete restrict,
  approved_by uuid references public.profiles(id) on delete set null,
  reason text not null check (length(reason) between 8 and 2000),
  ticket_ref text not null check (length(ticket_ref) between 1 and 200),
  resource_scope jsonb not null default '{}'::jsonb,
  status public.support_access_status not null default 'pending',
  requires_second_approver boolean not null default true,
  mfa_verified_at timestamptz not null,
  expires_at timestamptz not null,
  started_at timestamptz,
  ended_at timestamptz,
  revoked_by uuid references public.profiles(id) on delete set null,
  revoked_reason text,
  version bigint not null default 1,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  check (expires_at > created_at),
  check (approved_by is null or approved_by <> requested_by),
  check (status not in ('active', 'approved') or approved_by is not null)
);

create index support_access_grants_school_status_idx
  on public.support_access_grants (school_id, status);

do $api042$
declare
  table_name text;
begin
  foreach table_name in array array[
    'invitations', 'notification_preferences', 'support_access_grants'
  ]
  loop
    execute format(
      'create trigger api042_set_updated_at before update on public.%I '
      'for each row execute function private.set_updated_at()',
      table_name
    );
    execute format(
      'alter table public.%I enable row level security', table_name
    );
    execute format(
      'revoke all on table public.%I from anon, authenticated, studafy_api_runtime, studafy_worker_runtime',
      table_name
    );
  end loop;
  -- platform_operators is read by SECURITY DEFINER helpers only; never
  -- writable, listable, or grantable through any runtime role.
  execute 'alter table public.platform_operators enable row level security';
  execute 'revoke all on table public.platform_operators from anon, authenticated, studafy_api_runtime, studafy_worker_runtime';
end
$api042$;
