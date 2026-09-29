-- Access checks that stay fast as schools grow (2026-09-29).
--
-- Measured with scripts/scale (docs/operations/capacity.md): at 100 schools
-- and 50,000 students, opening a student's assignments took 8.6 s and a
-- parent's view 14 s, and 91% of all database time went to one pattern.
-- To ask "may the caller see class X?", the access functions walked every
-- enrollment in X and asked, for each enrolled student, "is this the
-- caller?" - and that question found the caller's student row by user_id,
-- which had no index, so every step read the whole students table. Lists
-- run the check once per row, so a list's cost grew with the school's size.
--
-- The rules are unchanged. Each check now starts from the caller: their own
-- student rows (for a student) or their own verified guardian links (for a
-- parent) - usually one - and asks the same function as before whether that
-- one is enrolled in X. That is logically the same question: the functions
-- only ever answered yes for a student row belonging to the caller, or a
-- verified link held by the caller, enrolled in X.
--
-- students.user_id gets the index every "which student is this user" lookup
-- needs (guardian_links already has one on guardian_id for verified links).

create index if not exists students_user_live_idx
  on public.students (user_id) where user_id is not null and deleted_at is null;

CREATE OR REPLACE FUNCTION private.can_view_classroom(target_classroom uuid)
 RETURNS boolean
 LANGUAGE sql
 STABLE SECURITY DEFINER
 SET search_path TO ''
AS $function$
  select exists (
    select 1
    from public.classrooms c
    where c.id = target_classroom
      and (
        private.is_school_admin(c.school_id)
        or private.is_class_staff(c.id)
        or exists (
          select 1 from public.students own_st
          where own_st.user_id = auth.uid() and own_st.deleted_at is null
            and private.is_enrolled_student(c.id, own_st.id)
        )
        or exists (
          select 1 from public.guardian_links own_gl
          where own_gl.guardian_id = auth.uid() and own_gl.status = 'verified'
            and private.is_verified_guardian(c.id, own_gl.student_id)
        )
      )
  );
$function$;

CREATE OR REPLACE FUNCTION private.can_view_resource_publication(target_publication uuid)
 RETURNS boolean
 LANGUAGE sql
 STABLE SECURITY DEFINER
 SET search_path TO ''
AS $function$
  select private.notebook_reader_allowed((select school_id from public.resource_publications where id = target_publication)) and exists (
    select 1
    from public.resource_publications rp
    join public.resource_versions rv
      on rv.id = rp.resource_version_id and rv.school_id = rp.school_id
    join public.resources r
      on r.id = rv.resource_id and r.school_id = rv.school_id
    left join public.file_objects f
      on f.id = rv.file_object_id and f.school_id = rv.school_id
    where rp.id = target_publication
      and (
        private.is_school_admin(rp.school_id)
        or private.has_active_membership(
          rp.school_id,
          array['teacher']::public.app_role[]
        )
        or (
          rp.state = 'published'
          and rp.published_at is not null
          and rp.withdrawn_at is null
          and r.state = 'published'
          and r.deleted_at is null
          and (rv.file_object_id is null or (
            f.scan_state = 'clean' and f.deleted_at is null
          ))
          and (
            (
              rp.audience in ('students', 'both')
              and (
                (rp.classroom_id is null and private.has_active_membership(
                  rp.school_id,
                  array['student']::public.app_role[]
                ))
                or exists (
                  select 1 from public.students own_st
          where own_st.user_id = auth.uid() and own_st.deleted_at is null
            and private.is_enrolled_student(rp.classroom_id, own_st.id)
                )
              )
            )
            or (
              rp.audience in ('guardians', 'both')
              and (
                (rp.classroom_id is null and private.has_active_membership(
                  rp.school_id,
                  array['parent', 'guardian']::public.app_role[]
                ))
                or exists (
                  select 1 from public.guardian_links own_gl
          where own_gl.guardian_id = auth.uid() and own_gl.status = 'verified'
            and private.is_verified_guardian(rp.classroom_id, own_gl.student_id)
                )
              )
            )
          )
        )
      )
  );
$function$;

CREATE OR REPLACE FUNCTION private.file051_authorize_download(p_file_id uuid)
 RETURNS jsonb
 LANGUAGE plpgsql
 STABLE SECURITY DEFINER
 SET search_path TO ''
AS $function$
declare
  decision jsonb;
begin
  decision := private.file051_authorize_download_pre_guardian_reads(p_file_id);
  if coalesce((decision->>'allowed')::boolean, false)
    or coalesce(decision->>'reason', '') = 'invalid_resource' then
    return decision;
  end if;

  if exists (
    select 1 from public.file_bindings b
    left join public.assignments asg on asg.id = b.assignment_id
    left join public.assessments ass on ass.id = b.assessment_id
    where b.file_object_id = p_file_id
      and (
        (asg.id is not null and asg.state = 'published' and asg.deleted_at is null
          and exists (select 1 from public.guardian_links own_gl
          where own_gl.guardian_id = auth.uid() and own_gl.status = 'verified'
            and private.is_linked_guardian(own_gl.student_id, asg.classroom_id)))
        or (ass.id is not null and ass.state = 'published' and ass.deleted_at is null
          and exists (select 1 from public.guardian_links own_gl
          where own_gl.guardian_id = auth.uid() and own_gl.status = 'verified'
            and private.is_linked_guardian(own_gl.student_id, ass.classroom_id)))
      )
  ) or exists (
    select 1 from public.file_bindings b
    join public.resource_publications rp on rp.resource_version_id = b.resource_version_id
    where b.file_object_id = p_file_id
      and rp.state = 'published' and rp.published_at is not null
      and rp.withdrawn_at is null and rp.classroom_id is not null
      and rp.audience in ('guardians', 'both')
      and exists (select 1 from public.guardian_links own_gl
          where own_gl.guardian_id = auth.uid() and own_gl.status = 'verified'
            and private.is_linked_guardian(own_gl.student_id, rp.classroom_id))
  ) then
    return jsonb_build_object('allowed', true,
      'schoolId', decision->'schoolId', 'reason', 'linked_guardian');
  end if;

  return decision;
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
                select 1 from public.students own_st
          where own_st.user_id = auth.uid() and own_st.deleted_at is null
            and private.is_enrolled_student(an.classroom_id, own_st.id)
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
                select 1 from public.guardian_links own_gl
          where own_gl.guardian_id = auth.uid() and own_gl.status = 'verified'
            and private.is_verified_guardian(an.classroom_id, own_gl.student_id)
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
            select 1 from public.students own_st
          where own_st.user_id = auth.uid() and own_st.deleted_at is null
            and private.is_enrolled_student(m.classroom_id, own_st.id)
          )
        )
        or (
          m.state = 'scheduled'
          and m.audience in ('guardians', 'both')
          and exists (
            select 1 from public.guardian_links own_gl
          where own_gl.guardian_id = auth.uid() and own_gl.status = 'verified'
            and private.is_verified_guardian(m.classroom_id, own_gl.student_id)
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

-- ---------------------------------------------------------------------------
-- Lists look only where the caller can see.
--
-- Each academic list scanned every row of the school in id order and ran an
-- access function on each until it had a page: a student with 15 grades
-- among a school's 7,500 paid for 7,500 checks (17 s measured). The lists
-- now test, first and cheaply, whether a row belongs to a class the caller
-- teaches or to one of the caller's own student rows or children (worked
-- out once per call); the same access check then decides every row that
-- remains. A guardian's view of a child's work scanned every assignment in
-- the database; it now looks only at the child's classes.
-- ---------------------------------------------------------------------------
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
  -- Within one call the functions read one snapshot, so the answer for a
  -- class is the same on every row of that class: ask once per class.
  v_staff_ok := array(select c from unnest(v_classes) c where private.is_class_staff(c));
  v_view_ok := array(select c from unnest(v_classes) c where private.can_view_classroom(c));
  v_pairs_ok := array(
    select e.classroom_id::text || '/' || e.student_id::text from public.enrollments e
    where e.student_id = any(v_mine) and e.active
      and private.can_view_class_student(e.classroom_id, e.student_id));
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
            or (ls.classroom_id = any(v_staff_ok) and private.can_view_class_student(ls.classroom_id,ar.student_id)))
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
$function$;
CREATE OR REPLACE FUNCTION private.api041_query_pre_roster_shape(p_operation text, p_resource_id uuid, p_input jsonb)
 RETURNS jsonb
 LANGUAGE plpgsql
 STABLE SECURITY DEFINER
 SET search_path TO ''
AS $function$
declare
  v_child uuid;
  v_child_classes uuid[];
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
      select coalesce(jsonb_agg(
          -- The builder reports the *caller's* submission. For a guardian
          -- that is always none; what they need is the child's.
          private.api041_assignment_json(x.id) || jsonb_build_object(
            'submissionId', su.id, 'submittedAt', su.submitted_at)
          order by x.id), '[]'), max(x.id::text)
        into result, next_pos
      from (
        select a.id from public.assignments a
        where a.state = 'published' and a.deleted_at is null
          and (pos is null or a.id > pos)
          and (v_class is null or a.classroom_id = v_class)
          and a.classroom_id = any(v_child_classes)
          and private.is_linked_guardian(v_child, a.classroom_id)
        order by a.id limit limit_rows
      ) x
      left join public.submissions su
        on su.assignment_id = x.id and su.student_id = v_child;

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
      select coalesce(jsonb_agg(private.api041_resource_json(x.id) order by x.id), '[]'),
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
      select coalesce(jsonb_agg(private.api041_grade_json(x.id) order by x.id), '[]'),
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
$function$;

-- ---------------------------------------------------------------------------
-- Notifications by recipient.
--
-- The unread badge and the notifications list read one person's in-app
-- deliveries; with no index on the recipient each read scanned every
-- delivery ever made (1,000,000 rows at 100 schools). The worker's fan-out
-- reads the last day's delivered notifications every ten seconds.
-- ---------------------------------------------------------------------------
create index if not exists notification_deliveries_inbox_idx
  on public.notification_deliveries (recipient_id, id desc) where channel = 'in_app';
create index if not exists notification_deliveries_unread_idx
  on public.notification_deliveries (recipient_id) where channel = 'in_app' and read_at is null;
create index if not exists notification_deliveries_fanout_idx
  on public.notification_deliveries (delivered_at) where channel = 'in_app' and state = 'sent';

-- A lesson's JSON reads its latest publication. The only index on the
-- version was partial (live publications), which this read cannot use, so
-- every lesson in a list scanned all publications (7.8 ms each measured).
create index if not exists resource_publications_version_latest_idx
  on public.resource_publications (resource_version_id, created_at desc);
