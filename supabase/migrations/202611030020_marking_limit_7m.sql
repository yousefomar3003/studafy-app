-- Studafy AI Marking: 7,000,000 tokens a month per teacher (owner,
-- 2026-11-03, DL-075), from 4,000,000. The cost cap beneath it moves from
-- US$2 to US$3: at the model's list price 7M tokens cost at most about
-- US$1.75, so the cap still only bites if the price changes, and stays well
-- inside the plan's US$7.99. Pages per hand-in and attempts are unchanged.
create or replace function private.marking_limits()
returns jsonb language sql immutable set search_path = '' as $$
  select jsonb_build_object(
    'monthlyTokens', 7000000,
    'monthlyCapMicroUsd', 3000000,
    'pagesPerHandIn', 20,
    'handInChars', 60000,
    'maxAttempts', 3);
$$;

alter function private.marking_limits() owner to postgres;
revoke all on function private.marking_limits()
  from public, anon, authenticated, service_role, studafy_api_runtime, studafy_worker_runtime;
