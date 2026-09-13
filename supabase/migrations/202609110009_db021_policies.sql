-- DB-021 complete policy cutover. Client writes are deliberately absent;
-- bounded RPCs and audited server functions own every mutation.

do $db021$
declare
  policy_row record;
begin
  for policy_row in
    select schemaname, tablename, policyname
    from pg_policies
    where schemaname = 'public'
  loop
    execute format(
      'drop policy if exists %I on %I.%I',
      policy_row.policyname,
      policy_row.schemaname,
      policy_row.tablename
    );
  end loop;
end
$db021$;

create policy db021_profiles_select_self
on public.profiles for select to authenticated
using (id = auth.uid() and private.is_active_user());

create policy db021_memberships_select_self
on public.memberships for select to authenticated
using (
  user_id = auth.uid()
  and private.has_active_membership(school_id)
);

create policy db021_schools_select_member
on public.schools for select to authenticated
using (private.has_active_membership(id));

create policy db021_terms_select_member
on public.terms for select to authenticated
using (
  private.is_school_admin(school_id)
  or private.has_active_membership(
    school_id,
    array['teacher']::public.app_role[]
  )
  or (
    status = 'active'
    and private.has_active_membership(
      school_id,
      array['student', 'parent', 'guardian']::public.app_role[]
    )
  )
);

create policy db021_students_select_relationship
on public.students for select to authenticated
using (private.can_access_student(id));

create policy db021_guardian_links_select_relationship
on public.guardian_links for select to authenticated
using (
  private.is_school_admin(school_id)
  or guardian_id = auth.uid() and private.has_active_membership(
    school_id,
    array['parent', 'guardian']::public.app_role[]
  )
  or exists (
    select 1
    from public.students st
    where st.id = guardian_links.student_id
      and st.user_id = auth.uid()
      and private.has_active_membership(
        guardian_links.school_id,
        array['student']::public.app_role[]
      )
  )
  or exists (
    select 1
    from public.enrollments e
    where e.student_id = guardian_links.student_id
      and e.school_id = guardian_links.school_id
      and private.is_class_staff(e.classroom_id)
  )
);

create policy db021_classrooms_select_relationship
on public.classrooms for select to authenticated
using (private.can_view_classroom(id));

create policy db021_enrollments_select_exact_relationship
on public.enrollments for select to authenticated
using (private.can_view_class_student(classroom_id, student_id));

create policy db021_classroom_staff_select_class
on public.classroom_staff for select to authenticated
using (
  private.is_school_admin(school_id)
  or private.is_class_staff(classroom_id)
);

create policy db021_class_schedules_select_class
on public.class_schedules for select to authenticated
using (private.can_view_classroom(classroom_id));

create policy db021_lesson_sessions_select_class
on public.lesson_sessions for select to authenticated
using (
  private.is_school_admin(school_id)
  or private.is_class_staff(classroom_id)
  or (
    status = 'completed'
    and filed_at is not null
    and private.can_view_classroom(classroom_id)
  )
);

create policy db021_lesson_materials_select_class
on public.lesson_materials for select to authenticated
using (
  deleted_at is null
  and exists (
    select 1
    from public.lesson_sessions ls
    where ls.id = lesson_materials.session_id
      and ls.school_id = lesson_materials.school_id
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
);

create policy db021_assignments_select_class
on public.assignments for select to authenticated
using (
  private.is_school_admin(school_id)
  or private.is_class_staff(classroom_id)
  or (
    state = 'published'
    and published_at is not null
    and deleted_at is null
    and private.can_view_classroom(classroom_id)
  )
);

create policy db021_submissions_select_exact_relationship
on public.submissions for select to authenticated
using (
  private.has_active_membership(school_id)
  and exists (
    select 1
    from public.assignments a
    where a.id = submissions.assignment_id
      and a.school_id = submissions.school_id
      and private.can_view_class_student(a.classroom_id, submissions.student_id)
      and (
        private.is_school_admin(a.school_id)
        or private.is_class_staff(a.classroom_id)
        or (a.state = 'published' and a.deleted_at is null)
      )
  )
);

create policy db021_assessments_select_class
on public.assessments for select to authenticated
using (
  private.is_school_admin(school_id)
  or private.is_class_staff(classroom_id)
  or (
    state = 'published'
    and published_at is not null
    and deleted_at is null
    and private.can_view_classroom(classroom_id)
  )
);

create policy db021_assessment_questions_select_class
on public.assessment_questions for select to authenticated
using (
  exists (
    select 1
    from public.assessments a
    where a.id = assessment_questions.assessment_id
      and a.school_id = assessment_questions.school_id
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
  )
);

create policy db021_grade_results_select_exact_relationship
on public.grade_results for select to authenticated
using (
  private.has_active_membership(school_id)
  and exists (
    select 1
    from public.assessments a
    where a.id = grade_results.assessment_id
      and a.school_id = grade_results.school_id
      and private.can_view_class_student(a.classroom_id, grade_results.student_id)
      and (
        private.is_school_admin(a.school_id)
        or private.is_class_staff(a.classroom_id)
        or (
          grade_results.state = 'published'
          and grade_results.published_at is not null
        )
      )
  )
);

create policy db021_attendance_records_select_exact_relationship
on public.attendance_records for select to authenticated
using (
  private.has_active_membership(school_id)
  and exists (
    select 1
    from public.lesson_sessions ls
    where ls.id = attendance_records.session_id
      and ls.school_id = attendance_records.school_id
      and private.can_view_class_student(
        ls.classroom_id,
        attendance_records.student_id
      )
  )
);

create policy db021_wellbeing_events_select_visibility
on public.wellbeing_events for select to authenticated
using (private.can_view_wellbeing(id));

create policy db021_announcements_select_audience
on public.announcements for select to authenticated
using (
  state = 'published'
  and deleted_at is null
  and published_at is not null
  and (
    (created_by = auth.uid() and private.has_active_membership(school_id))
    or private.is_school_admin(school_id)
    or (
      private.has_active_membership(
        school_id,
        array['teacher']::public.app_role[]
      )
      and (classroom_id is null or private.is_class_staff(classroom_id))
    )
    or (
      audience in ('students', 'both')
      and (
        (
          classroom_id is null
          and private.has_active_membership(
            school_id,
            array['student']::public.app_role[]
          )
        )
        or exists (
          select 1 from public.enrollments e
          where e.classroom_id = announcements.classroom_id
            and private.is_enrolled_student(e.classroom_id, e.student_id)
        )
      )
    )
    or (
      audience in ('guardians', 'both')
      and (
        (
          classroom_id is null
          and private.has_active_membership(
            school_id,
            array['parent', 'guardian']::public.app_role[]
          )
        )
        or exists (
          select 1 from public.enrollments e
          where e.classroom_id = announcements.classroom_id
            and private.is_verified_guardian(e.classroom_id, e.student_id)
        )
      )
    )
  )
);

create policy db021_meetings_select_audience
on public.meetings for select to authenticated
using (
  (created_by = auth.uid() and private.has_active_membership(school_id))
  or private.is_school_admin(school_id)
  or private.is_class_staff(classroom_id)
  or (
    state = 'scheduled'
    and audience in ('students', 'both')
    and exists (
      select 1 from public.enrollments e
      where e.classroom_id = meetings.classroom_id
        and private.is_enrolled_student(e.classroom_id, e.student_id)
    )
  )
  or (
    state = 'scheduled'
    and audience in ('guardians', 'both')
    and exists (
      select 1 from public.enrollments e
      where e.classroom_id = meetings.classroom_id
        and private.is_verified_guardian(e.classroom_id, e.student_id)
    )
  )
);

create policy db021_meeting_deliveries_select_recipient_or_staff
on public.meeting_deliveries for select to authenticated
using (
  recipient_id = auth.uid()
  or exists (
    select 1 from public.meetings m
    where m.id = meeting_deliveries.meeting_id
      and m.school_id = meeting_deliveries.school_id
      and (
        private.is_school_admin(m.school_id)
        or private.is_class_staff(m.classroom_id)
      )
  )
);

create policy db021_notifications_select_self
on public.notifications for select to authenticated
using (user_id = auth.uid() and private.is_active_user());

create policy db021_subscription_entitlements_select_self
on public.subscription_entitlements for select to authenticated
using (user_id = auth.uid() and private.is_active_user());

create policy db021_consent_records_select_self
on public.consent_records for select to authenticated
using (user_id = auth.uid() and private.is_active_user());

create policy db021_practice_sessions_select_relationship
on public.practice_sessions for select to authenticated
using (
  private.is_school_admin(school_id)
  or private.is_class_staff(classroom_id)
  or private.is_enrolled_student(classroom_id, student_id)
);

create policy db021_resources_select_authorized
on public.resources for select to authenticated
using (private.can_view_resource(id));

create policy db021_resource_versions_select_authorized
on public.resource_versions for select to authenticated
using (private.can_view_resource_version(id));

create policy db021_resource_publications_select_authorized
on public.resource_publications for select to authenticated
using (private.can_view_resource_publication(id));

-- Deliberately policy-free client/service-only relations:
-- membership_events, submission_attempts, grade_result_events, file_objects,
-- file_bindings, upload_sessions, notification_outbox,
-- notification_deliveries, store_products, store_transactions, store_events,
-- entitlements, consent_policies, idempotency_records, conversations,
-- conversation_participants, messages, ai_grading_drafts,
-- question_suggestions, audit_events, and account_deletion_requests.
