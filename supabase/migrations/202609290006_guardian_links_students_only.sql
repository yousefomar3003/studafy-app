-- A guardian links only to a student (2026-09-29).
--
-- A child is found by their Studafy ID, which belongs to a students row.
-- Nothing checked who the account behind that row was, and accounts can
-- hold several roles, so a parent could link to a teacher's account (or
-- to their own) as their "child" and read it through the family views.
--
-- private.guardian_link_target_allowed is the rule for every link: the row
-- is live, and it is either a child with no account yet (created by the
-- school), or an account that holds no role but student anywhere and is not
-- the guardian themselves. private.student_linkable adds, for what a parent
-- may find and request, that the account is a current student there. Locating an ID that is not linkable answers
-- exactly as an unknown ID does, so it cannot be used to discover staff
-- accounts; a request for one is not_found; and a trigger refuses any other
-- path that would create or re-point such a link.

-- Never a staff account and never the guardian's own: the rule every link
-- obeys, however it is made.
create or replace function private.guardian_link_target_allowed(
  p_student uuid, p_guardian uuid)
returns boolean language sql stable security definer set search_path = '' as $$
  select exists (
    select 1 from public.students st
    where st.id = p_student and st.deleted_at is null
      and (
        st.user_id is null
        or (
          st.user_id is distinct from p_guardian
          and not exists (
            select 1 from public.memberships m
            where m.user_id = st.user_id and m.role <> 'student' and m.active)
        )
      )
  );
$$;

-- What a parent may find and ask to link to: the above, and an account
-- must also be a current student at that school.
create or replace function private.student_linkable(p_student uuid, p_guardian uuid)
returns boolean language sql stable security definer set search_path = '' as $$
  select private.guardian_link_target_allowed(p_student, p_guardian)
    and exists (
      select 1 from public.students st
      where st.id = p_student
        and (st.user_id is null or exists (
          select 1 from public.memberships m
          where m.user_id = st.user_id and m.school_id = st.school_id
            and m.role = 'student' and m.active)));
$$;

alter function private.guardian_link_target_allowed(uuid, uuid) owner to postgres;
alter function private.student_linkable(uuid, uuid) owner to postgres;
revoke all on function private.guardian_link_target_allowed(uuid, uuid),
  private.student_linkable(uuid, uuid)
  from public, anon, authenticated, service_role, studafy_api_runtime,
  studafy_worker_runtime;

-- Every way a link is made - a parent's request, a managed child joining a
-- school, a verified link following the child to another school - passes
-- here. Existing links are left alone; only a new or re-pointed one is
-- checked.
create or replace function private.guardian_link_requires_student()
returns trigger language plpgsql security definer set search_path = '' as $$
begin
  if tg_op = 'UPDATE' and new.student_id = old.student_id
     and new.guardian_id = old.guardian_id then
    return new;
  end if;
  if not private.guardian_link_target_allowed(new.student_id, new.guardian_id) then
    raise exception using errcode = '23514',
      message = 'A guardian can be linked only to a student';
  end if;
  return new;
end;
$$;
alter function private.guardian_link_requires_student() owner to postgres;
revoke all on function private.guardian_link_requires_student()
  from public, anon, authenticated, service_role, studafy_api_runtime,
  studafy_worker_runtime;

drop trigger if exists guardian_link_requires_student on public.guardian_links;
create trigger guardian_link_requires_student
before insert or update of student_id, guardian_id on public.guardian_links
for each row execute function private.guardian_link_requires_student();

-- The family link commands, re-issued from 202609280003 with the check in
-- locateStudent and requestGuardianLink; otherwise unchanged.
CREATE OR REPLACE FUNCTION private.ops_command_family_links(p_operation text, p_resource_id uuid, p_input jsonb, p_idempotency_id uuid, p_idempotency_generation bigint)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
declare
  tenant uuid := nullif(current_setting('studafy.school_id', true), '')::uuid;
  request_id text := nullif(current_setting('studafy.request_id', true), '');
  body jsonb := coalesce(p_input->'body', '{}'::jsonb);
  response jsonb; before_value jsonb;
  entity_id uuid; entity_type text; audit_action text;
  idem_key text; resolved_school uuid; existing_status text;
  v_student_id uuid; v_recent_attempts bigint; v_expires_days int;
  outbox_template text; outbox_entity uuid; completed boolean;
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
    when 'locateStudent' then
      select count(*) into v_recent_attempts from public.audit_events
      where actor_id = auth.uid() and action = 'student_locate_attempted' and created_at > now() - interval '1 hour';
      if v_recent_attempts >= 10 then return jsonb_build_object('outcome', 'invalid_state'); end if;
      select st.id, st.school_id into v_student_id, resolved_school
      from public.students st where st.studafy_id = body->>'studafyId';
      -- Only a student can be a child. A teacher's or other staff account,
      -- or the caller's own, is answered exactly as an unknown ID is.
      if v_student_id is not null
         and not private.student_linkable(v_student_id, auth.uid()) then
        v_student_id := null;
        resolved_school := null;
      end if;
      -- Uniform shape whether found or not: only the nullable fields differ,
      -- never the outcome or response structure, so response shape/timing
      -- cannot itself be used to enumerate valid codes.
      response := case when v_student_id is null then jsonb_build_object('found', false, 'studentId', null, 'displayName', null)
        else jsonb_build_object('found', true, 'studentId', v_student_id,
          'displayName', (select display_name from public.students where id = v_student_id)) end;
      entity_type := 'student_locate'; entity_id := v_student_id; audit_action := 'student_locate_attempted';
      tenant := resolved_school;

    when 'requestGuardianLink' then
      v_student_id := (body->>'studentId')::uuid;
      select st.school_id into resolved_school from public.students st where st.id = v_student_id;
      if resolved_school is null then return jsonb_build_object('outcome', 'not_found'); end if;
      if not private.student_linkable(v_student_id, auth.uid()) then
        return jsonb_build_object('outcome', 'not_found');
      end if;
      select status::text into existing_status from public.guardian_links
      where student_id = v_student_id and guardian_id = auth.uid();
      if existing_status in ('pending', 'verified') then return jsonb_build_object('outcome', 'invalid'); end if;
      insert into public.guardian_links(school_id, student_id, guardian_id, status, relationship)
      values (resolved_school, v_student_id, auth.uid(), 'pending', nullif(body->>'relationship', ''))
      on conflict (student_id, guardian_id) do update set
        status = 'pending', relationship = nullif(body->>'relationship', ''),
        verified_by = null, verified_at = null, expires_at = null, updated_at = now()
      returning id into entity_id;
      tenant := resolved_school;
      response := private.api042_guardian_link_json(entity_id);
      entity_type := 'guardian_link'; audit_action := 'guardian_link_requested';
      outbox_template := 'family.guardian_link_requested'; outbox_entity := entity_id;

    when 'verifyGuardianLink' then
      select gl.school_id, gl.status::text, to_jsonb(gl) into resolved_school, existing_status, before_value
      from public.guardian_links gl where gl.id = p_resource_id for update;
      if resolved_school is null then return jsonb_build_object('outcome', 'not_found'); end if;
      -- Only an admin ever reaches this case (see authz_authorize), and an
      -- admin always has a membership in the resolved school, so tenant is
      -- reliably non-null here; this is defense in depth against a future
      -- middleware bug, not the only check.
      if resolved_school <> tenant then return jsonb_build_object('outcome', 'forbidden'); end if;
      if not private.is_school_admin(tenant) then return jsonb_build_object('outcome', 'forbidden'); end if;
      if existing_status <> 'pending' then return jsonb_build_object('outcome', 'invalid_state'); end if;
      v_expires_days := coalesce((body->>'expiresInDays')::int, 365);
      if v_expires_days < 1 or v_expires_days > 1825 then return jsonb_build_object('outcome', 'invalid'); end if;
      update public.guardian_links set status = 'verified', verified_by = auth.uid(), verified_at = now(),
        expires_at = now() + make_interval(days => v_expires_days), updated_at = now()
      where id = p_resource_id;
      entity_id := p_resource_id; entity_type := 'guardian_link'; audit_action := 'guardian_link_verified';
      response := private.api042_guardian_link_json(entity_id);
      outbox_template := 'family.guardian_link_verified'; outbox_entity := entity_id;

    when 'revokeGuardianLink' then
      select gl.school_id, gl.status::text, to_jsonb(gl) into resolved_school, existing_status, before_value
      from public.guardian_links gl where gl.id = p_resource_id for update;
      if resolved_school is null then return jsonb_build_object('outcome', 'not_found'); end if;
      -- tenant may be null here: the revoking guardian often has no
      -- memberships row at all (guardian_link.revoke is not tenantRequired
      -- for exactly this reason). resolved_school, read directly from the
      -- row the actor is actually touching, is the real tenant for the
      -- rest of this command; tenant is reassigned to it once the
      -- authorization check below has run.
      if not (private.is_school_admin(resolved_school) or (select guardian_id from public.guardian_links where id = p_resource_id) = auth.uid())
      then return jsonb_build_object('outcome', 'forbidden'); end if;
      if existing_status not in ('pending', 'verified') then return jsonb_build_object('outcome', 'invalid_state'); end if;
      tenant := resolved_school;
      update public.guardian_links set status = 'revoked', updated_at = now() where id = p_resource_id;
      entity_id := p_resource_id; entity_type := 'guardian_link'; audit_action := 'guardian_link_revoked';
      response := private.api042_guardian_link_json(entity_id);
      outbox_template := 'family.guardian_link_revoked'; outbox_entity := entity_id;

    else return jsonb_build_object('outcome', 'invalid');
  end case;

  insert into public.audit_events(school_id, actor_id, action, entity_type, entity_id, before_value, after_value, request_id)
  values (tenant, auth.uid(), audit_action, entity_type, entity_id, before_value, response, request_id);
  if outbox_template is not null then
    insert into public.notification_outbox(school_id, source_event_id, idempotency_key, channel, template_key, audience, payload)
    values (tenant, outbox_entity::text, idem_key, 'in_app', outbox_template,
      jsonb_build_object('schoolId', tenant), coalesce(response, '{}'::jsonb));
  end if;
  completed := private.api_idempotency_complete(p_idempotency_id, p_idempotency_generation, response_status, response);
  if not completed then raise exception 'API042_IDEMPOTENCY_COMPLETION_FAILED'; end if;
  return jsonb_build_object('outcome', 'ok', 'response', response);
end;
$function$;
