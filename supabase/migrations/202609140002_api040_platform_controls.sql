-- API-040: durable command idempotency for the least-privilege API runtime.
-- The runtime receives only EXECUTE on the functions at the end of this file.

alter table public.idempotency_records
  add column generation bigint not null default 1,
  add column lease_expires_at timestamptz;

update public.idempotency_records
set lease_expires_at = least(expires_at, now())
where status = 'reserved' and lease_expires_at is null;

alter table public.idempotency_records
  add constraint api040_idempotency_generation_positive check (generation > 0),
  add constraint api040_idempotency_reserved_lease check (
    status <> 'reserved' or lease_expires_at is not null
  ),
  add constraint api040_idempotency_safe_response check (
    response_body is null or octet_length(response_body::text) <= 65536
  );

create or replace function private.api_idempotency_reserve(
  p_school_id uuid,
  p_scope text,
  p_key text,
  p_request_hash text,
  p_retention_seconds integer default 86400,
  p_lease_seconds integer default 15
)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  actor uuid := auth.uid();
  existing public.idempotency_records%rowtype;
begin
  if actor is null or not private.is_active_user() then
    return jsonb_build_object('outcome', 'denied');
  end if;
  if p_school_id is not null and not private.has_active_membership(p_school_id, null) then
    return jsonb_build_object('outcome', 'denied');
  end if;
  if p_scope !~ '^[A-Za-z0-9][A-Za-z0-9._:-]{2,127}$'
     or p_key !~ '^[A-Za-z0-9][A-Za-z0-9._:-]{15,127}$'
     or p_request_hash !~ '^[0-9a-f]{64}$'
     or p_retention_seconds not between 60 and 604800
     or p_lease_seconds not between 1 and 60 then
    return jsonb_build_object('outcome', 'invalid');
  end if;

  perform pg_advisory_xact_lock(hashtextextended(
    coalesce(p_school_id::text, 'global') || ':' || actor::text || ':' || p_scope || ':' || p_key,
    0
  ));

  select * into existing
  from public.idempotency_records r
  where r.school_id is not distinct from p_school_id
    and r.actor_id = actor
    and r.scope = p_scope
    and r.idempotency_key = p_key
  for update;

  if found and existing.expires_at <= now() then
    delete from public.idempotency_records where id = existing.id;
    existing := null;
  end if;

  if existing.id is null then
    insert into public.idempotency_records (
      school_id, actor_id, scope, idempotency_key, request_hash,
      status, expires_at, lease_expires_at
    ) values (
      p_school_id, actor, p_scope, p_key, p_request_hash,
      'reserved', now() + make_interval(secs => p_retention_seconds),
      now() + make_interval(secs => p_lease_seconds)
    ) returning * into existing;
    return jsonb_build_object(
      'outcome', 'reserved', 'id', existing.id, 'generation', existing.generation
    );
  end if;

  if existing.request_hash <> p_request_hash then
    return jsonb_build_object('outcome', 'mismatch');
  end if;
  if existing.status = 'completed' then
    return jsonb_build_object(
      'outcome', 'replay', 'responseStatus', existing.response_status,
      'responseBody', existing.response_body
    );
  end if;
  if existing.status = 'reserved' and existing.lease_expires_at > now() then
    return jsonb_build_object('outcome', 'inProgress');
  end if;

  update public.idempotency_records r
  set status = 'reserved', generation = r.generation + 1,
      lease_expires_at = now() + make_interval(secs => p_lease_seconds),
      response_status = null, response_body = null
  where r.id = existing.id
  returning * into existing;

  return jsonb_build_object(
    'outcome', 'reserved', 'id', existing.id, 'generation', existing.generation
  );
end;
$$;

create or replace function private.api_idempotency_complete(
  p_id uuid,
  p_generation bigint,
  p_response_status integer,
  p_response_body jsonb
)
returns boolean
language plpgsql
security definer
set search_path = ''
as $$
begin
  if auth.uid() is null
     or p_response_status not between 200 and 299
     or octet_length(coalesce(p_response_body, '{}'::jsonb)::text) > 65536 then
    return false;
  end if;
  update public.idempotency_records r
  set status = 'completed', response_status = p_response_status,
      response_body = coalesce(p_response_body, '{}'::jsonb),
      lease_expires_at = null
  where r.id = p_id and r.actor_id = auth.uid()
    and r.generation = p_generation and r.status = 'reserved';
  return found;
end;
$$;

create or replace function private.api_idempotency_fail(
  p_id uuid,
  p_generation bigint
)
returns boolean
language plpgsql
security definer
set search_path = ''
as $$
begin
  if auth.uid() is null then return false; end if;
  update public.idempotency_records r
  set status = 'failed', response_status = null, response_body = null,
      lease_expires_at = null
  where r.id = p_id and r.actor_id = auth.uid()
    and r.generation = p_generation and r.status = 'reserved';
  return found;
end;
$$;

alter function private.api_idempotency_reserve(uuid, text, text, text, integer, integer) owner to postgres;
alter function private.api_idempotency_complete(uuid, bigint, integer, jsonb) owner to postgres;
alter function private.api_idempotency_fail(uuid, bigint) owner to postgres;

revoke all on function private.api_idempotency_reserve(uuid, text, text, text, integer, integer)
from public, anon, authenticated, service_role, studafy_worker_runtime;
revoke all on function private.api_idempotency_complete(uuid, bigint, integer, jsonb)
from public, anon, authenticated, service_role, studafy_worker_runtime;
revoke all on function private.api_idempotency_fail(uuid, bigint)
from public, anon, authenticated, service_role, studafy_worker_runtime;

grant execute on function private.api_idempotency_reserve(uuid, text, text, text, integer, integer)
to studafy_api_runtime;
grant execute on function private.api_idempotency_complete(uuid, bigint, integer, jsonb)
to studafy_api_runtime;
grant execute on function private.api_idempotency_fail(uuid, bigint)
to studafy_api_runtime;
