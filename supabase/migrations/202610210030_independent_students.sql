-- Students without a class (2026-10-21, DL-072, ADR-0045).
--
-- A student could sign up, but until a teacher's class link arrived the app
-- was a single "Join your first class" screen: no AI Tutor, no notebook, no
-- way to try anything. The owner decided that joining a class adds to
-- Studafy and is never the price of using it:
--
--   1. The AI study tools are for every student account, in a class or not.
--      This supersedes ADR-0043 D3 ("students in a class only") and
--      privacy policy 1.6 §5, replaced by 1.7. A parent or teacher account
--      is still refused, the AI consent is still needed first, and names are
--      still replaced before anything is sent.
--   2. A student has a personal notebook that belongs to no class: notes
--      with no school, class or student record, only an owner. It is kept
--      apart from every class's notebook, and joining a class later changes
--      nothing in it. Typed notes stay free (DL-055); notes made by AI from a
--      photo or screenshot stay Studafy Plus, metered in the ledger.
--   3. Any of the student's own notes - personal or in a class - can be
--      edited and renamed, which nothing could do before.
--
-- Account deletion, the data export, and the helper's "my notes" reference
-- already read notebook_entries by owner, so personal notes are deleted,
-- exported and readable by the Tutor with no change to them.

-- ---------------------------------------------------------------------------
-- 1. AI for any student account.
-- ---------------------------------------------------------------------------
-- ai_enrolled_student stays: authz_notebook uses it for study sets made from
-- a class's lesson, which still need that lesson's class.
create or replace function private.ai_access(p_user uuid)
returns text language sql stable security definer set search_path = '' as $$
  select case
    -- A parent or a teacher, or no account at all.
    when p_user is null
      or not exists (select 1 from public.profiles p
        where p.id = p_user and p.deleted_at is null and p.status = 'active')
      or private.account_kind(p_user) = 'adult'
      then 'not_student'
    -- An account nothing has decided yet (signed up, never signed in as a
    -- student): not a student yet. The app records the kind at sign-in.
    when private.account_kind(p_user) is distinct from 'student' then 'no_class'
    when private.ai_current_consent(p_user) is not null then 'ok'
    when exists (select 1 from private.managed_accounts m where m.child_id = p_user)
      then 'guardian_consent_required'
    else 'consent_required'
  end;
$$;

-- ---------------------------------------------------------------------------
-- 2. Personal notes: an owner and nothing else.
-- ---------------------------------------------------------------------------
alter table public.notebook_entries
  alter column school_id drop not null,
  alter column classroom_id drop not null,
  alter column student_id drop not null;

-- A note is in a class (all three set) or personal (none set). A personal
-- note keeps no photo: the screenshot it was made from is read once and
-- never stored.
alter table public.notebook_entries
  drop constraint if exists notebook_entries_class_or_personal;
alter table public.notebook_entries
  add constraint notebook_entries_class_or_personal check (
    (school_id is null and classroom_id is null and student_id is null
      and photo_file_id is null)
    or (school_id is not null and classroom_id is not null
      and student_id is not null));

create index if not exists notebook_entries_personal_idx
  on public.notebook_entries (owner_id, created_at desc)
  where classroom_id is null and deleted_at is null;

-- The entry as the API returns it, now with when it was last changed.
create or replace function private.notebook_entry_json(p_id uuid)
returns jsonb language sql stable security definer set search_path = '' as $$
  select jsonb_build_object(
    'id', n.id, 'classroomId', n.classroom_id, 'title', n.title,
    'body', n.body, 'source', n.source, 'createdAt', n.created_at,
    'updatedAt', n.updated_at,
    'photo', case when f.id is null then null else jsonb_build_object(
      'id', f.id, 'displayName', f.display_name, 'sizeBytes', f.size_bytes,
      'mediaType', f.declared_media_type, 'scanState', f.scan_state) end)
  from public.notebook_entries n
  left join public.file_objects f on f.id = n.photo_file_id and f.deleted_at is null
  where n.id = p_id;
$$;

-- A student account: the only kind with a notebook of its own.
create or replace function private.personal_notebook_owner(p_user uuid)
returns boolean language sql stable security definer set search_path = '' as $$
  select p_user is not null and private.account_kind(p_user) = 'student';
$$;

-- How many personal notes one account may keep. Generous for a student;
-- a ceiling for a script.
create or replace function private.personal_notebook_limit()
returns integer language sql immutable set search_path = '' as $$
  select 2000;
$$;

-- ---------------------------------------------------------------------------
-- 3. Reads (api058_query).
-- ---------------------------------------------------------------------------
create or replace function private.api058_query(
  p_operation text, p_input jsonb)
returns jsonb language plpgsql stable security definer set search_path = '' as $$
declare
  v_items jsonb;
  v_ids uuid[];
begin
  if auth.uid() is null or not private.is_active_user() then
    return jsonb_build_object('outcome', 'forbidden');
  end if;
  case p_operation
    when 'listPersonal' then
      -- The caller's personal notebook, newest change first.
      select coalesce(jsonb_agg(private.notebook_entry_json(n.id)
          order by n.updated_at desc, n.id desc), '[]'::jsonb)
        into v_items
      from (
        select n.id, n.updated_at from public.notebook_entries n
        where n.owner_id = auth.uid() and n.classroom_id is null
          and n.deleted_at is null
        order by n.updated_at desc, n.id desc
        limit 500
      ) n;
      return jsonb_build_object('outcome', 'ok', 'items', v_items);

    when 'notesForPractice' then
      -- The text of the caller's own notes, for a quiz or flashcards
      -- (Studafy Max). Any of their notes, personal or in a class; nobody
      -- else's, and nothing deleted. The plan is checked again where the
      -- tokens are held.
      if private.ai_access(auth.uid()) not in ('ok') then
        return jsonb_build_object('outcome', 'forbidden');
      end if;
      if private.study_plan(auth.uid()) <> 'max' then
        return jsonb_build_object('outcome', 'plan_required');
      end if;
      select array_agg(distinct (e.value)::uuid) into v_ids
      from jsonb_array_elements_text(coalesce(p_input->'entryIds', '[]'::jsonb)) e;
      if v_ids is null or cardinality(v_ids) = 0 or cardinality(v_ids) > 20 then
        return jsonb_build_object('outcome', 'invalid');
      end if;
      select coalesce(jsonb_agg(jsonb_build_object(
          'id', n.id, 'title', n.title, 'text', n.body)
          order by n.created_at), '[]'::jsonb)
        into v_items
      from public.notebook_entries n
      where n.id = any(v_ids) and n.owner_id = auth.uid()
        and n.deleted_at is null;
      if jsonb_array_length(v_items) <> cardinality(v_ids) then
        return jsonb_build_object('outcome', 'not_found');
      end if;
      return jsonb_build_object('outcome', 'ok', 'items', v_items);

    else
      return jsonb_build_object('outcome', 'invalid');
  end case;
exception when invalid_text_representation then
  return jsonb_build_object('outcome', 'not_found');
end;
$$;

-- ---------------------------------------------------------------------------
-- 4. Writes (api058_command).
-- ---------------------------------------------------------------------------
create or replace function private.api058_command(
  p_operation text, p_resource_id uuid, p_input jsonb,
  p_idempotency_id uuid, p_idempotency_generation bigint)
returns jsonb language plpgsql security definer set search_path = '' as $$
declare
  body jsonb := coalesce(p_input->'body', '{}'::jsonb);
  v_id uuid;
  v_school uuid;
  v_source text;
  v_title text;
  v_body text;
  response jsonb;
  audit_action text;
  request_id text := nullif(current_setting('studafy.request_id', true), '');
begin
  if auth.uid() is null or not private.is_active_user() then
    return jsonb_build_object('outcome', 'forbidden');
  end if;

  case p_operation
    when 'createPersonal' then
      if not private.personal_notebook_owner(auth.uid()) then
        return jsonb_build_object('outcome', 'forbidden');
      end if;
      -- 'whiteboard' (made by AI from a photo or screenshot) is set by the
      -- API after it has run the model; the typed route always sends
      -- 'typed'.
      v_source := coalesce(body->>'source', 'typed');
      if v_source not in ('typed', 'whiteboard') then
        return jsonb_build_object('outcome', 'invalid');
      end if;
      -- Two creates at once must not both slip under the limit.
      perform pg_advisory_xact_lock(
        hashtextextended('personal_notebook:' || auth.uid()::text, 0));
      if (select count(*) from public.notebook_entries n
          where n.owner_id = auth.uid() and n.classroom_id is null
            and n.deleted_at is null) >= private.personal_notebook_limit() then
        return jsonb_build_object('outcome', 'invalid_state');
      end if;
      insert into public.notebook_entries(owner_id, title, body, source)
      values (auth.uid(), btrim(body->>'title'), body->>'body', v_source)
      returning id into v_id;
      audit_action := 'notebook_entry_created';

    when 'updateEntry' then
      -- Any of the caller's own notes, personal or in a class: a student's
      -- notes are theirs to rename and correct, even in a class that has
      -- since closed.
      v_title := nullif(btrim(body->>'title'), '');
      v_body := nullif(body->>'body', '');
      if v_title is null and v_body is null then
        return jsonb_build_object('outcome', 'invalid');
      end if;
      update public.notebook_entries n
      set title = coalesce(v_title, n.title),
          body = coalesce(v_body, n.body),
          updated_at = now()
      where n.id = p_resource_id and n.owner_id = auth.uid()
        and n.deleted_at is null
      returning n.id, n.school_id into v_id, v_school;
      if v_id is null then return jsonb_build_object('outcome', 'not_found'); end if;
      audit_action := 'notebook_entry_updated';

    when 'deleteEntry' then
      update public.notebook_entries n set deleted_at = now(), updated_at = now()
      where n.id = p_resource_id and n.owner_id = auth.uid() and n.deleted_at is null
      returning n.id, n.school_id into v_id, v_school;
      if v_id is null then return jsonb_build_object('outcome', 'not_found'); end if;
      audit_action := 'notebook_entry_deleted';

    else
      return jsonb_build_object('outcome', 'invalid');
  end case;

  response := case when p_operation = 'deleteEntry'
    then jsonb_build_object('id', v_id, 'deleted', true)
    else private.notebook_entry_json(v_id) end;

  insert into public.audit_events(school_id, actor_id, action, entity_type,
    entity_id, after_value, request_id)
  values (v_school, auth.uid(), audit_action, 'notebook_entry', v_id,
    -- That a note changed and where it lives - never what it says.
    jsonb_build_object('personal', v_school is null,
      'source', coalesce(v_source, 'unchanged')),
    request_id);

  if not private.api_idempotency_complete(
    p_idempotency_id, p_idempotency_generation,
    case when p_operation = 'createPersonal' then 201 else 200 end, response) then
    raise exception 'API058_IDEMPOTENCY_COMPLETION_FAILED';
  end if;
  return jsonb_build_object('outcome', 'ok', 'response', response);
exception when invalid_text_representation or check_violation then
  return jsonb_build_object('outcome', 'invalid');
end;
$$;

-- ---------------------------------------------------------------------------
-- 5. Owners and grants: the API calls the two dispatchers; the helpers are
--    reached only through them.
-- ---------------------------------------------------------------------------
alter function private.ai_access(uuid) owner to postgres;
alter function private.notebook_entry_json(uuid) owner to postgres;
alter function private.personal_notebook_owner(uuid) owner to postgres;
alter function private.personal_notebook_limit() owner to postgres;
alter function private.api058_query(text, jsonb) owner to postgres;
alter function private.api058_command(text, uuid, jsonb, uuid, bigint)
  owner to postgres;

revoke all on function private.personal_notebook_owner(uuid)
  from public, anon, authenticated, service_role, studafy_worker_runtime,
  studafy_api_runtime;
revoke all on function private.personal_notebook_limit()
  from public, anon, authenticated, service_role, studafy_worker_runtime,
  studafy_api_runtime;
revoke all on function private.api058_query(text, jsonb)
  from public, anon, authenticated, service_role, studafy_worker_runtime;
revoke all on function private.api058_command(text, uuid, jsonb, uuid, bigint)
  from public, anon, authenticated, service_role, studafy_worker_runtime;
grant execute on function private.api058_query(text, jsonb)
  to studafy_api_runtime;
grant execute on function private.api058_command(text, uuid, jsonb, uuid, bigint)
  to studafy_api_runtime;
