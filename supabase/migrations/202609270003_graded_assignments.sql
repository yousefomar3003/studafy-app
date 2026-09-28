-- Graded assignments are assignments.
--
-- The "new assignment" form created graded work as an assessment instead of
-- an assignment, because grade_results attach to assessments. That made
-- graded work a different kind of thing from the rest of the coursework:
-- it did not appear among the assignments, the student could not open or
-- hand it in, and it could carry no hand-in history.
--
-- Now graded work is an assignment - handed in, with material and history,
-- like any other - plus an assessment that carries its mark, linked here.
-- The assignment says it is graded and out of how much; the assessment
-- stays what the gradebook reads, exactly as before.

alter table public.assessments
  add column if not exists assignment_id uuid;

do $$ begin
  if not exists (
    select 1 from pg_constraint
    where conrelid = 'public.assessments'::regclass
      and conname = 'assessments_assignment_school_fk'
  ) then
    alter table public.assessments
      add constraint assessments_assignment_school_fk
      foreign key (school_id, assignment_id)
      references public.assignments(school_id, id) on delete set null (assignment_id) not valid;
  end if;
end $$;

-- One mark per piece of work.
create unique index if not exists assessments_one_per_assignment
  on public.assessments (assignment_id) where assignment_id is not null;

-- ---------------------------------------------------------------------------
-- Reads: the assignment says it is graded; the assessment says what for.
-- ---------------------------------------------------------------------------
create or replace function private.api041_assignment_json(p_id uuid)
returns jsonb language sql stable security definer set search_path='' as $$
  select jsonb_build_object('id',a.id,'classroomId',a.classroom_id,'title',a.title,
    'instructions',a.instructions,'dueAt',a.due_at,'closesAt',a.closes_at,
    'state',a.state,'version',a.version,'submissionId',s.id,'submittedAt',s.submitted_at,
    'attachments',private.file_attachment_json(p_assignment => a.id),
    'maximumScore',(select g.maximum_score from public.assessments g
      where g.assignment_id = a.id and g.deleted_at is null limit 1))
  from public.assignments a left join lateral (
    select su.id,su.submitted_at from public.submissions su join public.students st on st.id=su.student_id
    where su.assignment_id=a.id and st.user_id=auth.uid() limit 1
  ) s on true where a.id=p_id;
$$;

create or replace function private.api041_assessment_json(p_id uuid)
returns jsonb language sql stable security definer set search_path='' as $$
  select jsonb_build_object('id',a.id,'classroomId',a.classroom_id,'title',a.title,
    'category',a.category,'maximumScore',a.maximum_score,'scheduledAt',a.scheduled_at,
    'delivery',a.delivery,'state',a.state,'version',a.version,
    'attachments',private.file_attachment_json(p_assessment => a.id),
    'assignmentId',a.assignment_id)
  from public.assessments a where a.id=p_id;
$$;

alter function private.api041_assignment_json(uuid) owner to postgres;
alter function private.api041_assessment_json(uuid) owner to postgres;

-- ---------------------------------------------------------------------------
-- Creating the mark for a piece of work links the two.
-- ---------------------------------------------------------------------------
do $$ begin
  if not exists (
    select 1 from pg_proc p join pg_namespace n on n.oid = p.pronamespace
    where n.nspname = 'private' and p.proname = 'api041_command_pre_graded'
  ) then
    alter function private.api041_command(text, uuid, jsonb, uuid, bigint)
      rename to api041_command_pre_graded;
  end if;
end $$;

create or replace function private.api041_command(
  p_operation text, p_resource_id uuid, p_input jsonb,
  p_idempotency_id uuid, p_idempotency_generation bigint)
returns jsonb language plpgsql security definer set search_path = '' as $$
declare
  v_assignment uuid := nullif((p_input->'body')->>'assignmentId', '')::uuid;
  v_class uuid := nullif((p_input->'body')->>'classroomId', '')::uuid;
  result jsonb;
  v_assessment uuid;
  v_response jsonb;
begin
  if p_operation <> 'createAssessment' or v_assignment is null then
    return private.api041_command_pre_graded(
      p_operation, p_resource_id, p_input, p_idempotency_id,
      p_idempotency_generation);
  end if;

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

  result := private.api041_command_pre_graded(
    p_operation, p_resource_id, p_input, p_idempotency_id,
    p_idempotency_generation);
  if coalesce(result->>'outcome', '') <> 'ok' then return result; end if;

  v_assessment := ((result->'response')->>'id')::uuid;
  update public.assessments set assignment_id = v_assignment
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
$$;

alter function private.api041_command(text, uuid, jsonb, uuid, bigint)
  owner to postgres;
alter function private.api041_command_pre_graded(
  text, uuid, jsonb, uuid, bigint) owner to postgres;
revoke all on function private.api041_command_pre_graded(
  text, uuid, jsonb, uuid, bigint)
  from public, anon, authenticated, service_role, studafy_worker_runtime,
  studafy_api_runtime;
revoke all on function private.api041_command(text, uuid, jsonb, uuid, bigint)
  from public, anon, authenticated, service_role, studafy_worker_runtime;
grant execute on function private.api041_command(
  text, uuid, jsonb, uuid, bigint) to studafy_api_runtime;
