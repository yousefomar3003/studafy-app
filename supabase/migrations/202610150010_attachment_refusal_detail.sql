-- Attachment and link refusals say which one and why (launch plan 2.8).
--
-- On the test copy (2026-10-15) a teacher's lesson save was refused four
-- times with a bare 400 INVALID_REQUEST: the scanner had refused the PDFs
-- they attached, and nothing in the answer or the access log said so, so
-- the app showed "try again" and every retry failed the same way.
--
-- private.coursework_attach_files and private.content_links_attach answered
-- every refusal with the bare outcome 'invalid'. They now raise SQLSTATE
-- SF052 ('attachment_refused') whose DETAIL is a JSON array of
-- {path, reason}: the request path of the refused file or link
-- ("attachmentFileIds.2", "links.0", "questions.1.attachmentFileIds.0")
-- and a fixed reason code:
--
--   file_refused           the caller's own file, refused by the scan
--   file_not_found         no such file, deleted, or not one the caller may
--                          name (another account's refused file says this,
--                          never why it was refused)
--   file_wrong_purpose     uploaded for something else
--   file_already_attached  already on something else
--   duplicate              the same file twice in one request
--   too_many               more files or links than the target takes
--                          (path is the field itself)
--   link_invalid           a link that is not a {title, url} object
--   link_title_invalid     a title that is empty or over 120 characters
--   link_not_allowed       not https, no dotted host, credentials or spaces
--
-- private.api041_command, which every caller is reached through, turns it
-- into {"outcome": "attachment_refused", "rows": [...]}; the API answers
-- 422 ATTACHMENT_REFUSED with those rows as problem `errors`, so the access
-- log carries them as invalid_fields. The exception unwinds the whole
-- command, as the callers' own refusals already did: nothing is saved.
--
-- What is refused, and when, is unchanged. Authorization is unchanged:
-- another account's file, another school's, or one uploaded for another
-- class is still 'forbidden'. The only difference in order is that files
-- are checked in the order they were sent rather than by id.
--
-- ADR-0030: the helpers and the handlers that call them are replaced in
-- place (same signatures, so owners and grants are kept); nothing is
-- renamed or wrapped. Two small helpers are added and revoked from every
-- client and runtime role.

-- ---------------------------------------------------------------------------
-- 1. Raising a refusal
-- ---------------------------------------------------------------------------

-- Volatile on purpose: it exists to raise, and must never be folded into a
-- constant when a statement is planned.
create or replace function private.attachment_refuse(p_rows jsonb)
returns void language plpgsql volatile set search_path = '' as $$
begin
  raise exception using errcode = 'SF052', message = 'attachment_refused',
    detail = p_rows::text;
end;
$$;

-- What is wrong with each link of a list, as {path, reason} rows; empty
-- when every link may be added. The count is the caller's to check.
create or replace function private.content_links_refusals(p_links jsonb, p_path text default 'links')
returns jsonb language sql immutable set search_path = '' as $$
  select coalesce(jsonb_agg(jsonb_build_object('path', p_path || '.' || (t.ord - 1),
      'reason', t.reason) order by t.ord), '[]'::jsonb)
  from (
    select l.ord, case
        when jsonb_typeof(l.item) <> 'object' then 'link_invalid'
        when char_length(btrim(coalesce(l.item->>'title', ''))) not between 1 and 120
          then 'link_title_invalid'
        when not private.content_link_url_ok(btrim(l.item->>'url')) then 'link_not_allowed'
      end as reason
    from jsonb_array_elements(case when jsonb_typeof(p_links) = 'array' then p_links
      else '[]'::jsonb end) with ordinality as l(item, ord)
  ) t
  where t.reason is not null;
$$;

-- ---------------------------------------------------------------------------
-- 2. The two helpers
-- ---------------------------------------------------------------------------

-- Adds links to one target. 'ok', or raises a refusal naming the link.
create or replace function private.content_links_attach(
  p_links jsonb, p_school uuid,
  p_assignment uuid default null, p_assessment uuid default null,
  p_question uuid default null, p_grade_result uuid default null,
  p_resource_version uuid default null, p_role text default 'material',
  p_max int default 10)
returns text language plpgsql security definer set search_path = '' as $$
declare
  v_item jsonb;
  v_pos int;
  v_live int;
  v_refusals jsonb;
begin
  if p_links is null or jsonb_typeof(p_links) <> 'array' or jsonb_array_length(p_links) = 0 then
    return 'ok';
  end if;
  v_refusals := private.content_links_refusals(p_links);
  if jsonb_array_length(v_refusals) > 0 then
    perform private.attachment_refuse(v_refusals);
  end if;
  select coalesce(max(l.position), 0) into v_pos from public.content_links l
  where l.detached_at is null
    and (l.assignment_id = p_assignment or l.assessment_id = p_assessment
      or l.assessment_question_id = p_question or l.grade_result_id = p_grade_result
      or l.resource_version_id = p_resource_version);
  for v_item in select value from jsonb_array_elements(p_links) loop
    v_pos := v_pos + 1;
    insert into public.content_links(school_id, title, url, role, position,
      assignment_id, assessment_id, assessment_question_id, grade_result_id,
      resource_version_id, created_by)
    values (p_school, btrim(v_item->>'title'), btrim(v_item->>'url'), p_role, v_pos,
      p_assignment, p_assessment, p_question, p_grade_result, p_resource_version,
      auth.uid());
  end loop;
  select count(*) into v_live from public.content_links l
  where l.detached_at is null and l.role = p_role
    and (l.assignment_id = p_assignment or l.assessment_id = p_assessment
      or l.assessment_question_id = p_question or l.grade_result_id = p_grade_result
      or l.resource_version_id = p_resource_version);
  if v_live > p_max then
    perform private.attachment_refuse(jsonb_build_array(
      jsonb_build_object('path', 'links', 'reason', 'too_many')));
  end if;
  return 'ok';
end;
$$;

-- Binds the caller's own unattached uploads of one purpose, started for
-- p_class, to one target. 'ok' or 'forbidden', or raises a refusal naming
-- the file.
create or replace function private.coursework_attach_files(
  p_file_ids jsonb, p_purpose public.file_purpose, p_school uuid, p_class uuid,
  p_assignment uuid default null, p_assessment uuid default null,
  p_question uuid default null, p_grade_result uuid default null,
  p_resource_version uuid default null, p_role text default 'material',
  p_max int default 10)
returns text language plpgsql security definer set search_path = '' as $$
declare
  v_ids uuid[];
  v_count int;
  v_index int;
  v_id uuid;
  v_file public.file_objects%rowtype;
  v_live int;
  v_reason text;
begin
  if auth.uid() is null then return 'forbidden'; end if;
  if num_nonnulls(p_assignment, p_assessment, p_question, p_grade_result,
      p_resource_version) <> 1 then
    raise exception 'COURSEWORK_ATTACH_TARGET_AMBIGUOUS';
  end if;
  if p_file_ids is null or jsonb_typeof(p_file_ids) <> 'array' then return 'ok'; end if;
  -- In the order sent, so a refusal's index is the request's.
  select coalesce(array_agg(x::uuid order by ord), array[]::uuid[]) into v_ids
  from jsonb_array_elements_text(p_file_ids) with ordinality as t(x, ord);
  v_count := cardinality(v_ids);
  if v_count = 0 then return 'ok'; end if;
  -- The list as a whole first, before any file is looked at.
  if v_count > p_max then
    perform private.attachment_refuse(jsonb_build_array(
      jsonb_build_object('path', 'attachmentFileIds', 'reason', 'too_many')));
  end if;
  select min(t.ord) - 1 into v_index
  from unnest(v_ids) with ordinality as t(id, ord)
  where exists (select 1 from unnest(v_ids) with ordinality as e(id, ord)
    where e.id = t.id and e.ord < t.ord);
  if v_index is not null then
    perform private.attachment_refuse(jsonb_build_array(jsonb_build_object(
      'path', 'attachmentFileIds.' || v_index, 'reason', 'duplicate')));
  end if;

  for v_index in 1 .. v_count loop
    v_id := v_ids[v_index];
    v_reason := null;
    select * into v_file from public.file_objects fo where fo.id = v_id for update;
    if v_file.id is null or v_file.deleted_at is not null
       or v_file.scan_state in ('deleted', 'rejected') then
      -- Why it was refused is told only to the person who uploaded it.
      v_reason := case when v_file.id is not null and v_file.deleted_at is null
          and v_file.scan_state = 'rejected'
          and v_file.owner_id is not distinct from auth.uid()
          and v_file.school_id = p_school
        then 'file_refused' else 'file_not_found' end;
    elsif v_file.owner_id is distinct from auth.uid() or v_file.school_id <> p_school then
      return 'forbidden';
    elsif v_file.purpose <> p_purpose then
      v_reason := 'file_wrong_purpose';
    elsif private.file_is_attached(v_id) then
      v_reason := 'file_already_attached';
    end if;
    if v_reason is not null then
      perform private.attachment_refuse(jsonb_build_array(jsonb_build_object(
        'path', 'attachmentFileIds.' || (v_index - 1), 'reason', v_reason)));
    end if;
    -- The upload was authorised for one class; it is only ever that
    -- class's.
    if not exists (select 1 from public.file_bindings b
        join public.upload_sessions u on u.id = b.upload_session_id
        where b.file_object_id = v_id
          and (u.classroom_id = p_class
            or (select a.classroom_id from public.assignments a
                where a.id = u.assignment_id) = p_class
            or (select a.classroom_id from public.grade_results g
                join public.assessments a on a.id = g.assessment_id
                where g.id = u.grade_result_id) = p_class)) then
      return 'forbidden';
    end if;
    insert into public.file_bindings(school_id, file_object_id, assignment_id,
      assessment_id, assessment_question_id, grade_result_id, resource_version_id, role)
    values (p_school, v_id, p_assignment, p_assessment, p_question, p_grade_result,
      p_resource_version, p_role);
  end loop;

  select count(*) into v_live from public.file_bindings b
  where b.detached_at is null and b.role = p_role
    and (b.assignment_id = p_assignment or b.assessment_id = p_assessment
      or b.assessment_question_id = p_question or b.grade_result_id = p_grade_result
      or b.resource_version_id = p_resource_version);
  if v_live > p_max then
    perform private.attachment_refuse(jsonb_build_array(
      jsonb_build_object('path', 'attachmentFileIds', 'reason', 'too_many')));
  end if;
  return 'ok';
end;
$$;

-- ---------------------------------------------------------------------------
-- 3. Questions: a refusal names the question it came from
-- ---------------------------------------------------------------------------

-- The body of 202610060001 with the attaching of each question's files and
-- links put in a block that prefixes a refusal's path with
-- "questions.<index>.".
create or replace function private.assessment_write_questions(
  a public.assessments, p_questions jsonb)
returns text language plpgsql security definer set search_path = '' as $$
declare
  v_item jsonb;
  v_pos int := 0;
  v_qid uuid;
  v_keep uuid[] := array[]::uuid[];
  v_result text;
  v_problem text;
  v_detail text;
begin
  if p_questions is null or jsonb_typeof(p_questions) <> 'array'
     or jsonb_array_length(p_questions) > 100 then
    return 'invalid';
  end if;
  for v_item in select value from jsonb_array_elements(p_questions) loop
    v_problem := private.assessment_question_problem(v_item);
    if v_problem is not null then return 'invalid'; end if;
  end loop;

  -- Questions dropped from the list go, with their files and links.
  select coalesce(array_agg((x->>'id')::uuid), array[]::uuid[]) into v_keep
  from jsonb_array_elements(p_questions) x where nullif(x->>'id', '') is not null;
  if exists (select 1 from unnest(v_keep) k where not exists (
      select 1 from public.assessment_questions q where q.id = k and q.assessment_id = a.id)) then
    return 'invalid';
  end if;
  delete from public.assessment_questions q
  where q.assessment_id = a.id and not (q.id = any(v_keep));
  -- Positions are rewritten in two steps so a reorder never collides.
  update public.assessment_questions set position = position + 100000
  where assessment_id = a.id;

  for v_item in select value from jsonb_array_elements(p_questions) loop
    v_pos := v_pos + 1;
    v_qid := nullif(v_item->>'id', '')::uuid;
    if v_qid is null then
      insert into public.assessment_questions(school_id, assessment_id, position, prompt,
        preferred_answer, maximum_score, kind, options, answer_key, marking_guidance, required)
      values (a.school_id, a.id, v_pos, btrim(v_item->>'prompt'),
        nullif(v_item->>'preferredAnswer', ''), (v_item->>'maximumScore')::numeric,
        coalesce(v_item->>'kind', 'essay'), coalesce(v_item->'options', '[]'::jsonb),
        private.assessment_draft_key(v_item),
        nullif(v_item->>'markingGuidance', ''), coalesce((v_item->>'required')::boolean, true))
      returning id into v_qid;
    else
      update public.assessment_questions set position = v_pos, prompt = btrim(v_item->>'prompt'),
        preferred_answer = nullif(v_item->>'preferredAnswer', ''),
        maximum_score = (v_item->>'maximumScore')::numeric,
        kind = coalesce(v_item->>'kind', 'essay'),
        options = coalesce(v_item->'options', '[]'::jsonb),
        answer_key = private.assessment_draft_key(v_item),
        marking_guidance = nullif(v_item->>'markingGuidance', ''),
        required = coalesce((v_item->>'required')::boolean, true), updated_at = now()
      where id = v_qid;
    end if;
    perform private.coursework_detach_files(v_item->'detachFileIds', p_question => v_qid);
    perform private.content_links_detach(v_item->'removeLinkIds', p_question => v_qid);
    begin
      v_result := private.coursework_attach_files(v_item->'attachmentFileIds',
        'assignment_material', a.school_id, a.classroom_id, p_question => v_qid, p_max => 5);
      if v_result <> 'ok' then return v_result; end if;
      v_result := private.content_links_attach(v_item->'links', a.school_id,
        p_question => v_qid, p_max => 5);
      if v_result <> 'ok' then return v_result; end if;
    exception when sqlstate 'SF052' then
      get stacked diagnostics v_detail = pg_exception_detail;
      perform private.attachment_refuse((
        select jsonb_agg(r || jsonb_build_object('path',
          'questions.' || (v_pos - 1) || '.' || (r->>'path')) order by ord)
        from jsonb_array_elements(v_detail::jsonb) with ordinality as t(r, ord)));
    end;
  end loop;

  update public.assessments set maximum_score = coalesce((select sum(q.maximum_score)
    from public.assessment_questions q where q.assessment_id = a.id), maximum_score)
  where id = a.id and exists (select 1 from public.assessment_questions q where q.assessment_id = a.id);
  return null;
end;
$$;

-- ---------------------------------------------------------------------------
-- 4. The dispatcher answers a refusal with its rows
-- ---------------------------------------------------------------------------

-- The live body of 202610070005 with two changes: links refused before
-- anything is created name the link, and a refusal raised anywhere below
-- (SF052) is answered as {"outcome": "attachment_refused", "rows": [...]}.
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
  v_refusals jsonb;
  v_detail text;
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
  v_refusals := private.content_links_refusals(body->'links');
  if jsonb_array_length(v_refusals) > 0 then
    return jsonb_build_object('outcome', 'attachment_refused', 'rows', v_refusals);
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
exception
  when sqlstate 'SF052' then
    -- Raised by private.attachment_refuse: nothing below was kept.
    get stacked diagnostics v_detail = pg_exception_detail;
    return jsonb_build_object('outcome', 'attachment_refused', 'rows', v_detail::jsonb);
  when invalid_text_representation or invalid_datetime_format or invalid_parameter_value then
    return jsonb_build_object('outcome', 'invalid');
end;
$function$;

-- ---------------------------------------------------------------------------
-- 5. Ownership and grants
-- ---------------------------------------------------------------------------

-- The replaced functions keep their owner and grants. The two new helpers
-- are reached only through the dispatcher, like every other handler.
do $grants$
declare
  f text;
begin
  foreach f in array array[
    'private.attachment_refuse(jsonb)',
    'private.content_links_refusals(jsonb,text)'
  ] loop
    execute format('alter function %s owner to postgres', f);
    execute format('revoke all on function %s from public, anon, authenticated, service_role, studafy_api_runtime, studafy_worker_runtime', f);
  end loop;
end;
$grants$;
