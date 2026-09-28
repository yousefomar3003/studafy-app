-- The student's Notebook, and quizzes and flashcards made from lessons.
--
-- Notebook: a student's own notes, one notebook per class, every entry dated.
-- Typing a note is free. Turning a photo of the lesson whiteboard into notes
-- is Studafy Plus: the API runs the model (metered by api047_ai_usage) and
-- files the result here with source 'whiteboard' and the photo it came from.
-- Nobody but the student reads their notebook.
--
-- Study sets: a quiz or a set of flashcards generated from one version of a
-- lesson. Studafy Max. Generated once per lesson version and kind, then
-- shared with every Max student in that class - the provider is paid once,
-- not once per student, and the set cannot drift between classmates. A new
-- version of the lesson gets a new set.
--
-- Two reviewed entry points, api046_query and api046_command, keep the API
-- role's executable surface narrow (auth030_grants.sql pins it).

-- ---------------------------------------------------------------------------
-- 1. Whiteboard photos are uploaded through FILE-050 like any other file.
-- ---------------------------------------------------------------------------
insert into public.file_purpose_policies(
  purpose, policy_version, maximum_size_bytes, allowed_media_types)
values ('notebook_photo', 'notebook-photo-v1', 10485760,
  array['image/jpeg', 'image/png'])
on conflict (purpose) do update set
  policy_version = excluded.policy_version,
  maximum_size_bytes = excluded.maximum_size_bytes,
  allowed_media_types = excluded.allowed_media_types,
  enabled = true,
  updated_at = now();

alter table public.upload_sessions
  drop constraint if exists file050_upload_target_check;
alter table public.upload_sessions
  add constraint file050_upload_target_check check (
    policy_version='legacy' or case purpose
      when 'profile_image' then num_nonnulls(classroom_id,assignment_id,student_id,grade_result_id)=0
      when 'lesson_resource' then classroom_id is not null and num_nonnulls(assignment_id,student_id,grade_result_id)=0
      when 'assignment_material' then num_nonnulls(classroom_id,assignment_id)=1 and num_nonnulls(student_id,grade_result_id)=0
      when 'assignment_submission' then assignment_id is not null and student_id is not null and num_nonnulls(classroom_id,grade_result_id)=0
      when 'paper_scan' then grade_result_id is not null and num_nonnulls(classroom_id,assignment_id,student_id)=0
      when 'coach_attachment' then student_id is not null and num_nonnulls(classroom_id,assignment_id,grade_result_id)=0
      when 'message_attachment' then num_nonnulls(classroom_id,assignment_id,student_id,grade_result_id)=0
      when 'announcement_attachment' then num_nonnulls(classroom_id,assignment_id,student_id,grade_result_id)=0
      -- The class whose notebook the photo is for.
      when 'notebook_photo' then classroom_id is not null and num_nonnulls(assignment_id,student_id,grade_result_id)=0
      else false end
  ) not valid;
alter table public.upload_sessions validate constraint file050_upload_target_check;

do $$ begin
  if not exists (
    select 1 from pg_proc p join pg_namespace n on n.oid = p.pronamespace
    where n.nspname = 'private' and p.proname = 'file050_authorize_target_pre_notebook'
  ) then
    alter function private.file050_authorize_target(jsonb)
      rename to file050_authorize_target_pre_notebook;
  end if;
end $$;

create or replace function private.file050_authorize_target(p_body jsonb)
returns jsonb language plpgsql stable security definer set search_path = '' as $$
declare
  v_class uuid;
begin
  if p_body->>'purpose' <> 'notebook_photo' then
    return private.file050_authorize_target_pre_notebook(p_body);
  end if;
  -- A student photographs the board of a class they are in.
  v_class := nullif(p_body->>'classroomId', '')::uuid;
  if v_class is null or not exists (
    select 1 from public.students s
    join public.enrollments e on e.student_id = s.id
      and e.classroom_id = v_class and e.active and e.status = 'active'
    where s.user_id = auth.uid() and s.deleted_at is null
      and s.school_id = nullif(p_body->>'schoolId', '')::uuid
  ) then
    return jsonb_build_object('allowed', false);
  end if;
  -- Standing in the school is what a profile photo already asks, so the
  -- membership the session is owned through is resolved the same way.
  return private.file050_authorize_target_pre_notebook(
    jsonb_set(p_body - 'classroomId', array['purpose'], '"profile_image"'::jsonb));
exception when invalid_text_representation then
  return jsonb_build_object('allowed', false);
end;
$$;

alter function private.file050_authorize_target(jsonb) owner to postgres;
alter function private.file050_authorize_target_pre_notebook(jsonb) owner to postgres;
revoke all on function private.file050_authorize_target(jsonb)
  from public, anon, authenticated, service_role, studafy_worker_runtime,
  studafy_api_runtime;
revoke all on function private.file050_authorize_target_pre_notebook(jsonb)
  from public, anon, authenticated, service_role, studafy_worker_runtime,
  studafy_api_runtime;

-- ---------------------------------------------------------------------------
-- 2. Tables.
-- ---------------------------------------------------------------------------
create table if not exists public.notebook_entries (
  id uuid primary key default gen_random_uuid(),
  school_id uuid not null references public.schools(id) on delete cascade,
  classroom_id uuid not null,
  student_id uuid not null,
  owner_id uuid not null references public.profiles(id) on delete cascade,
  title text not null check (length(trim(title)) between 1 and 200),
  body text not null check (length(body) between 1 and 20000),
  source text not null check (source in ('typed', 'whiteboard')),
  photo_file_id uuid references public.file_objects(id) on delete set null,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  deleted_at timestamptz,
  foreign key (school_id, classroom_id)
    references public.classrooms(school_id, id) on delete cascade,
  foreign key (school_id, student_id)
    references public.students(school_id, id) on delete cascade
);
create index if not exists notebook_entries_owner_class_idx
  on public.notebook_entries (owner_id, classroom_id, created_at desc)
  where deleted_at is null;
alter table public.notebook_entries enable row level security;
-- No policies: every read and write goes through api046, which checks the
-- owner. RLS with no policy denies any direct table access.
revoke all on public.notebook_entries from anon, authenticated;

create table if not exists public.study_sets (
  id uuid primary key default gen_random_uuid(),
  school_id uuid not null references public.schools(id) on delete cascade,
  classroom_id uuid not null,
  resource_id uuid not null references public.resources(id) on delete cascade,
  resource_version_id uuid not null references public.resource_versions(id) on delete cascade,
  kind text not null check (kind in ('quiz', 'flashcards')),
  items jsonb not null check (jsonb_typeof(items) = 'array'
    and jsonb_array_length(items) between 1 and 30),
  model text not null,
  created_by uuid references public.profiles(id) on delete set null,
  created_at timestamptz not null default now(),
  withdrawn_at timestamptz,
  unique (resource_version_id, kind),
  foreign key (school_id, classroom_id)
    references public.classrooms(school_id, id) on delete cascade
);
alter table public.study_sets enable row level security;
revoke all on public.study_sets from anon, authenticated;

-- ---------------------------------------------------------------------------
-- 3. Helpers.
-- ---------------------------------------------------------------------------
-- The caller's student record in a class they are enrolled in.
create or replace function private.notebook_student(p_class uuid)
returns uuid language sql stable security definer set search_path = '' as $$
  select s.id from public.students s
  join public.enrollments e on e.student_id = s.id
    and e.classroom_id = p_class and e.active and e.status = 'active'
  where s.user_id = auth.uid() and s.deleted_at is null
  limit 1;
$$;
revoke all on function private.notebook_student(uuid)
  from public, anon, authenticated, service_role, studafy_worker_runtime,
  studafy_api_runtime;
alter function private.notebook_student(uuid) owner to postgres;

create or replace function private.notebook_entry_json(p_id uuid)
returns jsonb language sql stable security definer set search_path = '' as $$
  select jsonb_build_object(
    'id', n.id, 'classroomId', n.classroom_id, 'title', n.title,
    'body', n.body, 'source', n.source, 'createdAt', n.created_at,
    'photo', case when f.id is null then null else jsonb_build_object(
      'id', f.id, 'displayName', f.display_name, 'sizeBytes', f.size_bytes,
      'mediaType', f.declared_media_type, 'scanState', f.scan_state) end)
  from public.notebook_entries n
  left join public.file_objects f on f.id = n.photo_file_id and f.deleted_at is null
  where n.id = p_id;
$$;
revoke all on function private.notebook_entry_json(uuid)
  from public, anon, authenticated, service_role, studafy_worker_runtime,
  studafy_api_runtime;
alter function private.notebook_entry_json(uuid) owner to postgres;

-- The published lesson a Max student may study from: the version currently
-- published to a class they can see. Null when they may not.
create or replace function private.study_lesson(p_resource uuid)
returns jsonb language sql stable security definer set search_path = '' as $$
  select jsonb_build_object(
    'resourceId', r.id, 'versionId', rv.id, 'schoolId', r.school_id,
    'classroomId', rp.classroom_id, 'title', r.title, 'body', rv.body)
  from public.resources r
  join public.resource_versions rv
    on rv.resource_id = r.id and rv.version = r.current_version
  join public.resource_publications rp on rp.resource_version_id = rv.id
  where r.id = p_resource and r.deleted_at is null and r.state = 'published'
    and rp.state = 'published' and rp.withdrawn_at is null
    and rp.classroom_id is not null
    and private.can_view_resource_publication(rp.id)
  order by rp.published_at desc nulls last
  limit 1;
$$;
revoke all on function private.study_lesson(uuid)
  from public, anon, authenticated, service_role, studafy_worker_runtime,
  studafy_api_runtime;
alter function private.study_lesson(uuid) owner to postgres;

create or replace function private.study_set_json(p_id uuid)
returns jsonb language sql stable security definer set search_path = '' as $$
  select jsonb_build_object(
    'id', s.id, 'resourceId', s.resource_id, 'kind', s.kind,
    'items', s.items, 'createdAt', s.created_at)
  from public.study_sets s where s.id = p_id and s.withdrawn_at is null;
$$;
revoke all on function private.study_set_json(uuid)
  from public, anon, authenticated, service_role, studafy_worker_runtime,
  studafy_api_runtime;
alter function private.study_set_json(uuid) owner to postgres;

-- ---------------------------------------------------------------------------
-- 4. Reads.
-- ---------------------------------------------------------------------------
create or replace function private.api046_query(
  p_operation text, p_resource_id uuid, p_input jsonb)
returns jsonb language plpgsql stable security definer set search_path = '' as $$
declare
  v_lesson jsonb;
  v_id uuid;
  v_items jsonb;
begin
  if auth.uid() is null or not private.is_active_user() then
    return jsonb_build_object('outcome', 'forbidden');
  end if;
  case p_operation
    when 'listNotebookEntries' then
      -- The caller's own notebook for this class, newest first.
      if private.notebook_student(p_resource_id) is null then
        return jsonb_build_object('outcome', 'not_found');
      end if;
      select coalesce(jsonb_agg(private.notebook_entry_json(n.id)
          order by n.created_at desc, n.id desc), '[]'::jsonb)
        into v_items
      from (
        select n.id, n.created_at from public.notebook_entries n
        where n.owner_id = auth.uid() and n.classroom_id = p_resource_id
          and n.deleted_at is null
        order by n.created_at desc, n.id desc
        limit 200
      ) n;
      return jsonb_build_object('items', v_items, 'nextPosition', null);

    when 'getNotebookPhoto' then
      -- The cleaned copy of the caller's own whiteboard photo, for the API to
      -- hand to the model. Only once the scan has passed, only for the class
      -- it was taken for.
      if not exists (
        select 1 from public.file_objects f
        join public.file_bindings b on b.file_object_id = f.id
        join public.upload_sessions u on u.id = b.upload_session_id
        where f.id = p_resource_id and f.owner_id = auth.uid()
          and f.purpose = 'notebook_photo' and f.deleted_at is null
          and u.classroom_id = nullif(p_input->>'classroomId', '')::uuid
      ) then
        return jsonb_build_object('outcome', 'not_found');
      end if;
      return jsonb_build_object('outcome', 'ok',
        'object', private.file051_effective_object(p_resource_id));

    when 'getStudyLesson' then
      -- What the API needs to generate a set: only for a Max student who can
      -- see the lesson, and only its text.
      if private.study_plan(auth.uid()) <> 'max' then
        return jsonb_build_object('outcome', 'plan_required');
      end if;
      v_lesson := private.study_lesson(p_resource_id);
      if v_lesson is null then return jsonb_build_object('outcome', 'not_found'); end if;
      select s.id into v_id from public.study_sets s
      where s.resource_version_id = (v_lesson->>'versionId')::uuid
        and s.kind = p_input->>'kind' and s.withdrawn_at is null;
      return jsonb_build_object('outcome', 'ok', 'lesson', v_lesson,
        'existing', case when v_id is null then null else private.study_set_json(v_id) end);

    else
      return jsonb_build_object('outcome', 'invalid');
  end case;
exception when invalid_text_representation then
  return jsonb_build_object('outcome', 'not_found');
end;
$$;

-- ---------------------------------------------------------------------------
-- 5. Writes.
-- ---------------------------------------------------------------------------
create or replace function private.api046_command(
  p_operation text, p_resource_id uuid, p_input jsonb,
  p_idempotency_id uuid, p_idempotency_generation bigint)
returns jsonb language plpgsql security definer set search_path = '' as $$
declare
  body jsonb := p_input->'body';
  v_student uuid;
  v_school uuid;
  v_id uuid;
  v_photo uuid;
  v_lesson jsonb;
  response jsonb;
  request_id text := nullif(current_setting('studafy.request_id', true), '');
begin
  if auth.uid() is null or not private.is_active_user() then
    return jsonb_build_object('outcome', 'forbidden');
  end if;

  case p_operation
    when 'createNotebookEntry' then
      v_student := private.notebook_student(p_resource_id);
      if v_student is null then return jsonb_build_object('outcome', 'not_found'); end if;
      select c.school_id into v_school from public.classrooms c where c.id = p_resource_id;
      v_photo := nullif(body->>'photoFileId', '')::uuid;
      -- A photo must be the caller's own clean notebook photo for this class.
      if v_photo is not null and not exists (
        select 1 from public.file_objects f
        join public.file_bindings b on b.file_object_id = f.id
        join public.upload_sessions u on u.id = b.upload_session_id
        where f.id = v_photo and f.owner_id = auth.uid()
          and f.purpose = 'notebook_photo' and f.deleted_at is null
          and u.classroom_id = p_resource_id
      ) then
        return jsonb_build_object('outcome', 'invalid');
      end if;
      -- 'whiteboard' is set by the API after it has run the model; a client
      -- asking for it directly is refused by the route before reaching here.
      insert into public.notebook_entries(
        school_id, classroom_id, student_id, owner_id, title, body, source, photo_file_id)
      values (v_school, p_resource_id, v_student, auth.uid(),
        trim(body->>'title'), body->>'body',
        coalesce(body->>'source', 'typed'), v_photo)
      returning id into v_id;
      response := private.notebook_entry_json(v_id);
      insert into public.audit_events(school_id, actor_id, action, entity_type, entity_id, after_value, request_id)
      values (v_school, auth.uid(), 'notebook_entry_created', 'notebook_entry', v_id,
        -- That a note exists and where it came from - never what it says.
        jsonb_build_object('classroomId', p_resource_id, 'source', coalesce(body->>'source', 'typed')),
        request_id);

    when 'deleteNotebookEntry' then
      update public.notebook_entries n set deleted_at = now(), updated_at = now()
      where n.id = p_resource_id and n.owner_id = auth.uid() and n.deleted_at is null
      returning n.school_id into v_school;
      if v_school is null then return jsonb_build_object('outcome', 'not_found'); end if;
      response := jsonb_build_object('id', p_resource_id, 'deleted', true);

    when 'saveStudySet' then
      -- Called by the API after generating. The plan and the lesson are
      -- checked again here, so the route cannot be the only guard.
      if private.study_plan(auth.uid()) <> 'max' then
        return jsonb_build_object('outcome', 'plan_required');
      end if;
      v_lesson := private.study_lesson(p_resource_id);
      if v_lesson is null or (v_lesson->>'versionId') is distinct from body->>'versionId' then
        return jsonb_build_object('outcome', 'not_found');
      end if;
      insert into public.study_sets(school_id, classroom_id, resource_id,
        resource_version_id, kind, items, model, created_by)
      values ((v_lesson->>'schoolId')::uuid, (v_lesson->>'classroomId')::uuid,
        p_resource_id, (v_lesson->>'versionId')::uuid, body->>'kind',
        body->'items', left(body->>'model', 120), auth.uid())
      on conflict (resource_version_id, kind) do nothing
      returning id into v_id;
      if v_id is null then
        -- A classmate generated it first; theirs is the class's set.
        select s.id into v_id from public.study_sets s
        where s.resource_version_id = (v_lesson->>'versionId')::uuid
          and s.kind = body->>'kind';
      end if;
      response := private.study_set_json(v_id);

    else
      return jsonb_build_object('outcome', 'invalid');
  end case;

  if not private.api_idempotency_complete(
    p_idempotency_id, p_idempotency_generation, 201, response) then
    raise exception 'API046_IDEMPOTENCY_COMPLETION_FAILED';
  end if;
  return jsonb_build_object('outcome', 'ok', 'response', response);
exception when invalid_text_representation or check_violation then
  return jsonb_build_object('outcome', 'invalid');
end;
$$;

revoke all on function private.api046_query(text, uuid, jsonb)
  from public, anon, authenticated, service_role, studafy_worker_runtime;
revoke all on function private.api046_command(text, uuid, jsonb, uuid, bigint)
  from public, anon, authenticated, service_role, studafy_worker_runtime;
grant execute on function private.api046_query(text, uuid, jsonb) to studafy_api_runtime;
grant execute on function private.api046_command(text, uuid, jsonb, uuid, bigint)
  to studafy_api_runtime;
alter function private.api046_query(text, uuid, jsonb) owner to postgres;
alter function private.api046_command(text, uuid, jsonb, uuid, bigint) owner to postgres;

-- ---------------------------------------------------------------------------
-- 6. Decisions for the new actions.
-- ---------------------------------------------------------------------------
do $$ begin
  if not exists (
    select 1 from pg_proc p join pg_namespace n on n.oid = p.pronamespace
    where n.nspname = 'private' and p.proname = 'authz_authorize_pre_notebook'
  ) then
    alter function private.authz_authorize(text, uuid)
      rename to authz_authorize_pre_notebook;
  end if;
end $$;

create or replace function private.authz_authorize(
  p_action text, p_resource_id uuid)
returns jsonb language plpgsql stable security definer set search_path = '' as $$
declare
  sid uuid;
  allowed boolean := false;
begin
  if p_action not in ('notebook.read', 'notebook.write', 'notebook_entry.delete',
      'study_set.generate') then
    return private.authz_authorize_pre_notebook(p_action, p_resource_id);
  end if;
  if auth.uid() is null or p_resource_id is null then
    return jsonb_build_object('allowed', false, 'school_id', null, 'reason', 'invalid_resource');
  end if;
  if p_action in ('notebook.read', 'notebook.write') then
    select c.school_id, private.notebook_student(c.id) is not null
      into sid, allowed
    from public.classrooms c where c.id = p_resource_id;
  elsif p_action = 'notebook_entry.delete' then
    select n.school_id, n.owner_id = auth.uid() into sid, allowed
    from public.notebook_entries n
    where n.id = p_resource_id and n.deleted_at is null;
  else
    -- The plan is checked where the money is spent; this asks only whether
    -- the lesson is one the caller can see.
    select r.school_id, private.study_lesson(r.id) is not null into sid, allowed
    from public.resources r where r.id = p_resource_id;
  end if;
  return jsonb_build_object('allowed', coalesce(allowed, false), 'school_id', sid,
    'reason', case when sid is null then 'invalid_resource'
      when coalesce(allowed, false) then 'allowed' else 'denied' end);
end;
$$;

alter function private.authz_authorize(text, uuid) owner to postgres;
alter function private.authz_authorize_pre_notebook(text, uuid) owner to postgres;
revoke all on function private.authz_authorize_pre_notebook(text, uuid)
  from public, anon, authenticated, service_role, studafy_worker_runtime,
  studafy_api_runtime;
revoke all on function private.authz_authorize(text, uuid)
  from public, anon, authenticated, service_role, studafy_worker_runtime;
grant execute on function private.authz_authorize(text, uuid) to studafy_api_runtime;
