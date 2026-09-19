-- Messaging safeguards (DL-049). Three defects found while building the
-- mobile report/block controls on top of API-042 communications:
--
-- 1. Private message contents leaked school-wide. sendMessage wrote an
--    audience outbox row ({"schoolId": ...}) whose payload was the whole
--    message, body included. OPS-061 expands that audience into an in-app
--    delivery for every active teacher and school admin, and the
--    notifications API returns the payload. Every private message between a
--    parent and a teacher, or a student and a teacher, would have been
--    readable by every member of staff - and the actual recipients were
--    never notified at all.
-- 2. No contact policy. Any member or verified guardian of a school could
--    open a conversation with any other, so a parent could message another
--    family's child directly.
-- 3. The school's `messaging_enabled` content control (default off) was
--    stored and displayed but never enforced.
--
-- Contact policy (safeguarding default, recorded in DL-049):
--   * staff (active teacher or school_admin) may contact anyone in the school;
--   * anyone in the school may contact staff;
--   * a guardian and the child they hold a verified, unexpired link to may
--     contact each other;
--   * nothing else: no student-to-student, guardian-to-other-child or
--     guardian-to-guardian conversations.
-- The policy is enforced when a conversation is created and again on every
-- message, so a revoked guardian link or ended membership stops contact
-- immediately rather than at the next conversation.

create or replace function private.is_school_staff(p_user uuid, p_school uuid)
returns boolean language sql stable security definer set search_path = '' as $$
  select exists (
    select 1 from public.memberships m
    where m.user_id = p_user and m.school_id = p_school
      and m.role in ('teacher', 'school_admin')
      and m.active and m.status = 'active'
      and (m.valid_from is null or m.valid_from <= now())
      and (m.valid_until is null or m.valid_until > now())
  );
$$;

create or replace function private.is_guardian_of_user(p_guardian uuid, p_student_user uuid, p_school uuid)
returns boolean language sql stable security definer set search_path = '' as $$
  select exists (
    select 1 from public.guardian_links gl
    join public.students st on st.id = gl.student_id and st.deleted_at is null
    where gl.guardian_id = p_guardian and st.user_id = p_student_user
      and st.school_id = p_school and gl.status = 'verified'
      and (gl.expires_at is null or gl.expires_at > now())
  );
$$;

create or replace function private.can_contact(p_from uuid, p_to uuid, p_school uuid)
returns boolean language sql stable security definer set search_path = '' as $$
  select p_from is not null and p_to is not null and p_from <> p_to
    and private.can_message_in_school(p_from, p_school)
    and private.can_message_in_school(p_to, p_school)
    and (
      private.is_school_staff(p_from, p_school)
      or private.is_school_staff(p_to, p_school)
      or private.is_guardian_of_user(p_from, p_to, p_school)
      or private.is_guardian_of_user(p_to, p_from, p_school)
    );
$$;

create or replace function private.school_messaging_enabled(p_school uuid)
returns boolean language sql stable security definer set search_path = '' as $$
  select coalesce((select cc.messaging_enabled from public.school_content_controls cc
    where cc.school_id = p_school), false);
$$;

create or replace function private.messaging_role(p_user uuid, p_school uuid)
returns text language sql stable security definer set search_path = '' as $$
  select case
    when private.is_school_staff(p_user, p_school) then 'staff'
    when exists (select 1 from public.students st where st.user_id = p_user
      and st.school_id = p_school and st.deleted_at is null) then 'student'
    else 'guardian' end;
$$;

-- Conversations now name their active participants, so a client can show
-- who it is talking to and target a report or block at a person.
create or replace function private.api042_conversation_json(p_id uuid)
returns jsonb language sql stable security definer set search_path = '' as $$
  select jsonb_build_object(
    'id', c.id, 'schoolId', c.school_id, 'subject', c.subject, 'state', c.state,
    'lastReadAt', (select cp.last_read_at from public.conversation_participants cp
      where cp.conversation_id = c.id and cp.user_id = auth.uid()),
    'updatedAt', c.updated_at,
    'participants', coalesce((
      select jsonb_agg(jsonb_build_object(
          'userId', cp.user_id,
          'displayName', p.display_name,
          'role', private.messaging_role(cp.user_id, c.school_id)
        ) order by p.display_name, cp.user_id)
      from public.conversation_participants cp
      join public.profiles p on p.id = cp.user_id
      where cp.conversation_id = c.id and cp.left_at is null
    ), '[]'::jsonb)
  ) from public.conversations c where c.id = p_id;
$$;

-- -------------------------------------------------------------------------
-- Queries: listContacts is new; everything else delegates.
-- -------------------------------------------------------------------------
alter function private.api042_query(text, uuid, jsonb)
  rename to api042_query_pre_messaging;

create or replace function private.api042_query(p_operation text, p_resource_id uuid, p_input jsonb)
returns jsonb language plpgsql stable security definer set search_path = '' as $$
declare
  v_school uuid;
  v_actor uuid := auth.uid();
  v_staff boolean;
  pos uuid;
  limit_rows int;
  result jsonb;
  next_pos text;
begin
  if p_operation <> 'listContacts' then
    return private.api042_query_pre_messaging(p_operation, p_resource_id, p_input);
  end if;
  v_school := nullif(p_input->>'schoolId', '')::uuid;
  if v_actor is null or v_school is null
     or not private.can_message_in_school(v_actor, v_school) then
    return jsonb_build_object('outcome', 'forbidden');
  end if;
  v_staff := private.is_school_staff(v_actor, v_school);
  limit_rows := least(greatest(coalesce((p_input->>'pageSize')::int, 50), 1), 100);
  pos := nullif(p_input->>'position', '')::uuid;

  with candidates as (
    select m.user_id from public.memberships m
    where m.school_id = v_school and m.active and m.status = 'active'
      and (m.valid_from is null or m.valid_from <= now())
      and (m.valid_until is null or m.valid_until > now())
    union
    select gl.guardian_id from public.guardian_links gl
    join public.students st on st.id = gl.student_id and st.deleted_at is null
    where st.school_id = v_school and gl.status = 'verified'
      and (gl.expires_at is null or gl.expires_at > now())
  ), page as (
    select c.user_id from candidates c
    join public.profiles p on p.id = c.user_id and p.status = 'active'
    where (pos is null or c.user_id > pos)
      and private.can_contact(v_actor, c.user_id, v_school)
    order by c.user_id
    limit limit_rows
  )
  select coalesce(jsonb_agg(jsonb_build_object(
      'userId', pg.user_id,
      'displayName', p.display_name,
      'role', private.messaging_role(pg.user_id, v_school),
      -- Staff see which child a guardian belongs to; nobody else is told
      -- about other families.
      'relatedStudentNames', case when v_staff then coalesce((
        select jsonb_agg(st.display_name order by st.display_name)
        from public.guardian_links gl
        join public.students st on st.id = gl.student_id and st.deleted_at is null
        where gl.guardian_id = pg.user_id and st.school_id = v_school
          and gl.status = 'verified' and (gl.expires_at is null or gl.expires_at > now())
      ), '[]'::jsonb) else '[]'::jsonb end
    ) order by pg.user_id), '[]'::jsonb), max(pg.user_id::text)
  into result, next_pos
  from page pg join public.profiles p on p.id = pg.user_id;

  return jsonb_build_object('items', result, 'nextPosition',
    case when jsonb_array_length(result) = limit_rows then next_pos end);
end;
$$;

-- -------------------------------------------------------------------------
-- Commands: createConversation gains the policy and the switch, then
-- delegates; sendMessage is fully owned here so its side effect is a
-- per-participant notification that carries no message content.
-- -------------------------------------------------------------------------
alter function private.api042_command(text, uuid, jsonb, uuid, bigint)
  rename to api042_command_pre_messaging;

create or replace function private.api042_command(
  p_operation text,
  p_resource_id uuid,
  p_input jsonb,
  p_idempotency_id uuid,
  p_idempotency_generation bigint
)
returns jsonb language plpgsql security definer set search_path = '' as $$
declare
  v_actor uuid := auth.uid();
  tenant uuid := nullif(current_setting('studafy.school_id', true), '')::uuid;
  request_id text := nullif(current_setting('studafy.request_id', true), '');
  req_body jsonb := coalesce(p_input->'body', '{}'::jsonb);
  response_status int := coalesce((p_input->>'responseStatus')::int, 200);
  v_school uuid;
  v_members uuid[];
  v_participants uuid[];
  v_actor_staff boolean;
  v_recipient uuid;
  idem_key text;
  entity_id uuid;
  response jsonb;
  completed boolean;
begin
  if p_operation not in ('createConversation', 'sendMessage') then
    return private.api042_command_pre_messaging(
      p_operation, p_resource_id, p_input, p_idempotency_id, p_idempotency_generation
    );
  end if;
  if v_actor is null or request_id is null then
    return jsonb_build_object('outcome', 'forbidden');
  end if;

  if p_operation = 'createConversation' then
    v_school := nullif(req_body->>'schoolId', '')::uuid;
    if v_school is not null and not private.school_messaging_enabled(v_school) then
      return jsonb_build_object('outcome', 'messaging_disabled');
    end if;
    select array_agg(distinct x)::uuid[] into v_participants
    from jsonb_array_elements_text(coalesce(req_body->'participantIds', '[]'::jsonb)) x;
    v_actor_staff := v_school is not null and private.is_school_staff(v_actor, v_school);
    if v_school is not null and v_participants is not null and not v_actor_staff and (
      exists (select 1 from unnest(v_participants) p
        where p <> v_actor and not private.can_contact(v_actor, p, v_school)
          and private.can_message_in_school(p, v_school))
      or exists (select 1 from unnest(v_participants) a, unnest(v_participants) b
        where a < b and not private.can_contact(a, b, v_school)
          and private.can_message_in_school(a, v_school)
          and private.can_message_in_school(b, v_school))
    ) then
      -- Participants outside the school keep the downstream 'invalid'
      -- outcome; only an in-school pair the policy forbids is reported here.
      return jsonb_build_object('outcome', 'contact_not_allowed');
    end if;
    return private.api042_command_pre_messaging(
      p_operation, p_resource_id, p_input, p_idempotency_id, p_idempotency_generation
    );
  end if;

  -- sendMessage
  select c.school_id into v_school from public.conversations c
  where c.id = p_resource_id and c.state = 'active';
  if v_school is null or not private.is_conversation_participant(p_resource_id) then
    return jsonb_build_object('outcome', 'not_found');
  end if;
  if not private.school_messaging_enabled(v_school) then
    return jsonb_build_object('outcome', 'messaging_disabled');
  end if;
  select array_agg(cp.user_id) into v_members
  from public.conversation_participants cp
  where cp.conversation_id = p_resource_id and cp.left_at is null;
  if exists (
    select 1 from unnest(v_members) a, unnest(v_members) b
    where a < b and private.safe043_is_blocked_pair(v_school, a, b)
  ) then
    return jsonb_build_object('outcome', 'forbidden');
  end if;
  if not private.can_message_in_school(v_actor, v_school) or (
    not private.is_school_staff(v_actor, v_school) and exists (
      select 1 from unnest(v_members) p
      where p <> v_actor and not private.can_contact(v_actor, p, v_school)
    )
  ) then
    return jsonb_build_object('outcome', 'contact_not_allowed');
  end if;

  select r.idempotency_key into idem_key from public.idempotency_records r
  where r.id = p_idempotency_id and r.actor_id = v_actor
    and r.school_id is not distinct from tenant
    and r.generation = p_idempotency_generation and r.status = 'reserved'
  for update;
  if idem_key is null then return jsonb_build_object('outcome', 'forbidden'); end if;

  insert into public.messages(school_id, conversation_id, sender_id, client_message_id, body)
  values (v_school, p_resource_id, v_actor, (req_body->>'clientMessageId')::uuid, req_body->>'body')
  on conflict (conversation_id, client_message_id) do nothing
  returning id into entity_id;
  if entity_id is null then
    select m.id into entity_id from public.messages m
    where m.conversation_id = p_resource_id
      and m.client_message_id = (req_body->>'clientMessageId')::uuid;
  end if;
  update public.conversations set updated_at = now() where id = p_resource_id;
  update public.conversation_participants set last_read_at = now()
  where conversation_id = p_resource_id and user_id = v_actor;
  response := private.api042_message_json(entity_id);

  insert into public.audit_events(school_id, actor_id, action, entity_type, entity_id, before_value, after_value, request_id)
  values (v_school, v_actor, 'message_sent', 'message', entity_id, null,
    -- The audit trail records that a message exists, never what it says.
    jsonb_build_object('conversationId', p_resource_id, 'messageId', entity_id), request_id);

  foreach v_recipient in array v_members loop
    continue when v_recipient = v_actor;
    perform private.notify_recipient(
      v_school, v_recipient, 'communications.message_sent',
      jsonb_build_object('conversationId', p_resource_id, 'messageId', entity_id),
      'message:' || entity_id,
      'communications.message_sent:' || entity_id || ':' || v_recipient
    );
  end loop;

  completed := private.api_idempotency_complete(p_idempotency_id, p_idempotency_generation, response_status, response);
  if not completed then raise exception 'MESSAGING_IDEMPOTENCY_COMPLETION_FAILED'; end if;
  return jsonb_build_object('outcome', 'ok', 'response', response);
end;
$$;

-- -------------------------------------------------------------------------
-- Remediate rows written by the leaking path. No production data exists;
-- this makes every local and synthetic database consistent with the fix.
-- -------------------------------------------------------------------------
delete from public.notification_deliveries nd
using public.notification_outbox o
where nd.outbox_id = o.id
  and o.template_key = 'communications.message_sent'
  and o.recipient_id is null;

update public.notification_outbox o
  set payload = jsonb_build_object(
        'conversationId', o.payload->'conversationId',
        'messageId', o.payload->'id'),
      state = case when o.state in ('pending', 'retry', 'processing')
        then 'completed'::public.outbox_state else o.state end,
      lease_token = null, lease_until = null, updated_at = now()
where o.template_key = 'communications.message_sent'
  and o.recipient_id is null;

update public.audit_events a
  set after_value = jsonb_build_object(
    'conversationId', a.after_value->'conversationId',
    'messageId', a.entity_id)
where a.action = 'message_sent' and a.after_value ? 'body';

-- -------------------------------------------------------------------------
-- Ownership and grants.
-- -------------------------------------------------------------------------
do $grants$
declare fn text;
begin
  foreach fn in array array[
    'private.is_school_staff(uuid, uuid)',
    'private.is_guardian_of_user(uuid, uuid, uuid)',
    'private.can_contact(uuid, uuid, uuid)',
    'private.school_messaging_enabled(uuid)',
    'private.messaging_role(uuid, uuid)',
    'private.api042_conversation_json(uuid)',
    'private.api042_query(text, uuid, jsonb)',
    'private.api042_command(text, uuid, jsonb, uuid, bigint)',
    'private.api042_query_pre_messaging(text, uuid, jsonb)',
    'private.api042_command_pre_messaging(text, uuid, jsonb, uuid, bigint)'
  ] loop
    execute format('alter function %s owner to postgres', fn);
    execute format('revoke all on function %s from public, anon, authenticated, service_role, studafy_worker_runtime, studafy_api_runtime', fn);
  end loop;
end
$grants$;

grant execute on function
  private.api042_query(text, uuid, jsonb),
  private.api042_command(text, uuid, jsonb, uuid, bigint)
to studafy_api_runtime;
