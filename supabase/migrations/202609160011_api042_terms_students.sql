-- API-042 S9: createTerm/createStudent close a real gap API-041 shipped
-- with. createClassroom (202609150002) requires an existing term with
-- status 'active' or 'planned', and enrollStudent (202609160002) requires
-- an existing students row - but nothing in the catalogue could create
-- either. A freshly provisioned school could never reach a working
-- classroom or roster entry through the real API. Found writing the
-- reviewer-tenant seed script, whose entire job is to prove the onboarding
-- lifecycle works end-to-end through real commands.

alter function private.authz_authorize(text, uuid)
  rename to authz_authorize_pre_s9_roster;

create or replace function private.authz_authorize(p_action text, p_resource_id uuid)
returns jsonb language plpgsql stable security definer set search_path = '' as $$
declare target_school uuid; permitted boolean := false;
begin
  if p_action not in ('term.create', 'student.create') then
    return private.authz_authorize_pre_s9_roster(p_action, p_resource_id);
  end if;
  if auth.uid() is null or p_resource_id is null then
    return jsonb_build_object('allowed', false, 'school_id', null, 'reason', 'invalid_resource');
  end if;

  select s.id, private.is_school_admin(s.id)
  into target_school, permitted from public.schools s where s.id = p_resource_id;
  return jsonb_build_object('allowed', coalesce(permitted, false), 'school_id', target_school,
    'reason', case when target_school is null then 'invalid_resource' when permitted then 'allowed' else 'denied' end);
end;
$$;

alter function private.api042_command(text, uuid, jsonb, uuid, bigint)
  rename to api042_command_pre_s9_roster;

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
  response jsonb;
  entity_id uuid; entity_type text; audit_action text;
  idem_key text; v_user_id uuid; v_studafy_id text; v_provisional boolean;
  outbox_template text; outbox_entity uuid; completed boolean;
  response_status int := coalesce((p_input->>'responseStatus')::int, 200);
begin
  if p_operation not in ('createTerm', 'createStudent') then
    return private.api042_command_pre_s9_roster(
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
  if not private.is_school_admin(tenant) then return jsonb_build_object('outcome', 'forbidden'); end if;

  case p_operation
    when 'createTerm' then
      insert into public.terms(school_id, name, starts_on, ends_on, status, active)
      values (
        tenant, req_body->>'name', (req_body->>'startsOn')::date, (req_body->>'endsOn')::date,
        'active', true
      ) returning id into entity_id;
      response := jsonb_build_object(
        'id', entity_id, 'schoolId', tenant, 'name', req_body->>'name',
        'startsOn', req_body->>'startsOn', 'endsOn', req_body->>'endsOn', 'status', 'active'
      );
      entity_type := 'term'; audit_action := 'term_created';
      outbox_template := null; outbox_entity := null;

    when 'createStudent' then
      v_user_id := nullif(req_body->>'userId', '')::uuid;
      if v_user_id is not null and not exists (select 1 from public.profiles p where p.id = v_user_id) then
        return jsonb_build_object('outcome', 'invalid');
      end if;
      v_provisional := v_user_id is null;
      -- Opaque, server-generated locator - never client-selected. Replaces
      -- the class of hard-coded/predictable studafy_id this schema's own
      -- design already forbids (see supabase/tests/api042_family.sql and
      -- the S3 locateStudent rate-limit posture it shares this table with).
      v_studafy_id := 'STU-' || upper(substr(replace(gen_random_uuid()::text, '-', ''), 1, 10));
      insert into public.students(school_id, user_id, studafy_id, display_name, provisional, created_by)
      values (tenant, v_user_id, v_studafy_id, req_body->>'displayName', v_provisional, auth.uid())
      returning id into entity_id;
      response := jsonb_build_object(
        'id', entity_id, 'schoolId', tenant, 'userId', v_user_id,
        'studafyId', v_studafy_id, 'displayName', req_body->>'displayName', 'provisional', v_provisional
      );
      entity_type := 'student'; audit_action := 'student_created';
      outbox_template := null; outbox_entity := null;

    else return jsonb_build_object('outcome', 'invalid');
  end case;

  insert into public.audit_events(school_id, actor_id, action, entity_type, entity_id, before_value, after_value, request_id)
  values (tenant, auth.uid(), audit_action, entity_type, entity_id, null, response, request_id);
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

alter function private.authz_authorize(text, uuid) owner to postgres;
alter function private.api042_command(text, uuid, jsonb, uuid, bigint) owner to postgres;

revoke all on function private.authz_authorize(text, uuid),
  private.api042_command(text, uuid, jsonb, uuid, bigint)
from public, anon, authenticated, service_role, studafy_worker_runtime;
revoke all on function private.authz_authorize_pre_s9_roster(text, uuid)
from public, anon, authenticated, service_role, studafy_worker_runtime, studafy_api_runtime;
revoke all on function private.api042_command_pre_s9_roster(text, uuid, jsonb, uuid, bigint)
from public, anon, authenticated, service_role, studafy_worker_runtime, studafy_api_runtime;
grant execute on function private.authz_authorize(text, uuid),
  private.api042_command(text, uuid, jsonb, uuid, bigint)
to studafy_api_runtime;
