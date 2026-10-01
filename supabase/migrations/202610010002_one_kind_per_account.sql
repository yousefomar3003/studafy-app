-- One kind of account per email (2026-10-01).
--
-- Signing in through another role's door used to carry an account into that
-- role: a student who tapped "Teacher" was walked into teacher setup, and a
-- teacher who tapped "Student" could join a class as a pupil. The email's
-- earlier role was still there, but nothing in the app led back to it.
--
-- The rule the owner chose:
--
--   * a student account is a student only - never a teacher, never a
--     parent - because it is a child's account;
--   * an adult account may be a teacher, a parent, or both, and switches
--     between them;
--   * nothing else combines.
--
-- private.account_kind says which an account is: 'student', 'adult', or
-- null for an account nothing has decided yet (signed up, no class, no
-- child). It reads what the account already has - memberships, student
-- records, links to children - and otherwise the kind recorded once on the
-- profile when the person first signed in. The app reads it with the
-- profile and sends a person who came in through the wrong door to their
-- own role; the server refuses each way a role is gained against it:
-- teacher setup, joining a class, asking to link to a child, and - as a
-- backstop for every other path - the memberships and guardian_links tables
-- themselves. Nothing that already exists is removed or changed.

alter table public.profiles
  add column if not exists account_kind text
    check (account_kind in ('student', 'adult'));

create or replace function private.account_kind(p_user uuid)
returns text language sql stable security definer set search_path = '' as $$
  select case
    -- Staff anywhere, or a parent of anyone: an adult.
    when exists (
      select 1 from public.memberships m
      where m.user_id = p_user and m.active and m.status = 'active'
        and m.role <> 'student')
      or exists (
      select 1 from public.guardian_links g
      where g.guardian_id = p_user and g.status in ('pending', 'verified'))
      then 'adult'
    -- In a class, or on a class list: a student.
    when exists (
      select 1 from public.memberships m
      where m.user_id = p_user and m.active and m.status = 'active'
        and m.role = 'student')
      or exists (
      select 1 from public.students s
      where s.user_id = p_user and s.deleted_at is null)
      then 'student'
    -- Otherwise what was recorded when they first signed in, if anything.
    else (select p.account_kind from public.profiles p where p.id = p_user)
  end;
$$;

alter function private.account_kind(uuid) owner to postgres;
revoke all on function private.account_kind(uuid)
  from public, anon, authenticated, service_role, studafy_api_runtime,
  studafy_worker_runtime;

-- The profile tells the app which kind the account is.
create or replace function private.profile_json(p_user uuid)
returns jsonb language sql stable security definer set search_path = '' as $$
  select jsonb_build_object(
    'id', p.id,
    'displayName', p.display_name,
    'locale', p.locale,
    'gender', p.gender,
    'setupComplete', p.profile_completed_at is not null,
    'accountKind', private.account_kind(p.id))
  from public.profiles p where p.id = p_user;
$$;

-- Recording the kind: the app sends it once, for an undecided account, with
-- the role the person signed in as. Re-issued from 202609300006; otherwise
-- unchanged.
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
      if (req_body->>'accountKind') is not null
         and (req_body->>'accountKind') not in ('student', 'adult') then
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
        -- Recorded once, for an account nothing else has decided yet. After
        -- that the kind is the account's, and asking again changes nothing.
        account_kind = case
          when account_kind is null and private.account_kind(auth.uid()) is null
            then req_body->>'accountKind'
          else account_kind end,
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

-- Teacher setup: never for a student account. Re-issued from
-- 202609240001 with that check first; otherwise unchanged.
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
      -- One kind of account per email: a student account never teaches.
      if private.account_kind(auth.uid()) = 'student' then
        return jsonb_build_object('outcome', 'invalid_state');
      end if;
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

-- Joining a class (by link or code): never for an adult account.
-- Re-issued from 202609270004 with that check first; otherwise unchanged.
create or replace function private.api044_command(
  p_operation text, p_resource_id uuid, p_input jsonb,
  p_idempotency_id uuid, p_idempotency_generation bigint)
returns jsonb language plpgsql security definer set search_path = '' as $$
declare
  v_salt text := nullif((p_input->'body')->>'derivationSalt', '');
  result jsonb;
begin
  -- One kind of account per email: an adult account never joins a class as
  -- a pupil, by link or by code.
  if p_operation = 'redeemClassJoinLink'
     and private.account_kind(auth.uid()) = 'adult' then
    return jsonb_build_object('outcome', 'forbidden');
  end if;
  result := private.api044_command_pre_salt(
    p_operation, p_resource_id,
    -- The delegate's body is strict about what it reads; the salt is this
    -- wrapper's alone.
    case when p_input ? 'body'
      then jsonb_set(p_input, array['body'], (p_input->'body') - 'derivationSalt')
      else p_input end,
    p_idempotency_id, p_idempotency_generation);
  if p_operation = 'createClassJoinLink' and v_salt is not null
    and coalesce(result->>'outcome', '') = 'ok' then
    update public.class_join_links set derivation_salt = v_salt
    where id = ((result->'response')->>'id')::uuid;
  end if;
  return result;
end;
$$;

alter function private.api044_command(text, uuid, jsonb, uuid, bigint)
  owner to postgres;
revoke all on function private.api044_command(text, uuid, jsonb, uuid, bigint)
  from public, anon, authenticated, service_role, studafy_worker_runtime;
grant execute on function private.api044_command(
  text, uuid, jsonb, uuid, bigint) to studafy_api_runtime;

-- Finding and linking to a child: adults only. Re-issued from
-- 202610010001 with that check first; otherwise unchanged.
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

  -- A student account cannot be anyone's parent: finding a child and asking
  -- to link are for adults only.
  if p_operation in ('locateStudent', 'requestGuardianLink')
     and private.account_kind(auth.uid()) = 'student' then
    return jsonb_build_object('outcome', 'forbidden');
  end if;

  case p_operation
    when 'locateStudent' then
      select count(*) into v_recent_attempts from public.audit_events
      where actor_id = auth.uid() and action = 'student_locate_attempted' and created_at > now() - interval '1 hour';
      if v_recent_attempts >= 10 then return jsonb_build_object('outcome', 'invalid_state'); end if;
      -- One ID is shared by every school record of the same child, so the
      -- oldest live record answers - the same child whichever it is, and a
      -- deleted record is never the one found.
      select st.id, st.school_id into v_student_id, resolved_school
      from public.students st
      where st.studafy_id = body->>'studafyId' and st.deleted_at is null
      order by st.created_at, st.id
      limit 1;
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

-- Backstops: whatever path writes a role, the tables keep the rule.
create or replace function private.membership_keeps_account_kind()
returns trigger language plpgsql security definer set search_path = '' as $$
declare
  v_kind text;
begin
  if not (new.active and new.status = 'active') then return new; end if;
  if tg_op = 'UPDATE' and old.active and old.status = 'active'
     and old.role = new.role and old.user_id = new.user_id then
    return new;
  end if;
  v_kind := private.account_kind(new.user_id);
  if new.role = 'student' and v_kind = 'adult' then
    raise exception using errcode = '23514',
      message = 'An adult account cannot be a student';
  end if;
  if new.role <> 'student' and v_kind = 'student' then
    raise exception using errcode = '23514',
      message = 'A student account cannot hold another role';
  end if;
  return new;
end;
$$;

alter function private.membership_keeps_account_kind() owner to postgres;
revoke all on function private.membership_keeps_account_kind()
  from public, anon, authenticated, service_role, studafy_api_runtime,
  studafy_worker_runtime;

drop trigger if exists membership_keeps_account_kind on public.memberships;
create trigger membership_keeps_account_kind
before insert or update of role, active, status, user_id on public.memberships
for each row execute function private.membership_keeps_account_kind();

create or replace function private.guardian_keeps_account_kind()
returns trigger language plpgsql security definer set search_path = '' as $$
begin
  if tg_op = 'UPDATE' and new.guardian_id = old.guardian_id then
    return new;
  end if;
  if private.account_kind(new.guardian_id) = 'student' then
    raise exception using errcode = '23514',
      message = 'A student account cannot be a parent';
  end if;
  return new;
end;
$$;

alter function private.guardian_keeps_account_kind() owner to postgres;
revoke all on function private.guardian_keeps_account_kind()
  from public, anon, authenticated, service_role, studafy_api_runtime,
  studafy_worker_runtime;

-- Named to run after guardian_link_requires_student (triggers fire in name
-- order), so a link to oneself is still refused as that one explains.
drop trigger if exists guardian_parent_is_adult on public.guardian_links;
create trigger guardian_parent_is_adult
before insert or update of guardian_id on public.guardian_links
for each row execute function private.guardian_keeps_account_kind();
