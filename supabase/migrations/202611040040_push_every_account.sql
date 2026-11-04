-- Push notifications reach every account signed in on the phone (DL-082).
--
-- The app keeps several accounts on one phone (ADR-0031): accounts people
-- signed in to themselves, and the child accounts a parent manages. Until
-- now a phone's push token belonged to one account at a time: registering
-- it for B revoked A's registration (202609190011), so only the account
-- last open on the phone got its notifications.
--
-- Now:
--
--   * one live row per (account, token), so the same phone can be
--     registered for several accounts at once. Registering for B leaves A's
--     row alone;
--   * a parent's registration also covers the child accounts they manage:
--     a child account has no email or phone and is only ever entered through
--     the parent, on the parent's phones, so the parent's phone is the
--     child's phone. Unregistering as the parent (signing out of the phone,
--     which takes the children with it) removes the children's rows for the
--     token too;
--   * unregistering as anyone else removes only the caller's own row;
--   * a token the provider reports dead is still revoked for every account
--     (private.push_device_revoke_token is unchanged and already does this);
--   * a push job now carries `recipientId`, the account it is for, so a tap
--     on the phone opens it as that account. An opaque id, like
--     `notificationId`; the copy is still the fixed, content-free text.
--
-- Account deletion is unchanged: both deletion paths delete the account's
-- rows and the profile trigger revokes them, whichever account shares the
-- token.

drop index if exists public.push_devices_live_token_idx;
create unique index if not exists push_devices_live_user_token_idx
  on public.push_devices (user_id, token) where revoked_at is null;
-- Dead-token revocation and the per-token lookups stay indexed.
create index if not exists push_devices_live_token_lookup_idx
  on public.push_devices (token) where revoked_at is null;

-- The push-device commands live in this link of the api042_command chain
-- (202609190011 created it as private.api042_command; 202609210005 renamed
-- it). Replaced in place: same signature, owner and grants.
create or replace function private.api042_command_pre_student_family(
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
  v_platform text := req_body->>'platform';
  v_account uuid;
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
    -- The caller, and the active child accounts the caller manages. Other
    -- accounts on the same phone keep their own rows.
    for v_account in
      select v_actor
      union
      select m.child_id from private.managed_accounts m
        join public.profiles p on p.id = m.child_id and p.status = 'active'
        where m.guardian_id = v_actor
    loop
      update public.push_devices set last_seen_at = now(), platform = v_platform
        where token = v_token and revoked_at is null and user_id = v_account;
      if not found then
        insert into public.push_devices(user_id, platform, token)
        values (v_account, v_platform, v_token);
      end if;
    end loop;
    response := jsonb_build_object('registered', true);
  else
    -- The caller's own row, and those of the child accounts they manage,
    -- which leave the phone with them. Nobody else's.
    update public.push_devices set revoked_at = now()
      where token = v_token and revoked_at is null
        and (user_id = v_actor or user_id in (
          select m.child_id from private.managed_accounts m
          where m.guardian_id = v_actor));
    response := jsonb_build_object('registered', false);
  end if;

  completed := private.api_idempotency_complete(p_idempotency_id, p_idempotency_generation, response_status, response);
  if not completed then raise exception 'PUSH_DEVICE_IDEMPOTENCY_COMPLETION_FAILED'; end if;
  return jsonb_build_object('outcome', 'ok', 'response', response);
end;
$$;

alter function private.api042_command_pre_student_family(text, uuid, jsonb, uuid, bigint)
  owner to postgres;
revoke all on function private.api042_command_pre_student_family(text, uuid, jsonb, uuid, bigint)
  from public, anon, authenticated, service_role, studafy_api_runtime, studafy_worker_runtime;

-- As in 202610180010, plus `recipientId` on push jobs.
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
        order by x.id desc limit 1) end,
      'recipientId', case when p_channel = 'push' then l.recipient_id::text end
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
