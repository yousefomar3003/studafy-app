-- Gender is asked as male, female or prefer not to say (2026-09-30).
--
-- First-sign-in setup asked "girl", "boy" or "prefer not to say", which
-- reads wrong for adults - teachers and parents answer it too. The stored
-- values become male and female; existing answers are carried over, and
-- "prefer not to say" is unchanged. The answer is still the person's own:
-- nothing here shows it to anyone else.

alter table public.profiles drop constraint if exists profiles_gender_check;
update public.profiles set gender = case gender
  when 'girl' then 'female' when 'boy' then 'male' else gender end
where gender in ('girl', 'boy');
alter table public.profiles add constraint profiles_gender_check
  check (gender in ('male', 'female', 'prefer_not_to_say'));

-- The profile command, accepting the new values. Otherwise unchanged.
create or replace function private.ops_command_account(p_operation text, p_resource_id uuid, p_input jsonb, p_idempotency_id uuid, p_idempotency_generation bigint)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
declare
  tenant uuid := nullif(current_setting('studafy.school_id', true), '')::uuid;
  request_id text := nullif(current_setting('studafy.request_id', true), '');
  req_body jsonb := coalesce(p_input->'body', '{}'::jsonb);
  response jsonb; before_value jsonb;
  entity_id uuid; entity_type text; audit_action text;
  idem_key text; completed boolean;
  response_status int := coalesce((p_input->>'responseStatus')::int, 200);
begin

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
      if (req_body->>'gender') is not null
         and (req_body->>'gender') not in ('male', 'female', 'prefer_not_to_say') then
        return jsonb_build_object('outcome', 'invalid');
      end if;
      -- Finishing setup takes both answers: the name the person chose, and a
      -- gender or "prefer not to say".
      if coalesce((req_body->>'completeSetup')::boolean, false)
         and (nullif(btrim(req_body->>'displayName'), '') is null
              or (req_body->>'gender') is null) then
        return jsonb_build_object('outcome', 'invalid');
      end if;
      update public.profiles set
        display_name = coalesce(nullif(btrim(req_body->>'displayName'), ''), display_name),
        locale = coalesce(req_body->>'locale', locale),
        gender = coalesce(req_body->>'gender', gender),
        profile_completed_at = case
          when coalesce((req_body->>'completeSetup')::boolean, false)
            then coalesce(profile_completed_at, now())
          else profile_completed_at end,
        updated_at = now()
      where id = auth.uid();
      entity_id := auth.uid(); entity_type := 'profile'; audit_action := 'profile_updated';
      response := private.profile_json(auth.uid());

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
$function$;

revoke all on function private.ops_command_account(text, uuid, jsonb, uuid, bigint)
  from public, anon, authenticated, service_role, studafy_api_runtime,
  studafy_worker_runtime;
alter function private.ops_command_account(text, uuid, jsonb, uuid, bigint)
  owner to postgres;
