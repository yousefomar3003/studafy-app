-- The retention schedule (DL-057, decided 2026-10-14; proposed defaults for
-- counsel to confirm). Privacy policy §10 now promises fixed periods; this
-- migration makes the database keep them. The worker runs the purges
-- (apps/worker/src/processors/retentionSweep.ts, RETENTION_SCHEDULE_ENABLED).
--
--   * Academic records, hand-ins, files, messages and voice notes: deleted
--     12 months after the class is closed or its last teacher's account is
--     deleted, unless the school has recorded a retention instruction
--     (private.school_retention_instructions). A class's closure is its
--     archived_at; deleting the last teacher now archives the class.
--     The class row, students' own notebooks and the school's lessons stay;
--     academic_records_purged_at marks a class whose records are gone.
--     Conversations have no class, so one is due once its participants share
--     no class any more and its last message is 12 months old.
--   * Security and access logs (audit_events, auth_security_events,
--     membership_events): 2 years. Consent and account-deletion records:
--     the life of the account, then 6 years. Account deletion therefore no
--     longer deletes consent_records.
--   * Billing records: 6 years after the end of the tax year (the calendar
--     year, Ireland) they relate to.
--   * Inactive accounts: warned after 23 months without activity, a deletion
--     request (14-day grace, the existing executor) opened at 24 months and
--     no sooner than 16 days after a warning that reached the person.
--   * The legacy AI rows retired by ADR-0026 are deleted.
--
-- Append-only relations stay append-only for every role. A DELETE passes the
-- guard only when the table owner runs it with studafy.retention_purge set
-- for the transaction, which only the purge functions below do; the owner
-- could already disable the trigger, so this grants nothing new. UPDATE is
-- still always refused.

-- 1. The guards let the owner's timed purge through, and nothing else.
--    Both become security invoker so that current_user is whoever runs the
--    DELETE, not the function's owner.
create or replace function private.reject_append_only_mutation()
returns trigger
language plpgsql
security invoker
set search_path = ''
as $$
begin
  if tg_op = 'DELETE' and current_user = 'postgres'
     and coalesce(current_setting('studafy.retention_purge', true), '') = 'on' then
    return old;
  end if;
  raise exception 'Append-only relation cannot be updated or deleted';
end;
$$;

create or replace function private.api041_reject_history_change()
returns trigger
language plpgsql
security invoker
set search_path = ''
as $$
begin
  if tg_op = 'DELETE' and current_user = 'postgres'
     and coalesce(current_setting('studafy.retention_purge', true), '') = 'on' then
    return old;
  end if;
  raise exception 'API041_IMMUTABLE_HISTORY';
end;
$$;

-- 2. A school's own retention instruction. With one recorded, its classes
--    and conversations follow academic_retention_months instead of 12; with
--    a null period they are kept until the school asks for deletion. There
--    is no school administrator in this release, so we record these on the
--    school's written instruction.
alter table public.classrooms add column academic_records_purged_at timestamptz;

create table private.school_retention_instructions (
  school_id uuid primary key references public.schools(id) on delete cascade,
  academic_retention_months integer
    check (academic_retention_months is null or academic_retention_months between 1 and 600),
  instruction_reference text not null
    check (length(instruction_reference) between 1 and 500),
  recorded_at timestamptz not null default now()
);

-- 3. Inactive-account warnings. A row means the person was warned (in the
--    app when they have a school to hold the notification; emailed_at is for
--    the email sender once one is configured). A deletion request follows
--    only a warning that reached them.
create table private.inactive_account_warnings (
  user_id uuid primary key references public.profiles(id) on delete cascade,
  last_active_at timestamptz not null,
  warned_at timestamptz not null default now(),
  notified_school_id uuid references public.schools(id) on delete set null,
  emailed_at timestamptz,
  deletion_request_id uuid
    references public.account_deletion_requests(id) on delete set null
);

alter table public.account_deletion_requests
  drop constraint account_deletion_requests_requested_via_check,
  add constraint account_deletion_requests_requested_via_check
    check (requested_via in ('in_app', 'support', 'school_admin', 'system'));

-- 4. Account deletion keeps consent records (§10: life of the account, then
--    6 years) and closes the classes nobody can teach any more. Otherwise
--    unchanged from 202610110004.
create or replace function private.account_deletion_execute(p_request_id uuid)
returns text language plpgsql security definer set search_path = '' as $$
declare
  req public.account_deletion_requests%rowtype;
  subject uuid;
  subject_email text;
  child uuid;
  child_request uuid;
  orphaned record;
begin
  select * into req from public.account_deletion_requests
  where id = p_request_id for update;
  if req.id is null then return 'lost'; end if;
  if req.state = 'completed' then return 'completed'; end if;
  if req.state = 'cancelled' then return 'cancelled'; end if;
  if req.state = 'grace_period' and req.execute_after > now() then
    return 'not_due';
  end if;
  if private.account_deletion_blocked_by_hold(req) then
    -- Return it to the grace state so the claim loop stops picking it up;
    -- releasing the hold makes it due again.
    update public.account_deletion_requests
      set state = 'grace_period', version = version + 1
      where id = req.id and state = 'executing';
    return 'held';
  end if;
  subject := req.user_id;
  -- Read before step 1 replaces it: invitations are matched on it below.
  select lower(u.email) into subject_email from auth.users u where u.id = subject;

  -- 1. No more sign-in, and no identifying data left in the auth schema.
  delete from auth.identities where user_id = subject;
  delete from auth.sessions where user_id = subject;
  delete from auth.refresh_tokens where user_id = subject::text;
  delete from auth.mfa_factors where user_id = subject;
  delete from auth.one_time_tokens where user_id = subject;
  update auth.users set
    email = 'deleted+' || subject::text || '@deleted.invalid',
    phone = null,
    email_change = '',
    phone_change = '',
    encrypted_password = '',
    raw_user_meta_data = '{}'::jsonb,
    raw_app_meta_data = jsonb_build_object('provider', 'deleted'),
    banned_until = 'infinity'::timestamptz
  where id = subject;

  -- 2. The profile becomes a nameless tombstone, and the rosters lose the
  --    name too.
  update public.profiles
    set display_name = 'Deleted user', locale = 'en', status = 'deleted',
        gender = null,
        deleted_at = coalesce(deleted_at, now())
    where id = subject;
  update public.students
    set display_name = 'Deleted student'
    where user_id = subject and display_name <> 'Deleted student';

  -- 2a. A class this person was the last teacher of is closed: nobody can
  --     teach it any more, and its retention period (§10) starts now.
  for orphaned in
    select c.id, c.school_id from public.classrooms c
    where c.archived_at is null
      and (c.teacher_id = subject or exists (
        select 1 from public.classroom_staff cs
        where cs.classroom_id = c.id and cs.user_id = subject
          and cs.role in ('lead_teacher', 'co_teacher')))
      and not exists (
        select 1 from public.classroom_staff cs
        join public.memberships m on m.id = cs.membership_id
        join public.profiles p on p.id = cs.user_id
        where cs.classroom_id = c.id and cs.user_id <> subject
          and cs.status = 'active' and cs.role in ('lead_teacher', 'co_teacher')
          and m.active and p.deleted_at is null)
    for update of c
  loop
    update public.classrooms
      set status = 'archived', archived_at = now(), version = version + 1,
          updated_at = now()
      where id = orphaned.id;
    update public.class_join_links set revoked_at = coalesce(revoked_at, now())
      where classroom_id = orphaned.id;
    insert into public.audit_events(school_id, actor_id, action, entity_type, entity_id, after_value, request_id)
    values (orphaned.school_id, null, 'classroom_archived', 'classroom', orphaned.id,
      jsonb_build_object('cause', 'last_teacher_deleted'),
      'account-deletion-' || req.id::text);
  end loop;

  -- 3. Every grant of authority ends.
  update public.memberships
    set active = false, status = 'revoked'
    where user_id = subject and status <> 'revoked';
  update public.guardian_links
    set status = 'revoked'
    where guardian_id = subject and status in ('pending', 'verified');
  update public.conversation_participants
    set left_at = coalesce(left_at, now())
    where user_id = subject;
  delete from public.auth_devices where user_id = subject;
  delete from public.auth_reauth_grants where user_id = subject;
  delete from public.auth_identity_links where user_id = subject;
  delete from public.platform_operators where user_id = subject;
  delete from private.managed_accounts where child_id = subject;

  -- 3a. The child accounts this person manages go with them. Each runs
  --     through this same function, so a held child is left for later.
  for child in
    select m.child_id from private.managed_accounts m
    join public.profiles p on p.id = m.child_id
    where m.guardian_id = subject and p.deleted_at is null
    order by m.child_id
  loop
    select r.id into child_request from public.account_deletion_requests r
    where r.user_id = child and r.state in ('grace_period', 'executing');
    if child_request is null then
      insert into public.account_deletion_requests (
        user_id, execute_after, reason_code, impact_snapshot)
      values (child, now(), 'undisclosed', jsonb_build_object(
        'cause', 'managing_guardian_deleted',
        'guardianDeletionRequestId', req.id))
      returning id into child_request;
    else
      update public.account_deletion_requests
        set execute_after = least(execute_after, now()), version = version + 1
        where id = child_request;
    end if;
    perform private.account_deletion_execute(child_request);
  end loop;

  -- 4. Personal-only data with no retention purpose. Consent records stay:
  --    private.retention_purge_records deletes them 6 years from now.
  delete from public.user_blocks where blocker_id = subject or blocked_id = subject;
  delete from public.notification_preferences where user_id = subject;
  delete from public.notification_deliveries where recipient_id = subject;
  delete from public.notification_outbox where recipient_id = subject;
  delete from public.notifications where user_id = subject;
  delete from public.push_devices where user_id = subject;
  delete from public.data_export_requests where user_id = subject;
  delete from public.billing_purchase_approvals
    where student_user_id = subject and status in ('requested', 'approved');
  delete from public.study_notebooks where owner_id = subject;
  delete from public.notebook_entries where owner_id = subject;
  delete from private.ai_usage where user_id = subject;
  delete from private.inactive_account_warnings where user_id = subject;
  update public.invitations
    set email = 'deleted+' || id::text || '@deleted.invalid',
        status = case when status = 'pending' then 'revoked'::public.invitation_status else status end,
        revoked_at = case when status = 'pending' then now() else revoked_at end,
        version = version + 1, updated_at = now()
    where accepted_by = subject
       or (status = 'pending' and subject_email is not null and email = subject_email);
  -- The retention sweep (private.api051_claim_retention) removes the bytes
  -- of clean, unheld files whose retention has ended and that nothing
  -- school-owned still references.
  update public.file_objects
    set retention_until = now()
    where coalesce(owner_id, uploader_id) = subject
      and purpose in ('profile_image', 'notebook_photo', 'assistant_attachment')
      and deleted_at is null and not legal_hold
      and (retention_until is null or retention_until > now());

  -- 5. Record completion. The audit row names the request, not the person.
  update public.account_deletion_requests
    set state = 'completed', completed_at = now(), version = version + 1
    where id = req.id;
  insert into public.audit_events(school_id, actor_id, action, entity_type, entity_id, after_value, request_id)
  values (null, null, 'account_deleted', 'account_deletion_request', req.id,
    jsonb_build_object('classification', req.education_record_classification),
    'account-deletion-' || req.id::text);
  return 'completed';
end;
$$;

-- Classes whose teachers were deleted before 2a existed close as of that
-- deletion.
with orphaned as (
  select c.id, (
    select max(p.deleted_at) from public.classroom_staff cs
    join public.profiles p on p.id = cs.user_id
    where cs.classroom_id = c.id and cs.role in ('lead_teacher', 'co_teacher')
  ) as closed_at
  from public.classrooms c
  where c.archived_at is null
    and exists (
      select 1 from public.classroom_staff cs
      where cs.classroom_id = c.id and cs.role in ('lead_teacher', 'co_teacher'))
    and not exists (
      select 1 from public.classroom_staff cs
      join public.memberships m on m.id = cs.membership_id
      join public.profiles p on p.id = cs.user_id
      where cs.classroom_id = c.id and cs.status = 'active'
        and cs.role in ('lead_teacher', 'co_teacher')
        and m.active and p.deleted_at is null)
)
update public.classrooms c
  set status = 'archived', archived_at = o.closed_at, version = c.version + 1,
      updated_at = now()
  from orphaned o
  where o.id = c.id and o.closed_at is not null;

-- The hourly purges find old log rows by age.
create index retention_audit_events_created_idx on public.audit_events (created_at);
create index retention_auth_security_events_created_idx on public.auth_security_events (created_at);
create index retention_membership_events_created_idx on public.membership_events (created_at);

-- 5. Files left with nothing to belong to become due for the FILE-051
--    sweep, which still checks holds, dedupe groups and live references.
create or replace function private.retention_release_files(p_files uuid[])
returns integer language plpgsql security definer set search_path = '' as $$
declare released integer;
begin
  update public.file_objects f
    set retention_until = now()
    where f.id = any(coalesce(p_files, '{}'))
      and f.deleted_at is null and not f.legal_hold
      and (f.retention_until is null or f.retention_until > now())
      and not exists (select 1 from public.file_bindings b where b.file_object_id = f.id)
      and not exists (select 1 from public.notebook_entries n where n.photo_file_id = f.id)
      and not exists (select 1 from public.report_evidence e where e.attachment_file_id = f.id);
  get diagnostics released = row_count;
  return released;
end;
$$;

-- 6. Timed purges of records: the audit split, consent and deletion
--    records, billing, and the retired AI rows. Each kind removes at most
--    p_limit rows per call; the worker calls again on its next pass.
create or replace function private.retention_purge_records(p_limit integer default 5000)
returns jsonb language plpgsql security definer set search_path = '' as $$
declare
  lim integer := least(greatest(coalesce(p_limit, 5000), 1), 50000);
  counts jsonb := '{}'::jsonb;
  n integer;
  due_tx uuid[];
  legacy_files uuid[];
begin
  perform set_config('studafy.retention_purge', 'on', true);

  -- Security and access logs: 2 years. Consent and deletion events are kept
  -- for the life of the account, then 6 years.
  delete from public.audit_events a where a.id in (
    select x.id from public.audit_events x
    where x.created_at < now() - interval '2 years'
      and x.action not in ('account_deleted', 'account_deletion_requested', 'account_deletion_cancelled')
    order by x.created_at limit lim);
  get diagnostics n = row_count; counts := counts || jsonb_build_object('audit_events', n);

  delete from public.audit_events a where a.id in (
    select x.id from public.audit_events x
    left join public.profiles p
      on x.entity_type = 'profile' and p.id = x.entity_id
    -- Anything due is over 6 years old, which keeps this to the old end.
    where x.created_at < now() - interval '6 years'
      and (x.action = 'account_deleted'
           or (x.action in ('account_deletion_requested', 'account_deletion_cancelled')
               and p.deleted_at < now() - interval '6 years'))
    order by x.created_at limit lim);
  get diagnostics n = row_count; counts := counts || jsonb_build_object('audit_events_consent_deletion', n);

  delete from public.auth_security_events e where e.id in (
    select x.id from public.auth_security_events x
    where x.created_at < now() - interval '2 years'
      and x.event_type not in ('consent_recorded', 'account_deletion_requested', 'account_deletion_cancelled')
    order by x.created_at limit lim);
  get diagnostics n = row_count; counts := counts || jsonb_build_object('auth_security_events', n);

  delete from public.auth_security_events e where e.id in (
    select x.id from public.auth_security_events x
    left join public.profiles p on p.id = x.actor_id
    where x.created_at < now() - interval '6 years'
      and x.event_type in ('consent_recorded', 'account_deletion_requested', 'account_deletion_cancelled')
      and (p.deleted_at < now() - interval '6 years' or x.actor_id is null)
    order by x.created_at limit lim);
  get diagnostics n = row_count; counts := counts || jsonb_build_object('auth_security_events_consent_deletion', n);

  delete from public.membership_events e where e.id in (
    select x.id from public.membership_events x
    where x.created_at < now() - interval '2 years'
    order by x.created_at limit lim);
  get diagnostics n = row_count; counts := counts || jsonb_build_object('membership_events', n);

  delete from public.consent_records c where c.id in (
    select x.id from public.consent_records x
    join public.profiles p on p.id = x.user_id
    where p.deleted_at < now() - interval '6 years'
    order by x.id limit lim);
  get diagnostics n = row_count; counts := counts || jsonb_build_object('consent_records', n);

  delete from private.inactive_account_warnings w
    using public.profiles p
    where p.id = w.user_id and p.deleted_at < now() - interval '6 years';
  delete from public.account_deletion_requests r where r.id in (
    select x.id from public.account_deletion_requests x
    join public.profiles p on p.id = x.user_id
    where p.deleted_at < now() - interval '6 years'
      and not exists (select 1 from public.legal_holds h where h.account_deletion_request_id = x.id)
    order by x.requested_at limit lim);
  get diagnostics n = row_count; counts := counts || jsonb_build_object('account_deletion_requests', n);

  -- Billing: 6 years after the end of the tax year a record relates to. A
  -- transaction relates to the year it last had effect in.
  select array_agg(t.id) into due_tx from (
    select x.id from public.store_transactions x
    where date_trunc('year', greatest(x.purchased_at, x.created_at,
            coalesce(x.effective_until, x.purchased_at))) + interval '7 years' <= now()
    order by x.purchased_at limit lim) t;
  delete from public.entitlements where source_transaction_id = any(coalesce(due_tx, '{}'));
  delete from public.store_transaction_history where store_transaction_id = any(coalesce(due_tx, '{}'));
  delete from public.store_transactions where id = any(coalesce(due_tx, '{}'));
  get diagnostics n = row_count; counts := counts || jsonb_build_object('store_transactions', n);

  delete from public.billing_purchase_approvals a where a.id in (
    select x.id from public.billing_purchase_approvals x
    where date_trunc('year', greatest(x.requested_at, x.decided_at, x.consumed_at))
            + interval '7 years' <= now()
      and not exists (select 1 from public.store_transactions t where t.purchase_approval_id = x.id)
    order by x.requested_at limit lim);
  get diagnostics n = row_count; counts := counts || jsonb_build_object('billing_purchase_approvals', n);

  delete from public.store_events e where e.id in (
    select x.id from public.store_events x
    where date_trunc('year', greatest(x.received_at, x.processed_at)) + interval '7 years' <= now()
    order by x.id limit lim);
  get diagnostics n = row_count; counts := counts || jsonb_build_object('store_events', n);

  delete from public.subscription_entitlements s
    where not s.active
      and date_trunc('year', greatest(s.verified_at, s.expires_at)) + interval '7 years' <= now();
  get diagnostics n = row_count; counts := counts || jsonb_build_object('subscription_entitlements', n);

  -- The AI rows retired by ADR-0026 (DL-047): nothing may write them, and
  -- the retention owner has decided to delete what is left.
  select array_agg(distinct f) into legacy_files from (
    select d.file_object_id as f from public.ai_grading_drafts d where d.file_object_id is not null
    union
    select b.file_object_id from public.file_bindings b where b.ai_grading_draft_id is not null
  ) x;
  delete from public.question_suggestions;
  get diagnostics n = row_count; counts := counts || jsonb_build_object('question_suggestions', n);
  delete from public.ai_grading_drafts;
  get diagnostics n = row_count; counts := counts || jsonb_build_object('ai_grading_drafts', n);
  delete from public.practice_sessions;
  get diagnostics n = row_count; counts := counts || jsonb_build_object('practice_sessions', n);
  counts := counts || jsonb_build_object('files_released',
    private.retention_release_files(legacy_files));

  perform set_config('studafy.retention_purge', '', true);
  return counts;
end;
$$;

-- 7. One closed class: everything recorded in it goes. The class row stays
--    as a nameplate, because students' own notebooks hang off it (they are
--    the student's, kept until the student deletes them or their account),
--    and so do its lessons in the school's library. Returns false when
--    something keeps it for now (a hold, a file job in flight, or another
--    worker holding the row).
create or replace function private.retention_purge_class(p_classroom_id uuid)
returns boolean language plpgsql security definer set search_path = '' as $$
declare
  v_school uuid;
  v_files uuid[];
  v_uploads uuid[];
begin
  select c.school_id into v_school from public.classrooms c
  where c.id = p_classroom_id and c.archived_at is not null
    and c.academic_records_purged_at is null
  for update skip locked;
  if v_school is null then return false; end if;

  -- Anyone in the class under a legal hold keeps the whole class.
  if exists (
    select 1 from public.legal_holds h
    where h.status = 'active' and (h.expires_at is null or h.expires_at > now())
      and h.subject_user_id in (
        select st.user_id from public.enrollments e
        join public.students st on st.id = e.student_id
        where e.classroom_id = p_classroom_id and st.user_id is not null
        union
        select cs.user_id from public.classroom_staff cs where cs.classroom_id = p_classroom_id)
  ) then
    return false;
  end if;

  select array_agg(u.id) into v_uploads from public.upload_sessions u
  where u.assignment_id in (select a.id from public.assignments a where a.classroom_id = p_classroom_id)
     or u.grade_result_id in (
       select g.id from public.grade_results g
       join public.assessments x on x.id = g.assessment_id
       where x.classroom_id = p_classroom_id);

  select array_agg(distinct b.file_object_id) into v_files from public.file_bindings b
  where b.submission_attempt_id in (
          select sa.id from public.submission_attempts sa
          join public.submissions s on s.id = sa.submission_id
          join public.assignments a on a.id = s.assignment_id
          where a.classroom_id = p_classroom_id)
     or b.assignment_id in (select a.id from public.assignments a where a.classroom_id = p_classroom_id)
     or b.assessment_id in (select x.id from public.assessments x where x.classroom_id = p_classroom_id)
     or b.assessment_question_id in (
          select q.id from public.assessment_questions q
          join public.assessments x on x.id = q.assessment_id
          where x.classroom_id = p_classroom_id)
     or b.grade_result_id in (
          select g.id from public.grade_results g
          join public.assessments x on x.id = g.assessment_id
          where x.classroom_id = p_classroom_id)
     or b.announcement_id in (select n.id from public.announcements n where n.classroom_id = p_classroom_id)
     or b.upload_session_id = any(coalesce(v_uploads, '{}'));

  -- A file under hold, or a file job still running, waits.
  if exists (select 1 from public.file_objects f where f.id = any(coalesce(v_files, '{}')) and f.legal_hold)
     or exists (
       select 1 from public.file_job_outbox j
       where j.state in ('pending', 'processing', 'retry')
         and (j.upload_session_id = any(coalesce(v_uploads, '{}'))
              or j.file_object_id = any(coalesce(v_files, '{}')))) then
    return false;
  end if;

  perform set_config('studafy.retention_purge', 'on', true);

  -- The histories hold RESTRICT references to what they describe, and so do
  -- uploads to the class's work, so they go first.
  delete from public.grade_result_events where grade_result_id in (
    select g.id from public.grade_results g
    join public.assessments x on x.id = g.assessment_id
    where x.classroom_id = p_classroom_id);
  delete from public.attendance_record_revisions where session_id in (
    select ls.id from public.lesson_sessions ls where ls.classroom_id = p_classroom_id);
  delete from public.file_job_outbox where upload_session_id = any(coalesce(v_uploads, '{}'));
  delete from public.file_bindings where upload_session_id = any(coalesce(v_uploads, '{}'));
  delete from public.upload_sessions where id = any(coalesce(v_uploads, '{}'));

  -- Work, hand-ins and their marks; assessments, attempts and marks;
  -- lessons held and their attendance; announcements; meetings; the roster;
  -- and where the school's lessons were published to the class. Everything
  -- under these cascades with them. Rows that point at another of these
  -- with ON DELETE SET NULL (a publication at a lesson held, an assessment
  -- at its work) go first, so no cascade has to update them.
  delete from public.resource_publications where classroom_id = p_classroom_id;
  delete from public.meetings where classroom_id = p_classroom_id;
  delete from public.announcements where classroom_id = p_classroom_id;
  delete from public.assessments where classroom_id = p_classroom_id;
  delete from public.assignments where classroom_id = p_classroom_id;
  delete from public.lesson_sessions where classroom_id = p_classroom_id;
  delete from public.enrollments where classroom_id = p_classroom_id;
  update public.classrooms set academic_records_purged_at = now()
    where id = p_classroom_id;

  perform private.retention_release_files(v_files);
  perform set_config('studafy.retention_purge', '', true);

  insert into public.audit_events(school_id, actor_id, action, entity_type, entity_id, after_value, request_id)
  values (v_school, null, 'retention_class_purged', 'classroom', p_classroom_id,
    jsonb_build_object('files', coalesce(cardinality(v_files), 0)),
    'retention-' || p_classroom_id::text);
  return true;
end;
$$;

-- 8. Closed classes past their period, then the conversations they leave
--    behind.
create or replace function private.retention_purge_classes(p_limit integer default 5)
returns jsonb language plpgsql security definer set search_path = '' as $$
declare
  lim integer := least(greatest(coalesce(p_limit, 5), 1), 100);
  cls uuid;
  conv record;
  v_files uuid[];
  purged integer := 0;
  kept integer := 0;
  conversations integer := 0;
begin
  for cls in
    select c.id from public.classrooms c
    left join private.school_retention_instructions i on i.school_id = c.school_id
    where c.archived_at is not null and c.academic_records_purged_at is null
      and (i.school_id is null or i.academic_retention_months is not null)
      and c.archived_at <= now() - make_interval(months => coalesce(i.academic_retention_months, 12))
    order by c.archived_at
    limit lim
  loop
    if private.retention_purge_class(cls) then
      purged := purged + 1;
    else
      kept := kept + 1;
    end if;
  end loop;

  for conv in
    select k.id, k.school_id from public.conversations k
    left join private.school_retention_instructions i on i.school_id = k.school_id
    where (i.school_id is null or i.academic_retention_months is not null)
      and coalesce(
            (select max(m.created_at) from public.messages m where m.conversation_id = k.id),
            k.created_at)
          <= now() - make_interval(months => coalesce(i.academic_retention_months, 12))
      -- Its participants no longer share a class: a teacher of it with a
      -- student in it, or with a student's guardian.
      and not exists (
        select 1 from public.conversation_participants a
        join public.classroom_staff cs on cs.user_id = a.user_id
        join public.conversation_participants b
          on b.conversation_id = a.conversation_id and b.user_id <> a.user_id
        join public.enrollments e on e.classroom_id = cs.classroom_id
        join public.students st on st.id = e.student_id
        where a.conversation_id = k.id
          and (st.user_id = b.user_id or exists (
            select 1 from public.guardian_links g
            where g.student_id = st.id and g.guardian_id = b.user_id)))
      -- A safety report keeps what it points at.
      and not exists (
        select 1 from public.reports r
        where r.conversation_id = k.id
           or r.message_id in (select m.id from public.messages m where m.conversation_id = k.id))
      and not exists (
        select 1 from public.report_evidence e
        join public.messages m on m.id = e.message_id
        where m.conversation_id = k.id)
      and not exists (
        select 1 from public.legal_holds h
        join public.conversation_participants p on p.user_id = h.subject_user_id
        where p.conversation_id = k.id and h.status = 'active'
          and (h.expires_at is null or h.expires_at > now()))
    order by k.created_at
    limit lim * 10
    for update of k skip locked
  loop
    select array_agg(distinct b.file_object_id) into v_files
    from public.file_bindings b
    join public.messages m on m.id = b.message_id
    where m.conversation_id = conv.id;

    perform set_config('studafy.retention_purge', 'on', true);
    delete from public.messages where conversation_id = conv.id;
    delete from public.conversations where id = conv.id;
    perform private.retention_release_files(v_files);
    perform set_config('studafy.retention_purge', '', true);

    insert into public.audit_events(school_id, actor_id, action, entity_type, entity_id, after_value, request_id)
    values (conv.school_id, null, 'retention_conversation_purged', 'conversation', conv.id,
      jsonb_build_object('files', coalesce(cardinality(v_files), 0)),
      'retention-' || conv.id::text);
    conversations := conversations + 1;
  end loop;

  return jsonb_build_object(
    'classes_purged', purged, 'classes_kept', kept,
    'conversations_purged', conversations);
end;
$$;

-- 9. Inactive accounts. Activity is the latest sign-in or token refresh:
--    someone who stays signed in and uses the app every day has not been
--    inactive, even though last_sign_in_at does not move. Managed children
--    have no sign-in of their own and go with their parent (ADR-0031).
create or replace function private.account_last_active_at(p_user_id uuid)
returns timestamptz language sql stable security definer set search_path = '' as $$
  select greatest(
    u.created_at,
    u.last_sign_in_at,
    (select max(greatest(s.created_at, s.updated_at, s.refreshed_at at time zone 'UTC'))
     from auth.sessions s where s.user_id = u.id))
  from auth.users u where u.id = p_user_id;
$$;

create or replace function private.retention_inactive_accounts(p_limit integer default 100)
returns jsonb language plpgsql security definer set search_path = '' as $$
declare
  lim integer := least(greatest(coalesce(p_limit, 100), 1), 1000);
  w record;
  v_active timestamptz;
  v_school uuid;
  v_request uuid;
  v_execute_after timestamptz;
  resumed integer := 0;
  warned integer := 0;
  requested integer := 0;
begin
  -- Activity since the warning ends it, and the deletion it led to.
  for w in
    select iw.user_id, iw.warned_at, iw.deletion_request_id
    from private.inactive_account_warnings iw
    join public.profiles p on p.id = iw.user_id
    where p.deleted_at is null
      and private.account_last_active_at(iw.user_id) > iw.warned_at
    for update of iw skip locked
  loop
    if w.deletion_request_id is not null then
      update public.account_deletion_requests
        set state = 'cancelled', cancelled_at = now(), version = version + 1
        where id = w.deletion_request_id and state = 'grace_period';
      if found then
        insert into public.audit_events(school_id, actor_id, action, entity_type, entity_id, after_value, request_id)
        values (null, null, 'account_deletion_cancelled', 'profile', w.user_id,
          jsonb_build_object('cause', 'activity_resumed', 'request_id', w.deletion_request_id),
          'inactive-account-' || w.user_id::text);
      end if;
    end if;
    delete from private.inactive_account_warnings where user_id = w.user_id;
    resumed := resumed + 1;
  end loop;

  -- 23 months: warn.
  for w in
    select p.id as user_id from public.profiles p
    join auth.users u on u.id = p.id
    where p.deleted_at is null and p.status <> 'deleted'
      and coalesce(u.last_sign_in_at, u.created_at) <= now() - interval '23 months'
      and not exists (select 1 from private.managed_accounts ma where ma.child_id = p.id)
      and not exists (select 1 from private.inactive_account_warnings iw where iw.user_id = p.id)
      and not exists (
        select 1 from public.account_deletion_requests r
        where r.user_id = p.id and r.state in ('grace_period', 'executing'))
      and private.account_last_active_at(p.id) <= now() - interval '23 months'
    order by u.created_at
    limit lim
  loop
    v_active := private.account_last_active_at(w.user_id);
    -- The in-app notification lives in a school: the person's own, as a
    -- student, a member, or a guardian of a student.
    v_school := null;
    select s.school_id into v_school from public.students s
    where s.user_id = w.user_id and s.deleted_at is null and s.school_id is not null
    order by s.created_at limit 1;
    if v_school is null then
      select m.school_id into v_school from public.memberships m
      where m.user_id = w.user_id and m.active
      order by m.created_at limit 1;
    end if;
    if v_school is null then
      select gl.school_id into v_school from public.guardian_links gl
      where gl.guardian_id = w.user_id and gl.status = 'verified'
      order by gl.verified_at, gl.id limit 1;
    end if;
    if v_school is not null then
      perform private.notify_recipient(
        v_school, w.user_id, 'account.inactive_deletion_warning',
        jsonb_build_object('lastActiveAt', v_active),
        'inactive-account:' || w.user_id::text,
        'account.inactive_deletion_warning:' || w.user_id::text || ':' || v_active::date::text);
    end if;
    insert into private.inactive_account_warnings(user_id, last_active_at, notified_school_id)
    values (w.user_id, v_active, v_school);
    warned := warned + 1;
  end loop;

  -- 24 months, and at least 16 days after a warning that reached them, so
  -- the deletion itself (14 days later) is 30 or more days after it.
  for w in
    select iw.user_id, iw.warned_at, iw.last_active_at
    from private.inactive_account_warnings iw
    join public.profiles p on p.id = iw.user_id
    where p.deleted_at is null and iw.deletion_request_id is null
      and (iw.notified_school_id is not null or iw.emailed_at is not null)
      and iw.warned_at <= now() - interval '16 days'
      and private.account_last_active_at(iw.user_id) <= now() - interval '24 months'
      and not exists (
        select 1 from public.account_deletion_requests r
        where r.user_id = iw.user_id and r.state in ('grace_period', 'executing'))
    order by iw.warned_at
    limit lim
    for update of iw skip locked
  loop
    v_execute_after := now() + interval '14 days';
    insert into public.account_deletion_requests(
      user_id, execute_after, reason_code, requested_via, impact_snapshot)
    values (w.user_id, v_execute_after, 'undisclosed', 'system', jsonb_build_object(
      'cause', 'inactive_account', 'lastActiveAt', w.last_active_at,
      'warnedAt', w.warned_at))
    returning id into v_request;
    update private.inactive_account_warnings
      set deletion_request_id = v_request where user_id = w.user_id;
    insert into public.audit_events(school_id, actor_id, action, entity_type, entity_id, after_value, request_id)
    values (null, null, 'account_deletion_requested', 'profile', w.user_id,
      jsonb_build_object('cause', 'inactive_account', 'execute_after', v_execute_after,
        'request_id', v_request),
      'inactive-account-' || w.user_id::text);
    requested := requested + 1;
  end loop;

  return jsonb_build_object(
    'activity_resumed', resumed, 'warned', warned, 'deletion_requested', requested);
end;
$$;

do $grants$
declare fn text;
begin
  foreach fn in array array[
    'private.reject_append_only_mutation()',
    'private.api041_reject_history_change()',
    'private.account_deletion_execute(uuid)',
    'private.retention_release_files(uuid[])',
    'private.retention_purge_records(integer)',
    'private.retention_purge_class(uuid)',
    'private.retention_purge_classes(integer)',
    'private.account_last_active_at(uuid)',
    'private.retention_inactive_accounts(integer)'
  ] loop
    execute format('alter function %s owner to postgres', fn);
    execute format('revoke all on function %s from public, anon, authenticated, service_role, studafy_api_runtime, studafy_worker_runtime', fn);
  end loop;
end
$grants$;

grant execute on function private.account_deletion_execute(uuid) to studafy_worker_runtime;
grant execute on function private.retention_purge_records(integer) to studafy_worker_runtime;
grant execute on function private.retention_purge_classes(integer) to studafy_worker_runtime;
grant execute on function private.retention_inactive_accounts(integer) to studafy_worker_runtime;

revoke all on table private.school_retention_instructions, private.inactive_account_warnings
  from public, anon, authenticated, service_role, studafy_api_runtime, studafy_worker_runtime;
