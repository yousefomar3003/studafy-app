-- Profile setup: a name the person chose, and their gender (2026-09-28).
--
-- New accounts were named from their email address. Now everyone, on their
-- first sign-in, says what they want to be called and - if they wish -
-- their gender: a girl, a boy, or "prefer not to say". Once saved, the
-- question is not asked again (profile_completed_at).
--
-- Gender is the person's own: it is returned to them and to nobody else by
-- this migration, and nothing here shows it to a school or another user.

alter table public.profiles
  add column if not exists gender text
    check (gender in ('girl', 'boy', 'prefer_not_to_say')),
  add column if not exists profile_completed_at timestamptz;

-- The caller's own profile, as the app reads it.
create or replace function private.profile_json(p_user uuid)
returns jsonb language sql stable security definer set search_path = '' as $$
  select jsonb_build_object(
    'id', p.id,
    'displayName', p.display_name,
    'locale', p.locale,
    'gender', p.gender,
    'setupComplete', p.profile_completed_at is not null)
  from public.profiles p where p.id = p_user;
$$;

revoke all on function private.profile_json(uuid)
  from public, anon, authenticated, service_role, studafy_api_runtime,
  studafy_worker_runtime;
alter function private.profile_json(uuid) owner to postgres;

create or replace function private.ops_query_profile(
  p_operation text, p_resource_id uuid, p_input jsonb)
returns jsonb language plpgsql stable security definer set search_path = '' as $$
begin
  if auth.uid() is null then return jsonb_build_object('outcome', 'forbidden'); end if;
  return coalesce(private.profile_json(auth.uid()),
    jsonb_build_object('outcome', 'not_found'));
end;
$$;

revoke all on function private.ops_query_profile(text, uuid, jsonb)
  from public, anon, authenticated, service_role, studafy_api_runtime,
  studafy_worker_runtime;
alter function private.ops_query_profile(text, uuid, jsonb) owner to postgres;

-- The query dispatcher, with getProfile added (ADR-0030: one dispatcher,
-- named handlers). Copied from 202609280002 otherwise unchanged.
create or replace function private.api042_query(p_operation text, p_resource_id uuid, p_input jsonb)
returns jsonb
language plpgsql
stable security definer
set search_path = ''
as $$
begin
  -- Each operation has one owner; the first match is the newest code for it.
  case
    when p_operation = 'listMeetings' then
      return private.ops_query_meeting_list(p_operation, p_resource_id, p_input);
    when p_operation = 'getFamilyInsights' then
      return private.ops_query_family_insights(p_operation, p_resource_id, p_input);
    when p_operation = 'getStudentFamily' then
      return private.ops_query_student_family(p_operation, p_resource_id, p_input);
    when p_operation = 'downloadDataExport' then
      return private.ops_query_data_export_download(p_operation, p_resource_id, p_input);
    when p_operation = 'listMyGuardianLinks' then
      return private.ops_query_my_guardian_links(p_operation, p_resource_id, p_input);
    when p_operation in ('listMessages', 'listConversations', 'listContacts') then
      return private.ops_query_messaging(p_operation, p_resource_id, p_input);
    when p_operation in ('getContentControls', 'listReports', 'getReport', 
        'listBlocks', 'getModerationOverview', 'listModerationQueue', 
        'getModerationReport', 'listModerationAccess') then
      return private.ops_query_safety(p_operation, p_resource_id, p_input);
    when p_operation = 'listSupportAccessGrants' then
      return private.ops_query_support_access(p_operation, p_resource_id, p_input);
    when p_operation = 'getExportStatus' then
      return private.ops_query_account(p_operation, p_resource_id, p_input);
    when p_operation = 'getProfile' then
      return private.ops_query_profile(p_operation, p_resource_id, p_input);
    when p_operation in ('listNotifications', 'getUnreadCount', 'getNotificationPreferences') then
      return private.ops_query_notifications(p_operation, p_resource_id, p_input);
    when p_operation = 'getMeetingStatus' then
      return private.ops_query_meeting_status(p_operation, p_resource_id, p_input);
    when p_operation = 'listAnnouncements' then
      return private.ops_query_communications(p_operation, p_resource_id, p_input);
    else
      return private.ops_query_invitations(p_operation, p_resource_id, p_input);
  end case;
end;
$$;

-- updateProfile takes the gender and finishes setup. Copied from
-- 202609280003 otherwise unchanged.
CREATE OR REPLACE FUNCTION private.ops_command_account(p_operation text, p_resource_id uuid, p_input jsonb, p_idempotency_id uuid, p_idempotency_generation bigint)
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
         and (req_body->>'gender') not in ('girl', 'boy', 'prefer_not_to_say') then
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
