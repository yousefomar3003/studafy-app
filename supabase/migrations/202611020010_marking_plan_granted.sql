-- Studafy AI Marking: say when the plan was given by Studafy (2026-11-02).
--
-- A teacher holding a comp grant (private.marking_plan_grants) and no store
-- subscription was shown the store's "Manage or cancel" and "Restore
-- purchases", as if they had bought it. The plan read now carries
-- `granted`, like Family+ (202610190010), and the app says "Given by
-- Studafy, nothing to pay" instead. api059_query is re-issued whole from
-- 202610210060 with only that field added to 'plan'.

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
