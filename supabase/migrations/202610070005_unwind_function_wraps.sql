-- Unwinds the rename-and-wrap layers of 202610060001 and 202610070001
-- (ADR-0030, ADR-0040).
--
-- Those two migrations extended five functions by renaming each to
-- `<name>_pre_<change>` and wrapping it, which ADR-0030 forbids after
-- 202609280001. Both are applied to the hosted test database, so they are
-- not edited; this migration leaves the schema as ADR-0030 asks instead:
--
--   * private.authz_authorize was an exclusive layer (one action pair in
--     front of the flat dispatcher). It is flattened: the dispatcher below
--     is the live body of authz_authorize_pre_material with that one branch
--     added at the top, exactly where the wrapper tested it, and the
--     history-named layer is dropped.
--   * The other four are middleware layers - they rewrite a request, or
--     post-process the result - which ADR-0030 keeps as layers. Their inner
--     functions are renamed for what they do, bodies untouched, and the
--     outer functions replaced with their live bodies calling the new names:
--       api041_command_pre_assessments            -> api041_command_core
--       api041_query_pre_assessments              -> api041_query_core
--       file050_authorize_target_pre_paper_class  -> file050_authorize_target_by_purpose
--       file051_authorize_download_pre_assessments -> file051_authorize_material_download
--
-- Every body here is pg_get_functiondef of the function as it stands after
-- 202610070004, with only the called name changed, so behaviour is the
-- same by construction. scripts/check-migration-immutability.ts accepts a
-- wrap in a migration after 202609280001 only once a later migration, such
-- as this one, has unwound it.

-- ---------------------------------------------------------------------------
-- 1. Middleware layers: the inner functions get names for what they do.
-- ---------------------------------------------------------------------------

alter function private.api041_command_pre_assessments(text, uuid, jsonb, uuid, bigint)
  rename to api041_command_core;
alter function private.api041_query_pre_assessments(text, uuid, jsonb)
  rename to api041_query_core;
alter function private.file050_authorize_target_pre_paper_class(jsonb)
  rename to file050_authorize_target_by_purpose;
alter function private.file051_authorize_download_pre_assessments(uuid)
  rename to file051_authorize_material_download;

-- The academic command surface: online assessments, attachments and links on
-- coursework, then everything else through api041_command_core.
CREATE OR REPLACE FUNCTION private.api041_command(p_operation text, p_resource_id uuid, p_input jsonb, p_idempotency_id uuid, p_idempotency_generation bigint)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
declare
  body jsonb := coalesce(p_input->'body', '{}'::jsonb);
  result jsonb;
  v_id uuid;
  v_school uuid;
  v_class uuid;
  v_problem text;
  a public.assessments%rowtype;
  v_version uuid;
  v_response jsonb;
begin
  case p_operation
    when 'updateAssessmentDesign' then
      return private.api041_update_assessment_design(p_resource_id, p_input, p_idempotency_id, p_idempotency_generation);
    when 'grantAssessmentAccess' then
      return private.api041_grant_assessment_access(p_resource_id, p_input, p_idempotency_id, p_idempotency_generation);
    when 'submitAssessment' then
      return private.api041_submit_assessment(p_resource_id, p_input, p_idempotency_id, p_idempotency_generation);
    when 'markAssessmentAttempt' then
      return private.api041_mark_assessment_attempt(p_resource_id, p_input, p_idempotency_id, p_idempotency_generation);
    when 'updateGradeAttachments' then
      return private.api041_update_grade_attachments(p_resource_id, p_input, p_idempotency_id, p_idempotency_generation);
    when 'updateAssignmentMaterials', 'updateAssessmentMaterials' then
      if body ? 'links' or body ? 'removeLinkIds' then
        return private.api041_update_work_materials_with_links(p_operation, p_resource_id, p_input,
          p_idempotency_id, p_idempotency_generation);
      end if;
    when 'editResource' then
      return private.api041_edit_resource_with_attachments(p_resource_id, p_input,
        p_idempotency_id, p_idempotency_generation);
    else null;
  end case;

  if p_operation not in ('createAssessment', 'createAssignment', 'createResource') then
    return private.api041_command_core(p_operation, p_resource_id, p_input,
      p_idempotency_id, p_idempotency_generation);
  end if;

  -- The questions are checked before anything is created.
  if p_operation = 'createAssessment' and jsonb_typeof(body->'questions') = 'array' then
    if exists (select 1 from jsonb_array_elements(body->'questions') q
        where private.assessment_question_problem(q) is not null) then
      return jsonb_build_object('outcome', 'invalid');
    end if;
  end if;
  -- Links are checked before anything is created, too.
  if jsonb_typeof(body->'links') = 'array' and exists (
      select 1 from jsonb_array_elements(body->'links') l
      where char_length(btrim(coalesce(l->>'title', ''))) not between 1 and 120
        or not private.content_link_url_ok(btrim(l->>'url'))) then
    return jsonb_build_object('outcome', 'invalid');
  end if;

  begin
    result := private.api041_command_core(p_operation, p_resource_id, p_input,
      p_idempotency_id, p_idempotency_generation);
    if coalesce(result->>'outcome', '') <> 'ok' then return result; end if;
    v_id := ((result->'response')->>'id')::uuid;

    if p_operation = 'createAssessment' then
      select * into a from public.assessments x where x.id = v_id;
      if jsonb_typeof(body->'questions') = 'array' and jsonb_array_length(body->'questions') > 0 then
        -- The base wrote prompts and scores; the rest is written by position.
        v_problem := private.assessment_write_questions(a, (
          select jsonb_agg(item || jsonb_build_object('id', q.id) order by ord)
          from jsonb_array_elements(body->'questions') with ordinality t(item, ord)
          join public.assessment_questions q on q.assessment_id = a.id and q.position = (item->>'position')::int));
        if v_problem is not null then raise exception using errcode = 'SF051', message = v_problem; end if;
      end if;
      v_problem := private.assessment_write_settings(a, body);
      if v_problem is not null then raise exception using errcode = 'SF051', message = v_problem; end if;
      v_problem := private.content_links_attach(body->'links', a.school_id, p_assessment => a.id);
      if v_problem <> 'ok' then raise exception using errcode = 'SF051', message = v_problem; end if;
      v_response := private.api041_assessment_json(a.id);
    elsif p_operation = 'createAssignment' then
      select x.school_id into v_school from public.assignments x where x.id = v_id;
      v_problem := private.content_links_attach(body->'links', v_school, p_assignment => v_id);
      if v_problem <> 'ok' then raise exception using errcode = 'SF051', message = v_problem; end if;
      v_response := private.api041_assignment_json(v_id);
    else
      -- A lesson: its files and links belong to its first version.
      select rv.id, r.school_id into v_version, v_school from public.resources r
      join public.resource_versions rv on rv.resource_id = r.id and rv.version = r.current_version
      where r.id = v_id;
      v_class := nullif(body->>'classroomId', '')::uuid;
      if jsonb_typeof(body->'attachmentFileIds') = 'array' and jsonb_array_length(body->'attachmentFileIds') > 0 then
        if v_class is null then raise exception using errcode = 'SF051', message = 'invalid'; end if;
        v_problem := private.coursework_attach_files(body->'attachmentFileIds', 'lesson_resource',
          v_school, v_class, p_resource_version => v_version);
        if v_problem <> 'ok' then raise exception using errcode = 'SF051', message = v_problem; end if;
      end if;
      v_problem := private.content_links_attach(body->'links', v_school, p_resource_version => v_version);
      if v_problem <> 'ok' then raise exception using errcode = 'SF051', message = v_problem; end if;
      v_response := private.api041_resource_json(v_id);
    end if;
  exception when sqlstate 'SF051' then
    return jsonb_build_object('outcome', sqlerrm);
  end;

  update public.idempotency_records r set response_body = v_response
  where r.id = p_idempotency_id and r.actor_id = auth.uid()
    and r.generation = p_idempotency_generation and r.status = 'completed';
  return jsonb_set(result, array['response'], v_response);
exception when invalid_text_representation or invalid_datetime_format or invalid_parameter_value then
  return jsonb_build_object('outcome', 'invalid');
end;
$function$;

-- The academic query surface: online assessments, then everything else
-- through api041_query_core, with the gradebook's attachments and each lesson
-- section's content state added.
CREATE OR REPLACE FUNCTION private.api041_query(p_operation text, p_resource_id uuid, p_input jsonb)
 RETURNS jsonb
 LANGUAGE plpgsql
 STABLE SECURITY DEFINER
 SET search_path TO ''
AS $function$
declare
  result jsonb;
begin
  case p_operation
    when 'getAssessmentResults' then return private.api041_assessment_results(p_resource_id, p_input);
    when 'getAssessmentAttempt' then
      if not exists (select 1 from public.assessment_attempts t
          join public.assessments a on a.id = t.assessment_id
          where t.id = p_resource_id and private.coursework_staff(a.classroom_id)) then
        return jsonb_build_object('outcome', 'not_found');
      end if;
      return private.assessment_attempt_json(p_resource_id, 'staff');
    when 'listAssessmentQuestions' then return private.api041_assessment_questions(p_resource_id, 'student');
    when 'listAssessmentAuthoringQuestions' then return private.api041_assessment_questions(p_resource_id, 'author');
    when 'listAssessmentAttempts' then return private.api041_assessment_attempts(p_resource_id, p_input);
    else null;
  end case;

  result := private.api041_query_core(p_operation, p_resource_id, p_input);

  -- The gradebook carries each student's attachments and the class's.
  if p_operation = 'listGradebook' and jsonb_typeof(result->'items') = 'array' then
    result := jsonb_set(result, '{item}', (result->'item') || jsonb_build_object(
      'sharedAttachments', private.coursework_files_json(p_assessment => p_resource_id, p_role => 'results'),
      'sharedLinks', private.content_links_json(p_assessment => p_resource_id, p_role => 'results')));
    result := jsonb_set(result, '{items}', (
      select coalesce(jsonb_agg(case when item->'grade' is null or jsonb_typeof(item->'grade') = 'null' then item
        else jsonb_set(item, '{grade}', (item->'grade')
          || private.grade_attachments_json(p_resource_id, (item->'grade'->>'id')::uuid) - 'gradeResultId') end
        order by ordinality), '[]'::jsonb)
      from jsonb_array_elements(result->'items') with ordinality as t(item, ordinality)));
  end if;

  -- Each section says whether its lesson is filed and published, so a
  -- section is not reported as needing content once the class can see one.
  if p_operation = 'listLessonSessions' and jsonb_typeof(result->'items') = 'array' then
    result := jsonb_set(result, '{items}', (
      select coalesce(jsonb_agg(item || jsonb_build_object('contentState',
          private.lesson_session_content_state((item->>'id')::uuid,
            private.coursework_staff((item->>'classroomId')::uuid)))
        order by ordinality), '[]'::jsonb)
      from jsonb_array_elements(result->'items') with ordinality as t(item, ordinality)));
  end if;
  return result;
end;
$function$;

-- A paper scan for a class is a teacher's, as a lesson file is; every other
-- upload target is decided by purpose.
CREATE OR REPLACE FUNCTION private.file050_authorize_target(p_body jsonb)
 RETURNS jsonb
 LANGUAGE plpgsql
 STABLE SECURITY DEFINER
 SET search_path TO ''
AS $function$
begin
  if p_body->>'purpose' = 'paper_scan' and nullif(p_body->>'classroomId', '') is not null then
    return private.file050_authorize_target_by_purpose(
      jsonb_set(p_body, array['purpose'], '"lesson_resource"'::jsonb));
  end if;
  return private.file050_authorize_target_by_purpose(p_body);
end;
$function$;

-- Files on questions, grades and shared results are decided here; every
-- other file by file051_authorize_material_download.
CREATE OR REPLACE FUNCTION private.file051_authorize_download(p_file_id uuid)
 RETURNS jsonb
 LANGUAGE plpgsql
 STABLE SECURITY DEFINER
 SET search_path TO ''
AS $function$
declare
  v_school uuid;
  v_new boolean;
  v_allowed boolean := false;
begin
  select fo.school_id into v_school from public.file_objects fo where fo.id = p_file_id;
  select exists (select 1 from public.file_bindings b where b.file_object_id = p_file_id
      and (b.assessment_question_id is not null or b.grade_result_id is not null or b.role = 'results'))
    into v_new;
  if not v_new then
    return private.file051_authorize_material_download(p_file_id);
  end if;
  if auth.uid() is null then
    return jsonb_build_object('allowed', false, 'schoolId', v_school, 'reason', 'denied');
  end if;
  select exists (
    -- A question's file.
    select 1 from public.file_bindings b
    join public.assessment_questions q on q.id = b.assessment_question_id
    join public.assessments a on a.id = q.assessment_id and a.deleted_at is null
    where b.file_object_id = p_file_id and b.detached_at is null
      and (private.coursework_staff(a.classroom_id)
        or (a.state = 'published' and (a.opens_at is null or a.opens_at <= now())
          and private.can_view_classroom(a.classroom_id)))
  ) or exists (
    -- One student's paper-grade file.
    select 1 from public.file_bindings b
    join public.grade_results g on g.id = b.grade_result_id
    join public.assessments a on a.id = g.assessment_id and a.deleted_at is null
    where b.file_object_id = p_file_id and b.detached_at is null
      and (private.coursework_staff(a.classroom_id)
        or (g.state = 'published' and private.coursework_reader_of(g.student_id, a.classroom_id)))
  ) or exists (
    -- The class's shared results: to anyone whose own published grade it is.
    select 1 from public.file_bindings b
    join public.assessments a on a.id = b.assessment_id and a.deleted_at is null
    where b.file_object_id = p_file_id and b.detached_at is null and b.role = 'results'
      and (private.coursework_staff(a.classroom_id)
        or exists (select 1 from public.grade_results g
          where g.assessment_id = a.id and g.state = 'published'
            and private.coursework_reader_of(g.student_id, a.classroom_id)))
  ) or exists (
    -- Detached: the class's staff only.
    select 1 from public.file_bindings b
    left join public.assessment_questions q on q.id = b.assessment_question_id
    left join public.grade_results g on g.id = b.grade_result_id
    join public.assessments a on a.id = coalesce(q.assessment_id, g.assessment_id, b.assessment_id)
    where b.file_object_id = p_file_id and b.detached_at is not null
      and private.coursework_staff(a.classroom_id)
  ) into v_allowed;
  return jsonb_build_object('allowed', coalesce(v_allowed, false), 'schoolId', v_school,
    'reason', case when v_allowed then 'coursework' else 'denied' end);
end;
$function$;

-- ---------------------------------------------------------------------------
-- 2. The exclusive layer: flattened into the dispatcher.
-- ---------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION private.authz_authorize(p_action text, p_resource_id uuid)
 RETURNS jsonb
 LANGUAGE plpgsql
 STABLE SECURITY DEFINER
 SET search_path TO ''
AS $function$
declare
  decision jsonb;
begin
  -- How far a lesson's material is read for the study helper (ADR-0037),
  -- formerly a layer of its own around this dispatcher.
  if p_action in ('lesson_reading.read', 'lesson_reading.retry') then
    return private.authz_lesson_reading(p_action, p_resource_id);
  end if;
  if p_action in ('notebook.read', 'notebook.write', 'notebook_entry.delete', 'study_set.generate') then
    return private.authz_notebook(p_action, p_resource_id);
  end if;
  if p_action = 'conversation.mark_read' then
    return private.authz_conversation_read(p_action, p_resource_id);
  end if;
  if p_action = 'assessment.results' then
    return private.authz_assessment_results(p_action, p_resource_id);
  end if;
  if p_action in ('gradebook.read', 'gradebook.write', 'gradebook.publish',
      'gradebook.correct', 'assessment.update', 'grade_result.history',
      'attendance_session.correct', 'attendance_session.history',
      'assignment.extend', 'assignment.reopen', 'assignment.materials',
      'assessment.materials', 'resource.edit', 'assessment.design',
      'assessment.access', 'assessment_attempt.read', 'assessment_attempt.mark',
      'gradebook.attachments') then
    return private.authz_coursework(p_action, p_resource_id);
  end if;

  if p_action = 'submission.history' then
    decision := private.authz_submission_history(p_action, p_resource_id);
  else
    decision := case
      when p_action = 'lesson_session.close'
        then private.authz_lesson_session_close(p_action, p_resource_id)
      when p_action in ('classJoinLink.create', 'classJoinLink.read', 'classJoinLink.revoke')
        then private.authz_class_join_links(p_action, p_resource_id)
      when p_action = 'classroom.create'
        then private.authz_classroom_create(p_action, p_resource_id)
      when p_action in ('file.download', 'file.publish')
        then private.authz_file_publication(p_action, p_resource_id)
      when p_action in ('upload.intent.create', 'upload.read', 'upload.complete',
        'file.read')
        then private.authz_file_delivery(p_action, p_resource_id)
      when p_action in ('content_controls.read', 'content_controls.write',
        'moderation.overview.read', 'moderation.queue.read', 'moderation.report.read',
        'moderation.triage', 'moderation.resolve', 'moderation.escalate',
        'moderation.evidence.write', 'moderation.hold', 'moderation.access.approve',
        'moderation.access.start', 'moderation.access.revoke', 'moderation.access.list')
        then private.authz_safety(p_action, p_resource_id)
      when p_action in ('term.create', 'student.create')
        then private.authz_roster_create(p_action, p_resource_id)
      when p_action in ('support_access.approve', 'support_access.start',
        'support_access.revoke', 'support_access.list')
        then private.authz_support_access(p_action, p_resource_id)
      when p_action in ('meeting.request', 'meeting.cancel', 'meeting.status')
        then private.authz_meetings(p_action, p_resource_id)
      when p_action in ('message.list', 'message.send', 'announcement.create',
        'announcement.list')
        then private.authz_communications(p_action, p_resource_id)
      when p_action in ('guardian_link.verify', 'guardian_link.revoke')
        then private.authz_guardian_links(p_action, p_resource_id)
      when p_action in ('invitation.issue', 'invitation.revoke', 'invitation.list')
        then private.authz_invitations(p_action, p_resource_id)
      when p_action in ('school.suspend', 'school.close', 'membership.grant',
        'membership.activate', 'membership.suspend', 'membership.revoke',
        'classroom_staff.write', 'enrollment.write')
        then private.authz_school_admin(p_action, p_resource_id)
      when p_action in ('term.list', 'classroom.list', 'classroom.update',
        'classroom.schedule.write', 'classroom.roster.read', 'classroom.staff.read',
        'lesson_session.list', 'resource.list', 'resource.create', 'resource.revise',
        'resource.publish', 'resource.withdraw', 'assignment.list', 'assignment.create',
        'assignment.publish', 'assignment.withdraw', 'assignment.submit',
        'assignment.read', 'submission.list', 'assessment.list', 'assessment.create',
        'assessment.publish', 'assessment.withdraw', 'assessment.submit',
        'assessment_question.list', 'assessment_question.authoring.list',
        'assessment_attempt.list', 'grade_result.list', 'grade_result.review',
        'grade_result.publish', 'grade_result.correct', 'grade_result.withdraw',
        'attendance_record.list', 'attendance_record.write', 'attendance_roster.read',
        'wellbeing_event.list', 'wellbeing_event.create')
        then private.authz_school_operations(p_action, p_resource_id)
      else private.authz_academic(p_action, p_resource_id)
    end;
    decision := private.authz_guardian_submits(p_action, p_resource_id, decision);
  end if;

  return private.authz_guardian_list_reads(p_action, p_resource_id, decision);
end;
$function$;

drop function private.authz_authorize_pre_material(text, uuid);

-- ---------------------------------------------------------------------------
-- 3. Ownership and grants: unchanged. Only the dispatchers are granted.
-- ---------------------------------------------------------------------------

do $grants$
declare
  f text;
begin
  foreach f in array array[
    'private.api041_command_core(text,uuid,jsonb,uuid,bigint)',
    'private.api041_query_core(text,uuid,jsonb)',
    'private.file050_authorize_target_by_purpose(jsonb)',
    'private.file051_authorize_material_download(uuid)',
    'private.api041_command(text,uuid,jsonb,uuid,bigint)',
    'private.api041_query(text,uuid,jsonb)',
    'private.file050_authorize_target(jsonb)',
    'private.file051_authorize_download(uuid)',
    'private.authz_authorize(text,uuid)'
  ] loop
    execute format('alter function %s owner to postgres', f);
    execute format('revoke all on function %s from public, anon, authenticated, service_role, studafy_api_runtime, studafy_worker_runtime', f);
  end loop;
end;
$grants$;

grant execute on function private.api041_command(text, uuid, jsonb, uuid, bigint)
  to studafy_api_runtime;
grant execute on function private.api041_query(text, uuid, jsonb) to studafy_api_runtime;
grant execute on function private.authz_authorize(text, uuid) to studafy_api_runtime;
