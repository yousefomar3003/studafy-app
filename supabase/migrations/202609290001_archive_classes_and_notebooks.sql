-- A teacher deletes a class; notebooks outlive it (2026-09-29).
--
-- "Delete" is archive: the class leaves every class list (they already skip
-- archived classes), nobody can join or post to it, and nothing that
-- belongs to a student is removed. A student's notebook for it stays theirs
-- and is shown as belonging to a class that no longer exists. A hard delete
-- would cascade into notebook_entries, which is exactly what must not happen,
-- so no path here ever deletes a classroom row.
--
-- Also: a notebook entry can say it was made from a lesson, and a student
-- can list every notebook they have, grouped by class, archived ones too.

-- ---------------------------------------------------------------------------
-- 1. Archiving a class.
-- ---------------------------------------------------------------------------
create or replace function private.api041_archive_classroom(
  p_resource_id uuid, p_input jsonb,
  p_idempotency_id uuid, p_idempotency_generation bigint)
returns jsonb language plpgsql security definer set search_path = '' as $$
declare
  tenant uuid := nullif(current_setting('studafy.school_id', true), '')::uuid;
  request_id text := nullif(current_setting('studafy.request_id', true), '');
  body jsonb := coalesce(p_input->'body', '{}'::jsonb);
  v_school uuid;
  v_version bigint;
  v_status public.classroom_status;
  idem_key text;
  response jsonb;
begin
  if auth.uid() is null or tenant is null or request_id is null then
    return jsonb_build_object('outcome', 'forbidden');
  end if;
  select r.idempotency_key into idem_key from public.idempotency_records r
  where r.id = p_idempotency_id and r.actor_id = auth.uid()
    and r.school_id = tenant and r.generation = p_idempotency_generation
    and r.status = 'reserved'
  for update;
  if idem_key is null then return jsonb_build_object('outcome', 'forbidden'); end if;

  select c.school_id, c.version, c.status into v_school, v_version, v_status
  from public.classrooms c where c.id = p_resource_id for update;
  if v_school is null then return jsonb_build_object('outcome', 'not_found'); end if;
  -- Only a teacher of the class (or the school's administrator) may.
  if v_school <> tenant or not (
    private.api041_class_writer(p_resource_id) or private.is_school_admin(tenant)
  ) then
    return jsonb_build_object('outcome', 'forbidden');
  end if;
  if v_version <> (body->>'expectedVersion')::bigint then
    return jsonb_build_object('outcome', 'version_conflict');
  end if;
  if v_status = 'archived' then
    return jsonb_build_object('outcome', 'invalid_state');
  end if;

  update public.classrooms
  set status = 'archived', archived_at = now(), version = version + 1,
      updated_at = now()
  where id = p_resource_id;
  -- Its join links stop working with it.
  update public.class_join_links set revoked_at = coalesce(revoked_at, now())
  where classroom_id = p_resource_id;

  response := private.api041_classroom_json(p_resource_id);
  insert into public.audit_events(
    school_id, actor_id, action, entity_type, entity_id, after_value, request_id)
  values (tenant, auth.uid(), 'classroom_archived', 'classroom', p_resource_id,
    response, request_id);
  if not private.api_idempotency_complete(
    p_idempotency_id, p_idempotency_generation, 200, response) then
    raise exception 'API041_IDEMPOTENCY_COMPLETION_FAILED';
  end if;
  return jsonb_build_object('outcome', 'ok', 'response', response);
end;
$$;

revoke all on function private.api041_archive_classroom(uuid, jsonb, uuid, bigint)
  from public, anon, authenticated, service_role, studafy_api_runtime,
  studafy_worker_runtime;
alter function private.api041_archive_classroom(uuid, jsonb, uuid, bigint)
  owner to postgres;

-- The command dispatcher, routing archiveClassroom to its handler. Copied
-- from its current definition otherwise unchanged; no rename, no new link.
CREATE OR REPLACE FUNCTION private.api041_command(p_operation text, p_resource_id uuid, p_input jsonb, p_idempotency_id uuid, p_idempotency_generation bigint)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
declare
  v_assignment uuid := nullif((p_input->'body')->>'assignmentId', '')::uuid;
  v_class uuid := nullif((p_input->'body')->>'classroomId', '')::uuid;
  result jsonb;
  v_assessment uuid;
  v_response jsonb;
begin
  -- Named handlers first (ADR-0030): each owns its operation outright.
  if p_operation = 'archiveClassroom' then
    return private.api041_archive_classroom(
      p_resource_id, p_input, p_idempotency_id, p_idempotency_generation);
  end if;
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
$function$;

-- ---------------------------------------------------------------------------
-- 2. A note made from a lesson.
-- ---------------------------------------------------------------------------
alter table public.notebook_entries
  drop constraint if exists notebook_entries_source_check;
alter table public.notebook_entries
  add constraint notebook_entries_source_check
  check (source in ('typed', 'whiteboard', 'lesson'));

-- ---------------------------------------------------------------------------
-- 3. Every notebook a student has, by class - archived classes included.
--
-- Only the caller's own entries, whichever class they were written in: they
-- are the student's notes, and a class being archived takes nothing away.
-- ---------------------------------------------------------------------------
create or replace function private.api049_notebooks(
  p_operation text, p_resource_id uuid, p_input jsonb)
returns jsonb language plpgsql stable security definer set search_path = '' as $$
declare
  v_lesson jsonb;
begin
  if auth.uid() is null or not private.is_active_user() then
    return jsonb_build_object('outcome', 'forbidden');
  end if;
  case p_operation
    when 'myNotebooks' then
      return jsonb_build_object('outcome', 'ok', 'classes', coalesce((
        select jsonb_agg(jsonb_build_object(
            'classroomId', c.id,
            'name', c.name,
            'archived', c.archived_at is not null,
            'entries', (
              select coalesce(jsonb_agg(private.notebook_entry_json(n.id)
                order by n.created_at desc), '[]'::jsonb)
              from public.notebook_entries n
              where n.owner_id = auth.uid() and n.classroom_id = c.id
                and n.deleted_at is null))
          order by (c.archived_at is not null), c.name)
        from public.classrooms c
        where exists (
          select 1 from public.notebook_entries n
          where n.owner_id = auth.uid() and n.classroom_id = c.id
            and n.deleted_at is null)
      ), '[]'::jsonb));

    when 'lessonForNotes' then
      -- Turning a lesson into study notes is Studafy Plus, like the
      -- whiteboard: only a lesson the caller can see, only its text.
      if private.study_plan(auth.uid()) not in ('plus', 'max') then
        return jsonb_build_object('outcome', 'plan_required');
      end if;
      v_lesson := private.study_lesson(p_resource_id);
      if v_lesson is null then return jsonb_build_object('outcome', 'not_found'); end if;
      return jsonb_build_object('outcome', 'ok', 'lesson', v_lesson);

    else
      return jsonb_build_object('outcome', 'invalid');
  end case;
end;
$$;

revoke all on function private.api049_notebooks(text, uuid, jsonb)
  from public, anon, authenticated, service_role, studafy_worker_runtime;
grant execute on function private.api049_notebooks(text, uuid, jsonb)
  to studafy_api_runtime;
alter function private.api049_notebooks(text, uuid, jsonb) owner to postgres;
