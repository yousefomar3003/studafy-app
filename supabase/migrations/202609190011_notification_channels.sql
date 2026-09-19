-- Email and push delivery (DL-053). Notifications were in-app only: the
-- preferences table accepted `email` and `push` channels, but nothing read
-- them and no device could register for push. This adds:
--
--   * public.push_devices, a per-user registry of FCM tokens, registered
--     and unregistered by the app through /v1/me/push-devices;
--   * a fan-out that turns a recent in-app delivery into email and push
--     deliveries for the channels its recipient allows. Email is opt-in per
--     category (a child's inbox is not ours to fill by default); push is on
--     for anyone with a registered device unless they turn a category off;
--   * worker-only claim and finish functions with leases and bounded
--     retries. A token the provider reports as unregistered is revoked.
--
-- Channel content is fixed copy chosen by the worker from the template key
-- and the recipient's language. No names, message text or record details
-- ever leave Studafy in an email or a push notification.

create table public.push_devices (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references public.profiles(id) on delete cascade,
  platform text not null check (platform in ('ios', 'android')),
  token text not null check (length(token) between 32 and 4096),
  created_at timestamptz not null default now(),
  last_seen_at timestamptz not null default now(),
  revoked_at timestamptz
);
-- One live registration per token: a device that signs in as someone else
-- moves to the new account instead of notifying both.
create unique index push_devices_live_token_idx
  on public.push_devices (token) where revoked_at is null;
create index push_devices_user_idx
  on public.push_devices (user_id) where revoked_at is null;
alter table public.push_devices enable row level security;
revoke all on public.push_devices
  from public, anon, authenticated, service_role, studafy_api_runtime, studafy_worker_runtime;

alter table public.notification_deliveries
  add column channel_attempts integer not null default 0
    check (channel_attempts >= 0);
create index notification_deliveries_channel_due_idx
  on public.notification_deliveries (channel, attempted_at)
  where channel in ('email', 'push') and state in ('pending', 'retry');

create or replace function private.notification_category(p_template_key text)
returns text language sql immutable set search_path = '' as $$
  select split_part(p_template_key, '.', 1);
$$;

create or replace function private.channel_allowed(
  p_user uuid, p_school uuid, p_channel text, p_category text
)
returns boolean language sql stable security definer set search_path = '' as $$
  with pref as (
    -- A school-specific setting wins over the person's global setting.
    select p.enabled from public.notification_preferences p
    where p.user_id = p_user and p.channel = p_channel and p.category = p_category
      and (p.school_id = p_school or p.school_id is null)
    order by (p.school_id is null) limit 1
  )
  select case p_channel
    when 'email' then coalesce((select enabled from pref), false)
    when 'push' then coalesce((select enabled from pref), true)
      and exists (select 1 from public.push_devices d
        where d.user_id = p_user and d.revoked_at is null)
    else false end;
$$;

-- Creates pending email/push deliveries for in-app deliveries from the last
-- day that do not have them yet. Safe to run repeatedly: the unique
-- (outbox, recipient, channel, attempt) key absorbs duplicates.
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

-- Leases up to p_limit due deliveries on one channel for two minutes and
-- returns what the sender needs: template, language and address(es).
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
        where pd.user_id = l.recipient_id and pd.revoked_at is null), '[]'::jsonb) end
    )), '[]'::jsonb)
  into jobs
  from leased l
  join public.notification_outbox o on o.id = l.outbox_id
  join public.profiles p on p.id = l.recipient_id;
  return jobs;
end;
$$;

create or replace function private.channel_finish(
  p_delivery bigint, p_success boolean, p_error_code text,
  p_terminal boolean, p_provider_message_id text
)
returns text language plpgsql security definer set search_path = '' as $$
declare
  d public.notification_deliveries%rowtype;
begin
  select * into d from public.notification_deliveries
  where id = p_delivery for update;
  if d.id is null then return 'lost'; end if;
  if d.state in ('sent', 'failed', 'cancelled') then return d.state::text; end if;
  if p_success then
    update public.notification_deliveries
      set state = 'sent', delivered_at = now(), error_code = null,
          provider_message_id = left(p_provider_message_id, 200)
      where id = d.id;
    return 'sent';
  end if;
  if p_terminal or d.channel_attempts >= 5 then
    update public.notification_deliveries
      set state = 'failed', error_code = left(p_error_code, 80)
      where id = d.id;
    return 'failed';
  end if;
  update public.notification_deliveries
    set state = 'retry', error_code = left(p_error_code, 80)
    where id = d.id;
  return 'retry';
end;
$$;

-- The push provider reported this token as no longer valid.
create or replace function private.push_device_revoke_token(p_token text)
returns integer language plpgsql security definer set search_path = '' as $$
declare n integer;
begin
  update public.push_devices set revoked_at = now()
    where token = p_token and revoked_at is null;
  get diagnostics n = row_count;
  return n;
end;
$$;

-- App-facing commands: register this device for push, or stop.
alter function private.api042_command(text, uuid, jsonb, uuid, bigint)
  rename to api042_command_pre_push_devices;

create or replace function private.api042_command(
  p_operation text,
  p_resource_id uuid,
  p_input jsonb,
  p_idempotency_id uuid,
  p_idempotency_generation bigint
)
returns jsonb language plpgsql security definer set search_path = '' as $$
declare
  v_actor uuid := auth.uid();
  tenant uuid := nullif(current_setting('studafy.school_id', true), '')::uuid;
  req_body jsonb := coalesce(p_input->'body', '{}'::jsonb);
  response_status int := coalesce((p_input->>'responseStatus')::int, 200);
  v_token text := req_body->>'token';
  idem_key text;
  response jsonb;
  completed boolean;
begin
  if p_operation not in ('registerPushDevice', 'unregisterPushDevice') then
    return private.api042_command_pre_push_devices(
      p_operation, p_resource_id, p_input, p_idempotency_id, p_idempotency_generation
    );
  end if;
  if v_actor is null or not private.is_active_user() then
    return jsonb_build_object('outcome', 'forbidden');
  end if;
  select r.idempotency_key into idem_key from public.idempotency_records r
  where r.id = p_idempotency_id and r.actor_id = v_actor
    and r.school_id is not distinct from tenant
    and r.generation = p_idempotency_generation and r.status = 'reserved'
  for update;
  if idem_key is null then return jsonb_build_object('outcome', 'forbidden'); end if;

  if p_operation = 'registerPushDevice' then
    -- The token moves to this account if another account held it.
    update public.push_devices set revoked_at = now()
      where token = v_token and revoked_at is null and user_id <> v_actor;
    update public.push_devices set last_seen_at = now(),
        platform = req_body->>'platform'
      where token = v_token and revoked_at is null and user_id = v_actor;
    if not found then
      insert into public.push_devices(user_id, platform, token)
      values (v_actor, req_body->>'platform', v_token);
    end if;
    response := jsonb_build_object('registered', true);
  else
    -- Only the caller's own registration can be removed.
    update public.push_devices set revoked_at = now()
      where token = v_token and user_id = v_actor and revoked_at is null;
    response := jsonb_build_object('registered', false);
  end if;

  completed := private.api_idempotency_complete(p_idempotency_id, p_idempotency_generation, response_status, response);
  if not completed then raise exception 'PUSH_DEVICE_IDEMPOTENCY_COMPLETION_FAILED'; end if;
  return jsonb_build_object('outcome', 'ok', 'response', response);
end;
$$;

do $grants$
declare fn text;
begin
  foreach fn in array array[
    'private.channel_allowed(uuid, uuid, text, text)',
    'private.channel_fanout(integer)',
    'private.channel_claim(text, integer)',
    'private.channel_finish(bigint, boolean, text, boolean, text)',
    'private.push_device_revoke_token(text)',
    'private.api042_command(text, uuid, jsonb, uuid, bigint)',
    'private.api042_command_pre_push_devices(text, uuid, jsonb, uuid, bigint)'
  ] loop
    execute format('alter function %s owner to postgres', fn);
    execute format('revoke all on function %s from public, anon, authenticated, service_role, studafy_api_runtime, studafy_worker_runtime', fn);
  end loop;
end
$grants$;

grant execute on function
  private.channel_fanout(integer),
  private.channel_claim(text, integer),
  private.channel_finish(bigint, boolean, text, boolean, text),
  private.push_device_revoke_token(text)
to studafy_worker_runtime;
grant execute on function private.api042_command(text, uuid, jsonb, uuid, bigint)
  to studafy_api_runtime;

-- A deleted account (DL-051) must never receive another push notification,
-- whichever path marked it deleted.
create or replace function private.revoke_push_devices_on_profile_delete()
returns trigger language plpgsql security definer set search_path = '' as $$
begin
  if new.status = 'deleted' and old.status is distinct from 'deleted' then
    update public.push_devices set revoked_at = now()
      where user_id = new.id and revoked_at is null;
  end if;
  return new;
end;
$$;
alter function private.revoke_push_devices_on_profile_delete() owner to postgres;
revoke all on function private.revoke_push_devices_on_profile_delete()
  from public, anon, authenticated, service_role, studafy_api_runtime, studafy_worker_runtime;
create trigger dl053_revoke_push_devices_on_delete
after update of status on public.profiles
for each row execute function private.revoke_push_devices_on_profile_delete();
