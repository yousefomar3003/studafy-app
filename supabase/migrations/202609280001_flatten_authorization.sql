-- Flattens private.authz_authorize (ADR-0030).
--
-- Every permission added since API-041 wrapped the previous authorizer by
-- renaming it (authz_authorize_pre_*) and delegating to it, so a decision
-- for an original academic action walked twenty security-definer calls, and
-- which rule owned an action could only be recovered from migration history.
--
-- Each layer becomes a named handler with the same body minus its "not
-- mine, pass it down" guard, and authz_authorize dispatches to them in the
-- order the chain applied them. Decisions are unchanged: a differential run
-- over every fixture user, action and resource returned identical results
-- before and after this migration.
--
-- Two actions were claimed by two layers (file.download, classroom.create);
-- the newer always answered first, so the older handler never sees them.

CREATE OR REPLACE FUNCTION private.authz_notebook(p_action text, p_resource_id uuid)
 RETURNS jsonb
 LANGUAGE plpgsql
 STABLE SECURITY DEFINER
 SET search_path TO ''
AS $function$
declare
  sid uuid;
  allowed boolean := false;
begin
  if auth.uid() is null or p_resource_id is null then
    return jsonb_build_object('allowed', false, 'school_id', null, 'reason', 'invalid_resource');
  end if;
  if p_action in ('notebook.read', 'notebook.write') then
    select c.school_id, private.notebook_student(c.id) is not null
      into sid, allowed
    from public.classrooms c where c.id = p_resource_id;
  elsif p_action = 'notebook_entry.delete' then
    select n.school_id, n.owner_id = auth.uid() into sid, allowed
    from public.notebook_entries n
    where n.id = p_resource_id and n.deleted_at is null;
  else
    -- The plan is checked where the money is spent; this asks only whether
    -- the lesson is one the caller can see.
    select r.school_id, private.study_lesson(r.id) is not null into sid, allowed
    from public.resources r where r.id = p_resource_id;
  end if;
  return jsonb_build_object('allowed', coalesce(allowed, false), 'school_id', sid,
    'reason', case when sid is null then 'invalid_resource'
      when coalesce(allowed, false) then 'allowed' else 'denied' end);
end;
$function$;

CREATE OR REPLACE FUNCTION private.authz_conversation_read(p_action text, p_resource_id uuid)
 RETURNS jsonb
 LANGUAGE plpgsql
 STABLE SECURITY DEFINER
 SET search_path TO ''
AS $function$
declare
  sid uuid;
begin
  if auth.uid() is null or p_resource_id is null then
    return jsonb_build_object('allowed', false, 'school_id', null, 'reason', 'invalid_resource');
  end if;
  select c.school_id into sid from public.conversations c where c.id = p_resource_id;
  if sid is null or not private.is_conversation_participant(p_resource_id) then
    return jsonb_build_object('allowed', false, 'school_id', sid, 'reason',
      case when sid is null then 'invalid_resource' else 'denied' end);
  end if;
  return jsonb_build_object('allowed', true, 'school_id', sid, 'reason', 'participant');
end;
$function$;

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
      'grade_result.list', 'attendance_record.list', 'upload.intent.create')
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

CREATE OR REPLACE FUNCTION private.authz_submission_history(p_action text, p_resource_id uuid)
 RETURNS jsonb
 LANGUAGE plpgsql
 STABLE SECURITY DEFINER
 SET search_path TO ''
AS $function$
declare
  sid uuid;
  cls uuid;
  allowed boolean := false;
begin
  if auth.uid() is null or p_resource_id is null then
    return jsonb_build_object('allowed', false, 'school_id', null, 'reason', 'invalid_resource');
  end if;
  select a.school_id, a.classroom_id into sid, cls
  from public.assignments a
  where a.id = p_resource_id and a.deleted_at is null;
  if cls is null then
    return jsonb_build_object('allowed', false, 'school_id', null, 'reason', 'invalid_resource');
  end if;

  allowed := private.is_school_admin(sid) or private.is_class_staff(cls)
    or exists (
      select 1 from public.students s
      where s.school_id = sid and s.deleted_at is null
        and (s.user_id = auth.uid() or private.is_linked_guardian(s.id, cls))
        and (
          exists (select 1 from public.enrollments e
            where e.student_id = s.id and e.classroom_id = cls
              and e.active and e.status = 'active')
          or exists (select 1 from public.submissions su
            where su.assignment_id = p_resource_id and su.student_id = s.id)
        )
    );
  return jsonb_build_object('allowed', coalesce(allowed, false), 'school_id', sid,
    'reason', case when allowed then 'allowed' else 'denied' end);
end;
$function$;

CREATE OR REPLACE FUNCTION private.authz_guardian_submits(p_action text, p_resource_id uuid, p_decision jsonb)
 RETURNS jsonb
 LANGUAGE plpgsql
 STABLE SECURITY DEFINER
 SET search_path TO ''
AS $function$
declare
  decision jsonb;
  sid uuid;
  cls uuid;
  allowed boolean := false;
begin
  decision := p_decision;
  if p_action <> 'assignment.submit'
    or coalesce((decision->>'allowed')::boolean, false) then
    return decision;
  end if;
  if auth.uid() is null or p_resource_id is null then return decision; end if;

  select a.school_id, a.classroom_id into sid, cls
  from public.assignments a
  where a.id = p_resource_id and a.state = 'published' and a.deleted_at is null;
  if cls is null then return decision; end if;

  select exists (
    select 1 from public.enrollments e
    where e.classroom_id = cls and e.active and e.status = 'active'
      and private.is_linked_guardian(e.student_id, cls)
  ) into allowed;
  if not allowed then return decision; end if;

  return jsonb_build_object(
    'allowed', true, 'school_id', sid, 'reason', 'linked_guardian');
end;
$function$;

CREATE OR REPLACE FUNCTION private.authz_lesson_session_close(p_action text, p_resource_id uuid)
 RETURNS jsonb
 LANGUAGE plpgsql
 STABLE SECURITY DEFINER
 SET search_path TO ''
AS $function$
declare sid uuid; allowed boolean := false; cls uuid;
begin
  if auth.uid() is null or p_resource_id is null then
    return jsonb_build_object('allowed', false, 'school_id', null, 'reason', 'invalid_resource');
  end if;
  -- Closing a section is a teaching act, bound to the classroom's own staff.
  select ls.school_id, ls.classroom_id into sid, cls
  from public.lesson_sessions ls where ls.id = p_resource_id;
  if cls is null then
    return jsonb_build_object('allowed', false, 'school_id', null, 'reason', 'invalid_resource');
  end if;
  allowed := private.is_class_staff(cls);
  return jsonb_build_object('allowed', coalesce(allowed, false), 'school_id', sid,
    'reason', case when allowed then 'allowed' else 'denied' end);
end;
$function$;

CREATE OR REPLACE FUNCTION private.authz_class_join_links(p_action text, p_resource_id uuid)
 RETURNS jsonb
 LANGUAGE plpgsql
 STABLE SECURITY DEFINER
 SET search_path TO ''
AS $function$
declare sid uuid; allowed boolean := false;
begin
  if auth.uid() is null or p_resource_id is null then
    return jsonb_build_object('allowed', false, 'school_id', null, 'reason', 'invalid_resource');
  end if;
  declare cls uuid;
  begin
    if p_action = 'classJoinLink.revoke' then
      select l.school_id, l.classroom_id into sid, cls
      from public.class_join_links l where l.id = p_resource_id;
    else
      select c.school_id, c.id into sid, cls
      from public.classrooms c where c.id = p_resource_id;
    end if;
    if cls is null then
      return jsonb_build_object('allowed', false, 'school_id', null, 'reason', 'invalid_resource');
    end if;
    allowed := private.is_class_staff(cls);
    return jsonb_build_object('allowed', coalesce(allowed, false), 'school_id', sid,
      'reason', case when allowed then 'allowed' else 'denied' end);
  end;
end;
$function$;

CREATE OR REPLACE FUNCTION private.authz_classroom_create(p_action text, p_resource_id uuid)
 RETURNS jsonb
 LANGUAGE plpgsql
 STABLE SECURITY DEFINER
 SET search_path TO ''
AS $function$
declare sid uuid; allowed boolean := false;
begin
  -- Carries forward the classroom.create decision granted in
  -- 202609200001. Preserving the previous generation means preserving what
  -- it decided, not the generation before it.
  if auth.uid() is null or p_resource_id is null then
    return jsonb_build_object('allowed', false, 'school_id', null, 'reason', 'invalid_resource');
  end if;
  select s.id,
    private.has_active_membership(
      s.id, array['teacher','school_admin']::public.app_role[])
  into sid, allowed
  from public.schools s where s.id = p_resource_id;
  return jsonb_build_object('allowed', coalesce(allowed, false), 'school_id', sid,
    'reason', case when sid is null then 'invalid_resource' when allowed then 'allowed' else 'denied' end);
end;
$function$;

CREATE OR REPLACE FUNCTION private.authz_file_publication(p_action text, p_resource_id uuid)
 RETURNS jsonb
 LANGUAGE plpgsql
 STABLE SECURITY DEFINER
 SET search_path TO ''
AS $function$
declare sid uuid; allowed boolean := false;
begin
  if auth.uid() is null or p_resource_id is null then
    return jsonb_build_object('allowed', false, 'school_id', null, 'reason', 'invalid_resource');
  end if;
  if p_action = 'file.publish' then
    select f.school_id,
      (f.owner_id = auth.uid() or private.is_school_admin(f.school_id))
    into sid, allowed
    from public.file_objects f where f.id = p_resource_id;
  else
    select f.school_id into sid from public.file_objects f where f.id = p_resource_id;
    allowed := coalesce(
      (private.file051_authorize_download(p_resource_id) ->> 'allowed')::boolean, false);
  end if;
  return jsonb_build_object('allowed', coalesce(allowed, false), 'school_id', sid,
    'reason', case when sid is null then 'invalid_resource' when allowed then 'allowed' else 'denied' end);
end;
$function$;

CREATE OR REPLACE FUNCTION private.authz_file_delivery(p_action text, p_resource_id uuid)
 RETURNS jsonb
 LANGUAGE plpgsql
 STABLE SECURITY DEFINER
 SET search_path TO ''
AS $function$
declare sid uuid; allowed boolean:=false;
begin
  if auth.uid() is null or p_resource_id is null then
    return jsonb_build_object('allowed',false,'school_id',null,'reason','invalid_resource');
  end if;
  if p_action='upload.intent.create' then
    select s.id,private.has_active_membership(s.id) into sid,allowed from public.schools s where s.id=p_resource_id;
  elsif p_action in ('upload.read','upload.complete') then
    select u.school_id,u.owner_id=auth.uid() into sid,allowed from public.upload_sessions u where u.id=p_resource_id;
  else
    select f.school_id,f.owner_id=auth.uid() into sid,allowed from public.file_objects f where f.id=p_resource_id;
  end if;
  return jsonb_build_object('allowed',coalesce(allowed,false),'school_id',sid,
    'reason',case when sid is null then 'invalid_resource' when allowed then 'allowed' else 'denied' end);
end;
$function$;

CREATE OR REPLACE FUNCTION private.authz_safety(p_action text, p_resource_id uuid)
 RETURNS jsonb
 LANGUAGE plpgsql
 STABLE SECURITY DEFINER
 SET search_path TO ''
AS $function$
declare target_school uuid; permitted boolean := false;
begin
  if auth.uid() is null or p_resource_id is null then
    return jsonb_build_object('allowed', false, 'school_id', null, 'reason', 'invalid_resource');
  end if;

  case
    when p_action = 'content_controls.read' then
      select s.id,
        (private.has_active_membership(s.id) or private.is_school_admin(s.id)
          or private.is_platform_operator())
      into target_school, permitted from public.schools s where s.id = p_resource_id;

    when p_action = 'content_controls.write' then
      select s.id, private.is_school_admin(s.id)
      into target_school, permitted from public.schools s where s.id = p_resource_id;

    when p_action in ('moderation.overview.read', 'moderation.queue.read') then
      select s.id, private.safe043_can_access_reports(s.id)
      into target_school, permitted from public.schools s where s.id = p_resource_id;

    when p_action in (
      'moderation.report.read', 'moderation.triage', 'moderation.resolve',
      'moderation.escalate', 'moderation.evidence.write'
    ) then
      select r.school_id, private.safe043_can_access_report(r.school_id, r.id)
      into target_school, permitted from public.reports r where r.id = p_resource_id;

    -- The same action authorizes both ends of a hold: the report id when
    -- applying, and the legal-hold id when releasing. A school admin may
    -- release a user-scoped hold of their own school (spec), anything else
    -- needs a platform operator.
    when p_action = 'moderation.hold' then
      select h.school_id,
        (private.is_platform_operator()
           or (h.applied_to = 'account' and private.is_school_admin(h.school_id)))
      into target_school, permitted from public.legal_holds h where h.id = p_resource_id;
      if target_school is null then
        select r.school_id, private.safe043_can_access_report(r.school_id, r.id)
        into target_school, permitted from public.reports r where r.id = p_resource_id;
      end if;

    when p_action = 'moderation.access.approve' then
      select g.school_id, private.safe043_is_second_approver(g.id)
      into target_school, permitted from public.moderation_access_grants g where g.id = p_resource_id;

    when p_action = 'moderation.access.start' then
      select g.school_id, (g.requested_by = auth.uid())
      into target_school, permitted from public.moderation_access_grants g where g.id = p_resource_id;

    when p_action = 'moderation.access.revoke' then
      select g.school_id,
        (private.is_platform_operator() or private.is_school_admin(g.school_id))
      into target_school, permitted from public.moderation_access_grants g where g.id = p_resource_id;

    when p_action = 'moderation.access.list' then
      select s.id, (private.is_platform_operator() or private.is_school_admin(s.id))
      into target_school, permitted from public.schools s where s.id = p_resource_id;
  end case;

  return jsonb_build_object('allowed', coalesce(permitted, false), 'school_id', target_school,
    'reason', case when target_school is null then 'invalid_resource' when permitted then 'allowed' else 'denied' end);
end;
$function$;

CREATE OR REPLACE FUNCTION private.authz_roster_create(p_action text, p_resource_id uuid)
 RETURNS jsonb
 LANGUAGE plpgsql
 STABLE SECURITY DEFINER
 SET search_path TO ''
AS $function$
declare target_school uuid; permitted boolean := false;
begin
  if auth.uid() is null or p_resource_id is null then
    return jsonb_build_object('allowed', false, 'school_id', null, 'reason', 'invalid_resource');
  end if;

  select s.id, private.is_school_admin(s.id)
  into target_school, permitted from public.schools s where s.id = p_resource_id;
  return jsonb_build_object('allowed', coalesce(permitted, false), 'school_id', target_school,
    'reason', case when target_school is null then 'invalid_resource' when permitted then 'allowed' else 'denied' end);
end;
$function$;

CREATE OR REPLACE FUNCTION private.authz_support_access(p_action text, p_resource_id uuid)
 RETURNS jsonb
 LANGUAGE plpgsql
 STABLE SECURITY DEFINER
 SET search_path TO ''
AS $function$
declare target_school uuid; permitted boolean := false;
begin
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
$function$;

CREATE OR REPLACE FUNCTION private.authz_meetings(p_action text, p_resource_id uuid)
 RETURNS jsonb
 LANGUAGE plpgsql
 STABLE SECURITY DEFINER
 SET search_path TO ''
AS $function$
declare target_school uuid; permitted boolean := false;
begin
  if auth.uid() is null or p_resource_id is null then
    return jsonb_build_object('allowed', false, 'school_id', null, 'reason', 'invalid_resource');
  end if;

  case
    when p_action = 'meeting.request' then
      select c.school_id, private.api041_class_writer(c.id)
      into target_school, permitted from public.classrooms c where c.id = p_resource_id;
    when p_action = 'meeting.cancel' then
      select m.school_id, private.is_meeting_authorized(m.id)
      into target_school, permitted from public.meetings m where m.id = p_resource_id;
    when p_action = 'meeting.status' then
      select m.school_id, (private.is_meeting_authorized(m.id) or exists (
        select 1 from public.meeting_deliveries md where md.meeting_id = m.id and md.recipient_id = auth.uid()
      )) into target_school, permitted from public.meetings m where m.id = p_resource_id;
  end case;
  return jsonb_build_object('allowed', coalesce(permitted, false), 'school_id', target_school,
    'reason', case when target_school is null then 'invalid_resource' when permitted then 'allowed' else 'denied' end);
end;
$function$;

CREATE OR REPLACE FUNCTION private.authz_communications(p_action text, p_resource_id uuid)
 RETURNS jsonb
 LANGUAGE plpgsql
 STABLE SECURITY DEFINER
 SET search_path TO ''
AS $function$
declare target_school uuid; permitted boolean := false;
begin
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
$function$;

CREATE OR REPLACE FUNCTION private.authz_guardian_links(p_action text, p_resource_id uuid)
 RETURNS jsonb
 LANGUAGE plpgsql
 STABLE SECURITY DEFINER
 SET search_path TO ''
AS $function$
declare target_school uuid; permitted boolean := false;
begin
  if auth.uid() is null or p_resource_id is null then
    return jsonb_build_object('allowed', false, 'school_id', null, 'reason', 'invalid_resource');
  end if;

  case
    when p_action = 'guardian_link.verify' then
      select gl.school_id, private.is_school_admin(gl.school_id)
      into target_school, permitted from public.guardian_links gl where gl.id = p_resource_id;
    when p_action = 'guardian_link.revoke' then
      select gl.school_id, (private.is_school_admin(gl.school_id) or gl.guardian_id = auth.uid())
      into target_school, permitted from public.guardian_links gl where gl.id = p_resource_id;
  end case;
  return jsonb_build_object('allowed', coalesce(permitted, false), 'school_id', target_school,
    'reason', case when target_school is null then 'invalid_resource' when permitted then 'allowed' else 'denied' end);
end;
$function$;

CREATE OR REPLACE FUNCTION private.authz_invitations(p_action text, p_resource_id uuid)
 RETURNS jsonb
 LANGUAGE plpgsql
 STABLE SECURITY DEFINER
 SET search_path TO ''
AS $function$
declare target_school uuid; permitted boolean := false;
begin
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
$function$;

CREATE OR REPLACE FUNCTION private.authz_school_admin(p_action text, p_resource_id uuid)
 RETURNS jsonb
 LANGUAGE plpgsql
 STABLE SECURITY DEFINER
 SET search_path TO ''
AS $function$
declare target_school uuid; permitted boolean := false;
begin
  if auth.uid() is null or p_resource_id is null then
    return jsonb_build_object('allowed', false, 'school_id', null, 'reason', 'invalid_resource');
  end if;

  case
    when p_action in ('school.suspend', 'school.close') then
      select s.id, (private.is_platform_operator() or private.is_school_admin(s.id))
      into target_school, permitted from public.schools s where s.id = p_resource_id;
    when p_action = 'membership.grant' then
      select s.id, private.is_school_admin(s.id)
      into target_school, permitted from public.schools s where s.id = p_resource_id;
    when p_action in ('membership.activate', 'membership.suspend', 'membership.revoke') then
      select m.school_id, private.is_school_admin(m.school_id)
      into target_school, permitted from public.memberships m where m.id = p_resource_id;
    when p_action = 'classroom_staff.write' then
      select c.school_id, (private.is_school_admin(c.school_id) or private.is_class_lead(c.id))
      into target_school, permitted from public.classrooms c where c.id = p_resource_id;
    when p_action = 'enrollment.write' then
      select c.school_id, (private.is_school_admin(c.school_id) or private.api041_class_writer(c.id))
      into target_school, permitted from public.classrooms c where c.id = p_resource_id;
  end case;
  return jsonb_build_object('allowed', coalesce(permitted, false), 'school_id', target_school,
    'reason', case when target_school is null then 'invalid_resource' when permitted then 'allowed' else 'denied' end);
end;
$function$;

CREATE OR REPLACE FUNCTION private.authz_school_operations(p_action text, p_resource_id uuid)
 RETURNS jsonb
 LANGUAGE plpgsql
 STABLE SECURITY DEFINER
 SET search_path TO ''
AS $function$
declare target_school uuid; permitted boolean := false; target_class uuid;
begin
  if auth.uid() is null or p_resource_id is null then
    return jsonb_build_object('allowed',false,'school_id',null,'reason','invalid_resource');
  end if;

  case
    when p_action='term.list' then
      select s.id, private.has_active_membership(s.id) into target_school,permitted
      from public.schools s where s.id=p_resource_id;
    when p_action in ('classroom.list','lesson_session.list','resource.list','assignment.list','assessment.list','grade_result.list','attendance_record.list','wellbeing_event.list') then
      select s.id, private.has_active_membership(s.id) into target_school,permitted
      from public.schools s where s.id=p_resource_id;
      if target_school is null then
        select c.school_id, private.can_view_classroom(c.id) into target_school,permitted
        from public.classrooms c where c.id=p_resource_id;
      end if;
      if target_school is null then
        select st.school_id, private.can_access_student(st.id) into target_school,permitted
        from public.students st where st.id=p_resource_id;
      end if;
    when p_action='classroom.create' then
      select s.id, private.is_school_admin(s.id)
      into target_school,permitted from public.schools s where s.id=p_resource_id;
    when p_action in ('classroom.update','classroom.schedule.write') then
      select c.school_id, private.api041_class_writer(c.id) into target_school,permitted
      from public.classrooms c where c.id=p_resource_id;
    when p_action='classroom.roster.read' then
      select c.school_id, (private.is_school_admin(c.school_id) or private.is_class_staff(c.id))
      into target_school,permitted from public.classrooms c where c.id=p_resource_id;
    when p_action in ('classroom.staff.read','attendance_roster.read') then
      select c.school_id, (private.is_school_admin(c.school_id) or private.is_class_staff(c.id))
      into target_school,permitted from public.classrooms c where c.id=p_resource_id;
    when p_action in ('assignment.create','assessment.create','attendance_record.write','wellbeing_event.create') then
      select c.school_id, private.api041_class_writer(c.id) into target_school,permitted
      from public.classrooms c where c.id=p_resource_id;
    when p_action in ('assignment.publish','assignment.withdraw','submission.list') then
      select a.school_id, private.api041_class_writer(a.classroom_id) into target_school,permitted
      from public.assignments a where a.id=p_resource_id;
    when p_action='assignment.submit' then
      select a.school_id, a.state='published' and a.deleted_at is null and exists (
        select 1 from public.enrollments e join public.students st on st.id=e.student_id
        where e.classroom_id=a.classroom_id and e.status='active' and e.active and st.user_id=auth.uid()
      ) into target_school,permitted from public.assignments a where a.id=p_resource_id;
    when p_action='assignment.read' then
      select a.school_id, (private.is_school_admin(a.school_id) or private.is_class_staff(a.classroom_id) or
        (a.state='published' and a.deleted_at is null and private.can_view_classroom(a.classroom_id)))
      into target_school,permitted from public.assignments a where a.id=p_resource_id;
    when p_action in ('assessment.publish','assessment.withdraw') then
      select a.school_id, private.api041_class_writer(a.classroom_id) into target_school,permitted
      from public.assessments a where a.id=p_resource_id;
    when p_action='assessment.submit' then
      select a.school_id, a.state='published' and a.delivery in ('online','practice') and exists (
        select 1 from public.enrollments e join public.students st on st.id=e.student_id
        where e.classroom_id=a.classroom_id and e.status='active' and e.active and st.user_id=auth.uid()
      ) into target_school,permitted from public.assessments a where a.id=p_resource_id;
    when p_action='assessment_question.list' then
      select a.school_id, (private.is_class_staff(a.classroom_id) or
        (a.state='published' and private.can_view_classroom(a.classroom_id)))
      into target_school,permitted from public.assessments a where a.id=p_resource_id;
    when p_action='assessment_question.authoring.list' then
      select a.school_id, private.api041_class_writer(a.classroom_id)
      into target_school,permitted from public.assessments a where a.id=p_resource_id;
    when p_action='assessment_attempt.list' then
      select a.school_id, private.api041_class_writer(a.classroom_id)
      into target_school,permitted from public.assessments a where a.id=p_resource_id;
    when p_action in ('grade_result.review','grade_result.publish','grade_result.correct','grade_result.withdraw') then
      select g.school_id, private.api041_class_writer(a.classroom_id) into target_school,permitted
      from public.grade_results g join public.assessments a on a.id=g.assessment_id where g.id=p_resource_id;
    when p_action in ('resource.revise','resource.publish','resource.withdraw') then
      select r.school_id, (private.is_school_admin(r.school_id) or r.created_by=auth.uid() or exists (
        select 1 from public.resource_publications rp where rp.resource_version_id in (
          select rv.id from public.resource_versions rv where rv.resource_id=r.id
        ) and rp.classroom_id is not null and private.api041_class_writer(rp.classroom_id)
      )) into target_school,permitted from public.resources r where r.id=p_resource_id;
    when p_action='resource.create' then
      select s.id, private.is_school_admin(s.id)
      into target_school,permitted from public.schools s where s.id=p_resource_id;
      if target_school is null then
        select c.school_id, private.api041_class_writer(c.id) into target_school,permitted
        from public.classrooms c where c.id=p_resource_id;
      end if;
  end case;
  return jsonb_build_object('allowed',coalesce(permitted,false),'school_id',target_school,
    'reason',case when target_school is null then 'invalid_resource' when permitted then 'allowed' else 'denied' end);
end;
$function$;

CREATE OR REPLACE FUNCTION private.authz_academic(p_action text, p_resource_id uuid)
 RETURNS jsonb
 LANGUAGE plpgsql
 STABLE SECURITY DEFINER
 SET search_path TO ''
AS $function$
declare
  target_school uuid;
  permitted boolean := false;
  known_action boolean := true;
begin
  if auth.uid() is null or p_action is null or p_resource_id is null then
    return jsonb_build_object(
      'allowed', false, 'school_id', null, 'reason', 'invalid_resource'
    );
  end if;

  case p_action
    when 'school.read' then
      select s.id, private.has_active_membership(s.id)
      into target_school, permitted
      from public.schools s where s.id = p_resource_id;

    when 'term.read' then
      select t.school_id, (
        private.is_school_admin(t.school_id)
        or private.has_active_membership(
          t.school_id, array['teacher']::public.app_role[]
        )
        or (
          t.status = 'active'
          and private.has_active_membership(
            t.school_id,
            array['student', 'parent', 'guardian']::public.app_role[]
          )
        )
      ) into target_school, permitted
      from public.terms t where t.id = p_resource_id;

    when 'student.read' then
      select st.school_id, private.can_access_student(st.id)
      into target_school, permitted
      from public.students st where st.id = p_resource_id;

    when 'guardian_link.read' then
      select gl.school_id, (
        private.is_school_admin(gl.school_id)
        or (
          gl.guardian_id = auth.uid()
          and private.has_active_membership(
            gl.school_id, array['parent', 'guardian']::public.app_role[]
          )
        )
        or exists (
          select 1 from public.students st
          where st.id = gl.student_id
            and st.user_id = auth.uid()
            and private.has_active_membership(
              gl.school_id, array['student']::public.app_role[]
            )
        )
        or exists (
          select 1 from public.enrollments e
          where e.student_id = gl.student_id
            and e.school_id = gl.school_id
            and private.is_class_staff(e.classroom_id)
        )
      ) into target_school, permitted
      from public.guardian_links gl where gl.id = p_resource_id;

    when 'classroom.read' then
      select c.school_id, private.can_view_classroom(c.id)
      into target_school, permitted
      from public.classrooms c where c.id = p_resource_id;

    when 'classroom_staff.read' then
      select cs.school_id, (
        private.is_school_admin(cs.school_id)
        or private.is_class_staff(cs.classroom_id)
      ) into target_school, permitted
      from public.classroom_staff cs where cs.id = p_resource_id;

    when 'class_schedule.read' then
      select cs.school_id, private.can_view_classroom(cs.classroom_id)
      into target_school, permitted
      from public.class_schedules cs where cs.id = p_resource_id;

    when 'lesson_session.read' then
      select ls.school_id, (
        private.is_school_admin(ls.school_id)
        or private.is_class_staff(ls.classroom_id)
        or (
          ls.status = 'completed'
          and ls.filed_at is not null
          and private.can_view_classroom(ls.classroom_id)
        )
      ) into target_school, permitted
      from public.lesson_sessions ls where ls.id = p_resource_id;

    when 'lesson_material.read' then
      select lm.school_id, (
        lm.deleted_at is null
        and exists (
          select 1 from public.lesson_sessions ls
          where ls.id = lm.session_id
            and ls.school_id = lm.school_id
            and (
              private.is_school_admin(ls.school_id)
              or private.is_class_staff(ls.classroom_id)
              or (
                ls.status = 'completed'
                and ls.filed_at is not null
                and private.can_view_classroom(ls.classroom_id)
              )
            )
        )
      ) into target_school, permitted
      from public.lesson_materials lm where lm.id = p_resource_id;

    when 'assignment.read' then
      select a.school_id, (
        private.is_school_admin(a.school_id)
        or private.is_class_staff(a.classroom_id)
        or (
          a.state = 'published'
          and a.published_at is not null
          and a.deleted_at is null
          and private.can_view_classroom(a.classroom_id)
        )
      ) into target_school, permitted
      from public.assignments a where a.id = p_resource_id;

    when 'submission.read' then
      select su.school_id, (
        private.has_active_membership(su.school_id)
        and exists (
          select 1 from public.assignments a
          where a.id = su.assignment_id
            and a.school_id = su.school_id
            and private.can_view_class_student(a.classroom_id, su.student_id)
            and (
              private.is_school_admin(a.school_id)
              or private.is_class_staff(a.classroom_id)
              or (a.state = 'published' and a.deleted_at is null)
            )
        )
      ) into target_school, permitted
      from public.submissions su where su.id = p_resource_id;

    when 'assessment.read' then
      select a.school_id, (
        private.is_school_admin(a.school_id)
        or private.is_class_staff(a.classroom_id)
        or (
          a.state = 'published'
          and a.published_at is not null
          and a.deleted_at is null
          and private.can_view_classroom(a.classroom_id)
        )
      ) into target_school, permitted
      from public.assessments a where a.id = p_resource_id;

    when 'assessment_question.read' then
      select aq.school_id, exists (
        select 1 from public.assessments a
        where a.id = aq.assessment_id
          and a.school_id = aq.school_id
          and (
            private.is_school_admin(a.school_id)
            or private.is_class_staff(a.classroom_id)
            or (
              a.delivery = 'practice'
              and a.state = 'published'
              and a.published_at is not null
              and a.deleted_at is null
              and private.can_view_classroom(a.classroom_id)
            )
          )
      ) into target_school, permitted
      from public.assessment_questions aq where aq.id = p_resource_id;

    when 'grade_result.read' then
      select gr.school_id, (
        private.has_active_membership(gr.school_id)
        and exists (
          select 1 from public.assessments a
          where a.id = gr.assessment_id
            and a.school_id = gr.school_id
            and private.can_view_class_student(a.classroom_id, gr.student_id)
            and (
              private.is_school_admin(a.school_id)
              or private.is_class_staff(a.classroom_id)
              or (gr.state = 'published' and gr.published_at is not null)
            )
        )
      ) into target_school, permitted
      from public.grade_results gr where gr.id = p_resource_id;

    when 'attendance_record.read' then
      select ar.school_id, (
        private.has_active_membership(ar.school_id)
        and exists (
          select 1 from public.lesson_sessions ls
          where ls.id = ar.session_id
            and ls.school_id = ar.school_id
            and private.can_view_class_student(
              ls.classroom_id, ar.student_id
            )
        )
      ) into target_school, permitted
      from public.attendance_records ar where ar.id = p_resource_id;

    when 'wellbeing_event.read' then
      select w.school_id, private.can_view_wellbeing(w.id)
      into target_school, permitted
      from public.wellbeing_events w where w.id = p_resource_id;

    when 'announcement.read' then
      select an.school_id, (
        an.state = 'published'
        and an.deleted_at is null
        and an.published_at is not null
        and (
          (an.created_by = auth.uid() and private.has_active_membership(an.school_id))
          or private.is_school_admin(an.school_id)
          or (
            private.has_active_membership(
              an.school_id, array['teacher']::public.app_role[]
            )
            and (
              an.classroom_id is null
              or private.is_class_staff(an.classroom_id)
            )
          )
          or (
            an.audience in ('students', 'both')
            and (
              (
                an.classroom_id is null
                and private.has_active_membership(
                  an.school_id, array['student']::public.app_role[]
                )
              )
              or exists (
                select 1 from public.enrollments e
                where e.classroom_id = an.classroom_id
                  and private.is_enrolled_student(
                    e.classroom_id, e.student_id
                  )
              )
            )
          )
          or (
            an.audience in ('guardians', 'both')
            and (
              (
                an.classroom_id is null
                and private.has_active_membership(
                  an.school_id,
                  array['parent', 'guardian']::public.app_role[]
                )
              )
              or exists (
                select 1 from public.enrollments e
                where e.classroom_id = an.classroom_id
                  and private.is_verified_guardian(
                    e.classroom_id, e.student_id
                  )
              )
            )
          )
        )
      ) into target_school, permitted
      from public.announcements an where an.id = p_resource_id;

    when 'meeting.read' then
      select m.school_id, (
        (m.created_by = auth.uid() and private.has_active_membership(m.school_id))
        or private.is_school_admin(m.school_id)
        or private.is_class_staff(m.classroom_id)
        or (
          m.state = 'scheduled'
          and m.audience in ('students', 'both')
          and exists (
            select 1 from public.enrollments e
            where e.classroom_id = m.classroom_id
              and private.is_enrolled_student(e.classroom_id, e.student_id)
          )
        )
        or (
          m.state = 'scheduled'
          and m.audience in ('guardians', 'both')
          and exists (
            select 1 from public.enrollments e
            where e.classroom_id = m.classroom_id
              and private.is_verified_guardian(e.classroom_id, e.student_id)
          )
        )
      ) into target_school, permitted
      from public.meetings m where m.id = p_resource_id;

    when 'notification.read' then
      select n.school_id, (
        n.user_id = auth.uid() and private.is_active_user()
      ) into target_school, permitted
      from public.notifications n where n.id = p_resource_id;

    when 'subscription_entitlement.read' then
      select null::uuid, (
        se.user_id = auth.uid() and private.is_active_user()
      ) into target_school, permitted
      from public.subscription_entitlements se
      where se.user_id = p_resource_id;

    when 'consent_record.read' then
      -- consent_records has a bigint row id. The UUID resource for this
      -- permission is therefore the owning profile/collection, while RLS
      -- continues to filter every individual consent row by user_id.
      select null::uuid, (
        p_resource_id = auth.uid() and private.is_active_user()
      ) into target_school, permitted;

    when 'practice_session.read' then
      select ps.school_id, (
        private.is_school_admin(ps.school_id)
        or private.is_class_staff(ps.classroom_id)
        or private.is_enrolled_student(ps.classroom_id, ps.student_id)
      ) into target_school, permitted
      from public.practice_sessions ps where ps.id = p_resource_id;

    when 'resource.read' then
      select r.school_id, private.can_view_resource(r.id)
      into target_school, permitted
      from public.resources r where r.id = p_resource_id;

    when 'resource_version.read' then
      select rv.school_id, private.can_view_resource_version(rv.id)
      into target_school, permitted
      from public.resource_versions rv where rv.id = p_resource_id;

    when 'resource_publication.read' then
      select rp.school_id, private.can_view_resource_publication(rp.id)
      into target_school, permitted
      from public.resource_publications rp where rp.id = p_resource_id;

    when 'membership.grant' then
      select s.id, private.is_school_admin(s.id)
      into target_school, permitted
      from public.schools s where s.id = p_resource_id;

    when 'membership.revoke' then
      select m.school_id, (
        private.is_school_admin(m.school_id)
        and not (m.user_id = auth.uid() and m.role = 'school_admin')
      ) into target_school, permitted
      from public.memberships m where m.id = p_resource_id;

    else
      known_action := false;
  end case;

  if not known_action then
    return jsonb_build_object(
      'allowed', false, 'school_id', null, 'reason', 'unknown_action'
    );
  end if;

  return jsonb_build_object(
    'allowed', coalesce(permitted, false),
    'school_id', target_school,
    'reason', case when coalesce(permitted, false) then 'allowed' else 'denied' end
  );
end;
$function$;

create or replace function private.authz_authorize(p_action text, p_resource_id uuid)
returns jsonb
language plpgsql
stable security definer
set search_path = ''
as $$
declare
  decision jsonb;
begin
  -- Decided outright, above both guardian rules below.
  if p_action in ('notebook.read', 'notebook.write', 'notebook_entry.delete', 'study_set.generate') then
    return private.authz_notebook(p_action, p_resource_id);
  end if;
  if p_action = 'conversation.mark_read' then
    return private.authz_conversation_read(p_action, p_resource_id);
  end if;

  if p_action = 'submission.history' then
    decision := private.authz_submission_history(p_action, p_resource_id);
  else
    -- Each action has one owner; the first match is the newest rule for it.
    decision := case
      when p_action = 'lesson_session.close'
        then private.authz_lesson_session_close(p_action, p_resource_id)
      when p_action in ('classJoinLink.create', 'classJoinLink.read', 'classJoinLink.revoke')
        then private.authz_class_join_links(p_action, p_resource_id)
      when p_action = 'classroom.create'
        then private.authz_classroom_create(p_action, p_resource_id)
      when p_action in ('file.download', 'file.publish')
        then private.authz_file_publication(p_action, p_resource_id)
      when p_action in ('upload.intent.create', 'upload.read', 'upload.complete', 
        'file.read')
        then private.authz_file_delivery(p_action, p_resource_id)
      when p_action in ('content_controls.read', 'content_controls.write', 
        'moderation.overview.read', 'moderation.queue.read', 'moderation.report.read', 
        'moderation.triage', 'moderation.resolve', 'moderation.escalate', 
        'moderation.evidence.write', 'moderation.hold', 'moderation.access.approve', 
        'moderation.access.start', 'moderation.access.revoke', 'moderation.access.list')
        then private.authz_safety(p_action, p_resource_id)
      when p_action in ('term.create', 'student.create')
        then private.authz_roster_create(p_action, p_resource_id)
      when p_action in ('support_access.approve', 'support_access.start', 
        'support_access.revoke', 'support_access.list')
        then private.authz_support_access(p_action, p_resource_id)
      when p_action in ('meeting.request', 'meeting.cancel', 'meeting.status')
        then private.authz_meetings(p_action, p_resource_id)
      when p_action in ('message.list', 'message.send', 'announcement.create', 
        'announcement.list')
        then private.authz_communications(p_action, p_resource_id)
      when p_action in ('guardian_link.verify', 'guardian_link.revoke')
        then private.authz_guardian_links(p_action, p_resource_id)
      when p_action in ('invitation.issue', 'invitation.revoke', 'invitation.list')
        then private.authz_invitations(p_action, p_resource_id)
      when p_action in ('school.suspend', 'school.close', 'membership.grant', 
        'membership.activate', 'membership.suspend', 'membership.revoke', 
        'classroom_staff.write', 'enrollment.write')
        then private.authz_school_admin(p_action, p_resource_id)
      when p_action in ('term.list', 'classroom.list', 'classroom.update', 
        'classroom.schedule.write', 'classroom.roster.read', 'classroom.staff.read', 
        'lesson_session.list', 'resource.list', 'resource.create', 'resource.revise', 
        'resource.publish', 'resource.withdraw', 'assignment.list', 'assignment.create', 
        'assignment.publish', 'assignment.withdraw', 'assignment.submit', 
        'assignment.read', 'submission.list', 'assessment.list', 'assessment.create', 
        'assessment.publish', 'assessment.withdraw', 'assessment.submit', 
        'assessment_question.list', 'assessment_question.authoring.list', 
        'assessment_attempt.list', 'grade_result.list', 'grade_result.review', 
        'grade_result.publish', 'grade_result.correct', 'grade_result.withdraw', 
        'attendance_record.list', 'attendance_record.write', 'attendance_roster.read', 
        'wellbeing_event.list', 'wellbeing_event.create')
        then private.authz_school_operations(p_action, p_resource_id)
      else private.authz_academic(p_action, p_resource_id)
    end;
    -- A guardian hands work in for a child with no device of their own.
    decision := private.authz_guardian_submits(p_action, p_resource_id, decision);
  end if;

  -- A verified guardian reads their child's lists and starts uploads for
  -- them, even with no membership of their own.
  return private.authz_guardian_list_reads(p_action, p_resource_id, decision);
end;
$$;

revoke all on function private.authz_notebook(text, uuid)
  from public, anon, authenticated, service_role, studafy_api_runtime,
  studafy_worker_runtime;
revoke all on function private.authz_conversation_read(text, uuid)
  from public, anon, authenticated, service_role, studafy_api_runtime,
  studafy_worker_runtime;
revoke all on function private.authz_guardian_list_reads(text, uuid, jsonb)
  from public, anon, authenticated, service_role, studafy_api_runtime,
  studafy_worker_runtime;
revoke all on function private.authz_submission_history(text, uuid)
  from public, anon, authenticated, service_role, studafy_api_runtime,
  studafy_worker_runtime;
revoke all on function private.authz_guardian_submits(text, uuid, jsonb)
  from public, anon, authenticated, service_role, studafy_api_runtime,
  studafy_worker_runtime;
revoke all on function private.authz_lesson_session_close(text, uuid)
  from public, anon, authenticated, service_role, studafy_api_runtime,
  studafy_worker_runtime;
revoke all on function private.authz_class_join_links(text, uuid)
  from public, anon, authenticated, service_role, studafy_api_runtime,
  studafy_worker_runtime;
revoke all on function private.authz_classroom_create(text, uuid)
  from public, anon, authenticated, service_role, studafy_api_runtime,
  studafy_worker_runtime;
revoke all on function private.authz_file_publication(text, uuid)
  from public, anon, authenticated, service_role, studafy_api_runtime,
  studafy_worker_runtime;
revoke all on function private.authz_file_delivery(text, uuid)
  from public, anon, authenticated, service_role, studafy_api_runtime,
  studafy_worker_runtime;
revoke all on function private.authz_safety(text, uuid)
  from public, anon, authenticated, service_role, studafy_api_runtime,
  studafy_worker_runtime;
revoke all on function private.authz_roster_create(text, uuid)
  from public, anon, authenticated, service_role, studafy_api_runtime,
  studafy_worker_runtime;
revoke all on function private.authz_support_access(text, uuid)
  from public, anon, authenticated, service_role, studafy_api_runtime,
  studafy_worker_runtime;
revoke all on function private.authz_meetings(text, uuid)
  from public, anon, authenticated, service_role, studafy_api_runtime,
  studafy_worker_runtime;
revoke all on function private.authz_communications(text, uuid)
  from public, anon, authenticated, service_role, studafy_api_runtime,
  studafy_worker_runtime;
revoke all on function private.authz_guardian_links(text, uuid)
  from public, anon, authenticated, service_role, studafy_api_runtime,
  studafy_worker_runtime;
revoke all on function private.authz_invitations(text, uuid)
  from public, anon, authenticated, service_role, studafy_api_runtime,
  studafy_worker_runtime;
revoke all on function private.authz_school_admin(text, uuid)
  from public, anon, authenticated, service_role, studafy_api_runtime,
  studafy_worker_runtime;
revoke all on function private.authz_school_operations(text, uuid)
  from public, anon, authenticated, service_role, studafy_api_runtime,
  studafy_worker_runtime;
revoke all on function private.authz_academic(text, uuid)
  from public, anon, authenticated, service_role, studafy_api_runtime,
  studafy_worker_runtime;

drop function private.authz_authorize_pre_notebook(text, uuid);
drop function private.authz_authorize_pre_receipts(text, uuid);
drop function private.authz_authorize_pre_guardian_reads(text, uuid);
drop function private.authz_authorize_pre_history(text, uuid);
drop function private.authz_authorize_pre_guardian(text, uuid);
drop function private.authz_authorize_pre_teach055(text, uuid);
drop function private.authz_authorize_pre_join052(text, uuid);
drop function private.authz_authorize_pre_teacher_class(text, uuid);
drop function private.authz_authorize_pre_file051(text, uuid);
drop function private.authz_authorize_pre_file050(text, uuid);
drop function private.authz_authorize_pre_safe043(text, uuid);
drop function private.authz_authorize_pre_s9_roster(text, uuid);
drop function private.authz_authorize_pre_api042_support(text, uuid);
drop function private.authz_authorize_pre_api042_meetings(text, uuid);
drop function private.authz_authorize_pre_api042_comms(text, uuid);
drop function private.authz_authorize_pre_api042_family(text, uuid);
drop function private.authz_authorize_pre_api042_invitations(text, uuid);
drop function private.authz_authorize_pre_api042(text, uuid);
drop function private.authz_authorize_pre_api041(text, uuid);
