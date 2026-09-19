-- Meeting processor (DL-052). API-042 records meeting requests and their
-- recipients, but nothing ever created the calendar event, so every meeting
-- stayed `pending` and no invite or link was sent. The worker now claims
-- pending meetings, creates the event and video link through a conferencing
-- provider, and marks the meeting scheduled; it also withdraws the provider
-- event when a scheduled meeting is cancelled.
--
-- Work is leased (next_attempt_at moves forward on claim) so concurrent
-- workers never take the same meeting. Failures retry with backoff; the
-- fifth failure, a provider refusal, or a start time that has passed makes
-- the meeting `failed` and tells its organiser. Recipients are notified in
-- the app without any meeting details in the payload.

alter table public.meetings
  add column processing_attempts integer not null default 0
    check (processing_attempts >= 0),
  add column next_attempt_at timestamptz not null default now(),
  add column provider_cancelled_at timestamptz,
  add column last_error_code text;

create index meetings_processor_due_idx
  on public.meetings (next_attempt_at)
  where state = 'pending'
    or (state = 'cancelled' and calendar_event_id is not null
      and provider_cancelled_at is null);

-- Returns up to p_limit jobs and leases them for five minutes. Each job is
-- either `schedule` (with attendee emails) or `cancel` (with the event id).
create or replace function private.meeting_claim(p_limit integer default 5)
returns jsonb language plpgsql security definer set search_path = '' as $$
declare
  jobs jsonb;
begin
  -- A pending meeting whose start has passed can no longer be scheduled.
  perform private.meeting_fail(m.id, 'MEETING_START_PASSED', true)
  from public.meetings m
  where m.state = 'pending' and m.starts_at <= now();

  with due as (
    select m.id from public.meetings m
    where m.next_attempt_at <= now()
      and (m.state = 'pending'
        or (m.state = 'cancelled' and m.calendar_event_id is not null
          and m.provider_cancelled_at is null))
    order by m.next_attempt_at
    limit greatest(least(p_limit, 50), 1)
    for update skip locked
  ), leased as (
    update public.meetings m
      set next_attempt_at = now() + interval '5 minutes'
      from due where m.id = due.id
      returning m.*
  )
  select coalesce(jsonb_agg(jsonb_build_object(
      'meetingId', l.id,
      'action', case when l.state = 'pending' then 'schedule' else 'cancel' end,
      'title', l.title,
      'startsAt', l.starts_at,
      'endsAt', l.ends_at,
      'calendarEventId', l.calendar_event_id,
      'attendees', case when l.state = 'pending' then coalesce((
        select jsonb_agg(e.email order by e.email)
        from private.meeting_recipient_emails(l.id) e
        where e.email is not null and e.email not like '%@deleted.invalid'
      ), '[]'::jsonb) else '[]'::jsonb end
    )), '[]'::jsonb)
  into jobs
  from leased l;
  return jobs;
end;
$$;

create or replace function private.meeting_finish_schedule(
  p_meeting uuid, p_calendar_event_id text, p_meet_url text
)
returns text language plpgsql security definer set search_path = '' as $$
declare
  m public.meetings%rowtype;
  recipient uuid;
begin
  select * into m from public.meetings where id = p_meeting for update;
  if m.id is null then return 'lost'; end if;
  if m.state = 'scheduled' then return 'scheduled'; end if;
  if m.state = 'cancelled' then
    -- Cancelled while the provider call was in flight: keep the event id so
    -- the cancel path withdraws it.
    update public.meetings
      set calendar_event_id = coalesce(calendar_event_id, p_calendar_event_id),
          next_attempt_at = now()
      where id = m.id;
    return 'cancelled';
  end if;
  if m.state <> 'pending' then return m.state; end if;
  if p_meet_url is not null and p_meet_url !~ '^https://' then
    raise exception using errcode = '22000', message = 'Meeting links must be https';
  end if;

  update public.meetings
    set state = 'scheduled', calendar_event_id = p_calendar_event_id,
        meet_url = p_meet_url, version = version + 1, updated_at = now(),
        last_error_code = null
    where id = m.id;
  update public.meeting_deliveries
    set state = 'sent', delivered_at = now()
    where meeting_id = m.id and state = 'queued';
  for recipient in
    select md.recipient_id from public.meeting_deliveries md
    where md.meeting_id = m.id and md.state = 'sent'
  loop
    perform private.notify_recipient(
      m.school_id, recipient, 'meetings.scheduled',
      jsonb_build_object('meetingId', m.id),
      'meeting:' || m.id, 'meetings.scheduled:' || m.id || ':' || recipient
    );
  end loop;
  insert into public.audit_events(school_id, actor_id, action, entity_type, entity_id, after_value, request_id)
  values (m.school_id, null, 'meeting_scheduled', 'meeting', m.id,
    jsonb_build_object('hasLink', p_meet_url is not null), 'meeting-' || m.id::text);
  return 'scheduled';
end;
$$;

create or replace function private.meeting_fail(p_meeting uuid, p_error_code text, p_terminal boolean)
returns text language plpgsql security definer set search_path = '' as $$
declare
  m public.meetings%rowtype;
  attempts integer;
begin
  select * into m from public.meetings where id = p_meeting for update;
  if m.id is null then return 'lost'; end if;
  attempts := m.processing_attempts + 1;
  if m.state = 'cancelled' then
    -- A failed provider cancel just retries; the meeting is already off.
    update public.meetings
      set processing_attempts = attempts, last_error_code = p_error_code,
          next_attempt_at = now() + make_interval(secs => least(3600, 30 * (2 ^ least(attempts, 7))::integer))
      where id = m.id;
    return 'retry';
  end if;
  if m.state <> 'pending' then return m.state; end if;
  if p_terminal or attempts >= 5 then
    update public.meetings
      set state = 'failed', processing_attempts = attempts,
          last_error_code = p_error_code, version = version + 1, updated_at = now()
      where id = m.id;
    update public.meeting_deliveries
      set state = 'failed', error_code = p_error_code
      where meeting_id = m.id and state = 'queued';
    perform private.notify_recipient(
      m.school_id, m.created_by, 'meetings.failed',
      jsonb_build_object('meetingId', m.id),
      'meeting:' || m.id, 'meetings.failed:' || m.id
    );
    return 'failed';
  end if;
  update public.meetings
    set processing_attempts = attempts, last_error_code = p_error_code,
        next_attempt_at = now() + make_interval(secs => least(3600, 30 * (2 ^ least(attempts, 7))::integer))
    where id = m.id;
  return 'retry';
end;
$$;

create or replace function private.meeting_finish_cancel(p_meeting uuid)
returns text language plpgsql security definer set search_path = '' as $$
begin
  update public.meetings
    set provider_cancelled_at = coalesce(provider_cancelled_at, now())
    where id = p_meeting and state = 'cancelled';
  return case when found then 'withdrawn' else 'lost' end;
end;
$$;

do $grants$
declare fn text;
begin
  foreach fn in array array[
    'private.meeting_claim(integer)',
    'private.meeting_finish_schedule(uuid, text, text)',
    'private.meeting_fail(uuid, text, boolean)',
    'private.meeting_finish_cancel(uuid)'
  ] loop
    execute format('alter function %s owner to postgres', fn);
    execute format('revoke all on function %s from public, anon, authenticated, service_role, studafy_api_runtime, studafy_worker_runtime', fn);
    execute format('grant execute on function %s to studafy_worker_runtime', fn);
  end loop;
end
$grants$;
