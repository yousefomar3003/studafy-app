-- Family+ : paid insights for a guardian about a linked child.
--
-- Two things happen here. An entitlement gate, and one read that collects
-- what a guardian is already permitted to see into a single response.
--
-- The read adds NO new visibility. Every row it returns is one the guardian
-- could already fetch through listGradeResults, listAttendance,
-- listAssignments and listWellbeing; it exists because doing so from the
-- client costs up to twenty sequential round trips, which measured six
-- seconds against a database on another continent. Collecting them here
-- makes the tab one request.
--
-- The entitlement belongs to the CHILD, not the guardian who pays: ADR-0009
-- and private.billing_resolve_beneficiary set beneficiaryId to the student's
-- user id, so the row is entitlements.user_id = <child>. The guardian join
-- below is the same one billing_list_entitlements already uses to let a
-- payer see the subscription they bought.

create or replace function private.parent_insights_has_access(p_student uuid)
returns boolean language sql stable security definer set search_path = '' as $$
  select private.is_active_user() and exists (
    select 1
    from public.guardian_links gl
    join public.students s on s.id = gl.student_id and s.deleted_at is null
    join public.entitlements e on e.user_id = s.user_id
      and e.feature_key = 'parent_insights'
    join public.store_transactions st on st.id = e.source_transaction_id
    join private.notebook_runtime runtime on runtime.singleton
    where gl.guardian_id = auth.uid()
      and gl.student_id = p_student
      and gl.status = 'verified'
      and (gl.expires_at is null or gl.expires_at > now())
      -- Live subscription, live window. grace_period is included so a failed
      -- card renewal does not cut a parent off the same hour.
      and e.status in ('active', 'grace_period')
      and e.starts_at <= now() and e.ends_at > now()
      -- A sandbox receipt must never unlock production, and the environment
      -- is read from the server's own single-row table rather than from
      -- anything the request carried.
      and st.environment = runtime.environment
  );
$$;

alter function private.parent_insights_has_access(uuid) owner to postgres;
revoke all on function private.parent_insights_has_access(uuid)
  from public, anon, authenticated, service_role, studafy_worker_runtime;
grant execute on function private.parent_insights_has_access(uuid)
  to studafy_api_runtime;

-- ---------------------------------------------------------------------------
-- getFamilyInsights
-- ---------------------------------------------------------------------------

alter function private.api042_query(text, uuid, jsonb)
  rename to api042_query_pre_family_insights;

create or replace function private.api042_query(
  p_operation text,
  p_resource_id uuid,
  p_input jsonb
)
returns jsonb
language plpgsql
stable
security definer
set search_path to ''
as $function$
declare
  v_actor uuid := auth.uid();
  v_student uuid;
  v_from timestamptz;
  v_to timestamptz := now();
  v_period text;
  v_name text;
begin
  if p_operation <> 'getFamilyInsights' then
    return private.api042_query_pre_family_insights(
      p_operation, p_resource_id, p_input);
  end if;

  v_student := nullif(p_input->>'studentId', '')::uuid;
  if v_actor is null or v_student is null then
    return jsonb_build_object('outcome', 'forbidden');
  end if;

  -- The paywall is enforced here, not in the client. A guardian without a
  -- live entitlement is refused the data itself, so a modified app cannot
  -- read a child's record for free.
  if not private.parent_insights_has_access(v_student) then
    return jsonb_build_object('outcome', 'forbidden');
  end if;

  select s.display_name into v_name
  from public.students s where s.id = v_student and s.deleted_at is null;
  if v_name is null then
    return jsonb_build_object('outcome', 'not_found');
  end if;

  v_period := coalesce(p_input->>'period', 'term');
  v_from := case v_period
    when 'last30' then v_to - interval '30 days'
    when 'year' then v_to - interval '1 year'
    else v_to - interval '120 days'
  end;

  return jsonb_build_object(
    'outcome', 'ok',
    'studentId', v_student,
    'studentName', v_name,
    'period', v_period,
    'from', v_from,
    'to', v_to,
    -- Published marks only: an unpublished mark is a teacher's draft, and a
    -- parent seeing one before the school releases it would be a leak.
    'grades', coalesce((
      select jsonb_agg(jsonb_build_object(
        'subject', coalesce(nullif(a.category, ''), a.title),
        'score', g.score,
        'maximumScore', a.maximum_score,
        'at', g.published_at
      ) order by g.published_at)
      from public.grade_results g
      join public.assessments a on a.id = g.assessment_id
      where g.student_id = v_student
        and g.state = 'published' and g.published_at is not null
        and g.published_at between v_from and v_to
        and a.maximum_score > 0 and g.score is not null
    ), '[]'::jsonb),
    'attendance', coalesce((
      select jsonb_agg(jsonb_build_object(
        'state', r.state, 'at', ls.starts_at
      ) order by ls.starts_at)
      from public.attendance_records r
      join public.lesson_sessions ls on ls.id = r.session_id
      where r.student_id = v_student
        and ls.starts_at between v_from and v_to
    ), '[]'::jsonb),
    -- Work set to a class this child is enrolled in, with what they did
    -- about it. Published only, for the same reason as marks.
    'homework', coalesce((
      select jsonb_agg(jsonb_build_object(
        'assignmentId', a.id,
        'title', a.title,
        'dueAt', a.due_at,
        'submittedAt', sub.submitted_at
      ) order by a.due_at)
      from public.assignments a
      join public.enrollments e on e.classroom_id = a.classroom_id
        and e.student_id = v_student and e.active and e.status = 'active'
      left join public.submissions sub on sub.assignment_id = a.id
        and sub.student_id = v_student
      where a.state = 'published' and a.deleted_at is null
        and a.due_at between v_from and v_to + interval '30 days'
    ), '[]'::jsonb),
    -- Only what the school chose to share with guardians. A note restricted
    -- to safeguarding staff is never returned, at any subscription level.
    'wellbeing', coalesce((
      select jsonb_agg(jsonb_build_object(
        'id', w.id, 'kind', w.kind, 'title', w.title, 'createdAt', w.created_at
      ) order by w.created_at desc)
      from public.wellbeing_events w
      where w.student_id = v_student
        and w.visibility in ('guardian_shared', 'student_guardian_shared')
        and w.created_at between v_from and v_to
    ), '[]'::jsonb)
  );
end;
$function$;

alter function private.api042_query(text, uuid, jsonb) owner to postgres;
alter function private.api042_query_pre_family_insights(text, uuid, jsonb)
  owner to postgres;
revoke all on function private.api042_query(text, uuid, jsonb)
  from public, anon, authenticated, service_role, studafy_worker_runtime;
-- The previous generation loses runtime execute as well, so the ungated
-- function cannot be reached around the gate above.
revoke all on function private.api042_query_pre_family_insights(text, uuid, jsonb)
  from public, anon, authenticated, service_role, studafy_worker_runtime,
       studafy_api_runtime;
grant execute on function private.api042_query(text, uuid, jsonb)
  to studafy_api_runtime;

-- ---------------------------------------------------------------------------
-- Lift the storefront hold on the parent product.
-- ---------------------------------------------------------------------------
--
-- 202609180005 listed parent_insights in synthetic only, pending the
-- ADR-0009/§29 sign-off. The repository owner has taken that decision, so
-- the product becomes buyable in the other environments. Without this,
-- _insightsProductOrThrow() refuses and no purchase can complete.
update public.store_products
set storefront_listed = true, updated_at = now()
where feature_key = 'parent_insights' and not storefront_listed;
