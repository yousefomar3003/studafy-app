-- AI-suggested marks against the teacher's reference answers (2026-10-21,
-- DL-073, ADR-0046).
--
-- ADR-0026 removed AI grading (the SEC-001 critical path signed a
-- caller-chosen storage path and forwarded it, unreviewed, to a provider).
-- The owner has decided to bring marking back in a narrower, reviewed form:
--
--   * the AI only SUGGESTS: a mark within the question's maximum, what the
--     answer met and missed against the teacher's reference, an explanation
--     and feedback for the teacher to edit. Suggestions live in their own
--     staff-only table. Nothing here writes assessment_answers, grade_results
--     or any mark: the teacher's own save (markAssessmentAttempt,
--     saveGradeDrafts) stays the only writer, with every rule it has;
--   * teachers write the reference: per question for an online assessment
--     (the model answer and guidance it already had, plus key points,
--     accepted alternatives and partial-credit rules), and per hand-in for
--     a graded assignment; a strictness setting; every change bumps a
--     reference version, and each run records the version and a snapshot
--     of what it used. A change never re-marks anything by itself;
--   * it is sold to teachers as "Studafy AI Marking" (studafy_ai_marking),
--     with operator comp grants for app review, and metered per teacher in
--     its own ledger with a monthly cap;
--   * students may opt out; their work is then never sent and is marked by
--     hand. Names on the class roster are replaced before anything is sent.
--
-- The retired ADR-0026 tables (ai_grading_drafts, question_suggestions) stay
-- sealed with check (false); none of this reuses them.

-- ---------------------------------------------------------------------------
-- 1. References and settings. Private tables: never readable by a client,
--    only through the functions below, which re-check the caller.
-- ---------------------------------------------------------------------------
create table if not exists private.marking_references (
  id uuid primary key default gen_random_uuid(),
  school_id uuid not null references public.schools(id) on delete cascade,
  assessment_id uuid not null references public.assessments(id) on delete cascade,
  -- A question of an online assessment; null is the whole hand-in of a
  -- graded assignment (a paper assessment linked to it).
  question_id uuid references public.assessment_questions(id) on delete cascade,
  -- For a hand-in: the model answer. For a question the model answer is
  -- assessment_questions.preferred_answer, where it already lives.
  reference_answer text check (reference_answer is null
    or char_length(reference_answer) <= 30000),
  -- [{"text": "...", "marks": 2}], what a complete answer must contain.
  key_points jsonb not null default '[]'::jsonb check (
    jsonb_typeof(key_points) = 'array' and jsonb_array_length(key_points) <= 20),
  accepted_methods text check (accepted_methods is null
    or char_length(accepted_methods) <= 5000),
  partial_credit text check (partial_credit is null
    or char_length(partial_credit) <= 5000),
  -- For a hand-in; a question's guidance is assessment_questions'.
  marking_guidance text check (marking_guidance is null
    or char_length(marking_guidance) <= 10000),
  updated_by uuid references public.profiles(id) on delete set null,
  updated_at timestamptz not null default now()
);
create unique index if not exists marking_references_one_per_target
  on private.marking_references (assessment_id,
    coalesce(question_id, '00000000-0000-0000-0000-000000000000'::uuid));

create table if not exists private.marking_settings (
  assessment_id uuid primary key references public.assessments(id) on delete cascade,
  school_id uuid not null references public.schools(id) on delete cascade,
  strictness text not null default 'balanced'
    check (strictness in ('lenient', 'balanced', 'strict')),
  reference_version integer not null default 1 check (reference_version > 0),
  updated_by uuid references public.profiles(id) on delete set null,
  updated_at timestamptz not null default now()
);

-- A student who does not want their work sent to the AI (DL-073).
create table if not exists private.marking_opt_outs (
  user_id uuid primary key references public.profiles(id) on delete cascade,
  created_at timestamptz not null default now()
);

-- ---------------------------------------------------------------------------
-- 2. Runs and suggestions. A suggestion row is also its own job.
-- ---------------------------------------------------------------------------
create table if not exists private.marking_runs (
  id uuid primary key default gen_random_uuid(),
  school_id uuid not null references public.schools(id) on delete cascade,
  assessment_id uuid not null references public.assessments(id) on delete cascade,
  requested_by uuid not null references public.profiles(id) on delete cascade,
  reference_version integer not null,
  strictness text not null check (strictness in ('lenient', 'balanced', 'strict')),
  -- What the references were when the run began, for the record.
  reference_snapshot jsonb not null,
  scope text not null check (scope in ('unmarked', 'all')),
  created_at timestamptz not null default now()
);

create table if not exists private.marking_suggestions (
  id uuid primary key default gen_random_uuid(),
  school_id uuid not null references public.schools(id) on delete cascade,
  run_id uuid not null references private.marking_runs(id) on delete cascade,
  assessment_id uuid not null references public.assessments(id) on delete cascade,
  student_id uuid not null references public.students(id) on delete cascade,
  -- Online: one answer. Hand-in: one submission attempt.
  attempt_id uuid references public.assessment_attempts(id) on delete cascade,
  question_id uuid references public.assessment_questions(id) on delete cascade,
  submission_attempt_id uuid references public.submission_attempts(id) on delete cascade,
  maximum_score numeric not null check (maximum_score > 0),
  reference_version integer not null,
  strictness text not null,
  status text not null default 'pending' check (status in
    ('pending', 'ready', 'failed', 'skipped', 'dismissed', 'superseded')),
  suggested_score numeric check (suggested_score is null
    or (suggested_score >= 0 and suggested_score <= maximum_score)),
  met jsonb not null default '[]'::jsonb,
  missed jsonb not null default '[]'::jsonb,
  rationale text check (rationale is null or char_length(rationale) <= 4000),
  feedback text check (feedback is null or char_length(feedback) <= 2000),
  -- The reference and the question or rubric disagree: the teacher decides.
  conflict text check (conflict is null or char_length(conflict) <= 1000),
  -- Why a person must look: ambiguous, unreadable, no_reference, conflict.
  review_reason text check (review_reason is null or review_reason in
    ('ambiguous', 'unreadable', 'no_reference', 'conflict', 'empty')),
  reason text,
  model text,
  attempts integer not null default 0,
  next_attempt_at timestamptz not null default now(),
  lease_until timestamptz,
  worker_id text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  check ((attempt_id is not null and question_id is not null
      and submission_attempt_id is null)
    or (attempt_id is null and question_id is null
      and submission_attempt_id is not null))
);
create index if not exists marking_suggestions_queue
  on private.marking_suggestions (next_attempt_at)
  where status = 'pending';
create index if not exists marking_suggestions_assessment
  on private.marking_suggestions (assessment_id, status);

-- The teacher's AI ledger: one row per model call, held then settled.
create table if not exists private.marking_usage (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references public.profiles(id) on delete cascade,
  suggestion_id uuid references private.marking_suggestions(id) on delete set null,
  state text not null check (state in ('reserved', 'settled', 'released')),
  reserved_tokens bigint not null default 0,
  reserved_micro_usd bigint not null default 0,
  tokens bigint not null default 0,
  cost_micro_usd bigint not null default 0,
  model text,
  created_at timestamptz not null default now(),
  settled_at timestamptz
);
create index if not exists marking_usage_user_month
  on private.marking_usage (user_id, created_at);

-- Comp grants for app review and pilots, written by an operator only.
create table if not exists private.marking_plan_grants (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references public.profiles(id) on delete cascade,
  reason text not null check (char_length(reason) between 3 and 200),
  starts_at timestamptz not null default now(),
  ends_at timestamptz not null,
  created_at timestamptz not null default now(),
  check (ends_at > starts_at)
);

do $$
declare t text;
begin
  foreach t in array array['marking_references', 'marking_settings',
    'marking_opt_outs', 'marking_runs', 'marking_suggestions', 'marking_usage',
    'marking_plan_grants'] loop
    execute format('alter table private.%I enable row level security', t);
    execute format('revoke all on private.%I from public, anon, authenticated, service_role, studafy_api_runtime, studafy_worker_runtime', t);
  end loop;
end $$;

-- ---------------------------------------------------------------------------
-- 3. The plan, its limits, and who may be marked.
-- ---------------------------------------------------------------------------
create or replace function private.marking_limits()
returns jsonb language sql immutable set search_path = '' as $$
  -- Per teacher per calendar month (UTC): tokens metered and a dollar cap
  -- beneath them, like the student plans (ADR-0037). Pages read from a
  -- scanned hand-in, and the size of one hand-in's text.
  select jsonb_build_object(
    'monthlyTokens', 4000000,
    'monthlyCapMicroUsd', 2000000,
    'pagesPerHandIn', 20,
    'handInChars', 60000,
    'maxAttempts', 3);
$$;

create or replace function private.marking_plan_active(p_user uuid)
returns boolean language sql stable security definer set search_path = '' as $$
  select p_user is not null and (
    exists (
      select 1 from public.entitlements e
      join public.store_transactions st on st.id = e.source_transaction_id
      join private.notebook_runtime runtime on runtime.singleton
      where e.user_id = p_user and e.feature_key = 'studafy_ai_marking'
        and e.status in ('active', 'grace_period')
        and e.starts_at <= now() and (e.ends_at is null or e.ends_at > now())
        and st.environment = runtime.environment
        and st.beneficiary_id = p_user)
    or exists (
      select 1 from private.marking_plan_grants g
      where g.user_id = p_user and g.starts_at <= now() and g.ends_at > now()));
$$;

create or replace function private.marking_month_used(p_user uuid)
returns jsonb language sql stable security definer set search_path = '' as $$
  select jsonb_build_object(
    'tokens', coalesce(sum(case when u.state = 'settled' then u.tokens
      when u.state = 'reserved' and u.created_at > now() - interval '15 minutes'
        then u.reserved_tokens else 0 end), 0),
    'microUsd', coalesce(sum(case when u.state = 'settled' then u.cost_micro_usd
      when u.state = 'reserved' and u.created_at > now() - interval '15 minutes'
        then u.reserved_micro_usd else 0 end), 0))
  from private.marking_usage u
  where u.user_id = p_user
    and u.created_at >= date_trunc('month', now() at time zone 'utc') at time zone 'utc';
$$;

-- The class's teacher, and the assessment, for marking. Null when not.
create or replace function private.marking_assessment(p_assessment uuid)
returns jsonb language sql stable security definer set search_path = '' as $$
  select jsonb_build_object(
    'id', a.id, 'schoolId', a.school_id, 'classroomId', a.classroom_id,
    'delivery', a.delivery, 'assignmentId', a.assignment_id,
    'maximumScore', a.maximum_score, 'title', a.title)
  from public.assessments a
  where a.id = p_assessment and a.deleted_at is null
    and private.coursework_teacher(a.classroom_id);
$$;

create or replace function private.marking_settings_json(p_assessment uuid)
returns jsonb language sql stable security definer set search_path = '' as $$
  select jsonb_build_object(
    'strictness', coalesce(s.strictness, 'balanced'),
    'referenceVersion', coalesce(s.reference_version, 1))
  from (select 1) one
  left join private.marking_settings s on s.assessment_id = p_assessment;
$$;

-- What the teacher wrote, for each question (or the hand-in).
create or replace function private.marking_references_json(p_assessment uuid)
returns jsonb language sql stable security definer set search_path = '' as $$
  select case when a.delivery = 'online' then (
    select coalesce(jsonb_agg(jsonb_build_object(
        'questionId', q.id, 'position', q.position, 'kind', q.kind,
        'prompt', q.prompt, 'maximumScore', q.maximum_score,
        'options', (select coalesce(jsonb_agg(jsonb_build_object(
            'id', o->>'id', 'text', o->>'text') order by ord), '[]'::jsonb)
          from jsonb_array_elements(coalesce(q.options, '[]'::jsonb))
            with ordinality t(o, ord)),
        'correctOptionIds', case when q.kind in ('single_choice', 'multiple_choice')
          then q.answer_key end,
        'correctChoice', case when q.kind = 'true_false' then q.answer_key end,
        'acceptedAnswers', case when q.kind = 'short_answer' then q.answer_key end,
        'preferredAnswer', q.preferred_answer,
        'markingGuidance', q.marking_guidance,
        'keyPoints', coalesce(r.key_points, '[]'::jsonb),
        'acceptedMethods', r.accepted_methods,
        'partialCredit', r.partial_credit)
      order by q.position), '[]'::jsonb)
    from public.assessment_questions q
    left join private.marking_references r
      on r.assessment_id = q.assessment_id and r.question_id = q.id
    where q.assessment_id = a.id)
  else (
    select jsonb_build_array(jsonb_build_object(
      'questionId', null, 'position', 1, 'kind', 'hand_in',
      'prompt', coalesce(asg.instructions, a.title),
      'maximumScore', a.maximum_score,
      'options', '[]'::jsonb, 'correctOptionIds', null,
      'correctChoice', null, 'acceptedAnswers', null,
      'preferredAnswer', r.reference_answer,
      'markingGuidance', r.marking_guidance,
      'keyPoints', coalesce(r.key_points, '[]'::jsonb),
      'acceptedMethods', r.accepted_methods,
      'partialCredit', r.partial_credit))
    from (select 1) one
    left join public.assignments asg on asg.id = a.assignment_id
    left join private.marking_references r
      on r.assessment_id = a.id and r.question_id is null)
  end
  from public.assessments a where a.id = p_assessment;
$$;

-- The names a teacher's marking call must keep out (DPIA D1): everyone on
-- the class roster, its teachers, and the students' parents. The student
-- whose work it is counts as "self".
create or replace function private.marking_known_names(
  p_classroom uuid, p_student uuid)
returns jsonb language sql stable security definer set search_path = '' as $$
  with named as (
    select st.display_name as name,
      case when st.id = p_student then 'self' else 'classmate' end as kind,
      case when st.id = p_student then 0 else 3 end as rank
      from public.enrollments e
      join public.students st on st.id = e.student_id
      where e.classroom_id = p_classroom and st.deleted_at is null
    union all
    select p.display_name,
      case when st.id = p_student then 'self' else 'classmate' end,
      case when st.id = p_student then 0 else 3 end
      from public.enrollments e
      join public.students st on st.id = e.student_id
      join public.profiles p on p.id = st.user_id
      where e.classroom_id = p_classroom and st.deleted_at is null
        and p.deleted_at is null
    union all
    select p.display_name, 'teacher', 2
      from public.classroom_staff cs
      join public.profiles p on p.id = cs.user_id
      where cs.classroom_id = p_classroom and p.deleted_at is null
    union all
    select p.display_name, 'teacher', 2
      from public.classrooms c
      join public.profiles p on p.id = c.teacher_id
      where c.id = p_classroom and p.deleted_at is null
    union all
    select p.display_name, 'parent', 1
      from public.enrollments e
      join public.guardian_links g on g.student_id = e.student_id
      join public.profiles p on p.id = g.guardian_id
      where e.classroom_id = p_classroom
        and g.status in ('pending', 'verified') and p.deleted_at is null
  ), distinct_names as (
    select distinct on (lower(btrim(n.name))) btrim(n.name) as name, n.kind, n.rank
    from named n
    where n.name is not null and char_length(btrim(n.name)) between 2 and 120
      and n.name not in ('Deleted student', 'Deleted user', 'Deleted account')
    order by lower(btrim(n.name)), n.rank
  )
  select coalesce(jsonb_agg(jsonb_build_object('name', d.name, 'kind', d.kind)
    order by d.rank, d.name), '[]'::jsonb)
  from (select * from distinct_names order by rank limit 5000) d;
$$;

-- A student has opted out: their own choice, or their managing parent's.
create or replace function private.marking_opted_out(p_student uuid)
returns boolean language sql stable security definer set search_path = '' as $$
  select exists (
    select 1 from public.students st
    join private.marking_opt_outs o on o.user_id = st.user_id
    where st.id = p_student);
$$;

-- ---------------------------------------------------------------------------
-- 4. Reads for the app (api059_query).
-- ---------------------------------------------------------------------------
create or replace function private.api059_query(
  p_operation text, p_resource_id uuid, p_input jsonb)
returns jsonb language plpgsql stable security definer set search_path = '' as $$
declare
  v_assessment jsonb;
  v_settings jsonb;
  v_used jsonb;
  v_limits jsonb := private.marking_limits();
begin
  if auth.uid() is null or not private.is_active_user() then
    return jsonb_build_object('outcome', 'forbidden');
  end if;
  case p_operation
    when 'plan' then
      v_used := private.marking_month_used(auth.uid());
      return jsonb_build_object('outcome', 'ok',
        'active', private.marking_plan_active(auth.uid()),
        'teacher', private.account_kind(auth.uid()) = 'adult'
          and exists (select 1 from public.memberships m
            where m.user_id = auth.uid() and m.role = 'teacher'
              and m.active and m.status = 'active'),
        'allowance', jsonb_build_object(
          'total', (v_limits->>'monthlyTokens')::bigint,
          'used', least((v_used->>'tokens')::bigint, (v_limits->>'monthlyTokens')::bigint),
          'resetsAt', (date_trunc('month', now() at time zone 'utc')
            + interval '1 month') at time zone 'utc'));

    when 'references' then
      v_assessment := private.marking_assessment(p_resource_id);
      if v_assessment is null then return jsonb_build_object('outcome', 'not_found'); end if;
      return jsonb_build_object('outcome', 'ok',
        'delivery', v_assessment->>'delivery',
        'settings', private.marking_settings_json(p_resource_id),
        'references', private.marking_references_json(p_resource_id));

    when 'suggestions' then
      v_assessment := private.marking_assessment(p_resource_id);
      if v_assessment is null then return jsonb_build_object('outcome', 'not_found'); end if;
      v_settings := private.marking_settings_json(p_resource_id);
      return jsonb_build_object('outcome', 'ok',
        'settings', v_settings,
        'items', (
          select coalesce(jsonb_agg(jsonb_build_object(
              'id', s.id, 'studentId', s.student_id,
              'attemptId', s.attempt_id, 'questionId', s.question_id,
              'submissionAttemptId', s.submission_attempt_id,
              'status', s.status, 'maximumScore', s.maximum_score,
              'suggestedScore', s.suggested_score,
              'met', s.met, 'missed', s.missed,
              'rationale', s.rationale, 'feedback', s.feedback,
              'conflict', s.conflict, 'reviewReason', s.review_reason,
              'reason', s.reason,
              'referenceVersion', s.reference_version,
              'strictness', s.strictness,
              'stale', s.reference_version < (v_settings->>'referenceVersion')::int,
              'createdAt', s.created_at, 'updatedAt', s.updated_at)
            order by s.created_at desc, s.id), '[]'::jsonb)
          from private.marking_suggestions s
          where s.assessment_id = p_resource_id
            and s.status in ('pending', 'ready', 'failed', 'skipped')
          ));

    when 'preference' then
      return jsonb_build_object('outcome', 'ok',
        'optedOut', exists (select 1 from private.marking_opt_outs o
          where o.user_id = auth.uid()));

    else
      return jsonb_build_object('outcome', 'invalid');
  end case;
exception when invalid_text_representation then
  return jsonb_build_object('outcome', 'not_found');
end;
$$;

-- ---------------------------------------------------------------------------
-- 5. Writes for the app (api059_command).
-- ---------------------------------------------------------------------------
create or replace function private.marking_key_points_valid(p_points jsonb, p_max numeric)
returns boolean language sql immutable set search_path = '' as $$
  select p_points is null or (
    jsonb_typeof(p_points) = 'array' and jsonb_array_length(p_points) <= 20
    and not exists (
      select 1 from jsonb_array_elements(p_points) e
      where jsonb_typeof(e) <> 'object'
        or char_length(coalesce(e->>'text', '')) not between 1 and 500
        or (e ? 'marks' and (jsonb_typeof(e->'marks') <> 'number'
          or (e->>'marks')::numeric < 0)))
    and coalesce((select sum((e->>'marks')::numeric)
      from jsonb_array_elements(p_points) e where e ? 'marks'), 0) <= p_max);
$$;

create or replace function private.api059_command(
  p_operation text, p_resource_id uuid, p_input jsonb,
  p_idempotency_id uuid, p_idempotency_generation bigint)
returns jsonb language plpgsql security definer set search_path = '' as $$
declare
  body jsonb := coalesce(p_input->'body', '{}'::jsonb);
  v_assessment jsonb;
  v_settings jsonb;
  v_changed boolean := false;
  v_item jsonb;
  v_question record;
  v_strictness text;
  v_version int;
  v_run uuid;
  v_scope text;
  v_queued int := 0;
  v_opted int := 0;
  v_superseded int := 0;
  v_stale int;
  v_targets jsonb;
  response jsonb;
  request_id text := nullif(current_setting('studafy.request_id', true), '');
begin
  if auth.uid() is null or not private.is_active_user() then
    return jsonb_build_object('outcome', 'forbidden');
  end if;

  case p_operation
    when 'setReferences' then
      v_assessment := private.marking_assessment(p_resource_id);
      if v_assessment is null then return jsonb_build_object('outcome', 'not_found'); end if;
      v_strictness := body->>'strictness';
      if v_strictness is not null and v_strictness not in ('lenient', 'balanced', 'strict') then
        return jsonb_build_object('outcome', 'invalid');
      end if;
      insert into private.marking_settings(assessment_id, school_id)
      values (p_resource_id, (v_assessment->>'schoolId')::uuid)
      on conflict (assessment_id) do nothing;
      if v_strictness is not null and v_strictness <> (
          select s.strictness from private.marking_settings s
          where s.assessment_id = p_resource_id) then
        update private.marking_settings set strictness = v_strictness
        where assessment_id = p_resource_id;
        v_changed := true;
      end if;

      for v_item in select * from jsonb_array_elements(coalesce(body->'references', '[]'::jsonb)) loop
        if v_assessment->>'delivery' = 'online' then
          select q.id, q.maximum_score into v_question
          from public.assessment_questions q
          where q.id = nullif(v_item->>'questionId', '')::uuid
            and q.assessment_id = p_resource_id;
          if v_question.id is null then
            return jsonb_build_object('outcome', 'invalid', 'path', 'questionId');
          end if;
        else
          if v_item ? 'questionId' and v_item->>'questionId' is not null then
            return jsonb_build_object('outcome', 'invalid', 'path', 'questionId');
          end if;
          select null::uuid as id, (v_assessment->>'maximumScore')::numeric as maximum_score
            into v_question;
        end if;
        if not private.marking_key_points_valid(v_item->'keyPoints', v_question.maximum_score) then
          return jsonb_build_object('outcome', 'invalid', 'path', 'keyPoints');
        end if;
        -- A question's model answer and guidance stay where they live; they
        -- never change the automatic mark (the key does, and it is not
        -- touched here), so they may be written after students answered.
        if v_question.id is not null and (v_item ? 'preferredAnswer' or v_item ? 'markingGuidance') then
          update public.assessment_questions q set
            preferred_answer = case when v_item ? 'preferredAnswer'
              then nullif(btrim(v_item->>'preferredAnswer'), '') else q.preferred_answer end,
            marking_guidance = case when v_item ? 'markingGuidance'
              then nullif(btrim(v_item->>'markingGuidance'), '') else q.marking_guidance end,
            updated_at = now()
          where q.id = v_question.id
            and (q.preferred_answer is distinct from case when v_item ? 'preferredAnswer'
                  then nullif(btrim(v_item->>'preferredAnswer'), '') else q.preferred_answer end
              or q.marking_guidance is distinct from case when v_item ? 'markingGuidance'
                  then nullif(btrim(v_item->>'markingGuidance'), '') else q.marking_guidance end);
          if found then v_changed := true; end if;
        end if;
        insert into private.marking_references(school_id, assessment_id, question_id,
          reference_answer, key_points, accepted_methods, partial_credit,
          marking_guidance, updated_by)
        values ((v_assessment->>'schoolId')::uuid, p_resource_id, v_question.id,
          case when v_question.id is null then nullif(btrim(v_item->>'preferredAnswer'), '') end,
          coalesce(v_item->'keyPoints', '[]'::jsonb),
          nullif(btrim(v_item->>'acceptedMethods'), ''),
          nullif(btrim(v_item->>'partialCredit'), ''),
          case when v_question.id is null then nullif(btrim(v_item->>'markingGuidance'), '') end,
          auth.uid())
        on conflict (assessment_id,
          coalesce(question_id, '00000000-0000-0000-0000-000000000000'::uuid))
        do update set
          reference_answer = case when excluded.question_id is null and v_item ? 'preferredAnswer'
            then excluded.reference_answer else private.marking_references.reference_answer end,
          key_points = case when v_item ? 'keyPoints'
            then excluded.key_points else private.marking_references.key_points end,
          accepted_methods = case when v_item ? 'acceptedMethods'
            then excluded.accepted_methods else private.marking_references.accepted_methods end,
          partial_credit = case when v_item ? 'partialCredit'
            then excluded.partial_credit else private.marking_references.partial_credit end,
          marking_guidance = case when excluded.question_id is null and v_item ? 'markingGuidance'
            then excluded.marking_guidance else private.marking_references.marking_guidance end,
          updated_by = auth.uid(), updated_at = now()
        where (private.marking_references.reference_answer, private.marking_references.key_points,
               private.marking_references.accepted_methods, private.marking_references.partial_credit,
               private.marking_references.marking_guidance)
          is distinct from (
            case when excluded.question_id is null and v_item ? 'preferredAnswer'
              then excluded.reference_answer else private.marking_references.reference_answer end,
            case when v_item ? 'keyPoints' then excluded.key_points else private.marking_references.key_points end,
            case when v_item ? 'acceptedMethods' then excluded.accepted_methods else private.marking_references.accepted_methods end,
            case when v_item ? 'partialCredit' then excluded.partial_credit else private.marking_references.partial_credit end,
            case when excluded.question_id is null and v_item ? 'markingGuidance'
              then excluded.marking_guidance else private.marking_references.marking_guidance end);
        if found then v_changed := true; end if;
      end loop;

      if v_changed then
        update private.marking_settings
        set reference_version = reference_version + 1, updated_by = auth.uid(), updated_at = now()
        where assessment_id = p_resource_id;
      end if;
      v_settings := private.marking_settings_json(p_resource_id);
      -- Existing suggestions are left as they are: nothing is re-marked by
      -- itself. The teacher is told how many no longer match.
      select count(*) into v_stale from private.marking_suggestions s
      where s.assessment_id = p_resource_id and s.status = 'ready'
        and s.reference_version < (v_settings->>'referenceVersion')::int;
      response := jsonb_build_object(
        'settings', v_settings,
        'references', private.marking_references_json(p_resource_id),
        'changed', v_changed, 'staleSuggestions', v_stale);

    when 'requestSuggestions' then
      v_assessment := private.marking_assessment(p_resource_id);
      if v_assessment is null then return jsonb_build_object('outcome', 'not_found'); end if;
      if not private.marking_plan_active(auth.uid()) then
        return jsonb_build_object('outcome', 'plan_required');
      end if;
      v_scope := coalesce(body->>'scope', 'unmarked');
      if v_scope not in ('unmarked', 'all') then
        return jsonb_build_object('outcome', 'invalid');
      end if;
      if v_assessment->>'delivery' <> 'online' and v_assessment->>'assignmentId' is null then
        -- Paper work with no hand-in has nothing to read.
        return jsonb_build_object('outcome', 'invalid_state');
      end if;
      insert into private.marking_settings(assessment_id, school_id)
      values (p_resource_id, (v_assessment->>'schoolId')::uuid)
      on conflict (assessment_id) do nothing;
      v_settings := private.marking_settings_json(p_resource_id);
      insert into private.marking_runs(school_id, assessment_id, requested_by,
        reference_version, strictness, reference_snapshot, scope)
      values ((v_assessment->>'schoolId')::uuid, p_resource_id, auth.uid(),
        (v_settings->>'referenceVersion')::int, v_settings->>'strictness',
        private.marking_references_json(p_resource_id), v_scope)
      returning id into v_run;

      -- What this run marks, as a list, so the statements below share it.
      if v_assessment->>'delivery' = 'online' then
        -- Written answers only: choice and true/false are marked by their key.
        select coalesce(jsonb_agg(jsonb_build_object(
            'student_id', at.student_id, 'attempt_id', at.id, 'question_id', q.id,
            'submission_attempt_id', null, 'maximum_score', q.maximum_score)), '[]'::jsonb)
          into v_targets
        from public.assessment_attempts at
        join public.assessment_answers an on an.attempt_id = at.id
        join public.assessment_questions q on q.id = an.question_id
        where at.assessment_id = p_resource_id and at.submitted_at is not null
          and q.kind in ('short_answer', 'essay')
          and coalesce(btrim(an.answer_text), '') <> ''
          and (v_scope = 'all' or an.awarded_score is null)
          and (body->'studentIds' is null or at.student_id in (
            select (x)::uuid from jsonb_array_elements_text(body->'studentIds') x));
      else
        select coalesce(jsonb_agg(jsonb_build_object(
            'student_id', s.student_id, 'attempt_id', null, 'question_id', null,
            'submission_attempt_id', s.current_attempt_id,
            'maximum_score', (v_assessment->>'maximumScore')::numeric)), '[]'::jsonb)
          into v_targets
        from public.submissions s
        where s.assignment_id = (v_assessment->>'assignmentId')::uuid
          and s.current_attempt_id is not null
          and (v_scope = 'all' or not exists (
            select 1 from public.grade_results g
            where g.assessment_id = p_resource_id and g.student_id = s.student_id
              and g.state <> 'draft'))
          and (body->'studentIds' is null or s.student_id in (
            select (x)::uuid from jsonb_array_elements_text(body->'studentIds') x));
      end if;

      -- A new run replaces what an earlier one said about the same work.
      update private.marking_suggestions old set status = 'superseded', updated_at = now()
      from jsonb_to_recordset(v_targets) as t(student_id uuid, attempt_id uuid,
        question_id uuid, submission_attempt_id uuid, maximum_score numeric)
      where old.assessment_id = p_resource_id
        and old.status in ('pending', 'ready', 'failed', 'skipped')
        and old.student_id = t.student_id
        and old.attempt_id is not distinct from t.attempt_id
        and old.question_id is not distinct from t.question_id
        and old.submission_attempt_id is not distinct from t.submission_attempt_id;
      get diagnostics v_superseded = row_count;

      insert into private.marking_suggestions(school_id, run_id, assessment_id,
        student_id, attempt_id, question_id, submission_attempt_id, maximum_score,
        reference_version, strictness, status, reason)
      select (v_assessment->>'schoolId')::uuid, v_run, p_resource_id,
        t.student_id, t.attempt_id, t.question_id, t.submission_attempt_id,
        t.maximum_score, (v_settings->>'referenceVersion')::int, v_settings->>'strictness',
        case when private.marking_opted_out(t.student_id) then 'skipped' else 'pending' end,
        case when private.marking_opted_out(t.student_id) then 'opted_out' end
      from jsonb_to_recordset(v_targets) as t(student_id uuid, attempt_id uuid,
        question_id uuid, submission_attempt_id uuid, maximum_score numeric);
      select count(*) filter (where s.status = 'pending'),
             count(*) filter (where s.status = 'skipped')
        into v_queued, v_opted
      from private.marking_suggestions s where s.run_id = v_run;

      response := jsonb_build_object('runId', v_run,
        'referenceVersion', (v_settings->>'referenceVersion')::int,
        'strictness', v_settings->>'strictness',
        'queued', v_queued, 'optedOut', v_opted, 'replaced', v_superseded);

    when 'dismissSuggestion' then
      update private.marking_suggestions s set status = 'dismissed', updated_at = now()
      where s.id = p_resource_id and s.status in ('ready', 'failed', 'skipped')
        and private.marking_assessment(s.assessment_id) is not null
      returning jsonb_build_object('id', s.id, 'status', s.status) into response;
      if response is null then return jsonb_build_object('outcome', 'not_found'); end if;

    when 'setPreference' then
      -- A student's own choice; a parent or teacher has nothing to opt out.
      if private.account_kind(auth.uid()) is distinct from 'student' then
        return jsonb_build_object('outcome', 'forbidden');
      end if;
      if (body->>'optedOut')::boolean then
        insert into private.marking_opt_outs(user_id) values (auth.uid())
        on conflict (user_id) do nothing;
        -- Work not yet read is not sent.
        update private.marking_suggestions s set status = 'skipped',
          reason = 'opted_out', updated_at = now()
        where s.status = 'pending' and s.student_id in (
          select st.id from public.students st where st.user_id = auth.uid());
      else
        delete from private.marking_opt_outs where user_id = auth.uid();
      end if;
      response := jsonb_build_object('optedOut',
        exists (select 1 from private.marking_opt_outs o where o.user_id = auth.uid()));

    else
      return jsonb_build_object('outcome', 'invalid');
  end case;

  insert into public.audit_events(school_id, actor_id, action, entity_type,
    entity_id, after_value, request_id)
  values ((v_assessment->>'schoolId')::uuid, auth.uid(),
    'marking_' || p_operation, 'assessment', coalesce(
      (v_assessment->>'id')::uuid, p_resource_id),
    -- What was asked for and what it touched - never a student's work.
    jsonb_strip_nulls(jsonb_build_object(
      'runId', v_run, 'queued', v_queued, 'optedOut', v_opted,
      'changed', case when p_operation = 'setReferences' then v_changed end,
      'referenceVersion', v_settings->'referenceVersion')),
    request_id);

  if not private.api_idempotency_complete(
    p_idempotency_id, p_idempotency_generation,
    case when p_operation = 'requestSuggestions' then 201 else 200 end, response) then
    raise exception 'API059_IDEMPOTENCY_COMPLETION_FAILED';
  end if;
  return jsonb_build_object('outcome', 'ok', 'response', response);
exception when invalid_text_representation or check_violation then
  return jsonb_build_object('outcome', 'invalid');
end;
$$;

-- ---------------------------------------------------------------------------
-- 6. The worker's doors. Each is bound to the claim (worker, job, attempt),
--    as the notebook queue is (202610160000), and acts for the teacher who
--    asked.
-- ---------------------------------------------------------------------------
create or replace function private.marking_job_held(
  p_worker text, p_job uuid, p_attempt int)
returns boolean language sql stable security definer set search_path = '' as $$
  select exists (select 1 from private.marking_suggestions s
    where s.id = p_job and s.status = 'pending' and s.worker_id = p_worker
      and s.attempts = p_attempt and s.lease_until > now());
$$;

create or replace function private.marking_jobs_claim(p_worker text, p_batch int)
returns jsonb language plpgsql security definer set search_path = '' as $$
declare
  v_limits jsonb := private.marking_limits();
  v_jobs jsonb := '[]'::jsonb;
  v_row record;
  v_payload jsonb;
begin
  if p_worker is null or char_length(p_worker) not between 1 and 200 then
    return '[]'::jsonb;
  end if;
  -- A run whose teacher no longer teaches the class, or no longer holds the
  -- plan, sends nothing.
  for v_row in
    select s.* from private.marking_suggestions s
    where s.status = 'pending' and s.next_attempt_at <= now()
      and (s.lease_until is null or s.lease_until < now())
    order by s.created_at
    limit greatest(1, least(coalesce(p_batch, 1), 10))
    for update skip locked
  loop
    if v_row.attempts >= (v_limits->>'maxAttempts')::int then
      update private.marking_suggestions set status = 'failed',
        reason = coalesce(reason, 'too_many_attempts'), updated_at = now()
      where id = v_row.id;
      continue;
    end if;
    if private.marking_opted_out(v_row.student_id) then
      update private.marking_suggestions set status = 'skipped',
        reason = 'opted_out', updated_at = now() where id = v_row.id;
      continue;
    end if;
    update private.marking_suggestions set attempts = attempts + 1,
      worker_id = p_worker, lease_until = now() + interval '5 minutes',
      updated_at = now()
    where id = v_row.id;
    select jsonb_build_object(
      'id', v_row.id, 'attempt', v_row.attempts + 1,
      'teacherId', r.requested_by,
      'classroomId', a.classroom_id,
      'studentId', v_row.student_id,
      'maximumScore', v_row.maximum_score,
      'strictness', v_row.strictness,
      'referenceVersion', v_row.reference_version,
      'limits', v_limits,
      'question', (
        select e from jsonb_array_elements(r.reference_snapshot) e
        where (v_row.question_id is null and e->>'questionId' is null)
           or e->>'questionId' = v_row.question_id::text
        limit 1),
      'answerText', case
        when v_row.attempt_id is not null then (
          select an.answer_text from public.assessment_answers an
          where an.attempt_id = v_row.attempt_id and an.question_id = v_row.question_id)
        else (select sa.answer_text from public.submission_attempts sa
          where sa.id = v_row.submission_attempt_id) end,
      'files', case when v_row.submission_attempt_id is null then '[]'::jsonb else (
        select coalesce(jsonb_agg(private.file051_effective_object(b.file_object_id)
            || jsonb_build_object('fileId', b.file_object_id) order by b.created_at), '[]'::jsonb)
        from public.file_bindings b
        join public.file_objects f on f.id = b.file_object_id
        where b.submission_attempt_id = v_row.submission_attempt_id
          and b.detached_at is null and f.deleted_at is null
          and f.purpose = 'assignment_submission') end,
      'names', private.marking_known_names(a.classroom_id, v_row.student_id),
      'planActive', private.marking_plan_active(r.requested_by),
      'teaches', exists (
        select 1 from public.classroom_staff cs
        where cs.classroom_id = a.classroom_id and cs.user_id = r.requested_by
          and cs.status = 'active'))
      into v_payload
    from private.marking_runs r
    join public.assessments a on a.id = v_row.assessment_id
    where r.id = v_row.run_id;
    v_jobs := v_jobs || jsonb_build_array(v_payload);
  end loop;
  return v_jobs;
end;
$$;

-- Hold tokens before a model call; refuse past the plan or its cap.
create or replace function private.marking_job_usage(
  p_worker text, p_job uuid, p_attempt int, p_operation text, p_input jsonb)
returns jsonb language plpgsql security definer set search_path = '' as $$
declare
  v_teacher uuid;
  v_limits jsonb := private.marking_limits();
  v_used jsonb;
  v_id uuid;
begin
  if not private.marking_job_held(p_worker, p_job, p_attempt) then
    return jsonb_build_object('outcome', 'lease_lost');
  end if;
  select r.requested_by into v_teacher
  from private.marking_suggestions s join private.marking_runs r on r.id = s.run_id
  where s.id = p_job;
  case p_operation
    when 'reserve' then
      if not private.marking_plan_active(v_teacher) then
        return jsonb_build_object('outcome', 'plan_required');
      end if;
      perform pg_advisory_xact_lock(hashtextextended('marking_usage:' || v_teacher::text, 0));
      v_used := private.marking_month_used(v_teacher);
      if (v_used->>'tokens')::bigint + coalesce((p_input->>'estimateTokens')::bigint, 0)
          > (v_limits->>'monthlyTokens')::bigint then
        return jsonb_build_object('outcome', 'allowance_exhausted');
      end if;
      if (v_used->>'microUsd')::bigint + coalesce((p_input->>'estimateMicroUsd')::bigint, 0)
          > (v_limits->>'monthlyCapMicroUsd')::bigint then
        return jsonb_build_object('outcome', 'monthly_cap');
      end if;
      insert into private.marking_usage(user_id, suggestion_id, state,
        reserved_tokens, reserved_micro_usd)
      values (v_teacher, p_job, 'reserved',
        greatest(0, coalesce((p_input->>'estimateTokens')::bigint, 0)),
        greatest(0, coalesce((p_input->>'estimateMicroUsd')::bigint, 0)))
      returning id into v_id;
      return jsonb_build_object('outcome', 'ok', 'usageId', v_id);
    when 'settle' then
      update private.marking_usage set state = 'settled',
        tokens = greatest(0, coalesce((p_input->>'inputTokens')::bigint, 0)
          + coalesce((p_input->>'outputTokens')::bigint, 0)),
        cost_micro_usd = greatest(0, coalesce((p_input->>'costMicroUsd')::bigint,
          reserved_micro_usd)),
        model = left(p_input->>'model', 120), settled_at = now()
      where id = (p_input->>'usageId')::uuid and user_id = v_teacher and state = 'reserved';
      return jsonb_build_object('outcome', 'ok');
    when 'release' then
      update private.marking_usage set state = 'released', settled_at = now()
      where id = (p_input->>'usageId')::uuid and user_id = v_teacher and state = 'reserved';
      return jsonb_build_object('outcome', 'ok');
    else
      return jsonb_build_object('outcome', 'invalid');
  end case;
end;
$$;

create or replace function private.marking_job_finish(
  p_worker text, p_job uuid, p_attempt int, p_outcome text, p_result jsonb)
returns jsonb language plpgsql security definer set search_path = '' as $$
declare
  v_row private.marking_suggestions%rowtype;
  v_score numeric;
begin
  if not private.marking_job_held(p_worker, p_job, p_attempt) then
    return jsonb_build_object('outcome', 'lease_lost');
  end if;
  select * into v_row from private.marking_suggestions where id = p_job for update;
  case p_outcome
    when 'ready' then
      v_score := nullif(p_result->>'suggestedScore', '')::numeric;
      if v_score is not null and (v_score < 0 or v_score > v_row.maximum_score) then
        return jsonb_build_object('outcome', 'invalid');
      end if;
      update private.marking_suggestions set
        status = 'ready', suggested_score = v_score,
        met = coalesce(p_result->'met', '[]'::jsonb),
        missed = coalesce(p_result->'missed', '[]'::jsonb),
        rationale = left(p_result->>'rationale', 4000),
        feedback = left(p_result->>'feedback', 2000),
        conflict = left(p_result->>'conflict', 1000),
        review_reason = nullif(p_result->>'reviewReason', ''),
        model = left(p_result->>'model', 120),
        lease_until = null, worker_id = null, updated_at = now()
      where id = p_job;
    when 'retry' then
      update private.marking_suggestions set
        lease_until = null, worker_id = null,
        next_attempt_at = now() + make_interval(secs => 20 * attempts * attempts),
        reason = left(p_result->>'reason', 60), updated_at = now()
      where id = p_job;
    when 'skipped' then
      update private.marking_suggestions set status = 'skipped',
        reason = left(p_result->>'reason', 60),
        lease_until = null, worker_id = null, updated_at = now()
      where id = p_job;
    else
      update private.marking_suggestions set status = 'failed',
        reason = left(coalesce(p_result->>'reason', 'failed'), 60),
        lease_until = null, worker_id = null, updated_at = now()
      where id = p_job;
  end case;
  return jsonb_build_object('outcome', 'ok');
exception when check_violation or invalid_text_representation then
  return jsonb_build_object('outcome', 'invalid');
end;
$$;

create or replace function private.marking_jobs_backlog()
returns jsonb language sql stable security definer set search_path = '' as $$
  select jsonb_build_object(
    'pending', count(*) filter (where status = 'pending'),
    'oldestSeconds', coalesce(extract(epoch from now() - min(created_at)
      filter (where status = 'pending'))::bigint, 0))
  from private.marking_suggestions;
$$;

-- ---------------------------------------------------------------------------
-- 7. Billing: "Studafy AI Marking", a teacher's own plan (DL-073).
--    The retired teacher_ai_grading key stays retired (ai072).
-- ---------------------------------------------------------------------------
insert into public.store_products(feature_key, platform, environment,
  store_product_id, active, storefront_listed)
values
  ('studafy_ai_marking', 'app_store', 'synthetic', 'studafy_ai_marking_monthly', true, true),
  ('studafy_ai_marking', 'play_store', 'synthetic', 'studafy_ai_marking_monthly', true, true),
  ('studafy_ai_marking', 'app_store', 'development', 'studafy_ai_marking_monthly', true, true),
  ('studafy_ai_marking', 'play_store', 'development', 'studafy_ai_marking_monthly', true, true),
  -- Listed in production by a later migration, once the store products
  -- exist and the owner says so.
  ('studafy_ai_marking', 'app_store', 'staging', 'studafy_ai_marking_monthly', true, false),
  ('studafy_ai_marking', 'play_store', 'staging', 'studafy_ai_marking_monthly', true, false),
  ('studafy_ai_marking', 'app_store', 'production', 'studafy_ai_marking_monthly', true, false),
  ('studafy_ai_marking', 'play_store', 'production', 'studafy_ai_marking_monthly', true, false)
on conflict do nothing;

-- Subscription notices reach the teacher too: re-issued from 202609300007
-- with only the new key added to the list.
create or replace function private.billing_notify_entitlement_change()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
declare
  kind text;
  payer uuid;
  school uuid;
begin
  if new.feature_key not in (
    'studafy_plus', 'studafy_max', 'parent_insights',
    'family_plus', 'family_plus_large', 'studafy_ai_marking'
  ) then
    return null;
  end if;

  kind := case
    when new.status = 'active' and (tg_op = 'INSERT'
        or old.status not in ('active', 'grace_period'))
      then 'billing.subscription_active'
    when tg_op = 'UPDATE' and new.status = 'active' and old.status = 'active'
        and new.ends_at > coalesce(old.ends_at, '-infinity'::timestamptz) + interval '1 day'
      then 'billing.subscription_renewed'
    when tg_op = 'UPDATE' and new.status in ('grace_period', 'on_hold')
        and old.status = 'active'
      then 'billing.payment_problem'
    when tg_op = 'UPDATE' and new.status in ('expired', 'revoked')
        and old.status in ('active', 'grace_period', 'on_hold')
      then 'billing.subscription_ended'
  end;
  if kind is null then return null; end if;

  select st.purchaser_id into payer from public.store_transactions st
  where st.id = new.source_transaction_id;
  if payer is null then return null; end if;

  -- Notifications are held per school. The beneficiary's school first (a
  -- guardian's purchase is for a child's), then any school of the payer's,
  -- then - for a family plan held by the parent - a linked child's school.
  select s.school_id into school from public.students s
  where s.user_id = new.user_id and s.deleted_at is null
  order by s.created_at limit 1;
  if school is null then
    select m.school_id into school from public.memberships m
    where m.user_id = payer and m.active
    order by m.created_at limit 1;
  end if;
  if school is null then
    select gl.school_id into school from public.guardian_links gl
    where gl.guardian_id = payer and gl.status = 'verified'
    order by gl.verified_at, gl.id limit 1;
  end if;
  if school is null then return null; end if;

  perform private.notify_recipient(
    school, payer, kind,
    jsonb_build_object('featureKey', new.feature_key, 'endsAt', new.ends_at),
    'entitlement:' || new.id,
    kind || ':' || new.id || ':' || new.version
  );
  return null;
end;
$$;

-- ---------------------------------------------------------------------------
-- 7b. Retention, deletion and export.
-- ---------------------------------------------------------------------------

-- Suggestions are drafts for the teacher, not school records: kept 180 days,
-- then removed with the runs that made them (TODO(legal): confirm in the
-- retention schedule). The ledger is kept 13 months for the monthly cap and
-- billing questions. The worker calls this once an hour.
create or replace function private.marking_purge_expired()
returns jsonb language plpgsql security definer set search_path = '' as $$
declare
  v_suggestions int;
  v_runs int;
  v_usage int;
begin
  delete from private.marking_suggestions
  where status <> 'pending' and updated_at < now() - interval '180 days';
  get diagnostics v_suggestions = row_count;
  delete from private.marking_runs r
  where r.created_at < now() - interval '180 days'
    and not exists (select 1 from private.marking_suggestions s where s.run_id = r.id);
  get diagnostics v_runs = row_count;
  delete from private.marking_usage where created_at < now() - interval '13 months';
  get diagnostics v_usage = row_count;
  return jsonb_build_object('suggestions', v_suggestions, 'runs', v_runs,
    'usage', v_usage);
end;
$$;

-- A deleted account takes its marking data with it: a student's opt-out and
-- every suggestion about their work, a teacher's ledger and comp grants. The
-- teacher's references stay with the school's assessment.
create or replace function private.marking_forget_deleted_profile()
returns trigger language plpgsql security definer set search_path = '' as $$
begin
  if new.status = 'deleted' and old.status is distinct from 'deleted' then
    delete from private.marking_opt_outs where user_id = new.id;
    delete from private.marking_suggestions
      where student_id in (select st.id from public.students st where st.user_id = new.id);
    delete from private.marking_usage where user_id = new.id;
    delete from private.marking_plan_grants where user_id = new.id;
  end if;
  return new;
end;
$$;
drop trigger if exists dl073_marking_forget_deleted_profile on public.profiles;
create trigger dl073_marking_forget_deleted_profile
after update of status on public.profiles
for each row execute function private.marking_forget_deleted_profile();

-- The export gains one section: re-issued whole from 202610150070 with
-- only "aiMarking" added at the end.
create or replace function private.data_export_document(p_user uuid)
returns jsonb language sql stable security definer set search_path = '' as $$
  select jsonb_build_object(
    'format', 'studafy-export/v2',
    'generatedAt', now(),
    'sections', jsonb_build_object(
      'about', jsonb_build_object(
        'scope', 'This account''s own data. A child account a parent manages has its own export: open the child''s account and choose Download my data.',
        'files', 'Files are listed by name, type, size and date; their contents are not in this document. Open them in the app, or write to hello@studafy.com for a copy.',
        'voiceNotes', 'Voice notes are message attachments with kind "voiceNote".',
        'onlineAssessments', 'Your own answers are always included. The questions, marks and feedback are included once your teacher releases the answers, as in the app.',
        'gradeHistory', 'Each mark as it was published, and every correction or withdrawal since, with the reason given.',
        'limits', 'messagesSent, messagesReceived, filesUploaded and aiUsage hold the newest 5,000 entries each. Write to hello@studafy.com for the rest.',
        'notIncluded', 'Study helper chats are kept only on your device. Wellbeing notes are the school''s records: write to hello@studafy.com and we will pass your request to the school.'),
      'profile', (
        select jsonb_build_object(
          'id', p.id, 'displayName', p.display_name, 'locale', p.locale,
          'status', p.status, 'createdAt', p.created_at,
          'gender', p.gender, 'studafyId', p.public_id,
          'email', (select u.email from auth.users u where u.id = p.id),
          'managedBy', (
            select g.display_name from private.managed_accounts m
            join public.profiles g on g.id = m.guardian_id
            where m.child_id = p.id)
        ) from public.profiles p where p.id = p_user),
      'managedChildAccounts', coalesce((
        select jsonb_agg(jsonb_build_object(
          'displayName', c.display_name, 'studafyId', c.public_id,
          'managedSince', m.created_at
        ) order by m.created_at)
        from private.managed_accounts m
        join public.profiles c on c.id = m.child_id
        where m.guardian_id = p_user and c.deleted_at is null), '[]'::jsonb),
      'memberships', coalesce((
        select jsonb_agg(jsonb_build_object(
          'school', s.name, 'role', m.role, 'status', m.status,
          'validFrom', m.valid_from, 'validUntil', m.valid_until
        ) order by m.created_at)
        from public.memberships m join public.schools s on s.id = m.school_id
        where m.user_id = p_user), '[]'::jsonb),
      'guardianLinks', coalesce((
        select jsonb_agg(jsonb_build_object(
          'child', st.display_name, 'school', s.name, 'status', gl.status,
          'relationship', gl.relationship, 'verifiedAt', gl.verified_at
        ))
        from public.guardian_links gl
        join public.students st on st.id = gl.student_id
        join public.schools s on s.id = st.school_id
        where gl.guardian_id = p_user), '[]'::jsonb),
      'studentRecords', coalesce((
        select jsonb_agg(jsonb_build_object(
          'school', s.name, 'displayName', st.display_name,
          'studafyId', st.studafy_id,
          'publishedGrades', coalesce((
            select jsonb_agg(jsonb_build_object(
              'assessment', a.title, 'mark', g.mark, 'score', g.score,
              'maximumScore', a.maximum_score, 'feedback', g.feedback,
              'publishedAt', g.published_at,
              'returnedFiles', private.data_export_files(p_grade_result => g.id)
            ) order by g.published_at)
            from public.grade_results g
            join public.assessments a on a.id = g.assessment_id
            where g.student_id = st.id and g.state = 'published'), '[]'::jsonb),
          -- From publication on: what the student was shown, then each
          -- change to it. A draft before publication was never theirs to see.
          'gradeHistory', coalesce((
            select jsonb_agg(jsonb_build_object(
              'assessment', a.title, 'change', e.event_type,
              'previousMark', case when e.event_type <> 'published' then e.previous_mark end,
              'previousScore', case when e.event_type <> 'published' then e.previous_score end,
              'previousFeedback', case when e.event_type <> 'published' then e.previous_feedback end,
              'mark', e.next_mark, 'score', e.next_score, 'feedback', e.next_feedback,
              'reason', case when e.event_type <> 'published' then e.reason end,
              'at', e.created_at
            ) order by e.created_at, e.id)
            from public.grade_results g
            join public.assessments a on a.id = g.assessment_id
            join public.grade_result_events e on e.grade_result_id = g.id
            where g.student_id = st.id
              and e.event_type in ('published', 'corrected', 'withdrawn')), '[]'::jsonb),
          'attendance', coalesce((
            select jsonb_agg(jsonb_build_object(
              'lesson', ls.title, 'lessonStartsAt', ls.starts_at,
              'state', ar.state, 'reason', ar.reason, 'recordedAt', ar.recorded_at
            ) order by ar.recorded_at)
            from public.attendance_records ar
            left join public.lesson_sessions ls on ls.id = ar.session_id
            where ar.student_id = st.id), '[]'::jsonb),
          'attendanceHistory', coalesce((
            select jsonb_agg(jsonb_build_object(
              'lesson', ls.title, 'lessonStartsAt', ls.starts_at,
              'previousState', r.previous_state, 'previousReason', r.previous_reason,
              'state', r.next_state, 'reason', r.next_reason,
              'changeReason', r.reason, 'at', r.created_at
            ) order by r.created_at, r.id)
            from public.attendance_record_revisions r
            left join public.lesson_sessions ls on ls.id = r.session_id
            where r.student_id = st.id), '[]'::jsonb),
          'submissions', coalesce((
            select jsonb_agg(jsonb_build_object(
              'assignment', asg.title, 'status', sb.status,
              'submittedAt', sb.submitted_at, 'excused', sb.excused,
              'attempts', coalesce((
                select jsonb_agg(jsonb_build_object(
                  'submittedAt', sa.submitted_at,
                  'text', nullif(sa.answer_text, ''),
                  'current', sa.id is not distinct from sb.current_attempt_id,
                  'handedInByParent', sa.submitted_by_guardian_id is not null,
                  'files', private.data_export_files(p_submission_attempt => sa.id)
                ) order by sa.created_at, sa.id)
                from public.submission_attempts sa
                where sa.submission_id = sb.id), '[]'::jsonb)
            ) order by sb.created_at)
            from public.submissions sb
            join public.assignments asg on asg.id = sb.assignment_id
            where sb.student_id = st.id), '[]'::jsonb),
          'onlineAssessments', coalesce((
            select jsonb_agg(jsonb_build_object(
                'assessment', a.title, 'attemptNumber', t.attempt_number,
                'submittedAt', t.submitted_at, 'answersReleased', rel.released,
                'answers', (
                  select coalesce(jsonb_agg(jsonb_build_object(
                      'questionNumber', q.position,
                      'answerText', nullif(aa.answer_text, ''),
                      'selectedOptionIds', case when jsonb_typeof(aa.selected) = 'array' then aa.selected end,
                      'choice', case when jsonb_typeof(aa.selected) = 'boolean' then aa.selected end)
                    || case when rel.released then jsonb_build_object(
                      'question', q.prompt,
                      'selectedOptions', case when jsonb_typeof(aa.selected) = 'array' then (
                        select coalesce(jsonb_agg(o->>'text' order by ord), '[]'::jsonb)
                        from jsonb_array_elements(q.options) with ordinality x(o, ord)
                        where aa.selected ? (o->>'id')) end,
                      'autoScore', aa.auto_score, 'awardedScore', aa.awarded_score,
                      'maximumScore', q.maximum_score, 'feedback', aa.feedback)
                      else '{}'::jsonb end
                    order by q.position), '[]'::jsonb)
                  from public.assessment_answers aa
                  join public.assessment_questions q on q.id = aa.question_id
                  where aa.attempt_id = t.id))
              || case when rel.released then jsonb_build_object(
                'awardedScore', t.awarded_score, 'feedback', t.feedback)
                else '{}'::jsonb end
              order by t.submitted_at, t.id)
            from public.assessment_attempts t
            join public.assessments a on a.id = t.assessment_id
            cross join lateral (
              select private.assessment_answers_released(a.id) as released) rel
            where t.student_id = st.id), '[]'::jsonb)
        ))
        from public.students st join public.schools s on s.id = st.school_id
        where st.user_id = p_user and st.deleted_at is null), '[]'::jsonb),
      'notebookEntries', coalesce((
        select jsonb_agg(jsonb_build_object(
          'title', n.title, 'body', n.body, 'source', n.source,
          'createdAt', n.created_at, 'updatedAt', n.updated_at
        ) order by n.created_at)
        from public.notebook_entries n
        where n.owner_id = p_user and n.deleted_at is null), '[]'::jsonb),
      'studyNotebooks', coalesce((
        select jsonb_agg(jsonb_build_object(
          'title', sn.title, 'subtitle', sn.subtitle, 'status', sn.status,
          'content', sn.content, 'personal', sn.personal,
          'createdAt', sn.created_at, 'updatedAt', sn.updated_at
        ) order by sn.created_at)
        from public.study_notebooks sn
        where sn.owner_id = p_user and sn.deleted_at is null), '[]'::jsonb),
      'devices', coalesce((
        select jsonb_agg(d.device order by d.seen desc)
        from (
          select jsonb_build_object(
              'kind', 'signIn', 'platform', ad.platform, 'appVersion', ad.app_version,
              'label', ad.display_label, 'firstSeenAt', ad.first_seen_at,
              'lastSeenAt', ad.last_seen_at, 'revokedAt', ad.revoked_at
            ) as device, ad.last_seen_at as seen
          from public.auth_devices ad where ad.user_id = p_user
          union all
          select jsonb_build_object(
              'kind', 'notifications', 'platform', pd.platform,
              'registeredAt', pd.created_at, 'lastSeenAt', pd.last_seen_at,
              'revokedAt', pd.revoked_at
            ), pd.last_seen_at
          from public.push_devices pd where pd.user_id = p_user
        ) d), '[]'::jsonb),
      'conversations', coalesce((
        select jsonb_agg(jsonb_build_object(
          'conversationId', c.id, 'subject', c.subject,
          'joinedAt', cp.joined_at, 'leftAt', cp.left_at
        ) order by cp.joined_at, c.id)
        from public.conversation_participants cp
        join public.conversations c on c.id = cp.conversation_id
        where cp.user_id = p_user), '[]'::jsonb),
      'messagesSent', coalesce((
        select jsonb_agg(jsonb_build_object(
          'conversationId', m.conversation_id, 'body', m.body, 'sentAt', m.created_at,
          'editedAt', m.edited_at,
          'attachments', private.data_export_files(p_message => m.id)
        ) order by m.created_at)
        from (
          select * from public.messages
          where sender_id = p_user and deleted_at is null
          order by created_at desc limit 5000
        ) m), '[]'::jsonb),
      -- What the app shows the person: the conversations they are still in.
      'messagesReceived', coalesce((
        select jsonb_agg(jsonb_build_object(
          'conversationId', m.conversation_id, 'from', p.display_name,
          'body', m.body, 'sentAt', m.created_at, 'editedAt', m.edited_at,
          'attachments', private.data_export_files(p_message => m.id)
        ) order by m.created_at)
        from (
          select x.* from public.conversation_participants cp
          join public.messages x on x.conversation_id = cp.conversation_id
          where cp.user_id = p_user and cp.left_at is null
            and x.sender_id is distinct from p_user and x.deleted_at is null
          order by x.created_at desc limit 5000
        ) m
        left join public.profiles p on p.id = m.sender_id), '[]'::jsonb),
      'filesUploaded', coalesce((
        select jsonb_agg(private.data_export_file_json(f)
            || jsonb_build_object('purpose', f.purpose, 'scanState', f.scan_state)
          order by f.created_at)
        from (
          select * from public.file_objects
          where owner_id = p_user and deleted_at is null
          order by created_at desc limit 5000
        ) f), '[]'::jsonb),
      'aiUsage', coalesce((
        select jsonb_agg(jsonb_build_object(
          'feature', u.feature, 'plan', u.plan, 'status', u.status,
          'inputTokens', u.input_tokens, 'outputTokens', u.output_tokens,
          'countedTokens', u.metered_tokens, 'model', u.model,
          'at', u.created_at
        ) order by u.created_at)
        from (
          select * from private.ai_usage
          where user_id = p_user
          order by created_at desc limit 5000
        ) u), '[]'::jsonb),
      'reportsFiled', coalesce((
        select jsonb_agg(jsonb_build_object(
          'kind', r.kind, 'status', r.status, 'details', r.details,
          'filedAt', r.created_at, 'resolvedAt', r.resolved_at
        ) order by r.created_at)
        from public.reports r where r.reported_by = p_user), '[]'::jsonb),
      'blocksMade', coalesce((
        select jsonb_agg(jsonb_build_object(
          'scope', b.scope, 'createdAt', b.created_at, 'expiresAt', b.expires_at
        ))
        from public.user_blocks b where b.blocker_id = p_user), '[]'::jsonb),
      'consents', coalesce((
        select jsonb_agg(jsonb_build_object(
          'purpose', c.purpose, 'policyVersion', c.policy_version,
          'acceptedAt', c.accepted_at, 'withdrawnAt', c.withdrawn_at
        ) order by c.accepted_at)
        from public.consent_records c where c.user_id = p_user), '[]'::jsonb),
      'purchases', coalesce((
        select jsonb_agg(jsonb_build_object(
          'product', sp.feature_key, 'platform', t.platform, 'state', t.state,
          'purchasedAt', t.purchased_at, 'effectiveUntil', t.effective_until
        ) order by t.purchased_at)
        from public.store_transactions t
        join public.store_products sp on sp.id = t.product_id
        where t.purchaser_id = p_user), '[]'::jsonb),
      'entitlements', coalesce((
        select jsonb_agg(jsonb_build_object(
          'feature', e.feature_key, 'status', e.status,
          'startsAt', e.starts_at, 'endsAt', e.ends_at
        ))
        from public.entitlements e where e.user_id = p_user), '[]'::jsonb),
      'notifications', coalesce((
        select jsonb_agg(jsonb_build_object(
          'template', o.template_key, 'deliveredAt', d.delivered_at,
          'readAt', d.read_at
        ) order by d.delivered_at)
        from public.notification_deliveries d
        join public.notification_outbox o on o.id = d.outbox_id
        where d.recipient_id = p_user), '[]'::jsonb),
      -- ADR-0046: a student's choice about suggested marks, and a teacher's
      -- Studafy AI Marking usage. Suggestions are drafts for the teacher and
      -- not included; marks are in grades.
      'aiMarking', jsonb_build_object(
        'about', 'A student''s choice about AI-suggested marks, and a teacher''s Studafy AI Marking usage. Suggestions are drafts for the teacher and are not included; your marks are in grades.',
        'optedOut', exists (select 1 from private.marking_opt_outs o where o.user_id = p_user),
        'usage', coalesce((
          select jsonb_agg(jsonb_build_object(
            'state', u.state, 'tokens', u.tokens, 'model', u.model, 'at', u.created_at)
            order by u.created_at)
          from (select * from private.marking_usage where user_id = p_user
                order by created_at desc limit 5000) u), '[]'::jsonb))
    )
  );
$$;

-- Who may buy it: re-issued whole from 202610210050 with only the teacher
-- branch widened to the new key.
create or replace function private.billing_resolve_beneficiary(p_purchaser uuid, p_feature_key text, p_beneficiary_student_id uuid, p_parental_gate_confirmed boolean)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
declare
  student_row public.students%rowtype;
  guardian_link uuid;
  purchaser_school uuid;
begin
  -- Studafy AI Marking (DL-073) is a teacher's own plan, bought by the
  -- teacher for themselves, like the retired teacher_ai_grading before it.
  if p_feature_key in ('teacher_ai_grading', 'studafy_ai_marking') then
    if p_beneficiary_student_id is not null then
      return jsonb_build_object('ok', false, 'outcome', 'invalid_beneficiary');
    end if;
    if not exists (
      select 1 from public.memberships m
      where m.user_id = p_purchaser and m.role = 'teacher'
        and m.active and m.status = 'active'
        and m.valid_from <= now() and (m.valid_until is null or m.valid_until > now())
    ) then
      return jsonb_build_object('ok', false, 'outcome', 'not_eligible');
    end if;
    return jsonb_build_object(
      'ok', true, 'beneficiaryId', p_purchaser, 'guardianLinkId', null
    );
  end if;

  -- Family+ is the parent's own plan, covering their linked children up to
  -- the plan's size. It is held by the guardian who pays, so no child is
  -- named at purchase; only somebody who is already a verified guardian of
  -- at least one child may buy it.
  if p_feature_key in ('family_plus', 'family_plus_large') then
    if p_beneficiary_student_id is not null then
      return jsonb_build_object('ok', false, 'outcome', 'invalid_beneficiary');
    end if;
    if not exists (
      select 1 from public.guardian_links gl
      join public.students s on s.id = gl.student_id and s.deleted_at is null
      where gl.guardian_id = p_purchaser and gl.status = 'verified'
        and (gl.expires_at is null or gl.expires_at > now())
    ) then
      return jsonb_build_object('ok', false, 'outcome', 'not_eligible');
    end if;
    return jsonb_build_object(
      'ok', true, 'beneficiaryId', p_purchaser, 'guardianLinkId', null
    );
  end if;

  if p_feature_key = 'parent_insights' and p_beneficiary_student_id is null then
    return jsonb_build_object('ok', false, 'outcome', 'beneficiary_required');
  end if;

  if p_beneficiary_student_id is not null then
    select * into student_row from public.students
    where id = p_beneficiary_student_id and deleted_at is null;
    if student_row.id is null then
      return jsonb_build_object('ok', false, 'outcome', 'beneficiary_link_invalid');
    end if;
    select gl.id into guardian_link
      from public.guardian_links gl
      where gl.student_id = student_row.id
        and gl.guardian_id = p_purchaser
        and gl.status = 'verified'
        and (gl.expires_at is null or gl.expires_at > now())
      limit 1;
    if guardian_link is null then
      return jsonb_build_object('ok', false, 'outcome', 'beneficiary_link_invalid');
    end if;
    return jsonb_build_object(
      'ok', true, 'beneficiaryId', student_row.user_id, 'guardianLinkId', guardian_link
    );
  end if;

  -- Self-purchase: a student buying their own plan. The store account on
  -- the phone pays; for a child, the store's own family controls (Family
  -- Link, Ask to Buy) are where a parent approves (DL-071).
  --
  -- A student account in no class (ADR-0045) has no student record and no
  -- school, so neither may be required: the account's kind says it is a
  -- student's. A school's opt-out still applies to its own students.
  select st.* into student_row from public.students st
  where st.user_id = p_purchaser and st.deleted_at is null
  limit 1;
  if student_row.id is null
     and private.account_kind(p_purchaser) is distinct from 'student' then
    return jsonb_build_object('ok', false, 'outcome', 'not_eligible');
  end if;
  if p_feature_key not in ('studafy_plus', 'studafy_max')
     and not p_parental_gate_confirmed then
    return jsonb_build_object('ok', false, 'outcome', 'parental_gate_required');
  end if;
  if exists (
    select 1 from public.memberships m
    join public.school_billing_settings s on s.school_id = m.school_id
    where m.user_id = p_purchaser and m.role = 'student'
      and m.active and m.status = 'active'
      and m.valid_from <= now() and (m.valid_until is null or m.valid_until > now())
      and not s.self_purchase_enabled
  ) then
    return jsonb_build_object('ok', false, 'outcome', 'student_purchase_disabled');
  end if;
  return jsonb_build_object(
    'ok', true, 'beneficiaryId', p_purchaser, 'guardianLinkId', null
  );
end;
$function$;

-- ---------------------------------------------------------------------------
-- 8. Owners and grants. The API calls api059_*; the worker its doors; every
--    helper is reached only through them.
-- ---------------------------------------------------------------------------
do $grants$
declare fn text;
begin
  foreach fn in array array[
    'private.marking_limits()',
    'private.marking_plan_active(uuid)',
    'private.marking_month_used(uuid)',
    'private.marking_assessment(uuid)',
    'private.marking_settings_json(uuid)',
    'private.marking_references_json(uuid)',
    'private.marking_known_names(uuid, uuid)',
    'private.marking_opted_out(uuid)',
    'private.marking_key_points_valid(jsonb, numeric)',
    'private.api059_query(text, uuid, jsonb)',
    'private.api059_command(text, uuid, jsonb, uuid, bigint)',
    'private.marking_job_held(text, uuid, integer)',
    'private.marking_jobs_claim(text, integer)',
    'private.marking_job_usage(text, uuid, integer, text, jsonb)',
    'private.marking_job_finish(text, uuid, integer, text, jsonb)',
    'private.marking_jobs_backlog()',
    'private.marking_purge_expired()',
    'private.marking_forget_deleted_profile()',
    'private.billing_notify_entitlement_change()',
    'private.data_export_document(uuid)',
    'private.billing_resolve_beneficiary(uuid, text, uuid, boolean)'
  ] loop
    execute format('alter function %s owner to postgres', fn);
    execute format('revoke all on function %s from public, anon, authenticated, service_role, studafy_api_runtime, studafy_worker_runtime', fn);
  end loop;
end
$grants$;

grant execute on function private.api059_query(text, uuid, jsonb) to studafy_api_runtime;
grant execute on function private.api059_command(text, uuid, jsonb, uuid, bigint)
  to studafy_api_runtime;
grant execute on function private.marking_jobs_claim(text, integer),
  private.marking_job_usage(text, uuid, integer, text, jsonb),
  private.marking_job_finish(text, uuid, integer, text, jsonb),
  private.marking_jobs_backlog(),
  private.marking_purge_expired()
  to studafy_worker_runtime;

