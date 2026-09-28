-- Files a teacher attaches to the work they set.
--
-- The `assignment_material` purpose has existed since FILE-050, but it needed
-- the assignment to exist before the upload could start, and nothing ever
-- bound the result to anything a student could read. So a teacher could not
-- attach a worksheet while writing an assignment, and a student could not
-- open one if they had.
--
-- This follows the shape chat and announcements already use:
--
--   1. The upload starts while the teacher is still writing, scoped to the
--      class they are writing for. Only that class's lead or co-teachers (or
--      a school admin) may start it.
--   2. Creating the assignment or assessment binds the files to it, through
--      the one binding gate. The gate now also refuses a file uploaded for a
--      different class, so an upload authorised for class A cannot be bound
--      to work in class B.
--   3. Who may open a bound file is the same test as who may see the work:
--      the class's staff, and - once it is published - its enrolled students
--      and their verified guardians.
--
-- A refused binding rolls back the assignment it came with. The chat and
-- submission wrappers return a refusal after their delegate has already
-- written; here the delegate and the bind share a savepoint, so a teacher is
-- never told "that failed" about work that was in fact created.
--
-- Forward-only: everything changed is renamed and delegated to, or re-issued
-- whole, never edited in an earlier file.

-- ---------------------------------------------------------------------------
-- 1. Uploads may be scoped to a class rather than an existing assignment.
-- ---------------------------------------------------------------------------
alter table public.upload_sessions
  drop constraint if exists file050_upload_target_check;
alter table public.upload_sessions
  add constraint file050_upload_target_check check (
    policy_version='legacy' or case purpose
      when 'profile_image' then num_nonnulls(classroom_id,assignment_id,student_id,grade_result_id)=0
      when 'lesson_resource' then classroom_id is not null and num_nonnulls(assignment_id,student_id,grade_result_id)=0
      -- An existing assignment, or the class the work is being written for.
      when 'assignment_material' then num_nonnulls(classroom_id,assignment_id)=1 and num_nonnulls(student_id,grade_result_id)=0
      when 'assignment_submission' then assignment_id is not null and student_id is not null and num_nonnulls(classroom_id,grade_result_id)=0
      when 'paper_scan' then grade_result_id is not null and num_nonnulls(classroom_id,assignment_id,student_id)=0
      when 'coach_attachment' then student_id is not null and num_nonnulls(classroom_id,assignment_id,grade_result_id)=0
      when 'message_attachment' then num_nonnulls(classroom_id,assignment_id,student_id,grade_result_id)=0
      when 'announcement_attachment' then num_nonnulls(classroom_id,assignment_id,student_id,grade_result_id)=0
      else false end
  ) not valid;
alter table public.upload_sessions validate constraint file050_upload_target_check;

do $$ begin
  if not exists (
    select 1 from pg_proc p join pg_namespace n on n.oid = p.pronamespace
    where n.nspname = 'private' and p.proname = 'file050_authorize_target_pre_materials'
  ) then
    alter function private.file050_authorize_target(jsonb)
      rename to file050_authorize_target_pre_materials;
  end if;
end $$;

create or replace function private.file050_authorize_target(p_body jsonb)
returns jsonb language plpgsql stable security definer set search_path = '' as $$
begin
  -- A class-scoped material upload asks exactly what a lesson resource
  -- upload asks - is the caller a lead or co-teacher of that class, or an
  -- admin of its school - so it is put to that same test rather than a
  -- second copy of it.
  if p_body->>'purpose' = 'assignment_material'
    and nullif(p_body->>'assignmentId', '') is null
    and nullif(p_body->>'classroomId', '') is not null then
    return private.file050_authorize_target_pre_materials(
      jsonb_set(p_body, array['purpose'], '"lesson_resource"'::jsonb));
  end if;
  return private.file050_authorize_target_pre_materials(p_body);
end;
$$;

alter function private.file050_authorize_target(jsonb) owner to postgres;
alter function private.file050_authorize_target_pre_materials(jsonb)
  owner to postgres;
revoke all on function private.file050_authorize_target(jsonb)
  from public, anon, authenticated, service_role, studafy_worker_runtime,
  studafy_api_runtime;
revoke all on function private.file050_authorize_target_pre_materials(jsonb)
  from public, anon, authenticated, service_role, studafy_worker_runtime,
  studafy_api_runtime;

-- ---------------------------------------------------------------------------
-- 2. Assignments and assessments become binding targets.
-- ---------------------------------------------------------------------------
alter table public.file_bindings
  add column if not exists assignment_id uuid,
  add column if not exists assessment_id uuid;

do $$ begin
  if not exists (
    select 1 from pg_constraint
    where conrelid = 'public.file_bindings'::regclass
      and conname = 'file_material_binding_assignment_school_fk'
  ) then
    alter table public.file_bindings
      add constraint file_material_binding_assignment_school_fk
      foreign key (school_id, assignment_id)
      references public.assignments(school_id, id) on delete cascade not valid;
  end if;
  if not exists (
    select 1 from pg_constraint
    where conrelid = 'public.file_bindings'::regclass
      and conname = 'file_material_binding_assessment_school_fk'
  ) then
    alter table public.file_bindings
      add constraint file_material_binding_assessment_school_fk
      foreign key (school_id, assessment_id)
      references public.assessments(school_id, id) on delete cascade not valid;
  end if;
end $$;

alter table public.file_bindings
  drop constraint if exists file050_binding_one_target;
alter table public.file_bindings
  add constraint file050_binding_one_target check (
    num_nonnulls(
      resource_version_id, submission_attempt_id, message_id,
      ai_grading_draft_id, upload_session_id, announcement_id,
      assignment_id, assessment_id
    ) = 1
  ) not valid;
alter table public.file_bindings validate constraint file050_binding_one_target;

drop trigger if exists db021_immutable_file_binding on public.file_bindings;
create trigger db021_immutable_file_binding before update on public.file_bindings
for each row execute function private.reject_immutable_columns(
  'id', 'school_id', 'file_object_id', 'resource_version_id',
  'submission_attempt_id', 'message_id', 'ai_grading_draft_id',
  'upload_session_id', 'announcement_id', 'assignment_id', 'assessment_id',
  'created_at'
);

create index if not exists file_material_binding_assignment_idx
  on public.file_bindings (assignment_id) where assignment_id is not null;
create index if not exists file_material_binding_assessment_idx
  on public.file_bindings (assessment_id) where assessment_id is not null;

-- ---------------------------------------------------------------------------
-- 3. The binding gate, re-issued with two more targets.
--
-- Dropped and recreated rather than overloaded: two signatures differing only
-- in trailing defaults make every named-argument call ambiguous. Callers are
-- PL/pgSQL, resolved at call time, so they pick the new one up unchanged.
-- ---------------------------------------------------------------------------
drop function if exists private.file_attach_bind(
  jsonb, public.file_purpose, uuid, uuid, uuid, uuid);

create or replace function private.file_attach_bind(
  p_file_ids jsonb,
  p_purpose public.file_purpose,
  p_school uuid,
  p_submission_attempt uuid default null,
  p_message uuid default null,
  p_announcement uuid default null,
  p_assignment uuid default null,
  p_assessment uuid default null
) returns text language plpgsql security definer set search_path = '' as $$
declare
  v_ids uuid[];
  v_id uuid;
  v_file public.file_objects%rowtype;
  v_count int;
  v_target_class uuid;
begin
  if auth.uid() is null then return 'forbidden'; end if;
  if num_nonnulls(p_submission_attempt, p_message, p_announcement,
      p_assignment, p_assessment) <> 1 then
    raise exception 'FILE_ATTACH_TARGET_AMBIGUOUS';
  end if;
  if p_file_ids is null or jsonb_typeof(p_file_ids) <> 'array' then
    return 'ok';
  end if;

  select array_agg(distinct x::uuid), count(*)
    into v_ids, v_count
  from jsonb_array_elements_text(p_file_ids) x;
  if v_count = 0 then return 'ok'; end if;
  if v_count <> cardinality(v_ids) then return 'invalid'; end if;
  if cardinality(v_ids) > 5 then return 'invalid'; end if;

  if p_assignment is not null then
    select a.classroom_id into v_target_class
    from public.assignments a where a.id = p_assignment;
  elsif p_assessment is not null then
    select a.classroom_id into v_target_class
    from public.assessments a where a.id = p_assessment;
  end if;

  foreach v_id in array v_ids loop
    select * into v_file from public.file_objects fo where fo.id = v_id;
    if v_file.id is null or v_file.deleted_at is not null
      or v_file.scan_state = 'deleted' then
      return 'invalid';
    end if;
    if v_file.owner_id <> auth.uid() then return 'forbidden'; end if;
    if v_file.school_id <> p_school then return 'forbidden'; end if;
    if v_file.purpose <> p_purpose then return 'invalid'; end if;
    if exists (
      select 1 from public.file_bindings b
      where b.file_object_id = v_id
        and num_nonnulls(
          b.resource_version_id, b.submission_attempt_id, b.message_id,
          b.ai_grading_draft_id, b.announcement_id, b.assignment_id,
          b.assessment_id
        ) > 0
    ) then
      return 'invalid';
    end if;
    -- Material was authorised for one class when its upload started. Binding
    -- it to work in another would hand it to students the upload was never
    -- checked against.
    if v_target_class is not null and not exists (
      select 1 from public.file_bindings b
      join public.upload_sessions u on u.id = b.upload_session_id
      where b.file_object_id = v_id
        and (u.classroom_id = v_target_class
          or (select a.classroom_id from public.assignments a
              where a.id = u.assignment_id) = v_target_class)
    ) then
      return 'forbidden';
    end if;

    insert into public.file_bindings(
      school_id, file_object_id, submission_attempt_id, message_id,
      announcement_id, assignment_id, assessment_id)
    values (
      p_school, v_id, p_submission_attempt, p_message, p_announcement,
      p_assignment, p_assessment);
  end loop;

  return 'ok';
end;
$$;

revoke all on function private.file_attach_bind(
  jsonb, public.file_purpose, uuid, uuid, uuid, uuid, uuid, uuid)
  from public, anon, authenticated, service_role, studafy_worker_runtime,
  studafy_api_runtime;
alter function private.file_attach_bind(
  jsonb, public.file_purpose, uuid, uuid, uuid, uuid, uuid, uuid)
  owner to postgres;

-- The read model, likewise re-issued with the two new targets.
drop function if exists private.file_attachment_json(uuid, uuid, uuid);

create or replace function private.file_attachment_json(
  p_submission_attempt uuid default null,
  p_message uuid default null,
  p_announcement uuid default null,
  p_assignment uuid default null,
  p_assessment uuid default null
) returns jsonb language sql stable security definer set search_path = '' as $$
  select coalesce(
    jsonb_agg(
      jsonb_build_object(
        'id', fo.id,
        'displayName', fo.display_name,
        'sizeBytes', fo.size_bytes,
        'mediaType', fo.declared_media_type,
        'scanState', fo.scan_state
      ) order by fo.created_at, fo.id
    ),
    '[]'::jsonb
  )
  from public.file_bindings b
  join public.file_objects fo on fo.id = b.file_object_id
  where fo.deleted_at is null
    and (p_submission_attempt is not null
      and b.submission_attempt_id = p_submission_attempt
      or p_message is not null and b.message_id = p_message
      or p_announcement is not null and b.announcement_id = p_announcement
      or p_assignment is not null and b.assignment_id = p_assignment
      or p_assessment is not null and b.assessment_id = p_assessment);
$$;

revoke all on function private.file_attachment_json(uuid, uuid, uuid, uuid, uuid)
  from public, anon, authenticated, service_role, studafy_worker_runtime,
  studafy_api_runtime;
alter function private.file_attachment_json(uuid, uuid, uuid, uuid, uuid)
  owner to postgres;

-- ---------------------------------------------------------------------------
-- 4. Reads of the work carry its material.
--
-- Both builders are re-issued whole; they are short, and a wrapper around a
-- json builder would have to re-read the row anyway.
-- ---------------------------------------------------------------------------
create or replace function private.api041_assignment_json(p_id uuid)
returns jsonb language sql stable security definer set search_path='' as $$
  select jsonb_build_object('id',a.id,'classroomId',a.classroom_id,'title',a.title,
    'instructions',a.instructions,'dueAt',a.due_at,'closesAt',a.closes_at,
    'state',a.state,'version',a.version,'submissionId',s.id,'submittedAt',s.submitted_at,
    'attachments',private.file_attachment_json(p_assignment => a.id))
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
    'attachments',private.file_attachment_json(p_assessment => a.id))
  from public.assessments a where a.id=p_id;
$$;

alter function private.api041_assignment_json(uuid) owner to postgres;
alter function private.api041_assessment_json(uuid) owner to postgres;

-- ---------------------------------------------------------------------------
-- 5. Creating work binds its material, atomically.
-- ---------------------------------------------------------------------------
do $$ begin
  if not exists (
    select 1 from pg_proc p join pg_namespace n on n.oid = p.pronamespace
    where n.nspname = 'private' and p.proname = 'api041_command_pre_materials'
  ) then
    alter function private.api041_command(text, uuid, jsonb, uuid, bigint)
      rename to api041_command_pre_materials;
  end if;
end $$;

create or replace function private.api041_command(
  p_operation text, p_resource_id uuid, p_input jsonb,
  p_idempotency_id uuid, p_idempotency_generation bigint)
returns jsonb language plpgsql security definer set search_path = '' as $$
declare
  result jsonb;
  v_files jsonb := (p_input->'body')->'attachmentFileIds';
  v_entity uuid;
  v_school uuid;
  v_bind text;
  v_response jsonb;
begin
  if p_operation not in ('createAssignment', 'createAssessment')
    or v_files is null or jsonb_typeof(v_files) <> 'array'
    or jsonb_array_length(v_files) = 0 then
    return private.api041_command_pre_materials(
      p_operation, p_resource_id, p_input, p_idempotency_id,
      p_idempotency_generation);
  end if;

  -- One savepoint around the create and the bind: a refused file undoes the
  -- work it came with, and the idempotency completion with it, so a retry
  -- is a fresh attempt rather than a replay of a success that did not happen.
  begin
    result := private.api041_command_pre_materials(
      p_operation, p_resource_id, p_input, p_idempotency_id,
      p_idempotency_generation);
    if coalesce(result->>'outcome', '') <> 'ok' then return result; end if;

    v_entity := ((result->'response')->>'id')::uuid;
    if p_operation = 'createAssignment' then
      select a.school_id into v_school from public.assignments a where a.id = v_entity;
      v_bind := private.file_attach_bind(
        v_files, 'assignment_material'::public.file_purpose, v_school,
        p_assignment => v_entity);
    else
      select a.school_id into v_school from public.assessments a where a.id = v_entity;
      v_bind := private.file_attach_bind(
        v_files, 'assignment_material'::public.file_purpose, v_school,
        p_assessment => v_entity);
    end if;
    if v_bind <> 'ok' then
      raise exception using errcode = 'SF041', message = v_bind;
    end if;
  exception when sqlstate 'SF041' then
    return jsonb_build_object('outcome', sqlerrm);
  end;

  v_response := case when p_operation = 'createAssignment'
    then private.api041_assignment_json(v_entity)
    else private.api041_assessment_json(v_entity) end;

  -- The delegate stored its response before anything was bound. A replay
  -- must describe the same work the first answer did, files included.
  update public.idempotency_records r
  set response_body = v_response
  where r.id = p_idempotency_id and r.actor_id = auth.uid()
    and r.generation = p_idempotency_generation and r.status = 'completed';

  return jsonb_set(result, array['response'], v_response);
end;
$$;

alter function private.api041_command(text, uuid, jsonb, uuid, bigint)
  owner to postgres;
alter function private.api041_command_pre_materials(
  text, uuid, jsonb, uuid, bigint) owner to postgres;
-- Grants follow the OID through a rename; move the API role's EXECUTE to the
-- wrapper, as 202609250002 and 202609250003 did.
revoke all on function private.api041_command_pre_materials(
  text, uuid, jsonb, uuid, bigint)
  from public, anon, authenticated, service_role, studafy_worker_runtime,
  studafy_api_runtime;
revoke all on function private.api041_command(text, uuid, jsonb, uuid, bigint)
  from public, anon, authenticated, service_role, studafy_worker_runtime;
grant execute on function private.api041_command(
  text, uuid, jsonb, uuid, bigint) to studafy_api_runtime;

-- ---------------------------------------------------------------------------
-- 6. Who may open material: whoever may see the work.
--
-- Renamed and delegated: every earlier relationship stands, and this adds
-- one. Mirrors listAssignments/listAssessments exactly - staff always,
-- everyone else who can view the class once the work is published.
-- ---------------------------------------------------------------------------
do $$ begin
  if not exists (
    select 1 from pg_proc p join pg_namespace n on n.oid = p.pronamespace
    where n.nspname = 'private' and p.proname = 'file051_authorize_download_pre_materials'
  ) then
    alter function private.file051_authorize_download(uuid)
      rename to file051_authorize_download_pre_materials;
  end if;
end $$;

create or replace function private.file051_authorize_download(p_file_id uuid)
returns jsonb language plpgsql stable security definer set search_path = '' as $$
declare
  decision jsonb;
  v_school uuid;
begin
  decision := private.file051_authorize_download_pre_materials(p_file_id);
  if coalesce((decision->>'allowed')::boolean, false)
    or coalesce(decision->>'reason', '') = 'invalid_resource' then
    return decision;
  end if;

  select fo.school_id into v_school from public.file_objects fo where fo.id = p_file_id;

  if exists (
    select 1 from public.file_bindings b
    join public.assignments a on a.id = b.assignment_id
    where b.file_object_id = p_file_id
      and a.deleted_at is null
      and (private.is_school_admin(a.school_id)
        or private.is_class_staff(a.classroom_id)
        or (a.state = 'published' and private.can_view_classroom(a.classroom_id)))
  ) or exists (
    select 1 from public.file_bindings b
    join public.assessments a on a.id = b.assessment_id
    where b.file_object_id = p_file_id
      and a.deleted_at is null
      and (private.is_school_admin(a.school_id)
        or private.is_class_staff(a.classroom_id)
        or (a.state = 'published' and private.can_view_classroom(a.classroom_id)))
  ) then
    return jsonb_build_object('allowed', true, 'schoolId', v_school, 'reason', 'work_audience');
  end if;

  return decision;
end;
$$;

alter function private.file051_authorize_download(uuid) owner to postgres;
alter function private.file051_authorize_download_pre_materials(uuid)
  owner to postgres;
revoke all on function private.file051_authorize_download_pre_materials(uuid)
  from public, anon, authenticated, service_role, studafy_worker_runtime,
  studafy_api_runtime;
revoke all on function private.file051_authorize_download(uuid)
  from public, anon, authenticated, service_role, studafy_worker_runtime,
  studafy_api_runtime;
