-- A tapped push opens the notification it was sent for.
--
-- A push job now carries `notificationId`: the id the app's notifications
-- list knows the notification by, which is the recipient's in-app delivery
-- for the same outbox row (`api042_notification_json` returns that id). The
-- worker puts it, and only it, in the FCM data payload beside the template
-- key. It is an opaque row id, not content: the app looks the notification up
-- through the API after sign-in, as the signed-in account, so a push that
-- reached a phone now signed in as someone else finds nothing and opens that
-- account's own list. Email jobs are unchanged. Everything else is as in
-- 202609190011: the same lease, backoff, ordering and fields.

create or replace function private.channel_claim(p_channel text, p_limit integer default 20)
returns jsonb language plpgsql security definer set search_path = '' as $$
declare
  jobs jsonb;
begin
  if p_channel not in ('email', 'push') then
    raise exception using errcode = '22023', message = 'Unknown channel';
  end if;
  with due as (
    select d.id from public.notification_deliveries d
    where d.channel = p_channel
      -- New deliveries are due at once (attempted_at defaults to their
      -- creation time); retries and expired leases wait out the backoff.
      and (d.state = 'pending' or (d.state = 'retry' and d.attempted_at <= now()
        - make_interval(secs => least(3600, 30 * (2 ^ least(d.channel_attempts, 7))::integer))))
    order by d.id
    limit greatest(least(p_limit, 100), 1)
    for update skip locked
  ), leased as (
    update public.notification_deliveries d
      set state = 'retry', attempted_at = now(),
          channel_attempts = d.channel_attempts + 1
      from due where d.id = due.id
      returning d.*
  )
  select coalesce(jsonb_agg(jsonb_build_object(
      'deliveryId', l.id,
      'templateKey', o.template_key,
      'locale', p.locale,
      'email', case when p_channel = 'email' then (
        select u.email from auth.users u where u.id = l.recipient_id
          and u.email not like '%@deleted.invalid') end,
      'tokens', case when p_channel = 'push' then coalesce((
        select jsonb_agg(pd.token) from public.push_devices pd
        where pd.user_id = l.recipient_id and pd.revoked_at is null), '[]'::jsonb) end,
      'notificationId', case when p_channel = 'push' then (
        select x.id::text from public.notification_deliveries x
        where x.outbox_id = l.outbox_id and x.recipient_id = l.recipient_id
          and x.channel = 'in_app'
        order by x.id desc limit 1) end
    )), '[]'::jsonb)
  into jobs
  from leased l
  join public.notification_outbox o on o.id = l.outbox_id
  join public.profiles p on p.id = l.recipient_id;
  return jobs;
end;
$$;

alter function private.channel_claim(text, integer) owner to postgres;
revoke all on function private.channel_claim(text, integer)
  from public, anon, authenticated, service_role, studafy_api_runtime, studafy_worker_runtime;
grant execute on function private.channel_claim(text, integer) to studafy_worker_runtime;
