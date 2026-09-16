-- API-042 S2: invitations. Tokens are generated and hashed in TypeScript
-- (apps/api/src/invitations/repository.ts, same opaqueGrant/sha256Hex
-- pattern AUTH-030 uses for recent-auth grants); this migration only ever
-- sees the hash. acceptInvitation is self-scoped like provisionSchool - the
-- valid token is the credential, matching an ordinary invitation-link model,
-- not an authenticated actor's email (profiles carries no email to match
-- against, deliberately, per the data-minimization posture elsewhere in this
-- schema).

alter function private.api042_command(text, uuid, jsonb, uuid, bigint)
  rename to api042_command_pre_s2_invitations;

alter function private.authz_authorize(text, uuid)
  rename to authz_authorize_pre_api042_invitations;

create or replace function private.authz_authorize(p_action text, p_resource_id uuid)
returns jsonb language plpgsql stable security definer set search_path = '' as $$
declare target_school uuid; permitted boolean := false;
begin
  if p_action not in ('invitation.issue', 'invitation.revoke', 'invitation.list') then
    return private.authz_authorize_pre_api042_invitations(p_action, p_resource_id);
  end if;
  if auth.uid() is null or p_resource_id is null then
    return jsonb_build_object('allowed', false, 'school_id', null, 'reason', 'invalid_resource');
  end if;

  case
    when p_action in ('invitation.issue', 'invitation.list') then
      select s.id, private.is_school_admin(s.id)
      into target_school, permitted from public.schools s where s.id = p_resource_id;
    when p_action = 'invitation.revoke' then
      select i.school_id, private.is_school_admin(i.school_id)
      into target_school, permitted from public.invitations i where i.id = p_resource_id;
  end case;
  return jsonb_build_object('allowed', coalesce(permitted, false), 'school_id', target_school,
    'reason', case when target_school is null then 'invalid_resource' when permitted then 'allowed' else 'denied' end);
end;
$$;

create or replace function private.api042_invitation_json(p_id uuid)
returns jsonb language sql stable security definer set search_path = '' as $$
  select jsonb_build_object(
    'id', i.id, 'schoolId', i.school_id, 'role', i.role, 'email', i.email,
    'status', i.status, 'expiresAt', i.expires_at, 'version', i.version
  ) from public.invitations i where i.id = p_id;
$$;

create or replace function private.api042_query(p_operation text, p_resource_id uuid, p_input jsonb)
returns jsonb language plpgsql stable security definer set search_path = '' as $$
declare tenant uuid; limit_rows int; pos uuid; result jsonb; next_pos text;
begin
  tenant := nullif(current_setting('studafy.school_id', true), '')::uuid;
  if auth.uid() is null or tenant is null then return jsonb_build_object('outcome', 'forbidden'); end if;
  if not private.is_school_admin(tenant) then return jsonb_build_object('outcome', 'forbidden'); end if;
  limit_rows := least(greatest(coalesce((p_input->>'pageSize')::int, 50), 1), 100);
  pos := nullif(p_input->>'position', '')::uuid;
  case p_operation
    when 'listInvitations' then
      select coalesce(jsonb_agg(private.api042_invitation_json(x.id) order by x.id), '[]'), max(x.id::text)
        into result, next_pos from (
        select i.id from public.invitations i where i.school_id = tenant and (pos is null or i.id > pos)
        order by i.id limit limit_rows
      ) x;
      return jsonb_build_object('items', result, 'nextPosition', case when jsonb_array_length(result) = limit_rows then next_pos end);
    else return jsonb_build_object('outcome', 'not_found');
  end case;
end;
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
  idem_key text; resolved_school uuid; existing_status text; existing_expires timestamptz;
  v_attempt_count int; v_max_attempts int; outbox_template text; outbox_entity uuid;
  completed boolean; v_role public.app_role; v_invitation_id uuid; v_membership_id uuid;
  existing_version bigint;
  response_status int := coalesce((p_input->>'responseStatus')::int, 200);
begin
  if p_operation not in ('issueInvitation', 'acceptInvitation', 'revokeInvitation') then
    return private.api042_command_pre_s2_invitations(
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
    when 'issueInvitation' then
      if not private.is_school_admin(tenant) then return jsonb_build_object('outcome', 'forbidden'); end if;
      -- A stale, never-accepted invite blocks the live-invite unique index
      -- forever unless something expires it. Do that lazily here rather
      -- than depending on a scheduled job that does not exist yet.
      update public.invitations set status = 'expired', version = version + 1, updated_at = now()
      where school_id = tenant and email = lower(body->>'email') and role = (body->>'role')::public.app_role
        and status = 'pending' and expires_at <= now();
      if exists (
        select 1 from public.invitations i where i.school_id = tenant and i.email = lower(body->>'email')
          and i.role = (body->>'role')::public.app_role and i.status = 'pending'
      ) then return jsonb_build_object('outcome', 'invalid'); end if;
      -- Whether this email already belongs to an active member is checked
      -- at acceptance time (below), not here: profiles carries no email to
      -- match against without reading auth.users, and the accept-time check
      -- already refuses to grant a duplicate membership.
      insert into public.invitations(
        school_id, role, email, classroom_id, token_hash, status, invited_by, expires_at, version
      ) values (
        tenant, (body->>'role')::public.app_role, lower(body->>'email'),
        nullif(body->>'classroomId', '')::uuid, body->>'tokenHash', 'pending', auth.uid(),
        now() + interval '7 days', 1
      ) returning id into entity_id;
      response := private.api042_invitation_json(entity_id);
      entity_type := 'invitation'; audit_action := 'invitation_issued';
      outbox_template := 'invitations.issued'; outbox_entity := entity_id;

    when 'revokeInvitation' then
      select i.school_id, i.status::text, i.version, to_jsonb(i)
        into resolved_school, existing_status, existing_version, before_value
      from public.invitations i where i.id = p_resource_id for update;
      if resolved_school is null then return jsonb_build_object('outcome', 'not_found'); end if;
      if resolved_school <> tenant then return jsonb_build_object('outcome', 'forbidden'); end if;
      if not private.is_school_admin(tenant) then return jsonb_build_object('outcome', 'forbidden'); end if;
      if existing_status <> 'pending' then return jsonb_build_object('outcome', 'invalid_state'); end if;
      update public.invitations set status = 'revoked', revoked_by = auth.uid(), revoked_at = now(),
        version = version + 1, updated_at = now()
      where id = p_resource_id;
      entity_id := p_resource_id; entity_type := 'invitation'; audit_action := 'invitation_revoked';
      response := private.api042_invitation_json(entity_id);

    when 'acceptInvitation' then
      select i.id, i.status::text, i.expires_at, i.attempt_count, i.max_attempts, i.school_id, i.role, to_jsonb(i)
        into v_invitation_id, existing_status, existing_expires, v_attempt_count, v_max_attempts, resolved_school, v_role, before_value
      from public.invitations i where i.token_hash = body->>'tokenHash' for update;
      if v_invitation_id is null then return jsonb_build_object('outcome', 'not_found'); end if;
      if existing_status <> 'pending' or existing_expires <= now() then
        return jsonb_build_object('outcome', 'invalid_state');
      end if;
      if v_attempt_count >= v_max_attempts then
        update public.invitations set status = 'expired', version = version + 1, updated_at = now()
        where id = v_invitation_id;
        return jsonb_build_object('outcome', 'invalid_state');
      end if;
      update public.invitations set attempt_count = v_attempt_count + 1 where id = v_invitation_id;
      if exists (
        select 1 from public.memberships m where m.school_id = resolved_school and m.user_id = auth.uid()
      ) then
        -- The invitation was for someone who is already a member (or has
        -- become one since it was issued): consume it without granting a
        -- duplicate membership, rather than leaving it acceptable forever.
        update public.invitations set status = 'revoked', revoked_at = now(), version = version + 1, updated_at = now()
        where id = v_invitation_id;
        return jsonb_build_object('outcome', 'invalid_state');
      end if;
      insert into public.memberships(school_id, user_id, role, active, status, version)
      values (resolved_school, auth.uid(), v_role, true, 'active', 1)
      returning id into v_membership_id;
      insert into public.membership_events(school_id, membership_id, actor_id, event_type, reason, idempotency_key)
      values (resolved_school, v_membership_id, auth.uid(), 'granted', 'invitation_accepted', idem_key);
      update public.invitations set status = 'accepted', accepted_by = auth.uid(), accepted_at = now(),
        version = version + 1, updated_at = now()
      where id = v_invitation_id;
      entity_id := v_membership_id; entity_type := 'membership'; audit_action := 'invitation_accepted';
      response := private.api042_membership_json(v_membership_id);
      tenant := resolved_school;

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

alter function private.api042_invitation_json(uuid) owner to postgres;
alter function private.api042_query(text, uuid, jsonb) owner to postgres;
alter function private.api042_command(text, uuid, jsonb, uuid, bigint) owner to postgres;
alter function private.authz_authorize(text, uuid) owner to postgres;

revoke all on function private.api042_invitation_json(uuid), private.api042_query(text, uuid, jsonb),
  private.api042_command(text, uuid, jsonb, uuid, bigint)
from public, anon, authenticated, service_role, studafy_worker_runtime;
revoke all on function private.api042_command_pre_s2_invitations(text, uuid, jsonb, uuid, bigint)
from public, anon, authenticated, service_role, studafy_worker_runtime, studafy_api_runtime;
revoke all on function private.authz_authorize_pre_api042_invitations(text, uuid)
from public, anon, authenticated, service_role, studafy_worker_runtime, studafy_api_runtime;
revoke all on function private.authz_authorize(text, uuid)
from public, anon, authenticated, service_role, studafy_worker_runtime;
grant execute on function private.authz_authorize(text, uuid),
  private.api042_query(text, uuid, jsonb), private.api042_command(text, uuid, jsonb, uuid, bigint)
to studafy_api_runtime;

revoke all privileges on all tables in schema public from studafy_api_runtime;
revoke all privileges on all sequences in schema public from studafy_api_runtime;
