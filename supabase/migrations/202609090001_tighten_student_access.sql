-- Teachers may only access students enrolled in a class they own. School-wide
-- access is never school-wide for an app user.
create or replace function public.can_access_student(target_student uuid)
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select exists (
    select 1
    from public.students s
    where s.id = target_student
      and (
        s.user_id = auth.uid()
        or exists (
          select 1 from public.guardian_links g
          where g.student_id = s.id
            and g.guardian_id = auth.uid()
            and g.status = 'verified'
        )
        or exists (
          select 1
          from public.enrollments e
          join public.classrooms c on c.id = e.classroom_id
          where e.student_id = s.id
            and e.active
            and c.teacher_id = auth.uid()
        )
      )
  );
$$;

revoke all on function public.can_access_student(uuid) from public;
grant execute on function public.can_access_student(uuid) to authenticated;

-- Resolve classroom access directly. Using can_access_student() here would let
-- a teacher who teaches a student in one classroom infer that student's other
-- classrooms.
create or replace function public.can_access_classroom(target_classroom uuid)
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select exists (
    select 1
    from public.classrooms c
    where c.id = target_classroom
      and (
        c.teacher_id = auth.uid()
        or exists (
          select 1
          from public.enrollments e
          join public.students s on s.id = e.student_id
          where e.classroom_id = c.id
            and e.active
            and s.user_id = auth.uid()
        )
        or exists (
          select 1
          from public.enrollments e
          join public.guardian_links g on g.student_id = e.student_id
          where e.classroom_id = c.id
            and e.active
            and g.guardian_id = auth.uid()
            and g.status = 'verified'
        )
      )
  );
$$;

revoke all on function public.can_access_classroom(uuid) from public;
grant execute on function public.can_access_classroom(uuid) to authenticated;

-- Audience is enforced for both class and school-wide communication.
drop policy if exists "announcements read audience" on public.announcements;
create policy "announcements read audience" on public.announcements for select
using (
  public.is_school_member(school_id)
  and (classroom_id is null or public.can_access_classroom(classroom_id))
  and (
    created_by = auth.uid()
    or (
      audience in ('students', 'both')
      and exists (
        select 1 from public.students s
        where s.school_id = announcements.school_id and s.user_id = auth.uid()
      )
    )
    or (
      audience in ('guardians', 'both')
      and exists (
        select 1
        from public.guardian_links g
        join public.students s on s.id = g.student_id
        where s.school_id = announcements.school_id
          and g.guardian_id = auth.uid()
          and g.status = 'verified'
      )
    )
  )
);

drop policy if exists "meetings read authorized" on public.meetings;
create policy "meetings read authorized" on public.meetings for select
using (
  public.can_access_classroom(classroom_id)
  and (
    created_by = auth.uid()
    or (
      audience in ('students', 'both')
      and exists (
        select 1
        from public.enrollments e
        join public.students s on s.id = e.student_id
        where e.classroom_id = meetings.classroom_id
          and e.active
          and s.user_id = auth.uid()
      )
    )
    or (
      audience in ('guardians', 'both')
      and exists (
        select 1
        from public.enrollments e
        join public.guardian_links g on g.student_id = e.student_id
        where e.classroom_id = meetings.classroom_id
          and e.active
          and g.guardian_id = auth.uid()
          and g.status = 'verified'
      )
    )
  )
);

-- Clients may upload only into their own papers/ or coach/ namespace. Reads
-- are delivered as short-lived signed URLs by audited server functions.
create policy "private uploads own namespace" on storage.objects for insert
to authenticated
with check (
  bucket_id = 'private-school-files'
  and (storage.foldername(name))[1] in ('papers', 'coach')
  and (storage.foldername(name))[2] = auth.uid()::text
);
