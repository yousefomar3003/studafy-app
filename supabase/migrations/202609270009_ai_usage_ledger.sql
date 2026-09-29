-- What each student's AI use costs, and the caps that bound it.
--
-- Studafy Plus is $3.99 and Studafy Max $5.99 a month. The owner's rule is
-- that AI spend on one student never exceeds $0.80 a month on Plus or $1.60
-- on Max. That is enforced here, in money, from the provider's own token
-- counts - not estimated from a request count, which would let one long
-- request cost as much as a hundred short ones.
--
-- Every provider call is bracketed:
--
--   reserve  - before the call. The worst-case cost of the call (its input
--              bound plus its max_tokens, at the model's prices) is held
--              against the month. Refused if the plan does not include the
--              feature, or if spent + held + this would pass the cap. Taken
--              under a per-student lock, so two simultaneous requests cannot
--              both squeeze under the cap.
--   settle   - after. The hold is replaced by the actual cost the provider
--              reported.
--   release  - if the call failed and nothing was spent.
--
-- A hold that is never settled (a crashed request) stops counting after 15
-- minutes, so it cannot lock a student out.
--
-- Free students get the question box only, limited per day by count; Plus
-- and Max get a higher daily allowance, and every paid call counts toward the
-- monthly cap.

create table if not exists private.ai_usage (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references public.profiles(id) on delete cascade,
  feature text not null check (feature in ('ask', 'whiteboard', 'quiz', 'flashcards')),
  plan text not null check (plan in ('free', 'plus', 'max')),
  -- The calendar month (UTC) the cost belongs to. A cap resets on the 1st.
  month date not null,
  status text not null default 'reserved'
    check (status in ('reserved', 'settled', 'released')),
  reserved_micro_usd bigint not null check (reserved_micro_usd >= 0),
  cost_micro_usd bigint not null default 0 check (cost_micro_usd >= 0),
  input_tokens integer check (input_tokens >= 0),
  output_tokens integer check (output_tokens >= 0),
  model text,
  created_at timestamptz not null default now(),
  settled_at timestamptz
);

create index if not exists ai_usage_user_month_idx
  on private.ai_usage (user_id, month);
create index if not exists ai_usage_user_day_idx
  on private.ai_usage (user_id, feature, created_at);

revoke all on private.ai_usage
  from public, anon, authenticated, service_role, studafy_api_runtime,
  studafy_worker_runtime;

-- The caps, in millionths of a dollar. One place, so a price change is a
-- migration a reviewer sees rather than a constant in application code.
create or replace function private.ai_plan_limits(p_plan text)
returns jsonb language sql immutable set search_path = '' as $$
  select case p_plan
    when 'max' then jsonb_build_object(
      'capMicroUsd', 1600000, 'askPerDay', 60,
      'features', jsonb_build_array('ask', 'whiteboard', 'quiz', 'flashcards'))
    when 'plus' then jsonb_build_object(
      'capMicroUsd', 800000, 'askPerDay', 40,
      'features', jsonb_build_array('ask', 'whiteboard'))
    else jsonb_build_object(
      'capMicroUsd', 0, 'askPerDay', 10,
      'features', jsonb_build_array('ask'))
  end;
$$;

revoke all on function private.ai_plan_limits(text)
  from public, anon, authenticated, service_role, studafy_worker_runtime,
  studafy_api_runtime;
alter function private.ai_plan_limits(text) owner to postgres;

-- Spent plus live holds, this month.
create or replace function private.ai_month_committed(p_user uuid, p_month date)
returns bigint language sql stable security definer set search_path = '' as $$
  select coalesce(sum(case
      when u.status = 'settled' then u.cost_micro_usd
      when u.status = 'reserved' and u.created_at > now() - interval '15 minutes'
        then u.reserved_micro_usd
      else 0 end), 0)::bigint
  from private.ai_usage u
  where u.user_id = p_user and u.month = p_month;
$$;

revoke all on function private.ai_month_committed(uuid, date)
  from public, anon, authenticated, service_role, studafy_worker_runtime,
  studafy_api_runtime;
alter function private.ai_month_committed(uuid, date) owner to postgres;

create or replace function private.api047_ai_usage(p_operation text, p_input jsonb)
returns jsonb language plpgsql security definer set search_path = '' as $$
declare
  v_user uuid := auth.uid();
  v_month date := date_trunc('month', now() at time zone 'utc')::date;
  v_plan text;
  v_limits jsonb;
  v_feature text := p_input->>'feature';
  v_estimate bigint;
  v_committed bigint;
  v_today integer;
  v_id uuid;
begin
  if v_user is null or not private.is_active_user() then
    return jsonb_build_object('outcome', 'forbidden');
  end if;

  case p_operation
    when 'summary' then
      v_plan := private.study_plan(v_user);
      v_limits := private.ai_plan_limits(v_plan);
      select count(*) into v_today from private.ai_usage u
      where u.user_id = v_user and u.feature = 'ask' and u.status <> 'released'
        and u.created_at >= date_trunc('day', now());
      return jsonb_build_object(
        'outcome', 'ok',
        'plan', v_plan,
        'features', v_limits->'features',
        'capMicroUsd', (v_limits->>'capMicroUsd')::bigint,
        'committedMicroUsd', private.ai_month_committed(v_user, v_month),
        'askToday', v_today,
        'askPerDay', (v_limits->>'askPerDay')::int,
        'resetsAt', (v_month + interval '1 month')::timestamptz);

    when 'reserve' then
      v_estimate := (p_input->>'estimateMicroUsd')::bigint;
      if v_feature is null or v_estimate is null or v_estimate < 0
        or v_estimate > 100000 then
        -- No single call may be allowed to hold more than ten cents.
        return jsonb_build_object('outcome', 'invalid');
      end if;
      -- One student's reservations are serialised, so two requests at once
      -- cannot both pass a check that only one of them fits.
      perform pg_advisory_xact_lock(hashtextextended('ai-usage:' || v_user::text, 0));

      v_plan := private.study_plan(v_user);
      v_limits := private.ai_plan_limits(v_plan);
      if not (v_limits->'features') ? v_feature then
        return jsonb_build_object('outcome', 'plan_required', 'plan', v_plan);
      end if;

      if v_feature = 'ask' then
        select count(*) into v_today from private.ai_usage u
        where u.user_id = v_user and u.feature = 'ask' and u.status <> 'released'
          and u.created_at >= date_trunc('day', now());
        if v_today >= (v_limits->>'askPerDay')::int then
          return jsonb_build_object('outcome', 'daily_limit', 'plan', v_plan);
        end if;
      end if;

      -- The money cap applies to paid plans. A free question is bounded by
      -- the daily count instead, and costs a fraction of a cent.
      if v_plan <> 'free' then
        v_committed := private.ai_month_committed(v_user, v_month);
        if v_committed + v_estimate > (v_limits->>'capMicroUsd')::bigint then
          return jsonb_build_object('outcome', 'monthly_cap', 'plan', v_plan,
            'resetsAt', (v_month + interval '1 month')::timestamptz);
        end if;
      end if;

      insert into private.ai_usage(user_id, feature, plan, month, reserved_micro_usd)
      values (v_user, v_feature, v_plan, v_month, v_estimate)
      returning id into v_id;
      return jsonb_build_object('outcome', 'ok', 'usageId', v_id, 'plan', v_plan);

    when 'settle' then
      update private.ai_usage u set
        status = 'settled',
        cost_micro_usd = greatest(0, (p_input->>'costMicroUsd')::bigint),
        input_tokens = nullif(p_input->>'inputTokens', '')::int,
        output_tokens = nullif(p_input->>'outputTokens', '')::int,
        model = left(p_input->>'model', 120),
        settled_at = now()
      where u.id = (p_input->>'usageId')::uuid and u.user_id = v_user
        and u.status = 'reserved';
      return jsonb_build_object('outcome', case when found then 'ok' else 'not_found' end);

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
$$;

revoke all on function private.api047_ai_usage(text, jsonb)
  from public, anon, authenticated, service_role, studafy_worker_runtime;
grant execute on function private.api047_ai_usage(text, jsonb) to studafy_api_runtime;
alter function private.api047_ai_usage(text, jsonb) owner to postgres;
