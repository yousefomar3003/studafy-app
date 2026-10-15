-- Capacity fix 5 (docs/capacity/2026-10-14.md, "Next" 1): conversations
-- built for the whole page at once.
--
-- Every conversation in the list was built by api042_conversation_json,
-- one call per row, and each call named every participant's role through
-- messaging_role, which asks is_school_staff and then looks for a student
-- record: two function calls per participant per conversation. A class
-- conversation has a teacher and its students, so a student's list of three
-- made about 160 calls. On the scale data the list and its row builder were
-- 6.2% + 5.7% of database time.
--
-- api042_conversation_rows builds a page in one query. Each participant's
-- role comes from the same rule, answered for the whole page at once: staff
-- if is_school_staff would say so (the same membership conditions), else a
-- student if they have a live student record in the conversation's school,
-- else a guardian. Fields, order and values are unchanged. The list
-- (ops_query_messaging) calls it; only that line changes there, the rest is
-- re-stated unchanged, as CREATE OR REPLACE requires.
-- api042_conversation_json stays for the single-conversation responses.
--
-- Proven before shipping like fixes 1-3 (docs/capacity/2026-10-15.md).

-- A page of conversations, in the order of p_ids, each exactly as
-- api042_conversation_json builds it for the caller.
create or replace function private.api042_conversation_rows(p_ids uuid[])
returns jsonb
language sql stable security definer set search_path = '' as $$
  with page as (
    select p.id, p.ord from unnest(p_ids) with ordinality as p(id, ord)
  ), people as (
    -- Everyone still in each conversation on the page.
    select cp.conversation_id, cp.user_id, c.school_id, pr.display_name
    from page pg
    join public.conversations c on c.id = pg.id
    join public.conversation_participants cp on cp.conversation_id = c.id
    join public.profiles pr on pr.id = cp.user_id
    where cp.left_at is null
  ), pairs as (
    select distinct pp.user_id, pp.school_id from people pp
  ), staff as (
    -- is_school_staff(user, school), for every pair at once.
    select distinct m.user_id, m.school_id
    from pairs q
    join public.memberships m on m.user_id = q.user_id and m.school_id = q.school_id
    where m.role in ('teacher', 'school_admin')
      and m.active and m.status = 'active'
      and (m.valid_from is null or m.valid_from <= now())
      and (m.valid_until is null or m.valid_until > now())
  ), pupils as (
    -- messaging_role's student test: a live student record in that school.
    select distinct st.user_id, st.school_id
    from pairs q
    join public.students st on st.user_id = q.user_id and st.school_id = q.school_id
    where st.deleted_at is null
  ), roles as (
    select pp.conversation_id, jsonb_agg(jsonb_build_object(
        'userId', pp.user_id,
        'displayName', pp.display_name,
        'role', case when sf.user_id is not null then 'staff'
          when pu.user_id is not null then 'student'
          else 'guardian' end
      ) order by pp.display_name, pp.user_id) as items
    from people pp
    left join staff sf on sf.user_id = pp.user_id and sf.school_id = pp.school_id
    left join pupils pu on pu.user_id = pp.user_id and pu.school_id = pp.school_id
    group by pp.conversation_id
  )
  select jsonb_agg(case when c.id is null then null else jsonb_build_object(
      'id', c.id, 'schoolId', c.school_id, 'subject', c.subject, 'state', c.state,
      'lastReadAt', me.last_read_at,
      'updatedAt', c.updated_at,
      'participants', coalesce(rl.items, '[]'::jsonb)) end
    order by pg.ord)
  from page pg
  left join public.conversations c on c.id = pg.id
  left join public.conversation_participants me
    on me.conversation_id = c.id and me.user_id = auth.uid()
  left join roles rl on rl.conversation_id = c.id;
$$;

CREATE OR REPLACE FUNCTION private.ops_query_messaging(p_operation text, p_resource_id uuid, p_input jsonb)
 RETURNS jsonb
 LANGUAGE plpgsql
 STABLE SECURITY DEFINER
 SET search_path TO ''
AS $function$
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
      -- The page's rows are built together (capacity fix 5).
      select coalesce(private.api042_conversation_rows(array_agg(x.id order by x.updated_at desc, x.id desc)), '[]'::jsonb),
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
      ), '[]'::jsonb) else '[]'::jsonb end,
      -- Ids as well as names. Two children in one class can share a display
      -- name, and matching a guardian to a child by name would attach one
      -- family's contact to the other child's record.
      'relatedStudentIds', case when v_staff then coalesce((
        select jsonb_agg(st.id order by st.display_name)
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
$function$

;

do $grants$
declare fn text;
begin
  foreach fn in array array[
    'private.api042_conversation_rows(uuid[])',
    'private.ops_query_messaging(text, uuid, jsonb)'
  ] loop
    execute format('alter function %s owner to postgres', fn);
  end loop;
end
$grants$;

revoke all on function private.api042_conversation_rows(uuid[])
  from public, anon, authenticated, service_role, studafy_api_runtime, studafy_worker_runtime;
