-- Self-serve teacher sign-up.
--
-- Until now the only way to get a first membership was provisionSchool, which
-- requires a public.platform_operators row that has deliberately never been
-- exposed over any API. That made every teacher account something a human at
-- Studafy had to create by hand, which does not survive a public launch.
--
-- The product has no concept of a school: a teacher signs up, makes a class
-- and invites students to it. The schools row remains because the whole
-- schema, RLS and audit trail are tenant-scoped, so this command creates one
-- silently as the teacher's own container. Nothing surfaces it to the client
-- beyond the id its own classes hang from.
--
-- Three details are deliberate:
--
--   1. The creator is granted 'teacher', never 'school_admin'. An active
--      school_admin membership makes apps/api/src/authorization/middleware.ts
--      demand aal2 for every permission outside a small bootstrap set, so
--      granting it here would lock the new teacher out of the entire API
--      until they enrolled MFA - on the first screen after sign-up.
--   2. A term is created in the same transaction. createClassroom refuses
--      with invalid_state when the school has no 'active' or 'planned' term
--      (202609200001_teacher_creates_class.sql), so a workspace without one
--      would be a dead end: a teacher who can make no class at all.
--   3. One workspace per account, enforced by the absence of ANY membership
--      row. Signed-in accounts can call this, so the cheap durable-state
--      abuse - one account minting tenants in a loop - has to be closed here
--      rather than only at the edge.
--
-- A new dispatcher rather than another generation of private.api042_command,
-- which is already five rename-and-chain deep; JOIN-052 set this precedent
-- with private.api044_command. The permission is declared scope:"self" in the
-- API's catalogue, so private.authz_authorize is never consulted for it and
-- no decision chain has to change.

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

  -- The tenant is deliberately not read from studafy.school_id: the caller
  -- has no school yet, which is the entire point of this command.
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

      -- Any membership at all, active or not, means this account has already
      -- been placed somewhere. Revoked rows count: letting a removed teacher
      -- mint a fresh tenant would turn removal into a no-op.
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

      -- Spans a year from today rather than a calendar academic year: a
      -- teacher signing up in March must be able to teach in March.
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

-- JOIN-052 shipped private.api044_* without granting execute to the runtime
-- role, so redeeming a class join link would fail the moment the API stops
-- connecting as a superuser. That is the path a brand-new student takes, so
-- it is repaired here rather than left to be discovered in production.
grant execute on function private.api044_command(text, uuid, jsonb, uuid, bigint)
  to studafy_api_runtime;
grant execute on function private.api044_query(text, uuid, jsonb)
  to studafy_api_runtime;
