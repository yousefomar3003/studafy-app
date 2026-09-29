-- Flattens the school-operations command core under private.api042_command
-- (ADR-0030).
--
-- The nine oldest layers of the chain (roster, support access, account,
-- notifications, meetings, communications, family links, invitations, school
-- administration) each handled a fixed set of operations and passed the rest
-- down. They become named handlers behind one dispatcher, private.ops_command.
--
-- The layers above them are not flattened: they transform a request or its
-- result around the call (messaging safety checks, meeting links, receipts,
-- attachments), so they stay as they are and now call ops_command directly.
-- The chain is six calls deep instead of fifteen.

CREATE OR REPLACE FUNCTION private.ops_command_roster_create(p_operation text, p_resource_id uuid, p_input jsonb, p_idempotency_id uuid, p_idempotency_generation bigint)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
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
$function$;
CREATE OR REPLACE FUNCTION private.ops_command_support_access(p_operation text, p_resource_id uuid, p_input jsonb, p_idempotency_id uuid, p_idempotency_generation bigint)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
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
$function$;
CREATE OR REPLACE FUNCTION private.ops_command_account(p_operation text, p_resource_id uuid, p_input jsonb, p_idempotency_id uuid, p_idempotency_generation bigint)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
declare
  tenant uuid := nullif(current_setting('studafy.school_id', true), '')::uuid;
  request_id text := nullif(current_setting('studafy.request_id', true), '');
  req_body jsonb := coalesce(p_input->'body', '{}'::jsonb);
  response jsonb; before_value jsonb;
  entity_id uuid; entity_type text; audit_action text;
  idem_key text; completed boolean;
  response_status int := coalesce((p_input->>'responseStatus')::int, 200);
begin

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
    when 'updateProfile' then
      select to_jsonb(p) into before_value from public.profiles p where p.id = auth.uid();
      if before_value is null then return jsonb_build_object('outcome', 'not_found'); end if;
      if (req_body->>'locale') is not null and (req_body->>'locale') not in ('en', 'ar') then
        return jsonb_build_object('outcome', 'invalid');
      end if;
      update public.profiles set
        display_name = coalesce(nullif(req_body->>'displayName', ''), display_name),
        locale = coalesce(req_body->>'locale', locale),
        updated_at = now()
      where id = auth.uid();
      entity_id := auth.uid(); entity_type := 'profile'; audit_action := 'profile_updated';
      select jsonb_build_object('id', p.id, 'displayName', p.display_name, 'locale', p.locale) into response
      from public.profiles p where p.id = auth.uid();

    when 'requestDataExport' then
      if exists (select 1 from public.data_export_requests d where d.user_id = auth.uid() and d.status = 'pending') then
        select d.id into entity_id from public.data_export_requests d where d.user_id = auth.uid() and d.status = 'pending';
      else
        insert into public.data_export_requests(user_id, status, expires_at)
        values (auth.uid(), 'pending', now() + interval '7 days')
        returning id into entity_id;
      end if;
      entity_type := 'data_export_request'; audit_action := 'data_export_requested';
      response := private.api042_export_json(entity_id);

    else return jsonb_build_object('outcome', 'invalid');
  end case;

  insert into public.audit_events(school_id, actor_id, action, entity_type, entity_id, before_value, after_value, request_id)
  values (tenant, auth.uid(), audit_action, entity_type, entity_id, before_value, response, request_id);
  completed := private.api_idempotency_complete(p_idempotency_id, p_idempotency_generation, response_status, response);
  if not completed then raise exception 'API042_IDEMPOTENCY_COMPLETION_FAILED'; end if;
  return jsonb_build_object('outcome', 'ok', 'response', response);
end;
$function$;
CREATE OR REPLACE FUNCTION private.ops_command_notifications(p_operation text, p_resource_id uuid, p_input jsonb, p_idempotency_id uuid, p_idempotency_generation bigint)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
declare
  tenant uuid := nullif(current_setting('studafy.school_id', true), '')::uuid;
  request_id text := nullif(current_setting('studafy.request_id', true), '');
  req_body jsonb := coalesce(p_input->'body', '{}'::jsonb);
  response jsonb; before_value jsonb;
  entity_id uuid; entity_type text; audit_action text;
  idem_key text; marked_count int; pref_id uuid;
  outbox_template text; outbox_entity uuid; completed boolean;
  response_status int := coalesce((p_input->>'responseStatus')::int, 200);
begin

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
    when 'markNotificationsRead' then
      if coalesce((req_body->>'all')::boolean, false) then
        update public.notification_deliveries set read_at = now()
        where recipient_id = auth.uid() and channel = 'in_app' and read_at is null;
        get diagnostics marked_count = row_count;
      else
        if jsonb_array_length(coalesce(req_body->'ids', '[]'::jsonb)) > 100 then
          return jsonb_build_object('outcome', 'invalid');
        end if;
        update public.notification_deliveries set read_at = now()
        where recipient_id = auth.uid() and channel = 'in_app' and read_at is null
          and id = any(
            select (x)::bigint from jsonb_array_elements_text(coalesce(req_body->'ids', '[]'::jsonb)) x
          );
        get diagnostics marked_count = row_count;
      end if;
      response := jsonb_build_object('markedCount', marked_count);
      entity_type := 'notification_deliveries'; audit_action := 'notifications_marked_read';

    when 'updateNotificationPreferences' then
      if (req_body->>'schoolId') is not null then
        insert into public.notification_preferences(user_id, school_id, channel, category, enabled)
        values (auth.uid(), (req_body->>'schoolId')::uuid, req_body->>'channel', req_body->>'category', (req_body->>'enabled')::boolean)
        on conflict (user_id, school_id, channel, category) where school_id is not null
        do update set enabled = excluded.enabled, updated_at = now()
        returning id into pref_id;
      else
        insert into public.notification_preferences(user_id, school_id, channel, category, enabled)
        values (auth.uid(), null, req_body->>'channel', req_body->>'category', (req_body->>'enabled')::boolean)
        on conflict (user_id, channel, category) where school_id is null
        do update set enabled = excluded.enabled, updated_at = now()
        returning id into pref_id;
      end if;
      select jsonb_build_object('schoolId', p.school_id, 'channel', p.channel, 'category', p.category, 'enabled', p.enabled)
        into response from public.notification_preferences p where p.id = pref_id;
      entity_id := pref_id; entity_type := 'notification_preference'; audit_action := 'notification_preference_updated';

    else return jsonb_build_object('outcome', 'invalid');
  end case;

  insert into public.audit_events(school_id, actor_id, action, entity_type, entity_id, before_value, after_value, request_id)
  values (tenant, auth.uid(), audit_action, entity_type, entity_id, before_value, response, request_id);
  completed := private.api_idempotency_complete(p_idempotency_id, p_idempotency_generation, response_status, response);
  if not completed then raise exception 'API042_IDEMPOTENCY_COMPLETION_FAILED'; end if;
  return jsonb_build_object('outcome', 'ok', 'response', response);
end;
$function$;
CREATE OR REPLACE FUNCTION private.ops_command_meetings(p_operation text, p_resource_id uuid, p_input jsonb, p_idempotency_id uuid, p_idempotency_generation bigint)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
declare
  tenant uuid := nullif(current_setting('studafy.school_id', true), '')::uuid;
  request_id text := nullif(current_setting('studafy.request_id', true), '');
  req_body jsonb := coalesce(p_input->'body', '{}'::jsonb);
  response jsonb; before_value jsonb;
  entity_id uuid; entity_type text; audit_action text;
  idem_key text; resolved_school uuid; existing_state text; existing_version bigint;
  outbox_template text; outbox_entity uuid; completed boolean;
  response_status int := coalesce((p_input->>'responseStatus')::int, 200);
begin

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
    when 'requestMeeting' then
      if not exists (select 1 from public.classrooms c where c.id = p_resource_id and c.school_id = tenant) then
        return jsonb_build_object('outcome', 'not_found');
      end if;
      if not private.api041_class_writer(p_resource_id) then return jsonb_build_object('outcome', 'forbidden'); end if;
      if (req_body->>'endsAt')::timestamptz <= (req_body->>'startsAt')::timestamptz then
        return jsonb_build_object('outcome', 'invalid');
      end if;
      -- The idempotency key doubles as the schema's own
      -- db020_meetings_idempotency_key guard: a retried request can never
      -- create a second meeting even if the idempotency_records row were
      -- somehow lost.
      insert into public.meetings(school_id, classroom_id, title, starts_at, ends_at, audience, state, created_by, idempotency_key, version)
      values (tenant, p_resource_id, req_body->>'title', (req_body->>'startsAt')::timestamptz, (req_body->>'endsAt')::timestamptz,
        coalesce(req_body->>'audience', 'both')::public.meeting_audience, 'pending', auth.uid(), idem_key, 1)
      on conflict (school_id, idempotency_key) do nothing
      returning id into entity_id;
      if entity_id is null then
        select id into entity_id from public.meetings where school_id = tenant and idempotency_key = idem_key;
      else
        -- One set-based recipient resolution, one bulk insert - not a
        -- per-student guardian lookup followed by a per-recipient loop.
        insert into public.meeting_deliveries(school_id, meeting_id, recipient_id, state)
        select tenant, entity_id, recipient_id, 'queued' from (
          select distinct r.recipient_id from (
            select st.user_id as recipient_id from public.enrollments e
              join public.students st on st.id = e.student_id
              where e.classroom_id = p_resource_id and e.active and e.status = 'active'
                and coalesce(req_body->>'audience', 'both') in ('students', 'both')
            union all
            select gl.guardian_id from public.guardian_links gl
              join public.enrollments e on e.student_id = gl.student_id
              where e.classroom_id = p_resource_id and e.active and e.status = 'active'
                and gl.status = 'verified' and (gl.expires_at is null or gl.expires_at > now())
                and coalesce(req_body->>'audience', 'both') in ('guardians', 'both')
            union all
            select cs.user_id from public.classroom_staff cs
              where cs.classroom_id = p_resource_id and cs.status = 'active'
          ) r where r.recipient_id is not null
        ) r;
      end if;
      response := private.api042_meeting_json(entity_id);
      entity_type := 'meeting'; audit_action := 'meeting_requested';
      outbox_template := 'meetings.requested'; outbox_entity := entity_id;

    when 'cancelMeeting' then
      select m.school_id, m.state, m.version, to_jsonb(m) into resolved_school, existing_state, existing_version, before_value
      from public.meetings m where m.id = p_resource_id for update;
      if resolved_school is null then return jsonb_build_object('outcome', 'not_found'); end if;
      if resolved_school <> tenant then return jsonb_build_object('outcome', 'forbidden'); end if;
      if not private.is_meeting_authorized(p_resource_id) then return jsonb_build_object('outcome', 'forbidden'); end if;
      if existing_version <> (req_body->>'expectedVersion')::bigint then return jsonb_build_object('outcome', 'version_conflict'); end if;
      if existing_state not in ('pending', 'scheduled') then return jsonb_build_object('outcome', 'invalid_state'); end if;
      update public.meetings set state = 'cancelled', version = version + 1, updated_at = now() where id = p_resource_id;
      -- One bulk update, matching what the legacy cancel-google-meet Edge
      -- Function already got right for this specific step.
      update public.meeting_deliveries set state = 'cancelled'
      where meeting_id = p_resource_id and state in ('queued', 'sent');
      entity_id := p_resource_id; entity_type := 'meeting'; audit_action := 'meeting_cancelled';
      response := private.api042_meeting_json(entity_id);
      tenant := resolved_school;
      outbox_template := 'meetings.cancelled'; outbox_entity := entity_id;

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
$function$;
CREATE OR REPLACE FUNCTION private.ops_command_communications(p_operation text, p_resource_id uuid, p_input jsonb, p_idempotency_id uuid, p_idempotency_generation bigint)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
declare
  tenant uuid := nullif(current_setting('studafy.school_id', true), '')::uuid;
  request_id text := nullif(current_setting('studafy.request_id', true), '');
  req_body jsonb := coalesce(p_input->'body', '{}'::jsonb);
  response jsonb; before_value jsonb;
  entity_id uuid; entity_type text; audit_action text;
  idem_key text; resolved_school uuid; v_participant uuid; participants uuid[];
  outbox_template text; outbox_entity uuid; completed boolean;
  response_status int := coalesce((p_input->>'responseStatus')::int, 200);
begin

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
    when 'createConversation' then
      resolved_school := (req_body->>'schoolId')::uuid;
      if not exists (select 1 from public.schools s where s.id = resolved_school and s.status = 'active') then
        return jsonb_build_object('outcome', 'not_found');
      end if;
      if not private.can_message_in_school(auth.uid(), resolved_school) then
        return jsonb_build_object('outcome', 'forbidden');
      end if;
      select array_agg(distinct x)::uuid[] into participants
      from jsonb_array_elements_text(coalesce(req_body->'participantIds', '[]'::jsonb)) x;
      if participants is null or array_length(participants, 1) = 0 then
        return jsonb_build_object('outcome', 'invalid');
      end if;
      if exists (
        select 1 from unnest(participants) p where not private.can_message_in_school(p, resolved_school)
      ) then return jsonb_build_object('outcome', 'invalid'); end if;
      insert into public.conversations(school_id, subject, created_by)
      values (resolved_school, nullif(req_body->>'subject', ''), auth.uid())
      returning id into entity_id;
      insert into public.conversation_participants(school_id, conversation_id, user_id)
      select resolved_school, entity_id, p from unnest(participants) p
      union
      select resolved_school, entity_id, auth.uid()
      on conflict (conversation_id, user_id) do nothing;
      tenant := resolved_school;
      response := private.api042_conversation_json(entity_id);
      entity_type := 'conversation'; audit_action := 'conversation_created';

    when 'sendMessage' then
      select c.school_id into resolved_school from public.conversations c
      where c.id = p_resource_id and c.state = 'active';
      if resolved_school is null then return jsonb_build_object('outcome', 'not_found'); end if;
      if not private.is_conversation_participant(p_resource_id) then return jsonb_build_object('outcome', 'not_found'); end if;
      insert into public.messages(school_id, conversation_id, sender_id, client_message_id, body)
      values (resolved_school, p_resource_id, auth.uid(), (req_body->>'clientMessageId')::uuid, req_body->>'body')
      on conflict (conversation_id, client_message_id) do nothing
      returning id into entity_id;
      if entity_id is null then
        select m.id into entity_id from public.messages m
        where m.conversation_id = p_resource_id and m.client_message_id = (req_body->>'clientMessageId')::uuid;
      end if;
      update public.conversations set updated_at = now() where id = p_resource_id;
      update public.conversation_participants set last_read_at = now()
      where conversation_id = p_resource_id and user_id = auth.uid();
      tenant := resolved_school;
      response := private.api042_message_json(entity_id);
      entity_type := 'message'; audit_action := 'message_sent';
      outbox_template := 'communications.message_sent'; outbox_entity := entity_id;

    when 'createAnnouncement' then
      resolved_school := nullif(req_body->>'schoolId', '')::uuid;
      v_participant := nullif(req_body->>'classroomId', '')::uuid; -- reused: target classroom id
      if v_participant is not null then
        select c.school_id into resolved_school from public.classrooms c where c.id = v_participant;
        if resolved_school is null or resolved_school <> (req_body->>'schoolId')::uuid then
          return jsonb_build_object('outcome', 'not_found');
        end if;
        if not private.api041_class_writer(v_participant) then return jsonb_build_object('outcome', 'forbidden'); end if;
      else
        if not private.is_school_admin(resolved_school) then return jsonb_build_object('outcome', 'forbidden'); end if;
      end if;
      insert into public.announcements(school_id, classroom_id, title, body, audience, important, created_by)
      values (resolved_school, v_participant, req_body->>'title', req_body->>'body',
        coalesce(req_body->>'audience', 'both')::public.meeting_audience,
        coalesce((req_body->>'important')::boolean, false), auth.uid())
      returning id into entity_id;
      tenant := resolved_school;
      response := private.api042_announcement_json(entity_id);
      entity_type := 'announcement'; audit_action := 'announcement_created';
      outbox_template := 'communications.announcement_created'; outbox_entity := entity_id;

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
$function$;
CREATE OR REPLACE FUNCTION private.ops_command_family_links(p_operation text, p_resource_id uuid, p_input jsonb, p_idempotency_id uuid, p_idempotency_generation bigint)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
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
$function$;
CREATE OR REPLACE FUNCTION private.ops_command_invitations(p_operation text, p_resource_id uuid, p_input jsonb, p_idempotency_id uuid, p_idempotency_generation bigint)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
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
$function$;
CREATE OR REPLACE FUNCTION private.ops_command_school_admin(p_operation text, p_resource_id uuid, p_input jsonb, p_idempotency_id uuid, p_idempotency_generation bigint)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
declare
  tenant uuid := nullif(current_setting('studafy.school_id', true), '')::uuid;
  request_id text := nullif(current_setting('studafy.request_id', true), '');
  body jsonb := coalesce(p_input->'body', '{}'::jsonb);
  response jsonb; before_value jsonb;
  entity_id uuid; entity_type text; audit_action text;
  idem_key text; version_value bigint; target_user uuid; target_role text;
  membership_id uuid; staff_id uuid; v_student_id uuid; v_target_classroom_id uuid;
  membership_event text; outbox_template text; outbox_entity uuid; resolved_school uuid;
  completed boolean;
  response_status int := coalesce((p_input->>'responseStatus')::int, 200);
begin
  if auth.uid() is null or request_id is null then
    return jsonb_build_object('outcome', 'forbidden');
  end if;
  select r.idempotency_key into idem_key from public.idempotency_records r
  where r.id = p_idempotency_id and r.actor_id = auth.uid()
    and r.school_id is not distinct from tenant
    and r.generation = p_idempotency_generation and r.status = 'reserved'
  for update;
  if idem_key is null then return jsonb_build_object('outcome', 'forbidden'); end if;
  -- Unlike API-041, there is no blanket has_active_membership(tenant) gate
  -- here: a platform operator legitimately acts on a school without being
  -- one of its members (suspendSchool/closeSchool), and provisionSchool has
  -- no tenant at all. Every case below re-derives and checks its own exact
  -- authorization predicate instead.

  case p_operation
    when 'provisionSchool' then
      if not private.is_platform_operator() then return jsonb_build_object('outcome', 'forbidden'); end if;
      target_user := (body->>'initialAdminUserId')::uuid;
      if not exists (select 1 from public.profiles p where p.id = target_user) then
        return jsonb_build_object('outcome', 'invalid');
      end if;
      insert into public.schools(name, timezone, locale, status, version)
      values (body->>'name', coalesce(body->>'timezone', 'Asia/Riyadh'), coalesce(body->>'locale', 'en'), 'active', 1)
      returning id into entity_id;
      insert into public.memberships(school_id, user_id, role, active, status, version)
      values (entity_id, target_user, 'school_admin', true, 'active', 1)
      returning id into membership_id;
      insert into public.membership_events(school_id, membership_id, actor_id, event_type, reason, idempotency_key)
      values (entity_id, membership_id, auth.uid(), 'granted', 'school_provisioned', idem_key);
      select jsonb_build_object('id', s.id, 'name', s.name, 'timezone', s.timezone, 'locale', s.locale,
        'status', s.status, 'version', s.version) into response
      from public.schools s where s.id = entity_id;
      entity_type := 'school'; audit_action := 'school_provisioned';

    when 'suspendSchool', 'closeSchool' then
      select s.version, to_jsonb(s) into version_value, before_value from public.schools s
      where s.id = p_resource_id for update;
      if version_value is null then return jsonb_build_object('outcome', 'not_found'); end if;
      if tenant <> p_resource_id then return jsonb_build_object('outcome', 'forbidden'); end if;
      if not (private.is_platform_operator() or private.is_school_admin(p_resource_id)) then
        return jsonb_build_object('outcome', 'forbidden');
      end if;
      if version_value <> (body->>'expectedVersion')::bigint then return jsonb_build_object('outcome', 'version_conflict'); end if;
      if p_operation = 'suspendSchool' and not exists (
        select 1 from public.schools where id = p_resource_id and status = 'active'
      ) then return jsonb_build_object('outcome', 'invalid_state'); end if;
      if p_operation = 'closeSchool' and not exists (
        select 1 from public.schools where id = p_resource_id and status in ('active', 'suspended')
      ) then return jsonb_build_object('outcome', 'invalid_state'); end if;
      update public.schools set
        status = (case when p_operation = 'suspendSchool' then 'suspended' else 'closed' end)::public.school_status,
        version = version + 1, updated_at = now()
      where id = p_resource_id;
      entity_id := p_resource_id; entity_type := 'school';
      audit_action := case when p_operation = 'suspendSchool' then 'school_suspended' else 'school_closed' end;
      select jsonb_build_object('id', s.id, 'name', s.name, 'timezone', s.timezone, 'locale', s.locale,
        'status', s.status, 'version', s.version) into response
      from public.schools s where s.id = entity_id;

    when 'grantMembership' then
      if not private.is_school_admin(tenant) then return jsonb_build_object('outcome', 'forbidden'); end if;
      target_user := (body->>'userId')::uuid;
      target_role := body->>'role';
      if not exists (
        select 1 from public.memberships m where m.school_id = tenant and m.user_id = target_user
      ) then
        -- grantMembership only adds an additional role for someone already
        -- verified as a member of this school. Onboarding a brand-new
        -- person to a school goes through invitations, not this command.
        return jsonb_build_object('outcome', 'invalid_state');
      end if;
      if exists (
        select 1 from public.memberships m where m.school_id = tenant and m.user_id = target_user
          and m.role = target_role::public.app_role and m.status <> 'revoked'
      ) then return jsonb_build_object('outcome', 'invalid'); end if;
      insert into public.memberships(school_id, user_id, role, active, status, version)
      values (tenant, target_user, target_role::public.app_role, true, 'active', 1)
      returning id into entity_id;
      insert into public.membership_events(school_id, membership_id, actor_id, event_type, reason, idempotency_key)
      values (tenant, entity_id, auth.uid(), 'granted', coalesce(body->>'reason', ''), idem_key);
      response := private.api042_membership_json(entity_id);
      entity_type := 'membership'; audit_action := 'membership_granted';
      outbox_template := 'school_admin.membership_granted'; outbox_entity := entity_id;

    when 'activateMembership', 'suspendMembership', 'revokeMembership' then
      select m.school_id, m.version, m.status::text, to_jsonb(m)
        into resolved_school, version_value, target_role, before_value
      from public.memberships m where m.id = p_resource_id for update;
      if resolved_school is null then return jsonb_build_object('outcome', 'not_found'); end if;
      -- Defense in depth: the AUTH-031 decision already derived `tenant` from
      -- this exact membership row, so this can only fail if that invariant
      -- is ever broken by a future change.
      if resolved_school <> tenant then return jsonb_build_object('outcome', 'forbidden'); end if;
      if not private.is_school_admin(tenant) then return jsonb_build_object('outcome', 'forbidden'); end if;
      if version_value <> (body->>'expectedVersion')::bigint then return jsonb_build_object('outcome', 'version_conflict'); end if;
      if p_operation = 'activateMembership' and target_role <> 'suspended' then return jsonb_build_object('outcome', 'invalid_state'); end if;
      if p_operation = 'suspendMembership' and target_role <> 'active' then return jsonb_build_object('outcome', 'invalid_state'); end if;
      if p_operation = 'revokeMembership' and target_role not in ('active', 'suspended') then return jsonb_build_object('outcome', 'invalid_state'); end if;
      if p_operation = 'revokeMembership' and (select m2.role from public.memberships m2 where m2.id = p_resource_id) = 'school_admin'
        and (select count(*) from public.memberships m3 where m3.school_id = tenant and m3.role = 'school_admin'
          and m3.status = 'active' and m3.id <> p_resource_id) = 0
      then
        -- Never let a school lose its last active admin through this path;
        -- that would strand every subsequent admin-only recovery action.
        return jsonb_build_object('outcome', 'invalid_state');
      end if;
      update public.memberships set
        status = (case p_operation
          when 'activateMembership' then 'active' when 'suspendMembership' then 'suspended' else 'revoked' end)::public.membership_status,
        active = (p_operation = 'activateMembership'),
        version = version + 1, updated_at = now()
      where id = p_resource_id;
      membership_event := case p_operation
        when 'activateMembership' then 'reactivated' when 'suspendMembership' then 'suspended' else 'revoked' end;
      insert into public.membership_events(school_id, membership_id, actor_id, event_type, reason, idempotency_key)
      values (tenant, p_resource_id, auth.uid(), membership_event, coalesce(body->>'reason', ''), idem_key);
      entity_id := p_resource_id; entity_type := 'membership';
      audit_action := 'membership_' || membership_event;
      response := private.api042_membership_json(entity_id);
      outbox_template := 'school_admin.membership_' || membership_event; outbox_entity := entity_id;

    when 'assignClassroomStaff' then
      if not exists (select 1 from public.classrooms c where c.id = p_resource_id and c.school_id = tenant) then
        return jsonb_build_object('outcome', 'not_found');
      end if;
      if not (private.is_school_admin(tenant) or private.is_class_lead(p_resource_id)) then
        return jsonb_build_object('outcome', 'forbidden');
      end if;
      target_user := (body->>'userId')::uuid;
      target_role := body->>'role';
      select ms.id into membership_id from public.memberships ms
        where ms.school_id = tenant and ms.user_id = target_user and ms.active and ms.status = 'active'
        order by ms.created_at limit 1;
      if membership_id is null then return jsonb_build_object('outcome', 'invalid_state'); end if;
      if exists (
        select 1 from public.classroom_staff cs where cs.classroom_id = p_resource_id
          and cs.user_id = target_user and cs.status = 'active'
      ) then return jsonb_build_object('outcome', 'invalid'); end if;
      insert into public.classroom_staff(school_id, classroom_id, membership_id, user_id, role, status)
      values (tenant, p_resource_id, membership_id, target_user, target_role::public.classroom_staff_role, 'active')
      returning id into entity_id;
      response := private.api042_staff_json(entity_id);
      entity_type := 'classroom_staff'; audit_action := 'classroom_staff_assigned';
      outbox_template := 'school_admin.classroom_staff_assigned'; outbox_entity := entity_id;

    when 'removeClassroomStaff' then
      if not exists (select 1 from public.classrooms c where c.id = p_resource_id and c.school_id = tenant) then
        return jsonb_build_object('outcome', 'not_found');
      end if;
      if not (private.is_school_admin(tenant) or private.is_class_lead(p_resource_id)) then
        return jsonb_build_object('outcome', 'forbidden');
      end if;
      staff_id := (body->>'staffAssignmentId')::uuid;
      select cs.status::text, to_jsonb(cs) into target_role, before_value
      from public.classroom_staff cs where cs.id = staff_id and cs.classroom_id = p_resource_id for update;
      if target_role is null then return jsonb_build_object('outcome', 'not_found'); end if;
      if target_role <> 'active' then return jsonb_build_object('outcome', 'invalid_state'); end if;
      if (select role from public.classroom_staff where id = staff_id) = 'lead_teacher'
        and (select count(*) from public.classroom_staff cs2 where cs2.classroom_id = p_resource_id
          and cs2.role = 'lead_teacher' and cs2.status = 'active' and cs2.id <> staff_id) = 0
      then return jsonb_build_object('outcome', 'invalid_state'); end if;
      update public.classroom_staff set status = 'ended', ends_at = now(), updated_at = now() where id = staff_id;
      entity_id := staff_id; entity_type := 'classroom_staff'; audit_action := 'classroom_staff_removed';
      response := private.api042_staff_json(entity_id);
      outbox_template := 'school_admin.classroom_staff_removed'; outbox_entity := entity_id;

    when 'enrollStudent' then
      if not exists (select 1 from public.classrooms c where c.id = p_resource_id and c.school_id = tenant) then
        return jsonb_build_object('outcome', 'not_found');
      end if;
      if not (private.is_school_admin(tenant) or private.api041_class_writer(p_resource_id)) then
        return jsonb_build_object('outcome', 'forbidden');
      end if;
      v_student_id := (body->>'studentId')::uuid;
      if not exists (select 1 from public.students st where st.id = v_student_id and st.school_id = tenant) then
        return jsonb_build_object('outcome', 'not_found');
      end if;
      if exists (
        select 1 from public.enrollments e where e.classroom_id = p_resource_id and e.student_id = v_student_id
          and e.active and e.status = 'active'
      ) then return jsonb_build_object('outcome', 'invalid'); end if;
      insert into public.enrollments(school_id, classroom_id, student_id, active, status, starts_on)
      values (tenant, p_resource_id, v_student_id, true, 'active', current_date)
      on conflict (school_id, classroom_id, student_id) do update set
        active = true, status = 'active', starts_on = current_date, ends_on = null, updated_at = now();
      entity_type := 'enrollment'; audit_action := 'student_enrolled';
      response := private.api042_enrollment_json(p_resource_id, v_student_id);
      outbox_template := 'school_admin.student_enrolled'; outbox_entity := v_student_id;

    when 'withdrawStudent' then
      if not exists (select 1 from public.classrooms c where c.id = p_resource_id and c.school_id = tenant) then
        return jsonb_build_object('outcome', 'not_found');
      end if;
      if not (private.is_school_admin(tenant) or private.api041_class_writer(p_resource_id)) then
        return jsonb_build_object('outcome', 'forbidden');
      end if;
      v_student_id := (body->>'studentId')::uuid;
      if not exists (
        select 1 from public.enrollments e where e.classroom_id = p_resource_id and e.student_id = v_student_id
          and e.active and e.status = 'active'
      ) then return jsonb_build_object('outcome', 'invalid_state'); end if;
      update public.enrollments e set active = false, status = 'withdrawn', ends_on = current_date, updated_at = now()
      where e.classroom_id = p_resource_id and e.student_id = v_student_id;
      entity_type := 'enrollment'; audit_action := 'student_withdrawn';
      response := private.api042_enrollment_json(p_resource_id, v_student_id);
      outbox_template := 'school_admin.student_withdrawn'; outbox_entity := v_student_id;

    when 'transferEnrollment' then
      if not exists (select 1 from public.classrooms c where c.id = p_resource_id and c.school_id = tenant) then
        return jsonb_build_object('outcome', 'not_found');
      end if;
      if not (private.is_school_admin(tenant) or private.api041_class_writer(p_resource_id)) then
        return jsonb_build_object('outcome', 'forbidden');
      end if;
      v_student_id := (body->>'studentId')::uuid;
      v_target_classroom_id := (body->>'targetClassroomId')::uuid;
      if not exists (
        select 1 from public.enrollments e where e.classroom_id = p_resource_id and e.student_id = v_student_id
          and e.active and e.status = 'active'
      ) then return jsonb_build_object('outcome', 'invalid_state'); end if;
      if not exists (select 1 from public.classrooms c where c.id = v_target_classroom_id and c.school_id = tenant) then
        return jsonb_build_object('outcome', 'not_found');
      end if;
      if not private.api041_class_writer(v_target_classroom_id) then return jsonb_build_object('outcome', 'forbidden'); end if;
      update public.enrollments e set active = false, status = 'withdrawn', ends_on = current_date, updated_at = now()
      where e.classroom_id = p_resource_id and e.student_id = v_student_id;
      insert into public.enrollments(school_id, classroom_id, student_id, active, status, starts_on)
      values (tenant, v_target_classroom_id, v_student_id, true, 'active', current_date)
      on conflict (school_id, classroom_id, student_id) do update set
        active = true, status = 'active', starts_on = current_date, ends_on = null, updated_at = now();
      entity_type := 'enrollment'; audit_action := 'student_transferred';
      response := private.api042_enrollment_json(v_target_classroom_id, v_student_id);
      outbox_template := 'school_admin.student_transferred'; outbox_entity := v_student_id;

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
$function$;

create or replace function private.ops_command(p_operation text, p_resource_id uuid, p_input jsonb, p_idempotency_id uuid, p_idempotency_generation bigint)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
begin
  -- Each operation has one owner; the first match is the newest code for it.
  case
    when p_operation in ('createTerm', 'createStudent') then
      return private.ops_command_roster_create(p_operation, p_resource_id, p_input, p_idempotency_id, p_idempotency_generation);
    when p_operation in ('requestSupportAccess', 'approveSupportAccess', 
        'startSupportAccess', 'revokeSupportAccess') then
      return private.ops_command_support_access(p_operation, p_resource_id, p_input, p_idempotency_id, p_idempotency_generation);
    when p_operation in ('updateProfile', 'requestDataExport') then
      return private.ops_command_account(p_operation, p_resource_id, p_input, p_idempotency_id, p_idempotency_generation);
    when p_operation in ('markNotificationsRead', 'updateNotificationPreferences') then
      return private.ops_command_notifications(p_operation, p_resource_id, p_input, p_idempotency_id, p_idempotency_generation);
    when p_operation in ('requestMeeting', 'cancelMeeting') then
      return private.ops_command_meetings(p_operation, p_resource_id, p_input, p_idempotency_id, p_idempotency_generation);
    when p_operation in ('createConversation', 'sendMessage', 'createAnnouncement') then
      return private.ops_command_communications(p_operation, p_resource_id, p_input, p_idempotency_id, p_idempotency_generation);
    when p_operation in ('locateStudent', 'requestGuardianLink', 'verifyGuardianLink', 
        'revokeGuardianLink') then
      return private.ops_command_family_links(p_operation, p_resource_id, p_input, p_idempotency_id, p_idempotency_generation);
    when p_operation in ('issueInvitation', 'acceptInvitation', 'revokeInvitation') then
      return private.ops_command_invitations(p_operation, p_resource_id, p_input, p_idempotency_id, p_idempotency_generation);
    else
      return private.ops_command_school_admin(p_operation, p_resource_id, p_input, p_idempotency_id, p_idempotency_generation);
  end case;
end;
$$;

revoke all on function private.ops_command_roster_create(text, uuid, jsonb, uuid, bigint)
  from public, anon, authenticated, service_role, studafy_api_runtime,
  studafy_worker_runtime;
revoke all on function private.ops_command_support_access(text, uuid, jsonb, uuid, bigint)
  from public, anon, authenticated, service_role, studafy_api_runtime,
  studafy_worker_runtime;
revoke all on function private.ops_command_account(text, uuid, jsonb, uuid, bigint)
  from public, anon, authenticated, service_role, studafy_api_runtime,
  studafy_worker_runtime;
revoke all on function private.ops_command_notifications(text, uuid, jsonb, uuid, bigint)
  from public, anon, authenticated, service_role, studafy_api_runtime,
  studafy_worker_runtime;
revoke all on function private.ops_command_meetings(text, uuid, jsonb, uuid, bigint)
  from public, anon, authenticated, service_role, studafy_api_runtime,
  studafy_worker_runtime;
revoke all on function private.ops_command_communications(text, uuid, jsonb, uuid, bigint)
  from public, anon, authenticated, service_role, studafy_api_runtime,
  studafy_worker_runtime;
revoke all on function private.ops_command_family_links(text, uuid, jsonb, uuid, bigint)
  from public, anon, authenticated, service_role, studafy_api_runtime,
  studafy_worker_runtime;
revoke all on function private.ops_command_invitations(text, uuid, jsonb, uuid, bigint)
  from public, anon, authenticated, service_role, studafy_api_runtime,
  studafy_worker_runtime;
revoke all on function private.ops_command_school_admin(text, uuid, jsonb, uuid, bigint)
  from public, anon, authenticated, service_role, studafy_api_runtime,
  studafy_worker_runtime;

revoke all on function private.ops_command(text, uuid, jsonb, uuid, bigint)
  from public, anon, authenticated, service_role, studafy_api_runtime,
  studafy_worker_runtime;

CREATE OR REPLACE FUNCTION private.api042_command_pre_messaging(p_operation text, p_resource_id uuid, p_input jsonb, p_idempotency_id uuid, p_idempotency_generation bigint)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
declare
  tenant uuid := nullif(current_setting('studafy.school_id', true), '')::uuid;
  request_id text := nullif(current_setting('studafy.request_id', true), '');
  req_body jsonb := coalesce(p_input->'body', '{}'::jsonb);
  response jsonb; before_value jsonb;
  entity_id uuid; entity_type text; audit_action text;
  idem_key text; resolved_school uuid; existing_status text; existing_version bigint;
  v_user uuid; v_digest text; v_priority text; v_message public.messages%rowtype;
  v_conversation public.conversations%rowtype; v_subject uuid; v_target uuid;
  v_attempt public.report_attempts%rowtype; v_count int; v_note text;
  v_resolution public.report_resolution; v_kind text; v_hold public.legal_holds%rowtype;
  v_applied text; v_for_user uuid; v_deletion public.account_deletion_requests%rowtype;
  v_template text; outbox_entity uuid; completed boolean;
  response_status int := coalesce((p_input->>'responseStatus')::int, 200);
begin
  -- Block enforcement backstop for the messaging surface: a block in either
  -- direction refuses a new conversation or a new message, while reads of
  -- already-delivered messages are untouched. Delegated commands other than
  -- these two take the normal path below.
  if p_operation in ('sendMessage', 'createConversation') then
    declare
      v_school uuid;
      v_actor uuid := auth.uid();
      v_members uuid[];
    begin
      if v_actor is not null then
        if p_operation = 'sendMessage' then
          select c.school_id,
            array_agg(cp.user_id) filter (where cp.left_at is null)
          into v_school, v_members
          from public.conversations c
          join public.conversation_participants cp on cp.conversation_id = c.id
          where c.id = p_resource_id
          group by c.school_id;
        else
          v_school := nullif(req_body->>'schoolId', '')::uuid;
          select array_agg(distinct x)::uuid[] into v_members
          from jsonb_array_elements_text(coalesce(req_body->'participantIds', '[]'::jsonb)) x;
          v_members := coalesce(v_members, '{}'::uuid[]) || v_actor;
        end if;
        if v_school is not null and exists (
          select 1 from unnest(coalesce(v_members, array[v_actor])) as av(a),
            unnest(coalesce(v_members, array[v_actor])) as bv(b)
          where av.a < bv.b and private.safe043_is_blocked_pair(v_school, av.a, bv.b)
        ) then
          return jsonb_build_object('outcome', 'forbidden');
        end if;
      end if;
    end;
    return private.ops_command(
      p_operation, p_resource_id, p_input, p_idempotency_id, p_idempotency_generation
    );
  end if;

  if p_operation not in (
    'updateContentControls', 'createReport', 'appealReport', 'createBlock',
    'unblockUser', 'triageReport', 'resolveReport', 'escalateReport',
    'addReportEvidence', 'holdReport', 'releaseLegalHold',
    'requestModerationAccess', 'approveModerationAccess',
    'startModerationAccess', 'revokeModerationAccess'
  ) then
    return private.ops_command(
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
    when 'updateContentControls' then
      if not private.is_school_admin(p_resource_id) then
        return jsonb_build_object('outcome', 'forbidden');
      end if;
      perform private.ensure_school_safety_defaults(p_resource_id);
      select to_jsonb(c) into before_value from public.school_content_controls c where c.school_id = p_resource_id;
      if before_value is null then return jsonb_build_object('outcome', 'not_found'); end if;
      if (before_value->>'version')::bigint <> (req_body->>'expectedVersion')::bigint then
        return jsonb_build_object('outcome', 'version_conflict');
      end if;
      update public.school_content_controls set
        messaging_enabled = coalesce((req_body->>'messagingEnabled')::boolean, messaging_enabled),
        content_filter_level = coalesce(nullif(req_body->>'contentFilterLevel', ''), content_filter_level),
        classifier_assist_enabled = coalesce(
          (req_body->>'classifierAssistEnabled')::boolean, classifier_assist_enabled),
        support_contact = case when req_body ? 'supportContact'
          then nullif(req_body->>'supportContact', '') else support_contact end,
        sla_hours = coalesce(req_body->'slaHours', sla_hours),
        updated_by = auth.uid(), version = version + 1, updated_at = now()
      where school_id = p_resource_id;
      resolved_school := p_resource_id;
      entity_id := (before_value->>'id')::uuid;
      entity_type := 'school_content_controls'; audit_action := 'safety_controls_updated';
      response := private.safe043_content_controls_json(p_resource_id);

    when 'createReport' then
      resolved_school := nullif(req_body->>'schoolId', '')::uuid;
      if not exists (
        select 1 from public.schools s where s.id = resolved_school and s.status = 'active'
      ) then return jsonb_build_object('outcome', 'not_found'); end if;
      if not private.can_message_in_school(auth.uid(), resolved_school) then
        return jsonb_build_object('outcome', 'forbidden');
      end if;
      perform private.ensure_school_safety_defaults(resolved_school);
      v_kind := req_body->>'kind';
      if v_kind not in ('message', 'conversation', 'user') then
        return jsonb_build_object('outcome', 'invalid');
      end if;

      if v_kind = 'message' then
        select m.* into v_message from public.messages m
        where m.id = (req_body->>'messageId')::uuid and m.school_id = resolved_school;
        if v_message.id is null then return jsonb_build_object('outcome', 'not_found'); end if;
        if not (private.is_conversation_participant(v_message.conversation_id)
          or private.is_school_admin(resolved_school)) then
          return jsonb_build_object('outcome', 'forbidden');
        end if;
        select jsonb_build_object(
          'messageBody', v_message.body, 'senderId', v_message.sender_id,
          'createdAt', v_message.created_at, 'conversationId', v_message.conversation_id
        ) into before_value;
      elsif v_kind = 'conversation' then
        select c.* into v_conversation from public.conversations c
        where c.id = (req_body->>'conversationId')::uuid and c.school_id = resolved_school;
        if v_conversation.id is null then return jsonb_build_object('outcome', 'not_found'); end if;
        if not (private.is_conversation_participant(v_conversation.id)
          or private.is_school_admin(resolved_school)) then
          return jsonb_build_object('outcome', 'forbidden');
        end if;
        select jsonb_build_object(
          'subject', v_conversation.subject, 'state', v_conversation.state,
          'createdAt', v_conversation.created_at
        ) into before_value;
      else
        v_subject := nullif(req_body->>'subjectUserId', '')::uuid;
        if v_subject is null or v_subject = auth.uid() then
          return jsonb_build_object('outcome', 'invalid');
        end if;
        if not (
          private.has_active_membership(resolved_school)
          and exists (
            select 1 from public.memberships m
            where m.user_id = v_subject and m.school_id = resolved_school and m.active
          )
        ) then return jsonb_build_object('outcome', 'invalid'); end if;
        before_value := '{}'::jsonb;
      end if;

      -- Dedupe: the same normalized concern inside a live window is refused.
      v_digest := encode(extensions.digest(
        lower(btrim(regexp_replace(req_body->>'details', '\s+', ' ', 'g'))), 'sha256'
      ), 'hex');
      select a.* into v_attempt from public.report_attempts a
      where a.school_id = resolved_school and a.reporter_id = auth.uid()
        and a.digest = v_digest and a.window_expires_at > now()
      for update;
      if v_attempt.id is not null then
        return jsonb_build_object('outcome', 'invalid_state');
      end if;
      select count(*) into v_count from public.report_attempts a
      where a.school_id = resolved_school and a.reporter_id = auth.uid()
        and a.window_expires_at > now();
      if v_count >= 20 then return jsonb_build_object('outcome', 'window_closed'); end if;

      v_priority := private.safe043_rule_priority(resolved_school, req_body->>'details');
      insert into public.reports(
        school_id, reported_by, kind, status, subject_user_id, conversation_id,
        message_id, details, evidence_snapshot, classifier_confidence,
        aup_version, contact_consent, priority
      ) values (
        resolved_school, auth.uid(), v_kind::public.report_kind, 'queued',
        case when v_kind = 'user' then v_subject end,
        case when v_kind = 'conversation' then v_conversation.id
          when v_kind = 'message' then v_message.conversation_id end,
        case when v_kind = 'message' then v_message.id end,
        req_body->>'details', coalesce(before_value, '{}'::jsonb),
        (req_body->>'classifierConfidence')::numeric,
        nullif(req_body->>'aupVersion', ''),
        coalesce((req_body->>'contactConsent')::boolean, false),
        v_priority
      ) returning id into entity_id;
      insert into public.report_attempts(
        school_id, reporter_id, digest, count_this_window, window_started_at, window_expires_at
      ) values (
        resolved_school, auth.uid(), v_digest, 1, now(), now() + interval '24 hours'
      );
      insert into public.report_events(school_id, report_id, actor_id, event, detail)
      values (resolved_school, entity_id, auth.uid(), 'submitted',
        jsonb_build_object('kind', v_kind, 'priority', v_priority)),
        (resolved_school, entity_id, auth.uid(), 'queued',
        jsonb_build_object('priority', v_priority));
      tenant := resolved_school;
      response := private.safe043_reporter_report_json(entity_id);
      entity_type := 'report'; audit_action := 'report_submitted';

    when 'appealReport' then
      select r.school_id, r.status, r.version, r.reported_by, to_jsonb(r)
        into resolved_school, existing_status, existing_version, v_user, before_value
      from public.reports r where r.id = p_resource_id for update;
      if resolved_school is null or v_user <> auth.uid() then
        return jsonb_build_object('outcome', 'not_found');
      end if;
      if existing_status <> 'resolved' then return jsonb_build_object('outcome', 'invalid_state'); end if;
      if existing_version <> (req_body->>'expectedVersion')::bigint then
        return jsonb_build_object('outcome', 'version_conflict');
      end if;
      update public.reports set status = 'under_review', resolution = null,
        resolved_at = null, version = version + 1, updated_at = now()
      where id = p_resource_id;
      insert into public.report_events(school_id, report_id, actor_id, event, detail)
      values (resolved_school, p_resource_id, auth.uid(), 'appeal',
        jsonb_build_object('note', nullif(req_body->>'reason', '')));
      entity_id := p_resource_id; entity_type := 'report'; audit_action := 'report_appealed';
      tenant := resolved_school;
      response := private.safe043_reporter_report_json(entity_id);

    when 'createBlock' then
      resolved_school := nullif(req_body->>'schoolId', '')::uuid;
      v_target := nullif(req_body->>'blockedUserId', '')::uuid;
      if v_target is null or v_target = auth.uid() then
        return jsonb_build_object('outcome', 'invalid');
      end if;
      if not private.can_message_in_school(auth.uid(), resolved_school)
         or not private.can_message_in_school(v_target, resolved_school) then
        return jsonb_build_object('outcome', 'forbidden');
      end if;
      insert into public.user_blocks(
        school_id, blocker_id, blocked_id, scope, reason, expires_at
      ) values (
        resolved_school, auth.uid(), v_target,
        coalesce(nullif(req_body->>'scope', ''), 'messages'),
        nullif(req_body->>'reason', ''),
        case when (req_body->>'durationHours') is not null
          then now() + make_interval(hours => greatest((req_body->>'durationHours')::int, 1)) end
      )
      on conflict (school_id, blocker_id, blocked_id) do update set
        scope = excluded.scope, reason = excluded.reason, expires_at = excluded.expires_at,
        version = public.user_blocks.version + 1, updated_at = now()
      returning id into entity_id;
      tenant := resolved_school;
      response := private.safe043_block_json(entity_id);
      entity_type := 'user_block'; audit_action := 'user_blocked';

    when 'unblockUser' then
      select b.school_id, b.blocker_id, to_jsonb(b)
        into resolved_school, v_user, before_value
      from public.user_blocks b where b.id = p_resource_id for update;
      if resolved_school is null then return jsonb_build_object('outcome', 'not_found'); end if;
      if not (v_user = auth.uid() or private.is_school_admin(resolved_school)) then
        return jsonb_build_object('outcome', 'forbidden');
      end if;
      -- Project the row while it still exists: the route validates against the
      -- camelCase V1Block, and to_jsonb(b) is the raw snake_case row, which
      -- fails response validation and surfaces as a 500.
      response := private.safe043_block_json(p_resource_id);
      delete from public.user_blocks where id = p_resource_id;
      entity_id := p_resource_id; entity_type := 'user_block'; audit_action := 'user_unblocked';
      tenant := resolved_school;

    when 'triageReport' then
      select r.school_id, r.status, r.version, to_jsonb(r)
        into resolved_school, existing_status, existing_version, before_value
      from public.reports r where r.id = p_resource_id for update;
      if resolved_school is null then return jsonb_build_object('outcome', 'not_found'); end if;
      if not private.safe043_can_access_report(resolved_school, p_resource_id) then
        return jsonb_build_object('outcome', 'forbidden');
      end if;
      if existing_status not in ('submitted', 'queued') then
        return jsonb_build_object('outcome', 'invalid_state');
      end if;
      if existing_version <> (req_body->>'expectedVersion')::bigint then
        return jsonb_build_object('outcome', 'version_conflict');
      end if;
      update public.reports set status = 'under_review',
        priority = coalesce(nullif(req_body->>'priority', ''), priority),
        assigned_to = coalesce(nullif(req_body->>'assignedTo', '')::uuid, assigned_to),
        version = version + 1, updated_at = now()
      where id = p_resource_id;
      insert into public.report_events(school_id, report_id, actor_id, event, detail)
      values (resolved_school, p_resource_id, auth.uid(), 'triage',
        jsonb_build_object('note', nullif(req_body->>'note', '')));
      entity_id := p_resource_id; entity_type := 'report'; audit_action := 'report_triaged';
      tenant := resolved_school;
      response := private.safe043_moderation_report_json(entity_id, false);

    when 'resolveReport' then
      select r.school_id, r.status, r.version, r.reported_by, to_jsonb(r)
        into resolved_school, existing_status, existing_version, v_user, before_value
      from public.reports r where r.id = p_resource_id for update;
      if resolved_school is null then return jsonb_build_object('outcome', 'not_found'); end if;
      if not private.safe043_can_access_report(resolved_school, p_resource_id) then
        return jsonb_build_object('outcome', 'forbidden');
      end if;
      if existing_status not in ('under_review', 'on_hold') then
        return jsonb_build_object('outcome', 'invalid_state');
      end if;
      if existing_version <> (req_body->>'expectedVersion')::bigint then
        return jsonb_build_object('outcome', 'version_conflict');
      end if;
      v_resolution := (req_body->>'resolution')::public.report_resolution;
      update public.reports set status = 'resolved', resolution = v_resolution,
        resolution_note = nullif(req_body->>'note', ''), resolved_at = now(),
        version = version + 1, updated_at = now()
      where id = p_resource_id;
      insert into public.report_events(school_id, report_id, actor_id, event, detail)
      values (resolved_school, p_resource_id, auth.uid(), 'resolve',
        jsonb_build_object('resolution', v_resolution, 'note', nullif(req_body->>'note', '')));
      perform private.notify_recipient(
        resolved_school, v_user, 'safety.report_resolved',
        jsonb_build_object('reportId', p_resource_id, 'resolution', v_resolution),
        'report:' || p_resource_id, 'safety.report_resolved:' || p_resource_id
      );
      entity_id := p_resource_id; entity_type := 'report'; audit_action := 'report_resolved';
      tenant := resolved_school;
      response := private.safe043_moderation_report_json(entity_id, false);

    when 'escalateReport' then
      select r.school_id, r.status, r.version, r.reported_by, to_jsonb(r)
        into resolved_school, existing_status, existing_version, v_user, before_value
      from public.reports r where r.id = p_resource_id for update;
      if resolved_school is null then return jsonb_build_object('outcome', 'not_found'); end if;
      if not private.safe043_can_access_report(resolved_school, p_resource_id) then
        return jsonb_build_object('outcome', 'forbidden');
      end if;
      if existing_status in ('resolved', 'withdrawn') then
        return jsonb_build_object('outcome', 'invalid_state');
      end if;
      if existing_version <> (req_body->>'expectedVersion')::bigint then
        return jsonb_build_object('outcome', 'version_conflict');
      end if;
      update public.reports set status = 'escalated',
        version = version + 1, updated_at = now()
      where id = p_resource_id;
      insert into public.report_events(school_id, report_id, actor_id, event, detail)
      values (resolved_school, p_resource_id, auth.uid(), 'escalate',
        jsonb_build_object('note', nullif(req_body->>'note', '')));
      perform private.notify_recipient(
        resolved_school, v_user, 'safety.report_escalated',
        jsonb_build_object('reportId', p_resource_id),
        'report:' || p_resource_id, 'safety.report_escalated:' || p_resource_id
      );
      entity_id := p_resource_id; entity_type := 'report'; audit_action := 'report_escalated';
      tenant := resolved_school;
      response := private.safe043_moderation_report_json(entity_id, true);

    when 'addReportEvidence' then
      select r.school_id, r.status, r.version, to_jsonb(r)
        into resolved_school, existing_status, existing_version, before_value
      from public.reports r where r.id = p_resource_id for update;
      if resolved_school is null then return jsonb_build_object('outcome', 'not_found'); end if;
      if not private.safe043_can_access_report(resolved_school, p_resource_id) then
        return jsonb_build_object('outcome', 'forbidden');
      end if;
      v_kind := req_body->>'kind';
      if v_kind = 'message' then
        if not exists (
          select 1 from public.messages m
          where m.id = (req_body->>'messageId')::uuid and m.school_id = resolved_school
        ) then return jsonb_build_object('outcome', 'invalid'); end if;
      elsif v_kind = 'attachment' then
        if not exists (
          select 1 from public.file_objects f
          where f.id = (req_body->>'attachmentFileId')::uuid and f.school_id = resolved_school
        ) then return jsonb_build_object('outcome', 'invalid'); end if;
      elsif v_kind is null or v_kind <> 'note' then
        return jsonb_build_object('outcome', 'invalid');
      end if;
      insert into public.report_evidence(
        school_id, report_id, added_by, kind, message_id, attachment_file_id,
        note, content_hash
      ) values (
        resolved_school, p_resource_id, auth.uid(), v_kind,
        case when v_kind = 'message' then (req_body->>'messageId')::uuid end,
        case when v_kind = 'attachment' then (req_body->>'attachmentFileId')::uuid end,
        case when v_kind = 'note' then req_body->>'note' end,
        nullif(req_body->>'contentHash', '')
      ) returning id into entity_id;
      insert into public.report_events(school_id, report_id, actor_id, event, detail)
      values (resolved_school, p_resource_id, auth.uid(), 'evidence_added',
        jsonb_build_object('evidenceId', entity_id, 'kind', v_kind));
      tenant := resolved_school;
      response := private.safe043_moderation_report_json(p_resource_id, false);
      entity_type := 'report'; audit_action := 'report_evidence_added';

    when 'holdReport' then
      select r.school_id, r.status, r.subject_user_id, to_jsonb(r)
        into resolved_school, existing_status, v_subject, before_value
      from public.reports r where r.id = p_resource_id for update;
      if resolved_school is null then return jsonb_build_object('outcome', 'not_found'); end if;
      if not private.is_platform_operator() then return jsonb_build_object('outcome', 'forbidden'); end if;
      v_applied := coalesce(nullif(req_body->>'appliedTo', ''), 'report');
      v_for_user := coalesce(nullif(req_body->>'subjectUserId', '')::uuid, v_subject);
      if v_applied = 'account' and v_for_user is null then
        return jsonb_build_object('outcome', 'invalid');
      end if;
      -- Applying an account hold to a live deletion request is what makes the
      -- hold actually retain data: the existing deletion constraint refuses to
      -- complete a request flagged as held.
      if v_applied = 'account' then
        select d.* into v_deletion from public.account_deletion_requests d
        where d.user_id = v_for_user and d.state in ('grace_period', 'executing')
        for update;
        if v_deletion.id is not null then
          update public.account_deletion_requests
          set legal_hold = true,
            legal_hold_reason = coalesce(legal_hold_reason, req_body->>'reason')
          where id = v_deletion.id;
        end if;
      end if;
      insert into public.legal_holds(
        school_id, subject_user_id, report_id, account_deletion_request_id,
        applied_to, reason, ticket_ref, granted_by, expires_at
      ) values (
        resolved_school, v_for_user, p_resource_id, v_deletion.id,
        v_applied, req_body->>'reason', req_body->>'ticketRef', auth.uid(),
        case when (req_body->>'expiresAt') is not null
          then greatest((req_body->>'expiresAt')::timestamptz, now() + interval '1 hour')
          else null end
      ) returning id into entity_id;
      if existing_status in ('submitted', 'queued', 'under_review', 'escalated') then
        update public.reports set status = 'on_hold', version = version + 1, updated_at = now()
        where id = p_resource_id;
      end if;
      insert into public.report_events(school_id, report_id, actor_id, event, detail)
      values (resolved_school, p_resource_id, auth.uid(), 'hold',
        jsonb_build_object('holdId', entity_id, 'appliedTo', v_applied));
      tenant := resolved_school;
      response := private.safe043_legal_hold_json(entity_id);
      entity_type := 'legal_hold'; audit_action := 'legal_hold_applied';
      v_template := 'safety.report_held'; outbox_entity := entity_id;

    when 'releaseLegalHold' then
      select h.* into v_hold from public.legal_holds h
      where h.id = p_resource_id for update;
      if v_hold.id is null then return jsonb_build_object('outcome', 'not_found'); end if;
      -- A platform operator may release any hold; a school admin only a
      -- user-scoped hold of their own school (the account-deletion pause is
      -- theirs to lift; the report scoping is a platform responsibility).
      if not (
        private.is_platform_operator()
        or (v_hold.applied_to = 'account' and private.is_school_admin(v_hold.school_id))
      ) then return jsonb_build_object('outcome', 'forbidden'); end if;
      if v_hold.status <> 'active' then return jsonb_build_object('outcome', 'invalid_state'); end if;
      if v_hold.version <> (req_body->>'expectedVersion')::bigint then
        return jsonb_build_object('outcome', 'version_conflict');
      end if;
      before_value := to_jsonb(v_hold);
      update public.legal_holds set status = 'released', released_by = auth.uid(),
        released_reason = coalesce(nullif(req_body->>'reason', ''), 'released'),
        released_at = now(), version = version + 1, updated_at = now()
      where id = p_resource_id;
      if v_hold.applied_to = 'account' and v_hold.account_deletion_request_id is not null then
        if not exists (
          select 1 from public.legal_holds h2
          where h2.id <> p_resource_id and h2.status = 'active'
            and h2.applied_to = 'account'
            and h2.subject_user_id = v_hold.subject_user_id
        ) then
          update public.account_deletion_requests
          set legal_hold = false
          where id = v_hold.account_deletion_request_id;
        end if;
      end if;
      resolved_school := v_hold.school_id;
      entity_id := p_resource_id; entity_type := 'legal_hold'; audit_action := 'legal_hold_released';
      response := private.safe043_legal_hold_json(entity_id);

    when 'requestModerationAccess' then
      resolved_school := nullif(req_body->>'schoolId', '')::uuid;
      if not exists (select 1 from public.schools s where s.id = resolved_school) then
        return jsonb_build_object('outcome', 'not_found');
      end if;
      if not (private.is_platform_operator() or private.is_school_admin(resolved_school)) then
        return jsonb_build_object('outcome', 'forbidden');
      end if;
      if not coalesce((p_input->>'aal2')::boolean, false) then
        return jsonb_build_object('outcome', 'forbidden');
      end if;
      perform private.lazily_expire_moderation_access(resolved_school);
      insert into public.moderation_access_grants(
        school_id, requested_by, reason, ticket_ref, resource_scope, status,
        requires_second_approver, mfa_verified_at, expires_at, version
      ) values (
        resolved_school, auth.uid(), req_body->>'reason', req_body->>'ticketRef',
        coalesce(req_body->'resourceScope', '{}'::jsonb), 'pending',
        coalesce((req_body->>'requiresSecondApprover')::boolean, true), now(),
        now() + make_interval(mins => least(greatest(
          coalesce((req_body->>'durationMinutes')::int, 60), 1), 480)),
        1
      ) returning id into entity_id;
      tenant := resolved_school;
      response := private.safe043_moderation_grant_json(entity_id);
      entity_type := 'moderation_access_grant'; audit_action := 'moderation_access_requested';

    when 'approveModerationAccess' then
      select g.school_id, g.status, g.version, to_jsonb(g)
        into resolved_school, existing_status, existing_version, before_value
      from public.moderation_access_grants g where g.id = p_resource_id for update;
      if resolved_school is null then return jsonb_build_object('outcome', 'not_found'); end if;
      if not private.safe043_is_second_approver(p_resource_id) then
        return jsonb_build_object('outcome', 'forbidden');
      end if;
      if not coalesce((p_input->>'aal2')::boolean, false) then
        return jsonb_build_object('outcome', 'forbidden');
      end if;
      perform private.lazily_expire_moderation_access(resolved_school);
      select status, version into existing_status, existing_version
      from public.moderation_access_grants where id = p_resource_id;
      if existing_status <> 'pending' then return jsonb_build_object('outcome', 'invalid_state'); end if;
      if existing_version <> (req_body->>'expectedVersion')::bigint then
        return jsonb_build_object('outcome', 'version_conflict');
      end if;
      update public.moderation_access_grants set status = 'approved',
        approved_by = auth.uid(), version = version + 1, updated_at = now()
      where id = p_resource_id;
      entity_id := p_resource_id; entity_type := 'moderation_access_grant';
      audit_action := 'moderation_access_approved';
      tenant := resolved_school;
      response := private.safe043_moderation_grant_json(entity_id);

    when 'startModerationAccess' then
      select g.school_id, g.status, g.version, to_jsonb(g)
        into resolved_school, existing_status, existing_version, before_value
      from public.moderation_access_grants g where g.id = p_resource_id for update;
      if resolved_school is null then return jsonb_build_object('outcome', 'not_found'); end if;
      if not exists (
        select 1 from public.moderation_access_grants g
        where g.id = p_resource_id and g.requested_by = auth.uid()
      ) then return jsonb_build_object('outcome', 'forbidden'); end if;
      perform private.lazily_expire_moderation_access(resolved_school);
      select status, version into existing_status, existing_version
      from public.moderation_access_grants where id = p_resource_id;
      if existing_status <> 'approved' then return jsonb_build_object('outcome', 'invalid_state'); end if;
      if existing_version <> (req_body->>'expectedVersion')::bigint then
        return jsonb_build_object('outcome', 'version_conflict');
      end if;
      update public.moderation_access_grants set status = 'active', started_at = now(),
        version = version + 1, updated_at = now()
      where id = p_resource_id;
      entity_id := p_resource_id; entity_type := 'moderation_access_grant';
      audit_action := 'moderation_access_started';
      tenant := resolved_school;
      response := private.safe043_moderation_grant_json(entity_id);

    when 'revokeModerationAccess' then
      select g.school_id, g.status, g.version, to_jsonb(g)
        into resolved_school, existing_status, existing_version, before_value
      from public.moderation_access_grants g where g.id = p_resource_id for update;
      if resolved_school is null then return jsonb_build_object('outcome', 'not_found'); end if;
      if not (private.is_platform_operator() or private.is_school_admin(resolved_school)) then
        return jsonb_build_object('outcome', 'forbidden');
      end if;
      if existing_status not in ('pending', 'approved', 'active') then
        return jsonb_build_object('outcome', 'invalid_state');
      end if;
      if existing_version <> (req_body->>'expectedVersion')::bigint then
        return jsonb_build_object('outcome', 'version_conflict');
      end if;
      update public.moderation_access_grants set status = 'revoked', revoked_by = auth.uid(),
        revoked_reason = nullif(req_body->>'reason', ''), ended_at = now(),
        version = version + 1, updated_at = now()
      where id = p_resource_id;
      entity_id := p_resource_id; entity_type := 'moderation_access_grant';
      audit_action := 'moderation_access_revoked';
      tenant := resolved_school;
      response := private.safe043_moderation_grant_json(entity_id);

    else return jsonb_build_object('outcome', 'invalid');
  end case;

  insert into public.audit_events(school_id, actor_id, action, entity_type, entity_id, before_value, after_value, request_id)
  values (tenant, auth.uid(), audit_action, entity_type, entity_id, before_value, response, request_id);
  if v_template is not null then
    insert into public.notification_outbox(school_id, source_event_id, idempotency_key, channel, template_key, audience, payload)
    values (tenant, outbox_entity::text, idem_key, 'in_app', v_template,
      jsonb_build_object('schoolId', tenant), coalesce(response, '{}'::jsonb));
  end if;
  completed := private.api_idempotency_complete(p_idempotency_id, p_idempotency_generation, response_status, response);
  if not completed then raise exception 'API042_IDEMPOTENCY_COMPLETION_FAILED'; end if;
  return jsonb_build_object('outcome', 'ok', 'response', response);
end;
$function$;

drop function private.api042_command_pre_safe043(text, uuid, jsonb, uuid, bigint);
drop function private.api042_command_pre_s9_roster(text, uuid, jsonb, uuid, bigint);
drop function private.api042_command_pre_s8_support(text, uuid, jsonb, uuid, bigint);
drop function private.api042_command_pre_s7_account(text, uuid, jsonb, uuid, bigint);
drop function private.api042_command_pre_s6_notifications(text, uuid, jsonb, uuid, bigint);
drop function private.api042_command_pre_s5_meetings(text, uuid, jsonb, uuid, bigint);
drop function private.api042_command_pre_s4_comms(text, uuid, jsonb, uuid, bigint);
drop function private.api042_command_pre_s3_family(text, uuid, jsonb, uuid, bigint);
drop function private.api042_command_pre_s2_invitations(text, uuid, jsonb, uuid, bigint);
