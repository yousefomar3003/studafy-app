-- Online assessments, answer release, and attachments on coursework
-- (ADR-0036).
--
-- Adds, without changing what an existing record means:
--
--   * question kinds - single choice, multiple choice, true/false, short
--     answer, essay - with options, an answer key, marking guidance and a
--     required flag; automatic marking of what has a key, manual marking of
--     the rest;
--   * an open/close window, attempts (best or latest counts), per-student
--     access grants (more time, more attempts), and an answer-release rule
--     (after close, after grading, or manual - never while anyone can still
--     attempt);
--   * titled links (public.content_links) and more file targets
--     (file_bindings: question, grade result, results role) on lessons,
--     assignments, assessments, questions and paper grades;
--   * the read models, commands, download rules and authorization for all of
--     it. Every answer-key gate is here, in SQL.
--
-- Existing questions are essays, existing assessments have one attempt and
-- release after close, and existing material is role 'material'.

-- ===========================================================================
-- 1. Schema
-- ===========================================================================

alter table public.assessment_questions
  add column if not exists kind text not null default 'essay',
  add column if not exists options jsonb not null default '[]'::jsonb,
  add column if not exists answer_key jsonb,
  add column if not exists marking_guidance text,
  add column if not exists required boolean not null default true;
alter table public.assessment_questions
  drop constraint if exists assessment_questions_kind_check,
  add constraint assessment_questions_kind_check check (kind in (
    'single_choice', 'multiple_choice', 'true_false', 'short_answer', 'essay')),
  drop constraint if exists assessment_questions_options_check,
  add constraint assessment_questions_options_check
    check (jsonb_typeof(options) = 'array' and jsonb_array_length(options) <= 10),
  drop constraint if exists assessment_questions_guidance_check,
  add constraint assessment_questions_guidance_check
    check (marking_guidance is null or char_length(marking_guidance) <= 10000);

alter table public.assessments
  add column if not exists opens_at timestamptz,
  add column if not exists closes_at timestamptz,
  add column if not exists max_attempts integer not null default 1,
  add column if not exists attempt_policy text not null default 'best',
  add column if not exists answer_release text not null default 'after_close',
  add column if not exists answers_released_at timestamptz;
alter table public.assessments
  drop constraint if exists assessments_attempts_check,
  add constraint assessments_attempts_check check (max_attempts between 1 and 20),
  drop constraint if exists assessments_attempt_policy_check,
  add constraint assessments_attempt_policy_check
    check (attempt_policy in ('best', 'latest')),
  drop constraint if exists assessments_answer_release_check,
  add constraint assessments_answer_release_check
    check (answer_release in ('after_close', 'after_grading', 'manual')),
  drop constraint if exists assessments_window_check,
  add constraint assessments_window_check
    check (opens_at is null or closes_at is null or closes_at > opens_at);

alter table public.assessment_attempts
  add column if not exists attempt_number integer,
  add column if not exists needs_marking boolean not null default false,
  add column if not exists awarded_score numeric(8,2),
  add column if not exists feedback text,
  add column if not exists marked_by uuid references public.profiles(id) on delete set null,
  add column if not exists marked_at timestamptz;

alter table public.assessment_answers
  add column if not exists selected jsonb,
  add column if not exists auto_score numeric(8,2),
  add column if not exists awarded_score numeric(8,2),
  add column if not exists feedback text,
  add column if not exists marked_by uuid references public.profiles(id) on delete set null,
  add column if not exists marked_at timestamptz;

-- What was handed in stays as it was handed in; only its marks change.
drop trigger if exists api041_immutable_assessment_attempt on public.assessment_attempts;
drop trigger if exists api041_immutable_assessment_answer on public.assessment_answers;
create trigger api041_immutable_assessment_attempt
before update on public.assessment_attempts
for each row execute function private.reject_immutable_columns(
  'id', 'school_id', 'assessment_id', 'student_id', 'operation_id',
  'submitted_at', 'created_at', 'attempt_number');
create trigger api041_undeletable_assessment_attempt
before delete on public.assessment_attempts
for each row execute function private.api041_reject_history_change();
create trigger api041_immutable_assessment_answer
before update on public.assessment_answers
for each row execute function private.reject_immutable_columns(
  'school_id', 'attempt_id', 'question_id', 'answer_text', 'selected',
  'auto_score', 'created_at');
create trigger api041_undeletable_assessment_answer
before delete on public.assessment_answers
for each row execute function private.api041_reject_history_change();

-- More time, or more attempts, for one student.
create table if not exists public.assessment_access_grants (
  id uuid primary key default gen_random_uuid(),
  school_id uuid not null references public.schools(id) on delete cascade,
  assessment_id uuid not null,
  student_id uuid not null,
  closes_at timestamptz,
  extra_attempts integer not null default 0 check (extra_attempts between 0 and 20),
  reason text check (reason is null or char_length(reason) <= 500),
  granted_by uuid references public.profiles(id) on delete set null,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (assessment_id, student_id),
  unique (school_id, id),
  foreign key (school_id, assessment_id)
    references public.assessments(school_id, id) on delete cascade,
  foreign key (school_id, student_id)
    references public.students(school_id, id) on delete cascade
);
alter table public.assessment_access_grants enable row level security;
revoke all on public.assessment_access_grants
  from public, anon, authenticated, service_role, studafy_api_runtime,
  studafy_worker_runtime;

-- Titled links. Same targets and the same detach rule as file_bindings.
create table if not exists public.content_links (
  id uuid primary key default gen_random_uuid(),
  school_id uuid not null references public.schools(id) on delete cascade,
  title text not null check (char_length(btrim(title)) between 1 and 120),
  url text not null check (char_length(url) <= 2048 and url ~ '^https://'),
  role text not null default 'material' check (role in ('material', 'results')),
  position integer not null default 0,
  assignment_id uuid,
  assessment_id uuid,
  assessment_question_id uuid,
  grade_result_id uuid,
  resource_version_id uuid,
  created_by uuid references public.profiles(id) on delete set null,
  created_at timestamptz not null default now(),
  detached_at timestamptz,
  detached_by uuid references public.profiles(id) on delete set null,
  unique (school_id, id),
  constraint content_links_one_target check (num_nonnulls(
    assignment_id, assessment_id, assessment_question_id, grade_result_id,
    resource_version_id) = 1),
  foreign key (school_id, assignment_id)
    references public.assignments(school_id, id) on delete cascade,
  foreign key (school_id, assessment_id)
    references public.assessments(school_id, id) on delete cascade,
  foreign key (school_id, assessment_question_id)
    references public.assessment_questions(school_id, id) on delete cascade,
  foreign key (school_id, grade_result_id)
    references public.grade_results(school_id, id) on delete cascade,
  foreign key (school_id, resource_version_id)
    references public.resource_versions(school_id, id) on delete cascade
);
alter table public.content_links enable row level security;
revoke all on public.content_links
  from public, anon, authenticated, service_role, studafy_api_runtime,
  studafy_worker_runtime;
create index if not exists content_links_assignment_idx on public.content_links (assignment_id)
  where assignment_id is not null and detached_at is null;
create index if not exists content_links_assessment_idx on public.content_links (assessment_id)
  where assessment_id is not null and detached_at is null;
create index if not exists content_links_question_idx on public.content_links (assessment_question_id)
  where assessment_question_id is not null and detached_at is null;
create index if not exists content_links_grade_idx on public.content_links (grade_result_id)
  where grade_result_id is not null and detached_at is null;
create index if not exists content_links_resource_version_idx on public.content_links (resource_version_id)
  where resource_version_id is not null and detached_at is null;

-- Files: two more targets, and the role of a file on an assessment.
alter table public.file_bindings
  add column if not exists assessment_question_id uuid,
  add column if not exists grade_result_id uuid,
  add column if not exists role text not null default 'material';
alter table public.file_bindings
  drop constraint if exists file_bindings_role_check,
  add constraint file_bindings_role_check check (role in ('material', 'results'));
do $$ begin
  if not exists (select 1 from pg_constraint where conrelid = 'public.file_bindings'::regclass
      and conname = 'file_binding_question_school_fk') then
    alter table public.file_bindings add constraint file_binding_question_school_fk
      foreign key (school_id, assessment_question_id)
      references public.assessment_questions(school_id, id) on delete cascade;
  end if;
  if not exists (select 1 from pg_constraint where conrelid = 'public.file_bindings'::regclass
      and conname = 'file_binding_grade_school_fk') then
    alter table public.file_bindings add constraint file_binding_grade_school_fk
      foreign key (school_id, grade_result_id)
      references public.grade_results(school_id, id) on delete cascade;
  end if;
end $$;
alter table public.file_bindings drop constraint if exists file050_binding_one_target;
alter table public.file_bindings add constraint file050_binding_one_target check (
  num_nonnulls(
    resource_version_id, submission_attempt_id, message_id,
    ai_grading_draft_id, upload_session_id, announcement_id,
    assignment_id, assessment_id, assessment_question_id, grade_result_id
  ) = 1) not valid;
alter table public.file_bindings validate constraint file050_binding_one_target;
create index if not exists file_binding_question_idx on public.file_bindings (assessment_question_id)
  where assessment_question_id is not null and detached_at is null;
create index if not exists file_binding_grade_idx on public.file_bindings (grade_result_id)
  where grade_result_id is not null and detached_at is null;
create index if not exists file_binding_resource_version_live_idx on public.file_bindings (resource_version_id)
  where resource_version_id is not null and detached_at is null;

drop trigger if exists db021_immutable_file_binding on public.file_bindings;
create trigger db021_immutable_file_binding before update on public.file_bindings
for each row execute function private.reject_immutable_columns(
  'id', 'school_id', 'file_object_id', 'resource_version_id',
  'submission_attempt_id', 'message_id', 'ai_grading_draft_id',
  'upload_session_id', 'announcement_id', 'assignment_id', 'assessment_id',
  'assessment_question_id', 'grade_result_id', 'role', 'created_at');

create index if not exists assessment_attempts_student_idx
  on public.assessment_attempts (assessment_id, student_id);

-- ===========================================================================
-- 2. Who the caller is to a student
-- ===========================================================================

-- The student themself, or a verified, unexpired guardian of a child with a
-- live enrolment in the class.
create or replace function private.coursework_reader_of(p_student uuid, p_class uuid)
returns boolean language sql stable security definer set search_path = '' as $$
  select auth.uid() is not null and (
    exists (select 1 from public.students st
      where st.id = p_student and st.user_id = auth.uid() and st.deleted_at is null)
    or private.is_linked_guardian(p_student, p_class));
$$;

-- The caller's own student row in a class, when they are enrolled in it.
create or replace function private.coursework_own_student(p_class uuid)
returns uuid language sql stable security definer set search_path = '' as $$
  select st.id from public.students st
  join public.enrollments e on e.student_id = st.id and e.classroom_id = p_class
    and e.active and e.status = 'active'
  where st.user_id = auth.uid() and st.deleted_at is null
  limit 1;
$$;

-- ===========================================================================
-- 3. Links
-- ===========================================================================

create or replace function private.content_link_url_ok(p_url text)
returns boolean language sql immutable set search_path = '' as $$
  -- https, a dotted host, an optional port, no credentials, no spaces.
  select p_url is not null and char_length(p_url) <= 2048
    and p_url ~* '^https://([a-z0-9]([a-z0-9-]*[a-z0-9])?\.)+[a-z]{2,63}(:[0-9]{1,5})?([/?#][^[:space:]]*)?$';
$$;

create or replace function private.content_links_json(
  p_assignment uuid default null, p_assessment uuid default null,
  p_question uuid default null, p_grade_result uuid default null,
  p_resource_version uuid default null, p_role text default 'material')
returns jsonb language sql stable security definer set search_path = '' as $$
  select coalesce(jsonb_agg(jsonb_build_object('id', l.id, 'title', l.title, 'url', l.url)
    order by l.position, l.created_at, l.id), '[]'::jsonb)
  from public.content_links l
  where l.detached_at is null and l.role = p_role
    and (p_assignment is not null and l.assignment_id = p_assignment
      or p_assessment is not null and l.assessment_id = p_assessment
      or p_question is not null and l.assessment_question_id = p_question
      or p_grade_result is not null and l.grade_result_id = p_grade_result
      or p_resource_version is not null and l.resource_version_id = p_resource_version);
$$;

-- Adds links to one target. 'ok', or 'invalid' for a bad link or too many.
create or replace function private.content_links_attach(
  p_links jsonb, p_school uuid,
  p_assignment uuid default null, p_assessment uuid default null,
  p_question uuid default null, p_grade_result uuid default null,
  p_resource_version uuid default null, p_role text default 'material',
  p_max int default 10)
returns text language plpgsql security definer set search_path = '' as $$
declare
  v_item jsonb;
  v_pos int;
  v_live int;
begin
  if p_links is null or jsonb_typeof(p_links) <> 'array' or jsonb_array_length(p_links) = 0 then
    return 'ok';
  end if;
  select coalesce(max(l.position), 0) into v_pos from public.content_links l
  where l.detached_at is null
    and (l.assignment_id = p_assignment or l.assessment_id = p_assessment
      or l.assessment_question_id = p_question or l.grade_result_id = p_grade_result
      or l.resource_version_id = p_resource_version);
  for v_item in select value from jsonb_array_elements(p_links) loop
    if jsonb_typeof(v_item) <> 'object'
       or char_length(btrim(coalesce(v_item->>'title', ''))) not between 1 and 120
       or not private.content_link_url_ok(btrim(v_item->>'url')) then
      return 'invalid';
    end if;
    v_pos := v_pos + 1;
    insert into public.content_links(school_id, title, url, role, position,
      assignment_id, assessment_id, assessment_question_id, grade_result_id,
      resource_version_id, created_by)
    values (p_school, btrim(v_item->>'title'), btrim(v_item->>'url'), p_role, v_pos,
      p_assignment, p_assessment, p_question, p_grade_result, p_resource_version,
      auth.uid());
  end loop;
  select count(*) into v_live from public.content_links l
  where l.detached_at is null and l.role = p_role
    and (l.assignment_id = p_assignment or l.assessment_id = p_assessment
      or l.assessment_question_id = p_question or l.grade_result_id = p_grade_result
      or l.resource_version_id = p_resource_version);
  if v_live > p_max then return 'invalid'; end if;
  return 'ok';
end;
$$;

-- Detaches links of one target, by id. A detached link is kept, not shown.
create or replace function private.content_links_detach(
  p_ids jsonb, p_assignment uuid default null, p_assessment uuid default null,
  p_question uuid default null, p_grade_result uuid default null,
  p_resource_version uuid default null, p_role text default 'material')
returns void language sql security definer set search_path = '' as $$
  update public.content_links l set detached_at = now(), detached_by = auth.uid()
  where l.detached_at is null and l.role = p_role
    and l.id in (select x::uuid from jsonb_array_elements_text(coalesce(p_ids, '[]'::jsonb)) x)
    and (l.assignment_id = p_assignment or l.assessment_id = p_assessment
      or l.assessment_question_id = p_question or l.grade_result_id = p_grade_result
      or l.resource_version_id = p_resource_version);
$$;

-- ===========================================================================
-- 4. Files on the new targets
-- ===========================================================================

-- Whether a file is already attached to anything (an upload session is not
-- an attachment).
create or replace function private.file_is_attached(p_file uuid)
returns boolean language sql stable security definer set search_path = '' as $$
  select exists (select 1 from public.file_bindings b
    where b.file_object_id = p_file
      and num_nonnulls(b.resource_version_id, b.submission_attempt_id, b.message_id,
        b.ai_grading_draft_id, b.announcement_id, b.assignment_id, b.assessment_id,
        b.assessment_question_id, b.grade_result_id) > 0);
$$;

-- Binds the caller's own unattached uploads of one purpose, started for
-- p_class, to one target. 'ok', 'invalid' or 'forbidden'.
create or replace function private.coursework_attach_files(
  p_file_ids jsonb, p_purpose public.file_purpose, p_school uuid, p_class uuid,
  p_assignment uuid default null, p_assessment uuid default null,
  p_question uuid default null, p_grade_result uuid default null,
  p_resource_version uuid default null, p_role text default 'material',
  p_max int default 10)
returns text language plpgsql security definer set search_path = '' as $$
declare
  v_ids uuid[];
  v_count int;
  v_id uuid;
  v_file public.file_objects%rowtype;
  v_live int;
begin
  if auth.uid() is null then return 'forbidden'; end if;
  if num_nonnulls(p_assignment, p_assessment, p_question, p_grade_result,
      p_resource_version) <> 1 then
    raise exception 'COURSEWORK_ATTACH_TARGET_AMBIGUOUS';
  end if;
  if p_file_ids is null or jsonb_typeof(p_file_ids) <> 'array' then return 'ok'; end if;
  select array_agg(distinct x::uuid), count(*) into v_ids, v_count
  from jsonb_array_elements_text(p_file_ids) x;
  if v_count = 0 then return 'ok'; end if;
  if v_count <> cardinality(v_ids) or v_count > p_max then return 'invalid'; end if;

  foreach v_id in array v_ids loop
    select * into v_file from public.file_objects fo where fo.id = v_id for update;
    if v_file.id is null or v_file.deleted_at is not null
       or v_file.scan_state in ('deleted', 'rejected') then
      return 'invalid';
    end if;
    if v_file.owner_id is distinct from auth.uid() or v_file.school_id <> p_school then
      return 'forbidden';
    end if;
    if v_file.purpose <> p_purpose then return 'invalid'; end if;
    if private.file_is_attached(v_id) then return 'invalid'; end if;
    -- The upload was authorised for one class; it is only ever that
    -- class's.
    if not exists (select 1 from public.file_bindings b
        join public.upload_sessions u on u.id = b.upload_session_id
        where b.file_object_id = v_id
          and (u.classroom_id = p_class
            or (select a.classroom_id from public.assignments a
                where a.id = u.assignment_id) = p_class)) then
      return 'forbidden';
    end if;
    insert into public.file_bindings(school_id, file_object_id, assignment_id,
      assessment_id, assessment_question_id, grade_result_id, resource_version_id, role)
    values (p_school, v_id, p_assignment, p_assessment, p_question, p_grade_result,
      p_resource_version, p_role);
  end loop;

  select count(*) into v_live from public.file_bindings b
  where b.detached_at is null and b.role = p_role
    and (b.assignment_id = p_assignment or b.assessment_id = p_assessment
      or b.assessment_question_id = p_question or b.grade_result_id = p_grade_result
      or b.resource_version_id = p_resource_version);
  if v_live > p_max then return 'invalid'; end if;
  return 'ok';
end;
$$;

-- Detaches files of one target. The file and the binding are kept.
create or replace function private.coursework_detach_files(
  p_ids jsonb, p_assignment uuid default null, p_assessment uuid default null,
  p_question uuid default null, p_grade_result uuid default null,
  p_resource_version uuid default null, p_role text default 'material')
returns void language sql security definer set search_path = '' as $$
  update public.file_bindings b set detached_at = now(), detached_by = auth.uid()
  where b.detached_at is null and b.role = p_role
    and b.file_object_id in (select x::uuid from jsonb_array_elements_text(coalesce(p_ids, '[]'::jsonb)) x)
    and (b.assignment_id = p_assignment or b.assessment_id = p_assessment
      or b.assessment_question_id = p_question or b.grade_result_id = p_grade_result
      or b.resource_version_id = p_resource_version);
$$;

create or replace function private.coursework_files_json(
  p_assessment uuid default null, p_question uuid default null,
  p_grade_result uuid default null, p_resource_version uuid default null,
  p_role text default 'material')
returns jsonb language sql stable security definer set search_path = '' as $$
  select coalesce(jsonb_agg(jsonb_build_object(
      'id', fo.id, 'displayName', fo.display_name, 'sizeBytes', fo.size_bytes,
      'mediaType', fo.declared_media_type, 'scanState', fo.scan_state)
    order by b.created_at, fo.id), '[]'::jsonb)
  from public.file_bindings b
  join public.file_objects fo on fo.id = b.file_object_id
  where fo.deleted_at is null and b.detached_at is null and b.role = p_role
    and (p_assessment is not null and b.assessment_id = p_assessment
      or p_question is not null and b.assessment_question_id = p_question
      or p_grade_result is not null and b.grade_result_id = p_grade_result
      or p_resource_version is not null and b.resource_version_id = p_resource_version);
$$;

-- Material lists only material: a paper grade's shared results follow each
-- student's grade, not the assessment. Otherwise unchanged from 202609300004.
create or replace function private.file_attachment_json(p_submission_attempt uuid DEFAULT NULL::uuid, p_message uuid DEFAULT NULL::uuid, p_announcement uuid DEFAULT NULL::uuid, p_assignment uuid DEFAULT NULL::uuid, p_assessment uuid DEFAULT NULL::uuid)
returns jsonb language sql stable security definer set search_path = '' as $function$
  select coalesce(
    jsonb_agg(
      jsonb_build_object(
        'id', fo.id,
        'displayName', fo.display_name,
        'sizeBytes', fo.size_bytes,
        'mediaType', fo.declared_media_type,
        'scanState', fo.scan_state
      ) order by fo.created_at, fo.id
    ),
    '[]'::jsonb
  )
  from public.file_bindings b
  join public.file_objects fo on fo.id = b.file_object_id
  where fo.deleted_at is null
    and b.detached_at is null
    and b.role = 'material'
    and (p_submission_attempt is not null
      and b.submission_attempt_id = p_submission_attempt
      or p_message is not null and b.message_id = p_message
      or p_announcement is not null and b.announcement_id = p_announcement
      or p_assignment is not null and b.assignment_id = p_assignment
      or p_assessment is not null and b.assessment_id = p_assessment);
$function$;

-- The older binder also refuses a file attached to one of the new targets.
-- Copied from 202609260001 with that check widened.
create or replace function private.file_attach_bind(
  p_file_ids jsonb,
  p_purpose public.file_purpose,
  p_school uuid,
  p_submission_attempt uuid default null,
  p_message uuid default null,
  p_announcement uuid default null,
  p_assignment uuid default null,
  p_assessment uuid default null
) returns text language plpgsql security definer set search_path = '' as $$
declare
  v_ids uuid[];
  v_id uuid;
  v_file public.file_objects%rowtype;
  v_count int;
  v_target_class uuid;
begin
  if auth.uid() is null then return 'forbidden'; end if;
  if num_nonnulls(p_submission_attempt, p_message, p_announcement,
      p_assignment, p_assessment) <> 1 then
    raise exception 'FILE_ATTACH_TARGET_AMBIGUOUS';
  end if;
  if p_file_ids is null or jsonb_typeof(p_file_ids) <> 'array' then
    return 'ok';
  end if;

  select array_agg(distinct x::uuid), count(*)
    into v_ids, v_count
  from jsonb_array_elements_text(p_file_ids) x;
  if v_count = 0 then return 'ok'; end if;
  if v_count <> cardinality(v_ids) then return 'invalid'; end if;
  if cardinality(v_ids) > 5 then return 'invalid'; end if;

  if p_assignment is not null then
    select a.classroom_id into v_target_class
    from public.assignments a where a.id = p_assignment;
  elsif p_assessment is not null then
    select a.classroom_id into v_target_class
    from public.assessments a where a.id = p_assessment;
  end if;

  foreach v_id in array v_ids loop
    select * into v_file from public.file_objects fo where fo.id = v_id;
    if v_file.id is null or v_file.deleted_at is not null
      or v_file.scan_state = 'deleted' then
      return 'invalid';
    end if;
    if v_file.owner_id <> auth.uid() then return 'forbidden'; end if;
    if v_file.school_id <> p_school then return 'forbidden'; end if;
    if v_file.purpose <> p_purpose then return 'invalid'; end if;
    if private.file_is_attached(v_id) then return 'invalid'; end if;
    if v_target_class is not null and not exists (
      select 1 from public.file_bindings b
      join public.upload_sessions u on u.id = b.upload_session_id
      where b.file_object_id = v_id
        and (u.classroom_id = v_target_class
          or (select a.classroom_id from public.assignments a
              where a.id = u.assignment_id) = v_target_class)
    ) then
      return 'forbidden';
    end if;

    insert into public.file_bindings(
      school_id, file_object_id, submission_attempt_id, message_id,
      announcement_id, assignment_id, assessment_id)
    values (
      p_school, v_id, p_submission_attempt, p_message, p_announcement,
      p_assignment, p_assessment);
  end loop;

  return 'ok';
end;
$$;

-- ===========================================================================
-- 5. Windows, attempts and release
-- ===========================================================================

-- The close time and attempts allowed for one student: the assessment's,
-- widened by any grant.
create or replace function private.assessment_student_terms(p_assessment uuid, p_student uuid)
returns table(opens_at timestamptz, closes_at timestamptz, attempts_allowed int, attempts_used int)
language sql stable security definer set search_path = '' as $$
  select a.opens_at,
    case when a.closes_at is null then null
      else greatest(a.closes_at, coalesce(g.closes_at, a.closes_at)) end,
    a.max_attempts + coalesce(g.extra_attempts, 0),
    (select count(*)::int from public.assessment_attempts t
      where t.assessment_id = a.id and t.student_id = p_student)
  from public.assessments a
  left join public.assessment_access_grants g
    on g.assessment_id = a.id and g.student_id = p_student
  where a.id = p_assessment;
$$;

-- Whether nobody can attempt any more: the window, and every grant, closed.
create or replace function private.assessment_closed_for_all(p_assessment uuid)
returns boolean language sql stable security definer set search_path = '' as $$
  select a.closes_at is not null and a.closes_at <= now()
    and not exists (select 1 from public.assessment_access_grants g
      where g.assessment_id = a.id and g.closes_at is not null and g.closes_at > now())
  from public.assessments a where a.id = p_assessment;
$$;

-- The one gate on answer keys, model answers, marking guidance and
-- per-question marks for students and families. Never true while anyone can
-- still attempt.
create or replace function private.assessment_answers_released(p_assessment uuid)
returns boolean language sql stable security definer set search_path = '' as $$
  select coalesce(
    a.state = 'published' and a.deleted_at is null
    and private.assessment_closed_for_all(a.id)
    and case a.answer_release
      when 'after_close' then true
      when 'after_grading' then
        not exists (select 1 from public.assessment_attempts t
          where t.assessment_id = a.id and t.needs_marking)
        and not exists (select 1 from public.grade_results g
          where g.assessment_id = a.id and g.state in ('draft', 'reviewed')
            and exists (select 1 from public.assessment_attempts t
              where t.assessment_id = a.id and t.student_id = g.student_id))
      when 'manual' then a.answers_released_at is not null and a.answers_released_at <= now()
      else false end, false)
  from public.assessments a where a.id = p_assessment;
$$;

-- ===========================================================================
-- 6. Questions: validation, read models, marking
-- ===========================================================================

-- The answer key a draft question carries, from the field its kind uses:
-- the correct option ids, true or false, or the short answers accepted.
create or replace function private.assessment_draft_key(q jsonb)
returns jsonb language sql immutable set search_path = '' as $$
  select case coalesce(q->>'kind', 'essay')
    when 'single_choice' then q->'correctOptionIds'
    when 'multiple_choice' then q->'correctOptionIds'
    when 'true_false' then q->'correctChoice'
    when 'short_answer' then case when jsonb_typeof(q->'acceptedAnswers') = 'array'
      and jsonb_array_length(q->'acceptedAnswers') > 0 then q->'acceptedAnswers' end
    else null end;
$$;

-- Null when the draft question is complete and coherent, else the problem.
create or replace function private.assessment_question_problem(q jsonb)
returns text language plpgsql immutable set search_path = '' as $$
declare
  v_kind text := coalesce(q->>'kind', 'essay');
  v_options jsonb := coalesce(q->'options', '[]'::jsonb);
  v_key jsonb := private.assessment_draft_key(q);
  v_ids text[];
  v_score numeric;
begin
  if char_length(btrim(coalesce(q->>'prompt', ''))) not between 1 and 10000 then
    return 'prompt';
  end if;
  v_score := (q->>'maximumScore')::numeric;
  if v_score is null or v_score <= 0 or v_score > 1000 then return 'score'; end if;
  if char_length(coalesce(q->>'markingGuidance', '')) > 10000
     or char_length(coalesce(q->>'preferredAnswer', '')) > 30000 then
    return 'too_long';
  end if;
  if jsonb_typeof(v_options) <> 'array' then return 'options'; end if;
  case v_kind
    when 'single_choice', 'multiple_choice' then
      if jsonb_array_length(v_options) not between 2 and 10 then return 'options'; end if;
      if exists (select 1 from jsonb_array_elements(v_options) o
          where jsonb_typeof(o) <> 'object'
            or char_length(coalesce(o->>'id', '')) not between 1 and 40
            or char_length(btrim(coalesce(o->>'text', ''))) not between 1 and 1000) then
        return 'options';
      end if;
      select array_agg(o->>'id') into v_ids from jsonb_array_elements(v_options) o;
      if cardinality(v_ids) <> (select count(distinct x) from unnest(v_ids) x) then
        return 'options';
      end if;
      if jsonb_typeof(v_key) <> 'array' or jsonb_array_length(v_key) = 0
         or exists (select 1 from jsonb_array_elements_text(v_key) k where not (k = any(v_ids)))
         or jsonb_array_length(v_key) <> (select count(distinct k) from jsonb_array_elements_text(v_key) k) then
        return 'answer_key';
      end if;
      if v_kind = 'single_choice' and jsonb_array_length(v_key) <> 1 then return 'answer_key'; end if;
    when 'true_false' then
      if jsonb_typeof(v_key) <> 'boolean' then return 'answer_key'; end if;
    when 'short_answer' then
      if v_key is not null and jsonb_typeof(v_key) <> 'null' and (
          jsonb_typeof(v_key) <> 'array' or jsonb_array_length(v_key) not between 1 and 20
          or exists (select 1 from jsonb_array_elements(v_key) k
            where jsonb_typeof(k) <> 'string' or char_length(btrim(k #>> '{}')) not between 1 and 500)) then
        return 'answer_key';
      end if;
    when 'essay' then null;
    else return 'kind';
  end case;
  return null;
end;
$$;

-- Comparable form of a short answer: case, outer spaces and runs of spaces
-- do not matter.
create or replace function private.short_answer_norm(p text)
returns text language sql immutable set search_path = '' as $$
  select regexp_replace(lower(btrim(coalesce(p, ''))), '[[:space:]]+', ' ', 'g');
$$;

-- The automatic mark for one answer, or null when a person must mark it.
create or replace function private.assessment_auto_mark(
  q public.assessment_questions, p_selected jsonb, p_text text)
returns numeric language plpgsql immutable set search_path = '' as $$
declare
  v_answered boolean := (p_selected is not null and jsonb_typeof(p_selected) <> 'null')
    or char_length(btrim(coalesce(p_text, ''))) > 0;
begin
  if not v_answered then return 0; end if;
  case q.kind
    when 'single_choice', 'multiple_choice' then
      if jsonb_typeof(p_selected) = 'array'
         and (select coalesce(array_agg(distinct x order by x), '{}') from jsonb_array_elements_text(p_selected) x)
           = (select coalesce(array_agg(distinct x order by x), '{}') from jsonb_array_elements_text(q.answer_key) x) then
        return q.maximum_score;
      end if;
      return 0;
    when 'true_false' then
      return case when p_selected = q.answer_key then q.maximum_score else 0 end;
    when 'short_answer' then
      if q.answer_key is null or jsonb_typeof(q.answer_key) <> 'array' then return null; end if;
      return case when exists (select 1 from jsonb_array_elements_text(q.answer_key) k
          where private.short_answer_norm(k) = private.short_answer_norm(p_text))
        then q.maximum_score else 0 end;
    else return null;
  end case;
end;
$$;

-- One question as each reader may see it. 'author' is everything, for the
-- class's teachers; 'student' never carries the key, the model answer or
-- the marking guidance; 'review' carries them, and is only ever built once
-- answers are released (or for staff).
create or replace function private.assessment_question_json(
  q public.assessment_questions, p_mode text)
returns jsonb language sql stable security definer set search_path = '' as $$
  select jsonb_build_object(
      'id', q.id, 'position', q.position, 'prompt', q.prompt,
      'maximumScore', q.maximum_score, 'kind', q.kind, 'required', q.required,
      'options', (select coalesce(jsonb_agg(jsonb_build_object('id', o->>'id', 'text', o->>'text')
        order by ord), '[]'::jsonb) from jsonb_array_elements(q.options) with ordinality t(o, ord)),
      'attachments', private.coursework_files_json(p_question => q.id),
      'links', private.content_links_json(p_question => q.id))
    || case when p_mode in ('author', 'review') then jsonb_build_object(
      'correctOptionIds', case when q.kind in ('single_choice', 'multiple_choice') then q.answer_key end,
      'correctChoice', case when q.kind = 'true_false' then q.answer_key end,
      'acceptedAnswers', case when q.kind = 'short_answer' then q.answer_key end,
      'preferredAnswer', q.preferred_answer,
      'markingGuidance', q.marking_guidance) else '{}'::jsonb end;
$$;

create or replace function private.assessment_questions_json(p_assessment uuid, p_mode text)
returns jsonb language sql stable security definer set search_path = '' as $$
  select coalesce(jsonb_agg(private.assessment_question_json(q, p_mode) order by q.position), '[]'::jsonb)
  from public.assessment_questions q where q.assessment_id = p_assessment;
$$;

-- ===========================================================================
-- 7. Read models of the work, with links and settings
-- ===========================================================================

create or replace function private.api041_assessment_json(p_id uuid)
returns jsonb language sql stable security definer set search_path = '' as $$
  select jsonb_build_object('id',a.id,'classroomId',a.classroom_id,'title',a.title,
    'category',a.category,'maximumScore',a.maximum_score,'scheduledAt',a.scheduled_at,
    'delivery',a.delivery,'state',a.state,'version',a.version,
    'attachments',private.file_attachment_json(p_assessment => a.id),
    'links',private.content_links_json(p_assessment => a.id),
    'assignmentId',a.assignment_id,'weight',a.category_weight,
    'opensAt',a.opens_at,'closesAt',a.closes_at,'maxAttempts',a.max_attempts,
    'attemptPolicy',a.attempt_policy,'answerRelease',a.answer_release,
    'answersReleasedAt',a.answers_released_at,
    'questionCount',(select count(*) from public.assessment_questions q where q.assessment_id = a.id))
  from public.assessments a where a.id=p_id;
$$;

-- Copied from 202609300003 with the work's links added.
create or replace function private.api041_assignment_json(p_id uuid)
returns jsonb language sql stable security definer set search_path = '' as $$
  select jsonb_build_object('id',a.id,'classroomId',a.classroom_id,'title',a.title,
    'instructions',a.instructions,'dueAt',a.due_at,'closesAt',a.closes_at,
    'state',a.state,'version',a.version,'submissionId',s.id,'submittedAt',s.submitted_at,
    'attachments',private.file_attachment_json(p_assignment => a.id),
    'links',private.content_links_json(p_assignment => a.id),
    'maximumScore',(select g.maximum_score from public.assessments g
      where g.assignment_id = a.id and g.deleted_at is null limit 1),
    'timeZone',sc.timezone,
    'dueLocal',private.school_local_text(a.school_id, a.due_at),
    'closesLocal',private.school_local_text(a.school_id, a.closes_at))
  || coalesce(private.assignment_student_json(a.id, own.id), '{}'::jsonb)
  from public.assignments a
  join public.schools sc on sc.id = a.school_id
  left join lateral (
    select st.id from public.students st
    join public.enrollments e on e.student_id = st.id and e.classroom_id = a.classroom_id
    where st.user_id = auth.uid() and st.deleted_at is null
    limit 1
  ) own on true
  left join lateral (
    select su.id,su.submitted_at from public.submissions su
    where su.assignment_id=a.id and su.student_id = own.id limit 1
  ) s on true where a.id=p_id;
$$;

-- Copied from 202609300004: a lesson carries every file bound to its
-- current version, and its links.
create or replace function private.api041_resource_json(p_id uuid)
returns jsonb language sql stable security definer set search_path = '' as $function$
  select jsonb_build_object(
    'id',r.id,'schoolId',r.school_id,'classroomId',rp.classroom_id,'title',r.title,
    'resourceType',r.resource_type,'body',rv.body,'state',r.state,
    'version',r.version,'publishedAt',rp.published_at,
    'attachments',coalesce((select jsonb_agg(jsonb_build_object(
        'id', fo.id, 'displayName', fo.display_name, 'sizeBytes', fo.size_bytes,
        'mediaType', fo.declared_media_type, 'scanState', fo.scan_state)
        order by (fo.id = rv.file_object_id) desc, fo.created_at, fo.id)
      from public.file_objects fo
      where fo.deleted_at is null and (fo.id = rv.file_object_id or exists (
        select 1 from public.file_bindings b where b.file_object_id = fo.id
          and b.resource_version_id = rv.id and b.detached_at is null
          and b.role = 'material'))), '[]'::jsonb),
    'links',private.content_links_json(p_resource_version => rv.id)
  ) from public.resources r
  join public.resource_versions rv on rv.resource_id=r.id and rv.version=r.current_version
  left join lateral (select x.classroom_id,x.published_at from public.resource_publications x
    where x.resource_version_id=rv.id order by x.created_at desc limit 1) rp on true
  where r.id=p_id;
$function$;

-- A grade carries its own attachments, and the shared results of its
-- assessment - only once published, unless the reader is the class's staff.
create or replace function private.api041_grade_json(p_id uuid)
returns jsonb language sql stable security definer set search_path = '' as $$
  select jsonb_build_object('id',g.id,'assessmentId',g.assessment_id,'studentId',g.student_id,
    'assessmentTitle',a.title,'category',a.category,
    'score',g.score,'maximumScore',a.maximum_score,'feedback',g.feedback,'state',g.state,
    'version',g.version,'reviewedAt',g.reviewed_at,'publishedAt',g.published_at,
    'delivery',a.delivery,'mark',private.grade_mark_of(g.mark,g.score),
    'weight',a.category_weight,'assignmentId',a.assignment_id)
  || case when g.state = 'published' or private.coursework_staff(a.classroom_id) then
    jsonb_build_object(
      'attachments', private.coursework_files_json(p_grade_result => g.id),
      'links', private.content_links_json(p_grade_result => g.id),
      'sharedAttachments', private.coursework_files_json(p_assessment => a.id, p_role => 'results'),
      'sharedLinks', private.content_links_json(p_assessment => a.id, p_role => 'results'))
    else jsonb_build_object('attachments', '[]'::jsonb, 'links', '[]'::jsonb,
      'sharedAttachments', '[]'::jsonb, 'sharedLinks', '[]'::jsonb) end
  from public.grade_results g join public.assessments a on a.id=g.assessment_id where g.id=p_id;
$$;

-- ===========================================================================
-- 8. Grades from attempts
-- ===========================================================================

-- Recomputes one student's draft grade from their attempts. A grade already
-- published or withdrawn is the teacher's to correct and is left alone.
create or replace function private.assessment_sync_grade(p_assessment uuid, p_student uuid)
returns void language plpgsql security definer set search_path = '' as $$
declare
  a public.assessments%rowtype;
  v_pending boolean;
  v_score numeric;
  v_marker uuid;
begin
  select * into a from public.assessments x where x.id = p_assessment;
  if a.id is null then return; end if;
  if not exists (select 1 from public.assessment_attempts t
      where t.assessment_id = a.id and t.student_id = p_student) then
    return;
  end if;
  select bool_or(t.needs_marking) into v_pending from public.assessment_attempts t
  where t.assessment_id = a.id and t.student_id = p_student;
  if a.attempt_policy = 'latest' then
    select t.awarded_score, t.marked_by into v_score, v_marker from public.assessment_attempts t
    where t.assessment_id = a.id and t.student_id = p_student
    order by t.attempt_number desc nulls last, t.submitted_at desc limit 1;
  else
    select t.awarded_score, t.marked_by into v_score, v_marker from public.assessment_attempts t
    where t.assessment_id = a.id and t.student_id = p_student and not t.needs_marking
    order by t.awarded_score desc nulls last limit 1;
  end if;

  insert into public.grade_results as g(school_id, assessment_id, student_id, score, state, version)
  values (a.school_id, a.id, p_student, null, 'draft', 1)
  on conflict (assessment_id, student_id) do nothing;

  update public.grade_results g set
    score = case when v_pending then null else v_score end,
    mark = case when v_pending then null else 'scored'::public.grade_mark end,
    state = (case when v_pending or v_score is null then 'draft' else 'reviewed' end)::public.publication_state,
    -- An automatic mark is the key the class's teacher wrote.
    reviewed_by = case when v_pending or v_score is null then null
      else coalesce(v_marker, a.created_by) end,
    reviewed_at = case when v_pending or v_score is null then null else now() end,
    version = g.version + 1, updated_at = now()
  where g.assessment_id = a.id and g.student_id = p_student
    and g.state in ('draft', 'reviewed')
    and (g.score, g.state) is distinct from
      (case when v_pending then null else v_score end,
       (case when v_pending or v_score is null then 'draft' else 'reviewed' end)::public.publication_state);
  update public.assessments set gradebook_version = gradebook_version + 1 where id = a.id;
end;
$$;

-- ===========================================================================
-- 9. Commands
-- ===========================================================================

-- Writes a full question list onto an assessment: questions keep their ids,
-- new ones are added, missing ones are removed. Files and links of each
-- question are attached by position. Returns null or the problem.
create or replace function private.assessment_write_questions(
  a public.assessments, p_questions jsonb)
returns text language plpgsql security definer set search_path = '' as $$
declare
  v_item jsonb;
  v_pos int := 0;
  v_qid uuid;
  v_keep uuid[] := array[]::uuid[];
  v_result text;
  v_problem text;
begin
  if p_questions is null or jsonb_typeof(p_questions) <> 'array'
     or jsonb_array_length(p_questions) > 100 then
    return 'invalid';
  end if;
  for v_item in select value from jsonb_array_elements(p_questions) loop
    v_problem := private.assessment_question_problem(v_item);
    if v_problem is not null then return 'invalid'; end if;
  end loop;

  -- Questions dropped from the list go, with their files and links.
  select coalesce(array_agg((x->>'id')::uuid), array[]::uuid[]) into v_keep
  from jsonb_array_elements(p_questions) x where nullif(x->>'id', '') is not null;
  if exists (select 1 from unnest(v_keep) k where not exists (
      select 1 from public.assessment_questions q where q.id = k and q.assessment_id = a.id)) then
    return 'invalid';
  end if;
  delete from public.assessment_questions q
  where q.assessment_id = a.id and not (q.id = any(v_keep));
  -- Positions are rewritten in two steps so a reorder never collides.
  update public.assessment_questions set position = position + 100000
  where assessment_id = a.id;

  for v_item in select value from jsonb_array_elements(p_questions) loop
    v_pos := v_pos + 1;
    v_qid := nullif(v_item->>'id', '')::uuid;
    if v_qid is null then
      insert into public.assessment_questions(school_id, assessment_id, position, prompt,
        preferred_answer, maximum_score, kind, options, answer_key, marking_guidance, required)
      values (a.school_id, a.id, v_pos, btrim(v_item->>'prompt'),
        nullif(v_item->>'preferredAnswer', ''), (v_item->>'maximumScore')::numeric,
        coalesce(v_item->>'kind', 'essay'), coalesce(v_item->'options', '[]'::jsonb),
        private.assessment_draft_key(v_item),
        nullif(v_item->>'markingGuidance', ''), coalesce((v_item->>'required')::boolean, true))
      returning id into v_qid;
    else
      update public.assessment_questions set position = v_pos, prompt = btrim(v_item->>'prompt'),
        preferred_answer = nullif(v_item->>'preferredAnswer', ''),
        maximum_score = (v_item->>'maximumScore')::numeric,
        kind = coalesce(v_item->>'kind', 'essay'),
        options = coalesce(v_item->'options', '[]'::jsonb),
        answer_key = private.assessment_draft_key(v_item),
        marking_guidance = nullif(v_item->>'markingGuidance', ''),
        required = coalesce((v_item->>'required')::boolean, true), updated_at = now()
      where id = v_qid;
    end if;
    perform private.coursework_detach_files(v_item->'detachFileIds', p_question => v_qid);
    perform private.content_links_detach(v_item->'removeLinkIds', p_question => v_qid);
    v_result := private.coursework_attach_files(v_item->'attachmentFileIds',
      'assignment_material', a.school_id, a.classroom_id, p_question => v_qid, p_max => 5);
    if v_result <> 'ok' then return v_result; end if;
    v_result := private.content_links_attach(v_item->'links', a.school_id,
      p_question => v_qid, p_max => 5);
    if v_result <> 'ok' then return v_result; end if;
  end loop;

  update public.assessments set maximum_score = coalesce((select sum(q.maximum_score)
    from public.assessment_questions q where q.assessment_id = a.id), maximum_score)
  where id = a.id and exists (select 1 from public.assessment_questions q where q.assessment_id = a.id);
  return null;
end;
$$;

-- The settings of an online assessment, from a create or design body.
create or replace function private.assessment_write_settings(a public.assessments, body jsonb)
returns text language plpgsql security definer set search_path = '' as $$
declare
  v_opens timestamptz := a.opens_at;
  v_closes timestamptz := a.closes_at;
begin
  if body ? 'opensAt' then v_opens := nullif(body->>'opensAt', '')::timestamptz; end if;
  if body ? 'closesAt' then v_closes := nullif(body->>'closesAt', '')::timestamptz; end if;
  if v_opens is not null and v_closes is not null and v_closes <= v_opens then return 'invalid'; end if;
  if body ? 'maxAttempts' and ((body->>'maxAttempts')::int not between 1 and 20) then return 'invalid'; end if;
  if body ? 'attemptPolicy' and body->>'attemptPolicy' not in ('best', 'latest') then return 'invalid'; end if;
  if body ? 'answerRelease' and body->>'answerRelease' not in ('after_close', 'after_grading', 'manual') then
    return 'invalid';
  end if;
  update public.assessments set opens_at = v_opens, closes_at = v_closes,
    max_attempts = coalesce((body->>'maxAttempts')::int, max_attempts),
    attempt_policy = coalesce(body->>'attemptPolicy', attempt_policy),
    answer_release = coalesce(body->>'answerRelease', answer_release),
    answers_released_at = case
      when coalesce(body->>'answerRelease', answer_release) <> 'manual' then null
      when (body->>'releaseAnswersNow')::boolean then coalesce(answers_released_at, now())
      else answers_released_at end
  where id = a.id;
  return null;
end;
$$;

-- updateAssessmentDesign: the questions and settings of an assessment. The
-- questions only while nobody has attempted it; the settings (window,
-- attempts, release) at any time.
create or replace function private.api041_update_assessment_design(
  p_assessment uuid, p_input jsonb, p_idempotency_id uuid, p_idempotency_generation bigint)
returns jsonb language plpgsql security definer set search_path = '' as $$
declare
  body jsonb := coalesce(p_input->'body', '{}'::jsonb);
  v_key text;
  a public.assessments%rowtype;
  v_problem text;
  v_before jsonb;
begin
  v_key := private.coursework_idempotency_key(p_idempotency_id, p_idempotency_generation);
  if v_key is null then return jsonb_build_object('outcome', 'forbidden'); end if;
  select * into a from public.assessments x where x.id = p_assessment and x.deleted_at is null for update;
  if a.id is null then return jsonb_build_object('outcome', 'not_found'); end if;
  if a.school_id <> nullif(current_setting('studafy.school_id', true), '')::uuid
     or not private.coursework_teacher(a.classroom_id) then
    return jsonb_build_object('outcome', 'forbidden');
  end if;
  if a.version <> (body->>'expectedVersion')::bigint then
    return jsonb_build_object('outcome', 'version_conflict');
  end if;
  if a.delivery = 'paper' then return jsonb_build_object('outcome', 'invalid_state'); end if;
  v_before := private.api041_assessment_json(a.id);

  begin
    if body ? 'questions' then
      if exists (select 1 from public.assessment_attempts t where t.assessment_id = a.id) then
        raise exception using errcode = 'SF046', message = 'invalid_state';
      end if;
      v_problem := private.assessment_write_questions(a, body->'questions');
      if v_problem is not null then raise exception using errcode = 'SF046', message = v_problem; end if;
    end if;
    if body ? 'title' then
      if char_length(btrim(body->>'title')) not between 1 and 200 then
        raise exception using errcode = 'SF046', message = 'invalid';
      end if;
      update public.assessments set title = btrim(body->>'title') where id = a.id;
    end if;
    select * into a from public.assessments x where x.id = a.id;
    v_problem := private.assessment_write_settings(a, body);
    if v_problem is not null then raise exception using errcode = 'SF046', message = v_problem; end if;
    -- Manual release is still only ever after everyone has finished.
    if (body->>'releaseAnswersNow')::boolean and not private.assessment_closed_for_all(a.id) then
      raise exception using errcode = 'SF046', message = 'window_closed';
    end if;
    perform private.coursework_detach_files(body->'detachFileIds', p_assessment => a.id);
    perform private.content_links_detach(body->'removeLinkIds', p_assessment => a.id);
    v_problem := private.content_links_attach(body->'links', a.school_id, p_assessment => a.id);
    if v_problem <> 'ok' then raise exception using errcode = 'SF046', message = v_problem; end if;
    v_problem := private.coursework_attach_files(body->'attachmentFileIds', 'assignment_material',
      a.school_id, a.classroom_id, p_assessment => a.id);
    if v_problem <> 'ok' then raise exception using errcode = 'SF046', message = v_problem; end if;
  exception when sqlstate 'SF046' then
    return jsonb_build_object('outcome', sqlerrm);
  end;

  update public.assessments set version = version + 1, updated_at = now() where id = a.id;
  return private.coursework_finish(p_idempotency_id, p_idempotency_generation, 200,
    'assessment_designed', 'assessment', a.id, v_before,
    jsonb_build_object('operation', 'updateAssessmentDesign',
      'questions', body ? 'questions', 'release', body->>'answerRelease',
      'releasedNow', coalesce((body->>'releaseAnswersNow')::boolean, false)),
    private.api041_assessment_json(a.id));
end;
$$;

-- grantAssessmentAccess: more time and/or more attempts for one student.
create or replace function private.api041_grant_assessment_access(
  p_assessment uuid, p_input jsonb, p_idempotency_id uuid, p_idempotency_generation bigint)
returns jsonb language plpgsql security definer set search_path = '' as $$
declare
  body jsonb := coalesce(p_input->'body', '{}'::jsonb);
  v_key text;
  a public.assessments%rowtype;
  v_student uuid := nullif(body->>'studentId', '')::uuid;
  v_closes timestamptz := nullif(body->>'closesAt', '')::timestamptz;
  v_extra int := coalesce((body->>'extraAttempts')::int, 0);
begin
  v_key := private.coursework_idempotency_key(p_idempotency_id, p_idempotency_generation);
  if v_key is null then return jsonb_build_object('outcome', 'forbidden'); end if;
  select * into a from public.assessments x where x.id = p_assessment and x.deleted_at is null for update;
  if a.id is null then return jsonb_build_object('outcome', 'not_found'); end if;
  if a.school_id <> nullif(current_setting('studafy.school_id', true), '')::uuid
     or not private.coursework_teacher(a.classroom_id) then
    return jsonb_build_object('outcome', 'forbidden');
  end if;
  if a.delivery = 'paper' then return jsonb_build_object('outcome', 'invalid_state'); end if;
  if v_student is null or not exists (select 1 from public.enrollments e
      where e.classroom_id = a.classroom_id and e.student_id = v_student
        and e.active and e.status = 'active') then
    return jsonb_build_object('outcome', 'invalid');
  end if;
  if v_extra not between 0 and 20 or (v_closes is not null and v_closes <= now())
     or (v_closes is null and v_extra = 0) then
    return jsonb_build_object('outcome', 'invalid');
  end if;
  insert into public.assessment_access_grants as g(school_id, assessment_id, student_id,
    closes_at, extra_attempts, reason, granted_by)
  values (a.school_id, a.id, v_student, v_closes, v_extra,
    nullif(btrim(body->>'reason'), ''), auth.uid())
  on conflict (assessment_id, student_id) do update set
    closes_at = excluded.closes_at, extra_attempts = excluded.extra_attempts,
    reason = excluded.reason, granted_by = excluded.granted_by, updated_at = now();
  return private.coursework_finish(p_idempotency_id, p_idempotency_generation, 200,
    'assessment_access_granted', 'assessment', a.id, null,
    jsonb_build_object('studentId', v_student, 'closesAt', v_closes, 'extraAttempts', v_extra),
    jsonb_build_object('studentId', v_student, 'closesAt', v_closes, 'extraAttempts', v_extra));
end;
$$;

-- submitAssessment: one attempt by the student themself. Never by a
-- guardian. Marks what has a key at once; the confirmation carries no mark.
create or replace function private.api041_submit_assessment(
  p_assessment uuid, p_input jsonb, p_idempotency_id uuid, p_idempotency_generation bigint)
returns jsonb language plpgsql security definer set search_path = '' as $$
declare
  body jsonb := coalesce(p_input->'body', '{}'::jsonb);
  v_key text;
  a public.assessments%rowtype;
  v_student uuid;
  t record;
  v_attempt uuid;
  v_number int;
  q public.assessment_questions%rowtype;
  v_answer jsonb;
  v_selected jsonb;
  v_text text;
  v_auto numeric;
  v_pending boolean := false;
  v_total numeric := 0;
begin
  v_key := private.coursework_idempotency_key(p_idempotency_id, p_idempotency_generation);
  if v_key is null then return jsonb_build_object('outcome', 'forbidden'); end if;
  select * into a from public.assessments x
  where x.id = p_assessment and x.deleted_at is null and x.delivery in ('online', 'practice')
  for update;
  if a.id is null then return jsonb_build_object('outcome', 'not_found'); end if;
  v_student := private.coursework_own_student(a.classroom_id);
  if a.school_id <> nullif(current_setting('studafy.school_id', true), '')::uuid
     or v_student is null then
    return jsonb_build_object('outcome', 'forbidden');
  end if;
  if a.state <> 'published' then return jsonb_build_object('outcome', 'invalid_state'); end if;
  select * into t from private.assessment_student_terms(a.id, v_student);
  if (t.opens_at is not null and now() < t.opens_at)
     or (t.closes_at is not null and now() >= t.closes_at) then
    return jsonb_build_object('outcome', 'window_closed');
  end if;
  if t.attempts_used >= t.attempts_allowed then
    return jsonb_build_object('outcome', 'invalid_state');
  end if;

  -- Every answer names a question of this assessment, once.
  if jsonb_typeof(body->'answers') <> 'array'
     or (select count(*) <> count(distinct x->>'questionId') from jsonb_array_elements(body->'answers') x)
     or exists (select 1 from jsonb_array_elements(body->'answers') x where not exists (
       select 1 from public.assessment_questions qq
       where qq.assessment_id = a.id and qq.id = (x->>'questionId')::uuid)) then
    return jsonb_build_object('outcome', 'invalid');
  end if;

  v_number := t.attempts_used + 1;
  insert into public.assessment_attempts(school_id, assessment_id, student_id, operation_id, attempt_number)
  values (a.school_id, a.id, v_student, p_idempotency_id, v_number) returning id into v_attempt;

  for q in select * from public.assessment_questions qq where qq.assessment_id = a.id order by qq.position loop
    select x into v_answer from jsonb_array_elements(body->'answers') x
    where (x->>'questionId')::uuid = q.id;
    v_selected := null;
    v_text := '';
    if v_answer is not null then
      v_text := coalesce(v_answer->>'answerText', '');
      if char_length(v_text) > 30000 then raise exception using errcode = 'SF047', message = 'invalid'; end if;
      if q.kind in ('single_choice', 'multiple_choice') and jsonb_typeof(v_answer->'selectedOptionIds') = 'array'
         and jsonb_array_length(v_answer->'selectedOptionIds') > 0 then
        v_selected := v_answer->'selectedOptionIds';
        if exists (select 1 from jsonb_array_elements_text(v_selected) s
            where not exists (select 1 from jsonb_array_elements(q.options) o where o->>'id' = s))
           or (q.kind = 'single_choice' and jsonb_array_length(v_selected) <> 1) then
          raise exception using errcode = 'SF047', message = 'invalid';
        end if;
      elsif q.kind = 'true_false' and jsonb_typeof(v_answer->'choice') = 'boolean' then
        v_selected := v_answer->'choice';
      end if;
      if q.kind not in ('short_answer', 'essay') then v_text := ''; end if;
    end if;
    if q.required and v_selected is null and char_length(btrim(v_text)) = 0 then
      raise exception using errcode = 'SF047', message = 'invalid';
    end if;
    v_auto := private.assessment_auto_mark(q, v_selected, v_text);
    if v_auto is null then v_pending := true; else v_total := v_total + v_auto; end if;
    insert into public.assessment_answers(school_id, attempt_id, question_id, answer_text,
      selected, auto_score, awarded_score)
    values (a.school_id, v_attempt, q.id, v_text, v_selected, v_auto, v_auto);
  end loop;

  update public.assessment_attempts set needs_marking = v_pending,
    awarded_score = case when v_pending then null else v_total end,
    marked_at = case when v_pending then null else now() end
  where id = v_attempt;
  perform private.assessment_sync_grade(a.id, v_student);

  return private.coursework_finish(p_idempotency_id, p_idempotency_generation, 201,
    'assessment_submitted', 'assessment_attempt', v_attempt, null,
    jsonb_build_object('assessmentId', a.id, 'attemptNumber', v_number),
    jsonb_build_object('id', v_attempt, 'assessmentId', a.id, 'studentId', v_student,
      'attemptNumber', v_number, 'submittedAt', now(),
      'attemptsRemaining', greatest(t.attempts_allowed - v_number, 0), 'version', 1));
exception when sqlstate 'SF047' then
  return jsonb_build_object('outcome', sqlerrm);
end;
$$;

-- markAssessmentAttempt: a teacher's marks for written answers (or an
-- override of an automatic one), and feedback on the attempt.
create or replace function private.api041_mark_assessment_attempt(
  p_attempt uuid, p_input jsonb, p_idempotency_id uuid, p_idempotency_generation bigint)
returns jsonb language plpgsql security definer set search_path = '' as $$
declare
  body jsonb := coalesce(p_input->'body', '{}'::jsonb);
  v_key text;
  t public.assessment_attempts%rowtype;
  a public.assessments%rowtype;
  v_mark jsonb;
  v_max numeric;
  v_pending boolean;
  v_total numeric;
begin
  v_key := private.coursework_idempotency_key(p_idempotency_id, p_idempotency_generation);
  if v_key is null then return jsonb_build_object('outcome', 'forbidden'); end if;
  select * into t from public.assessment_attempts x where x.id = p_attempt for update;
  if t.id is null then return jsonb_build_object('outcome', 'not_found'); end if;
  select * into a from public.assessments x where x.id = t.assessment_id for update;
  if a.school_id <> nullif(current_setting('studafy.school_id', true), '')::uuid
     or not private.coursework_teacher(a.classroom_id) then
    return jsonb_build_object('outcome', 'forbidden');
  end if;
  if jsonb_typeof(body->'marks') <> 'array' then return jsonb_build_object('outcome', 'invalid'); end if;
  for v_mark in select value from jsonb_array_elements(body->'marks') loop
    select q.maximum_score into v_max from public.assessment_questions q
    join public.assessment_answers aa on aa.question_id = q.id and aa.attempt_id = t.id
    where q.id = (v_mark->>'questionId')::uuid;
    if v_max is null or (v_mark->>'score')::numeric is null
       or (v_mark->>'score')::numeric < 0 or (v_mark->>'score')::numeric > v_max
       or char_length(coalesce(v_mark->>'feedback', '')) > 5000 then
      return jsonb_build_object('outcome', 'invalid');
    end if;
    update public.assessment_answers set awarded_score = (v_mark->>'score')::numeric,
      feedback = nullif(btrim(v_mark->>'feedback'), ''), marked_by = auth.uid(), marked_at = now()
    where attempt_id = t.id and question_id = (v_mark->>'questionId')::uuid;
  end loop;
  select bool_or(aa.awarded_score is null), sum(aa.awarded_score) into v_pending, v_total
  from public.assessment_answers aa where aa.attempt_id = t.id;
  update public.assessment_attempts set needs_marking = coalesce(v_pending, false),
    awarded_score = case when coalesce(v_pending, false) then null else v_total end,
    feedback = case when body ? 'feedback' then nullif(btrim(body->>'feedback'), '') else feedback end,
    marked_by = auth.uid(), marked_at = now()
  where id = t.id;
  perform private.assessment_sync_grade(a.id, t.student_id);
  return private.coursework_finish(p_idempotency_id, p_idempotency_generation, 200,
    'assessment_attempt_marked', 'assessment_attempt', t.id, null,
    jsonb_build_object('marks', jsonb_array_length(body->'marks')),
    private.assessment_attempt_json(t.id, 'staff'));
end;
$$;

-- updateGradeAttachments: the paper grade's shared attachments (the class)
-- or one student's own. Private until that student's grade is published.
create or replace function private.api041_update_grade_attachments(
  p_assessment uuid, p_input jsonb, p_idempotency_id uuid, p_idempotency_generation bigint)
returns jsonb language plpgsql security definer set search_path = '' as $$
declare
  body jsonb := coalesce(p_input->'body', '{}'::jsonb);
  v_key text;
  a public.assessments%rowtype;
  v_student uuid := nullif(body->>'studentId', '')::uuid;
  v_grade uuid;
  v_result text;
begin
  v_key := private.coursework_idempotency_key(p_idempotency_id, p_idempotency_generation);
  if v_key is null then return jsonb_build_object('outcome', 'forbidden'); end if;
  select * into a from public.assessments x where x.id = p_assessment and x.deleted_at is null for update;
  if a.id is null then return jsonb_build_object('outcome', 'not_found'); end if;
  if a.school_id <> nullif(current_setting('studafy.school_id', true), '')::uuid
     or not private.coursework_teacher(a.classroom_id) then
    return jsonb_build_object('outcome', 'forbidden');
  end if;
  if v_student is not null then
    if not exists (select 1 from public.grade_results g where g.assessment_id = a.id and g.student_id = v_student)
       and not exists (select 1 from public.enrollments e where e.classroom_id = a.classroom_id
         and e.student_id = v_student and e.active and e.status = 'active') then
      return jsonb_build_object('outcome', 'invalid');
    end if;
    insert into public.grade_results(school_id, assessment_id, student_id, score, state, version)
    values (a.school_id, a.id, v_student, null, 'draft', 1)
    on conflict (assessment_id, student_id) do nothing;
    select g.id into v_grade from public.grade_results g where g.assessment_id = a.id and g.student_id = v_student;
  end if;

  begin
    if v_grade is null then
      perform private.coursework_detach_files(body->'detachFileIds', p_assessment => a.id, p_role => 'results');
      perform private.content_links_detach(body->'removeLinkIds', p_assessment => a.id, p_role => 'results');
      v_result := private.coursework_attach_files(body->'attachmentFileIds', 'paper_scan',
        a.school_id, a.classroom_id, p_assessment => a.id, p_role => 'results');
      if v_result <> 'ok' then raise exception using errcode = 'SF048', message = v_result; end if;
      v_result := private.content_links_attach(body->'links', a.school_id,
        p_assessment => a.id, p_role => 'results');
    else
      perform private.coursework_detach_files(body->'detachFileIds', p_grade_result => v_grade);
      perform private.content_links_detach(body->'removeLinkIds', p_grade_result => v_grade);
      v_result := private.coursework_attach_files(body->'attachmentFileIds', 'paper_scan',
        a.school_id, a.classroom_id, p_grade_result => v_grade);
      if v_result <> 'ok' then raise exception using errcode = 'SF048', message = v_result; end if;
      v_result := private.content_links_attach(body->'links', a.school_id, p_grade_result => v_grade);
    end if;
    if v_result <> 'ok' then raise exception using errcode = 'SF048', message = v_result; end if;
  exception when sqlstate 'SF048' then
    return jsonb_build_object('outcome', sqlerrm);
  end;

  update public.assessments set gradebook_version = gradebook_version + 1 where id = a.id;
  return private.coursework_finish(p_idempotency_id, p_idempotency_generation, 200,
    'grade_attachments_updated', 'assessment', a.id, null,
    jsonb_build_object('studentId', v_student,
      'attached', body->'attachmentFileIds', 'detached', body->'detachFileIds'),
    private.grade_attachments_json(a.id, v_grade));
end;
$$;

create or replace function private.grade_attachments_json(p_assessment uuid, p_grade uuid)
returns jsonb language sql stable security definer set search_path = '' as $$
  select case when p_grade is null then jsonb_build_object(
      'attachments', private.coursework_files_json(p_assessment => p_assessment, p_role => 'results'),
      'links', private.content_links_json(p_assessment => p_assessment, p_role => 'results'))
    else jsonb_build_object('gradeResultId', p_grade,
      'attachments', private.coursework_files_json(p_grade_result => p_grade),
      'links', private.content_links_json(p_grade_result => p_grade)) end;
$$;

-- Links on set work, then the files through the existing handler. A refusal
-- from it undoes the links too.
create or replace function private.api041_update_work_materials_with_links(
  p_operation text, p_target uuid, p_input jsonb, p_idempotency_id uuid,
  p_idempotency_generation bigint)
returns jsonb language plpgsql security definer set search_path = '' as $$
declare
  body jsonb := coalesce(p_input->'body', '{}'::jsonb);
  v_assignment boolean := p_operation = 'updateAssignmentMaterials';
  v_school uuid;
  v_result jsonb;
  v_links text;
begin
  if v_assignment then
    select a.school_id into v_school from public.assignments a where a.id = p_target;
  else
    select a.school_id into v_school from public.assessments a where a.id = p_target;
  end if;
  if v_school is null then return jsonb_build_object('outcome', 'not_found'); end if;
  begin
    v_result := private.api041_update_work_materials(p_operation, p_target, p_input,
      p_idempotency_id, p_idempotency_generation);
    if coalesce(v_result->>'outcome', '') <> 'ok' then return v_result; end if;
    if v_assignment then
      perform private.content_links_detach(body->'removeLinkIds', p_assignment => p_target);
      v_links := private.content_links_attach(body->'links', v_school, p_assignment => p_target);
    else
      perform private.content_links_detach(body->'removeLinkIds', p_assessment => p_target);
      v_links := private.content_links_attach(body->'links', v_school, p_assessment => p_target);
    end if;
    if v_links <> 'ok' then raise exception using errcode = 'SF049', message = v_links; end if;
  exception when sqlstate 'SF049' then
    return jsonb_build_object('outcome', sqlerrm);
  end;
  -- The answer now carries the links as they are.
  v_result := jsonb_set(v_result, '{response}', case when v_assignment
    then private.api041_assignment_json(p_target) else private.api041_assessment_json(p_target) end);
  update public.idempotency_records r set response_body = v_result->'response'
  where r.id = p_idempotency_id and r.actor_id = auth.uid()
    and r.generation = p_idempotency_generation and r.status = 'completed';
  return v_result;
end;
$$;

-- editResource: the lesson's live files and links carry on to the new
-- version; the request adds and detaches.
create or replace function private.api041_edit_resource_with_attachments(
  p_resource uuid, p_input jsonb, p_idempotency_id uuid, p_idempotency_generation bigint)
returns jsonb language plpgsql security definer set search_path = '' as $$
declare
  body jsonb := coalesce(p_input->'body', '{}'::jsonb);
  v_old uuid;
  v_old_main uuid;
  v_new uuid;
  v_class uuid;
  v_school uuid;
  v_result jsonb;
  v_bind text;
begin
  select rv.id, rv.file_object_id, r.school_id into v_old, v_old_main, v_school from public.resources r
  join public.resource_versions rv on rv.resource_id = r.id and rv.version = r.current_version
  where r.id = p_resource;
  begin
    v_result := private.api041_edit_resource(p_resource, p_input, p_idempotency_id, p_idempotency_generation);
    if coalesce(v_result->>'outcome', '') <> 'ok' then return v_result; end if;
    select rv.id into v_new from public.resources r
    join public.resource_versions rv on rv.resource_id = r.id and rv.version = r.current_version
    where r.id = p_resource;
    select rp.classroom_id into v_class from public.resource_publications rp
    where rp.resource_version_id = v_new order by rp.created_at desc limit 1;
    -- Carry on what was attached and is not being detached. The version's
    -- own file is the edit's to keep or replace, not this.
    insert into public.file_bindings(school_id, file_object_id, resource_version_id, role)
    select b.school_id, b.file_object_id, v_new, b.role from public.file_bindings b
    where b.resource_version_id = v_old and b.detached_at is null
      and b.file_object_id is distinct from v_old_main
      and not exists (select 1 from public.file_bindings nb
        where nb.resource_version_id = v_new and nb.file_object_id = b.file_object_id)
      and not (b.file_object_id::text in (select jsonb_array_elements_text(coalesce(body->'detachFileIds', '[]'::jsonb))));
    insert into public.content_links(school_id, title, url, role, position, resource_version_id, created_by)
    select l.school_id, l.title, l.url, l.role, l.position, v_new, l.created_by from public.content_links l
    where l.resource_version_id = v_old and l.detached_at is null
      and not (l.id::text in (select jsonb_array_elements_text(coalesce(body->'removeLinkIds', '[]'::jsonb))));
    if v_class is not null then
      v_bind := private.coursework_attach_files(body->'attachmentFileIds', 'lesson_resource',
        v_school, v_class, p_resource_version => v_new);
      if v_bind <> 'ok' then raise exception using errcode = 'SF050', message = v_bind; end if;
    end if;
    v_bind := private.content_links_attach(body->'links', v_school, p_resource_version => v_new);
    if v_bind <> 'ok' then raise exception using errcode = 'SF050', message = v_bind; end if;
  exception when sqlstate 'SF050' then
    return jsonb_build_object('outcome', sqlerrm);
  end;
  v_result := jsonb_set(v_result, '{response}', private.api041_resource_json(p_resource));
  update public.idempotency_records r set response_body = v_result->'response'
  where r.id = p_idempotency_id and r.actor_id = auth.uid()
    and r.generation = p_idempotency_generation and r.status = 'completed';
  return v_result;
end;
$$;

-- ===========================================================================
-- 10. Queries
-- ===========================================================================

-- One attempt. 'staff' sees every answer's mark and the key; 'reader' (the
-- student or their parent) sees marks and the key only once released.
create or replace function private.assessment_attempt_json(p_attempt uuid, p_mode text)
returns jsonb language sql stable security definer set search_path = '' as $$
  select jsonb_build_object('id', t.id, 'assessmentId', t.assessment_id,
      'studentId', t.student_id, 'attemptNumber', t.attempt_number,
      'submittedAt', t.submitted_at, 'version', t.version)
    || case when p_mode = 'staff' or private.assessment_answers_released(t.assessment_id) then
      jsonb_build_object('needsMarking', t.needs_marking, 'awardedScore', t.awarded_score,
        'feedback', t.feedback,
        'answers', (select coalesce(jsonb_agg(jsonb_build_object(
            'question', private.assessment_question_json(q, 'review'),
            'answerText', nullif(aa.answer_text, ''),
            'selectedOptionIds', case when jsonb_typeof(aa.selected) = 'array' then aa.selected end,
            'choice', case when jsonb_typeof(aa.selected) = 'boolean' then aa.selected end,
            'autoScore', aa.auto_score, 'awardedScore', aa.awarded_score,
            'feedback', aa.feedback) order by q.position), '[]'::jsonb)
          from public.assessment_answers aa
          join public.assessment_questions q on q.id = aa.question_id
          where aa.attempt_id = t.id))
      else '{}'::jsonb end
  from public.assessment_attempts t where t.id = p_attempt;
$$;

-- getAssessmentResults: one student's own view of an online assessment - or
-- a linked parent's of their child's. Four separate things, each only when
-- authorised and released: the confirmation of each attempt, the published
-- grade, the teacher's feedback on it, and the answers.
create or replace function private.api041_assessment_results(p_assessment uuid, p_input jsonb)
returns jsonb language plpgsql stable security definer set search_path = '' as $$
declare
  a public.assessments%rowtype;
  v_student uuid := nullif(p_input->>'studentId', '')::uuid;
  t record;
  g public.grade_results%rowtype;
  v_released boolean;
begin
  select * into a from public.assessments x where x.id = p_assessment and x.deleted_at is null;
  if a.id is null or a.state <> 'published' then return jsonb_build_object('outcome', 'not_found'); end if;
  if v_student is null then v_student := private.coursework_own_student(a.classroom_id); end if;
  if v_student is null or not private.coursework_reader_of(v_student, a.classroom_id) then
    return jsonb_build_object('outcome', 'not_found');
  end if;
  select * into t from private.assessment_student_terms(a.id, v_student);
  select * into g from public.grade_results x where x.assessment_id = a.id and x.student_id = v_student;
  v_released := private.assessment_answers_released(a.id);
  return jsonb_build_object('outcome', 'ok',
    'assessment', private.api041_assessment_json(a.id),
    'studentId', v_student,
    'opensAt', t.opens_at, 'closesAt', t.closes_at,
    'attemptsAllowed', t.attempts_allowed, 'attemptsUsed', t.attempts_used,
    'canAttempt', a.delivery in ('online', 'practice')
      and exists (select 1 from public.students st where st.id = v_student and st.user_id = auth.uid())
      and (t.opens_at is null or now() >= t.opens_at)
      and (t.closes_at is null or now() < t.closes_at)
      and t.attempts_used < t.attempts_allowed,
    'answersReleased', v_released,
    'attempts', (select coalesce(jsonb_agg(private.assessment_attempt_json(x.id, 'reader')
        order by x.attempt_number, x.submitted_at), '[]'::jsonb)
      from public.assessment_attempts x where x.assessment_id = a.id and x.student_id = v_student),
    'grade', case when g.state = 'published' then private.api041_grade_json(g.id) end);
end;
$$;

-- listAssessmentQuestions for a student: before the window opens, nothing;
-- after, the questions without any key.
create or replace function private.api041_assessment_questions(p_assessment uuid, p_mode text)
returns jsonb language plpgsql stable security definer set search_path = '' as $$
declare
  a public.assessments%rowtype;
begin
  select * into a from public.assessments x where x.id = p_assessment and x.deleted_at is null;
  if a.id is null or a.school_id is distinct from nullif(current_setting('studafy.school_id', true), '')::uuid then
    return jsonb_build_object('outcome', 'not_found');
  end if;
  if p_mode = 'author' then
    if not private.coursework_staff(a.classroom_id) then return jsonb_build_object('outcome', 'not_found'); end if;
    return jsonb_build_object('items', private.assessment_questions_json(a.id, 'author'), 'nextPosition', null);
  end if;
  if private.coursework_staff(a.classroom_id) then
    return jsonb_build_object('items', private.assessment_questions_json(a.id, 'student'), 'nextPosition', null);
  end if;
  if a.state <> 'published' or not private.can_view_classroom(a.classroom_id)
     or (a.opens_at is not null and now() < a.opens_at) then
    return jsonb_build_object('outcome', 'not_found');
  end if;
  return jsonb_build_object('items', private.assessment_questions_json(a.id, 'student'), 'nextPosition', null);
end;
$$;

create or replace function private.api041_assessment_attempts(p_assessment uuid, p_input jsonb)
returns jsonb language plpgsql stable security definer set search_path = '' as $$
declare
  a public.assessments%rowtype;
begin
  select * into a from public.assessments x where x.id = p_assessment and x.deleted_at is null;
  if a.id is null or not private.coursework_staff(a.classroom_id) then
    return jsonb_build_object('outcome', 'not_found');
  end if;
  return jsonb_build_object('items', (select coalesce(jsonb_agg(jsonb_build_object(
      'id', t.id, 'assessmentId', t.assessment_id, 'studentId', t.student_id,
      'studentName', st.display_name, 'attemptNumber', t.attempt_number,
      'submittedAt', t.submitted_at, 'version', t.version,
      'needsMarking', t.needs_marking, 'awardedScore', t.awarded_score)
      order by st.display_name, t.attempt_number), '[]'::jsonb)
    from public.assessment_attempts t join public.students st on st.id = t.student_id
    where t.assessment_id = a.id), 'nextPosition', null);
end;
$$;

-- ===========================================================================
-- 11. Downloads
-- ===========================================================================

do $$ begin
  if not exists (select 1 from pg_proc p join pg_namespace n on n.oid = p.pronamespace
      where n.nspname = 'private' and p.proname = 'file051_authorize_download_pre_assessments') then
    alter function private.file051_authorize_download(uuid)
      rename to file051_authorize_download_pre_assessments;
  end if;
end $$;

-- A file on a question, a grade or a paper grade's shared results is
-- decided here alone: a question's by the assessment's audience once it
-- opens, a grade's and a shared result's by that student's published grade.
-- The class's staff always.
create or replace function private.file051_authorize_download(p_file_id uuid)
returns jsonb language plpgsql stable security definer set search_path = '' as $$
declare
  v_school uuid;
  v_new boolean;
  v_allowed boolean := false;
begin
  select fo.school_id into v_school from public.file_objects fo where fo.id = p_file_id;
  select exists (select 1 from public.file_bindings b where b.file_object_id = p_file_id
      and (b.assessment_question_id is not null or b.grade_result_id is not null or b.role = 'results'))
    into v_new;
  if not v_new then
    return private.file051_authorize_download_pre_assessments(p_file_id);
  end if;
  if auth.uid() is null then
    return jsonb_build_object('allowed', false, 'schoolId', v_school, 'reason', 'denied');
  end if;
  select exists (
    -- A question's file.
    select 1 from public.file_bindings b
    join public.assessment_questions q on q.id = b.assessment_question_id
    join public.assessments a on a.id = q.assessment_id and a.deleted_at is null
    where b.file_object_id = p_file_id and b.detached_at is null
      and (private.coursework_staff(a.classroom_id)
        or (a.state = 'published' and (a.opens_at is null or a.opens_at <= now())
          and private.can_view_classroom(a.classroom_id)))
  ) or exists (
    -- One student's paper-grade file.
    select 1 from public.file_bindings b
    join public.grade_results g on g.id = b.grade_result_id
    join public.assessments a on a.id = g.assessment_id and a.deleted_at is null
    where b.file_object_id = p_file_id and b.detached_at is null
      and (private.coursework_staff(a.classroom_id)
        or (g.state = 'published' and private.coursework_reader_of(g.student_id, a.classroom_id)))
  ) or exists (
    -- The class's shared results: to anyone whose own published grade it is.
    select 1 from public.file_bindings b
    join public.assessments a on a.id = b.assessment_id and a.deleted_at is null
    where b.file_object_id = p_file_id and b.detached_at is null and b.role = 'results'
      and (private.coursework_staff(a.classroom_id)
        or exists (select 1 from public.grade_results g
          where g.assessment_id = a.id and g.state = 'published'
            and private.coursework_reader_of(g.student_id, a.classroom_id)))
  ) or exists (
    -- Detached: the class's staff only.
    select 1 from public.file_bindings b
    left join public.assessment_questions q on q.id = b.assessment_question_id
    left join public.grade_results g on g.id = b.grade_result_id
    join public.assessments a on a.id = coalesce(q.assessment_id, g.assessment_id, b.assessment_id)
    where b.file_object_id = p_file_id and b.detached_at is not null
      and private.coursework_staff(a.classroom_id)
  ) into v_allowed;
  return jsonb_build_object('allowed', coalesce(v_allowed, false), 'schoolId', v_school,
    'reason', case when v_allowed then 'coursework' else 'denied' end);
end;
$$;

-- ===========================================================================
-- 12. Authorization
-- ===========================================================================

-- Copied from 202609300001 with the new staff-only actions.
create or replace function private.authz_coursework(p_action text, p_resource_id uuid)
returns jsonb language plpgsql stable security definer set search_path = '' as $$
declare
  target_school uuid;
  permitted boolean := false;
begin
  if auth.uid() is null or p_resource_id is null then
    return jsonb_build_object('allowed', false, 'school_id', null, 'reason', 'invalid_resource');
  end if;

  case
    when p_action = 'gradebook.read' then
      select a.school_id, private.coursework_staff(a.classroom_id)
      into target_school, permitted
      from public.assessments a where a.id = p_resource_id and a.deleted_at is null;
    when p_action in ('gradebook.write', 'gradebook.publish', 'gradebook.correct',
                      'assessment.update', 'assessment.design', 'assessment.access',
                      'gradebook.attachments') then
      select a.school_id, private.coursework_teacher(a.classroom_id)
      into target_school, permitted
      from public.assessments a where a.id = p_resource_id and a.deleted_at is null;
    when p_action = 'assessment_attempt.read' then
      select t.school_id, private.coursework_staff(a.classroom_id)
      into target_school, permitted
      from public.assessment_attempts t join public.assessments a on a.id = t.assessment_id
      where t.id = p_resource_id;
    when p_action = 'assessment_attempt.mark' then
      select t.school_id, private.coursework_teacher(a.classroom_id)
      into target_school, permitted
      from public.assessment_attempts t join public.assessments a on a.id = t.assessment_id
      where t.id = p_resource_id;
    when p_action = 'grade_result.history' then
      select g.school_id, private.coursework_staff(a.classroom_id)
      into target_school, permitted
      from public.grade_results g join public.assessments a on a.id = g.assessment_id
      where g.id = p_resource_id;
    when p_action = 'attendance_session.correct' then
      select ls.school_id, private.coursework_teacher(ls.classroom_id)
      into target_school, permitted
      from public.lesson_sessions ls where ls.id = p_resource_id;
    when p_action = 'attendance_session.history' then
      select ls.school_id, private.coursework_staff(ls.classroom_id)
      into target_school, permitted
      from public.lesson_sessions ls where ls.id = p_resource_id;
    when p_action in ('assignment.extend', 'assignment.reopen') then
      select a.school_id, private.coursework_teacher(a.classroom_id)
      into target_school, permitted
      from public.assignments a where a.id = p_resource_id and a.deleted_at is null;
    when p_action = 'assignment.materials' then
      select a.school_id, private.coursework_teacher(a.classroom_id)
      into target_school, permitted
      from public.assignments a where a.id = p_resource_id and a.deleted_at is null;
    when p_action = 'assessment.materials' then
      select a.school_id, private.coursework_teacher(a.classroom_id)
      into target_school, permitted
      from public.assessments a where a.id = p_resource_id and a.deleted_at is null;
    when p_action = 'resource.edit' then
      select r.school_id, (r.created_by = auth.uid() or exists (
        select 1 from public.resource_versions rv
        join public.resource_publications rp on rp.resource_version_id = rv.id
        where rv.resource_id = r.id and rp.classroom_id is not null
          and private.coursework_teacher(rp.classroom_id)))
      into target_school, permitted
      from public.resources r where r.id = p_resource_id and r.deleted_at is null;
    else
      return jsonb_build_object('allowed', false, 'school_id', null, 'reason', 'invalid_resource');
  end case;

  return jsonb_build_object('allowed', coalesce(permitted, false), 'school_id', target_school,
    'reason', case when target_school is null then 'invalid_resource'
      when permitted then 'allowed' else 'denied' end);
end;
$$;

-- A student's own results, or a linked parent's child's: read-only. The
-- query checks the exact child named.
create or replace function private.authz_assessment_results(p_action text, p_resource_id uuid)
returns jsonb language sql stable security definer set search_path = '' as $$
  select coalesce((
    select jsonb_build_object('allowed', ok, 'school_id', a.school_id,
      'reason', case when ok then 'allowed' else 'denied' end)
    from public.assessments a
    cross join lateral (select a.state = 'published' and a.deleted_at is null and (
      private.coursework_own_student(a.classroom_id) is not null
      or private.coursework_staff(a.classroom_id)
      or exists (select 1 from public.guardian_links gl
        where gl.guardian_id = auth.uid() and gl.status = 'verified'
          and private.is_linked_guardian(gl.student_id, a.classroom_id))) as ok) x
    where a.id = p_resource_id),
    jsonb_build_object('allowed', false, 'school_id', null, 'reason', 'invalid_resource'));
$$;

-- Copied from 202609300001 with the new actions routed.
create or replace function private.authz_authorize(p_action text, p_resource_id uuid)
returns jsonb language plpgsql stable security definer set search_path = '' as $function$
declare
  decision jsonb;
begin
  if p_action in ('notebook.read', 'notebook.write', 'notebook_entry.delete', 'study_set.generate') then
    return private.authz_notebook(p_action, p_resource_id);
  end if;
  if p_action = 'conversation.mark_read' then
    return private.authz_conversation_read(p_action, p_resource_id);
  end if;
  if p_action = 'assessment.results' then
    return private.authz_assessment_results(p_action, p_resource_id);
  end if;
  if p_action in ('gradebook.read', 'gradebook.write', 'gradebook.publish',
      'gradebook.correct', 'assessment.update', 'grade_result.history',
      'attendance_session.correct', 'attendance_session.history',
      'assignment.extend', 'assignment.reopen', 'assignment.materials',
      'assessment.materials', 'resource.edit', 'assessment.design',
      'assessment.access', 'assessment_attempt.read', 'assessment_attempt.mark',
      'gradebook.attachments') then
    return private.authz_coursework(p_action, p_resource_id);
  end if;

  if p_action = 'submission.history' then
    decision := private.authz_submission_history(p_action, p_resource_id);
  else
    decision := case
      when p_action = 'lesson_session.close'
        then private.authz_lesson_session_close(p_action, p_resource_id)
      when p_action in ('classJoinLink.create', 'classJoinLink.read', 'classJoinLink.revoke')
        then private.authz_class_join_links(p_action, p_resource_id)
      when p_action = 'classroom.create'
        then private.authz_classroom_create(p_action, p_resource_id)
      when p_action in ('file.download', 'file.publish')
        then private.authz_file_publication(p_action, p_resource_id)
      when p_action in ('upload.intent.create', 'upload.read', 'upload.complete',
        'file.read')
        then private.authz_file_delivery(p_action, p_resource_id)
      when p_action in ('content_controls.read', 'content_controls.write',
        'moderation.overview.read', 'moderation.queue.read', 'moderation.report.read',
        'moderation.triage', 'moderation.resolve', 'moderation.escalate',
        'moderation.evidence.write', 'moderation.hold', 'moderation.access.approve',
        'moderation.access.start', 'moderation.access.revoke', 'moderation.access.list')
        then private.authz_safety(p_action, p_resource_id)
      when p_action in ('term.create', 'student.create')
        then private.authz_roster_create(p_action, p_resource_id)
      when p_action in ('support_access.approve', 'support_access.start',
        'support_access.revoke', 'support_access.list')
        then private.authz_support_access(p_action, p_resource_id)
      when p_action in ('meeting.request', 'meeting.cancel', 'meeting.status')
        then private.authz_meetings(p_action, p_resource_id)
      when p_action in ('message.list', 'message.send', 'announcement.create',
        'announcement.list')
        then private.authz_communications(p_action, p_resource_id)
      when p_action in ('guardian_link.verify', 'guardian_link.revoke')
        then private.authz_guardian_links(p_action, p_resource_id)
      when p_action in ('invitation.issue', 'invitation.revoke', 'invitation.list')
        then private.authz_invitations(p_action, p_resource_id)
      when p_action in ('school.suspend', 'school.close', 'membership.grant',
        'membership.activate', 'membership.suspend', 'membership.revoke',
        'classroom_staff.write', 'enrollment.write')
        then private.authz_school_admin(p_action, p_resource_id)
      when p_action in ('term.list', 'classroom.list', 'classroom.update',
        'classroom.schedule.write', 'classroom.roster.read', 'classroom.staff.read',
        'lesson_session.list', 'resource.list', 'resource.create', 'resource.revise',
        'resource.publish', 'resource.withdraw', 'assignment.list', 'assignment.create',
        'assignment.publish', 'assignment.withdraw', 'assignment.submit',
        'assignment.read', 'submission.list', 'assessment.list', 'assessment.create',
        'assessment.publish', 'assessment.withdraw', 'assessment.submit',
        'assessment_question.list', 'assessment_question.authoring.list',
        'assessment_attempt.list', 'grade_result.list', 'grade_result.review',
        'grade_result.publish', 'grade_result.correct', 'grade_result.withdraw',
        'attendance_record.list', 'attendance_record.write', 'attendance_roster.read',
        'wellbeing_event.list', 'wellbeing_event.create')
        then private.authz_school_operations(p_action, p_resource_id)
      else private.authz_academic(p_action, p_resource_id)
    end;
    decision := private.authz_guardian_submits(p_action, p_resource_id, decision);
  end if;

  return private.authz_guardian_list_reads(p_action, p_resource_id, decision);
end;
$function$;

-- ===========================================================================
-- 13. Dispatch
-- ===========================================================================

do $$ begin
  if not exists (select 1 from pg_proc p join pg_namespace n on n.oid = p.pronamespace
      where n.nspname = 'private' and p.proname = 'api041_command_pre_assessments') then
    alter function private.api041_command(text, uuid, jsonb, uuid, bigint)
      rename to api041_command_pre_assessments;
  end if;
  if not exists (select 1 from pg_proc p join pg_namespace n on n.oid = p.pronamespace
      where n.nspname = 'private' and p.proname = 'api041_query_pre_assessments') then
    alter function private.api041_query(text, uuid, jsonb)
      rename to api041_query_pre_assessments;
  end if;
end $$;

create or replace function private.api041_command(p_operation text, p_resource_id uuid,
  p_input jsonb, p_idempotency_id uuid, p_idempotency_generation bigint)
returns jsonb language plpgsql security definer set search_path = '' as $function$
declare
  body jsonb := coalesce(p_input->'body', '{}'::jsonb);
  result jsonb;
  v_id uuid;
  v_school uuid;
  v_class uuid;
  v_problem text;
  a public.assessments%rowtype;
  v_version uuid;
  v_response jsonb;
begin
  case p_operation
    when 'updateAssessmentDesign' then
      return private.api041_update_assessment_design(p_resource_id, p_input, p_idempotency_id, p_idempotency_generation);
    when 'grantAssessmentAccess' then
      return private.api041_grant_assessment_access(p_resource_id, p_input, p_idempotency_id, p_idempotency_generation);
    when 'submitAssessment' then
      return private.api041_submit_assessment(p_resource_id, p_input, p_idempotency_id, p_idempotency_generation);
    when 'markAssessmentAttempt' then
      return private.api041_mark_assessment_attempt(p_resource_id, p_input, p_idempotency_id, p_idempotency_generation);
    when 'updateGradeAttachments' then
      return private.api041_update_grade_attachments(p_resource_id, p_input, p_idempotency_id, p_idempotency_generation);
    when 'updateAssignmentMaterials', 'updateAssessmentMaterials' then
      if body ? 'links' or body ? 'removeLinkIds' then
        return private.api041_update_work_materials_with_links(p_operation, p_resource_id, p_input,
          p_idempotency_id, p_idempotency_generation);
      end if;
    when 'editResource' then
      return private.api041_edit_resource_with_attachments(p_resource_id, p_input,
        p_idempotency_id, p_idempotency_generation);
    else null;
  end case;

  if p_operation not in ('createAssessment', 'createAssignment', 'createResource') then
    return private.api041_command_pre_assessments(p_operation, p_resource_id, p_input,
      p_idempotency_id, p_idempotency_generation);
  end if;

  -- The questions are checked before anything is created.
  if p_operation = 'createAssessment' and jsonb_typeof(body->'questions') = 'array' then
    if exists (select 1 from jsonb_array_elements(body->'questions') q
        where private.assessment_question_problem(q) is not null) then
      return jsonb_build_object('outcome', 'invalid');
    end if;
  end if;
  -- Links are checked before anything is created, too.
  if jsonb_typeof(body->'links') = 'array' and exists (
      select 1 from jsonb_array_elements(body->'links') l
      where char_length(btrim(coalesce(l->>'title', ''))) not between 1 and 120
        or not private.content_link_url_ok(btrim(l->>'url'))) then
    return jsonb_build_object('outcome', 'invalid');
  end if;

  begin
    result := private.api041_command_pre_assessments(p_operation, p_resource_id, p_input,
      p_idempotency_id, p_idempotency_generation);
    if coalesce(result->>'outcome', '') <> 'ok' then return result; end if;
    v_id := ((result->'response')->>'id')::uuid;

    if p_operation = 'createAssessment' then
      select * into a from public.assessments x where x.id = v_id;
      if jsonb_typeof(body->'questions') = 'array' and jsonb_array_length(body->'questions') > 0 then
        -- The base wrote prompts and scores; the rest is written by position.
        v_problem := private.assessment_write_questions(a, (
          select jsonb_agg(item || jsonb_build_object('id', q.id) order by ord)
          from jsonb_array_elements(body->'questions') with ordinality t(item, ord)
          join public.assessment_questions q on q.assessment_id = a.id and q.position = (item->>'position')::int));
        if v_problem is not null then raise exception using errcode = 'SF051', message = v_problem; end if;
      end if;
      v_problem := private.assessment_write_settings(a, body);
      if v_problem is not null then raise exception using errcode = 'SF051', message = v_problem; end if;
      v_problem := private.content_links_attach(body->'links', a.school_id, p_assessment => a.id);
      if v_problem <> 'ok' then raise exception using errcode = 'SF051', message = v_problem; end if;
      v_response := private.api041_assessment_json(a.id);
    elsif p_operation = 'createAssignment' then
      select x.school_id into v_school from public.assignments x where x.id = v_id;
      v_problem := private.content_links_attach(body->'links', v_school, p_assignment => v_id);
      if v_problem <> 'ok' then raise exception using errcode = 'SF051', message = v_problem; end if;
      v_response := private.api041_assignment_json(v_id);
    else
      -- A lesson: its files and links belong to its first version.
      select rv.id, r.school_id into v_version, v_school from public.resources r
      join public.resource_versions rv on rv.resource_id = r.id and rv.version = r.current_version
      where r.id = v_id;
      v_class := nullif(body->>'classroomId', '')::uuid;
      if jsonb_typeof(body->'attachmentFileIds') = 'array' and jsonb_array_length(body->'attachmentFileIds') > 0 then
        if v_class is null then raise exception using errcode = 'SF051', message = 'invalid'; end if;
        v_problem := private.coursework_attach_files(body->'attachmentFileIds', 'lesson_resource',
          v_school, v_class, p_resource_version => v_version);
        if v_problem <> 'ok' then raise exception using errcode = 'SF051', message = v_problem; end if;
      end if;
      v_problem := private.content_links_attach(body->'links', v_school, p_resource_version => v_version);
      if v_problem <> 'ok' then raise exception using errcode = 'SF051', message = v_problem; end if;
      v_response := private.api041_resource_json(v_id);
    end if;
  exception when sqlstate 'SF051' then
    return jsonb_build_object('outcome', sqlerrm);
  end;

  update public.idempotency_records r set response_body = v_response
  where r.id = p_idempotency_id and r.actor_id = auth.uid()
    and r.generation = p_idempotency_generation and r.status = 'completed';
  return jsonb_set(result, array['response'], v_response);
exception when invalid_text_representation or invalid_datetime_format or invalid_parameter_value then
  return jsonb_build_object('outcome', 'invalid');
end;
$function$;

create or replace function private.api041_query(p_operation text, p_resource_id uuid, p_input jsonb)
returns jsonb language plpgsql stable security definer set search_path = '' as $function$
declare
  result jsonb;
begin
  case p_operation
    when 'getAssessmentResults' then return private.api041_assessment_results(p_resource_id, p_input);
    when 'getAssessmentAttempt' then
      if not exists (select 1 from public.assessment_attempts t
          join public.assessments a on a.id = t.assessment_id
          where t.id = p_resource_id and private.coursework_staff(a.classroom_id)) then
        return jsonb_build_object('outcome', 'not_found');
      end if;
      return private.assessment_attempt_json(p_resource_id, 'staff');
    when 'listAssessmentQuestions' then return private.api041_assessment_questions(p_resource_id, 'student');
    when 'listAssessmentAuthoringQuestions' then return private.api041_assessment_questions(p_resource_id, 'author');
    when 'listAssessmentAttempts' then return private.api041_assessment_attempts(p_resource_id, p_input);
    else null;
  end case;

  result := private.api041_query_pre_assessments(p_operation, p_resource_id, p_input);

  -- The gradebook carries each student's attachments and the class's.
  if p_operation = 'listGradebook' and jsonb_typeof(result->'items') = 'array' then
    result := jsonb_set(result, '{item}', (result->'item') || jsonb_build_object(
      'sharedAttachments', private.coursework_files_json(p_assessment => p_resource_id, p_role => 'results'),
      'sharedLinks', private.content_links_json(p_assessment => p_resource_id, p_role => 'results')));
    result := jsonb_set(result, '{items}', (
      select coalesce(jsonb_agg(case when item->'grade' is null or jsonb_typeof(item->'grade') = 'null' then item
        else jsonb_set(item, '{grade}', (item->'grade')
          || private.grade_attachments_json(p_resource_id, (item->'grade'->>'id')::uuid) - 'gradeResultId') end
        order by ordinality), '[]'::jsonb)
      from jsonb_array_elements(result->'items') with ordinality as t(item, ordinality)));
  end if;
  return result;
end;
$function$;

-- ===========================================================================
-- 14. Ownership and grants
-- ===========================================================================

do $grants$
declare
  f text;
begin
  foreach f in array array[
    'private.coursework_reader_of(uuid,uuid)',
    'private.coursework_own_student(uuid)',
    'private.content_link_url_ok(text)',
    'private.content_links_json(uuid,uuid,uuid,uuid,uuid,text)',
    'private.content_links_attach(jsonb,uuid,uuid,uuid,uuid,uuid,uuid,text,integer)',
    'private.content_links_detach(jsonb,uuid,uuid,uuid,uuid,uuid,text)',
    'private.file_is_attached(uuid)',
    'private.coursework_attach_files(jsonb,public.file_purpose,uuid,uuid,uuid,uuid,uuid,uuid,uuid,text,integer)',
    'private.coursework_detach_files(jsonb,uuid,uuid,uuid,uuid,uuid,text)',
    'private.coursework_files_json(uuid,uuid,uuid,uuid,text)',
    'private.file_attachment_json(uuid,uuid,uuid,uuid,uuid)',
    'private.file_attach_bind(jsonb,public.file_purpose,uuid,uuid,uuid,uuid,uuid,uuid)',
    'private.assessment_student_terms(uuid,uuid)',
    'private.assessment_closed_for_all(uuid)',
    'private.assessment_answers_released(uuid)',
    'private.assessment_draft_key(jsonb)',
    'private.assessment_question_problem(jsonb)',
    'private.short_answer_norm(text)',
    'private.assessment_auto_mark(public.assessment_questions,jsonb,text)',
    'private.assessment_question_json(public.assessment_questions,text)',
    'private.assessment_questions_json(uuid,text)',
    'private.api041_assessment_json(uuid)',
    'private.api041_assignment_json(uuid)',
    'private.api041_resource_json(uuid)',
    'private.api041_grade_json(uuid)',
    'private.assessment_sync_grade(uuid,uuid)',
    'private.assessment_write_questions(public.assessments,jsonb)',
    'private.assessment_write_settings(public.assessments,jsonb)',
    'private.api041_update_assessment_design(uuid,jsonb,uuid,bigint)',
    'private.api041_grant_assessment_access(uuid,jsonb,uuid,bigint)',
    'private.api041_submit_assessment(uuid,jsonb,uuid,bigint)',
    'private.api041_mark_assessment_attempt(uuid,jsonb,uuid,bigint)',
    'private.api041_update_grade_attachments(uuid,jsonb,uuid,bigint)',
    'private.grade_attachments_json(uuid,uuid)',
    'private.api041_update_work_materials_with_links(text,uuid,jsonb,uuid,bigint)',
    'private.api041_edit_resource_with_attachments(uuid,jsonb,uuid,bigint)',
    'private.assessment_attempt_json(uuid,text)',
    'private.api041_assessment_results(uuid,jsonb)',
    'private.api041_assessment_questions(uuid,text)',
    'private.api041_assessment_attempts(uuid,jsonb)',
    'private.file051_authorize_download(uuid)',
    'private.file051_authorize_download_pre_assessments(uuid)',
    'private.authz_coursework(text,uuid)',
    'private.authz_assessment_results(text,uuid)',
    'private.authz_authorize(text,uuid)',
    'private.api041_command(text,uuid,jsonb,uuid,bigint)',
    'private.api041_command_pre_assessments(text,uuid,jsonb,uuid,bigint)',
    'private.api041_query(text,uuid,jsonb)',
    'private.api041_query_pre_assessments(text,uuid,jsonb)'
  ] loop
    execute format('alter function %s owner to postgres', f);
    execute format('revoke all on function %s from public, anon, authenticated, service_role, studafy_api_runtime, studafy_worker_runtime', f);
  end loop;
end;
$grants$;

-- The three entry points the API runtime calls, as before. Everything else
-- is reached only through them.
grant execute on function private.api041_command(text, uuid, jsonb, uuid, bigint)
  to studafy_api_runtime;
grant execute on function private.api041_query(text, uuid, jsonb) to studafy_api_runtime;
grant execute on function private.authz_authorize(text, uuid) to studafy_api_runtime;
