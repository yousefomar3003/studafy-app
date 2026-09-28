-- Flattens private.api042_query (ADR-0030).
--
-- Thirteen nested layers, one per school-operations slice, become named
-- handlers (ops_query_messaging, ops_query_notifications, ...) and
-- api042_query dispatches each operation straight to its owner. Handler
-- bodies are the layers' own, less their "not mine, pass it down" guard.
--
-- listMessages and listConversations were answered by two layers; the newer
-- (ops_query_messaging) always answered first, and still does.

CREATE OR REPLACE FUNCTION private.ops_query_meeting_list(p_operation text, p_resource_id uuid, p_input jsonb)
 RETURNS jsonb
 LANGUAGE plpgsql
 STABLE SECURITY DEFINER
 SET search_path TO ''
AS $function$
declare
  v_class uuid;
  v_items jsonb;
begin

  if auth.uid() is null then return jsonb_build_object('outcome', 'forbidden'); end if;
  v_class := nullif(p_input->>'classroomId', '')::uuid;

  select coalesce(jsonb_agg(
      private.api042_meeting_json(m.id)
        || jsonb_build_object('classroomName', c.name)
      order by m.starts_at, m.id), '[]'::jsonb)
  into v_items
  from public.meetings m
  join public.classrooms c on c.id = m.classroom_id
  where (v_class is null or m.classroom_id = v_class)
    -- Still worth showing: upcoming, and a day of grace after the end so a
    -- meeting running late is not pulled from under the people in it.
    and m.ends_at >= now() - interval '1 day'
    and (
      -- Invited: the recipients were fixed when the meeting was created.
      exists (select 1 from public.meeting_deliveries md
        where md.meeting_id = m.id and md.recipient_id = auth.uid()
          and md.state in ('queued', 'sent', 'cancelled'))
      or m.created_by = auth.uid()
      or private.is_class_staff(m.classroom_id)
      or private.is_school_admin(m.school_id)
    );

  return jsonb_build_object('items', v_items, 'nextPosition', null);
exception when invalid_text_representation then
  return jsonb_build_object('outcome', 'not_found');
end;
$function$;
CREATE OR REPLACE FUNCTION private.ops_query_family_insights(p_operation text, p_resource_id uuid, p_input jsonb)
 RETURNS jsonb
 LANGUAGE plpgsql
 STABLE SECURITY DEFINER
 SET search_path TO ''
AS $function$
declare
  v_actor uuid := auth.uid();
  v_student uuid;
  v_from timestamptz;
  v_to timestamptz := now();
  v_period text;
  v_name text;
begin


  v_student := nullif(p_input->>'studentId', '')::uuid;
  if v_actor is null or v_student is null then
    return jsonb_build_object('outcome', 'forbidden');
  end if;

  -- The paywall is enforced here, not in the client. A guardian without a
  -- live entitlement is refused the data itself, so a modified app cannot
  -- read a child's record for free.
  if not private.parent_insights_has_access(v_student) then
    return jsonb_build_object('outcome', 'forbidden');
  end if;

  select s.display_name into v_name
  from public.students s where s.id = v_student and s.deleted_at is null;
  if v_name is null then
    return jsonb_build_object('outcome', 'not_found');
  end if;

  v_period := coalesce(p_input->>'period', 'term');
  v_from := case v_period
    when 'last30' then v_to - interval '30 days'
    when 'year' then v_to - interval '1 year'
    else v_to - interval '120 days'
  end;

  return jsonb_build_object(
    'outcome', 'ok',
    'studentId', v_student,
    'studentName', v_name,
    'period', v_period,
    'from', v_from,
    'to', v_to,
    -- Published marks only: an unpublished mark is a teacher's draft, and a
    -- parent seeing one before the school releases it would be a leak.
    'grades', coalesce((
      select jsonb_agg(jsonb_build_object(
        'subject', coalesce(nullif(a.category, ''), a.title),
        'score', g.score,
        'maximumScore', a.maximum_score,
        'at', g.published_at
      ) order by g.published_at)
      from public.grade_results g
      join public.assessments a on a.id = g.assessment_id
      where g.student_id = v_student
        and g.state = 'published' and g.published_at is not null
        and g.published_at between v_from and v_to
        and a.maximum_score > 0 and g.score is not null
    ), '[]'::jsonb),
    'attendance', coalesce((
      select jsonb_agg(jsonb_build_object(
        'state', r.state, 'at', ls.starts_at
      ) order by ls.starts_at)
      from public.attendance_records r
      join public.lesson_sessions ls on ls.id = r.session_id
      where r.student_id = v_student
        and ls.starts_at between v_from and v_to
    ), '[]'::jsonb),
    -- Work set to a class this child is enrolled in, with what they did
    -- about it. Published only, for the same reason as marks.
    'homework', coalesce((
      select jsonb_agg(jsonb_build_object(
        'assignmentId', a.id,
        'title', a.title,
        'dueAt', a.due_at,
        'submittedAt', sub.submitted_at
      ) order by a.due_at)
      from public.assignments a
      join public.enrollments e on e.classroom_id = a.classroom_id
        and e.student_id = v_student and e.active and e.status = 'active'
      left join public.submissions sub on sub.assignment_id = a.id
        and sub.student_id = v_student
      where a.state = 'published' and a.deleted_at is null
        and a.due_at between v_from and v_to + interval '30 days'
    ), '[]'::jsonb),
    -- Only what the school chose to share with guardians. A note restricted
    -- to safeguarding staff is never returned, at any subscription level.
    'wellbeing', coalesce((
      select jsonb_agg(jsonb_build_object(
        'id', w.id, 'kind', w.kind, 'title', w.title, 'createdAt', w.created_at
      ) order by w.created_at desc)
      from public.wellbeing_events w
      where w.student_id = v_student
        and w.visibility in ('guardian_shared', 'student_guardian_shared')
        and w.created_at between v_from and v_to
    ), '[]'::jsonb)
  );
end;
$function$;
CREATE OR REPLACE FUNCTION private.ops_query_student_family(p_operation text, p_resource_id uuid, p_input jsonb)
 RETURNS jsonb
 LANGUAGE plpgsql
 STABLE SECURITY DEFINER
 SET search_path TO ''
AS $function$
declare actor uuid := auth.uid(); ids jsonb; links jsonb;
begin

  if actor is null or not private.is_active_user() then return jsonb_build_object('outcome','forbidden'); end if;
  select coalesce(jsonb_agg(jsonb_build_object('id',s.id,'studafyId',s.studafy_id,'displayName',s.display_name) order by s.id),'[]') into ids
  from public.students s where s.user_id=actor and s.deleted_at is null;
  select coalesce(jsonb_agg(jsonb_build_object('id',g.id,'guardianId',g.guardian_id,'guardianName',p.display_name,'studentId',g.student_id,'relationship',g.relationship,'status',g.status) order by g.updated_at desc,g.id),'[]') into links
  from public.guardian_links g join public.students s on s.id=g.student_id
  join public.profiles p on p.id=g.guardian_id and p.status='active'
  where s.user_id=actor and s.deleted_at is null;
  return jsonb_build_object('studentIds',ids,'requests',links);
end;
$function$;
CREATE OR REPLACE FUNCTION private.ops_query_data_export_download(p_operation text, p_resource_id uuid, p_input jsonb)
 RETURNS jsonb
 LANGUAGE plpgsql
 STABLE SECURITY DEFINER
 SET search_path TO ''
AS $function$
declare
  result jsonb;
begin

  if auth.uid() is null or not private.is_active_user() then
    return jsonb_build_object('outcome', 'forbidden');
  end if;
  select p.payload into result
  from public.data_export_requests d
  join public.data_export_payloads p on p.request_id = d.id
  where d.user_id = auth.uid() and d.status = 'ready' and d.expires_at > now()
  order by d.ready_at desc limit 1;
  if result is null then return jsonb_build_object('outcome', 'not_found'); end if;
  return result;
end;
$function$;
CREATE OR REPLACE FUNCTION private.ops_query_my_guardian_links(p_operation text, p_resource_id uuid, p_input jsonb)
 RETURNS jsonb
 LANGUAGE plpgsql
 STABLE SECURITY DEFINER
 SET search_path TO ''
AS $function$
declare
  v_actor uuid := auth.uid();
  result jsonb;
begin

  if v_actor is null or not private.is_active_user() then
    return jsonb_build_object('outcome', 'forbidden');
  end if;
  select coalesce(jsonb_agg(jsonb_build_object(
      'id', gl.id,
      'schoolId', st.school_id,
      'schoolName', s.name,
      'studentId', st.id,
      'studentName', st.display_name,
      'relationship', gl.relationship,
      'status', gl.status,
      'expiresAt', gl.expires_at
    ) order by gl.updated_at desc, gl.id), '[]'::jsonb)
  into result
  from public.guardian_links gl
  join public.students st on st.id = gl.student_id and st.deleted_at is null
  join public.schools s on s.id = st.school_id
  where gl.guardian_id = v_actor;
  return jsonb_build_object('items', result);
end;
$function$;
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
$function$;
CREATE OR REPLACE FUNCTION private.ops_query_safety(p_operation text, p_resource_id uuid, p_input jsonb)
 RETURNS jsonb
 LANGUAGE plpgsql
 STABLE SECURITY DEFINER
 SET search_path TO ''
AS $function$
declare
  limit_rows int; result jsonb; next_pos text;
  pos_text text := nullif(p_input->>'position', '');
  pos uuid; target_school uuid;
begin

  if auth.uid() is null then return jsonb_build_object('outcome', 'forbidden'); end if;
  limit_rows := least(greatest(coalesce((p_input->>'pageSize')::int, 50), 1), 100);

  case p_operation
    when 'getContentControls' then
      if not (
        private.has_active_membership(p_resource_id)
        or private.is_school_admin(p_resource_id)
        or private.is_platform_operator()
      ) then return jsonb_build_object('outcome', 'forbidden'); end if;
      select private.safe043_content_controls_json(p_resource_id) into result;
      if result is null then return jsonb_build_object('outcome', 'not_found'); end if;
      return result;

    when 'listReports' then
      pos := nullif(pos_text, '')::uuid;
      select coalesce(jsonb_agg(
        private.safe043_reporter_report_json(x.id) order by x.id
      ), '[]'), max(x.id::text)
        into result, next_pos from (
        select r.id from public.reports r
        where r.reported_by = auth.uid()
          and (nullif(p_input->>'schoolId', '') is null
            or r.school_id = (p_input->>'schoolId')::uuid)
          and (pos is null or r.id > pos)
        order by r.id limit limit_rows
      ) x;
      return jsonb_build_object('items', result,
        'nextPosition', case when jsonb_array_length(result) = limit_rows then next_pos end);

    when 'getReport' then
      select private.safe043_reporter_report_json(p_resource_id) into result;
      if result is null then return jsonb_build_object('outcome', 'not_found'); end if;
      return result;

    when 'listBlocks' then
      pos := nullif(pos_text, '')::uuid;
      select coalesce(jsonb_agg(private.safe043_block_json(x.id) order by x.id), '[]'),
        max(x.id::text)
        into result, next_pos from (
        select b.id from public.user_blocks b
        where (b.blocker_id = auth.uid() or b.blocked_id = auth.uid())
          and (nullif(p_input->>'schoolId', '') is null
            or b.school_id = (p_input->>'schoolId')::uuid)
          and (pos is null or b.id > pos)
        order by b.id limit limit_rows
      ) x;
      return jsonb_build_object('items', result,
        'nextPosition', case when jsonb_array_length(result) = limit_rows then next_pos end);

    when 'getModerationOverview' then
      if not private.safe043_can_access_reports(p_resource_id) then
        return jsonb_build_object('outcome', 'forbidden');
      end if;
      perform private.lazily_expire_moderation_access(p_resource_id);
      select jsonb_build_object(
        'schoolId', p_resource_id,
        'submitted', count(*) filter (where r.status in ('submitted', 'queued')),
        'underReview', count(*) filter (where r.status = 'under_review'),
        'onHold', count(*) filter (where r.status = 'on_hold'),
        'escalated', count(*) filter (where r.status = 'escalated'),
        'resolved', count(*) filter (where r.status = 'resolved'),
        'slaBreaches', count(*) filter (
          where r.status in ('submitted', 'queued', 'under_review', 'on_hold', 'escalated')
            and r.created_at < now() - make_interval(
              hours => private.safe043_sla_hours(p_resource_id, r.priority)
            )
        ),
        'activeModeratorSessions', (
          select count(*) from public.moderation_access_grants g
          where g.school_id = p_resource_id and g.status = 'active' and g.expires_at > now()
        )
      ) into result
      from public.reports r where r.school_id = p_resource_id;
      return result;

    when 'listModerationQueue' then
      if not private.safe043_can_access_reports(p_resource_id) then
        return jsonb_build_object('outcome', 'forbidden');
      end if;
      perform private.lazily_expire_moderation_access(p_resource_id);
      select coalesce(jsonb_agg(
        private.safe043_moderation_report_json(
          x.id, x.status = 'escalated'
        ) order by
          case x.priority when 'critical' then 1 when 'high' then 2
            when 'medium' then 3 else 4 end,
          x.enqueue_seq
      ), '[]'), max(x.enqueue_seq::text)
        into result, next_pos from (
        select r.id, r.status, r.priority, r.enqueue_seq
        from public.reports r
        where r.school_id = p_resource_id
          and r.status not in ('resolved', 'withdrawn')
          and (nullif(p_input->>'status', '') is null or r.status::text = p_input->>'status')
          and (nullif(p_input->>'priority', '') is null or r.priority = p_input->>'priority')
          and (nullif(p_input->>'position', '') is null
            or r.enqueue_seq > (p_input->>'position')::bigint)
        order by r.enqueue_seq limit limit_rows
      ) x;
      return jsonb_build_object('items', result,
        'nextPosition', case when jsonb_array_length(result) = limit_rows then next_pos end);

    when 'getModerationReport' then
      select r.school_id into target_school from public.reports r where r.id = p_resource_id;
      if target_school is null then return jsonb_build_object('outcome', 'not_found'); end if;
      if not private.safe043_can_access_report(target_school, p_resource_id) then
        return jsonb_build_object('outcome', 'not_found');
      end if;
      select private.safe043_moderation_report_json(
        p_resource_id, exists (
          select 1 from public.reports r where r.id = p_resource_id and r.status = 'escalated'
        )
      ) into result;
      return result;

    when 'listModerationAccess' then
      if not (private.is_platform_operator() or private.is_school_admin(p_resource_id)) then
        return jsonb_build_object('outcome', 'forbidden');
      end if;
      perform private.lazily_expire_moderation_access(p_resource_id);
      pos := nullif(pos_text, '')::uuid;
      select coalesce(jsonb_agg(private.safe043_moderation_grant_json(x.id) order by x.id), '[]'),
        max(x.id::text)
        into result, next_pos from (
        select g.id from public.moderation_access_grants g
        where g.school_id = p_resource_id and (pos is null or g.id > pos)
        order by g.id limit limit_rows
      ) x;
      return jsonb_build_object('items', result,
        'nextPosition', case when jsonb_array_length(result) = limit_rows then next_pos end);

    else return jsonb_build_object('outcome', 'not_found');
  end case;
end;
$function$;
CREATE OR REPLACE FUNCTION private.ops_query_support_access(p_operation text, p_resource_id uuid, p_input jsonb)
 RETURNS jsonb
 LANGUAGE plpgsql
 STABLE SECURITY DEFINER
 SET search_path TO ''
AS $function$
declare limit_rows int; pos uuid; result jsonb; next_pos text;
begin

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
$function$;
CREATE OR REPLACE FUNCTION private.ops_query_account(p_operation text, p_resource_id uuid, p_input jsonb)
 RETURNS jsonb
 LANGUAGE plpgsql
 STABLE SECURITY DEFINER
 SET search_path TO ''
AS $function$
begin

  if auth.uid() is null then return jsonb_build_object('outcome', 'forbidden'); end if;
  return jsonb_build_object('request', (
    select private.api042_export_json(d.id) from public.data_export_requests d
    where d.user_id = auth.uid() order by d.requested_at desc limit 1
  ));
end;
$function$;
CREATE OR REPLACE FUNCTION private.ops_query_notifications(p_operation text, p_resource_id uuid, p_input jsonb)
 RETURNS jsonb
 LANGUAGE plpgsql
 STABLE SECURITY DEFINER
 SET search_path TO ''
AS $function$
declare limit_rows int; pos bigint; result jsonb; next_pos text;
begin

  if auth.uid() is null then return jsonb_build_object('outcome', 'forbidden'); end if;

  case p_operation
    when 'listNotifications' then
      limit_rows := least(greatest(coalesce((p_input->>'pageSize')::int, 50), 1), 100);
      pos := nullif(p_input->>'position', '')::bigint;
      select coalesce(jsonb_agg(private.api042_notification_json(x.id) order by x.id desc), '[]'), min(x.id::text)
        into result, next_pos from (
        select nd.id from public.notification_deliveries nd
        where nd.recipient_id = auth.uid() and nd.channel = 'in_app' and (pos is null or nd.id < pos)
        order by nd.id desc limit limit_rows
      ) x;
      return jsonb_build_object('items', result, 'nextPosition', case when jsonb_array_length(result) = limit_rows then next_pos end);

    when 'getUnreadCount' then
      return jsonb_build_object('unreadCount', (
        select count(*) from public.notification_deliveries nd
        where nd.recipient_id = auth.uid() and nd.channel = 'in_app' and nd.read_at is null
      ));

    when 'getNotificationPreferences' then
      select coalesce(jsonb_agg(jsonb_build_object(
        'schoolId', p.school_id, 'channel', p.channel, 'category', p.category, 'enabled', p.enabled
      ) order by p.school_id nulls first, p.channel, p.category), '[]')
      into result from public.notification_preferences p where p.user_id = auth.uid();
      return jsonb_build_object('items', result, 'nextPosition', null);
    else return jsonb_build_object('outcome', 'not_found');
  end case;
end;
$function$;
CREATE OR REPLACE FUNCTION private.ops_query_meeting_status(p_operation text, p_resource_id uuid, p_input jsonb)
 RETURNS jsonb
 LANGUAGE plpgsql
 STABLE SECURITY DEFINER
 SET search_path TO ''
AS $function$
begin

  if auth.uid() is null then return jsonb_build_object('outcome', 'forbidden'); end if;
  if not exists (select 1 from public.meetings where id = p_resource_id) then
    return jsonb_build_object('outcome', 'not_found');
  end if;
  if not (
    private.is_meeting_authorized(p_resource_id)
    or exists (
      select 1 from public.meeting_deliveries md
      where md.meeting_id = p_resource_id and md.recipient_id = auth.uid()
    )
  ) then
    return jsonb_build_object('outcome', 'forbidden');
  end if;
  return jsonb_build_object('meeting', private.api042_meeting_json(p_resource_id), 'deliveries', coalesce((
    select jsonb_agg(jsonb_build_object('recipientId', md.recipient_id, 'state', md.state, 'deliveredAt', md.delivered_at)
      order by md.recipient_id)
    from public.meeting_deliveries md where md.meeting_id = p_resource_id
  ), '[]'::jsonb));
end;
$function$;
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
$function$;
CREATE OR REPLACE FUNCTION private.ops_query_invitations(p_operation text, p_resource_id uuid, p_input jsonb)
 RETURNS jsonb
 LANGUAGE plpgsql
 STABLE SECURITY DEFINER
 SET search_path TO ''
AS $function$
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
$function$;

create or replace function private.api042_query(p_operation text, p_resource_id uuid, p_input jsonb)
returns jsonb
language plpgsql
stable security definer
set search_path = ''
as $$
begin
  -- Each operation has one owner; the first match is the newest code for it.
  case
    when p_operation = 'listMeetings' then
      return private.ops_query_meeting_list(p_operation, p_resource_id, p_input);
    when p_operation = 'getFamilyInsights' then
      return private.ops_query_family_insights(p_operation, p_resource_id, p_input);
    when p_operation = 'getStudentFamily' then
      return private.ops_query_student_family(p_operation, p_resource_id, p_input);
    when p_operation = 'downloadDataExport' then
      return private.ops_query_data_export_download(p_operation, p_resource_id, p_input);
    when p_operation = 'listMyGuardianLinks' then
      return private.ops_query_my_guardian_links(p_operation, p_resource_id, p_input);
    when p_operation in ('listMessages', 'listConversations', 'listContacts') then
      return private.ops_query_messaging(p_operation, p_resource_id, p_input);
    when p_operation in ('getContentControls', 'listReports', 'getReport', 
        'listBlocks', 'getModerationOverview', 'listModerationQueue', 
        'getModerationReport', 'listModerationAccess') then
      return private.ops_query_safety(p_operation, p_resource_id, p_input);
    when p_operation = 'listSupportAccessGrants' then
      return private.ops_query_support_access(p_operation, p_resource_id, p_input);
    when p_operation = 'getExportStatus' then
      return private.ops_query_account(p_operation, p_resource_id, p_input);
    when p_operation in ('listNotifications', 'getUnreadCount', 'getNotificationPreferences') then
      return private.ops_query_notifications(p_operation, p_resource_id, p_input);
    when p_operation = 'getMeetingStatus' then
      return private.ops_query_meeting_status(p_operation, p_resource_id, p_input);
    when p_operation = 'listAnnouncements' then
      return private.ops_query_communications(p_operation, p_resource_id, p_input);
    else
      return private.ops_query_invitations(p_operation, p_resource_id, p_input);
  end case;
end;
$$;

revoke all on function private.ops_query_meeting_list(text, uuid, jsonb)
  from public, anon, authenticated, service_role, studafy_api_runtime,
  studafy_worker_runtime;
revoke all on function private.ops_query_family_insights(text, uuid, jsonb)
  from public, anon, authenticated, service_role, studafy_api_runtime,
  studafy_worker_runtime;
revoke all on function private.ops_query_student_family(text, uuid, jsonb)
  from public, anon, authenticated, service_role, studafy_api_runtime,
  studafy_worker_runtime;
revoke all on function private.ops_query_data_export_download(text, uuid, jsonb)
  from public, anon, authenticated, service_role, studafy_api_runtime,
  studafy_worker_runtime;
revoke all on function private.ops_query_my_guardian_links(text, uuid, jsonb)
  from public, anon, authenticated, service_role, studafy_api_runtime,
  studafy_worker_runtime;
revoke all on function private.ops_query_messaging(text, uuid, jsonb)
  from public, anon, authenticated, service_role, studafy_api_runtime,
  studafy_worker_runtime;
revoke all on function private.ops_query_safety(text, uuid, jsonb)
  from public, anon, authenticated, service_role, studafy_api_runtime,
  studafy_worker_runtime;
revoke all on function private.ops_query_support_access(text, uuid, jsonb)
  from public, anon, authenticated, service_role, studafy_api_runtime,
  studafy_worker_runtime;
revoke all on function private.ops_query_account(text, uuid, jsonb)
  from public, anon, authenticated, service_role, studafy_api_runtime,
  studafy_worker_runtime;
revoke all on function private.ops_query_notifications(text, uuid, jsonb)
  from public, anon, authenticated, service_role, studafy_api_runtime,
  studafy_worker_runtime;
revoke all on function private.ops_query_meeting_status(text, uuid, jsonb)
  from public, anon, authenticated, service_role, studafy_api_runtime,
  studafy_worker_runtime;
revoke all on function private.ops_query_communications(text, uuid, jsonb)
  from public, anon, authenticated, service_role, studafy_api_runtime,
  studafy_worker_runtime;
revoke all on function private.ops_query_invitations(text, uuid, jsonb)
  from public, anon, authenticated, service_role, studafy_api_runtime,
  studafy_worker_runtime;

drop function private.api042_query_pre_meeting_list(text, uuid, jsonb);
drop function private.api042_query_pre_family_insights(text, uuid, jsonb);
drop function private.api042_query_pre_student_family(text, uuid, jsonb);
drop function private.api042_query_pre_export_download(text, uuid, jsonb);
drop function private.api042_query_pre_guardian_reads(text, uuid, jsonb);
drop function private.api042_query_pre_messaging(text, uuid, jsonb);
drop function private.api042_query_pre_safe043(text, uuid, jsonb);
drop function private.api042_query_pre_s8_support(text, uuid, jsonb);
drop function private.api042_query_pre_s7_account(text, uuid, jsonb);
drop function private.api042_query_pre_s6_notifications(text, uuid, jsonb);
drop function private.api042_query_pre_s5_meetings(text, uuid, jsonb);
drop function private.api042_query_pre_s4_comms(text, uuid, jsonb);
