-- Account deletion executor (DL-051). AUTH-030 built request, impact and
-- cancel; nothing ever executed a request, so a deletion requested in the
-- app never happened. This adds the executor the worker runs.
--
-- Deletion is de-identification, not a row delete. More than thirty tables
-- reference public.profiles, several with RESTRICT and several append-only
-- (messages, grade events, report events, the payment ledger), and
-- public.profiles itself cascades from auth.users. Deleting either row would
-- either fail or destroy school, safeguarding and financial records the
-- school and the law require us to keep. So the executor:
--
--   * removes the ability to sign in: scrubs the auth user's email, phone,
--     password and metadata, bans it permanently, and deletes its
--     identities, sessions, refresh tokens, MFA factors and one-time tokens;
--   * de-identifies the profile: "Deleted user", status `deleted`;
--   * revokes every membership and guardian link, and every device, reauth
--     grant, identity link, block, notification preference and delivery;
--   * erases personal-only data with no retention purpose: export requests
--     and payloads, pending purchase approvals, notification deliveries;
--   * keeps a nameless tombstone so retained records stay referentially
--     intact: messages already sent, reports, grades the school owns, the
--     audit trail and the payment ledger.
--
-- A request is executed only when its grace period has ended, it was not
-- cancelled, and neither the request nor its subject is under an active
-- legal hold. The school's education records attached to a student stay
-- with the school, as `education_record_classification` records.

create or replace function private.account_deletion_blocked_by_hold(p_request public.account_deletion_requests)
returns boolean language sql stable security definer set search_path = '' as $$
  select p_request.legal_hold or exists (
    select 1 from public.legal_holds h
    where h.status = 'active'
      and (h.expires_at is null or h.expires_at > now())
      and (h.subject_user_id = p_request.user_id
        or h.account_deletion_request_id = p_request.id)
  );
$$;

-- Moves due requests to `executing` and returns their ids. A request stuck
-- in `executing` for fifteen minutes (a crashed worker) is claimed again;
-- execution is a single transaction, so a crash leaves nothing half done.
create or replace function private.account_deletion_claim(p_limit integer default 5)
returns uuid[] language plpgsql security definer set search_path = '' as $$
declare
  claimed uuid[];
begin
  with due as (
    select r.id from public.account_deletion_requests r
    where ((r.state = 'grace_period' and r.execute_after <= now())
        or (r.state = 'executing' and r.updated_at < now() - interval '15 minutes'))
      and not private.account_deletion_blocked_by_hold(r)
    order by r.execute_after
    limit greatest(least(p_limit, 50), 1)
    for update skip locked
  ), moved as (
    update public.account_deletion_requests r
      set state = 'executing', version = r.version + 1
      from due where r.id = due.id
      returning r.id
  )
  select coalesce(array_agg(moved.id), '{}') into claimed from moved;
  return claimed;
end;
$$;

create or replace function private.account_deletion_execute(p_request_id uuid)
returns text language plpgsql security definer set search_path = '' as $$
declare
  req public.account_deletion_requests%rowtype;
  subject uuid;
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

  -- 2. The profile becomes a nameless tombstone.
  update public.profiles
    set display_name = 'Deleted user', locale = 'en', status = 'deleted',
        deleted_at = coalesce(deleted_at, now())
    where id = subject;

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

  -- 4. Personal-only data with no retention purpose.
  delete from public.user_blocks where blocker_id = subject or blocked_id = subject;
  delete from public.notification_preferences where user_id = subject;
  delete from public.notification_deliveries where recipient_id = subject;
  delete from public.data_export_requests where user_id = subject;
  delete from public.billing_purchase_approvals
    where student_user_id = subject and status in ('requested', 'approved');

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

do $grants$
declare fn text;
begin
  foreach fn in array array[
    'private.account_deletion_blocked_by_hold(public.account_deletion_requests)',
    'private.account_deletion_claim(integer)',
    'private.account_deletion_execute(uuid)'
  ] loop
    execute format('alter function %s owner to postgres', fn);
    execute format('revoke all on function %s from public, anon, authenticated, service_role, studafy_api_runtime, studafy_worker_runtime', fn);
  end loop;
end
$grants$;

grant execute on function
  private.account_deletion_claim(integer),
  private.account_deletion_execute(uuid)
to studafy_worker_runtime;
