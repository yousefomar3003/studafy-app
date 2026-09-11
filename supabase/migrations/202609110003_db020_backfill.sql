-- DB-020 backfill step. This migration never guesses across conflicting
-- tenants. Ambiguous or inconsistent legacy rows abort with aggregate counts.

update public.schools set
  status = coalesce(status, 'active'),
  locale = coalesce(locale, 'en'),
  updated_at = coalesce(updated_at, created_at);

update public.profiles set
  status = coalesce(status, 'active'),
  updated_at = coalesce(updated_at, created_at);

update public.memberships set
  status = coalesce(
    status,
    case
      when active then 'active'::public.membership_status
      else 'suspended'::public.membership_status
    end
  ),
  valid_from = coalesce(valid_from, created_at),
  version = coalesce(version, 1),
  updated_at = coalesce(updated_at, created_at);

update public.terms set
  status = coalesce(
    status,
    case
      when active then 'active'::public.term_status
      when ends_on < current_date then 'closed'::public.term_status
      else 'planned'::public.term_status
    end
  ),
  updated_at = coalesce(updated_at, now());

-- A nullable legacy student tenant can be derived only when all enrolled
-- classrooms agree on exactly one school.
with enrollment_school as (
  select
    e.student_id,
    min(c.school_id::text)::uuid as school_id
  from public.enrollments e
  join public.classrooms c on c.id = e.classroom_id
  group by e.student_id
  having count(distinct c.school_id) = 1
)
update public.students s
set school_id = es.school_id
from enrollment_school es
where s.id = es.student_id and s.school_id is null;

-- If no enrollment exists, a creator with exactly one active school
-- membership is an unambiguous fallback.
with creator_school as (
  select
    user_id,
    min(school_id::text)::uuid as school_id
  from public.memberships
  where active
  group by user_id
  having count(distinct school_id) = 1
)
update public.students s
set school_id = cs.school_id
from creator_school cs
where s.created_by = cs.user_id and s.school_id is null;

do $db020$
declare
  unresolved bigint;
begin
  select count(*) into unresolved from public.students where school_id is null;
  if unresolved > 0 then
    raise exception 'DB-020 stopped: % student rows have ambiguous or missing tenant ownership', unresolved;
  end if;
end
$db020$;

update public.students set
  updated_at = coalesce(updated_at, created_at);

update public.guardian_links g set
  school_id = s.school_id,
  updated_at = coalesce(g.updated_at, now())
from public.students s
where s.id = g.student_id;

update public.classrooms set
  status = coalesce(
    status,
    case
      when archived_at is null then 'active'::public.classroom_status
      else 'archived'::public.classroom_status
    end
  ),
  created_at = coalesce(created_at, now()),
  updated_at = coalesce(updated_at, created_at, now());

update public.enrollments e set
  school_id = c.school_id,
  status = coalesce(
    e.status,
    case
      when e.active then 'active'::public.enrollment_status
      else 'withdrawn'::public.enrollment_status
    end
  ),
  starts_on = coalesce(e.starts_on, current_date),
  created_at = coalesce(e.created_at, now()),
  updated_at = coalesce(e.updated_at, e.created_at, now())
from public.classrooms c
where c.id = e.classroom_id;

update public.lesson_sessions s set
  school_id = c.school_id,
  status = coalesce(
    s.status,
    case
      when filed_at is null then 'scheduled'::public.lesson_session_status
      else 'completed'::public.lesson_session_status
    end
  ),
  created_at = coalesce(s.created_at, now()),
  updated_at = coalesce(s.updated_at, s.created_at, now())
from public.classrooms c
where c.id = s.classroom_id;

update public.lesson_materials m set
  school_id = s.school_id,
  updated_at = coalesce(m.updated_at, m.created_at)
from public.lesson_sessions s
where s.id = m.session_id;

update public.assignments a set
  school_id = c.school_id,
  version = coalesce(a.version, 1),
  created_at = coalesce(a.created_at, a.published_at, now()),
  updated_at = coalesce(a.updated_at, a.created_at, a.published_at, now())
from public.classrooms c
where c.id = a.classroom_id;

update public.submissions s set
  school_id = a.school_id,
  status = coalesce(
    s.status,
    case
      when s.excused then 'excused'::public.submission_status
      when s.submitted_at is not null then 'submitted'::public.submission_status
      else 'open'::public.submission_status
    end
  ),
  version = coalesce(s.version, 1),
  created_at = coalesce(s.created_at, s.submitted_at, now()),
  updated_at = coalesce(s.updated_at, s.submitted_at, s.created_at, now())
from public.assignments a
where a.id = s.assignment_id;

update public.assessments a set
  school_id = c.school_id,
  version = coalesce(a.version, 1),
  created_at = coalesce(a.created_at, a.published_at, a.scheduled_at, now()),
  updated_at = coalesce(a.updated_at, a.created_at, a.published_at, a.scheduled_at, now())
from public.classrooms c
where c.id = a.classroom_id;

update public.assessment_questions q set
  school_id = a.school_id,
  created_at = coalesce(q.created_at, now()),
  updated_at = coalesce(q.updated_at, q.created_at, now())
from public.assessments a
where a.id = q.assessment_id;

update public.grade_results g set
  school_id = a.school_id,
  version = coalesce(g.version, 1),
  published_by = case
    when g.state = 'published' then coalesce(g.published_by, g.reviewed_by)
    else g.published_by
  end,
  created_at = coalesce(g.created_at, g.reviewed_at, g.published_at, now()),
  updated_at = coalesce(g.updated_at, g.published_at, g.reviewed_at, g.created_at, now())
from public.assessments a
where a.id = g.assessment_id;

update public.attendance_records r set
  school_id = s.school_id,
  updated_at = coalesce(r.updated_at, r.recorded_at)
from public.lesson_sessions s
where s.id = r.session_id;

update public.wellbeing_events e set
  school_id = s.school_id,
  visibility = coalesce(visibility, 'class_staff'),
  severity = coalesce(severity, 'low'),
  status = coalesce(status, 'open'),
  updated_at = coalesce(e.updated_at, e.created_at)
from public.students s
where s.id = e.student_id;

update public.announcements set
  state = coalesce(state, 'published'),
  updated_at = coalesce(updated_at, published_at);

update public.meetings m set
  school_id = c.school_id,
  updated_at = coalesce(m.updated_at, m.created_at)
from public.classrooms c
where c.id = m.classroom_id;

update public.meeting_deliveries d set
  school_id = m.school_id,
  attempt_count = coalesce(d.attempt_count, case when d.state = 'queued' then 0 else 1 end),
  error_code = coalesce(d.error_code, case when d.error is null then null else 'provider_error' end),
  created_at = coalesce(d.created_at, d.delivered_at, now()),
  updated_at = coalesce(d.updated_at, d.delivered_at, d.created_at, now())
from public.meetings m
where m.id = d.meeting_id;

-- Notifications may be platform-scoped. Infer a school only for a recipient
-- with exactly one active membership; otherwise leave school_id null.
with recipient_school as (
  select
    user_id,
    min(school_id::text)::uuid as school_id
  from public.memberships
  where active
  group by user_id
  having count(distinct school_id) = 1
)
update public.notifications n set
  school_id = coalesce(n.school_id, rs.school_id),
  updated_at = coalesce(n.updated_at, n.created_at)
from recipient_school rs
where rs.user_id = n.user_id;

update public.notifications set updated_at = coalesce(updated_at, created_at);

update public.ai_grading_drafts d set
  school_id = g.school_id,
  version = coalesce(d.version, 1),
  updated_at = coalesce(d.updated_at, d.created_at)
from public.grade_results g
where g.id = d.grade_result_id;

update public.question_suggestions s set
  school_id = d.school_id,
  created_at = coalesce(s.created_at, d.created_at, now())
from public.ai_grading_drafts d
where d.id = s.draft_id;

update public.subscription_entitlements set updated_at = coalesce(updated_at, verified_at);

update public.practice_sessions p set
  school_id = s.school_id,
  updated_at = coalesce(p.updated_at, p.completed_at, p.created_at)
from public.students s
where s.id = p.student_id;

update public.consent_records set updated_at = coalesce(updated_at, withdrawn_at, accepted_at);

update public.account_deletion_requests set
  version = coalesce(version, 1),
  updated_at = coalesce(updated_at, completed_at, requested_at);

-- Preserve the legacy single-teacher field while establishing the canonical
-- co-teaching assignment model. Never manufacture a missing membership.
do $db020$
declare
  missing_memberships bigint;
begin
  select count(*) into missing_memberships
  from public.classrooms c
  where not exists (
    select 1
    from public.memberships m
    where m.school_id = c.school_id
      and m.user_id = c.teacher_id
      and m.active
      and m.role in ('teacher', 'school_admin')
  );
  if missing_memberships > 0 then
    raise exception 'DB-020 stopped: % classroom teachers lack an active same-school membership', missing_memberships;
  end if;
end
$db020$;

insert into public.classroom_staff (
  school_id, classroom_id, membership_id, user_id, role, status, starts_at
)
select
  c.school_id,
  c.id,
  chosen.id,
  c.teacher_id,
  'lead_teacher',
  'active',
  c.created_at
from public.classrooms c
cross join lateral (
  select m.id
  from public.memberships m
  where m.school_id = c.school_id
    and m.user_id = c.teacher_id
    and m.active
    and m.role in ('teacher', 'school_admin')
  order by case when m.role = 'teacher' then 0 else 1 end, m.created_at, m.id
  limit 1
) chosen
where not exists (
  select 1 from public.classroom_staff cs
  where cs.classroom_id = c.id
    and cs.user_id = c.teacher_id
    and cs.role = 'lead_teacher'
    and cs.status = 'active'
);

-- One aggregate-only preflight catches missing and cross-tenant graph edges.
do $db020$
declare
  null_tenants bigint;
  mismatched_edges bigint;
begin
  select sum(row_count) into null_tenants from (
    select count(*) row_count from public.guardian_links where school_id is null
    union all select count(*) from public.enrollments where school_id is null
    union all select count(*) from public.lesson_sessions where school_id is null
    union all select count(*) from public.lesson_materials where school_id is null
    union all select count(*) from public.assignments where school_id is null
    union all select count(*) from public.submissions where school_id is null
    union all select count(*) from public.assessments where school_id is null
    union all select count(*) from public.assessment_questions where school_id is null
    union all select count(*) from public.grade_results where school_id is null
    union all select count(*) from public.attendance_records where school_id is null
    union all select count(*) from public.wellbeing_events where school_id is null
    union all select count(*) from public.meetings where school_id is null
    union all select count(*) from public.meeting_deliveries where school_id is null
    union all select count(*) from public.notifications where school_id is null
    union all select count(*) from public.ai_grading_drafts where school_id is null
    union all select count(*) from public.question_suggestions where school_id is null
    union all select count(*) from public.practice_sessions where school_id is null
  ) counts;

  select sum(row_count) into mismatched_edges from (
    select count(*) row_count
    from public.classrooms c join public.terms t on t.id = c.term_id
    where c.school_id <> t.school_id
    union all
    select count(*) from public.enrollments e
      join public.classrooms c on c.id = e.classroom_id
      join public.students s on s.id = e.student_id
      where e.school_id <> c.school_id or e.school_id <> s.school_id
    union all
    select count(*) from public.submissions s
      join public.assignments a on a.id = s.assignment_id
      join public.students st on st.id = s.student_id
      where s.school_id <> a.school_id or s.school_id <> st.school_id
    union all
    select count(*) from public.grade_results g
      join public.assessments a on a.id = g.assessment_id
      join public.students s on s.id = g.student_id
      where g.school_id <> a.school_id or g.school_id <> s.school_id
    union all
    select count(*) from public.attendance_records r
      join public.lesson_sessions s on s.id = r.session_id
      join public.students st on st.id = r.student_id
      where r.school_id <> s.school_id or r.school_id <> st.school_id
    union all
    select count(*) from public.practice_sessions p
      join public.classrooms c on c.id = p.classroom_id
      join public.students s on s.id = p.student_id
      where p.school_id <> c.school_id or p.school_id <> s.school_id
  ) counts;

  if null_tenants > 0 or mismatched_edges > 0 then
    raise exception 'DB-020 stopped: % missing tenant values and % cross-tenant edges', null_tenants, mismatched_edges;
  end if;
end
$db020$;
