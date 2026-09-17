-- FILE-051: scanning, safe transformation, publication, school-scoped
-- deduplication, retention, and signed delivery that re-authorizes on every
-- request. No object becomes clean without a recorded scan verdict; no clean
-- object is delivered without a current authorization decision.

-- Retention durations stay NULL until the human retention decision (§29,
-- deferred): the sweep only deletes objects whose purpose policy carries an
-- interval. The mechanism ships now, the schedule does not.
alter table public.file_purpose_policies
  add column retention_interval_days integer
    check (retention_interval_days is null or retention_interval_days >= 1);

-- Scan/transform/dedupe evidence on the immutable object row. `sha256` stays
-- the identity of the originally uploaded content (dedupe key); `stored_*`
-- describes the bytes actually kept after transformation.
alter table public.file_objects
  add column scan_policy_version text,
  add column scan_duration_ms integer
    check (scan_duration_ms is null or scan_duration_ms >= 0),
  add column transform_policy_version text,
  add column stored_sha256 text
    check (stored_sha256 is null or stored_sha256 ~ '^[0-9a-f]{64}$'),
  add column stored_size_bytes bigint
    check (stored_size_bytes is null or stored_size_bytes >= 0),
  add column physical_deleted_at timestamptz,
  add column dedup_source_file_id uuid;

alter table public.file_objects
  add constraint file051_file_dedup_same_school_fk
    foreign key (school_id, dedup_source_file_id)
    references public.file_objects (school_id, id) on delete restrict not valid,
  add constraint file051_file_clean_scan_check check (
    policy_version = 'legacy'
    or scan_state <> 'clean'
    or (scan_policy_version is not null and scanned_at is not null)
  ) not valid,
  -- A dependent is only ever created clean; afterwards it may leave `clean`
  -- only for a terminal state (operator containment, retention deletion),
  -- never back to quarantine, because its own bytes are already gone.
  add constraint file051_file_dedup_check check (
    dedup_source_file_id is null
    or (scan_state in ('clean', 'error', 'deleted')
      and dedup_source_file_id <> id and sha256 is not null)
  ) not valid,
  add constraint file051_file_stored_pair_check check (
    num_nonnulls(stored_sha256, stored_size_bytes) in (0, 2)
  ) not valid;

-- The outbox gains two job shapes: `dedupe_delete` removes a dependent's now
-- redundant physical bytes while the row stays clean, and `retention_delete`
-- removes a whole same-school dedupe group after its retention horizon.
-- Retention jobs have no upload session, so the column becomes nullable; the
-- (session, job_type) uniqueness still covers every sessioned job.
alter table public.file_job_outbox alter column upload_session_id drop not null;
alter table public.file_job_outbox
  drop constraint if exists file_job_outbox_job_type_check;
alter table public.file_job_outbox
  add constraint file051_job_type_check check (
    job_type in ('scan', 'delete', 'dedupe_delete', 'retention_delete')
  ) not valid;

-- Single-use, short-lived delivery grants. A signed delivery URL is only the
-- carrier; the nonce recorded here is what makes one URL one download, and
-- the consume function is what re-checks authorization at request time.
create table public.file_delivery_grants (
  id uuid primary key default gen_random_uuid(),
  school_id uuid not null references public.schools (id) on delete cascade,
  file_object_id uuid not null,
  recipient_id uuid not null references public.profiles (id) on delete restrict,
  nonce_hash text not null check (nonce_hash ~ '^[0-9a-f]{64}$'),
  state text not null default 'available'
    check (state in ('available', 'consumed', 'expired')),
  expires_at timestamptz not null,
  consumed_at timestamptz,
  request_id text,
  created_at timestamptz not null default now(),
  unique (nonce_hash),
  foreign key (school_id, file_object_id)
    references public.file_objects (school_id, id) on delete restrict
);
alter table public.file_delivery_grants enable row level security;

create index file051_delivery_grant_expiry_idx
  on public.file_delivery_grants (expires_at, id) where state = 'available';
create index file051_delivery_grant_file_idx
  on public.file_delivery_grants (file_object_id, state);
-- The dedupe canonical lookup: roots only, clean only, one school.
create index file051_file_dedup_root_idx
  on public.file_objects (school_id, sha256, purpose, created_at, id)
  where scan_state = 'clean' and deleted_at is null
    and dedup_source_file_id is null and legal_hold = false;
create index file051_file_dedup_source_idx
  on public.file_objects (dedup_source_file_id)
  where dedup_source_file_id is not null;
create index file051_file_retention_idx
  on public.file_objects (retention_until, id)
  where scan_state = 'clean' and deleted_at is null and retention_until is not null;

-- ---------------------------------------------------------------------------
-- Derived download authorization.
--
-- The owner may always ask (the command still refuses anything not clean).
-- Everyone else must reach the object through a live relationship: a
-- currently published resource publication (reusing the DB-021 audience
-- helper, which itself re-checks file cleanliness), an own submission
-- attempt, or an assigned-staff/admin relationship for grading material.
-- ---------------------------------------------------------------------------
create or replace function private.file051_authorize_download(p_file_id uuid)
returns jsonb language plpgsql stable security definer set search_path = '' as $$
declare
  f public.file_objects%rowtype;
  reason text := 'denied';
begin
  if auth.uid() is null then
    return jsonb_build_object('allowed', false, 'reason', 'invalid_resource');
  end if;
  select * into f from public.file_objects fo where fo.id = p_file_id;
  if f.id is null then
    return jsonb_build_object('allowed', false, 'reason', 'invalid_resource');
  end if;
  if f.deleted_at is not null or f.scan_state = 'deleted' then
    return jsonb_build_object('allowed', false, 'schoolId', f.school_id, 'reason', 'invalid_resource');
  end if;
  if f.owner_id = auth.uid() then
    return jsonb_build_object('allowed', true, 'schoolId', f.school_id, 'reason', 'owner');
  end if;

  if exists (
    select 1 from public.file_bindings b
    join public.resource_versions rv on rv.id = b.resource_version_id
    join public.resource_publications rp on rp.resource_version_id = rv.id
    where b.file_object_id = f.id
      and rp.state = 'published' and rp.published_at is not null
      and rp.withdrawn_at is null
      and private.can_view_resource_publication(rp.id)
  ) then
    return jsonb_build_object('allowed', true, 'schoolId', f.school_id, 'reason', 'publication');
  end if;

  -- Own submission attempt: the student who authored the attempt.
  if exists (
    select 1 from public.file_bindings b
    join public.submission_attempts sa on sa.id = b.submission_attempt_id
    join public.submissions s on s.id = sa.submission_id
    join public.students st on st.id = s.student_id and st.school_id = s.school_id
    where b.file_object_id = f.id and st.user_id = auth.uid()
  ) then
    return jsonb_build_object('allowed', true, 'schoolId', f.school_id, 'reason', 'own_submission');
  end if;

  -- Grading and class material: assigned lead/co teachers and admins of the
  -- classroom the file's target belongs to.
  if exists (
    select 1 from public.file_bindings b
    join public.upload_sessions u on u.id = b.upload_session_id
    where b.file_object_id = f.id
      and (
        (u.assignment_id is not null and private.api041_class_writer(
          (select a.classroom_id from public.assignments a where a.id = u.assignment_id)))
        or (u.grade_result_id is not null and private.api041_class_writer(
          (select a.classroom_id from public.grade_results g
           join public.assessments a on a.id = g.assessment_id
           where g.id = u.grade_result_id)))
      )
  ) then
    return jsonb_build_object('allowed', true, 'schoolId', f.school_id, 'reason', 'assigned_staff');
  end if;

  return jsonb_build_object('allowed', false, 'schoolId', f.school_id, 'reason', reason);
end;
$$;

-- Resolves the physical object behind a row: a dedupe dependent is served
-- from its canonical root's bytes. Chains are depth-one by construction
-- (only roots are eligible dedupe sources).
create or replace function private.file051_effective_object(p_file_id uuid)
returns jsonb language sql stable security definer set search_path = '' as $$
  with root as (
    select r.* from public.file_objects r
    where r.id = coalesce(
      (select f.dedup_source_file_id from public.file_objects f where f.id = p_file_id),
      p_file_id)
  )
  select jsonb_build_object(
    'schoolId', r.school_id, 'bucket', r.bucket, 'objectKey', r.object_key,
    'storedSha256', r.stored_sha256, 'storedSizeBytes', r.stored_size_bytes,
    'mediaType', (select f2.detected_media_type from public.file_objects f2 where f2.id = p_file_id),
    'displayName', (select f2.display_name from public.file_objects f2 where f2.id = p_file_id),
    'rootClean', r.scan_state = 'clean' and r.deleted_at is null and r.physical_deleted_at is null)
  from root r;
$$;

-- ---------------------------------------------------------------------------
-- Delivery commands (API runtime).
-- ---------------------------------------------------------------------------

-- The download-intent command. The signed URL/token material is produced in
-- the application layer; this function validates the shape, re-authorizes,
-- records the single-use grant, audits, and completes idempotency atomically.
create or replace function private.api051_create_download_grant(
  p_file_id uuid, p_internal jsonb, p_idempotency_id uuid, p_idempotency_generation bigint)
returns jsonb language plpgsql security definer set search_path = '' as $$
declare
  f public.file_objects%rowtype;
  authz jsonb;
  expires timestamptz := (p_internal->>'expiresAt')::timestamptz;
  response jsonb;
  request_id text := nullif(current_setting('studafy.request_id', true), '');
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
    or expires > now() + interval '10 minutes' then
    return jsonb_build_object('outcome', 'invalid');
  end if;
  if f.dedup_source_file_id is not null and not coalesce(
    (private.file051_effective_object(p_file_id)->>'rootClean')::boolean, false) then
    return jsonb_build_object('outcome', 'invalid_state');
  end if;

  insert into public.file_delivery_grants(
    school_id, file_object_id, recipient_id, nonce_hash, expires_at, request_id)
  values (f.school_id, f.id, auth.uid(), p_internal->>'nonceHash', expires, request_id);

  response := jsonb_build_object(
    'downloadUrl', p_internal->>'downloadUrl', 'expiresAt', expires,
    'displayName', f.display_name, 'mediaType', f.detected_media_type);
  insert into public.audit_events(school_id, actor_id, action, entity_type, entity_id, after_value, request_id)
  values (f.school_id, auth.uid(), 'file_download_grant_issued', 'file_object', f.id,
    jsonb_build_object('reason', authz->>'reason', 'expiresAt', expires), request_id);
  if not private.api_idempotency_complete(p_idempotency_id, p_idempotency_generation, 200, response) then
    raise exception 'FILE051_IDEMPOTENCY_COMPLETION_FAILED';
  end if;
  return jsonb_build_object('outcome', 'ok', 'response', response);
end;
$$;

-- The consume step behind GET /delivery/v1/files/{id}/content. The nonce is
-- spent atomically, then authorization is re-derived from *current* state:
-- a withdrawn publication, revoked membership or non-clean object denies a
-- URL that was perfectly valid when issued. A leaked URL is therefore never
-- a standing grant: it is single-use, short-lived, bound to one recipient,
-- and re-authorized at the moment of use.
create or replace function private.api051_consume_download_grant(
  p_file_id uuid, p_nonce_hash text)
returns jsonb language plpgsql security definer set search_path = '' as $$
declare
  f public.file_objects%rowtype;
  authz jsonb;
  effective jsonb;
  request_id text := nullif(current_setting('studafy.request_id', true), '');
begin
  if auth.uid() is null or p_nonce_hash is null or p_nonce_hash !~ '^[0-9a-f]{64}$' then
    return jsonb_build_object('outcome', 'grant_invalid');
  end if;
  update public.file_delivery_grants
    set state = 'consumed', consumed_at = now()
    where nonce_hash = p_nonce_hash and file_object_id = p_file_id
      and recipient_id = auth.uid() and state = 'available' and expires_at > now();
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
  insert into public.audit_events(school_id, actor_id, action, entity_type, entity_id, after_value, request_id)
  values (f.school_id, auth.uid(), 'file_download_delivered', 'file_object', f.id,
    jsonb_build_object('reason', authz->>'reason'), request_id);
  return jsonb_build_object('outcome', 'ok', 'response', effective);
end;
$$;

-- ---------------------------------------------------------------------------
-- Publication: one file object, one resource/version, one publication.
-- Publication derives access; it never copies bytes.
-- ---------------------------------------------------------------------------
create or replace function private.api051_publish_file(
  p_file_id uuid, p_body jsonb, p_idempotency_id uuid, p_idempotency_generation bigint)
returns jsonb language plpgsql security definer set search_path = '' as $$
declare
  f public.file_objects%rowtype;
  class_id uuid;
  audience_value public.meeting_audience;
  resource_id uuid; version_id uuid; publication_id uuid;
  response jsonb;
  request_id text := nullif(current_setting('studafy.request_id', true), '');
begin
  if auth.uid() is null or request_id is null then
    return jsonb_build_object('outcome', 'forbidden');
  end if;
  audience_value := coalesce(p_body->>'audience', 'students')::public.meeting_audience;
  select * into f from public.file_objects fo where fo.id = p_file_id for update;
  if f.id is null or f.deleted_at is not null then
    return jsonb_build_object('outcome', 'not_found');
  end if;
  if f.school_id::text <> current_setting('studafy.school_id', true) then
    return jsonb_build_object('outcome', 'not_found');
  end if;
  -- The target classroom comes from the upload's own binding, never from
  -- the request; authorization is decided before any state is revealed.
  select u.classroom_id into class_id
  from public.file_bindings b
  join public.upload_sessions u on u.id = b.upload_session_id
  where b.file_object_id = f.id and b.upload_session_id is not null
  limit 1;
  if class_id is null or not coalesce(private.api041_class_writer(class_id), false) then
    return jsonb_build_object('outcome', 'not_found');
  end if;
  if f.purpose <> 'lesson_resource' then
    return jsonb_build_object('outcome', 'invalid');
  end if;
  if f.scan_state <> 'clean' then
    return jsonb_build_object('outcome', 'file_not_clean');
  end if;
  if exists (
    select 1 from public.file_bindings b
    where b.file_object_id = f.id and b.resource_version_id is not null
  ) then
    return jsonb_build_object('outcome', 'invalid_state');
  end if;

  insert into public.resources(school_id, title, resource_type, state, current_version, created_by, version)
  values (f.school_id, f.display_name, 'file', 'published', 1, auth.uid(), 1)
  returning id into resource_id;
  insert into public.resource_versions(school_id, resource_id, version, body, file_object_id, created_by)
  values (f.school_id, resource_id, 1, null, f.id, auth.uid())
  returning id into version_id;
  insert into public.resource_publications(
    school_id, resource_version_id, classroom_id, audience, state, published_at, created_by, version)
  values (f.school_id, version_id, class_id, audience_value, 'published', now(), auth.uid(), 1)
  returning id into publication_id;
  insert into public.file_bindings(school_id, file_object_id, resource_version_id)
  values (f.school_id, f.id, version_id);

  response := jsonb_build_object(
    'file', private.file050_file_json(f.id),
    'resource', private.api041_resource_json(resource_id));
  insert into public.audit_events(school_id, actor_id, action, entity_type, entity_id, after_value, request_id)
  values (f.school_id, auth.uid(), 'file_published', 'file_object', f.id,
    jsonb_build_object('resourceId', resource_id, 'publicationId', publication_id,
      'classroomId', class_id, 'audience', audience_value::text), request_id);
  if not private.api_idempotency_complete(p_idempotency_id, p_idempotency_generation, 201, response) then
    raise exception 'FILE051_IDEMPOTENCY_COMPLETION_FAILED';
  end if;
  return jsonb_build_object('outcome', 'ok', 'response', response);
end;
$$;

-- ---------------------------------------------------------------------------
-- Scan worker surface (worker runtime). Same claim/acknowledge shape as the
-- FILE-050 cleanup poller: the exact bucket/key comes from the claim, never
-- from a payload; infrastructure failures retry, verdicts are terminal.
-- ---------------------------------------------------------------------------

-- A binding to something still live blocks retention deletion. Session
-- bindings are upload provenance, not live references.
create or replace function private.file051_has_live_reference(p_file_id uuid)
returns boolean language sql stable security definer set search_path = '' as $$
  select exists (
    select 1 from public.file_bindings b
    where b.file_object_id = p_file_id
      and (
        (b.resource_version_id is not null and exists (
          select 1 from public.resource_versions rv
          join public.resources r on r.id = rv.resource_id and r.school_id = rv.school_id
          where rv.id = b.resource_version_id and r.deleted_at is null
            and r.state in ('draft', 'published')))
        or (b.submission_attempt_id is not null and exists (
          select 1 from public.submission_attempts sa
          join public.submissions s on s.id = sa.submission_id and s.school_id = sa.school_id
          where sa.id = b.submission_attempt_id and s.status in ('open', 'submitted')))
        or (b.message_id is not null and exists (
          select 1 from public.messages m where m.id = b.message_id))
        or (b.ai_grading_draft_id is not null and exists (
          select 1 from public.ai_grading_drafts d where d.id = b.ai_grading_draft_id))
      )
  );
$$;

create or replace function private.api051_claim_scan(p_worker text, p_limit integer default 10)
returns jsonb language plpgsql security definer set search_path = '' as $$
declare claimed jsonb;
begin
  if p_worker is null or length(p_worker) not between 1 and 100 or p_limit not between 1 and 100 then
    raise exception 'FILE051_INVALID_WORKER_CLAIM';
  end if;
  with candidates as (
    select j.id from public.file_job_outbox j
    where j.job_type = 'scan' and (
        (j.state in ('pending', 'retry') and j.available_at <= now())
        or (j.state = 'processing' and j.locked_at < now() - interval '10 minutes'))
    order by j.available_at, j.id for update skip locked limit p_limit
  ), updated as (
    update public.file_job_outbox j set state = 'processing',
      attempt_count = attempt_count + 1, locked_at = now(), locked_by = p_worker
    from candidates c where j.id = c.id
    returning j.id, j.upload_session_id, j.file_object_id
  ), scanning as (
    update public.file_objects f set scan_state = 'scanning'
    where f.id in (select u.file_object_id from updated u
      where u.file_object_id is not null)
      and f.scan_state in ('quarantined', 'scanning')
    returning f.id
  )
  select coalesce(jsonb_agg(jsonb_build_object(
      'jobId', u.id, 'uploadId', u.upload_session_id, 'fileId', u.file_object_id,
      'schoolId', s.school_id, 'purpose', f.purpose::text,
      'bucket', s.bucket, 'objectKey', s.object_key,
      'sizeBytes', f.size_bytes, 'sha256', f.sha256,
      'storedSha256', f.stored_sha256, 'transformPolicyVersion', f.transform_policy_version,
      'declaredMediaType', f.declared_media_type, 'detectedMediaType', f.detected_media_type)
    order by u.id), '[]'::jsonb)
  into claimed
  from updated u
  join public.upload_sessions s on s.id = u.upload_session_id
  join public.file_objects f on f.id = u.file_object_id;
  return claimed;
end;
$$;

-- Write-ahead for the transformation. The worker records the stored digest
-- it is about to write *before* overwriting the quarantined object, so a
-- retry after a lost finish can recognise its own earlier write instead of
-- mistaking it for tampering. The row stays non-clean throughout.
create or replace function private.api051_record_transform(
  p_worker text, p_job_id bigint, p_stored_sha256 text, p_stored_size_bytes bigint,
  p_transform_policy_version text)
returns boolean language plpgsql security definer set search_path = '' as $$
declare job public.file_job_outbox%rowtype;
begin
  if p_stored_sha256 is null or p_stored_sha256 !~ '^[0-9a-f]{64}$'
    or p_stored_size_bytes is null or p_stored_size_bytes < 0
    or p_transform_policy_version is null or length(p_transform_policy_version) not between 1 and 40 then
    raise exception 'FILE051_INVALID_TRANSFORM_RECORD';
  end if;
  select * into job from public.file_job_outbox
  where id = p_job_id and job_type = 'scan' and state = 'processing' and locked_by = p_worker
  for update;
  if job.id is null then return false; end if;
  update public.file_objects set stored_sha256 = p_stored_sha256,
    stored_size_bytes = p_stored_size_bytes,
    transform_policy_version = p_transform_policy_version
  where id = job.file_object_id and scan_state = 'scanning';
  return found;
end;
$$;

-- Observability: quarantine age, outcome counts and dead letters. Counts
-- only, across all schools, with no identifiers — safe for worker logs.
create or replace function private.api051_scan_backlog()
returns jsonb language sql stable security definer set search_path = '' as $$
  select jsonb_build_object(
    'quarantined', (select count(*) from public.file_objects
      where scan_state in ('quarantined', 'scanning') and policy_version <> 'legacy'),
    'oldestQuarantineSeconds', (select coalesce(extract(epoch from now() - min(created_at))::bigint, 0)
      from public.file_objects
      where scan_state in ('quarantined', 'scanning') and policy_version <> 'legacy'),
    'scanDeadLetters', (select count(*) from public.file_job_outbox
      where job_type = 'scan' and state = 'dead_letter'),
    'deleteDeadLetters', (select count(*) from public.file_job_outbox
      where job_type in ('delete', 'dedupe_delete', 'retention_delete') and state = 'dead_letter'),
    'dedupeBytesPending', (select count(*) from public.file_objects
      where dedup_source_file_id is not null and scan_state = 'clean'
        and physical_deleted_at is null));
$$;

create or replace function private.api051_finish_scan(
  p_worker text, p_job_id bigint, p_result jsonb)
returns boolean language plpgsql security definer set search_path = '' as $$
declare
  job public.file_job_outbox%rowtype;
  f public.file_objects%rowtype;
  outcome_value text := p_result->>'outcome';
  error_code text := nullif(left(coalesce(p_result->>'errorCode', ''), 80), '');
  scan_policy text := nullif(left(coalesce(p_result->>'scanPolicyVersion', ''), 40), '');
  duration_ms integer := nullif(p_result->>'scanDurationMs', '')::integer;
  transform_policy text := nullif(left(coalesce(p_result->>'transformPolicyVersion', ''), 40), '');
  stored_sha text := nullif(p_result->>'storedSha256', '');
  stored_size bigint := nullif(p_result->>'storedSizeBytes', '')::bigint;
  canonical public.file_objects%rowtype;
  retention_days integer;
  deduped boolean := false;
begin
  if p_worker is null or outcome_value not in ('clean', 'rejected', 'retry') then
    raise exception 'FILE051_INVALID_SCAN_RESULT';
  end if;
  select * into job from public.file_job_outbox
  where id = p_job_id and state = 'processing' and locked_by = p_worker for update;
  if job.id is null or job.file_object_id is null then return false; end if;
  select * into f from public.file_objects fo where fo.id = job.file_object_id for update;

  if outcome_value = 'clean' then
    if scan_policy is null or stored_sha is null or stored_sha !~ '^[0-9a-f]{64}$'
      or stored_size is null or stored_size < 0 then
      raise exception 'FILE051_INVALID_CLEAN_RESULT';
    end if;
    select p.retention_interval_days into retention_days
    from public.file_purpose_policies p where p.purpose = f.purpose;
    update public.file_objects set
      scan_state = 'clean', scanned_at = now(),
      scan_policy_version = scan_policy, scan_duration_ms = duration_ms,
      transform_policy_version = transform_policy,
      stored_sha256 = stored_sha, stored_size_bytes = stored_size,
      scan_error_code = null,
      retention_until = case when retention_days is null then null
        else now() + make_interval(days => retention_days) end
    where id = f.id and scan_state in ('scanning', 'quarantined');
    if not found then raise exception 'FILE051_SCAN_STATE_RACE'; end if;

    -- School-scoped dedupe: same school, same content hash, same purpose,
    -- both clean, neither held. The query never crosses schools, so no
    -- tenant can learn another tenant holds the same bytes.
    if not f.legal_hold then
      select * into canonical from public.file_objects c
      where c.school_id = f.school_id and c.sha256 = f.sha256
        and c.purpose = f.purpose and c.scan_state = 'clean'
        and c.deleted_at is null and c.legal_hold = false
        and c.dedup_source_file_id is null and c.id <> f.id
        and c.physical_deleted_at is null
        -- Same transform policy: the canonical bytes must be exactly what
        -- this object's own transformation produced.
        and c.transform_policy_version is not distinct from transform_policy
        and c.stored_sha256 = stored_sha
      order by c.created_at, c.id limit 1;
      if canonical.id is not null then
        update public.file_objects set
          dedup_source_file_id = canonical.id,
          stored_sha256 = canonical.stored_sha256,
          stored_size_bytes = canonical.stored_size_bytes,
          transform_policy_version = coalesce(canonical.transform_policy_version, transform_policy)
        where id = f.id;
        insert into public.file_job_outbox(school_id, upload_session_id, file_object_id, job_type)
        values (f.school_id, job.upload_session_id, f.id, 'dedupe_delete')
        on conflict (upload_session_id, job_type) do nothing;
        deduped := true;
      end if;
    end if;
    update public.file_job_outbox set state = 'completed', completed_at = now(),
      locked_at = null, locked_by = null, last_error_code = null
    where id = job.id;
    insert into public.audit_events(school_id, actor_id, action, entity_type, entity_id, after_value, request_id)
    values (f.school_id, null, 'file_scan_clean', 'file_object', f.id,
      jsonb_build_object('scanPolicyVersion', scan_policy, 'durationMs', duration_ms,
        'transformPolicyVersion', transform_policy, 'deduplicated', deduped),
      'file051-scan-' || job.id);

  elsif outcome_value = 'rejected' then
    if error_code is null or scan_policy is null then
      raise exception 'FILE051_INVALID_REJECT_RESULT';
    end if;
    update public.file_objects set
      scan_state = 'rejected', scan_error_code = error_code, scanned_at = now(),
      scan_policy_version = scan_policy, scan_duration_ms = duration_ms
    where id = f.id and scan_state in ('scanning', 'quarantined');
    if not found then raise exception 'FILE051_SCAN_STATE_RACE'; end if;
    -- A held object keeps its bytes as evidence; the runbook releases the
    -- hold explicitly. Everything else is queued for exact-key deletion.
    if not f.legal_hold then
      insert into public.file_job_outbox(school_id, upload_session_id, file_object_id, job_type)
      values (f.school_id, job.upload_session_id, f.id, 'delete')
      on conflict (upload_session_id, job_type) do nothing;
    end if;
    update public.file_job_outbox set state = 'completed', completed_at = now(),
      locked_at = null, locked_by = null, last_error_code = null
    where id = job.id;
    insert into public.audit_events(school_id, actor_id, action, entity_type, entity_id, after_value, request_id)
    values (f.school_id, null, 'file_scan_rejected', 'file_object', f.id,
      jsonb_build_object('failureCode', error_code, 'scanPolicyVersion', scan_policy,
        'legalHold', f.legal_hold), 'file051-scan-' || job.id);

  else
    -- Infrastructure failure: never clean, never terminal. The object goes
    -- back to quarantine and the job retries with capped backoff until it
    -- dead-letters into `error` for an operator.
    update public.file_objects set scan_state = 'quarantined'
    where id = f.id and scan_state = 'scanning';
    if (select attempt_count from public.file_job_outbox where id = job.id) >= 10 then
      update public.file_job_outbox set state = 'dead_letter', locked_at = null,
        locked_by = null, last_error_code = coalesce(nullif(error_code, ''), 'SCAN_INFRASTRUCTURE')
      where id = job.id;
      update public.file_objects set scan_state = 'error',
        scan_error_code = coalesce(nullif(error_code, ''), 'SCAN_INFRASTRUCTURE')
      where id = f.id;
      insert into public.audit_events(school_id, actor_id, action, entity_type, entity_id, after_value, request_id)
      values (f.school_id, null, 'file_scan_failed', 'file_object', f.id,
        jsonb_build_object('failureCode', error_code, 'attempts', job.attempt_count),
        'file051-scan-' || job.id);
    else
      update public.file_job_outbox set state = 'retry',
        available_at = now() + make_interval(secs => least(3600, 5 * (2 ^ least(attempt_count, 9))::integer)),
        locked_at = null, locked_by = null,
        last_error_code = left(coalesce(nullif(error_code, ''), 'SCAN_INFRASTRUCTURE'), 80)
      where id = job.id;
    end if;
  end if;
  return true;
end;
$$;

-- FILE-050's cleanup claim gains a legal-hold guard and consumes FILE-051's
-- `dedupe_delete` jobs: an object under hold is never handed to the deleter,
-- and a deduped dependent's redundant bytes are removed while its row stays
-- clean (the finish function below records the physical deletion only).
create or replace function private.api050_claim_cleanup(p_worker text, p_limit integer default 20)
returns jsonb language plpgsql security definer set search_path = '' as $$
declare claimed jsonb;
begin
  if p_worker is null or length(p_worker) not between 1 and 100 or p_limit not between 1 and 100 then
    raise exception 'FILE050_INVALID_WORKER_CLAIM';
  end if;
  with expired as (
    update public.upload_sessions u set state = 'expired', updated_at = now()
    where u.state = 'initiated' and u.expires_at <= now()
    returning u.school_id, u.id, u.file_object_id
  )
  insert into public.file_job_outbox(school_id, upload_session_id, file_object_id, job_type)
  select school_id, id, file_object_id, 'delete' from expired
    where file_object_id is null or not exists (
      select 1 from public.file_objects f where f.id = file_object_id and f.legal_hold)
  on conflict (upload_session_id, job_type) do nothing;

  with candidates as (
    select j.id from public.file_job_outbox j
    where j.job_type in ('delete', 'dedupe_delete')
      and j.state in ('pending', 'retry') and j.available_at <= now()
      and (j.file_object_id is null or not exists (
        select 1 from public.file_objects f where f.id = j.file_object_id and f.legal_hold))
    order by j.available_at, j.id for update skip locked limit p_limit
  ), updated as (
    update public.file_job_outbox j set state = 'processing', attempt_count = attempt_count + 1,
      locked_at = now(), locked_by = p_worker
    from candidates c where j.id = c.id
    returning j.id, j.upload_session_id, j.file_object_id, j.job_type
  )
  select coalesce(jsonb_agg(jsonb_build_object('jobId', u.id, 'uploadId', u.upload_session_id,
    'fileId', u.file_object_id, 'jobType', u.job_type,
    'bucket', s.bucket, 'objectKey', s.object_key) order by u.id), '[]'::jsonb)
  into claimed from updated u join public.upload_sessions s on s.id = u.upload_session_id;
  return claimed;
end;
$$;

-- The finish side of the same extension: a deduped dependent's row remains
-- `clean` with its physical deletion recorded; everything else keeps the
-- FILE-050 behaviour (rows reach `deleted` only after storage confirmed).
create or replace function private.api050_finish_cleanup(
  p_worker text, p_job_id bigint, p_succeeded boolean, p_error_code text default null)
returns boolean language plpgsql security definer set search_path = '' as $$
declare job public.file_job_outbox%rowtype;
begin
  select * into job from public.file_job_outbox
  where id = p_job_id and state = 'processing' and locked_by = p_worker for update;
  if job.id is null then return false; end if;
  if p_succeeded then
    update public.file_job_outbox set state = 'completed', completed_at = now(),
      locked_at = null, locked_by = null, last_error_code = null
    where id = job.id;
    if job.job_type = 'dedupe_delete' then
      update public.file_objects set physical_deleted_at = now()
      where id = job.file_object_id and scan_state = 'clean'
        and dedup_source_file_id is not null and physical_deleted_at is null;
      insert into public.audit_events(school_id, actor_id, action, entity_type, entity_id, after_value, request_id)
      values (job.school_id, null, 'dedupe_object_deleted', 'file_object', job.file_object_id,
        jsonb_build_object('jobId', job.id), 'file051-cleanup-' || job.id);
    else
      if job.file_object_id is not null then
        update public.file_objects set scan_state = 'deleted', deleted_at = now(), physical_deleted_at = now()
        where id = job.file_object_id and scan_state in ('rejected', 'error');
      end if;
      insert into public.audit_events(school_id, actor_id, action, entity_type, entity_id, after_value, request_id)
      values (job.school_id, null, 'quarantine_object_deleted', 'upload_session', job.upload_session_id,
        jsonb_build_object('fileId', job.file_object_id, 'jobId', job.id), 'file050-cleanup-' || job.id);
    end if;
  else
    update public.file_job_outbox set
      state = case when attempt_count >= 10 then 'dead_letter'::public.outbox_state
        else 'retry'::public.outbox_state end,
      available_at = now() + make_interval(secs => least(3600, 5 * (2 ^ least(attempt_count, 9))::integer)),
      locked_at = null, locked_by = null,
      last_error_code = left(coalesce(p_error_code, 'STORAGE_UNAVAILABLE'), 80)
    where id = job.id;
  end if;
  return true;
end;
$$;

-- ---------------------------------------------------------------------------
-- Retention sweep (worker runtime). Deletes one physical object — a dedupe
-- root and its dependents — only when every member is past its horizon,
-- unheld, unreferenced, and has no other deletion in flight.
-- ---------------------------------------------------------------------------

create or replace function private.api051_expire_delivery_grants()
returns integer language plpgsql security definer set search_path = '' as $$
declare expired_count integer;
begin
  update public.file_delivery_grants set state = 'expired'
  where state = 'available' and expires_at <= now();
  get diagnostics expired_count = row_count;
  return expired_count;
end;
$$;

create or replace function private.api051_claim_retention(p_worker text, p_limit integer default 5)
returns jsonb language plpgsql security definer set search_path = '' as $$
declare
  claimed jsonb := '[]'::jsonb;
  candidate public.file_objects%rowtype;
  member public.file_objects%rowtype;
  job_id bigint;
  members uuid[];
  eligible boolean;
  retry_root uuid;
  taken integer := 0;
begin
  if p_worker is null or length(p_worker) not between 1 and 100 or p_limit not between 1 and 100 then
    raise exception 'FILE051_INVALID_WORKER_CLAIM';
  end if;
  perform private.api051_expire_delivery_grants();

  -- The unit of deletion is one physical object: a dedupe root plus every
  -- dependent served from its bytes. Roots with different content hashes
  -- or purposes are separate objects and separate units.
  for candidate in
    select * from public.file_objects r
    where r.scan_state = 'clean' and r.deleted_at is null
      and r.dedup_source_file_id is null
      and r.retention_until is not null and r.retention_until <= now()
    order by r.retention_until, r.id
    for update skip locked
  loop
    exit when taken >= p_limit;
    members := '{}';
    eligible := true;
    for member in
      select * from public.file_objects m
      where m.school_id = candidate.school_id
        and (m.id = candidate.id or m.dedup_source_file_id = candidate.id)
        and m.deleted_at is null
      order by (m.id = candidate.id) desc, m.id
      for update
    loop
      -- One ineligible member blocks the whole unit: shared bytes make the
      -- group the only safe unit. A dependent whose redundant copy has not
      -- been removed yet would be orphaned, so it blocks too.
      if member.scan_state <> 'clean' or member.legal_hold
        or member.retention_until is null or member.retention_until > now()
        or private.file051_has_live_reference(member.id)
        or (member.id <> candidate.id and member.physical_deleted_at is null)
        or exists (
          select 1 from public.file_job_outbox j
          where j.file_object_id = member.id
            and j.job_type in ('retention_delete', 'dedupe_delete', 'delete')
            and j.state in ('pending', 'retry', 'processing'))
      then
        eligible := false;
        exit;
      end if;
      members := members || member.id;
    end loop;
    if not eligible or cardinality(members) = 0 then
      continue;
    end if;

    insert into public.file_job_outbox(school_id, file_object_id, job_type, state,
      attempt_count, available_at, locked_at, locked_by)
    values (candidate.school_id, candidate.id, 'retention_delete', 'processing', 1, now(), now(), p_worker)
    returning id into job_id;
    claimed := claimed || jsonb_build_array(jsonb_build_object(
      'jobId', job_id, 'schoolId', candidate.school_id, 'rootFileId', candidate.id,
      'memberFileIds', to_jsonb(members), 'bucket', candidate.bucket,
      'objectKey', candidate.object_key));
    taken := taken + 1;
  end loop;

  -- Retention jobs that failed and are due again are re-claimed here too.
  for job_id, retry_root in
    select j.id, j.file_object_id from public.file_job_outbox j
    where j.job_type = 'retention_delete' and j.state = 'retry' and j.available_at <= now()
    order by j.available_at, j.id
    for update skip locked
    limit greatest(p_limit - taken, 0)
  loop
    update public.file_job_outbox set state = 'processing', attempt_count = attempt_count + 1,
      locked_at = now(), locked_by = p_worker
    where id = job_id;
    select * into candidate from public.file_objects where id = retry_root;
    select coalesce(array_agg(m.id order by (m.id = candidate.id) desc, m.id), '{}') into members
    from public.file_objects m
    where m.school_id = candidate.school_id
      and (m.id = candidate.id or m.dedup_source_file_id = candidate.id)
      and m.deleted_at is null;
    claimed := claimed || jsonb_build_array(jsonb_build_object(
      'jobId', job_id, 'schoolId', candidate.school_id, 'rootFileId', candidate.id,
      'memberFileIds', to_jsonb(members), 'bucket', candidate.bucket,
      'objectKey', candidate.object_key));
  end loop;
  return claimed;
end;
$$;

create or replace function private.api051_finish_retention(
  p_worker text, p_job_id bigint, p_succeeded boolean, p_error_code text default null)
returns boolean language plpgsql security definer set search_path = '' as $$
declare
  job public.file_job_outbox%rowtype;
  root public.file_objects%rowtype;
  member_ids uuid[];
begin
  select * into job from public.file_job_outbox
  where id = p_job_id and state = 'processing' and locked_by = p_worker for update;
  if job.id is null then return false; end if;
  select * into root from public.file_objects f where f.id = job.file_object_id;
  if root.id is null then return false; end if;

  if p_succeeded then
    select coalesce(array_agg(f.id order by f.id), '{}') into member_ids
    from public.file_objects f
    where f.school_id = root.school_id
      and (f.id = root.id or f.dedup_source_file_id = root.id)
      and f.scan_state = 'clean' and f.deleted_at is null;
    update public.file_objects set scan_state = 'deleted', deleted_at = now(),
      physical_deleted_at = now()
    where id = any(member_ids) and scan_state = 'clean' and deleted_at is null;
    update public.file_job_outbox set state = 'completed', completed_at = now(),
      locked_at = null, locked_by = null, last_error_code = null
    where id = job.id;
    insert into public.audit_events(school_id, actor_id, action, entity_type, entity_id, after_value, request_id)
    values (root.school_id, null, 'retention_objects_deleted', 'file_object', root.id,
      jsonb_build_object('fileIds', to_jsonb(member_ids), 'jobId', job.id),
      'file051-retention-' || job.id);
  else
    update public.file_job_outbox set
      state = case when attempt_count >= 10 then 'dead_letter'::public.outbox_state
        else 'retry'::public.outbox_state end,
      available_at = now() + make_interval(secs => least(3600, 5 * (2 ^ least(attempt_count, 9))::integer)),
      locked_at = null, locked_by = null,
      last_error_code = left(coalesce(p_error_code, 'STORAGE_UNAVAILABLE'), 80)
    where id = job.id;
  end if;
  return true;
end;
$$;

-- ---------------------------------------------------------------------------
-- Malicious-file response (operator only; see
-- docs/security/file051-malicious-file-runbook.md). Neither function is
-- granted to any runtime role: they run from an audited operator session.
-- ---------------------------------------------------------------------------

-- Containment: the whole same-school dedupe group sharing the reported
-- object's bytes leaves `clean` (so every delivery path denies at once),
-- every publication of it is withdrawn, outstanding grants are expired, and
-- a legal hold preserves the bytes as evidence until the release step.
create or replace function private.file051_contain_object(
  p_file_id uuid, p_operator uuid, p_reason text)
returns jsonb language plpgsql security definer set search_path = '' as $$
declare
  f public.file_objects%rowtype;
  root_id uuid;
  group_ids uuid[];
  withdrawn integer;
  expired integer;
begin
  if p_reason is null or length(p_reason) not between 3 and 200 then
    raise exception 'FILE051_CONTAINMENT_REASON_REQUIRED';
  end if;
  select * into f from public.file_objects where id = p_file_id for update;
  if f.id is null then raise exception 'FILE051_FILE_NOT_FOUND'; end if;
  root_id := coalesce(f.dedup_source_file_id, f.id);
  select array_agg(g.id order by g.id) into group_ids
  from public.file_objects g
  where g.school_id = f.school_id
    and (g.id = root_id or g.dedup_source_file_id = root_id);

  perform 1 from public.file_objects g where g.id = any(group_ids) for update;
  update public.file_objects set
    scan_state = case when scan_state = 'deleted' then scan_state else 'error' end,
    scan_error_code = case when scan_state = 'deleted' then scan_error_code
      else 'operator_contained' end,
    legal_hold = true
  where id = any(group_ids);

  update public.resource_publications rp set state = 'withdrawn',
    withdrawn_at = coalesce(rp.withdrawn_at, now()), version = rp.version + 1
  where rp.state = 'published' and rp.resource_version_id in (
    select b.resource_version_id from public.file_bindings b
    where b.file_object_id = any(group_ids) and b.resource_version_id is not null);
  get diagnostics withdrawn = row_count;
  update public.resources r set state = 'withdrawn', version = r.version + 1
  where r.state = 'published' and r.id in (
    select rv.resource_id from public.resource_versions rv
    join public.file_bindings b on b.resource_version_id = rv.id
    where b.file_object_id = any(group_ids));

  update public.file_delivery_grants set state = 'expired'
  where file_object_id = any(group_ids) and state = 'available';
  get diagnostics expired = row_count;

  insert into public.audit_events(school_id, actor_id, action, entity_type, entity_id, after_value, request_id)
  values (f.school_id, p_operator, 'file_contained', 'file_object', root_id,
    jsonb_build_object('fileIds', to_jsonb(group_ids), 'reason', p_reason,
      'publicationsWithdrawn', withdrawn, 'grantsExpired', expired),
    'file051-contain-' || root_id);
  return jsonb_build_object('rootFileId', root_id, 'fileIds', to_jsonb(group_ids),
    'publicationsWithdrawn', withdrawn, 'grantsExpired', expired);
end;
$$;

-- Release: after evidence is preserved, lift the hold and queue exact-key
-- deletion. Dependents whose bytes were already removed by dedupe go
-- straight to `deleted`; everything else is deleted by the cleanup worker,
-- which only moves a row to `deleted` after storage confirms.
create or replace function private.file051_release_contained_object(
  p_file_id uuid, p_operator uuid)
returns jsonb language plpgsql security definer set search_path = '' as $$
declare
  f public.file_objects%rowtype;
  root_id uuid;
  group_ids uuid[];
  queued integer;
begin
  select * into f from public.file_objects where id = p_file_id;
  if f.id is null then raise exception 'FILE051_FILE_NOT_FOUND'; end if;
  root_id := coalesce(f.dedup_source_file_id, f.id);
  select array_agg(g.id order by g.id) into group_ids
  from public.file_objects g
  where g.school_id = f.school_id
    and (g.id = root_id or g.dedup_source_file_id = root_id)
    and g.scan_state = 'error' and g.scan_error_code = 'operator_contained';
  if group_ids is null then raise exception 'FILE051_NOT_CONTAINED'; end if;

  update public.file_objects set legal_hold = false where id = any(group_ids);
  update public.file_objects set scan_state = 'deleted', deleted_at = now()
  where id = any(group_ids) and physical_deleted_at is not null;

  insert into public.file_job_outbox(school_id, upload_session_id, file_object_id, job_type)
  select g.school_id, b.upload_session_id, g.id, 'delete'
  from public.file_objects g
  join public.file_bindings b on b.file_object_id = g.id and b.upload_session_id is not null
  where g.id = any(group_ids) and g.physical_deleted_at is null
  on conflict (upload_session_id, job_type) do update
    set state = 'pending', available_at = now(), attempt_count = 0,
      locked_at = null, locked_by = null, last_error_code = null, completed_at = null;
  get diagnostics queued = row_count;

  insert into public.audit_events(school_id, actor_id, action, entity_type, entity_id, after_value, request_id)
  values (f.school_id, p_operator, 'file_containment_released', 'file_object', root_id,
    jsonb_build_object('fileIds', to_jsonb(group_ids), 'deletesQueued', queued),
    'file051-release-' || root_id);
  return jsonb_build_object('rootFileId', root_id, 'fileIds', to_jsonb(group_ids),
    'deletesQueued', queued);
end;
$$;

-- ---------------------------------------------------------------------------
-- AUTH-031 extension (rename-and-fallback, third link in the chain).
-- `file.download` now derives from the audience matrix instead of ownership
-- alone; `file.publish` gates the publication command. Every command
-- function still re-checks its own relationship before mutating.
-- ---------------------------------------------------------------------------
alter function private.authz_authorize(text, uuid) rename to authz_authorize_pre_file051;
create or replace function private.authz_authorize(p_action text, p_resource_id uuid)
returns jsonb language plpgsql stable security definer set search_path = '' as $$
declare sid uuid; allowed boolean := false;
begin
  if p_action not in ('file.download', 'file.publish') then
    return private.authz_authorize_pre_file051(p_action, p_resource_id);
  end if;
  if auth.uid() is null or p_resource_id is null then
    return jsonb_build_object('allowed', false, 'school_id', null, 'reason', 'invalid_resource');
  end if;
  if p_action = 'file.publish' then
    select f.school_id,
      (f.owner_id = auth.uid() or private.is_school_admin(f.school_id))
    into sid, allowed
    from public.file_objects f where f.id = p_resource_id;
  else
    select f.school_id into sid from public.file_objects f where f.id = p_resource_id;
    allowed := coalesce(
      (private.file051_authorize_download(p_resource_id) ->> 'allowed')::boolean, false);
  end if;
  return jsonb_build_object('allowed', coalesce(allowed, false), 'school_id', sid,
    'reason', case when sid is null then 'invalid_resource' when allowed then 'allowed' else 'denied' end);
end;
$$;

-- ---------------------------------------------------------------------------
-- Ownership and grants.
-- ---------------------------------------------------------------------------
alter function private.file051_authorize_download(uuid) owner to postgres;
alter function private.file051_effective_object(uuid) owner to postgres;
alter function private.api051_create_download_grant(uuid, jsonb, uuid, bigint) owner to postgres;
alter function private.api051_consume_download_grant(uuid, text) owner to postgres;
alter function private.api051_publish_file(uuid, jsonb, uuid, bigint) owner to postgres;
alter function private.file051_has_live_reference(uuid) owner to postgres;
alter function private.api051_claim_scan(text, integer) owner to postgres;
alter function private.api051_finish_scan(text, bigint, jsonb) owner to postgres;
alter function private.api051_scan_backlog() owner to postgres;
alter function private.api051_record_transform(text, bigint, text, bigint, text) owner to postgres;
alter function private.api051_expire_delivery_grants() owner to postgres;
alter function private.api051_claim_retention(text, integer) owner to postgres;
alter function private.api051_finish_retention(text, bigint, boolean, text) owner to postgres;
alter function private.authz_authorize(text, uuid) owner to postgres;
alter function private.file051_contain_object(uuid, uuid, text) owner to postgres;
alter function private.file051_release_contained_object(uuid, uuid) owner to postgres;

revoke all on function private.file051_contain_object(uuid, uuid, text),
  private.file051_release_contained_object(uuid, uuid)
  from public, anon, authenticated, service_role, studafy_api_runtime, studafy_worker_runtime;

-- FILE-050 granted the worker its narrow functions but never USAGE on the
-- schema that holds them, so the file workers could only ever run as a
-- privileged role. Usage on the schema grants nothing by itself; every
-- function remains individually revoked or granted below.
grant usage on schema private to studafy_worker_runtime;

revoke all privileges on public.file_delivery_grants
  from public, anon, authenticated, service_role, studafy_api_runtime, studafy_worker_runtime;
revoke all on function private.authz_authorize_pre_file051(text, uuid)
  from public, anon, authenticated, service_role, studafy_api_runtime, studafy_worker_runtime;
revoke all on function private.file051_authorize_download(uuid),
  private.file051_effective_object(uuid), private.file051_has_live_reference(uuid)
  from public, anon, authenticated, service_role, studafy_api_runtime, studafy_worker_runtime;
revoke all on function private.api051_create_download_grant(uuid, jsonb, uuid, bigint),
  private.api051_consume_download_grant(uuid, text),
  private.api051_publish_file(uuid, jsonb, uuid, bigint),
  private.authz_authorize(text, uuid)
  from public, anon, authenticated, service_role, studafy_worker_runtime;
grant execute on function private.api051_create_download_grant(uuid, jsonb, uuid, bigint),
  private.api051_consume_download_grant(uuid, text),
  private.api051_publish_file(uuid, jsonb, uuid, bigint),
  private.authz_authorize(text, uuid) to studafy_api_runtime;
revoke all on function private.api051_claim_scan(text, integer),
  private.api051_finish_scan(text, bigint, jsonb),
  private.api051_record_transform(text, bigint, text, bigint, text),
  private.api051_scan_backlog(),
  private.api051_expire_delivery_grants(),
  private.api051_claim_retention(text, integer),
  private.api051_finish_retention(text, bigint, boolean, text)
  from public, anon, authenticated, service_role, studafy_api_runtime;
grant execute on function private.api051_claim_scan(text, integer),
  private.api051_finish_scan(text, bigint, jsonb),
  private.api051_record_transform(text, bigint, text, bigint, text),
  private.api051_scan_backlog(),
  private.api051_expire_delivery_grants(),
  private.api051_claim_retention(text, integer),
  private.api051_finish_retention(text, bigint, boolean, text)
  to studafy_worker_runtime;

alter table public.file_objects validate constraint file051_file_dedup_same_school_fk;
alter table public.file_objects validate constraint file051_file_clean_scan_check;
alter table public.file_objects validate constraint file051_file_dedup_check;
alter table public.file_objects validate constraint file051_file_stored_pair_check;
alter table public.file_job_outbox validate constraint file051_job_type_check;
