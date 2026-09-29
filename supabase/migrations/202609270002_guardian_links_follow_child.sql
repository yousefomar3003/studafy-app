-- A guardian link follows the child, not one school record of them.
--
-- A child with an account who joins classes at two schools has two students
-- rows - one per school, each with its own Studafy ID - and a guardian link
-- points at exactly one of them. A parent who linked with the ID from one
-- school was therefore a stranger to the other: that school's teacher never
-- saw them as the child's parent, could not message them, and none of that
-- school's work, grades or meetings reached them.
--
-- The link is approved once, by the child, for their account. So once it is
-- verified it now holds on every school record of the same child account:
--
--   * verifying a link (or changing a verified link - revoking it, changing
--     its expiry) is mirrored onto the child's other records;
--   * a record the child gains later, by joining a class at another school,
--     inherits their verified links.
--
-- Only verified links are mirrored. A pending request stays one request, so
-- the child is never asked to approve the same parent once per school, and a
-- request they decline was never mirrored anywhere.
--
-- Children without an account (students.user_id is null) have one record
-- per school that nothing ties together; they are unaffected.

create or replace function private.guardian_link_mirror(p_link uuid)
returns void language plpgsql security definer set search_path = '' as $$
declare
  l public.guardian_links%rowtype;
  v_user uuid;
begin
  select * into l from public.guardian_links where id = p_link;
  if l.id is null then return; end if;
  select st.user_id into v_user from public.students st where st.id = l.student_id;
  if v_user is null then return; end if;

  -- Onto every other record of the same child account. A sibling that was
  -- never verified is created verified; one that exists takes this link's
  -- state, so a revocation reaches everywhere the approval did.
  insert into public.guardian_links(
    school_id, student_id, guardian_id, status, relationship,
    verified_by, verified_at, expires_at)
  select st.school_id, st.id, l.guardian_id, l.status, l.relationship,
    l.verified_by, l.verified_at, l.expires_at
  from public.students st
  where st.user_id = v_user and st.id <> l.student_id and st.deleted_at is null
  on conflict (student_id, guardian_id) do update set
    status = excluded.status,
    relationship = coalesce(public.guardian_links.relationship, excluded.relationship),
    verified_by = coalesce(excluded.verified_by, public.guardian_links.verified_by),
    verified_at = coalesce(excluded.verified_at, public.guardian_links.verified_at),
    expires_at = excluded.expires_at;
end;
$$;

revoke all on function private.guardian_link_mirror(uuid)
  from public, anon, authenticated, service_role, studafy_worker_runtime,
  studafy_api_runtime;
alter function private.guardian_link_mirror(uuid) owner to postgres;

create or replace function private.guardian_link_mirror_trigger()
returns trigger language plpgsql security definer set search_path = '' as $$
begin
  -- The mirror's own writes fire this trigger again; only the change a
  -- person made is propagated.
  if pg_trigger_depth() > 1 then return null; end if;
  if new.status = 'verified'
    or (tg_op = 'UPDATE' and old.status = 'verified') then
    perform private.guardian_link_mirror(new.id);
  end if;
  return null;
end;
$$;

revoke all on function private.guardian_link_mirror_trigger()
  from public, anon, authenticated, service_role, studafy_worker_runtime,
  studafy_api_runtime;
alter function private.guardian_link_mirror_trigger() owner to postgres;

drop trigger if exists guardian_link_follows_child on public.guardian_links;
create trigger guardian_link_follows_child
after insert or update of status, expires_at on public.guardian_links
for each row execute function private.guardian_link_mirror_trigger();

-- A record the child gains later inherits their verified links.
create or replace function private.student_inherits_guardians()
returns trigger language plpgsql security definer set search_path = '' as $$
begin
  if new.user_id is null or new.deleted_at is not null then return null; end if;
  if tg_op = 'UPDATE' and old.user_id is not distinct from new.user_id then
    return null;
  end if;
  insert into public.guardian_links(
    school_id, student_id, guardian_id, status, relationship,
    verified_by, verified_at, expires_at)
  select distinct on (gl.guardian_id)
    new.school_id, new.id, gl.guardian_id, gl.status, gl.relationship,
    gl.verified_by, gl.verified_at, gl.expires_at
  from public.guardian_links gl
  join public.students st on st.id = gl.student_id
  where st.user_id = new.user_id and st.id <> new.id
    and gl.status = 'verified'
    and (gl.expires_at is null or gl.expires_at > now())
  order by gl.guardian_id, gl.verified_at desc
  on conflict (student_id, guardian_id) do nothing;
  return null;
end;
$$;

revoke all on function private.student_inherits_guardians()
  from public, anon, authenticated, service_role, studafy_worker_runtime,
  studafy_api_runtime;
alter function private.student_inherits_guardians() owner to postgres;

drop trigger if exists student_inherits_guardians on public.students;
create trigger student_inherits_guardians
after insert or update of user_id on public.students
for each row execute function private.student_inherits_guardians();

-- Links verified before this change reach the child's other records now.
do $$
declare r record;
begin
  for r in
    select gl.id from public.guardian_links gl
    join public.students st on st.id = gl.student_id
    where gl.status = 'verified' and st.user_id is not null
  loop
    perform private.guardian_link_mirror(r.id);
  end loop;
end $$;
