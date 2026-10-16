-- Hand-ins, messages, announcements and work material refuse a file the
-- scan refused, and say which one; a file refused after it was attached
-- says so instead of "still being checked" (follows 202610150010).
--
-- private.file_attach_bind, the binder behind those four surfaces, refused
-- only a deleted file. A file the scan had refused ('rejected', or 'error'
-- when the scan gave up or an operator contained it) was bound like any
-- other: readers saw it "still being checked" for ever, and once the
-- cleanup job deleted it, it dropped out of every read without a word - a
-- teacher saw a hand-in with no file and no reason. Nothing leaked:
-- delivery only ever serves clean files.
--
-- 1. private.file_attach_bind now refuses, as 202610150010 does for
--    coursework, by raising SF052 with {path, reason} rows that
--    private.api041_command / private.api042_command answer as
--    {"outcome": "attachment_refused", "rows": [...]} (API: 422
--    ATTACHMENT_REFUSED). Paths are the request's ("attachmentFileIds.2"),
--    and files are checked in the order sent rather than by id. Reasons:
--
--      file_refused           the caller's own file, refused by the scan
--                             ('rejected' or 'error', or deleted after that)
--      file_not_found         missing or deleted, or a refused file that is
--                             not the caller's own
--      file_wrong_purpose     uploaded for something else
--      file_already_attached  already on something else
--      duplicate              the same file twice
--      too_many               more than five (path: the field)
--
--    A file still 'quarantined' or 'scanning' is bound as before: the scan
--    finishes after the bind.
--
--    Authorization is unchanged: every request answered 'forbidden' before
--    is answered 'forbidden' now. A scan refusal is only raised once every
--    file in the request has passed the checks that can answer
--    'forbidden', so another account's file, another school's, or one
--    uploaded for another class still answers 403, whatever else is in the
--    request. The other refusals are raised where they were before (the
--    old 'invalid').
--
-- 2. private.api041_submit_assignment binds only the files not carried
--    over from the attempt being replaced, so it puts each refusal back at
--    the file's place in the request; a duplicate is named; and a carried
--    over file that the scan has since refused, or that is gone, is
--    refused too instead of being carried onto the new attempt.
--
-- 3. private.api042_command (messages, announcements) answers SF052 like
--    private.api041_command does. Its body is otherwise unchanged. The
--    refusal rolls the message or announcement back with it: previously a
--    bind refusal answered 'invalid' while the message itself was kept.
--
-- 4. Read models (private.file_attachment_json, private.coursework_files_json,
--    private.api041_resource_json) keep listing a file the scan refused
--    after it was attached, rather than dropping it once it is deleted. The
--    least invasive marker is the one already on the wire: `scanState` is
--    'rejected', 'error' or 'deleted' (V1FileScanState already has all
--    three), and only such a file is listed when deleted - a file deleted
--    any other way (retention) still drops out. The contract shape and the
--    generated clients are unchanged; the app shows those states as
--    "removed by the safety check". Delivery is unchanged and still serves
--    only clean files.
--
-- ADR-0030: every function is replaced in place with the same signature,
-- so owners and grants are kept; nothing is renamed or wrapped, and no
-- helper is added.

-- ---------------------------------------------------------------------------
-- 1. The binder
-- ---------------------------------------------------------------------------

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
  v_count int;
  v_index int;
  v_id uuid;
  v_file public.file_objects%rowtype;
  v_target_class uuid;
  v_reason text;
  -- Scan refusals, raised only once nothing in the request is forbidden.
  v_refused jsonb := '[]'::jsonb;
begin
  if auth.uid() is null then return 'forbidden'; end if;
  if num_nonnulls(p_submission_attempt, p_message, p_announcement,
      p_assignment, p_assessment) <> 1 then
    raise exception 'FILE_ATTACH_TARGET_AMBIGUOUS';
  end if;
  if p_file_ids is null or jsonb_typeof(p_file_ids) <> 'array' then
    return 'ok';
  end if;

  -- In the order sent, so a refusal's index is the request's.
  select coalesce(array_agg(x::uuid order by ord), array[]::uuid[]) into v_ids
  from jsonb_array_elements_text(p_file_ids) with ordinality as t(x, ord);
  v_count := cardinality(v_ids);
  if v_count = 0 then return 'ok'; end if;
  select min(t.ord) - 1 into v_index
  from unnest(v_ids) with ordinality as t(id, ord)
  where exists (select 1 from unnest(v_ids) with ordinality as e(id, ord)
    where e.id = t.id and e.ord < t.ord);
  if v_index is not null then
    perform private.attachment_refuse(jsonb_build_array(jsonb_build_object(
      'path', 'attachmentFileIds.' || v_index, 'reason', 'duplicate')));
  end if;
  if v_count > 5 then
    perform private.attachment_refuse(jsonb_build_array(
      jsonb_build_object('path', 'attachmentFileIds', 'reason', 'too_many')));
  end if;

  if p_assignment is not null then
    select a.classroom_id into v_target_class
    from public.assignments a where a.id = p_assignment;
  elsif p_assessment is not null then
    select a.classroom_id into v_target_class
    from public.assessments a where a.id = p_assessment;
  end if;

  for v_index in 1 .. v_count loop
    v_id := v_ids[v_index];
    v_reason := null;
    select * into v_file from public.file_objects fo where fo.id = v_id for update;
    if v_file.id is null or v_file.deleted_at is not null
      or v_file.scan_state = 'deleted' then
      -- Deleted after the scan refused it: why is told only to its owner.
      v_reason := case when v_file.id is not null
          and v_file.scan_error_code is not null
          and v_file.owner_id = auth.uid() and v_file.school_id = p_school
        then 'file_refused' else 'file_not_found' end;
    else
      if v_file.owner_id <> auth.uid() then return 'forbidden'; end if;
      if v_file.school_id <> p_school then return 'forbidden'; end if;
      if v_file.purpose <> p_purpose then
        v_reason := 'file_wrong_purpose';
      elsif private.file_is_attached(v_id) then
        v_reason := 'file_already_attached';
      end if;
    end if;
    if v_reason is not null then
      -- With any scan refusal met so far, so the answer names those too.
      perform private.attachment_refuse(v_refused || jsonb_build_array(
        jsonb_build_object('path', 'attachmentFileIds.' || (v_index - 1),
          'reason', v_reason)));
    end if;
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

    -- Refused by the scan: never bound. Still being scanned: bound, and
    -- the scan finishes after.
    if v_file.scan_state in ('rejected', 'error') then
      v_refused := v_refused || jsonb_build_array(jsonb_build_object(
        'path', 'attachmentFileIds.' || (v_index - 1),
        'reason', case when v_file.owner_id = auth.uid()
          then 'file_refused' else 'file_not_found' end));
      continue;
    end if;

    insert into public.file_bindings(
      school_id, file_object_id, submission_attempt_id, message_id,
      announcement_id, assignment_id, assessment_id)
    values (
      p_school, v_id, p_submission_attempt, p_message, p_announcement,
      p_assignment, p_assessment);
  end loop;

  if jsonb_array_length(v_refused) > 0 then
    perform private.attachment_refuse(v_refused);
  end if;
  return 'ok';
end;
$$;

-- ---------------------------------------------------------------------------
-- 2. Handing work in
-- ---------------------------------------------------------------------------

-- The body of the live handler (202609300003 and later) with three
-- changes, each marked: a duplicate is named, a carried-over file that the
-- scan has since refused (or that is gone) is refused, and a refusal from
-- the binder is put back at each file's place in the request.
create or replace function private.api041_submit_assignment(p_assignment uuid, p_input jsonb, p_idempotency_id uuid, p_idempotency_generation bigint)
returns jsonb language plpgsql security definer set search_path to '' as $function$
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
  v_index int;
  v_new jsonb;
  v_new_at int[];
  v_refused jsonb := '[]'::jsonb;
  v_detail text;
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
  -- Changed: the same file twice in one hand-in names the second.
  if cardinality(coalesce(v_files, array[]::uuid[]))
     <> jsonb_array_length(coalesce(body->'attachmentFileIds', '[]'::jsonb)) then
    select min(t.ord) - 1 into v_index
    from jsonb_array_elements_text(body->'attachmentFileIds') with ordinality as t(id, ord)
    where exists (select 1
      from jsonb_array_elements_text(body->'attachmentFileIds') with ordinality as e(id, ord)
      where e.id::uuid = t.id::uuid and e.ord < t.ord);
    perform private.attachment_refuse(jsonb_build_array(jsonb_build_object(
      'path', 'attachmentFileIds.' || v_index, 'reason', 'duplicate')));
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

  -- Changed: a carried-over file the scan has since refused, or that is
  -- gone, is not carried onto the new attempt. Raised after the binder, so
  -- a forbidden file anywhere in the request still answers 'forbidden'.
  select coalesce(jsonb_agg(jsonb_build_object(
      'path', 'attachmentFileIds.' || (t.ord - 1),
      'reason', case when fo.owner_id = auth.uid()
          and (fo.scan_state in ('rejected', 'error')
            or (fo.scan_state = 'deleted' and fo.scan_error_code is not null))
        then 'file_refused' else 'file_not_found' end) order by t.ord), '[]'::jsonb)
    into v_refused
  from jsonb_array_elements_text(coalesce(body->'attachmentFileIds', '[]'::jsonb))
    with ordinality as t(id, ord)
  join public.file_objects fo on fo.id = t.id::uuid
  where fo.id = any(v_kept)
    and (fo.deleted_at is not null or fo.scan_state in ('rejected', 'error', 'deleted'));

  -- The new files, in the order sent, and where each one was sent.
  select jsonb_agg(to_jsonb(t.id) order by t.ord), array_agg((t.ord - 1)::int order by t.ord)
    into v_new, v_new_at
  from jsonb_array_elements_text(coalesce(body->'attachmentFileIds', '[]'::jsonb))
    with ordinality as t(id, ord)
  where not (t.id::uuid = any(v_kept));

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

    if v_new is not null then
      -- Changed: the binder names files by their place in v_new; each is
      -- put back at its place in the request.
      begin
        v_bind := private.file_attach_bind(v_new,
          'assignment_submission'::public.file_purpose, a.school_id,
          p_submission_attempt => v_attempt);
      exception when sqlstate 'SF052' then
        get stacked diagnostics v_detail = pg_exception_detail;
        v_refused := v_refused || (
          select coalesce(jsonb_agg(case
              when r->>'path' ~ '^attachmentFileIds\.[0-9]+$' then
                r || jsonb_build_object('path', 'attachmentFileIds.'
                  || v_new_at[split_part(r->>'path', '.', 2)::int + 1])
              else r end), '[]'::jsonb)
          from jsonb_array_elements(v_detail::jsonb) as r);
        v_bind := 'ok';
      end;
      if v_bind <> 'ok' then
        raise exception using errcode = 'SF043', message = v_bind;
      end if;
    end if;
  exception when sqlstate 'SF043' then
    return jsonb_build_object('outcome', sqlerrm);
  end;

  if jsonb_array_length(v_refused) > 0 then
    perform private.attachment_refuse((
      select jsonb_agg(r order by coalesce(nullif(split_part(r->>'path', '.', 2), ''), '-1')::int)
      from jsonb_array_elements(v_refused) as r));
  end if;

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
$function$;

-- ---------------------------------------------------------------------------
-- 3. Messages and announcements answer a refusal with its rows
-- ---------------------------------------------------------------------------

-- The live body (202609280003 and later) with one change: a refusal raised
-- anywhere below (SF052) is answered as {"outcome": "attachment_refused",
-- "rows": [...]}, and nothing below is kept.
create or replace function private.api042_command(p_operation text, p_resource_id uuid, p_input jsonb, p_idempotency_id uuid, p_idempotency_generation bigint)
returns jsonb language plpgsql security definer set search_path to '' as $function$
declare
  v_actor uuid := auth.uid();
  v_at timestamptz := now();
  v_count int;
  response jsonb;
  v_detail text;
begin
  if p_operation not in ('markConversationRead', 'acknowledgeMessageDelivery') then
    return private.api042_command_pre_receipts(
      p_operation, p_resource_id, p_input, p_idempotency_id,
      p_idempotency_generation);
  end if;
  if v_actor is null then return jsonb_build_object('outcome', 'forbidden'); end if;

  if p_operation = 'markConversationRead' then
    -- Never moves backwards: a stale request arriving late must not un-read
    -- what a newer one already read.
    update public.conversation_participants cp
    set last_read_at = greatest(coalesce(cp.last_read_at, v_at), v_at),
        last_delivered_at = greatest(coalesce(cp.last_delivered_at, v_at), v_at)
    where cp.conversation_id = p_resource_id and cp.user_id = v_actor
      and cp.left_at is null;
    if not found then return jsonb_build_object('outcome', 'not_found'); end if;
    response := jsonb_build_object('conversationId', p_resource_id, 'readAt', v_at);
  else
    -- Every conversation the actor is in: their app has just fetched them.
    update public.conversation_participants cp
    set last_delivered_at = v_at
    where cp.user_id = v_actor and cp.left_at is null
      and (cp.last_delivered_at is null or cp.last_delivered_at < v_at);
    get diagnostics v_count = row_count;
    response := jsonb_build_object('acknowledgedAt', v_at, 'conversations', v_count);
  end if;

  if not private.api_idempotency_complete(
    p_idempotency_id, p_idempotency_generation, 200, response) then
    raise exception 'API042_IDEMPOTENCY_COMPLETION_FAILED';
  end if;
  return jsonb_build_object('outcome', 'ok', 'response', response);
exception
  when sqlstate 'SF052' then
    -- Raised by private.attachment_refuse: the message or announcement it
    -- came with was not kept.
    get stacked diagnostics v_detail = pg_exception_detail;
    return jsonb_build_object('outcome', 'attachment_refused', 'rows', v_detail::jsonb);
end;
$function$;

-- ---------------------------------------------------------------------------
-- 4. A file refused after it was attached stays listed, as refused
-- ---------------------------------------------------------------------------

-- 202610060001's body; a deleted file is listed only when the scan refused
-- it first (scan_error_code is cleared when a file is found clean, so a file
-- deleted by retention still drops out).
create or replace function private.file_attachment_json(p_submission_attempt uuid DEFAULT NULL::uuid, p_message uuid DEFAULT NULL::uuid, p_announcement uuid DEFAULT NULL::uuid, p_assignment uuid DEFAULT NULL::uuid, p_assessment uuid DEFAULT NULL::uuid)
returns jsonb language sql stable security definer set search_path = '' as $function$
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
  where (fo.deleted_at is null
      or (fo.scan_state = 'deleted' and fo.scan_error_code is not null))
    and b.detached_at is null
    and b.role = 'material'
    and (p_submission_attempt is not null
      and b.submission_attempt_id = p_submission_attempt
      or p_message is not null and b.message_id = p_message
      or p_announcement is not null and b.announcement_id = p_announcement
      or p_assignment is not null and b.assignment_id = p_assignment
      or p_assessment is not null and b.assessment_id = p_assessment);
$function$;

create or replace function private.coursework_files_json(p_assessment uuid DEFAULT NULL::uuid, p_question uuid DEFAULT NULL::uuid, p_grade_result uuid DEFAULT NULL::uuid, p_resource_version uuid DEFAULT NULL::uuid, p_role text DEFAULT 'material'::text)
returns jsonb language sql stable security definer set search_path to '' as $function$
  select coalesce(jsonb_agg(jsonb_build_object(
      'id', fo.id, 'displayName', fo.display_name, 'sizeBytes', fo.size_bytes,
      'mediaType', fo.declared_media_type, 'scanState', fo.scan_state)
    order by b.created_at, fo.id), '[]'::jsonb)
  from public.file_bindings b
  join public.file_objects fo on fo.id = b.file_object_id
  where (fo.deleted_at is null
      or (fo.scan_state = 'deleted' and fo.scan_error_code is not null))
    and b.detached_at is null and b.role = p_role
    and (p_assessment is not null and b.assessment_id = p_assessment
      or p_question is not null and b.assessment_question_id = p_question
      or p_grade_result is not null and b.grade_result_id = p_grade_result
      or p_resource_version is not null and b.resource_version_id = p_resource_version);
$function$;

create or replace function private.api041_resource_json(p_id uuid)
returns jsonb language sql stable security definer set search_path to '' as $function$
  select jsonb_build_object(
    'id',r.id,'schoolId',r.school_id,'classroomId',rp.classroom_id,'title',r.title,
    'resourceType',r.resource_type,'body',rv.body,'state',r.state,
    'version',r.version,'publishedAt',rp.published_at,
    'attachments',coalesce((select jsonb_agg(jsonb_build_object(
        'id', fo.id, 'displayName', fo.display_name, 'sizeBytes', fo.size_bytes,
        'mediaType', fo.declared_media_type, 'scanState', fo.scan_state)
        order by (fo.id = rv.file_object_id) desc, fo.created_at, fo.id)
      from public.file_objects fo
      where (fo.deleted_at is null
          or (fo.scan_state = 'deleted' and fo.scan_error_code is not null))
        and (fo.id = rv.file_object_id or exists (
        select 1 from public.file_bindings b where b.file_object_id = fo.id
          and b.resource_version_id = rv.id and b.detached_at is null
          and b.role = 'material'))), '[]'::jsonb),
    'links',private.content_links_json(p_resource_version => rv.id)
  ) from public.resources r
  join public.resource_versions rv on rv.resource_id=r.id and rv.version=r.current_version
  left join lateral (select x.classroom_id,x.published_at from public.resource_publications x
    where x.resource_version_id=rv.id order by x.created_at desc limit 1) rp on true
  where r.id=p_id;
$function$;
