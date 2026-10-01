-- Attendance corrections under the school's lock rule, with a history of
-- every mark that changed.
--
-- Until now a register could be re-saved at any time by any class teacher,
-- the previous mark was overwritten, and the audit row said only that
-- attendance was recorded. A lesson could also stop being correctable
-- altogether: re-saving needed the class's current schedule to contain the
-- lesson and every student to be enrolled today, so a schedule change or a
-- withdrawal froze past registers. This migration adds:
--
--   * the lock rule. Marks change freely on the school day of the lesson;
--     after that a changed mark needs a reason; seven school days on, the
--     register locks and only the class's lead teacher can override it, with
--     a reason. This release has no school administrator, so there is no
--     per-school setting and nobody else who can override.
--   * public.attendance_record_revisions - append-only: who changed which
--     mark, when, from what, to what, why, and whether a lock was overridden.
--   * recordAttendance as a named handler that applies the rule, and
--     correctAttendance, addressed by lesson rather than by timetable slot,
--     for corrections after the schedule moved or the student left.
--
-- "The school day" is the lesson's date in the school's own time zone.

create table if not exists public.attendance_record_revisions (
  id bigint generated always as identity primary key,
  school_id uuid not null references public.schools(id) on delete restrict,
  attendance_record_id uuid not null,
  session_id uuid not null,
  student_id uuid not null,
  previous_state public.attendance_state not null,
  previous_reason text,
  previous_recorded_by uuid,
  previous_recorded_at timestamptz not null,
  next_state public.attendance_state not null,
  next_reason text,
  actor_id uuid references public.profiles(id) on delete set null,
  reason text,
  override boolean not null default false,
  operation_id uuid not null,
  created_at timestamptz not null default now(),
  unique (attendance_record_id, operation_id),
  -- An education record's history is kept as long as the record is.
  constraint attendance_record_revisions_record_fk
    foreign key (school_id, attendance_record_id)
    references public.attendance_records(school_id, id) on delete restrict,
  constraint attendance_record_revisions_session_fk
    foreign key (school_id, session_id)
    references public.lesson_sessions(school_id, id) on delete restrict
);
create index if not exists attendance_record_revisions_session_idx
  on public.attendance_record_revisions (session_id, id desc);
create index if not exists attendance_record_revisions_record_idx
  on public.attendance_record_revisions (attendance_record_id, id desc);
create trigger attendance_record_revisions_append_only
  before update or delete on public.attendance_record_revisions
  for each row execute function private.reject_append_only_mutation();
alter table public.attendance_record_revisions enable row level security;
revoke all on table public.attendance_record_revisions
  from public, anon, authenticated, service_role, studafy_api_runtime, studafy_worker_runtime;

-- ---------------------------------------------------------------------------
-- The rule for one lesson date, for the caller.
-- ---------------------------------------------------------------------------

-- open             marks change freely (the lesson's school day, or later)
-- reason_required  new marks are fine; a changed mark needs a reason
-- locked           nothing changes
-- locked_override  locked, but this caller - the class's lead teacher - may
--                  override it with a reason
create or replace function private.attendance_edit_rule(p_classroom uuid, p_local_date date)
returns text
language sql
stable
security definer
set search_path = ''
as $$
  select case
    when p_local_date >= today then 'open'
    when today - p_local_date <= 7 then 'reason_required'
    when private.coursework_teacher(c.id) and private.is_class_lead(c.id)
      then 'locked_override'
    else 'locked'
  end
  from public.classrooms c
  join public.schools s on s.id = c.school_id
  cross join lateral (select (now() at time zone s.timezone)::date as today) t
  where c.id = p_classroom;
$$;

create or replace function private.lesson_local_date(p_school uuid, p_at timestamptz)
returns date
language sql
stable
security definer
set search_path = ''
as $$
  select (p_at at time zone s.timezone)::date from public.schools s where s.id = p_school;
$$;

-- ---------------------------------------------------------------------------
-- Applying marks to one lesson: the policy, the eligibility of each student,
-- the write and the history, in set-based statements.
-- ---------------------------------------------------------------------------

create or replace function private.attendance_apply(
  p_session uuid, p_entries jsonb, p_reason text, p_override boolean,
  p_operation uuid)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  ls public.lesson_sessions%rowtype;
  v_date date;
  v_rule text;
  v_reason text := nullif(btrim(p_reason), '');
  v_new int;
  v_changed int;
  v_ineligible jsonb;
  v_recorded int;
begin
  select * into ls from public.lesson_sessions where id = p_session;
  v_date := private.lesson_local_date(ls.school_id, ls.starts_at);
  v_rule := private.attendance_edit_rule(ls.classroom_id, v_date);

  if (select count(*) <> count(distinct e."studentId") or bool_or(e."studentId" is null)
      from jsonb_to_recordset(p_entries) as e("studentId" uuid)) then
    return jsonb_build_object('outcome', 'invalid');
  end if;

  -- A student may be marked for a lesson they were in: already on its
  -- register, enrolled now, or enrolled on that date before leaving.
  select coalesce(jsonb_agg(jsonb_build_object('studentId', e."studentId",
      'reason', 'not_enrolled')), '[]'::jsonb)
  into v_ineligible
  from jsonb_to_recordset(p_entries) as e("studentId" uuid)
  where not exists (select 1 from public.attendance_records ar
      where ar.session_id = ls.id and ar.student_id = e."studentId")
    and not exists (select 1 from public.enrollments en
      where en.classroom_id = ls.classroom_id and en.student_id = e."studentId"
        and en.starts_on <= v_date
        and ((en.active and en.status = 'active')
          or (en.status in ('withdrawn', 'completed') and en.ends_on >= v_date)));
  if jsonb_array_length(v_ineligible) > 0 then
    return jsonb_build_object('outcome', 'grade_entries_invalid', 'rows', v_ineligible);
  end if;

  perform 1 from public.attendance_records ar
  where ar.session_id = ls.id order by ar.id for update;

  select count(*) filter (where ar.id is null),
    count(*) filter (where ar.id is not null
      and (ar.state, ar.reason) is distinct from
        (e.state::public.attendance_state, nullif(btrim(e.reason), '')))
  into v_new, v_changed
  from jsonb_to_recordset(p_entries) as e("studentId" uuid, state text, reason text)
  left join public.attendance_records ar
    on ar.session_id = ls.id and ar.student_id = e."studentId";

  if v_rule = 'locked' and (v_new + v_changed) > 0 then
    return jsonb_build_object('outcome', 'attendance_locked');
  end if;
  if v_rule = 'locked_override' and (v_new + v_changed) > 0 then
    if not coalesce(p_override, false) then
      return jsonb_build_object('outcome', 'attendance_locked');
    end if;
    if v_reason is null then return jsonb_build_object('outcome', 'reason_required'); end if;
  end if;
  if v_rule = 'reason_required' and v_changed > 0 and v_reason is null then
    return jsonb_build_object('outcome', 'reason_required');
  end if;

  with incoming as (
    select e."studentId" as student_id, e.state::public.attendance_state as state,
      nullif(btrim(e.reason), '') as reason
    from jsonb_to_recordset(p_entries) as e("studentId" uuid, state text, reason text)
  ), previous as (
    select ar.id, ar.student_id, ar.state, ar.reason, ar.recorded_by, ar.recorded_at
    from public.attendance_records ar
    where ar.session_id = ls.id
      and ar.student_id in (select student_id from incoming)
  ), written as (
    insert into public.attendance_records as ar(
      school_id, session_id, student_id, state, reason, recorded_by)
    select ls.school_id, ls.id, i.student_id, i.state, i.reason, auth.uid()
    from incoming i
    on conflict (session_id, student_id) do update set
      state = excluded.state, reason = excluded.reason,
      recorded_by = auth.uid(), recorded_at = now()
    where (ar.state, ar.reason) is distinct from (excluded.state, excluded.reason)
    returning ar.id, ar.student_id, ar.state, ar.reason
  ), logged as (
    insert into public.attendance_record_revisions(
      school_id, attendance_record_id, session_id, student_id, previous_state,
      previous_reason, previous_recorded_by, previous_recorded_at, next_state,
      next_reason, actor_id, reason, override, operation_id)
    select ls.school_id, w.id, ls.id, w.student_id, p.state, p.reason,
      p.recorded_by, p.recorded_at, w.state, w.reason, auth.uid(), v_reason,
      v_rule = 'locked_override', p_operation
    from written w join previous p on p.id = w.id
    returning 1
  )
  select (select count(*) from incoming) into v_recorded;

  return jsonb_build_object('outcome', 'ok', 'recorded', v_recorded,
    'changed', v_changed, 'rule', v_rule,
    'override', v_rule = 'locked_override' and (v_new + v_changed) > 0);
end;
$$;

-- recordAttendance: today's register, addressed by timetable slot. Same
-- request and response as before; the school's policy now applies when the
-- lesson is in the past, and every changed mark is kept.
create or replace function private.api041_record_attendance(
  p_resource_id uuid, p_input jsonb, p_idempotency_id uuid,
  p_idempotency_generation bigint)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  body jsonb := coalesce(p_input->'body', '{}'::jsonb);
  v_tenant uuid := nullif(current_setting('studafy.school_id', true), '')::uuid;
  v_key text;
  v_class uuid;
  v_school uuid;
  v_starts timestamptz;
  v_ends timestamptz;
  v_session uuid;
  v_version bigint;
  v_result jsonb;
  v_response jsonb;
  v_created boolean := false;
begin
  v_key := private.coursework_idempotency_key(p_idempotency_id, p_idempotency_generation);
  if v_key is null then return jsonb_build_object('outcome', 'forbidden'); end if;
  v_class := (body->>'classroomId')::uuid;
  v_starts := (body->>'startsAt')::timestamptz;
  v_ends := (body->>'endsAt')::timestamptz;
  select c.school_id into v_school from public.classrooms c where c.id = v_class;
  if v_school is null then return jsonb_build_object('outcome', 'not_found'); end if;
  if v_school <> v_tenant or not private.coursework_teacher(v_class) then
    return jsonb_build_object('outcome', 'forbidden');
  end if;
  if v_ends <= v_starts then return jsonb_build_object('outcome', 'invalid'); end if;

  -- One savepoint around the lesson row and its marks: a refusal leaves
  -- nothing behind, a lesson created for it included.
  begin
    select ls.id, ls.version into v_session, v_version from public.lesson_sessions ls
    where ls.classroom_id = v_class and ls.starts_at = v_starts for update;
    if v_session is null then
      -- A new register must be for a lesson on the class's timetable.
      if not exists (select 1 from public.class_schedules cs join public.schools s on s.id = cs.school_id
          where cs.classroom_id = v_class
            and cs.weekday = extract(isodow from (v_starts at time zone s.timezone))
            and cs.starts_at = (v_starts at time zone s.timezone)::time
            and (v_starts at time zone s.timezone)::date
              between cs.effective_from and coalesce(cs.effective_until, 'infinity'::date)) then
        return jsonb_build_object('outcome', 'invalid_state');
      end if;
      if (body->>'expectedVersion')::bigint <> 0 then
        return jsonb_build_object('outcome', 'version_conflict');
      end if;
      insert into public.lesson_sessions(school_id, classroom_id, starts_at, ends_at, status, version)
      values (v_tenant, v_class, v_starts, v_ends, 'completed', 1)
      returning id, version into v_session, v_version;
      v_created := true;
    elsif v_version <> (body->>'expectedVersion')::bigint then
      return jsonb_build_object('outcome', 'version_conflict');
    end if;

    v_result := private.attendance_apply(v_session, body->'entries',
      body->>'correctionReason', (body->>'override')::boolean, p_idempotency_id);
    if v_result->>'outcome' <> 'ok' then
      raise exception using errcode = 'SF042', message = v_result::text;
    end if;
  exception when sqlstate 'SF042' then
    return sqlerrm::jsonb;
  end;

  if not v_created then
    update public.lesson_sessions set ends_at = v_ends, status = 'completed',
      version = version + 1
    where id = v_session returning version into v_version;
  end if;

  v_response := jsonb_build_object('sessionId', v_session, 'version', v_version,
    'recorded', (v_result->>'recorded')::int);
  return private.coursework_finish(
    p_idempotency_id, p_idempotency_generation, 200,
    case when (v_result->>'changed')::int > 0 then 'attendance_corrected' else 'attendance_recorded' end,
    'lesson_session', v_session, null,
    jsonb_build_object('operation', 'recordAttendance', 'version', v_version,
      'changed', v_result->'changed', 'rule', v_result->'rule',
      'override', v_result->'override'),
    v_response);
end;
$$;

-- correctAttendance: one lesson's register, addressed by the lesson itself,
-- for one student or the whole class.
create or replace function private.api041_correct_attendance(
  p_session uuid, p_input jsonb, p_idempotency_id uuid,
  p_idempotency_generation bigint)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  body jsonb := coalesce(p_input->'body', '{}'::jsonb);
  v_tenant uuid := nullif(current_setting('studafy.school_id', true), '')::uuid;
  v_key text;
  ls public.lesson_sessions%rowtype;
  v_result jsonb;
  v_version bigint;
begin
  v_key := private.coursework_idempotency_key(p_idempotency_id, p_idempotency_generation);
  if v_key is null then return jsonb_build_object('outcome', 'forbidden'); end if;
  select * into ls from public.lesson_sessions where id = p_session for update;
  if ls.id is null then return jsonb_build_object('outcome', 'not_found'); end if;
  if ls.school_id <> v_tenant or not private.coursework_teacher(ls.classroom_id) then
    return jsonb_build_object('outcome', 'forbidden');
  end if;
  if ls.version <> (body->>'expectedVersion')::bigint then
    return jsonb_build_object('outcome', 'version_conflict');
  end if;

  v_result := private.attendance_apply(ls.id, body->'entries', body->>'reason',
    (body->>'override')::boolean, p_idempotency_id);
  if v_result->>'outcome' <> 'ok' then return v_result; end if;

  update public.lesson_sessions set version = version + 1
  where id = ls.id returning version into v_version;

  return private.coursework_finish(
    p_idempotency_id, p_idempotency_generation, 200, 'attendance_corrected',
    'lesson_session', ls.id, null,
    jsonb_build_object('operation', 'correctAttendance', 'version', v_version,
      'changed', v_result->'changed', 'rule', v_result->'rule',
      'override', v_result->'override', 'reason', btrim(body->>'reason')),
    jsonb_build_object('sessionId', ls.id, 'version', v_version,
      'recorded', (v_result->>'recorded')::int));
end;
$$;

-- Every change to one lesson's marks, newest first.
create or replace function private.api041_attendance_history(p_session uuid, p_input jsonb)
returns jsonb
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  v_tenant uuid := nullif(current_setting('studafy.school_id', true), '')::uuid;
  v_limit int := least(greatest(coalesce((p_input->>'pageSize')::int, 50), 1), 100);
  v_pos bigint := nullif(p_input->>'position', '')::bigint;
  ls public.lesson_sessions%rowtype;
  v_items jsonb;
  v_next text;
  v_count int;
begin
  select * into ls from public.lesson_sessions where id = p_session;
  if ls.id is null or ls.school_id is distinct from v_tenant
     or not private.coursework_staff(ls.classroom_id) then
    return jsonb_build_object('outcome', 'not_found');
  end if;

  select coalesce(jsonb_agg(jsonb_build_object(
      'id', x.id::text, 'studentId', x.student_id,
      'studentName', x.student_name,
      'previousState', x.previous_state, 'previousReason', x.previous_reason,
      'nextState', x.next_state, 'nextReason', x.next_reason,
      'reason', x.reason, 'override', x.override,
      'actor', case when x.actor_id is null then null else jsonb_build_object(
        'id', x.actor_id, 'displayName', x.actor_name) end,
      'createdAt', x.created_at) order by x.id desc), '[]'::jsonb),
    min(x.id)::text, count(*)
  into v_items, v_next, v_count
  from (
    select r.*, st.display_name as student_name, p.display_name as actor_name
    from public.attendance_record_revisions r
    join public.students st on st.id = r.student_id
    left join public.profiles p on p.id = r.actor_id
    where r.session_id = ls.id and (v_pos is null or r.id < v_pos)
    order by r.id desc
    limit v_limit
  ) x;

  return jsonb_build_object('items', v_items,
    'nextPosition', case when v_count = v_limit then v_next end);
end;
$$;

-- ---------------------------------------------------------------------------
-- Dispatch.
-- ---------------------------------------------------------------------------

create or replace function private.api041_command(p_operation text, p_resource_id uuid, p_input jsonb, p_idempotency_id uuid, p_idempotency_generation bigint)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $function$
declare
  v_assignment uuid := nullif((p_input->'body')->>'assignmentId', '')::uuid;
  v_class uuid := nullif((p_input->'body')->>'classroomId', '')::uuid;
  result jsonb;
  v_assessment uuid;
  v_response jsonb;
begin
  -- Named handlers first (ADR-0030): each owns its operation outright.
  case p_operation
    when 'archiveClassroom' then
      return private.api041_archive_classroom(
        p_resource_id, p_input, p_idempotency_id, p_idempotency_generation);
    when 'saveGradeDrafts' then
      return private.api041_save_grade_drafts(
        p_resource_id, p_input, p_idempotency_id, p_idempotency_generation);
    when 'publishGrades' then
      return private.api041_publish_grades(
        p_resource_id, p_input, p_idempotency_id, p_idempotency_generation);
    when 'correctGrades' then
      return private.api041_correct_grades(
        p_resource_id, p_input, p_idempotency_id, p_idempotency_generation);
    when 'correctGradeResult' then
      return private.api041_correct_grade_result(
        p_resource_id, p_input, p_idempotency_id, p_idempotency_generation);
    when 'updateGradebookItem' then
      return private.api041_update_gradebook_item(
        p_resource_id, p_input, p_idempotency_id, p_idempotency_generation);
    when 'recordAttendance' then
      return private.api041_record_attendance(
        p_resource_id, p_input, p_idempotency_id, p_idempotency_generation);
    when 'correctAttendance' then
      return private.api041_correct_attendance(
        p_resource_id, p_input, p_idempotency_id, p_idempotency_generation);
    else null;
  end case;

  if p_operation <> 'createAssessment' then
    return private.api041_command_pre_graded(
      p_operation, p_resource_id, p_input, p_idempotency_id,
      p_idempotency_generation);
  end if;

  if v_assignment is not null then
    -- The work must be in the class the mark is being created for, and not
    -- already have one. The delegate checks the caller may write that class.
    if not exists (
      select 1 from public.assignments a
      where a.id = v_assignment and a.classroom_id = v_class and a.deleted_at is null
    ) then
      return jsonb_build_object('outcome', 'invalid');
    end if;
    if exists (select 1 from public.assessments g
        where g.assignment_id = v_assignment and g.deleted_at is null) then
      return jsonb_build_object('outcome', 'invalid');
    end if;
  end if;

  result := private.api041_command_pre_graded(
    p_operation, p_resource_id, p_input, p_idempotency_id,
    p_idempotency_generation);
  if coalesce(result->>'outcome', '') <> 'ok' then return result; end if;
  if v_assignment is null and (p_input->'body'->'weight') is null then
    return result;
  end if;

  v_assessment := ((result->'response')->>'id')::uuid;
  update public.assessments set
    assignment_id = coalesce(v_assignment, assignment_id),
    -- How much the category counts, when the school weighs categories.
    category_weight = nullif((p_input->'body')->>'weight', '')::numeric
  where id = v_assessment;

  v_response := private.api041_assessment_json(v_assessment);
  update public.idempotency_records r
  set response_body = v_response
  where r.id = p_idempotency_id and r.actor_id = auth.uid()
    and r.generation = p_idempotency_generation and r.status = 'completed';
  return jsonb_set(result, array['response'], v_response);
exception when invalid_text_representation then
  return jsonb_build_object('outcome', 'invalid');
end;
$function$;

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
begin
  -- Named handlers first (ADR-0030).
  case p_operation
    when 'listGradebook' then return private.api041_gradebook(p_resource_id, p_input);
    when 'listGradeHistory' then return private.api041_grade_history(p_resource_id, p_input);
    when 'listAttendanceHistory' then
      return private.api041_attendance_history(p_resource_id, p_input);
    else null;
  end case;

  result := private.api041_query_pre_roster_shape(p_operation, p_resource_id, p_input);
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

do $grants$
declare
  f text;
begin
  foreach f in array array[
    'private.attendance_edit_rule(uuid,date)',
    'private.lesson_local_date(uuid,timestamptz)',
    'private.attendance_apply(uuid,jsonb,text,boolean,uuid)',
    'private.api041_record_attendance(uuid,jsonb,uuid,bigint)',
    'private.api041_correct_attendance(uuid,jsonb,uuid,bigint)',
    'private.api041_attendance_history(uuid,jsonb)'
  ] loop
    execute format('alter function %s owner to postgres', f);
    execute format('revoke all on function %s from public, anon, authenticated, service_role, studafy_api_runtime, studafy_worker_runtime', f);
  end loop;
end;
$grants$;
