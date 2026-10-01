-- Paper gradebook: marks for work done on paper, entered for a whole class
-- at once, kept private until the teacher publishes them, and corrected with
-- a recorded reason and the value it replaced.
--
-- Many schools set exams and homework on paper. Until now a mark could only
-- be entered through the online grading path, one call per student, with no
-- way to say a student was absent, and a correction overwrote the score with
-- nothing left to show what it had been. This migration adds:
--
--   * grade_results.mark - scored, absent or not_graded. A missing mark is
--     never a zero: an unmarked row stays a draft and is never published.
--   * assessments.gradebook_version - bumped by every gradebook write, and
--     demanded by publish, so a teacher publishes exactly what they saw.
--   * previous/next values on grade_result_events, which is already
--     append-only, so every publication and correction keeps who changed a
--     mark, when, from what, to what, and why.
--   * set-based handlers for the class gradebook (read, bulk save, publish,
--     bulk correct). Each is one statement per step inside one transaction,
--     locking the assessment row and the grade rows it touches - never the
--     table - and writing a single outbox row per operation, so the worker
--     fans out notifications after the request has returned.
--   * private.authz_coursework, the one authorization owner for every action
--     this and the three migrations after it add (ADR-0030), and the two
--     teacher-only tests it uses. This release has no school administrator:
--     nobody but a class's own teachers reads or changes its coursework.
--
-- A paper gradebook item is an assessment with delivery 'paper': the class
-- already fixes the school, the term and the subject.

create type public.grade_mark as enum ('scored', 'absent', 'not_graded');

alter table public.grade_results add column if not exists mark public.grade_mark;
alter table public.assessments
  add column if not exists gradebook_version bigint not null default 0;

-- A null mark on a row with a score is a mark entered before marks existed:
-- it reads as 'scored', so no row needs rewriting. Absent and not-graded
-- carry no score; any other non-draft row needs one.
alter table public.grade_results drop constraint if exists api041_grade_scored_state_check;
alter table public.grade_results add constraint grade_results_mark_check check (
  (mark is null or mark = 'scored' or score is null)
  and (state = 'draft' or (
    reviewed_by is not null and reviewed_at is not null
    and (score is not null or mark in ('absent', 'not_graded'))))
) not valid;
alter table public.grade_results validate constraint grade_results_mark_check;

alter table public.grade_result_events
  add column if not exists previous_mark public.grade_mark,
  add column if not exists previous_score numeric(8,2),
  add column if not exists previous_feedback text,
  add column if not exists next_mark public.grade_mark,
  add column if not exists next_score numeric(8,2),
  add column if not exists next_feedback text,
  -- Whether the mark itself changed. A comment-only edit is recorded but is
  -- not announced to the family.
  add column if not exists material boolean;

-- ---------------------------------------------------------------------------
-- Shared command plumbing.
-- ---------------------------------------------------------------------------

-- The idempotency key of the caller's reserved request, or null when the
-- call is not one this request may make. Every command below starts here,
-- as the academic base command does.
create or replace function private.coursework_idempotency_key(
  p_idempotency_id uuid, p_idempotency_generation bigint)
returns text
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_tenant uuid := nullif(current_setting('studafy.school_id', true), '')::uuid;
  v_key text;
begin
  if auth.uid() is null or v_tenant is null
     or nullif(current_setting('studafy.request_id', true), '') is null then
    return null;
  end if;
  select r.idempotency_key into v_key from public.idempotency_records r
  where r.id = p_idempotency_id and r.actor_id = auth.uid()
    and r.school_id = v_tenant and r.generation = p_idempotency_generation
    and r.status = 'reserved'
  for update;
  if v_key is null or not private.has_active_membership(v_tenant) then
    return null;
  end if;
  return v_key;
end;
$$;

-- Records the audit row, completes the idempotency record and answers ok.
create or replace function private.coursework_finish(
  p_idempotency_id uuid, p_idempotency_generation bigint, p_status int,
  p_action text, p_entity_type text, p_entity_id uuid, p_before jsonb,
  p_after jsonb, p_response jsonb)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
begin
  insert into public.audit_events(
    school_id, actor_id, action, entity_type, entity_id, before_value,
    after_value, request_id)
  values (
    nullif(current_setting('studafy.school_id', true), '')::uuid, auth.uid(),
    p_action, p_entity_type, p_entity_id, p_before, p_after,
    nullif(current_setting('studafy.request_id', true), ''));
  if not private.api_idempotency_complete(
      p_idempotency_id, p_idempotency_generation, p_status, p_response) then
    raise exception 'COURSEWORK_IDEMPOTENCY_COMPLETION_FAILED';
  end if;
  return jsonb_build_object('outcome', 'ok', 'response', p_response);
end;
$$;

-- ---------------------------------------------------------------------------
-- Who may touch a class's coursework: its own teachers, and nobody else.
-- ---------------------------------------------------------------------------

-- A lead or co-teacher of a class that is not archived, through a live
-- teacher membership. Deliberately not api041_class_writer, which also
-- admits a school administrator; this release has none.
create or replace function private.coursework_teacher(p_classroom uuid)
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select auth.uid() is not null and exists (
    select 1
    from public.classroom_staff cs
    join public.classrooms c on c.id = cs.classroom_id and c.archived_at is null
    join public.memberships m
      on m.id = cs.membership_id and m.school_id = cs.school_id
     and m.user_id = cs.user_id
    where cs.classroom_id = p_classroom and cs.user_id = auth.uid()
      and cs.status = 'active' and cs.role in ('lead_teacher', 'co_teacher')
      and m.role = 'teacher' and m.active and m.status = 'active'
      and (m.valid_from is null or m.valid_from <= now())
      and (m.valid_until is null or m.valid_until > now()));
$$;

-- Any of the class's staff - lead, co-teacher or assistant - through a live
-- teacher membership: who may read the class's gradebook and history.
create or replace function private.coursework_staff(p_classroom uuid)
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select auth.uid() is not null and exists (
    select 1
    from public.classroom_staff cs
    join public.memberships m
      on m.id = cs.membership_id and m.school_id = cs.school_id
     and m.user_id = cs.user_id
    where cs.classroom_id = p_classroom and cs.user_id = auth.uid()
      and cs.status = 'active'
      and m.role = 'teacher' and m.active and m.status = 'active'
      and (m.valid_from is null or m.valid_from <= now())
      and (m.valid_until is null or m.valid_until > now()));
$$;

-- ---------------------------------------------------------------------------
-- Read models.
-- ---------------------------------------------------------------------------

create or replace function private.grade_mark_of(p_mark public.grade_mark, p_score numeric)
returns text
language sql
immutable
set search_path = ''
as $$
  select coalesce(p_mark::text, case when p_score is not null then 'scored' end);
$$;

create or replace function private.api041_grade_json(p_id uuid)
returns jsonb
language sql
stable
security definer
set search_path = ''
as $$
  select jsonb_build_object('id',g.id,'assessmentId',g.assessment_id,'studentId',g.student_id,
    'assessmentTitle',a.title,'category',a.category,
    'score',g.score,'maximumScore',a.maximum_score,'feedback',g.feedback,'state',g.state,
    'version',g.version,'reviewedAt',g.reviewed_at,'publishedAt',g.published_at,
    -- Paper work is labelled as such for students and families, and kept
    -- apart from marks for work handed in online.
    'delivery',a.delivery,'mark',private.grade_mark_of(g.mark,g.score),
    'weight',a.category_weight,'assignmentId',a.assignment_id)
  from public.grade_results g join public.assessments a on a.id=g.assessment_id where g.id=p_id;
$$;

create or replace function private.api041_assessment_json(p_id uuid)
returns jsonb
language sql
stable
security definer
set search_path = ''
as $$
  select jsonb_build_object('id',a.id,'classroomId',a.classroom_id,'title',a.title,
    'category',a.category,'maximumScore',a.maximum_score,'scheduledAt',a.scheduled_at,
    'delivery',a.delivery,'state',a.state,'version',a.version,
    'attachments',private.file_attachment_json(p_assessment => a.id),
    'assignmentId',a.assignment_id,'weight',a.category_weight)
  from public.assessments a where a.id=p_id;
$$;

-- One grade row as the gradebook shows it to staff.
create or replace function private.gradebook_grade_json(g public.grade_results)
returns jsonb
language sql
stable
security definer
set search_path = ''
as $$
  select case when g.id is null then null else jsonb_build_object(
    'id', g.id, 'mark', private.grade_mark_of(g.mark, g.score),
    'score', g.score, 'feedback', g.feedback, 'state', g.state,
    'version', g.version, 'reviewedAt', g.reviewed_at,
    'publishedAt', g.published_at, 'updatedAt', g.updated_at,
    'corrections', (select count(*) from public.grade_result_events e
      where e.grade_result_id = g.id and e.event_type = 'corrected'))
  end;
$$;

-- The whole class for one gradebook item: everyone actively enrolled, plus
-- anyone who has left but already has a mark, which must stay correctable.
-- One statement, keyset-paged by student id.
create or replace function private.api041_gradebook(p_assessment uuid, p_input jsonb)
returns jsonb
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  v_tenant uuid := nullif(current_setting('studafy.school_id', true), '')::uuid;
  v_limit int := least(greatest(coalesce((p_input->>'pageSize')::int, 50), 1), 100);
  v_pos uuid := nullif(p_input->>'position', '')::uuid;
  a public.assessments%rowtype;
  v_items jsonb;
  v_next text;
  v_count int;
begin
  select * into a from public.assessments x
  where x.id = p_assessment and x.deleted_at is null;
  if a.id is null or a.school_id is distinct from v_tenant
     or not private.coursework_staff(a.classroom_id) then
    return jsonb_build_object('outcome', 'not_found');
  end if;

  select coalesce(jsonb_agg(jsonb_build_object(
      'student', jsonb_build_object('id', r.id, 'displayName', r.display_name,
        'studafyId', r.studafy_id),
      'enrolled', r.enrolled,
      'grade', private.gradebook_grade_json(r.g)) order by r.id), '[]'::jsonb),
    max(r.id::text), count(*)
  into v_items, v_next, v_count
  from (
    select st.id, st.display_name, st.studafy_id,
      exists (select 1 from public.enrollments e
        where e.classroom_id = a.classroom_id and e.student_id = st.id
          and e.active and e.status = 'active') as enrolled,
      g
    from (
      select e.student_id from public.enrollments e
      where e.classroom_id = a.classroom_id and e.active and e.status = 'active'
        and (v_pos is null or e.student_id > v_pos)
      union
      select gr.student_id from public.grade_results gr
      where gr.assessment_id = a.id and (v_pos is null or gr.student_id > v_pos)
    ) ids
    join public.students st on st.id = ids.student_id and st.deleted_at is null
    left join public.grade_results g on g.assessment_id = a.id and g.student_id = st.id
    order by st.id
    limit v_limit
  ) r;

  return jsonb_build_object(
    'item', private.api041_assessment_json(a.id) || jsonb_build_object(
      'gradebookVersion', a.gradebook_version,
      'counts', (select jsonb_build_object(
          'unmarked', count(*) filter (where g.state = 'draft'),
          'ready', count(*) filter (where g.state = 'reviewed'),
          'published', count(*) filter (where g.state = 'published'),
          'withdrawn', count(*) filter (where g.state = 'withdrawn'))
        from public.grade_results g where g.assessment_id = a.id)),
    'items', v_items,
    'nextPosition', case when v_count = v_limit then v_next end);
end;
$$;

-- Every publication and correction of one mark, newest first.
create or replace function private.api041_grade_history(p_grade uuid, p_input jsonb)
returns jsonb
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  v_tenant uuid := nullif(current_setting('studafy.school_id', true), '')::uuid;
  v_limit int := least(greatest(coalesce((p_input->>'pageSize')::int, 50), 1), 100);
  v_pos bigint := nullif(p_input->>'position', '')::bigint;
  v_class uuid;
  v_school uuid;
  v_items jsonb;
  v_next text;
  v_count int;
begin
  select a.classroom_id, g.school_id into v_class, v_school
  from public.grade_results g join public.assessments a on a.id = g.assessment_id
  where g.id = p_grade;
  if v_class is null or v_school is distinct from v_tenant
     or not private.coursework_staff(v_class) then
    return jsonb_build_object('outcome', 'not_found');
  end if;

  select coalesce(jsonb_agg(jsonb_build_object(
      'id', x.id::text, 'change', x.event_type,
      'previousState', x.previous_state, 'nextState', x.next_state,
      'previousMark', x.previous_mark, 'previousScore', x.previous_score,
      'previousFeedback', x.previous_feedback,
      'nextMark', x.next_mark, 'nextScore', x.next_score,
      'nextFeedback', x.next_feedback, 'reason', x.reason,
      'actor', case when x.actor_id is null then null else jsonb_build_object(
        'id', x.actor_id, 'displayName', x.display_name) end,
      'createdAt', x.created_at) order by x.id desc), '[]'::jsonb),
    min(x.id)::text, count(*)
  into v_items, v_next, v_count
  from (
    select e.*, p.display_name
    from public.grade_result_events e
    left join public.profiles p on p.id = e.actor_id
    where e.grade_result_id = p_grade and (v_pos is null or e.id < v_pos)
    order by e.id desc
    limit v_limit
  ) x;

  return jsonb_build_object('items', v_items,
    'nextPosition', case when v_count = v_limit then v_next end);
end;
$$;

-- ---------------------------------------------------------------------------
-- Commands.
-- ---------------------------------------------------------------------------

-- Locks the gradebook item a command writes, and answers who may write it.
-- Null when the caller may: otherwise the refusal.
create or replace function private.gradebook_refusal(a public.assessments)
returns text
language sql
stable
security definer
set search_path = ''
as $$
  select case
    when a.id is null then 'not_found'
    when a.school_id is distinct from
        nullif(current_setting('studafy.school_id', true), '')::uuid
      or not private.coursework_teacher(a.classroom_id)
      then 'forbidden'
  end;
$$;

-- The entries of a bulk request, one row each. Plain rows rather than a
-- temporary table: under load, a temporary table per request is catalog
-- churn every other query pays for.
create or replace function private.gradebook_entries(p_entries jsonb)
returns table(student_id uuid, grade_id uuid, expected_version bigint,
  mark public.grade_mark, score numeric, feedback text)
language sql
stable
set search_path = ''
as $$
  select e."studentId", e."gradeResultId", e."expectedVersion",
    e.mark::public.grade_mark, e.score, nullif(btrim(e.feedback), '')
  from jsonb_to_recordset(coalesce(p_entries, '[]'::jsonb)) as e(
    "studentId" uuid, "gradeResultId" uuid, "expectedVersion" bigint,
    mark text, score numeric, feedback text);
$$;

-- Saves marks as drafts. A marked row is ready to publish; a cleared row goes
-- back to unmarked. Nothing here is visible to a student or a family.
create or replace function private.api041_save_grade_drafts(
  p_assessment uuid, p_input jsonb, p_idempotency_id uuid,
  p_idempotency_generation bigint)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
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
begin
  v_key := private.coursework_idempotency_key(p_idempotency_id, p_idempotency_generation);
  if v_key is null then return jsonb_build_object('outcome', 'forbidden'); end if;
  select * into a from public.assessments x
  where x.id = p_assessment and x.deleted_at is null for update;
  v_outcome := private.gradebook_refusal(a);
  if v_outcome is not null then return jsonb_build_object('outcome', v_outcome); end if;
  -- Online work is marked from what was handed in; this table is for paper.
  if a.delivery <> 'paper' then return jsonb_build_object('outcome', 'invalid_state'); end if;
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
    returning g.id, g.student_id, g.state, g.version
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
$$;

-- Publishes every mark that is ready, all at once or not at all. Unmarked
-- rows stay drafts: a missing mark is never released as a zero.
create or replace function private.api041_publish_grades(
  p_assessment uuid, p_input jsonb, p_idempotency_id uuid,
  p_idempotency_generation bigint)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  body jsonb := coalesce(p_input->'body', '{}'::jsonb);
  v_key text;
  a public.assessments;
  v_outcome text;
  v_ids uuid[];
  v_version bigint;
  v_unmarked int;
begin
  v_key := private.coursework_idempotency_key(p_idempotency_id, p_idempotency_generation);
  if v_key is null then return jsonb_build_object('outcome', 'forbidden'); end if;
  select * into a from public.assessments x
  where x.id = p_assessment and x.deleted_at is null for update;
  v_outcome := private.gradebook_refusal(a);
  if v_outcome is not null then return jsonb_build_object('outcome', v_outcome); end if;
  if (body->>'expectedGradebookVersion')::bigint is distinct from a.gradebook_version then
    return jsonb_build_object('outcome', 'version_conflict');
  end if;

  perform 1 from public.grade_results g
  where g.assessment_id = a.id and g.state = 'reviewed' order by g.id for update;

  with published as (
    update public.grade_results g set state = 'published',
      published_by = auth.uid(), published_at = now(), version = g.version + 1
    where g.assessment_id = a.id and g.state = 'reviewed'
    returning g.id, g.mark, g.score, g.feedback
  ), logged as (
    insert into public.grade_result_events(
      school_id, grade_result_id, actor_id, event_type, previous_state,
      next_state, idempotency_key, next_mark, next_score, next_feedback, material)
    select a.school_id, p.id, auth.uid(), 'published', 'reviewed', 'published',
      v_key || ':' || p.id::text, coalesce(p.mark, 'scored'), p.score,
      p.feedback, true
    from published p
    returning grade_result_id
  )
  select coalesce(array_agg(grade_result_id), array[]::uuid[]) into v_ids from logged;

  if cardinality(v_ids) = 0 then
    return jsonb_build_object('outcome', 'invalid_state');
  end if;

  -- A paper item recorded after the fact is not an upcoming exam: it becomes
  -- visible with its marks, and nobody is told about it separately.
  update public.assessments set
    state = case when state = 'draft' then 'published'::public.publication_state else state end,
    published_at = coalesce(published_at, now()),
    version = case when state = 'draft' then version + 1 else version end,
    gradebook_version = gradebook_version + 1
  where id = a.id returning gradebook_version into v_version;

  select count(*) into v_unmarked from public.grade_results g
  where g.assessment_id = a.id and g.state = 'draft';

  -- One outbox row for the whole release; the worker resolves the students
  -- and their verified guardians after this transaction commits.
  insert into public.notification_outbox(
    school_id, source_event_id, idempotency_key, channel, template_key,
    audience, payload)
  values (a.school_id, a.id::text, v_key, 'in_app', 'academic.grades_published',
    jsonb_build_object('gradeResultIds', to_jsonb(v_ids)),
    jsonb_build_object('entityId', a.id));

  return private.coursework_finish(
    p_idempotency_id, p_idempotency_generation, 200, 'grades_published',
    'assessment', a.id, null,
    jsonb_build_object('operation', 'publishGrades',
      'published', cardinality(v_ids), 'gradebookVersion', v_version),
    jsonb_build_object('gradebookVersion', v_version,
      'published', cardinality(v_ids), 'unmarked', v_unmarked));
end;
$$;

-- Corrects published marks. Each change keeps the value it replaced, the
-- reason and who made it; families hear about changes to the mark itself.
create or replace function private.gradebook_apply_corrections(
  a public.assessments, p_entries jsonb, p_reason text, p_key text)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_errors jsonb;
  v_conflicts int;
  v_changed int;
  v_material uuid[];
  v_grades jsonb;
begin
  if nullif(btrim(p_reason), '') is null or length(btrim(p_reason)) < 3 then
    return jsonb_build_object('outcome', 'reason_required');
  end if;

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
      btrim(p_reason), p_key || ':' || c.id::text, c.previous_mark,
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
$$;

create or replace function private.api041_correct_grades(
  p_assessment uuid, p_input jsonb, p_idempotency_id uuid,
  p_idempotency_generation bigint)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  body jsonb := coalesce(p_input->'body', '{}'::jsonb);
  v_key text;
  a public.assessments;
  v_outcome text;
  v_result jsonb;
  v_version bigint;
begin
  v_key := private.coursework_idempotency_key(p_idempotency_id, p_idempotency_generation);
  if v_key is null then return jsonb_build_object('outcome', 'forbidden'); end if;
  select * into a from public.assessments x
  where x.id = p_assessment and x.deleted_at is null for update;
  v_outcome := private.gradebook_refusal(a);
  if v_outcome is not null then return jsonb_build_object('outcome', v_outcome); end if;

  v_result := private.gradebook_apply_corrections(
    a, body->'entries', body->>'reason', v_key);
  if v_result->>'outcome' <> 'ok' then return v_result; end if;

  update public.assessments set gradebook_version = gradebook_version + 1
  where id = a.id returning gradebook_version into v_version;

  return private.coursework_finish(
    p_idempotency_id, p_idempotency_generation, 200, 'grades_corrected',
    'assessment', a.id, null,
    jsonb_build_object('operation', 'correctGrades',
      'corrected', v_result->'corrected', 'gradebookVersion', v_version),
    jsonb_build_object('gradebookVersion', v_version,
      'corrected', v_result->'corrected', 'notified', v_result->'notified',
      'grades', v_result->'grades'));
end;
$$;

-- The single-grade correction route, now through the same path, so it too
-- keeps the value it replaced. Request and response are unchanged.
create or replace function private.api041_correct_grade_result(
  p_grade uuid, p_input jsonb, p_idempotency_id uuid,
  p_idempotency_generation bigint)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  body jsonb := coalesce(p_input->'body', '{}'::jsonb);
  v_key text;
  a public.assessments;
  v_outcome text;
  v_result jsonb;
  v_assessment uuid;
  v_response jsonb;
begin
  v_key := private.coursework_idempotency_key(p_idempotency_id, p_idempotency_generation);
  if v_key is null then return jsonb_build_object('outcome', 'forbidden'); end if;
  select g.assessment_id into v_assessment from public.grade_results g where g.id = p_grade;
  if v_assessment is null then return jsonb_build_object('outcome', 'not_found'); end if;
  select * into a from public.assessments x
  where x.id = v_assessment and x.deleted_at is null for update;
  v_outcome := private.gradebook_refusal(a);
  if v_outcome is not null then return jsonb_build_object('outcome', v_outcome); end if;

  v_result := private.gradebook_apply_corrections(a,
    jsonb_build_array(jsonb_build_object('gradeResultId', p_grade,
      'expectedVersion', body->'expectedVersion', 'mark', 'scored',
      'score', body->'score', 'feedback', body->'feedback')),
    body->>'reason', v_key);
  if v_result->>'outcome' in ('grade_entries_invalid', 'reason_required') then
    return jsonb_build_object('outcome', case
      when v_result->'rows'->0->>'reason' = 'not_published' then 'invalid_state'
      else 'invalid' end);
  end if;
  if v_result->>'outcome' <> 'ok' then return v_result - 'rows'; end if;

  update public.assessments set gradebook_version = gradebook_version + 1
  where id = a.id;
  v_response := private.api041_grade_json(p_grade);
  return private.coursework_finish(
    p_idempotency_id, p_idempotency_generation, 200, 'grade_corrected',
    'grade_result', p_grade, null,
    jsonb_build_object('operation', 'correctGradeResult',
      'version', v_response->'version', 'state', v_response->'state'),
    v_response);
end;
$$;

-- Title, category, out-of, weight and date of a paper gradebook item.
create or replace function private.api041_update_gradebook_item(
  p_assessment uuid, p_input jsonb, p_idempotency_id uuid,
  p_idempotency_generation bigint)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  body jsonb := coalesce(p_input->'body', '{}'::jsonb);
  v_key text;
  a public.assessments;
  v_outcome text;
  v_max numeric := (body->>'maximumScore')::numeric;
  v_response jsonb;
begin
  v_key := private.coursework_idempotency_key(p_idempotency_id, p_idempotency_generation);
  if v_key is null then return jsonb_build_object('outcome', 'forbidden'); end if;
  select * into a from public.assessments x
  where x.id = p_assessment and x.deleted_at is null for update;
  v_outcome := private.gradebook_refusal(a);
  if v_outcome is not null then return jsonb_build_object('outcome', v_outcome); end if;
  if a.delivery <> 'paper'
     or exists (select 1 from public.assessment_questions q where q.assessment_id = a.id) then
    return jsonb_build_object('outcome', 'invalid_state');
  end if;
  if a.version <> (body->>'expectedVersion')::bigint then
    return jsonb_build_object('outcome', 'version_conflict');
  end if;
  -- Lowering what the work is out of below a mark already given would leave
  -- that mark impossible.
  if exists (select 1 from public.grade_results g
      where g.assessment_id = a.id and g.score > v_max) then
    return jsonb_build_object('outcome', 'grade_entries_invalid', 'rows',
      (select jsonb_agg(jsonb_build_object('studentId', g.student_id,
          'reason', 'score_out_of_range'))
       from public.grade_results g where g.assessment_id = a.id and g.score > v_max));
  end if;

  update public.assessments set title = btrim(body->>'title'),
    category = btrim(body->>'category'), maximum_score = v_max,
    category_weight = nullif(body->>'weight', '')::numeric,
    scheduled_at = nullif(body->>'scheduledAt', '')::timestamptz,
    version = version + 1, gradebook_version = gradebook_version + 1
  where id = a.id;

  v_response := private.api041_assessment_json(a.id);
  return private.coursework_finish(
    p_idempotency_id, p_idempotency_generation, 200, 'assessment_updated',
    'assessment', a.id, to_jsonb(a),
    jsonb_build_object('operation', 'updateGradebookItem',
      'version', v_response->'version'),
    v_response);
end;
$$;

-- ---------------------------------------------------------------------------
-- Authorization for every coursework action added from here on.
-- ---------------------------------------------------------------------------

create or replace function private.authz_coursework(p_action text, p_resource_id uuid)
returns jsonb
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  target_school uuid;
  permitted boolean := false;
begin
  if auth.uid() is null or p_resource_id is null then
    return jsonb_build_object('allowed', false, 'school_id', null, 'reason', 'invalid_resource');
  end if;

  case
    -- Reading a class gradebook: any of the class's staff.
    when p_action = 'gradebook.read' then
      select a.school_id, private.coursework_staff(a.classroom_id)
      into target_school, permitted
      from public.assessments a where a.id = p_resource_id and a.deleted_at is null;
    -- Entering, publishing and correcting marks: the class's lead and
    -- co-teachers. An assistant may read, not mark.
    when p_action in ('gradebook.write', 'gradebook.publish', 'gradebook.correct',
                      'assessment.update') then
      select a.school_id, private.coursework_teacher(a.classroom_id)
      into target_school, permitted
      from public.assessments a where a.id = p_resource_id and a.deleted_at is null;
    when p_action = 'grade_result.history' then
      select g.school_id, private.coursework_staff(a.classroom_id)
      into target_school, permitted
      from public.grade_results g join public.assessments a on a.id = g.assessment_id
      where g.id = p_resource_id;
    -- Attendance for one lesson. The school's lock policy is enforced by the
    -- command, since it depends on the reason and override in the request.
    when p_action = 'attendance_session.correct' then
      select ls.school_id, private.coursework_teacher(ls.classroom_id)
      into target_school, permitted
      from public.lesson_sessions ls where ls.id = p_resource_id;
    when p_action = 'attendance_session.history' then
      select ls.school_id, private.coursework_staff(ls.classroom_id)
      into target_school, permitted
      from public.lesson_sessions ls where ls.id = p_resource_id;
    -- Deadlines of a piece of work.
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
    -- Editing a lesson: whoever made it, or the class's lead or
    -- co-teachers.
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

create or replace function private.authz_authorize(p_action text, p_resource_id uuid)
returns jsonb
language plpgsql
stable
security definer
set search_path = ''
as $function$
declare
  decision jsonb;
begin
  -- Decided outright, above both guardian rules below.
  if p_action in ('notebook.read', 'notebook.write', 'notebook_entry.delete', 'study_set.generate') then
    return private.authz_notebook(p_action, p_resource_id);
  end if;
  if p_action = 'conversation.mark_read' then
    return private.authz_conversation_read(p_action, p_resource_id);
  end if;
  -- Staff-only coursework actions: no guardian rule applies to any of them.
  if p_action in ('gradebook.read', 'gradebook.write', 'gradebook.publish',
      'gradebook.correct', 'assessment.update', 'grade_result.history',
      'attendance_session.correct', 'attendance_session.history',
      'assignment.extend', 'assignment.reopen', 'assignment.materials',
      'assessment.materials', 'resource.edit') then
    return private.authz_coursework(p_action, p_resource_id);
  end if;

  if p_action = 'submission.history' then
    decision := private.authz_submission_history(p_action, p_resource_id);
  else
    -- Each action has one owner; the first match is the newest rule for it.
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
    -- A guardian hands work in for a child with no device of their own.
    decision := private.authz_guardian_submits(p_action, p_resource_id, decision);
  end if;

  -- A verified guardian reads their child's lists and starts uploads for
  -- them, even with no membership of their own.
  return private.authz_guardian_list_reads(p_action, p_resource_id, decision);
end;
$function$;

-- ---------------------------------------------------------------------------
-- Dispatch (ADR-0030: named handlers first, each owning its operation).
-- ---------------------------------------------------------------------------

create or replace function private.api041_command(p_operation text, p_resource_id uuid, p_input jsonb, p_idempotency_id uuid, p_idempotency_generation bigint)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $function$
declare
  v_assignment uuid := nullif((p_input->'body')->>'assignmentId', '')::uuid;
  v_class uuid := nullif((p_input->'body')->>'classroomId', '')::uuid;
  result jsonb;
  v_assessment uuid;
  v_response jsonb;
begin
  -- Named handlers first (ADR-0030): each owns its operation outright.
  case p_operation
    when 'archiveClassroom' then
      return private.api041_archive_classroom(
        p_resource_id, p_input, p_idempotency_id, p_idempotency_generation);
    when 'saveGradeDrafts' then
      return private.api041_save_grade_drafts(
        p_resource_id, p_input, p_idempotency_id, p_idempotency_generation);
    when 'publishGrades' then
      return private.api041_publish_grades(
        p_resource_id, p_input, p_idempotency_id, p_idempotency_generation);
    when 'correctGrades' then
      return private.api041_correct_grades(
        p_resource_id, p_input, p_idempotency_id, p_idempotency_generation);
    when 'correctGradeResult' then
      return private.api041_correct_grade_result(
        p_resource_id, p_input, p_idempotency_id, p_idempotency_generation);
    when 'updateGradebookItem' then
      return private.api041_update_gradebook_item(
        p_resource_id, p_input, p_idempotency_id, p_idempotency_generation);
    else null;
  end case;

  if p_operation <> 'createAssessment' then
    return private.api041_command_pre_graded(
      p_operation, p_resource_id, p_input, p_idempotency_id,
      p_idempotency_generation);
  end if;

  if v_assignment is not null then
    -- The work must be in the class the mark is being created for, and not
    -- already have one. The delegate checks the caller may write that class.
    if not exists (
      select 1 from public.assignments a
      where a.id = v_assignment and a.classroom_id = v_class and a.deleted_at is null
    ) then
      return jsonb_build_object('outcome', 'invalid');
    end if;
    if exists (select 1 from public.assessments g
        where g.assignment_id = v_assignment and g.deleted_at is null) then
      return jsonb_build_object('outcome', 'invalid');
    end if;
  end if;

  result := private.api041_command_pre_graded(
    p_operation, p_resource_id, p_input, p_idempotency_id,
    p_idempotency_generation);
  if coalesce(result->>'outcome', '') <> 'ok' then return result; end if;
  if v_assignment is null and (p_input->'body'->'weight') is null then
    return result;
  end if;

  v_assessment := ((result->'response')->>'id')::uuid;
  update public.assessments set
    assignment_id = coalesce(v_assignment, assignment_id),
    -- How much the category counts, when the school weighs categories.
    category_weight = nullif((p_input->'body')->>'weight', '')::numeric
  where id = v_assessment;

  v_response := private.api041_assessment_json(v_assessment);
  update public.idempotency_records r
  set response_body = v_response
  where r.id = p_idempotency_id and r.actor_id = auth.uid()
    and r.generation = p_idempotency_generation and r.status = 'completed';
  return jsonb_set(result, array['response'], v_response);
exception when invalid_text_representation then
  return jsonb_build_object('outcome', 'invalid');
end;
$function$;

create or replace function private.api041_query(p_operation text, p_resource_id uuid, p_input jsonb)
returns jsonb
language plpgsql
stable
security definer
set search_path = ''
as $function$
declare
  result jsonb;
begin
  -- Named handlers first (ADR-0030).
  case p_operation
    when 'listGradebook' then return private.api041_gradebook(p_resource_id, p_input);
    when 'listGradeHistory' then return private.api041_grade_history(p_resource_id, p_input);
    else null;
  end case;

  result := private.api041_query_pre_roster_shape(p_operation, p_resource_id, p_input);
  if p_operation <> 'listAttendanceRoster' or result is null
    or jsonb_typeof(result->'items') <> 'array' then
    return result;
  end if;
  return jsonb_set(result, array['items'], (
    select coalesce(jsonb_agg(item - 'id' order by ordinality), '[]'::jsonb)
    from jsonb_array_elements(result->'items') with ordinality as t(item, ordinality)
  ));
end;
$function$;

-- ---------------------------------------------------------------------------
-- Notifications: one outbox row per release or correction names the marks;
-- only the students they belong to and those students' verified guardians
-- are told, never the whole class and never the staff who made the change.
-- ---------------------------------------------------------------------------

create or replace function private.api061_notification_recipients(p_school uuid, p_template text, p_source text, p_audience jsonb)
 RETURNS uuid[]
 LANGUAGE plpgsql
 STABLE SECURITY DEFINER
 SET search_path TO ''
AS $function$
declare
  v_classroom uuid;
  v_source uuid;
  v_staff uuid[] := array[]::uuid[];
  v_family uuid[] := array[]::uuid[];
  v_students uuid[] := array[]::uuid[];
  -- Whether the child themselves hears about it, separately from their
  -- guardians. Almost always yes; a pastoral note shared with home is the
  -- exception the school explicitly asked for.
  v_tell_student boolean := true;
begin
  -- source_event_id is text, and not every producer writes a uuid into it.
  -- Casting it unconditionally raised inside the dispatcher, which fails the
  -- job rather than the row and eventually poisons the queue for everyone,
  -- so anything that is not a uuid is simply "no entity" here.
  if p_source ~ ('^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}'
                 || '-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$') then
    v_source := p_source::uuid;
  end if;

  -- The staff audience, unchanged from what this function has always done.
  -- Every existing template keeps exactly the recipients it had.
  if p_audience->>'classroomId' is not null then
    v_classroom := nullif(p_audience->>'classroomId', '')::uuid;
    if v_classroom is null then return null; end if;
    select coalesce(array_agg(m.user_id), array[]::uuid[]) into v_staff
    from public.memberships m
    join public.classroom_staff cs
      on cs.school_id = m.school_id and cs.user_id = m.user_id
    join public.profiles p on p.id = m.user_id and p.status = 'active'
    where m.school_id = p_school and m.active and m.status = 'active'
      and cs.classroom_id = v_classroom and cs.status = 'active'
      and cs.role in ('lead_teacher', 'co_teacher', 'assistant');
  elsif p_audience->>'schoolId' is not null
        and nullif(p_audience->>'schoolId', '')::uuid = p_school then
    select coalesce(array_agg(m.user_id), array[]::uuid[]) into v_staff
    from public.memberships m
    join public.profiles p on p.id = m.user_id and p.status = 'active'
    where m.school_id = p_school and m.active and m.status = 'active'
      and m.role in ('school_admin', 'teacher');
  elsif p_audience ? 'gradeResultIds' then
    -- Marks released or corrected in one go: nobody on the staff side.
    v_staff := array[]::uuid[];
  else
    return null;
  end if;

  -- A guardian link concerns two named people, not a class. The requesting
  -- guardian is not verified yet, so they are read from the link row itself
  -- rather than through the verified-guardian join used everywhere else.
  -- Both sides are told about all three events: the student is the one who
  -- decides on a request, and the guardian is the one a verification or a
  -- revocation is about.
  if p_template like 'family.guardian_link_%' then
    select coalesce(array_agg(distinct x.user_id), array[]::uuid[])
      into v_family
    from (
      select gl.guardian_id as user_id
      from public.guardian_links gl
      where gl.id = v_source and gl.school_id = p_school
      union
      select s.user_id
      from public.guardian_links gl
      join public.students s
        on s.id = gl.student_id and s.deleted_at is null
      where gl.id = v_source and gl.school_id = p_school
        and s.user_id is not null
    ) x
    join public.profiles p on p.id = x.user_id and p.status = 'active';
    return (
      select coalesce(array_agg(distinct u), array[]::uuid[])
      from unnest(v_staff || v_family) as t(u)
    );
  end if;

  -- Which children the event is about. Left empty for every template that
  -- concerns staff alone, which is why those are untouched by this.
  if p_template in ('academic.assignment_published',
                    'academic.assessment_published',
                    'academic.resource_published')
  then
    -- Set for the whole class, so the whole class hears about it.
    select coalesce(array_agg(e.student_id), array[]::uuid[]) into v_students
    from public.enrollments e
    where e.school_id = p_school and e.classroom_id = v_classroom
      and e.active and e.status = 'active'
      and e.starts_on <= current_date
      and (e.ends_on is null or e.ends_on >= current_date);
  elsif p_template = 'academic.grade_published' then
    -- One child's mark. Announcing it to the class would be both noise and
    -- a statement about somebody else's child.
    select coalesce(array_agg(g.student_id), array[]::uuid[]) into v_students
    from public.grade_results g
    where g.id = v_source and g.school_id = p_school
      and g.state = 'published';
  elsif p_template in ('academic.grades_published', 'academic.grades_corrected') then
    -- Only marks that are still published, of this piece of work, named by
    -- the event: a mark withdrawn since is not announced.
    select coalesce(array_agg(g.student_id), array[]::uuid[]) into v_students
    from public.grade_results g
    where g.assessment_id = v_source and g.school_id = p_school
      and g.state = 'published'
      and g.id in (
        select x::uuid from jsonb_array_elements_text(
          coalesce(p_audience->'gradeResultIds', '[]'::jsonb)) x);
  elsif p_template = 'academic.wellbeing_shared' then
    -- Re-read the visibility here rather than trusting the template name:
    -- if a note has since been restricted, this must not announce it. A
    -- safeguarding-restricted note matches nothing and reaches no family.
    select coalesce(array_agg(w.student_id), array[]::uuid[]),
           bool_or(w.visibility = 'student_guardian_shared')
      into v_students, v_tell_student
    from public.wellbeing_events w
    where w.id = v_source and w.school_id = p_school
      and w.visibility in ('guardian_shared', 'student_guardian_shared');
    v_tell_student := coalesce(v_tell_student, false);
  end if;

  if cardinality(v_students) = 0 then
    return (
      select coalesce(array_agg(distinct u), array[]::uuid[])
      from unnest(v_staff) as t(u)
    );
  end if;

  select coalesce(array_agg(distinct x.user_id), array[]::uuid[])
    into v_family
  from (
    select s.user_id
    from public.students s
    where v_tell_student and s.id = any(v_students)
      and s.deleted_at is null and s.user_id is not null
    union
    -- An expired or revoked link is not a link. This is the same test the
    -- read paths use, so nobody is notified about a child whose record they
    -- could no longer open.
    select gl.guardian_id
    from public.guardian_links gl
    where gl.student_id = any(v_students) and gl.school_id = p_school
      and gl.status = 'verified'
      and (gl.expires_at is null or gl.expires_at > now())
  ) x
  join public.profiles p on p.id = x.user_id and p.status = 'active';

  return (
    select coalesce(array_agg(distinct u), array[]::uuid[])
    from unnest(v_staff || v_family) as t(u)
  );
end;
$function$;

-- ---------------------------------------------------------------------------
-- Grants: every function here is reached only through the dispatchers.
-- ---------------------------------------------------------------------------

do $grants$
declare
  f text;
begin
  foreach f in array array[
    'private.coursework_idempotency_key(uuid,bigint)',
    'private.coursework_finish(uuid,bigint,integer,text,text,uuid,jsonb,jsonb,jsonb)',
    'private.grade_mark_of(public.grade_mark,numeric)',
    'private.api041_grade_json(uuid)',
    'private.api041_assessment_json(uuid)',
    'private.gradebook_grade_json(public.grade_results)',
    'private.api041_gradebook(uuid,jsonb)',
    'private.api041_grade_history(uuid,jsonb)',
    'private.gradebook_refusal(public.assessments)',
    'private.gradebook_entries(jsonb)',
    'private.api041_save_grade_drafts(uuid,jsonb,uuid,bigint)',
    'private.api041_publish_grades(uuid,jsonb,uuid,bigint)',
    'private.gradebook_apply_corrections(public.assessments,jsonb,text,text)',
    'private.api041_correct_grades(uuid,jsonb,uuid,bigint)',
    'private.api041_correct_grade_result(uuid,jsonb,uuid,bigint)',
    'private.api041_update_gradebook_item(uuid,jsonb,uuid,bigint)',
    'private.authz_coursework(text,uuid)',
    'private.coursework_teacher(uuid)',
    'private.coursework_staff(uuid)'
  ] loop
    execute format('alter function %s owner to postgres', f);
    execute format('revoke all on function %s from public, anon, authenticated, service_role, studafy_api_runtime, studafy_worker_runtime', f);
  end loop;
end;
$grants$;
