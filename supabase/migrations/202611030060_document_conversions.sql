-- Old Office files and in-app previews, through an isolated document
-- converter (DL-078, 2026-11-03).
--
-- 1. Lesson files (`lesson_resource`) and assignment material
--    (`assignment_material`) may be Word, Excel and PowerPoint 97-2003 files
--    (.doc, .xls, .ppt), as they may be .docx/.xlsx/.pptx (202610070001,
--    202611030050). Hand-ins and every other purpose are unchanged. The scan
--    walks the compound file under caps and refuses macros, ActiveX,
--    embedded objects, links to other files and passwords
--    (packages/domain/src/files/cfb.ts). The bucket's allow-list stays the
--    union of the enabled purposes (as 202610110001 set it).
--
-- 2. Derived files ("renditions"), made by the document converter
--    (infra/converter: LibreOffice, headless, its own Fly app on the private
--    network only):
--      pdf_preview - a PDF of a Word, Excel, PowerPoint or CSV file, shown
--                    inside the app (a PDF is its own preview; pictures need
--                    none);
--      ooxml       - the .docx/.xlsx/.pptx copy of a .doc/.xls/.ppt, which
--                    the material index reads with the readers it has.
--    One row per file and kind, queued when the file's scan clears it. The
--    worker claims a row with a lease, converts the exact bytes the scan
--    recorded, re-scans the output with the upload rules, stores it in the
--    same private bucket under renditions/v1/, and finishes it here. Without
--    a converter a row is `skipped`; it is queued again when one is set.
--    A dedupe dependent has none of its own: it is served from its root's.
--
-- 3. Renditions never outlive their file: when the file leaves `clean`, is
--    deleted, loses its bytes, or becomes a dedupe dependent, its rows are
--    deleted, and every deleted row queues its object for deletion
--    (private.file_rendition_deletions, swept by the worker) - whether it
--    went by that trigger, a school's deletion, or a cascade.
--
-- 4. The material index waits for a .doc/.xls/.ppt's OOXML copy (the file
--    stays `pending`, which the app shows as still being read) and reads the
--    copy once it is settled; finishing the copy queues the reading again.
--
-- 5. A download intent may ask for `variant: preview`: the same
--    authorization as the original; a PDF returns itself; otherwise a ready
--    pdf_preview, served as application/pdf with a .pdf name, or
--    `preview_unavailable` (409 PREVIEW_UNAVAILABLE). The single-use grant
--    records which variant it is for, so a preview link can never fetch
--    anything else.

-- ---------------------------------------------------------------------------
-- 1. Upload purposes and the bucket.
-- ---------------------------------------------------------------------------
update public.file_purpose_policies p
set allowed_media_types = p.allowed_media_types || array(
      select t
      from unnest(array[
        'application/msword',
        'application/vnd.ms-excel',
        'application/vnd.ms-powerpoint']) as t
      where not (t = any(p.allowed_media_types))),
    updated_at = now()
where p.purpose in ('lesson_resource', 'assignment_material');

update storage.buckets b
set allowed_mime_types = (
  select array_agg(distinct t order by t)
  from (
    select unnest(p.allowed_media_types) as t
    from public.file_purpose_policies p
    where p.enabled
    union
    select unnest(coalesce(b.allowed_mime_types, '{}'::text[]))
  ) types
)
where b.id = 'private-school-files';

-- The media types the material index reads. The binary ones are read from
-- their OOXML copy.
create or replace function private.ai_material_readable_type(p_media text)
returns boolean language sql immutable set search_path = '' as $$
  select p_media in ('application/pdf', 'image/jpeg', 'image/png',
    'application/vnd.openxmlformats-officedocument.wordprocessingml.document',
    'application/vnd.openxmlformats-officedocument.presentationml.presentation',
    'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
    'text/csv',
    'application/msword',
    'application/vnd.ms-excel',
    'application/vnd.ms-powerpoint');
$$;

-- ---------------------------------------------------------------------------
-- 2. Renditions.
-- ---------------------------------------------------------------------------
create table if not exists private.file_renditions (
  id uuid primary key default gen_random_uuid(),
  file_object_id uuid not null references public.file_objects(id) on delete cascade,
  school_id uuid not null references public.schools(id) on delete cascade,
  kind text not null check (kind in ('pdf_preview', 'ooxml')),
  source_media_type text not null check (length(source_media_type) between 1 and 120),
  media_type text not null check (media_type in (
    'application/pdf',
    'application/vnd.openxmlformats-officedocument.wordprocessingml.document',
    'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
    'application/vnd.openxmlformats-officedocument.presentationml.presentation')),
  bucket text not null check (bucket = 'private-school-files'),
  storage_path text not null unique
    check (storage_path ~ '^renditions/v1/[0-9a-f-]{36}/[A-Za-z0-9_-]{22,64}$'),
  -- At most the global file ceiling (FILE-050): 25 MB.
  size_bytes bigint check (size_bytes between 1 and 26214400),
  sha256 text check (sha256 ~ '^[0-9a-f]{64}$'),
  status text not null default 'queued'
    check (status in ('queued', 'processing', 'ready', 'failed', 'skipped')),
  attempts integer not null default 0 check (attempts >= 0),
  next_attempt_at timestamptz not null default now(),
  lease_until timestamptz,
  worker_id text check (length(worker_id) <= 120),
  -- Why it failed or was skipped, as a short code; never file content.
  last_error text check (last_error ~ '^[a-z_]{1,60}$'),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  completed_at timestamptz,
  unique (file_object_id, kind),
  check (status <> 'ready' or (sha256 is not null and size_bytes is not null))
);
create index if not exists file_renditions_queue_idx
  on private.file_renditions (next_attempt_at)
  where status in ('queued', 'processing');
create index if not exists file_renditions_school_idx
  on private.file_renditions (school_id);

-- Objects to delete from storage, kept apart from the rows that named them
-- so a cascade cannot lose one.
create table if not exists private.file_rendition_deletions (
  id bigint generated always as identity primary key,
  bucket text not null check (bucket = 'private-school-files'),
  storage_path text not null
    check (storage_path ~ '^renditions/v1/[0-9a-f-]{36}/[A-Za-z0-9_-]{22,64}$'),
  state text not null default 'pending'
    check (state in ('pending', 'processing', 'dead_letter')),
  attempts integer not null default 0 check (attempts >= 0),
  next_attempt_at timestamptz not null default now(),
  lease_until timestamptz,
  worker_id text check (length(worker_id) <= 120),
  last_error text check (last_error ~ '^[A-Za-z_]{1,60}$'),
  created_at timestamptz not null default now()
);
create index if not exists file_rendition_deletions_queue_idx
  on private.file_rendition_deletions (next_attempt_at, id)
  where state in ('pending', 'processing');

revoke all on private.file_renditions, private.file_rendition_deletions
  from public, anon, authenticated, service_role, studafy_api_runtime,
  studafy_worker_runtime;

-- Which renditions a file gets, by its media type.
create or replace function private.file_rendition_kinds(p_media text)
returns text[] language sql immutable set search_path = '' as $$
  select case
    when p_media in (
      'application/vnd.openxmlformats-officedocument.wordprocessingml.document',
      'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
      'application/vnd.openxmlformats-officedocument.presentationml.presentation',
      'text/csv') then array['pdf_preview']
    when p_media in ('application/msword', 'application/vnd.ms-excel',
      'application/vnd.ms-powerpoint') then array['pdf_preview', 'ooxml']
    else array[]::text[]
  end;
$$;

-- The media type a rendition is stored as.
create or replace function private.file_rendition_media_type(p_kind text, p_source text)
returns text language sql immutable set search_path = '' as $$
  select case
    when p_kind = 'pdf_preview' then 'application/pdf'
    when p_source = 'application/msword'
      then 'application/vnd.openxmlformats-officedocument.wordprocessingml.document'
    when p_source = 'application/vnd.ms-excel'
      then 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet'
    when p_source = 'application/vnd.ms-powerpoint'
      then 'application/vnd.openxmlformats-officedocument.presentationml.presentation'
  end;
$$;

-- The name a preview is shown and saved under: the file's own, as .pdf.
create or replace function private.file_preview_name(p_name text)
returns text language sql immutable set search_path = '' as $$
  select coalesce(nullif(left(regexp_replace(coalesce(p_name, ''),
    '\.[A-Za-z0-9]{1,8}$', ''), 251), ''), 'preview') || '.pdf';
$$;

-- Queue a file's renditions once its scan has cleared it; drop them when
-- its bytes go, stop being trusted, or are another file's.
create or replace function private.file_renditions_on_file()
returns trigger language plpgsql security definer set search_path = '' as $$
declare
  v_media text := coalesce(new.detected_media_type, new.declared_media_type);
begin
  if new.scan_state <> 'clean' or new.deleted_at is not null
     or new.physical_deleted_at is not null
     or new.dedup_source_file_id is not null then
    delete from private.file_renditions r where r.file_object_id = new.id;
    return new;
  end if;
  if new.bucket <> 'private-school-files' then
    return new;
  end if;
  insert into private.file_renditions(file_object_id, school_id, kind,
    source_media_type, media_type, bucket, storage_path)
  select new.id, new.school_id, k, v_media,
    private.file_rendition_media_type(k, v_media), 'private-school-files',
    'renditions/v1/' || new.id::text || '/' || replace(gen_random_uuid()::text, '-', '')
  from unnest(private.file_rendition_kinds(v_media)) as k
  on conflict (file_object_id, kind) do nothing;
  return new;
end;
$$;

drop trigger if exists file_renditions_on_file on public.file_objects;
create trigger file_renditions_on_file
  after insert or update of scan_state, deleted_at, physical_deleted_at,
    dedup_source_file_id
  on public.file_objects
  for each row execute function private.file_renditions_on_file();

-- Every rendition row that goes, however it goes, queues its object.
create or replace function private.file_renditions_on_delete()
returns trigger language plpgsql security definer set search_path = '' as $$
begin
  insert into private.file_rendition_deletions(bucket, storage_path)
  values (old.bucket, old.storage_path);
  return old;
end;
$$;

drop trigger if exists file_renditions_on_delete on private.file_renditions;
create trigger file_renditions_on_delete
  after delete on private.file_renditions
  for each row execute function private.file_renditions_on_delete();

-- Clean documents already stored get their renditions too.
insert into private.file_renditions(file_object_id, school_id, kind,
  source_media_type, media_type, bucket, storage_path)
select f.id, f.school_id, k, coalesce(f.detected_media_type, f.declared_media_type),
  private.file_rendition_media_type(k, coalesce(f.detected_media_type, f.declared_media_type)),
  'private-school-files',
  'renditions/v1/' || f.id::text || '/' || replace(gen_random_uuid()::text, '-', '')
from public.file_objects f
cross join lateral unnest(private.file_rendition_kinds(
  coalesce(f.detected_media_type, f.declared_media_type))) as k
where f.scan_state = 'clean' and f.deleted_at is null
  and f.physical_deleted_at is null and f.dedup_source_file_id is null
  and f.bucket = 'private-school-files'
on conflict (file_object_id, kind) do nothing;

-- ---------------------------------------------------------------------------
-- 2b. The worker's side: claim, finish, deletions.
-- ---------------------------------------------------------------------------

-- Claims up to p_limit queued renditions (or ones whose lease lapsed), with
-- the exact stored object the scan cleared. A file that is no longer clean
-- has no rows to claim: the trigger above removed them.
create or replace function private.file_rendition_claim(p_worker text, p_limit integer)
returns jsonb language plpgsql security definer set search_path = '' as $$
declare
  v_jobs jsonb;
begin
  if p_worker is null or length(p_worker) not between 1 and 120 then
    raise exception 'FILE_RENDITION_INVALID_WORKER';
  end if;
  with picked as (
    select r.id from private.file_renditions r
    where (r.status = 'queued' and r.next_attempt_at <= now())
       or (r.status = 'processing' and r.lease_until < now())
    -- The copy the AI reads before the preview.
    order by r.next_attempt_at, (r.kind = 'pdf_preview'), r.id
    limit greatest(1, least(coalesce(p_limit, 1), 10))
    for update skip locked
  ), claimed as (
    update private.file_renditions r set status = 'processing',
      worker_id = p_worker, lease_until = now() + interval '10 minutes',
      attempts = r.attempts + 1, updated_at = now()
    from picked where r.id = picked.id
    returning r.*
  )
  select coalesce(jsonb_agg(jsonb_build_object(
      'renditionId', c.id, 'kind', c.kind, 'attempt', c.attempts,
      'sourceMediaType', c.source_media_type, 'mediaType', c.media_type,
      'bucket', c.bucket, 'objectKey', c.storage_path,
      'source', (select jsonb_build_object(
          'bucket', f.bucket, 'objectKey', f.object_key,
          'storedSha256', f.stored_sha256,
          'storedSizeBytes', f.stored_size_bytes,
          'clean', f.scan_state = 'clean' and f.deleted_at is null
            and f.physical_deleted_at is null)
        from public.file_objects f where f.id = c.file_object_id))
      order by c.attempts),
    '[]'::jsonb)
  into v_jobs from claimed c;
  return v_jobs;
end;
$$;

-- Lets the material index read a .doc/.xls/.ppt again once its OOXML copy
-- is settled, for the file and every dedupe dependent served from it.
create or replace function private.file_rendition_requeue_material(p_file uuid)
returns void language sql security definer set search_path = '' as $$
  update private.ai_material_docs d set state = 'pending', attempts = 0,
    reason = null, next_attempt_at = now(), lease_until = null,
    updated_at = now()
  where d.file_object_id in (
      select f.id from public.file_objects f
      where f.id = p_file or f.dedup_source_file_id = p_file)
    and d.state <> 'processing';
$$;

-- The worker's result: ready (stored, with its digest), failed (a short
-- code), skipped (no converter), or retry (the converter or storage was
-- unavailable: up to 5 attempts, backing off to an hour). Answers 'recorded',
-- 'lost' (another worker holds it now: leave its object alone) or 'gone'
-- (the row was deleted meanwhile: the caller deletes what it wrote).
create or replace function private.file_rendition_finish(
  p_worker text, p_rendition uuid, p_result jsonb)
returns text language plpgsql security definer set search_path = '' as $$
declare
  r private.file_renditions%rowtype;
  v_outcome text := p_result->>'outcome';
  v_code text := p_result->>'code';
  v_sha text := p_result->>'sha256';
  v_size bigint;
begin
  select * into r from private.file_renditions x where x.id = p_rendition for update;
  if r.id is null then return 'gone'; end if;
  if r.worker_id is distinct from p_worker or r.status <> 'processing' then
    return 'lost';
  end if;
  if v_code is null or v_code !~ '^[a-z_]{1,60}$' then
    v_code := null;
  end if;

  if v_outcome = 'ready' then
    v_size := (p_result->>'sizeBytes')::bigint;
    if v_sha is null or v_sha !~ '^[0-9a-f]{64}$'
       or v_size is null or v_size not between 1 and 26214400 then
      raise exception 'FILE_RENDITION_INVALID_RESULT';
    end if;
    update private.file_renditions set status = 'ready', sha256 = v_sha,
      size_bytes = v_size, last_error = null, lease_until = null,
      completed_at = now(), updated_at = now()
    where id = r.id;
  elsif v_outcome = 'skipped' then
    update private.file_renditions set status = 'skipped',
      last_error = coalesce(v_code, 'converter_not_configured'),
      lease_until = null, completed_at = now(), updated_at = now()
    where id = r.id;
  elsif v_outcome = 'retry' and r.attempts < 5 then
    update private.file_renditions set status = 'queued',
      last_error = coalesce(v_code, 'temporary'), lease_until = null,
      next_attempt_at = now() + make_interval(secs => least(3600, 30 * (2 ^ r.attempts)::integer)),
      updated_at = now()
    where id = r.id;
    return 'recorded';
  elsif v_outcome in ('failed', 'retry') then
    update private.file_renditions set status = 'failed',
      last_error = coalesce(v_code, 'conversion_failed'), lease_until = null,
      completed_at = now(), updated_at = now()
    where id = r.id;
  else
    raise exception 'FILE_RENDITION_INVALID_RESULT';
  end if;

  if r.kind = 'ooxml' then
    perform private.file_rendition_requeue_material(r.file_object_id);
  end if;
  return 'recorded';
end;
$$;

-- When a converter is configured after files were skipped, they are
-- converted after all. Returns how many were queued again.
create or replace function private.file_rendition_requeue_skipped()
returns integer language plpgsql security definer set search_path = '' as $$
declare v_count integer;
begin
  update private.file_renditions set status = 'queued', attempts = 0,
    last_error = null, next_attempt_at = now(), completed_at = null,
    updated_at = now()
  where status = 'skipped';
  get diagnostics v_count = row_count;
  return v_count;
end;
$$;

create or replace function private.file_rendition_claim_deletions(
  p_worker text, p_limit integer)
returns jsonb language plpgsql security definer set search_path = '' as $$
declare v_jobs jsonb;
begin
  if p_worker is null or length(p_worker) not between 1 and 120 then
    raise exception 'FILE_RENDITION_INVALID_WORKER';
  end if;
  with picked as (
    select d.id from private.file_rendition_deletions d
    where (d.state = 'pending' and d.next_attempt_at <= now())
       or (d.state = 'processing' and d.lease_until < now())
    order by d.next_attempt_at, d.id
    limit greatest(1, least(coalesce(p_limit, 1), 100))
    for update skip locked
  ), claimed as (
    update private.file_rendition_deletions d set state = 'processing',
      worker_id = p_worker, lease_until = now() + interval '5 minutes',
      attempts = d.attempts + 1
    from picked where d.id = picked.id
    returning d.*
  )
  select coalesce(jsonb_agg(jsonb_build_object('deletionId', c.id,
      'bucket', c.bucket, 'objectKey', c.storage_path) order by c.id), '[]'::jsonb)
  into v_jobs from claimed c;
  return v_jobs;
end;
$$;

-- Storage confirmed the deletion (the row goes), or did not (retried with
-- backoff; after 10 attempts left as a dead letter for an operator).
create or replace function private.file_rendition_finish_deletion(
  p_worker text, p_deletion bigint, p_succeeded boolean, p_error text)
returns boolean language plpgsql security definer set search_path = '' as $$
declare d private.file_rendition_deletions%rowtype;
begin
  select * into d from private.file_rendition_deletions x
  where x.id = p_deletion for update;
  if d.id is null or d.worker_id is distinct from p_worker
     or d.state <> 'processing' then
    return false;
  end if;
  if p_succeeded then
    delete from private.file_rendition_deletions where id = d.id;
  else
    update private.file_rendition_deletions set
      state = case when d.attempts >= 10 then 'dead_letter' else 'pending' end,
      next_attempt_at = now() + make_interval(secs => least(3600, 5 * (2 ^ least(d.attempts, 9))::integer)),
      lease_until = null,
      last_error = case when p_error ~ '^[A-Za-z_]{1,60}$' then p_error
        else 'STORAGE_UNAVAILABLE' end
    where id = d.id;
  end if;
  return true;
end;
$$;

-- Counts only, for the worker's periodic log line.
create or replace function private.file_rendition_backlog()
returns jsonb language sql stable security definer set search_path = '' as $$
  select jsonb_build_object(
    'queued', (select count(*) from private.file_renditions where status = 'queued'),
    'processing', (select count(*) from private.file_renditions where status = 'processing'),
    'failed', (select count(*) from private.file_renditions where status = 'failed'),
    'skipped', (select count(*) from private.file_renditions where status = 'skipped'),
    'deletionsPending', (select count(*) from private.file_rendition_deletions
      where state in ('pending', 'processing')),
    'deletionsDead', (select count(*) from private.file_rendition_deletions
      where state = 'dead_letter'));
$$;

-- ---------------------------------------------------------------------------
-- 3. The material index reads a binary Office file from its OOXML copy.
-- ---------------------------------------------------------------------------

-- The OOXML copy of a file (or of the root it is served from), or null.
create or replace function private.ai_material_rendition(p_file uuid)
returns jsonb language sql stable security definer set search_path = '' as $$
  select jsonb_build_object('status', r.status, 'bucket', r.bucket,
    'objectKey', r.storage_path, 'sha256', r.sha256,
    'sizeBytes', r.size_bytes, 'mediaType', r.media_type)
  from public.file_objects f
  join private.file_renditions r
    on r.file_object_id = coalesce(f.dedup_source_file_id, f.id)
   and r.kind = 'ooxml'
  where f.id = p_file;
$$;

-- True while a file's OOXML copy is still being made: its reading waits.
create or replace function private.ai_material_awaits_rendition(p_file uuid)
returns boolean language sql stable security definer set search_path = '' as $$
  select p_file is not null and exists (
    select 1 from public.file_objects f
    join private.file_renditions r
      on r.file_object_id = coalesce(f.dedup_source_file_id, f.id)
     and r.kind = 'ooxml'
    where f.id = p_file and r.status in ('queued', 'processing'));
$$;

-- As 202610070001, but a document waiting on its OOXML copy is not claimed,
-- and a claimed file carries that copy.
create or replace function private.ai_material_claim(p_worker text, p_limit integer)
returns jsonb language plpgsql security definer set search_path = '' as $$
declare
  v_jobs jsonb;
begin
  with picked as (
    select d.id from private.ai_material_docs d
    where ((d.state = 'pending' and d.next_attempt_at <= now())
       or (d.state = 'processing' and d.lease_until < now()))
      and not private.ai_material_awaits_rendition(d.file_object_id)
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
      'rendition', case when c.file_object_id is null then null
        else private.ai_material_rendition(c.file_object_id) end,
      'url', (select l.url from public.content_links l where l.id = c.content_link_id),
      'title', (select l.title from public.content_links l where l.id = c.content_link_id))),
    '[]'::jsonb)
  into v_jobs from claimed c;
  return v_jobs;
end;
$$;

-- ---------------------------------------------------------------------------
-- 4. Preview delivery.
-- ---------------------------------------------------------------------------
alter table public.file_delivery_grants
  add column if not exists variant text not null default 'original'
    check (variant in ('original', 'preview'));

-- As 202609170004, with the variant: a preview grant is recorded only for a
-- ready PDF preview (or a PDF, which is its own). Authorization, cleanliness
-- and the link's shape are checked first, exactly as for the original, so a
-- preview reveals nothing an original would not.
create or replace function private.api051_create_download_grant(
  p_file_id uuid, p_internal jsonb, p_idempotency_id uuid, p_idempotency_generation bigint)
returns jsonb language plpgsql security definer set search_path = '' as $$
declare
  f public.file_objects%rowtype;
  authz jsonb;
  expires timestamptz := (p_internal->>'expiresAt')::timestamptz;
  response jsonb;
  request_id text := nullif(current_setting('studafy.request_id', true), '');
  v_variant text := coalesce(p_internal->>'variant', 'original');
  v_media text;
  v_name text;
begin
  if auth.uid() is null or request_id is null then
    return jsonb_build_object('outcome', 'forbidden');
  end if;
  select * into f from public.file_objects fo where fo.id = p_file_id for update;
  if f.id is null or f.deleted_at is not null then
    return jsonb_build_object('outcome', 'not_found');
  end if;
  -- Authorize before revealing anything about the object's state.
  authz := private.file051_authorize_download(p_file_id);
  if not coalesce((authz->>'allowed')::boolean, false) then
    return jsonb_build_object('outcome', 'not_found');
  end if;
  if f.scan_state <> 'clean' then
    return jsonb_build_object('outcome', 'file_not_clean');
  end if;
  if (p_internal->>'nonceHash') is null or (p_internal->>'nonceHash') !~ '^[0-9a-f]{64}$'
    or (p_internal->>'downloadUrl') is null
    or expires is null or expires <= now() + interval '30 seconds'
    or expires > now() + interval '10 minutes'
    or v_variant not in ('original', 'preview') then
    return jsonb_build_object('outcome', 'invalid');
  end if;
  if f.dedup_source_file_id is not null and not coalesce(
    (private.file051_effective_object(p_file_id)->>'rootClean')::boolean, false) then
    return jsonb_build_object('outcome', 'invalid_state');
  end if;

  v_media := f.detected_media_type;
  v_name := f.display_name;
  if v_variant = 'preview' then
    if f.detected_media_type = 'application/pdf' then
      -- A PDF is shown as it is.
      v_variant := 'original';
    elsif exists (
      select 1 from private.file_renditions r
      where r.file_object_id = coalesce(f.dedup_source_file_id, f.id)
        and r.kind = 'pdf_preview' and r.status = 'ready') then
      v_media := 'application/pdf';
      v_name := private.file_preview_name(f.display_name);
    else
      return jsonb_build_object('outcome', 'preview_unavailable');
    end if;
  end if;

  insert into public.file_delivery_grants(
    school_id, file_object_id, recipient_id, nonce_hash, expires_at, request_id,
    variant)
  values (f.school_id, f.id, auth.uid(), p_internal->>'nonceHash', expires,
    request_id, v_variant);

  response := jsonb_build_object(
    'downloadUrl', p_internal->>'downloadUrl', 'expiresAt', expires,
    'displayName', v_name, 'mediaType', v_media);
  insert into public.audit_events(school_id, actor_id, action, entity_type, entity_id, after_value, request_id)
  values (f.school_id, auth.uid(), 'file_download_grant_issued', 'file_object', f.id,
    jsonb_build_object('reason', authz->>'reason', 'expiresAt', expires,
      'variant', v_variant), request_id);
  if not private.api_idempotency_complete(p_idempotency_id, p_idempotency_generation, 200, response) then
    raise exception 'FILE051_IDEMPOTENCY_COMPLETION_FAILED';
  end if;
  return jsonb_build_object('outcome', 'ok', 'response', response);
end;
$$;

-- As 202609170004; a preview grant is served from the ready PDF preview,
-- re-checked now, with the same digest check in the API as an original.
create or replace function private.api051_consume_download_grant(
  p_file_id uuid, p_nonce_hash text)
returns jsonb language plpgsql security definer set search_path = '' as $$
declare
  f public.file_objects%rowtype;
  authz jsonb;
  effective jsonb;
  request_id text := nullif(current_setting('studafy.request_id', true), '');
  v_variant text;
  r private.file_renditions%rowtype;
begin
  if auth.uid() is null or p_nonce_hash is null or p_nonce_hash !~ '^[0-9a-f]{64}$' then
    return jsonb_build_object('outcome', 'grant_invalid');
  end if;
  update public.file_delivery_grants
    set state = 'consumed', consumed_at = now()
    where nonce_hash = p_nonce_hash and file_object_id = p_file_id
      and recipient_id = auth.uid() and state = 'available' and expires_at > now()
    returning variant into v_variant;
  if not found then
    return jsonb_build_object('outcome', 'grant_invalid');
  end if;

  select * into f from public.file_objects fo where fo.id = p_file_id;
  if f.id is null or f.deleted_at is not null or f.scan_state <> 'clean' then
    return jsonb_build_object('outcome', 'not_found');
  end if;
  authz := private.file051_authorize_download(p_file_id);
  if not coalesce((authz->>'allowed')::boolean, false) then
    return jsonb_build_object('outcome', 'not_found');
  end if;
  effective := private.file051_effective_object(p_file_id);
  if not coalesce((effective->>'rootClean')::boolean, false)
    or (effective->>'objectKey') is null then
    return jsonb_build_object('outcome', 'invalid_state');
  end if;
  if v_variant = 'preview' then
    select * into r from private.file_renditions x
    where x.file_object_id = coalesce(f.dedup_source_file_id, f.id)
      and x.kind = 'pdf_preview' and x.status = 'ready';
    if r.id is null then
      return jsonb_build_object('outcome', 'not_found');
    end if;
    effective := jsonb_build_object(
      'schoolId', f.school_id, 'bucket', r.bucket, 'objectKey', r.storage_path,
      'storedSha256', r.sha256, 'storedSizeBytes', r.size_bytes,
      'mediaType', 'application/pdf',
      'displayName', private.file_preview_name(f.display_name),
      'rootClean', true);
  end if;
  insert into public.audit_events(school_id, actor_id, action, entity_type, entity_id, after_value, request_id)
  values (f.school_id, auth.uid(), 'file_download_delivered', 'file_object', f.id,
    jsonb_build_object('reason', authz->>'reason', 'variant', v_variant), request_id);
  return jsonb_build_object('outcome', 'ok', 'response', effective);
end;
$$;

-- ---------------------------------------------------------------------------
-- 5. Ownership and grants.
-- ---------------------------------------------------------------------------
do $$
declare fn text;
begin
  foreach fn in array array[
    'private.ai_material_readable_type(text)',
    'private.file_rendition_kinds(text)',
    'private.file_rendition_media_type(text, text)',
    'private.file_preview_name(text)',
    'private.file_renditions_on_file()',
    'private.file_renditions_on_delete()',
    'private.file_rendition_claim(text, integer)',
    'private.file_rendition_requeue_material(uuid)',
    'private.file_rendition_finish(text, uuid, jsonb)',
    'private.file_rendition_requeue_skipped()',
    'private.file_rendition_claim_deletions(text, integer)',
    'private.file_rendition_finish_deletion(text, bigint, boolean, text)',
    'private.file_rendition_backlog()',
    'private.ai_material_rendition(uuid)',
    'private.ai_material_awaits_rendition(uuid)',
    'private.ai_material_claim(text, integer)',
    'private.api051_create_download_grant(uuid, jsonb, uuid, bigint)',
    'private.api051_consume_download_grant(uuid, text)']
  loop
    execute format('revoke all on function %s from public, anon, authenticated, '
      'service_role, studafy_api_runtime, studafy_worker_runtime', fn);
    execute format('alter function %s owner to postgres', fn);
  end loop;
end $$;

grant execute on function private.api051_create_download_grant(uuid, jsonb, uuid, bigint),
  private.api051_consume_download_grant(uuid, text)
  to studafy_api_runtime;
grant execute on function private.ai_material_claim(text, integer),
  private.file_rendition_claim(text, integer),
  private.file_rendition_finish(text, uuid, jsonb),
  private.file_rendition_requeue_skipped(),
  private.file_rendition_claim_deletions(text, integer),
  private.file_rendition_finish_deletion(text, bigint, boolean, text),
  private.file_rendition_backlog()
  to studafy_worker_runtime;
