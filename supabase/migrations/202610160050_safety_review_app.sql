-- The platform operator reviews safety reports in the app (DL-063).
--
-- Until now the only way to read a report was scripts/review-report.ts with
-- the database password. This gives the app the same audited path:
--
-- 1. private.auth_context() also says whether the account is a platform
--    operator, so GET /v1/me can tell the app to offer the review area. It
--    grants nothing: every review route is decided below, by the database.
-- 2. private.safety_review_query, the API's one new entry point:
--    * listSafetyReviewReports: every open report on the platform, as
--      metadata only (id, school id, kind, priority, status, filed at) and
--      whether the caller holds an active grant covering it. No details, no
--      evidence, no names, no account ids. The school id is what a grant is
--      requested for (the review script prints it the same way).
--    * openSafetyReviewReport: one report, exactly as report_review_open
--      gives it to the script: only under an active grant covering it, the
--      reporter masked unless escalated, and every attempt, allowed or
--      refused, written to audit_events (via 'app').
--    Both refuse anyone who is not a platform operator. Grants, triage and
--    resolution keep using the existing moderation commands, which check
--    and audit as before.
--
-- No school administrator path is added: both operations require a
-- platform operator, whatever school role the caller holds.

-- 1. The session context, unchanged but for platform_operator.
create or replace function private.auth_context()
returns jsonb
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  actor uuid := auth.uid();
  result jsonb;
begin
  if actor is null then
    return null;
  end if;

  select jsonb_build_object(
    'user_id', p.id,
    'display_name', p.display_name,
    'locale', p.locale,
    'profile_status', p.status,
    'profile_deleted_at', p.deleted_at,
    'revoked_before', (
      select r.revoked_before
      from public.auth_session_revocations r
      where r.user_id = actor
    ),
    'deletion_state', (
      select d.state
      from public.account_deletion_requests d
      where d.user_id = actor
        and d.state in ('grace_period', 'executing')
      limit 1
    ),
    'memberships', coalesce((
      select jsonb_agg(
        jsonb_build_object(
          'id', m.id,
          'school_id', m.school_id,
          'school_name', s.name,
          'school_timezone', s.timezone,
          'role', m.role,
          'active', m.active,
          'active_term_id', (
            select t.id
            from public.terms t
            where t.school_id = m.school_id
              and t.active
              and t.status = 'active'
            limit 1
          )
        )
        order by s.name, m.role
      )
      from public.memberships m
      join public.schools s on s.id = m.school_id
      where m.user_id = actor
        and m.active
        and m.status = 'active'
        and m.valid_from <= now()
        and (m.valid_until is null or m.valid_until > now())
        and s.status = 'active'
        and s.deleted_at is null
    ), '[]'::jsonb),
    'membership_version', coalesce((
      select encode(
        extensions.digest(
          string_agg(
            m.id::text || ':' || m.status || ':' || m.active::text || ':' ||
            extract(epoch from m.updated_at)::text,
            '|' order by m.id
          ),
          'sha256'
        ),
        'hex'
      )
      from public.memberships m
      where m.user_id = actor
    ), 'none'),
    'mfa_enrolled', exists (
      select 1
      from auth.mfa_factors f
      where f.user_id = actor and f.status = 'verified'
    ),
    'platform_operator', exists (
      select 1
      from public.platform_operators po
      where po.user_id = actor
    )
  )
  into result
  from public.profiles p
  where p.id = actor;

  return result;
end;
$$;

-- 2a. The reviewer's read, for the script and the app alike. The body is
-- report_review_open's (202610150080), with where the read came from and the
-- request id in the audit event.
create function private.safety_review_open(p_report uuid, p_via text)
returns jsonb language plpgsql security definer set search_path = '' as $$
declare
  v_school uuid;
  v_status public.report_status;
  v_allowed boolean;
begin
  if p_via is null or p_via not in ('scripts/review-report.ts', 'app') then
    raise exception 'SAFETY_REVIEW_INVALID_VIA';
  end if;
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
    school_id, actor_id, action, entity_type, entity_id, after_value,
    request_id
  ) values (
    v_school, auth.uid(),
    case when v_allowed then 'report_review_opened'
      else 'report_review_refused' end,
    'report', p_report,
    jsonb_build_object('via', p_via),
    nullif(current_setting('studafy.request_id', true), '')
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

-- The script's entry point, now the shared read.
create or replace function private.report_review_open(p_report uuid)
returns jsonb language sql security definer set search_path = '' as $$
  select private.safety_review_open(p_report, 'scripts/review-report.ts');
$$;

-- 2b. The API's entry point for the review area.
create function private.safety_review_query(
  p_operation text,
  p_resource_id uuid,
  p_input jsonb
)
returns jsonb language plpgsql security definer set search_path = '' as $$
declare
  v_limit integer;
  v_position text := nullif(p_input->>'position', '');
  v_after_rank integer;
  v_after_seq bigint;
  v_items jsonb;
  v_count integer;
  v_last text;
  v_open jsonb;
begin
  if auth.uid() is null or not private.is_platform_operator() then
    return jsonb_build_object('outcome', 'forbidden');
  end if;

  case p_operation
    when 'listSafetyReviewReports' then
      v_limit := least(greatest(
        coalesce((p_input->>'pageSize')::integer, 50), 1), 100);
      -- The cursor position is "<priority rank>:<enqueue_seq>" of the last
      -- row on the previous page; the API signs it, this only parses it.
      if v_position is not null then
        if v_position !~ '^[1-4]:[0-9]{1,18}$' then
          return jsonb_build_object('outcome', 'invalid');
        end if;
        v_after_rank := split_part(v_position, ':', 1)::integer;
        v_after_seq := split_part(v_position, ':', 2)::bigint;
      end if;

      with open_reports as (
        select r.id, r.school_id, r.kind, r.priority, r.status,
          r.created_at, r.enqueue_seq,
          case r.priority when 'critical' then 1 when 'high' then 2
            when 'medium' then 3 else 4 end as rank
        from public.reports r
        where r.status not in ('resolved', 'withdrawn')
      ), page as (
        select o.* from open_reports o
        where v_position is null
          or (o.rank, o.enqueue_seq) > (v_after_rank, v_after_seq)
        order by o.rank, o.enqueue_seq
        limit v_limit
      )
      select
        coalesce(jsonb_agg(jsonb_build_object(
          'id', p.id,
          'schoolId', p.school_id,
          'kind', p.kind,
          'priority', p.priority,
          'status', p.status,
          'createdAt', p.created_at,
          'grantActive', private.safe043_can_access_report(p.school_id, p.id)
        ) order by p.rank, p.enqueue_seq), '[]'::jsonb),
        count(*),
        (array_agg(p.rank::text || ':' || p.enqueue_seq::text
          order by p.rank desc, p.enqueue_seq desc))[1]
      into v_items, v_count, v_last
      from page p;

      return jsonb_build_object(
        'items', v_items,
        'nextPosition', case when v_count = v_limit then v_last end,
        'singleReviewer', private.safety_single_reviewer_mode()
      );

    when 'openSafetyReviewReport' then
      v_open := private.safety_review_open(p_resource_id, 'app');
      if v_open->>'outcome' = 'ok' then
        return v_open->'report';
      end if;
      -- No active grant covering the report (never had one, or it expired
      -- or was revoked): the app asks for one.
      if v_open->>'outcome' = 'no_grant' then
        return jsonb_build_object('outcome', 'forbidden');
      end if;
      return jsonb_build_object(
        'outcome', coalesce(v_open->>'outcome', 'not_found'));

    else
      return jsonb_build_object('outcome', 'not_found');
  end case;
end;
$$;

do $grants$
declare fn text;
begin
  foreach fn in array array[
    'private.safety_review_open(uuid, text)',
    'private.report_review_open(uuid)',
    'private.safety_review_query(text, uuid, jsonb)'
  ] loop
    execute format('alter function %s owner to postgres', fn);
    execute format('revoke all on function %s from public, anon, authenticated, service_role, studafy_api_runtime, studafy_worker_runtime', fn);
  end loop;
end
$grants$;

-- The API reaches the review area through this one function, which refuses
-- anyone who is not a platform operator.
grant execute on function private.safety_review_query(text, uuid, jsonb)
  to studafy_api_runtime;
