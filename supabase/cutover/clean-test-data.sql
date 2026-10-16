-- Launch-day cleanup of the owner's TEST schools from the shared Frankfurt
-- database (DL-064: production uses the project the test copy used).
--
-- This file is not a migration and changes nothing by itself. It defines
-- three session-local functions in pg_temp, which vanish when the session
-- ends. scripts/production/clean-test-data.ts loads it and calls them inside
-- one REPEATABLE READ transaction that it rolls back unless it was run with
-- `--execute --confirm-schools <ids>` (docs/deployment/production-cutover.md).
--
--   pg_temp.cutover_list_schools()            every school, to choose from
--   pg_temp.cutover_plan(ids, reviewer, holds) what would go, and refusals
--   pg_temp.cutover_clean(ids, reviewer, holds) does it, verifies, reports
--
-- What it removes, for exactly the named schools:
--   1. Their classes, through the retention schedule's own purge
--      (private.retention_purge_class): each class is closed and its records
--      go the way a class past its retention period goes.
--   2. Their test-only accounts, through the account-deletion executor
--      (private.account_deletion_execute): sign-in removed, profile
--      de-identified, personal data erased, exactly as an in-app deletion
--      after its grace period. An account is test-only when every tie it
--      has (membership, class staff, student record, guardian link, class
--      ownership, conversation, upload, notification) is to a named school, it is not a
--      platform operator, it is not a store reviewer account (unless the
--      reviewer school is named), it is under no legal hold, and every child
--      account it manages is test-only too.
--   3. Whatever school-scoped rows remain (the school's library, messages,
--      reports, audit rows, file records ...), then the school rows. The
--      append-only guards let these deletes through only because the table
--      owner runs them with studafy.retention_purge set for the transaction,
--      the same switch the retention purges use.
--
-- It never touches platform_operators, any school not named, or any account
-- with a tie outside the named schools. Before committing it compares a
-- fingerprint (md5 of every row) of everything kept - every school-scoped
-- table outside the named schools, the other schools, platform_operators,
-- and the profiles, auth users and managed-account links of every kept
-- account - and refuses if anything differs.
--
-- "Cedar Grove Review School" (the store reviewers' school,
-- scripts/provision-reviewer-school.ts), or any school with a reviewer
-- account in it, is refused unless the caller also passes the reviewer flag.
--
-- Storage bytes cannot be deleted from SQL (storage.protect_delete). The
-- clean function returns the bucket and key of every stored object of the
-- removed schools; the wrapper deletes them through the Storage API after
-- the commit, and saves the list first so a failed deletion can be retried.
--
-- Run it as `postgres` (the table owner): the private functions and the
-- append-only guards require it. No school administrator path is used.

create or replace function pg_temp.cutover_school_tables()
returns table (rel regclass, col text)
language sql stable as $$
  -- Every table holding a school's rows: a single-column foreign key to
  -- public.schools that cascades or restricts, and every table in public or
  -- private with a school_id column (enrollments, grades and the security
  -- log carry one without a direct foreign key). SET NULL references
  -- (private.inactive_account_warnings) belong to accounts, not schools.
  select distinct x.rel, x.col from (
    select c.conrelid::regclass as rel, a.attname::text as col
    from pg_constraint c
    join pg_attribute a on a.attrelid = c.conrelid and a.attnum = c.conkey[1]
    where c.contype = 'f' and c.confrelid = 'public.schools'::regclass
      and cardinality(c.conkey) = 1 and c.confdeltype in ('c', 'r', 'a')
    union
    select c.oid::regclass, a.attname::text
    from pg_class c
    join pg_namespace n on n.oid = c.relnamespace
    join pg_attribute a on a.attrelid = c.oid and a.attname = 'school_id'
      and not a.attisdropped
    where c.relkind in ('r', 'p') and n.nspname in ('public', 'private')
  ) x
  order by 1, 2;
$$;

create or replace function pg_temp.cutover_mask_email(p_email text)
returns text language sql immutable as $$
  select case
    when p_email is null or position('@' in p_email) < 2 then null
    else left(p_email, 1) || '***@' || split_part(p_email, '@', 2)
  end;
$$;

create or replace function pg_temp.cutover_is_reviewer_school(p_school_id uuid)
returns boolean language sql stable as $$
  select exists (
      select 1 from public.schools s
      where s.id = p_school_id
        and lower(btrim(s.name)) = lower('Cedar Grove Review School'))
    or exists (
      select 1 from public.memberships m
      join auth.users u on u.id = m.user_id
      where m.school_id = p_school_id
        and coalesce(u.raw_app_meta_data ->> 'studafy_reviewer', '') = 'true');
$$;

create or replace function pg_temp.cutover_list_schools()
returns jsonb language sql stable as $$
  select coalesce(jsonb_agg(jsonb_build_object(
      'id', s.id,
      'name', s.name,
      'status', s.status,
      'created_at', s.created_at,
      'members', (select count(distinct m.user_id) from public.memberships m where m.school_id = s.id),
      'classes', (select count(*) from public.classrooms c where c.school_id = s.id),
      'reviewer_school', pg_temp.cutover_is_reviewer_school(s.id))
    order by s.created_at, s.id), '[]'::jsonb)
  from public.schools s;
$$;

-- Every (account, school) tie that keeps an account in a school.
create or replace function pg_temp.cutover_ties()
returns table (user_id uuid, school_id uuid)
language sql stable as $$
  select m.user_id, m.school_id from public.memberships m
  union select cs.user_id, cs.school_id from public.classroom_staff cs
  union select st.user_id, st.school_id from public.students st where st.user_id is not null
  union select g.guardian_id, st.school_id from public.guardian_links g
    join public.students st on st.id = g.student_id
  union select c.teacher_id, c.school_id from public.classrooms c
  union select cp.user_id, cp.school_id from public.conversation_participants cp
  union select f.uploader_id, f.school_id from public.file_objects f
  union select f.owner_id, f.school_id from public.file_objects f where f.owner_id is not null
  union select u.uploader_id, u.school_id from public.upload_sessions u
  union select n.user_id, n.school_id from public.notifications n;
$$;

-- The accounts the named schools' removal would de-identify.
create or replace function pg_temp.cutover_test_accounts(p_school_ids uuid[], p_include_reviewer boolean)
returns table (user_id uuid)
language plpgsql stable as $$
begin
  return query
  with tied as (
    select distinct t.user_id from pg_temp.cutover_ties() t
    where t.school_id = any(p_school_ids) and t.user_id is not null
  ), only_here as (
    select t.user_id from tied t
    join public.profiles p on p.id = t.user_id and p.deleted_at is null
    where not exists (
        select 1 from pg_temp.cutover_ties() o
        where o.user_id = t.user_id and o.school_id <> all(p_school_ids))
      and not exists (select 1 from public.platform_operators po where po.user_id = t.user_id)
      and (p_include_reviewer or not exists (
        select 1 from auth.users u where u.id = t.user_id
          and coalesce(u.raw_app_meta_data ->> 'studafy_reviewer', '') = 'true'))
      and not exists (
        select 1 from public.legal_holds h
        where h.status = 'active' and (h.expires_at is null or h.expires_at > now())
          and h.subject_user_id = t.user_id and h.school_id <> all(p_school_ids))
  )
  -- A guardian goes only with every child account they manage: the
  -- executor deletes those children too.
  select o.user_id from only_here o
  where not exists (
    select 1 from private.managed_accounts ma
    where ma.guardian_id = o.user_id
      and ma.child_id not in (select x.user_id from only_here x)
      and exists (select 1 from public.profiles cp where cp.id = ma.child_id and cp.deleted_at is null));
end;
$$;

create or replace function pg_temp.cutover_school_row_counts(p_school_ids uuid[])
returns jsonb language plpgsql stable as $$
declare
  t record;
  n bigint;
  counts jsonb := '{}'::jsonb;
begin
  for t in select * from pg_temp.cutover_school_tables() loop
    execute format('select count(*) from %s where %I = any($1)', t.rel, t.col)
      into n using p_school_ids;
    if n > 0 then
      counts := counts || jsonb_build_object(t.rel::text, n);
    end if;
  end loop;
  return counts;
end;
$$;

-- An md5 of every row that must survive: school-scoped rows outside the
-- named schools, the other schools, platform_operators, and every kept
-- account's profile, auth user and managed-account links.
create or replace function pg_temp.cutover_fingerprint(p_school_ids uuid[], p_accounts uuid[])
returns jsonb language plpgsql stable as $$
declare
  t record;
  digest text;
  prints jsonb := '{}'::jsonb;
begin
  for t in select * from pg_temp.cutover_school_tables() loop
    execute format(
      'select md5(coalesce(string_agg(x::text, %L order by x::text), %L)) from %s x where x.%I is not null and x.%I <> all($1)',
      E'\n', '', t.rel, t.col, t.col)
      into digest using p_school_ids;
    prints := prints || jsonb_build_object(t.rel::text, digest);
  end loop;
  select md5(coalesce(string_agg(x::text, E'\n' order by x::text), '')) into digest
    from public.schools x where x.id <> all(p_school_ids);
  prints := prints || jsonb_build_object('public.schools', digest);
  select md5(coalesce(string_agg(x::text, E'\n' order by x::text), '')) into digest
    from public.platform_operators x;
  prints := prints || jsonb_build_object('public.platform_operators', digest);
  select md5(coalesce(string_agg(x::text, E'\n' order by x::text), '')) into digest
    from public.profiles x where x.id <> all(p_accounts);
  prints := prints || jsonb_build_object('public.profiles (kept accounts)', digest);
  select md5(coalesce(string_agg(x::text, E'\n' order by x::text), '')) into digest
    from auth.users x where x.id <> all(p_accounts);
  prints := prints || jsonb_build_object('auth.users (kept accounts)', digest);
  select md5(coalesce(string_agg(x::text, E'\n' order by x::text), '')) into digest
    from private.managed_accounts x
    where x.guardian_id <> all(p_accounts) and x.child_id <> all(p_accounts);
  prints := prints || jsonb_build_object('private.managed_accounts (kept accounts)', digest);
  return prints;
end;
$$;

-- What the removal of the named schools would do, and why it would refuse.
-- Raises CUTOVER_REFUSED for a request that must never run; returns the
-- blockers it can name otherwise.
create or replace function pg_temp.cutover_plan(
  p_school_ids uuid[], p_include_reviewer boolean, p_release_holds boolean)
returns jsonb language plpgsql stable as $$
declare
  v_unknown uuid[];
  v_reviewer jsonb;
  v_accounts uuid[];
  v_blockers jsonb := '[]'::jsonb;
  v_holds bigint;
  v_requests_held bigint;
begin
  if p_school_ids is null or cardinality(p_school_ids) = 0 then
    raise exception 'CUTOVER_REFUSED: name at least one school id';
  end if;
  if cardinality(p_school_ids) <> (select count(distinct x) from unnest(p_school_ids) x) then
    raise exception 'CUTOVER_REFUSED: a school id is named twice';
  end if;
  select array_agg(x) into v_unknown from unnest(p_school_ids) x
  where not exists (select 1 from public.schools s where s.id = x);
  if v_unknown is not null then
    raise exception 'CUTOVER_REFUSED: no school has id %', array_to_string(v_unknown, ', ');
  end if;
  select jsonb_agg(jsonb_build_object('id', s.id, 'name', s.name)) into v_reviewer
  from public.schools s
  where s.id = any(p_school_ids) and pg_temp.cutover_is_reviewer_school(s.id);
  if v_reviewer is not null and not p_include_reviewer then
    raise exception 'CUTOVER_REFUSED: % is the store reviewer school; it is removed only when also named with the reviewer flag', v_reviewer;
  end if;

  select coalesce(array_agg(a.user_id), '{}') into v_accounts
  from pg_temp.cutover_test_accounts(p_school_ids, p_include_reviewer) a;

  select count(*) into v_holds from public.legal_holds h
  where h.school_id = any(p_school_ids) and h.status = 'active'
    and (h.expires_at is null or h.expires_at > now());
  if v_holds > 0 and not p_release_holds then
    v_blockers := v_blockers || jsonb_build_array(format(
      '%s active legal hold(s) in these schools: release them in the app, or pass the release-holds flag to remove them with the schools', v_holds));
  end if;
  select count(*) into v_requests_held from public.account_deletion_requests r
  where r.user_id = any(v_accounts) and r.legal_hold
    and r.state in ('grace_period', 'executing');
  if v_requests_held > 0 then
    v_blockers := v_blockers || jsonb_build_array(format(
      '%s account deletion request(s) of these accounts carry a legal hold', v_requests_held));
  end if;

  return jsonb_build_object(
    'schools', (select jsonb_agg(jsonb_build_object(
        'id', s.id, 'name', s.name, 'status', s.status,
        'reviewer_school', pg_temp.cutover_is_reviewer_school(s.id)) order by s.name)
      from public.schools s where s.id = any(p_school_ids)),
    'rows', pg_temp.cutover_school_row_counts(p_school_ids),
    'classes', (select count(*) from public.classrooms c where c.school_id = any(p_school_ids)),
    'accounts_removed', (select coalesce(jsonb_agg(jsonb_build_object(
        'email', pg_temp.cutover_mask_email(u.email),
        'kind', p.account_kind,
        'roles', (select jsonb_agg(distinct m.role) from public.memberships m where m.user_id = p.id))
        order by u.email), '[]'::jsonb)
      from public.profiles p join auth.users u on u.id = p.id
      where p.id = any(v_accounts)),
    'accounts_kept', (select jsonb_build_object(
        'with_another_school', count(*) filter (where kept.elsewhere),
        'platform_operators', count(*) filter (where kept.operator),
        'reviewer_accounts', count(*) filter (where kept.reviewer),
        'already_deleted', count(*) filter (where kept.deleted))
      from (
        select
          exists (select 1 from pg_temp.cutover_ties() o where o.user_id = t.user_id and o.school_id <> all(p_school_ids)) as elsewhere,
          exists (select 1 from public.platform_operators po where po.user_id = t.user_id) as operator,
          exists (select 1 from auth.users u where u.id = t.user_id and coalesce(u.raw_app_meta_data ->> 'studafy_reviewer', '') = 'true') as reviewer,
          exists (select 1 from public.profiles p where p.id = t.user_id and p.deleted_at is not null) as deleted
        from (select distinct x.user_id from pg_temp.cutover_ties() x
              where x.school_id = any(p_school_ids) and x.user_id is not null) t
        where t.user_id <> all(v_accounts)) kept),
    'kept_accounts_personal_files', (select count(*) from public.file_objects f
      where f.school_id = any(p_school_ids) and f.deleted_at is null
        and f.purpose in ('profile_image', 'notebook_photo', 'assistant_attachment')
        and coalesce(f.owner_id, f.uploader_id) <> all(v_accounts)),
    'files_by_state', (select coalesce(jsonb_object_agg(x.scan_state, x.n), '{}'::jsonb)
      from (select f.scan_state, count(*) as n from public.file_objects f
            where f.school_id = any(p_school_ids) group by f.scan_state) x),
    'file_jobs_in_flight', (select count(*) from public.file_job_outbox j
      where j.school_id = any(p_school_ids) and j.state in ('pending', 'processing', 'retry')),
    'legal_holds_active', v_holds,
    'blockers', v_blockers);
end;
$$;

-- Removes the named schools. Raises (so the caller's transaction rolls back)
-- on any blocker, on any step that does not complete, and when anything
-- kept changed.
create or replace function pg_temp.cutover_clean(
  p_school_ids uuid[], p_include_reviewer boolean, p_release_holds boolean)
returns jsonb language plpgsql volatile as $$
declare
  v_plan jsonb;
  v_accounts uuid[];
  v_before jsonb;
  v_after jsonb;
  v_changed text[];
  v_objects jsonb;
  v_class uuid;
  v_account uuid;
  v_request uuid;
  v_outcome text;
  v_round integer;
  v_progress boolean;
  v_stuck text[];
  v_left jsonb;
  t record;
  n bigint;
  v_deidentified integer := 0;
  v_classes integer := 0;
begin
  if current_user <> 'postgres' then
    raise exception 'CUTOVER_REFUSED: run as postgres (the table owner), not %', current_user;
  end if;
  v_plan := pg_temp.cutover_plan(p_school_ids, p_include_reviewer, p_release_holds);
  if jsonb_array_length(v_plan -> 'blockers') > 0 then
    raise exception 'CUTOVER_BLOCKED: %', v_plan -> 'blockers';
  end if;

  select coalesce(array_agg(a.user_id), '{}') into v_accounts
  from pg_temp.cutover_test_accounts(p_school_ids, p_include_reviewer) a;
  v_before := pg_temp.cutover_fingerprint(p_school_ids, v_accounts);

  -- Stored bytes of these schools, for the Storage API after the commit.
  -- A key another school also uses is left alone.
  select coalesce(jsonb_agg(jsonb_build_object('bucket', k.bucket, 'key', k.object_key)
      order by k.bucket, k.object_key), '[]'::jsonb) into v_objects
  from (
    select f.bucket, f.object_key from public.file_objects f
    where f.school_id = any(p_school_ids) and f.physical_deleted_at is null
    union
    select u.bucket, u.object_key from public.upload_sessions u
    where u.school_id = any(p_school_ids) and u.bucket is not null and u.object_key is not null
  ) k
  where exists (select 1 from storage.objects o where o.bucket_id = k.bucket and o.name = k.object_key)
    and not exists (select 1 from public.file_objects f2
      where f2.bucket = k.bucket and f2.object_key = k.object_key and f2.school_id <> all(p_school_ids))
    and not exists (select 1 from public.upload_sessions u2
      where u2.bucket = k.bucket and u2.object_key = k.object_key and u2.school_id <> all(p_school_ids));

  -- The test worker is stopped before this runs (the runbook's order), so
  -- nothing is working on these jobs; they would otherwise keep the class
  -- purge waiting.
  update public.file_job_outbox
    set state = 'cancelled', locked_at = null, locked_by = null
    where school_id = any(p_school_ids) and state in ('pending', 'processing', 'retry');
  if p_release_holds then
    delete from public.legal_holds where school_id = any(p_school_ids);
  end if;

  -- 1. Classes: closed, then purged as the retention schedule purges them.
  update public.classrooms
    set status = 'archived', archived_at = now(), version = version + 1, updated_at = now()
    where school_id = any(p_school_ids) and archived_at is null;
  for v_class in
    select c.id from public.classrooms c
    where c.school_id = any(p_school_ids) and c.academic_records_purged_at is null
    order by c.id
  loop
    if not private.retention_purge_class(v_class) then
      raise exception 'CUTOVER_BLOCKED: class % could not be purged (a hold or a file job keeps it)', v_class;
    end if;
    v_classes := v_classes + 1;
  end loop;

  -- 2. Test-only accounts: the account-deletion executor, due now.
  foreach v_account in array v_accounts loop
    if exists (select 1 from public.profiles p where p.id = v_account and p.deleted_at is not null) then
      continue; -- a managed child already removed with its guardian
    end if;
    select r.id into v_request from public.account_deletion_requests r
    where r.user_id = v_account and r.state in ('grace_period', 'executing');
    if v_request is null then
      insert into public.account_deletion_requests (
        user_id, execute_after, reason_code, requested_via, impact_snapshot)
      values (v_account, now(), 'undisclosed', 'support',
        jsonb_build_object('cause', 'cutover_test_data'))
      returning id into v_request;
    else
      update public.account_deletion_requests
        set execute_after = least(execute_after, now()), version = version + 1
        where id = v_request;
    end if;
    v_outcome := private.account_deletion_execute(v_request);
    if v_outcome <> 'completed' then
      raise exception 'CUTOVER_BLOCKED: an account deletion ended %', v_outcome;
    end if;
    v_deidentified := v_deidentified + 1;
  end loop;

  -- 3. What is left of the schools. Each table is tried in turn; one that a
  --    reference still holds is tried again after the others.
  perform set_config('studafy.retention_purge', 'on', true);
  for v_round in 1..20 loop
    v_progress := false;
    v_stuck := '{}';
    for t in select * from pg_temp.cutover_school_tables() loop
      begin
        execute format('delete from %s where %I = any($1)', t.rel, t.col) using p_school_ids;
        get diagnostics n = row_count;
        if n > 0 then v_progress := true; end if;
      exception when foreign_key_violation or restrict_violation then
        v_stuck := v_stuck || t.rel::text;
      end;
    end loop;
    exit when cardinality(v_stuck) = 0;
    if not v_progress then
      raise exception 'CUTOVER_BLOCKED: rows in % are still referenced', array_to_string(v_stuck, ', ');
    end if;
  end loop;
  if cardinality(v_stuck) > 0 then
    raise exception 'CUTOVER_BLOCKED: rows in % are still referenced', array_to_string(v_stuck, ', ');
  end if;
  delete from public.schools where id = any(p_school_ids);
  perform set_config('studafy.retention_purge', '', true);

  -- 4. Nothing of the schools is left, and nothing kept changed.
  v_left := pg_temp.cutover_school_row_counts(p_school_ids);
  if v_left <> '{}'::jsonb or exists (select 1 from public.schools where id = any(p_school_ids)) then
    raise exception 'CUTOVER_BLOCKED: rows of the schools remain: %', v_left;
  end if;
  v_after := pg_temp.cutover_fingerprint(p_school_ids, v_accounts);
  select array_agg(b.key order by b.key) into v_changed
  from jsonb_each_text(v_before) b
  where b.value is distinct from v_after ->> b.key;
  if v_changed is not null then
    raise exception 'CUTOVER_KEPT_DATA_CHANGED: % changed; nothing was committed', array_to_string(v_changed, ', ');
  end if;

  -- The audit trail names the removed school by id only.
  insert into public.audit_events (school_id, actor_id, action, entity_type, entity_id, after_value, request_id)
  select null, null, 'cutover_test_school_removed', 'school', x,
    jsonb_build_object('accounts_deidentified', v_deidentified, 'classes_purged', v_classes),
    'cutover-clean-' || x::text
  from unnest(p_school_ids) x;

  return jsonb_build_object(
    'plan', v_plan,
    'classes_purged', v_classes,
    'accounts_deidentified', v_deidentified,
    'storage_objects', v_objects,
    'kept_fingerprint_tables', (select count(*) from jsonb_object_keys(v_before)));
end;
$$;
