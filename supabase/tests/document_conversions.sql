-- Old Office files and in-app previews (202611030060, DL-078): upload types,
-- renditions queued when a file is cleared and dropped with it, the worker's
-- claim and finish, the material index waiting for a .doc's OOXML copy, and
-- preview delivery under the original's authorization. Synthetic fixtures;
-- everything rolls back.
begin;
\set auth031_fixture_only true
\ir rls_access_seed.sql
\unset auth031_fixture_only
create extension if not exists pgtap with schema extensions;
set local search_path=public,extensions;
select plan(60);

\set doc_file 'dc078000-0000-4000-8000-0000000000f1'
\set docx_file 'dc078000-0000-4000-8000-0000000000f2'
\set pdf_file 'dc078000-0000-4000-8000-0000000000f3'
\set png_file 'dc078000-0000-4000-8000-0000000000f4'
\set csv_file 'dc078000-0000-4000-8000-0000000000f5'
\set gone_file 'dc078000-0000-4000-8000-0000000000f6'

-- A lesson file owned by the seed teacher, in quarantine.
create function pg_temp.upload(p_id uuid, p_media text, p_name text) returns void
language sql as $$
  insert into public.file_objects (id, school_id, bucket, object_key, uploader_id,
    size_bytes, declared_media_type, detected_media_type, sha256, scan_state,
    owner_id, purpose, display_name)
  values (p_id, '11111111-1111-4111-8111-111111111111', 'private-school-files',
    'quarantine/v1/' || p_id::text || '/abcdefghijklmnopqrstuvwx',
    'aaaa0000-0000-4000-8000-000000000001', 10, p_media, p_media,
    encode(extensions.digest(p_id::text, 'sha256'), 'hex'), 'quarantined',
    'aaaa0000-0000-4000-8000-000000000001', 'lesson_resource', p_name);
$$;
-- The scan clearing it.
create function pg_temp.clean(p_id uuid) returns void language sql as $$
  update public.file_objects set scan_state = 'clean', scanned_at = now(),
    stored_sha256 = sha256, stored_size_bytes = size_bytes
  where id = p_id;
$$;
create function pg_temp.kinds(p_id uuid) returns text[] language sql as $$
  select coalesce(array_agg(r.kind order by r.kind), '{}')
  from private.file_renditions r where r.file_object_id = p_id;
$$;
create function pg_temp.rendition(p_id uuid, p_kind text) returns uuid
language sql as $$
  select r.id from private.file_renditions r
  where r.file_object_id = p_id and r.kind = p_kind;
$$;
-- One download intent as the given user.
create function pg_temp.intent(p_user uuid, p_file uuid, p_seq integer,
  p_variant text) returns jsonb language plpgsql as $$
declare reserve jsonb;
begin
  perform set_config('request.jwt.claim.sub', p_user::text, true);
  perform set_config('studafy.school_id', '11111111-1111-4111-8111-111111111111', true);
  perform set_config('studafy.request_id', 'dl078-intent-' || p_seq, true);
  reserve := private.api_idempotency_reserve('11111111-1111-4111-8111-111111111111',
    'v1.createFileDownloadIntent', 'dl078-download-' || lpad(p_seq::text, 8, '0'),
    md5('dl078' || p_seq) || md5('dl078:' || p_seq));
  return private.api051_create_download_grant(p_file,
    jsonb_build_object('nonceHash', md5('nonce' || p_seq) || md5('nonce:' || p_seq),
      'downloadUrl', 'https://api.studafy.test/delivery/v1/files/' || p_file || '/content?token=t' || p_seq,
      'expiresAt', now() + interval '5 minutes', 'variant', p_variant),
    (reserve->>'id')::uuid, (reserve->>'generation')::bigint);
end $$;
create function pg_temp.consume(p_user uuid, p_file uuid, p_seq integer)
returns jsonb language plpgsql as $$
begin
  perform set_config('request.jwt.claim.sub', p_user::text, true);
  perform set_config('studafy.request_id', 'dl078-consume-' || p_seq, true);
  return private.api051_consume_download_grant(p_file,
    md5('nonce' || p_seq) || md5('nonce:' || p_seq));
end $$;

-- ---------------------------------------------------------------------------
-- 1. What may be uploaded, and what reads it.
-- ---------------------------------------------------------------------------
select is(
  (select count(*) from public.file_purpose_policies p
   cross join unnest(array['application/msword', 'application/vnd.ms-excel',
     'application/vnd.ms-powerpoint']) as t(media_type)
   where p.purpose in ('lesson_resource', 'assignment_material')
     and t.media_type = any(p.allowed_media_types)),
  6::bigint,
  'lessons and assignment material take .doc, .xls and .ppt');
select ok(
  (select not (allowed_media_types && array['application/msword',
     'application/vnd.ms-excel', 'application/vnd.ms-powerpoint'])
   from public.file_purpose_policies where purpose = 'assignment_submission'),
  'hand-ins do not take the old binary formats');
select ok(
  (select array['application/msword', 'application/vnd.ms-excel',
     'application/vnd.ms-powerpoint'] <@ allowed_mime_types
   from storage.buckets where id = 'private-school-files'),
  'the storage bucket accepts them');
select is(
  (select count(*) from public.file_purpose_policies p
   cross join unnest(p.allowed_media_types) as t(media_type)
   join storage.buckets b on b.id = 'private-school-files'
   where p.enabled and not (t.media_type = any(b.allowed_mime_types))),
  0::bigint,
  'the bucket is still the union of every enabled purpose');
select ok(
  private.ai_material_readable_type('application/msword')
    and private.ai_material_readable_type('application/vnd.ms-excel')
    and private.ai_material_readable_type('application/vnd.ms-powerpoint')
    and private.ai_material_readable_type('text/csv')
    and not private.ai_material_readable_type('image/webp'),
  'the material index reads the old binary formats');

-- ---------------------------------------------------------------------------
-- 2. Nothing is open to any role; the worker gets its functions only.
-- ---------------------------------------------------------------------------
select is(
  (select count(*) from information_schema.role_table_grants
   where table_schema = 'private'
     and table_name in ('file_renditions', 'file_rendition_deletions')
     and grantee in ('anon', 'authenticated', 'service_role',
       'studafy_api_runtime', 'studafy_worker_runtime')),
  0::bigint,
  'no role holds a grant on renditions or their deletions');
select ok(
  has_function_privilege('studafy_worker_runtime', 'private.file_rendition_claim(text, integer)', 'execute')
    and has_function_privilege('studafy_worker_runtime', 'private.file_rendition_finish(text, uuid, jsonb)', 'execute')
    and has_function_privilege('studafy_worker_runtime', 'private.file_rendition_requeue_skipped()', 'execute')
    and has_function_privilege('studafy_worker_runtime', 'private.file_rendition_claim_deletions(text, integer)', 'execute')
    and has_function_privilege('studafy_worker_runtime', 'private.file_rendition_finish_deletion(text, bigint, boolean, text)', 'execute')
    and has_function_privilege('studafy_worker_runtime', 'private.file_rendition_backlog()', 'execute')
    and has_function_privilege('studafy_worker_runtime', 'private.ai_material_claim(text, integer)', 'execute'),
  'the worker may claim, finish and sweep renditions, and still claim material');
select ok(
  not has_function_privilege('studafy_api_runtime', 'private.file_rendition_claim(text, integer)', 'execute')
    and not has_function_privilege('authenticated', 'private.file_rendition_finish(text, uuid, jsonb)', 'execute')
    and not has_function_privilege('anon', 'private.file_rendition_claim_deletions(text, integer)', 'execute')
    and not has_function_privilege('service_role', 'private.file_rendition_requeue_skipped()', 'execute'),
  'no client, service or API role can drive the rendition worker');
select is(
  (select count(*) from pg_proc p join pg_namespace n on n.oid = p.pronamespace
   where n.nspname = 'private'
     and p.proname in ('file_renditions_on_file', 'file_renditions_on_delete',
       'file_rendition_requeue_material', 'file_rendition_kinds',
       'file_rendition_media_type', 'file_preview_name', 'ai_material_rendition',
       'ai_material_awaits_rendition')
     and (has_function_privilege('anon', p.oid, 'execute')
       or has_function_privilege('authenticated', p.oid, 'execute')
       or has_function_privilege('service_role', p.oid, 'execute')
       or has_function_privilege('studafy_api_runtime', p.oid, 'execute')
       or has_function_privilege('studafy_worker_runtime', p.oid, 'execute'))),
  0::bigint,
  'the triggers and helpers are callable by no role');
select ok(
  has_function_privilege('studafy_api_runtime', 'private.api051_create_download_grant(uuid, jsonb, uuid, bigint)', 'execute')
    and has_function_privilege('studafy_api_runtime', 'private.api051_consume_download_grant(uuid, text)', 'execute')
    and not has_function_privilege('studafy_worker_runtime', 'private.api051_create_download_grant(uuid, jsonb, uuid, bigint)', 'execute')
    and not has_function_privilege('authenticated', 'private.api051_consume_download_grant(uuid, text)', 'execute'),
  'the delivery commands keep their grants');

-- ---------------------------------------------------------------------------
-- 3. Renditions are queued when the scan clears a document.
-- ---------------------------------------------------------------------------
select pg_temp.upload(:'doc_file', 'application/msword', 'Week 3 notes.doc');
select pg_temp.upload(:'docx_file',
  'application/vnd.openxmlformats-officedocument.wordprocessingml.document', 'Plan.docx');
select pg_temp.upload(:'pdf_file', 'application/pdf', 'Sheet.pdf');
select pg_temp.upload(:'png_file', 'image/png', 'Board.png');
select pg_temp.upload(:'csv_file', 'text/csv', 'Marks.csv');

select is(pg_temp.kinds(:'doc_file'), '{}'::text[],
  'a file in quarantine has no renditions');

-- Work other suites left behind waits, so the claims below see only ours.
update private.file_renditions set next_attempt_at = now() + interval '1 day';
update private.ai_material_docs set next_attempt_at = now() + interval '1 day';

select pg_temp.clean(:'doc_file');
select pg_temp.clean(:'docx_file');
select pg_temp.clean(:'pdf_file');
select pg_temp.clean(:'png_file');
select pg_temp.clean(:'csv_file');

select is(pg_temp.kinds(:'doc_file'), array['ooxml', 'pdf_preview'],
  'a cleared .doc gets a preview and an OOXML copy');
select is(
  (select media_type from private.file_renditions
   where id = pg_temp.rendition(:'doc_file', 'ooxml')),
  'application/vnd.openxmlformats-officedocument.wordprocessingml.document',
  'the .doc is copied to .docx');
select is(pg_temp.kinds(:'docx_file'), array['pdf_preview'],
  'a .docx gets a preview only');
select is(pg_temp.kinds(:'csv_file'), array['pdf_preview'],
  'a CSV gets a preview');
select is(pg_temp.kinds(:'pdf_file'), '{}'::text[],
  'a PDF is its own preview');
select is(pg_temp.kinds(:'png_file'), '{}'::text[],
  'a picture needs none');
select ok(
  (select bool_and(r.status = 'queued'
     and r.bucket = 'private-school-files'
     and r.storage_path ~ ('^renditions/v1/' || r.file_object_id || '/[0-9a-f]{32}$'))
   from private.file_renditions r
   where r.file_object_id in (:'doc_file', :'docx_file', :'csv_file')),
  'each is queued under its own derived key in the private bucket');

-- ---------------------------------------------------------------------------
-- 4. The material index waits for the .doc's OOXML copy.
-- ---------------------------------------------------------------------------
select is(
  (select state from private.ai_material_docs where file_object_id = :'doc_file'),
  'pending', 'the .doc is queued for reading');
select ok(private.ai_material_awaits_rendition(:'doc_file'),
  'and waits for its OOXML copy');
create temporary table claimed_material as
  select private.ai_material_claim('dl078-reader', 10) as jobs;
select ok(
  not exists (select 1 from claimed_material c,
    jsonb_array_elements(c.jobs) j
    where j->>'docId' = (select id::text from private.ai_material_docs
      where file_object_id = :'doc_file')),
  'the reader does not claim it while the copy is being made');
select ok(
  exists (select 1 from claimed_material c, jsonb_array_elements(c.jobs) j
    where (j->'file'->>'mediaType') like '%wordprocessingml%'
      and j->'rendition' = 'null'::jsonb),
  'other files are claimed as before, with no copy to read');

-- ---------------------------------------------------------------------------
-- 5. The rendition worker's claim and finish.
-- ---------------------------------------------------------------------------
create temporary table claimed_renditions as
  select private.file_rendition_claim('dl078-converter', 10) as jobs;
select is(
  (select jsonb_array_length(jobs) from claimed_renditions), 4,
  'every queued rendition is claimed');
select ok(
  (select bool_and((j->'source'->>'clean')::boolean
     and j->'source'->>'objectKey' like 'quarantine/v1/%'
     and j->>'objectKey' like 'renditions/v1/%')
   from claimed_renditions c, jsonb_array_elements(c.jobs) j),
  'a claim names the cleared original and the derived key, nothing else');
select is(
  (select j->>'kind' from claimed_renditions c, jsonb_array_elements(c.jobs) j
   where j->>'renditionId' = pg_temp.rendition(:'doc_file', 'ooxml')::text),
  'ooxml', 'the copy the AI reads is in the claim');
select is(
  (select count(*) from private.file_renditions where status = 'processing'
     and worker_id = 'dl078-converter'),
  4::bigint, 'claimed renditions are leased to the worker');

select is(
  private.file_rendition_finish('someone-else', pg_temp.rendition(:'doc_file', 'ooxml'),
    jsonb_build_object('outcome', 'ready', 'sha256', repeat('a', 64), 'sizeBytes', 900)),
  'lost', 'another worker cannot finish a lease it does not hold');
select is(
  private.file_rendition_finish('dl078-converter', pg_temp.rendition(:'doc_file', 'ooxml'),
    jsonb_build_object('outcome', 'ready', 'sha256', repeat('a', 64), 'sizeBytes', 900)),
  'recorded', 'the worker records the stored copy');
select is(
  (select status || ':' || sha256 || ':' || size_bytes from private.file_renditions
   where id = pg_temp.rendition(:'doc_file', 'ooxml')),
  'ready:' || repeat('a', 64) || ':900', 'the copy is ready with its digest');
select is(
  (select state || ':' || attempts from private.ai_material_docs
   where file_object_id = :'doc_file'),
  'pending:0', 'finishing the copy queues the reading again');
select ok(not private.ai_material_awaits_rendition(:'doc_file'),
  'and the reading no longer waits');
select is(
  (select j->'rendition'->>'status'
   from jsonb_array_elements(private.ai_material_claim('dl078-reader-2', 10)) j
   where j->>'docId' = (select id::text from private.ai_material_docs
     where file_object_id = :'doc_file')),
  'ready', 'the reader now claims it with its ready copy');

-- A conversion the converter refused, with a code that is not a code.
select is(
  private.file_rendition_finish('dl078-converter', pg_temp.rendition(:'docx_file', 'pdf_preview'),
    jsonb_build_object('outcome', 'failed', 'code', '<b>File.docx</b>')),
  'recorded', 'a failure is recorded');
select is(
  (select status || ':' || last_error from private.file_renditions
   where id = pg_temp.rendition(:'docx_file', 'pdf_preview')),
  'failed:conversion_failed', 'with a fixed code, never what the worker sent');

-- The converter unavailable: retried later.
select is(
  private.file_rendition_finish('dl078-converter', pg_temp.rendition(:'csv_file', 'pdf_preview'),
    jsonb_build_object('outcome', 'retry', 'code', 'converter_unavailable')),
  'recorded', 'a passing failure is recorded');
select ok(
  (select status = 'queued' and next_attempt_at > now() and lease_until is null
     and last_error = 'converter_unavailable'
   from private.file_renditions where id = pg_temp.rendition(:'csv_file', 'pdf_preview')),
  'and queued again after a pause');

-- No converter: skipped, then queued again when there is one.
select is(
  private.file_rendition_finish('dl078-converter', pg_temp.rendition(:'doc_file', 'pdf_preview'),
    jsonb_build_object('outcome', 'skipped', 'code', 'converter_not_configured')),
  'recorded', 'a rendition with no converter is skipped');
select ok(private.file_rendition_requeue_skipped() >= 1,
  'skipped renditions are queued again once a converter is set');
select is(
  (select status from private.file_renditions
   where id = pg_temp.rendition(:'doc_file', 'pdf_preview')),
  'queued', 'including this one');
select is(
  private.file_rendition_finish('dl078-converter', gen_random_uuid(),
    '{"outcome":"ready"}'::jsonb),
  'gone', 'a rendition deleted meanwhile answers gone, so its object is removed');

-- ---------------------------------------------------------------------------
-- 6. Preview delivery, under the original's authorization.
-- ---------------------------------------------------------------------------
-- The .doc's preview is made.
update private.file_renditions set status = 'processing', worker_id = 'dl078-p'
where id = pg_temp.rendition(:'doc_file', 'pdf_preview');
select is(
  private.file_rendition_finish('dl078-p', pg_temp.rendition(:'doc_file', 'pdf_preview'),
    jsonb_build_object('outcome', 'ready', 'sha256', repeat('b', 64), 'sizeBytes', 4000)),
  'recorded', 'the .doc preview is stored');

select is(
  (select pg_temp.intent('aaaa0000-0000-4000-8000-000000000001', :'doc_file', 1, 'preview')
     ->'response'->>'mediaType'),
  'application/pdf', 'a ready preview is offered as a PDF');
select is(
  (select response->>'displayName' from (select pg_temp.intent(
     'aaaa0000-0000-4000-8000-000000000001', :'doc_file', 2, 'preview')->'response'
     as response) x),
  'Week 3 notes.pdf', 'under the file''s own name, as .pdf');
select is(
  (select variant from public.file_delivery_grants
   where nonce_hash = md5('nonce1') || md5('nonce:1')),
  'preview', 'the grant records that it is for the preview');
select is(
  (select pg_temp.consume('aaaa0000-0000-4000-8000-000000000001', :'doc_file', 1)
     ->'response'->>'objectKey'),
  (select storage_path from private.file_renditions
   where id = pg_temp.rendition(:'doc_file', 'pdf_preview')),
  'spending a preview grant serves the preview, not the original');
select is(
  (select pg_temp.intent('aaaa0000-0000-4000-8000-000000000001', :'doc_file', 3, 'original')
     ->'response'->>'mediaType'),
  'application/msword', 'the original is still the original');
select is(
  (select pg_temp.intent('aaaa0000-0000-4000-8000-000000000001', :'pdf_file', 4, 'preview')
     ->'response'->>'mediaType'),
  'application/pdf', 'a PDF is its own preview');
select is(
  (select variant from public.file_delivery_grants
   where nonce_hash = md5('nonce4') || md5('nonce:4')),
  'original', 'and is served as the original');
select is(
  pg_temp.intent('aaaa0000-0000-4000-8000-000000000001', :'docx_file', 5, 'preview')->>'outcome',
  'preview_unavailable', 'no ready preview is preview_unavailable');
select is(
  pg_temp.intent('aaaa0000-0000-4000-8000-000000000001', :'png_file', 6, 'preview')->>'outcome',
  'preview_unavailable', 'a picture has no preview');
select is(
  pg_temp.intent('eeee0000-0000-4000-8000-000000000005', :'doc_file', 7, 'preview')->>'outcome',
  pg_temp.intent('eeee0000-0000-4000-8000-000000000005', :'doc_file', 8, 'original')->>'outcome',
  'someone who may not download the original is refused the preview the same way');
select is(
  pg_temp.intent('aaaa0000-0000-4000-8000-000000000001', :'doc_file', 9, 'thumbnail')->>'outcome',
  'invalid', 'an unknown variant is invalid');

-- ---------------------------------------------------------------------------
-- 7. Renditions never outlive their file; their objects are swept.
-- ---------------------------------------------------------------------------
select pg_temp.upload(:'gone_file', 'application/vnd.ms-powerpoint', 'Old deck.ppt');
select pg_temp.clean(:'gone_file');
create temporary table gone_paths as
  select storage_path from private.file_renditions where file_object_id = :'gone_file';
update public.file_objects set scan_state = 'deleted', deleted_at = now(),
  physical_deleted_at = now() where id = :'gone_file';
select is(pg_temp.kinds(:'gone_file'), '{}'::text[],
  'a deleted file''s renditions go with it');
select is(
  (select count(*) from private.file_rendition_deletions d
   join gone_paths g on g.storage_path = d.storage_path where d.state = 'pending'),
  2::bigint, 'and both of their objects are queued for deletion');
select is(
  (select count(*) from private.file_rendition_deletions d
   join gone_paths g on g.storage_path = d.storage_path
   where d.id in (select (j->>'deletionId')::bigint from jsonb_array_elements(
     private.file_rendition_claim_deletions('dl078-sweeper', 100)) j)),
  2::bigint, 'the sweeper claims them');
select ok(
  private.file_rendition_finish_deletion('dl078-sweeper',
    (select d.id from private.file_rendition_deletions d
     join gone_paths g on g.storage_path = d.storage_path order by d.id limit 1),
    true, null),
  'the sweeper confirms one deletion');
select is(
  (select count(*) from private.file_rendition_deletions d
   join gone_paths g on g.storage_path = d.storage_path),
  1::bigint, 'a confirmed deletion leaves the queue');
select ok(
  private.file_rendition_finish_deletion('dl078-sweeper',
    (select d.id from private.file_rendition_deletions d
     join gone_paths g on g.storage_path = d.storage_path),
    false, 'STORAGE_UNAVAILABLE'),
  'a failed deletion is reported');
select is(
  (select state || ':' || last_error from private.file_rendition_deletions d
   join gone_paths g on g.storage_path = d.storage_path),
  'pending:STORAGE_UNAVAILABLE', 'and stays queued to be tried again');
-- A file that becomes a dedupe dependent is served from its root's copies.
update public.file_objects set dedup_source_file_id = :'docx_file'
where id = :'csv_file';
select is(pg_temp.kinds(:'csv_file'), '{}'::text[],
  'a dedupe dependent keeps no renditions of its own');

select * from finish();
rollback;
