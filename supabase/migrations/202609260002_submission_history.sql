-- Every attempt at a piece of work, not only the latest.
--
-- A resubmission has always created a new submission_attempts row and moved
-- submissions.current_attempt_id to it, so the history was recorded and never
-- readable: the roster, the student's own view and a parent's view all showed
-- the current attempt and nothing before it. This exposes the attempts as
-- one read, for the three people entitled to it:
--
--   * the student whose work it is;
--   * the class's staff (and school admins), who mark it;
--   * a verified guardian of that student, who may have handed it in.
--
-- Each attempt says who handed it in. A guardian filing work for a young
-- child is recorded on the attempt (202609250003); a teacher reading the
-- history sees that parent's name against the attempt they filed.
--
-- Also closes a gap the history makes visible: a guardian could hand work in
-- with a file and then not open that file. The download rule gains the same
-- relationship the history read uses.
--
-- Forward-only: each function changed is renamed and delegated to.

-- ---------------------------------------------------------------------------
-- 1. Who may ask for an assignment's history at all.
--
-- Coarse, because the middleware only knows the assignment: staff of its
-- class, or someone with a child - themselves or one they are a verified
-- guardian of - enrolled in it or holding work on it. Which student's
-- history is returned is decided in the query, where the student id exists.
-- ---------------------------------------------------------------------------
do $$ begin
  if not exists (
    select 1 from pg_proc p join pg_namespace n on n.oid = p.pronamespace
    where n.nspname = 'private' and p.proname = 'authz_authorize_pre_history'
  ) then
    alter function private.authz_authorize(text, uuid)
      rename to authz_authorize_pre_history;
  end if;
end $$;

create or replace function private.authz_authorize(
  p_action text, p_resource_id uuid)
returns jsonb language plpgsql stable security definer set search_path = '' as $$
declare
  sid uuid;
  cls uuid;
  allowed boolean := false;
begin
  if p_action <> 'submission.history' then
    return private.authz_authorize_pre_history(p_action, p_resource_id);
  end if;
  if auth.uid() is null or p_resource_id is null then
    return jsonb_build_object('allowed', false, 'school_id', null, 'reason', 'invalid_resource');
  end if;
  select a.school_id, a.classroom_id into sid, cls
  from public.assignments a
  where a.id = p_resource_id and a.deleted_at is null;
  if cls is null then
    return jsonb_build_object('allowed', false, 'school_id', null, 'reason', 'invalid_resource');
  end if;

  allowed := private.is_school_admin(sid) or private.is_class_staff(cls)
    or exists (
      select 1 from public.students s
      where s.school_id = sid and s.deleted_at is null
        and (s.user_id = auth.uid() or private.is_linked_guardian(s.id, cls))
        and (
          exists (select 1 from public.enrollments e
            where e.student_id = s.id and e.classroom_id = cls
              and e.active and e.status = 'active')
          or exists (select 1 from public.submissions su
            where su.assignment_id = p_resource_id and su.student_id = s.id)
        )
    );
  return jsonb_build_object('allowed', coalesce(allowed, false), 'school_id', sid,
    'reason', case when allowed then 'allowed' else 'denied' end);
end;
$$;

alter function private.authz_authorize(text, uuid) owner to postgres;
alter function private.authz_authorize_pre_history(text, uuid) owner to postgres;
revoke all on function private.authz_authorize_pre_history(text, uuid)
  from public, anon, authenticated, service_role, studafy_worker_runtime,
  studafy_api_runtime;
revoke all on function private.authz_authorize(text, uuid)
  from public, anon, authenticated, service_role, studafy_worker_runtime;
grant execute on function private.authz_authorize(text, uuid)
  to studafy_api_runtime;

-- ---------------------------------------------------------------------------
-- 2. The read.
-- ---------------------------------------------------------------------------
do $$ begin
  if not exists (
    select 1 from pg_proc p join pg_namespace n on n.oid = p.pronamespace
    where n.nspname = 'private' and p.proname = 'api041_query_pre_history'
  ) then
    alter function private.api041_query(text, uuid, jsonb)
      rename to api041_query_pre_history;
  end if;
end $$;

create or replace function private.api041_query(
  p_operation text, p_resource_id uuid, p_input jsonb)
returns jsonb language plpgsql stable security definer set search_path = '' as $$
declare
  v_school uuid;
  v_class uuid;
  v_student uuid := nullif(p_input->>'studentId', '')::uuid;
  v_staff boolean;
  v_items jsonb;
begin
  if p_operation <> 'listSubmissionHistory' then
    return private.api041_query_pre_history(p_operation, p_resource_id, p_input);
  end if;
  if auth.uid() is null then return jsonb_build_object('outcome', 'not_found'); end if;

  select a.school_id, a.classroom_id into v_school, v_class
  from public.assignments a
  where a.id = p_resource_id and a.deleted_at is null;
  if v_class is null then return jsonb_build_object('outcome', 'not_found'); end if;

  v_staff := private.is_school_admin(v_school) or private.is_class_staff(v_class);

  -- A student asking about their own work does not name themselves, for the
  -- same reason as an upload: the app is not told its own student record.
  if v_student is null then
    select s.id into v_student
    from public.students s
    where s.user_id = auth.uid() and s.school_id = v_school
      and s.deleted_at is null
      and (exists (select 1 from public.enrollments e
             where e.student_id = s.id and e.classroom_id = v_class)
        or exists (select 1 from public.submissions su
             where su.assignment_id = p_resource_id and su.student_id = s.id))
    limit 1;
    if v_student is null then return jsonb_build_object('outcome', 'not_found'); end if;
  end if;

  -- Named, or resolved: the caller must be that student, a verified guardian
  -- of them, or someone who marks the class. Anything else is concealed.
  if not (
    v_staff
    or exists (select 1 from public.students s
      where s.id = v_student and s.school_id = v_school
        and s.user_id = auth.uid())
    or private.is_linked_guardian(v_student, v_class)
  ) then
    return jsonb_build_object('outcome', 'not_found');
  end if;

  select coalesce(jsonb_agg(jsonb_build_object(
      'id', sa.id,
      'submittedAt', sa.submitted_at,
      'answerText', sa.answer_text,
      'current', sa.id = su.current_attempt_id,
      'submittedByGuardianId', sa.submitted_by_guardian_id,
      -- A name, not an account: enough for a teacher to know which parent
      -- filed it, and nothing a reader could use to reach them outside the
      -- product.
      'submittedByGuardianName', gp.display_name,
      'attachments', private.file_attachment_json(p_submission_attempt => sa.id)
    ) order by sa.submitted_at desc, sa.id desc), '[]'::jsonb)
  into v_items
  from public.submissions su
  join public.submission_attempts sa on sa.submission_id = su.id
  left join public.profiles gp on gp.id = sa.submitted_by_guardian_id
  where su.assignment_id = p_resource_id and su.student_id = v_student;

  return jsonb_build_object('items', v_items, 'nextPosition', null);
exception when invalid_text_representation then
  return jsonb_build_object('outcome', 'not_found');
end;
$$;

alter function private.api041_query(text, uuid, jsonb) owner to postgres;
alter function private.api041_query_pre_history(text, uuid, jsonb)
  owner to postgres;
revoke all on function private.api041_query_pre_history(text, uuid, jsonb)
  from public, anon, authenticated, service_role, studafy_worker_runtime,
  studafy_api_runtime;
revoke all on function private.api041_query(text, uuid, jsonb)
  from public, anon, authenticated, service_role, studafy_worker_runtime;
grant execute on function private.api041_query(text, uuid, jsonb)
  to studafy_api_runtime;

-- ---------------------------------------------------------------------------
-- 3. A guardian may open the files on their child's work.
--
-- The same relationship as the read above: a verified link to the student
-- whose submission the file is bound to.
-- ---------------------------------------------------------------------------
do $$ begin
  if not exists (
    select 1 from pg_proc p join pg_namespace n on n.oid = p.pronamespace
    where n.nspname = 'private' and p.proname = 'file051_authorize_download_pre_history'
  ) then
    alter function private.file051_authorize_download(uuid)
      rename to file051_authorize_download_pre_history;
  end if;
end $$;

create or replace function private.file051_authorize_download(p_file_id uuid)
returns jsonb language plpgsql stable security definer set search_path = '' as $$
declare
  decision jsonb;
begin
  decision := private.file051_authorize_download_pre_history(p_file_id);
  if coalesce((decision->>'allowed')::boolean, false)
    or coalesce(decision->>'reason', '') = 'invalid_resource' then
    return decision;
  end if;

  if exists (
    select 1 from public.file_bindings b
    join public.submission_attempts sa on sa.id = b.submission_attempt_id
    join public.submissions s on s.id = sa.submission_id
    join public.assignments a on a.id = s.assignment_id
    where b.file_object_id = p_file_id
      and private.is_linked_guardian(s.student_id, a.classroom_id)
  ) then
    return jsonb_build_object('allowed', true,
      'schoolId', decision->'schoolId', 'reason', 'linked_guardian');
  end if;

  return decision;
end;
$$;

alter function private.file051_authorize_download(uuid) owner to postgres;
alter function private.file051_authorize_download_pre_history(uuid)
  owner to postgres;
revoke all on function private.file051_authorize_download(uuid)
  from public, anon, authenticated, service_role, studafy_worker_runtime,
  studafy_api_runtime;
revoke all on function private.file051_authorize_download_pre_history(uuid)
  from public, anon, authenticated, service_role, studafy_worker_runtime,
  studafy_api_runtime;
