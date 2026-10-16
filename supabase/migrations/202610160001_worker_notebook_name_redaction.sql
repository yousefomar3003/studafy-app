-- Names out of the notebooks the worker writes (ADR-0043 DPIA D1, ADR-0038;
-- 2026-10-16).
--
-- Study notebooks are written by the worker's notebook queue
-- (202610160000), not in the API. Every AI call the API makes replaces the
-- names the student can see before anything is sent - their own, their
-- classmates' and teachers' in their active classes, their parents' - with
-- "[student]", "[classmate]", "[teacher]" or "[parent]", reading them through
-- private.api057_ai_consent('names') (202610150060). That function is the
-- API's and derives the person from auth.uid(); the worker has no request
-- of its own.
--
-- private.notebook_job_names gives the worker the same list,
-- private.ai_known_names, for the owner of the notebook job it holds now and
-- for nothing else: like the queue's other calls it names the claim (worker,
-- job, attempt), and answers lease_lost to a worker that no longer holds it.
-- The worker replaces the names with the API's own code before the model
-- call, and sends nothing when they cannot be read.
--
-- Whether the owner may still use AI is not asked here: the AI ledger
-- (api047 'reserve', reached through private.notebook_job_usage) refuses an
-- owner without access before any token is held, and the notebook fails with
-- that reason.
--
-- A new function (ADR-0030: nothing renamed or wrapped). Owned by postgres,
-- executable by the worker's role only.

create or replace function private.notebook_job_names(
  p_worker text, p_job uuid, p_attempt integer)
returns jsonb language plpgsql stable security definer set search_path = '' as $$
declare
  h record;
begin
  select * into h from private.notebook_job_held(p_worker, p_job, p_attempt);
  if h.job_id is null then
    return jsonb_build_object('outcome', 'lease_lost');
  end if;
  return jsonb_build_object('outcome', 'ok',
    'names', private.ai_known_names(h.owner_id));
end;
$$;

alter function private.notebook_job_names(text, uuid, integer) owner to postgres;
revoke all on function private.notebook_job_names(text, uuid, integer)
  from public, anon, authenticated, service_role, studafy_api_runtime,
    studafy_worker_runtime;
grant execute on function private.notebook_job_names(text, uuid, integer)
  to studafy_worker_runtime;
