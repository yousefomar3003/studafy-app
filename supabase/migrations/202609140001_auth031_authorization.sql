-- AUTH-031 action/resource authorization decision surface.
--
-- The caller supplies an action and an opaque resource id, never a tenant.
-- Every branch resolves school_id from the stored resource and uses the same
-- private relationship helpers and state predicates as DB-021. Unknown
-- actions, absent resources and unauthenticated actors fail closed.
--
-- This function does not return data and grants no table access to the API
-- role. PostgreSQL RLS remains the final line of defence for every query.

create or replace function private.authz_authorize(
  p_action text,
  p_resource_id uuid
)
returns jsonb
language plpgsql
stable
security definer
set search_path = ''
as $$
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
$$;

alter function private.authz_authorize(text, uuid) owner to postgres;
revoke all on function private.authz_authorize(text, uuid)
from public, anon, authenticated, service_role, studafy_worker_runtime;
grant execute on function private.authz_authorize(text, uuid)
to studafy_api_runtime;
