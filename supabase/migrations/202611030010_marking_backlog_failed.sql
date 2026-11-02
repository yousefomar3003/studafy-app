-- The AI-marking queue in the worker's queue alerts (2026-11-03).
--
-- marking_jobs_backlog (202610210060) said how many suggestions wait and for
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
