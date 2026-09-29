-- Managed child accounts (2026-09-28).
--
-- Young children have no email and no phone, so they cannot sign in to
-- anything. Until now a parent acted *for* such a child without the child
-- having an account (202609250003_guardian_child_mode.sql). The owner asked
-- for more: the parent creates a real student account for the child from
-- their own account, and switches into it the way Instagram switches
-- accounts, with the app showing that it is a sub-account.
--
-- The account itself is created by the API through Supabase Auth, with an
-- address under the reserved `.invalid` domain so no mail can ever reach it,
-- and with the guardian's id in its app metadata - which only the service
-- role can write. This migration holds the rest:
--
--   * private.managed_accounts - which account manages which child;
--   * a verified guardian link for the managing parent at every school the
--     child joins, so the parent's own view of the child works as for any
--     linked child;
--   * private.api048_managed_accounts - list, register, and authorise a
--     sign-in, each re-deriving the caller from auth.uid().
--
-- A managed account manages nobody, and neither does a student. A child
-- cannot create accounts or sign in as anyone, whatever the client sends.

create table if not exists private.managed_accounts (
  child_id uuid primary key references public.profiles(id) on delete cascade,
  guardian_id uuid not null references public.profiles(id) on delete cascade,
  created_at timestamptz not null default now(),
  check (child_id <> guardian_id)
);

create index if not exists managed_accounts_guardian_idx
  on private.managed_accounts (guardian_id);

revoke all on private.managed_accounts
  from public, anon, authenticated, service_role, studafy_api_runtime,
  studafy_worker_runtime;

-- How many children one account may manage. A family, not a school.
create or replace function private.managed_account_limit()
returns integer language sql immutable set search_path = '' as $$ select 6 $$;

revoke all on function private.managed_account_limit()
  from public, anon, authenticated, service_role, studafy_worker_runtime,
  studafy_api_runtime;
alter function private.managed_account_limit() owner to postgres;

-- ---------------------------------------------------------------------------
-- The managing parent is a verified guardian wherever the child studies.
--
-- The child joins a class like any student, which creates their students
-- row at that school. The parent who made the account is already the adult
-- responsible for it, so the link is verified at once rather than waiting
-- for a child who cannot read to approve it. An existing link is left as it
-- is: a school that revoked one has decided, and this must not undo that.
-- ---------------------------------------------------------------------------
create or replace function private.managed_child_links_guardian()
returns trigger language plpgsql security definer set search_path = '' as $$
declare
  v_guardian uuid;
begin
  if new.user_id is null or new.deleted_at is not null then return null; end if;
  if tg_op = 'UPDATE' and old.user_id is not distinct from new.user_id then
    return null;
  end if;
  select m.guardian_id into v_guardian
  from private.managed_accounts m where m.child_id = new.user_id;
  if v_guardian is null then return null; end if;

  insert into public.guardian_links(
    school_id, student_id, guardian_id, status, relationship,
    verified_by, verified_at)
  values (new.school_id, new.id, v_guardian, 'verified', 'parent',
    v_guardian, now())
  on conflict (student_id, guardian_id) do nothing;

  if found then
    insert into public.audit_events(
      school_id, actor_id, action, entity_type, entity_id, after_value,
      request_id)
    values (new.school_id, v_guardian, 'managed_account_guardian_linked',
      'student', new.id, jsonb_build_object('childId', new.user_id),
      nullif(current_setting('studafy.request_id', true), ''));
  end if;
  return null;
end;
$$;

revoke all on function private.managed_child_links_guardian()
  from public, anon, authenticated, service_role, studafy_worker_runtime,
  studafy_api_runtime;
alter function private.managed_child_links_guardian() owner to postgres;

drop trigger if exists managed_child_links_guardian on public.students;
create trigger managed_child_links_guardian
after insert or update of user_id on public.students
for each row execute function private.managed_child_links_guardian();

-- Child accounts are a parent's to create. An account that is a student -
-- enrolled at any school, or holding a student membership - creates none,
-- whatever the app it is using shows.
create or replace function private.managed_account_caller_is_student(p_user uuid)
returns boolean language sql stable security definer set search_path = '' as $$
  select exists (
    select 1 from public.students st
    where st.user_id = p_user and st.deleted_at is null
  ) or exists (
    select 1 from public.memberships m
    where m.user_id = p_user and m.role = 'student' and m.active
  );
$$;

revoke all on function private.managed_account_caller_is_student(uuid)
  from public, anon, authenticated, service_role, studafy_worker_runtime,
  studafy_api_runtime;
alter function private.managed_account_caller_is_student(uuid) owner to postgres;

-- ---------------------------------------------------------------------------
-- The API's one entry point.
--
--   list               the caller's managed children
--   can_create         whether the caller may create one more
--   register           record a child account the API has just created
--   authorize_session  may the caller sign in as this child now
--
-- `register` trusts nothing from the request but the child's id, and checks
-- that id against auth.users: the account must be minutes old and carry the
-- caller as its guardian in app metadata, which only the service role can
-- write. A caller who names somebody else's account - or an old account of
-- their own - gets `invalid`, so this cannot be used to take over a user.
-- ---------------------------------------------------------------------------
create or replace function private.api048_managed_accounts(
  p_operation text, p_input jsonb)
returns jsonb language plpgsql security definer set search_path = '' as $$
declare
  v_caller uuid := auth.uid();
  v_child uuid;
  v_name text;
  v_count integer;
  v_version text;
  v_policy uuid;
  v_request text := nullif(current_setting('studafy.request_id', true), '');
begin
  if v_caller is null then
    return jsonb_build_object('outcome', 'forbidden');
  end if;
  if exists (
    select 1 from public.profiles p
    where p.id = v_caller and p.deleted_at is not null
  ) or exists (
    select 1 from private.managed_accounts m where m.child_id = v_caller
  ) then
    return jsonb_build_object('outcome', 'forbidden');
  end if;

  case p_operation
    when 'list' then
      return jsonb_build_object('outcome', 'ok', 'items', coalesce((
        select jsonb_agg(jsonb_build_object(
            'childId', m.child_id,
            'displayName', p.display_name,
            'createdAt', m.created_at)
          order by m.created_at, m.child_id)
        from private.managed_accounts m
        join public.profiles p on p.id = m.child_id
        where m.guardian_id = v_caller and p.deleted_at is null
      ), '[]'::jsonb));

    when 'can_create' then
      if private.managed_account_caller_is_student(v_caller) then
        return jsonb_build_object('outcome', 'forbidden');
      end if;
      select count(*) into v_count
      from private.managed_accounts m where m.guardian_id = v_caller;
      if v_count >= private.managed_account_limit() then
        return jsonb_build_object('outcome', 'limit_reached');
      end if;
      return jsonb_build_object('outcome', 'ok');

    when 'register' then
      if private.managed_account_caller_is_student(v_caller) then
        return jsonb_build_object('outcome', 'forbidden');
      end if;
      v_child := (p_input->>'childId')::uuid;
      if v_child is null or not exists (
        select 1 from auth.users u
        where u.id = v_child
          and u.raw_app_meta_data->>'studafy_managed_by' = v_caller::text
          and u.created_at > now() - interval '15 minutes'
      ) then
        return jsonb_build_object('outcome', 'invalid');
      end if;
      select p.display_name into v_name
      from public.profiles p where p.id = v_child and p.deleted_at is null;
      if v_name is null then
        return jsonb_build_object('outcome', 'invalid');
      end if;

      -- The parent accepted the terms for the child when creating the
      -- account. It is recorded on the child against a published policy
      -- only - the rule record_policy_consent applies - so a client cannot
      -- invent a version and have it stand as consent. Checked before any
      -- write: a refusal below this point would leave half a registration.
      v_version := p_input->>'policyVersion';
      select pol.id into v_policy
      from public.consent_policies pol
      where pol.purpose = 'terms_and_privacy'
        and pol.policy_version = v_version
        and pol.locale = p_input->>'locale'
        and pol.published_at <= now() and pol.effective_at <= now()
        and (pol.retired_at is null or pol.retired_at > now());
      if v_policy is null then
        return jsonb_build_object('outcome', 'invalid');
      end if;

      -- Serialise one guardian's registrations so two at once cannot both
      -- pass the limit.
      perform pg_advisory_xact_lock(hashtextextended(v_caller::text, 48));
      select count(*) into v_count
      from private.managed_accounts m where m.guardian_id = v_caller;
      if v_count >= private.managed_account_limit() then
        return jsonb_build_object('outcome', 'limit_reached');
      end if;

      insert into private.managed_accounts (child_id, guardian_id)
      values (v_child, v_caller)
      on conflict (child_id) do nothing;
      if not found then
        return jsonb_build_object('outcome', 'invalid');
      end if;

      insert into public.consent_records (
        user_id, purpose, policy_version, locale, accepted_at, withdrawn_at,
        policy_id)
      values (v_child, 'terms_and_privacy', v_version, p_input->>'locale',
        now(), null, v_policy)
      on conflict (user_id, purpose, policy_version) do nothing;

      insert into public.audit_events(
        school_id, actor_id, action, entity_type, entity_id, after_value,
        request_id)
      values (null, v_caller, 'managed_account_created', 'profile', v_child,
        jsonb_build_object('consentGivenByGuardian', v_version), v_request);

      return jsonb_build_object('outcome', 'ok',
        'childId', v_child, 'displayName', v_name,
        'createdAt', now());

    when 'authorize_session' then
      v_child := (p_input->>'childId')::uuid;
      if v_child is null or not exists (
        select 1 from private.managed_accounts m
        join public.profiles p on p.id = m.child_id
        where m.child_id = v_child and m.guardian_id = v_caller
          and p.deleted_at is null
      ) then
        -- Not "forbidden": whether an account exists is not the caller's to
        -- learn unless it is theirs.
        return jsonb_build_object('outcome', 'not_found');
      end if;
      insert into public.audit_events(
        school_id, actor_id, action, entity_type, entity_id, after_value,
        request_id)
      values (null, v_caller, 'managed_account_session_issued', 'profile',
        v_child, null, v_request);
      return jsonb_build_object('outcome', 'ok');

    else
      return jsonb_build_object('outcome', 'invalid');
  end case;
exception when invalid_text_representation then
  return jsonb_build_object('outcome', 'invalid');
end;
$$;

revoke all on function private.api048_managed_accounts(text, jsonb)
  from public, anon, authenticated, service_role, studafy_worker_runtime;
grant execute on function private.api048_managed_accounts(text, jsonb)
  to studafy_api_runtime;
alter function private.api048_managed_accounts(text, jsonb) owner to postgres;
