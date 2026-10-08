-- Security audit 2026-10-08: a wellbeing note's author keeps access only
-- while they still belong to its school.
--
-- private.can_view_wellbeing let `created_by = auth.uid()` through on its
-- own. A teacher whose membership was revoked and whose class assignment
-- had ended could therefore still read every note they had written -
-- safeguarding-restricted ones included - straight from PostgREST
-- (`wellbeing_events` is readable by `authenticated` under this policy).
-- Reproduced on a throwaway stack before this change.
--
-- The author now also needs an active membership in the note's school.
-- Every other branch is unchanged. Same name, arguments, owner and grants:
-- `create or replace` keeps the existing EXECUTE grants.

create or replace function private.can_view_wellbeing(target_event uuid)
returns boolean
language sql
stable security definer
set search_path = ''
as $$
  select exists (
    select 1
    from public.wellbeing_events w
    where w.id = target_event
      and (
        private.is_school_admin(w.school_id)
        or (
          w.created_by = auth.uid()
          and private.has_active_membership(w.school_id)
        )
        or (
          w.visibility <> 'safeguarding_restricted'
          and (
            (w.classroom_id is not null and private.is_class_staff(w.classroom_id))
            or (
              w.classroom_id is null and exists (
                select 1
                from public.enrollments e
                where e.student_id = w.student_id
                  and e.active
                  and e.status = 'active'
                  and private.is_class_staff(e.classroom_id)
              )
            )
          )
        )
        or (
          w.visibility in ('guardian_shared', 'student_guardian_shared')
          and exists (
            select 1
            from public.enrollments e
            where e.student_id = w.student_id
              and (w.classroom_id is null or e.classroom_id = w.classroom_id)
              and private.is_verified_guardian(e.classroom_id, e.student_id)
          )
        )
        or (
          w.visibility = 'student_guardian_shared'
          and exists (
            select 1
            from public.enrollments e
            where e.student_id = w.student_id
              and (w.classroom_id is null or e.classroom_id = w.classroom_id)
              and private.is_enrolled_student(e.classroom_id, e.student_id)
          )
        )
      )
  );
$$;
