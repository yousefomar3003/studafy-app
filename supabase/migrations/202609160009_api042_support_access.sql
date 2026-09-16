-- API-042 S8: time-bounded, MFA-gated, two-person-approved support access.
-- requestSupportAccess/approveSupportAccess/startSupportAccess all require
-- actor.aal2 (a session that actually presented a second factor this
-- session, not merely MFA enrollment) - checked in TypeScript from the
-- widened RequestDbContext.aal2 and re-checked here from
-- mfa_verified_at, which only requestSupportAccess is allowed to set and
-- only when it is itself given a verified assurance timestamp.

create or replace function private.is_second_approver(p_grant uuid)
returns boolean language sql stable security definer set search_path = '' as $$
  select private.is_platform_operator() and exists (
    select 1 from public.support_access_grants g where g.id = p_grant and g.requested_by <> auth.uid()
  );
$$;

alter function private.authz_authorize(text, uuid)
  rename to authz_authorize_pre_api042_support;

create or replace function private.authz_authorize(p_action text, p_resource_id uuid)
returns jsonb language plpgsql stable security definer set search_path = '' as $$
declare target_school uuid; permitted boolean := false;
begin
  if p_action not in ('support_access.approve', 'support_access.start', 'support_access.revoke', 'support_access.list') then
    return private.authz_authorize_pre_api042_support(p_action, p_resource_id);
  end if;
  if auth.uid() is null or p_resource_id is null then
    return jsonb_build_object('allowed', false, 'school_id', null, 'reason', 'invalid_resource');
  end if;

  case
    when p_action = 'support_access.approve' then
      select g.school_id, private.is_second_approver(g.id)
      into target_school, permitted from public.support_access_grants g where g.id = p_resource_id;
    when p_action = 'support_access.start' then
      select g.school_id, (g.requested_by = auth.uid())
      into target_school, permitted from public.support_access_grants g where g.id = p_resource_id;
    when p_action = 'support_access.revoke' then
      select g.school_id, (private.is_platform_operator() or private.is_school_admin(g.school_id))
      into target_school, permitted from public.support_access_grants g where g.id = p_resource_id;
    when p_action = 'support_access.list' then
      select s.id, (private.is_platform_operator() or private.is_school_admin(s.id))
      into target_school, permitted from public.schools s where s.id = p_resource_id;
  end case;
  return jsonb_build_object('allowed', coalesce(permitted, false), 'school_id', target_school,
    'reason', case when target_school is null then 'invalid_resource' when permitted then 'allowed' else 'denied' end);
end;
$$;

create or replace function private.api042_support_grant_json(p_id uuid)
returns jsonb language sql stable security definer set search_path = '' as $$
  select jsonb_build_object(
    'id', g.id, 'schoolId', g.school_id, 'requestedBy', g.requested_by, 'approvedBy', g.approved_by,
    'reason', g.reason, 'ticketRef', g.ticket_ref, 'resourceScope', g.resource_scope, 'status', g.status,
    'requiresSecondApprover', g.requires_second_approver, 'expiresAt', g.expires_at,
    'startedAt', g.started_at, 'endedAt', g.ended_at, 'version', g.version
  ) from public.support_access_grants g where g.id = p_id;
$$;

-- Lazily expires any grant this actor can see that is past its own
-- expires_at and still in a live state, before it is read or acted on -
-- there is no scheduled worker to do this yet (OPS-061), the same honest
-- gap S2's invitation expiry documents.
create or replace function private.lazily_expire_support_access(p_school uuid)
returns void language sql security definer set search_path = '' as $$
  update public.support_access_grants set status = 'expired', updated_at = now()
  where school_id = p_school and status in ('pending', 'approved', 'active') and expires_at <= now();
$$;

alter function private.api042_query(text, uuid, jsonb)
  rename to api042_query_pre_s8_support;

create or replace function private.api042_query(p_operation text, p_resource_id uuid, p_input jsonb)
returns jsonb language plpgsql stable security definer set search_path = '' as $$
declare limit_rows int; pos uuid; result jsonb; next_pos text;
begin
  if p_operation <> 'listSupportAccessGrants' then
    return private.api042_query_pre_s8_support(p_operation, p_resource_id, p_input);
  end if;
  if auth.uid() is null then return jsonb_build_object('outcome', 'forbidden'); end if;
  if not (private.is_platform_operator() or private.is_school_admin(p_resource_id)) then
    return jsonb_build_object('outcome', 'forbidden');
  end if;
  limit_rows := least(greatest(coalesce((p_input->>'pageSize')::int, 50), 1), 100);
  pos := nullif(p_input->>'position', '')::uuid;
  select coalesce(jsonb_agg(private.api042_support_grant_json(x.id) order by x.id), '[]'), max(x.id::text)
    into result, next_pos from (
    select g.id from public.support_access_grants g where g.school_id = p_resource_id and (pos is null or g.id > pos)
    order by g.id limit limit_rows
  ) x;
  return jsonb_build_object('items', result, 'nextPosition', case when jsonb_array_length(result) = limit_rows then next_pos end);
end;
$$;

alter function private.api042_command(text, uuid, jsonb, uuid, bigint)
  rename to api042_command_pre_s8_support;

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
  req_body jsonb := coalesce(p_input->'body', '{}'::jsonb);
  req_aal2 boolean := coalesce((p_input->>'aal2')::boolean, false);
  response jsonb; before_value jsonb;
  entity_id uuid; entity_type text; audit_action text;
  idem_key text; resolved_school uuid; existing_status text; existing_version bigint;
  v_duration_minutes int; outbox_template text; outbox_entity uuid; completed boolean;
  response_status int := coalesce((p_input->>'responseStatus')::int, 200);
begin
  if p_operation not in ('requestSupportAccess', 'approveSupportAccess', 'startSupportAccess', 'revokeSupportAccess') then
    return private.api042_command_pre_s8_support(
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
    when 'requestSupportAccess' then
      resolved_school := (req_body->>'schoolId')::uuid;
      if not exists (select 1 from public.schools s where s.id = resolved_school) then
        return jsonb_build_object('outcome', 'not_found');
      end if;
      if not private.is_platform_operator() then return jsonb_build_object('outcome', 'forbidden'); end if;
      if not req_aal2 then return jsonb_build_object('outcome', 'forbidden'); end if;
      perform private.lazily_expire_support_access(resolved_school);
      v_duration_minutes := least(greatest(coalesce((req_body->>'durationMinutes')::int, 60), 1), 480);
      insert into public.support_access_grants(
        school_id, requested_by, reason, ticket_ref, resource_scope, status,
        requires_second_approver, mfa_verified_at, expires_at, version
      ) values (
        resolved_school, auth.uid(), req_body->>'reason', req_body->>'ticketRef',
        coalesce(req_body->'resourceScope', '{}'::jsonb), 'pending',
        coalesce((req_body->>'requiresSecondApprover')::boolean, true), now(),
        now() + make_interval(mins => v_duration_minutes), 1
      ) returning id into entity_id;
      tenant := resolved_school;
      response := private.api042_support_grant_json(entity_id);
      entity_type := 'support_access_grant'; audit_action := 'support_access_requested';
      outbox_template := 'support_access.requested'; outbox_entity := entity_id;

    when 'approveSupportAccess' then
      select g.school_id, g.status, g.version, to_jsonb(g) into resolved_school, existing_status, existing_version, before_value
      from public.support_access_grants g where g.id = p_resource_id for update;
      if resolved_school is null then return jsonb_build_object('outcome', 'not_found'); end if;
      if not private.is_second_approver(p_resource_id) then return jsonb_build_object('outcome', 'forbidden'); end if;
      if not req_aal2 then return jsonb_build_object('outcome', 'forbidden'); end if;
      perform private.lazily_expire_support_access(resolved_school);
      select status into existing_status from public.support_access_grants where id = p_resource_id;
      if existing_status <> 'pending' then return jsonb_build_object('outcome', 'invalid_state'); end if;
      if existing_version <> (req_body->>'expectedVersion')::bigint then return jsonb_build_object('outcome', 'version_conflict'); end if;
      update public.support_access_grants set status = 'approved', approved_by = auth.uid(), version = version + 1, updated_at = now()
      where id = p_resource_id;
      entity_id := p_resource_id; entity_type := 'support_access_grant'; audit_action := 'support_access_approved';
      tenant := resolved_school;
      response := private.api042_support_grant_json(entity_id);
      outbox_template := 'support_access.approved'; outbox_entity := entity_id;

    when 'startSupportAccess' then
      select g.school_id, g.status, g.version, to_jsonb(g) into resolved_school, existing_status, existing_version, before_value
      from public.support_access_grants g where g.id = p_resource_id for update;
      if resolved_school is null then return jsonb_build_object('outcome', 'not_found'); end if;
      if not exists (select 1 from public.support_access_grants g where g.id = p_resource_id and g.requested_by = auth.uid())
      then return jsonb_build_object('outcome', 'forbidden'); end if;
      perform private.lazily_expire_support_access(resolved_school);
      select status into existing_status from public.support_access_grants where id = p_resource_id;
      if existing_status <> 'approved' then return jsonb_build_object('outcome', 'invalid_state'); end if;
      if existing_version <> (req_body->>'expectedVersion')::bigint then return jsonb_build_object('outcome', 'version_conflict'); end if;
      update public.support_access_grants set status = 'active', started_at = now(), version = version + 1, updated_at = now()
      where id = p_resource_id;
      entity_id := p_resource_id; entity_type := 'support_access_grant'; audit_action := 'support_access_started';
      tenant := resolved_school;
      response := private.api042_support_grant_json(entity_id);
      outbox_template := 'support_access.started'; outbox_entity := entity_id;

    when 'revokeSupportAccess' then
      select g.school_id, g.status, g.version, to_jsonb(g) into resolved_school, existing_status, existing_version, before_value
      from public.support_access_grants g where g.id = p_resource_id for update;
      if resolved_school is null then return jsonb_build_object('outcome', 'not_found'); end if;
      if not (private.is_platform_operator() or private.is_school_admin(resolved_school)) then
        return jsonb_build_object('outcome', 'forbidden');
      end if;
      if existing_status not in ('pending', 'approved', 'active') then return jsonb_build_object('outcome', 'invalid_state'); end if;
      if existing_version <> (req_body->>'expectedVersion')::bigint then return jsonb_build_object('outcome', 'version_conflict'); end if;
      update public.support_access_grants set status = 'revoked', revoked_by = auth.uid(),
        revoked_reason = nullif(req_body->>'reason', ''), ended_at = now(), version = version + 1, updated_at = now()
      where id = p_resource_id;
      entity_id := p_resource_id; entity_type := 'support_access_grant'; audit_action := 'support_access_revoked';
      tenant := resolved_school;
      response := private.api042_support_grant_json(entity_id);
      outbox_template := 'support_access.revoked'; outbox_entity := entity_id;

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

alter function private.is_second_approver(uuid) owner to postgres;
alter function private.api042_support_grant_json(uuid) owner to postgres;
alter function private.lazily_expire_support_access(uuid) owner to postgres;
alter function private.api042_query(text, uuid, jsonb) owner to postgres;
alter function private.api042_command(text, uuid, jsonb, uuid, bigint) owner to postgres;
alter function private.authz_authorize(text, uuid) owner to postgres;

revoke all on function private.is_second_approver(uuid), private.api042_support_grant_json(uuid),
  private.lazily_expire_support_access(uuid), private.api042_query(text, uuid, jsonb),
  private.api042_command(text, uuid, jsonb, uuid, bigint)
from public, anon, authenticated, service_role, studafy_worker_runtime;
revoke all on function private.api042_query_pre_s8_support(text, uuid, jsonb)
from public, anon, authenticated, service_role, studafy_worker_runtime, studafy_api_runtime;
revoke all on function private.api042_command_pre_s8_support(text, uuid, jsonb, uuid, bigint)
from public, anon, authenticated, service_role, studafy_worker_runtime, studafy_api_runtime;
revoke all on function private.authz_authorize_pre_api042_support(text, uuid)
from public, anon, authenticated, service_role, studafy_worker_runtime, studafy_api_runtime;
revoke all on function private.authz_authorize(text, uuid)
from public, anon, authenticated, service_role, studafy_worker_runtime;
grant execute on function private.authz_authorize(text, uuid),
  private.api042_query(text, uuid, jsonb), private.api042_command(text, uuid, jsonb, uuid, bigint)
to studafy_api_runtime;

revoke all privileges on all tables in schema public from studafy_api_runtime;
revoke all privileges on all sequences in schema public from studafy_api_runtime;
