-- Notebook writing survives an API restart (2026-10-11, launch plan 2.7).
--
-- A notebook is written in the background by the API instance that received
-- the request. If that machine stopped mid-write (a deploy, a crash), the
-- notebook stayed "creating" until it showed as failed ten minutes later and
-- the student had to try again.
--
-- Now every API instance asks, once a minute, for notebooks that have been
-- "creating" for three minutes or more - longer than a write takes (the
-- model's own limit is two minutes) - and writes them again. The claim takes
-- a short lease with SKIP LOCKED, so two instances never write the same one,
-- and a notebook is resumed at most twice before the existing ten-minute
-- rule shows it as failed with its retry.
--
-- The payload is built as the notebook's owner, through the same
-- notebook_start_json the start command uses, so the lesson is checked
-- against what the student may see now: a student who lost access gets a
-- failed notebook, never one written from material they can no longer read.

alter table public.study_notebooks
  add column if not exists generation_lease_until timestamptz,
  add column if not exists generation_resumes integer not null default 0
    check (generation_resumes >= 0);

create or replace function private.study_notebooks_resume(p_limit integer)
returns jsonb language plpgsql security definer set search_path = '' as $$
declare
  n public.study_notebooks%rowtype;
  v_payload jsonb;
  v_claimed jsonb := '[]'::jsonb;
begin
  if p_limit is null or p_limit < 1 or p_limit > 20 then
    raise exception 'Resume batch out of range';
  end if;
  for n in
    select x.* from public.study_notebooks x
    where x.status = 'creating' and x.deleted_at is null
      and x.generation_started_at < now() - interval '3 minutes'
      and x.generation_started_at > now() - interval '9 minutes'
      and (x.generation_lease_until is null or x.generation_lease_until < now())
      and x.generation_resumes < 2
    order by x.generation_started_at
    limit p_limit
    for update skip locked
  loop
    update public.study_notebooks
    set generation_lease_until = now() + interval '3 minutes',
      generation_resumes = generation_resumes + 1
    where id = n.id
    returning * into n;
    -- As the owner, for this row only: the lesson check is theirs.
    perform set_config('request.jwt.claim.sub', n.owner_id::text, true);
    v_payload := private.notebook_start_json(n);
    -- The ids always travel, so a notebook whose lesson the owner can no
    -- longer see is marked failed rather than left "creating".
    v_claimed := v_claimed || jsonb_build_array(v_payload || jsonb_build_object(
      'notebookId', n.id, 'generation', n.generation,
      'ownerId', n.owner_id, 'schoolId', n.school_id,
      'resume', n.generation_resumes));
  end loop;
  perform set_config('request.jwt.claim.sub', '', true);
  return v_claimed;
end;
$$;

alter function private.study_notebooks_resume(integer) owner to postgres;
revoke all on function private.study_notebooks_resume(integer)
  from public, anon, authenticated;
grant execute on function private.study_notebooks_resume(integer)
  to studafy_api_runtime;

-- Each new generation (start or regenerate) gets its own resume budget.
create or replace function private.study_notebook_generation_reset()
returns trigger language plpgsql security definer set search_path = '' as $$
begin
  if new.generation is distinct from old.generation then
    new.generation_resumes := 0;
    new.generation_lease_until := null;
  end if;
  return new;
end;
$$;

alter function private.study_notebook_generation_reset() owner to postgres;
revoke all on function private.study_notebook_generation_reset()
  from public, anon, authenticated;

drop trigger if exists study_notebook_generation_reset on public.study_notebooks;
create trigger study_notebook_generation_reset
before update of generation on public.study_notebooks
for each row execute function private.study_notebook_generation_reset();
