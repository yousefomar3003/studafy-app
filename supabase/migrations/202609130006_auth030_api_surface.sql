-- AUTH-030 API database surface.
--
-- The API does not receive table privileges. Its entire database authority is
-- EXECUTE on the functions below, so the reviewable question is "which of
-- these may the API call", not "what DML might a handler have constructed".
-- This keeps the DB-021 posture intact: `studafy_api_runtime` still holds no
-- table or column grant, still cannot bypass RLS, and still inherits nothing.
--
-- Every function derives the acting user from `auth.uid()`. None accepts a
-- user identifier as a parameter, so a handler cannot act as another person
-- even if it wanted to. The API sets `request.jwt.claims` inside the
-- transaction from the token it has already verified against JWKS.

-- ---------------------------------------------------------------------------
-- Security event recording
-- ---------------------------------------------------------------------------

-- `p_account_identifier` is hashed here and never stored in the clear. The
-- API passes it only for failure events, where no `auth.uid()` exists yet and
-- rate-limiting an account still has to be possible.
create or replace function private.auth_record_security_event(
  p_event_type text,
  p_outcome text,
  p_reason_code text,
  p_account_identifier text default null,
  p_school_id uuid default null,
  p_method text default null,
  p_aal text default null,
  p_ip text default null,
  p_device_hash text default null,
  p_user_agent_family text default null,
  p_request_id uuid default null
)
returns void
language plpgsql
security definer
set search_path = ''
as $$
begin
  insert into public.auth_security_events (
    actor_id, account_hash, school_id, event_type, outcome, reason_code,
    method, aal, ip_hash, device_hash, user_agent_family, request_id
  ) values (
    auth.uid(),
    private.auth_normalized_hash('account', p_account_identifier),
    p_school_id,
    p_event_type,
    p_outcome,
    p_reason_code,
    p_method,
    p_aal,
    private.auth_normalized_hash('network', p_ip),
    p_device_hash,
    left(p_user_agent_family, 64),
    p_request_id
  );
end;
$$;

-- ---------------------------------------------------------------------------
-- Session context
-- ---------------------------------------------------------------------------

-- One round trip for everything an authenticated request needs to decide
-- authority: profile state, active memberships, the school's active term, the
-- revocation watermark, and a membership version the API can cache against.
--
-- `membership_version` changes whenever any membership row that grants this
-- user authority changes, so a cache keyed on it cannot serve a stale grant
-- past a revocation.
create or replace function private.auth_context()
returns jsonb
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  actor uuid := auth.uid();
  result jsonb;
begin
  if actor is null then
    return null;
  end if;

  select jsonb_build_object(
    'user_id', p.id,
    'display_name', p.display_name,
    'locale', p.locale,
    'profile_status', p.status,
    'profile_deleted_at', p.deleted_at,
    'revoked_before', (
      select r.revoked_before
      from public.auth_session_revocations r
      where r.user_id = actor
    ),
    'deletion_state', (
      select d.state
      from public.account_deletion_requests d
      where d.user_id = actor
        and d.state in ('grace_period', 'executing')
      limit 1
    ),
    'memberships', coalesce((
      select jsonb_agg(
        jsonb_build_object(
          'id', m.id,
          'school_id', m.school_id,
          'school_name', s.name,
          'school_timezone', s.timezone,
          'role', m.role,
          'active', m.active,
          'active_term_id', (
            select t.id
            from public.terms t
            where t.school_id = m.school_id
              and t.active
              and t.status = 'active'
            limit 1
          )
        )
        order by s.name, m.role
      )
      from public.memberships m
      join public.schools s on s.id = m.school_id
      where m.user_id = actor
        and m.active
        and m.status = 'active'
        and m.valid_from <= now()
        and (m.valid_until is null or m.valid_until > now())
        and s.status = 'active'
        and s.deleted_at is null
    ), '[]'::jsonb),
    'membership_version', coalesce((
      select encode(
        extensions.digest(
          string_agg(
            m.id::text || ':' || m.status || ':' || m.active::text || ':' ||
            extract(epoch from m.updated_at)::text,
            '|' order by m.id
          ),
          'sha256'
        ),
        'hex'
      )
      from public.memberships m
      where m.user_id = actor
    ), 'none'),
    'mfa_enrolled', exists (
      select 1
      from auth.mfa_factors f
      where f.user_id = actor and f.status = 'verified'
    )
  )
  into result
  from public.profiles p
  where p.id = actor;

  return result;
end;
$$;

-- ---------------------------------------------------------------------------
-- Devices and revocation
-- ---------------------------------------------------------------------------

create or replace function private.auth_touch_device(
  p_device_hash text,
  p_platform text,
  p_app_version text default null,
  p_display_label text default null
)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  actor uuid := auth.uid();
  device public.auth_devices;
begin
  if actor is null then
    return null;
  end if;

  insert into public.auth_devices (
    user_id, device_hash, platform, app_version, display_label
  ) values (
    actor, p_device_hash, p_platform, p_app_version, left(p_display_label, 64)
  )
  on conflict (user_id, device_hash) do update
    set last_seen_at = now(),
        app_version = coalesce(excluded.app_version, public.auth_devices.app_version),
        display_label = coalesce(excluded.display_label, public.auth_devices.display_label)
  returning * into device;

  return jsonb_build_object(
    'id', device.id,
    'revoked', device.revoked_at is not null
  );
end;
$$;

create or replace function private.auth_list_devices()
returns jsonb
language sql
stable
security definer
set search_path = ''
as $$
  select coalesce(
    jsonb_agg(
      jsonb_build_object(
        'id', d.id,
        'platform', d.platform,
        'app_version', d.app_version,
        'display_label', d.display_label,
        'first_seen_at', d.first_seen_at,
        'last_seen_at', d.last_seen_at,
        'revoked_at', d.revoked_at
      )
      order by d.last_seen_at desc
    ),
    '[]'::jsonb
  )
  from public.auth_devices d
  where d.user_id = auth.uid();
$$;

create or replace function private.auth_revoke_device(
  p_device_id uuid,
  p_reason text default 'user_revoked'
)
returns boolean
language plpgsql
security definer
set search_path = ''
as $$
declare
  actor uuid := auth.uid();
  affected integer;
begin
  if actor is null then
    return false;
  end if;

  update public.auth_devices
  set revoked_at = now(),
      revoked_by = actor,
      revocation_reason = p_reason
  where id = p_device_id
    and user_id = actor
    and revoked_at is null;

  get diagnostics affected = row_count;
  return affected > 0;
end;
$$;

-- All-device sign-out. Supabase invalidates the refresh tokens; the watermark
-- is what stops the access tokens that are already in flight, so the bound is
-- "next request" rather than "next token expiry".
create or replace function private.auth_sign_out_all(
  p_reason text default 'all_device_sign_out'
)
returns timestamptz
language plpgsql
security definer
set search_path = ''
as $$
declare
  actor uuid := auth.uid();
  watermark timestamptz := now();
begin
  if actor is null then
    return null;
  end if;

  insert into public.auth_session_revocations (
    user_id, revoked_before, reason, actor_id
  ) values (actor, watermark, p_reason, actor)
  on conflict (user_id) do update
    set revoked_before = excluded.revoked_before,
        reason = excluded.reason,
        actor_id = excluded.actor_id;

  update public.auth_devices
  set revoked_at = watermark,
      revoked_by = actor,
      revocation_reason = 'all_device_sign_out'
  where user_id = actor and revoked_at is null;

  return watermark;
end;
$$;

-- ---------------------------------------------------------------------------
-- Recent authentication
-- ---------------------------------------------------------------------------

-- The API generates an opaque grant, hands the token to the caller once, and
-- stores only its digest. `on conflict` replaces any live grant for the same
-- purpose so an older unconsumed grant cannot be held in reserve.
create or replace function private.auth_issue_reauth_grant(
  p_purpose text,
  p_grant_hash text,
  p_session_id uuid,
  p_aal text,
  p_ttl_seconds integer
)
returns timestamptz
language plpgsql
security definer
set search_path = ''
as $$
declare
  actor uuid := auth.uid();
  expiry timestamptz;
begin
  if actor is null then
    return null;
  end if;
  if p_ttl_seconds is null or p_ttl_seconds < 1 or p_ttl_seconds > 1800 then
    raise exception 'Reauth grant lifetime out of range';
  end if;

  delete from public.auth_reauth_grants
  where user_id = actor and purpose = p_purpose and consumed_at is null;

  expiry := now() + make_interval(secs => p_ttl_seconds);

  insert into public.auth_reauth_grants (
    user_id, purpose, grant_hash, session_id, aal, expires_at
  ) values (
    actor, p_purpose, p_grant_hash, p_session_id, p_aal, expiry
  );

  return expiry;
end;
$$;

-- Single-use. The UPDATE ... WHERE consumed_at is null is the atomic claim, so
-- two concurrent replays cannot both succeed.
create or replace function private.auth_consume_reauth_grant(
  p_purpose text,
  p_grant_hash text,
  p_session_id uuid,
  p_request_id uuid default null
)
returns boolean
language plpgsql
security definer
set search_path = ''
as $$
declare
  actor uuid := auth.uid();
  affected integer;
begin
  if actor is null then
    return false;
  end if;

  update public.auth_reauth_grants
  set consumed_at = now(),
      consumed_request_id = p_request_id
  where user_id = actor
    and purpose = p_purpose
    and grant_hash = p_grant_hash
    and session_id = p_session_id
    and consumed_at is null
    and expires_at > now();

  get diagnostics affected = row_count;
  return affected > 0;
end;
$$;

-- ---------------------------------------------------------------------------
-- Identity linking
-- ---------------------------------------------------------------------------

create or replace function private.auth_link_identity(
  p_provider text,
  p_subject text,
  p_is_primary boolean default false
)
returns text
language plpgsql
security definer
set search_path = ''
as $$
declare
  actor uuid := auth.uid();
  subject_hash text;
  existing_owner uuid;
begin
  if actor is null then
    return 'unauthenticated';
  end if;

  subject_hash := private.auth_normalized_hash('account', p_provider || ':' || p_subject);

  select l.user_id into existing_owner
  from public.auth_identity_links l
  where l.provider = p_provider
    and l.provider_subject_hash = subject_hash
    and l.unlinked_at is null;

  if existing_owner = actor then
    return 'already_linked';
  end if;

  -- The identity belongs to a different canonical profile. Merging profiles is
  -- a school-operations workflow (API-042), not something a link request may
  -- do implicitly, so this refuses rather than reassigns.
  if existing_owner is not null then
    return 'collision';
  end if;

  if p_is_primary then
    update public.auth_identity_links
    set is_primary = false
    where user_id = actor and unlinked_at is null and is_primary;
  end if;

  insert into public.auth_identity_links (
    user_id, provider, provider_subject_hash, is_primary, linked_by
  ) values (actor, p_provider, subject_hash, p_is_primary, actor);

  return 'linked';
end;
$$;

create or replace function private.auth_unlink_identity(
  p_provider text,
  p_subject text
)
returns text
language plpgsql
security definer
set search_path = ''
as $$
declare
  actor uuid := auth.uid();
  subject_hash text;
  target public.auth_identity_links;
  remaining integer;
begin
  if actor is null then
    return 'unauthenticated';
  end if;

  subject_hash := private.auth_normalized_hash('account', p_provider || ':' || p_subject);

  select * into target
  from public.auth_identity_links l
  where l.user_id = actor
    and l.provider = p_provider
    and l.provider_subject_hash = subject_hash
    and l.unlinked_at is null;

  if target.id is null then
    return 'not_linked';
  end if;

  select count(*) into remaining
  from public.auth_identity_links l
  where l.user_id = actor and l.unlinked_at is null;

  -- Unlinking the last identity would leave an account nobody can sign in to.
  if remaining <= 1 then
    return 'last_identity';
  end if;

  update public.auth_identity_links
  set unlinked_at = now(), unlinked_by = actor, is_primary = false
  where id = target.id;

  return 'unlinked';
end;
$$;

-- ---------------------------------------------------------------------------
-- Account deletion
-- ---------------------------------------------------------------------------

-- The impact summary is computed server-side so the confirmation screen states
-- what will actually happen to this account rather than generic copy. School
-- records a student cannot delete are counted explicitly, because a reviewer
-- reading "some records may remain" with no detail treats it as a missing
-- deletion flow.
create or replace function private.auth_deletion_impact()
returns jsonb
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  actor uuid := auth.uid();
begin
  if actor is null then
    return null;
  end if;

  return jsonb_build_object(
    'memberships', (
      select coalesce(jsonb_agg(jsonb_build_object(
        'school_name', s.name, 'role', m.role
      ) order by s.name), '[]'::jsonb)
      from public.memberships m
      join public.schools s on s.id = m.school_id
      where m.user_id = actor and m.active and m.status = 'active'
    ),
    'retained_school_records', jsonb_build_object(
      'attendance', (
        select count(*) from public.attendance_records a
        join public.students st on st.id = a.student_id
        where st.user_id = actor
      ),
      'grades', (
        select count(*) from public.grade_results g
        join public.students st on st.id = g.student_id
        where st.user_id = actor
      ),
      'submissions', (
        select count(*) from public.submissions sub
        join public.students st on st.id = sub.student_id
        where st.user_id = actor
      ),
      'wellbeing', (
        select count(*) from public.wellbeing_events w
        join public.students st on st.id = w.student_id
        where st.user_id = actor
      )
    ),
    'deleted_personal_data', jsonb_build_object(
      'profile', 1,
      'devices', (
        select count(*) from public.auth_devices d where d.user_id = actor
      ),
      'consents', (
        select count(*) from public.consent_records c where c.user_id = actor
      ),
      'notifications', (
        select count(*) from public.notifications n where n.user_id = actor
      )
    ),
    'guardian_links', (
      select count(*) from public.guardian_links gl
      where gl.guardian_id = actor and gl.status = 'verified'
    ),
    'active_entitlements', (
      select count(*) from public.entitlements e
      where e.user_id = actor and e.status = 'active'
    )
  );
end;
$$;

create or replace function private.auth_request_deletion(
  p_reason_code text,
  p_impact jsonb,
  p_grace_days integer default 14
)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  actor uuid := auth.uid();
  existing public.account_deletion_requests;
  created public.account_deletion_requests;
  execute_at timestamptz;
begin
  if actor is null then
    return null;
  end if;
  if p_grace_days < 1 or p_grace_days > 90 then
    raise exception 'Deletion grace period out of range';
  end if;

  select * into existing
  from public.account_deletion_requests d
  where d.user_id = actor and d.state in ('grace_period', 'executing')
  limit 1;

  -- Idempotent: asking twice returns the live request rather than failing or
  -- creating a second one.
  if existing.id is not null then
    return jsonb_build_object(
      'id', existing.id,
      'state', existing.state,
      'execute_after', existing.execute_after,
      'created', false
    );
  end if;

  execute_at := now() + make_interval(days => p_grace_days);

  insert into public.account_deletion_requests (
    user_id, state, requested_at, execute_after, reason_code,
    requested_via, impact_snapshot
  ) values (
    actor, 'grace_period', now(), execute_at, p_reason_code,
    'in_app', p_impact
  )
  returning * into created;

  insert into public.audit_events (
    actor_id, action, entity_type, entity_id, after_value
  ) values (
    actor, 'account_deletion_requested', 'profile', actor,
    jsonb_build_object('execute_after', execute_at, 'request_id', created.id)
  );

  return jsonb_build_object(
    'id', created.id,
    'state', created.state,
    'execute_after', created.execute_after,
    'created', true
  );
end;
$$;

create or replace function private.auth_cancel_deletion()
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  actor uuid := auth.uid();
  cancelled public.account_deletion_requests;
begin
  if actor is null then
    return null;
  end if;

  -- Only a request still inside its grace period may be cancelled; once
  -- execution has begun the data is already going.
  update public.account_deletion_requests
  set state = 'cancelled', cancelled_at = now(), cancelled_by = actor
  where user_id = actor and state = 'grace_period'
  returning * into cancelled;

  if cancelled.id is null then
    return jsonb_build_object('cancelled', false);
  end if;

  insert into public.audit_events (
    actor_id, action, entity_type, entity_id, after_value
  ) values (
    actor, 'account_deletion_cancelled', 'profile', actor,
    jsonb_build_object('request_id', cancelled.id)
  );

  return jsonb_build_object('cancelled', true, 'id', cancelled.id);
end;
$$;

-- ---------------------------------------------------------------------------
-- Ownership and the API grant surface
-- ---------------------------------------------------------------------------

do $auth030$
declare
  signature text;
begin
  foreach signature in array array[
    'private.auth_record_security_event(text, text, text, text, uuid, text, text, text, text, text, uuid)',
    'private.auth_context()',
    'private.auth_touch_device(text, text, text, text)',
    'private.auth_list_devices()',
    'private.auth_revoke_device(uuid, text)',
    'private.auth_sign_out_all(text)',
    'private.auth_issue_reauth_grant(text, text, uuid, text, integer)',
    'private.auth_consume_reauth_grant(text, text, uuid, uuid)',
    'private.auth_link_identity(text, text, boolean)',
    'private.auth_unlink_identity(text, text)',
    'private.auth_deletion_impact()',
    'private.auth_request_deletion(text, jsonb, integer)',
    'private.auth_cancel_deletion()'
  ]
  loop
    execute format('alter function %s owner to postgres', signature);
    execute format(
      'revoke all on function %s from public, anon, authenticated, service_role, studafy_worker_runtime',
      signature
    );
    execute format(
      'grant execute on function %s to studafy_api_runtime',
      signature
    );
  end loop;
end
$auth030$;

alter function private.auth_normalized_hash(text, text) owner to postgres;
revoke all on function private.auth_normalized_hash(text, text)
from public, anon, authenticated, service_role,
  studafy_api_runtime, studafy_worker_runtime;

-- The API needs to resolve the schema to reach the functions above, and
-- nothing else. It receives no table, column, or sequence privilege here, so
-- the DB-021 grant posture is unchanged.
grant usage on schema private to studafy_api_runtime;

-- Activate the role. The password is deliberately not set here: a credential
-- in a migration is a committed secret. It is provisioned out of band —
-- locally by scripts/bootstrap-local-api-role.ts, in a deployed environment by
-- the secret manager (INFRA-080). Until then the role cannot connect.
alter role studafy_api_runtime login;

-- The migration owner must be able to SET ROLE to the runtime role to
-- administer and test it. The role is NOINHERIT, so this conveys nothing
-- implicitly: privileges apply only after an explicit SET ROLE.
grant studafy_api_runtime to postgres;
