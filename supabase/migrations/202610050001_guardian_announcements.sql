-- A linked parent reads the announcements meant for parents.
--
-- Most parents link to a child by the child's Studafy ID, which makes a
-- verified guardian_links row and no membership. 202609260003 let such a
-- parent read their child's schoolwork on the strength of the link, but left
-- announcements out: announcement.list and the listAnnouncements query both
-- still required an active membership of the school, so the parent app's
-- Announcements tab failed for every parent who linked the ordinary way.
--
-- The same rule now applies here. With no membership, a verified, unexpired
-- link to a child with a live enrolment at the school (is_linked_guardian)
-- lets the parent list that school's announcements - only those whose
-- audience includes guardians, and only school-wide ones or ones for a class
-- their child is in.
--
-- Callers with a membership are untouched: the guardian path runs only when
-- the ordinary one refuses.

-- ---------------------------------------------------------------------------
-- 1. The decision: announcement.list joins the guardian allowlist, on the
--    school, through a live link to a child there. Copied from
--    202609280001 with that branch added.
-- ---------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION private.authz_guardian_list_reads(p_action text, p_resource_id uuid, p_decision jsonb)
 RETURNS jsonb
 LANGUAGE plpgsql
 STABLE SECURITY DEFINER
 SET search_path TO ''
AS $function$
declare
  decision jsonb;
  sid uuid;
begin
  decision := p_decision;
  if coalesce((decision->>'allowed')::boolean, false)
    or p_action not in ('assignment.list', 'assessment.list', 'resource.list',
      'grade_result.list', 'attendance_record.list', 'upload.intent.create',
      'announcement.list')
    or auth.uid() is null or p_resource_id is null then
    return decision;
  end if;

  -- Starting an upload names only the school. A guardian's standing there is
  -- a verified, unexpired link to a child enrolled in it - the same test
  -- file050_authorize_target applies to the upload itself, which then checks
  -- the exact child and purpose.
  if p_action = 'upload.intent.create' then
    if exists (
      select 1 from public.guardian_links gl
      join public.enrollments e on e.student_id = gl.student_id
        and e.school_id = gl.school_id and e.active and e.status = 'active'
      where gl.school_id = p_resource_id and gl.guardian_id = auth.uid()
        and gl.status = 'verified'
        and (gl.expires_at is null or gl.expires_at > now())
    ) then
      return jsonb_build_object('allowed', true, 'school_id', p_resource_id,
        'reason', 'linked_guardian');
    end if;
    return decision;
  end if;

  -- Listing announcements names the school too. The query then serves only
  -- the rows meant for guardians, in the child's classes or school-wide.
  if p_action = 'announcement.list' then
    if private.is_linked_guardian_at_school(p_resource_id) then
      return jsonb_build_object('allowed', true, 'school_id', p_resource_id,
        'reason', 'linked_guardian');
    end if;
    return decision;
  end if;

  -- The resource is the child named in the request. Anything else - a
  -- school, a class - keeps the ordinary decision.
  select st.school_id into sid
  from public.students st
  where st.id = p_resource_id and st.deleted_at is null;
  if sid is null or not private.is_linked_guardian(p_resource_id) then
    return decision;
  end if;
  return jsonb_build_object('allowed', true, 'school_id', sid, 'reason', 'linked_guardian');
end;
$function$;

-- ---------------------------------------------------------------------------
-- 2. A guardian's standing at a school: a live link to a child with a live
--    enrolment there, by the same test as is_linked_guardian.
-- ---------------------------------------------------------------------------
create or replace function private.is_linked_guardian_at_school(p_school uuid)
returns boolean language sql stable security definer set search_path = '' as $$
  select exists (
    select 1 from public.guardian_links gl
    where gl.school_id = p_school
      and gl.guardian_id = auth.uid()
      and private.is_linked_guardian(gl.student_id)
  );
$$;

-- ---------------------------------------------------------------------------
-- 3. The query: a member is served as before; a linked guardian with no
--    membership gets the guardian audience. Copied from 202609280002 with the
--    listAnnouncements branch extended.
-- ---------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION private.ops_query_communications(p_operation text, p_resource_id uuid, p_input jsonb)
 RETURNS jsonb
 LANGUAGE plpgsql
 STABLE SECURITY DEFINER
 SET search_path TO ''
AS $function$
declare tenant uuid; limit_rows int; pos uuid; result jsonb; next_pos text;
begin

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
      if tenant is null then return jsonb_build_object('outcome', 'forbidden'); end if;
      if private.has_active_membership(tenant) then
        select coalesce(jsonb_agg(private.api042_announcement_json(x.id) order by x.id), '[]'), max(x.id::text)
          into result, next_pos from (
          select a.id from public.announcements a where a.school_id = tenant and (pos is null or a.id > pos)
            and (a.classroom_id is null or private.can_view_classroom(a.classroom_id))
          order by a.id limit limit_rows
        ) x;
      elsif private.is_linked_guardian_at_school(tenant) then
        -- A parent linked by the child's ID: what is meant for guardians,
        -- school-wide or in a class one of their children is in.
        select coalesce(jsonb_agg(private.api042_announcement_json(x.id) order by x.id), '[]'), max(x.id::text)
          into result, next_pos from (
          select a.id from public.announcements a
          where a.school_id = tenant and (pos is null or a.id > pos)
            and a.audience in ('guardians', 'both')
            and (a.classroom_id is null or exists (
              select 1 from public.guardian_links gl
              where gl.school_id = tenant and gl.guardian_id = auth.uid()
                and private.is_linked_guardian(gl.student_id, a.classroom_id)))
          order by a.id limit limit_rows
        ) x;
      else
        return jsonb_build_object('outcome', 'forbidden');
      end if;
      return jsonb_build_object('items', result, 'nextPosition', case when jsonb_array_length(result) = limit_rows then next_pos end);
    else return jsonb_build_object('outcome', 'not_found');
  end case;
end;
$function$;

revoke all on function private.authz_guardian_list_reads(text, uuid, jsonb)
  from public, anon, authenticated, service_role, studafy_api_runtime,
  studafy_worker_runtime;
revoke all on function private.is_linked_guardian_at_school(uuid)
  from public, anon, authenticated, service_role, studafy_api_runtime,
  studafy_worker_runtime;
alter function private.is_linked_guardian_at_school(uuid) owner to postgres;
revoke all on function private.ops_query_communications(text, uuid, jsonb)
  from public, anon, authenticated, service_role, studafy_api_runtime,
  studafy_worker_runtime;
