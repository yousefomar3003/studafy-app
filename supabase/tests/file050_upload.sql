begin;
create extension if not exists pgtap with schema extensions;
set local search_path=public,extensions;
select plan(36);

\set school_id '11111111-1111-4111-8111-111111111111'
\set other_school_id '22222222-2222-4222-8222-222222222222'
\set teacher_user 'aaaa0000-0000-4000-8000-000000000001'
\set upload_id 'f0500000-0000-4000-8000-000000000001'

select is((select count(*) from information_schema.role_table_grants where grantee='studafy_api_runtime'),0::bigint,
  'FILE-050 leaves API runtime with zero table grants');
select ok(has_function_privilege('studafy_api_runtime','private.api050_issue_intent(jsonb,jsonb,uuid,bigint)','execute'),
  'API runtime can execute only the narrow intent command');
select ok(not has_function_privilege('authenticated','private.api050_issue_intent(jsonb,jsonb,uuid,bigint)','execute'),
  'authenticated clients cannot invoke file commands directly');
select is((select count(*) from pg_policies where schemaname='storage' and tablename='objects' and cmd='INSERT'),0::bigint,
  'no direct authenticated storage insert policy is restored');

select set_config('request.jwt.claim.sub',:'teacher_user',true);
select set_config('studafy.school_id',:'school_id',true);
select set_config('studafy.request_id','f0500000-0000-4000-8000-000000000099',true);

create temporary table f050_results(name text primary key,result jsonb);
insert into f050_results values('oversize',private.api050_prepare_intent(jsonb_build_object(
  'schoolId',:'school_id','purpose','profile_image','displayName','large.png','expectedSizeBytes',5242881,
  'declaredMediaType','image/png','sha256',repeat('a',64))));
select is((select result->>'outcome' from f050_results where name='oversize'),'size_limit','oversized intent is rejected before signing');
insert into f050_results values('bad-type',private.api050_prepare_intent(jsonb_build_object(
  'schoolId',:'school_id','purpose','profile_image','displayName','bad.pdf','expectedSizeBytes',8,
  'declaredMediaType','application/pdf','sha256',repeat('a',64))));
select is((select result->>'outcome' from f050_results where name='bad-type'),'type_not_allowed','purpose type allowlist is enforced');
insert into f050_results values('cross-tenant',private.api050_prepare_intent(jsonb_build_object(
  'schoolId',:'other_school_id','purpose','profile_image','displayName','x.png','expectedSizeBytes',8,
  'declaredMediaType','image/png','sha256',repeat('a',64))));
select is((select result->>'outcome' from f050_results where name='cross-tenant'),'not_found','cross-tenant binding is concealed');

insert into f050_results values('reserve',private.api_idempotency_reserve(
  :'school_id','v1.createUploadIntent','file050-intent-key-001',repeat('1',64)));
insert into f050_results values('issue',private.api050_issue_intent(
  jsonb_build_object('schoolId',:'school_id','purpose','profile_image','displayName','avatar.png',
    'expectedSizeBytes',8,'declaredMediaType','image/png','sha256',repeat('a',64)),
  jsonb_build_object('uploadId',:'upload_id','bucket','private-school-files',
    'objectKey','quarantine/v1/'||:'upload_id'||'/abcdefghijklmnopqrstuv',
    'nonceHash',repeat('b',64),'uploadUrl','https://storage.invalid/upload',
    'expiresAt',now()+interval '2 hours'),
  ((select result->>'id' from f050_results where name='reserve')::uuid),1));
select is((select result->>'outcome' from f050_results where name='issue'),'ok','authorized upload intent is issued');
select is((select state::text from public.upload_sessions where id=:'upload_id'),'initiated','intent reserves one active session');
select is((select object_key from public.upload_sessions where id=:'upload_id'),
  'quarantine/v1/'||:'upload_id'||'/abcdefghijklmnopqrstuv','only the server-provided quarantine key is persisted');
select is((select status from public.idempotency_records where id=((select result->>'id' from f050_results where name='reserve')::uuid)),
  'completed','intent and idempotency response commit together');
select is((select count(*) from public.audit_events where request_id='f0500000-0000-4000-8000-000000000099'),1::bigint,
  'intent writes one redacted audit event');

update public.file_quota_policies set user_active_sessions=1 where school_id=:'school_id';
insert into f050_results values('reserve2',private.api_idempotency_reserve(
  :'school_id','v1.createUploadIntent','file050-intent-key-002',repeat('2',64)));
insert into f050_results values('concurrency',private.api050_issue_intent(
  jsonb_build_object('schoolId',:'school_id','purpose','profile_image','displayName','two.png',
    'expectedSizeBytes',8,'declaredMediaType','image/png','sha256',repeat('a',64)),
  jsonb_build_object('uploadId','f0500000-0000-4000-8000-000000000002','bucket','private-school-files',
    'objectKey','quarantine/v1/f0500000-0000-4000-8000-000000000002/bcdefghijklmnopqrstuvw',
    'nonceHash',repeat('c',64),'uploadUrl','https://storage.invalid/upload-two','expiresAt',now()+interval '2 hours'),
  ((select result->>'id' from f050_results where name='reserve2')::uuid),1));
select is((select result->>'outcome' from f050_results where name='concurrency'),'concurrency_limit','active-session quota is serialized and enforced');
select is((select count(*) from public.upload_sessions where owner_id=:'teacher_user' and policy_version='file050-v1'),1::bigint,
  'failed quota check creates no second reservation');

insert into f050_results values('complete-reserve',private.api_idempotency_reserve(
  :'school_id','v1.completeUpload','file050-complete-key1',repeat('3',64)));
insert into f050_results values('complete',private.api050_complete_upload(:'upload_id',
  jsonb_build_object('exists',true,'sizeBytes',8,'detectedMediaType','image/png','sha256',repeat('a',64)),
  ((select result->>'id' from f050_results where name='complete-reserve')::uuid),1));
select is((select result->>'outcome' from f050_results where name='complete'),'ok','matching object completes');
select is((select scan_state::text from public.file_objects where id=(select file_object_id from public.upload_sessions where id=:'upload_id')),
  'quarantined','completed object remains quarantined');
select is((select count(*) from public.file_bindings where upload_session_id=:'upload_id'),1::bigint,'object receives one durable session binding');
select is((select count(*) from public.file_job_outbox where upload_session_id=:'upload_id' and job_type='scan'),1::bigint,'completion emits one scan outbox job');

update public.file_quota_policies set user_hourly_intents=30,user_active_sessions=3 where school_id=:'school_id';
insert into f050_results values('type-intent-reserve',private.api_idempotency_reserve(
  :'school_id','v1.createUploadIntent','file050-type-intent-004',repeat('5',64)));
insert into f050_results values('type-intent',private.api050_issue_intent(
  jsonb_build_object('schoolId',:'school_id','purpose','profile_image','displayName','wrong-magic.png',
    'expectedSizeBytes',8,'declaredMediaType','image/png','sha256',repeat('a',64)),
  jsonb_build_object('uploadId','f0500000-0000-4000-8000-000000000004','bucket','private-school-files',
    'objectKey','quarantine/v1/f0500000-0000-4000-8000-000000000004/defghijklmnopqrstuvwxy',
    'nonceHash',repeat('e',64),'uploadUrl','https://storage.invalid/upload-four','expiresAt',now()+interval '2 hours'),
  ((select result->>'id' from f050_results where name='type-intent-reserve')::uuid),1));
select is((select result->>'outcome' from f050_results where name='type-intent'),'ok','type-mismatch fixture receives an exact reservation');
insert into f050_results values('type-complete-reserve',private.api_idempotency_reserve(
  :'school_id','v1.completeUpload','file050-type-complete-004',repeat('6',64)));
insert into f050_results values('type-complete',private.api050_complete_upload(
  'f0500000-0000-4000-8000-000000000004',
  jsonb_build_object('exists',true,'sizeBytes',8,'detectedMediaType','application/pdf','sha256',repeat('a',64)),
  ((select result->>'id' from f050_results where name='type-complete-reserve')::uuid),1));
select is((select result->>'code' from f050_results where name='type-complete'),'UPLOAD_TYPE_MISMATCH','magic-type mismatch is rejected');
select is((select state::text from public.upload_sessions where id='f0500000-0000-4000-8000-000000000004'),'rejected','type mismatch makes the session terminal');
select is((select scan_state::text from public.file_objects where id=(select file_object_id from public.upload_sessions where id='f0500000-0000-4000-8000-000000000004')),
  'rejected','type-mismatched bytes never enter quarantine');
select is((select count(*) from public.file_job_outbox where upload_session_id='f0500000-0000-4000-8000-000000000004' and job_type='delete'),1::bigint,
  'type mismatch enqueues exact-object deletion');

insert into f050_results values('size-intent-reserve',private.api_idempotency_reserve(
  :'school_id','v1.createUploadIntent','file050-size-intent-005',repeat('7',64)));
insert into f050_results values('size-intent',private.api050_issue_intent(
  jsonb_build_object('schoolId',:'school_id','purpose','profile_image','displayName','wrong-size.png',
    'expectedSizeBytes',8,'declaredMediaType','image/png','sha256',repeat('a',64)),
  jsonb_build_object('uploadId','f0500000-0000-4000-8000-000000000005','bucket','private-school-files',
    'objectKey','quarantine/v1/f0500000-0000-4000-8000-000000000005/efghijklmnopqrstuvwxyz',
    'nonceHash',repeat('f',64),'uploadUrl','https://storage.invalid/upload-five','expiresAt',now()+interval '2 hours'),
  ((select result->>'id' from f050_results where name='size-intent-reserve')::uuid),1));
insert into f050_results values('size-complete-reserve',private.api_idempotency_reserve(
  :'school_id','v1.completeUpload','file050-size-complete-005',repeat('8',64)));
insert into f050_results values('size-complete',private.api050_complete_upload(
  'f0500000-0000-4000-8000-000000000005',
  jsonb_build_object('exists',true,'sizeBytes',9,'detectedMediaType','image/png','sha256',repeat('a',64)),
  ((select result->>'id' from f050_results where name='size-complete-reserve')::uuid),1));
select is((select result->>'code' from f050_results where name='size-complete'),'UPLOAD_SIZE_MISMATCH','observed-size mismatch is rejected');
select is((select response_status from public.idempotency_records where id=((select result->>'id' from f050_results where name='size-complete-reserve')::uuid)),422,
  'deterministic mismatch and idempotency completion commit together');

create temporary table f050_claim as
select private.api050_claim_cleanup('file050-test-worker',20) as jobs;
select is(jsonb_array_length((select jobs from f050_claim)),2,'cleanup worker claims only the two delete jobs');
select is((select jobs->0->>'objectKey' from f050_claim),
  'quarantine/v1/f0500000-0000-4000-8000-000000000004/defghijklmnopqrstuvwxy',
  'cleanup claim resolves the immutable server-owned exact key');
select ok(private.api050_finish_cleanup('file050-test-worker',((select jobs->0->>'jobId' from f050_claim)::bigint),true,null),
  'cleanup acknowledgement succeeds only for the claiming worker');
select is((select scan_state::text from public.file_objects where id=((select jobs->0->>'fileId' from f050_claim)::uuid)),
  'deleted','database deletion is recorded only after worker acknowledgement');

-- The second claimed job exercises the failure branch: a delete that storage
-- refuses must move to retry with backoff, not raise. The enum cast in that
-- branch is load-bearing, so it is asserted rather than assumed.
select ok(private.api050_finish_cleanup('file050-test-worker',((select jobs->1->>'jobId' from f050_claim)::bigint),false,'STORAGE_UNAVAILABLE'),
  'a failed deletion is acknowledged without raising');
select is((select state::text from public.file_job_outbox where id=((select jobs->1->>'jobId' from f050_claim)::bigint)),
  'retry','a failed deletion is rescheduled for retry');
select is((select last_error_code from public.file_job_outbox where id=((select jobs->1->>'jobId' from f050_claim)::bigint)),
  'STORAGE_UNAVAILABLE','the retry records why the deletion failed');
select is((select scan_state::text from public.file_objects where id=((select jobs->1->>'fileId' from f050_claim)::uuid)),
  'rejected','a failed deletion never records the object as deleted');

update public.file_quota_policies set user_hourly_intents=1,user_active_sessions=3 where school_id=:'school_id';
insert into f050_results values('reserve3',private.api_idempotency_reserve(
  :'school_id','v1.createUploadIntent','file050-intent-key-003',repeat('4',64)));
insert into f050_results values('quota',private.api050_issue_intent(
  jsonb_build_object('schoolId',:'school_id','purpose','profile_image','displayName','three.png',
    'expectedSizeBytes',8,'declaredMediaType','image/png','sha256',repeat('a',64)),
  jsonb_build_object('uploadId','f0500000-0000-4000-8000-000000000003','bucket','private-school-files',
    'objectKey','quarantine/v1/f0500000-0000-4000-8000-000000000003/cdefghijklmnopqrstuvwx',
    'nonceHash',repeat('d',64),'uploadUrl','https://storage.invalid/upload-three','expiresAt',now()+interval '2 hours'),
  ((select result->>'id' from f050_results where name='reserve3')::uuid),1));
select is((select result->>'outcome' from f050_results where name='quota'),'quota_exceeded','rolling intent quota is enforced before issuance');

select is(private.api050_query('createFileDownloadIntent',(select file_object_id from public.upload_sessions where id=:'upload_id'))->>'outcome',
  'file_not_clean','quarantined objects cannot receive download intents');

select set_config('request.jwt.claim.sub','eeee0000-0000-4000-8000-000000000005',true);
select set_config('studafy.school_id',:'other_school_id',true);
select is(private.api050_prepare_completion(:'upload_id')->>'outcome','not_found','another tenant cannot resolve the server-owned object path');

select * from finish();
rollback;
