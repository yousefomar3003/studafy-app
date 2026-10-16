-- Capacity (docs/capacity/2026-10-16.md, "Next" 2): study_lesson decides
-- access in its own query.
--
-- study_lesson is the lesson the AI study tools and study notebooks read:
-- the version currently published to a class the caller can see, newest
-- publication first. Through the API it was about 5% of database time. It
-- asked private.can_view_resource_publication of each candidate
-- publication, and that function is a chain of SQL functions that cannot be
-- inlined (each is SECURITY DEFINER with its own search_path):
-- notebook_reader_allowed, is_school_admin and has_active_membership (each
-- with is_active_user), then the caller's student records with
-- is_enrolled_student (is_active_user and has_active_membership again) and
-- the caller's guardian links with is_verified_guardian (the same again).
-- About ten separately planned queries for one decision, on every call.
--
-- In PostgreSQL 17 a SQL function's queries are planned again on every
-- top-level call, so each request paid that planning too.
--
-- study_lesson is now a plpgsql function, whose plans are kept for the life
-- of the connection, and it decides access itself, once per call: it finds
-- the caller's facts first (are they an active user; the schools where they
-- are school admin or teacher; the classes they are enrolled in; the
-- classes of children they are a verified guardian of), each by its own
-- index from the caller's id, then picks the newest publication allowed by
-- them, from the same candidates in the same order as before. Restated for
-- this path, where the publication is already published, not withdrawn,
-- for a class, and of the current version of a published, live lesson:
--
--   the caller is an active user (is_active_user: a live, active profile;
--   every branch of the old rule required it, and it implies
--   notebook_reader_allowed's signed-in check), and either
--   - holds an active membership as school_admin or teacher in the
--     publication's school (the old rule's is_school_admin and
--     has_active_membership(teacher) branches, which already gave school
--     admins this; nothing is added for them), or
--   - the publication has a publish time, the version's file (if any) is
--     clean and not deleted, and
--     - for students or both: the caller has a live student record with an
--       active, current enrolment in the class (active class, active
--       term) and an active student membership in the enrolment's school
--       (is_enrolled_student), or
--     - for guardians or both: the caller has a verified, unexpired link
--       to a child with such an enrolment in the class and an active
--       parent or guardian membership in the link's school
--       (is_verified_guardian; the old outer test for a verified link is
--       implied by the inner one).
--
-- Each of the caller's sets is exactly the old per-publication test asked
-- of every class or school at once, so membership in the set is the same
-- decision. The old rule's branches for publications without a class are
-- not restated: study_lesson never considers those. The school equalities of
-- the old joins (version and lesson in the publication's school, the file
-- in the version's school) are kept, though the composite foreign keys
-- already guarantee them.
--
-- Same decisions, proven before shipping like fixes 1-6
-- (docs/capacity/2026-10-17.md, scripts/scale/proof/study-lesson-
-- differential.sql). can_view_resource_publication itself is unchanged and
-- still used by the row-level policies and the other readers.

create or replace function private.study_lesson(p_resource uuid)
returns jsonb language plpgsql stable security definer set search_path = '' as $$
declare
  v_uid uuid := auth.uid();
  -- The schools where the caller is school admin or teacher.
  v_staff_schools uuid[];
  -- The classes the caller is enrolled in as a student (is_enrolled_student
  -- for one of their live student records).
  v_student_classes uuid[];
  -- The classes of the children the caller is a verified guardian of
  -- (is_verified_guardian for one of their verified links).
  v_guardian_classes uuid[];
begin
  -- is_active_user, once: every branch of the rule requires it.
  if v_uid is null or not exists (
      select 1 from public.profiles p
      where p.id = v_uid and p.status = 'active' and p.deleted_at is null) then
    return null;
  end if;

  -- has_active_membership(school, school_admin or teacher).
  v_staff_schools := array(
    select m.school_id
    from public.memberships m
    join public.schools s on s.id = m.school_id
    where m.user_id = v_uid
      and m.active and m.status = 'active'
      and m.valid_from <= now()
      and (m.valid_until is null or m.valid_until > now())
      and s.status = 'active' and s.deleted_at is null
      and m.role in ('school_admin', 'teacher'));

  -- A live student record of the caller's, actively enrolled in the class
  -- today, the class and its term active, and an active student membership
  -- in the enrolment's school.
  v_student_classes := array(
    select e.classroom_id
    from public.students st
    join public.enrollments e
      on e.student_id = st.id and e.school_id = st.school_id
    join public.classrooms c
      on c.id = e.classroom_id and c.school_id = e.school_id
    join public.terms t
      on t.id = c.term_id and t.school_id = c.school_id
    where st.user_id = v_uid
      and st.deleted_at is null
      and e.active and e.status = 'active'
      and e.starts_on <= current_date
      and (e.ends_on is null or e.ends_on >= current_date)
      and c.status = 'active' and t.status = 'active'
      and exists (
        select 1
        from public.memberships m
        join public.schools s on s.id = m.school_id
        where m.school_id = e.school_id
          and m.user_id = v_uid
          and m.active and m.status = 'active'
          and m.valid_from <= now()
          and (m.valid_until is null or m.valid_until > now())
          and s.status = 'active' and s.deleted_at is null
          and m.role = 'student'));

  -- A verified, unexpired link of the caller's to a child actively enrolled
  -- in the class today, the class and its term active, and an active parent
  -- or guardian membership in the link's school.
  v_guardian_classes := array(
    select e.classroom_id
    from public.guardian_links gl
    join public.enrollments e
      on e.student_id = gl.student_id and e.school_id = gl.school_id
    join public.classrooms c
      on c.id = e.classroom_id and c.school_id = e.school_id
    join public.terms t
      on t.id = c.term_id and t.school_id = c.school_id
    where gl.guardian_id = v_uid
      and gl.status = 'verified'
      and (gl.expires_at is null or gl.expires_at > now())
      and e.active and e.status = 'active'
      and e.starts_on <= current_date
      and (e.ends_on is null or e.ends_on >= current_date)
      and c.status = 'active' and t.status = 'active'
      and exists (
        select 1
        from public.memberships m
        join public.schools s on s.id = m.school_id
        where m.school_id = gl.school_id
          and m.user_id = v_uid
          and m.active and m.status = 'active'
          and m.valid_from <= now()
          and (m.valid_until is null or m.valid_until > now())
          and s.status = 'active' and s.deleted_at is null
          and m.role in ('parent', 'guardian')));

  return (
    select jsonb_build_object(
      'resourceId', r.id, 'versionId', rv.id, 'schoolId', r.school_id,
      'classroomId', rp.classroom_id, 'title', r.title, 'body', rv.body)
    from public.resources r
    join public.resource_versions rv
      on rv.resource_id = r.id and rv.version = r.current_version
    join public.resource_publications rp on rp.resource_version_id = rv.id
    left join public.file_objects f
      on f.id = rv.file_object_id and f.school_id = rv.school_id
    where r.id = p_resource and r.deleted_at is null and r.state = 'published'
      and rp.state = 'published' and rp.withdrawn_at is null
      and rp.classroom_id is not null
      and rv.school_id = rp.school_id and r.school_id = rv.school_id
      and (
        rp.school_id = any(v_staff_schools)
        or (
          rp.published_at is not null
          and (rv.file_object_id is null or (
            f.scan_state = 'clean' and f.deleted_at is null))
          and (
            (rp.audience in ('students', 'both')
              and rp.classroom_id = any(v_student_classes))
            or (rp.audience in ('guardians', 'both')
              and rp.classroom_id = any(v_guardian_classes))
          )
        )
      )
    order by rp.published_at desc nulls last
    limit 1);
end;
$$;

revoke all on function private.study_lesson(uuid)
  from public, anon, authenticated, service_role, studafy_worker_runtime,
  studafy_api_runtime;
alter function private.study_lesson(uuid) owner to postgres;
