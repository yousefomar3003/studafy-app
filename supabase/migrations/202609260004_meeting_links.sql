-- Meetings the teacher hosts on Google Meet.
--
-- DL-052 had the worker create each meeting's calendar event and video link
-- through a conferencing provider. No provider is configured, so every
-- meeting sat `pending` until its start passed and then failed, and nobody
-- was ever told about it. Studafy does not host the call and should not need
-- to: the teacher creates the meeting in Google Meet and gives Studafy the
-- link. This makes that the path:
--
--   * requestMeeting accepts `meetUrl`. With one, the meeting is scheduled
--     at once through the same private.meeting_finish_schedule the worker
--     used, so recipients are notified exactly as before and the worker -
--     which only claims `pending` meetings - never touches it. Without one,
--     the old provider path is unchanged.
--   * Only https://meet.google.com/ links are accepted. A teacher account
--     sends this link to every family in a class; an allowlist keeps it from
--     being usable to send them anywhere else.
--   * listMeetings is new. Until now a meeting could only be fetched by its
--     id, so nobody but its creator could ever find one. It lists what the
--     caller was invited to - the delivery rows resolved when the meeting was
--     created are the authority - plus, for staff, their classes' meetings.
--
-- Forward-only: both surfaces are renamed and delegated to.

-- ---------------------------------------------------------------------------
-- 1. Scheduling with a link.
-- ---------------------------------------------------------------------------
create or replace function private.meeting_link_is_allowed(p_url text)
returns boolean language sql immutable set search_path = '' as $$
  select p_url ~ '^https://meet\.google\.com/[A-Za-z0-9-]{3,64}(\?[A-Za-z0-9=&._-]{0,200})?$';
$$;
revoke all on function private.meeting_link_is_allowed(text)
  from public, anon, authenticated, service_role, studafy_worker_runtime,
  studafy_api_runtime;
alter function private.meeting_link_is_allowed(text) owner to postgres;

do $$ begin
  if not exists (
    select 1 from pg_proc p join pg_namespace n on n.oid = p.pronamespace
    where n.nspname = 'private' and p.proname = 'api042_command_pre_meeting_links'
  ) then
    alter function private.api042_command(text, uuid, jsonb, uuid, bigint)
      rename to api042_command_pre_meeting_links;
  end if;
end $$;

create or replace function private.api042_command(
  p_operation text, p_resource_id uuid, p_input jsonb,
  p_idempotency_id uuid, p_idempotency_generation bigint)
returns jsonb language plpgsql security definer set search_path = '' as $$
declare
  v_url text := nullif(trim((p_input->'body')->>'meetUrl'), '');
  result jsonb;
  v_meeting uuid;
  v_response jsonb;
begin
  if p_operation <> 'requestMeeting' or v_url is null then
    return private.api042_command_pre_meeting_links(
      p_operation, p_resource_id, p_input, p_idempotency_id,
      p_idempotency_generation);
  end if;
  if not private.meeting_link_is_allowed(v_url) then
    return jsonb_build_object('outcome', 'invalid');
  end if;

  result := private.api042_command_pre_meeting_links(
    p_operation, p_resource_id, p_input, p_idempotency_id,
    p_idempotency_generation);
  if coalesce(result->>'outcome', '') <> 'ok' then return result; end if;

  v_meeting := ((result->'response')->>'id')::uuid;
  -- Scheduled now, with the teacher's link: the same transition, delivery
  -- update and in-app notification the provider path performed.
  perform private.meeting_finish_schedule(v_meeting, null, v_url);

  v_response := private.api042_meeting_json(v_meeting);
  -- The delegate stored its answer while the meeting was still pending; a
  -- replay must describe the meeting as it now is.
  update public.idempotency_records r
  set response_body = v_response
  where r.id = p_idempotency_id and r.actor_id = auth.uid()
    and r.generation = p_idempotency_generation and r.status = 'completed';
  return jsonb_set(result, array['response'], v_response);
end;
$$;

alter function private.api042_command(text, uuid, jsonb, uuid, bigint)
  owner to postgres;
alter function private.api042_command_pre_meeting_links(
  text, uuid, jsonb, uuid, bigint) owner to postgres;
revoke all on function private.api042_command_pre_meeting_links(
  text, uuid, jsonb, uuid, bigint)
  from public, anon, authenticated, service_role, studafy_worker_runtime,
  studafy_api_runtime;
revoke all on function private.api042_command(text, uuid, jsonb, uuid, bigint)
  from public, anon, authenticated, service_role, studafy_worker_runtime;
grant execute on function private.api042_command(
  text, uuid, jsonb, uuid, bigint) to studafy_api_runtime;

-- ---------------------------------------------------------------------------
-- 2. Listing the meetings one was invited to.
-- ---------------------------------------------------------------------------
do $$ begin
  if not exists (
    select 1 from pg_proc p join pg_namespace n on n.oid = p.pronamespace
    where n.nspname = 'private' and p.proname = 'api042_query_pre_meeting_list'
  ) then
    alter function private.api042_query(text, uuid, jsonb)
      rename to api042_query_pre_meeting_list;
  end if;
end $$;

create or replace function private.api042_query(
  p_operation text, p_resource_id uuid, p_input jsonb)
returns jsonb language plpgsql stable security definer set search_path = '' as $$
declare
  v_class uuid;
  v_items jsonb;
begin
  if p_operation <> 'listMeetings' then
    return private.api042_query_pre_meeting_list(p_operation, p_resource_id, p_input);
  end if;
  if auth.uid() is null then return jsonb_build_object('outcome', 'forbidden'); end if;
  v_class := nullif(p_input->>'classroomId', '')::uuid;

  select coalesce(jsonb_agg(
      private.api042_meeting_json(m.id)
        || jsonb_build_object('classroomName', c.name)
      order by m.starts_at, m.id), '[]'::jsonb)
  into v_items
  from public.meetings m
  join public.classrooms c on c.id = m.classroom_id
  where (v_class is null or m.classroom_id = v_class)
    -- Still worth showing: upcoming, and a day of grace after the end so a
    -- meeting running late is not pulled from under the people in it.
    and m.ends_at >= now() - interval '1 day'
    and (
      -- Invited: the recipients were fixed when the meeting was created.
      exists (select 1 from public.meeting_deliveries md
        where md.meeting_id = m.id and md.recipient_id = auth.uid()
          and md.state in ('queued', 'sent', 'cancelled'))
      or m.created_by = auth.uid()
      or private.is_class_staff(m.classroom_id)
      or private.is_school_admin(m.school_id)
    );

  return jsonb_build_object('items', v_items, 'nextPosition', null);
exception when invalid_text_representation then
  return jsonb_build_object('outcome', 'not_found');
end;
$$;

alter function private.api042_query(text, uuid, jsonb) owner to postgres;
alter function private.api042_query_pre_meeting_list(text, uuid, jsonb)
  owner to postgres;
revoke all on function private.api042_query_pre_meeting_list(text, uuid, jsonb)
  from public, anon, authenticated, service_role, studafy_worker_runtime,
  studafy_api_runtime;
revoke all on function private.api042_query(text, uuid, jsonb)
  from public, anon, authenticated, service_role, studafy_worker_runtime;
grant execute on function private.api042_query(text, uuid, jsonb)
  to studafy_api_runtime;
