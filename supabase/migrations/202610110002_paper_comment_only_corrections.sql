-- Paper marks: a comment-only correction needs no reason (2026-10-11,
-- launch plan 2.6).
--
-- Online marking stopped asking for a reason when only the feedback changes
-- (202610070006), but the paper grade sheet still refused any correction to
-- a published mark without one - the check ran before looking at what
-- changed. The reason is now required only when some entry's mark or score
-- changes. A comment-only edit is still applied atomically, kept in the
-- grade's history (material = false, reason null) and not announced.
-- Everything else is unchanged from the current definition
-- (202609300001_paper_gradebook.sql). Same signature and owner, so the
-- existing EXECUTE grants stay.

create or replace function private.gradebook_apply_corrections(
  a public.assessments, p_entries jsonb, p_reason text, p_key text)
returns jsonb language plpgsql security definer set search_path = '' as $function$
declare
  v_errors jsonb;
  v_conflicts int;
  v_changed int;
  v_material uuid[];
  v_grades jsonb;
begin
  if (select count(*) <> count(distinct e.grade_id) or bool_or(e.grade_id is null)
      from private.gradebook_entries(p_entries) e) then
    return jsonb_build_object('outcome', 'invalid');
  end if;

  perform 1 from public.grade_results g
  where g.id in (select e.grade_id from private.gradebook_entries(p_entries) e)
  order by g.id for update;

  select coalesce(jsonb_agg(jsonb_build_object('gradeResultId', x.grade_id,
      'studentId', x.student_id, 'reason', x.reason) order by x.grade_id), '[]'::jsonb),
    count(*) filter (where x.reason = 'version_conflict')
  into v_errors, v_conflicts
  from (
    select c.grade_id, g.student_id, case
      when g.id is null or g.assessment_id <> a.id then 'not_found'
      when g.state <> 'published' then 'not_published'
      when g.version <> c.expected_version then 'version_conflict'
      when c.mark = 'scored' and c.score is null then 'score_required'
      when c.mark = 'scored' and (c.score < 0 or c.score > a.maximum_score)
        then 'score_out_of_range'
      when c.mark <> 'scored' and c.score is not null then 'score_not_allowed'
    end as reason
    from (select e.grade_id, e.expected_version, coalesce(e.mark, 'scored') as mark,
        e.score from private.gradebook_entries(p_entries) e) c
    left join public.grade_results g on g.id = c.grade_id
  ) x
  where x.reason is not null;

  if jsonb_array_length(v_errors) > 0 then
    return jsonb_build_object(
      'outcome', case when v_conflicts > 0 then 'version_conflict'
        else 'grade_entries_invalid' end,
      'rows', v_errors);
  end if;

  -- A reason is needed only when a mark or score changes. A comment-only
  -- edit is applied without one, recorded as not material and not
  -- announced - as online marking does since 202610070006.
  if (nullif(btrim(p_reason), '') is null or length(btrim(p_reason)) < 3)
     and exists (
       select 1 from private.gradebook_entries(p_entries) e
       join public.grade_results g on g.id = e.grade_id
       where (private.grade_mark_of(g.mark, g.score)::public.grade_mark, g.score)
         is distinct from (coalesce(e.mark, 'scored'), e.score)) then
    return jsonb_build_object('outcome', 'reason_required');
  end if;

  with previous as (
    select g.id, private.grade_mark_of(g.mark, g.score)::public.grade_mark as mark,
      g.score, g.feedback
    from public.grade_results g
    where g.id in (select e.grade_id from private.gradebook_entries(p_entries) e)
  ), changed as (
    update public.grade_results g set mark = c.mark, score = c.score,
      feedback = c.feedback, reviewed_by = auth.uid(), reviewed_at = now(),
      version = g.version + 1
    from (select e.grade_id, coalesce(e.mark, 'scored') as mark, e.score, e.feedback
        from private.gradebook_entries(p_entries) e) c
    join previous p on p.id = c.grade_id
    where g.id = c.grade_id
      and (p.mark, p.score, p.feedback) is distinct from (c.mark, c.score, c.feedback)
    returning g.id, g.student_id, g.version, p.mark as previous_mark,
      p.score as previous_score, p.feedback as previous_feedback,
      c.mark as next_mark, c.score as next_score, c.feedback as next_feedback,
      (p.mark, p.score) is distinct from (c.mark, c.score) as material
  ), logged as (
    insert into public.grade_result_events(
      school_id, grade_result_id, actor_id, event_type, previous_state,
      next_state, reason, idempotency_key, previous_mark, previous_score,
      previous_feedback, next_mark, next_score, next_feedback, material)
    select a.school_id, c.id, auth.uid(), 'corrected', 'published', 'published',
      nullif(btrim(p_reason), ''), p_key || ':' || c.id::text, c.previous_mark,
      c.previous_score, c.previous_feedback, c.next_mark, c.next_score,
      c.next_feedback, c.material
    from changed c
    returning grade_result_id
  )
  select count(*),
    coalesce(array_agg(c.id) filter (where c.material), array[]::uuid[]),
    coalesce(jsonb_agg(jsonb_build_object('id', c.id, 'studentId', c.student_id,
      'state', 'published', 'version', c.version) order by c.student_id), '[]'::jsonb)
  into v_changed, v_material, v_grades
  from changed c
  where c.id in (select grade_result_id from logged);

  if cardinality(v_material) > 0 then
    insert into public.notification_outbox(
      school_id, source_event_id, idempotency_key, channel, template_key,
      audience, payload)
    values (a.school_id, a.id::text, p_key, 'in_app', 'academic.grades_corrected',
      jsonb_build_object('gradeResultIds', to_jsonb(v_material)),
      jsonb_build_object('entityId', a.id));
  end if;

  return jsonb_build_object('outcome', 'ok', 'corrected', v_changed,
    'notified', cardinality(v_material), 'grades', v_grades);
end;
$function$;
