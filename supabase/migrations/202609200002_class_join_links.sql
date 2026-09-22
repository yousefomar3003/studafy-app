-- Shareable class join links (JOIN-052).
--
-- A teacher creates one link per class and shares it; anyone who opens it
-- joins that class as a student. This is deliberately not an invitation:
-- public.invitations is addressed to one email, carries the granted role in
-- its body and is consumed once. A join link names no recipient, always
-- grants 'student', and is redeemed many times until it expires, is revoked
-- or reaches its use budget.
--
-- The link is only ever stored as a SHA-256 hash, exactly as invitations
-- store theirs: whoever holds the plaintext can join the class, so the
-- database must not be able to hand it out.

create type public.class_join_link_status as enum ('active', 'revoked', 'expired');

create table public.class_join_links (
  id uuid primary key default gen_random_uuid(),
  school_id uuid not null references public.schools(id) on delete cascade,
  classroom_id uuid not null,
  token_hash text not null unique,
  created_by uuid not null references public.profiles(id) on delete restrict,
  status public.class_join_link_status not null default 'active',
  expires_at timestamptz not null,
  -- Null means "no cap": the link stays usable until it expires or is
  -- revoked. A cap lets a teacher size the link to a known class roster.
  max_uses integer,
  use_count integer not null default 0,
  revoked_by uuid references public.profiles(id) on delete restrict,
  revoked_at timestamptz,
  version bigint not null default 1,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint class_join_links_classroom_school_fk
    foreign key (school_id, classroom_id)
    references public.classrooms(school_id, id) on delete cascade,
  constraint class_join_links_use_count_check check (use_count >= 0),
  constraint class_join_links_max_uses_check
    check (max_uses is null or max_uses > 0),
  constraint class_join_links_revoked_check
    check ((status = 'revoked') = (revoked_at is not null))
);

-- One live link per class. A teacher who creates a second link supersedes
-- the first rather than leaving two valid ways into the same room.
create unique index class_join_links_one_active
  on public.class_join_links (classroom_id) where status = 'active';

create index class_join_links_school_classroom
  on public.class_join_links (school_id, classroom_id);

-- Mirrors every other tenant table: row security on, no policy, so only the
-- SECURITY DEFINER surface below can read or write it.
alter table public.class_join_links enable row level security;

-- ---------------------------------------------------------------------------
-- Read model
-- ---------------------------------------------------------------------------

-- Never returns token_hash. The plaintext is shown once, at creation, and is
-- unrecoverable afterwards; a teacher who loses it creates a new link.
create or replace function private.class_join_link_json(p_id uuid)
returns jsonb
language sql
stable
security definer
set search_path to ''
as $function$
  select jsonb_build_object(
    'id', l.id,
    'schoolId', l.school_id,
    'classroomId', l.classroom_id,
    'classroomName', c.name,
    'status', l.status,
    'expiresAt', l.expires_at,
    'maxUses', l.max_uses,
    'useCount', l.use_count,
    'createdAt', l.created_at,
    'version', l.version
  )
  from public.class_join_links l
  join public.classrooms c on c.id = l.classroom_id
  where l.id = p_id;
$function$;

-- ---------------------------------------------------------------------------
-- Query surface
-- ---------------------------------------------------------------------------

create or replace function private.api044_query(
  p_operation text,
  p_resource_id uuid,
  p_input jsonb
)
returns jsonb
language plpgsql
stable
security definer
set search_path to ''
as $function$
declare
  tenant uuid := nullif(current_setting('studafy.school_id', true), '')::uuid;
  link_id uuid;
begin
  if auth.uid() is null or tenant is null then return null; end if;

  case p_operation
    when 'getClassJoinLink' then
      -- Only the staff of that classroom may look at its link.
      if not private.is_class_staff(p_resource_id) then return null; end if;
      select l.id into link_id
      from public.class_join_links l
      where l.classroom_id = p_resource_id and l.school_id = tenant
        and l.status = 'active';
      if link_id is null then
        return jsonb_build_object('outcome', 'not_found');
      end if;
      return private.class_join_link_json(link_id);
    else return null;
  end case;
end;
$function$;

-- ---------------------------------------------------------------------------
-- Command surface
-- ---------------------------------------------------------------------------

create or replace function private.api044_command(
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
  tenant uuid := nullif(current_setting('studafy.school_id', true), '')::uuid;
  request_id text := nullif(current_setting('studafy.request_id', true), '');
  body jsonb := coalesce(p_input->'body', '{}'::jsonb);
  idem_key text;
  entity_id uuid; entity_type text; audit_action text;
  response jsonb; before_value jsonb;
  v_link public.class_join_links;
  v_classroom_id uuid; v_school uuid;
  v_student_id uuid; v_membership_id uuid;
  v_display_name text;
  v_expires timestamptz;
  v_max_uses integer;
begin
  if auth.uid() is null or request_id is null then
    return jsonb_build_object('outcome', 'forbidden');
  end if;

  select r.idempotency_key into idem_key
  from public.idempotency_records r
  where r.id = p_idempotency_id and r.actor_id = auth.uid()
    and r.school_id is not distinct from tenant
    and r.generation = p_idempotency_generation and r.status = 'reserved'
  for update;
  if idem_key is null then
    return jsonb_build_object('outcome', 'forbidden');
  end if;

  case p_operation

    when 'createClassJoinLink' then
      v_classroom_id := p_resource_id;
      -- Creating a way into a class is a teaching act, so it is bound to the
      -- classroom's own staff rather than to a school-wide role.
      if not private.is_class_staff(v_classroom_id) then
        return jsonb_build_object('outcome', 'forbidden');
      end if;
      select c.school_id into v_school
      from public.classrooms c
      where c.id = v_classroom_id and c.school_id = tenant;
      if v_school is null then
        return jsonb_build_object('outcome', 'not_found');
      end if;

      v_expires := coalesce(
        nullif(body->>'expiresAt', '')::timestamptz, now() + interval '30 days'
      );
      if v_expires <= now() then
        return jsonb_build_object('outcome', 'invalid');
      end if;
      v_max_uses := nullif(body->>'maxUses', '')::integer;
      if v_max_uses is not null and v_max_uses <= 0 then
        return jsonb_build_object('outcome', 'invalid');
      end if;

      -- Supersede whatever was live, keeping one way in per class.
      update public.class_join_links
      set status = 'revoked', revoked_by = auth.uid(), revoked_at = now(),
          version = version + 1, updated_at = now()
      where classroom_id = v_classroom_id and status = 'active';

      insert into public.class_join_links(
        school_id, classroom_id, token_hash, created_by, status,
        expires_at, max_uses
      ) values (
        tenant, v_classroom_id, body->>'tokenHash', auth.uid(), 'active',
        v_expires, v_max_uses
      ) returning id into entity_id;

      response := private.class_join_link_json(entity_id);
      entity_type := 'class_join_link'; audit_action := 'class_join_link_created';

    when 'revokeClassJoinLink' then
      select l.* into v_link
      from public.class_join_links l where l.id = p_resource_id for update;
      if v_link.id is null then
        return jsonb_build_object('outcome', 'not_found');
      end if;
      if v_link.school_id <> tenant then
        return jsonb_build_object('outcome', 'forbidden');
      end if;
      if not private.is_class_staff(v_link.classroom_id) then
        return jsonb_build_object('outcome', 'forbidden');
      end if;
      if v_link.status <> 'active' then
        return jsonb_build_object('outcome', 'invalid_state');
      end if;
      before_value := to_jsonb(v_link);
      update public.class_join_links
      set status = 'revoked', revoked_by = auth.uid(), revoked_at = now(),
          version = version + 1, updated_at = now()
      where id = p_resource_id;
      entity_id := p_resource_id;
      response := private.class_join_link_json(entity_id);
      entity_type := 'class_join_link'; audit_action := 'class_join_link_revoked';

    when 'redeemClassJoinLink' then
      -- Redemption is open to any signed-in account: the holder of the link
      -- is by definition not yet a member, so no membership can be required
      -- to reach this branch. The token is the whole credential, which is why
      -- it is budgeted and expiring.
      select l.* into v_link
      from public.class_join_links l
      where l.token_hash = body->>'tokenHash' for update;
      if v_link.id is null then
        return jsonb_build_object('outcome', 'not_found');
      end if;
      if v_link.status <> 'active' or v_link.expires_at <= now() then
        -- Fold an expired-but-still-active row over as it is observed, so a
        -- dead link stops being live without waiting for a scheduled job.
        if v_link.status = 'active' then
          update public.class_join_links
          set status = 'expired', version = version + 1, updated_at = now()
          where id = v_link.id;
        end if;
        return jsonb_build_object('outcome', 'invalid_state');
      end if;
      if v_link.max_uses is not null and v_link.use_count >= v_link.max_uses then
        update public.class_join_links
        set status = 'expired', version = version + 1, updated_at = now()
        where id = v_link.id;
        return jsonb_build_object('outcome', 'invalid_state');
      end if;

      v_school := v_link.school_id;
      v_classroom_id := v_link.classroom_id;

      -- A teacher of this school must not be demoted into its student body
      -- by opening the link they shared.
      if exists (
        select 1 from public.memberships m
        where m.school_id = v_school and m.user_id = auth.uid()
          and m.active and m.status = 'active' and m.role <> 'student'
      ) then
        return jsonb_build_object('outcome', 'forbidden');
      end if;

      select p.display_name into v_display_name
      from public.profiles p where p.id = auth.uid();

      select m.id into v_membership_id
      from public.memberships m
      where m.school_id = v_school and m.user_id = auth.uid()
        and m.role = 'student';
      if v_membership_id is null then
        insert into public.memberships(
          school_id, user_id, role, active, status, version
        ) values (v_school, auth.uid(), 'student', true, 'active', 1)
        returning id into v_membership_id;
        insert into public.membership_events(
          school_id, membership_id, actor_id, event_type, reason, idempotency_key
        ) values (
          v_school, v_membership_id, auth.uid(), 'granted',
          'class_join_link_redeemed', idem_key
        );
      else
        update public.memberships
        set active = true, status = 'active', version = version + 1,
            updated_at = now()
        where id = v_membership_id and (not active or status <> 'active');
      end if;

      -- Enrollment needs a students row; a self-joining student has none, so
      -- one is created for them rather than requiring an administrator to
      -- pre-register every arrival.
      select s.id into v_student_id
      from public.students s
      where s.school_id = v_school and s.user_id = auth.uid()
        and s.deleted_at is null;
      if v_student_id is null then
        insert into public.students(
          school_id, user_id, studafy_id, display_name, provisional, created_by
        ) values (
          v_school, auth.uid(),
          'SJ-' || upper(substring(replace(gen_random_uuid()::text, '-', '') for 10)),
          coalesce(v_display_name, 'Student'), true, auth.uid()
        ) returning id into v_student_id;
      end if;

      if exists (
        select 1 from public.enrollments e
        where e.classroom_id = v_classroom_id and e.student_id = v_student_id
          and e.active
      ) then
        -- Already in the room. Report it plainly instead of counting another
        -- use against the budget for someone who opened the link twice.
        return jsonb_build_object('outcome', 'invalid_state');
      end if;

      insert into public.enrollments(
        classroom_id, student_id, active, school_id, status, starts_on
      ) values (
        v_classroom_id, v_student_id, true, v_school, 'active', current_date
      );

      update public.class_join_links
      set use_count = use_count + 1, version = version + 1, updated_at = now()
      where id = v_link.id;

      entity_id := v_membership_id;
      entity_type := 'membership';
      audit_action := 'class_join_link_redeemed';
      response := private.class_join_link_json(v_link.id);
      tenant := v_school;

    else return jsonb_build_object('outcome', 'invalid');
  end case;

  insert into public.audit_events(
    school_id, actor_id, action, entity_type, entity_id,
    before_value, after_value, request_id
  ) values (
    tenant, auth.uid(), audit_action, entity_type, entity_id,
    before_value, response, request_id
  );

  return jsonb_build_object('outcome', 'ok', 'response', response);
end;
$function$;

-- ---------------------------------------------------------------------------
-- AUTH-031 decision surface
-- ---------------------------------------------------------------------------
--
-- The resource-scoped permissions above are resolved by private.authz_authorize
-- before any handler runs. An action it does not recognise is denied, and for a
-- concealed resource that denial surfaces as 404, so registering them here is
-- what makes the routes reachable at all.
--
-- Chained exactly as FILE-051 chained its predecessor: the previous generation
-- is preserved under a new name and called for every action this one does not
-- own, so no earlier decision changes.

create or replace function private.authz_authorize_pre_join052(
  p_action text, p_resource_id uuid
)
returns jsonb
language plpgsql
stable
security definer
set search_path to ''
as $function$
declare sid uuid; allowed boolean := false;
begin
  -- Carries forward the classroom.create decision granted in
  -- 202609200001. Preserving the previous generation means preserving what
  -- it decided, not the generation before it.
  if p_action <> 'classroom.create' then
    return private.authz_authorize_pre_teacher_class(p_action, p_resource_id);
  end if;
  if auth.uid() is null or p_resource_id is null then
    return jsonb_build_object('allowed', false, 'school_id', null, 'reason', 'invalid_resource');
  end if;
  select s.id,
    private.has_active_membership(
      s.id, array['teacher','school_admin']::public.app_role[])
  into sid, allowed
  from public.schools s where s.id = p_resource_id;
  return jsonb_build_object('allowed', coalesce(allowed, false), 'school_id', sid,
    'reason', case when sid is null then 'invalid_resource' when allowed then 'allowed' else 'denied' end);
end;
$function$;

create or replace function private.authz_authorize(
  p_action text, p_resource_id uuid
)
returns jsonb
language plpgsql
stable
security definer
set search_path to ''
as $function$
declare sid uuid; allowed boolean := false; cls uuid;
begin
  if p_action not in (
    'classJoinLink.create', 'classJoinLink.read', 'classJoinLink.revoke'
  ) then
    return private.authz_authorize_pre_join052(p_action, p_resource_id);
  end if;
  if auth.uid() is null or p_resource_id is null then
    return jsonb_build_object('allowed', false, 'school_id', null, 'reason', 'invalid_resource');
  end if;

  if p_action = 'classJoinLink.revoke' then
    -- The resource is the link; the decision is about the room it opens.
    select l.school_id, l.classroom_id into sid, cls
    from public.class_join_links l where l.id = p_resource_id;
  else
    select c.school_id, c.id into sid, cls
    from public.classrooms c where c.id = p_resource_id;
  end if;

  if cls is null then
    return jsonb_build_object('allowed', false, 'school_id', null, 'reason', 'invalid_resource');
  end if;

  -- Bound to the classroom's own staff, not to a school-wide role: handing
  -- out a way into a room is a teaching act.
  allowed := private.is_class_staff(cls);
  return jsonb_build_object('allowed', coalesce(allowed, false), 'school_id', sid,
    'reason', case when allowed then 'allowed' else 'denied' end);
end;
$function$;
