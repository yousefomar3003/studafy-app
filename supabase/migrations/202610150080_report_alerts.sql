-- DPIA D7: safety reports that nobody sees.
--
-- A report filed through createReport is readable only by a school
-- administrator (none exists in this release) or by a platform operator
-- holding a live, two-person-approved moderation grant. Nothing told anyone
-- that a report had arrived. This migration adds:
--
-- 1. An alert queue. Every new report adds one row to private.report_alerts
--    (a trigger, so no code path that files a report can skip it). The
--    worker claims rows, sends a Telegram message carrying only the report
--    id, its kind and priority, and a hash of the school id, and marks them
--    sent (docs/security/safe043-operator-runbook.md). No content, no names,
--    no account ids leave the database.
-- 2. An audited reviewer read for scripts/review-report.ts: a platform
--    operator with an active grant covering the report sees it (reporter
--    masked unless escalated, as in the moderation queue); every attempt,
--    allowed or refused, writes an audit event. Resolutions go through the
--    existing resolveReport command, which is audited already.
--
-- No school administrator path is added: the reviewer read requires a
-- platform operator, whatever school role the caller holds.

create table private.report_alerts (
  report_id uuid primary key references public.reports(id) on delete cascade,
  created_at timestamptz not null default now(),
  attempts integer not null default 0 check (attempts >= 0),
  -- A claim is a lease: another worker may take the row once it lapses.
  claimed_until timestamptz,
  sent_at timestamptz,
  -- A short error code from the sender (never a message body or a URL).
  last_error text check (last_error is null or last_error ~ '^[A-Z0-9_]{1,64}$')
);

create index report_alerts_pending_idx
  on private.report_alerts (created_at)
  where sent_at is null;

create or replace function private.report_alerts_enqueue()
returns trigger language plpgsql security definer set search_path = '' as $$
begin
  insert into private.report_alerts (report_id) values (new.id)
  on conflict (report_id) do nothing;
  return new;
end;
$$;

create trigger reports_alert_on_insert
  after insert on public.reports
  for each row execute function private.report_alerts_enqueue();

-- The school is named by a hash, so the alert channel (a third party)
-- never holds an identifier that resolves to a school. Operators match it
-- with the same expression; the review script prints it.
create or replace function private.report_alert_school_hash(p_school uuid)
returns text language sql immutable set search_path = '' as $$
  select left(encode(extensions.digest(
    'studafy-report-alert:' || p_school::text, 'sha256'), 'hex'), 16);
$$;

-- Claims up to p_limit unsent alerts for p_lease_seconds. Returns only what
-- the alert may carry.
create or replace function private.report_alerts_claim(
  p_limit integer,
  p_lease_seconds integer
)
returns table (
  report_id uuid,
  kind text,
  priority text,
  school_hash text,
  reported_at timestamptz,
  attempts integer
)
language plpgsql security definer set search_path = '' as $$
#variable_conflict use_column
begin
  if p_limit is null or p_limit not between 1 and 100
     or p_lease_seconds is null or p_lease_seconds not between 10 and 3600 then
    raise exception 'REPORT_ALERTS_INVALID_CLAIM';
  end if;
  return query
  with due as (
    select a.report_id
    from private.report_alerts a
    where a.sent_at is null
      and (a.claimed_until is null or a.claimed_until <= now())
    order by a.created_at
    limit p_limit
    for update skip locked
  ), claimed as (
    update private.report_alerts a
    set claimed_until = now() + make_interval(secs => p_lease_seconds),
        attempts = a.attempts + 1
    from due
    where a.report_id = due.report_id
    returning a.report_id, a.attempts
  )
  select c.report_id, r.kind::text, r.priority,
    private.report_alert_school_hash(r.school_id), r.created_at, c.attempts
  from claimed c
  join public.reports r on r.id = c.report_id
  order by r.created_at;
end;
$$;

-- Records the outcome of one send. A failure is retried after a backoff
-- (1, 2, 4 ... minutes, at most 30), indefinitely: a report nobody hears
-- about is the failure this exists to prevent.
create or replace function private.report_alerts_finish(
  p_report uuid,
  p_sent boolean,
  p_error text
)
returns boolean language plpgsql security definer set search_path = '' as $$
declare
  v_attempts integer;
begin
  if p_sent then
    update private.report_alerts
    set sent_at = now(), claimed_until = null, last_error = null
    where report_id = p_report and sent_at is null;
    return found;
  end if;
  update private.report_alerts
  set claimed_until = now() + make_interval(
        mins => least(30, power(2, greatest(attempts - 1, 0))::integer)),
      last_error = case
        when p_error ~ '^[A-Z0-9_]{1,64}$' then p_error else 'SEND_FAILED' end
  where report_id = p_report and sent_at is null
  returning attempts into v_attempts;
  return v_attempts is not null;
end;
$$;

-- Unsent alerts and the oldest one's age, for the queue monitor and the
-- runbook. Counts only.
create or replace function private.report_alerts_backlog()
returns jsonb language sql stable security definer set search_path = '' as $$
  select jsonb_build_object(
    'unsent', count(*),
    'oldestSeconds', coalesce(
      extract(epoch from now() - min(a.created_at))::bigint, 0)
  )
  from private.report_alerts a
  where a.sent_at is null;
$$;

-- The reviewer's read (scripts/review-report.ts). Runs in the caller's
-- identity (request.jwt.claim.sub), like every API dispatcher call.
create or replace function private.report_review_open(p_report uuid)
returns jsonb language plpgsql security definer set search_path = '' as $$
declare
  v_school uuid;
  v_status public.report_status;
  v_allowed boolean;
begin
  if auth.uid() is null or not private.is_platform_operator() then
    return jsonb_build_object('outcome', 'forbidden');
  end if;
  select r.school_id, r.status into v_school, v_status
  from public.reports r where r.id = p_report;
  if v_school is null then
    return jsonb_build_object('outcome', 'not_found');
  end if;
  perform private.lazily_expire_moderation_access(v_school);
  v_allowed := private.safe043_has_active_grant(v_school)
    and private.safe043_can_access_report(v_school, p_report);
  insert into public.audit_events (
    school_id, actor_id, action, entity_type, entity_id, after_value
  ) values (
    v_school, auth.uid(),
    case when v_allowed then 'report_review_opened'
      else 'report_review_refused' end,
    'report', p_report,
    jsonb_build_object('via', 'scripts/review-report.ts')
  );
  if not v_allowed then
    -- The school id (not a name) is what a grant request needs.
    return jsonb_build_object(
      'outcome', 'no_grant',
      'schoolId', v_school,
      'schoolHash', private.report_alert_school_hash(v_school)
    );
  end if;
  return jsonb_build_object(
    'outcome', 'ok',
    'schoolHash', private.report_alert_school_hash(v_school),
    'report', private.safe043_moderation_report_json(
      p_report, v_status = 'escalated')
  );
end;
$$;

-- Reports filed before this migration have never alerted anyone: queue the
-- ones still open so a reviewer sees them once.
insert into private.report_alerts (report_id, created_at)
select r.id, r.created_at
from public.reports r
where r.status not in ('resolved', 'withdrawn')
on conflict (report_id) do nothing;

do $grants$
declare fn text;
begin
  foreach fn in array array[
    'private.report_alerts_enqueue()',
    'private.report_alert_school_hash(uuid)',
    'private.report_alerts_claim(integer, integer)',
    'private.report_alerts_finish(uuid, boolean, text)',
    'private.report_alerts_backlog()',
    'private.report_review_open(uuid)'
  ] loop
    execute format('alter function %s owner to postgres', fn);
    execute format('revoke all on function %s from public, anon, authenticated, service_role, studafy_api_runtime, studafy_worker_runtime', fn);
  end loop;
end
$grants$;

grant execute on function private.report_alerts_claim(integer, integer),
  private.report_alerts_finish(uuid, boolean, text),
  private.report_alerts_backlog()
  to studafy_worker_runtime;

revoke all on table private.report_alerts
  from public, anon, authenticated, service_role, studafy_api_runtime, studafy_worker_runtime;
