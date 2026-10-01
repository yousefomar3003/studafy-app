-- Deadlines for handed-in work: replace until the deadline, then closed
-- unless the teacher extends it for a student or reopens it for the class.
--
-- A student could already hand work in again until the assignment closed;
-- each hand-in is an attempt of its own and the earlier ones are kept. What
-- was missing:
--
--   * a teacher could not give one student more time, or reopen the work
--     for the class once it had closed;
--   * a student could keep replacing work after the teacher had published a
--     mark for it, so the mark no longer described the work on file;
--   * replacing an answer meant uploading every file again, because a file
--     can be bound only once;
--   * deadlines were shown in the device's time zone, not the school's.
--
-- This migration adds public.assignment_extensions and a named submit
-- handler for students and for guardians handing work in for a child. The
-- rule, applied on the server to every hand-in:
--
--   deadline = the later of (closes_at, else due_at) and any active extension
--   open     = now is before the deadline and no mark has been published
--              for this student since their extension was granted
--
-- A hand-in after due_at but before the deadline is accepted and marked
-- late. Drafts are not stored on the server: until work is handed in it
-- stays on the device.

create table if not exists public.assignment_extensions (
  id uuid primary key default gen_random_uuid(),
  school_id uuid not null references public.schools(id) on delete cascade,
  assignment_id uuid not null,
  student_id uuid not null,
  extended_until timestamptz not null,
  reason text not null check (length(btrim(reason)) between 3 and 500),
  granted_by uuid references public.profiles(id) on delete set null,
  created_at timestamptz not null default now(),
  revoked_at timestamptz,
  revoked_by uuid references public.profiles(id) on delete set null,
  constraint assignment_extensions_future check (extended_until > created_at),
  constraint assignment_extensions_assignment_fk foreign key (school_id, assignment_id)
    references public.assignments(school_id, id) on delete cascade,
  constraint assignment_extensions_student_fk foreign key (school_id, student_id)
    references public.students(school_id, id) on delete cascade
);
-- At most one live extension per student per piece of work; granting again
-- revokes the previous one in the same transaction.
create unique index if not exists assignment_extensions_live_key
  on public.assignment_extensions (assignment_id, student_id)
  where revoked_at is null;
alter table public.assignment_extensions enable row level security;
revoke all on table public.assignment_extensions
  from public, anon, authenticated, service_role, studafy_api_runtime, studafy_worker_runtime;

-- ---------------------------------------------------------------------------
-- School time.
-- ---------------------------------------------------------------------------

-- A wall-clock time the teacher picked ("2026-10-01T23:59") as the instant
-- it names in the school's time zone.
create or replace function private.school_instant(p_school uuid, p_local text)
returns timestamptz
language sql
stable
security definer
set search_path = ''
as $$
  select (p_local::timestamp) at time zone s.timezone
  from public.schools s where s.id = p_school and nullif(p_local, '') is not null;
$$;

create or replace function private.school_local_text(p_school uuid, p_at timestamptz)
returns text
language sql
stable
security definer
set search_path = ''
as $$
  select to_char(p_at at time zone s.timezone, 'YYYY-MM-DD"T"HH24:MI')
  from public.schools s where s.id = p_school and p_at is not null;
$$;

-- ---------------------------------------------------------------------------
-- The gate.
-- ---------------------------------------------------------------------------

create or replace function private.submission_gate(p_assignment uuid, p_student uuid)
returns jsonb
language sql
stable
security definer
set search_path = ''
as $$
  select jsonb_build_object(
    'deadlineAt', d.deadline,
    'deadlineLocal', private.school_local_text(a.school_id, d.deadline),
    'state', case
      when g.published_at is not null
        and (x.created_at is null or x.created_at < g.published_at) then 'graded_locked'
      when now() > d.deadline then 'closed'
      else 'open' end,
    'late', now() > a.due_at,
    'extension', case when x.id is null then null else jsonb_build_object(
      'id', x.id, 'extendedUntil', x.extended_until,
      'extendedUntilLocal', private.school_local_text(a.school_id, x.extended_until),
      'reason', x.reason, 'createdAt', x.created_at) end)
  from public.assignments a
  left join public.assignment_extensions x
    on x.assignment_id = a.id and x.student_id = p_student and x.revoked_at is null
  left join lateral (
    select gr.published_at from public.assessments s
    join public.grade_results gr on gr.assessment_id = s.id
      and gr.student_id = p_student and gr.state = 'published'
    where s.assignment_id = a.id and s.deleted_at is null
    limit 1
  ) g on true
  cross join lateral (
    select greatest(coalesce(a.closes_at, a.due_at), x.extended_until) as deadline
  ) d
  where a.id = p_assignment;
$$;

create or replace function private.assignment_student_json(p_assignment uuid, p_student uuid)
returns jsonb
language sql
stable
security definer
set search_path = ''
as $$
  select case when p_student is null then null else (
    select jsonb_build_object(
      'deadlineAt', gate->'deadlineAt', 'deadlineLocal', gate->'deadlineLocal',
      'submissionState', gate->'state', 'extension', gate->'extension')
    from (select private.submission_gate(p_assignment, p_student) as gate) g) end;
$$;

create or replace function private.api041_assignment_json(p_id uuid)
returns jsonb
language sql
stable
security definer
set search_path = ''
as $$
  select jsonb_build_object('id',a.id,'classroomId',a.classroom_id,'title',a.title,
    'instructions',a.instructions,'dueAt',a.due_at,'closesAt',a.closes_at,
    'state',a.state,'version',a.version,'submissionId',s.id,'submittedAt',s.submitted_at,
    'attachments',private.file_attachment_json(p_assignment => a.id),
    'maximumScore',(select g.maximum_score from public.assessments g
      where g.assignment_id = a.id and g.deleted_at is null limit 1),
    -- Deadlines as the school reads them, whatever the device's zone.
    'timeZone',sc.timezone,
    'dueLocal',private.school_local_text(a.school_id, a.due_at),
    'closesLocal',private.school_local_text(a.school_id, a.closes_at))
  -- The caller's own position on this work, when the caller is a student.
  || coalesce(private.assignment_student_json(a.id, own.id), '{}'::jsonb)
  from public.assignments a
  join public.schools sc on sc.id = a.school_id
  left join lateral (
    select st.id from public.students st
    join public.enrollments e on e.student_id = st.id and e.classroom_id = a.classroom_id
    where st.user_id = auth.uid() and st.deleted_at is null
    limit 1
  ) own on true
  left join lateral (
    select su.id,su.submitted_at from public.submissions su
    where su.assignment_id=a.id and su.student_id = own.id limit 1
  ) s on true where a.id=p_id;
$$;

-- ---------------------------------------------------------------------------
-- Handing work in.
-- ---------------------------------------------------------------------------

create or replace function private.api041_submit_assignment(
  p_assignment uuid, p_input jsonb, p_idempotency_id uuid,
  p_idempotency_generation bigint)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  body jsonb := coalesce(p_input->'body', '{}'::jsonb);
  v_tenant uuid := nullif(current_setting('studafy.school_id', true), '')::uuid;
  v_request text := nullif(current_setting('studafy.request_id', true), '');
  v_named uuid := nullif(body->>'studentId', '')::uuid;
  a public.assignments%rowtype;
  v_student uuid;
  v_guardian boolean := false;
  v_gate jsonb;
  v_submission uuid;
  v_previous uuid;
  v_attempt uuid;
  v_files uuid[];
  v_kept uuid[];
  v_bind text;
  v_response jsonb;
  v_key text;
begin
  if auth.uid() is null or v_request is null then
    return jsonb_build_object('outcome', 'forbidden');
  end if;
  -- A guardian has no membership of the school, so they have no tenant and
  -- no idempotency school: their reservation is checked on its own.
  select r.idempotency_key into v_key from public.idempotency_records r
  where r.id = p_idempotency_id and r.actor_id = auth.uid()
    and r.generation = p_idempotency_generation and r.status = 'reserved'
  for update;
  if v_key is null then return jsonb_build_object('outcome', 'forbidden'); end if;

  select * into a from public.assignments x
  where x.id = p_assignment and x.deleted_at is null for update;
  if a.id is null then return jsonb_build_object('outcome', 'not_found'); end if;

  -- Whose work this is: the caller's own, or the child a guardian names.
  select st.id into v_student from public.students st
  join public.enrollments e on e.student_id = st.id
  where st.user_id = auth.uid() and e.classroom_id = a.classroom_id
    and e.active and e.status = 'active'
    and (v_named is null or st.id = v_named)
  limit 1;
  if v_student is null and v_named is not null
     and private.is_linked_guardian(v_named, a.classroom_id) then
    v_student := v_named;
    v_guardian := true;
  end if;
  if v_student is null
     or (not v_guardian and a.school_id is distinct from v_tenant) then
    return jsonb_build_object('outcome', 'forbidden');
  end if;
  if a.state <> 'published' then return jsonb_build_object('outcome', 'invalid_state'); end if;

  v_gate := private.submission_gate(a.id, v_student);
  if v_gate->>'state' = 'closed' then
    return jsonb_build_object('outcome', 'window_closed');
  elsif v_gate->>'state' = 'graded_locked' then
    return jsonb_build_object('outcome', 'graded_locked');
  end if;

  select array_agg(distinct x::uuid) into v_files
  from jsonb_array_elements_text(coalesce(body->'attachmentFileIds', '[]'::jsonb)) x;
  -- The same file twice in one hand-in is a malformed request, not a merge.
  if cardinality(coalesce(v_files, array[]::uuid[]))
     <> jsonb_array_length(coalesce(body->'attachmentFileIds', '[]'::jsonb)) then
    return jsonb_build_object('outcome', 'invalid');
  end if;

  -- Files already on the work being replaced carry over without another
  -- upload; anything else goes through the ordinary binding checks.
  select s.id, s.current_attempt_id into v_submission, v_previous
  from public.submissions s
  where s.assignment_id = a.id and s.student_id = v_student for update;
  select coalesce(array_agg(b.file_object_id), array[]::uuid[]) into v_kept
  from public.file_bindings b
  where v_previous is not null and b.submission_attempt_id = v_previous
    and b.file_object_id = any(coalesce(v_files, array[]::uuid[]));

  begin
    insert into public.submissions(
      school_id, assignment_id, student_id, submitted_at, excused, status, version)
    values (a.school_id, a.id, v_student, now(), false, 'submitted', 1)
    on conflict (assignment_id, student_id) do update set
      submitted_at = now(), status = 'submitted',
      version = public.submissions.version + 1, updated_at = now()
    returning id into v_submission;

    insert into public.submission_attempts(
      school_id, submission_id, operation_id, answer_text, submitted_at,
      submitted_by_guardian_id)
    values (a.school_id, v_submission, p_idempotency_id, body->>'answerText', now(),
      case when v_guardian then auth.uid() end)
    returning id into v_attempt;
    update public.submissions set current_attempt_id = v_attempt where id = v_submission;

    insert into public.file_bindings(school_id, file_object_id, submission_attempt_id)
    select a.school_id, k, v_attempt from unnest(v_kept) k;

    if cardinality(coalesce(v_files, array[]::uuid[])) > cardinality(v_kept) then
      v_bind := private.file_attach_bind(
        (select jsonb_agg(f) from unnest(v_files) f where not (f = any(v_kept))),
        'assignment_submission'::public.file_purpose, a.school_id,
        p_submission_attempt => v_attempt);
      if v_bind <> 'ok' then
        raise exception using errcode = 'SF043', message = v_bind;
      end if;
    end if;
  exception when sqlstate 'SF043' then
    return jsonb_build_object('outcome', sqlerrm);
  end;

  select jsonb_build_object(
    'id', s.id, 'assignmentId', s.assignment_id, 'studentId', s.student_id,
    'status', s.status, 'version', s.version, 'answerText', sa.answer_text,
    'submittedAt', s.submitted_at,
    'submittedByGuardianId', sa.submitted_by_guardian_id,
    'attachments', private.file_attachment_json(p_submission_attempt => v_attempt),
    'late', sa.submitted_at > a.due_at)
  into v_response
  from public.submissions s
  join public.submission_attempts sa on sa.id = s.current_attempt_id
  where s.id = v_submission;

  -- Audited against the work's school, which a guardian's request does not
  -- carry. Named apart so the trail separates a child's hand-in from a
  -- guardian's.
  insert into public.audit_events(
    school_id, actor_id, action, entity_type, entity_id, after_value, request_id)
  values (a.school_id, auth.uid(),
    case when v_guardian then 'assignment_submitted_by_guardian' else 'assignment_submitted' end,
    'submission', v_submission,
    jsonb_build_object('operation', 'submitAssignment', 'version', v_response->'version',
      'attempt', v_attempt, 'late', v_response->'late',
      'replaced', v_previous is not null), v_request);
  if not private.api_idempotency_complete(p_idempotency_id, p_idempotency_generation,
      coalesce((p_input->>'responseStatus')::int, 201), v_response) then
    raise exception 'API041_IDEMPOTENCY_COMPLETION_FAILED';
  end if;
  return jsonb_build_object('outcome', 'ok', 'response', v_response);
end;
$$;

-- ---------------------------------------------------------------------------
-- The teacher's side: more time for one student, or the class reopened.
-- ---------------------------------------------------------------------------

create or replace function private.assignment_extension_json(p_id uuid)
returns jsonb
language sql
stable
security definer
set search_path = ''
as $$
  select jsonb_build_object('id', x.id, 'assignmentId', x.assignment_id,
    'studentId', x.student_id, 'extendedUntil', x.extended_until,
    'extendedUntilLocal', private.school_local_text(x.school_id, x.extended_until),
    'reason', x.reason, 'grantedBy', x.granted_by, 'createdAt', x.created_at,
    'revokedAt', x.revoked_at)
  from public.assignment_extensions x where x.id = p_id;
$$;

create or replace function private.api041_grant_extension(
  p_assignment uuid, p_input jsonb, p_idempotency_id uuid,
  p_idempotency_generation bigint)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  body jsonb := coalesce(p_input->'body', '{}'::jsonb);
  v_key text;
  a public.assignments%rowtype;
  v_student uuid := (body->>'studentId')::uuid;
  v_until timestamptz;
  v_id uuid;
begin
  v_key := private.coursework_idempotency_key(p_idempotency_id, p_idempotency_generation);
  if v_key is null then return jsonb_build_object('outcome', 'forbidden'); end if;
  select * into a from public.assignments x
  where x.id = p_assignment and x.deleted_at is null for update;
  if a.id is null then return jsonb_build_object('outcome', 'not_found'); end if;
  if a.school_id <> nullif(current_setting('studafy.school_id', true), '')::uuid
     or not private.coursework_teacher(a.classroom_id) then
    return jsonb_build_object('outcome', 'forbidden');
  end if;
  if not exists (select 1 from public.enrollments e
      where e.classroom_id = a.classroom_id and e.student_id = v_student
        and e.active and e.status = 'active') then
    return jsonb_build_object('outcome', 'grade_entries_invalid', 'rows',
      jsonb_build_array(jsonb_build_object('studentId', v_student, 'reason', 'not_enrolled')));
  end if;
  v_until := private.school_instant(a.school_id, body->>'extendedUntilLocal');
  if v_until is null or v_until <= now() then
    return jsonb_build_object('outcome', 'invalid');
  end if;

  update public.assignment_extensions set revoked_at = now(), revoked_by = auth.uid()
  where assignment_id = a.id and student_id = v_student and revoked_at is null;
  insert into public.assignment_extensions(
    school_id, assignment_id, student_id, extended_until, reason, granted_by)
  values (a.school_id, a.id, v_student, v_until, btrim(body->>'reason'), auth.uid())
  returning id into v_id;

  return private.coursework_finish(
    p_idempotency_id, p_idempotency_generation, 201, 'assignment_extension_granted',
    'assignment', a.id, null,
    jsonb_build_object('operation', 'grantAssignmentExtension', 'studentId', v_student,
      'extendedUntil', v_until, 'reason', btrim(body->>'reason')),
    private.assignment_extension_json(v_id));
exception when check_violation then
  return jsonb_build_object('outcome', 'invalid');
end;
$$;

create or replace function private.api041_revoke_extension(
  p_assignment uuid, p_input jsonb, p_idempotency_id uuid,
  p_idempotency_generation bigint)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  body jsonb := coalesce(p_input->'body', '{}'::jsonb);
  v_key text;
  a public.assignments%rowtype;
  v_id uuid;
begin
  v_key := private.coursework_idempotency_key(p_idempotency_id, p_idempotency_generation);
  if v_key is null then return jsonb_build_object('outcome', 'forbidden'); end if;
  select * into a from public.assignments x
  where x.id = p_assignment and x.deleted_at is null for update;
  if a.id is null then return jsonb_build_object('outcome', 'not_found'); end if;
  if a.school_id <> nullif(current_setting('studafy.school_id', true), '')::uuid
     or not private.coursework_teacher(a.classroom_id) then
    return jsonb_build_object('outcome', 'forbidden');
  end if;
  update public.assignment_extensions set revoked_at = now(), revoked_by = auth.uid()
  where assignment_id = a.id and student_id = (body->>'studentId')::uuid
    and revoked_at is null
  returning id into v_id;
  if v_id is null then return jsonb_build_object('outcome', 'not_found'); end if;
  return private.coursework_finish(
    p_idempotency_id, p_idempotency_generation, 200, 'assignment_extension_revoked',
    'assignment', a.id, null,
    jsonb_build_object('operation', 'revokeAssignmentExtension',
      'studentId', body->>'studentId'),
    private.assignment_extension_json(v_id));
end;
$$;

create or replace function private.api041_reopen_assignment(
  p_assignment uuid, p_input jsonb, p_idempotency_id uuid,
  p_idempotency_generation bigint)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  body jsonb := coalesce(p_input->'body', '{}'::jsonb);
  v_key text;
  a public.assignments%rowtype;
  v_closes timestamptz;
begin
  v_key := private.coursework_idempotency_key(p_idempotency_id, p_idempotency_generation);
  if v_key is null then return jsonb_build_object('outcome', 'forbidden'); end if;
  select * into a from public.assignments x
  where x.id = p_assignment and x.deleted_at is null for update;
  if a.id is null then return jsonb_build_object('outcome', 'not_found'); end if;
  if a.school_id <> nullif(current_setting('studafy.school_id', true), '')::uuid
     or not private.coursework_teacher(a.classroom_id) then
    return jsonb_build_object('outcome', 'forbidden');
  end if;
  if a.version <> (body->>'expectedVersion')::bigint then
    return jsonb_build_object('outcome', 'version_conflict');
  end if;
  if a.state <> 'published' then return jsonb_build_object('outcome', 'invalid_state'); end if;
  v_closes := private.school_instant(a.school_id, body->>'closesAtLocal');
  if v_closes is null or v_closes <= now() or v_closes < a.due_at then
    return jsonb_build_object('outcome', 'invalid');
  end if;

  update public.assignments set closes_at = v_closes, version = version + 1,
    updated_at = now()
  where id = a.id;
  return private.coursework_finish(
    p_idempotency_id, p_idempotency_generation, 200, 'assignment_reopened',
    'assignment', a.id,
    jsonb_build_object('closesAt', a.closes_at, 'version', a.version),
    jsonb_build_object('operation', 'reopenAssignment', 'closesAt', v_closes,
      'reason', btrim(body->>'reason')),
    private.api041_assignment_json(a.id));
end;
$$;

-- The live extensions on one piece of work, for its teachers.
create or replace function private.api041_assignment_extensions(p_assignment uuid, p_input jsonb)
returns jsonb
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  a public.assignments%rowtype;
begin
  select * into a from public.assignments x where x.id = p_assignment and x.deleted_at is null;
  if a.id is null or a.school_id is distinct from nullif(current_setting('studafy.school_id', true), '')::uuid
     or not private.coursework_staff(a.classroom_id) then
    return jsonb_build_object('outcome', 'not_found');
  end if;
  -- One extension per enrolled student at most, so one bounded page.
  return jsonb_build_object('items', coalesce((
    select jsonb_agg(private.assignment_extension_json(x.id) order by x.student_id)
    from public.assignment_extensions x
    where x.assignment_id = a.id and x.revoked_at is null), '[]'::jsonb),
    'nextPosition', null);
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
  v_school uuid;
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
    when 'submitAssignment' then
      return private.api041_submit_assignment(
        p_resource_id, p_input, p_idempotency_id, p_idempotency_generation);
    when 'grantAssignmentExtension' then
      return private.api041_grant_extension(
        p_resource_id, p_input, p_idempotency_id, p_idempotency_generation);
    when 'revokeAssignmentExtension' then
      return private.api041_revoke_extension(
        p_resource_id, p_input, p_idempotency_id, p_idempotency_generation);
    when 'reopenAssignment' then
      return private.api041_reopen_assignment(
        p_resource_id, p_input, p_idempotency_id, p_idempotency_generation);
    else null;
  end case;

  -- A due time picked as the school's wall-clock time wins over the instant
  -- the device worked out, which assumed the device's own zone.
  if p_operation = 'createAssignment'
     and ((p_input->'body') ? 'dueLocal' or (p_input->'body') ? 'closesLocal') then
    select c.school_id into v_school from public.classrooms c where c.id = v_class;
    if (p_input->'body'->>'dueLocal') is not null then
      p_input := jsonb_set(p_input, '{body,dueAt}',
        to_jsonb(private.school_instant(v_school, p_input->'body'->>'dueLocal')));
    end if;
    if (p_input->'body'->>'closesLocal') is not null then
      p_input := jsonb_set(p_input, '{body,closesAt}',
        to_jsonb(private.school_instant(v_school, p_input->'body'->>'closesLocal')));
    end if;
  end if;

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
exception when invalid_text_representation or invalid_datetime_format then
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

do $grants$
declare
  f text;
begin
  foreach f in array array[
    'private.school_instant(uuid,text)',
    'private.school_local_text(uuid,timestamptz)',
    'private.submission_gate(uuid,uuid)',
    'private.api041_assignment_json(uuid)',
    'private.assignment_student_json(uuid,uuid)',
    'private.api041_submit_assignment(uuid,jsonb,uuid,bigint)',
    'private.assignment_extension_json(uuid)',
    'private.api041_grant_extension(uuid,jsonb,uuid,bigint)',
    'private.api041_revoke_extension(uuid,jsonb,uuid,bigint)',
    'private.api041_reopen_assignment(uuid,jsonb,uuid,bigint)',
    'private.api041_assignment_extensions(uuid,jsonb)'
  ] loop
    execute format('alter function %s owner to postgres', f);
    execute format('revoke all on function %s from public, anon, authenticated, service_role, studafy_api_runtime, studafy_worker_runtime', f);
  end loop;
end;
$grants$;
