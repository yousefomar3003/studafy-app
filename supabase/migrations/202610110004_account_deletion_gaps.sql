-- Account deletion removes what it left behind (launch plan 3.6b).
--
-- The DL-051 executor (202609190008) de-identified the profile and ended
-- every grant, but kept personal data that serves no school, safety or
-- legal purpose once the account is gone, and the deletion screen promised
-- more than it did (private.auth_deletion_impact lists devices, consents and
-- notifications). The Data safety answers (docs/store/google-play-data-safety.md)
-- describe this behaviour. In addition to everything 0008 did, the executor
-- now:
--
--   * clears the profile's gender;
--   * replaces the name on the account's student rows (class rosters) with
--     "Deleted student". The rows stay: grades, attendance and hand-ins
--     cascade from them and are the school's records;
--   * deletes the account's study notebooks (and their practice sets),
--     notebook entries and AI usage ledger;
--   * deletes consents, notifications, queued notifications to the account
--     and push registrations (0008 only revoked them through a trigger);
--   * ends a managed child's link to the parent who managed it;
--   * deletes, in the same transaction, every child account the person
--     manages (ADR-0031): a managed child has no sign-in of its own, so
--     without its parent nobody could ever use or delete it. Each child gets
--     its own request, recording why; a child under legal hold waits, and
--     the claim loop deletes it once the hold ends. The deletion screen
--     names these children before the parent confirms
--     (private.auth_deletion_impact, re-issued below);
--   * replaces the account's email on invitations it accepted or that were
--     waiting for it, and revokes the waiting ones;
--   * marks the account's personal-only files (profile image, notebook
--     photo, AI-helper photo) as due for removal. The FILE-051 retention
--     sweep deletes their bytes; a file whose bytes another account shares
--     through dedupe waits until that copy is due too.
--
-- Still kept on purpose: messages already sent, grades, attendance,
-- hand-ins and their files, message attachments, reports, the append-only
-- security event log, the audit trail and the payment ledger. The profile's
-- Studafy ID stays as a meaningless number: the profile_gets_public_id
-- trigger restores it on any change, and nothing links it to a person once
-- the name and email are gone. Shared study sets and AI outputs belong to
-- lessons, not people, and stay too.
--
-- create or replace with the same signatures (ADR-0030); owner and grants
-- are restated below.

create or replace function private.account_deletion_execute(p_request_id uuid)
returns text language plpgsql security definer set search_path = '' as $$
declare
  req public.account_deletion_requests%rowtype;
  subject uuid;
  subject_email text;
  child uuid;
  child_request uuid;
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

  -- 4. Personal-only data with no retention purpose.
  delete from public.user_blocks where blocker_id = subject or blocked_id = subject;
  delete from public.notification_preferences where user_id = subject;
  delete from public.notification_deliveries where recipient_id = subject;
  delete from public.notification_outbox where recipient_id = subject;
  delete from public.notifications where user_id = subject;
  delete from public.push_devices where user_id = subject;
  delete from public.consent_records where user_id = subject;
  delete from public.data_export_requests where user_id = subject;
  delete from public.billing_purchase_approvals
    where student_user_id = subject and status in ('requested', 'approved');
  delete from public.study_notebooks where owner_id = subject;
  delete from public.notebook_entries where owner_id = subject;
  delete from private.ai_usage where user_id = subject;
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

-- The deletion screen's summary also names the child accounts the person
-- manages, because deleting the parent deletes them (step 3a above).
-- Re-issued from 202609130006; otherwise unchanged. create or replace keeps
-- its owner and its grant to studafy_api_runtime.
create or replace function private.auth_deletion_impact()
returns jsonb
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  actor uuid := auth.uid();
begin
  if actor is null then
    return null;
  end if;

  return jsonb_build_object(
    'memberships', (
      select coalesce(jsonb_agg(jsonb_build_object(
        'school_name', s.name, 'role', m.role
      ) order by s.name), '[]'::jsonb)
      from public.memberships m
      join public.schools s on s.id = m.school_id
      where m.user_id = actor and m.active and m.status = 'active'
    ),
    'retained_school_records', jsonb_build_object(
      'attendance', (
        select count(*) from public.attendance_records a
        join public.students st on st.id = a.student_id
        where st.user_id = actor
      ),
      'grades', (
        select count(*) from public.grade_results g
        join public.students st on st.id = g.student_id
        where st.user_id = actor
      ),
      'submissions', (
        select count(*) from public.submissions sub
        join public.students st on st.id = sub.student_id
        where st.user_id = actor
      ),
      'wellbeing', (
        select count(*) from public.wellbeing_events w
        join public.students st on st.id = w.student_id
        where st.user_id = actor
      )
    ),
    'deleted_personal_data', jsonb_build_object(
      'profile', 1,
      'devices', (
        select count(*) from public.auth_devices d where d.user_id = actor
      ),
      'consents', (
        select count(*) from public.consent_records c where c.user_id = actor
      ),
      'notifications', (
        select count(*) from public.notifications n where n.user_id = actor
      )
    ),
    'guardian_links', (
      select count(*) from public.guardian_links gl
      where gl.guardian_id = actor and gl.status = 'verified'
    ),
    'active_entitlements', (
      select count(*) from public.entitlements e
      where e.user_id = actor and e.status = 'active'
    ),
    'managed_child_accounts', (
      select coalesce(jsonb_agg(p.display_name order by p.display_name), '[]'::jsonb)
      from private.managed_accounts m
      join public.profiles p on p.id = m.child_id
      where m.guardian_id = actor and p.deleted_at is null
    )
  );
end;
$$;

-- The export gains what the account holds and could not download before:
-- gender, Studafy ID, notebooks and devices.
create or replace function private.data_export_document(p_user uuid)
returns jsonb language sql stable security definer set search_path = '' as $$
  select jsonb_build_object(
    'format', 'studafy-export/v1',
    'generatedAt', now(),
    'sections', jsonb_build_object(
      'profile', (
        select jsonb_build_object(
          'id', p.id, 'displayName', p.display_name, 'locale', p.locale,
          'status', p.status, 'createdAt', p.created_at,
          'gender', p.gender, 'studafyId', p.public_id,
          'email', (select u.email from auth.users u where u.id = p.id)
        ) from public.profiles p where p.id = p_user),
      'memberships', coalesce((
        select jsonb_agg(jsonb_build_object(
          'school', s.name, 'role', m.role, 'status', m.status,
          'validFrom', m.valid_from, 'validUntil', m.valid_until
        ) order by m.created_at)
        from public.memberships m join public.schools s on s.id = m.school_id
        where m.user_id = p_user), '[]'::jsonb),
      'guardianLinks', coalesce((
        select jsonb_agg(jsonb_build_object(
          'child', st.display_name, 'school', s.name, 'status', gl.status,
          'relationship', gl.relationship, 'verifiedAt', gl.verified_at
        ))
        from public.guardian_links gl
        join public.students st on st.id = gl.student_id
        join public.schools s on s.id = st.school_id
        where gl.guardian_id = p_user), '[]'::jsonb),
      'studentRecords', coalesce((
        select jsonb_agg(jsonb_build_object(
          'school', s.name, 'displayName', st.display_name,
          'studafyId', st.studafy_id,
          'publishedGrades', coalesce((
            select jsonb_agg(jsonb_build_object(
              'assessment', a.title, 'score', g.score,
              'maximumScore', a.maximum_score, 'feedback', g.feedback,
              'publishedAt', g.published_at
            ) order by g.published_at)
            from public.grade_results g
            join public.assessments a on a.id = g.assessment_id
            where g.student_id = st.id and g.state = 'published'), '[]'::jsonb),
          'attendance', coalesce((
            select jsonb_agg(jsonb_build_object(
              'state', ar.state, 'reason', ar.reason, 'recordedAt', ar.recorded_at
            ) order by ar.recorded_at)
            from public.attendance_records ar where ar.student_id = st.id), '[]'::jsonb),
          'submissions', coalesce((
            select jsonb_agg(jsonb_build_object(
              'assignment', asg.title, 'status', sb.status,
              'submittedAt', sb.submitted_at
            ) order by sb.created_at)
            from public.submissions sb
            join public.assignments asg on asg.id = sb.assignment_id
            where sb.student_id = st.id), '[]'::jsonb)
        ))
        from public.students st join public.schools s on s.id = st.school_id
        where st.user_id = p_user and st.deleted_at is null), '[]'::jsonb),
      'notebookEntries', coalesce((
        select jsonb_agg(jsonb_build_object(
          'title', n.title, 'body', n.body, 'source', n.source,
          'createdAt', n.created_at, 'updatedAt', n.updated_at
        ) order by n.created_at)
        from public.notebook_entries n
        where n.owner_id = p_user and n.deleted_at is null), '[]'::jsonb),
      'studyNotebooks', coalesce((
        select jsonb_agg(jsonb_build_object(
          'title', sn.title, 'subtitle', sn.subtitle, 'status', sn.status,
          'content', sn.content, 'personal', sn.personal,
          'createdAt', sn.created_at, 'updatedAt', sn.updated_at
        ) order by sn.created_at)
        from public.study_notebooks sn
        where sn.owner_id = p_user and sn.deleted_at is null), '[]'::jsonb),
      'devices', coalesce((
        select jsonb_agg(d.device order by d.seen desc)
        from (
          select jsonb_build_object(
              'kind', 'signIn', 'platform', ad.platform, 'appVersion', ad.app_version,
              'label', ad.display_label, 'firstSeenAt', ad.first_seen_at,
              'lastSeenAt', ad.last_seen_at, 'revokedAt', ad.revoked_at
            ) as device, ad.last_seen_at as seen
          from public.auth_devices ad where ad.user_id = p_user
          union all
          select jsonb_build_object(
              'kind', 'notifications', 'platform', pd.platform,
              'registeredAt', pd.created_at, 'lastSeenAt', pd.last_seen_at,
              'revokedAt', pd.revoked_at
            ), pd.last_seen_at
          from public.push_devices pd where pd.user_id = p_user
        ) d), '[]'::jsonb),
      'messagesSent', coalesce((
        select jsonb_agg(jsonb_build_object(
          'conversationId', m.conversation_id, 'body', m.body, 'sentAt', m.created_at
        ) order by m.created_at)
        from (
          select * from public.messages
          where sender_id = p_user and deleted_at is null
          order by created_at desc limit 5000
        ) m), '[]'::jsonb),
      'reportsFiled', coalesce((
        select jsonb_agg(jsonb_build_object(
          'kind', r.kind, 'status', r.status, 'details', r.details,
          'filedAt', r.created_at, 'resolvedAt', r.resolved_at
        ) order by r.created_at)
        from public.reports r where r.reported_by = p_user), '[]'::jsonb),
      'blocksMade', coalesce((
        select jsonb_agg(jsonb_build_object(
          'scope', b.scope, 'createdAt', b.created_at, 'expiresAt', b.expires_at
        ))
        from public.user_blocks b where b.blocker_id = p_user), '[]'::jsonb),
      'consents', coalesce((
        select jsonb_agg(jsonb_build_object(
          'purpose', c.purpose, 'policyVersion', c.policy_version,
          'acceptedAt', c.accepted_at, 'withdrawnAt', c.withdrawn_at
        ) order by c.accepted_at)
        from public.consent_records c where c.user_id = p_user), '[]'::jsonb),
      'purchases', coalesce((
        select jsonb_agg(jsonb_build_object(
          'product', sp.feature_key, 'platform', t.platform, 'state', t.state,
          'purchasedAt', t.purchased_at, 'effectiveUntil', t.effective_until
        ) order by t.purchased_at)
        from public.store_transactions t
        join public.store_products sp on sp.id = t.product_id
        where t.purchaser_id = p_user), '[]'::jsonb),
      'entitlements', coalesce((
        select jsonb_agg(jsonb_build_object(
          'feature', e.feature_key, 'status', e.status,
          'startsAt', e.starts_at, 'endsAt', e.ends_at
        ))
        from public.entitlements e where e.user_id = p_user), '[]'::jsonb),
      'notifications', coalesce((
        select jsonb_agg(jsonb_build_object(
          'template', o.template_key, 'deliveredAt', d.delivered_at,
          'readAt', d.read_at
        ) order by d.delivered_at)
        from public.notification_deliveries d
        join public.notification_outbox o on o.id = d.outbox_id
        where d.recipient_id = p_user), '[]'::jsonb)
    )
  );
$$;

do $grants$
declare fn text;
begin
  foreach fn in array array[
    'private.account_deletion_execute(uuid)',
    'private.data_export_document(uuid)'
  ] loop
    execute format('alter function %s owner to postgres', fn);
    execute format('revoke all on function %s from public, anon, authenticated, service_role, studafy_api_runtime, studafy_worker_runtime', fn);
  end loop;
end
$grants$;

grant execute on function private.account_deletion_execute(uuid) to studafy_worker_runtime;
