-- Messaging order (DL-049). listMessages and listConversations paged by
-- random UUID, so a chat rendered out of order and a page boundary cut
-- through time arbitrarily. Both now use keyset paging on time, newest
-- first, matching the existing db020_messages_conversation_cursor index.
-- The cursor position becomes "<timestamptz>|<uuid>"; it stays opaque and
-- server-signed to clients, so no contract change is needed.

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
  pos_at timestamptz;
  pos_id uuid;
begin
  if p_operation in ('listMessages', 'listConversations') then
    if v_actor is null then return jsonb_build_object('outcome', 'forbidden'); end if;
    limit_rows := least(greatest(coalesce((p_input->>'pageSize')::int, 50), 1), 100);
    -- Keyset position "<timestamptz>|<uuid>". A malformed position is
    -- treated as absent rather than raising.
    begin
      pos_at := nullif(split_part(p_input->>'position', '|', 1), '')::timestamptz;
      pos_id := nullif(split_part(p_input->>'position', '|', 2), '')::uuid;
    exception when others then
      pos_at := null; pos_id := null;
    end;

    if p_operation = 'listMessages' then
      if not private.is_conversation_participant(p_resource_id) then
        return jsonb_build_object('outcome', 'not_found');
      end if;
      -- Newest first, the order a chat screen pages backwards through.
      select coalesce(jsonb_agg(private.api042_message_json(x.id) order by x.created_at desc, x.id desc), '[]'::jsonb),
        (array_agg(x.created_at::text || '|' || x.id::text order by x.created_at, x.id))[1]
      into result, next_pos
      from (
        select m.id, m.created_at from public.messages m
        where m.conversation_id = p_resource_id and m.deleted_at is null
          and (pos_at is null or (m.created_at, m.id) < (pos_at, pos_id))
        order by m.created_at desc, m.id desc
        limit limit_rows
      ) x;
    else
      -- Most recently active first.
      select coalesce(jsonb_agg(private.api042_conversation_json(x.id) order by x.updated_at desc, x.id desc), '[]'::jsonb),
        (array_agg(x.updated_at::text || '|' || x.id::text order by x.updated_at, x.id))[1]
      into result, next_pos
      from (
        select c.id, c.updated_at from public.conversations c
        join public.conversation_participants cp on cp.conversation_id = c.id
        where cp.user_id = v_actor and cp.left_at is null
          and (pos_at is null or (c.updated_at, c.id) < (pos_at, pos_id))
        order by c.updated_at desc, c.id desc
        limit limit_rows
      ) x;
    end if;
    return jsonb_build_object('items', result, 'nextPosition',
      case when jsonb_array_length(result) = limit_rows then next_pos end);
  end if;

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

alter function private.api042_query(text, uuid, jsonb) owner to postgres;
revoke all on function private.api042_query(text, uuid, jsonb)
  from public, anon, authenticated, service_role, studafy_worker_runtime;
grant execute on function private.api042_query(text, uuid, jsonb) to studafy_api_runtime;
