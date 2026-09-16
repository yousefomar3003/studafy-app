-- API-042 S1: school provisioning/suspend/close, membership lifecycle,
-- classroom staffing and enrollment transitions. Same discipline as
-- API-041: one SECURITY DEFINER command dispatcher, execute-only grant to
-- studafy_api_runtime, audit_events + notification_outbox on every mutation.

create or replace function private.is_platform_operator()
returns boolean language sql stable security definer set search_path = '' as $$
  select auth.uid() is not null and exists (
    select 1 from public.platform_operators po where po.user_id = auth.uid()
  );
$$;

-- API-040's reservation function requires active school membership before
-- it will reserve a school-scoped key at all -- correct for every ordinary
-- tenant command, but it would also block a platform operator from ever
-- reaching suspendSchool/closeSchool for a school they administer without
-- being a member of. Widen the gate with a narrow, already-audited
-- allowlist rather than loosening it for every caller.
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
  if p_school_id is not null
    and not private.has_active_membership(p_school_id, null)
    and not private.is_platform_operator() then
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

create or replace function private.is_class_lead(target_classroom uuid)
returns boolean language sql stable security definer set search_path = '' as $$
  select private.is_active_user() and exists (
    select 1 from public.classroom_staff cs
    join public.memberships m on m.id = cs.membership_id and m.user_id = cs.user_id
    where cs.classroom_id = target_classroom and cs.user_id = auth.uid()
      and cs.status = 'active' and cs.role = 'lead_teacher'
      and m.active and m.status = 'active'
      and (m.valid_from is null or m.valid_from <= now())
      and (m.valid_until is null or m.valid_until > now())
  );
$$;

-- Same rename-and-extend technique 202609150002 used: the API-041 decision
-- function keeps its old name as a fallback so every previously recognized
-- action keeps working unmodified.
alter function private.authz_authorize(text, uuid)
  rename to authz_authorize_pre_api042;

create or replace function private.authz_authorize(p_action text, p_resource_id uuid)
returns jsonb language plpgsql stable security definer set search_path = '' as $$
declare target_school uuid; permitted boolean := false;
begin
  if p_action not in (
    'school.suspend', 'school.close',
    'membership.grant', 'membership.activate', 'membership.suspend', 'membership.revoke',
    'classroom_staff.write', 'enrollment.write'
  ) then return private.authz_authorize_pre_api042(p_action, p_resource_id); end if;
  if auth.uid() is null or p_resource_id is null then
    return jsonb_build_object('allowed', false, 'school_id', null, 'reason', 'invalid_resource');
  end if;

  case
    when p_action in ('school.suspend', 'school.close') then
      select s.id, (private.is_platform_operator() or private.is_school_admin(s.id))
      into target_school, permitted from public.schools s where s.id = p_resource_id;
    when p_action = 'membership.grant' then
      select s.id, private.is_school_admin(s.id)
      into target_school, permitted from public.schools s where s.id = p_resource_id;
    when p_action in ('membership.activate', 'membership.suspend', 'membership.revoke') then
      select m.school_id, private.is_school_admin(m.school_id)
      into target_school, permitted from public.memberships m where m.id = p_resource_id;
    when p_action = 'classroom_staff.write' then
      select c.school_id, (private.is_school_admin(c.school_id) or private.is_class_lead(c.id))
      into target_school, permitted from public.classrooms c where c.id = p_resource_id;
    when p_action = 'enrollment.write' then
      select c.school_id, (private.is_school_admin(c.school_id) or private.api041_class_writer(c.id))
      into target_school, permitted from public.classrooms c where c.id = p_resource_id;
  end case;
  return jsonb_build_object('allowed', coalesce(permitted, false), 'school_id', target_school,
    'reason', case when target_school is null then 'invalid_resource' when permitted then 'allowed' else 'denied' end);
end;
$$;

create or replace function private.api042_membership_json(p_id uuid)
returns jsonb language sql stable security definer set search_path = '' as $$
  select jsonb_build_object(
    'id', m.id, 'schoolId', m.school_id, 'userId', m.user_id, 'role', m.role,
    'status', m.status, 'version', m.version
  ) from public.memberships m where m.id = p_id;
$$;

create or replace function private.api042_staff_json(p_id uuid)
returns jsonb language sql stable security definer set search_path = '' as $$
  select jsonb_build_object(
    'id', cs.id, 'classroomId', cs.classroom_id, 'userId', cs.user_id,
    'role', cs.role, 'status', cs.status
  ) from public.classroom_staff cs where cs.id = p_id;
$$;

create or replace function private.api042_enrollment_json(p_classroom uuid, p_student uuid)
returns jsonb language sql stable security definer set search_path = '' as $$
  select jsonb_build_object(
    'classroomId', e.classroom_id, 'studentId', e.student_id, 'status', e.status
  ) from public.enrollments e where e.classroom_id = p_classroom and e.student_id = p_student;
$$;

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
  body jsonb := coalesce(p_input->'body', '{}'::jsonb);
  response jsonb; before_value jsonb;
  entity_id uuid; entity_type text; audit_action text;
  idem_key text; version_value bigint; target_user uuid; target_role text;
  membership_id uuid; staff_id uuid; v_student_id uuid; v_target_classroom_id uuid;
  membership_event text; outbox_template text; outbox_entity uuid; resolved_school uuid;
  completed boolean;
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
  -- Unlike API-041, there is no blanket has_active_membership(tenant) gate
  -- here: a platform operator legitimately acts on a school without being
  -- one of its members (suspendSchool/closeSchool), and provisionSchool has
  -- no tenant at all. Every case below re-derives and checks its own exact
  -- authorization predicate instead.

  case p_operation
    when 'provisionSchool' then
      if not private.is_platform_operator() then return jsonb_build_object('outcome', 'forbidden'); end if;
      target_user := (body->>'initialAdminUserId')::uuid;
      if not exists (select 1 from public.profiles p where p.id = target_user) then
        return jsonb_build_object('outcome', 'invalid');
      end if;
      insert into public.schools(name, timezone, locale, status, version)
      values (body->>'name', coalesce(body->>'timezone', 'Asia/Riyadh'), coalesce(body->>'locale', 'en'), 'active', 1)
      returning id into entity_id;
      insert into public.memberships(school_id, user_id, role, active, status, version)
      values (entity_id, target_user, 'school_admin', true, 'active', 1)
      returning id into membership_id;
      insert into public.membership_events(school_id, membership_id, actor_id, event_type, reason, idempotency_key)
      values (entity_id, membership_id, auth.uid(), 'granted', 'school_provisioned', idem_key);
      select jsonb_build_object('id', s.id, 'name', s.name, 'timezone', s.timezone, 'locale', s.locale,
        'status', s.status, 'version', s.version) into response
      from public.schools s where s.id = entity_id;
      entity_type := 'school'; audit_action := 'school_provisioned';

    when 'suspendSchool', 'closeSchool' then
      select s.version, to_jsonb(s) into version_value, before_value from public.schools s
      where s.id = p_resource_id for update;
      if version_value is null then return jsonb_build_object('outcome', 'not_found'); end if;
      if tenant <> p_resource_id then return jsonb_build_object('outcome', 'forbidden'); end if;
      if not (private.is_platform_operator() or private.is_school_admin(p_resource_id)) then
        return jsonb_build_object('outcome', 'forbidden');
      end if;
      if version_value <> (body->>'expectedVersion')::bigint then return jsonb_build_object('outcome', 'version_conflict'); end if;
      if p_operation = 'suspendSchool' and not exists (
        select 1 from public.schools where id = p_resource_id and status = 'active'
      ) then return jsonb_build_object('outcome', 'invalid_state'); end if;
      if p_operation = 'closeSchool' and not exists (
        select 1 from public.schools where id = p_resource_id and status in ('active', 'suspended')
      ) then return jsonb_build_object('outcome', 'invalid_state'); end if;
      update public.schools set
        status = (case when p_operation = 'suspendSchool' then 'suspended' else 'closed' end)::public.school_status,
        version = version + 1, updated_at = now()
      where id = p_resource_id;
      entity_id := p_resource_id; entity_type := 'school';
      audit_action := case when p_operation = 'suspendSchool' then 'school_suspended' else 'school_closed' end;
      select jsonb_build_object('id', s.id, 'name', s.name, 'timezone', s.timezone, 'locale', s.locale,
        'status', s.status, 'version', s.version) into response
      from public.schools s where s.id = entity_id;

    when 'grantMembership' then
      if not private.is_school_admin(tenant) then return jsonb_build_object('outcome', 'forbidden'); end if;
      target_user := (body->>'userId')::uuid;
      target_role := body->>'role';
      if not exists (
        select 1 from public.memberships m where m.school_id = tenant and m.user_id = target_user
      ) then
        -- grantMembership only adds an additional role for someone already
        -- verified as a member of this school. Onboarding a brand-new
        -- person to a school goes through invitations, not this command.
        return jsonb_build_object('outcome', 'invalid_state');
      end if;
      if exists (
        select 1 from public.memberships m where m.school_id = tenant and m.user_id = target_user
          and m.role = target_role::public.app_role and m.status <> 'revoked'
      ) then return jsonb_build_object('outcome', 'invalid'); end if;
      insert into public.memberships(school_id, user_id, role, active, status, version)
      values (tenant, target_user, target_role::public.app_role, true, 'active', 1)
      returning id into entity_id;
      insert into public.membership_events(school_id, membership_id, actor_id, event_type, reason, idempotency_key)
      values (tenant, entity_id, auth.uid(), 'granted', coalesce(body->>'reason', ''), idem_key);
      response := private.api042_membership_json(entity_id);
      entity_type := 'membership'; audit_action := 'membership_granted';
      outbox_template := 'school_admin.membership_granted'; outbox_entity := entity_id;

    when 'activateMembership', 'suspendMembership', 'revokeMembership' then
      select m.school_id, m.version, m.status::text, to_jsonb(m)
        into resolved_school, version_value, target_role, before_value
      from public.memberships m where m.id = p_resource_id for update;
      if resolved_school is null then return jsonb_build_object('outcome', 'not_found'); end if;
      -- Defense in depth: the AUTH-031 decision already derived `tenant` from
      -- this exact membership row, so this can only fail if that invariant
      -- is ever broken by a future change.
      if resolved_school <> tenant then return jsonb_build_object('outcome', 'forbidden'); end if;
      if not private.is_school_admin(tenant) then return jsonb_build_object('outcome', 'forbidden'); end if;
      if version_value <> (body->>'expectedVersion')::bigint then return jsonb_build_object('outcome', 'version_conflict'); end if;
      if p_operation = 'activateMembership' and target_role <> 'suspended' then return jsonb_build_object('outcome', 'invalid_state'); end if;
      if p_operation = 'suspendMembership' and target_role <> 'active' then return jsonb_build_object('outcome', 'invalid_state'); end if;
      if p_operation = 'revokeMembership' and target_role not in ('active', 'suspended') then return jsonb_build_object('outcome', 'invalid_state'); end if;
      if p_operation = 'revokeMembership' and (select m2.role from public.memberships m2 where m2.id = p_resource_id) = 'school_admin'
        and (select count(*) from public.memberships m3 where m3.school_id = tenant and m3.role = 'school_admin'
          and m3.status = 'active' and m3.id <> p_resource_id) = 0
      then
        -- Never let a school lose its last active admin through this path;
        -- that would strand every subsequent admin-only recovery action.
        return jsonb_build_object('outcome', 'invalid_state');
      end if;
      update public.memberships set
        status = (case p_operation
          when 'activateMembership' then 'active' when 'suspendMembership' then 'suspended' else 'revoked' end)::public.membership_status,
        active = (p_operation = 'activateMembership'),
        version = version + 1, updated_at = now()
      where id = p_resource_id;
      membership_event := case p_operation
        when 'activateMembership' then 'reactivated' when 'suspendMembership' then 'suspended' else 'revoked' end;
      insert into public.membership_events(school_id, membership_id, actor_id, event_type, reason, idempotency_key)
      values (tenant, p_resource_id, auth.uid(), membership_event, coalesce(body->>'reason', ''), idem_key);
      entity_id := p_resource_id; entity_type := 'membership';
      audit_action := 'membership_' || membership_event;
      response := private.api042_membership_json(entity_id);
      outbox_template := 'school_admin.membership_' || membership_event; outbox_entity := entity_id;

    when 'assignClassroomStaff' then
      if not exists (select 1 from public.classrooms c where c.id = p_resource_id and c.school_id = tenant) then
        return jsonb_build_object('outcome', 'not_found');
      end if;
      if not (private.is_school_admin(tenant) or private.is_class_lead(p_resource_id)) then
        return jsonb_build_object('outcome', 'forbidden');
      end if;
      target_user := (body->>'userId')::uuid;
      target_role := body->>'role';
      select ms.id into membership_id from public.memberships ms
        where ms.school_id = tenant and ms.user_id = target_user and ms.active and ms.status = 'active'
        order by ms.created_at limit 1;
      if membership_id is null then return jsonb_build_object('outcome', 'invalid_state'); end if;
      if exists (
        select 1 from public.classroom_staff cs where cs.classroom_id = p_resource_id
          and cs.user_id = target_user and cs.status = 'active'
      ) then return jsonb_build_object('outcome', 'invalid'); end if;
      insert into public.classroom_staff(school_id, classroom_id, membership_id, user_id, role, status)
      values (tenant, p_resource_id, membership_id, target_user, target_role::public.classroom_staff_role, 'active')
      returning id into entity_id;
      response := private.api042_staff_json(entity_id);
      entity_type := 'classroom_staff'; audit_action := 'classroom_staff_assigned';
      outbox_template := 'school_admin.classroom_staff_assigned'; outbox_entity := entity_id;

    when 'removeClassroomStaff' then
      if not exists (select 1 from public.classrooms c where c.id = p_resource_id and c.school_id = tenant) then
        return jsonb_build_object('outcome', 'not_found');
      end if;
      if not (private.is_school_admin(tenant) or private.is_class_lead(p_resource_id)) then
        return jsonb_build_object('outcome', 'forbidden');
      end if;
      staff_id := (body->>'staffAssignmentId')::uuid;
      select cs.status::text, to_jsonb(cs) into target_role, before_value
      from public.classroom_staff cs where cs.id = staff_id and cs.classroom_id = p_resource_id for update;
      if target_role is null then return jsonb_build_object('outcome', 'not_found'); end if;
      if target_role <> 'active' then return jsonb_build_object('outcome', 'invalid_state'); end if;
      if (select role from public.classroom_staff where id = staff_id) = 'lead_teacher'
        and (select count(*) from public.classroom_staff cs2 where cs2.classroom_id = p_resource_id
          and cs2.role = 'lead_teacher' and cs2.status = 'active' and cs2.id <> staff_id) = 0
      then return jsonb_build_object('outcome', 'invalid_state'); end if;
      update public.classroom_staff set status = 'ended', ends_at = now(), updated_at = now() where id = staff_id;
      entity_id := staff_id; entity_type := 'classroom_staff'; audit_action := 'classroom_staff_removed';
      response := private.api042_staff_json(entity_id);
      outbox_template := 'school_admin.classroom_staff_removed'; outbox_entity := entity_id;

    when 'enrollStudent' then
      if not exists (select 1 from public.classrooms c where c.id = p_resource_id and c.school_id = tenant) then
        return jsonb_build_object('outcome', 'not_found');
      end if;
      if not (private.is_school_admin(tenant) or private.api041_class_writer(p_resource_id)) then
        return jsonb_build_object('outcome', 'forbidden');
      end if;
      v_student_id := (body->>'studentId')::uuid;
      if not exists (select 1 from public.students st where st.id = v_student_id and st.school_id = tenant) then
        return jsonb_build_object('outcome', 'not_found');
      end if;
      if exists (
        select 1 from public.enrollments e where e.classroom_id = p_resource_id and e.student_id = v_student_id
          and e.active and e.status = 'active'
      ) then return jsonb_build_object('outcome', 'invalid'); end if;
      insert into public.enrollments(school_id, classroom_id, student_id, active, status, starts_on)
      values (tenant, p_resource_id, v_student_id, true, 'active', current_date)
      on conflict (school_id, classroom_id, student_id) do update set
        active = true, status = 'active', starts_on = current_date, ends_on = null, updated_at = now();
      entity_type := 'enrollment'; audit_action := 'student_enrolled';
      response := private.api042_enrollment_json(p_resource_id, v_student_id);
      outbox_template := 'school_admin.student_enrolled'; outbox_entity := v_student_id;

    when 'withdrawStudent' then
      if not exists (select 1 from public.classrooms c where c.id = p_resource_id and c.school_id = tenant) then
        return jsonb_build_object('outcome', 'not_found');
      end if;
      if not (private.is_school_admin(tenant) or private.api041_class_writer(p_resource_id)) then
        return jsonb_build_object('outcome', 'forbidden');
      end if;
      v_student_id := (body->>'studentId')::uuid;
      if not exists (
        select 1 from public.enrollments e where e.classroom_id = p_resource_id and e.student_id = v_student_id
          and e.active and e.status = 'active'
      ) then return jsonb_build_object('outcome', 'invalid_state'); end if;
      update public.enrollments e set active = false, status = 'withdrawn', ends_on = current_date, updated_at = now()
      where e.classroom_id = p_resource_id and e.student_id = v_student_id;
      entity_type := 'enrollment'; audit_action := 'student_withdrawn';
      response := private.api042_enrollment_json(p_resource_id, v_student_id);
      outbox_template := 'school_admin.student_withdrawn'; outbox_entity := v_student_id;

    when 'transferEnrollment' then
      if not exists (select 1 from public.classrooms c where c.id = p_resource_id and c.school_id = tenant) then
        return jsonb_build_object('outcome', 'not_found');
      end if;
      if not (private.is_school_admin(tenant) or private.api041_class_writer(p_resource_id)) then
        return jsonb_build_object('outcome', 'forbidden');
      end if;
      v_student_id := (body->>'studentId')::uuid;
      v_target_classroom_id := (body->>'targetClassroomId')::uuid;
      if not exists (
        select 1 from public.enrollments e where e.classroom_id = p_resource_id and e.student_id = v_student_id
          and e.active and e.status = 'active'
      ) then return jsonb_build_object('outcome', 'invalid_state'); end if;
      if not exists (select 1 from public.classrooms c where c.id = v_target_classroom_id and c.school_id = tenant) then
        return jsonb_build_object('outcome', 'not_found');
      end if;
      if not private.api041_class_writer(v_target_classroom_id) then return jsonb_build_object('outcome', 'forbidden'); end if;
      update public.enrollments e set active = false, status = 'withdrawn', ends_on = current_date, updated_at = now()
      where e.classroom_id = p_resource_id and e.student_id = v_student_id;
      insert into public.enrollments(school_id, classroom_id, student_id, active, status, starts_on)
      values (tenant, v_target_classroom_id, v_student_id, true, 'active', current_date)
      on conflict (school_id, classroom_id, student_id) do update set
        active = true, status = 'active', starts_on = current_date, ends_on = null, updated_at = now();
      entity_type := 'enrollment'; audit_action := 'student_transferred';
      response := private.api042_enrollment_json(v_target_classroom_id, v_student_id);
      outbox_template := 'school_admin.student_transferred'; outbox_entity := v_student_id;

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
$$;

alter function private.is_platform_operator() owner to postgres;
alter function private.is_class_lead(uuid) owner to postgres;
alter function private.authz_authorize(text, uuid) owner to postgres;
alter function private.api042_membership_json(uuid) owner to postgres;
alter function private.api042_staff_json(uuid) owner to postgres;
alter function private.api042_enrollment_json(uuid, uuid) owner to postgres;
alter function private.api042_command(text, uuid, jsonb, uuid, bigint) owner to postgres;

revoke all on function private.is_platform_operator(), private.is_class_lead(uuid),
  private.api042_membership_json(uuid), private.api042_staff_json(uuid),
  private.api042_enrollment_json(uuid, uuid), private.api042_command(text, uuid, jsonb, uuid, bigint)
from public, anon, authenticated, service_role, studafy_worker_runtime;
revoke all on function private.authz_authorize_pre_api042(text, uuid)
from public, anon, authenticated, service_role, studafy_worker_runtime, studafy_api_runtime;
revoke all on function private.authz_authorize(text, uuid)
from public, anon, authenticated, service_role, studafy_worker_runtime;
grant execute on function private.authz_authorize(text, uuid),
  private.api042_command(text, uuid, jsonb, uuid, bigint)
to studafy_api_runtime;

revoke all privileges on all tables in schema public from studafy_api_runtime;
revoke all privileges on all sequences in schema public from studafy_api_runtime;
