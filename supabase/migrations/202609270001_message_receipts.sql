-- Message receipts: sent, delivered, read - the ticks people expect from
-- WhatsApp.
--
-- conversation_participants.last_read_at existed but only moved when someone
-- *sent* a message, so it could not say whether they had read anyone else's,
-- and nothing recorded delivery at all. This adds:
--
--   * last_delivered_at, advanced when a participant's app fetches their
--     conversations (acknowledgeMessageDelivery). "Delivered" means what it
--     means in WhatsApp: it reached their device, not that they looked.
--   * markConversationRead, called when a participant opens the chat. It
--     advances last_read_at, and last_delivered_at with it - a message that
--     has been read has certainly arrived.
--   * `status` on the sender's own messages, derived from both: `read` when
--     every other active participant has read up to it, `delivered` when
--     every one has received it, otherwise `sent`. For a group, as in
--     WhatsApp, a tick means everyone. Other people's messages carry no
--     status: whether a third participant read a message is not the
--     reader's business.
--
-- Receipts are derived from two timestamps per participant, not stored per
-- message, so marking a whole conversation read is one row update however
-- long the conversation is.

alter table public.conversation_participants
  add column if not exists last_delivered_at timestamptz;

-- ---------------------------------------------------------------------------
-- 1. Status of one message, for its sender.
-- ---------------------------------------------------------------------------
create or replace function private.message_receipt_status(p_message uuid)
returns text language sql stable security definer set search_path = '' as $$
  with m as (
    select id, conversation_id, sender_id, created_at
    from public.messages where id = p_message
  ), others as (
    select cp.last_read_at, cp.last_delivered_at
    from public.conversation_participants cp, m
    where cp.conversation_id = m.conversation_id
      and cp.user_id <> m.sender_id and cp.left_at is null
  )
  select case
    when not exists (select 1 from others) then 'sent'
    when (select bool_and(o.last_read_at is not null and o.last_read_at >= m.created_at)
          from others o, m) then 'read'
    -- coalesce: someone who has never fetched anything has no timestamp,
    -- and bool_and skips nulls - without it they would count as received.
    when (select bool_and(coalesce(
            greatest(o.last_delivered_at, o.last_read_at) >= m.created_at, false))
          from others o, m) then 'delivered'
    else 'sent'
  end
  from m;
$$;

revoke all on function private.message_receipt_status(uuid)
  from public, anon, authenticated, service_role, studafy_worker_runtime,
  studafy_api_runtime;
alter function private.message_receipt_status(uuid) owner to postgres;

-- The one message shape, now with the sender's receipt.
create or replace function private.api042_message_json(p_id uuid)
returns jsonb language sql stable security definer set search_path = '' as $$
  select jsonb_build_object(
    'id', m.id, 'conversationId', m.conversation_id, 'senderId', m.sender_id,
    'clientMessageId', m.client_message_id, 'body', m.body,
    'createdAt', m.created_at,
    'attachments', private.file_attachment_json(p_message => m.id),
    'status', case when m.sender_id = auth.uid()
      then private.message_receipt_status(m.id) end
  ) from public.messages m where m.id = p_id and m.deleted_at is null;
$$;

alter function private.api042_message_json(uuid) owner to postgres;

-- ---------------------------------------------------------------------------
-- 2. Deciding who may send a receipt.
-- ---------------------------------------------------------------------------
do $$ begin
  if not exists (
    select 1 from pg_proc p join pg_namespace n on n.oid = p.pronamespace
    where n.nspname = 'private' and p.proname = 'authz_authorize_pre_receipts'
  ) then
    alter function private.authz_authorize(text, uuid)
      rename to authz_authorize_pre_receipts;
  end if;
end $$;

create or replace function private.authz_authorize(
  p_action text, p_resource_id uuid)
returns jsonb language plpgsql stable security definer set search_path = '' as $$
declare
  sid uuid;
begin
  if p_action <> 'conversation.mark_read' then
    return private.authz_authorize_pre_receipts(p_action, p_resource_id);
  end if;
  if auth.uid() is null or p_resource_id is null then
    return jsonb_build_object('allowed', false, 'school_id', null, 'reason', 'invalid_resource');
  end if;
  select c.school_id into sid from public.conversations c where c.id = p_resource_id;
  if sid is null or not private.is_conversation_participant(p_resource_id) then
    return jsonb_build_object('allowed', false, 'school_id', sid, 'reason',
      case when sid is null then 'invalid_resource' else 'denied' end);
  end if;
  return jsonb_build_object('allowed', true, 'school_id', sid, 'reason', 'participant');
end;
$$;

alter function private.authz_authorize(text, uuid) owner to postgres;
alter function private.authz_authorize_pre_receipts(text, uuid) owner to postgres;
revoke all on function private.authz_authorize_pre_receipts(text, uuid)
  from public, anon, authenticated, service_role, studafy_worker_runtime,
  studafy_api_runtime;
revoke all on function private.authz_authorize(text, uuid)
  from public, anon, authenticated, service_role, studafy_worker_runtime;
grant execute on function private.authz_authorize(text, uuid)
  to studafy_api_runtime;

-- ---------------------------------------------------------------------------
-- 3. The two receipt commands.
-- ---------------------------------------------------------------------------
do $$ begin
  if not exists (
    select 1 from pg_proc p join pg_namespace n on n.oid = p.pronamespace
    where n.nspname = 'private' and p.proname = 'api042_command_pre_receipts'
  ) then
    alter function private.api042_command(text, uuid, jsonb, uuid, bigint)
      rename to api042_command_pre_receipts;
  end if;
end $$;

create or replace function private.api042_command(
  p_operation text, p_resource_id uuid, p_input jsonb,
  p_idempotency_id uuid, p_idempotency_generation bigint)
returns jsonb language plpgsql security definer set search_path = '' as $$
declare
  v_actor uuid := auth.uid();
  v_at timestamptz := now();
  v_count int;
  response jsonb;
begin
  if p_operation not in ('markConversationRead', 'acknowledgeMessageDelivery') then
    return private.api042_command_pre_receipts(
      p_operation, p_resource_id, p_input, p_idempotency_id,
      p_idempotency_generation);
  end if;
  if v_actor is null then return jsonb_build_object('outcome', 'forbidden'); end if;

  if p_operation = 'markConversationRead' then
    -- Never moves backwards: a stale request arriving late must not un-read
    -- what a newer one already read.
    update public.conversation_participants cp
    set last_read_at = greatest(coalesce(cp.last_read_at, v_at), v_at),
        last_delivered_at = greatest(coalesce(cp.last_delivered_at, v_at), v_at)
    where cp.conversation_id = p_resource_id and cp.user_id = v_actor
      and cp.left_at is null;
    if not found then return jsonb_build_object('outcome', 'not_found'); end if;
    response := jsonb_build_object('conversationId', p_resource_id, 'readAt', v_at);
  else
    -- Every conversation the actor is in: their app has just fetched them.
    update public.conversation_participants cp
    set last_delivered_at = v_at
    where cp.user_id = v_actor and cp.left_at is null
      and (cp.last_delivered_at is null or cp.last_delivered_at < v_at);
    get diagnostics v_count = row_count;
    response := jsonb_build_object('acknowledgedAt', v_at, 'conversations', v_count);
  end if;

  if not private.api_idempotency_complete(
    p_idempotency_id, p_idempotency_generation, 200, response) then
    raise exception 'API042_IDEMPOTENCY_COMPLETION_FAILED';
  end if;
  return jsonb_build_object('outcome', 'ok', 'response', response);
end;
$$;

alter function private.api042_command(text, uuid, jsonb, uuid, bigint)
  owner to postgres;
alter function private.api042_command_pre_receipts(
  text, uuid, jsonb, uuid, bigint) owner to postgres;
revoke all on function private.api042_command_pre_receipts(
  text, uuid, jsonb, uuid, bigint)
  from public, anon, authenticated, service_role, studafy_worker_runtime,
  studafy_api_runtime;
revoke all on function private.api042_command(text, uuid, jsonb, uuid, bigint)
  from public, anon, authenticated, service_role, studafy_worker_runtime;
grant execute on function private.api042_command(
  text, uuid, jsonb, uuid, bigint) to studafy_api_runtime;
