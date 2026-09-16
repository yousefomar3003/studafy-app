-- API-042 S7: profile correction and data export request/status. Deletion
-- (impact/request/cancel) is already authoritative via AUTH-030/031's
-- /v1/account/deletion-* routes in apps/api/src/auth/routes.ts; this
-- migration adds the other half of account rights under the same /v1/account
-- namespace, as its own catalogue-driven module for consistency with every
-- other API-042 slice. Export generation itself (gathering every table's
-- rows for a user, packaging, signing a download URL) needs Phase 5's file
-- pipeline and is not built here - this is the request/status state machine
-- and audit trail only, honestly bounded rather than faked.

create table public.data_export_requests (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references public.profiles(id) on delete cascade,
  status text not null default 'pending' check (status in ('pending', 'ready', 'failed', 'expired')),
  requested_at timestamptz not null default now(),
  ready_at timestamptz,
  expires_at timestamptz,
  updated_at timestamptz not null default now(),
  check (status <> 'ready' or ready_at is not null)
);

-- Only one live (pending) export request per user at a time.
create unique index data_export_requests_live_unique
  on public.data_export_requests (user_id)
  where status = 'pending';

create trigger api042_set_updated_at before update on public.data_export_requests
for each row execute function private.set_updated_at();
alter table public.data_export_requests enable row level security;
revoke all on table public.data_export_requests from anon, authenticated, studafy_api_runtime, studafy_worker_runtime;

create or replace function private.api042_export_json(p_id uuid)
returns jsonb language sql stable security definer set search_path = '' as $$
  select jsonb_build_object(
    'id', d.id, 'status', d.status, 'requestedAt', d.requested_at, 'readyAt', d.ready_at, 'expiresAt', d.expires_at
  ) from public.data_export_requests d where d.id = p_id;
$$;

alter function private.api042_query(text, uuid, jsonb)
  rename to api042_query_pre_s7_account;

create or replace function private.api042_query(p_operation text, p_resource_id uuid, p_input jsonb)
returns jsonb language plpgsql stable security definer set search_path = '' as $$
begin
  if p_operation <> 'getExportStatus' then
    return private.api042_query_pre_s7_account(p_operation, p_resource_id, p_input);
  end if;
  if auth.uid() is null then return jsonb_build_object('outcome', 'forbidden'); end if;
  return jsonb_build_object('request', (
    select private.api042_export_json(d.id) from public.data_export_requests d
    where d.user_id = auth.uid() order by d.requested_at desc limit 1
  ));
end;
$$;

alter function private.api042_command(text, uuid, jsonb, uuid, bigint)
  rename to api042_command_pre_s7_account;

create or replace function private.api042_command(
  p_operation text,
  p_resource_id uuid,
  p_input jsonb,
  p_idempotency_id uuid,
  p_idempotency_generation bigint
)
returns jsonb language plpgsql security definer set search_path = '' as $$
declare
  tenant uuid := nullif(current_setting('studafy.school_id', true), '')::uuid;
  request_id text := nullif(current_setting('studafy.request_id', true), '');
  req_body jsonb := coalesce(p_input->'body', '{}'::jsonb);
  response jsonb; before_value jsonb;
  entity_id uuid; entity_type text; audit_action text;
  idem_key text; completed boolean;
  response_status int := coalesce((p_input->>'responseStatus')::int, 200);
begin
  if p_operation not in ('updateProfile', 'requestDataExport') then
    return private.api042_command_pre_s7_account(
      p_operation, p_resource_id, p_input, p_idempotency_id, p_idempotency_generation
    );
  end if;
  if auth.uid() is null or request_id is null then
    return jsonb_build_object('outcome', 'forbidden');
  end if;
  select r.idempotency_key into idem_key from public.idempotency_records r
  where r.id = p_idempotency_id and r.actor_id = auth.uid()
    and r.school_id is not distinct from tenant
    and r.generation = p_idempotency_generation and r.status = 'reserved'
  for update;
  if idem_key is null then return jsonb_build_object('outcome', 'forbidden'); end if;

  case p_operation
    when 'updateProfile' then
      select to_jsonb(p) into before_value from public.profiles p where p.id = auth.uid();
      if before_value is null then return jsonb_build_object('outcome', 'not_found'); end if;
      if (req_body->>'locale') is not null and (req_body->>'locale') not in ('en', 'ar') then
        return jsonb_build_object('outcome', 'invalid');
      end if;
      update public.profiles set
        display_name = coalesce(nullif(req_body->>'displayName', ''), display_name),
        locale = coalesce(req_body->>'locale', locale),
        updated_at = now()
      where id = auth.uid();
      entity_id := auth.uid(); entity_type := 'profile'; audit_action := 'profile_updated';
      select jsonb_build_object('id', p.id, 'displayName', p.display_name, 'locale', p.locale) into response
      from public.profiles p where p.id = auth.uid();

    when 'requestDataExport' then
      if exists (select 1 from public.data_export_requests d where d.user_id = auth.uid() and d.status = 'pending') then
        select d.id into entity_id from public.data_export_requests d where d.user_id = auth.uid() and d.status = 'pending';
      else
        insert into public.data_export_requests(user_id, status, expires_at)
        values (auth.uid(), 'pending', now() + interval '7 days')
        returning id into entity_id;
      end if;
      entity_type := 'data_export_request'; audit_action := 'data_export_requested';
      response := private.api042_export_json(entity_id);

    else return jsonb_build_object('outcome', 'invalid');
  end case;

  insert into public.audit_events(school_id, actor_id, action, entity_type, entity_id, before_value, after_value, request_id)
  values (tenant, auth.uid(), audit_action, entity_type, entity_id, before_value, response, request_id);
  completed := private.api_idempotency_complete(p_idempotency_id, p_idempotency_generation, response_status, response);
  if not completed then raise exception 'API042_IDEMPOTENCY_COMPLETION_FAILED'; end if;
  return jsonb_build_object('outcome', 'ok', 'response', response);
end;
$$;

alter function private.api042_export_json(uuid) owner to postgres;
alter function private.api042_query(text, uuid, jsonb) owner to postgres;
alter function private.api042_command(text, uuid, jsonb, uuid, bigint) owner to postgres;

revoke all on function private.api042_export_json(uuid), private.api042_query(text, uuid, jsonb),
  private.api042_command(text, uuid, jsonb, uuid, bigint)
from public, anon, authenticated, service_role, studafy_worker_runtime;
revoke all on function private.api042_query_pre_s7_account(text, uuid, jsonb)
from public, anon, authenticated, service_role, studafy_worker_runtime, studafy_api_runtime;
revoke all on function private.api042_command_pre_s7_account(text, uuid, jsonb, uuid, bigint)
from public, anon, authenticated, service_role, studafy_worker_runtime, studafy_api_runtime;
grant execute on function private.api042_query(text, uuid, jsonb), private.api042_command(text, uuid, jsonb, uuid, bigint)
to studafy_api_runtime;

revoke all privileges on all tables in schema public from studafy_api_runtime;
revoke all privileges on all sequences in schema public from studafy_api_runtime;
