-- API-042 S3: guarded student locator and guardian linking. locateStudent is
-- a POST, not a query, specifically so its rate-limit check and per-attempt
-- audit row (the only real defence against a human-readable studafy_id
-- being enumerated, since Redis-backed limits are still Phase 6) can be a
-- single atomic write, not a side effect smuggled into a `stable` function.

-- A guardian who only ever has a guardian_links row (no memberships row -
-- guardian membership is "if required by school policy" per instructions.md
-- section 6, not universal) must still be able to reserve an idempotency
-- key to revoke their own link. Widen the same gate S1 widened for platform
-- operators, with an equally narrow allowlist condition.
create or replace function private.api_idempotency_reserve(
  p_school_id uuid,
  p_scope text,
  p_key text,
  p_request_hash text,
  p_retention_seconds integer default 86400,
  p_lease_seconds integer default 15
)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  actor uuid := auth.uid();
  existing public.idempotency_records%rowtype;
begin
  if actor is null or not private.is_active_user() then
    return jsonb_build_object('outcome', 'denied');
  end if;
  if p_school_id is not null
    and not private.has_active_membership(p_school_id, null)
    and not private.is_platform_operator()
    and not exists (
      select 1 from public.guardian_links gl
      where gl.school_id = p_school_id and gl.guardian_id = actor
    ) then
    return jsonb_build_object('outcome', 'denied');
  end if;
  if p_scope !~ '^[A-Za-z0-9][A-Za-z0-9._:-]{2,127}$'
     or p_key !~ '^[A-Za-z0-9][A-Za-z0-9._:-]{15,127}$'
     or p_request_hash !~ '^[0-9a-f]{64}$'
     or p_retention_seconds not between 60 and 604800
     or p_lease_seconds not between 1 and 60 then
    return jsonb_build_object('outcome', 'invalid');
  end if;

  perform pg_advisory_xact_lock(hashtextextended(
    coalesce(p_school_id::text, 'global') || ':' || actor::text || ':' || p_scope || ':' || p_key,
    0
  ));

  select * into existing
  from public.idempotency_records r
  where r.school_id is not distinct from p_school_id
    and r.actor_id = actor
    and r.scope = p_scope
    and r.idempotency_key = p_key
  for update;

  if found and existing.expires_at <= now() then
    delete from public.idempotency_records where id = existing.id;
    existing := null;
  end if;

  if existing.id is null then
    insert into public.idempotency_records (
      school_id, actor_id, scope, idempotency_key, request_hash,
      status, expires_at, lease_expires_at
    ) values (
      p_school_id, actor, p_scope, p_key, p_request_hash,
      'reserved', now() + make_interval(secs => p_retention_seconds),
      now() + make_interval(secs => p_lease_seconds)
    ) returning * into existing;
    return jsonb_build_object(
      'outcome', 'reserved', 'id', existing.id, 'generation', existing.generation
    );
  end if;

  if existing.request_hash <> p_request_hash then
    return jsonb_build_object('outcome', 'mismatch');
  end if;
  if existing.status = 'completed' then
    return jsonb_build_object(
      'outcome', 'replay', 'responseStatus', existing.response_status,
      'responseBody', existing.response_body
    );
  end if;
  if existing.status = 'reserved' and existing.lease_expires_at > now() then
    return jsonb_build_object('outcome', 'inProgress');
  end if;

  update public.idempotency_records r
  set status = 'reserved', generation = r.generation + 1,
      lease_expires_at = now() + make_interval(secs => p_lease_seconds),
      response_status = null, response_body = null
  where r.id = existing.id
  returning * into existing;

  return jsonb_build_object(
    'outcome', 'reserved', 'id', existing.id, 'generation', existing.generation
  );
end;
$$;

alter function private.api042_command(text, uuid, jsonb, uuid, bigint)
  rename to api042_command_pre_s3_family;

alter function private.authz_authorize(text, uuid)
  rename to authz_authorize_pre_api042_family;

create or replace function private.authz_authorize(p_action text, p_resource_id uuid)
returns jsonb language plpgsql stable security definer set search_path = '' as $$
declare target_school uuid; permitted boolean := false;
begin
  if p_action not in ('guardian_link.verify', 'guardian_link.revoke') then
    return private.authz_authorize_pre_api042_family(p_action, p_resource_id);
  end if;
  if auth.uid() is null or p_resource_id is null then
    return jsonb_build_object('allowed', false, 'school_id', null, 'reason', 'invalid_resource');
  end if;

  case
    when p_action = 'guardian_link.verify' then
      select gl.school_id, private.is_school_admin(gl.school_id)
      into target_school, permitted from public.guardian_links gl where gl.id = p_resource_id;
    when p_action = 'guardian_link.revoke' then
      select gl.school_id, (private.is_school_admin(gl.school_id) or gl.guardian_id = auth.uid())
      into target_school, permitted from public.guardian_links gl where gl.id = p_resource_id;
  end case;
  return jsonb_build_object('allowed', coalesce(permitted, false), 'school_id', target_school,
    'reason', case when target_school is null then 'invalid_resource' when permitted then 'allowed' else 'denied' end);
end;
$$;

create or replace function private.api042_guardian_link_json(p_id uuid)
returns jsonb language sql stable security definer set search_path = '' as $$
  select jsonb_build_object(
    'id', gl.id, 'schoolId', gl.school_id, 'studentId', gl.student_id, 'guardianId', gl.guardian_id,
    'relationship', gl.relationship, 'status', gl.status, 'expiresAt', gl.expires_at
  ) from public.guardian_links gl where gl.id = p_id;
$$;

create or replace function private.api042_command(
  p_operation text,
  p_resource_id uuid,
  p_input jsonb,
  p_idempotency_id uuid,
  p_idempotency_generation bigint
)
returns jsonb language plpgsql security definer set search_path = '' as $$
declare
  tenant uuid := nullif(current_setting('studafy.school_id', true), '')::uuid;
  request_id text := nullif(current_setting('studafy.request_id', true), '');
  body jsonb := coalesce(p_input->'body', '{}'::jsonb);
  response jsonb; before_value jsonb;
  entity_id uuid; entity_type text; audit_action text;
  idem_key text; resolved_school uuid; existing_status text;
  v_student_id uuid; v_recent_attempts bigint; v_expires_days int;
  outbox_template text; outbox_entity uuid; completed boolean;
  response_status int := coalesce((p_input->>'responseStatus')::int, 200);
begin
  if p_operation not in ('locateStudent', 'requestGuardianLink', 'verifyGuardianLink', 'revokeGuardianLink') then
    return private.api042_command_pre_s3_family(
      p_operation, p_resource_id, p_input, p_idempotency_id, p_idempotency_generation
    );
  end if;
  if auth.uid() is null or request_id is null then
    return jsonb_build_object('outcome', 'forbidden');
  end if;
  select r.idempotency_key into idem_key from public.idempotency_records r
  where r.id = p_idempotency_id and r.actor_id = auth.uid()
    and r.school_id is not distinct from tenant
    and r.generation = p_idempotency_generation and r.status = 'reserved'
  for update;
  if idem_key is null then return jsonb_build_object('outcome', 'forbidden'); end if;

  case p_operation
    when 'locateStudent' then
      select count(*) into v_recent_attempts from public.audit_events
      where actor_id = auth.uid() and action = 'student_locate_attempted' and created_at > now() - interval '1 hour';
      if v_recent_attempts >= 10 then return jsonb_build_object('outcome', 'invalid_state'); end if;
      select st.id, st.school_id into v_student_id, resolved_school
      from public.students st where st.studafy_id = body->>'studafyId';
      -- Uniform shape whether found or not: only the nullable fields differ,
      -- never the outcome or response structure, so response shape/timing
      -- cannot itself be used to enumerate valid codes.
      response := case when v_student_id is null then jsonb_build_object('found', false, 'studentId', null, 'displayName', null)
        else jsonb_build_object('found', true, 'studentId', v_student_id,
          'displayName', (select display_name from public.students where id = v_student_id)) end;
      entity_type := 'student_locate'; entity_id := v_student_id; audit_action := 'student_locate_attempted';
      tenant := resolved_school;

    when 'requestGuardianLink' then
      v_student_id := (body->>'studentId')::uuid;
      select st.school_id into resolved_school from public.students st where st.id = v_student_id;
      if resolved_school is null then return jsonb_build_object('outcome', 'not_found'); end if;
      select status::text into existing_status from public.guardian_links
      where student_id = v_student_id and guardian_id = auth.uid();
      if existing_status in ('pending', 'verified') then return jsonb_build_object('outcome', 'invalid'); end if;
      insert into public.guardian_links(school_id, student_id, guardian_id, status, relationship)
      values (resolved_school, v_student_id, auth.uid(), 'pending', nullif(body->>'relationship', ''))
      on conflict (student_id, guardian_id) do update set
        status = 'pending', relationship = nullif(body->>'relationship', ''),
        verified_by = null, verified_at = null, expires_at = null, updated_at = now()
      returning id into entity_id;
      tenant := resolved_school;
      response := private.api042_guardian_link_json(entity_id);
      entity_type := 'guardian_link'; audit_action := 'guardian_link_requested';
      outbox_template := 'family.guardian_link_requested'; outbox_entity := entity_id;

    when 'verifyGuardianLink' then
      select gl.school_id, gl.status::text, to_jsonb(gl) into resolved_school, existing_status, before_value
      from public.guardian_links gl where gl.id = p_resource_id for update;
      if resolved_school is null then return jsonb_build_object('outcome', 'not_found'); end if;
      -- Only an admin ever reaches this case (see authz_authorize), and an
      -- admin always has a membership in the resolved school, so tenant is
      -- reliably non-null here; this is defense in depth against a future
      -- middleware bug, not the only check.
      if resolved_school <> tenant then return jsonb_build_object('outcome', 'forbidden'); end if;
      if not private.is_school_admin(tenant) then return jsonb_build_object('outcome', 'forbidden'); end if;
      if existing_status <> 'pending' then return jsonb_build_object('outcome', 'invalid_state'); end if;
      v_expires_days := coalesce((body->>'expiresInDays')::int, 365);
      if v_expires_days < 1 or v_expires_days > 1825 then return jsonb_build_object('outcome', 'invalid'); end if;
      update public.guardian_links set status = 'verified', verified_by = auth.uid(), verified_at = now(),
        expires_at = now() + make_interval(days => v_expires_days), updated_at = now()
      where id = p_resource_id;
      entity_id := p_resource_id; entity_type := 'guardian_link'; audit_action := 'guardian_link_verified';
      response := private.api042_guardian_link_json(entity_id);
      outbox_template := 'family.guardian_link_verified'; outbox_entity := entity_id;

    when 'revokeGuardianLink' then
      select gl.school_id, gl.status::text, to_jsonb(gl) into resolved_school, existing_status, before_value
      from public.guardian_links gl where gl.id = p_resource_id for update;
      if resolved_school is null then return jsonb_build_object('outcome', 'not_found'); end if;
      -- tenant may be null here: the revoking guardian often has no
      -- memberships row at all (guardian_link.revoke is not tenantRequired
      -- for exactly this reason). resolved_school, read directly from the
      -- row the actor is actually touching, is the real tenant for the
      -- rest of this command; tenant is reassigned to it once the
      -- authorization check below has run.
      if not (private.is_school_admin(resolved_school) or (select guardian_id from public.guardian_links where id = p_resource_id) = auth.uid())
      then return jsonb_build_object('outcome', 'forbidden'); end if;
      if existing_status not in ('pending', 'verified') then return jsonb_build_object('outcome', 'invalid_state'); end if;
      tenant := resolved_school;
      update public.guardian_links set status = 'revoked', updated_at = now() where id = p_resource_id;
      entity_id := p_resource_id; entity_type := 'guardian_link'; audit_action := 'guardian_link_revoked';
      response := private.api042_guardian_link_json(entity_id);
      outbox_template := 'family.guardian_link_revoked'; outbox_entity := entity_id;

    else return jsonb_build_object('outcome', 'invalid');
  end case;

  insert into public.audit_events(school_id, actor_id, action, entity_type, entity_id, before_value, after_value, request_id)
  values (tenant, auth.uid(), audit_action, entity_type, entity_id, before_value, response, request_id);
  if outbox_template is not null then
    insert into public.notification_outbox(school_id, source_event_id, idempotency_key, channel, template_key, audience, payload)
    values (tenant, outbox_entity::text, idem_key, 'in_app', outbox_template,
      jsonb_build_object('schoolId', tenant), coalesce(response, '{}'::jsonb));
  end if;
  completed := private.api_idempotency_complete(p_idempotency_id, p_idempotency_generation, response_status, response);
  if not completed then raise exception 'API042_IDEMPOTENCY_COMPLETION_FAILED'; end if;
  return jsonb_build_object('outcome', 'ok', 'response', response);
end;
$$;

alter function private.api042_guardian_link_json(uuid) owner to postgres;
alter function private.api042_command(text, uuid, jsonb, uuid, bigint) owner to postgres;
alter function private.authz_authorize(text, uuid) owner to postgres;

revoke all on function private.api042_guardian_link_json(uuid), private.api042_command(text, uuid, jsonb, uuid, bigint)
from public, anon, authenticated, service_role, studafy_worker_runtime;
revoke all on function private.api042_command_pre_s3_family(text, uuid, jsonb, uuid, bigint)
from public, anon, authenticated, service_role, studafy_worker_runtime, studafy_api_runtime;
revoke all on function private.authz_authorize_pre_api042_family(text, uuid)
from public, anon, authenticated, service_role, studafy_worker_runtime, studafy_api_runtime;
revoke all on function private.authz_authorize(text, uuid)
from public, anon, authenticated, service_role, studafy_worker_runtime;
grant execute on function private.authz_authorize(text, uuid), private.api042_command(text, uuid, jsonb, uuid, bigint)
to studafy_api_runtime;

revoke all privileges on all tables in schema public from studafy_api_runtime;
revoke all privileges on all sequences in schema public from studafy_api_runtime;
