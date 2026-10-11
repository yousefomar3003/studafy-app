-- Marking online work, corrections after publication, and whether a section
-- has its lesson (2026-10-07).
--
-- Three defects, found by following each path end to end:
--
--   * The teacher's feedback on an attempt never reached the student's
--     grade. assessment_sync_grade copied the score and left the grade's
--     feedback empty, so a published grade carried no comment.
--   * Marking an attempt again after its grade was published changed the
--     answers and the attempt, but the published grade kept its old score:
--     the sync leaves published grades alone, so a correction never reached
--     the student or their parents. Such a change is now a correction, with
--     a reason, through the same path as every other correction (history,
--     and a notice only when the mark itself changes).
--   * The marks were checked one at a time while being written, so a bad
--     mark late in a request left the earlier ones written. All are checked
--     first now.
--
-- The teacher's marking list also says, per attempt, where its grade stands
-- (unmarked, partly marked, marked, published), and a lesson section says
-- whether a lesson the class can see is filed for it: a draft never counts.
--
-- Forward-only and no rename-and-wrap (ADR-0030): each function is
-- replaced, and the query dispatcher gains one post-processing step.

-- ---------------------------------------------------------------------------
-- 1. The result that counts for one student: the latest attempt or the best
--    marked one, with its feedback.
-- ---------------------------------------------------------------------------

create or replace function private.assessment_counting_result(p_assessment uuid, p_student uuid)
returns table(pending boolean, score numeric, feedback text, marker uuid)
language plpgsql stable security definer set search_path = '' as $$
declare
  a public.assessments%rowtype;
begin
  select * into a from public.assessments x where x.id = p_assessment;
  if a.id is null then return; end if;
  select coalesce(bool_or(t.needs_marking), false) into pending
  from public.assessment_attempts t
  where t.assessment_id = a.id and t.student_id = p_student;
  if a.attempt_policy = 'latest' then
    select t.awarded_score, nullif(btrim(t.feedback), ''), t.marked_by
    into score, feedback, marker
    from public.assessment_attempts t
    where t.assessment_id = a.id and t.student_id = p_student
    order by t.attempt_number desc nulls last, t.submitted_at desc limit 1;
  else
    select t.awarded_score, nullif(btrim(t.feedback), ''), t.marked_by
    into score, feedback, marker
    from public.assessment_attempts t
    where t.assessment_id = a.id and t.student_id = p_student and not t.needs_marking
    order by t.awarded_score desc nulls last, t.attempt_number desc nulls last limit 1;
  end if;
  return next;
end;
$$;

-- Recomputes one student's draft grade from their attempts, feedback
-- included. A grade already published or withdrawn is the teacher's to
-- correct and is left alone.
create or replace function private.assessment_sync_grade(p_assessment uuid, p_student uuid)
returns void language plpgsql security definer set search_path = '' as $$
declare
  a public.assessments%rowtype;
  r record;
  v_score numeric;
  v_state public.publication_state;
begin
  select * into a from public.assessments x where x.id = p_assessment;
  if a.id is null then return; end if;
  if not exists (select 1 from public.assessment_attempts t
      where t.assessment_id = a.id and t.student_id = p_student) then
    return;
  end if;
  select * into r from private.assessment_counting_result(a.id, p_student);
  v_score := case when r.pending then null else r.score end;
  v_state := (case when v_score is null then 'draft' else 'reviewed' end)::public.publication_state;

  insert into public.grade_results as g(school_id, assessment_id, student_id, score, state, version)
  values (a.school_id, a.id, p_student, null, 'draft', 1)
  on conflict (assessment_id, student_id) do nothing;

  update public.grade_results g set
    score = v_score,
    mark = case when v_score is null then null else 'scored'::public.grade_mark end,
    feedback = r.feedback,
    state = v_state,
    -- An automatic mark is the key the class's teacher wrote.
    reviewed_by = case when v_score is null then null else coalesce(r.marker, a.created_by) end,
    reviewed_at = case when v_score is null then null else now() end,
    version = g.version + 1, updated_at = now()
  where g.assessment_id = a.id and g.student_id = p_student
    and g.state in ('draft', 'reviewed')
    and (g.score, g.state, g.feedback) is distinct from (v_score, v_state, r.feedback);
  update public.assessments set gradebook_version = gradebook_version + 1 where id = a.id;
end;
$$;

-- ---------------------------------------------------------------------------
-- 2. Marking: every mark checked before any is written; a change to a
--    published grade is a correction with a reason.
-- ---------------------------------------------------------------------------

create or replace function private.api041_mark_assessment_attempt(
  p_attempt uuid, p_input jsonb, p_idempotency_id uuid, p_idempotency_generation bigint)
returns jsonb language plpgsql security definer set search_path = '' as $$
declare
  body jsonb := coalesce(p_input->'body', '{}'::jsonb);
  v_key text;
  t public.assessment_attempts%rowtype;
  a public.assessments%rowtype;
  g public.grade_results%rowtype;
  v_mark jsonb;
  v_pending boolean;
  v_total numeric;
  r record;
  v_result jsonb;
  v_reason text := nullif(btrim(body->>'correctionReason'), '');
  v_corrected boolean := false;
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

  -- Every mark names an answer of this attempt once, and fits its question.
  if (select count(*) <> count(distinct m->>'questionId') from jsonb_array_elements(body->'marks') m)
     or exists (
       select 1 from jsonb_array_elements(body->'marks') m
       left join public.assessment_answers aa
         on aa.attempt_id = t.id and aa.question_id = (m->>'questionId')::uuid
       left join public.assessment_questions q on q.id = aa.question_id
       where q.id is null or jsonb_typeof(m->'score') <> 'number'
         or (m->>'score')::numeric < 0 or (m->>'score')::numeric > q.maximum_score
         or char_length(coalesce(m->>'feedback', '')) > 5000) then
    return jsonb_build_object('outcome', 'invalid');
  end if;

  select * into g from public.grade_results x
  where x.assessment_id = a.id and x.student_id = t.student_id for update;

  for v_mark in select value from jsonb_array_elements(body->'marks') loop
    update public.assessment_answers set awarded_score = (v_mark->>'score')::numeric,
      feedback = nullif(btrim(v_mark->>'feedback'), ''), marked_by = auth.uid(), marked_at = now()
    where attempt_id = t.id and question_id = (v_mark->>'questionId')::uuid
      and (awarded_score, feedback) is distinct from
        ((v_mark->>'score')::numeric, nullif(btrim(v_mark->>'feedback'), ''));
  end loop;
  select bool_or(aa.awarded_score is null), sum(aa.awarded_score) into v_pending, v_total
  from public.assessment_answers aa where aa.attempt_id = t.id;
  update public.assessment_attempts set needs_marking = coalesce(v_pending, false),
    awarded_score = case when coalesce(v_pending, false) then null else v_total end,
    feedback = case when body ? 'feedback' then nullif(btrim(body->>'feedback'), '') else feedback end,
    marked_by = auth.uid(), marked_at = now()
  where id = t.id;

  if g.state = 'published' then
    -- Published marks are corrected, never quietly replaced: the student and
    -- their parents already saw the old one.
    select * into r from private.assessment_counting_result(a.id, t.student_id);
    if not r.pending and r.score is not null
       and (private.grade_mark_of(g.mark, g.score), g.score, nullif(btrim(g.feedback), ''))
         is distinct from ('scored', r.score, r.feedback) then
      if v_reason is null or char_length(v_reason) < 3 then
        raise exception using errcode = 'SF047', message = 'reason_required';
      end if;
      v_result := private.gradebook_apply_corrections(a,
        jsonb_build_array(jsonb_build_object('gradeResultId', g.id,
          'expectedVersion', g.version, 'mark', 'scored', 'score', r.score,
          'feedback', r.feedback)),
        v_reason, v_key);
      if v_result->>'outcome' <> 'ok' then
        raise exception using errcode = 'SF047', message = v_result->>'outcome';
      end if;
      update public.assessments set gradebook_version = gradebook_version + 1 where id = a.id;
      v_corrected := true;
    end if;
  else
    perform private.assessment_sync_grade(a.id, t.student_id);
  end if;

  return private.coursework_finish(p_idempotency_id, p_idempotency_generation, 200,
    'assessment_attempt_marked', 'assessment_attempt', t.id, null,
    jsonb_build_object('marks', jsonb_array_length(body->'marks'), 'corrected', v_corrected),
    private.assessment_attempt_json(t.id, 'staff'));
exception when sqlstate 'SF047' then
  return jsonb_build_object('outcome', sqlerrm);
end;
$$;

-- ---------------------------------------------------------------------------
-- 3. Read models: where each attempt's grade stands, for the class's staff.
-- ---------------------------------------------------------------------------

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
    || case when p_mode = 'staff' then jsonb_build_object(
      'studentName', st.display_name,
      'gradeState', (select g.state from public.grade_results g
        where g.assessment_id = t.assessment_id and g.student_id = t.student_id))
      else '{}'::jsonb end
  from public.assessment_attempts t
  join public.students st on st.id = t.student_id
  where t.id = p_attempt;
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
      'needsMarking', t.needs_marking, 'awardedScore', t.awarded_score,
      'gradeState', g.state,
      'pendingAnswers', (select count(*) from public.assessment_answers aa
        where aa.attempt_id = t.id and aa.awarded_score is null),
      'manualAnswers', (select count(*) from public.assessment_answers aa
        where aa.attempt_id = t.id and aa.auto_score is null))
      order by st.display_name, t.attempt_number), '[]'::jsonb)
    from public.assessment_attempts t
    join public.students st on st.id = t.student_id
    left join public.grade_results g on g.assessment_id = t.assessment_id and g.student_id = t.student_id
    where t.assessment_id = a.id), 'nextPosition', null);
end;
$$;

-- ---------------------------------------------------------------------------
-- 4. Whether a section has its lesson.
-- ---------------------------------------------------------------------------

-- 'published' when a lesson filed for the section is published to students
-- (a lesson for parents alone is not one the class can learn from), 'draft'
-- while the only ones are drafts - said only to the class's staff - else
-- 'none'. A lesson filed for a section keeps that link through later
-- versions: the link is on its first publication.
create or replace function private.lesson_session_content_state(p_session uuid, p_staff boolean)
returns text language sql stable security definer set search_path = '' as $$
  with filed as (
    select distinct r.id, r.state
    from public.resource_publications rp
    join public.resource_versions rv on rv.id = rp.resource_version_id
    join public.resources r on r.id = rv.resource_id
    where rp.lesson_session_id = p_session and r.deleted_at is null
  )
  select case
    when exists (select 1 from filed f where f.state = 'published' and exists (
        select 1 from public.resource_publications rp
        join public.resource_versions rv on rv.id = rp.resource_version_id
        where rv.resource_id = f.id and rp.state = 'published'
          and rp.audience in ('students', 'both')))
      then 'published'
    when p_staff and exists (select 1 from filed f where f.state = 'draft')
      then 'draft'
    else 'none' end;
$$;

-- ---------------------------------------------------------------------------
-- 5. The query dispatcher: copied from 202610060001 with each lesson
--    section's content state added to listLessonSessions.
-- ---------------------------------------------------------------------------

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

  -- Each section says whether its lesson is filed and published, so a
  -- section is not reported as needing content once the class can see one.
  if p_operation = 'listLessonSessions' and jsonb_typeof(result->'items') = 'array' then
    result := jsonb_set(result, '{items}', (
      select coalesce(jsonb_agg(item || jsonb_build_object('contentState',
          private.lesson_session_content_state((item->>'id')::uuid,
            private.coursework_staff((item->>'classroomId')::uuid)))
        order by ordinality), '[]'::jsonb)
      from jsonb_array_elements(result->'items') with ordinality as t(item, ordinality)));
  end if;
  return result;
end;
$function$;

-- ---------------------------------------------------------------------------
-- 6. Ownership and grants: handlers are reached only through the
--    dispatchers, whose grants are unchanged.
-- ---------------------------------------------------------------------------

do $grants$
declare
  f text;
begin
  foreach f in array array[
    'private.assessment_counting_result(uuid,uuid)',
    'private.assessment_sync_grade(uuid,uuid)',
    'private.api041_mark_assessment_attempt(uuid,jsonb,uuid,bigint)',
    'private.assessment_attempt_json(uuid,text)',
    'private.api041_assessment_attempts(uuid,jsonb)',
    'private.lesson_session_content_state(uuid,boolean)',
    'private.api041_query(text,uuid,jsonb)'
  ] loop
    execute format('alter function %s owner to postgres', f);
    execute format('revoke all on function %s from public, anon, authenticated, service_role, studafy_api_runtime, studafy_worker_runtime', f);
  end loop;
end;
$grants$;

grant execute on function private.api041_query(text, uuid, jsonb) to studafy_api_runtime;
