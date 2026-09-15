-- API-042 S4: conversations/messages/announcements plumbing only. No
-- report/block/moderation surface - that is SAFE-043's job, and per the
-- Phase 4 gate communications is not launch-authorized without it.

create or replace function private.can_message_in_school(p_user uuid, p_school uuid)
returns boolean language sql stable security definer set search_path = '' as $$
  select exists (
    select 1 from public.memberships m where m.user_id = p_user and m.school_id = p_school
      and m.active and m.status = 'active'
      and (m.valid_from is null or m.valid_from <= now())
      and (m.valid_until is null or m.valid_until > now())
  ) or exists (
    select 1 from public.guardian_links gl join public.students st on st.id = gl.student_id
    where gl.guardian_id = p_user and st.school_id = p_school and gl.status = 'verified'
      and (gl.expires_at is null or gl.expires_at > now())
  );
$$;

create or replace function private.is_conversation_participant(p_conversation uuid)
returns boolean language sql stable security definer set search_path = '' as $$
  select exists (
    select 1 from public.conversation_participants cp
    where cp.conversation_id = p_conversation and cp.user_id = auth.uid() and cp.left_at is null
  );
$$;

alter function private.authz_authorize(text, uuid)
  rename to authz_authorize_pre_api042_comms;

create or replace function private.authz_authorize(p_action text, p_resource_id uuid)
returns jsonb language plpgsql stable security definer set search_path = '' as $$
declare target_school uuid; permitted boolean := false;
begin
  if p_action not in ('message.list', 'message.send', 'announcement.create', 'announcement.list') then
    return private.authz_authorize_pre_api042_comms(p_action, p_resource_id);
  end if;
  if auth.uid() is null or p_resource_id is null then
    return jsonb_build_object('allowed', false, 'school_id', null, 'reason', 'invalid_resource');
  end if;

  case
    when p_action in ('message.list', 'message.send') then
      select c.school_id, private.is_conversation_participant(c.id)
      into target_school, permitted from public.conversations c where c.id = p_resource_id;
    when p_action = 'announcement.list' then
      select s.id, private.has_active_membership(s.id)
      into target_school, permitted from public.schools s where s.id = p_resource_id;
    when p_action = 'announcement.create' then
      select s.id, private.is_school_admin(s.id)
      into target_school, permitted from public.schools s where s.id = p_resource_id;
      if target_school is null then
        select c.school_id, private.api041_class_writer(c.id) into target_school, permitted
        from public.classrooms c where c.id = p_resource_id;
      end if;
  end case;
  return jsonb_build_object('allowed', coalesce(permitted, false), 'school_id', target_school,
    'reason', case when target_school is null then 'invalid_resource' when permitted then 'allowed' else 'denied' end);
end;
$$;

create or replace function private.api042_conversation_json(p_id uuid)
returns jsonb language sql stable security definer set search_path = '' as $$
  select jsonb_build_object(
    'id', c.id, 'schoolId', c.school_id, 'subject', c.subject, 'state', c.state,
    'lastReadAt', (select cp.last_read_at from public.conversation_participants cp
      where cp.conversation_id = c.id and cp.user_id = auth.uid())
  ) from public.conversations c where c.id = p_id;
$$;

create or replace function private.api042_message_json(p_id uuid)
returns jsonb language sql stable security definer set search_path = '' as $$
  select jsonb_build_object(
    'id', m.id, 'conversationId', m.conversation_id, 'senderId', m.sender_id,
    'clientMessageId', m.client_message_id, 'body', m.body, 'createdAt', m.created_at
  ) from public.messages m where m.id = p_id and m.deleted_at is null;
$$;

create or replace function private.api042_announcement_json(p_id uuid)
returns jsonb language sql stable security definer set search_path = '' as $$
  select jsonb_build_object(
    'id', a.id, 'schoolId', a.school_id, 'classroomId', a.classroom_id, 'title', a.title,
    'body', a.body, 'audience', a.audience, 'important', a.important, 'publishedAt', a.published_at
  ) from public.announcements a where a.id = p_id;
$$;

alter function private.api042_query(text, uuid, jsonb)
  rename to api042_query_pre_s4_comms;

create or replace function private.api042_query(p_operation text, p_resource_id uuid, p_input jsonb)
returns jsonb language plpgsql stable security definer set search_path = '' as $$
declare tenant uuid; limit_rows int; pos uuid; result jsonb; next_pos text;
begin
  if p_operation not in ('listConversations', 'listMessages', 'listAnnouncements') then
    return private.api042_query_pre_s4_comms(p_operation, p_resource_id, p_input);
  end if;
  if auth.uid() is null then return jsonb_build_object('outcome', 'forbidden'); end if;
  limit_rows := least(greatest(coalesce((p_input->>'pageSize')::int, 50), 1), 100);
  pos := nullif(p_input->>'position', '')::uuid;

  case p_operation
    when 'listConversations' then
      select coalesce(jsonb_agg(private.api042_conversation_json(x.id) order by x.id), '[]'), max(x.id::text)
        into result, next_pos from (
        select c.id from public.conversations c
        join public.conversation_participants cp on cp.conversation_id = c.id
        where cp.user_id = auth.uid() and cp.left_at is null and (pos is null or c.id > pos)
        order by c.id limit limit_rows
      ) x;
      return jsonb_build_object('items', result, 'nextPosition', case when jsonb_array_length(result) = limit_rows then next_pos end);

    when 'listMessages' then
      if not private.is_conversation_participant(p_resource_id) then return jsonb_build_object('outcome', 'not_found'); end if;
      select coalesce(jsonb_agg(private.api042_message_json(x.id) order by x.id), '[]'), max(x.id::text)
        into result, next_pos from (
        select m.id from public.messages m where m.conversation_id = p_resource_id and m.deleted_at is null
          and (pos is null or m.id > pos) order by m.id limit limit_rows
      ) x;
      return jsonb_build_object('items', result, 'nextPosition', case when jsonb_array_length(result) = limit_rows then next_pos end);

    when 'listAnnouncements' then
      tenant := nullif(p_input->>'schoolId', '')::uuid;
      if tenant is null or not private.has_active_membership(tenant) then return jsonb_build_object('outcome', 'forbidden'); end if;
      select coalesce(jsonb_agg(private.api042_announcement_json(x.id) order by x.id), '[]'), max(x.id::text)
        into result, next_pos from (
        select a.id from public.announcements a where a.school_id = tenant and (pos is null or a.id > pos)
          and (a.classroom_id is null or private.can_view_classroom(a.classroom_id))
        order by a.id limit limit_rows
      ) x;
      return jsonb_build_object('items', result, 'nextPosition', case when jsonb_array_length(result) = limit_rows then next_pos end);
    else return jsonb_build_object('outcome', 'not_found');
  end case;
end;
$$;

alter function private.api042_command(text, uuid, jsonb, uuid, bigint)
  rename to api042_command_pre_s4_comms;

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
  response jsonb; before_value jsonb;
  entity_id uuid; entity_type text; audit_action text;
  idem_key text; resolved_school uuid; v_participant uuid; participants uuid[];
  outbox_template text; outbox_entity uuid; completed boolean;
  response_status int := coalesce((p_input->>'responseStatus')::int, 200);
begin
  if p_operation not in ('createConversation', 'sendMessage', 'createAnnouncement') then
    return private.api042_command_pre_s4_comms(
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
$$;

alter function private.can_message_in_school(uuid, uuid) owner to postgres;
alter function private.is_conversation_participant(uuid) owner to postgres;
alter function private.api042_conversation_json(uuid) owner to postgres;
alter function private.api042_message_json(uuid) owner to postgres;
alter function private.api042_announcement_json(uuid) owner to postgres;
alter function private.api042_query(text, uuid, jsonb) owner to postgres;
alter function private.api042_command(text, uuid, jsonb, uuid, bigint) owner to postgres;
alter function private.authz_authorize(text, uuid) owner to postgres;

revoke all on function private.can_message_in_school(uuid, uuid), private.is_conversation_participant(uuid),
  private.api042_conversation_json(uuid), private.api042_message_json(uuid), private.api042_announcement_json(uuid),
  private.api042_query(text, uuid, jsonb), private.api042_command(text, uuid, jsonb, uuid, bigint)
from public, anon, authenticated, service_role, studafy_worker_runtime;
revoke all on function private.api042_query_pre_s4_comms(text, uuid, jsonb)
from public, anon, authenticated, service_role, studafy_worker_runtime, studafy_api_runtime;
revoke all on function private.api042_command_pre_s4_comms(text, uuid, jsonb, uuid, bigint)
from public, anon, authenticated, service_role, studafy_worker_runtime, studafy_api_runtime;
revoke all on function private.authz_authorize_pre_api042_comms(text, uuid)
from public, anon, authenticated, service_role, studafy_worker_runtime, studafy_api_runtime;
revoke all on function private.authz_authorize(text, uuid)
from public, anon, authenticated, service_role, studafy_worker_runtime;
grant execute on function private.authz_authorize(text, uuid),
  private.api042_query(text, uuid, jsonb), private.api042_command(text, uuid, jsonb, uuid, bigint)
to studafy_api_runtime;

revoke all privileges on all tables in schema public from studafy_api_runtime;
revoke all privileges on all sequences in schema public from studafy_api_runtime;
