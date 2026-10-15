-- AI study tools: students in a class only, and a separate, versioned AI
-- consent (ADR-0043; draft DPIA §12 D2, D3, D4).
--
-- Privacy policy 1.4 says the AI study tools are for students (§6), that
-- children use Studafy only through a school (§5), and that their lawful
-- basis is consent (§4). The code did not match: any signed-in account -
-- a parent, a teacher, an account with no class - could ask the helper, and
-- the only consent recorded was the bundled terms_and_privacy one. This
-- migration makes the database decide both, on every AI call:
--
--   * private.ai_access(user) is 'ok' only for a student account with at
--     least one active enrollment in an active class, managed child
--     accounts included, that holds a current AI consent. Otherwise it says
--     why: 'not_student', 'no_class', 'consent_required', or
--     'guardian_consent_required' for a managed child account, whose parent
--     consents for them (ADR-0031).
--   * The AI consent is a consent_records row with purpose 'ai_features',
--     recorded only against the published notice (consent_policies, version
--     2026-10-15, the SHA-256 of the exact in-app notice in each language).
--     It names who gave it (given_by, given_as 'self' or 'guardian') and who
--     withdrew it. Every give and withdrawal is also written to
--     auth_security_events as 'consent_recorded', which keeps the history
--     after a withdrawal and a later consent overwrite the row. Being a
--     consent record, it is in the data export, counted on the deletion
--     screen and kept for the life of the account and 6 years after, like
--     every other consent (DL-057); nothing new to purge.
--   * A consent is current when it is for the newest published 'ai_features'
--     notice and not withdrawn. Publishing a new notice version asks every
--     student again.
--   * record_policy_consent no longer accepts 'ai_features': a managed child
--     could otherwise consent for themselves through the PostgREST RPC. The
--     only way to record it is private.api057_ai_consent, through the API.
--   * private.api047_ai_usage refuses to reserve tokens for any AI call when
--     ai_access is not 'ok' - the backstop under the API's own check, so no
--     route can reach the provider without it - and its summary says the
--     caller's access, so the app hides what it cannot use.
--   * private.authz_notebook refuses 'study_set.generate' to anyone who is
--     not a student in a class, so the SQL authorization catalogue says the
--     same as the API (a teacher or parent can see a lesson, and could
--     generate a study set from it before).
--   * private.ai_known_names(user) lists the names the student can see -
--     their own, classmates' and teachers' in their active classes, and
--     their parents' - so the API can replace them before any model call
--     (DPIA D1).
--
-- TODO(legal): counsel to confirm who gives the AI consent for a student
-- aged 13-17 who signs in themselves (today: the student), and the age
-- below which a parent must (DPIA Q-F, GDPR Art. 8, DL-037). Studafy holds
-- no age today, so only managed child accounts get a parent's consent.
-- TODO(legal): counsel to confirm the notice text (lib/l10n app_en.arb and
-- app_ar.arb, aiConsentNoticeBody) before AI is switched on for real
-- students; changing it means a new consent version here.
--
-- create or replace with the same signatures (ADR-0030); owners and grants
-- are restated at the end.

-- ---------------------------------------------------------------------------
-- 1. Who gave a consent, and who withdrew it.
-- ---------------------------------------------------------------------------
alter table public.consent_records
  add column given_by uuid references public.profiles(id) on delete set null,
  add column given_as text check (given_as in ('self', 'guardian')),
  add column withdrawn_by uuid references public.profiles(id) on delete set null;

comment on column public.consent_records.given_by is
  'Who gave this consent: the person, or the parent who manages their account (ADR-0043). Null for consents recorded before 2026-10-15.';
comment on column public.consent_records.given_as is
  '''self'' or ''guardian'' (a parent for a managed child account). Null for consents recorded before 2026-10-15.';

create index consent_records_given_by_idx on public.consent_records (given_by)
  where given_by is not null;
create index consent_records_withdrawn_by_idx on public.consent_records (withdrawn_by)
  where withdrawn_by is not null;

-- ---------------------------------------------------------------------------
-- 2. The AI notice, version 2026-10-15. content_hash is the SHA-256 of the
--    exact in-app text (aiConsentNoticeBody) in that language;
--    lib/core/ai_consent.dart moves to this version with it.
-- ---------------------------------------------------------------------------
insert into public.consent_policies (
  purpose, policy_version, locale, title, content_hash,
  published_at, effective_at
)
values
  ('ai_features', '2026-10-15', 'en', 'Studafy AI study tools',
    '537aff6fa6a3dd27ef14547399c99990554275977ae24d62e9ac75ff65977602', now(), now()),
  ('ai_features', '2026-10-15', 'ar', 'أدوات الدراسة بالذكاء الاصطناعي في ستودافاي',
    '988f44e07583f1967be2583f1eeef9209c1b21a3942d1d1f9cbf3884639259c6', now(), now())
on conflict (purpose, policy_version, locale) do nothing;

-- ---------------------------------------------------------------------------
-- 3. Terms only through the public RPC. Otherwise unchanged from
--    202609130005.
-- ---------------------------------------------------------------------------
create or replace function public.record_policy_consent(
  requested_purpose text,
  requested_version text,
  requested_locale text default 'en'
)
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  caller uuid := auth.uid();
  matched_policy uuid;
begin
  if caller is null then
    raise exception using
      errcode = '42501',
      message = 'Authentication required';
  end if;
  if not private.is_active_user() then
    raise exception using
      errcode = '42501',
      message = 'Active account required';
  end if;
  -- The AI consent is recorded only through private.api057_ai_consent,
  -- which knows who may give it (ADR-0043).
  if requested_purpose is null
     or requested_purpose not in ('terms_and_privacy') then
    raise exception using
      errcode = '22023',
      message = 'Unsupported consent purpose';
  end if;
  if requested_locale is null or requested_locale not in ('en', 'ar') then
    raise exception using
      errcode = '22023',
      message = 'Unsupported locale';
  end if;
  if requested_version is null
     or requested_version <> btrim(requested_version)
     or char_length(requested_version) not between 1 and 128 then
    raise exception using
      errcode = '22023',
      message = 'Invalid policy version';
  end if;

  select p.id into matched_policy
  from public.consent_policies p
  where p.purpose = requested_purpose
    and p.policy_version = requested_version
    and p.locale = requested_locale
    and p.published_at <= now()
    and p.effective_at <= now()
    and (p.retired_at is null or p.retired_at > now());

  if matched_policy is null then
    raise exception using
      errcode = '22023',
      message = 'Unsupported consent policy version';
  end if;

  insert into public.consent_records (
    user_id, purpose, policy_version, locale, accepted_at, withdrawn_at,
    policy_id, given_by, given_as, withdrawn_by
  ) values (
    caller,
    requested_purpose,
    requested_version,
    requested_locale,
    now(),
    null,
    matched_policy,
    caller,
    'self',
    null
  )
  on conflict (user_id, purpose, policy_version)
  do update set
    locale = excluded.locale,
    accepted_at = excluded.accepted_at,
    withdrawn_at = null,
    withdrawn_by = null,
    policy_id = excluded.policy_id,
    given_by = excluded.given_by,
    given_as = excluded.given_as;
end;
$$;

-- ---------------------------------------------------------------------------
-- 4. Who may use the AI study tools.
-- ---------------------------------------------------------------------------

-- The AI notice a consent must be for now: the newest published one.
create or replace function private.ai_consent_version()
returns text language sql stable security definer set search_path = '' as $$
  select p.policy_version from public.consent_policies p
  where p.purpose = 'ai_features'
    and p.published_at <= now() and p.effective_at <= now()
    and (p.retired_at is null or p.retired_at > now())
  order by p.effective_at desc, p.policy_version desc
  limit 1;
$$;

-- A student account with at least one active enrollment in an active class.
-- A managed child account is a student account like any other.
create or replace function private.ai_enrolled_student(p_user uuid)
returns boolean language sql stable security definer set search_path = '' as $$
  select coalesce(private.account_kind(p_user) = 'student', false) and exists (
    select 1
    from public.students st
    join public.enrollments e
      on e.student_id = st.id and e.school_id = st.school_id
    join public.classrooms c
      on c.id = e.classroom_id and c.school_id = e.school_id
    join public.schools s on s.id = c.school_id
    where st.user_id = p_user and st.deleted_at is null
      and e.active and e.status = 'active'
      and c.status = 'active' and s.status = 'active');
$$;

-- The current AI consent, or null.
create or replace function private.ai_current_consent(p_user uuid)
returns jsonb language sql stable security definer set search_path = '' as $$
  select jsonb_build_object(
    'version', r.policy_version, 'locale', r.locale,
    'givenAt', r.accepted_at, 'givenAs', coalesce(r.given_as, 'self'))
  from public.consent_records r
  where r.user_id = p_user and r.purpose = 'ai_features'
    and r.policy_version = private.ai_consent_version()
    and r.withdrawn_at is null;
$$;

create or replace function private.ai_access(p_user uuid)
returns text language sql stable security definer set search_path = '' as $$
  select case
    -- A parent or a teacher, or no account at all.
    when p_user is null
      or not exists (select 1 from public.profiles p
        where p.id = p_user and p.deleted_at is null and p.status = 'active')
      or private.account_kind(p_user) = 'adult'
      then 'not_student'
    -- Not in a class: no class, no AI (privacy policy §5).
    when not private.ai_enrolled_student(p_user) then 'no_class'
    when private.ai_current_consent(p_user) is not null then 'ok'
    when exists (select 1 from private.managed_accounts m where m.child_id = p_user)
      then 'guardian_consent_required'
    else 'consent_required'
  end;
$$;

-- The names a student can see in Studafy, for the API to replace before any
-- model call (DPIA D1). Their own; the classmates and teachers of their
-- active classes; their parents (linked, or managing their account). One
-- row per distinct name, the closest relation first.
create or replace function private.ai_known_names(p_user uuid)
returns jsonb language sql stable security definer set search_path = '' as $$
  with mine as (
    select st.id, st.display_name from public.students st
    where st.user_id = p_user and st.deleted_at is null
  ), classes as (
    select distinct e.classroom_id from public.enrollments e
    join mine on mine.id = e.student_id
    where e.active and e.status = 'active'
  ), named as (
    select p.display_name as name, 'self' as kind, 0 as rank
      from public.profiles p where p.id = p_user and p.deleted_at is null
    union all
    select mine.display_name, 'self', 0 from mine
    union all
    select p.display_name, 'parent', 1
      from public.guardian_links g
      join mine on mine.id = g.student_id
      join public.profiles p on p.id = g.guardian_id
      where g.status in ('pending', 'verified') and p.deleted_at is null
    union all
    select p.display_name, 'parent', 1
      from private.managed_accounts m
      join public.profiles p on p.id = m.guardian_id
      where m.child_id = p_user and p.deleted_at is null
    union all
    select p.display_name, 'teacher', 2
      from public.classroom_staff cs
      join classes on classes.classroom_id = cs.classroom_id
      join public.profiles p on p.id = cs.user_id
      where cs.status = 'active' and p.deleted_at is null
    union all
    select p.display_name, 'teacher', 2
      from public.classrooms c
      join classes on classes.classroom_id = c.id
      join public.profiles p on p.id = c.teacher_id
      where p.deleted_at is null
    union all
    select st.display_name, 'classmate', 3
      from public.enrollments e
      join classes on classes.classroom_id = e.classroom_id
      join public.students st on st.id = e.student_id
      where st.deleted_at is null and st.user_id is distinct from p_user
    union all
    select p.display_name, 'classmate', 3
      from public.enrollments e
      join classes on classes.classroom_id = e.classroom_id
      join public.students st on st.id = e.student_id
      join public.profiles p on p.id = st.user_id
      where st.deleted_at is null and p.id <> p_user and p.deleted_at is null
  ), distinct_names as (
    select distinct on (lower(btrim(n.name))) btrim(n.name) as name, n.kind, n.rank
    from named n
    where n.name is not null and char_length(btrim(n.name)) between 2 and 120
      -- What account deletion writes in place of a name is not a name.
      and n.name not in ('Deleted student', 'Deleted user', 'Deleted account')
    order by lower(btrim(n.name)), n.rank
  )
  select coalesce(jsonb_agg(jsonb_build_object('name', d.name, 'kind', d.kind)
    order by d.rank, d.name), '[]'::jsonb)
  from (select * from distinct_names order by rank limit 5000) d;
$$;

-- ---------------------------------------------------------------------------
-- 5. The API's one entry point for AI access and consent.
--
--   status          the caller's access, the current notice, their consent
--   names           the names to replace in what the caller sends the AI
--   give            the caller consents (not a managed child: their parent)
--   withdraw        the caller withdraws
--   child_status    the same, for a child account the caller manages
--   child_give      the caller consents for that child
--   child_withdraw  the caller withdraws for that child
--
-- Every operation re-derives the caller from auth.uid(). A child operation
-- answers not_found unless the caller manages that child, and a managed
-- account can manage nobody.
-- ---------------------------------------------------------------------------
create or replace function private.api057_ai_consent(p_operation text, p_input jsonb)
returns jsonb language plpgsql security definer set search_path = '' as $$
declare
  v_caller uuid := auth.uid();
  v_subject uuid;
  v_as text;
  v_version text := private.ai_consent_version();
  v_locale text := p_input->>'locale';
  v_policy uuid;
  v_access text;
  v_changed boolean;
begin
  if v_caller is null or not private.is_active_user() then
    return jsonb_build_object('outcome', 'forbidden');
  end if;

  if p_operation in ('child_status', 'child_give', 'child_withdraw') then
    v_subject := (p_input->>'childId')::uuid;
    if v_subject is null
       or exists (select 1 from private.managed_accounts m where m.child_id = v_caller)
       or not exists (select 1 from private.managed_accounts m
         join public.profiles p on p.id = m.child_id
         where m.child_id = v_subject and m.guardian_id = v_caller
           and p.deleted_at is null) then
      return jsonb_build_object('outcome', 'not_found');
    end if;
    v_as := 'guardian';
  elsif p_operation in ('status', 'names', 'give', 'withdraw') then
    v_subject := v_caller;
    v_as := 'self';
  else
    return jsonb_build_object('outcome', 'invalid');
  end if;

  if p_operation = 'names' then
    return jsonb_build_object('outcome', 'ok',
      'names', private.ai_known_names(v_subject));
  end if;

  if p_operation in ('give', 'child_give') then
    v_access := private.ai_access(v_subject);
    if v_access = 'not_student' then
      return jsonb_build_object('outcome', 'not_student');
    end if;
    -- A managed child's parent consents for them.
    if v_as = 'self' and exists (
        select 1 from private.managed_accounts m where m.child_id = v_subject) then
      return jsonb_build_object('outcome', 'guardian_consent_required');
    end if;
    -- Only to the notice the app showed: the current one, in the language
    -- it was shown in.
    if v_version is null or p_input->>'version' is distinct from v_version
       or v_locale is null or v_locale not in ('en', 'ar') then
      return jsonb_build_object('outcome', 'stale_version');
    end if;
    select p.id into v_policy from public.consent_policies p
    where p.purpose = 'ai_features' and p.policy_version = v_version
      and p.locale = v_locale;
    if v_policy is null then
      return jsonb_build_object('outcome', 'stale_version');
    end if;
    insert into public.consent_records (
      user_id, purpose, policy_version, locale, accepted_at, withdrawn_at,
      policy_id, given_by, given_as, withdrawn_by)
    values (v_subject, 'ai_features', v_version, v_locale, now(), null,
      v_policy, v_caller, v_as, null)
    on conflict (user_id, purpose, policy_version) do update set
      locale = excluded.locale, accepted_at = excluded.accepted_at,
      withdrawn_at = null, withdrawn_by = null, policy_id = excluded.policy_id,
      given_by = excluded.given_by, given_as = excluded.given_as;
    insert into public.auth_security_events (
      actor_id, event_type, outcome, reason_code)
    values (v_subject, 'consent_recorded', 'allowed',
      case when v_as = 'guardian' then 'ai_features_given_by_guardian'
        else 'ai_features_given' end);
  elsif p_operation in ('withdraw', 'child_withdraw') then
    -- Anyone who could give it may withdraw it, and a managed child may
    -- withdraw their own: turning AI off is never harder than turning it on.
    update public.consent_records r
      set withdrawn_at = now(), withdrawn_by = v_caller
      where r.user_id = v_subject and r.purpose = 'ai_features'
        and r.withdrawn_at is null;
    v_changed := found;
    if v_changed then
      insert into public.auth_security_events (
        actor_id, event_type, outcome, reason_code)
      values (v_subject, 'consent_recorded', 'allowed',
        case when v_as = 'guardian' then 'ai_features_withdrawn_by_guardian'
          else 'ai_features_withdrawn' end);
    end if;
  end if;

  return jsonb_build_object(
    'outcome', 'ok',
    'access', private.ai_access(v_subject),
    'version', v_version,
    'consent', private.ai_current_consent(v_subject));
exception when invalid_text_representation then
  return jsonb_build_object('outcome', 'not_found');
end;
$$;

-- ---------------------------------------------------------------------------
-- 6. The AI ledger checks access before it holds a single token, and its
--    summary says the caller's access. Otherwise unchanged from
--    202610070001.
-- ---------------------------------------------------------------------------
create or replace function private.api047_ai_usage(p_operation text, p_input jsonb)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
declare
  v_user uuid := auth.uid();
  v_month date := date_trunc('month', now() at time zone 'utc')::date;
  v_plan text;
  v_limits jsonb;
  v_feature text := p_input->>'feature';
  v_estimate bigint;
  v_tokens bigint;
  v_key text := nullif(p_input->>'requestKey', '');
  v_allowance jsonb;
  v_prior private.ai_usage%rowtype;
  v_replay boolean := false;
  v_row private.ai_usage%rowtype;
  v_metered bigint;
  v_id uuid;
  v_access text;
begin
  if v_user is null or not private.is_active_user() then
    return jsonb_build_object('outcome', 'forbidden');
  end if;

  case p_operation
    when 'summary' then
      v_plan := private.study_plan(v_user);
      v_limits := private.ai_plan_limits(v_plan);
      return jsonb_build_object(
        'outcome', 'ok',
        'plan', v_plan,
        'features', v_limits->'features',
        'allowance', private.ai_allowance_json(v_user, v_plan),
        'capMicroUsd', (v_limits->>'capMicroUsd')::bigint,
        'committedMicroUsd', private.ai_month_committed(v_user, v_month),
        -- What the caller may use (ADR-0043): the app hides what it cannot.
        'access', private.ai_access(v_user));

    when 'reserve' then
      v_estimate := (p_input->>'estimateMicroUsd')::bigint;
      v_tokens := (p_input->>'estimateTokens')::bigint;
      if v_feature is null or v_estimate is null or v_estimate < 0
        or v_estimate > 100000 or v_tokens is null or v_tokens <= 0
        or v_tokens > 400000 or length(coalesce(v_key, '')) > 120 then
        return jsonb_build_object('outcome', 'invalid');
      end if;
      -- Students in a class, with a current AI consent, only (ADR-0043).
      -- Every AI call holds tokens here first, so nothing reaches the
      -- provider for anyone else, whatever route it came from.
      v_access := private.ai_access(v_user);
      if v_access <> 'ok' then
        return jsonb_build_object('outcome', v_access);
      end if;
      -- One student's reservations are serialised, so two requests at once
      -- cannot both pass a check that only one of them fits.
      perform pg_advisory_xact_lock(hashtextextended('ai-usage:' || v_user::text, 0));

      v_plan := private.study_plan(v_user);
      v_limits := private.ai_plan_limits(v_plan);
      if not (v_limits->'features') ? v_feature then
        return jsonb_build_object('outcome', 'plan_required', 'plan', v_plan);
      end if;

      -- The same request again. Still running: refused, it would be charged
      -- twice. Already answered: answered again, free, once. Failed: tried
      -- again as new.
      if v_key is not null then
        select * into v_prior from private.ai_usage u
        where u.user_id = v_user and u.request_key = v_key;
        if v_prior.id is not null then
          if v_prior.status = 'reserved'
             and v_prior.created_at > now() - interval '15 minutes' then
            return jsonb_build_object('outcome', 'in_progress');
          elsif v_prior.status = 'settled' then
            if exists (select 1 from private.ai_usage u
                where u.user_id = v_user and u.request_key = v_key || ':replay') then
              return jsonb_build_object('outcome', 'duplicate');
            end if;
            v_key := v_key || ':replay';
            v_replay := true;
          else
            update private.ai_usage set request_key = null where id = v_prior.id;
          end if;
        end if;
      end if;

      if not v_replay then
        v_allowance := private.ai_allowance_json(v_user, v_plan);
        if (v_allowance->>'remaining')::bigint < v_tokens then
          return jsonb_build_object('outcome', 'allowance_exhausted',
            'plan', v_plan, 'allowance', v_allowance);
        end if;
        -- The dollar cap stays underneath the tokens on paid plans.
        if v_plan <> 'free' and private.ai_month_committed(v_user, v_month)
             + v_estimate > (v_limits->>'capMicroUsd')::bigint then
          return jsonb_build_object('outcome', 'monthly_cap', 'plan', v_plan,
            'allowance', v_allowance);
        end if;
      end if;

      insert into private.ai_usage(user_id, feature, plan, month,
        reserved_micro_usd, reserved_tokens, request_key, replay)
      values (v_user, v_feature, v_plan, v_month,
        case when v_replay then 0 else v_estimate end,
        case when v_replay then 0 else v_tokens end, v_key, v_replay)
      returning id into v_id;
      return jsonb_build_object('outcome', 'ok', 'usageId', v_id,
        'plan', v_plan, 'replay', v_replay);

    when 'settle' then
      select * into v_row from private.ai_usage u
      where u.id = (p_input->>'usageId')::uuid and u.user_id = v_user
        and u.status = 'reserved'
      for update;
      if v_row.id is null then return jsonb_build_object('outcome', 'not_found'); end if;
      v_metered := case when v_row.replay then 0 else private.ai_metered_tokens(
        left(p_input->>'model', 120), (p_input->>'inputTokens')::int,
        (p_input->>'outputTokens')::int) end;
      -- No token counts from the provider: charge what was held.
      if p_input->>'inputTokens' is null and not v_row.replay then
        v_metered := v_row.reserved_tokens;
      end if;
      update private.ai_usage u set
        status = 'settled',
        cost_micro_usd = case when v_row.replay then 0
          else greatest(0, (p_input->>'costMicroUsd')::bigint) end,
        metered_tokens = v_metered,
        input_tokens = nullif(p_input->>'inputTokens', '')::int,
        output_tokens = nullif(p_input->>'outputTokens', '')::int,
        model = left(p_input->>'model', 120),
        settled_at = now()
      where u.id = v_row.id;
      return jsonb_build_object('outcome', 'ok', 'meteredTokens', v_metered,
        'allowance', private.ai_allowance_json(v_user, v_row.plan));

    when 'release' then
      update private.ai_usage u set status = 'released', settled_at = now()
      where u.id = (p_input->>'usageId')::uuid and u.user_id = v_user
        and u.status = 'reserved';
      return jsonb_build_object('outcome', case when found then 'ok' else 'not_found' end);

    else
      return jsonb_build_object('outcome', 'invalid');
  end case;
exception when invalid_text_representation or numeric_value_out_of_range then
  return jsonb_build_object('outcome', 'invalid');
end;
$function$;

-- ---------------------------------------------------------------------------
-- 7. Study sets from a lesson: students in a class only. Otherwise
--    unchanged from 202610070005.
-- ---------------------------------------------------------------------------
create or replace function private.authz_notebook(p_action text, p_resource_id uuid)
 RETURNS jsonb
 LANGUAGE plpgsql
 STABLE SECURITY DEFINER
 SET search_path TO ''
AS $function$
declare
  sid uuid;
  allowed boolean := false;
begin
  if auth.uid() is null or p_resource_id is null then
    return jsonb_build_object('allowed', false, 'school_id', null, 'reason', 'invalid_resource');
  end if;
  if p_action in ('notebook.read', 'notebook.write') then
    select c.school_id, private.notebook_student(c.id) is not null
      into sid, allowed
    from public.classrooms c where c.id = p_resource_id;
  elsif p_action = 'notebook_entry.delete' then
    select n.school_id, n.owner_id = auth.uid() into sid, allowed
    from public.notebook_entries n
    where n.id = p_resource_id and n.deleted_at is null;
  else
    -- The plan is checked where the money is spent; this asks only whether
    -- the lesson is one the caller can see.
    -- Study sets are an AI study tool: students in a class only
    -- (ADR-0043). A teacher or parent can see the lesson, but not this.
    select r.school_id, private.study_lesson(r.id) is not null
        and private.ai_enrolled_student(auth.uid())
      into sid, allowed
    from public.resources r where r.id = p_resource_id;
  end if;
  return jsonb_build_object('allowed', coalesce(allowed, false), 'school_id', sid,
    'reason', case when sid is null then 'invalid_resource'
      when coalesce(allowed, false) then 'allowed' else 'denied' end);
end;
$function$;

-- ---------------------------------------------------------------------------
-- 8. Owners and grants. The API calls the dispatcher and the ledger; the
--    helpers are reached only through them.
-- ---------------------------------------------------------------------------
do $grants$
declare fn text;
begin
  foreach fn in array array[
    'private.ai_consent_version()',
    'private.ai_enrolled_student(uuid)',
    'private.ai_current_consent(uuid)',
    'private.ai_access(uuid)',
    'private.ai_known_names(uuid)',
    'private.api057_ai_consent(text, jsonb)',
    'private.api047_ai_usage(text, jsonb)',
    'private.authz_notebook(text, uuid)'
  ] loop
    execute format('alter function %s owner to postgres', fn);
    execute format('revoke all on function %s from public, anon, authenticated, service_role, studafy_api_runtime, studafy_worker_runtime', fn);
  end loop;
end
$grants$;

grant execute on function private.api057_ai_consent(text, jsonb),
  private.api047_ai_usage(text, jsonb)
  to studafy_api_runtime;

alter function public.record_policy_consent(text, text, text)
  owner to postgres;
revoke all on function public.record_policy_consent(text, text, text)
  from public, anon, authenticated, service_role;
grant execute on function public.record_policy_consent(text, text, text)
  to authenticated;
