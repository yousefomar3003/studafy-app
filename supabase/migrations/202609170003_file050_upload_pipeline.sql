-- FILE-050: authenticated, purpose-bound upload reservations and quarantine.
-- No object becomes clean or deliverable in this migration.

alter type public.upload_session_state add value if not exists 'rejected';

do $$ begin
  create type public.file_purpose as enum (
    'profile_image', 'lesson_resource', 'assignment_material',
    'assignment_submission', 'paper_scan', 'coach_attachment'
  );
exception when duplicate_object then null;
end $$;

create table public.file_purpose_policies (
  purpose public.file_purpose primary key,
  policy_version text not null,
  maximum_size_bytes bigint not null check (maximum_size_bytes > 0 and maximum_size_bytes <= 26214400),
  allowed_media_types text[] not null check (cardinality(allowed_media_types) > 0),
  enabled boolean not null default true,
  updated_at timestamptz not null default now()
);

insert into public.file_purpose_policies(purpose, policy_version, maximum_size_bytes, allowed_media_types)
values
  ('profile_image', 'file050-v1', 5242880, array['image/jpeg','image/png','image/webp']),
  ('lesson_resource', 'file050-v1', 26214400, array['application/pdf','image/jpeg','image/png']),
  ('assignment_material', 'file050-v1', 10485760, array['application/pdf','image/jpeg','image/png']),
  ('assignment_submission', 'file050-v1', 10485760, array['application/pdf','image/jpeg','image/png']),
  ('paper_scan', 'file050-v1', 26214400, array['application/pdf','image/jpeg','image/png']),
  ('coach_attachment', 'file050-v1', 10485760, array['application/pdf','image/jpeg','image/png'])
on conflict (purpose) do update set
  policy_version=excluded.policy_version,
  maximum_size_bytes=excluded.maximum_size_bytes,
  allowed_media_types=excluded.allowed_media_types,
  enabled=excluded.enabled,
  updated_at=now();

alter table public.file_purpose_policies enable row level security;

create table public.file_quota_policies (
  school_id uuid primary key references public.schools(id) on delete cascade,
  user_rolling_bytes bigint not null default 104857600 check (user_rolling_bytes > 0),
  school_rolling_bytes bigint not null default 1073741824 check (school_rolling_bytes > 0),
  school_stored_bytes bigint not null default 21474836480 check (school_stored_bytes > 0),
  school_live_objects integer not null default 10000 check (school_live_objects > 0),
  user_hourly_intents integer not null default 30 check (user_hourly_intents > 0),
  user_active_sessions integer not null default 3 check (user_active_sessions > 0),
  updated_at timestamptz not null default now()
);
insert into public.file_quota_policies(school_id)
select id from public.schools on conflict do nothing;

alter table public.file_quota_policies enable row level security;

create or replace function private.file050_seed_school_quota()
returns trigger language plpgsql security definer set search_path='' as $$
begin
  insert into public.file_quota_policies(school_id) values(new.id) on conflict do nothing;
  return new;
end;
$$;
create trigger file050_seed_school_quota
after insert on public.schools for each row execute function private.file050_seed_school_quota();

alter table public.file_objects
  alter column sha256 drop not null,
  add column owner_id uuid references public.profiles(id) on delete restrict,
  add column owner_membership_id uuid,
  add column purpose public.file_purpose,
  add column display_name text,
  add column policy_version text not null default 'legacy';

update public.file_objects f set
  owner_id=f.uploader_id,
  owner_membership_id=(select m.id from public.memberships m where m.school_id=f.school_id and m.user_id=f.uploader_id order by m.active desc,m.created_at limit 1),
  purpose=coalesce((
    select case
      when b.ai_grading_draft_id is not null then 'paper_scan'::public.file_purpose
      when b.submission_attempt_id is not null then 'assignment_submission'::public.file_purpose
      else 'lesson_resource'::public.file_purpose end
    from public.file_bindings b where b.file_object_id=f.id limit 1
  ), 'lesson_resource'::public.file_purpose),
  display_name='legacy-file';

alter table public.file_objects
  add constraint file050_file_owner_school_fk foreign key(school_id,owner_membership_id,owner_id)
    references public.memberships(school_id,id,user_id) on delete restrict not valid,
  add constraint file050_file_metadata_check check (
    policy_version='legacy' or (
      owner_id is not null and owner_membership_id is not null and purpose is not null and
      display_name is not null and length(display_name) between 1 and 255
    )
  ) not valid,
  add constraint file050_file_hash_state_check check (
    scan_state in ('rejected','error','deleted') or sha256 is not null
  ) not valid,
  add constraint file050_file_bucket_check check (
    policy_version='legacy' or (bucket='private-school-files' and object_key ~ '^quarantine/v1/[0-9a-f-]{36}/[A-Za-z0-9_-]{22,64}$')
  ) not valid;

alter table public.upload_sessions
  add column bucket text,
  add column object_key text,
  add column owner_id uuid references public.profiles(id) on delete restrict,
  add column owner_membership_id uuid,
  add column display_name text,
  add column declared_media_type text,
  add column expected_sha256 text,
  add column policy_version text not null default 'legacy',
  add column classroom_id uuid,
  add column assignment_id uuid,
  add column student_id uuid,
  add column grade_result_id uuid,
  add column actual_size_bytes bigint,
  add column failure_code text;

alter table public.upload_sessions
  add constraint file050_upload_school_id_key unique(school_id,id),
  add constraint file050_upload_owner_school_fk foreign key(school_id,owner_membership_id,owner_id)
    references public.memberships(school_id,id,user_id) on delete restrict not valid,
  add constraint file050_upload_classroom_school_fk foreign key(school_id,classroom_id)
    references public.classrooms(school_id,id) on delete restrict not valid,
  add constraint file050_upload_assignment_school_fk foreign key(school_id,assignment_id)
    references public.assignments(school_id,id) on delete restrict not valid,
  add constraint file050_upload_student_school_fk foreign key(school_id,student_id)
    references public.students(school_id,id) on delete restrict not valid,
  add constraint file050_upload_grade_school_fk foreign key(school_id,grade_result_id)
    references public.grade_results(school_id,id) on delete restrict not valid,
  add constraint file050_upload_metadata_check check (
    policy_version='legacy' or (
      bucket='private-school-files' and object_key ~ '^quarantine/v1/[0-9a-f-]{36}/[A-Za-z0-9_-]{22,64}$' and
      owner_id is not null and owner_membership_id is not null and
      display_name is not null and length(display_name) between 1 and 255 and
      declared_media_type is not null and expected_sha256 ~ '^[0-9a-f]{64}$'
    )
  ) not valid,
  add constraint file050_upload_target_check check (
    policy_version='legacy' or case purpose
      when 'profile_image' then num_nonnulls(classroom_id,assignment_id,student_id,grade_result_id)=0
      when 'lesson_resource' then classroom_id is not null and num_nonnulls(assignment_id,student_id,grade_result_id)=0
      when 'assignment_material' then assignment_id is not null and num_nonnulls(classroom_id,student_id,grade_result_id)=0
      when 'assignment_submission' then assignment_id is not null and student_id is not null and num_nonnulls(classroom_id,grade_result_id)=0
      when 'paper_scan' then grade_result_id is not null and num_nonnulls(classroom_id,assignment_id,student_id)=0
      when 'coach_attachment' then student_id is not null and num_nonnulls(classroom_id,assignment_id,grade_result_id)=0
      else false end
  ) not valid,
  add constraint file050_upload_actual_size_check check(actual_size_bytes is null or actual_size_bytes >= 0) not valid;

alter table public.file_bindings add column upload_session_id uuid;
alter table public.file_bindings drop constraint if exists file_bindings_check;
alter table public.file_bindings
  add constraint file050_binding_upload_school_fk foreign key(school_id,upload_session_id)
    references public.upload_sessions(school_id,id) on delete restrict not valid,
  add constraint file050_binding_one_target check (
    num_nonnulls(resource_version_id,submission_attempt_id,message_id,ai_grading_draft_id,upload_session_id)=1
  ) not valid;

-- Extend DB-021 immutability to the FILE-050 ownership and target columns.
drop trigger if exists db021_immutable_file_object on public.file_objects;
create trigger db021_immutable_file_object before update on public.file_objects
for each row execute function private.reject_immutable_columns(
  'id','school_id','bucket','object_key','uploader_id','owner_id','owner_membership_id',
  'purpose','display_name','policy_version','size_bytes','sha256','created_at'
);
drop trigger if exists db021_immutable_upload_session on public.upload_sessions;
create trigger db021_immutable_upload_session before update on public.upload_sessions
for each row execute function private.reject_immutable_columns(
  'id','school_id','uploader_id','owner_id','owner_membership_id','purpose','nonce_hash',
  'bucket','object_key','display_name','declared_media_type','expected_sha256','policy_version',
  'classroom_id','assignment_id','student_id','grade_result_id','created_at'
);
drop trigger if exists db021_immutable_file_binding on public.file_bindings;
create trigger db021_immutable_file_binding before update on public.file_bindings
for each row execute function private.reject_immutable_columns(
  'id','school_id','file_object_id','resource_version_id','submission_attempt_id',
  'message_id','ai_grading_draft_id','upload_session_id','created_at'
);

create table public.file_job_outbox (
  id bigint generated always as identity primary key,
  school_id uuid not null references public.schools(id) on delete cascade,
  upload_session_id uuid not null,
  file_object_id uuid,
  job_type text not null check(job_type in ('scan','delete')),
  state public.outbox_state not null default 'pending',
  attempt_count integer not null default 0 check(attempt_count >= 0),
  available_at timestamptz not null default now(),
  locked_at timestamptz,
  locked_by text,
  last_error_code text,
  completed_at timestamptz,
  created_at timestamptz not null default now(),
  unique(upload_session_id,job_type),
  foreign key(school_id,upload_session_id) references public.upload_sessions(school_id,id) on delete restrict,
  foreign key(school_id,file_object_id) references public.file_objects(school_id,id) on delete restrict
);
alter table public.file_job_outbox enable row level security;

create index file050_upload_owner_state_idx on public.upload_sessions(owner_id,state,expires_at,id);
create index file050_upload_school_created_idx on public.upload_sessions(school_id,created_at,id);
create index file050_upload_expiry_active_idx on public.upload_sessions(expires_at,id)
  where state='initiated';
create index file050_file_owner_created_idx on public.file_objects(owner_id,created_at desc,id desc);
create index file050_file_job_claim_idx on public.file_job_outbox(job_type,state,available_at,id)
  where state in ('pending','retry');

-- The global storage ceiling is defense in depth; purpose limits are smaller.
update storage.buckets set public=false, file_size_limit=26214400,
  allowed_mime_types=array['application/pdf','image/jpeg','image/png','image/webp']
where id='private-school-files';

-- A command transaction may need to persist a deterministic client error
-- (for example, checksum/type/size mismatch) together with the rejected
-- object and its deletion job. Transient 5xx responses remain ineligible.
create or replace function private.api_idempotency_complete(
  p_id uuid,
  p_generation bigint,
  p_response_status integer,
  p_response_body jsonb
)
returns boolean
language plpgsql
security definer
set search_path = ''
as $$
begin
  if auth.uid() is null
     or p_response_status not between 200 and 499
     or octet_length(coalesce(p_response_body, '{}'::jsonb)::text) > 65536 then
    return false;
  end if;
  update public.idempotency_records r
  set status = 'completed', response_status = p_response_status,
      response_body = coalesce(p_response_body, '{}'::jsonb),
      lease_expires_at = null
  where r.id = p_id and r.actor_id = auth.uid()
    and r.generation = p_generation and r.status = 'reserved';
  return found;
end;
$$;

create or replace function private.file050_authorize_target(p_body jsonb)
returns jsonb language plpgsql stable security definer set search_path='' as $$
declare
  sid uuid := nullif(p_body->>'schoolId','')::uuid;
  purpose_value public.file_purpose := nullif(p_body->>'purpose','')::public.file_purpose;
  target uuid; membership uuid; allowed boolean := false;
begin
  select m.id into membership from public.memberships m
  where m.school_id=sid and m.user_id=auth.uid() and m.active and m.status='active'
    and (m.valid_until is null or m.valid_until >= now())
  order by case m.role when 'school_admin' then 0 when 'teacher' then 1 when 'student' then 2 else 3 end limit 1;
  if membership is null then return jsonb_build_object('allowed',false); end if;

  case purpose_value
    when 'profile_image' then allowed := true;
    when 'lesson_resource' then
      target := nullif(p_body->>'classroomId','')::uuid;
      select exists(select 1 from public.classrooms c where c.id=target and c.school_id=sid and (
        private.is_school_admin(sid) or exists(select 1 from public.classroom_staff cs
          where cs.classroom_id=c.id and cs.school_id=sid and cs.user_id=auth.uid()
            and cs.status='active' and cs.role in ('lead_teacher','co_teacher')))) into allowed;
    when 'assignment_material' then
      target := nullif(p_body->>'assignmentId','')::uuid;
      select exists(select 1 from public.assignments a join public.classrooms c on c.id=a.classroom_id
        where a.id=target and a.school_id=sid and (private.is_school_admin(sid) or exists(
          select 1 from public.classroom_staff cs where cs.classroom_id=c.id and cs.school_id=sid
          and cs.user_id=auth.uid() and cs.status='active' and cs.role in ('lead_teacher','co_teacher')))) into allowed;
    when 'assignment_submission' then
      select exists(select 1 from public.assignments a
        join public.students s on s.id=nullif(p_body->>'studentId','')::uuid and s.school_id=sid
        join public.enrollments e on e.student_id=s.id and e.classroom_id=a.classroom_id and e.active and e.status='active'
        where a.id=nullif(p_body->>'assignmentId','')::uuid and a.school_id=sid and s.user_id=auth.uid()
          and a.state='published' and (a.closes_at is null or a.closes_at >= now())) into allowed;
    when 'paper_scan' then
      select exists(select 1 from public.grade_results g join public.assessments a on a.id=g.assessment_id
        where g.id=nullif(p_body->>'gradeResultId','')::uuid and g.school_id=sid and (
          private.is_school_admin(sid) or exists(select 1 from public.classroom_staff cs
            where cs.classroom_id=a.classroom_id and cs.school_id=sid and cs.user_id=auth.uid()
              and cs.status='active' and cs.role in ('lead_teacher','co_teacher')))) into allowed;
    when 'coach_attachment' then
      select exists(select 1 from public.students s where s.id=nullif(p_body->>'studentId','')::uuid
        and s.school_id=sid and s.user_id=auth.uid() and s.deleted_at is null) into allowed;
  end case;
  return jsonb_build_object('allowed',coalesce(allowed,false),'schoolId',sid,'membershipId',membership);
exception when invalid_text_representation then
  return jsonb_build_object('allowed',false);
end;
$$;

create or replace function private.file050_upload_json(p_id uuid)
returns jsonb language sql stable security definer set search_path='' as $$
  select jsonb_build_object(
    'id',u.id,'purpose',u.purpose,'displayName',u.display_name,
    'declaredMediaType',u.declared_media_type,'expectedSizeBytes',u.expected_size_bytes,
    'state',u.state,'expiresAt',u.expires_at,'createdAt',u.created_at,
    'completedAt',u.completed_at,'fileId',u.file_object_id,'failureCode',u.failure_code)
  from public.upload_sessions u where u.id=p_id;
$$;

create or replace function private.file050_file_json(p_id uuid)
returns jsonb language sql stable security definer set search_path='' as $$
  select jsonb_build_object(
    'id',f.id,'purpose',f.purpose,'displayName',f.display_name,'sizeBytes',f.size_bytes,
    'declaredMediaType',f.declared_media_type,'detectedMediaType',f.detected_media_type,
    'scanState',f.scan_state,'createdAt',f.created_at,'scannedAt',f.scanned_at,
    'failureCode',f.scan_error_code)
  from public.file_objects f where f.id=p_id;
$$;

create or replace function private.api050_prepare_intent(p_body jsonb)
returns jsonb language plpgsql stable security definer set search_path='' as $$
declare authz jsonb; policy public.file_purpose_policies%rowtype;
begin
  authz:=private.file050_authorize_target(p_body);
  if not coalesce((authz->>'allowed')::boolean,false) then return jsonb_build_object('outcome','not_found'); end if;
  select * into policy from public.file_purpose_policies where purpose=(p_body->>'purpose')::public.file_purpose and enabled;
  if policy.purpose is null then return jsonb_build_object('outcome','invalid'); end if;
  if (p_body->>'expectedSizeBytes')::bigint > policy.maximum_size_bytes then return jsonb_build_object('outcome','size_limit'); end if;
  if not (p_body->>'declaredMediaType'=any(policy.allowed_media_types)) then return jsonb_build_object('outcome','type_not_allowed'); end if;
  return jsonb_build_object('outcome','ok','policyVersion',policy.policy_version,'maximumSizeBytes',policy.maximum_size_bytes);
exception when others then return jsonb_build_object('outcome','invalid');
end;
$$;

create or replace function private.api050_issue_intent(
  p_body jsonb, p_internal jsonb, p_idempotency_id uuid, p_idempotency_generation bigint)
returns jsonb language plpgsql security definer set search_path='' as $$
declare
  authz jsonb; policy public.file_purpose_policies%rowtype; quota public.file_quota_policies%rowtype;
  sid uuid; mid uuid; upload_id uuid := (p_internal->>'uploadId')::uuid;
  expires timestamptz := (p_internal->>'expiresAt')::timestamptz;
  expected bigint := (p_body->>'expectedSizeBytes')::bigint;
  active_count bigint; hourly_count bigint; user_bytes bigint; school_bytes bigint; stored_bytes bigint; live_count bigint;
  response jsonb; request_id text := nullif(current_setting('studafy.request_id',true),'');
begin
  if auth.uid() is null or request_id is null then return jsonb_build_object('outcome','forbidden'); end if;
  authz:=private.file050_authorize_target(p_body);
  if not coalesce((authz->>'allowed')::boolean,false) then return jsonb_build_object('outcome','not_found'); end if;
  sid:=(authz->>'schoolId')::uuid; mid:=(authz->>'membershipId')::uuid;
  if sid::text<>current_setting('studafy.school_id',true) then return jsonb_build_object('outcome','forbidden'); end if;
  select * into policy from public.file_purpose_policies where purpose=(p_body->>'purpose')::public.file_purpose and enabled;
  if expected>policy.maximum_size_bytes then return jsonb_build_object('outcome','size_limit'); end if;
  if not (p_body->>'declaredMediaType'=any(policy.allowed_media_types)) then return jsonb_build_object('outcome','type_not_allowed'); end if;
  if p_internal->>'bucket'<>'private-school-files' or p_internal->>'objectKey' !~ '^quarantine/v1/[0-9a-f-]{36}/[A-Za-z0-9_-]{22,64}$'
    or expires<=now() or expires>now()+interval '2 hours 5 minutes' then return jsonb_build_object('outcome','invalid'); end if;

  select * into quota from public.file_quota_policies where school_id=sid for update;
  select count(*) into active_count from public.upload_sessions where owner_id=auth.uid() and state='initiated' and expires_at>now();
  select count(*) into hourly_count from public.upload_sessions where owner_id=auth.uid() and created_at>=now()-interval '1 hour';
  select coalesce(sum(case when state='initiated' and expires_at>now() then expected_size_bytes else coalesce(actual_size_bytes,0) end),0)
    into user_bytes from public.upload_sessions where owner_id=auth.uid() and created_at>=now()-interval '24 hours' and state not in ('expired','cancelled');
  select coalesce(sum(case when state='initiated' and expires_at>now() then expected_size_bytes else coalesce(actual_size_bytes,0) end),0)
    into school_bytes from public.upload_sessions where school_id=sid and created_at>=now()-interval '24 hours' and state not in ('expired','cancelled');
  select coalesce(sum(size_bytes),0),count(*) into stored_bytes,live_count from public.file_objects where school_id=sid and scan_state<>'deleted';
  if active_count>=quota.user_active_sessions then return jsonb_build_object('outcome','concurrency_limit'); end if;
  if hourly_count>=quota.user_hourly_intents or user_bytes+expected>quota.user_rolling_bytes or school_bytes+expected>quota.school_rolling_bytes
    or stored_bytes+expected>quota.school_stored_bytes or live_count+active_count+1>quota.school_live_objects then
    return jsonb_build_object('outcome','quota_exceeded');
  end if;

  insert into public.upload_sessions(id,school_id,uploader_id,owner_id,owner_membership_id,purpose,
    expected_size_bytes,allowed_media_types,nonce_hash,state,expires_at,bucket,object_key,display_name,
    declared_media_type,expected_sha256,policy_version,classroom_id,assignment_id,student_id,grade_result_id)
  values(upload_id,sid,auth.uid(),auth.uid(),mid,p_body->>'purpose',expected,policy.allowed_media_types,
    p_internal->>'nonceHash','initiated',expires,p_internal->>'bucket',p_internal->>'objectKey',p_body->>'displayName',
    p_body->>'declaredMediaType',p_body->>'sha256',policy.policy_version,
    nullif(p_body->>'classroomId','')::uuid,nullif(p_body->>'assignmentId','')::uuid,
    nullif(p_body->>'studentId','')::uuid,nullif(p_body->>'gradeResultId','')::uuid);
  response:=jsonb_build_object('session',private.file050_upload_json(upload_id),'uploadUrl',p_internal->>'uploadUrl',
    'method','PUT','requiredHeaders',jsonb_build_object(
      'content-type',p_body->>'declaredMediaType','cache-control','max-age=3600','x-upsert','false'
    ),'expiresAt',expires);
  insert into public.audit_events(school_id,actor_id,action,entity_type,entity_id,after_value,request_id)
  values(sid,auth.uid(),'upload_intent_issued','upload_session',upload_id,
    jsonb_build_object('purpose',p_body->>'purpose','expectedSizeBytes',expected,'policyVersion',policy.policy_version),request_id);
  if not private.api_idempotency_complete(p_idempotency_id,p_idempotency_generation,201,response) then
    raise exception 'FILE050_IDEMPOTENCY_COMPLETION_FAILED';
  end if;
  return jsonb_build_object('outcome','ok','response',response);
end;
$$;

create or replace function private.api050_query(p_operation text,p_resource_id uuid)
returns jsonb language plpgsql stable security definer set search_path='' as $$
declare result jsonb; state_value public.file_scan_state;
begin
  if p_operation='getUploadStatus' then
    select private.file050_upload_json(u.id) into result from public.upload_sessions u where u.id=p_resource_id and u.owner_id=auth.uid();
  elsif p_operation='getFileStatus' then
    select private.file050_file_json(f.id) into result from public.file_objects f where f.id=p_resource_id and f.owner_id=auth.uid();
  elsif p_operation='createFileDownloadIntent' then
    select f.scan_state into state_value from public.file_objects f where f.id=p_resource_id and f.owner_id=auth.uid();
    if state_value is null then return jsonb_build_object('outcome','not_found'); end if;
    if state_value<>'clean' then return jsonb_build_object('outcome','file_not_clean'); end if;
    return jsonb_build_object('outcome','delivery_disabled');
  end if;
  if result is null then return jsonb_build_object('outcome','not_found'); end if;
  return jsonb_build_object('outcome','ok','response',result);
end;
$$;

create or replace function private.api050_prepare_completion(p_upload_id uuid)
returns jsonb language sql stable security definer set search_path='' as $$
  select case
    when u.id is null then jsonb_build_object('outcome','not_found')
    when u.expires_at<=now() then jsonb_build_object('outcome','expired')
    when u.state='completed' then jsonb_build_object('outcome','already_completed')
    when u.state<>'initiated' then jsonb_build_object('outcome','invalid_state')
    else jsonb_build_object('outcome','ok','schoolId',u.school_id,'bucket',u.bucket,'objectKey',u.object_key,
      'expectedSizeBytes',u.expected_size_bytes,'declaredMediaType',u.declared_media_type,
      'expectedSha256',u.expected_sha256,'purpose',u.purpose) end
  from (select * from public.upload_sessions where id=p_upload_id and owner_id=auth.uid()) u
  right join (select 1) present on true limit 1;
$$;

create or replace function private.file050_problem(p_code text,p_status integer,p_request_id text)
returns jsonb language sql immutable security definer set search_path='' as $$
  select jsonb_build_object('type','https://api.studafy.io/problems/'||lower(replace(p_code,'_','-')),
    'title',case p_code when 'UPLOAD_SIZE_MISMATCH' then 'Upload size mismatch'
      when 'UPLOAD_TYPE_MISMATCH' then 'Upload type mismatch' else 'Upload checksum mismatch' end,
    'status',p_status,'code',p_code,
    'detail',case p_code when 'UPLOAD_SIZE_MISMATCH' then 'The uploaded object size does not match the reservation.'
      when 'UPLOAD_TYPE_MISMATCH' then 'The uploaded bytes do not match the declared file type.'
      else 'The uploaded object checksum does not match the reservation.' end,
    'requestId',p_request_id);
$$;

create or replace function private.api050_complete_upload(
  p_upload_id uuid,p_observed jsonb,p_idempotency_id uuid,p_idempotency_generation bigint)
returns jsonb language plpgsql security definer set search_path='' as $$
declare
  u public.upload_sessions%rowtype; body jsonb; authz jsonb; mismatch text; file_id uuid;
  response jsonb; status_value integer; request_id text:=nullif(current_setting('studafy.request_id',true),'');
begin
  select * into u from public.upload_sessions where id=p_upload_id and owner_id=auth.uid() for update;
  if u.id is null then return jsonb_build_object('outcome','not_found'); end if;
  if u.expires_at<=now() then return jsonb_build_object('outcome','expired'); end if;
  if u.state='completed' then return jsonb_build_object('outcome','already_completed'); end if;
  if u.state<>'initiated' then return jsonb_build_object('outcome','invalid_state'); end if;
  if not coalesce((p_observed->>'exists')::boolean,false) then return jsonb_build_object('outcome','incomplete'); end if;
  body:=jsonb_strip_nulls(jsonb_build_object('schoolId',u.school_id,'purpose',u.purpose,'classroomId',u.classroom_id,
    'assignmentId',u.assignment_id,'studentId',u.student_id,'gradeResultId',u.grade_result_id));
  authz:=private.file050_authorize_target(body);
  if not coalesce((authz->>'allowed')::boolean,false) then return jsonb_build_object('outcome','not_found'); end if;
  if (p_observed->>'sizeBytes')::bigint<>u.expected_size_bytes then mismatch:='UPLOAD_SIZE_MISMATCH';
  elsif p_observed->>'detectedMediaType' is distinct from u.declared_media_type then mismatch:='UPLOAD_TYPE_MISMATCH';
  elsif p_observed->>'sha256' is distinct from u.expected_sha256 then mismatch:='UPLOAD_CHECKSUM_MISMATCH'; end if;

  insert into public.file_objects(school_id,bucket,object_key,uploader_id,owner_id,owner_membership_id,purpose,
    display_name,policy_version,size_bytes,declared_media_type,detected_media_type,sha256,scan_state,scan_error_code)
  values(u.school_id,u.bucket,u.object_key,u.uploader_id,u.owner_id,u.owner_membership_id,u.purpose::public.file_purpose,
    u.display_name,u.policy_version,(p_observed->>'sizeBytes')::bigint,u.declared_media_type,
    nullif(p_observed->>'detectedMediaType',''),nullif(p_observed->>'sha256',''),
    case when mismatch is null then 'quarantined'::public.file_scan_state else 'rejected'::public.file_scan_state end,mismatch)
  returning id into file_id;
  insert into public.file_bindings(school_id,file_object_id,upload_session_id) values(u.school_id,file_id,u.id);
  update public.upload_sessions set state=case when mismatch is null then 'completed'::public.upload_session_state else 'rejected'::public.upload_session_state end,
    completed_at=now(),file_object_id=file_id,actual_size_bytes=(p_observed->>'sizeBytes')::bigint,
    failure_code=mismatch,updated_at=now() where id=u.id;
  insert into public.file_job_outbox(school_id,upload_session_id,file_object_id,job_type)
    values(u.school_id,u.id,file_id,case when mismatch is null then 'scan' else 'delete' end);
  insert into public.audit_events(school_id,actor_id,action,entity_type,entity_id,after_value,request_id)
    values(u.school_id,auth.uid(),case when mismatch is null then 'upload_completed' else 'upload_rejected' end,
      'file_object',file_id,jsonb_build_object('purpose',u.purpose,'scanState',case when mismatch is null then 'quarantined' else 'rejected' end,
      'failureCode',mismatch),request_id);
  if mismatch is null then
    response:=jsonb_build_object('session',private.file050_upload_json(u.id),'file',private.file050_file_json(file_id)); status_value:=200;
  else
    status_value:=422; response:=private.file050_problem(mismatch,status_value,request_id);
  end if;
  if not private.api_idempotency_complete(p_idempotency_id,p_idempotency_generation,status_value,response) then
    raise exception 'FILE050_IDEMPOTENCY_COMPLETION_FAILED';
  end if;
  return jsonb_build_object('outcome',case when mismatch is null then 'ok' else 'problem' end,
    'status',status_value,'code',mismatch,'response',response);
end;
$$;

create or replace function private.api050_claim_cleanup(p_worker text,p_limit integer default 20)
returns jsonb language plpgsql security definer set search_path='' as $$
declare claimed jsonb;
begin
  if p_worker is null or length(p_worker) not between 1 and 100 or p_limit not between 1 and 100 then
    raise exception 'FILE050_INVALID_WORKER_CLAIM';
  end if;
  with expired as (
    update public.upload_sessions u set state='expired',updated_at=now()
    where u.state='initiated' and u.expires_at<=now()
    returning u.school_id,u.id,u.file_object_id
  )
  insert into public.file_job_outbox(school_id,upload_session_id,file_object_id,job_type)
  select school_id,id,file_object_id,'delete' from expired on conflict(upload_session_id,job_type) do nothing;

  with candidates as (
    select j.id from public.file_job_outbox j
    where j.job_type='delete' and j.state in ('pending','retry') and j.available_at<=now()
    order by j.available_at,j.id for update skip locked limit p_limit
  ), updated as (
    update public.file_job_outbox j set state='processing',attempt_count=attempt_count+1,
      locked_at=now(),locked_by=p_worker
    from candidates c where j.id=c.id
    returning j.id,j.upload_session_id,j.file_object_id
  )
  select coalesce(jsonb_agg(jsonb_build_object('jobId',u.id,'uploadId',u.upload_session_id,
    'fileId',u.file_object_id,'bucket',s.bucket,'objectKey',s.object_key) order by u.id),'[]'::jsonb)
  into claimed from updated u join public.upload_sessions s on s.id=u.upload_session_id;
  return claimed;
end;
$$;

create or replace function private.api050_finish_cleanup(
  p_worker text,p_job_id bigint,p_succeeded boolean,p_error_code text default null)
returns boolean language plpgsql security definer set search_path='' as $$
declare job public.file_job_outbox%rowtype;
begin
  select * into job from public.file_job_outbox where id=p_job_id and state='processing' and locked_by=p_worker for update;
  if job.id is null then return false; end if;
  if p_succeeded then
    update public.file_job_outbox set state='completed',completed_at=now(),locked_at=null,locked_by=null,last_error_code=null where id=job.id;
    if job.file_object_id is not null then
      update public.file_objects set scan_state='deleted',deleted_at=now() where id=job.file_object_id and scan_state in ('rejected','error');
    end if;
    insert into public.audit_events(school_id,actor_id,action,entity_type,entity_id,after_value,request_id)
    values(job.school_id,null,'quarantine_object_deleted','upload_session',job.upload_session_id,
      jsonb_build_object('fileId',job.file_object_id,'jobId',job.id),'file050-cleanup-'||job.id);
  else
    update public.file_job_outbox set state=case when attempt_count>=10 then 'dead_letter'::public.outbox_state else 'retry'::public.outbox_state end,
      available_at=now()+make_interval(secs=>least(3600,5*(2^least(attempt_count,9))::integer)),
      locked_at=null,locked_by=null,last_error_code=left(coalesce(p_error_code,'STORAGE_UNAVAILABLE'),80)
    where id=job.id;
  end if;
  return true;
end;
$$;

-- AUTH-031 extension. Middleware establishes the tenant; command functions
-- still re-check the purpose-specific relationship before every mutation.
alter function private.authz_authorize(text,uuid) rename to authz_authorize_pre_file050;
create or replace function private.authz_authorize(p_action text,p_resource_id uuid)
returns jsonb language plpgsql stable security definer set search_path='' as $$
declare sid uuid; allowed boolean:=false;
begin
  if p_action not in ('upload.intent.create','upload.read','upload.complete','file.read','file.download') then
    return private.authz_authorize_pre_file050(p_action,p_resource_id);
  end if;
  if auth.uid() is null or p_resource_id is null then
    return jsonb_build_object('allowed',false,'school_id',null,'reason','invalid_resource');
  end if;
  if p_action='upload.intent.create' then
    select s.id,private.has_active_membership(s.id) into sid,allowed from public.schools s where s.id=p_resource_id;
  elsif p_action in ('upload.read','upload.complete') then
    select u.school_id,u.owner_id=auth.uid() into sid,allowed from public.upload_sessions u where u.id=p_resource_id;
  else
    select f.school_id,f.owner_id=auth.uid() into sid,allowed from public.file_objects f where f.id=p_resource_id;
  end if;
  return jsonb_build_object('allowed',coalesce(allowed,false),'school_id',sid,
    'reason',case when sid is null then 'invalid_resource' when allowed then 'allowed' else 'denied' end);
end;
$$;

-- FILE-050 request/runtime functions.
alter function private.file050_seed_school_quota() owner to postgres;
alter function private.file050_authorize_target(jsonb) owner to postgres;
alter function private.file050_upload_json(uuid) owner to postgres;
alter function private.file050_file_json(uuid) owner to postgres;
alter function private.api050_prepare_intent(jsonb) owner to postgres;
alter function private.api050_issue_intent(jsonb,jsonb,uuid,bigint) owner to postgres;
alter function private.api050_query(text,uuid) owner to postgres;
alter function private.api050_prepare_completion(uuid) owner to postgres;
alter function private.file050_problem(text,integer,text) owner to postgres;
alter function private.api050_complete_upload(uuid,jsonb,uuid,bigint) owner to postgres;
alter function private.api050_claim_cleanup(text,integer) owner to postgres;
alter function private.api050_finish_cleanup(text,bigint,boolean,text) owner to postgres;
alter function private.authz_authorize(text,uuid) owner to postgres;

revoke all privileges on public.file_purpose_policies,public.file_quota_policies,public.file_job_outbox
from public,anon,authenticated,service_role,studafy_api_runtime,studafy_worker_runtime;
revoke all privileges on all sequences in schema public from studafy_api_runtime;
revoke all on function private.authz_authorize_pre_file050(text,uuid)
from public,anon,authenticated,service_role,studafy_api_runtime,studafy_worker_runtime;
revoke all on function private.file050_authorize_target(jsonb),private.file050_upload_json(uuid),private.file050_file_json(uuid),
  private.file050_problem(text,integer,text),private.file050_seed_school_quota()
from public,anon,authenticated,service_role,studafy_api_runtime,studafy_worker_runtime;
revoke all on function private.api050_prepare_intent(jsonb),private.api050_issue_intent(jsonb,jsonb,uuid,bigint),
  private.api050_query(text,uuid),private.api050_prepare_completion(uuid),private.api050_complete_upload(uuid,jsonb,uuid,bigint),
  private.authz_authorize(text,uuid)
from public,anon,authenticated,service_role,studafy_worker_runtime;
grant execute on function private.api050_prepare_intent(jsonb),private.api050_issue_intent(jsonb,jsonb,uuid,bigint),
  private.api050_query(text,uuid),private.api050_prepare_completion(uuid),private.api050_complete_upload(uuid,jsonb,uuid,bigint),
  private.authz_authorize(text,uuid) to studafy_api_runtime;
revoke all on function private.api050_claim_cleanup(text,integer),private.api050_finish_cleanup(text,bigint,boolean,text)
from public,anon,authenticated,service_role,studafy_api_runtime;
grant execute on function private.api050_claim_cleanup(text,integer),private.api050_finish_cleanup(text,bigint,boolean,text)
to studafy_worker_runtime;

alter table public.file_objects validate constraint file050_file_metadata_check;
alter table public.file_objects validate constraint file050_file_hash_state_check;
alter table public.file_objects validate constraint file050_file_bucket_check;
alter table public.upload_sessions validate constraint file050_upload_metadata_check;
alter table public.upload_sessions validate constraint file050_upload_target_check;
alter table public.upload_sessions validate constraint file050_upload_actual_size_check;
alter table public.file_bindings validate constraint file050_binding_one_target;
alter table public.file_objects validate constraint file050_file_owner_school_fk;
alter table public.upload_sessions validate constraint file050_upload_owner_school_fk;
alter table public.upload_sessions validate constraint file050_upload_classroom_school_fk;
alter table public.upload_sessions validate constraint file050_upload_assignment_school_fk;
alter table public.upload_sessions validate constraint file050_upload_student_school_fk;
alter table public.upload_sessions validate constraint file050_upload_grade_school_fk;
alter table public.file_bindings validate constraint file050_binding_upload_school_fk;
