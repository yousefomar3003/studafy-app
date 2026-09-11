-- DB-021 authorization foundation. The private schema is intentionally absent
-- from the Data API schema list. Helpers are SECURITY DEFINER so policy
-- evaluation does not recurse through the protected relations they inspect.

create schema if not exists private authorization postgres;
revoke all on schema private from public, anon, authenticated, service_role;

do $db021$
begin
  if not exists (select 1 from pg_roles where rolname = 'studafy_api_runtime') then
    create role studafy_api_runtime nologin noinherit nocreatedb nocreaterole
      noreplication nobypassrls;
  end if;
  if not exists (select 1 from pg_roles where rolname = 'studafy_worker_runtime') then
    create role studafy_worker_runtime nologin noinherit nocreatedb nocreaterole
      noreplication nobypassrls;
  end if;
end
$db021$;

revoke all on schema public, private
from studafy_api_runtime, studafy_worker_runtime;

create or replace function private.is_active_user()
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select auth.uid() is not null and exists (
    select 1
    from public.profiles p
    where p.id = auth.uid()
      and p.status = 'active'
      and p.deleted_at is null
  );
$$;

create or replace function private.has_active_membership(
  target_school uuid,
  allowed_roles public.app_role[] default null
)
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select private.is_active_user() and exists (
    select 1
    from public.memberships m
    join public.schools s on s.id = m.school_id
    where m.school_id = target_school
      and m.user_id = auth.uid()
      and m.active
      and m.status = 'active'
      and m.valid_from <= now()
      and (m.valid_until is null or m.valid_until > now())
      and s.status = 'active'
      and s.deleted_at is null
      and (allowed_roles is null or m.role = any(allowed_roles))
  );
$$;

create or replace function private.is_school_admin(target_school uuid)
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select private.has_active_membership(
    target_school,
    array['school_admin']::public.app_role[]
  );
$$;

create or replace function private.is_class_staff(target_classroom uuid)
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select private.is_active_user() and exists (
    select 1
    from public.classroom_staff cs
    join public.memberships m
      on m.id = cs.membership_id
     and m.school_id = cs.school_id
     and m.user_id = cs.user_id
    join public.schools s on s.id = cs.school_id
    where cs.classroom_id = target_classroom
      and cs.user_id = auth.uid()
      and cs.status = 'active'
      and cs.starts_at <= now()
      and (cs.ends_at is null or cs.ends_at > now())
      and m.active
      and m.status = 'active'
      and m.valid_from <= now()
      and (m.valid_until is null or m.valid_until > now())
      and m.role in ('teacher', 'school_admin')
      and s.status = 'active'
      and s.deleted_at is null
  );
$$;

create or replace function private.is_enrolled_student(
  target_classroom uuid,
  target_student uuid
)
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select private.is_active_user() and exists (
    select 1
    from public.enrollments e
    join public.students st
      on st.id = e.student_id and st.school_id = e.school_id
    join public.classrooms c
      on c.id = e.classroom_id and c.school_id = e.school_id
    join public.terms t
      on t.id = c.term_id and t.school_id = c.school_id
    where e.classroom_id = target_classroom
      and e.student_id = target_student
      and st.user_id = auth.uid()
      and st.deleted_at is null
      and e.active
      and e.status = 'active'
      and e.starts_on <= current_date
      and (e.ends_on is null or e.ends_on >= current_date)
      and c.status = 'active'
      and t.status = 'active'
      and private.has_active_membership(
        e.school_id,
        array['student']::public.app_role[]
      )
  );
$$;

create or replace function private.is_verified_guardian(
  target_classroom uuid,
  target_student uuid
)
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select private.is_active_user() and exists (
    select 1
    from public.guardian_links gl
    join public.enrollments e
      on e.student_id = gl.student_id and e.school_id = gl.school_id
    join public.classrooms c
      on c.id = e.classroom_id and c.school_id = e.school_id
    join public.terms t
      on t.id = c.term_id and t.school_id = c.school_id
    where e.classroom_id = target_classroom
      and gl.student_id = target_student
      and gl.guardian_id = auth.uid()
      and gl.status = 'verified'
      and (gl.expires_at is null or gl.expires_at > now())
      and e.active
      and e.status = 'active'
      and e.starts_on <= current_date
      and (e.ends_on is null or e.ends_on >= current_date)
      and c.status = 'active'
      and t.status = 'active'
      and private.has_active_membership(
        gl.school_id,
        array['parent', 'guardian']::public.app_role[]
      )
  );
$$;

create or replace function private.can_view_classroom(target_classroom uuid)
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select exists (
    select 1
    from public.classrooms c
    where c.id = target_classroom
      and (
        private.is_school_admin(c.school_id)
        or private.is_class_staff(c.id)
        or exists (
          select 1
          from public.enrollments e
          where e.classroom_id = c.id
            and private.is_enrolled_student(c.id, e.student_id)
        )
        or exists (
          select 1
          from public.enrollments e
          where e.classroom_id = c.id
            and private.is_verified_guardian(c.id, e.student_id)
        )
      )
  );
$$;

create or replace function private.can_view_class_student(
  target_classroom uuid,
  target_student uuid
)
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select exists (
    select 1
    from public.enrollments e
    where e.classroom_id = target_classroom
      and e.student_id = target_student
      and e.active
      and e.status = 'active'
      and e.starts_on <= current_date
      and (e.ends_on is null or e.ends_on >= current_date)
      and (
        private.is_school_admin(e.school_id)
        or private.is_class_staff(e.classroom_id)
        or private.is_enrolled_student(e.classroom_id, e.student_id)
        or private.is_verified_guardian(e.classroom_id, e.student_id)
      )
  );
$$;

create or replace function private.can_access_student(target_student uuid)
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select exists (
    select 1
    from public.students st
    where st.id = target_student
      and st.deleted_at is null
      and (
        private.is_school_admin(st.school_id)
        or (
          st.user_id = auth.uid()
          and private.has_active_membership(
            st.school_id,
            array['student']::public.app_role[]
          )
        )
        or exists (
          select 1
          from public.guardian_links gl
          where gl.student_id = st.id
            and gl.guardian_id = auth.uid()
            and gl.status = 'verified'
            and (gl.expires_at is null or gl.expires_at > now())
            and private.has_active_membership(
              gl.school_id,
              array['parent', 'guardian']::public.app_role[]
            )
        )
        or exists (
          select 1
          from public.enrollments e
          where e.student_id = st.id
            and e.active
            and e.status = 'active'
            and private.is_class_staff(e.classroom_id)
        )
      )
  );
$$;

create or replace function private.can_view_wellbeing(target_event uuid)
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select exists (
    select 1
    from public.wellbeing_events w
    where w.id = target_event
      and (
        private.is_school_admin(w.school_id)
        or w.created_by = auth.uid()
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

create or replace function private.can_view_resource_publication(
  target_publication uuid
)
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select exists (
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
                  select 1 from public.enrollments e
                  where e.classroom_id = rp.classroom_id
                    and private.is_enrolled_student(e.classroom_id, e.student_id)
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
                  select 1 from public.enrollments e
                  where e.classroom_id = rp.classroom_id
                    and private.is_verified_guardian(e.classroom_id, e.student_id)
                )
              )
            )
          )
        )
      )
  );
$$;

create or replace function private.can_view_resource_version(target_version uuid)
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select exists (
    select 1
    from public.resource_versions rv
    where rv.id = target_version
      and (
        private.is_school_admin(rv.school_id)
        or private.has_active_membership(
          rv.school_id,
          array['teacher']::public.app_role[]
        )
        or exists (
          select 1 from public.resource_publications rp
          where rp.resource_version_id = rv.id
            and private.can_view_resource_publication(rp.id)
        )
      )
  );
$$;

create or replace function private.can_view_resource(target_resource uuid)
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select exists (
    select 1
    from public.resources r
    where r.id = target_resource
      and (
        private.is_school_admin(r.school_id)
        or private.has_active_membership(
          r.school_id,
          array['teacher']::public.app_role[]
        )
        or exists (
          select 1
          from public.resource_versions rv
          where rv.resource_id = r.id
            and private.can_view_resource_version(rv.id)
        )
      )
  );
$$;

alter function private.is_active_user() owner to postgres;
alter function private.has_active_membership(uuid, public.app_role[]) owner to postgres;
alter function private.is_school_admin(uuid) owner to postgres;
alter function private.is_class_staff(uuid) owner to postgres;
alter function private.is_enrolled_student(uuid, uuid) owner to postgres;
alter function private.is_verified_guardian(uuid, uuid) owner to postgres;
alter function private.can_view_classroom(uuid) owner to postgres;
alter function private.can_view_class_student(uuid, uuid) owner to postgres;
alter function private.can_access_student(uuid) owner to postgres;
alter function private.can_view_wellbeing(uuid) owner to postgres;
alter function private.can_view_resource_publication(uuid) owner to postgres;
alter function private.can_view_resource_version(uuid) owner to postgres;
alter function private.can_view_resource(uuid) owner to postgres;

revoke all on all functions in schema private
from public, anon, authenticated, service_role;
grant usage on schema private to authenticated;
grant execute on function private.is_active_user(),
  private.has_active_membership(uuid, public.app_role[]),
  private.is_school_admin(uuid),
  private.is_class_staff(uuid),
  private.is_enrolled_student(uuid, uuid),
  private.is_verified_guardian(uuid, uuid),
  private.can_view_classroom(uuid),
  private.can_view_class_student(uuid, uuid),
  private.can_access_student(uuid),
  private.can_view_wellbeing(uuid),
  private.can_view_resource_publication(uuid),
  private.can_view_resource_version(uuid),
  private.can_view_resource(uuid)
to authenticated;

alter default privileges for role postgres in schema private
  revoke execute on functions from public;
alter default privileges for role postgres in schema private
  revoke all on tables from public, anon, authenticated, service_role;
alter default privileges for role postgres in schema private
  revoke all on sequences from public, anon, authenticated, service_role;
