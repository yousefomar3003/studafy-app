-- Two faults in the upload path that only a real upload could show.
--
-- Both were invisible to the suites that covered attachments, because those
-- seeded finished file_objects rows directly instead of going through an
-- upload intent; this migration comes with tests that do the real thing.
--
--   1. file050_upload_target_check lists the purposes an upload session may
--      carry and ends `else false`. 202609250001 added message_attachment and
--      announcement_attachment without adding them here, so every chat and
--      announcement upload failed on insert. They carry no target: the
--      message or announcement they belong to is bound when it is created.
--
--   2. A guardian with no membership could not start a chat or announcement
--      upload: those name no child, and the guardian's standing was taken only
--      from a named child's link. It now comes from any verified, unexpired
--      link to a child enrolled in the school.
--
--   3. An assignment_submission session must record its student. A student
--      handing their own work in had no way to supply that - the app is never
--      told its own student record - so every student upload was refused.
--      The server now resolves it from the caller's enrolment in the
--      assignment's class. A guardian acting for a child still names the
--      child and is authorised on the verified link.
--
-- Forward-only: the two functions are re-issued from 202609250003, which has
-- already been pushed, rather than edited in place.

alter table public.upload_sessions
  drop constraint if exists file050_upload_target_check;
alter table public.upload_sessions
  add constraint file050_upload_target_check check (
    policy_version='legacy' or case purpose
      when 'profile_image' then num_nonnulls(classroom_id,assignment_id,student_id,grade_result_id)=0
      when 'lesson_resource' then classroom_id is not null and num_nonnulls(assignment_id,student_id,grade_result_id)=0
      when 'assignment_material' then assignment_id is not null and num_nonnulls(classroom_id,student_id,grade_result_id)=0
      when 'assignment_submission' then assignment_id is not null and student_id is not null and num_nonnulls(classroom_id,grade_result_id)=0
      when 'paper_scan' then grade_result_id is not null and num_nonnulls(classroom_id,assignment_id,student_id)=0
      when 'coach_attachment' then student_id is not null and num_nonnulls(classroom_id,assignment_id,grade_result_id)=0
      -- Bound to their message or announcement when that is created, so the
      -- session itself names nothing.
      when 'message_attachment' then num_nonnulls(classroom_id,assignment_id,student_id,grade_result_id)=0
      when 'announcement_attachment' then num_nonnulls(classroom_id,assignment_id,student_id,grade_result_id)=0
      else false end
  ) not valid;
alter table public.upload_sessions validate constraint file050_upload_target_check;

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
    if student_target is not null then
      -- Acting for a named child: the link to that child is the authority.
      if not private.is_linked_guardian(student_target) then
        return jsonb_build_object('allowed',false);
      end if;
      guardian_link := private.linked_guardian_link_id(student_target);
    else
      -- Naming no child - a chat or announcement attachment, whose target is
      -- bound later. The guardian's standing in this school is then a
      -- verified, unexpired link to any child enrolled here. Without this a
      -- parent with no membership, which is most of them, could read files
      -- in a conversation but never send one.
      select gl.id into guardian_link
      from public.guardian_links gl
      join public.enrollments e
        on e.student_id = gl.student_id and e.school_id = gl.school_id
        and e.active and e.status = 'active'
      where gl.school_id = sid
        and gl.guardian_id = auth.uid()
        and gl.status = 'verified'
        and (gl.expires_at is null or gl.expires_at > now())
      order by gl.verified_at desc nulls last
      limit 1;
    end if;
    if guardian_link is null then return jsonb_build_object('allowed',false); end if;
  end if;

  -- A student handing their own work in does not name themselves: the app has
  -- no reason to know its own student record, and asking it to supply one is
  -- asking it to be able to supply someone else's. Resolved here from the
  -- caller's enrolment in the assignment's class. A guardian acting for a
  -- child still names the child, and is authorised on the link below.
  if purpose_value = 'assignment_submission' and student_target is null
     and membership is not null then
    select s.id into student_target
    from public.assignments a
    join public.enrollments e
      on e.classroom_id = a.classroom_id and e.active and e.status = 'active'
    join public.students s
      on s.id = e.student_id and s.school_id = sid and s.deleted_at is null
    where a.id = nullif(p_body->>'assignmentId','')::uuid
      and s.user_id = auth.uid()
    limit 1;
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
    'membershipId',membership,'guardianLinkId',guardian_link,
    'studentId',student_target);
exception when invalid_text_representation then
  return jsonb_build_object('allowed',false);
end;
$$;

alter function private.file050_authorize_target(jsonb) owner to postgres;

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
    coalesce(nullif(p_body->>'studentId',''), authz->>'studentId')::uuid,
    nullif(p_body->>'gradeResultId','')::uuid);
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
