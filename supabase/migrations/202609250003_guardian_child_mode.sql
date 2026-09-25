-- A guardian acting for a child who has no device of their own.
--
-- Young children do not have phones or email addresses. The schema already
-- knew this: public.students.user_id is nullable and `provisional` defaults
-- true, so a child can exist as a student record a teacher created with no
-- account behind it at all. Nothing here impersonates anybody - there is
-- usually no account to impersonate. The guardian stays the authenticated
-- actor throughout; what changes is that a verified guardian link now
-- authorises acting *for* a named student.
--
-- Three properties are load-bearing:
--
--   1. **The link alone is the authority.** private.is_verified_guardian
--      additionally requires a parent/guardian membership, which
--      api042_family.sql itself calls "if required by school policy, not
--      universal". A feature that silently does nothing at schools which do
--      not grant those memberships is not a feature, so child mode uses a
--      link-only helper with every other freshness check intact.
--   2. **A guardian hand-in is attributable.** submission_attempts records
--      which guardian submitted, and the teacher's roster read carries it.
--      Without that a teacher cannot tell whose work they are marking, which
--      is the difference between helping a six-year-old and marking the
--      parent's homework.
--   3. **Scope is an allowlist.** The guardian path below covers handing work
--      in and the uploads that go with it. It deliberately does not widen any
--      read that is not already a guardian read.
--
-- It also repairs a defect introduced by 202609250002: file050_authorize_target
-- is a PL/pgSQL CASE with no ELSE, so the two new purposes it did not know
-- about raised `case not found` rather than returning a verdict. Every chat and
-- announcement upload intent was a 500. The ELSE added here makes an unknown
-- purpose fail closed instead of failing loudly.

-- ---------------------------------------------------------------------------
-- 1. Link-only guardian test.
--
-- Everything private.is_verified_guardian checks except the membership: the
-- link is verified and unexpired, the enrolment is live, and the class and
-- term are active. p_classroom is optional so callers that only know the
-- student (an upload intent) can use the same helper as callers that know
-- both (a hand-in).
-- ---------------------------------------------------------------------------
create or replace function private.is_linked_guardian(
  p_student uuid,
  p_classroom uuid default null
)
returns boolean language sql stable security definer set search_path = '' as $$
  select private.is_active_user() and exists (
    select 1
    from public.guardian_links gl
    join public.enrollments e
      on e.student_id = gl.student_id and e.school_id = gl.school_id
    join public.classrooms c
      on c.id = e.classroom_id and c.school_id = e.school_id
    join public.terms t
      on t.id = c.term_id and t.school_id = c.school_id
    where gl.student_id = p_student
      and gl.guardian_id = auth.uid()
      and gl.status = 'verified'
      and (gl.expires_at is null or gl.expires_at > now())
      and (p_classroom is null or e.classroom_id = p_classroom)
      and e.active
      and e.status = 'active'
      and e.starts_on <= current_date
      and (e.ends_on is null or e.ends_on >= current_date)
      and c.status = 'active'
      and t.status = 'active'
  );
$$;

revoke all on function private.is_linked_guardian(uuid, uuid) from public;
alter function private.is_linked_guardian(uuid, uuid) owner to postgres;

/** The live link row itself, for recording who owns a guardian's upload. */
create or replace function private.linked_guardian_link_id(p_student uuid)
returns uuid language sql stable security definer set search_path = '' as $$
  select gl.id from public.guardian_links gl
  where gl.student_id = p_student
    and gl.guardian_id = auth.uid()
    and gl.status = 'verified'
    and (gl.expires_at is null or gl.expires_at > now())
  limit 1;
$$;

revoke all on function private.linked_guardian_link_id(uuid) from public;
alter function private.linked_guardian_link_id(uuid) owner to postgres;

-- ---------------------------------------------------------------------------
-- 2. A guardian may own an uploaded object.
--
-- Ownership previously had to be proved by a memberships row, which a
-- guardian may not have. A verified guardian link is the equivalent proof, so
-- it becomes the other permitted half of the same requirement - still exactly
-- one, still a real foreign key, never neither.
-- ---------------------------------------------------------------------------
alter table public.upload_sessions
  add column if not exists owner_guardian_link_id uuid
    references public.guardian_links(id) on delete restrict;
alter table public.file_objects
  add column if not exists owner_guardian_link_id uuid
    references public.guardian_links(id) on delete restrict;

alter table public.upload_sessions
  drop constraint if exists file050_upload_metadata_check;
alter table public.upload_sessions
  add constraint file050_upload_metadata_check check (
    policy_version = 'legacy' or (
      bucket = 'private-school-files'
      and object_key ~ '^quarantine/v1/[0-9a-f-]{36}/[A-Za-z0-9_-]{22,64}$'
      and owner_id is not null
      and num_nonnulls(owner_membership_id, owner_guardian_link_id) = 1
      and display_name is not null and length(display_name) between 1 and 255
      and declared_media_type is not null
      and expected_sha256 ~ '^[0-9a-f]{64}$'
    )
  ) not valid;
alter table public.upload_sessions
  validate constraint file050_upload_metadata_check;

alter table public.file_objects
  drop constraint if exists file050_file_metadata_check;
alter table public.file_objects
  add constraint file050_file_metadata_check check (
    policy_version = 'legacy' or (
      owner_id is not null
      and num_nonnulls(owner_membership_id, owner_guardian_link_id) = 1
      and purpose is not null
      and display_name is not null and length(display_name) between 1 and 255
    )
  ) not valid;
alter table public.file_objects
  validate constraint file050_file_metadata_check;

-- Ownership is evidence of who may read an object, so the new column joins
-- the immutable set rather than being quietly editable.
drop trigger if exists db021_immutable_file_object on public.file_objects;
create trigger db021_immutable_file_object before update on public.file_objects
for each row execute function private.reject_immutable_columns(
  'id', 'school_id', 'bucket', 'object_key', 'uploader_id', 'owner_id',
  'owner_membership_id', 'owner_guardian_link_id', 'purpose', 'display_name',
  'policy_version', 'size_bytes', 'sha256', 'created_at'
);
drop trigger if exists db021_immutable_upload_session on public.upload_sessions;
create trigger db021_immutable_upload_session before update on public.upload_sessions
for each row execute function private.reject_immutable_columns(
  'id', 'school_id', 'uploader_id', 'owner_id', 'owner_membership_id',
  'owner_guardian_link_id', 'purpose', 'nonce_hash', 'bucket', 'object_key',
  'display_name', 'declared_media_type', 'expected_sha256', 'policy_version',
  'classroom_id', 'assignment_id', 'student_id', 'grade_result_id', 'created_at'
);

-- ---------------------------------------------------------------------------
-- 3. Upload target authorization: guardians, the two new purposes, and an
--    ELSE so an unknown purpose is a refusal rather than an exception.
-- ---------------------------------------------------------------------------
create or replace function private.file050_authorize_target(p_body jsonb)
returns jsonb language plpgsql stable security definer set search_path='' as $$
declare
  sid uuid := nullif(p_body->>'schoolId','')::uuid;
  purpose_value public.file_purpose := nullif(p_body->>'purpose','')::public.file_purpose;
  student_target uuid := nullif(p_body->>'studentId','')::uuid;
  target uuid; membership uuid; guardian_link uuid; allowed boolean := false;
begin
  select m.id into membership from public.memberships m
  where m.school_id=sid and m.user_id=auth.uid() and m.active and m.status='active'
    and (m.valid_until is null or m.valid_until >= now())
  order by case m.role when 'school_admin' then 0 when 'teacher' then 1 when 'student' then 2 else 3 end limit 1;

  -- A guardian may hold no membership at all. Their standing comes from the
  -- verified link to the child named in the request; with neither, stop here.
  if membership is null then
    if student_target is null or not private.is_linked_guardian(student_target) then
      return jsonb_build_object('allowed',false);
    end if;
    guardian_link := private.linked_guardian_link_id(student_target);
    if guardian_link is null then return jsonb_build_object('allowed',false); end if;
  end if;

  case purpose_value
    when 'profile_image' then allowed := membership is not null;
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
      -- The student themselves, or a verified guardian of that student. Both
      -- still require a live enrolment in the assignment's class and an open
      -- window, which is what stops a guardian filing work late or for a
      -- child who has moved class.
      select exists(select 1 from public.assignments a
        join public.students s on s.id=student_target and s.school_id=sid
        join public.enrollments e on e.student_id=s.id and e.classroom_id=a.classroom_id
          and e.active and e.status='active'
        where a.id=nullif(p_body->>'assignmentId','')::uuid and a.school_id=sid
          and (s.user_id=auth.uid() or private.is_linked_guardian(s.id, a.classroom_id))
          and a.state='published' and (a.closes_at is null or a.closes_at >= now())) into allowed;
    when 'paper_scan' then
      select exists(select 1 from public.grade_results g join public.assessments a on a.id=g.assessment_id
        where g.id=nullif(p_body->>'gradeResultId','')::uuid and g.school_id=sid and (
          private.is_school_admin(sid) or exists(select 1 from public.classroom_staff cs
            where cs.classroom_id=a.classroom_id and cs.school_id=sid and cs.user_id=auth.uid()
              and cs.status='active' and cs.role in ('lead_teacher','co_teacher')))) into allowed;
    when 'coach_attachment' then
      -- Left exactly as FILE-050 wrote it. AI-072 disables the purpose policy
      -- row instead, and the refusal it produces ('invalid', not 'not_found')
      -- is asserted by ai072_removal_seed.sql - so hardcoding false here
      -- changes a tested refusal path.
      select exists(select 1 from public.students s where s.id=nullif(p_body->>'studentId','')::uuid
        and s.school_id=sid and s.user_id=auth.uid() and s.deleted_at is null) into allowed;
    when 'message_attachment', 'announcement_attachment' then
      -- No target to authorise: the file is private to its owner until a
      -- message or announcement binds it, and private.file_attach_bind checks
      -- ownership at that point. Standing in the school is the whole test.
      allowed := membership is not null or guardian_link is not null;
    else
      -- Fail closed. A purpose added without a branch here used to raise
      -- `case not found`, which surfaced as a 500 rather than a refusal.
      allowed := false;
  end case;

  return jsonb_build_object(
    'allowed',coalesce(allowed,false),'schoolId',sid,
    'membershipId',membership,'guardianLinkId',guardian_link);
exception when invalid_text_representation then
  return jsonb_build_object('allowed',false);
end;
$$;

alter function private.file050_authorize_target(jsonb) owner to postgres;

-- ---------------------------------------------------------------------------
-- 4. Carry the guardian link through the intent and the completed object.
-- ---------------------------------------------------------------------------
create or replace function private.api050_issue_intent(
  p_body jsonb, p_internal jsonb, p_idempotency_id uuid, p_idempotency_generation bigint)
returns jsonb language plpgsql security definer set search_path='' as $$
declare
  authz jsonb; policy public.file_purpose_policies%rowtype; quota public.file_quota_policies%rowtype;
  sid uuid; mid uuid; glid uuid; upload_id uuid := (p_internal->>'uploadId')::uuid;
  expires timestamptz := (p_internal->>'expiresAt')::timestamptz;
  expected bigint := (p_body->>'expectedSizeBytes')::bigint;
  active_count bigint; hourly_count bigint; user_bytes bigint; school_bytes bigint; stored_bytes bigint; live_count bigint;
  response jsonb; request_id text := nullif(current_setting('studafy.request_id',true),'');
begin
  if auth.uid() is null or request_id is null then return jsonb_build_object('outcome','forbidden'); end if;
  authz:=private.file050_authorize_target(p_body);
  if not coalesce((authz->>'allowed')::boolean,false) then return jsonb_build_object('outcome','not_found'); end if;
  sid:=(authz->>'schoolId')::uuid; mid:=(authz->>'membershipId')::uuid;
  glid:=(authz->>'guardianLinkId')::uuid;
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

  insert into public.upload_sessions(id,school_id,uploader_id,owner_id,owner_membership_id,owner_guardian_link_id,purpose,
    expected_size_bytes,allowed_media_types,nonce_hash,state,expires_at,bucket,object_key,display_name,
    declared_media_type,expected_sha256,policy_version,classroom_id,assignment_id,student_id,grade_result_id)
  values(upload_id,sid,auth.uid(),auth.uid(),mid,case when mid is null then glid end,p_body->>'purpose',expected,policy.allowed_media_types,
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

alter function private.api050_issue_intent(jsonb, jsonb, uuid, bigint) owner to postgres;

-- ---------------------------------------------------------------------------
-- 5. Attribution.
--
-- Nullable: a student handing their own work in leaves it null, which is the
-- ordinary case and stays distinguishable from a guardian hand-in forever.
-- ---------------------------------------------------------------------------
alter table public.submission_attempts
  add column if not exists submitted_by_guardian_id uuid
    references public.profiles(id) on delete set null;

create index if not exists submission_attempts_guardian_idx
  on public.submission_attempts (submitted_by_guardian_id)
  where submitted_by_guardian_id is not null;

-- ---------------------------------------------------------------------------
-- 6. Completion copies the guardian link onto the object.
--
-- Re-issued in full because the INSERT gains a column. Everything else is
-- identical to FILE-050's version; the authorize_target call it makes is the
-- new one above, so a guardian's session re-authorises on the same link.
-- ---------------------------------------------------------------------------
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

  insert into public.file_objects(school_id,bucket,object_key,uploader_id,owner_id,owner_membership_id,
    owner_guardian_link_id,purpose,
    display_name,policy_version,size_bytes,declared_media_type,detected_media_type,sha256,scan_state,scan_error_code)
  values(u.school_id,u.bucket,u.object_key,u.uploader_id,u.owner_id,u.owner_membership_id,
    u.owner_guardian_link_id,u.purpose::public.file_purpose,
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

alter function private.api050_complete_upload(uuid,jsonb,uuid,bigint) owner to postgres;

-- ---------------------------------------------------------------------------
-- 7. A guardian hands work in.
--
-- Handled in the wrapper rather than by re-issuing the five-hundred-line
-- command: the student arm refuses a guardian before anything else can run, so
-- the guardian case is its own explicitly audited path. Keeping them separate
-- is also the point - one of them records who acted, and the reviewer can see
-- which at a glance.
-- ---------------------------------------------------------------------------
do $$ begin
  if not exists (
    select 1 from pg_proc p join pg_namespace n on n.oid = p.pronamespace
    where n.nspname = 'private' and p.proname = 'api041_command_pre_guardian'
  ) then
    alter function private.api041_command(text, uuid, jsonb, uuid, bigint)
      rename to api041_command_pre_guardian;
  end if;
end $$;

/**
 * The student's own hand-in, unchanged, with the attribution field present.
 *
 * V1Submission requires submittedByGuardianId, and the predecessor builds its
 * response inline without it. Rather than re-issue that whole arm, the field
 * is added here as an explicit null - a student handing their own work in is
 * exactly the case where nobody acted for them.
 */
create or replace function private.api041_student_submit(
  p_resource_id uuid, p_input jsonb,
  p_idempotency_id uuid, p_idempotency_generation bigint)
returns jsonb language plpgsql security definer set search_path = '' as $$
declare
  result jsonb;
begin
  result := private.api041_command_pre_guardian(
    'submitAssignment', p_resource_id, p_input, p_idempotency_id,
    p_idempotency_generation);
  if coalesce(result->>'outcome', '') <> 'ok' then return result; end if;
  return jsonb_set(
    result, array['response', 'submittedByGuardianId'], 'null'::jsonb);
end;
$$;

revoke all on function private.api041_student_submit(uuid, jsonb, uuid, bigint)
  from public, anon, authenticated, service_role, studafy_worker_runtime,
  studafy_api_runtime;
alter function private.api041_student_submit(uuid, jsonb, uuid, bigint)
  owner to postgres;

create or replace function private.api041_command(
  p_operation text, p_resource_id uuid, p_input jsonb,
  p_idempotency_id uuid, p_idempotency_generation bigint)
returns jsonb language plpgsql security definer set search_path = '' as $$
declare
  body jsonb := p_input->'body';
  request_id text := nullif(current_setting('studafy.request_id', true), '');
  v_student uuid;
  v_school uuid;
  v_class uuid;
  v_state text;
  v_submission uuid;
  v_attempt uuid;
  v_attachments jsonb;
  v_bind text;
  response jsonb;
begin
  -- Only a hand-in naming a student the caller is not is a candidate for the
  -- guardian path. Everything else, including a student's own hand-in, goes
  -- to the untouched predecessor.
  if p_operation <> 'submitAssignment' then
    return private.api041_command_pre_guardian(
      p_operation, p_resource_id, p_input, p_idempotency_id,
      p_idempotency_generation);
  end if;

  if nullif(body->>'studentId', '') is null then
    return private.api041_student_submit(
      p_resource_id, p_input, p_idempotency_id, p_idempotency_generation);
  end if;

  v_student := (body->>'studentId')::uuid;
  select a.school_id, a.classroom_id, a.state::text into v_school, v_class, v_state
  from public.assignments a
  where a.id = p_resource_id and a.deleted_at is null for update;
  if v_school is null then return jsonb_build_object('outcome','not_found'); end if;

  -- A student naming themselves is the ordinary path; hand it back.
  if exists (
    select 1 from public.students s
    where s.id = v_student and s.user_id = auth.uid()
  ) then
    return private.api041_student_submit(
      p_resource_id, p_input, p_idempotency_id, p_idempotency_generation);
  end if;

  if not private.is_linked_guardian(v_student, v_class) then
    return jsonb_build_object('outcome','forbidden');
  end if;
  if v_state <> 'published' then
    return jsonb_build_object('outcome','invalid_state');
  end if;
  if exists (
    select 1 from public.assignments a
    where a.id = p_resource_id and now() > coalesce(a.closes_at, a.due_at)
  ) then
    return jsonb_build_object('outcome','window_closed');
  end if;

  insert into public.submissions(
    school_id, assignment_id, student_id, submitted_at, excused, status, version)
  values (v_school, p_resource_id, v_student, now(), false, 'submitted', 1)
  on conflict (assignment_id, student_id) do update set
    submitted_at = now(), status = 'submitted',
    version = public.submissions.version + 1, updated_at = now()
  returning id into v_submission;

  insert into public.submission_attempts(
    school_id, submission_id, operation_id, answer_text, submitted_at,
    submitted_by_guardian_id)
  values (v_school, v_submission, p_idempotency_id, body->>'answerText', now(),
    auth.uid())
  returning id into v_attempt;
  update public.submissions set current_attempt_id = v_attempt
  where id = v_submission;

  v_attachments := body->'attachmentFileIds';
  if v_attachments is not null
    and jsonb_array_length(coalesce(v_attachments, '[]'::jsonb)) > 0 then
    v_bind := private.file_attach_bind(
      v_attachments, 'assignment_submission'::public.file_purpose, v_school,
      p_submission_attempt => v_attempt);
    if v_bind <> 'ok' then return jsonb_build_object('outcome', v_bind); end if;
  end if;

  select jsonb_build_object(
    'id', s.id, 'assignmentId', s.assignment_id, 'studentId', s.student_id,
    'status', s.status, 'version', s.version, 'answerText', sa.answer_text,
    'submittedAt', s.submitted_at,
    'submittedByGuardianId', sa.submitted_by_guardian_id,
    'attachments', private.file_attachment_json(p_submission_attempt => v_attempt))
  into response
  from public.submissions s
  join public.submission_attempts sa on sa.id = s.current_attempt_id
  where s.id = v_submission;

  -- Named distinctly from 'assignment_submitted' so the audit trail separates
  -- work a child handed in from work a guardian handed in for them.
  insert into public.audit_events(
    school_id, actor_id, action, entity_type, entity_id, after_value, request_id)
  values (v_school, auth.uid(), 'assignment_submitted_by_guardian',
    'submission', v_submission, response, request_id);

  if not private.api_idempotency_complete(
    p_idempotency_id, p_idempotency_generation, 201, response) then
    raise exception 'API041_IDEMPOTENCY_COMPLETION_FAILED';
  end if;
  return jsonb_build_object('outcome','ok','response',response);
end;
$$;

alter function private.api041_command(text, uuid, jsonb, uuid, bigint)
  owner to postgres;
alter function private.api041_command_pre_guardian(
  text, uuid, jsonb, uuid, bigint) owner to postgres;
-- Same reason as 202609250002: the rename took the API role's EXECUTE with it.
revoke all on function private.api041_command_pre_guardian(
  text, uuid, jsonb, uuid, bigint)
  from public, anon, authenticated, service_role, studafy_worker_runtime,
  studafy_api_runtime;
revoke all on function private.api041_command(text, uuid, jsonb, uuid, bigint)
  from public, anon, authenticated, service_role, studafy_worker_runtime;
grant execute on function private.api041_command(
  text, uuid, jsonb, uuid, bigint) to studafy_api_runtime;

-- ---------------------------------------------------------------------------
-- 8. The roster read carries who handed the work in.
--
-- Wraps the query surface the same way section 7 wraps the command surface.
-- A teacher marking work needs to know a parent filed it; that is the whole
-- point of recording it.
-- ---------------------------------------------------------------------------
do $$ begin
  if not exists (
    select 1 from pg_proc p join pg_namespace n on n.oid = p.pronamespace
    where n.nspname = 'private' and p.proname = 'api041_query_pre_guardian'
  ) then
    alter function private.api041_query(text, uuid, jsonb)
      rename to api041_query_pre_guardian;
  end if;
end $$;

create or replace function private.api041_query(
  p_operation text, p_resource_id uuid, p_input jsonb)
returns jsonb language plpgsql stable security definer set search_path = '' as $$
declare
  result jsonb;
begin
  result := private.api041_query_pre_guardian(
    p_operation, p_resource_id, p_input);
  if p_operation <> 'listAssignmentSubmissions'
    or result->'items' is null then
    return result;
  end if;
  return jsonb_set(result, array['items'], (
    select coalesce(jsonb_agg(
      item || jsonb_build_object(
        'submittedByGuardianId', (
          select sa.submitted_by_guardian_id
          from public.submissions s
          join public.submission_attempts sa on sa.id = s.current_attempt_id
          where s.id = (item->>'id')::uuid)
      ) order by ordinality
    ), '[]'::jsonb)
    from jsonb_array_elements(result->'items') with ordinality as t(item, ordinality)
  ));
end;
$$;

alter function private.api041_query(text, uuid, jsonb) owner to postgres;
alter function private.api041_query_pre_guardian(text, uuid, jsonb)
  owner to postgres;
revoke all on function private.api041_query_pre_guardian(text, uuid, jsonb)
  from public, anon, authenticated, service_role, studafy_worker_runtime,
  studafy_api_runtime;
revoke all on function private.api041_query(text, uuid, jsonb)
  from public, anon, authenticated, service_role, studafy_worker_runtime;
grant execute on function private.api041_query(text, uuid, jsonb)
  to studafy_api_runtime;

-- ---------------------------------------------------------------------------
-- 9. The coarse gate: may this actor submit against this assignment at all?
--
-- The middleware only knows the action and the assignment, so this can only
-- answer "is the caller a verified guardian of some child in that class". The
-- exact subject check - is this the child they named? - stays in the command,
-- which is the only place the student id exists. Two layers, each asking what
-- it can actually see.
-- ---------------------------------------------------------------------------
do $$ begin
  if not exists (
    select 1 from pg_proc p join pg_namespace n on n.oid = p.pronamespace
    where n.nspname = 'private' and p.proname = 'authz_authorize_pre_guardian'
  ) then
    alter function private.authz_authorize(text, uuid)
      rename to authz_authorize_pre_guardian;
  end if;
end $$;

create or replace function private.authz_authorize(
  p_action text, p_resource_id uuid)
returns jsonb language plpgsql stable security definer set search_path = '' as $$
declare
  decision jsonb;
  sid uuid;
  cls uuid;
  allowed boolean := false;
begin
  decision := private.authz_authorize_pre_guardian(p_action, p_resource_id);
  if p_action <> 'assignment.submit'
    or coalesce((decision->>'allowed')::boolean, false) then
    return decision;
  end if;
  if auth.uid() is null or p_resource_id is null then return decision; end if;

  select a.school_id, a.classroom_id into sid, cls
  from public.assignments a
  where a.id = p_resource_id and a.state = 'published' and a.deleted_at is null;
  if cls is null then return decision; end if;

  select exists (
    select 1 from public.enrollments e
    where e.classroom_id = cls and e.active and e.status = 'active'
      and private.is_linked_guardian(e.student_id, cls)
  ) into allowed;
  if not allowed then return decision; end if;

  return jsonb_build_object(
    'allowed', true, 'school_id', sid, 'reason', 'linked_guardian');
end;
$$;

alter function private.authz_authorize(text, uuid) owner to postgres;
alter function private.authz_authorize_pre_guardian(text, uuid)
  owner to postgres;
revoke all on function private.authz_authorize_pre_guardian(text, uuid)
  from public, anon, authenticated, service_role, studafy_worker_runtime,
  studafy_api_runtime;
revoke all on function private.authz_authorize(text, uuid)
  from public, anon, authenticated, service_role, studafy_worker_runtime;
grant execute on function private.authz_authorize(text, uuid)
  to studafy_api_runtime;
