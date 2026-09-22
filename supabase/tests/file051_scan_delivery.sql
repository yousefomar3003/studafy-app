-- FILE-051: scanning, publication, school-scoped dedupe, retention, delivery
-- grants and malicious-file containment. Synthetic fixtures only; the whole
-- suite runs in one transaction and rolls back.
begin;
create extension if not exists pgtap with schema extensions;
set local search_path=public,extensions;
select plan(99);

\set school_id '11111111-1111-4111-8111-111111111111'
\set other_school_id '22222222-2222-4222-8222-222222222222'
\set teacher_user 'aaaa0000-0000-4000-8000-000000000001'
\set other_school_user 'eeee0000-0000-4000-8000-000000000005'
\set unassigned_teacher_user 'ffff0000-0000-4000-8000-000000000005'
\set operator_user 'ffff0000-0000-4000-8000-000000000001'
\set term_id 'abce0000-0000-4000-8000-000000000006'
\set f_class 'f0510000-0000-4000-8000-0000000000c1'

-- ---------------------------------------------------------------------------
-- Fixture: one classroom with exactly thirty enrolled student accounts.
-- ---------------------------------------------------------------------------
insert into auth.users (
  id, email, encrypted_password, aud, role, email_confirmed_at, created_at,
  updated_at, instance_id, confirmation_token, recovery_token, email_change,
  email_change_token_new, email_change_token_current, phone_change_token,
  raw_app_meta_data, raw_user_meta_data)
select ('f0510000-0000-4000-8000-' || lpad(n::text, 12, '0'))::uuid,
  'file051.student' || n || '@synthetic.studafy.test', 'synthetic-not-a-secret',
  'authenticated', 'authenticated', now(), now(), now(),
  '00000000-0000-0000-0000-000000000000', '', '', '', '', '', '',
  '{}'::jsonb, jsonb_build_object('full_name', 'File051 Student ' || n)
from generate_series(1, 30) n;
insert into public.memberships (school_id, user_id, role, active)
select :'school_id', ('f0510000-0000-4000-8000-' || lpad(n::text, 12, '0'))::uuid, 'student', true
from generate_series(1, 30) n;
insert into public.students (id, school_id, user_id, studafy_id, display_name, provisional, created_by)
select ('f0510000-0000-4000-8001-' || lpad(n::text, 12, '0'))::uuid, :'school_id',
  ('f0510000-0000-4000-8000-' || lpad(n::text, 12, '0'))::uuid,
  'STU-F051-' || lpad(n::text, 4, '0'), 'File051 Student ' || n, false, :'teacher_user'
from generate_series(1, 30) n;
insert into public.classrooms (id, school_id, term_id, name, grade, section, teacher_id)
values (:'f_class', :'school_id', :'term_id', 'File051 Classroom', 'G7', 'F', :'teacher_user');
insert into public.classroom_staff (school_id, classroom_id, membership_id, user_id, role)
select :'school_id', :'f_class', m.id, :'teacher_user', 'lead_teacher'
from public.memberships m
where m.school_id = :'school_id' and m.user_id = :'teacher_user' and m.role = 'teacher';
insert into public.enrollments (classroom_id, student_id, active)
select :'f_class', ('f0510000-0000-4000-8001-' || lpad(n::text, 12, '0'))::uuid, true
from generate_series(1, 30) n;
insert into public.terms (id, school_id, name, starts_on, ends_on, active)
values ('f0510000-0000-4000-8000-0000000000c3', :'other_school_id', 'File051 Other Term', '2026-09-01', '2026-12-31', true);
insert into public.classrooms (id, school_id, term_id, name, grade, section, teacher_id)
values ('f0510000-0000-4000-8000-0000000000c2', :'other_school_id', 'f0510000-0000-4000-8000-0000000000c3',
  'File051 Other Classroom', 'G7', 'X', :'other_school_user');
insert into public.classroom_staff (school_id, classroom_id, membership_id, user_id, role)
select :'other_school_id', 'f0510000-0000-4000-8000-0000000000c2', m.id, :'other_school_user', 'lead_teacher'
from public.memberships m
where m.school_id = :'other_school_id' and m.user_id = :'other_school_user' and m.role = 'teacher';
insert into public.file_quota_policies (school_id, user_hourly_intents, user_active_sessions)
values (:'school_id', 1000, 1000), (:'other_school_id', 1000, 1000)
on conflict (school_id) do update set user_hourly_intents = 1000, user_active_sessions = 1000;

create function pg_temp.student(n integer) returns uuid language sql immutable as $$
  select ('f0510000-0000-4000-8000-' || lpad(n::text, 12, '0'))::uuid
$$;
create function pg_temp.as_user(p_user uuid, p_school uuid, p_request text) returns void
language sql as $$
  select set_config('request.jwt.claim.sub', p_user::text, true),
    set_config('studafy.school_id', coalesce(p_school::text, ''), true),
    set_config('studafy.request_id', p_request, true);
$$;
create function pg_temp.hex64(p_seed text) returns text language sql immutable as $$
  select md5(p_seed) || md5(p_seed || ':2')
$$;

-- Issues and completes one upload as the given owner; returns the file id.
create function pg_temp.upload(
  p_user uuid, p_school uuid, p_seq integer, p_sha text, p_media text,
  p_purpose text, p_class uuid default null)
returns uuid language plpgsql as $$
declare
  upload_id uuid := ('f0510000-0000-4000-8002-' || lpad(p_seq::text, 12, '0'))::uuid;
  reserve jsonb;
  result jsonb;
begin
  perform pg_temp.as_user(p_user, p_school, 'file051-upload-' || p_seq);
  reserve := private.api_idempotency_reserve(p_school, 'v1.createUploadIntent',
    'file051-intent-' || lpad(p_seq::text, 8, '0'), pg_temp.hex64('intent' || p_seq));
  result := private.api050_issue_intent(
    jsonb_build_object('schoolId', p_school, 'purpose', p_purpose,
      'displayName', 'file-' || p_seq || '.bin', 'expectedSizeBytes', 8,
      'declaredMediaType', p_media, 'sha256', p_sha, 'classroomId', p_class),
    jsonb_build_object('uploadId', upload_id, 'bucket', 'private-school-files',
      'objectKey', 'quarantine/v1/' || upload_id || '/' || rpad('key' || p_seq, 22, 'x'),
      'nonceHash', pg_temp.hex64('nonce' || p_seq),
      'uploadUrl', 'https://storage.invalid/upload-' || p_seq,
      'expiresAt', now() + interval '2 hours'),
    (reserve->>'id')::uuid, (reserve->>'generation')::bigint);
  if result->>'outcome' <> 'ok' then
    raise exception 'fixture intent % failed: %', p_seq, result;
  end if;
  reserve := private.api_idempotency_reserve(p_school, 'v1.completeUpload',
    'file051-complete-' || lpad(p_seq::text, 8, '0'), pg_temp.hex64('complete' || p_seq));
  result := private.api050_complete_upload(upload_id,
    jsonb_build_object('exists', true, 'sizeBytes', 8, 'detectedMediaType', p_media,
      'sha256', p_sha),
    (reserve->>'id')::uuid, (reserve->>'generation')::bigint);
  if result->>'outcome' <> 'ok' then
    raise exception 'fixture completion % failed: %', p_seq, result;
  end if;
  return (select file_object_id from public.upload_sessions where id = upload_id);
end;
$$;

-- Claims exactly the scan job of one file (others are parked) as a worker.
create function pg_temp.claim_scan(p_file uuid) returns jsonb language plpgsql as $$
declare claimed jsonb;
begin
  update public.file_job_outbox set available_at = now() + interval '1 day'
  where job_type = 'scan' and state in ('pending', 'retry') and file_object_id <> p_file;
  update public.file_job_outbox set available_at = now()
  where job_type = 'scan' and state in ('pending', 'retry') and file_object_id = p_file;
  claimed := private.api051_claim_scan('file051-test-worker', 100);
  if jsonb_array_length(claimed) <> 1 then
    raise exception 'expected one scan claim for %, got %', p_file, claimed;
  end if;
  return claimed->0;
end;
$$;

create function pg_temp.scan(p_file uuid, p_result jsonb) returns boolean language plpgsql as $$
declare claimed jsonb := pg_temp.claim_scan(p_file);
begin
  return private.api051_finish_scan('file051-test-worker', (claimed->>'jobId')::bigint, p_result);
end;
$$;

create function pg_temp.clean(p_stored text) returns jsonb language sql immutable as $$
  select jsonb_build_object('outcome', 'clean', 'scanPolicyVersion', 'file051-v1',
    'scanDurationMs', 4, 'storedSha256', p_stored, 'storedSizeBytes', 8)
$$;

create function pg_temp.grant_for(p_user uuid, p_school uuid, p_file uuid, p_seq integer,
  p_nonce_hash text, p_expires timestamptz default now() + interval '5 minutes')
returns jsonb language plpgsql as $$
declare reserve jsonb;
begin
  perform pg_temp.as_user(p_user, p_school, 'file051-grant-' || p_seq);
  reserve := private.api_idempotency_reserve(p_school, 'v1.createFileDownloadIntent',
    'file051-download-' || lpad(p_seq::text, 8, '0'), pg_temp.hex64('download' || p_seq));
  return private.api051_create_download_grant(p_file,
    jsonb_build_object('nonceHash', p_nonce_hash,
      'downloadUrl', 'https://api.studafy.test/delivery/v1/files/' || p_file || '/content?token=t' || p_seq,
      'expiresAt', p_expires),
    (reserve->>'id')::uuid, (reserve->>'generation')::bigint);
end;
$$;

create function pg_temp.publish(p_user uuid, p_school uuid, p_file uuid, p_seq integer)
returns jsonb language plpgsql as $$
declare reserve jsonb;
begin
  perform pg_temp.as_user(p_user, p_school, 'file051-publish-' || p_seq);
  reserve := private.api_idempotency_reserve(p_school, 'v1.publishFile',
    'file051-publish-' || lpad(p_seq::text, 8, '0'), pg_temp.hex64('publish' || p_seq));
  return private.api051_publish_file(p_file, '{"audience":"students"}'::jsonb,
    (reserve->>'id')::uuid, (reserve->>'generation')::bigint);
end;
$$;

create temporary table f051 (name text primary key, value jsonb);
create function pg_temp.id(p_name text) returns uuid language sql stable as $$
  select (value->>'id')::uuid from f051 where name = p_name
$$;

-- ---------------------------------------------------------------------------
-- 1. Privilege surface
-- ---------------------------------------------------------------------------
select is((select count(*) from information_schema.role_table_grants
  where grantee in ('studafy_api_runtime', 'studafy_worker_runtime')
    and table_name = 'file_delivery_grants'), 0::bigint,
  'no runtime role has a table grant on delivery grants');
select ok(not has_table_privilege('authenticated', 'public.file_delivery_grants', 'select'),
  'clients cannot read delivery grants');
select ok(has_function_privilege('studafy_api_runtime',
  'private.api051_consume_download_grant(uuid,text)', 'execute'),
  'API runtime may consume a delivery grant');
select ok(not has_function_privilege('studafy_api_runtime',
  'private.api051_claim_scan(text,integer)', 'execute'),
  'API runtime cannot claim scan jobs');
select ok(not has_function_privilege('studafy_worker_runtime',
  'private.api051_publish_file(uuid,jsonb,uuid,bigint)', 'execute'),
  'worker runtime cannot publish');
select ok(has_function_privilege('studafy_worker_runtime',
  'private.api051_record_transform(text,bigint,text,bigint,text)', 'execute'),
  'worker runtime may record a transform write-ahead');
select ok(has_schema_privilege('studafy_worker_runtime', 'private', 'usage')
  and not has_schema_privilege('studafy_worker_runtime', 'public', 'create'),
  'the worker runtime can reach its functions and nothing more');
select ok(not has_function_privilege('authenticated',
  'private.api051_consume_download_grant(uuid,text)', 'execute'),
  'clients cannot call delivery commands directly');
select ok(not has_function_privilege('studafy_api_runtime',
  'private.file051_contain_object(uuid,uuid,text)', 'execute')
  and not has_function_privilege('studafy_worker_runtime',
  'private.file051_contain_object(uuid,uuid,text)', 'execute'),
  'containment is operator-only');

-- ---------------------------------------------------------------------------
-- 2. Scan state machine
-- ---------------------------------------------------------------------------
insert into f051 values ('F1', jsonb_build_object('id',
  pg_temp.upload(:'teacher_user', :'school_id', 1, pg_temp.hex64('content-1'), 'application/pdf', 'lesson_resource', :'f_class')));
insert into f051 values ('F2', jsonb_build_object('id',
  pg_temp.upload(:'teacher_user', :'school_id', 2, pg_temp.hex64('content-2'), 'application/pdf', 'lesson_resource', :'f_class')));

insert into f051 values ('claim1', pg_temp.claim_scan(pg_temp.id('F1')));
select is((select value->>'objectKey' from f051 where name = 'claim1'),
  (select object_key from public.file_objects where id = pg_temp.id('F1')),
  'the scan claim hands over the immutable server-owned key');
select is((select scan_state::text from public.file_objects where id = pg_temp.id('F1')),
  'scanning', 'a claimed object is marked scanning, not clean');
select ok(not private.api051_record_transform('someone-else',
  (select (value->>'jobId')::bigint from f051 where name = 'claim1'),
  pg_temp.hex64('stored-1'), 8, 'file051-structural-strip-v1'),
  'a transform write-ahead from a non-claiming worker is refused');
select throws_ok(format($q$select private.api051_finish_scan('file051-test-worker', %s,
  '{"outcome":"clean","storedSha256":"%s","storedSizeBytes":8}'::jsonb)$q$,
  (select value->>'jobId' from f051 where name = 'claim1'), pg_temp.hex64('stored-1')),
  'FILE051_INVALID_CLEAN_RESULT', 'clean without a scan policy version is refused');
select throws_ok(format($q$select private.api051_finish_scan('file051-test-worker', %s,
  '{"outcome":"clean","scanPolicyVersion":"file051-v1","storedSizeBytes":8}'::jsonb)$q$,
  (select value->>'jobId' from f051 where name = 'claim1')),
  'FILE051_INVALID_CLEAN_RESULT', 'clean without a verified stored digest is refused');
select throws_ok(format($q$select private.api051_finish_scan('file051-test-worker', %s,
  '{"outcome":"rejected","scanPolicyVersion":"file051-v1"}'::jsonb)$q$,
  (select value->>'jobId' from f051 where name = 'claim1')),
  'FILE051_INVALID_REJECT_RESULT', 'a rejection must name its reason');
select ok(private.api051_finish_scan('file051-test-worker',
  (select (value->>'jobId')::bigint from f051 where name = 'claim1'),
  pg_temp.clean(pg_temp.hex64('stored-1'))), 'a clean verdict is accepted from the claiming worker');
select is((select scan_state::text || '/' || scan_policy_version || '/' || stored_sha256
  from public.file_objects where id = pg_temp.id('F1')),
  'clean/file051-v1/' || pg_temp.hex64('stored-1'),
  'clean records policy version and verified stored digest');
select ok((select retention_until is null from public.file_objects where id = pg_temp.id('F1')),
  'no retention horizon is invented while the schedule is undecided');
select is((select count(*) from public.audit_events
  where action = 'file_scan_clean' and entity_id = pg_temp.id('F1')), 1::bigint,
  'the clean transition is audited');
select ok(not private.api051_finish_scan('file051-test-worker',
  (select (value->>'jobId')::bigint from f051 where name = 'claim1'),
  pg_temp.clean(pg_temp.hex64('stored-1'))), 'a finished job cannot be finished twice');

-- ---------------------------------------------------------------------------
-- 3. Publication: one object, one resource, one version, one publication
-- ---------------------------------------------------------------------------
select is((pg_temp.publish(pg_temp.student(1), :'school_id', pg_temp.id('F1'), 1))->>'outcome',
  'not_found', 'a student cannot publish');
select is((pg_temp.publish(:'other_school_user', :'other_school_id', pg_temp.id('F1'), 2))->>'outcome',
  'not_found', 'another school cannot publish, and learns nothing');
select is((pg_temp.publish(:'teacher_user', :'school_id', pg_temp.id('F2'), 3))->>'outcome',
  'file_not_clean', 'a quarantined file cannot be published');

insert into f051 values ('counts-before', jsonb_build_object(
  'objects', (select count(*) from public.file_objects),
  'resources', (select count(*) from public.resources)));
insert into f051 values ('pub1', pg_temp.publish(:'teacher_user', :'school_id', pg_temp.id('F1'), 4));
select is((select value->>'outcome' from f051 where name = 'pub1'), 'ok',
  'the assigned teacher publishes a clean lesson file');
select is((select count(*) from public.file_objects), (select (value->>'objects')::bigint from f051 where name = 'counts-before'),
  'publication creates no file object (no copy)');
select is((select count(*) from public.resources), (select (value->>'resources')::bigint + 1 from f051 where name = 'counts-before'),
  'publication creates exactly one resource');
select is((select count(*) from public.resource_versions where file_object_id = pg_temp.id('F1')), 1::bigint,
  'publication creates exactly one immutable version');
select is((select count(*) from public.resource_publications rp
  join public.resource_versions rv on rv.id = rp.resource_version_id
  where rv.file_object_id = pg_temp.id('F1')), 1::bigint,
  'publication creates exactly one classroom publication');
select is((select count(*) from public.file_bindings
  where file_object_id = pg_temp.id('F1') and resource_version_id is not null), 1::bigint,
  'the object gets one live resource binding');
select is((pg_temp.publish(:'teacher_user', :'school_id', pg_temp.id('F1'), 5))->>'outcome',
  'invalid_state', 'the same object cannot be published twice');

create temporary table f051_access (n integer primary key, decision jsonb);
do $$
begin
  for n in 1..30 loop
    perform pg_temp.as_user(pg_temp.student(n), null, 'file051-access-' || n);
    insert into f051_access values (n, private.file051_authorize_download(
      (select (value->>'id')::uuid from f051 where name = 'F1')));
  end loop;
end;
$$;
select is((select count(*) from f051_access
  where decision->>'allowed' = 'true' and decision->>'reason' = 'publication'), 30::bigint,
  'all thirty enrolled students derive access from the one publication');
select is((select count(*) from public.file_objects
  where school_id = :'school_id' and sha256 = pg_temp.hex64('content-1')), 1::bigint,
  'thirty recipients share one physical object: no per-recipient copies exist');
select pg_temp.as_user(:'other_school_user', null, 'x');
select is((private.file051_authorize_download(pg_temp.id('F1')))->>'allowed', 'false',
  'another school has no derived access');
select pg_temp.as_user(pg_temp.student(1), null, 'x');
select is((private.authz_authorize('file.download', pg_temp.id('F1')))->>'allowed', 'true',
  'the AUTH-031 evaluator derives file.download from the publication');
select is((private.authz_authorize('file.publish', pg_temp.id('F1')))->>'allowed', 'false',
  'the AUTH-031 evaluator refuses file.publish to a student');

-- ---------------------------------------------------------------------------
-- 4. Delivery grants: single use, recipient bound, re-authorized at use
-- ---------------------------------------------------------------------------
select is((pg_temp.grant_for(pg_temp.student(1), :'school_id', pg_temp.id('F1'), 10,
  pg_temp.hex64('nonce-10'), now() + interval '11 minutes'))->>'outcome', 'invalid',
  'a grant longer than ten minutes is refused');
select is((pg_temp.grant_for(pg_temp.student(1), :'school_id', pg_temp.id('F2'), 11,
  pg_temp.hex64('nonce-11')))->>'outcome', 'not_found',
  'no grant for a file the caller cannot reach');
insert into f051 values ('grant1', pg_temp.grant_for(pg_temp.student(1), :'school_id', pg_temp.id('F1'), 12,
  pg_temp.hex64('nonce-12')));
select is((select value->>'outcome' from f051 where name = 'grant1'), 'ok',
  'an entitled student receives a grant');
select is((select nonce_hash from public.file_delivery_grants
  where file_object_id = pg_temp.id('F1') and recipient_id = pg_temp.student(1)),
  pg_temp.hex64('nonce-12'), 'the grant stores only the nonce hash, bound to the recipient');
select is((select response_status from public.idempotency_records
  where scope = 'v1.createFileDownloadIntent' and idempotency_key = 'file051-download-00000012'), 200,
  'grant and idempotency completion commit together');

select pg_temp.as_user(pg_temp.student(2), null, 'consume-a');
select is((private.api051_consume_download_grant(pg_temp.id('F1'), pg_temp.hex64('nonce-12')))->>'outcome',
  'grant_invalid', 'a leaked grant is useless to another entitled account');
select pg_temp.as_user(pg_temp.student(1), null, 'consume-b');
select is((private.api051_consume_download_grant(pg_temp.id('F2'), pg_temp.hex64('nonce-12')))->>'outcome',
  'grant_invalid', 'a grant cannot be replayed against another file');
insert into f051 values ('consume1', private.api051_consume_download_grant(pg_temp.id('F1'), pg_temp.hex64('nonce-12')));
select is((select value->>'outcome' from f051 where name = 'consume1'), 'ok',
  'the recipient consumes the grant once');
select is((select value->'response'->>'objectKey' from f051 where name = 'consume1'),
  (select object_key from public.file_objects where id = pg_temp.id('F1')),
  'consumption resolves the exact stored object');
select is((select value->'response'->>'storedSha256' from f051 where name = 'consume1'),
  pg_temp.hex64('stored-1'), 'consumption hands back the digest the server must verify');
select is((private.api051_consume_download_grant(pg_temp.id('F1'), pg_temp.hex64('nonce-12')))->>'outcome',
  'grant_invalid', 'a consumed grant never works twice');
select is((select count(*) from public.audit_events
  where action = 'file_download_delivered' and entity_id = pg_temp.id('F1')), 1::bigint,
  'each delivery is audited once');

-- Expiry.
select is((pg_temp.grant_for(pg_temp.student(5), :'school_id', pg_temp.id('F1'), 13,
  pg_temp.hex64('nonce-13')))->>'outcome', 'ok', 'expiry fixture grant issued');
update public.file_delivery_grants set expires_at = now() - interval '1 second'
where nonce_hash = pg_temp.hex64('nonce-13');
select pg_temp.as_user(pg_temp.student(5), null, 'consume-c');
select is((private.api051_consume_download_grant(pg_temp.id('F1'), pg_temp.hex64('nonce-13')))->>'outcome',
  'grant_invalid', 'an expired grant is refused');
select ok(private.api051_expire_delivery_grants() >= 1, 'the sweep marks expired grants');

-- Revocation after issue: enrollment ends.
select is((pg_temp.grant_for(pg_temp.student(3), :'school_id', pg_temp.id('F1'), 14,
  pg_temp.hex64('nonce-14')))->>'outcome', 'ok', 'revocation fixture grant issued');
update public.enrollments set active = false
where classroom_id = :'f_class' and student_id = 'f0510000-0000-4000-8001-000000000003';
select pg_temp.as_user(pg_temp.student(3), null, 'consume-d');
select is((private.api051_consume_download_grant(pg_temp.id('F1'), pg_temp.hex64('nonce-14')))->>'outcome',
  'not_found', 'a grant issued before enrollment ended is denied at use');

-- Withdrawal after issue.
select is((pg_temp.grant_for(pg_temp.student(4), :'school_id', pg_temp.id('F1'), 15,
  pg_temp.hex64('nonce-15')))->>'outcome', 'ok', 'withdrawal fixture grant issued');
update public.resource_publications rp set state = 'withdrawn', withdrawn_at = now()
from public.resource_versions rv
where rv.id = rp.resource_version_id and rv.file_object_id = pg_temp.id('F1');
select pg_temp.as_user(pg_temp.student(4), null, 'consume-e');
select is((private.api051_consume_download_grant(pg_temp.id('F1'), pg_temp.hex64('nonce-15')))->>'outcome',
  'not_found', 'a grant issued before withdrawal is denied at use');

-- ---------------------------------------------------------------------------
-- 5. School-scoped deduplication
-- ---------------------------------------------------------------------------
insert into f051 values ('D1', jsonb_build_object('id',
  pg_temp.upload(:'teacher_user', :'school_id', 20, pg_temp.hex64('dup'), 'application/pdf', 'lesson_resource', :'f_class')));
insert into f051 values ('D2', jsonb_build_object('id',
  pg_temp.upload(:'teacher_user', :'school_id', 21, pg_temp.hex64('dup'), 'application/pdf', 'lesson_resource', :'f_class')));
insert into f051 values ('D3', jsonb_build_object('id',
  pg_temp.upload(:'other_school_user', :'other_school_id', 22, pg_temp.hex64('dup'), 'application/pdf',
    'lesson_resource', 'f0510000-0000-4000-8000-0000000000c2')));
insert into f051 values ('D4', jsonb_build_object('id',
  pg_temp.upload(:'teacher_user', :'school_id', 23, pg_temp.hex64('dup'), 'application/pdf', 'lesson_resource', :'f_class')));
select ok(pg_temp.scan(pg_temp.id('D1'), pg_temp.clean(pg_temp.hex64('dup-stored'))), 'dedupe root scanned clean');
select ok(pg_temp.scan(pg_temp.id('D2'), pg_temp.clean(pg_temp.hex64('dup-stored'))), 'duplicate scanned clean');
select is((select dedup_source_file_id from public.file_objects where id = pg_temp.id('D2')), pg_temp.id('D1'),
  'a same-school, same-purpose duplicate points at the canonical root');
select is((select count(*) from public.file_job_outbox
  where file_object_id = pg_temp.id('D2') and job_type = 'dedupe_delete'), 1::bigint,
  'the duplicate''s redundant bytes are queued for exact-key deletion');
select ok(pg_temp.scan(pg_temp.id('D3'), pg_temp.clean(pg_temp.hex64('dup-stored'))),
  'the other school''s identical file scans exactly like any other');
select ok((select dedup_source_file_id is null from public.file_objects where id = pg_temp.id('D3'))
  and not exists (select 1 from public.file_job_outbox where file_object_id = pg_temp.id('D3') and job_type = 'dedupe_delete')
  and (select after_value->>'deduplicated' from public.audit_events
       where action = 'file_scan_clean' and entity_id = pg_temp.id('D3')) = 'false',
  'dedupe never crosses schools and records nothing that reveals the other tenant');
select ok(pg_temp.scan(pg_temp.id('D4'), pg_temp.clean(pg_temp.hex64('dup-other-transform'))
  || '{"transformPolicyVersion":"file051-structural-strip-v2"}'::jsonb), 'a different transform result scans clean');
select ok((select dedup_source_file_id is null from public.file_objects where id = pg_temp.id('D4')),
  'objects whose stored bytes differ are never merged');

select is((pg_temp.publish(:'teacher_user', :'school_id', pg_temp.id('D2'), 24))->>'outcome', 'ok',
  'a deduplicated file publishes like any other');
select is((pg_temp.grant_for(pg_temp.student(6), :'school_id', pg_temp.id('D2'), 25,
  pg_temp.hex64('nonce-25')))->>'outcome', 'ok', 'dependent grant issued');
select pg_temp.as_user(pg_temp.student(6), null, 'consume-f');
select is((private.api051_consume_download_grant(pg_temp.id('D2'), pg_temp.hex64('nonce-25')))->'response'->>'objectKey',
  (select object_key from public.file_objects where id = pg_temp.id('D1')),
  'a dependent is served from its canonical root''s bytes');

create temporary table f051_cleanup as
select private.api050_claim_cleanup('file051-cleanup-worker', 20) as jobs;
select is((select j->>'objectKey' from f051_cleanup, jsonb_array_elements(jobs) j
  where j->>'jobType' = 'dedupe_delete'),
  (select object_key from public.file_objects where id = pg_temp.id('D2')),
  'the dedupe deleter targets the dependent''s own key, never the root''s');
select ok(private.api050_finish_cleanup('file051-cleanup-worker',
  (select (j->>'jobId')::bigint from f051_cleanup, jsonb_array_elements(jobs) j where j->>'jobType' = 'dedupe_delete'),
  true, null), 'dedupe deletion is acknowledged');
select is((select scan_state::text || '/' || (physical_deleted_at is not null)::text
  from public.file_objects where id = pg_temp.id('D2')), 'clean/true',
  'the dependent stays clean with its physical deletion recorded');

-- ---------------------------------------------------------------------------
-- 6. Rejection, legal hold and dead letters
-- ---------------------------------------------------------------------------
insert into f051 values ('R1', jsonb_build_object('id',
  pg_temp.upload(:'teacher_user', :'school_id', 30, pg_temp.hex64('eicar'), 'application/pdf', 'lesson_resource', :'f_class')));
select ok(pg_temp.scan(pg_temp.id('R1'), '{"outcome":"rejected","errorCode":"malware_detected","scanPolicyVersion":"file051-v1"}'),
  'the EICAR-equivalent object is rejected');
select is((select scan_state::text || '/' || scan_error_code from public.file_objects where id = pg_temp.id('R1')),
  'rejected/malware_detected', 'the rejection and its reason are recorded');
select is((select count(*) from public.file_job_outbox where file_object_id = pg_temp.id('R1') and job_type = 'delete'),
  1::bigint, 'a rejected object is queued for exact-key deletion');
select is((pg_temp.publish(:'teacher_user', :'school_id', pg_temp.id('R1'), 31))->>'outcome', 'file_not_clean',
  'a rejected object can never be published');
select is((pg_temp.grant_for(:'teacher_user', :'school_id', pg_temp.id('R1'), 32,
  pg_temp.hex64('nonce-32')))->>'outcome', 'file_not_clean',
  'a rejected object can never be delivered, not even to its owner');

insert into f051 values ('R2', jsonb_build_object('id',
  pg_temp.upload(:'teacher_user', :'school_id', 33, pg_temp.hex64('held'), 'application/pdf', 'lesson_resource', :'f_class')));
update public.file_objects set legal_hold = true where id = pg_temp.id('R2');
select ok(pg_temp.scan(pg_temp.id('R2'), '{"outcome":"rejected","errorCode":"malware_detected","scanPolicyVersion":"file051-v1"}'),
  'a held object can still be rejected');
select is((select count(*) from public.file_job_outbox where file_object_id = pg_temp.id('R2') and job_type = 'delete'),
  0::bigint, 'a held object''s bytes are kept as evidence');

insert into f051 values ('R3', jsonb_build_object('id',
  pg_temp.upload(:'teacher_user', :'school_id', 34, pg_temp.hex64('outage'), 'application/pdf', 'lesson_resource', :'f_class')));
do $$
declare file_id uuid := (select (value->>'id')::uuid from f051 where name = 'R3');
begin
  for attempt in 1..10 loop
    perform pg_temp.scan(file_id, '{"outcome":"retry","errorCode":"SCAN_INFRASTRUCTURE"}');
  end loop;
end;
$$;
select is((select state::text from public.file_job_outbox where file_object_id = pg_temp.id('R3') and job_type = 'scan'),
  'dead_letter', 'a persistent scanner outage dead-letters the job');
select is((select scan_state::text from public.file_objects where id = pg_temp.id('R3')), 'error',
  'scanner outage ends in error, never clean');

-- ---------------------------------------------------------------------------
-- 7. Retention: one physical object at a time, only when fully eligible
-- ---------------------------------------------------------------------------
update public.file_objects set retention_until = now() - interval '1 day'
where id in (pg_temp.id('D1'), pg_temp.id('D2'), pg_temp.id('D4'));
select is(jsonb_array_length(private.api051_claim_retention('file051-retention-worker', 10)
  -> 0 -> 'memberFileIds' ), 1,
  'the unreferenced root with no dependents is claimable on its own');
-- D1/D2 are blocked by D2's live publication.
select is((select count(*) from public.file_job_outbox
  where job_type = 'retention_delete' and file_object_id = pg_temp.id('D1')), 0::bigint,
  'a live reference on any dependent blocks the whole physical object');
update public.resources r set state = 'archived'
from public.resource_versions rv
where rv.resource_id = r.id and rv.file_object_id = pg_temp.id('D2');
update public.file_objects set legal_hold = true where id = pg_temp.id('D2');
select is(jsonb_array_length(private.api051_claim_retention('file051-retention-worker', 10)), 0,
  'a legal hold on any member blocks the whole physical object');
update public.file_objects set legal_hold = false where id = pg_temp.id('D2');
insert into f051 values ('retention', private.api051_claim_retention('file051-retention-worker', 10) -> 0);
select is((select value->>'rootFileId' from f051 where name = 'retention')::uuid, pg_temp.id('D1'),
  'retention claims the root once every member is eligible');
select is((select value->'memberFileIds' from f051 where name = 'retention'),
  to_jsonb(array[pg_temp.id('D1'), pg_temp.id('D2')]),
  'the claim covers exactly the root and its dependent');
select is((select scan_state::text from public.file_objects where id = pg_temp.id('D1')), 'clean',
  'nothing is marked deleted before storage confirms');
select ok(private.api051_finish_retention('file051-retention-worker',
  (select (value->>'jobId')::bigint from f051 where name = 'retention'), true, null),
  'retention deletion is acknowledged');
select is((select count(*) from public.file_objects
  where id in (pg_temp.id('D1'), pg_temp.id('D2')) and scan_state = 'deleted'
    and deleted_at is not null and physical_deleted_at is not null), 2::bigint,
  'root and dependent are recorded deleted together after confirmation');

-- ---------------------------------------------------------------------------
-- 8. Malicious-file containment and release
-- ---------------------------------------------------------------------------
insert into f051 values ('M1', jsonb_build_object('id',
  pg_temp.upload(:'teacher_user', :'school_id', 40, pg_temp.hex64('late-detect'), 'application/pdf', 'lesson_resource', :'f_class')));
select ok(pg_temp.scan(pg_temp.id('M1'), pg_temp.clean(pg_temp.hex64('late-detect-stored'))), 'object initially scans clean');
select is((pg_temp.publish(:'teacher_user', :'school_id', pg_temp.id('M1'), 41))->>'outcome', 'ok',
  'and is published to the class');
select is((pg_temp.grant_for(pg_temp.student(7), :'school_id', pg_temp.id('M1'), 42,
  pg_temp.hex64('nonce-42')))->>'outcome', 'ok', 'a student holds an outstanding grant');
insert into f051 values ('contain', private.file051_contain_object(pg_temp.id('M1'), :'operator_user', 'provider signature update'));
select is((select (value->>'publicationsWithdrawn')::int || '/' || (value->>'grantsExpired')::int
  from f051 where name = 'contain'), '1/1',
  'containment withdraws the publication and expires outstanding grants');
select is((select scan_state::text || '/' || scan_error_code || '/' || legal_hold::text
  from public.file_objects where id = pg_temp.id('M1')), 'error/operator_contained/true',
  'the object leaves clean and is held as evidence');
select pg_temp.as_user(pg_temp.student(7), null, 'consume-g');
select is((private.api051_consume_download_grant(pg_temp.id('M1'), pg_temp.hex64('nonce-42')))->>'outcome',
  'grant_invalid', 'the outstanding link is dead immediately');
select is((pg_temp.grant_for(:'teacher_user', :'school_id', pg_temp.id('M1'), 43,
  pg_temp.hex64('nonce-43')))->>'outcome', 'file_not_clean', 'no new link can be issued, even to the owner');
select is((select count(*) from jsonb_array_elements(private.api050_claim_cleanup('file051-cleanup-worker', 20)) j
  where (j->>'fileId')::uuid = pg_temp.id('M1')), 0::bigint,
  'held evidence is never handed to the deleter');
select is((private.file051_release_contained_object(pg_temp.id('M1'), :'operator_user'))->>'deletesQueued', '1',
  'release queues exact-key deletion');
create temporary table f051_release as
select j from jsonb_array_elements(private.api050_claim_cleanup('file051-cleanup-worker', 20)) j
where (j->>'fileId')::uuid = (select (value->>'id')::uuid from f051 where name = 'M1');
select ok(private.api050_finish_cleanup('file051-cleanup-worker',
  (select (j->>'jobId')::bigint from f051_release), true, null), 'the released object is deleted');
select is((select scan_state::text from public.file_objects where id = pg_temp.id('M1')), 'deleted',
  'the contained object ends deleted after storage confirmation');
select is((select count(*) from public.audit_events
  where action in ('file_contained', 'file_containment_released') and actor_id = :'operator_user'), 2::bigint,
  'containment and release are both attributed to the operator');

-- ---------------------------------------------------------------------------
-- 9. Observability
-- ---------------------------------------------------------------------------
select ok((private.api051_scan_backlog()) ?& array['quarantined', 'oldestQuarantineSeconds',
  'scanDeadLetters', 'deleteDeadLetters', 'dedupeBytesPending'],
  'the backlog report exposes the runbook signals');
select ok((private.api051_scan_backlog()->>'scanDeadLetters')::int >= 1,
  'the dead-lettered scan is visible');

select * from finish();
rollback;
