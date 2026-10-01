-- Family+ becomes the parent's plan, sized by how many children it covers.
--
-- Until now Family+ (feature `parent_insights`) was bought per child and held
-- by the child. Parents asked for one price for the family instead:
--
--   * `family_plus`        - up to 4 linked children, one monthly price;
--   * `family_plus_large`  - up to 8 linked children, a higher monthly price.
--
-- Prices are the store's (App Store Connect / Play Console), never stored
-- here; the product ids below are what the stores list. Both products belong
-- in ONE subscription group (App Store) / one subscription with two base
-- plans or two subscriptions the app replaces (Play), so moving from 4 to 8
-- is an upgrade of the same subscription, never a second charge.
--
-- Who is covered. The entitlement is held by the guardian who pays
-- (beneficiary = purchaser). Coverage is decided when it is read, not stored:
-- a guardian's verified links to live students, ordered by when each link
-- was verified, and the first 4 (or 8) are covered. Nothing is copied per
-- child, so a link added or revoked takes effect on the next read, and no
-- job has to keep a coverage table in step. The ordering uses only the
-- guardian's own links (a handful of rows through
-- db020_guardian_links_guardian_verified), so the check stays a few index
-- lookups however many families there are.
--
-- A per-child `parent_insights` subscription bought before this change keeps
-- working until it ends: it is taken off sale (storefront_listed = false)
-- in every real store environment but stays active, so its renewals and
-- restores still verify.

-- ---------------------------------------------------------------------------
-- Catalogue
-- ---------------------------------------------------------------------------

-- Listed for sale only in `synthetic` and `development`, like the student
-- plans: staging and production are listed by a later migration once both
-- store consoles carry the products (docs/deployment/subscriptions.md §6).
insert into public.store_products (
  feature_key, platform, environment, store_product_id, active, storefront_listed
)
select f.feature_key, p.platform::public.store_platform, e.environment,
  f.store_product_id, true, e.environment in ('synthetic', 'development')
from (values
  ('family_plus', 'studafy_family_plus_monthly'),
  ('family_plus_large', 'studafy_family_plus_8_monthly')
) as f(feature_key, store_product_id)
cross join (values ('app_store'), ('play_store')) as p(platform)
cross join (values ('synthetic'), ('development'), ('staging'), ('production'))
  as e(environment)
on conflict (platform, environment, store_product_id) do nothing;

-- `synthetic` is the test-only environment; the per-child product stays
-- listed there so the ledger suites keep exercising its lineage rules.
update public.store_products
set storefront_listed = false, updated_at = now()
where feature_key = 'parent_insights' and storefront_listed
  and environment <> 'synthetic';

-- ---------------------------------------------------------------------------
-- Purchase: the guardian is the beneficiary
-- ---------------------------------------------------------------------------

create or replace function private.billing_resolve_beneficiary(p_purchaser uuid, p_feature_key text, p_beneficiary_student_id uuid, p_parental_gate_confirmed boolean)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
declare
  student_row public.students%rowtype;
  guardian_link uuid;
  purchaser_school uuid;
begin
  if p_feature_key = 'teacher_ai_grading' then
    if p_beneficiary_student_id is not null then
      return jsonb_build_object('ok', false, 'outcome', 'invalid_beneficiary');
    end if;
    if not exists (
      select 1 from public.memberships m
      where m.user_id = p_purchaser and m.role = 'teacher'
        and m.active and m.status = 'active'
        and m.valid_from <= now() and (m.valid_until is null or m.valid_until > now())
    ) then
      return jsonb_build_object('ok', false, 'outcome', 'not_eligible');
    end if;
    return jsonb_build_object(
      'ok', true, 'beneficiaryId', p_purchaser, 'guardianLinkId', null
    );
  end if;

  -- Family+ is the parent's own plan, covering their linked children up to
  -- the plan's size. It is held by the guardian who pays, so no child is
  -- named at purchase; only somebody who is already a verified guardian of
  -- at least one child may buy it.
  if p_feature_key in ('family_plus', 'family_plus_large') then
    if p_beneficiary_student_id is not null then
      return jsonb_build_object('ok', false, 'outcome', 'invalid_beneficiary');
    end if;
    if not exists (
      select 1 from public.guardian_links gl
      join public.students s on s.id = gl.student_id and s.deleted_at is null
      where gl.guardian_id = p_purchaser and gl.status = 'verified'
        and (gl.expires_at is null or gl.expires_at > now())
    ) then
      return jsonb_build_object('ok', false, 'outcome', 'not_eligible');
    end if;
    return jsonb_build_object(
      'ok', true, 'beneficiaryId', p_purchaser, 'guardianLinkId', null
    );
  end if;

  if p_feature_key = 'parent_insights' and p_beneficiary_student_id is null then
    return jsonb_build_object('ok', false, 'outcome', 'beneficiary_required');
  end if;

  if p_beneficiary_student_id is not null then
    select * into student_row from public.students
    where id = p_beneficiary_student_id and deleted_at is null;
    if student_row.id is null then
      return jsonb_build_object('ok', false, 'outcome', 'beneficiary_link_invalid');
    end if;
    select gl.id into guardian_link
      from public.guardian_links gl
      where gl.student_id = student_row.id
        and gl.guardian_id = p_purchaser
        and gl.status = 'verified'
        and (gl.expires_at is null or gl.expires_at > now())
      limit 1;
    if guardian_link is null then
      return jsonb_build_object('ok', false, 'outcome', 'beneficiary_link_invalid');
    end if;
    return jsonb_build_object(
      'ok', true, 'beneficiaryId', student_row.user_id, 'guardianLinkId', guardian_link
    );
  end if;

  -- Self-purchase: only student_notebook/student_ai reach here (the two
  -- branches above already returned for teacher_ai_grading/parent_insights).
  select st.* into student_row from public.students st
  where st.user_id = p_purchaser and st.deleted_at is null;
  if student_row.id is null then
    return jsonb_build_object('ok', false, 'outcome', 'not_eligible');
  end if;
  if not p_parental_gate_confirmed then
    return jsonb_build_object('ok', false, 'outcome', 'parental_gate_required');
  end if;
  select m.school_id into purchaser_school from public.memberships m
  where m.user_id = p_purchaser and m.role = 'student'
    and m.active and m.status = 'active'
    and m.valid_from <= now() and (m.valid_until is null or m.valid_until > now())
  limit 1;
  if purchaser_school is null or not coalesce(
    (select s.self_purchase_enabled from public.school_billing_settings s
      where s.school_id = purchaser_school),
    false
  ) then
    return jsonb_build_object('ok', false, 'outcome', 'student_purchase_disabled');
  end if;
  return jsonb_build_object(
    'ok', true, 'beneficiaryId', p_purchaser, 'guardianLinkId', null
  );
end;
$function$;

alter function private.billing_resolve_beneficiary(uuid, text, uuid, boolean)
  owner to postgres;
revoke all on function private.billing_resolve_beneficiary(uuid, text, uuid, boolean)
  from public, anon, authenticated, service_role, studafy_worker_runtime,
       studafy_api_runtime;

-- ---------------------------------------------------------------------------
-- Coverage
-- ---------------------------------------------------------------------------

-- How many children the guardian's own live Family+ plan covers: 8, 4 or 0.
-- Same liveness rules as every other entitlement read: active or in a
-- payment grace period, inside its window, and bought in this server's own
-- store environment (a sandbox receipt never unlocks production).
create or replace function private.family_plus_seats(p_guardian uuid)
returns integer
language sql
stable
security definer
set search_path = ''
as $$
  select coalesce(max(case e.feature_key
      when 'family_plus_large' then 8
      when 'family_plus' then 4
    end), 0)::integer
  from public.entitlements e
  join public.store_transactions st on st.id = e.source_transaction_id
  join private.notebook_runtime runtime on runtime.singleton
  where e.user_id = p_guardian
    and e.feature_key in ('family_plus', 'family_plus_large')
    and e.status in ('active', 'grace_period')
    and e.starts_at <= now() and e.ends_at > now()
    and st.environment = runtime.environment;
$$;

-- The guardian's children that the plan covers, first-linked first. The
-- order is stable (verified_at, then link id) so the same children stay
-- covered from one read to the next.
create or replace function private.family_plus_covered(p_guardian uuid)
returns table (student_id uuid)
language sql
stable
security definer
set search_path = ''
as $$
  select linked.student_id
  from (
    select gl.student_id,
      row_number() over (order by gl.verified_at, gl.id) as position
    from public.guardian_links gl
    join public.students s on s.id = gl.student_id and s.deleted_at is null
    where gl.guardian_id = p_guardian
      and gl.status = 'verified'
      and (gl.expires_at is null or gl.expires_at > now())
  ) linked
  where linked.position <= private.family_plus_seats(p_guardian);
$$;

create or replace function private.parent_insights_has_access(p_student uuid)
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select private.is_active_user() and (
    -- The parent's own Family+ plan, when this child is one it covers.
    exists (
      select 1 from private.family_plus_covered(auth.uid()) covered
      where covered.student_id = p_student
    )
    -- A per-child subscription bought before Family+ became a family plan.
    or exists (
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
        and e.status in ('active', 'grace_period')
        and e.starts_at <= now() and e.ends_at > now()
        and st.environment = runtime.environment
    )
  );
$$;

do $$
declare
  fn text;
begin
  foreach fn in array array[
    'private.family_plus_seats(uuid)',
    'private.family_plus_covered(uuid)',
    'private.parent_insights_has_access(uuid)'
  ] loop
    execute format('alter function %s owner to postgres', fn);
    execute format(
      'revoke all on function %s from public, anon, authenticated, '
      'service_role, studafy_worker_runtime', fn);
  end loop;
end;
$$;
-- The gate is evaluated by the API; the two helpers only through it.
grant execute on function private.parent_insights_has_access(uuid)
  to studafy_api_runtime;
revoke all on function private.family_plus_seats(uuid) from studafy_api_runtime;
revoke all on function private.family_plus_covered(uuid) from studafy_api_runtime;

-- ---------------------------------------------------------------------------
-- What the app is told: the plan, and which children it covers
-- ---------------------------------------------------------------------------

create or replace function private.billing_list_entitlements(p_environment text)
returns jsonb
language sql
stable
security definer
set search_path = ''
as $$
  select coalesce(jsonb_agg(row_json order by sort_feature, sort_student), '[]'::jsonb)
  from (
    select jsonb_build_object(
        'featureKey', e.feature_key, 'status', e.status,
        'startsAt', e.starts_at, 'endsAt', e.ends_at,
        'beneficiaryStudentId', null,
        'renewalStatus', st.renewal_status,
        'platform', st.platform,
        'storeProductId', sp.store_product_id,
        'purchasedByMe', st.purchaser_id = auth.uid()
      ) || case when e.feature_key in ('family_plus', 'family_plus_large')
        then jsonb_build_object(
          'coveredStudentIds', coalesce((
            select jsonb_agg(covered.student_id)
            from private.family_plus_covered(auth.uid()) covered
          ), '[]'::jsonb))
        else '{}'::jsonb end
        as row_json,
      e.feature_key as sort_feature, '' as sort_student
    from public.entitlements e
    join public.store_transactions st on st.id = e.source_transaction_id
    join public.store_products sp on sp.id = st.product_id
    where e.user_id = auth.uid() and st.environment = p_environment
    union all
    select jsonb_build_object(
        'featureKey', e.feature_key, 'status', e.status,
        'startsAt', e.starts_at, 'endsAt', e.ends_at,
        'beneficiaryStudentId', s.id,
        'renewalStatus', st.renewal_status,
        'platform', st.platform,
        'storeProductId', sp.store_product_id,
        'purchasedByMe', st.purchaser_id = auth.uid()
      ), e.feature_key, s.id::text
    from public.guardian_links gl
    join public.students s on s.id = gl.student_id and s.deleted_at is null
    join public.entitlements e on e.user_id = s.user_id
      and e.feature_key = 'parent_insights'
    join public.store_transactions st on st.id = e.source_transaction_id
    join public.store_products sp on sp.id = st.product_id
    where gl.guardian_id = auth.uid() and gl.status = 'verified'
      and (gl.expires_at is null or gl.expires_at > now())
      and st.environment = p_environment
  ) visible
  where private.is_active_user();
$$;

alter function private.billing_list_entitlements(text) owner to postgres;
revoke all on function private.billing_list_entitlements(text)
  from public, anon, authenticated, service_role, studafy_worker_runtime;
grant execute on function private.billing_list_entitlements(text)
  to studafy_api_runtime;

-- ---------------------------------------------------------------------------
-- Subscription notices reach the parent for the family plans too
-- ---------------------------------------------------------------------------

create or replace function private.billing_notify_entitlement_change()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
declare
  kind text;
  payer uuid;
  school uuid;
begin
  if new.feature_key not in (
    'studafy_plus', 'studafy_max', 'parent_insights',
    'family_plus', 'family_plus_large'
  ) then
    return null;
  end if;

  kind := case
    when new.status = 'active' and (tg_op = 'INSERT'
        or old.status not in ('active', 'grace_period'))
      then 'billing.subscription_active'
    when tg_op = 'UPDATE' and new.status = 'active' and old.status = 'active'
        and new.ends_at > coalesce(old.ends_at, '-infinity'::timestamptz) + interval '1 day'
      then 'billing.subscription_renewed'
    when tg_op = 'UPDATE' and new.status in ('grace_period', 'on_hold')
        and old.status = 'active'
      then 'billing.payment_problem'
    when tg_op = 'UPDATE' and new.status in ('expired', 'revoked')
        and old.status in ('active', 'grace_period', 'on_hold')
      then 'billing.subscription_ended'
  end;
  if kind is null then return null; end if;

  select st.purchaser_id into payer from public.store_transactions st
  where st.id = new.source_transaction_id;
  if payer is null then return null; end if;

  -- Notifications are held per school. The beneficiary's school first (a
  -- guardian's purchase is for a child's), then any school of the payer's,
  -- then - for a family plan held by the parent - a linked child's school.
  select s.school_id into school from public.students s
  where s.user_id = new.user_id and s.deleted_at is null
  order by s.created_at limit 1;
  if school is null then
    select m.school_id into school from public.memberships m
    where m.user_id = payer and m.active
    order by m.created_at limit 1;
  end if;
  if school is null then
    select gl.school_id into school from public.guardian_links gl
    where gl.guardian_id = payer and gl.status = 'verified'
    order by gl.verified_at, gl.id limit 1;
  end if;
  if school is null then return null; end if;

  perform private.notify_recipient(
    school, payer, kind,
    jsonb_build_object('featureKey', new.feature_key, 'endsAt', new.ends_at),
    'entitlement:' || new.id,
    kind || ':' || new.id || ':' || new.version
  );
  return null;
end;
$$;

alter function private.billing_notify_entitlement_change() owner to postgres;
revoke all on function private.billing_notify_entitlement_change()
  from public, anon, authenticated, service_role, studafy_worker_runtime,
       studafy_api_runtime;

-- ---------------------------------------------------------------------------
-- getFamilyInsights: what the richer Family+ screen is built from
-- ---------------------------------------------------------------------------
--
-- Same gate and the same visibility as before - published marks only, the
-- guardian-shared wellbeing notes only - with three changes:
--
--   * Marks are grouped by CLASS (a class is a subject here), and a paper
--     exam the child missed (mark = 'absent') is returned as such, so the
--     parent sees it rather than a gap. `not_graded` rows are left out: the
--     teacher chose not to mark them, so they say nothing about the child.
--   * Attendance is counted in SQL, per class, state and school-local
--     weekday, instead of one row per lesson. A year of registers was over a
--     thousand rows per request; the counts are at most a few dozen, which
--     keeps this read cheap however busy the service gets.
--     `attendance` stays in the answer, empty, for an API still reading it.
--   * Each list is bounded, newest first, so no child's history can make the
--     response unbounded.
--
-- Every sub-select starts from the child's own rows through an existing
-- index (db020_grade_results_student_published, db020_attendance_student_timeline,
-- db020_enrollments_student_active + db020_assignments_class_due).

create or replace function private.ops_query_family_insights(
  p_operation text,
  p_resource_id uuid,
  p_input jsonb
)
returns jsonb
language plpgsql
stable
security definer
set search_path = ''
as $function$
declare
  v_actor uuid := auth.uid();
  v_student uuid;
  v_from timestamptz;
  v_to timestamptz := now();
  v_period text;
  v_name text;
  v_zone text;
begin
  v_student := nullif(p_input->>'studentId', '')::uuid;
  if v_actor is null or v_student is null then
    return jsonb_build_object('outcome', 'forbidden');
  end if;

  -- The paywall is enforced here, not in the client. A guardian without a
  -- live plan covering this child is refused the data itself, so a modified
  -- app cannot read a child's record for free.
  if not private.parent_insights_has_access(v_student) then
    return jsonb_build_object('outcome', 'forbidden');
  end if;

  select s.display_name, coalesce(sch.timezone, 'UTC') into v_name, v_zone
  from public.students s
  left join public.schools sch on sch.id = s.school_id
  where s.id = v_student and s.deleted_at is null;
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
    -- The classes the child is in now, so a class with nothing marked yet
    -- still has a line of its own.
    'classes', coalesce((
      select jsonb_agg(jsonb_build_object(
        'classroomId', c.id, 'className', c.name) order by c.name, c.id)
      from public.enrollments e
      join public.classrooms c on c.id = e.classroom_id
      where e.student_id = v_student and e.active and e.status = 'active'
        and c.archived_at is null
    ), '[]'::jsonb),
    -- Published marks only: an unpublished mark is a teacher's draft, and a
    -- parent seeing one before the school releases it would be a leak.
    'grades', coalesce((
      select jsonb_agg(row_json order by at)
      from (
        select g.published_at as at, jsonb_build_object(
          'subject', c.name,
          'classroomId', c.id,
          'className', c.name,
          'title', a.title,
          'delivery', a.delivery,
          'mark', coalesce(g.mark::text, 'scored'),
          'score', g.score,
          'maximumScore', a.maximum_score,
          'at', g.published_at
        ) as row_json
        from public.grade_results g
        join public.assessments a on a.id = g.assessment_id
        join public.classrooms c on c.id = a.classroom_id
        where g.student_id = v_student
          and g.state = 'published' and g.published_at is not null
          and g.published_at between v_from and v_to
          and a.maximum_score > 0
          and (
            (g.score is not null and coalesce(g.mark::text, 'scored') = 'scored')
            or g.mark::text = 'absent'
          )
        order by g.published_at desc
        limit 500
      ) latest
    ), '[]'::jsonb),
    'attendance', '[]'::jsonb,
    'attendanceCounts', coalesce((
      select jsonb_agg(jsonb_build_object(
        'classroomId', counted.classroom_id,
        'className', counted.class_name,
        'state', counted.state,
        'weekday', counted.weekday,
        'count', counted.total
      ))
      from (
        select c.id as classroom_id, c.name as class_name, r.state,
          extract(dow from ls.starts_at at time zone v_zone)::int as weekday,
          count(*) as total
        from public.attendance_records r
        join public.lesson_sessions ls on ls.id = r.session_id
        join public.classrooms c on c.id = ls.classroom_id
        where r.student_id = v_student
          and ls.starts_at between v_from and v_to
        group by 1, 2, 3, 4
      ) counted
    ), '[]'::jsonb),
    -- Work set to a class this child is enrolled in, with what they did
    -- about it. Published only, for the same reason as marks.
    'homework', coalesce((
      select jsonb_agg(row_json order by due)
      from (
        select a.due_at as due, jsonb_build_object(
          'assignmentId', a.id,
          'title', a.title,
          'classroomId', c.id,
          'className', c.name,
          'dueAt', a.due_at,
          'submittedAt', sub.submitted_at
        ) as row_json
        from public.enrollments e
        join public.classrooms c on c.id = e.classroom_id
        join public.assignments a on a.classroom_id = e.classroom_id
        left join public.submissions sub on sub.assignment_id = a.id
          and sub.student_id = v_student
        where e.student_id = v_student and e.active and e.status = 'active'
          and a.state = 'published' and a.deleted_at is null
          and a.due_at between v_from and v_to + interval '30 days'
        order by a.due_at desc
        limit 400
      ) latest
    ), '[]'::jsonb),
    -- Only what the school chose to share with guardians. A note restricted
    -- to safeguarding staff is never returned, at any subscription level.
    'wellbeing', coalesce((
      select jsonb_agg(row_json order by created desc)
      from (
        select w.created_at as created, jsonb_build_object(
          'id', w.id, 'kind', w.kind, 'title', w.title,
          'createdAt', w.created_at
        ) as row_json
        from public.wellbeing_events w
        where w.student_id = v_student
          and w.visibility in ('guardian_shared', 'student_guardian_shared')
          and w.created_at between v_from and v_to
        order by w.created_at desc
        limit 20
      ) latest
    ), '[]'::jsonb)
  );
end;
$function$;

alter function private.ops_query_family_insights(text, uuid, jsonb)
  owner to postgres;
revoke all on function private.ops_query_family_insights(text, uuid, jsonb)
  from public, anon, authenticated, service_role, studafy_worker_runtime,
       studafy_api_runtime;
