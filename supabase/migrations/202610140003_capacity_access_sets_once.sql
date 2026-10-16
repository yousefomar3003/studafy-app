-- Capacity fix 1 (docs/capacity/2026-10-12.md): access rules once per call.
--
-- The academic lists (classes, lessons held, lessons, homework, exams,
-- grades, attendance) first work out whom the caller can possibly see. They
-- then asked is_class_staff and can_view_classroom once for every class in
-- that set, and can_view_class_student once for every class/student pair,
-- and attendance asked can_view_class_student again for every row of a
-- class the caller teaches. On the scale data those calls were about 20% of
-- all database time.
--
-- The rules are unchanged. They are now evaluated once for the caller as a
-- few set queries: the classes they actively teach (is_class_staff), the
-- schools they administer (is_school_admin), and the class/student pairs
-- where they are that enrolled student or a verified guardian of them
-- (is_enrolled_student, is_verified_guardian). The per-class and per-pair
-- answers are read from those sets. For a class the caller teaches,
-- can_view_class_student reduces to "the student is actively enrolled",
-- which attendance now asks directly.
--
-- Proven before shipping: every list, for every pgTAP fixture user and a
-- sample of the scale data, page by page, gives the same answer before and
-- after (docs/capacity/2026-10-14.md). create or replace keeps the
-- function's owner and grants.

CREATE OR REPLACE FUNCTION private.api041_query_before_notebook(p_operation text, p_resource_id uuid, p_input jsonb)
 RETURNS jsonb
 LANGUAGE plpgsql
 STABLE SECURITY DEFINER
 SET search_path TO ''
AS $function$
declare tenant uuid; limit_rows int; pos uuid; result jsonb; next_pos text;
  roster_session uuid; roster_version bigint;
  -- Whom the caller can possibly see rows for, worked out once per call so a
  -- list skips every other row before the per-row access check runs.
  v_admin boolean; v_mine uuid[]; v_taught uuid[]; v_classes uuid[];
  -- The access functions' answers for those classes (and class/student
  -- pairs), asked once each instead of once per row.
  v_staff_ok uuid[]; v_view_ok uuid[]; v_pairs_ok text[];
  -- The rules behind those answers, worked out once for the caller.
  v_active boolean; v_staff_all uuid[]; v_admin_schools uuid[]; v_own_pairs text[];
begin
  tenant := nullif(current_setting('studafy.school_id',true),'')::uuid;
  if auth.uid() is null or tenant is null or not private.has_active_membership(tenant) then
    return jsonb_build_object('outcome','forbidden');
  end if;
  limit_rows := least(greatest(coalesce((p_input->>'pageSize')::int,50),1),100);
  pos := nullif(p_input->>'position','')::uuid;
  -- Every access function below answers yes only for a school admin, the
  -- class's staff, or a student row the caller is or holds a verified link
  -- to, in a class it is actively enrolled in. These sets contain all of
  -- those, so testing them first never hides a row; it only skips, cheaply,
  -- rows the access check would refuse.
  if p_operation in ('listClassrooms', 'listLessonSessions', 'listResources',
      'listAssignments', 'listAssessments', 'listGradeResults', 'listAttendance') then
  v_admin := private.is_school_admin(tenant);
  v_mine := array(
    select st.id from public.students st
    where st.user_id = auth.uid() and st.deleted_at is null
    union
    select gl.student_id from public.guardian_links gl
    where gl.guardian_id = auth.uid() and gl.status = 'verified');
  v_taught := array(
    select cs.classroom_id from public.classroom_staff cs
    where cs.user_id = auth.uid() and cs.status = 'active');
  v_classes := v_taught || array(
    select e.classroom_id from public.enrollments e
    where e.student_id = any(v_mine) and e.active);
  -- The rules of is_class_staff, can_view_classroom and
  -- can_view_class_student, evaluated once for the caller as a few set
  -- queries instead of once per class and per class/student pair (capacity
  -- fix 1, 2026-10-14; proven equal on every fixture and the scale data).
  v_active := private.is_active_user();
  -- is_class_staff: the classes the caller actively teaches.
  v_staff_all := array(
    select cs.classroom_id from public.classroom_staff cs
    join public.memberships m
      on m.id = cs.membership_id and m.school_id = cs.school_id and m.user_id = cs.user_id
    join public.schools s on s.id = cs.school_id
    where v_active and cs.user_id = auth.uid() and cs.status = 'active'
      and cs.starts_at <= now() and (cs.ends_at is null or cs.ends_at > now())
      and m.active and m.status = 'active' and m.valid_from <= now()
      and (m.valid_until is null or m.valid_until > now())
      and m.role in ('teacher', 'school_admin')
      and s.status = 'active' and s.deleted_at is null);
  -- is_school_admin: the schools the caller administers.
  v_admin_schools := array(
    select m.school_id from public.memberships m
    join public.schools s on s.id = m.school_id
    where v_active and m.user_id = auth.uid() and m.active and m.status = 'active'
      and m.valid_from <= now() and (m.valid_until is null or m.valid_until > now())
      and s.status = 'active' and s.deleted_at is null
      and m.role = 'school_admin');
  -- is_enrolled_student and is_verified_guardian: the class/student pairs
  -- where the caller is that enrolled student, or a verified guardian of them.
  v_own_pairs := array(
    select e.classroom_id::text || '/' || e.student_id::text
    from public.enrollments e
    join public.students st on st.id = e.student_id and st.school_id = e.school_id
    join public.classrooms c on c.id = e.classroom_id and c.school_id = e.school_id
    join public.terms t on t.id = c.term_id and t.school_id = c.school_id
    where v_active and st.user_id = auth.uid() and st.deleted_at is null
      and e.active and e.status = 'active' and e.starts_on <= current_date
      and (e.ends_on is null or e.ends_on >= current_date)
      and c.status = 'active' and t.status = 'active'
      and private.has_active_membership(e.school_id, array['student']::public.app_role[])
    union
    select e.classroom_id::text || '/' || e.student_id::text
    from public.guardian_links gl
    join public.enrollments e on e.student_id = gl.student_id and e.school_id = gl.school_id
    join public.classrooms c on c.id = e.classroom_id and c.school_id = e.school_id
    join public.terms t on t.id = c.term_id and t.school_id = c.school_id
    where v_active and gl.guardian_id = auth.uid() and gl.status = 'verified'
      and (gl.expires_at is null or gl.expires_at > now())
      and e.active and e.status = 'active' and e.starts_on <= current_date
      and (e.ends_on is null or e.ends_on >= current_date)
      and c.status = 'active' and t.status = 'active'
      and private.has_active_membership(gl.school_id, array['parent', 'guardian']::public.app_role[]));
  v_staff_ok := array(select c from unnest(v_classes) c where c = any(v_staff_all));
  v_view_ok := array(
    select c.id from public.classrooms c
    where c.id = any(v_classes)
      and (c.school_id = any(v_admin_schools) or c.id = any(v_staff_all)
        or exists (select 1 from unnest(v_own_pairs) p
          where split_part(p, '/', 1) = c.id::text)));
  v_pairs_ok := array(
    select e.classroom_id::text || '/' || e.student_id::text from public.enrollments e
    where e.student_id = any(v_mine) and e.active and e.status = 'active'
      and e.starts_on <= current_date and (e.ends_on is null or e.ends_on >= current_date)
      and (e.school_id = any(v_admin_schools) or e.classroom_id = any(v_staff_all)
        or (e.classroom_id::text || '/' || e.student_id::text) = any(v_own_pairs)));
  end if;
  case p_operation
    when 'getSchool' then
      select to_jsonb(x) into result from (select s.id,s.name,s.timezone,coalesce(s.locale,'en') locale
        from public.schools s where s.id=p_resource_id and s.id=tenant and s.status='active') x;
      return result;
    when 'listTerms' then
      select coalesce(jsonb_agg(to_jsonb(x) order by x.id),'[]'),max(x.id::text) into result,next_pos from (
        select t.id,t.school_id "schoolId",t.name,t.starts_on "startsOn",t.ends_on "endsOn",t.status
        from public.terms t where t.school_id=tenant and (pos is null or t.id>pos) order by t.id limit limit_rows
      ) x; return jsonb_build_object('items',result,'nextPosition',case when jsonb_array_length(result)=limit_rows then next_pos end);
    when 'listClassrooms' then
      select coalesce(jsonb_agg(private.api041_classroom_json(x.id) order by x.id),'[]'),max(x.id::text) into result,next_pos from (
        select c.id from public.classrooms c where c.school_id=tenant and c.archived_at is null
          and (pos is null or c.id>pos) and (v_admin or c.id = any(v_classes))
          and (c.id = any(v_view_ok) or (v_admin and private.can_view_classroom(c.id))) order by c.id limit limit_rows
      ) x; return jsonb_build_object('items',result,'nextPosition',case when jsonb_array_length(result)=limit_rows then next_pos end);
    when 'getClassroom' then
      if not private.can_view_classroom(p_resource_id) then return jsonb_build_object('outcome','not_found'); end if;
      return jsonb_build_object('classroom',private.api041_classroom_json(p_resource_id),'schedule',coalesce((
        select jsonb_agg(jsonb_build_object('id',cs.id,'weekday',cs.weekday,'startsAt',cs.starts_at,
          'endsAt',cs.ends_at,'effectiveFrom',cs.effective_from,'effectiveUntil',cs.effective_until) order by cs.weekday,cs.starts_at)
        from public.class_schedules cs where cs.classroom_id=p_resource_id
      ),'[]'::jsonb));
    when 'listClassroomStudents' then
      if not (private.is_school_admin(tenant) or private.is_class_staff(p_resource_id)) then return jsonb_build_object('outcome','not_found'); end if;
      select coalesce(jsonb_agg(to_jsonb(x) order by x.id),'[]'),max(x.id::text) into result,next_pos from (
        select st.id,st.display_name "displayName",st.studafy_id "studafyId" from public.enrollments e
        join public.students st on st.id=e.student_id where e.classroom_id=p_resource_id and e.active and e.status='active'
          and (pos is null or st.id>pos) order by st.id limit limit_rows
      ) x; return jsonb_build_object('items',result,'nextPosition',case when jsonb_array_length(result)=limit_rows then next_pos end);
    when 'listClassroomStaff' then
      if not (private.is_school_admin(tenant) or private.is_class_staff(p_resource_id)) then return jsonb_build_object('outcome','not_found'); end if;
      select coalesce(jsonb_agg(to_jsonb(x) order by x.id),'[]'),max(x.id::text) into result,next_pos from (
        select cs.id,cs.user_id "userId",p.display_name "displayName",cs.role from public.classroom_staff cs
        join public.profiles p on p.id=cs.user_id where cs.classroom_id=p_resource_id and cs.status='active'
          and (pos is null or cs.id>pos) order by cs.id limit limit_rows
      ) x; return jsonb_build_object('items',result,'nextPosition',case when jsonb_array_length(result)=limit_rows then next_pos end);
    when 'listLessonSessions' then
      select coalesce(jsonb_agg(to_jsonb(x) order by x.id),'[]'),max(x.id::text) into result,next_pos from (
        select ls.id,ls.classroom_id "classroomId",ls.starts_at "startsAt",ls.ends_at "endsAt",ls.title,ls.status,ls.filed_at "filedAt",ls.version
        from public.lesson_sessions ls where ls.school_id=tenant and (pos is null or ls.id>pos)
          and ((p_input->>'classroomId') is null or ls.classroom_id=(p_input->>'classroomId')::uuid)
          and (v_admin or ls.classroom_id = any(v_classes))
          and (ls.classroom_id = any(v_view_ok) or (v_admin and private.can_view_classroom(ls.classroom_id))) order by ls.id limit limit_rows
      ) x; return jsonb_build_object('items',result,'nextPosition',case when jsonb_array_length(result)=limit_rows then next_pos end);
    when 'listResources' then
      select coalesce(jsonb_agg(private.api041_resource_json(x.id) order by x.id),'[]'),max(x.id::text) into result,next_pos from (
        select distinct r.id from public.resources r left join public.resource_versions rv on rv.resource_id=r.id
        left join public.resource_publications rp on rp.resource_version_id=rv.id
        where r.school_id=tenant and r.deleted_at is null and (pos is null or r.id>pos)
          and ((p_input->>'classroomId') is null or rp.classroom_id=(p_input->>'classroomId')::uuid)
          and (v_admin or r.created_by=auth.uid() or rp.classroom_id = any(v_classes))
          and (v_admin or r.created_by=auth.uid() or
            (rp.classroom_id is not null and rp.classroom_id = any(v_staff_ok)) or
            (r.state='published' and rp.state='published' and rp.classroom_id = any(v_view_ok)))
        order by r.id limit limit_rows
      ) x; return jsonb_build_object('items',result,'nextPosition',case when jsonb_array_length(result)=limit_rows then next_pos end);
    when 'listAssignments' then
      select coalesce(jsonb_agg(private.api041_assignment_json(x.id) order by x.id),'[]'),max(x.id::text) into result,next_pos from (
        select a.id from public.assignments a where a.school_id=tenant and a.deleted_at is null and (pos is null or a.id>pos)
          and ((p_input->>'classroomId') is null or a.classroom_id=(p_input->>'classroomId')::uuid)
          and (v_admin or a.classroom_id = any(v_classes))
          and (v_admin or a.classroom_id = any(v_staff_ok) or (a.state='published' and a.classroom_id = any(v_view_ok)))
        order by a.id limit limit_rows
      ) x; return jsonb_build_object('items',result,'nextPosition',case when jsonb_array_length(result)=limit_rows then next_pos end);
    when 'getAssignment' then
      if not exists(select 1 from public.assignments a where a.id=p_resource_id and a.school_id=tenant and
        (private.is_school_admin(tenant) or private.is_class_staff(a.classroom_id) or
          (a.state='published' and a.deleted_at is null and private.can_view_classroom(a.classroom_id)))) then
        return jsonb_build_object('outcome','not_found');
      end if;
      return private.api041_assignment_json(p_resource_id);
    when 'listAssignmentSubmissions' then
      if not private.api041_class_writer((select classroom_id from public.assignments where id=p_resource_id)) then return jsonb_build_object('outcome','not_found'); end if;
      select coalesce(jsonb_agg(to_jsonb(x) order by x.id),'[]'),max(x.id::text) into result,next_pos from (
        select s.id,s.assignment_id "assignmentId",s.student_id "studentId",s.status,s.version,
          sa.answer_text "answerText",s.submitted_at "submittedAt" from public.submissions s
        left join public.submission_attempts sa on sa.id=s.current_attempt_id where s.assignment_id=p_resource_id
          and (pos is null or s.id>pos) order by s.id limit limit_rows
      ) x; return jsonb_build_object('items',result,'nextPosition',case when jsonb_array_length(result)=limit_rows then next_pos end);
    when 'listAssessments' then
      select coalesce(jsonb_agg(private.api041_assessment_json(x.id) order by x.id),'[]'),max(x.id::text) into result,next_pos from (
        select a.id from public.assessments a where a.school_id=tenant and a.deleted_at is null and (pos is null or a.id>pos)
          and ((p_input->>'classroomId') is null or a.classroom_id=(p_input->>'classroomId')::uuid)
          and (v_admin or a.classroom_id = any(v_classes))
          and (v_admin or a.classroom_id = any(v_staff_ok) or (a.state='published' and a.classroom_id = any(v_view_ok)))
        order by a.id limit limit_rows
      ) x; return jsonb_build_object('items',result,'nextPosition',case when jsonb_array_length(result)=limit_rows then next_pos end);
    when 'listAssessmentQuestions' then
      if not exists(select 1 from public.assessments a where a.id=p_resource_id and a.school_id=tenant and
        (private.is_class_staff(a.classroom_id) or (a.state='published' and private.can_view_classroom(a.classroom_id)))) then return jsonb_build_object('outcome','not_found'); end if;
      select coalesce(jsonb_agg(to_jsonb(x) order by x.position),'[]') into result from (
        select q.id,q.position,q.prompt,q.maximum_score "maximumScore" from public.assessment_questions q
        where q.assessment_id=p_resource_id order by q.position limit limit_rows
      ) x; return jsonb_build_object('items',result,'nextPosition',null);
    when 'listAssessmentAuthoringQuestions' then
      if not exists(select 1 from public.assessments a where a.id=p_resource_id and a.school_id=tenant and private.api041_class_writer(a.classroom_id)) then
        return jsonb_build_object('outcome','not_found');
      end if;
      select coalesce(jsonb_agg(to_jsonb(x) order by x.position),'[]') into result from (
        select q.id,q.position,q.prompt,q.preferred_answer "preferredAnswer",q.maximum_score "maximumScore"
        from public.assessment_questions q where q.assessment_id=p_resource_id order by q.position limit limit_rows
      ) x; return jsonb_build_object('items',result,'nextPosition',null);
    when 'listAssessmentAttempts' then
      if not exists(select 1 from public.assessments a where a.id=p_resource_id and a.school_id=tenant and private.api041_class_writer(a.classroom_id)) then return jsonb_build_object('outcome','not_found'); end if;
      select coalesce(jsonb_agg(to_jsonb(x) order by x.id),'[]'),max(x.id::text) into result,next_pos from (
        select aa.id,aa.assessment_id "assessmentId",aa.student_id "studentId",aa.submitted_at "submittedAt",aa.version
        from public.assessment_attempts aa where aa.assessment_id=p_resource_id and (pos is null or aa.id>pos)
        order by aa.id limit limit_rows
      ) x; return jsonb_build_object('items',result,'nextPosition',case when jsonb_array_length(result)=limit_rows then next_pos end);
    when 'listGradeResults' then
      select coalesce(jsonb_agg(private.api041_grade_json(x.id) order by x.id),'[]'),max(x.id::text) into result,next_pos from (
        select g.id from public.grade_results g join public.assessments a on a.id=g.assessment_id
        where g.school_id=tenant and (pos is null or g.id>pos)
          and ((p_input->>'studentId') is null or g.student_id=(p_input->>'studentId')::uuid)
          and ((p_input->>'classroomId') is null or a.classroom_id=(p_input->>'classroomId')::uuid)
          and (v_admin or a.classroom_id = any(v_taught) or g.student_id = any(v_mine))
          and (v_admin or a.classroom_id = any(v_staff_ok) or (g.state='published' and (a.classroom_id::text || '/' || g.student_id::text) = any(v_pairs_ok)))
        order by g.id limit limit_rows
      ) x; return jsonb_build_object('items',result,'nextPosition',case when jsonb_array_length(result)=limit_rows then next_pos end);
    when 'listAttendance' then
      select coalesce(jsonb_agg(to_jsonb(x) order by x.id),'[]'),max(x.id::text) into result,next_pos from (
        select ar.id,ar.session_id "sessionId",ar.student_id "studentId",ar.state,ar.reason,ar.recorded_at "recordedAt"
        from public.attendance_records ar join public.lesson_sessions ls on ls.id=ar.session_id
        where ar.school_id=tenant and (pos is null or ar.id>pos)
          and ((p_input->>'studentId') is null or ar.student_id=(p_input->>'studentId')::uuid)
          and ((p_input->>'classroomId') is null or ls.classroom_id=(p_input->>'classroomId')::uuid)
          and (v_admin or ls.classroom_id = any(v_taught) or ar.student_id = any(v_mine))
          and (v_admin or (ls.classroom_id::text || '/' || ar.student_id::text) = any(v_pairs_ok)
            or (ls.classroom_id = any(v_staff_ok) and exists (
              select 1 from public.enrollments e
              where e.classroom_id = ls.classroom_id and e.student_id = ar.student_id
                and e.active and e.status = 'active' and e.starts_on <= current_date
                and (e.ends_on is null or e.ends_on >= current_date))))
        order by ar.id limit limit_rows
      ) x; return jsonb_build_object('items',result,'nextPosition',case when jsonb_array_length(result)=limit_rows then next_pos end);
    when 'listAttendanceRoster' then
      if not (private.is_school_admin(tenant) or private.is_class_staff(p_resource_id)) then return jsonb_build_object('outcome','not_found'); end if;
      -- A register belongs to one meeting, not to a day. The previous join
      -- matched every lesson_session on the date, so a class that meets twice
      -- in a day produced a duplicate row per student and merged two lessons
      -- into one register. Exactly one session is resolved first, and the
      -- records are read from that session alone.
      if nullif(p_input->>'startsAt','') is not null then
        select ls.id,ls.version into roster_session,roster_version
        from public.lesson_sessions ls
        where ls.classroom_id=p_resource_id
          and ls.starts_at=(p_input->>'startsAt')::timestamptz;
      else
        -- No meeting named: the earliest that day, so the result is at least
        -- deterministic rather than an arbitrary row from either session.
        select ls.id,ls.version into roster_session,roster_version
        from public.lesson_sessions ls
        where ls.classroom_id=p_resource_id
          and (ls.starts_at at time zone (select timezone from public.schools where id=tenant))::date
              =coalesce((p_input->>'date')::date,current_date)
        order by ls.starts_at limit 1;
      end if;
      select coalesce(jsonb_agg(to_jsonb(x) order by x.id),'[]'),max(x.id::text) into result,next_pos from (
        select st.id,jsonb_build_object('id',st.id,'displayName',st.display_name,'studafyId',st.studafy_id) student,
          case when ar.id is null then null else jsonb_build_object('id',ar.id,'sessionId',ar.session_id,'studentId',ar.student_id,
            'state',ar.state,'reason',ar.reason,'recordedAt',ar.recorded_at) end record
        from public.enrollments e join public.students st on st.id=e.student_id
        left join public.attendance_records ar on ar.session_id=roster_session and ar.student_id=st.id
        where e.classroom_id=p_resource_id and e.active and e.status='active' and (pos is null or st.id>pos)
        order by st.id limit limit_rows
      ) x;
      -- The session's version travels with the register so a correction can
      -- be saved: recordAttendance demands 0 for a session that does not
      -- exist yet and the current version for one that does.
      return jsonb_build_object('items',result,
        'session',case when roster_session is null then null
          else jsonb_build_object('id',roster_session,'version',roster_version) end,
        'nextPosition',case when jsonb_array_length(result)=limit_rows then next_pos end);
    when 'listWellbeing' then
      select coalesce(jsonb_agg(to_jsonb(x) order by x.id),'[]'),max(x.id::text) into result,next_pos from (
        select w.id,w.student_id "studentId",w.classroom_id "classroomId",w.kind,w.title,w.context,w.follow_up "followUp",
          w.visibility,w.severity,w.created_at "createdAt" from public.wellbeing_events w where w.school_id=tenant
          and (pos is null or w.id>pos) and ((p_input->>'studentId') is null or w.student_id=(p_input->>'studentId')::uuid)
          and w.visibility<>'safeguarding_restricted' and private.can_view_wellbeing(w.id) order by w.id limit limit_rows
      ) x; return jsonb_build_object('items',result,'nextPosition',case when jsonb_array_length(result)=limit_rows then next_pos end);
    else return jsonb_build_object('outcome','not_found');
  end case;
end;
$function$

;

alter function private.api041_query_before_notebook(text, uuid, jsonb) owner to postgres;
