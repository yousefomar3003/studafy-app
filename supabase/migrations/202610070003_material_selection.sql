-- Exactly the chosen material (2026-10-07, ADR-0039).
--
-- Every AI study tool now takes an explicit selection: whole lessons, a
-- lesson's own text, or particular files and links. Two things follow in
-- the database:
--
-- * a notebook made from chosen files records whether the lesson's own
--   text is part of it (before, choosing files always left the text out);
-- * a quiz, flashcards or notes made from one exact selection are kept
--   against a fingerprint of it - lesson versions and the files chosen -
--   so the same selection opens again for free, for any student who can
--   see every lesson in it. Access is re-checked on each read.

alter table public.study_notebooks
  add column if not exists include_text boolean not null default true,
  -- Every file and link on the lesson, those added later included. When
  -- false, exactly [source_ids] - none at all for the lesson's text alone.
  add column if not exists whole_lesson boolean not null default true;
-- Notebooks made before kept their choice as source ids, empty for whole.
update public.study_notebooks set whole_lesson = cardinality(source_ids) = 0;

-- What the chosen material of a lesson version looks like now: all of its
-- files and links for a whole lesson, exactly the chosen ones otherwise
-- (none, for its text alone).
create or replace function private.notebook_fingerprint(p_version uuid, p_sources uuid[], p_whole boolean)
returns text language sql stable security definer set search_path = '' as $$
  select md5(p_version::text || coalesce(string_agg(
    s.source_id::text || ':' || s.state || ':' ||
      coalesce((select d.processed_at::text from private.ai_material_docs d
        where d.id = s.doc_id), ''), ',' order by s.source_id), ''))
  from private.ai_version_sources(p_version) s
  where p_whole or s.source_id = any(coalesce(p_sources, '{}'));
$$;

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
        (v_lesson->>'versionId')::uuid, n.source_ids, n.whole_lesson),
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
        'chosen', n.whole_lesson or (s->>'id')::uuid = any(n.source_ids)))
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
    'generatedAt', n.generated_at,
    'includeText', n.include_text,
    'wholeLesson', n.whole_lesson);
end;
$$;


create or replace function private.notebook_start_json(n public.study_notebooks)
returns jsonb language plpgsql stable security definer set search_path = '' as $$
declare
  v_lesson jsonb := private.study_lesson(n.resource_id);
begin
  if v_lesson is null then return jsonb_build_object('outcome', 'not_found'); end if;
  return jsonb_build_object('outcome', 'ok', 'notebookId', n.id,
    'generation', n.generation, 'resourceId', n.resource_id,
    'lessonTitle', v_lesson->>'title', 'sourceIds', to_jsonb(n.source_ids),
    'includeText', n.include_text, 'wholeLesson', n.whole_lesson,
    'summary', private.notebook_summary_json(n));
end;
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
  v_whole boolean;
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
      -- Older apps send no flag: no files named meant the whole lesson.
      v_whole := coalesce((p_input->>'wholeLesson')::boolean, cardinality(v_sources) = 0);
      -- Only the lesson's own sources, and only ones read already.
      if exists (select 1 from unnest(v_sources) c(id)
          where not exists (select 1 from private.ai_version_sources(v_version) s
            where s.source_id = c.id)) then
        return jsonb_build_object('outcome', 'invalid');
      end if;
      if exists (select 1 from private.ai_version_sources(v_version) s
          where (v_whole or s.source_id = any(v_sources))
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
      -- Only the files chosen can leave out the lesson's text; the whole
      -- lesson always has it, and a notebook of nothing is refused.
      if not v_whole and cardinality(v_sources) = 0
          and not coalesce((p_input->>'includeText')::boolean, true) then
        return jsonb_build_object('outcome', 'invalid');
      end if;
      insert into public.study_notebooks (school_id, owner_id, classroom_id,
        resource_id, source_ids, whole_lesson, include_text, title)
      values ((v_lesson->>'schoolId')::uuid, v_user, (v_lesson->>'classroomId')::uuid,
        (p_input->>'resourceId')::uuid, case when v_whole then '{}' else v_sources end, v_whole,
        v_whole or coalesce((p_input->>'includeText')::boolean, true),
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
      v_whole := n.whole_lesson;
      if p_input ? 'sourceIds' then
        select coalesce(array_agg(distinct (e.value #>> '{}')::uuid), '{}') into v_sources
        from jsonb_array_elements(coalesce(p_input->'sourceIds', '[]'::jsonb)) e;
        v_whole := coalesce((p_input->>'wholeLesson')::boolean, cardinality(v_sources) = 0);
      end if;
      update public.study_notebooks set status = 'creating', failure = null,
        source_ids = case when v_whole then '{}' else v_sources end,
        whole_lesson = v_whole,
        include_text = v_whole
          or coalesce((p_input->>'includeText')::boolean, include_text),
        generation = generation + 1,
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
          else private.notebook_fingerprint((v_lesson->>'versionId')::uuid, n.source_ids, n.whole_lesson) end,
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


create table if not exists private.material_outputs (
  id uuid primary key default gen_random_uuid(),
  fingerprint text not null check (fingerprint ~ '^[0-9a-f]{64}$'),
  kind text not null check (kind in ('quiz', 'flashcards', 'summary')),
  -- The lessons it was made from: a student must see all of them to use it.
  resource_ids uuid[] not null check (cardinality(resource_ids) between 1 and 10),
  items jsonb check (items is null or (jsonb_typeof(items) = 'array'
    and jsonb_array_length(items) between 1 and 30)),
  body text check (char_length(body) <= 20000),
  scope jsonb not null check (jsonb_typeof(scope) = 'object'),
  model text not null check (char_length(model) <= 120),
  created_at timestamptz not null default now(),
  unique (fingerprint, kind),
  check ((kind = 'summary') = (body is not null and items is null))
);
alter table private.material_outputs enable row level security;
revoke all on private.material_outputs from public, anon, authenticated,
  service_role, studafy_api_runtime, studafy_worker_runtime;

create or replace function private.material_output_json(o private.material_outputs)
returns jsonb language sql stable set search_path = '' as $$
  select jsonb_build_object('id', o.id, 'kind', o.kind, 'items', o.items,
    'body', o.body, 'scope', o.scope, 'model', o.model, 'createdAt', o.created_at);
$$;

-- 'get' a kept result for a fingerprint, or 'put' one just made. Both need
-- the plan the result belongs to, and every lesson in it visible to the
-- caller now.
create or replace function private.api056_material_outputs(p_operation text, p_input jsonb)
returns jsonb language plpgsql security definer set search_path = '' as $$
declare
  v_user uuid := auth.uid();
  v_kind text := p_input->>'kind';
  v_plan text;
  v_ids uuid[];
  v_out private.material_outputs%rowtype;
begin
  if v_user is null or not private.is_active_user() then
    return jsonb_build_object('outcome', 'forbidden');
  end if;
  v_plan := private.study_plan(v_user);
  if v_kind in ('quiz', 'flashcards') and v_plan <> 'max' then
    return jsonb_build_object('outcome', 'plan_required');
  elsif v_kind = 'summary' and v_plan not in ('plus', 'max') then
    return jsonb_build_object('outcome', 'plan_required');
  elsif v_kind is null or v_kind not in ('quiz', 'flashcards', 'summary') then
    return jsonb_build_object('outcome', 'invalid');
  end if;

  select coalesce(array_agg(distinct (e.value #>> '{}')::uuid), '{}') into v_ids
  from jsonb_array_elements(coalesce(p_input->'resourceIds', '[]'::jsonb)) e;
  if cardinality(v_ids) = 0 or exists (select 1 from unnest(v_ids) r(id)
      where private.study_lesson(r.id) is null) then
    return jsonb_build_object('outcome', 'not_found');
  end if;

  case p_operation
    when 'get' then
      select * into v_out from private.material_outputs o
      where o.fingerprint = p_input->>'fingerprint' and o.kind = v_kind
        and o.resource_ids <@ v_ids and v_ids <@ o.resource_ids;
      return jsonb_build_object('outcome', 'ok', 'output',
        case when v_out.id is null then null else private.material_output_json(v_out) end);
    when 'put' then
      insert into private.material_outputs (fingerprint, kind, resource_ids,
        items, body, scope, model)
      values (p_input->>'fingerprint', v_kind, v_ids,
        case when v_kind = 'summary' then null else p_input->'items' end,
        case when v_kind = 'summary' then left(p_input->>'body', 20000) else null end,
        p_input->'scope', left(coalesce(p_input->>'model', 'unknown'), 120))
      on conflict (fingerprint, kind) do nothing
      returning * into v_out;
      if v_out.id is null then
        select * into v_out from private.material_outputs o
        where o.fingerprint = p_input->>'fingerprint' and o.kind = v_kind;
      end if;
      return jsonb_build_object('outcome', 'ok', 'output', private.material_output_json(v_out));
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
    'private.notebook_fingerprint(uuid, uuid[], boolean)',
    'private.notebook_summary_json(public.study_notebooks)',
    'private.notebook_json(public.study_notebooks)',
    'private.notebook_start_json(public.study_notebooks)',
    'private.api055_study_notebooks(text, jsonb)',
    'private.material_output_json(private.material_outputs)',
    'private.api056_material_outputs(text, jsonb)']
  loop
    execute format('revoke all on function %s from public, anon, authenticated, '
      'service_role, studafy_api_runtime, studafy_worker_runtime', fn);
    execute format('alter function %s owner to postgres', fn);
  end loop;
end $$;

grant execute on function private.api055_study_notebooks(text, jsonb) to studafy_api_runtime;
grant execute on function private.api056_material_outputs(text, jsonb) to studafy_api_runtime;
