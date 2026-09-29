-- A guardian reads their child's schoolwork on the strength of the link.
--
-- Guardians link to a child by the child's Studafy ID. That produces a
-- verified guardian_links row and nothing else - no memberships row - which
-- is the ordinary case, not an edge case. But every academic read required a
-- membership twice over: the authorization decision leaned on
-- has_active_membership / can_access_student / is_verified_guardian (all of
-- which demand a parent or guardian membership), and api041_query refused any
-- caller without a tenant membership before looking at the request. So a
-- linked parent's Learning tab failed on every feed.
--
-- 202609250003 settled the rule for acting on a child's behalf: the verified,
-- unexpired link to a child with a live enrolment is the authority
-- (private.is_linked_guardian). This applies the same rule to reading, for an
-- explicit allowlist of feeds a parent follows:
--
--   assignments, assessments                   - published only, and only in
--                                                classes the child is in;
--   class material                             - likewise, and only what the
--                                                teacher shared with guardians;
--   grades                                     - the child's, published only;
--   attendance                                 - the child's.
--
-- Wellbeing is deliberately absent: those records can hold concerns about the
-- home, and nothing here changes who may read them.
--
-- Also, on the same rule: a guardian may start an upload in the child's
-- school (the upload itself still checks the child and purpose), and may open
-- files the teacher shared with the child's class.
--
-- Every read names the child (studentId) and is served only for that child.
-- Callers with a membership are untouched: the guardian path runs only when
-- the ordinary path has nothing for them.

-- ---------------------------------------------------------------------------
-- 1. The decision: a list scoped to one's own linked child is allowed.
-- ---------------------------------------------------------------------------
do $$ begin
  if not exists (
    select 1 from pg_proc p join pg_namespace n on n.oid = p.pronamespace
    where n.nspname = 'private' and p.proname = 'authz_authorize_pre_guardian_reads'
  ) then
    alter function private.authz_authorize(text, uuid)
      rename to authz_authorize_pre_guardian_reads;
  end if;
end $$;

create or replace function private.authz_authorize(
  p_action text, p_resource_id uuid)
returns jsonb language plpgsql stable security definer set search_path = '' as $$
declare
  decision jsonb;
  sid uuid;
begin
  decision := private.authz_authorize_pre_guardian_reads(p_action, p_resource_id);
  if coalesce((decision->>'allowed')::boolean, false)
    or p_action not in ('assignment.list', 'assessment.list', 'resource.list',
      'grade_result.list', 'attendance_record.list', 'upload.intent.create')
    or auth.uid() is null or p_resource_id is null then
    return decision;
  end if;

  -- Starting an upload names only the school. A guardian's standing there is
  -- a verified, unexpired link to a child enrolled in it - the same test
  -- file050_authorize_target applies to the upload itself, which then checks
  -- the exact child and purpose.
  if p_action = 'upload.intent.create' then
    if exists (
      select 1 from public.guardian_links gl
      join public.enrollments e on e.student_id = gl.student_id
        and e.school_id = gl.school_id and e.active and e.status = 'active'
      where gl.school_id = p_resource_id and gl.guardian_id = auth.uid()
        and gl.status = 'verified'
        and (gl.expires_at is null or gl.expires_at > now())
    ) then
      return jsonb_build_object('allowed', true, 'school_id', p_resource_id,
        'reason', 'linked_guardian');
    end if;
    return decision;
  end if;

  -- The resource is the child named in the request. Anything else - a
  -- school, a class - keeps the ordinary decision.
  select st.school_id into sid
  from public.students st
  where st.id = p_resource_id and st.deleted_at is null;
  if sid is null or not private.is_linked_guardian(p_resource_id) then
    return decision;
  end if;
  return jsonb_build_object('allowed', true, 'school_id', sid, 'reason', 'linked_guardian');
end;
$$;

alter function private.authz_authorize(text, uuid) owner to postgres;
alter function private.authz_authorize_pre_guardian_reads(text, uuid) owner to postgres;
revoke all on function private.authz_authorize_pre_guardian_reads(text, uuid)
  from public, anon, authenticated, service_role, studafy_worker_runtime,
  studafy_api_runtime;
revoke all on function private.authz_authorize(text, uuid)
  from public, anon, authenticated, service_role, studafy_worker_runtime;
grant execute on function private.authz_authorize(text, uuid)
  to studafy_api_runtime;

-- ---------------------------------------------------------------------------
-- 2. The reads.
-- ---------------------------------------------------------------------------
do $$ begin
  if not exists (
    select 1 from pg_proc p join pg_namespace n on n.oid = p.pronamespace
    where n.nspname = 'private' and p.proname = 'api041_query_pre_guardian_reads'
  ) then
    alter function private.api041_query(text, uuid, jsonb)
      rename to api041_query_pre_guardian_reads;
  end if;
end $$;

create or replace function private.api041_query(
  p_operation text, p_resource_id uuid, p_input jsonb)
returns jsonb language plpgsql stable security definer set search_path = '' as $$
declare
  v_child uuid;
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
$$;

alter function private.api041_query(text, uuid, jsonb) owner to postgres;
alter function private.api041_query_pre_guardian_reads(text, uuid, jsonb)
  owner to postgres;
revoke all on function private.api041_query_pre_guardian_reads(text, uuid, jsonb)
  from public, anon, authenticated, service_role, studafy_worker_runtime,
  studafy_api_runtime;
revoke all on function private.api041_query(text, uuid, jsonb)
  from public, anon, authenticated, service_role, studafy_worker_runtime;
grant execute on function private.api041_query(text, uuid, jsonb)
  to studafy_api_runtime;

-- ---------------------------------------------------------------------------
-- 3. A guardian opens what the teacher shared with the child's class.
--
-- The existing rules reach guardians only through can_view_classroom and
-- can_view_resource_publication, both of which need a membership. These
-- mirror them on the link: material bound to published work in a class the
-- child is in, and class material published to guardians there.
-- ---------------------------------------------------------------------------
do $$ begin
  if not exists (
    select 1 from pg_proc p join pg_namespace n on n.oid = p.pronamespace
    where n.nspname = 'private' and p.proname = 'file051_authorize_download_pre_guardian_reads'
  ) then
    alter function private.file051_authorize_download(uuid)
      rename to file051_authorize_download_pre_guardian_reads;
  end if;
end $$;

create or replace function private.file051_authorize_download(p_file_id uuid)
returns jsonb language plpgsql stable security definer set search_path = '' as $$
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
          and exists (select 1 from public.enrollments e
            where e.classroom_id = asg.classroom_id
              and private.is_linked_guardian(e.student_id, asg.classroom_id)))
        or (ass.id is not null and ass.state = 'published' and ass.deleted_at is null
          and exists (select 1 from public.enrollments e
            where e.classroom_id = ass.classroom_id
              and private.is_linked_guardian(e.student_id, ass.classroom_id)))
      )
  ) or exists (
    select 1 from public.file_bindings b
    join public.resource_publications rp on rp.resource_version_id = b.resource_version_id
    where b.file_object_id = p_file_id
      and rp.state = 'published' and rp.published_at is not null
      and rp.withdrawn_at is null and rp.classroom_id is not null
      and rp.audience in ('guardians', 'both')
      and exists (select 1 from public.enrollments e
        where e.classroom_id = rp.classroom_id
          and private.is_linked_guardian(e.student_id, rp.classroom_id))
  ) then
    return jsonb_build_object('allowed', true,
      'schoolId', decision->'schoolId', 'reason', 'linked_guardian');
  end if;

  return decision;
end;
$$;

alter function private.file051_authorize_download(uuid) owner to postgres;
alter function private.file051_authorize_download_pre_guardian_reads(uuid)
  owner to postgres;
revoke all on function private.file051_authorize_download(uuid)
  from public, anon, authenticated, service_role, studafy_worker_runtime,
  studafy_api_runtime;
revoke all on function private.file051_authorize_download_pre_guardian_reads(uuid)
  from public, anon, authenticated, service_role, studafy_worker_runtime,
  studafy_api_runtime;

