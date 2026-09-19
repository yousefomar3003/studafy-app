-- Audit follow-up (2026-09-19): Parent Insights attaches its entitlement to
-- the linked child (ADR-0009), so the purchasing guardian could never read
-- the subscription they paid for. Guardians now see the Parent Insights
-- entitlement of each child they hold a verified, unexpired link to, tagged
-- with that child's student id. Nothing else about a child's entitlements is
-- disclosed, and a revoked or expired link stops the read immediately.
create or replace function private.billing_list_entitlements(p_environment text)
returns jsonb language sql stable security definer set search_path = '' as $$
  select coalesce(jsonb_agg(row_json order by sort_feature, sort_student), '[]'::jsonb)
  from (
    select jsonb_build_object(
        'featureKey', e.feature_key, 'status', e.status,
        'startsAt', e.starts_at, 'endsAt', e.ends_at,
        'beneficiaryStudentId', null
      ) as row_json, e.feature_key as sort_feature, '' as sort_student
    from public.entitlements e
    join public.store_transactions st on st.id = e.source_transaction_id
    where e.user_id = auth.uid() and st.environment = p_environment
    union all
    select jsonb_build_object(
        'featureKey', e.feature_key, 'status', e.status,
        'startsAt', e.starts_at, 'endsAt', e.ends_at,
        'beneficiaryStudentId', s.id
      ), e.feature_key, s.id::text
    from public.guardian_links gl
    join public.students s on s.id = gl.student_id and s.deleted_at is null
    join public.entitlements e on e.user_id = s.user_id
      and e.feature_key = 'parent_insights'
    join public.store_transactions st on st.id = e.source_transaction_id
    where gl.guardian_id = auth.uid() and gl.status = 'verified'
      and (gl.expires_at is null or gl.expires_at > now())
      and st.environment = p_environment
  ) visible
  where private.is_active_user();
$$;
revoke all on function private.billing_list_entitlements(text)
  from public, anon, authenticated, service_role, studafy_worker_runtime;
grant execute on function private.billing_list_entitlements(text) to studafy_api_runtime;
