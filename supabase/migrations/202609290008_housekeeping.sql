-- Expired idempotency records are removed (2026-09-29).
--
-- Every write through the API reserves an idempotency record so a retried
-- request is answered once. A record past expires_at already counts as
-- absent - the reserve path deletes it when its key is reused - but nothing
-- removed the rest, so the table grew by one row per write for ever (about
-- a million rows a day at 50,000 active users; docs/operations/capacity.md).
-- The worker now calls this every few minutes. A record still leased to an
-- in-flight request is never touched.
create or replace function private.prune_expired_idempotency(p_limit integer default 5000)
returns integer language plpgsql security definer set search_path = '' as $$
declare
  removed integer;
begin
  with doomed as (
    select r.id from public.idempotency_records r
    where r.expires_at < now()
      and (r.status <> 'reserved' or r.lease_expires_at is null or r.lease_expires_at < now())
    order by r.expires_at, r.id
    limit greatest(least(p_limit, 50000), 1)
    for update skip locked
  )
  delete from public.idempotency_records r using doomed where r.id = doomed.id;
  get diagnostics removed = row_count;
  return removed;
end;
$$;
alter function private.prune_expired_idempotency(integer) owner to postgres;
revoke all on function private.prune_expired_idempotency(integer)
  from public, anon, authenticated, service_role, studafy_api_runtime;
grant execute on function private.prune_expired_idempotency(integer) to studafy_worker_runtime;
