-- Editing lessons and the material on set work, without losing the files a
-- school keeps; lesson files downloadable by the students they were for.
--
-- Three gaps closed here:
--
--   * Revising a published lesson set it back to draft, so correcting a typo
--     hid the lesson from the class until it was published again, and a
--     lesson's file could not be replaced at all. editResource keeps the
--     lesson's state: its new version gets a new publication, the previous
--     publication is marked withdrawn (superseded), and the previous version
--     and its file are kept. Staff can still open the old file; students and
--     families see only the current one.
--   * Material on an assignment or assessment could not be changed after the
--     work was set. updateWorkMaterials adds files and detaches others; a
--     detached file is hidden from the class but never deleted, and stays
--     readable by the class's staff.
--   * A lesson's file was never returned with the lesson, so a student or
--     parent could not reach it to download. Resources now carry their
--     current file as attachments, in the shape every other surface uses.
--
-- Downloads still go through FILE-051: an authorised, single-use grant a
-- few minutes long, streamed from private storage.

alter table public.file_bindings
  add column if not exists detached_at timestamptz,
  add column if not exists detached_by uuid references public.profiles(id) on delete set null;

-- Material still attached to its work, which is how set work lists it.
create index if not exists file_material_binding_live_assignment_idx
  on public.file_bindings (assignment_id)
  where assignment_id is not null and detached_at is null;
create index if not exists file_material_binding_live_assessment_idx
  on public.file_bindings (assessment_id)
  where assessment_id is not null and detached_at is null;

create or replace function private.file_attachment_json(p_submission_attempt uuid DEFAULT NULL::uuid, p_message uuid DEFAULT NULL::uuid, p_announcement uuid DEFAULT NULL::uuid, p_assignment uuid DEFAULT NULL::uuid, p_assessment uuid DEFAULT NULL::uuid)
returns jsonb
language sql
stable
security definer
set search_path = ''
as $function$
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
    -- A detached file is kept, not listed.
    and b.detached_at is null
    and (p_submission_attempt is not null
      and b.submission_attempt_id = p_submission_attempt
      or p_message is not null and b.message_id = p_message
      or p_announcement is not null and b.announcement_id = p_announcement
      or p_assignment is not null and b.assignment_id = p_assignment
      or p_assessment is not null and b.assessment_id = p_assessment);
$function$;

-- A lesson with its current file, if it has one.
create or replace function private.api041_resource_json(p_id uuid)
returns jsonb
language sql
stable
security definer
set search_path = ''
as $function$
  select jsonb_build_object(
    'id',r.id,'schoolId',r.school_id,'classroomId',rp.classroom_id,'title',r.title,
    'resourceType',r.resource_type,'body',rv.body,'state',r.state,
    'version',r.version,'publishedAt',rp.published_at,
    'attachments',coalesce((select jsonb_agg(jsonb_build_object(
        'id', fo.id, 'displayName', fo.display_name, 'sizeBytes', fo.size_bytes,
        'mediaType', fo.declared_media_type, 'scanState', fo.scan_state))
      from public.file_objects fo
      where fo.id = rv.file_object_id and fo.deleted_at is null), '[]'::jsonb)
  ) from public.resources r
  join public.resource_versions rv on rv.resource_id=r.id and rv.version=r.current_version
  left join lateral (select x.classroom_id,x.published_at from public.resource_publications x
    where x.resource_version_id=rv.id order by x.created_at desc limit 1) rp on true
  where r.id=p_id;
$function$;

-- ---------------------------------------------------------------------------
-- Editing a lesson.
-- ---------------------------------------------------------------------------

create or replace function private.api041_edit_resource(
  p_resource uuid, p_input jsonb, p_idempotency_id uuid,
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
  r public.resources%rowtype;
  rv public.resource_versions%rowtype;
  rp public.resource_publications%rowtype;
  f public.file_objects%rowtype;
  v_replace uuid := nullif(body->>'replaceFileId', '')::uuid;
  v_file uuid;
  v_version_id uuid;
  v_before jsonb;
begin
  v_key := private.coursework_idempotency_key(p_idempotency_id, p_idempotency_generation);
  if v_key is null then return jsonb_build_object('outcome', 'forbidden'); end if;
  select * into r from public.resources x
  where x.id = p_resource and x.deleted_at is null for update;
  if r.id is null then return jsonb_build_object('outcome', 'not_found'); end if;
  select * into rv from public.resource_versions x
  where x.resource_id = r.id and x.version = r.current_version;
  select * into rp from public.resource_publications x
  where x.resource_version_id = rv.id order by x.created_at desc limit 1;
  if r.school_id <> v_tenant or not (r.created_by = auth.uid()
      or (rp.classroom_id is not null and private.coursework_teacher(rp.classroom_id))) then
    return jsonb_build_object('outcome', 'forbidden');
  end if;
  if r.version <> (body->>'expectedVersion')::bigint then
    return jsonb_build_object('outcome', 'version_conflict');
  end if;
  if r.state = 'archived' then return jsonb_build_object('outcome', 'invalid_state'); end if;

  v_file := rv.file_object_id;
  if v_replace is not null then
    -- The same checks publishing a lesson file makes: the caller's own clean
    -- lesson upload, started for this lesson's class, not used elsewhere.
    select * into f from public.file_objects x where x.id = v_replace for update;
    if f.id is null or f.deleted_at is not null or f.school_id <> r.school_id
       or f.owner_id is distinct from auth.uid() then
      return jsonb_build_object('outcome', 'forbidden');
    end if;
    if f.purpose <> 'lesson_resource' or rv.file_object_id is null then
      return jsonb_build_object('outcome', 'invalid');
    end if;
    if f.scan_state <> 'clean' then return jsonb_build_object('outcome', 'file_not_clean'); end if;
    if exists (select 1 from public.file_bindings b
        where b.file_object_id = f.id and b.upload_session_id is null) then
      return jsonb_build_object('outcome', 'invalid_state');
    end if;
    if not exists (select 1 from public.file_bindings b
        join public.upload_sessions u on u.id = b.upload_session_id
        where b.file_object_id = f.id and u.classroom_id is not distinct from rp.classroom_id) then
      return jsonb_build_object('outcome', 'forbidden');
    end if;
    v_file := f.id;
  end if;

  v_before := private.api041_resource_json(r.id);
  update public.resources set
    title = coalesce(nullif(btrim(body->>'title'), ''), title),
    current_version = current_version + 1, version = version + 1, updated_at = now()
  where id = r.id;
  insert into public.resource_versions(school_id, resource_id, version, body, file_object_id, created_by)
  values (r.school_id, r.id, r.current_version + 1,
    case when body ? 'body' then body->>'body' else rv.body end, v_file, auth.uid())
  returning id into v_version_id;
  if v_file is not null then
    insert into public.file_bindings(school_id, file_object_id, resource_version_id)
    values (r.school_id, v_file, v_version_id);
  end if;

  -- The lesson stays where it was, as visible as it was.
  if rp.id is not null then
    insert into public.resource_publications(school_id, resource_version_id, classroom_id,
      audience, state, published_at, created_by, version, lesson_session_id)
    values (r.school_id, v_version_id, rp.classroom_id, rp.audience, rp.state,
      case when rp.state = 'published' then now() end, auth.uid(), 1, rp.lesson_session_id);
    -- The superseded publication is withdrawn, not deleted: its version and
    -- file remain, readable by staff.
    if rp.state = 'published' then
      update public.resource_publications set state = 'withdrawn', withdrawn_at = now(),
        version = version + 1, updated_at = now()
      where id = rp.id;
    end if;
  end if;

  return private.coursework_finish(
    p_idempotency_id, p_idempotency_generation, 200, 'resource_edited',
    'resource', r.id, v_before,
    jsonb_build_object('operation', 'editResource', 'version', r.version + 1,
      'replacedFileId', case when v_replace is not null then rv.file_object_id end,
      'fileId', v_file),
    private.api041_resource_json(r.id));
end;
$$;

-- ---------------------------------------------------------------------------
-- Material on set work.
-- ---------------------------------------------------------------------------

create or replace function private.api041_update_work_materials(
  p_operation text, p_target uuid, p_input jsonb, p_idempotency_id uuid,
  p_idempotency_generation bigint)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  body jsonb := coalesce(p_input->'body', '{}'::jsonb);
  v_tenant uuid := nullif(current_setting('studafy.school_id', true), '')::uuid;
  v_assignment boolean := p_operation = 'updateAssignmentMaterials';
  v_key text;
  v_school uuid;
  v_class uuid;
  v_version bigint;
  v_detach uuid[];
  v_bind text;
  v_live int;
  v_response jsonb;
begin
  v_key := private.coursework_idempotency_key(p_idempotency_id, p_idempotency_generation);
  if v_key is null then return jsonb_build_object('outcome', 'forbidden'); end if;
  if v_assignment then
    select a.school_id, a.classroom_id, a.version into v_school, v_class, v_version
    from public.assignments a where a.id = p_target and a.deleted_at is null for update;
  else
    select a.school_id, a.classroom_id, a.version into v_school, v_class, v_version
    from public.assessments a where a.id = p_target and a.deleted_at is null for update;
  end if;
  if v_school is null then return jsonb_build_object('outcome', 'not_found'); end if;
  if v_school <> v_tenant or not private.coursework_teacher(v_class) then
    return jsonb_build_object('outcome', 'forbidden');
  end if;
  if v_version <> (body->>'expectedVersion')::bigint then
    return jsonb_build_object('outcome', 'version_conflict');
  end if;

  select coalesce(array_agg(x::uuid), array[]::uuid[]) into v_detach
  from jsonb_array_elements_text(coalesce(body->'detachFileIds', '[]'::jsonb)) x;

  begin
    update public.file_bindings b set detached_at = now(), detached_by = auth.uid()
    where b.file_object_id = any(v_detach) and b.detached_at is null
      and ((v_assignment and b.assignment_id = p_target)
        or (not v_assignment and b.assessment_id = p_target));
    if jsonb_array_length(coalesce(body->'attachmentFileIds', '[]'::jsonb)) > 0 then
      v_bind := case when v_assignment then
        private.file_attach_bind(body->'attachmentFileIds',
          'assignment_material'::public.file_purpose, v_school, p_assignment => p_target)
      else
        private.file_attach_bind(body->'attachmentFileIds',
          'assignment_material'::public.file_purpose, v_school, p_assessment => p_target)
      end;
      if v_bind <> 'ok' then raise exception using errcode = 'SF044', message = v_bind; end if;
    end if;
    select count(*) into v_live from public.file_bindings b
    where b.detached_at is null
      and ((v_assignment and b.assignment_id = p_target)
        or (not v_assignment and b.assessment_id = p_target));
    if v_live > 5 then raise exception using errcode = 'SF044', message = 'invalid'; end if;
  exception when sqlstate 'SF044' then
    return jsonb_build_object('outcome', sqlerrm);
  end;

  if v_assignment then
    update public.assignments set version = version + 1, updated_at = now() where id = p_target;
    v_response := private.api041_assignment_json(p_target);
  else
    update public.assessments set version = version + 1, updated_at = now() where id = p_target;
    v_response := private.api041_assessment_json(p_target);
  end if;

  return private.coursework_finish(
    p_idempotency_id, p_idempotency_generation, 200, 'work_materials_updated',
    case when v_assignment then 'assignment' else 'assessment' end, p_target, null,
    jsonb_build_object('operation', p_operation, 'version', v_response->'version',
      'detached', to_jsonb(v_detach), 'attached', body->'attachmentFileIds'),
    v_response);
end;
$$;

-- ---------------------------------------------------------------------------
-- Downloads: a detached file stays readable by the class's staff only.
-- ---------------------------------------------------------------------------

create or replace function private.file051_authorize_download(p_file_id uuid)
returns jsonb
language plpgsql
stable
security definer
set search_path = ''
as $function$
declare
  decision jsonb;
begin
  decision := private.file051_authorize_download_pre_guardian_reads(p_file_id);
  if not coalesce((decision->>'allowed')::boolean, false)
    and coalesce(decision->>'reason', '') <> 'invalid_resource' then
    if exists (
      select 1 from public.file_bindings b
      left join public.assignments asg on asg.id = b.assignment_id
      left join public.assessments ass on ass.id = b.assessment_id
      where b.file_object_id = p_file_id
        and (
          (asg.id is not null and asg.state = 'published' and asg.deleted_at is null
            and exists (select 1 from public.guardian_links own_gl
            where own_gl.guardian_id = auth.uid() and own_gl.status = 'verified'
              and private.is_linked_guardian(own_gl.student_id, asg.classroom_id)))
          or (ass.id is not null and ass.state = 'published' and ass.deleted_at is null
            and exists (select 1 from public.guardian_links own_gl
            where own_gl.guardian_id = auth.uid() and own_gl.status = 'verified'
              and private.is_linked_guardian(own_gl.student_id, ass.classroom_id)))
        )
    ) or exists (
      select 1 from public.file_bindings b
      join public.resource_publications rp on rp.resource_version_id = b.resource_version_id
      where b.file_object_id = p_file_id
        and rp.state = 'published' and rp.published_at is not null
        and rp.withdrawn_at is null and rp.classroom_id is not null
        and rp.audience in ('guardians', 'both')
        and exists (select 1 from public.guardian_links own_gl
            where own_gl.guardian_id = auth.uid() and own_gl.status = 'verified'
              and private.is_linked_guardian(own_gl.student_id, rp.classroom_id))
    ) then
      decision := jsonb_build_object('allowed', true,
        'schoolId', decision->'schoolId', 'reason', 'linked_guardian');
    end if;
  end if;

  -- Material a teacher detached from set work is kept for the school's
  -- record but is no longer the class's to read. Material files are bound to
  -- one piece of work only, so "every material binding is detached" is
  -- exactly "this file was taken off the work".
  if coalesce((decision->>'allowed')::boolean, false)
     and decision->>'reason' in ('work_audience', 'linked_guardian')
     and exists (select 1 from public.file_bindings b
       where b.file_object_id = p_file_id and b.detached_at is not null
         and (b.assignment_id is not null or b.assessment_id is not null))
     and not exists (select 1 from public.file_bindings b
       where b.file_object_id = p_file_id and b.detached_at is null
         and (b.assignment_id is not null or b.assessment_id is not null))
     and not exists (select 1 from public.file_bindings b
       left join public.assignments asg on asg.id = b.assignment_id
       left join public.assessments ass on ass.id = b.assessment_id
       where b.file_object_id = p_file_id
         and private.coursework_staff(coalesce(asg.classroom_id, ass.classroom_id))) then
    return jsonb_build_object('allowed', false,
      'schoolId', decision->'schoolId', 'reason', 'detached');
  end if;

  return decision;
end;
$function$;

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
    when 'editResource' then
      return private.api041_edit_resource(
        p_resource_id, p_input, p_idempotency_id, p_idempotency_generation);
    when 'updateAssignmentMaterials', 'updateAssessmentMaterials' then
      return private.api041_update_work_materials(
        p_operation, p_resource_id, p_input, p_idempotency_id, p_idempotency_generation);
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

do $grants$
declare
  f text;
begin
  foreach f in array array[
    'private.file_attachment_json(uuid,uuid,uuid,uuid,uuid)',
    'private.api041_resource_json(uuid)',
    'private.api041_edit_resource(uuid,jsonb,uuid,bigint)',
    'private.api041_update_work_materials(text,uuid,jsonb,uuid,bigint)',
    'private.file051_authorize_download(uuid)'
  ] loop
    execute format('alter function %s owner to postgres', f);
    execute format('revoke all on function %s from public, anon, authenticated, service_role, studafy_api_runtime, studafy_worker_runtime', f);
  end loop;
end;
$grants$;
