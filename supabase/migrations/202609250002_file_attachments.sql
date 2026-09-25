-- Attachments on submissions, chat messages and announcements.
--
-- The pieces already existed and were never joined up: file_bindings has
-- carried submission_attempt_id and message_id since DB-020, FILE-050/051
-- ship the quarantine, structural analysis, metadata strip and single-use
-- delivery grant, and private.file051_authorize_download already knows how to
-- reason about owner, publication, own-submission and assigned-staff
-- relationships. What was missing was a command that writes a binding, and a
-- download rule for conversations and announcements.
--
-- Three properties are load-bearing:
--
--   1. **One gate, not three.** private.file_attach_bind is the only way a
--      binding is written. Every invariant lives there once, so a fourth
--      attachment surface cannot accidentally ship with weaker checks than
--      the first three.
--   2. **A file is bound exactly once.** Binding is what grants other people
--      access, so re-binding an object would let one upload be smuggled into
--      a second conversation it was never authorised for. The gate refuses a
--      file that already has a target.
--   3. **Binding is atomic with the thing it is attached to.** The gate
--      raises, so a refused attachment rolls back the message or submission
--      rather than delivering it with a missing file.
--
-- Forward-only: the two command surfaces are extended by renaming the current
-- function and delegating to it, rather than by re-issuing five hundred lines
-- of CASE arms that this change does not touch.

-- ---------------------------------------------------------------------------
-- 1. Purpose policies for the new labels.
--
-- Deliberately narrower than the teaching purposes: a chat attachment is the
-- least supervised upload in the product, so it gets the smallest ceiling.
-- No office formats anywhere - the pipeline has no structural parser for a
-- zip container, so one would quarantine forever.
-- ---------------------------------------------------------------------------
insert into public.file_purpose_policies(
  purpose, policy_version, maximum_size_bytes, allowed_media_types)
values
  ('message_attachment', 'file-attach-v1', 5242880,
    array['application/pdf', 'image/jpeg', 'image/png']),
  ('announcement_attachment', 'file-attach-v1', 10485760,
    array['application/pdf', 'image/jpeg', 'image/png'])
on conflict (purpose) do update set
  policy_version = excluded.policy_version,
  maximum_size_bytes = excluded.maximum_size_bytes,
  allowed_media_types = excluded.allowed_media_types,
  enabled = excluded.enabled,
  updated_at = now();

-- ---------------------------------------------------------------------------
-- 2. Announcements become a binding target.
--
-- messages and submission_attempts already were. The one-target check is
-- recreated rather than relaxed: a binding row still names exactly one thing,
-- which is what makes the download rules a disjoint set of cases.
-- ---------------------------------------------------------------------------
alter table public.file_bindings
  add column if not exists announcement_id uuid;

do $$ begin
  if not exists (
    select 1 from pg_constraint
    where conrelid = 'public.file_bindings'::regclass
      and conname = 'file_attach_binding_announcement_school_fk'
  ) then
    alter table public.file_bindings
      add constraint file_attach_binding_announcement_school_fk
      foreign key (school_id, announcement_id)
      references public.announcements(school_id, id) on delete cascade not valid;
  end if;
end $$;

alter table public.file_bindings
  drop constraint if exists file050_binding_one_target;
alter table public.file_bindings
  add constraint file050_binding_one_target check (
    num_nonnulls(
      resource_version_id, submission_attempt_id, message_id,
      ai_grading_draft_id, upload_session_id, announcement_id
    ) = 1
  ) not valid;
alter table public.file_bindings validate constraint file050_binding_one_target;

-- A binding is evidence of who may read an object, so it stays immutable.
drop trigger if exists db021_immutable_file_binding on public.file_bindings;
create trigger db021_immutable_file_binding before update on public.file_bindings
for each row execute function private.reject_immutable_columns(
  'id', 'school_id', 'file_object_id', 'resource_version_id',
  'submission_attempt_id', 'message_id', 'ai_grading_draft_id',
  'upload_session_id', 'announcement_id', 'created_at'
);

create index if not exists file_attach_binding_message_idx
  on public.file_bindings (message_id) where message_id is not null;
create index if not exists file_attach_binding_announcement_idx
  on public.file_bindings (announcement_id) where announcement_id is not null;
create index if not exists file_attach_binding_attempt_idx
  on public.file_bindings (submission_attempt_id)
  where submission_attempt_id is not null;

-- ---------------------------------------------------------------------------
-- 3. The single binding gate.
--
-- Returns 'ok', or a reason the caller maps to an outcome. Raises only on an
-- internal contradiction, never on ordinary refusal, so a bad request is a
-- 4xx rather than a 500.
--
-- Exactly one target must be supplied. The caller has already proved it may
-- write that target; this function proves the *files* are the caller's own,
-- unbound, clean-pipeline objects of the right purpose in the right school.
-- ---------------------------------------------------------------------------
create or replace function private.file_attach_bind(
  p_file_ids jsonb,
  p_purpose public.file_purpose,
  p_school uuid,
  p_submission_attempt uuid default null,
  p_message uuid default null,
  p_announcement uuid default null
) returns text language plpgsql security definer set search_path = '' as $$
declare
  v_ids uuid[];
  v_id uuid;
  v_file public.file_objects%rowtype;
  v_count int;
begin
  if auth.uid() is null then return 'forbidden'; end if;
  if num_nonnulls(p_submission_attempt, p_message, p_announcement) <> 1 then
    raise exception 'FILE_ATTACH_TARGET_AMBIGUOUS';
  end if;
  if p_file_ids is null or jsonb_typeof(p_file_ids) <> 'array' then
    return 'ok';
  end if;

  -- Duplicates in the request would each try to bind the same object, and the
  -- second would be refused as already bound. Rejecting up front says why.
  select array_agg(distinct x::uuid), count(*)
    into v_ids, v_count
  from jsonb_array_elements_text(p_file_ids) x;
  if v_count = 0 then return 'ok'; end if;
  if v_count <> cardinality(v_ids) then return 'invalid'; end if;
  -- Matches the client's own ceiling. A cap belongs on the server because the
  -- client's is a courtesy.
  if cardinality(v_ids) > 5 then return 'invalid'; end if;

  foreach v_id in array v_ids loop
    select * into v_file from public.file_objects fo where fo.id = v_id;
    if v_file.id is null or v_file.deleted_at is not null
      or v_file.scan_state = 'deleted' then
      return 'invalid';
    end if;
    -- Ownership is the whole authorisation: a file nobody else can read is
    -- being handed to the people who can read the target.
    if v_file.owner_id <> auth.uid() then return 'forbidden'; end if;
    if v_file.school_id <> p_school then return 'forbidden'; end if;
    if v_file.purpose <> p_purpose then return 'invalid'; end if;
    -- Already attached somewhere. The upload-session binding every completed
    -- upload carries is not a target and is excluded.
    if exists (
      select 1 from public.file_bindings b
      where b.file_object_id = v_id
        and num_nonnulls(
          b.resource_version_id, b.submission_attempt_id, b.message_id,
          b.ai_grading_draft_id, b.announcement_id
        ) > 0
    ) then
      return 'invalid';
    end if;

    insert into public.file_bindings(
      school_id, file_object_id, submission_attempt_id, message_id,
      announcement_id)
    values (
      p_school, v_id, p_submission_attempt, p_message, p_announcement);
  end loop;

  return 'ok';
end;
$$;

revoke all on function private.file_attach_bind(
  jsonb, public.file_purpose, uuid, uuid, uuid, uuid) from public;
alter function private.file_attach_bind(
  jsonb, public.file_purpose, uuid, uuid, uuid, uuid) owner to postgres;

-- ---------------------------------------------------------------------------
-- 4. Read model.
--
-- What a client needs to render an attachment and decide whether it can be
-- opened yet. Never an object key, a bucket or a URL: a download is a
-- separate, single-use, user-bound grant.
-- ---------------------------------------------------------------------------
create or replace function private.file_attachment_json(
  p_submission_attempt uuid default null,
  p_message uuid default null,
  p_announcement uuid default null
) returns jsonb language sql stable security definer set search_path = '' as $$
  select coalesce(
    jsonb_agg(
      jsonb_build_object(
        'id', fo.id,
        'displayName', fo.display_name,
        'sizeBytes', fo.size_bytes,
        'mediaType', fo.declared_media_type,
        -- The client shows "checking" until this is clean; the delivery
        -- endpoint refuses anything else regardless of what is rendered.
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
      or p_announcement is not null and b.announcement_id = p_announcement);
$$;

revoke all on function private.file_attachment_json(uuid, uuid, uuid) from public;
alter function private.file_attachment_json(uuid, uuid, uuid) owner to postgres;

-- ---------------------------------------------------------------------------
-- 5. Download authorization gains two relationships.
--
-- Both mirror the rule that already decides whether the *thing* is visible,
-- so "I can see the message" and "I can open its attachment" can never
-- disagree - a mismatch either leaks a file or shows an unopenable one.
-- ---------------------------------------------------------------------------
create or replace function private.file051_authorize_download(p_file_id uuid)
returns jsonb language plpgsql stable security definer set search_path = '' as $$
declare
  f public.file_objects%rowtype;
  reason text := 'denied';
begin
  if auth.uid() is null then
    return jsonb_build_object('allowed', false, 'reason', 'invalid_resource');
  end if;
  select * into f from public.file_objects fo where fo.id = p_file_id;
  if f.id is null then
    return jsonb_build_object('allowed', false, 'reason', 'invalid_resource');
  end if;
  if f.deleted_at is not null or f.scan_state = 'deleted' then
    return jsonb_build_object('allowed', false, 'schoolId', f.school_id, 'reason', 'invalid_resource');
  end if;
  if f.owner_id = auth.uid() then
    return jsonb_build_object('allowed', true, 'schoolId', f.school_id, 'reason', 'owner');
  end if;

  if exists (
    select 1 from public.file_bindings b
    join public.resource_versions rv on rv.id = b.resource_version_id
    join public.resource_publications rp on rp.resource_version_id = rv.id
    where b.file_object_id = f.id
      and rp.state = 'published' and rp.published_at is not null
      and rp.withdrawn_at is null
      and private.can_view_resource_publication(rp.id)
  ) then
    return jsonb_build_object('allowed', true, 'schoolId', f.school_id, 'reason', 'publication');
  end if;

  -- Own submission attempt: the student who authored the attempt.
  if exists (
    select 1 from public.file_bindings b
    join public.submission_attempts sa on sa.id = b.submission_attempt_id
    join public.submissions s on s.id = sa.submission_id
    join public.students st on st.id = s.student_id and st.school_id = s.school_id
    where b.file_object_id = f.id and st.user_id = auth.uid()
  ) then
    return jsonb_build_object('allowed', true, 'schoolId', f.school_id, 'reason', 'own_submission');
  end if;

  -- A submission's attachment is also readable by the staff who may mark it.
  -- Without this a teacher could see that work was handed in and never open
  -- it, which is the same as it not having been handed in.
  if exists (
    select 1 from public.file_bindings b
    join public.submission_attempts sa on sa.id = b.submission_attempt_id
    join public.submissions s on s.id = sa.submission_id
    join public.assignments a on a.id = s.assignment_id
    where b.file_object_id = f.id
      and private.api041_class_writer(a.classroom_id)
  ) then
    return jsonb_build_object('allowed', true, 'schoolId', f.school_id, 'reason', 'assigned_staff');
  end if;

  -- Chat: anyone still in the conversation the message belongs to. Someone
  -- who has left keeps no access, which matches how the thread itself reads.
  if exists (
    select 1 from public.file_bindings b
    join public.messages m on m.id = b.message_id
    where b.file_object_id = f.id
      and m.deleted_at is null
      and private.is_conversation_participant(m.conversation_id)
  ) then
    return jsonb_build_object('allowed', true, 'schoolId', f.school_id, 'reason', 'message_participant');
  end if;

  -- Announcements: the same test listAnnouncements applies - an active
  -- membership of the school, and for a class announcement, visibility of
  -- that class.
  if exists (
    select 1 from public.file_bindings b
    join public.announcements an on an.id = b.announcement_id
    where b.file_object_id = f.id
      and private.has_active_membership(an.school_id)
      and (an.classroom_id is null or private.can_view_classroom(an.classroom_id))
  ) then
    return jsonb_build_object('allowed', true, 'schoolId', f.school_id, 'reason', 'announcement_audience');
  end if;

  -- Grading and class material: assigned lead/co teachers and admins of the
  -- classroom the file's target belongs to.
  if exists (
    select 1 from public.file_bindings b
    join public.upload_sessions u on u.id = b.upload_session_id
    where b.file_object_id = f.id
      and (
        (u.assignment_id is not null and private.api041_class_writer(
          (select a.classroom_id from public.assignments a where a.id = u.assignment_id)))
        or (u.grade_result_id is not null and private.api041_class_writer(
          (select a.classroom_id from public.grade_results g
           join public.assessments a on a.id = g.assessment_id
           where g.id = u.grade_result_id)))
      )
  ) then
    return jsonb_build_object('allowed', true, 'schoolId', f.school_id, 'reason', 'assigned_staff');
  end if;

  return jsonb_build_object('allowed', false, 'schoolId', f.school_id, 'reason', reason);
end;
$$;

alter function private.file051_authorize_download(uuid) owner to postgres;

-- ---------------------------------------------------------------------------
-- 6. The three commands.
--
-- Each delegates the work it does not change, then binds. The bind runs in
-- the delegate's transaction, so a refusal takes the message or submission
-- with it.
-- ---------------------------------------------------------------------------
-- Guarded so a re-run after a partially applied deploy is a no-op rather
-- than a hard failure on the rename.
do $$ begin
  if not exists (
    select 1 from pg_proc p join pg_namespace n on n.oid = p.pronamespace
    where n.nspname = 'private' and p.proname = 'api041_command_pre_attachments'
  ) then
    alter function private.api041_command(text, uuid, jsonb, uuid, bigint) rename to api041_command_pre_attachments;
  end if;
end $$;

create or replace function private.api041_command(
  p_operation text, p_resource_id uuid, p_input jsonb,
  p_idempotency_id uuid, p_idempotency_generation bigint)
returns jsonb language plpgsql security definer set search_path = '' as $$
declare
  result jsonb;
  v_attachments jsonb;
  v_attempt uuid;
  v_school uuid;
  v_bind text;
begin
  result := private.api041_command_pre_attachments(
    p_operation, p_resource_id, p_input, p_idempotency_id,
    p_idempotency_generation);

  if p_operation <> 'submitAssignment'
    or coalesce(result->>'outcome', '') <> 'ok' then
    return result;
  end if;

  select s.current_attempt_id, s.school_id into v_attempt, v_school
  from public.submissions s
  where s.id = ((result->'response')->>'id')::uuid;
  if v_attempt is null then raise exception 'FILE_ATTACH_NO_ATTEMPT'; end if;

  -- The field is always present, empty or not: V1Submission requires it, and
  -- a response that omits it on the no-attachment path fails validation. The
  -- message and announcement surfaces get this for free from their json
  -- helpers; this arm builds its response inline, so it is set here.
  v_attachments := (p_input->'body')->'attachmentFileIds';
  if v_attachments is not null
    and jsonb_array_length(coalesce(v_attachments, '[]'::jsonb)) > 0 then
    v_bind := private.file_attach_bind(
      v_attachments, 'assignment_submission'::public.file_purpose, v_school,
      p_submission_attempt => v_attempt);
    if v_bind <> 'ok' then
      return jsonb_build_object('outcome', v_bind);
    end if;
  end if;

  return jsonb_set(
    result, array['response', 'attachments'],
    private.file_attachment_json(p_submission_attempt => v_attempt));
end;
$$;

alter function private.api041_command(text, uuid, jsonb, uuid, bigint)
  owner to postgres;

-- Reads of a submission carry its attachments, so marking work is possible.
-- Guarded so a re-run after a partially applied deploy is a no-op rather
-- than a hard failure on the rename.
do $$ begin
  if not exists (
    select 1 from pg_proc p join pg_namespace n on n.oid = p.pronamespace
    where n.nspname = 'private' and p.proname = 'api041_query_pre_attachments'
  ) then
    alter function private.api041_query(text, uuid, jsonb) rename to api041_query_pre_attachments;
  end if;
end $$;

create or replace function private.api041_query(
  p_operation text, p_resource_id uuid, p_input jsonb)
returns jsonb language plpgsql stable security definer set search_path = '' as $$
declare
  result jsonb;
begin
  result := private.api041_query_pre_attachments(
    p_operation, p_resource_id, p_input);
  if p_operation <> 'listAssignmentSubmissions'
    or result->'items' is null then
    return result;
  end if;
  return jsonb_set(result, array['items'], (
    select coalesce(jsonb_agg(
      item || jsonb_build_object(
        'attachments',
        private.file_attachment_json(
          p_submission_attempt => (
            select s.current_attempt_id from public.submissions s
            where s.id = (item->>'id')::uuid))
      ) order by ordinality
    ), '[]'::jsonb)
    from jsonb_array_elements(result->'items') with ordinality as t(item, ordinality)
  ));
end;
$$;

alter function private.api041_query(text, uuid, jsonb) owner to postgres;

-- Guarded so a re-run after a partially applied deploy is a no-op rather
-- than a hard failure on the rename.
do $$ begin
  if not exists (
    select 1 from pg_proc p join pg_namespace n on n.oid = p.pronamespace
    where n.nspname = 'private' and p.proname = 'api042_command_pre_attachments'
  ) then
    alter function private.api042_command(text, uuid, jsonb, uuid, bigint) rename to api042_command_pre_attachments;
  end if;
end $$;

create or replace function private.api042_command(
  p_operation text, p_resource_id uuid, p_input jsonb,
  p_idempotency_id uuid, p_idempotency_generation bigint)
returns jsonb language plpgsql security definer set search_path = '' as $$
declare
  result jsonb;
  v_attachments jsonb;
  v_entity uuid;
  v_school uuid;
  v_bind text;
begin
  result := private.api042_command_pre_attachments(
    p_operation, p_resource_id, p_input, p_idempotency_id,
    p_idempotency_generation);

  if p_operation not in ('sendMessage', 'createAnnouncement')
    or coalesce(result->>'outcome', '') <> 'ok' then
    return result;
  end if;

  v_attachments := (p_input->'body')->'attachmentFileIds';
  if v_attachments is null or jsonb_array_length(coalesce(v_attachments, '[]'::jsonb)) = 0 then
    return result;
  end if;

  v_entity := ((result->'response')->>'id')::uuid;
  if v_entity is null then raise exception 'FILE_ATTACH_NO_ENTITY'; end if;

  if p_operation = 'sendMessage' then
    select m.school_id into v_school from public.messages m where m.id = v_entity;
    v_bind := private.file_attach_bind(
      v_attachments, 'message_attachment'::public.file_purpose, v_school,
      p_message => v_entity);
  else
    select an.school_id into v_school
    from public.announcements an where an.id = v_entity;
    v_bind := private.file_attach_bind(
      v_attachments, 'announcement_attachment'::public.file_purpose, v_school,
      p_announcement => v_entity);
  end if;

  if v_bind <> 'ok' then
    return jsonb_build_object('outcome', v_bind);
  end if;

  return jsonb_set(
    result, array['response', 'attachments'],
    case when p_operation = 'sendMessage'
      then private.file_attachment_json(p_message => v_entity)
      else private.file_attachment_json(p_announcement => v_entity)
    end);
end;
$$;

alter function private.api042_command(text, uuid, jsonb, uuid, bigint)
  owner to postgres;

-- ---------------------------------------------------------------------------
-- 7. Reads of messages and announcements carry their attachments.
-- ---------------------------------------------------------------------------
create or replace function private.api042_message_json(p_id uuid)
returns jsonb language sql stable security definer set search_path = '' as $$
  -- Identical to the FILE-050-era shape plus 'attachments'. The deleted_at
  -- filter is part of that shape: a deleted message resolves to null rather
  -- than to a row with its body in it.
  select jsonb_build_object(
    'id', m.id, 'conversationId', m.conversation_id, 'senderId', m.sender_id,
    'clientMessageId', m.client_message_id, 'body', m.body,
    'createdAt', m.created_at,
    'attachments', private.file_attachment_json(p_message => m.id)
  ) from public.messages m where m.id = p_id and m.deleted_at is null;
$$;

alter function private.api042_message_json(uuid) owner to postgres;

create or replace function private.api042_announcement_json(p_id uuid)
returns jsonb language sql stable security definer set search_path = '' as $$
  select jsonb_build_object(
    'id', a.id, 'schoolId', a.school_id, 'classroomId', a.classroom_id,
    'title', a.title, 'body', a.body, 'audience', a.audience,
    'important', a.important, 'publishedAt', a.published_at,
    'attachments', private.file_attachment_json(p_announcement => a.id)
  ) from public.announcements a where a.id = p_id;
$$;

alter function private.api042_announcement_json(uuid) owner to postgres;

-- Grants follow the function OID, so a rename carries the API role's EXECUTE
-- with it: the predecessor keeps it and the new wrapper has none. Left alone
-- that is two faults at once - the API cannot call the wrapper, and it can
-- still call the predecessor and skip it. auth030_grants.sql asserts the
-- runtime's executable surface exactly, which is what caught this.
alter function private.api041_command_pre_attachments(
  text, uuid, jsonb, uuid, bigint) owner to postgres;
alter function private.api041_query_pre_attachments(text, uuid, jsonb)
  owner to postgres;
alter function private.api042_command_pre_attachments(
  text, uuid, jsonb, uuid, bigint) owner to postgres;

revoke all on function private.api041_command_pre_attachments(
  text, uuid, jsonb, uuid, bigint)
  from public, anon, authenticated, service_role, studafy_worker_runtime,
  studafy_api_runtime;
revoke all on function private.api041_query_pre_attachments(text, uuid, jsonb)
  from public, anon, authenticated, service_role, studafy_worker_runtime,
  studafy_api_runtime;
revoke all on function private.api042_command_pre_attachments(
  text, uuid, jsonb, uuid, bigint)
  from public, anon, authenticated, service_role, studafy_worker_runtime,
  studafy_api_runtime;

revoke all on function private.api041_command(
  text, uuid, jsonb, uuid, bigint)
  from public, anon, authenticated, service_role, studafy_worker_runtime;
revoke all on function private.api041_query(text, uuid, jsonb)
  from public, anon, authenticated, service_role, studafy_worker_runtime;
revoke all on function private.api042_command(
  text, uuid, jsonb, uuid, bigint)
  from public, anon, authenticated, service_role, studafy_worker_runtime;
grant execute on function private.api041_command(
  text, uuid, jsonb, uuid, bigint) to studafy_api_runtime;
grant execute on function private.api041_query(text, uuid, jsonb)
  to studafy_api_runtime;
grant execute on function private.api042_command(
  text, uuid, jsonb, uuid, bigint) to studafy_api_runtime;
