-- Dates on school records.
--
-- A parent reading a child's attendance saw "absent" with no day: the list
-- carried when the mark was saved, never which lesson it was for. Work and
-- exams were listed without the day they were set. This adds them where
-- the lists are read - the lesson's class and times on each attendance
-- mark, and the publishing time on work and exams - without touching who
-- may read what: the rows are the ones the caller was already given.
--
-- ADR-0030: a named helper, and api041_query re-issued whole.

create or replace function private.api041_record_dates(p_operation text, p_id uuid)
returns jsonb
language sql
stable
security definer
set search_path = ''
as $function$
  select coalesce(case p_operation
    when 'listAttendance' then (
      select jsonb_build_object('classroomId', ls.classroom_id,
        'startsAt', ls.starts_at, 'endsAt', ls.ends_at)
      from public.attendance_records ar
      join public.lesson_sessions ls on ls.id = ar.session_id
      where ar.id = p_id)
    when 'listAssignments' then (
      select jsonb_build_object('publishedAt', a.published_at)
      from public.assignments a where a.id = p_id)
    when 'listAssessments' then (
      select jsonb_build_object('publishedAt', a.published_at)
      from public.assessments a where a.id = p_id)
  end, '{}'::jsonb);
$function$;

revoke all on function private.api041_record_dates(text, uuid)
  from public, anon, authenticated, service_role, studafy_api_runtime, studafy_worker_runtime;

create or replace function private.api041_query(p_operation text, p_resource_id uuid, p_input jsonb)
returns jsonb
language plpgsql
stable
security definer
set search_path = ''
as $function$
declare
  result jsonb;
  v_school uuid;
  v_date date;
  v_child uuid;
begin
  -- Named handlers first (ADR-0030).
  case p_operation
    when 'listGradebook' then return private.api041_gradebook(p_resource_id, p_input);
    when 'listGradeHistory' then return private.api041_grade_history(p_resource_id, p_input);
    when 'listAttendanceHistory' then
      return private.api041_attendance_history(p_resource_id, p_input);
    when 'listAssignmentExtensions' then
      return private.api041_assignment_extensions(p_resource_id, p_input);
    else null;
  end case;

  result := private.api041_query_pre_roster_shape(p_operation, p_resource_id, p_input);

  -- Every list of school records says when each one happened: the day of
  -- the lesson a mark is for, the day work or an exam was set.
  if p_operation in ('listAttendance', 'listAssignments', 'listAssessments')
    and jsonb_typeof(result->'items') = 'array' then
    result := jsonb_set(result, array['items'], (
      select coalesce(jsonb_agg(item || private.api041_record_dates(p_operation, (item->>'id')::uuid)
        order by ordinality), '[]'::jsonb)
      from jsonb_array_elements(result->'items') with ordinality as t(item, ordinality)));
  end if;

  -- A guardian reading a child's work sees the child's deadline, extension
  -- and whether the work can still be handed in, as the child would.
  if p_operation = 'listAssignments' and jsonb_typeof(result->'items') = 'array' then
    v_child := nullif(p_input->>'studentId', '')::uuid;
    if v_child is not null and private.is_linked_guardian(v_child) then
      return jsonb_set(result, array['items'], (
        select coalesce(jsonb_agg(item || coalesce(
            private.assignment_student_json((item->>'id')::uuid, v_child), '{}'::jsonb)
          order by ordinality), '[]'::jsonb)
        from jsonb_array_elements(result->'items') with ordinality as t(item, ordinality)));
    end if;
    return result;
  end if;

  if p_operation <> 'listAttendanceRoster' or result is null
    or jsonb_typeof(result->'items') <> 'array' then
    return result;
  end if;

  -- What the caller may do to this register, so the screen offers exactly
  -- that: judged on the lesson's own date in the school's time zone.
  select c.school_id into v_school from public.classrooms c where c.id = p_resource_id;
  v_date := coalesce(
    (select private.lesson_local_date(ls.school_id, ls.starts_at)
     from public.lesson_sessions ls where ls.id = (result->'session'->>'id')::uuid),
    private.lesson_local_date(v_school, nullif(p_input->>'startsAt', '')::timestamptz),
    nullif(p_input->>'date', '')::date,
    private.lesson_local_date(v_school, now()));

  -- Everyone on the register now, then - on the last page - anyone marked
  -- for this lesson who has since left the class, so their mark can still
  -- be read and corrected. They are flagged, not mixed in.
  return jsonb_set(result, array['items'], (
    select coalesce(jsonb_agg((item - 'id') || '{"enrolled":true}'::jsonb
      order by ordinality), '[]'::jsonb)
    from jsonb_array_elements(result->'items') with ordinality as t(item, ordinality)
  ) || case when result->>'nextPosition' is not null or result->'session' = 'null'::jsonb
      then '[]'::jsonb
    else coalesce((
      select jsonb_agg(jsonb_build_object(
          'student', jsonb_build_object('id', st.id, 'displayName', st.display_name,
            'studafyId', st.studafy_id),
          'record', jsonb_build_object('id', ar.id, 'sessionId', ar.session_id,
            'studentId', ar.student_id, 'state', ar.state, 'reason', ar.reason,
            'recordedAt', ar.recorded_at),
          'enrolled', false) order by st.id)
      from public.attendance_records ar
      join public.students st on st.id = ar.student_id
      where ar.session_id = (result->'session'->>'id')::uuid
        and not exists (select 1 from public.enrollments e
          where e.classroom_id = p_resource_id and e.student_id = ar.student_id
            and e.active and e.status = 'active')), '[]'::jsonb) end)
  || jsonb_build_object('editRule', private.attendance_edit_rule(p_resource_id, v_date));
end;
$function$;

alter function private.api041_record_dates(text, uuid) owner to postgres;
