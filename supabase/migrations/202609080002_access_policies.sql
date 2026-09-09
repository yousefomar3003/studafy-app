create or replace function public.can_access_classroom(target_classroom uuid)
returns boolean language sql stable security definer set search_path = '' as $$
  select exists (
    select 1 from public.classrooms c where c.id = target_classroom and (
      c.teacher_id = auth.uid()
      or exists (
        select 1 from public.enrollments e
        join public.students s on s.id=e.student_id
        where e.classroom_id=c.id and e.active and public.can_access_student(s.id)
      )
    )
  );
$$;

create or replace function public.is_class_teacher(target_classroom uuid)
returns boolean language sql stable security definer set search_path = '' as $$
  select exists (
    select 1 from public.classrooms c
    where c.id=target_classroom and c.teacher_id=auth.uid()
  );
$$;

create policy "schools read memberships" on public.schools for select
using (public.is_school_member(id));
create policy "terms read memberships" on public.terms for select
using (public.is_school_member(school_id));
create policy "classrooms read authorized" on public.classrooms for select
using (public.can_access_classroom(id));
create policy "enrollments read authorized" on public.enrollments for select
using (public.can_access_classroom(classroom_id));
create policy "sessions read authorized" on public.lesson_sessions for select
using (public.can_access_classroom(classroom_id));
create policy "materials read authorized" on public.lesson_materials for select
using (exists (
  select 1 from public.lesson_sessions s
  where s.id=session_id and public.can_access_classroom(s.classroom_id)
    and (s.filed_at is not null or public.is_class_teacher(s.classroom_id))
));
create policy "assignments read authorized" on public.assignments for select
using (public.can_access_classroom(classroom_id)
  and (state='published' or public.is_class_teacher(classroom_id)));
create policy "assessments read authorized" on public.assessments for select
using (public.can_access_classroom(classroom_id)
  and (state='published' or public.is_class_teacher(classroom_id)));
create policy "assessment questions teacher or practice" on public.assessment_questions for select
using (exists (
  select 1 from public.assessments a where a.id=assessment_id
    and public.can_access_classroom(a.classroom_id)
    and (public.is_class_teacher(a.classroom_id)
      or (a.delivery='practice' and a.state='published'))
));
create policy "announcements read audience" on public.announcements for select
using (public.is_school_member(school_id) and (
  classroom_id is null or public.can_access_classroom(classroom_id)
));
create policy "meetings read authorized" on public.meetings for select
using (public.can_access_classroom(classroom_id));
create policy "grading drafts teacher only" on public.ai_grading_drafts for select
using (exists (
  select 1 from public.grade_results g
  join public.assessments a on a.id=g.assessment_id
  where g.id=grade_result_id and public.is_class_teacher(a.classroom_id)
));
create policy "suggestions teacher only" on public.question_suggestions for select
using (exists (
  select 1 from public.ai_grading_drafts d
  join public.grade_results g on g.id=d.grade_result_id
  join public.assessments a on a.id=g.assessment_id
  where d.id=draft_id and public.is_class_teacher(a.classroom_id)
));
create policy "audit actors read own" on public.audit_events for select
using (actor_id = auth.uid());

-- Safe client-authored drafts. Publication, grade changes, guardian
-- verification, recipient expansion, and AI review stay in audited functions.
create policy "teachers create own class sessions" on public.lesson_sessions for insert
with check (public.is_class_teacher(classroom_id));
create policy "teachers update own class sessions" on public.lesson_sessions for update
using (public.is_class_teacher(classroom_id)) with check (public.is_class_teacher(classroom_id));
create policy "teachers create own materials" on public.lesson_materials for insert
with check (created_by=auth.uid() and exists (
  select 1 from public.lesson_sessions s
  where s.id=session_id and public.is_class_teacher(s.classroom_id)
));
create policy "teachers create assignment drafts" on public.assignments for insert
with check (created_by=auth.uid() and state='draft' and public.is_class_teacher(classroom_id));
create policy "teachers edit assignment drafts" on public.assignments for update
using (created_by=auth.uid() and state='draft' and public.is_class_teacher(classroom_id))
with check (created_by=auth.uid() and state='draft' and public.is_class_teacher(classroom_id));
create policy "students submit own work" on public.submissions for insert
with check (exists (
  select 1 from public.students s
  join public.assignments a on a.id=assignment_id
  join public.enrollments e on e.classroom_id=a.classroom_id and e.student_id=s.id
  where s.id=student_id and s.user_id=auth.uid() and e.active and a.state='published'
));
create policy "students update own work" on public.submissions for update
using (exists (select 1 from public.students s where s.id=student_id and s.user_id=auth.uid()))
with check (exists (select 1 from public.students s where s.id=student_id and s.user_id=auth.uid()));

revoke all on public.ai_grading_drafts from anon, authenticated;
revoke all on public.question_suggestions from anon, authenticated;
grant select on public.ai_grading_drafts, public.question_suggestions to authenticated;
