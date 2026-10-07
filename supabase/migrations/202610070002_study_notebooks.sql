-- Study notebooks (2026-10-07).
--
-- A student makes a notebook from one lesson - all of it, or chosen files
-- and links - and the AI writes it in a fixed structure. The notebook is
-- the student's alone: their notes, highlights, bookmarks and own sections
-- live beside the AI part and survive every regeneration. A fingerprint of
-- the material it was made from says when the lesson has changed since.
-- Quizzes and flashcards made from a notebook are kept per notebook
-- version, so reopening one costs nothing.
--
-- Everything goes through private.api055_study_notebooks, which re-checks
-- on every call that the caller owns the notebook and can still see the
-- lesson; the tables have RLS on and no policies.

create table if not exists public.study_notebooks (
  id uuid primary key default gen_random_uuid(),
  school_id uuid not null references public.schools(id) on delete cascade,
  owner_id uuid not null references public.profiles(id) on delete cascade,
  classroom_id uuid not null,
  resource_id uuid not null references public.resources(id) on delete cascade,
  -- The lesson's files and links it reads; empty means the whole lesson.
  source_ids uuid[] not null default '{}',
  title text not null check (char_length(btrim(title)) between 1 and 120),
  subtitle text check (char_length(subtitle) <= 160),
  color text not null default 'navy' check (color in
    ('navy', 'teal', 'coral', 'violet', 'amber', 'green', 'rose', 'slate')),
  icon text check (icon in ('book', 'science', 'math', 'language', 'globe',
    'history', 'art', 'music', 'code', 'star')),
  page_style text not null default 'lined'
    check (page_style in ('lined', 'plain', 'grid')),
  headings jsonb not null default '[]'::jsonb
    check (jsonb_typeof(headings) = 'array' and jsonb_array_length(headings) <= 40),
  status text not null default 'creating'
    check (status in ('creating', 'ready', 'failed')),
  failure text check (failure ~ '^[a-z_]{1,60}$'),
  content jsonb check (content is null or jsonb_typeof(content) = 'object'),
  unreadable jsonb not null default '[]'::jsonb,
  -- Bumped by each successful generation; quizzes made before it are
  -- outdated.
  content_version integer not null default 0 check (content_version >= 0),
  -- Bumped by each request to (re)generate: a late answer to an earlier
  -- request is ignored.
  generation integer not null default 1 check (generation >= 1),
  generation_started_at timestamptz not null default now(),
  source_fingerprint text,
  generated_at timestamptz,
  model text check (char_length(model) <= 120),
  personal jsonb not null default
    '{"notes":[],"sections":[],"bookmarks":[],"highlights":[]}'::jsonb,
  personal_version integer not null default 1 check (personal_version >= 1),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  deleted_at timestamptz,
  foreign key (school_id, classroom_id)
    references public.classrooms(school_id, id) on delete cascade
);
create index if not exists study_notebooks_owner_class_idx
  on public.study_notebooks (owner_id, classroom_id) where deleted_at is null;
create index if not exists study_notebooks_owner_resource_idx
  on public.study_notebooks (owner_id, resource_id) where deleted_at is null;

create table if not exists public.study_notebook_sets (
  id uuid primary key default gen_random_uuid(),
  notebook_id uuid not null references public.study_notebooks(id) on delete cascade,
  owner_id uuid not null references public.profiles(id) on delete cascade,
  kind text not null check (kind in ('quiz', 'flashcards')),
  section_keys text[] not null default '{}',
  content_version integer not null,
  items jsonb not null check (jsonb_typeof(items) = 'array'
    and jsonb_array_length(items) between 1 and 30),
  model text not null check (char_length(model) <= 120),
  created_at timestamptz not null default now(),
  unique (notebook_id, kind, section_keys, content_version)
);

alter table public.study_notebooks enable row level security;
alter table public.study_notebook_sets enable row level security;
revoke all on public.study_notebooks, public.study_notebook_sets
  from public, anon, authenticated, service_role, studafy_api_runtime,
  studafy_worker_runtime;

-- What the material of a lesson version looks like now, for the sources a
-- notebook reads: when this changes, the notebook can be updated.
create or replace function private.notebook_fingerprint(p_version uuid, p_sources uuid[])
returns text language sql stable security definer set search_path = '' as $$
  select md5(p_version::text || coalesce(string_agg(
    s.source_id::text || ':' || s.state || ':' ||
      coalesce((select d.processed_at::text from private.ai_material_docs d
        where d.id = s.doc_id), ''), ',' order by s.source_id), ''))
  from private.ai_version_sources(p_version) s
  where cardinality(coalesce(p_sources, '{}')) = 0 or s.source_id = any(p_sources);
$$;

-- A notebook as a list row. Its lesson is looked at as the student sees it
-- now: a lesson withdrawn since leaves the notebook, without updates.
create or replace function private.notebook_summary_json(n public.study_notebooks)
returns jsonb language plpgsql stable security definer set search_path = '' as $$
declare
  v_lesson jsonb := private.study_lesson(n.resource_id);
  v_title text;
  v_failure text := n.failure;
  v_status text := n.status;
begin
  select r.title into v_title from public.resources r where r.id = n.resource_id;
  -- A generation that never came back counts as failed after ten minutes.
  if v_status = 'creating' and n.generation_started_at < now() - interval '10 minutes' then
    v_status := 'failed';
    v_failure := 'timed_out';
  end if;
  return jsonb_build_object(
    'id', n.id, 'classroomId', n.classroom_id, 'resourceId', n.resource_id,
    'lessonTitle', coalesce(v_title, ''), 'title', n.title, 'subtitle', n.subtitle,
    'color', n.color, 'icon', n.icon, 'pageStyle', n.page_style,
    'status', v_status, 'failure', v_failure,
    'updateAvailable', v_status = 'ready' and v_lesson is not null
      and n.source_fingerprint is distinct from private.notebook_fingerprint(
        (v_lesson->>'versionId')::uuid, n.source_ids),
    'contentVersion', n.content_version,
    'sourceCount', cardinality(n.source_ids),
    'createdAt', n.created_at, 'updatedAt', n.updated_at);
end;
$$;

create or replace function private.notebook_json(n public.study_notebooks)
returns jsonb language plpgsql stable security definer set search_path = '' as $$
declare
  v_lesson jsonb := private.study_lesson(n.resource_id);
begin
  return jsonb_build_object(
    'summary', private.notebook_summary_json(n),
    'className', coalesce((select c.name from public.classrooms c where c.id = n.classroom_id), ''),
    'content', n.content,
    'unreadable', n.unreadable,
    'headings', n.headings,
    'personal', n.personal,
    'personalVersion', n.personal_version,
    'sources', case when v_lesson is null then '[]'::jsonb else coalesce((
      select jsonb_agg(jsonb_build_object('id', s->>'id', 'kind', s->>'kind',
        'name', s->>'name', 'state', s->>'state', 'reason', s->'reason',
        'chosen', cardinality(n.source_ids) = 0 or (s->>'id')::uuid = any(n.source_ids)))
      from jsonb_array_elements(private.ai_sources_json((v_lesson->>'versionId')::uuid)) s),
      '[]'::jsonb) end,
    -- The newest forty: older ones are still reopened by asking again.
    'sets', coalesce((
      select jsonb_agg(jsonb_build_object('id', t.id, 'kind', t.kind,
        'sectionKeys', to_jsonb(t.section_keys), 'count', jsonb_array_length(t.items),
        'outdated', t.content_version < n.content_version, 'createdAt', t.created_at)
        order by t.created_at desc)
      from (select * from public.study_notebook_sets s where s.notebook_id = n.id
        order by s.created_at desc limit 40) t), '[]'::jsonb),
    'generatedAt', n.generated_at);
end;
$$;

-- What the API needs to (re)generate a notebook: the lesson as the student
-- sees it now, and the sources still part of it.
create or replace function private.notebook_start_json(n public.study_notebooks)
returns jsonb language plpgsql stable security definer set search_path = '' as $$
declare
  v_lesson jsonb := private.study_lesson(n.resource_id);
begin
  if v_lesson is null then return jsonb_build_object('outcome', 'not_found'); end if;
  return jsonb_build_object('outcome', 'ok', 'notebookId', n.id,
    'generation', n.generation, 'resourceId', n.resource_id,
    'lessonTitle', v_lesson->>'title', 'sourceIds', to_jsonb(n.source_ids),
    'summary', private.notebook_summary_json(n));
end;
$$;

create or replace function private.notebook_personal_ok(p jsonb)
returns boolean language sql immutable set search_path = '' as $$
  select jsonb_typeof(p) = 'object'
    and jsonb_typeof(p->'notes') = 'array' and jsonb_array_length(p->'notes') <= 200
    and jsonb_typeof(p->'sections') = 'array' and jsonb_array_length(p->'sections') <= 40
    and jsonb_typeof(p->'bookmarks') = 'array' and jsonb_array_length(p->'bookmarks') <= 60
    and jsonb_typeof(p->'highlights') = 'array' and jsonb_array_length(p->'highlights') <= 400
    and octet_length(p::text) <= 400000;
$$;

create or replace function private.api055_study_notebooks(p_operation text, p_input jsonb)
returns jsonb language plpgsql security definer set search_path = '' as $$
declare
  v_user uuid := auth.uid();
  n public.study_notebooks%rowtype;
  v_lesson jsonb;
  v_sources uuid[];
  v_version uuid;
  v_class uuid;
  v_keys text[];
  v_set public.study_notebook_sets%rowtype;
begin
  if v_user is null or not private.is_active_user() then
    return jsonb_build_object('outcome', 'forbidden');
  end if;

  if p_operation in ('get', 'start', 'finish', 'fail', 'regenerate', 'settings',
      'personal', 'delete', 'set', 'saveSet') then
    select * into n from public.study_notebooks x
    where x.id = (p_input->>'id')::uuid and x.owner_id = v_user and x.deleted_at is null
    for update;
    if n.id is null then return jsonb_build_object('outcome', 'not_found'); end if;
  end if;

  case p_operation
    when 'list' then
      v_class := (p_input->>'classroomId')::uuid;
      return jsonb_build_object('outcome', 'ok', 'items', coalesce((
        select jsonb_agg(private.notebook_summary_json(x) order by x.updated_at desc)
        from public.study_notebooks x
        where x.owner_id = v_user and x.classroom_id = v_class and x.deleted_at is null),
        '[]'::jsonb));

    when 'create' then
      if private.study_plan(v_user) not in ('plus', 'max') then
        return jsonb_build_object('outcome', 'plan_required');
      end if;
      v_lesson := private.study_lesson((p_input->>'resourceId')::uuid);
      if v_lesson is null or (v_lesson->>'classroomId') is distinct from p_input->>'classroomId' then
        return jsonb_build_object('outcome', 'not_found');
      end if;
      v_version := (v_lesson->>'versionId')::uuid;
      select coalesce(array_agg(distinct (e.value #>> '{}')::uuid), '{}') into v_sources
      from jsonb_array_elements(coalesce(p_input->'sourceIds', '[]'::jsonb)) e;
      -- Only the lesson's own sources, and only ones read already.
      if exists (select 1 from unnest(v_sources) c(id)
          where not exists (select 1 from private.ai_version_sources(v_version) s
            where s.source_id = c.id)) then
        return jsonb_build_object('outcome', 'invalid');
      end if;
      if exists (select 1 from private.ai_version_sources(v_version) s
          where (cardinality(v_sources) = 0 or s.source_id = any(v_sources))
            and s.state in ('pending', 'processing')) then
        return jsonb_build_object('outcome', 'material_processing');
      end if;
      -- At most three being written at once, so a stuck tap cannot queue
      -- dozens.
      if (select count(*) from public.study_notebooks x where x.owner_id = v_user
          and x.status = 'creating' and x.deleted_at is null
          and x.generation_started_at > now() - interval '10 minutes') >= 3 then
        return jsonb_build_object('outcome', 'in_progress');
      end if;
      insert into public.study_notebooks (school_id, owner_id, classroom_id,
        resource_id, source_ids, title)
      values ((v_lesson->>'schoolId')::uuid, v_user, (v_lesson->>'classroomId')::uuid,
        (p_input->>'resourceId')::uuid, v_sources,
        left(coalesce(nullif(btrim(p_input->>'title'), ''), v_lesson->>'title', 'Notebook'), 120))
      returning * into n;
      return private.notebook_start_json(n);

    when 'start' then
      return private.notebook_start_json(n);

    when 'regenerate' then
      if n.status = 'creating' and n.generation_started_at > now() - interval '10 minutes' then
        return jsonb_build_object('outcome', 'in_progress');
      end if;
      if private.study_plan(v_user) not in ('plus', 'max') then
        return jsonb_build_object('outcome', 'plan_required');
      end if;
      v_lesson := private.study_lesson(n.resource_id);
      if v_lesson is null then return jsonb_build_object('outcome', 'not_found'); end if;
      v_sources := n.source_ids;
      if p_input ? 'sourceIds' then
        select coalesce(array_agg(distinct (e.value #>> '{}')::uuid), '{}') into v_sources
        from jsonb_array_elements(coalesce(p_input->'sourceIds', '[]'::jsonb)) e;
      end if;
      update public.study_notebooks set status = 'creating', failure = null,
        source_ids = v_sources, generation = generation + 1,
        generation_started_at = now(), updated_at = now()
      where id = n.id returning * into n;
      return private.notebook_start_json(n);

    when 'finish' then
      -- A late answer to an earlier request changes nothing.
      if (p_input->>'generation')::int <> n.generation or n.status <> 'creating' then
        return jsonb_build_object('outcome', 'stale');
      end if;
      v_lesson := private.study_lesson(n.resource_id);
      update public.study_notebooks set status = 'ready', failure = null,
        content = p_input->'content',
        unreadable = coalesce(p_input->'unreadable', '[]'::jsonb),
        content_version = content_version + 1,
        source_fingerprint = case when v_lesson is null then null
          else private.notebook_fingerprint((v_lesson->>'versionId')::uuid, n.source_ids) end,
        generated_at = now(), model = left(p_input->>'model', 120), updated_at = now()
      where id = n.id returning * into n;
      return jsonb_build_object('outcome', 'ok', 'summary', private.notebook_summary_json(n));

    when 'fail' then
      if (p_input->>'generation')::int <> n.generation or n.status <> 'creating' then
        return jsonb_build_object('outcome', 'stale');
      end if;
      update public.study_notebooks set status = 'failed',
        failure = left(coalesce(p_input->>'reason', 'generation_failed'), 60),
        updated_at = now()
      where id = n.id;
      return jsonb_build_object('outcome', 'ok');

    when 'get' then
      return jsonb_build_object('outcome', 'ok', 'notebook', private.notebook_json(n));

    when 'settings' then
      update public.study_notebooks set
        title = left(btrim(p_input->>'title'), 120),
        subtitle = nullif(left(btrim(coalesce(p_input->>'subtitle', '')), 160), ''),
        color = p_input->>'color', icon = p_input->>'icon',
        page_style = p_input->>'pageStyle',
        headings = coalesce(p_input->'headings', '[]'::jsonb),
        updated_at = now()
      where id = n.id returning * into n;
      return jsonb_build_object('outcome', 'ok', 'summary', private.notebook_summary_json(n));

    when 'personal' then
      if (p_input->>'expectedVersion')::int <> n.personal_version then
        return jsonb_build_object('outcome', 'version_conflict',
          'notebook', private.notebook_json(n));
      end if;
      if not private.notebook_personal_ok(p_input->'personal') then
        return jsonb_build_object('outcome', 'invalid');
      end if;
      update public.study_notebooks set personal = p_input->'personal',
        personal_version = personal_version + 1, updated_at = now()
      where id = n.id returning * into n;
      return jsonb_build_object('outcome', 'ok', 'notebook', private.notebook_json(n));

    when 'delete' then
      update public.study_notebooks set deleted_at = now(), updated_at = now() where id = n.id;
      return jsonb_build_object('outcome', 'ok', 'deleted', true);

    -- A quiz or flashcards from the notebook: the one already made for this
    -- version and these sections, or what is needed to make it.
    when 'set' then
      if private.study_plan(v_user) <> 'max' then
        return jsonb_build_object('outcome', 'plan_required');
      end if;
      if n.status <> 'ready' or n.content is null then
        return jsonb_build_object('outcome', 'invalid_state');
      end if;
      select coalesce(array_agg(k order by k), '{}') into v_keys
      from (select distinct e.value #>> '{}' as k
        from jsonb_array_elements(coalesce(p_input->'sectionKeys', '[]'::jsonb)) e) x;
      select * into v_set from public.study_notebook_sets t
      where t.notebook_id = n.id and t.kind = p_input->>'kind'
        and t.section_keys = v_keys and t.content_version = n.content_version;
      return jsonb_build_object('outcome', 'ok', 'sectionKeys', to_jsonb(v_keys),
        'contentVersion', n.content_version, 'title', n.title,
        'existing', case when v_set.id is null then null else jsonb_build_object(
          'id', v_set.id, 'notebookId', n.id, 'kind', v_set.kind,
          'sectionKeys', to_jsonb(v_set.section_keys), 'outdated', false,
          'items', v_set.items, 'createdAt', v_set.created_at) end,
        'content', case when v_set.id is null then n.content else null end);

    when 'saveSet' then
      if private.study_plan(v_user) <> 'max' then
        return jsonb_build_object('outcome', 'plan_required');
      end if;
      select coalesce(array_agg(k order by k), '{}') into v_keys
      from (select distinct e.value #>> '{}' as k
        from jsonb_array_elements(coalesce(p_input->'sectionKeys', '[]'::jsonb)) e) x;
      insert into public.study_notebook_sets (notebook_id, owner_id, kind,
        section_keys, content_version, items, model)
      values (n.id, v_user, p_input->>'kind', v_keys,
        (p_input->>'contentVersion')::int, p_input->'items', left(p_input->>'model', 120))
      on conflict (notebook_id, kind, section_keys, content_version) do nothing
      returning * into v_set;
      if v_set.id is null then
        select * into v_set from public.study_notebook_sets t
        where t.notebook_id = n.id and t.kind = p_input->>'kind'
          and t.section_keys = v_keys
          and t.content_version = (p_input->>'contentVersion')::int;
      end if;
      return jsonb_build_object('outcome', 'ok', 'set', jsonb_build_object(
        'id', v_set.id, 'notebookId', n.id, 'kind', v_set.kind,
        'sectionKeys', to_jsonb(v_set.section_keys),
        'outdated', v_set.content_version < n.content_version,
        'items', v_set.items, 'createdAt', v_set.created_at));

    else
      return jsonb_build_object('outcome', 'invalid');
  end case;
exception
  when invalid_text_representation or check_violation or not_null_violation then
    return jsonb_build_object('outcome', 'invalid');
end;
$$;

do $$
declare
  fn text;
begin
  foreach fn in array array[
    'private.notebook_fingerprint(uuid, uuid[])',
    'private.notebook_summary_json(public.study_notebooks)',
    'private.notebook_json(public.study_notebooks)',
    'private.notebook_start_json(public.study_notebooks)',
    'private.notebook_personal_ok(jsonb)',
    'private.api055_study_notebooks(text, jsonb)']
  loop
    execute format('revoke all on function %s from public, anon, authenticated, '
      'service_role, studafy_api_runtime, studafy_worker_runtime', fn);
    execute format('alter function %s owner to postgres', fn);
  end loop;
end $$;

grant execute on function private.api055_study_notebooks(text, jsonb) to studafy_api_runtime;
