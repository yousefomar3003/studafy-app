-- Absence for online exams, and edits to a published grade that are not
-- corrections (ADR-0040, 2026-10-07).
--
--   * A teacher may record a student who handed nothing in as absent - or
--     clear it - through the class gradebook's draft save. Only that: online
--     work is otherwise marked from what was handed in, and an absence never
--     carries a score. It is private until published with the class's
--     grades, and each change is kept in the grade's history.
--   * A student who hands in after being marked absent replaces an
--     unpublished absence with the attempt's result (recorded in the
--     history). A published absence is left alone: the family saw it, so the
--     teacher corrects it, with a reason, by marking the attempt.
--   * After publication, only a change to the mark or the score is a
--     correction needing a reason. A change to the feedback alone is applied
--     at once, kept in the history with the text it replaced, and not
--     announced. Answer comments never touch the grade.
--
-- Each function is replaced whole (ADR-0030); nothing is renamed.

-- ---------------------------------------------------------------------------
-- 1. The class gradebook's draft save: copied from 202609300001 with online
--    absences allowed and recorded.
-- ---------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION private.api041_save_grade_drafts(p_assessment uuid, p_input jsonb, p_idempotency_id uuid, p_idempotency_generation bigint)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
declare
  body jsonb := coalesce(p_input->'body', '{}'::jsonb);
  v_entries jsonb := coalesce(body->'entries', '[]'::jsonb);
  v_key text;
  a public.assessments;
  v_outcome text;
  v_errors jsonb;
  v_conflicts int;
  v_saved int;
  v_version bigint;
  v_grades jsonb;
  -- Online absences only: each row as it was, for its history.
  v_before jsonb;
begin
  v_key := private.coursework_idempotency_key(p_idempotency_id, p_idempotency_generation);
  if v_key is null then return jsonb_build_object('outcome', 'forbidden'); end if;
  select * into a from public.assessments x
  where x.id = p_assessment and x.deleted_at is null for update;
  v_outcome := private.gradebook_refusal(a);
  if v_outcome is not null then return jsonb_build_object('outcome', v_outcome); end if;
  -- Online work is marked from what was handed in. The one mark a teacher
  -- enters here for it is an absence - or clearing one - for a student who
  -- has handed nothing in (ADR-0040). Never a score: absence is not a zero.
  if a.delivery <> 'paper' and exists (
      select 1 from private.gradebook_entries(v_entries) e
      where (e.mark is not null and e.mark <> 'absent') or e.score is not null
        or exists (select 1 from public.assessment_attempts t
          where t.assessment_id = a.id and t.student_id = e.student_id)) then
    return jsonb_build_object('outcome', 'invalid_state');
  end if;
  if body ? 'expectedGradebookVersion'
     and (body->>'expectedGradebookVersion')::bigint <> a.gradebook_version then
    return jsonb_build_object('outcome', 'version_conflict');
  end if;
  if (select count(*) <> count(distinct e.student_id) or bool_or(e.student_id is null)
      from private.gradebook_entries(v_entries) e) then
    return jsonb_build_object('outcome', 'invalid');
  end if;

  -- Rows are locked in id order so two saves of the same sheet queue rather
  -- than deadlock; the assessment lock above already serialises them.
  perform 1 from public.grade_results g
  where g.assessment_id = a.id
    and g.student_id in (select e.student_id from private.gradebook_entries(v_entries) e)
  order by g.id for update;

  -- Every refusal, per student, in one pass. Nothing is written unless the
  -- whole sheet is valid.
  select coalesce(jsonb_agg(jsonb_build_object('studentId', x.student_id,
      'reason', x.reason) order by x.student_id), '[]'::jsonb),
    count(*) filter (where x.reason = 'version_conflict')
  into v_errors, v_conflicts
  from (
    select e.student_id, case
      when g.id is null and not exists (
        select 1 from public.enrollments en
        where en.classroom_id = a.classroom_id and en.student_id = e.student_id
          and en.active and en.status = 'active') then 'not_enrolled'
      when g.state in ('published', 'withdrawn') then 'already_published'
      when coalesce(g.version, 0) <> e.expected_version then 'version_conflict'
      when e.mark = 'scored' and e.score is null then 'score_required'
      when e.mark = 'scored' and (e.score < 0 or e.score > a.maximum_score)
        then 'score_out_of_range'
      when e.mark is distinct from 'scored' and e.score is not null
        then 'score_not_allowed'
    end as reason
    from private.gradebook_entries(v_entries) e
    left join public.grade_results g
      on g.assessment_id = a.id and g.student_id = e.student_id
  ) x
  where x.reason is not null;

  if jsonb_array_length(v_errors) > 0 then
    return jsonb_build_object(
      'outcome', case when v_conflicts > 0 then 'version_conflict'
        else 'grade_entries_invalid' end,
      'rows', v_errors);
  end if;

  select coalesce(jsonb_object_agg(g.student_id::text, jsonb_build_object(
      'mark', g.mark, 'feedback', g.feedback, 'state', g.state)), '{}'::jsonb)
  into v_before from public.grade_results g
  where g.assessment_id = a.id
    and g.student_id in (select e.student_id from private.gradebook_entries(v_entries) e);

  with saved as (
    insert into public.grade_results as g(
      school_id, assessment_id, student_id, score, mark, feedback, state,
      reviewed_by, reviewed_at, version)
    select a.school_id, a.id, e.student_id, e.score, e.mark, e.feedback,
      (case when e.mark is null then 'draft' else 'reviewed' end)::public.publication_state,
      case when e.mark is not null then auth.uid() end,
      case when e.mark is not null then now() end, 1
    from private.gradebook_entries(v_entries) e
    on conflict (assessment_id, student_id) do update set
      score = excluded.score, mark = excluded.mark, feedback = excluded.feedback,
      state = excluded.state, reviewed_by = excluded.reviewed_by,
      reviewed_at = excluded.reviewed_at, version = g.version + 1
    -- An unchanged row keeps its version, so a resave of the same sheet does
    -- not make the next save conflict.
    where (g.mark, g.score, g.feedback, g.state)
      is distinct from (excluded.mark, excluded.score, excluded.feedback, excluded.state)
    returning g.id, g.student_id, g.state, g.version, g.mark, g.feedback
  ), logged as (
    -- Marking an online student absent, or clearing it, is kept in the
    -- grade's history: who, when, from what, to what.
    insert into public.grade_result_events(
      school_id, grade_result_id, actor_id, event_type, previous_state,
      next_state, idempotency_key, previous_mark, previous_feedback,
      next_mark, next_feedback, material)
    select a.school_id, s.id, auth.uid(), 'reviewed',
      (v_before->s.student_id::text->>'state')::public.publication_state,
      s.state, v_key || ':' || s.id::text,
      (v_before->s.student_id::text->>'mark')::public.grade_mark,
      v_before->s.student_id::text->>'feedback', s.mark, s.feedback, false
    from saved s where a.delivery <> 'paper'
  )
  select count(*), coalesce(jsonb_agg(jsonb_build_object('id', s.id,
      'studentId', s.student_id, 'state', s.state, 'version', s.version)
      order by s.student_id), '[]'::jsonb)
  into v_saved, v_grades from saved s;

  update public.assessments set gradebook_version = gradebook_version + 1
  where id = a.id returning gradebook_version into v_version;

  return private.coursework_finish(
    p_idempotency_id, p_idempotency_generation, 200, 'grades_saved',
    'assessment', a.id, null,
    jsonb_build_object('operation', 'saveGradeDrafts', 'saved', v_saved,
      'gradebookVersion', v_version),
    jsonb_build_object('gradebookVersion', v_version, 'saved', v_saved,
      'grades', v_grades));
end;
$function$;

-- ---------------------------------------------------------------------------
-- 2. A student's grade from their attempts. Copied from 202610070004; an
--    unpublished absence the student has now handed in for is replaced, and
--    that is recorded.
-- ---------------------------------------------------------------------------

create or replace function private.assessment_sync_grade(p_assessment uuid, p_student uuid)
returns void language plpgsql security definer set search_path = '' as $$
declare
  a public.assessments%rowtype;
  r record;
  v_prev public.grade_results%rowtype;
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
  select * into v_prev from public.grade_results g
  where g.assessment_id = a.id and g.student_id = p_student;

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
    and (g.score, g.state, g.feedback, g.mark) is distinct from
      (v_score, v_state, r.feedback,
       case when v_score is null then null else 'scored'::public.grade_mark end);

  if v_prev.mark = 'absent' and v_prev.state in ('draft', 'reviewed') then
    insert into public.grade_result_events(
      school_id, grade_result_id, actor_id, event_type, previous_state,
      next_state, reason, idempotency_key, previous_mark, previous_feedback,
      next_mark, next_score, material)
    values (a.school_id, v_prev.id, auth.uid(), 'reviewed', v_prev.state, v_state,
      'Handed in after being marked absent',
      'absence-replaced:' || v_prev.id::text || ':' || v_prev.version::text,
      'absent', v_prev.feedback,
      case when v_score is null then null else 'scored'::public.grade_mark end,
      v_score, false);
  end if;
  update public.assessments set gradebook_version = gradebook_version + 1 where id = a.id;
end;
$$;

-- ---------------------------------------------------------------------------
-- 3. Marking: copied from 202610070004. A published grade is corrected, with
--    a reason, only when its mark or score changes; a feedback-only change is
--    applied without one and kept in the history.
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
  v_outcome text := 'unchanged';
  v_changed jsonb;
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

  -- Which answers actually change, for the audit record.
  select coalesce(jsonb_agg(jsonb_build_object('questionId', aa.question_id,
      'score', (m->>'score')::numeric <> coalesce(aa.awarded_score, -1),
      'comment', nullif(btrim(m->>'feedback'), '') is distinct from aa.feedback)), '[]'::jsonb)
  into v_changed
  from jsonb_array_elements(body->'marks') m
  join public.assessment_answers aa
    on aa.attempt_id = t.id and aa.question_id = (m->>'questionId')::uuid
  where (aa.awarded_score, aa.feedback) is distinct from
    ((m->>'score')::numeric, nullif(btrim(m->>'feedback'), ''));

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
    -- What the family already sees changes only as below.
    select * into r from private.assessment_counting_result(a.id, t.student_id);
    if not r.pending and r.score is not null
       and (private.grade_mark_of(g.mark, g.score), g.score)
         is distinct from ('scored', r.score) then
      -- The mark itself: a correction, with a reason, announced.
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
      v_outcome := 'corrected';
    elsif not r.pending and r.score is not null
       and nullif(btrim(g.feedback), '') is distinct from r.feedback then
      -- The feedback alone: no reason asked, nothing announced, and the
      -- text it replaced kept.
      update public.grade_results set feedback = r.feedback,
        version = version + 1, updated_at = now()
      where id = g.id;
      insert into public.grade_result_events(
        school_id, grade_result_id, actor_id, event_type, previous_state,
        next_state, reason, idempotency_key, previous_mark, previous_score,
        previous_feedback, next_mark, next_score, next_feedback, material)
      values (a.school_id, g.id, auth.uid(), 'corrected', 'published', 'published',
        v_reason, v_key || ':' || g.id::text,
        private.grade_mark_of(g.mark, g.score)::public.grade_mark, g.score, g.feedback,
        private.grade_mark_of(g.mark, g.score)::public.grade_mark, g.score, r.feedback, false);
      update public.assessments set gradebook_version = gradebook_version + 1 where id = a.id;
      v_outcome := 'feedback_updated';
    end if;
  else
    perform private.assessment_sync_grade(a.id, t.student_id);
  end if;

  return private.coursework_finish(p_idempotency_id, p_idempotency_generation, 200,
    'assessment_attempt_marked', 'assessment_attempt', t.id, null,
    jsonb_build_object('marks', jsonb_array_length(body->'marks'),
      'changedAnswers', v_changed,
      'feedbackChanged', body ? 'feedback',
      'grade', v_outcome),
    private.assessment_attempt_json(t.id, 'staff'));
exception when sqlstate 'SF047' then
  return jsonb_build_object('outcome', sqlerrm);
end;
$$;

-- ---------------------------------------------------------------------------
-- 4. The staff read of an attempt also says how its grade is marked, so the
--    marking screen can tell a published absence from a published score.
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
      'gradeState', g.state,
      'gradeMark', private.grade_mark_of(g.mark, g.score))
      else '{}'::jsonb end
  from public.assessment_attempts t
  join public.students st on st.id = t.student_id
  left join public.grade_results g
    on g.assessment_id = t.assessment_id and g.student_id = t.student_id
  where t.id = p_attempt;
$$;

do $grants$
declare
  f text;
begin
  foreach f in array array[
    'private.api041_save_grade_drafts(uuid,jsonb,uuid,bigint)',
    'private.assessment_sync_grade(uuid,uuid)',
    'private.api041_mark_assessment_attempt(uuid,jsonb,uuid,bigint)',
    'private.assessment_attempt_json(uuid,text)'
  ] loop
    execute format('alter function %s owner to postgres', f);
    execute format('revoke all on function %s from public, anon, authenticated, service_role, studafy_api_runtime, studafy_worker_runtime', f);
  end loop;
end;
$grants$;
