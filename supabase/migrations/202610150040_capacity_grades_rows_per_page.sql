-- Capacity fix 6 (docs/capacity/2026-10-15.md, "Next" 2): grades rows
-- built for the whole page at once.
--
-- Through the API the grades list and its per-row builder were about 19% of
-- database time on the scale data (9.5% the list, 9.1% api041_grade_json,
-- 142,680 calls). Each grade on a page was built by api041_grade_json, one
-- call per row, which asked coursework_staff for the grade's class and then
-- found its files and links through coursework_files_json and
-- content_links_json four times: the grade's own attachments and links,
-- and its assessment's shared results files and links. Those two helpers
-- take an either-or filter that serves five kinds of owner, so no index
-- answered it and each call read the bindings or links table; and the
-- assessment's shared results were found again for every grade of it.
--
-- api041_grade_rows builds a page of grades in one query: the same sources,
-- the same rule and the same order, field for field. coursework_staff is
-- asked once per class on the page instead of once per grade; the grade's
-- files and links are found by their indexes (file_binding_grade_idx,
-- content_links_grade_idx); an assessment's shared results once per
-- assessment on the page. Both lists that built grades a row at a time now
-- call it: the member list (api041_query_before_notebook) and the
-- guardian's list of a linked child's grades
-- (api041_query_pre_roster_shape). Only that line changes in each; the rest
-- of both functions is re-stated unchanged, as CREATE OR REPLACE requires
-- (including the access checks they already had). api041_grade_json stays
-- for the single-grade reads and command responses.
--
-- Proven before shipping like fixes 1-5 (docs/capacity/2026-10-16.md).

-- A page of grades, in id order, each exactly as api041_grade_json builds
-- it. A grade's attachments and links, and its assessment's shared
-- results, are shown once the grade is published or to the class's
-- teacher (coursework_staff), as before; otherwise they are empty.
create or replace function private.api041_grade_rows(p_ids uuid[])
returns jsonb
language sql stable security definer set search_path = '' as $$
  with page as materialized (
    select g.id, g.assessment_id, g.student_id, g.score, g.feedback, g.state, g.version,
      g.reviewed_at, g.published_at, g.mark, a.title, a.category, a.maximum_score,
      a.delivery, a.category_weight, a.assignment_id, a.classroom_id
    from public.grade_results g
    join public.assessments a on a.id = g.assessment_id
    where g.id = any(p_ids)
  ),
  -- coursework_staff, asked once for each class on the page.
  staff as materialized (
    select c.classroom_id, private.coursework_staff(c.classroom_id) as ok
    from (select distinct p.classroom_id from page p) c
  ),
  -- coursework_files_json / content_links_json (p_assessment => a.id,
  -- p_role => 'results'), once for each assessment on the page.
  shared as materialized (
    select x.assessment_id,
      (select coalesce(jsonb_agg(jsonb_build_object(
          'id', fo.id, 'displayName', fo.display_name, 'sizeBytes', fo.size_bytes,
          'mediaType', fo.declared_media_type, 'scanState', fo.scan_state)
        order by b.created_at, fo.id), '[]'::jsonb)
       from public.file_bindings b
       join public.file_objects fo on fo.id = b.file_object_id
       where fo.deleted_at is null and b.detached_at is null and b.role = 'results'
         and b.assessment_id = x.assessment_id) as files,
      (select coalesce(jsonb_agg(jsonb_build_object('id', l.id, 'title', l.title, 'url', l.url)
        order by l.position, l.created_at, l.id), '[]'::jsonb)
       from public.content_links l
       where l.detached_at is null and l.role = 'results'
         and l.assessment_id = x.assessment_id) as links
    from (select distinct p.assessment_id from page p) x
  )
  select jsonb_agg(jsonb_build_object('id', g.id, 'assessmentId', g.assessment_id,
      'studentId', g.student_id, 'assessmentTitle', g.title, 'category', g.category,
      'score', g.score, 'maximumScore', g.maximum_score, 'feedback', g.feedback,
      'state', g.state, 'version', g.version, 'reviewedAt', g.reviewed_at,
      'publishedAt', g.published_at, 'delivery', g.delivery,
      'mark', private.grade_mark_of(g.mark, g.score),
      'weight', g.category_weight, 'assignmentId', g.assignment_id)
    || case when g.state = 'published' or st.ok then
      jsonb_build_object(
        'attachments', att.items, 'links', lnk.items,
        'sharedAttachments', sh.files, 'sharedLinks', sh.links)
      else jsonb_build_object('attachments', '[]'::jsonb, 'links', '[]'::jsonb,
        'sharedAttachments', '[]'::jsonb, 'sharedLinks', '[]'::jsonb) end
    order by g.id)
  from page g
  join staff st on st.classroom_id is not distinct from g.classroom_id
  join shared sh on sh.assessment_id = g.assessment_id
  -- coursework_files_json(p_grade_result => g.id): material files only.
  cross join lateral (
    select coalesce(jsonb_agg(jsonb_build_object(
        'id', fo.id, 'displayName', fo.display_name, 'sizeBytes', fo.size_bytes,
        'mediaType', fo.declared_media_type, 'scanState', fo.scan_state)
      order by b.created_at, fo.id), '[]'::jsonb) as items
    from public.file_bindings b
    join public.file_objects fo on fo.id = b.file_object_id
    where fo.deleted_at is null and b.detached_at is null and b.role = 'material'
      and b.grade_result_id = g.id
  ) att
  -- content_links_json(p_grade_result => g.id): material links only.
  cross join lateral (
    select coalesce(jsonb_agg(jsonb_build_object('id', l.id, 'title', l.title, 'url', l.url)
      order by l.position, l.created_at, l.id), '[]'::jsonb) as items
    from public.content_links l
    where l.detached_at is null and l.role = 'material'
      and l.grade_result_id = g.id
  ) lnk;
$$;

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
      -- The page's rows are built together (capacity fix 4).
      select coalesce(private.api041_resource_rows(array_agg(x.id order by x.id)),'[]'),max(x.id::text) into result,next_pos from (
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
      -- The page's rows are built together (capacity fix 3).
      select coalesce(private.api041_assignment_rows(array_agg(x.id order by x.id)),'[]'),max(x.id::text) into result,next_pos from (
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
      -- The caller's own records first (capacity fix 2): the grades of the
      -- students they are or are linked to, and of the classes they teach,
      -- found by index. The conditions below are unchanged, so this only
      -- skips rows they would refuse; a school admin still reads the school.
      select coalesce(private.api041_grade_rows(array_agg(x.id order by x.id)),'[]'),max(x.id::text) into result,next_pos from (
        select g.id from (
          select g2.id from public.grade_results g2
          where not v_admin and g2.student_id = any(v_mine)
          union
          select g3.id from public.assessments a3
          join public.grade_results g3 on g3.assessment_id = a3.id
          where not v_admin and a3.classroom_id = any(v_taught)
          union
          select g4.id from public.grade_results g4 where v_admin and g4.school_id = tenant
        ) mine
        join public.grade_results g on g.id = mine.id
        join public.assessments a on a.id=g.assessment_id
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

CREATE OR REPLACE FUNCTION private.api041_query_pre_roster_shape(p_operation text, p_resource_id uuid, p_input jsonb)
 RETURNS jsonb
 LANGUAGE plpgsql
 STABLE SECURITY DEFINER
 SET search_path TO ''
AS $function$
declare
  v_child uuid;
  v_child_classes uuid[];
  v_ids uuid[];
  v_class uuid := nullif(p_input->>'classroomId', '')::uuid;
  limit_rows int := least(greatest(coalesce((p_input->>'pageSize')::int, 50), 1), 100);
  pos uuid := nullif(p_input->>'position', '')::uuid;
  result jsonb;
  next_pos text;
begin
  if p_operation not in ('listAssignments', 'listAssessments', 'listResources',
      'listGradeResults', 'listAttendance') then
    return private.api041_query_pre_guardian_reads(p_operation, p_resource_id, p_input);
  end if;

  v_child := nullif(p_input->>'studentId', '')::uuid;
  -- Only a request that names a child the caller is linked to, and that the
  -- caller cannot already read as a member of the school, takes this path.
  if v_child is null or auth.uid() is null
    or not private.is_linked_guardian(v_child)
    or exists (select 1 from public.students st
      where st.id = v_child and private.has_active_membership(st.school_id)) then
    return private.api041_query_pre_guardian_reads(p_operation, p_resource_id, p_input);
  end if;

  -- is_linked_guardian answers yes only for a class the child is actively
  -- enrolled in, so a list looks at those classes' rows alone instead of
  -- every row in the database.
  v_child_classes := array(
    select e.classroom_id from public.enrollments e
    where e.student_id = v_child and e.active);

  case p_operation
    when 'listAssignments' then
      select array_agg(x.id order by x.id), max(x.id::text)
        into v_ids, next_pos
      from (
        select a.id from public.assignments a
        where a.state = 'published' and a.deleted_at is null
          and (pos is null or a.id > pos)
          and (v_class is null or a.classroom_id = v_class)
          and a.classroom_id = any(v_child_classes)
          and private.is_linked_guardian(v_child, a.classroom_id)
        order by a.id limit limit_rows
      ) x;
      -- The page's rows are built together (capacity fix 3). The builder
      -- reports the *caller's* submission. For a guardian that is always
      -- none; what they need is the child's.
      select coalesce(jsonb_agg(r.item || jsonb_build_object(
          'submissionId', su.id, 'submittedAt', su.submitted_at)
          order by r.ord), '[]')
        into result
      from jsonb_array_elements(coalesce(private.api041_assignment_rows(v_ids), '[]'))
        with ordinality as r(item, ord)
      left join public.submissions su
        on su.assignment_id = (r.item->>'id')::uuid and su.student_id = v_child;

    when 'listAssessments' then
      select coalesce(jsonb_agg(private.api041_assessment_json(x.id) order by x.id), '[]'),
        max(x.id::text) into result, next_pos
      from (
        select a.id from public.assessments a
        where a.state = 'published' and a.deleted_at is null
          and (pos is null or a.id > pos)
          and (v_class is null or a.classroom_id = v_class)
          and a.classroom_id = any(v_child_classes)
          and private.is_linked_guardian(v_child, a.classroom_id)
        order by a.id limit limit_rows
      ) x;

    when 'listResources' then
      -- The page's rows are built together (capacity fix 4).
      select coalesce(private.api041_resource_rows(array_agg(x.id order by x.id)), '[]'),
        max(x.id::text) into result, next_pos
      from (
        select distinct r.id from public.resources r
        join public.resource_versions rv on rv.resource_id = r.id
        join public.resource_publications rp on rp.resource_version_id = rv.id
        where r.deleted_at is null and r.state = 'published'
          and rp.state = 'published' and rp.withdrawn_at is null
          and rp.classroom_id is not null
          -- The teacher chose who it is for when publishing; a guardian sees
          -- only what was shared with guardians, as can_view_resource_
          -- publication already decides for members.
          and rp.audience in ('guardians', 'both')
          and (pos is null or r.id > pos)
          and (v_class is null or rp.classroom_id = v_class)
          and rp.classroom_id = any(v_child_classes)
          and private.is_linked_guardian(v_child, rp.classroom_id)
        order by r.id limit limit_rows
      ) x;

    when 'listGradeResults' then
      select coalesce(private.api041_grade_rows(array_agg(x.id order by x.id)), '[]'),
        max(x.id::text) into result, next_pos
      from (
        select g.id from public.grade_results g
        join public.assessments a on a.id = g.assessment_id
        where g.student_id = v_child and g.state = 'published'
          and (pos is null or g.id > pos)
          and (v_class is null or a.classroom_id = v_class)
        order by g.id limit limit_rows
      ) x;

    when 'listAttendance' then
      select coalesce(jsonb_agg(to_jsonb(x) order by x.id), '[]'), max(x.id::text)
        into result, next_pos
      from (
        select ar.id, ar.session_id "sessionId", ar.student_id "studentId",
          ar.state, ar.reason, ar.recorded_at "recordedAt"
        from public.attendance_records ar
        join public.lesson_sessions ls on ls.id = ar.session_id
        where ar.student_id = v_child
          and (pos is null or ar.id > pos)
          and (v_class is null or ls.classroom_id = v_class)
        order by ar.id limit limit_rows
      ) x;
  end case;

  return jsonb_build_object('items', result, 'nextPosition',
    case when jsonb_array_length(result) = limit_rows then next_pos end);
exception when invalid_text_representation then
  return jsonb_build_object('outcome', 'not_found');
end;
$function$

;

do $grants$
declare fn text;
begin
  foreach fn in array array[
    'private.api041_grade_rows(uuid[])',
    'private.api041_query_before_notebook(text, uuid, jsonb)',
    'private.api041_query_pre_roster_shape(text, uuid, jsonb)'
  ] loop
    execute format('alter function %s owner to postgres', fn);
  end loop;
end
$grants$;

revoke all on function private.api041_grade_rows(uuid[])
  from public, anon, authenticated, service_role, studafy_api_runtime, studafy_worker_runtime;
