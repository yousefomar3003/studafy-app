-- API-042 S6: notifications. notification_outbox/notification_deliveries
-- (API-040/041-era) is the authoritative pair going forward; the legacy
-- public.notifications table stays read-only history, written by nothing
-- new. Without OPS-061's worker to expand a broad "audience" outbox row
-- into per-recipient deliveries, a direct per-recipient row is the only
-- honest way to make something appear in a recipient's list today:
-- private.notify_recipient inserts one outbox row (recipient_id set, not
-- audience) and its matching in-app delivery atomically, granted for reuse
-- by any future command or by OPS-061's worker. S1-S5's earlier
-- audience-only outbox rows are not retrofitted by this migration - they
-- remain audit/fan-out records pending that expansion step, and this is
-- recorded in the API-042 evidence doc rather than silently implied
-- otherwise.

alter table public.notification_deliveries add column if not exists read_at timestamptz;

create or replace function private.notify_recipient(
  p_school_id uuid,
  p_recipient_id uuid,
  p_template_key text,
  p_payload jsonb,
  p_source_event_id text,
  p_idempotency_key text
)
returns void language plpgsql security definer set search_path = '' as $$
declare v_outbox_id bigint;
begin
  insert into public.notification_outbox(school_id, source_event_id, idempotency_key, channel, template_key, recipient_id, payload)
  values (p_school_id, p_source_event_id, p_idempotency_key, 'in_app', p_template_key, p_recipient_id, p_payload)
  on conflict (school_id, idempotency_key) do nothing
  returning id into v_outbox_id;
  if v_outbox_id is not null then
    insert into public.notification_deliveries(school_id, outbox_id, recipient_id, channel, attempt, state, delivered_at)
    values (p_school_id, v_outbox_id, p_recipient_id, 'in_app', 1, 'sent', now());
  end if;
end;
$$;

create or replace function private.api042_notification_json(p_id bigint)
returns jsonb language sql stable security definer set search_path = '' as $$
  select jsonb_build_object(
    'id', nd.id::text, 'templateKey', o.template_key, 'payload', o.payload,
    'createdAt', o.created_at, 'readAt', nd.read_at
  ) from public.notification_deliveries nd
  join public.notification_outbox o on o.id = nd.outbox_id
  where nd.id = p_id;
$$;

alter function private.api042_query(text, uuid, jsonb)
  rename to api042_query_pre_s6_notifications;

create or replace function private.api042_query(p_operation text, p_resource_id uuid, p_input jsonb)
returns jsonb language plpgsql stable security definer set search_path = '' as $$
declare limit_rows int; pos bigint; result jsonb; next_pos text;
begin
  if p_operation not in ('listNotifications', 'getUnreadCount', 'getNotificationPreferences') then
    return private.api042_query_pre_s6_notifications(p_operation, p_resource_id, p_input);
  end if;
  if auth.uid() is null then return jsonb_build_object('outcome', 'forbidden'); end if;

  case p_operation
    when 'listNotifications' then
      limit_rows := least(greatest(coalesce((p_input->>'pageSize')::int, 50), 1), 100);
      pos := nullif(p_input->>'position', '')::bigint;
      select coalesce(jsonb_agg(private.api042_notification_json(x.id) order by x.id desc), '[]'), min(x.id::text)
        into result, next_pos from (
        select nd.id from public.notification_deliveries nd
        where nd.recipient_id = auth.uid() and nd.channel = 'in_app' and (pos is null or nd.id < pos)
        order by nd.id desc limit limit_rows
      ) x;
      return jsonb_build_object('items', result, 'nextPosition', case when jsonb_array_length(result) = limit_rows then next_pos end);

    when 'getUnreadCount' then
      return jsonb_build_object('unreadCount', (
        select count(*) from public.notification_deliveries nd
        where nd.recipient_id = auth.uid() and nd.channel = 'in_app' and nd.read_at is null
      ));

    when 'getNotificationPreferences' then
      select coalesce(jsonb_agg(jsonb_build_object(
        'schoolId', p.school_id, 'channel', p.channel, 'category', p.category, 'enabled', p.enabled
      ) order by p.school_id nulls first, p.channel, p.category), '[]')
      into result from public.notification_preferences p where p.user_id = auth.uid();
      return jsonb_build_object('items', result, 'nextPosition', null);
    else return jsonb_build_object('outcome', 'not_found');
  end case;
end;
$$;

alter function private.api042_command(text, uuid, jsonb, uuid, bigint)
  rename to api042_command_pre_s6_notifications;

create or replace function private.api042_command(
  p_operation text,
  p_resource_id uuid,
  p_input jsonb,
  p_idempotency_id uuid,
  p_idempotency_generation bigint
)
returns jsonb language plpgsql security definer set search_path = '' as $$
declare
  tenant uuid := nullif(current_setting('studafy.school_id', true), '')::uuid;
  request_id text := nullif(current_setting('studafy.request_id', true), '');
  req_body jsonb := coalesce(p_input->'body', '{}'::jsonb);
  response jsonb; before_value jsonb;
  entity_id uuid; entity_type text; audit_action text;
  idem_key text; marked_count int; pref_id uuid;
  outbox_template text; outbox_entity uuid; completed boolean;
  response_status int := coalesce((p_input->>'responseStatus')::int, 200);
begin
  if p_operation not in ('markNotificationsRead', 'updateNotificationPreferences') then
    return private.api042_command_pre_s6_notifications(
      p_operation, p_resource_id, p_input, p_idempotency_id, p_idempotency_generation
    );
  end if;
  if auth.uid() is null or request_id is null then
    return jsonb_build_object('outcome', 'forbidden');
  end if;
  select r.idempotency_key into idem_key from public.idempotency_records r
  where r.id = p_idempotency_id and r.actor_id = auth.uid()
    and r.school_id is not distinct from tenant
    and r.generation = p_idempotency_generation and r.status = 'reserved'
  for update;
  if idem_key is null then return jsonb_build_object('outcome', 'forbidden'); end if;

  case p_operation
    when 'markNotificationsRead' then
      if coalesce((req_body->>'all')::boolean, false) then
        update public.notification_deliveries set read_at = now()
        where recipient_id = auth.uid() and channel = 'in_app' and read_at is null;
        get diagnostics marked_count = row_count;
      else
        if jsonb_array_length(coalesce(req_body->'ids', '[]'::jsonb)) > 100 then
          return jsonb_build_object('outcome', 'invalid');
        end if;
        update public.notification_deliveries set read_at = now()
        where recipient_id = auth.uid() and channel = 'in_app' and read_at is null
          and id = any(
            select (x)::bigint from jsonb_array_elements_text(coalesce(req_body->'ids', '[]'::jsonb)) x
          );
        get diagnostics marked_count = row_count;
      end if;
      response := jsonb_build_object('markedCount', marked_count);
      entity_type := 'notification_deliveries'; audit_action := 'notifications_marked_read';

    when 'updateNotificationPreferences' then
      if (req_body->>'schoolId') is not null then
        insert into public.notification_preferences(user_id, school_id, channel, category, enabled)
        values (auth.uid(), (req_body->>'schoolId')::uuid, req_body->>'channel', req_body->>'category', (req_body->>'enabled')::boolean)
        on conflict (user_id, school_id, channel, category) where school_id is not null
        do update set enabled = excluded.enabled, updated_at = now()
        returning id into pref_id;
      else
        insert into public.notification_preferences(user_id, school_id, channel, category, enabled)
        values (auth.uid(), null, req_body->>'channel', req_body->>'category', (req_body->>'enabled')::boolean)
        on conflict (user_id, channel, category) where school_id is null
        do update set enabled = excluded.enabled, updated_at = now()
        returning id into pref_id;
      end if;
      select jsonb_build_object('schoolId', p.school_id, 'channel', p.channel, 'category', p.category, 'enabled', p.enabled)
        into response from public.notification_preferences p where p.id = pref_id;
      entity_id := pref_id; entity_type := 'notification_preference'; audit_action := 'notification_preference_updated';

    else return jsonb_build_object('outcome', 'invalid');
  end case;

  insert into public.audit_events(school_id, actor_id, action, entity_type, entity_id, before_value, after_value, request_id)
  values (tenant, auth.uid(), audit_action, entity_type, entity_id, before_value, response, request_id);
  completed := private.api_idempotency_complete(p_idempotency_id, p_idempotency_generation, response_status, response);
  if not completed then raise exception 'API042_IDEMPOTENCY_COMPLETION_FAILED'; end if;
  return jsonb_build_object('outcome', 'ok', 'response', response);
end;
$$;

alter function private.notify_recipient(uuid, uuid, text, jsonb, text, text) owner to postgres;
alter function private.api042_notification_json(bigint) owner to postgres;
alter function private.api042_query(text, uuid, jsonb) owner to postgres;
alter function private.api042_command(text, uuid, jsonb, uuid, bigint) owner to postgres;

revoke all on function private.notify_recipient(uuid, uuid, text, jsonb, text, text),
  private.api042_notification_json(bigint), private.api042_query(text, uuid, jsonb),
  private.api042_command(text, uuid, jsonb, uuid, bigint)
from public, anon, authenticated, service_role, studafy_worker_runtime;
revoke all on function private.api042_query_pre_s6_notifications(text, uuid, jsonb)
from public, anon, authenticated, service_role, studafy_worker_runtime, studafy_api_runtime;
revoke all on function private.api042_command_pre_s6_notifications(text, uuid, jsonb, uuid, bigint)
from public, anon, authenticated, service_role, studafy_worker_runtime, studafy_api_runtime;
grant execute on function private.api042_query(text, uuid, jsonb), private.api042_command(text, uuid, jsonb, uuid, bigint)
to studafy_api_runtime;
-- Reserved for OPS-061's future worker, which runs as studafy_worker_runtime
-- and will need to call this directly rather than through a postgres-owned
-- command function. Not granted to studafy_api_runtime: ordinary requests
-- create notifications only as a side effect of a specific command, never
-- as an arbitrary "notify anyone" primitive.
grant execute on function private.notify_recipient(uuid, uuid, text, jsonb, text, text) to studafy_worker_runtime;

revoke all privileges on all tables in schema public from studafy_api_runtime;
revoke all privileges on all sequences in schema public from studafy_api_runtime;
