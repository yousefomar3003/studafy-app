-- Grounded study AI and token allowances (ADR-0037, 2026-10-07).
--
--   1. Word and PowerPoint files may be attached to lessons and assignments.
--   2. Every clean lesson file, and every link on a lesson, is read once in
--      the background - text extracted, scanned pages and images read by
--      the model - and split into passages a question can be matched
--      against. Each has a visible state: processing, ready, unsupported or
--      failed. That reading is paid from a per-school monthly budget, never
--      from a student's allowance.
--   3. A student's question is answered from the passages of lessons they
--      can see right now - checked here, on every request, through the same
--      publication rule as the lesson itself. Exam papers, answer keys,
--      grades, submissions and anyone else's notes are never indexed or
--      never reachable: only lesson files and lesson links are read.
--   4. The AI allowance is counted in tokens instead of questions. Free has
--      40,000 a week; Studafy Plus 3,000,000 and Max 6,000,000 a month. The
--      dollar caps stay underneath as a backstop.

-- ---------------------------------------------------------------------------
-- 1. Word and PowerPoint uploads.
-- ---------------------------------------------------------------------------
update public.file_purpose_policies
set allowed_media_types = array[
      'application/pdf', 'image/jpeg', 'image/png',
      'application/vnd.openxmlformats-officedocument.wordprocessingml.document',
      'application/vnd.openxmlformats-officedocument.presentationml.presentation'],
    updated_at = now()
where purpose in ('lesson_resource', 'assignment_material');

-- ---------------------------------------------------------------------------
-- 2. The material index.
-- ---------------------------------------------------------------------------

-- What the background reading may spend, in one place.
create or replace function private.ai_material_limits()
returns jsonb language sql immutable set search_path = '' as $$
  select jsonb_build_object(
    -- Pages of one file read by the model (scanned pages, images).
    'ocrPagesPerFile', 60,
    -- Pages a school's files may have read by the model each month.
    'ocrPagesPerSchoolMonth', 3000,
    -- Pages of one PDF whose text is extracted at all.
    'textPagesPerFile', 500,
    -- Characters kept from one file or link.
    'charsPerDocument', 600000,
    -- Bytes fetched from one link.
    'linkMaxBytes', 3000000,
    -- Attempts before a file is marked failed.
    'maxAttempts', 3);
$$;

create table if not exists private.ai_material_docs (
  id uuid primary key default gen_random_uuid(),
  school_id uuid not null references public.schools(id) on delete cascade,
  file_object_id uuid unique references public.file_objects(id) on delete cascade,
  content_link_id uuid unique references public.content_links(id) on delete cascade,
  state text not null default 'pending'
    check (state in ('pending', 'processing', 'ready', 'unsupported', 'failed')),
  -- Why it is unsupported or failed, as a code the app words.
  reason text check (reason ~ '^[a-z_]{1,60}$'),
  -- Pages read, pages read by the model, pages skipped, characters kept.
  detail jsonb not null default '{}'::jsonb,
  attempts integer not null default 0 check (attempts >= 0),
  next_attempt_at timestamptz not null default now(),
  lease_until timestamptz,
  worker_id text,
  extractor text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  processed_at timestamptz,
  check (num_nonnulls(file_object_id, content_link_id) = 1)
);
create index if not exists ai_material_docs_queue_idx
  on private.ai_material_docs (next_attempt_at)
  where state in ('pending', 'processing');

-- Passages. Searchable as plain words, and stemmed for Arabic and English,
-- so "الخلايا" finds "خلية" and "cells" finds "cell".
create table if not exists private.ai_material_chunks (
  id bigint generated always as identity primary key,
  doc_id uuid not null references private.ai_material_docs(id) on delete cascade,
  ordinal integer not null check (ordinal >= 0),
  page integer check (page > 0),
  slide integer check (slide > 0),
  heading text check (length(heading) <= 300),
  body text not null check (length(body) between 1 and 6000),
  tsv tsvector generated always as (
    to_tsvector('simple'::regconfig, coalesce(heading, '') || ' ' || body)
    || to_tsvector('arabic'::regconfig, coalesce(heading, '') || ' ' || body)
    || to_tsvector('english'::regconfig, coalesce(heading, '') || ' ' || body)
  ) stored,
  unique (doc_id, ordinal)
);
create index if not exists ai_material_chunks_tsv_idx
  on private.ai_material_chunks using gin (tsv);
create index if not exists ai_material_chunks_page_idx
  on private.ai_material_chunks (doc_id, page);

-- What the background reading cost, kept apart from students' allowances.
create table if not exists private.ai_processing_usage (
  id bigint generated always as identity primary key,
  school_id uuid not null references public.schools(id) on delete cascade,
  doc_id uuid references private.ai_material_docs(id) on delete set null,
  kind text not null check (kind in ('ocr', 'image', 'link')),
  pages integer not null default 0 check (pages >= 0),
  input_tokens integer check (input_tokens >= 0),
  output_tokens integer check (output_tokens >= 0),
  cost_micro_usd bigint not null default 0 check (cost_micro_usd >= 0),
  model text check (length(model) <= 120),
  month date not null,
  created_at timestamptz not null default now()
);
create index if not exists ai_processing_usage_school_month_idx
  on private.ai_processing_usage (school_id, month);

revoke all on private.ai_material_docs, private.ai_material_chunks,
  private.ai_processing_usage
  from public, anon, authenticated, service_role, studafy_api_runtime,
  studafy_worker_runtime;

-- The media types read, by purpose: lesson files only.
create or replace function private.ai_material_readable_type(p_media text)
returns boolean language sql immutable set search_path = '' as $$
  select p_media in ('application/pdf', 'image/jpeg', 'image/png',
    'application/vnd.openxmlformats-officedocument.wordprocessingml.document',
    'application/vnd.openxmlformats-officedocument.presentationml.presentation');
$$;

-- Queue a lesson file once its scan has cleared it; forget it when deleted.
create or replace function private.ai_material_on_file()
returns trigger language plpgsql security definer set search_path = '' as $$
begin
  if new.deleted_at is not null or new.physical_deleted_at is not null then
    delete from private.ai_material_docs d where d.file_object_id = new.id;
    return new;
  end if;
  if new.scan_state = 'clean' and new.purpose = 'lesson_resource'
     and private.ai_material_readable_type(
       coalesce(new.detected_media_type, new.declared_media_type)) then
    insert into private.ai_material_docs(school_id, file_object_id)
    values (new.school_id, new.id)
    on conflict (file_object_id) do nothing;
  end if;
  return new;
end;
$$;

drop trigger if exists ai_material_on_file on public.file_objects;
create trigger ai_material_on_file
  after insert or update of scan_state, deleted_at, physical_deleted_at
  on public.file_objects
  for each row execute function private.ai_material_on_file();

-- Queue a link on a lesson. A lesson edit carries its links to the new
-- version as new rows: the same address read recently is copied, not
-- fetched again.
create or replace function private.ai_material_on_link()
returns trigger language plpgsql security definer set search_path = '' as $$
declare
  v_doc uuid;
  v_source private.ai_material_docs%rowtype;
begin
  if new.resource_version_id is null or new.role <> 'material'
     or new.detached_at is not null then
    return new;
  end if;
  select d.* into v_source
  from private.ai_material_docs d
  join public.content_links l on l.id = d.content_link_id
  where l.school_id = new.school_id and l.url = new.url and d.state = 'ready'
    and d.processed_at > now() - interval '7 days'
  order by d.processed_at desc limit 1;
  if v_source.id is null then
    insert into private.ai_material_docs(school_id, content_link_id)
    values (new.school_id, new.id)
    on conflict (content_link_id) do nothing;
    return new;
  end if;
  insert into private.ai_material_docs(school_id, content_link_id, state,
    reason, detail, extractor, processed_at)
  values (new.school_id, new.id, 'ready', null, v_source.detail,
    v_source.extractor, v_source.processed_at)
  on conflict (content_link_id) do nothing
  returning id into v_doc;
  if v_doc is not null then
    insert into private.ai_material_chunks(doc_id, ordinal, page, slide, heading, body)
    select v_doc, c.ordinal, c.page, c.slide, c.heading, c.body
    from private.ai_material_chunks c where c.doc_id = v_source.id;
  end if;
  return new;
end;
$$;

drop trigger if exists ai_material_on_link on public.content_links;
create trigger ai_material_on_link
  after insert on public.content_links
  for each row execute function private.ai_material_on_link();

-- Files and links already on lessons are read too.
insert into private.ai_material_docs(school_id, file_object_id)
select f.school_id, f.id from public.file_objects f
where f.scan_state = 'clean' and f.purpose = 'lesson_resource'
  and f.deleted_at is null and f.physical_deleted_at is null
  and private.ai_material_readable_type(
    coalesce(f.detected_media_type, f.declared_media_type))
on conflict (file_object_id) do nothing;

insert into private.ai_material_docs(school_id, content_link_id)
select l.school_id, l.id from public.content_links l
where l.resource_version_id is not null and l.role = 'material'
  and l.detached_at is null
on conflict (content_link_id) do nothing;

-- Everything a lesson version is made of: its main file, its live attached
-- files and its live links, each with its reading state.
create or replace function private.ai_version_sources(p_version uuid)
returns table (
  source_id uuid, kind text, name text, url text, media_type text,
  doc_id uuid, state text, reason text, detail jsonb, ord integer)
language sql stable security definer set search_path = '' as $$
  select f.id, 'file', coalesce(f.display_name, 'file'), null::text,
    coalesce(f.detected_media_type, f.declared_media_type),
    d.id, coalesce(d.state, case when f.scan_state in ('quarantined', 'scanning')
      then 'processing' else 'unsupported' end),
    case when d.id is null then case
      when f.scan_state = 'clean' then 'unsupported_type'
      when f.scan_state in ('quarantined', 'scanning') then null
      else 'file_rejected' end else d.reason end,
    coalesce(d.detail, '{}'::jsonb), 0
  from public.resource_versions rv
  join public.file_objects f on f.id = rv.file_object_id
  left join private.ai_material_docs d on d.file_object_id = f.id
  where rv.id = p_version and f.deleted_at is null
  union all
  select f.id, 'file', coalesce(f.display_name, 'file'), null,
    coalesce(f.detected_media_type, f.declared_media_type),
    d.id, coalesce(d.state, case when f.scan_state in ('quarantined', 'scanning')
      then 'processing' else 'unsupported' end),
    case when d.id is null then case
      when f.scan_state = 'clean' then 'unsupported_type'
      when f.scan_state in ('quarantined', 'scanning') then null
      else 'file_rejected' end else d.reason end,
    coalesce(d.detail, '{}'::jsonb), 1
  from public.file_bindings b
  join public.file_objects f on f.id = b.file_object_id
  left join private.ai_material_docs d on d.file_object_id = f.id
  where b.resource_version_id = p_version and b.detached_at is null
    and b.role = 'material' and f.deleted_at is null
  union all
  select l.id, 'link', l.title, l.url, null,
    d.id, coalesce(d.state, 'pending'), d.reason,
    coalesce(d.detail, '{}'::jsonb), 2 + l.position
  from public.content_links l
  left join private.ai_material_docs d on d.content_link_id = l.id
  where l.resource_version_id = p_version and l.detached_at is null
    and l.role = 'material';
$$;

create or replace function private.ai_sources_json(p_version uuid)
returns jsonb language sql stable security definer set search_path = '' as $$
  select coalesce(jsonb_agg(jsonb_build_object(
      'id', s.source_id, 'kind', s.kind, 'name', s.name, 'url', s.url,
      'mediaType', s.media_type, 'state',
      case s.state when 'pending' then 'processing' else s.state end,
      'reason', s.reason,
      'pages', (s.detail->>'pages')::int,
      'skippedPages', (s.detail->>'skippedPages')::int)
    order by s.ord, s.name), '[]'::jsonb)
  from private.ai_version_sources(p_version) s;
$$;

-- A search query from what a student typed: each word, stemmed as Arabic
-- and as English, any of them matching.
create or replace function private.ai_search_query(p_text text)
returns tsquery language plpgsql immutable set search_path = '' as $$
declare
  v_query tsquery;
  v_word text;
  v_english text[];
  v_arabic text[];
  v_lexeme text;
  v_count integer := 0;
begin
  for v_word in
    select distinct w from regexp_split_to_table(
      lower(coalesce(p_text, '')),
      '[\s\.,;:!\?\(\)\[\]\{\}"''`<>/\\|=\+\*&\^%\$#@~،؛؟«»…–—_-]+') as w
    where length(w) between 2 and 40
  loop
    -- A stop word in either language ("the", "ما") matches everything, so
    -- it is left out. to_tsvector, unlike plainto_tsquery, says so quietly.
    v_english := tsvector_to_array(to_tsvector('english'::regconfig, v_word));
    v_arabic := tsvector_to_array(to_tsvector('arabic'::regconfig, v_word));
    continue when cardinality(v_english) = 0 or cardinality(v_arabic) = 0;
    -- Common Arabic words the stemmer keeps, and words that say what to do
    -- rather than what to find.
    continue when v_word = any(array[
      'ما', 'هي', 'هو', 'في', 'من', 'على', 'إلى', 'الى', 'عن', 'هذا', 'هذه',
      'ذلك', 'تلك', 'التي', 'الذي', 'أن', 'ان', 'إن', 'كان', 'لا', 'لم', 'مع',
      'أو', 'او', 'ثم', 'كيف', 'ماذا', 'لماذا', 'متى', 'أين', 'هل', 'كل', 'قد',
      'اشرح', 'لخص', 'ملخص', 'اختبرني', 'صفحة', 'الصفحة', 'شريحة', 'الشريحة',
      'الدرس', 'درس', 'ساعدني', 'explain', 'summarise', 'summarize', 'summary',
      'quiz', 'help', 'understand', 'page', 'pages', 'slide', 'slides',
      'lesson', 'document', 'file', 'please', 'tell', 'mean', 'means']);
    v_count := v_count + 1;
    exit when v_count > 24;
    for v_lexeme in
      select distinct x from unnest(v_english || v_arabic
        || tsvector_to_array(to_tsvector('simple'::regconfig, v_word))) as x
    loop
      v_query := case when v_query is null then quote_literal(v_lexeme)::tsquery
        else v_query || quote_literal(v_lexeme)::tsquery end;
    end loop;
  end loop;
  return v_query;
end;
$$;

-- Generated study content made from a lesson version before all of its
-- material was read no longer reflects it: drop it so it is made again.
create or replace function private.ai_material_refresh_outputs(p_doc uuid)
returns void language plpgsql security definer set search_path = '' as $$
declare
  v_versions uuid[];
begin
  select array_agg(distinct v) into v_versions from (
    select rv.id as v from private.ai_material_docs d
    join public.resource_versions rv on rv.file_object_id = d.file_object_id
    where d.id = p_doc
    union
    select b.resource_version_id from private.ai_material_docs d
    join public.file_bindings b on b.file_object_id = d.file_object_id
    where d.id = p_doc and b.resource_version_id is not null
    union
    select l.resource_version_id from private.ai_material_docs d
    join public.content_links l on l.id = d.content_link_id
    where d.id = p_doc and l.resource_version_id is not null
  ) x;
  if v_versions is null then return; end if;
  delete from private.lesson_notes_cache c where c.resource_version_id = any(v_versions);
  delete from public.study_sets s where s.resource_version_id = any(v_versions);
end;
$$;

-- ---------------------------------------------------------------------------
-- 2b. The worker's side: claim, budget, finish.
-- ---------------------------------------------------------------------------
create or replace function private.ai_material_claim(p_worker text, p_limit integer)
returns jsonb language plpgsql security definer set search_path = '' as $$
declare
  v_jobs jsonb;
begin
  with picked as (
    select d.id from private.ai_material_docs d
    where (d.state = 'pending' and d.next_attempt_at <= now())
       or (d.state = 'processing' and d.lease_until < now())
    order by d.next_attempt_at
    limit greatest(1, least(p_limit, 10))
    for update skip locked
  ), claimed as (
    update private.ai_material_docs d set state = 'processing',
      worker_id = left(p_worker, 120), lease_until = now() + interval '10 minutes',
      attempts = d.attempts + 1, updated_at = now()
    from picked where d.id = picked.id
    returning d.*
  )
  select coalesce(jsonb_agg(jsonb_build_object(
      'docId', c.id, 'schoolId', c.school_id, 'attempt', c.attempts,
      'limits', private.ai_material_limits(),
      'kind', case when c.file_object_id is null then 'link' else 'file' end,
      'file', case when c.file_object_id is null then null
        else private.file051_effective_object(c.file_object_id) end,
      'url', (select l.url from public.content_links l where l.id = c.content_link_id),
      'title', (select l.title from public.content_links l where l.id = c.content_link_id))),
    '[]'::jsonb)
  into v_jobs from claimed c;
  return v_jobs;
end;
$$;

-- How many pages of this file the model may read now: the per-file cap,
-- and what is left of the school's month. Taken under a per-school lock.
create or replace function private.ai_material_ocr_allowance(
  p_worker text, p_doc uuid, p_pages integer)
returns integer language plpgsql security definer set search_path = '' as $$
declare
  v_school uuid;
  v_limits jsonb := private.ai_material_limits();
  v_used integer;
  v_month date := date_trunc('month', now() at time zone 'utc')::date;
begin
  select d.school_id into v_school from private.ai_material_docs d
  where d.id = p_doc and d.worker_id = p_worker and d.state = 'processing';
  if v_school is null then return 0; end if;
  perform pg_advisory_xact_lock(hashtextextended('ai-ocr:' || v_school::text, 0));
  select coalesce(sum(u.pages), 0) into v_used from private.ai_processing_usage u
  where u.school_id = v_school and u.month = v_month and u.kind in ('ocr', 'image');
  return greatest(0, least(p_pages, (v_limits->>'ocrPagesPerFile')::int,
    (v_limits->>'ocrPagesPerSchoolMonth')::int - v_used));
end;
$$;

-- The worker's result. 'ready' replaces the passages in one step;
-- 'retry' tries again later until the attempts run out.
create or replace function private.ai_material_finish(
  p_worker text, p_doc uuid, p_result jsonb)
returns boolean language plpgsql security definer set search_path = '' as $$
declare
  d private.ai_material_docs%rowtype;
  v_outcome text := p_result->>'outcome';
  v_limits jsonb := private.ai_material_limits();
  v_month date := date_trunc('month', now() at time zone 'utc')::date;
begin
  select * into d from private.ai_material_docs x
  where x.id = p_doc for update;
  if d.id is null or d.worker_id is distinct from p_worker
     or d.state <> 'processing' then
    return false;
  end if;

  insert into private.ai_processing_usage(school_id, doc_id, kind, pages,
    input_tokens, output_tokens, cost_micro_usd, model, month)
  select d.school_id, d.id, u->>'kind', coalesce((u->>'pages')::int, 0),
    (u->>'inputTokens')::int, (u->>'outputTokens')::int,
    coalesce((u->>'costMicroUsd')::bigint, 0), left(u->>'model', 120), v_month
  from jsonb_array_elements(coalesce(p_result->'usage', '[]'::jsonb)) u
  where u->>'kind' in ('ocr', 'image', 'link');

  if v_outcome = 'ready' then
    delete from private.ai_material_chunks c where c.doc_id = d.id;
    insert into private.ai_material_chunks(doc_id, ordinal, page, slide, heading, body)
    select d.id, (c.ordinality - 1)::int,
      nullif(c.value->>'page', '')::int, nullif(c.value->>'slide', '')::int,
      left(nullif(c.value->>'heading', ''), 300), left(c.value->>'body', 6000)
    from jsonb_array_elements(coalesce(p_result->'chunks', '[]'::jsonb))
      with ordinality c
    where length(coalesce(c.value->>'body', '')) > 0
    limit 2000;
    update private.ai_material_docs set state = 'ready', reason = p_result->>'reason',
      detail = coalesce(p_result->'detail', '{}'::jsonb),
      extractor = left(p_result->>'extractor', 60), lease_until = null,
      processed_at = now(), updated_at = now()
    where id = d.id;
    perform private.ai_material_refresh_outputs(d.id);
  elsif v_outcome = 'unsupported' then
    delete from private.ai_material_chunks c where c.doc_id = d.id;
    update private.ai_material_docs set state = 'unsupported',
      reason = coalesce(p_result->>'reason', 'unsupported_type'),
      detail = coalesce(p_result->'detail', '{}'::jsonb), lease_until = null,
      processed_at = now(), updated_at = now()
    where id = d.id;
  elsif v_outcome = 'retry' and d.attempts < (v_limits->>'maxAttempts')::int then
    update private.ai_material_docs set state = 'pending',
      reason = coalesce(p_result->>'reason', 'temporary'), lease_until = null,
      next_attempt_at = now() + make_interval(mins => 2 * d.attempts * d.attempts),
      updated_at = now()
    where id = d.id;
  else
    update private.ai_material_docs set state = 'failed',
      reason = coalesce(p_result->>'reason', 'processing_failed'),
      lease_until = null, processed_at = now(), updated_at = now()
    where id = d.id;
  end if;
  return true;
end;
$$;

create or replace function private.ai_material_backlog()
returns jsonb language sql stable security definer set search_path = '' as $$
  select jsonb_build_object(
    'pending', count(*) filter (where state = 'pending'),
    'processing', count(*) filter (where state = 'processing'),
    'failed', count(*) filter (where state = 'failed'))
  from private.ai_material_docs;
$$;

-- ---------------------------------------------------------------------------
-- 3. The API's side: what a student may read, and what a teacher sees.
-- ---------------------------------------------------------------------------
create or replace function private.ai_teaches_resource(p_resource uuid)
returns boolean language sql stable security definer set search_path = '' as $$
  select auth.uid() is not null and (
    exists (select 1 from public.resources r
      where r.id = p_resource and r.created_by = auth.uid() and r.deleted_at is null)
    or exists (select 1 from public.resource_versions rv
      join public.resource_publications rp on rp.resource_version_id = rv.id
      where rv.resource_id = p_resource and rp.classroom_id is not null
        and private.coursework_teacher(rp.classroom_id)));
$$;

create or replace function private.api054_ai_material(p_operation text, p_input jsonb)
returns jsonb language plpgsql security definer set search_path = '' as $$
declare
  v_lesson jsonb;
  v_lessons jsonb := '[]'::jsonb;
  v_versions uuid[] := '{}';
  v_id uuid;
  v_version uuid;
  v_sources uuid[];
  v_query tsquery;
  v_pages int[];
  v_slides int[];
  v_budget integer;
  v_mode text;
  v_passages jsonb;
  v_resource uuid;
  v_doc private.ai_material_docs%rowtype;
begin
  if auth.uid() is null or not private.is_active_user() then
    return jsonb_build_object('outcome', 'forbidden');
  end if;

  case p_operation
    -- The lessons a student points the helper at, each with its files and
    -- links and how far reading them has got. Lessons they cannot see are
    -- left out, not refused.
    when 'lessons' then
      for v_id in
        select distinct (e.value #>> '{}')::uuid
        from jsonb_array_elements(coalesce(p_input->'resourceIds', '[]'::jsonb)) e
        limit 10
      loop
        v_lesson := private.study_lesson(v_id);
        continue when v_lesson is null;
        v_lessons := v_lessons || jsonb_build_array(jsonb_build_object(
          'resourceId', v_id, 'versionId', v_lesson->>'versionId',
          'classroomId', v_lesson->>'classroomId',
          'grade', (select c.grade from public.classrooms c
            where c.id = (v_lesson->>'classroomId')::uuid),
          'title', v_lesson->>'title', 'body', coalesce(v_lesson->>'body', ''),
          'sources', private.ai_sources_json((v_lesson->>'versionId')::uuid)));
      end loop;
      return jsonb_build_object('outcome', 'ok', 'lessons', v_lessons);

    -- Passages for one question, from those lessons only. 'search' ranks by
    -- the question's words and any page or slide it names; 'coverage'
    -- spreads across the whole material, for summaries and quizzes.
    when 'retrieve' then
      for v_id in
        select distinct (e.value #>> '{}')::uuid
        from jsonb_array_elements(coalesce(p_input->'resourceIds', '[]'::jsonb)) e
        limit 10
      loop
        v_lesson := private.study_lesson(v_id);
        if v_lesson is not null then
          v_versions := v_versions || (v_lesson->>'versionId')::uuid;
        end if;
      end loop;
      select array_agg((e.value #>> '{}')::uuid) into v_sources
      from jsonb_array_elements(coalesce(p_input->'sourceIds', '[]'::jsonb)) e;
      select array_agg((e.value #>> '{}')::int) into v_pages
      from jsonb_array_elements(coalesce(p_input->'pages', '[]'::jsonb)) e;
      select array_agg((e.value #>> '{}')::int) into v_slides
      from jsonb_array_elements(coalesce(p_input->'slides', '[]'::jsonb)) e;
      v_budget := least(greatest(coalesce((p_input->>'budgetChars')::int, 8000), 500), 120000);
      v_mode := coalesce(p_input->>'mode', 'search');
      v_query := private.ai_search_query(p_input->>'query');

      with docs as (
        select s.doc_id, s.kind, s.name, s.url
        from unnest(v_versions) v(id)
        cross join lateral private.ai_version_sources(v.id) s
        where s.state = 'ready' and s.doc_id is not null
          and (v_sources is null or s.source_id = any(v_sources))
      ), scored as (
        select c.id, c.doc_id, c.ordinal, c.page, c.slide, c.heading, c.body,
          d.kind, d.name, d.url,
          (c.page = any(coalesce(v_pages, '{}')) or c.slide = any(coalesce(v_slides, '{}'))) as named,
          case when v_query is null then 0 else ts_rank_cd(c.tsv, v_query) end as rank,
          row_number() over (order by c.doc_id, c.ordinal) as seq,
          sum(length(c.body)) over () as all_chars
        from private.ai_material_chunks c join docs d on d.doc_id = c.doc_id
      ), chosen as (
        select s.*,
          sum(length(s.body)) over (order by
            case when v_mode = 'coverage' then 0 else (case when s.named then 0 else 1 end) end,
            case when v_mode = 'coverage' then 0 else -s.rank end,
            s.doc_id, s.ordinal rows between unbounded preceding and current row) as running
        from scored s
        where case when v_mode = 'coverage'
          -- Every n-th passage, n chosen so the whole material fits: a
          -- summary sees the end of a long file, not only its start.
          then (s.seq - 1) % greatest(1, ceil(s.all_chars::numeric / v_budget)::int) = 0
          else s.named or s.rank > 0
            or (v_query is null and not exists (select 1 from private.ai_material_chunks x
              join docs y on y.doc_id = x.doc_id
              where x.page = any(coalesce(v_pages, '{}')) or x.slide = any(coalesce(v_slides, '{}'))))
          end
      )
      select coalesce(jsonb_agg(jsonb_build_object(
          'sourceKind', c.kind, 'name', c.name, 'url', c.url,
          'page', c.page, 'slide', c.slide, 'heading', c.heading, 'text', c.body)
        order by c.doc_id, c.ordinal), '[]'::jsonb)
      into v_passages
      from chosen c where c.running - length(c.body) < v_budget;

      -- Nothing matched: the start of the material is better than nothing,
      -- and the model is told what it was given.
      if jsonb_array_length(v_passages) = 0 and v_mode <> 'coverage' then
        return private.api054_ai_material('retrieve',
          p_input || jsonb_build_object('mode', 'coverage'));
      end if;
      return jsonb_build_object('outcome', 'ok', 'passages', v_passages);

    -- A teacher's view of one lesson's material, published or not.
    when 'status' then
      v_resource := (p_input->>'resourceId')::uuid;
      if not private.ai_teaches_resource(v_resource) then
        return jsonb_build_object('outcome', 'not_found');
      end if;
      select rv.id into v_version from public.resources r
      join public.resource_versions rv on rv.resource_id = r.id and rv.version = r.current_version
      where r.id = v_resource and r.deleted_at is null;
      if v_version is null then return jsonb_build_object('outcome', 'not_found'); end if;
      return jsonb_build_object('outcome', 'ok', 'resourceId', v_resource,
        'sources', private.ai_sources_json(v_version));

    -- Read one file or link again: a teacher of its lesson, after it failed
    -- or could not be read.
    when 'retry' then
      v_resource := (p_input->>'resourceId')::uuid;
      v_id := (p_input->>'sourceId')::uuid;
      if not private.ai_teaches_resource(v_resource) then
        return jsonb_build_object('outcome', 'not_found');
      end if;
      select rv.id into v_version from public.resources r
      join public.resource_versions rv on rv.resource_id = r.id and rv.version = r.current_version
      where r.id = v_resource and r.deleted_at is null;
      select d.* into v_doc from private.ai_version_sources(v_version) s
      join private.ai_material_docs d on d.id = s.doc_id
      where s.source_id = v_id;
      if v_doc.id is null then return jsonb_build_object('outcome', 'not_found'); end if;
      if v_doc.state not in ('failed', 'unsupported') then
        return jsonb_build_object('outcome', 'invalid_state');
      end if;
      update private.ai_material_docs set state = 'pending', reason = null,
        attempts = 0, next_attempt_at = now(), lease_until = null, updated_at = now()
      where id = v_doc.id;
      return jsonb_build_object('outcome', 'ok', 'resourceId', v_resource,
        'sources', private.ai_sources_json(v_version));

    -- Whether a lesson's material is still being read: quizzes, flashcards
    -- and notes wait for it, so they reflect every file.
    when 'pending' then
      v_lesson := private.study_lesson((p_input->>'resourceId')::uuid);
      if v_lesson is null then return jsonb_build_object('outcome', 'not_found'); end if;
      return jsonb_build_object('outcome', 'ok', 'pending', exists (
        select 1 from private.ai_version_sources((v_lesson->>'versionId')::uuid) s
        where s.state in ('pending', 'processing')));

    else
      return jsonb_build_object('outcome', 'invalid');
  end case;
exception when invalid_text_representation then
  return jsonb_build_object('outcome', 'invalid');
end;
$$;

-- ---------------------------------------------------------------------------
-- 4. Token allowances.
-- ---------------------------------------------------------------------------

-- How a model's tokens count. One token of the reference model counts as
-- one; a model that costs more counts more, so an allowance means the same
-- whatever answers it.
create table if not exists private.ai_model_rates (
  model text primary key check (length(model) between 1 and 120),
  input_weight numeric(8, 4) not null check (input_weight > 0),
  output_weight numeric(8, 4) not null check (output_weight > 0)
);
insert into private.ai_model_rates(model, input_weight, output_weight)
values ('Qwen/Qwen3.5-9B', 1, 1)
on conflict (model) do nothing;
revoke all on private.ai_model_rates
  from public, anon, authenticated, service_role, studafy_api_runtime,
  studafy_worker_runtime;

alter table private.ai_usage
  add column if not exists metered_tokens bigint not null default 0
    check (metered_tokens >= 0),
  add column if not exists reserved_tokens bigint not null default 0
    check (reserved_tokens >= 0),
  add column if not exists request_key text check (length(request_key) <= 140),
  -- A retry of a request that already succeeded: answered again, not charged.
  add column if not exists replay boolean not null default false;
alter table private.ai_usage drop constraint if exists ai_usage_feature_check;
alter table private.ai_usage add constraint ai_usage_feature_check
  check (feature in ('ask', 'whiteboard', 'notes', 'quiz', 'flashcards'));
create unique index if not exists ai_usage_request_key_idx
  on private.ai_usage (user_id, request_key) where request_key is not null;
create index if not exists ai_usage_user_created_idx
  on private.ai_usage (user_id, created_at);

-- What each plan allows. Changing a number is a migration a reviewer sees.
-- Worst case is every token an output token at $0.25 a million: 40k a week
-- is about $0.04 a month, 3M is $0.75 (under Plus's $0.80 cap), 6M is
-- $1.50 (under Max's $1.60).
create or replace function private.ai_plan_limits(p_plan text)
returns jsonb language sql immutable set search_path = '' as $$
  select case p_plan
    when 'max' then jsonb_build_object(
      'tokenAllowance', 6000000, 'period', 'month', 'capMicroUsd', 1600000,
      'features', jsonb_build_array('ask', 'whiteboard', 'notes', 'quiz', 'flashcards'))
    when 'plus' then jsonb_build_object(
      'tokenAllowance', 3000000, 'period', 'month', 'capMicroUsd', 800000,
      'features', jsonb_build_array('ask', 'whiteboard', 'notes'))
    else jsonb_build_object(
      'tokenAllowance', 40000, 'period', 'week', 'capMicroUsd', 0,
      'features', jsonb_build_array('ask'))
  end;
$$;

-- When the current allowance period began: Monday 00:00 UTC for a weekly
-- allowance, the 1st 00:00 UTC for a monthly one.
create or replace function private.ai_period_start(p_period text)
returns timestamptz language sql stable set search_path = '' as $$
  select (date_trunc(case p_period when 'week' then 'week' else 'month' end,
    now() at time zone 'utc')) at time zone 'utc';
$$;

create or replace function private.ai_period_end(p_period text)
returns timestamptz language sql stable set search_path = '' as $$
  select private.ai_period_start(p_period)
    + case p_period when 'week' then interval '7 days' else interval '1 month' end;
$$;

-- Tokens used since [p_since]: what was settled, plus live holds.
create or replace function private.ai_tokens_committed(p_user uuid, p_since timestamptz)
returns bigint language sql stable security definer set search_path = '' as $$
  select coalesce(sum(case
      when u.status = 'settled' then u.metered_tokens
      when u.status = 'reserved' and u.created_at > now() - interval '15 minutes'
        then u.reserved_tokens
      else 0 end), 0)::bigint
  from private.ai_usage u
  where u.user_id = p_user and u.created_at >= p_since;
$$;

create or replace function private.ai_allowance_json(p_user uuid, p_plan text)
returns jsonb language sql stable security definer set search_path = '' as $$
  with l as (select private.ai_plan_limits(p_plan) as v),
  p as (select l.v->>'period' as period, (l.v->>'tokenAllowance')::bigint as total from l),
  u as (select private.ai_tokens_committed(p_user, private.ai_period_start(p.period)) as used from p)
  select jsonb_build_object('period', p.period, 'total', p.total,
    'used', least(u.used, p.total), 'remaining', greatest(0, p.total - u.used),
    'resetsAt', private.ai_period_end(p.period))
  from p, u;
$$;

-- Metered tokens for a call, from the provider's own counts.
create or replace function private.ai_metered_tokens(
  p_model text, p_input integer, p_output integer)
returns bigint language sql stable security definer set search_path = '' as $$
  select ceil(coalesce(p_input, 0) * coalesce(r.input_weight, 2)
    + coalesce(p_output, 0) * coalesce(r.output_weight, 2))::bigint
  from (select 1) one
  left join private.ai_model_rates r on r.model = p_model;
$$;

create or replace function private.api047_ai_usage(p_operation text, p_input jsonb)
returns jsonb language plpgsql security definer set search_path = '' as $$
declare
  v_user uuid := auth.uid();
  v_month date := date_trunc('month', now() at time zone 'utc')::date;
  v_plan text;
  v_limits jsonb;
  v_feature text := p_input->>'feature';
  v_estimate bigint;
  v_tokens bigint;
  v_key text := nullif(p_input->>'requestKey', '');
  v_allowance jsonb;
  v_prior private.ai_usage%rowtype;
  v_replay boolean := false;
  v_row private.ai_usage%rowtype;
  v_metered bigint;
  v_id uuid;
begin
  if v_user is null or not private.is_active_user() then
    return jsonb_build_object('outcome', 'forbidden');
  end if;

  case p_operation
    when 'summary' then
      v_plan := private.study_plan(v_user);
      v_limits := private.ai_plan_limits(v_plan);
      return jsonb_build_object(
        'outcome', 'ok',
        'plan', v_plan,
        'features', v_limits->'features',
        'allowance', private.ai_allowance_json(v_user, v_plan),
        'capMicroUsd', (v_limits->>'capMicroUsd')::bigint,
        'committedMicroUsd', private.ai_month_committed(v_user, v_month));

    when 'reserve' then
      v_estimate := (p_input->>'estimateMicroUsd')::bigint;
      v_tokens := (p_input->>'estimateTokens')::bigint;
      if v_feature is null or v_estimate is null or v_estimate < 0
        or v_estimate > 100000 or v_tokens is null or v_tokens <= 0
        or v_tokens > 400000 or length(coalesce(v_key, '')) > 120 then
        return jsonb_build_object('outcome', 'invalid');
      end if;
      -- One student's reservations are serialised, so two requests at once
      -- cannot both pass a check that only one of them fits.
      perform pg_advisory_xact_lock(hashtextextended('ai-usage:' || v_user::text, 0));

      v_plan := private.study_plan(v_user);
      v_limits := private.ai_plan_limits(v_plan);
      if not (v_limits->'features') ? v_feature then
        return jsonb_build_object('outcome', 'plan_required', 'plan', v_plan);
      end if;

      -- The same request again. Still running: refused, it would be charged
      -- twice. Already answered: answered again, free, once. Failed: tried
      -- again as new.
      if v_key is not null then
        select * into v_prior from private.ai_usage u
        where u.user_id = v_user and u.request_key = v_key;
        if v_prior.id is not null then
          if v_prior.status = 'reserved'
             and v_prior.created_at > now() - interval '15 minutes' then
            return jsonb_build_object('outcome', 'in_progress');
          elsif v_prior.status = 'settled' then
            if exists (select 1 from private.ai_usage u
                where u.user_id = v_user and u.request_key = v_key || ':replay') then
              return jsonb_build_object('outcome', 'duplicate');
            end if;
            v_key := v_key || ':replay';
            v_replay := true;
          else
            update private.ai_usage set request_key = null where id = v_prior.id;
          end if;
        end if;
      end if;

      if not v_replay then
        v_allowance := private.ai_allowance_json(v_user, v_plan);
        if (v_allowance->>'remaining')::bigint < v_tokens then
          return jsonb_build_object('outcome', 'allowance_exhausted',
            'plan', v_plan, 'allowance', v_allowance);
        end if;
        -- The dollar cap stays underneath the tokens on paid plans.
        if v_plan <> 'free' and private.ai_month_committed(v_user, v_month)
             + v_estimate > (v_limits->>'capMicroUsd')::bigint then
          return jsonb_build_object('outcome', 'monthly_cap', 'plan', v_plan,
            'allowance', v_allowance);
        end if;
      end if;

      insert into private.ai_usage(user_id, feature, plan, month,
        reserved_micro_usd, reserved_tokens, request_key, replay)
      values (v_user, v_feature, v_plan, v_month,
        case when v_replay then 0 else v_estimate end,
        case when v_replay then 0 else v_tokens end, v_key, v_replay)
      returning id into v_id;
      return jsonb_build_object('outcome', 'ok', 'usageId', v_id,
        'plan', v_plan, 'replay', v_replay);

    when 'settle' then
      select * into v_row from private.ai_usage u
      where u.id = (p_input->>'usageId')::uuid and u.user_id = v_user
        and u.status = 'reserved'
      for update;
      if v_row.id is null then return jsonb_build_object('outcome', 'not_found'); end if;
      v_metered := case when v_row.replay then 0 else private.ai_metered_tokens(
        left(p_input->>'model', 120), (p_input->>'inputTokens')::int,
        (p_input->>'outputTokens')::int) end;
      -- No token counts from the provider: charge what was held.
      if p_input->>'inputTokens' is null and not v_row.replay then
        v_metered := v_row.reserved_tokens;
      end if;
      update private.ai_usage u set
        status = 'settled',
        cost_micro_usd = case when v_row.replay then 0
          else greatest(0, (p_input->>'costMicroUsd')::bigint) end,
        metered_tokens = v_metered,
        input_tokens = nullif(p_input->>'inputTokens', '')::int,
        output_tokens = nullif(p_input->>'outputTokens', '')::int,
        model = left(p_input->>'model', 120),
        settled_at = now()
      where u.id = v_row.id;
      return jsonb_build_object('outcome', 'ok', 'meteredTokens', v_metered,
        'allowance', private.ai_allowance_json(v_user, v_row.plan));

    when 'release' then
      update private.ai_usage u set status = 'released', settled_at = now()
      where u.id = (p_input->>'usageId')::uuid and u.user_id = v_user
        and u.status = 'reserved';
      return jsonb_build_object('outcome', case when found then 'ok' else 'not_found' end);

    else
      return jsonb_build_object('outcome', 'invalid');
  end case;
exception when invalid_text_representation or numeric_value_out_of_range then
  return jsonb_build_object('outcome', 'invalid');
end;
$$;

-- ---------------------------------------------------------------------------
-- 5. Who may see a lesson's reading state, and ask for a file to be read
--    again. Routed ahead of the existing dispatcher (ADR-0030).
-- ---------------------------------------------------------------------------
create or replace function private.authz_lesson_reading(p_action text, p_resource_id uuid)
returns jsonb language sql stable security definer set search_path = '' as $$
  select coalesce((
    select jsonb_build_object('allowed', ok, 'school_id', r.school_id,
      'reason', case when ok then 'allowed' else 'denied' end)
    from public.resources r
    cross join lateral (select r.deleted_at is null and (
      private.ai_teaches_resource(r.id)
      or (p_action = 'lesson_reading.read'
        and private.study_lesson(r.id) is not null)) as ok) x
    where r.id = p_resource_id),
    jsonb_build_object('allowed', false, 'school_id', null, 'reason', 'invalid_resource'));
$$;

do $$ begin
  if not exists (select 1 from pg_proc p join pg_namespace n on n.oid = p.pronamespace
      where n.nspname = 'private' and p.proname = 'authz_authorize_pre_material') then
    alter function private.authz_authorize(text, uuid)
      rename to authz_authorize_pre_material;
  end if;
end $$;

create or replace function private.authz_authorize(p_action text, p_resource_id uuid)
returns jsonb language plpgsql stable security definer set search_path = '' as $$
begin
  if p_action in ('lesson_reading.read', 'lesson_reading.retry') then
    return private.authz_lesson_reading(p_action, p_resource_id);
  end if;
  return private.authz_authorize_pre_material(p_action, p_resource_id);
end;
$$;

-- ---------------------------------------------------------------------------
-- Grants. The API reads material and meters; the worker reads files.
-- ---------------------------------------------------------------------------
do $$
declare
  fn text;
begin
  foreach fn in array array[
    'private.ai_material_limits()',
    'private.ai_material_readable_type(text)',
    'private.ai_material_on_file()',
    'private.ai_material_on_link()',
    'private.ai_version_sources(uuid)',
    'private.ai_sources_json(uuid)',
    'private.ai_search_query(text)',
    'private.ai_material_refresh_outputs(uuid)',
    'private.ai_material_claim(text, integer)',
    'private.ai_material_ocr_allowance(text, uuid, integer)',
    'private.ai_material_finish(text, uuid, jsonb)',
    'private.ai_material_backlog()',
    'private.ai_teaches_resource(uuid)',
    'private.api054_ai_material(text, jsonb)',
    'private.ai_plan_limits(text)',
    'private.ai_period_start(text)',
    'private.ai_period_end(text)',
    'private.ai_tokens_committed(uuid, timestamptz)',
    'private.ai_allowance_json(uuid, text)',
    'private.ai_metered_tokens(text, integer, integer)',
    'private.api047_ai_usage(text, jsonb)',
    'private.authz_lesson_reading(text, uuid)',
    'private.authz_authorize_pre_material(text, uuid)',
    'private.authz_authorize(text, uuid)']
  loop
    execute format('revoke all on function %s from public, anon, authenticated, '
      'service_role, studafy_api_runtime, studafy_worker_runtime', fn);
    execute format('alter function %s owner to postgres', fn);
  end loop;
end $$;

grant execute on function private.api054_ai_material(text, jsonb),
  private.api047_ai_usage(text, jsonb),
  private.authz_authorize(text, uuid)
  to studafy_api_runtime;
grant execute on function private.ai_material_claim(text, integer),
  private.ai_material_ocr_allowance(text, uuid, integer),
  private.ai_material_finish(text, uuid, jsonb),
  private.ai_material_backlog()
  to studafy_worker_runtime;
