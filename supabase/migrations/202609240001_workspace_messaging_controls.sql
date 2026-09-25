-- Give every teaching space its messaging controls.
--
-- private.school_messaging_enabled reads public.school_content_controls and
-- coalesces a missing row to FALSE. That fail-closed default is right: a
-- school should opt in to letting its students be messaged, not discover
-- afterwards that it was on.
--
-- But nothing was creating the row. provisionSchool never did, and neither
-- did createTeacherWorkspace, which this repairs. The result was that every
-- school ever created had messaging silently disabled, with no screen
-- reporting why and - in a product with no school administrator - nobody
-- able to turn it on. Conversations simply returned nothing, for everyone,
-- for ever.
--
-- A teacher's own workspace is created BY that teacher for their own
-- classes, so the teacher is the person the opt-in belongs to and it is
-- taken at creation. content_filter_level stays at its strictest setting,
-- and the classifier stays off; only the switch that makes a conversation
-- possible at all is turned on.

create or replace function private.api045_command(
  p_operation text,
  p_resource_id uuid,
  p_input jsonb,
  p_idempotency_id uuid,
  p_idempotency_generation bigint
)
returns jsonb
language plpgsql
security definer
set search_path to ''
as $function$
declare
  request_id text := nullif(current_setting('studafy.request_id', true), '');
  body jsonb := coalesce(p_input->'body', '{}'::jsonb);
  idem_key text;
  entity_id uuid; entity_type text; audit_action text;
  response jsonb;
  v_membership_id uuid;
  v_display_name text;
  v_name text;
  v_today date := current_date;
begin
  if auth.uid() is null or request_id is null then
    return jsonb_build_object('outcome', 'forbidden');
  end if;

  select r.idempotency_key into idem_key
  from public.idempotency_records r
  where r.id = p_idempotency_id and r.actor_id = auth.uid()
    and r.school_id is null
    and r.generation = p_idempotency_generation and r.status = 'reserved'
  for update;
  if idem_key is null then
    return jsonb_build_object('outcome', 'forbidden');
  end if;

  case p_operation

    when 'createTeacherWorkspace' then
      select p.display_name into v_display_name
      from public.profiles p where p.id = auth.uid() and p.deleted_at is null;
      if v_display_name is null then
        return jsonb_build_object('outcome', 'invalid');
      end if;

      if exists (
        select 1 from public.memberships m where m.user_id = auth.uid()
      ) then
        return jsonb_build_object('outcome', 'invalid_state');
      end if;

      v_name := coalesce(nullif(btrim(body->>'name'), ''), v_display_name);

      insert into public.schools(name, timezone, locale, status, version)
      values (
        v_name,
        coalesce(nullif(body->>'timezone', ''), 'Asia/Amman'),
        coalesce(nullif(body->>'locale', ''), 'en'),
        'active',
        1
      )
      returning id into entity_id;

      insert into public.memberships(
        school_id, user_id, role, active, status, version
      ) values (entity_id, auth.uid(), 'teacher', true, 'active', 1)
      returning id into v_membership_id;

      insert into public.membership_events(
        school_id, membership_id, actor_id, event_type, reason, idempotency_key
      ) values (
        entity_id, v_membership_id, auth.uid(), 'granted',
        'teacher_workspace_created', idem_key
      );

      insert into public.terms(
        school_id, name, starts_on, ends_on, active, status
      ) values (
        entity_id,
        to_char(v_today, 'YYYY') || '/' || to_char(v_today + interval '1 year', 'YYYY'),
        v_today,
        (v_today + interval '1 year')::date,
        true,
        'active'
      );

      -- Without this row messaging is off and cannot be turned on.
      insert into public.school_content_controls(
        school_id, messaging_enabled, content_filter_level,
        classifier_assist_enabled, updated_by
      ) values (entity_id, true, 'strict', false, auth.uid());

      select jsonb_build_object(
        'id', s.id, 'name', s.name, 'timezone', s.timezone,
        'locale', s.locale, 'role', 'teacher'
      ) into response
      from public.schools s where s.id = entity_id;

      entity_type := 'school';
      audit_action := 'teacher_workspace_created';

    else return jsonb_build_object('outcome', 'invalid');
  end case;

  insert into public.audit_events(
    school_id, actor_id, action, entity_type, entity_id,
    before_value, after_value, request_id
  ) values (
    entity_id, auth.uid(), audit_action, entity_type, entity_id,
    null, response, request_id
  );

  return jsonb_build_object('outcome', 'ok', 'response', response);
end;
$function$;

alter function private.api045_command(text, uuid, jsonb, uuid, bigint)
  owner to postgres;
revoke all on function private.api045_command(text, uuid, jsonb, uuid, bigint)
  from public, anon, authenticated, service_role, studafy_worker_runtime;
grant execute on function private.api045_command(text, uuid, jsonb, uuid, bigint)
  to studafy_api_runtime;

-- Backfill: every school that predates the fix has no row, so its people
-- cannot message each other at all. Only schools with no row are touched, so
-- a school that has since made a deliberate choice keeps it.
insert into public.school_content_controls(
  school_id, messaging_enabled, content_filter_level, classifier_assist_enabled
)
select s.id, true, 'strict', false
from public.schools s
where not exists (
  select 1 from public.school_content_controls cc where cc.school_id = s.id
);
