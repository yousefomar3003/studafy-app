-- AI marking, after the readiness checks (2026-11-03).
--
-- 1. The suggestions list shows a hand-in's suggestion only for the
--    student's latest attempt: one they replaced was still counted as
--    "ready" beside the current one. api059_query re-issued whole from
--    202611020010 with only that filter added.
--
-- 2. The AI-marking queue in the worker's queue alerts.
--
--    marking_jobs_backlog (202610210060) said how many suggestions wait and for
-- how long; the queue monitor also needs how many failed, so a run of
-- failures (the provider down, a key revoked) alerts like the notebook
-- queue's dead letters do. Same signature; grants restated.
create or replace function private.marking_jobs_backlog()
returns jsonb language sql stable security definer set search_path = '' as $$
  select jsonb_build_object(
    'pending', count(*) filter (where status = 'pending'),
    'oldestSeconds', coalesce(extract(epoch from now() - min(created_at)
      filter (where status = 'pending'))::bigint, 0),
    'failed', count(*) filter (where status = 'failed'))
  from private.marking_suggestions;
$$;

alter function private.marking_jobs_backlog() owner to postgres;
revoke all on function private.marking_jobs_backlog()
  from public, anon, authenticated, service_role, studafy_api_runtime, studafy_worker_runtime;
grant execute on function private.marking_jobs_backlog() to studafy_worker_runtime;

create or replace function private.api059_query(
  p_operation text, p_resource_id uuid, p_input jsonb)
returns jsonb language plpgsql stable security definer set search_path = '' as $$
declare
  v_assessment jsonb;
  v_settings jsonb;
  v_used jsonb;
  v_limits jsonb := private.marking_limits();
begin
  if auth.uid() is null or not private.is_active_user() then
    return jsonb_build_object('outcome', 'forbidden');
  end if;
  case p_operation
    when 'plan' then
      v_used := private.marking_month_used(auth.uid());
      return jsonb_build_object('outcome', 'ok',
        'active', private.marking_plan_active(auth.uid()),
        -- Given by Studafy with no store subscription behind it: nothing to
        -- manage, cancel or restore in a store.
        'granted', exists (
            select 1 from private.marking_plan_grants g
            where g.user_id = auth.uid() and g.starts_at <= now() and g.ends_at > now())
          and not exists (
            select 1 from public.entitlements e
            join public.store_transactions st on st.id = e.source_transaction_id
            join private.notebook_runtime runtime on runtime.singleton
            where e.user_id = auth.uid() and e.feature_key = 'studafy_ai_marking'
              and e.status in ('active', 'grace_period')
              and e.starts_at <= now() and (e.ends_at is null or e.ends_at > now())
              and st.environment = runtime.environment),
        'teacher', private.account_kind(auth.uid()) = 'adult'
          and exists (select 1 from public.memberships m
            where m.user_id = auth.uid() and m.role = 'teacher'
              and m.active and m.status = 'active'),
        'allowance', jsonb_build_object(
          'total', (v_limits->>'monthlyTokens')::bigint,
          'used', least((v_used->>'tokens')::bigint, (v_limits->>'monthlyTokens')::bigint),
          'resetsAt', (date_trunc('month', now() at time zone 'utc')
            + interval '1 month') at time zone 'utc'));

    when 'references' then
      v_assessment := private.marking_assessment(p_resource_id);
      if v_assessment is null then return jsonb_build_object('outcome', 'not_found'); end if;
      return jsonb_build_object('outcome', 'ok',
        'delivery', v_assessment->>'delivery',
        'settings', private.marking_settings_json(p_resource_id),
        'references', private.marking_references_json(p_resource_id));

    when 'suggestions' then
      v_assessment := private.marking_assessment(p_resource_id);
      if v_assessment is null then return jsonb_build_object('outcome', 'not_found'); end if;
      v_settings := private.marking_settings_json(p_resource_id);
      return jsonb_build_object('outcome', 'ok',
        'settings', v_settings,
        'items', (
          select coalesce(jsonb_agg(jsonb_build_object(
              'id', s.id, 'studentId', s.student_id,
              'attemptId', s.attempt_id, 'questionId', s.question_id,
              'submissionAttemptId', s.submission_attempt_id,
              'status', s.status, 'maximumScore', s.maximum_score,
              'suggestedScore', s.suggested_score,
              'met', s.met, 'missed', s.missed,
              'rationale', s.rationale, 'feedback', s.feedback,
              'conflict', s.conflict, 'reviewReason', s.review_reason,
              'reason', s.reason,
              'referenceVersion', s.reference_version,
              'strictness', s.strictness,
              'stale', s.reference_version < (v_settings->>'referenceVersion')::int,
              'createdAt', s.created_at, 'updatedAt', s.updated_at)
            order by s.created_at desc, s.id), '[]'::jsonb)
          from private.marking_suggestions s
          where s.assessment_id = p_resource_id
            and s.status in ('pending', 'ready', 'failed', 'skipped')
            -- A hand-in: only the student's latest attempt. An earlier one
            -- they replaced is no longer what the teacher marks.
            and (s.submission_attempt_id is null or s.submission_attempt_id = (
              select sub.current_attempt_id from public.submissions sub
              join public.assessments a on a.id = s.assessment_id
              where sub.assignment_id = a.assignment_id
                and sub.student_id = s.student_id))
          ));

    when 'preference' then
      return jsonb_build_object('outcome', 'ok',
        'optedOut', exists (select 1 from private.marking_opt_outs o
          where o.user_id = auth.uid()));

    else
      return jsonb_build_object('outcome', 'invalid');
  end case;
exception when invalid_text_representation then
  return jsonb_build_object('outcome', 'not_found');
end;
$$;

alter function private.api059_query(text, uuid, jsonb) owner to postgres;
revoke all on function private.api059_query(text, uuid, jsonb)
  from public, anon, authenticated, service_role, studafy_api_runtime, studafy_worker_runtime;
grant execute on function private.api059_query(text, uuid, jsonb) to studafy_api_runtime;
