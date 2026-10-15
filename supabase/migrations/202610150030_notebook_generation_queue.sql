-- Study notebooks written on the worker's queue (2026-10-16, capacity fix 4,
-- docs/capacity/2026-10-16-notebooks.md).
--
-- Until now the API instance that received the request wrote the notebook
-- itself, as a background promise in its own process: gathering the
-- material, holding and settling the AI allowance, saving the result. Each
-- notebook cost that process about as much database time as twenty page
-- loads, competing with the requests it is there to answer, and a stopped
-- instance left notebooks for every instance to resume (202610110003).
--
-- Now the database records a job for every notebook generation, in the same
-- transaction that creates or regenerates the notebook, and the worker writes
-- it. Nothing changes for the app: the request still answers "creating" at
-- once and the notebook becomes "ready" or "failed" as before.
--
-- * private.study_notebook_jobs: one row per generation (unique), so a
--   generation is queued once however the request was retried. A trigger on
--   study_notebooks adds it, which keeps api055 as it is.
-- * The worker claims jobs with a three-minute lease (SKIP LOCKED); every
--   call it makes for a job names the claim - worker, job, attempt - so a
--   worker that lost its lease can no longer act on it.
-- * It acts as the notebook's owner, and only through three functions: the
--   lesson material of that notebook's lesson (api054), its AI allowance
--   for that one generation's ledger key (api047), and saving or failing
--   that notebook (api055). It cannot read another lesson or touch another
--   charge, and the lesson is read as the owner sees it on every attempt.
-- * Charged once per generation: every attempt shares the ledger key
--   notebook:<id>:<generation>. A hold left by an attempt that stopped is
--   released when the next attempt starts, never settled.
-- * Three attempts with backoff (20 s, 80 s) for failures that cost nothing
--   (the provider busy, the database briefly away, a worker stopped). Then,
--   or once the notebook has waited nine minutes, the job is a dead letter:
--   the notebook shows failed with its retry, as the ten-minute rule already
--   showed it, and private.notebook_jobs_backlog() counts it for the queue
--   alerts. Dead letters are kept 30 days.
--
-- The API-side resume (202610110003) is retired: its function, trigger and
-- columns are dropped.

create table if not exists private.study_notebook_jobs (
  id uuid primary key default gen_random_uuid(),
  notebook_id uuid not null references public.study_notebooks(id) on delete cascade,
  generation integer not null check (generation >= 1),
  state text not null default 'pending'
    check (state in ('pending', 'processing', 'dead')),
  attempts integer not null default 0 check (attempts >= 0),
  next_attempt_at timestamptz not null default now(),
  lease_until timestamptz,
  worker_id text check (char_length(worker_id) between 1 and 120),
  last_error text check (last_error ~ '^[a-z_]{1,60}$'),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  dead_at timestamptz,
  unique (notebook_id, generation),
  check ((state = 'dead') = (dead_at is not null))
);
create index if not exists study_notebook_jobs_queue_idx
  on private.study_notebook_jobs (next_attempt_at)
  where state in ('pending', 'processing');
create index if not exists study_notebook_jobs_dead_idx
  on private.study_notebook_jobs (dead_at) where state = 'dead';

alter table private.study_notebook_jobs enable row level security;
revoke all on private.study_notebook_jobs from public, anon, authenticated,
  service_role, studafy_api_runtime, studafy_worker_runtime;

-- ---------------------------------------------------------------------------
-- Queued with the notebook: a new notebook, or a new generation of one.
-- ---------------------------------------------------------------------------
create or replace function private.study_notebook_enqueue()
returns trigger language plpgsql security definer set search_path = '' as $$
begin
  if new.status = 'creating' and new.deleted_at is null and (tg_op = 'INSERT'
      or new.generation is distinct from old.generation) then
    insert into private.study_notebook_jobs (notebook_id, generation)
    values (new.id, new.generation)
    on conflict (notebook_id, generation) do nothing;
  end if;
  return null;
end;
$$;

drop trigger if exists study_notebook_enqueue on public.study_notebooks;
create trigger study_notebook_enqueue
after insert or update of generation on public.study_notebooks
for each row execute function private.study_notebook_enqueue();

-- A notebook whose generation could not be written shows failed, with its
-- retry. Only the generation the job was for, and only while it is still
-- being written.
create or replace function private.notebook_job_mark_failed(
  p_notebook uuid, p_generation integer, p_reason text)
returns void language sql security definer set search_path = '' as $$
  update public.study_notebooks set status = 'failed',
    failure = case when p_reason ~ '^[a-z_]{1,60}$' then p_reason
      else 'generation_failed' end,
    updated_at = now()
  where id = p_notebook and generation = p_generation and status = 'creating';
$$;

-- The job a worker holds, with its notebook: null unless this worker holds
-- this attempt of it now.
create or replace function private.notebook_job_held(
  p_worker text, p_job uuid, p_attempt integer)
returns table (job_id uuid, notebook_id uuid, generation integer,
  attempts integer, owner_id uuid, resource_id uuid, started_at timestamptz)
language sql stable security definer set search_path = '' as $$
  select j.id, j.notebook_id, j.generation, j.attempts, n.owner_id,
    n.resource_id, n.generation_started_at
  from private.study_notebook_jobs j
  join public.study_notebooks n on n.id = j.notebook_id
  where j.id = p_job and j.worker_id = p_worker and j.state = 'processing'
    and j.attempts = p_attempt;
$$;

-- ---------------------------------------------------------------------------
-- The worker's side: claim, material, allowance, finish, backlog.
-- ---------------------------------------------------------------------------
create or replace function private.notebook_jobs_claim(p_worker text, p_limit integer)
returns jsonb language plpgsql security definer set search_path = '' as $$
declare
  j private.study_notebook_jobs%rowtype;
  n public.study_notebooks%rowtype;
  v_title text;
  v_claimed jsonb := '[]'::jsonb;
  v_max_attempts constant integer := 3;
begin
  if p_worker is null or char_length(p_worker) not between 1 and 120 then
    raise exception 'Worker id out of range';
  end if;
  if p_limit is null or p_limit < 1 or p_limit > 20 then
    raise exception 'Claim batch out of range';
  end if;

  -- Dead letters are kept a month for the record, then removed.
  delete from private.study_notebook_jobs x
  where x.id in (select d.id from private.study_notebook_jobs d
    where d.state = 'dead' and d.dead_at < now() - interval '30 days'
    limit 100);

  for j in
    select x.* from private.study_notebook_jobs x
    where (x.state = 'pending' and x.next_attempt_at <= now())
       or (x.state = 'processing' and x.lease_until < now())
    order by x.next_attempt_at
    limit p_limit
    for update skip locked
  loop
    -- Read, not locked: the notebook's own writes lock it first.
    select * into n from public.study_notebooks x where x.id = j.notebook_id;
    -- Deleted, written, failed, or replaced by a newer generation: nothing
    -- left to do.
    if n.id is null or n.deleted_at is not null or n.status <> 'creating'
        or n.generation <> j.generation then
      delete from private.study_notebook_jobs where id = j.id;
      continue;
    end if;
    -- Too late to be of use, or a lease lapsed on its last attempt.
    if n.generation_started_at < now() - interval '9 minutes'
        or j.attempts >= v_max_attempts then
      update private.study_notebook_jobs set state = 'dead', lease_until = null,
        dead_at = now(), updated_at = now(),
        last_error = case when j.attempts >= v_max_attempts
          then coalesce(j.last_error, 'worker_stopped') else 'timed_out' end
      where id = j.id;
      perform private.notebook_job_mark_failed(n.id, n.generation,
        case when j.attempts >= v_max_attempts then 'generation_failed'
          else 'timed_out' end);
      continue;
    end if;

    -- What notebook_start_json gives, without its list-row summary. Whether
    -- the owner still sees the lesson is decided by the first thing the
    -- worker does, reading the lesson as them (notebook_job_material): a
    -- student who lost it gets a failed notebook, never one written from
    -- material they can no longer read.
    select r.title into v_title from public.resources r where r.id = n.resource_id;

    update private.study_notebook_jobs set state = 'processing',
      worker_id = p_worker, lease_until = now() + interval '3 minutes',
      attempts = attempts + 1, updated_at = now()
    where id = j.id
    returning * into j;
    v_claimed := v_claimed || jsonb_build_array(jsonb_build_object(
      'jobId', j.id, 'attempt', j.attempts, 'ownerId', n.owner_id,
      'schoolId', n.school_id, 'start', jsonb_build_object(
        'notebookId', n.id, 'generation', n.generation,
        'resourceId', n.resource_id, 'lessonTitle', v_title,
        'sourceIds', to_jsonb(n.source_ids), 'includeText', n.include_text,
        'wholeLesson', n.whole_lesson)));
  end loop;
  return v_claimed;
end;
$$;

-- Lesson material for the job's notebook, read as its owner: their lesson
-- and nothing else.
create or replace function private.notebook_job_material(
  p_worker text, p_job uuid, p_attempt integer, p_operation text, p_input jsonb)
returns jsonb language plpgsql security definer set search_path = '' as $$
declare
  h record;
  v_result jsonb;
begin
  select * into h from private.notebook_job_held(p_worker, p_job, p_attempt);
  if h.job_id is null then
    return jsonb_build_object('outcome', 'lease_lost');
  end if;
  if p_operation not in ('lessons', 'retrieve')
      or jsonb_typeof(p_input->'resourceIds') is distinct from 'array'
      or exists (select 1 from jsonb_array_elements_text(p_input->'resourceIds') e
        where e.value is distinct from h.resource_id::text)
      or jsonb_array_length(p_input->'resourceIds') <> 1 then
    return jsonb_build_object('outcome', 'invalid');
  end if;
  perform set_config('request.jwt.claim.sub', h.owner_id::text, true);
  v_result := private.api054_ai_material(p_operation, p_input);
  perform set_config('request.jwt.claim.sub', '', true);
  return v_result;
end;
$$;

-- The owner's AI allowance for this one generation. Every attempt uses the
-- generation's own key, so it is charged once.
create or replace function private.notebook_job_usage(
  p_worker text, p_job uuid, p_attempt integer, p_operation text, p_input jsonb)
returns jsonb language plpgsql security definer set search_path = '' as $$
declare
  h record;
  v_key text;
  v_result jsonb;
begin
  select * into h from private.notebook_job_held(p_worker, p_job, p_attempt);
  if h.job_id is null then
    return jsonb_build_object('outcome', 'lease_lost');
  end if;
  v_key := 'notebook:' || h.notebook_id::text || ':' || h.generation::text;
  if p_operation = 'reserve' then
    if p_input->>'feature' is distinct from 'notes' then
      return jsonb_build_object('outcome', 'invalid');
    end if;
    if h.attempts > 1 then
      -- An earlier attempt that stopped mid-write left its hold: released,
      -- never charged, so this attempt is not refused as a duplicate.
      update private.ai_usage u set status = 'released', settled_at = now()
      where u.user_id = h.owner_id and u.request_key = v_key
        and u.status = 'reserved';
    end if;
  elsif p_operation in ('settle', 'release') then
    -- Only this generation's own hold.
    if not exists (select 1 from private.ai_usage u
        where u.id = nullif(p_input->>'usageId', '')::uuid
          and u.user_id = h.owner_id
          and u.request_key in (v_key, v_key || ':replay')) then
      return jsonb_build_object('outcome', 'not_found');
    end if;
  else
    return jsonb_build_object('outcome', 'invalid');
  end if;
  perform set_config('request.jwt.claim.sub', h.owner_id::text, true);
  v_result := private.api047_ai_usage(p_operation,
    case when p_operation = 'reserve'
      then p_input || jsonb_build_object('requestKey', v_key)
      else p_input end);
  perform set_config('request.jwt.claim.sub', '', true);
  return v_result;
exception when invalid_text_representation then
  return jsonb_build_object('outcome', 'invalid');
end;
$$;

-- What came of an attempt:
--   ready   - saved as the owner (api055 'finish'), which ignores a late
--             answer to a replaced generation;
--   failed  - the notebook shows the reason, with its retry;
--   retry   - tried again with backoff, while attempts and time remain;
--             otherwise a dead letter, and the notebook shows failed.
create or replace function private.notebook_job_finish(
  p_worker text, p_job uuid, p_attempt integer, p_result jsonb)
returns jsonb language plpgsql security definer set search_path = '' as $$
declare
  h record;
  v_outcome text := p_result->>'outcome';
  v_reason text := case when p_result->>'reason' ~ '^[a-z_]{1,60}$'
    then p_result->>'reason' else 'generation_failed' end;
  v_saved jsonb;
  v_next timestamptz;
  v_max_attempts constant integer := 3;
begin
  perform 1 from private.study_notebook_jobs x where x.id = p_job for update;
  select * into h from private.notebook_job_held(p_worker, p_job, p_attempt);
  if h.job_id is null then
    return jsonb_build_object('outcome', 'lease_lost');
  end if;

  if v_outcome = 'ready' then
    perform set_config('request.jwt.claim.sub', h.owner_id::text, true);
    v_saved := private.api055_study_notebooks('finish', jsonb_build_object(
      'id', h.notebook_id, 'generation', h.generation,
      'content', p_result->'content',
      'unreadable', coalesce(p_result->'unreadable', '[]'::jsonb),
      'model', p_result->>'model'));
    perform set_config('request.jwt.claim.sub', '', true);
    delete from private.study_notebook_jobs where id = h.job_id;
    return jsonb_build_object('outcome', 'ok', 'state', 'done',
      'notebook', v_saved->>'outcome');
  elsif v_outcome = 'failed' then
    perform private.notebook_job_mark_failed(h.notebook_id, h.generation, v_reason);
    delete from private.study_notebook_jobs where id = h.job_id;
    return jsonb_build_object('outcome', 'ok', 'state', 'done');
  elsif v_outcome = 'retry' then
    v_next := now() + make_interval(secs => 20 * h.attempts * h.attempts);
    if h.attempts < v_max_attempts
        and v_next < h.started_at + interval '9 minutes' then
      update private.study_notebook_jobs set state = 'pending', lease_until = null,
        next_attempt_at = v_next, last_error = v_reason, updated_at = now()
      where id = h.job_id;
      return jsonb_build_object('outcome', 'ok', 'state', 'pending');
    end if;
    update private.study_notebook_jobs set state = 'dead', lease_until = null,
      dead_at = now(), last_error = v_reason, updated_at = now()
    where id = h.job_id;
    perform private.notebook_job_mark_failed(h.notebook_id, h.generation, v_reason);
    return jsonb_build_object('outcome', 'ok', 'state', 'dead');
  end if;
  return jsonb_build_object('outcome', 'invalid');
end;
$$;

-- For the backlog line and the queue alerts (launch plan 4.7).
create or replace function private.notebook_jobs_backlog()
returns jsonb language sql stable security definer set search_path = '' as $$
  select jsonb_build_object(
    'pending', count(*) filter (where state = 'pending'),
    'processing', count(*) filter (where state = 'processing'),
    'oldestPendingSeconds', coalesce(extract(epoch from now() - min(created_at)
      filter (where state = 'pending'))::bigint, 0),
    'deadLetters', count(*) filter (where state = 'dead'))
  from private.study_notebook_jobs;
$$;

-- ---------------------------------------------------------------------------
-- The API-side resume (202610110003), retired.
-- ---------------------------------------------------------------------------
drop function if exists private.study_notebooks_resume(integer);
drop trigger if exists study_notebook_generation_reset on public.study_notebooks;
drop function if exists private.study_notebook_generation_reset();
alter table public.study_notebooks
  drop column if exists generation_lease_until,
  drop column if exists generation_resumes;

-- Notebooks being written when this lands were started by an API instance
-- that writes them itself; they are not queued again.

do $$
declare
  fn text;
begin
  foreach fn in array array[
    'private.study_notebook_enqueue()',
    'private.notebook_job_mark_failed(uuid, integer, text)',
    'private.notebook_job_held(text, uuid, integer)',
    'private.notebook_jobs_claim(text, integer)',
    'private.notebook_job_material(text, uuid, integer, text, jsonb)',
    'private.notebook_job_usage(text, uuid, integer, text, jsonb)',
    'private.notebook_job_finish(text, uuid, integer, jsonb)',
    'private.notebook_jobs_backlog()']
  loop
    execute format('revoke all on function %s from public, anon, authenticated, '
      'service_role, studafy_api_runtime, studafy_worker_runtime', fn);
    execute format('alter function %s owner to postgres', fn);
  end loop;
end $$;

grant execute on function private.notebook_jobs_claim(text, integer),
  private.notebook_job_material(text, uuid, integer, text, jsonb),
  private.notebook_job_usage(text, uuid, integer, text, jsonb),
  private.notebook_job_finish(text, uuid, integer, jsonb),
  private.notebook_jobs_backlog()
  to studafy_worker_runtime;
