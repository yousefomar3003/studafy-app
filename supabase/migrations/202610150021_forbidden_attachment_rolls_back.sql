-- A message or announcement whose attachment is forbidden is not kept
-- (follows 202610150020).
--
-- private.api042_command_pre_meeting_links binds a message's or an
-- announcement's files after the layers below it have created the message
-- or announcement. When the binder answered 'forbidden' (another account's
-- file, or another school's), the layer returned {"outcome": "forbidden"}
-- but did not undo what was already written: the API answered 403 while the
-- message, its notification fan-out, the conversation's last-activity time
-- and the completed idempotency record were all committed.
--
-- The layer now raises SQLSTATE SF053 with the binder's outcome as the
-- message, and private.api042_command, whose whole body is one block, turns
-- it back into {"outcome": "forbidden"} after unwinding everything below:
-- the same rollback a named refusal (SF052) already gets. The answer is
-- unchanged - still 'forbidden', still naming nothing - and who may attach
-- what is unchanged; only what is kept after the refusal changes.
--
-- ADR-0030: both functions are replaced in place with the same signatures,
-- so owners and grants are kept. api042_command_pre_meeting_links is one of
-- the middleware layers that ADR left in place; its body changes, its name
-- does not, and nothing is renamed or wrapped.

create or replace function private.api042_command_pre_meeting_links(p_operation text, p_resource_id uuid, p_input jsonb, p_idempotency_id uuid, p_idempotency_generation bigint)
returns jsonb language plpgsql security definer set search_path to '' as $function$
declare
  result jsonb;
  v_attachments jsonb;
  v_entity uuid;
  v_school uuid;
  v_bind text;
begin
  result := private.api042_command_pre_attachments(
    p_operation, p_resource_id, p_input, p_idempotency_id,
    p_idempotency_generation);

  if p_operation not in ('sendMessage', 'createAnnouncement')
    or coalesce(result->>'outcome', '') <> 'ok' then
    return result;
  end if;

  v_attachments := (p_input->'body')->'attachmentFileIds';
  if v_attachments is null or jsonb_array_length(coalesce(v_attachments, '[]'::jsonb)) = 0 then
    return result;
  end if;

  v_entity := ((result->'response')->>'id')::uuid;
  if v_entity is null then raise exception 'FILE_ATTACH_NO_ENTITY'; end if;

  if p_operation = 'sendMessage' then
    select m.school_id into v_school from public.messages m where m.id = v_entity;
    v_bind := private.file_attach_bind(
      v_attachments, 'message_attachment'::public.file_purpose, v_school,
      p_message => v_entity);
  else
    select an.school_id into v_school
    from public.announcements an where an.id = v_entity;
    v_bind := private.file_attach_bind(
      v_attachments, 'announcement_attachment'::public.file_purpose, v_school,
      p_announcement => v_entity);
  end if;

  -- Changed: the message or announcement above is not kept. Unwound by
  -- private.api042_command, which answers with this outcome.
  if v_bind <> 'ok' then
    raise exception using errcode = 'SF053', message = v_bind;
  end if;

  return jsonb_set(
    result, array['response', 'attachments'],
    case when p_operation = 'sendMessage'
      then private.file_attachment_json(p_message => v_entity)
      else private.file_attachment_json(p_announcement => v_entity)
    end);
end;
$function$;

-- 202610150020's body with one more handler: SF053, a binder outcome
-- ('forbidden') raised so that what was created with it is unwound.
create or replace function private.api042_command(p_operation text, p_resource_id uuid, p_input jsonb, p_idempotency_id uuid, p_idempotency_generation bigint)
returns jsonb language plpgsql security definer set search_path to '' as $function$
declare
  v_actor uuid := auth.uid();
  v_at timestamptz := now();
  v_count int;
  response jsonb;
  v_detail text;
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
exception
  when sqlstate 'SF052' then
    -- Raised by private.attachment_refuse: the message or announcement it
    -- came with was not kept.
    get stacked diagnostics v_detail = pg_exception_detail;
    return jsonb_build_object('outcome', 'attachment_refused', 'rows', v_detail::jsonb);
  when sqlstate 'SF053' then
    -- A file the caller may not attach: nothing below was kept, and the
    -- answer names nothing.
    return jsonb_build_object('outcome', sqlerrm);
end;
$function$;
