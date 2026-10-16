-- The inactive-account warning by email (DL-057, privacy policy 1.4 §10).
--
-- Policy §10 applies to every account: "Deleted after 2 years without a
-- sign-in. We warn the account holder by email or in the app 30 days
-- before". 202610140001 warned in the app only, and only people with a
-- school, because an in-app notification lives in a school. Email went out
-- only if the person had turned email on for the `account` category, which
-- the app does not offer. So nobody was emailed, `emailed_at` was never set,
-- and someone without a school was never warned and so never deleted.
--
-- This is a required service notice, not a preference:
--
--   1. The warning is emailed to the account's address whatever the
--      person's email preferences, by the retention worker through the same
--      Resend sender as other email (claim, send, finish). It is sent once:
--      `emailed_at` is set when the provider accepts it, and a sent warning
--      is never claimed again. Failures retry with backoff, up to 8 tries;
--      a refused address or no address stops at once. In-app and push stay
--      as they were.
--   2. The general channel fan-out no longer emails this template, so a
--      person who did turn on `account` email does not get it twice.
--   3. People without a school are warned the same way, by email. Deletion
--      is still requested only after a warning that reached the person, now
--      counted from when it reached them: in the app when it was raised
--      (people with a school), or when the email was accepted. The deletion
--      follows 16 + 14 = 30 days or more after that. Managed children are
--      unchanged: never warned or deleted on their own, they go with their
--      parent (ADR-0031; account_deletion_execute step 3a).
--   4. Someone with a school who was warned in the app more than a week
--      before email was configured is not emailed late: the email would say
--      "in about a month" when the deletion is nearer. Their in-app warning
--      already reached them.

alter table private.inactive_account_warnings
  add column email_attempts integer not null default 0
    check (email_attempts between 0 and 8),
  add column email_claimed_at timestamptz,
  add column email_error_code text check (length(email_error_code) <= 80),
  add column email_provider_message_id text
    check (length(email_provider_message_id) <= 200);

-- What is due: not yet emailed, nothing has stopped it, the person still
-- exists, and the email can still be honest about the date (see 4).
create or replace function private.inactive_warning_email_due(
  p_row private.inactive_account_warnings
)
returns boolean language sql stable security definer set search_path = '' as $$
  select p_row.emailed_at is null
    and p_row.deletion_request_id is null
    and p_row.email_attempts < 8
    and (p_row.notified_school_id is null or p_row.warned_at > now() - interval '7 days')
    and exists (select 1 from public.profiles p
      where p.id = p_row.user_id and p.deleted_at is null and p.status <> 'deleted');
$$;

-- Leases up to p_limit due warning emails (the lease is the claim time; a
-- lost worker's lease is retried after the backoff) and returns the
-- address and language for each. Preferences are not consulted.
create or replace function private.inactive_warning_email_claim(p_limit integer default 20)
returns jsonb language plpgsql security definer set search_path = '' as $$
declare
  jobs jsonb;
begin
  with due as (
    select iw.user_id from private.inactive_account_warnings iw
    where private.inactive_warning_email_due(iw)
      and (iw.email_claimed_at is null or iw.email_claimed_at <= now()
        - make_interval(secs => least(86400, 300 * (2 ^ least(iw.email_attempts, 8))::integer)))
    order by iw.warned_at, iw.user_id
    limit greatest(least(coalesce(p_limit, 20), 100), 1)
    for update of iw skip locked
  ), leased as (
    update private.inactive_account_warnings iw
      set email_claimed_at = now(), email_attempts = iw.email_attempts + 1
      from due where iw.user_id = due.user_id
      returning iw.user_id
  )
  select coalesce(jsonb_agg(jsonb_build_object(
      'userId', l.user_id,
      'locale', p.locale,
      'email', (select u.email from auth.users u where u.id = l.user_id
        and u.email is not null and u.email <> ''
        and u.email not like '%@deleted.invalid')
    ) order by l.user_id), '[]'::jsonb)
  into jobs
  from leased l
  join public.profiles p on p.id = l.user_id;
  return jobs;
end;
$$;

-- Records the outcome. Returns 'sent', 'retry', 'failed', or 'unchanged'
-- for a warning that was already emailed or no longer exists (idempotent).
create or replace function private.inactive_warning_email_finish(
  p_user_id uuid, p_sent boolean, p_error_code text, p_terminal boolean,
  p_provider_message_id text
)
returns text language plpgsql security definer set search_path = '' as $$
declare
  w private.inactive_account_warnings%rowtype;
begin
  select * into w from private.inactive_account_warnings
  where user_id = p_user_id for update;
  if w.user_id is null or w.emailed_at is not null then return 'unchanged'; end if;

  if p_sent then
    update private.inactive_account_warnings
      set emailed_at = now(), email_error_code = null,
          email_provider_message_id = left(p_provider_message_id, 200)
      where user_id = p_user_id;
    insert into public.audit_events(school_id, actor_id, action, entity_type, entity_id, after_value, request_id)
    values (null, null, 'inactive_account_warning_emailed', 'profile', p_user_id,
      jsonb_build_object('warnedAt', w.warned_at, 'lastActiveAt', w.last_active_at),
      'inactive-account-' || p_user_id::text);
    return 'sent';
  end if;

  if p_terminal or w.email_attempts >= 8 then
    update private.inactive_account_warnings
      set email_attempts = 8, email_error_code = left(p_error_code, 80)
      where user_id = p_user_id;
    return 'failed';
  end if;
  update private.inactive_account_warnings
    set email_error_code = left(p_error_code, 80)
    where user_id = p_user_id;
  return 'retry';
end;
$$;

-- How many warnings wait for an email, for the worker's log when no email
-- provider is configured. Claims nothing.
create or replace function private.inactive_warning_email_pending()
returns integer language sql stable security definer set search_path = '' as $$
  select count(*)::integer from private.inactive_account_warnings iw
  where private.inactive_warning_email_due(iw);
$$;

-- 2. The fan-out no longer emails the inactive-account warning: the
--    retention worker always does (unchanged otherwise from 202609190011).
create or replace function private.channel_fanout(p_limit integer default 200)
returns integer language plpgsql security definer set search_path = '' as $$
declare
  n integer;
begin
  with candidates as (
    select d.school_id, d.outbox_id, d.recipient_id, ch.channel
    from public.notification_deliveries d
    join public.notification_outbox o on o.id = d.outbox_id
    join public.profiles p on p.id = d.recipient_id and p.status = 'active'
    cross join (values ('email'), ('push')) as ch(channel)
    where d.channel = 'in_app' and d.state = 'sent'
      and d.delivered_at >= now() - interval '24 hours'
      and not (ch.channel = 'email' and o.template_key = 'account.inactive_deletion_warning')
      and private.channel_allowed(d.recipient_id, d.school_id, ch.channel,
        private.notification_category(o.template_key))
      and not exists (
        select 1 from public.notification_deliveries x
        where x.outbox_id = d.outbox_id and x.recipient_id = d.recipient_id
          and x.channel = ch.channel)
    limit greatest(least(p_limit, 1000), 1)
  )
  insert into public.notification_deliveries(school_id, outbox_id, recipient_id, channel, attempt, state)
  select school_id, outbox_id, recipient_id, channel, 1, 'pending' from candidates
  on conflict (outbox_id, recipient_id, channel, attempt) do nothing;
  get diagnostics n = row_count;
  return n;
end;
$$;

-- 3. Deletion counts from when the warning reached the person.
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

  -- 23 months: warn. Everyone but a managed child, school or not; the
  -- email is sent by the worker (inactive_warning_email_claim).
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

  -- 24 months, and at least 16 days after the warning reached them (in the
  -- app when it was raised, or by email when it was sent), so the deletion
  -- itself (14 days later) is 30 or more days after it.
  for w in
    select iw.user_id, iw.warned_at, iw.last_active_at, iw.emailed_at
    from private.inactive_account_warnings iw
    join public.profiles p on p.id = iw.user_id
    where p.deleted_at is null and iw.deletion_request_id is null
      and ((iw.notified_school_id is not null and iw.warned_at <= now() - interval '16 days')
        or (iw.emailed_at is not null and iw.emailed_at <= now() - interval '16 days'))
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
      'warnedAt', w.warned_at, 'emailedAt', w.emailed_at))
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
    'private.inactive_warning_email_due(private.inactive_account_warnings)',
    'private.inactive_warning_email_claim(integer)',
    'private.inactive_warning_email_finish(uuid, boolean, text, boolean, text)',
    'private.inactive_warning_email_pending()',
    'private.channel_fanout(integer)',
    'private.retention_inactive_accounts(integer)'
  ] loop
    execute format('alter function %s owner to postgres', fn);
    execute format('revoke all on function %s from public, anon, authenticated, service_role, studafy_api_runtime, studafy_worker_runtime', fn);
  end loop;
end
$grants$;

grant execute on function private.inactive_warning_email_claim(integer),
  private.inactive_warning_email_finish(uuid, boolean, text, boolean, text),
  private.inactive_warning_email_pending(),
  private.channel_fanout(integer),
  private.retention_inactive_accounts(integer)
to studafy_worker_runtime;
