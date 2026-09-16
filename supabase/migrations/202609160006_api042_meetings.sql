-- API-042 S5: meetings. requestMeeting resolves every recipient (enrolled
-- students, their verified guardians, classroom staff) with one set-based
-- query and inserts every meeting_deliveries row with one bulk INSERT ...
-- SELECT - this is the fix for the create-google-meet Edge Function's N+1
-- (a guardian_links lookup per student, then an auth.admin lookup per
-- recipient). The bulk email resolution the dispatcher needs for the
-- Calendar invite is private.meeting_recipient_emails, granted only to
-- studafy_worker_runtime, never studafy_api_runtime: ordinary /v1 requests
-- still never read auth.users.

alter table public.meetings add column if not exists version bigint not null default 1;
alter table public.meetings
  add constraint api042_meetings_version_check check (version > 0) not valid;
alter table public.meetings validate constraint api042_meetings_version_check;

create or replace function private.is_meeting_authorized(p_meeting uuid)
returns boolean language sql stable security definer set search_path = '' as $$
  select exists (
    select 1 from public.meetings m
    where m.id = p_meeting and (
      private.is_school_admin(m.school_id) or private.api041_class_writer(m.classroom_id)
    )
  );
$$;

alter function private.authz_authorize(text, uuid)
  rename to authz_authorize_pre_api042_meetings;

create or replace function private.authz_authorize(p_action text, p_resource_id uuid)
returns jsonb language plpgsql stable security definer set search_path = '' as $$
declare target_school uuid; permitted boolean := false;
begin
  if p_action not in ('meeting.request', 'meeting.cancel', 'meeting.status') then
    return private.authz_authorize_pre_api042_meetings(p_action, p_resource_id);
  end if;
  if auth.uid() is null or p_resource_id is null then
    return jsonb_build_object('allowed', false, 'school_id', null, 'reason', 'invalid_resource');
  end if;

  case
    when p_action = 'meeting.request' then
      select c.school_id, private.api041_class_writer(c.id)
      into target_school, permitted from public.classrooms c where c.id = p_resource_id;
    when p_action = 'meeting.cancel' then
      select m.school_id, private.is_meeting_authorized(m.id)
      into target_school, permitted from public.meetings m where m.id = p_resource_id;
    when p_action = 'meeting.status' then
      select m.school_id, (private.is_meeting_authorized(m.id) or exists (
        select 1 from public.meeting_deliveries md where md.meeting_id = m.id and md.recipient_id = auth.uid()
      )) into target_school, permitted from public.meetings m where m.id = p_resource_id;
  end case;
  return jsonb_build_object('allowed', coalesce(permitted, false), 'school_id', target_school,
    'reason', case when target_school is null then 'invalid_resource' when permitted then 'allowed' else 'denied' end);
end;
$$;

create or replace function private.api042_meeting_json(p_id uuid)
returns jsonb language sql stable security definer set search_path = '' as $$
  select jsonb_build_object(
    'id', m.id, 'classroomId', m.classroom_id, 'title', m.title, 'startsAt', m.starts_at, 'endsAt', m.ends_at,
    'audience', m.audience, 'state', m.state, 'meetUrl', m.meet_url, 'version', m.version,
    'recipientCount', (select count(*) from public.meeting_deliveries md where md.meeting_id = m.id)
  ) from public.meetings m where m.id = p_id;
$$;

-- Granted only to studafy_worker_runtime (see grants at the end): the
-- dispatcher's one bulk read of attendee emails for the Calendar invite.
create or replace function private.meeting_recipient_emails(p_meeting uuid)
returns table(recipient_id uuid, email text)
language sql stable security definer set search_path = '' as $$
  select md.recipient_id, u.email
  from public.meeting_deliveries md
  join auth.users u on u.id = md.recipient_id
  where md.meeting_id = p_meeting and md.state = 'queued';
$$;

alter function private.api042_query(text, uuid, jsonb)
  rename to api042_query_pre_s5_meetings;

create or replace function private.api042_query(p_operation text, p_resource_id uuid, p_input jsonb)
returns jsonb language plpgsql stable security definer set search_path = '' as $$
begin
  if p_operation <> 'getMeetingStatus' then
    return private.api042_query_pre_s5_meetings(p_operation, p_resource_id, p_input);
  end if;
  if auth.uid() is null then return jsonb_build_object('outcome', 'forbidden'); end if;
  if not exists (select 1 from public.meetings where id = p_resource_id) then
    return jsonb_build_object('outcome', 'not_found');
  end if;
  if not (
    private.is_meeting_authorized(p_resource_id)
    or exists (
      select 1 from public.meeting_deliveries md
      where md.meeting_id = p_resource_id and md.recipient_id = auth.uid()
    )
  ) then
    return jsonb_build_object('outcome', 'forbidden');
  end if;
  return jsonb_build_object('meeting', private.api042_meeting_json(p_resource_id), 'deliveries', coalesce((
    select jsonb_agg(jsonb_build_object('recipientId', md.recipient_id, 'state', md.state, 'deliveredAt', md.delivered_at)
      order by md.recipient_id)
    from public.meeting_deliveries md where md.meeting_id = p_resource_id
  ), '[]'::jsonb));
end;
$$;

alter function private.api042_command(text, uuid, jsonb, uuid, bigint)
  rename to api042_command_pre_s5_meetings;

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
  idem_key text; resolved_school uuid; existing_state text; existing_version bigint;
  outbox_template text; outbox_entity uuid; completed boolean;
  response_status int := coalesce((p_input->>'responseStatus')::int, 200);
begin
  if p_operation not in ('requestMeeting', 'cancelMeeting') then
    return private.api042_command_pre_s5_meetings(
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
    when 'requestMeeting' then
      if not exists (select 1 from public.classrooms c where c.id = p_resource_id and c.school_id = tenant) then
        return jsonb_build_object('outcome', 'not_found');
      end if;
      if not private.api041_class_writer(p_resource_id) then return jsonb_build_object('outcome', 'forbidden'); end if;
      if (req_body->>'endsAt')::timestamptz <= (req_body->>'startsAt')::timestamptz then
        return jsonb_build_object('outcome', 'invalid');
      end if;
      -- The idempotency key doubles as the schema's own
      -- db020_meetings_idempotency_key guard: a retried request can never
      -- create a second meeting even if the idempotency_records row were
      -- somehow lost.
      insert into public.meetings(school_id, classroom_id, title, starts_at, ends_at, audience, state, created_by, idempotency_key, version)
      values (tenant, p_resource_id, req_body->>'title', (req_body->>'startsAt')::timestamptz, (req_body->>'endsAt')::timestamptz,
        coalesce(req_body->>'audience', 'both')::public.meeting_audience, 'pending', auth.uid(), idem_key, 1)
      on conflict (school_id, idempotency_key) do nothing
      returning id into entity_id;
      if entity_id is null then
        select id into entity_id from public.meetings where school_id = tenant and idempotency_key = idem_key;
      else
        -- One set-based recipient resolution, one bulk insert - not a
        -- per-student guardian lookup followed by a per-recipient loop.
        insert into public.meeting_deliveries(school_id, meeting_id, recipient_id, state)
        select tenant, entity_id, recipient_id, 'queued' from (
          select distinct r.recipient_id from (
            select st.user_id as recipient_id from public.enrollments e
              join public.students st on st.id = e.student_id
              where e.classroom_id = p_resource_id and e.active and e.status = 'active'
                and coalesce(req_body->>'audience', 'both') in ('students', 'both')
            union all
            select gl.guardian_id from public.guardian_links gl
              join public.enrollments e on e.student_id = gl.student_id
              where e.classroom_id = p_resource_id and e.active and e.status = 'active'
                and gl.status = 'verified' and (gl.expires_at is null or gl.expires_at > now())
                and coalesce(req_body->>'audience', 'both') in ('guardians', 'both')
            union all
            select cs.user_id from public.classroom_staff cs
              where cs.classroom_id = p_resource_id and cs.status = 'active'
          ) r where r.recipient_id is not null
        ) r;
      end if;
      response := private.api042_meeting_json(entity_id);
      entity_type := 'meeting'; audit_action := 'meeting_requested';
      outbox_template := 'meetings.requested'; outbox_entity := entity_id;

    when 'cancelMeeting' then
      select m.school_id, m.state, m.version, to_jsonb(m) into resolved_school, existing_state, existing_version, before_value
      from public.meetings m where m.id = p_resource_id for update;
      if resolved_school is null then return jsonb_build_object('outcome', 'not_found'); end if;
      if resolved_school <> tenant then return jsonb_build_object('outcome', 'forbidden'); end if;
      if not private.is_meeting_authorized(p_resource_id) then return jsonb_build_object('outcome', 'forbidden'); end if;
      if existing_version <> (req_body->>'expectedVersion')::bigint then return jsonb_build_object('outcome', 'version_conflict'); end if;
      if existing_state not in ('pending', 'scheduled') then return jsonb_build_object('outcome', 'invalid_state'); end if;
      update public.meetings set state = 'cancelled', version = version + 1, updated_at = now() where id = p_resource_id;
      -- One bulk update, matching what the legacy cancel-google-meet Edge
      -- Function already got right for this specific step.
      update public.meeting_deliveries set state = 'cancelled'
      where meeting_id = p_resource_id and state in ('queued', 'sent');
      entity_id := p_resource_id; entity_type := 'meeting'; audit_action := 'meeting_cancelled';
      response := private.api042_meeting_json(entity_id);
      tenant := resolved_school;
      outbox_template := 'meetings.cancelled'; outbox_entity := entity_id;

    else return jsonb_build_object('outcome', 'invalid');
  end case;

  insert into public.audit_events(school_id, actor_id, action, entity_type, entity_id, before_value, after_value, request_id)
  values (tenant, auth.uid(), audit_action, entity_type, entity_id, before_value, response, request_id);
  if outbox_template is not null then
    insert into public.notification_outbox(school_id, source_event_id, idempotency_key, channel, template_key, audience, payload)
    values (tenant, outbox_entity::text, idem_key, 'in_app', outbox_template,
      jsonb_build_object('schoolId', tenant), coalesce(response, '{}'::jsonb));
  end if;
  completed := private.api_idempotency_complete(p_idempotency_id, p_idempotency_generation, response_status, response);
  if not completed then raise exception 'API042_IDEMPOTENCY_COMPLETION_FAILED'; end if;
  return jsonb_build_object('outcome', 'ok', 'response', response);
end;
$$;

alter function private.is_meeting_authorized(uuid) owner to postgres;
alter function private.api042_meeting_json(uuid) owner to postgres;
alter function private.meeting_recipient_emails(uuid) owner to postgres;
alter function private.api042_query(text, uuid, jsonb) owner to postgres;
alter function private.api042_command(text, uuid, jsonb, uuid, bigint) owner to postgres;
alter function private.authz_authorize(text, uuid) owner to postgres;

revoke all on function private.is_meeting_authorized(uuid), private.api042_meeting_json(uuid),
  private.meeting_recipient_emails(uuid), private.api042_query(text, uuid, jsonb),
  private.api042_command(text, uuid, jsonb, uuid, bigint)
from public, anon, authenticated, service_role, studafy_worker_runtime;
revoke all on function private.api042_query_pre_s5_meetings(text, uuid, jsonb)
from public, anon, authenticated, service_role, studafy_worker_runtime, studafy_api_runtime;
revoke all on function private.api042_command_pre_s5_meetings(text, uuid, jsonb, uuid, bigint)
from public, anon, authenticated, service_role, studafy_worker_runtime, studafy_api_runtime;
revoke all on function private.authz_authorize_pre_api042_meetings(text, uuid)
from public, anon, authenticated, service_role, studafy_worker_runtime, studafy_api_runtime;
revoke all on function private.authz_authorize(text, uuid)
from public, anon, authenticated, service_role, studafy_worker_runtime;
grant execute on function private.authz_authorize(text, uuid),
  private.api042_query(text, uuid, jsonb), private.api042_command(text, uuid, jsonb, uuid, bigint)
to studafy_api_runtime;
-- The bulk email-resolution function is the one thing in this migration the
-- worker role needs that the API role must never have.
grant execute on function private.meeting_recipient_emails(uuid) to studafy_worker_runtime;

revoke all privileges on all tables in schema public from studafy_api_runtime;
revoke all privileges on all sequences in schema public from studafy_api_runtime;
revoke all privileges on all tables in schema public from studafy_worker_runtime;
revoke all privileges on all sequences in schema public from studafy_worker_runtime;
