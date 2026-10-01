-- One Studafy ID per student (2026-10-01).
--
-- A student record belongs to one school, and in this release every
-- teacher's space is a school of its own. A student who joined classes from
-- two teachers therefore had two records - each with its own Studafy ID -
-- and saw two IDs on their profile, while a parent needed the right one for
-- the right teacher. The ID now belongs to the child:
--
--   * every school record of the same account carries the same ID - the
--     ID of their oldest record - and existing duplicates are merged onto it;
--   * any new record for that account (a class join, a teacher adding them,
--     a managed child joining) takes it, whichever path creates the row;
--   * an ID is never shared with another account, nor with a record that
--     has no account;
--   * a parent's lookup by ID finds the child's oldest live record. Once the
--     child approves, the link already follows them to every school
--     (202609270002), so one ID and one approval cover all their classes.
--
-- Records with no account (a child added by a teacher, not yet signed up)
-- keep an ID of their own until they are tied to an account. Guardian links
-- point at records, not IDs, so none of them changes here.

-- An ID was unique per row. It is now shared by one child's records, so
-- uniqueness moves to the trigger below: one ID, one child. (A school can
-- hold two records of the same child - an admin adding an account that
-- already joined a class - and both carry the child's one ID.)
alter table public.students drop constraint if exists students_studafy_id_key;

-- Merge: each account's records take the ID of its oldest live record (the
-- oldest of any, if none is live).
with keep as (
  select distinct on (st.user_id) st.user_id, st.studafy_id
  from public.students st
  where st.user_id is not null
  order by st.user_id, (st.deleted_at is not null), st.created_at, st.id
)
update public.students st set studafy_id = keep.studafy_id
from keep
where st.user_id = keep.user_id and st.studafy_id <> keep.studafy_id;

-- The parent's lookup reads by ID alone.
create index if not exists students_studafy_id_idx
  on public.students (studafy_id);

-- Every path that writes a student row passes here.
create or replace function private.student_keeps_one_studafy_id()
returns trigger language plpgsql security definer set search_path = '' as $$
declare
  existing text;
begin
  if new.user_id is not null then
    -- Two joins by the same child at the same moment must not mint two
    -- IDs: they queue on the account.
    perform pg_advisory_xact_lock(
      hashtextextended('studafy_id:' || new.user_id::text, 0));
    select st.studafy_id into existing
    from public.students st
    where st.user_id = new.user_id and st.id <> new.id
    order by (st.deleted_at is not null), st.created_at, st.id
    limit 1;
    if existing is not null then
      new.studafy_id := existing;
    end if;
  end if;
  -- An ID belongs to one child: never another account's, and never shared
  -- by a record that has no account.
  if exists (
    select 1 from public.students st
    where st.studafy_id = new.studafy_id and st.id <> new.id
      and (new.user_id is null or st.user_id is distinct from new.user_id)
  ) then
    raise exception using errcode = '23505',
      message = 'A Studafy ID belongs to one student';
  end if;
  return new;
end;
$$;

alter function private.student_keeps_one_studafy_id() owner to postgres;
revoke all on function private.student_keeps_one_studafy_id()
  from public, anon, authenticated, service_role, studafy_api_runtime,
  studafy_worker_runtime;

drop trigger if exists student_keeps_one_studafy_id on public.students;
create trigger student_keeps_one_studafy_id
before insert or update of user_id, studafy_id on public.students
for each row execute function private.student_keeps_one_studafy_id();

-- The student's own family view: the ID once, and each parent once.
-- Re-issued from 202609280002; otherwise unchanged.
CREATE OR REPLACE FUNCTION private.ops_query_student_family(p_operation text, p_resource_id uuid, p_input jsonb)
 RETURNS jsonb
 LANGUAGE plpgsql
 STABLE SECURITY DEFINER
 SET search_path TO ''
AS $function$
declare actor uuid := auth.uid(); ids jsonb; links jsonb;
begin

  if actor is null or not private.is_active_user() then return jsonb_build_object('outcome','forbidden'); end if;
  -- One identity per Studafy ID - which is now one per child - from the
  -- child's oldest live record, however many schools they are in.
  select coalesce(jsonb_agg(jsonb_build_object('id',x.id,'studafyId',x.studafy_id,'displayName',x.display_name) order by x.created_at, x.id),'[]') into ids
  from (
    select distinct on (s.studafy_id) s.id, s.studafy_id, s.display_name, s.created_at
    from public.students s where s.user_id=actor and s.deleted_at is null
    order by s.studafy_id, s.created_at, s.id
  ) x;
  -- A verified link is mirrored onto each school record of the child, so
  -- each parent is listed once: their most recently changed link.
  select coalesce(jsonb_agg(jsonb_build_object('id',x.id,'guardianId',x.guardian_id,'guardianName',x.display_name,'studentId',x.student_id,'relationship',x.relationship,'status',x.status) order by x.updated_at desc,x.id),'[]') into links
  from (
    select distinct on (g.guardian_id) g.id, g.guardian_id, p.display_name, g.student_id, g.relationship, g.status, g.updated_at
    from public.guardian_links g join public.students s on s.id=g.student_id
    join public.profiles p on p.id=g.guardian_id and p.status='active'
    where s.user_id=actor and s.deleted_at is null
    order by g.guardian_id, g.updated_at desc, g.id
  ) x;
  return jsonb_build_object('studentIds',ids,'requests',links);
end;
$function$;

-- The family link commands, re-issued from 202609290006 with a lookup that
-- finds one live record for an ID shared by several; otherwise unchanged.
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

-- Adding a student: the response carries the ID the record actually has,
-- which is the child's existing one when they already have an account with
-- an ID. Re-issued from 202609280003; otherwise unchanged.
CREATE OR REPLACE FUNCTION private.ops_command_roster_create(p_operation text, p_resource_id uuid, p_input jsonb, p_idempotency_id uuid, p_idempotency_generation bigint)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
declare
  tenant uuid := nullif(current_setting('studafy.school_id', true), '')::uuid;
  request_id text := nullif(current_setting('studafy.request_id', true), '');
  req_body jsonb := coalesce(p_input->'body', '{}'::jsonb);
  response jsonb;
  entity_id uuid; entity_type text; audit_action text;
  idem_key text; v_user_id uuid; v_studafy_id text; v_provisional boolean;
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
  if not private.is_school_admin(tenant) then return jsonb_build_object('outcome', 'forbidden'); end if;

  case p_operation
    when 'createTerm' then
      insert into public.terms(school_id, name, starts_on, ends_on, status, active)
      values (
        tenant, req_body->>'name', (req_body->>'startsOn')::date, (req_body->>'endsOn')::date,
        'active', true
      ) returning id into entity_id;
      response := jsonb_build_object(
        'id', entity_id, 'schoolId', tenant, 'name', req_body->>'name',
        'startsOn', req_body->>'startsOn', 'endsOn', req_body->>'endsOn', 'status', 'active'
      );
      entity_type := 'term'; audit_action := 'term_created';
      outbox_template := null; outbox_entity := null;

    when 'createStudent' then
      v_user_id := nullif(req_body->>'userId', '')::uuid;
      if v_user_id is not null and not exists (select 1 from public.profiles p where p.id = v_user_id) then
        return jsonb_build_object('outcome', 'invalid');
      end if;
      v_provisional := v_user_id is null;
      -- Opaque, server-generated locator - never client-selected. Replaces
      -- the class of hard-coded/predictable studafy_id this schema's own
      -- design already forbids (see supabase/tests/api042_family.sql and
      -- the S3 locateStudent rate-limit posture it shares this table with).
      v_studafy_id := 'STU-' || upper(substr(replace(gen_random_uuid()::text, '-', ''), 1, 10));
      insert into public.students(school_id, user_id, studafy_id, display_name, provisional, created_by)
      values (tenant, v_user_id, v_studafy_id, req_body->>'displayName', v_provisional, auth.uid())
      -- A child who already has a Studafy ID keeps it; the row says which.
      returning id, studafy_id into entity_id, v_studafy_id;
      response := jsonb_build_object(
        'id', entity_id, 'schoolId', tenant, 'userId', v_user_id,
        'studafyId', v_studafy_id, 'displayName', req_body->>'displayName', 'provisional', v_provisional
      );
      entity_type := 'student'; audit_action := 'student_created';
      outbox_template := null; outbox_entity := null;

    else return jsonb_build_object('outcome', 'invalid');
  end case;

  insert into public.audit_events(school_id, actor_id, action, entity_type, entity_id, before_value, after_value, request_id)
  values (tenant, auth.uid(), audit_action, entity_type, entity_id, null, response, request_id);
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
