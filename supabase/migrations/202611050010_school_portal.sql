-- Studafy School Portal, step 1: the database (docs/planning/school-portal.md,
-- sections 3, 7.3 and 7.4; owner's decisions of 2026-11-05 in section 14).
--
-- A school's page (an "org") has up to three administrators. An
-- administrator asks a teacher to link by the teacher's Studafy ID; the
-- teacher accepts or declines in the app, and can unlink at any time. While
-- linked, the org's administrators can READ every class the teacher teaches
-- (including classes created later): roster with emails, Studafy IDs and
-- linked parents, lessons and files, announcements, hand-ins, test answers,
-- every mark (published or not, and AI-suggested ones), daily attendance and
-- wellbeing notes. Nothing here writes to a class.
--
-- Never readable through the portal: messages, AI Tutor material, students'
-- own notebooks, notes, flashcards and quizzes. No function below reads
-- those tables.
--
-- The administrator is NOT a school member: no memberships row, so no
-- existing staff check (coursework_teacher, coursework_staff,
-- is_school_admin, api041_class_writer) ever admits them. Every read goes
-- through private.school_portal_class_visible, checked at the moment of the
-- read, and writes one row to the activity record.
--
-- A teacher's Studafy ID is the account's own public number
-- (profiles.public_id, 202610010003), which the app already shows as the
-- person's Studafy ID. Until now no endpoint found anyone by it; the portal
-- is the first, and it finds only teacher accounts, counted per
-- administrator (10 lookups an hour).
--
-- One school at a time: a teacher has at most one linked org.
-- Everything is in schema private, RLS on with no policies, owned by
-- postgres; the API reaches it only through api062_query / api062_command.

-- ---------------------------------------------------------------------------
-- 1. Tables.
-- ---------------------------------------------------------------------------

create table private.school_portal_orgs (
  id uuid primary key default gen_random_uuid(),
  name text not null check (char_length(btrim(name)) between 2 and 120),
  country text not null check (char_length(btrim(country)) between 2 and 80),
  city text not null check (char_length(btrim(city)) between 1 and 80),
  kind text not null check (kind in ('public', 'private', 'international', 'other')),
  contact_email text check (contact_email is null or (
    char_length(contact_email) <= 254 and contact_email ~ '^[^@\s]+@[^@\s]+\.[^@\s]+$')),
  status text not null default 'active' check (status in ('active', 'suspended', 'closed')),
  created_by uuid references public.profiles(id) on delete set null,
  suspended_by uuid references public.profiles(id) on delete set null,
  suspended_at timestamptz,
  suspended_reason text check (suspended_reason is null or char_length(suspended_reason) <= 500),
  closed_at timestamptz,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  check ((status = 'closed') = (closed_at is not null))
);
create index school_portal_orgs_created_by_idx
  on private.school_portal_orgs (created_by, created_at);

create table private.school_portal_admins (
  id uuid primary key default gen_random_uuid(),
  org_id uuid not null references private.school_portal_orgs(id) on delete cascade,
  user_id uuid not null references public.profiles(id) on delete cascade,
  job_title text not null check (char_length(btrim(job_title)) between 2 and 80),
  added_by uuid references public.profiles(id) on delete set null,
  added_at timestamptz not null default now(),
  removed_at timestamptz,
  removed_by uuid references public.profiles(id) on delete set null
);
create unique index school_portal_admins_live_idx
  on private.school_portal_admins (org_id, user_id) where removed_at is null;
create index school_portal_admins_user_idx
  on private.school_portal_admins (user_id) where removed_at is null;

create table private.school_portal_admin_invites (
  id uuid primary key default gen_random_uuid(),
  org_id uuid not null references private.school_portal_orgs(id) on delete cascade,
  email text not null check (email = lower(email) and char_length(email) <= 254
    and email ~ '^[^@\s]+@[^@\s]+\.[^@\s]+$'),
  job_title text not null check (char_length(btrim(job_title)) between 2 and 80),
  invited_by uuid references public.profiles(id) on delete set null,
  created_at timestamptz not null default now(),
  expires_at timestamptz not null default now() + interval '7 days',
  accepted_at timestamptz,
  accepted_by uuid references public.profiles(id) on delete set null,
  revoked_at timestamptz
);
create unique index school_portal_admin_invites_live_idx
  on private.school_portal_admin_invites (org_id, email)
  where accepted_at is null and revoked_at is null;
create index school_portal_admin_invites_email_idx
  on private.school_portal_admin_invites (email)
  where accepted_at is null and revoked_at is null;

create table private.school_portal_teacher_links (
  id uuid primary key default gen_random_uuid(),
  org_id uuid not null references private.school_portal_orgs(id) on delete cascade,
  teacher_id uuid not null references public.profiles(id) on delete cascade,
  requested_by uuid references public.profiles(id) on delete set null,
  status text not null default 'pending' check (status in
    ('pending', 'linked', 'declined', 'cancelled', 'expired', 'unlinked')),
  requested_at timestamptz not null default now(),
  decided_at timestamptz,
  ended_at timestamptz,
  ended_by uuid references public.profiles(id) on delete set null
);
-- One live request or link per (org, teacher), and one school at a time.
create unique index school_portal_teacher_links_live_idx
  on private.school_portal_teacher_links (org_id, teacher_id)
  where status in ('pending', 'linked');
create unique index school_portal_teacher_links_one_school_idx
  on private.school_portal_teacher_links (teacher_id) where status = 'linked';
create index school_portal_teacher_links_org_idx
  on private.school_portal_teacher_links (org_id, status, requested_at);
create index school_portal_teacher_links_teacher_idx
  on private.school_portal_teacher_links (teacher_id, status);

create table private.school_portal_reports (
  id uuid primary key default gen_random_uuid(),
  org_id uuid not null references private.school_portal_orgs(id) on delete cascade,
  link_id uuid references private.school_portal_teacher_links(id) on delete set null,
  reported_by uuid not null references public.profiles(id) on delete cascade,
  reason text not null check (reason in ('not_my_school', 'fake_school', 'pressure', 'other')),
  details text check (details is null or char_length(details) <= 1000),
  created_at timestamptz not null default now(),
  handled_at timestamptz,
  handled_by uuid references public.profiles(id) on delete set null
);
create index school_portal_reports_open_idx
  on private.school_portal_reports (created_at) where handled_at is null;

-- The activity record: every portal read, kept 12 months (TODO(legal)).
create table private.school_portal_views (
  id bigint generated always as identity primary key,
  admin_id uuid not null references public.profiles(id) on delete cascade,
  org_id uuid not null references private.school_portal_orgs(id) on delete cascade,
  classroom_id uuid,
  student_id uuid,
  file_id uuid,
  item_id uuid,
  -- For an export (plan 13a.5): what was exported, and as what.
  export_kind text check (export_kind is null or export_kind in
    ('students', 'marks', 'attendance', 'reports', 'class')),
  export_format text check (export_format is null or export_format in ('csv', 'pdf')),
  view text not null check (view in ('dashboard', 'teachers', 'classes', 'roster',
    'lessons', 'file', 'assignments', 'hand_ins', 'tests', 'test_answers', 'marks',
    'attendance', 'wellbeing', 'overview', 'student', 'teacher', 'reports', 'export')),
  at timestamptz not null default now()
);
create index school_portal_views_org_idx on private.school_portal_views (org_id, at);
create index school_portal_views_at_idx on private.school_portal_views (at);

-- Studafy ID lookups by administrators, for the hourly limit.
create table private.school_portal_lookups (
  id bigint generated always as identity primary key,
  admin_id uuid not null references public.profiles(id) on delete cascade,
  org_id uuid not null references private.school_portal_orgs(id) on delete cascade,
  found boolean not null,
  at timestamptz not null default now()
);
create index school_portal_lookups_admin_idx on private.school_portal_lookups (admin_id, at);

do $tables$
declare t text;
begin
  foreach t in array array['school_portal_orgs', 'school_portal_admins',
    'school_portal_admin_invites', 'school_portal_teacher_links', 'school_portal_reports',
    'school_portal_views', 'school_portal_lookups'] loop
    execute format('alter table private.%I enable row level security', t);
    execute format('alter table private.%I force row level security', t);
    execute format('revoke all on private.%I from public, anon, authenticated, '
      'service_role, studafy_api_runtime, studafy_worker_runtime', t);
  end loop;
end
$tables$;

-- ---------------------------------------------------------------------------
-- 2. Who may see what.
-- ---------------------------------------------------------------------------

-- The caller is a live administrator of an active org.
create or replace function private.school_portal_admin_ok(p_org uuid)
returns boolean language sql stable security definer set search_path = '' as $$
  select auth.uid() is not null and private.is_active_user() and exists (
    select 1 from private.school_portal_admins a
    join private.school_portal_orgs o on o.id = a.org_id and o.status = 'active'
    where a.org_id = p_org and a.user_id = auth.uid() and a.removed_at is null);
$$;

-- The classes an org may read right now: every class that is not archived
-- and has a lead or co-teacher, through a live teacher membership, whose
-- link with the org is 'linked'. Checked at the moment of each read, so an
-- unlink hides everything at once.
create or replace function private.school_portal_visible_classes(p_org uuid)
returns setof uuid language sql stable security definer set search_path = '' as $$
  select distinct cs.classroom_id
  from private.school_portal_teacher_links l
  join public.profiles p on p.id = l.teacher_id and p.status = 'active'
  join public.classroom_staff cs on cs.user_id = l.teacher_id
   and cs.status = 'active' and cs.role in ('lead_teacher', 'co_teacher')
  join public.classrooms c on c.id = cs.classroom_id and c.archived_at is null
  join public.memberships m
    on m.id = cs.membership_id and m.school_id = cs.school_id and m.user_id = cs.user_id
  where l.org_id = p_org and l.status = 'linked'
    and m.role = 'teacher' and m.active and m.status = 'active'
    and (m.valid_from is null or m.valid_from <= now())
    and (m.valid_until is null or m.valid_until > now());
$$;

create or replace function private.school_portal_class_visible(p_org uuid, p_classroom uuid)
returns boolean language sql stable security definer set search_path = '' as $$
  select p_classroom is not null and exists (
    select 1 from private.school_portal_visible_classes(p_org) v(id) where v.id = p_classroom);
$$;

-- A request still waiting after 14 days counts as expired.
create or replace function private.school_portal_link_status(
  p_status text, p_requested_at timestamptz)
returns text language sql immutable set search_path = '' as $$
  select case when p_status = 'pending' and p_requested_at <= now() - interval '14 days'
    then 'expired' else p_status end;
$$;

-- A teacher account found by its Studafy ID, or null. Only teachers: an
-- active profile with a live teacher membership. Never a student or child.
create or replace function private.school_portal_find_teacher(p_public_id text)
returns uuid language sql stable security definer set search_path = '' as $$
  select p.id from public.profiles p
  where p_public_id ~ '^[1-9][0-9]{9}$' and p.public_id = p_public_id
    and p.status = 'active' and private.account_kind(p.id) = 'adult'
    and exists (select 1 from public.memberships m
      where m.user_id = p.id and m.role = 'teacher' and m.active and m.status = 'active'
        and (m.valid_until is null or m.valid_until > now()));
$$;

create or replace function private.school_portal_person(p_user uuid)
returns jsonb language sql stable security definer set search_path = '' as $$
  select case when p_user is null then null else jsonb_build_object(
    'id', p.id, 'name', p.display_name,
    'email', (select u.email from auth.users u where u.id = p.id)) end
  from public.profiles p where p.id = p_user;
$$;

create or replace function private.school_portal_log(
  p_org uuid, p_view text, p_classroom uuid default null,
  p_student uuid default null, p_file uuid default null, p_item uuid default null)
returns void language sql security definer set search_path = '' as $$
  insert into private.school_portal_views(admin_id, org_id, classroom_id, student_id, file_id, item_id, view)
  values (auth.uid(), p_org, p_classroom, p_student, p_file, p_item, p_view);
$$;

-- The files bound to one target, as the portal shows them (open through
-- the delivery route only; this lists, never serves).
create or replace function private.school_portal_files(p_bindings uuid[])
returns jsonb language sql stable security definer set search_path = '' as $$
  select coalesce(jsonb_agg(jsonb_build_object(
    'fileId', f.id, 'name', f.display_name, 'sizeBytes', f.size_bytes,
    'mediaType', coalesce(f.detected_media_type, f.declared_media_type),
    'scanState', f.scan_state) order by f.display_name), '[]'::jsonb)
  from public.file_objects f
  where f.id = any(p_bindings) and f.deleted_at is null;
$$;

-- ---------------------------------------------------------------------------
-- 3. Reads (the API's GET routes).
-- ---------------------------------------------------------------------------

create or replace function private.school_portal_class_json(p_org uuid, p_classroom uuid)
returns jsonb language sql stable security definer set search_path = '' as $$
  select jsonb_build_object(
    'id', c.id, 'name', c.name, 'grade', c.grade, 'section', c.section,
    'status', c.status, 'timezone', s.timezone,
    'teachers', coalesce((select jsonb_agg(jsonb_build_object(
        'id', p.id, 'name', p.display_name, 'role', cs.role) order by cs.role, p.display_name)
      from public.classroom_staff cs join public.profiles p on p.id = cs.user_id
      where cs.classroom_id = c.id and cs.status = 'active'
        and cs.role in ('lead_teacher', 'co_teacher')), '[]'::jsonb),
    'students', (select count(*) from public.enrollments e
      where e.classroom_id = c.id and e.status = 'active'))
  from public.classrooms c join public.schools s on s.id = c.school_id
  where c.id = p_classroom;
$$;

-- Per (class, student): attendance over 30 days, average mark and missing
-- work, for the visible classes of an org. Shared by the overview, the
-- student's page and the reports.
create or replace function private.school_portal_student_stats(p_org uuid)
returns table (classroom_id uuid, student_id uuid, sessions bigint,
  attended bigint, average numeric, missing bigint)
language sql stable security definer set search_path = '' as $$
  with vc as (select id from private.school_portal_visible_classes(p_org) v(id)),
  enr as (
    select e.classroom_id, e.student_id from public.enrollments e
    join public.students s on s.id = e.student_id and s.deleted_at is null
    where e.status = 'active' and e.classroom_id in (select id from vc)),
  att as (
    select ls.classroom_id, ar.student_id, count(*) as sessions,
      count(*) filter (where ar.state in ('present', 'late')) as attended
    from public.lesson_sessions ls
    join public.attendance_records ar on ar.session_id = ls.id
    where ls.classroom_id in (select id from vc)
      and ls.starts_at > now() - interval '30 days'
    group by 1, 2),
  mk as (
    select t.classroom_id, g.student_id,
      avg(g.score / nullif(t.maximum_score, 0)) as average
    from public.grade_results g
    join public.assessments t on t.id = g.assessment_id and t.deleted_at is null
    where t.classroom_id in (select id from vc) and g.mark = 'scored'
      and g.score is not null
    group by 1, 2),
  miss as (
    select a.classroom_id, e.student_id, count(*) as missing
    from public.assignments a
    join enr e on e.classroom_id = a.classroom_id
    where a.deleted_at is null and a.state::text = 'published'
      and a.due_at < now()
      and not exists (select 1 from public.submissions sb
        where sb.assignment_id = a.id and sb.student_id = e.student_id
          and (sb.status = 'submitted' or sb.excused))
    group by 1, 2)
  select e.classroom_id, e.student_id, coalesce(att.sessions, 0),
    coalesce(att.attended, 0), mk.average, coalesce(miss.missing, 0)
  from enr e
  left join att on att.classroom_id = e.classroom_id and att.student_id = e.student_id
  left join mk on mk.classroom_id = e.classroom_id and mk.student_id = e.student_id
  left join miss on miss.classroom_id = e.classroom_id and miss.student_id = e.student_id;
$$;

-- Thresholds for "needs attention" (plan 13a.1).
create or replace function private.school_portal_attention_reasons(
  p_sessions bigint, p_attended bigint, p_average numeric, p_missing bigint)
returns text[] language sql immutable set search_path = '' as $$
  select array_remove(array[
    case when p_sessions >= 3 and p_attended::numeric / p_sessions < 0.85
      then 'attendance' end,
    case when p_missing >= 2 then 'missing_work' end,
    case when p_average is not null and p_average < 0.5 then 'low_marks' end
  ], null);
$$;

create or replace function private.school_portal_overview(p_org uuid)
returns jsonb language sql stable security definer set search_path = '' as $$
  with st as (select * from private.school_portal_student_stats(p_org))
  select jsonb_build_object('outcome', 'ok',
    'classes', coalesce((
      select jsonb_agg(jsonb_build_object(
        'classroomId', c.id, 'name', c.name,
        'students', (select count(*) from st where st.classroom_id = c.id),
        'attendanceRate', (select round(sum(st.attended)::numeric
            / nullif(sum(st.sessions), 0), 3) from st where st.classroom_id = c.id),
        'averageMark', (select round(avg(st.average), 3) from st
          where st.classroom_id = c.id),
        'missing', (select coalesce(sum(st.missing), 0) from st
          where st.classroom_id = c.id)) order by c.name)
      from public.classrooms c
      where c.id in (select id from private.school_portal_visible_classes(p_org) v(id))),
      '[]'::jsonb),
    'attention', coalesce((
      select jsonb_agg(jsonb_build_object(
        'studentId', s.id, 'name', s.display_name,
        'classroomId', c.id, 'className', c.name,
        'reasons', to_jsonb(private.school_portal_attention_reasons(
          st.sessions, st.attended, st.average, st.missing)),
        'attendanceRate', round(st.attended::numeric / nullif(st.sessions, 0), 3),
        'averageMark', round(st.average, 3), 'missing', st.missing)
        order by s.display_name, c.name)
      from st
      join public.students s on s.id = st.student_id
      join public.classrooms c on c.id = st.classroom_id
      where cardinality(private.school_portal_attention_reasons(
        st.sessions, st.attended, st.average, st.missing)) > 0), '[]'::jsonb));
$$;

-- One student across every visible class (plan 13a.2). The same child
-- may be on several teachers' lists (one row per teacher's workspace, one
-- account); their rows are read together.
create or replace function private.school_portal_student_page(p_org uuid, p_student uuid)
returns jsonb language sql stable security definer set search_path = '' as $$
  with me as (
    select s.id, s.user_id from public.students s where s.id = p_student),
  rows as (
    select s.id from public.students s, me
    where s.deleted_at is null
      and (s.id = me.id or (me.user_id is not null and s.user_id = me.user_id))),
  vc as (select id from private.school_portal_visible_classes(p_org) v(id)),
  enr as (
    select e.classroom_id, e.student_id from public.enrollments e
    where e.status = 'active' and e.student_id in (select id from rows)
      and e.classroom_id in (select id from vc)),
  st as (
    select st.* from private.school_portal_student_stats(p_org) st
    where st.student_id in (select id from rows))
  select case when not exists (select 1 from enr) then null else jsonb_build_object(
    'outcome', 'ok',
    'student', (select jsonb_build_object('studentId', s.id, 'name', s.display_name,
        'studafyId', s.studafy_id,
        'email', (select u.email from auth.users u where u.id = s.user_id),
        'parents', coalesce((select jsonb_agg(distinct jsonb_build_object(
            'name', gp.display_name,
            'email', (select u.email from auth.users u where u.id = gl.guardian_id),
            'relationship', gl.relationship))
          from public.guardian_links gl
          join public.profiles gp on gp.id = gl.guardian_id and gp.status = 'active'
          where gl.student_id in (select id from rows) and gl.status = 'verified'
            and (gl.expires_at is null or gl.expires_at > now())), '[]'::jsonb))
      from public.students s where s.id = p_student),
    'classes', coalesce((select jsonb_agg(jsonb_build_object(
        'classroomId', c.id, 'name', c.name,
        'teachers', (select coalesce(jsonb_agg(p.display_name order by p.display_name), '[]'::jsonb)
          from public.classroom_staff cs join public.profiles p on p.id = cs.user_id
          where cs.classroom_id = c.id and cs.status = 'active'
            and cs.role in ('lead_teacher', 'co_teacher')),
        'attendanceRate', round(st.attended::numeric / nullif(st.sessions, 0), 3),
        'averageMark', round(st.average, 3), 'missing', coalesce(st.missing, 0))
        order by c.name)
      from enr join public.classrooms c on c.id = enr.classroom_id
      left join st on st.classroom_id = enr.classroom_id and st.student_id = enr.student_id),
      '[]'::jsonb),
    'recentMarks', coalesce((select jsonb_agg(m order by m->>'at' desc) from (
        select jsonb_build_object('assessmentId', t.id, 'title', t.title,
          'className', c.name, 'score', g.score, 'maximumScore', t.maximum_score,
          'mark', g.mark, 'state', g.state,
          'at', coalesce(g.published_at, g.updated_at)) as m
        from public.grade_results g
        join public.assessments t on t.id = g.assessment_id and t.deleted_at is null
        join enr on enr.classroom_id = t.classroom_id and enr.student_id = g.student_id
        join public.classrooms c on c.id = t.classroom_id
        order by coalesce(g.published_at, g.updated_at) desc limit 20) x), '[]'::jsonb),
    'missingWork', coalesce((select jsonb_agg(jsonb_build_object('assignmentId', a.id,
        'title', a.title, 'className', c.name, 'dueAt', a.due_at) order by a.due_at desc)
      from public.assignments a
      join enr on enr.classroom_id = a.classroom_id
      join public.classrooms c on c.id = a.classroom_id
      where a.deleted_at is null and a.state::text = 'published' and a.due_at < now()
        and not exists (select 1 from public.submissions sb
          where sb.assignment_id = a.id and sb.student_id = enr.student_id
            and (sb.status = 'submitted' or sb.excused))), '[]'::jsonb),
    'wellbeing', coalesce((select jsonb_agg(jsonb_build_object('id', w.id,
        'className', c.name, 'kind', w.kind, 'title', w.title, 'context', w.context,
        'createdAt', w.created_at) order by w.created_at desc)
      from public.wellbeing_events w
      join enr on enr.classroom_id = w.classroom_id and enr.student_id = w.student_id
      join public.classrooms c on c.id = w.classroom_id
      where w.visibility::text <> 'safeguarding_restricted'), '[]'::jsonb)) end;
$$;

-- One linked teacher (plan 13a.3): their classes with the same numbers as
-- the overview, recent lessons, and marking still to do.
create or replace function private.school_portal_teacher_page(p_org uuid, p_teacher uuid)
returns jsonb language sql stable security definer set search_path = '' as $$
  with link as (
    select l.* from private.school_portal_teacher_links l
    where l.org_id = p_org and l.teacher_id = p_teacher and l.status = 'linked'),
  tc as (
    select distinct cs.classroom_id as id from public.classroom_staff cs
    where cs.user_id = p_teacher and cs.status = 'active'
      and cs.role in ('lead_teacher', 'co_teacher')
      and cs.classroom_id in (select id from private.school_portal_visible_classes(p_org) v(id))),
  st as (
    select st.* from private.school_portal_student_stats(p_org) st
    where st.classroom_id in (select id from tc))
  select case when not exists (select 1 from link) then null else jsonb_build_object(
    'outcome', 'ok',
    'teacher', private.school_portal_person(p_teacher) || jsonb_build_object(
      'studafyId', (select p.public_id from public.profiles p where p.id = p_teacher),
      'linkedSince', (select decided_at from link)),
    'classes', coalesce((select jsonb_agg(jsonb_build_object(
        'classroomId', c.id, 'name', c.name,
        'students', (select count(*) from st where st.classroom_id = c.id),
        'attendanceRate', (select round(sum(st.attended)::numeric
            / nullif(sum(st.sessions), 0), 3) from st where st.classroom_id = c.id),
        'averageMark', (select round(avg(st.average), 3) from st where st.classroom_id = c.id),
        'missing', (select coalesce(sum(st.missing), 0) from st where st.classroom_id = c.id))
        order by c.name)
      from public.classrooms c where c.id in (select id from tc)), '[]'::jsonb),
    'recentLessons', coalesce((select jsonb_agg(x order by x->>'startsAt' desc) from (
        select jsonb_build_object('id', ls.id, 'title', ls.title, 'className', c.name,
          'startsAt', ls.starts_at, 'status', ls.status) as x
        from public.lesson_sessions ls join public.classrooms c on c.id = ls.classroom_id
        where ls.classroom_id in (select id from tc) and ls.starts_at <= now()
        order by ls.starts_at desc limit 10) y), '[]'::jsonb),
    'toMark', jsonb_build_object(
      'testAnswers', (select count(*) from public.assessment_attempts at
        join public.assessments t on t.id = at.assessment_id and t.deleted_at is null
        where t.classroom_id in (select id from tc) and at.submitted_at is not null
          and at.needs_marking),
      'handIns', (select count(*) from public.submissions sb
        join public.assignments a on a.id = sb.assignment_id and a.deleted_at is null
        where a.classroom_id in (select id from tc) and sb.status = 'submitted'
          and not exists (select 1 from public.assessments t
            join public.grade_results g on g.assessment_id = t.id
              and g.student_id = sb.student_id and g.state::text = 'published'
            where t.assignment_id = a.id)))) end;
$$;

-- Reports across classes (plan 13a.4): attendance by week for the last 12
-- weeks (school-wide and per class), and per class the attendance rate over
-- those weeks, the average mark, the hand-in rate (published work past due:
-- handed in or excused, of all owed) and how marks spread across four bands.
create or replace function private.school_portal_reports(p_org uuid)
returns jsonb language sql stable security definer set search_path = '' as $$
  with vc as (select id from private.school_portal_visible_classes(p_org) v(id)),
  wk as (
    select generate_series(date_trunc('week', now()) - interval '11 weeks',
      date_trunc('week', now()), interval '1 week') as week_start),
  att as (
    select ls.classroom_id, date_trunc('week', ls.starts_at) as week_start,
      count(*) as sessions,
      count(*) filter (where ar.state in ('present', 'late')) as attended
    from public.lesson_sessions ls
    join public.attendance_records ar on ar.session_id = ls.id
    where ls.classroom_id in (select id from vc)
      and ls.starts_at >= date_trunc('week', now()) - interval '11 weeks'
    group by 1, 2),
  marks as (
    select t.classroom_id, g.score / nullif(t.maximum_score, 0) as pct
    from public.grade_results g
    join public.assessments t on t.id = g.assessment_id and t.deleted_at is null
    where t.classroom_id in (select id from vc) and g.mark = 'scored'
      and g.score is not null),
  owed as (
    select a.classroom_id, count(*) as owed,
      count(*) filter (where exists (select 1 from public.submissions sb
        where sb.assignment_id = a.id and sb.student_id = e.student_id
          and (sb.status = 'submitted' or sb.excused))) as handed
    from public.assignments a
    join public.enrollments e on e.classroom_id = a.classroom_id and e.status = 'active'
    where a.classroom_id in (select id from vc) and a.deleted_at is null
      and a.state::text = 'published' and a.due_at < now()
    group by 1)
  select jsonb_build_object('outcome', 'ok',
    'weeks', (select jsonb_agg(jsonb_build_object(
        'weekStart', to_char(wk.week_start, 'YYYY-MM-DD'),
        'attendanceRate', (select round(sum(att.attended)::numeric
          / nullif(sum(att.sessions), 0), 3) from att where att.week_start = wk.week_start))
        order by wk.week_start) from wk),
    'classes', coalesce((select jsonb_agg(jsonb_build_object(
        'classroomId', c.id, 'name', c.name,
        'students', (select count(*) from public.enrollments e
          where e.classroom_id = c.id and e.status = 'active'),
        'attendanceRate', (select round(sum(att.attended)::numeric
          / nullif(sum(att.sessions), 0), 3) from att where att.classroom_id = c.id),
        'averageMark', (select round(avg(m.pct), 3) from marks m where m.classroom_id = c.id),
        'handInRate', (select round(o.handed::numeric / nullif(o.owed, 0), 3)
          from owed o where o.classroom_id = c.id),
        'bands', (select jsonb_build_object(
            'below50', count(*) filter (where m.pct < 0.5),
            'from50', count(*) filter (where m.pct >= 0.5 and m.pct < 0.7),
            'from70', count(*) filter (where m.pct >= 0.7 and m.pct < 0.85),
            'from85', count(*) filter (where m.pct >= 0.85))
          from marks m where m.classroom_id = c.id),
        'weeks', (select jsonb_agg(jsonb_build_object(
            'weekStart', to_char(wk.week_start, 'YYYY-MM-DD'),
            'attendanceRate', (select round(att.attended::numeric
              / nullif(att.sessions, 0), 3) from att
              where att.classroom_id = c.id and att.week_start = wk.week_start))
            order by wk.week_start) from wk))
        order by c.name)
      from public.classrooms c where c.id in (select id from vc)), '[]'::jsonb));
$$;

create or replace function private.api062_query(
  p_operation text, p_resource_id uuid, p_input jsonb)
returns jsonb language plpgsql volatile security definer set search_path = '' as $$
declare
  v_org uuid;
  v_classroom uuid;
  v_result jsonb;
begin
  if auth.uid() is null or not private.is_active_user() then
    return jsonb_build_object('outcome', 'forbidden');
  end if;

  -- The teacher's and the invited person's own reads.
  if p_operation = 'myLinks' then
    return jsonb_build_object('outcome', 'ok', 'links', coalesce((
      select jsonb_agg(jsonb_build_object(
        'id', l.id,
        'status', private.school_portal_link_status(l.status, l.requested_at),
        'requestedAt', l.requested_at, 'decidedAt', l.decided_at, 'endedAt', l.ended_at,
        'org', jsonb_build_object('id', o.id, 'name', o.name, 'city', o.city,
          'country', o.country, 'kind', o.kind, 'status', o.status),
        'requestedBy', private.school_portal_person(l.requested_by) || jsonb_build_object(
          'jobTitle', (select a.job_title from private.school_portal_admins a
            where a.org_id = l.org_id and a.user_id = l.requested_by
            order by a.added_at desc limit 1)))
        order by l.requested_at desc)
      from private.school_portal_teacher_links l
      join private.school_portal_orgs o on o.id = l.org_id
      where l.teacher_id = auth.uid()), '[]'::jsonb));
  elsif p_operation = 'myInvites' then
    return jsonb_build_object('outcome', 'ok', 'invites', coalesce((
      select jsonb_agg(jsonb_build_object('id', i.id, 'jobTitle', i.job_title,
        'expiresAt', i.expires_at,
        'org', jsonb_build_object('id', o.id, 'name', o.name, 'city', o.city, 'country', o.country),
        'invitedBy', private.school_portal_person(i.invited_by)) order by i.created_at)
      from private.school_portal_admin_invites i
      join private.school_portal_orgs o on o.id = i.org_id and o.status = 'active'
      where i.email = lower((select u.email from auth.users u where u.id = auth.uid()))
        and i.accepted_at is null and i.revoked_at is null and i.expires_at > now()), '[]'::jsonb));
  elsif p_operation = 'orgs' then
    return jsonb_build_object('outcome', 'ok', 'orgs', coalesce((
      select jsonb_agg(jsonb_build_object(
        'id', o.id, 'name', o.name, 'country', o.country, 'city', o.city, 'kind', o.kind,
        'contactEmail', o.contact_email, 'status', o.status, 'createdAt', o.created_at,
        'admins', (select jsonb_agg(private.school_portal_person(a2.user_id)
            || jsonb_build_object('jobTitle', a2.job_title, 'addedAt', a2.added_at)
            order by a2.added_at)
          from private.school_portal_admins a2
          where a2.org_id = o.id and a2.removed_at is null),
        'invites', coalesce((select jsonb_agg(jsonb_build_object('id', i.id, 'email', i.email,
            'jobTitle', i.job_title, 'expiresAt', i.expires_at) order by i.created_at)
          from private.school_portal_admin_invites i
          where i.org_id = o.id and i.accepted_at is null and i.revoked_at is null
            and i.expires_at > now()), '[]'::jsonb))
        order by o.created_at)
      from private.school_portal_admins a
      join private.school_portal_orgs o on o.id = a.org_id and o.status <> 'closed'
      where a.user_id = auth.uid() and a.removed_at is null), '[]'::jsonb));
  end if;

  -- Everything else is an administrator reading their org.
  v_org := case when p_operation in ('dashboard', 'teachers', 'classes', 'overview', 'reports')
    then p_resource_id else nullif(p_input->>'orgId', '')::uuid end;
  if v_org is null or not private.school_portal_admin_ok(v_org) then
    return jsonb_build_object('outcome', 'not_found');
  end if;

  case p_operation
    when 'dashboard' then
      perform private.school_portal_log(v_org, 'dashboard');
      return jsonb_build_object('outcome', 'ok',
        'linkedTeachers', (select count(*) from private.school_portal_teacher_links l
          where l.org_id = v_org and l.status = 'linked'),
        'classes', (select count(*) from private.school_portal_visible_classes(v_org)),
        'students', (select count(distinct e.student_id) from public.enrollments e
          where e.status = 'active'
            and e.classroom_id in (select id from private.school_portal_visible_classes(v_org) v(id))),
        'waiting', coalesce((select jsonb_agg(jsonb_build_object('id', l.id,
            'teacher', private.school_portal_person(l.teacher_id), 'requestedAt', l.requested_at)
            order by l.requested_at desc)
          from private.school_portal_teacher_links l
          where l.org_id = v_org
            and private.school_portal_link_status(l.status, l.requested_at) = 'pending'), '[]'::jsonb));

    when 'teachers' then
      perform private.school_portal_log(v_org, 'teachers');
      return jsonb_build_object('outcome', 'ok', 'teachers', coalesce((
        select jsonb_agg(private.school_portal_person(l.teacher_id) || jsonb_build_object(
          'linkId', l.id,
          'studafyId', (select p.public_id from public.profiles p where p.id = l.teacher_id),
          'status', private.school_portal_link_status(l.status, l.requested_at),
          'requestedAt', l.requested_at, 'decidedAt', l.decided_at, 'endedAt', l.ended_at,
          'classes', case when l.status = 'linked' then (
            select count(distinct cs.classroom_id) from public.classroom_staff cs
            where cs.user_id = l.teacher_id and cs.status = 'active'
              and cs.classroom_id in (select id from private.school_portal_visible_classes(v_org) v(id)))
            else 0 end)
          order by l.requested_at desc)
        from private.school_portal_teacher_links l where l.org_id = v_org), '[]'::jsonb));

    when 'reports' then
      perform private.school_portal_log(v_org, 'reports');
      return private.school_portal_reports(v_org);

    when 'overview' then
      -- The school at a glance (plan 13a.1): per class, attendance over the
      -- last 30 days, the average mark and work still missing; and the
      -- students who need attention, each with the reason.
      perform private.school_portal_log(v_org, 'overview');
      return private.school_portal_overview(v_org);

    when 'classes' then
      perform private.school_portal_log(v_org, 'classes');
      return jsonb_build_object('outcome', 'ok', 'classes', coalesce((
        select jsonb_agg(private.school_portal_class_json(v_org, v.id)
          order by (select c.name from public.classrooms c where c.id = v.id))
        from private.school_portal_visible_classes(v_org) v(id)), '[]'::jsonb));
    else
      null;
  end case;

  -- Reads of one class (or of one item in it).
  if p_operation = 'handIns' then
    select a.classroom_id into v_classroom from public.assignments a
    where a.id = p_resource_id and a.deleted_at is null;
  elsif p_operation = 'testAnswers' then
    select a.classroom_id into v_classroom from public.assessments a
    where a.id = p_resource_id and a.deleted_at is null;
  elsif p_operation = 'student' then
    v_result := private.school_portal_student_page(v_org, p_resource_id);
    if v_result is null then return jsonb_build_object('outcome', 'not_found'); end if;
    perform private.school_portal_log(v_org, 'student', null, p_resource_id);
    return v_result;
  elsif p_operation = 'teacher' then
    v_result := private.school_portal_teacher_page(v_org, p_resource_id);
    if v_result is null then return jsonb_build_object('outcome', 'not_found'); end if;
    perform private.school_portal_log(v_org, 'teacher', null, null, null, p_resource_id);
    return v_result;
  elsif p_operation in ('roster', 'lessons', 'assignments', 'tests', 'marks', 'attendance', 'wellbeing') then
    v_classroom := p_resource_id;
  else
    return jsonb_build_object('outcome', 'invalid');
  end if;
  if not private.school_portal_class_visible(v_org, v_classroom) then
    return jsonb_build_object('outcome', 'not_found');
  end if;

  case p_operation
    when 'roster' then
      v_result := coalesce((
        select jsonb_agg(jsonb_build_object(
          'studentId', s.id, 'name', s.display_name, 'studafyId', s.studafy_id,
          'email', (select u.email from auth.users u where u.id = s.user_id),
          'joinedOn', e.starts_on,
          'parents', coalesce((
            select jsonb_agg(jsonb_build_object('name', gp.display_name,
              'email', (select u.email from auth.users u where u.id = gl.guardian_id),
              'relationship', gl.relationship) order by gp.display_name)
            from public.guardian_links gl
            join public.profiles gp on gp.id = gl.guardian_id and gp.status = 'active'
            where gl.student_id = s.id and gl.status = 'verified'
              and (gl.expires_at is null or gl.expires_at > now())), '[]'::jsonb))
          order by s.display_name)
        from public.enrollments e
        join public.students s on s.id = e.student_id and s.deleted_at is null
        where e.classroom_id = v_classroom and e.status = 'active'), '[]'::jsonb);
      perform private.school_portal_log(v_org, 'roster', v_classroom);
      return jsonb_build_object('outcome', 'ok', 'students', v_result);

    when 'lessons' then
      perform private.school_portal_log(v_org, 'lessons', v_classroom);
      return jsonb_build_object('outcome', 'ok',
        'sessions', coalesce((select jsonb_agg(jsonb_build_object('id', ls.id,
            'title', ls.title, 'startsAt', ls.starts_at, 'endsAt', ls.ends_at, 'status', ls.status)
            order by ls.starts_at desc)
          from (select * from public.lesson_sessions where classroom_id = v_classroom
                order by starts_at desc limit 500) ls), '[]'::jsonb),
        'materials', coalesce((select jsonb_agg(jsonb_build_object(
            'id', r.id, 'title', r.title, 'type', r.resource_type, 'body', rv.body,
            'lessonSessionId', rp.lesson_session_id, 'publishedAt', rp.published_at,
            'files', private.school_portal_files(array(
              select fb.file_object_id from public.file_bindings fb
              where fb.resource_version_id = rv.id and fb.detached_at is null)),
            'links', coalesce((select jsonb_agg(jsonb_build_object('title', cl.title, 'url', cl.url)
                order by cl.position)
              from public.content_links cl
              where cl.resource_version_id = rv.id and cl.detached_at is null), '[]'::jsonb))
            order by rp.published_at desc nulls last)
          from public.resource_publications rp
          join public.resource_versions rv on rv.id = rp.resource_version_id
          join public.resources r on r.id = rv.resource_id and r.deleted_at is null
          where rp.classroom_id = v_classroom and rp.state::text = 'published'
            and rp.withdrawn_at is null), '[]'::jsonb),
        'announcements', coalesce((select jsonb_agg(jsonb_build_object('id', an.id,
            'title', an.title, 'body', an.body, 'audience', an.audience,
            'important', an.important, 'publishedAt', an.published_at,
            'files', private.school_portal_files(array(
              select fb.file_object_id from public.file_bindings fb
              where fb.announcement_id = an.id and fb.detached_at is null)))
            order by an.published_at desc)
          from public.announcements an
          where an.classroom_id = v_classroom and an.state::text = 'published'
            and an.deleted_at is null), '[]'::jsonb));

    when 'assignments' then
      perform private.school_portal_log(v_org, 'assignments', v_classroom);
      return jsonb_build_object('outcome', 'ok', 'assignments', coalesce((
        select jsonb_agg(jsonb_build_object('id', a.id, 'title', a.title,
          'instructions', a.instructions, 'dueAt', a.due_at, 'closesAt', a.closes_at,
          'state', a.state, 'publishedAt', a.published_at,
          'handedIn', (select count(*) from public.submissions sb
            where sb.assignment_id = a.id and sb.status = 'submitted'),
          'students', (select count(*) from public.enrollments e
            where e.classroom_id = a.classroom_id and e.status = 'active'),
          'files', private.school_portal_files(array(
            select fb.file_object_id from public.file_bindings fb
            where fb.assignment_id = a.id and fb.detached_at is null)))
          order by a.due_at desc nulls last, a.created_at desc)
        from public.assignments a
        where a.classroom_id = v_classroom and a.deleted_at is null), '[]'::jsonb));

    when 'handIns' then
      perform private.school_portal_log(v_org, 'hand_ins', v_classroom, null, null, p_resource_id);
      return jsonb_build_object('outcome', 'ok', 'assignmentId', p_resource_id, 'handIns', coalesce((
        select jsonb_agg(jsonb_build_object('studentId', s.id, 'name', s.display_name,
          'status', coalesce(sb.status::text, 'not_handed_in'),
          'submittedAt', sb.submitted_at, 'excused', coalesce(sb.excused, false),
          'answerText', at.answer_text,
          'files', case when at.id is null then '[]'::jsonb else private.school_portal_files(array(
            select fb.file_object_id from public.file_bindings fb
            where fb.submission_attempt_id = at.id and fb.detached_at is null)) end)
          order by s.display_name)
        from public.assignments a
        join public.enrollments e on e.classroom_id = a.classroom_id and e.status = 'active'
        join public.students s on s.id = e.student_id and s.deleted_at is null
        left join public.submissions sb on sb.assignment_id = a.id and sb.student_id = s.id
        left join public.submission_attempts at on at.id = sb.current_attempt_id
        where a.id = p_resource_id), '[]'::jsonb));

    when 'tests' then
      perform private.school_portal_log(v_org, 'tests', v_classroom);
      return jsonb_build_object('outcome', 'ok', 'tests', coalesce((
        select jsonb_agg(jsonb_build_object('id', t.id, 'title', t.title,
          'category', t.category, 'delivery', t.delivery, 'state', t.state,
          'maximumScore', t.maximum_score, 'scheduledAt', t.scheduled_at,
          'opensAt', t.opens_at, 'closesAt', t.closes_at,
          'sat', (select count(distinct at.student_id) from public.assessment_attempts at
            where at.assessment_id = t.id and at.submitted_at is not null),
          'averageScore', (select round(avg(g.score), 2) from public.grade_results g
            where g.assessment_id = t.id and g.mark = 'scored' and g.score is not null))
          order by coalesce(t.scheduled_at, t.opens_at, t.created_at) desc)
        from public.assessments t
        where t.classroom_id = v_classroom and t.deleted_at is null), '[]'::jsonb));

    when 'testAnswers' then
      perform private.school_portal_log(v_org, 'test_answers', v_classroom, null, null, p_resource_id);
      return jsonb_build_object('outcome', 'ok', 'testId', p_resource_id,
        'questions', coalesce((select jsonb_agg(jsonb_build_object('id', q.id,
            'position', q.position, 'kind', q.kind, 'prompt', q.prompt,
            'maximumScore', q.maximum_score) order by q.position)
          from public.assessment_questions q where q.assessment_id = p_resource_id), '[]'::jsonb),
        'attempts', coalesce((select jsonb_agg(jsonb_build_object('attemptId', at.id,
            'studentId', s.id, 'name', s.display_name, 'attemptNumber', at.attempt_number,
            'submittedAt', at.submitted_at, 'awardedScore', at.awarded_score,
            'feedback', at.feedback, 'needsMarking', at.needs_marking,
            'answers', coalesce((select jsonb_agg(jsonb_build_object('questionId', an.question_id,
                'answerText', an.answer_text, 'selected', an.selected,
                'autoScore', an.auto_score, 'awardedScore', an.awarded_score,
                'feedback', an.feedback))
              from public.assessment_answers an where an.attempt_id = at.id), '[]'::jsonb))
            order by s.display_name, at.attempt_number)
          from public.assessment_attempts at
          join public.students s on s.id = at.student_id
          where at.assessment_id = p_resource_id and at.submitted_at is not null), '[]'::jsonb));

    when 'marks' then
      perform private.school_portal_log(v_org, 'marks', v_classroom);
      return jsonb_build_object('outcome', 'ok',
        'items', coalesce((select jsonb_agg(jsonb_build_object('id', t.id, 'title', t.title,
            'maximumScore', t.maximum_score, 'category', t.category)
            order by coalesce(t.scheduled_at, t.created_at))
          from public.assessments t
          where t.classroom_id = v_classroom and t.deleted_at is null), '[]'::jsonb),
        'marks', coalesce((select jsonb_agg(jsonb_build_object('assessmentId', g.assessment_id,
            'studentId', g.student_id, 'score', g.score, 'mark', g.mark,
            'state', g.state, 'feedback', g.feedback, 'publishedAt', g.published_at))
          from public.grade_results g
          join public.assessments t on t.id = g.assessment_id
           and t.classroom_id = v_classroom and t.deleted_at is null), '[]'::jsonb),
        'suggestions', coalesce((select jsonb_agg(jsonb_build_object(
            'assessmentId', ms.assessment_id, 'studentId', ms.student_id,
            'questionId', ms.question_id, 'suggestedScore', ms.suggested_score,
            'maximumScore', ms.maximum_score))
          from private.marking_suggestions ms
          join public.assessments t on t.id = ms.assessment_id
           and t.classroom_id = v_classroom and t.deleted_at is null
          where ms.status = 'ready'), '[]'::jsonb),
        'students', coalesce((select jsonb_agg(jsonb_build_object('studentId', s.id,
            'name', s.display_name) order by s.display_name)
          from public.enrollments e join public.students s on s.id = e.student_id
          where e.classroom_id = v_classroom and e.status = 'active'
            and s.deleted_at is null), '[]'::jsonb));

    when 'attendance' then
      perform private.school_portal_log(v_org, 'attendance', v_classroom);
      return jsonb_build_object('outcome', 'ok', 'records', coalesce((
        select jsonb_agg(jsonb_build_object('sessionId', ls.id,
          'date', (ls.starts_at at time zone sch.timezone)::date,
          'startsAt', ls.starts_at, 'studentId', ar.student_id, 'name', s.display_name,
          'state', ar.state, 'reason', ar.reason)
          order by ls.starts_at desc, s.display_name)
        from public.lesson_sessions ls
        join public.classrooms c on c.id = ls.classroom_id
        join public.schools sch on sch.id = c.school_id
        join public.attendance_records ar on ar.session_id = ls.id
        join public.students s on s.id = ar.student_id
        where ls.classroom_id = v_classroom), '[]'::jsonb));

    when 'wellbeing' then
      perform private.school_portal_log(v_org, 'wellbeing', v_classroom);
      -- Safeguarding-restricted notes stay with the people the teacher chose.
      return jsonb_build_object('outcome', 'ok', 'notes', coalesce((
        select jsonb_agg(jsonb_build_object('id', w.id, 'studentId', w.student_id,
          'name', s.display_name, 'kind', w.kind, 'title', w.title, 'context', w.context,
          'followUp', w.follow_up, 'severity', w.severity, 'status', w.status,
          'createdAt', w.created_at, 'author', (select p.display_name from public.profiles p
            where p.id = w.created_by)) order by w.created_at desc)
        from public.wellbeing_events w
        join public.students s on s.id = w.student_id
        where w.classroom_id = v_classroom
          and w.visibility::text <> 'safeguarding_restricted'), '[]'::jsonb));
    else
      return jsonb_build_object('outcome', 'invalid');
  end case;
end;
$$;

-- ---------------------------------------------------------------------------
-- 4. Commands (the API's POST routes), each behind a reserved idempotency
--    record with no school (the portal is not a school member).
-- ---------------------------------------------------------------------------

create or replace function private.school_portal_reserved(
  p_idempotency_id uuid, p_idempotency_generation bigint)
returns boolean language plpgsql security definer set search_path = '' as $$
begin
  if nullif(current_setting('studafy.request_id', true), '') is null then
    return false;
  end if;
  perform 1 from public.idempotency_records r
  where r.id = p_idempotency_id and r.actor_id = auth.uid() and r.school_id is null
    and r.generation = p_idempotency_generation and r.status = 'reserved'
  for update;
  return found;
end;
$$;

-- Ends every live link of an org (when it closes or is suspended for good).
create or replace function private.school_portal_end_org_links(p_org uuid, p_by uuid)
returns void language sql security definer set search_path = '' as $$
  update private.school_portal_teacher_links
  set status = case when status = 'linked' then 'unlinked' else 'cancelled' end,
      ended_at = now(), ended_by = p_by
  where org_id = p_org and status in ('pending', 'linked');
$$;

-- A person who signs in on the website only belongs to no school, so
-- nothing has decided what kind of account theirs is. Confirming they are
-- an adult records it, once, exactly as the app's first-sign-in setup does
-- (202610010002): never over a kind already decided, so a student account
-- stays a student's and can never administer a school.
create or replace function private.school_portal_confirm_adult(body jsonb)
returns void language sql security definer set search_path = '' as $$
  update public.profiles set account_kind = 'adult', updated_at = now()
  where id = auth.uid() and coalesce((body->>'adult')::boolean, false)
    and account_kind is null and private.account_kind(auth.uid()) is null;
$$;

create or replace function private.api062_command(
  p_operation text, p_resource_id uuid, p_input jsonb,
  p_idempotency_id uuid, p_idempotency_generation bigint)
returns jsonb language plpgsql security definer set search_path = '' as $$
declare
  body jsonb := coalesce(p_input->'body', '{}'::jsonb);
  me uuid := auth.uid();
  v_org private.school_portal_orgs%rowtype;
  v_link private.school_portal_teacher_links%rowtype;
  v_invite private.school_portal_admin_invites%rowtype;
  v_teacher uuid;
  v_current uuid;
  v_id uuid;
  v_status int := 200;
  v_live int;
  response jsonb;
begin
  if me is null or not private.is_active_user() then
    return jsonb_build_object('outcome', 'forbidden');
  end if;
  if not private.school_portal_reserved(p_idempotency_id, p_idempotency_generation) then
    return jsonb_build_object('outcome', 'forbidden');
  end if;

  case p_operation
    when 'createOrg' then
      perform private.school_portal_confirm_adult(body);
      if private.account_kind(me) is distinct from 'adult' then
        return jsonb_build_object('outcome', 'forbidden');
      end if;
      if (select count(*) from private.school_portal_orgs o
          where o.created_by = me and o.created_at > now() - interval '1 day') >= 3 then
        return jsonb_build_object('outcome', 'rate_limited');
      end if;
      insert into private.school_portal_orgs(name, country, city, kind, contact_email, created_by)
      values (btrim(body->>'name'), btrim(body->>'country'), btrim(body->>'city'),
        body->>'kind', lower(nullif(btrim(body->>'contactEmail'), '')), me)
      returning * into v_org;
      insert into private.school_portal_admins(org_id, user_id, job_title, added_by)
      values (v_org.id, me, btrim(body->>'jobTitle'), me);
      v_status := 201;
      response := jsonb_build_object('id', v_org.id, 'status', v_org.status);

    when 'updateOrg' then
      if not private.school_portal_admin_ok(p_resource_id) then
        return jsonb_build_object('outcome', 'not_found');
      end if;
      update private.school_portal_orgs o set
        name = coalesce(btrim(body->>'name'), o.name),
        country = coalesce(btrim(body->>'country'), o.country),
        city = coalesce(btrim(body->>'city'), o.city),
        kind = coalesce(body->>'kind', o.kind),
        contact_email = case when body ? 'contactEmail'
          then lower(nullif(btrim(body->>'contactEmail'), '')) else o.contact_email end,
        updated_at = now()
      where o.id = p_resource_id returning * into v_org;
      response := jsonb_build_object('id', v_org.id);

    when 'inviteAdmin' then
      if not private.school_portal_admin_ok(p_resource_id) then
        return jsonb_build_object('outcome', 'not_found');
      end if;
      perform 1 from private.school_portal_orgs where id = p_resource_id for update;
      select count(*) into v_live from (
        select 1 from private.school_portal_admins a
        where a.org_id = p_resource_id and a.removed_at is null
        union all
        select 1 from private.school_portal_admin_invites i
        where i.org_id = p_resource_id and i.accepted_at is null and i.revoked_at is null
          and i.expires_at > now()) x;
      if v_live >= 3 then
        return jsonb_build_object('outcome', 'conflict', 'reason', 'admin_limit');
      end if;
      if exists (select 1 from private.school_portal_admins a join auth.users u on u.id = a.user_id
          where a.org_id = p_resource_id and a.removed_at is null
            and lower(u.email) = lower(btrim(body->>'email'))) then
        return jsonb_build_object('outcome', 'conflict', 'reason', 'already_admin');
      end if;
      -- An earlier invite to the same address that ran out makes way.
      update private.school_portal_admin_invites set revoked_at = now()
      where org_id = p_resource_id and email = lower(btrim(body->>'email'))
        and accepted_at is null and revoked_at is null;
      insert into private.school_portal_admin_invites(org_id, email, job_title, invited_by)
      values (p_resource_id, lower(btrim(body->>'email')), btrim(body->>'jobTitle'), me)
      returning id into v_id;
      v_status := 201;
      response := jsonb_build_object('id', v_id);

    when 'acceptInvite' then
      perform private.school_portal_confirm_adult(body);
      select * into v_invite from private.school_portal_admin_invites i
      where i.id = p_resource_id and i.accepted_at is null and i.revoked_at is null
        and i.expires_at > now()
        and i.email = lower((select u.email from auth.users u where u.id = me))
      for update;
      if v_invite.id is null or private.account_kind(me) is distinct from 'adult' then
        return jsonb_build_object('outcome', 'not_found');
      end if;
      select * into v_org from private.school_portal_orgs where id = v_invite.org_id for update;
      if v_org.status <> 'active' then
        return jsonb_build_object('outcome', 'not_found');
      end if;
      if (select count(*) from private.school_portal_admins a
          where a.org_id = v_org.id and a.removed_at is null) >= 3 then
        return jsonb_build_object('outcome', 'conflict', 'reason', 'admin_limit');
      end if;
      update private.school_portal_admin_invites set accepted_at = now(), accepted_by = me
      where id = v_invite.id;
      insert into private.school_portal_admins(org_id, user_id, job_title, added_by)
      values (v_org.id, me, v_invite.job_title, v_invite.invited_by)
      on conflict (org_id, user_id) where removed_at is null do nothing;
      response := jsonb_build_object('orgId', v_org.id);

    when 'removeAdmin' then
      if not private.school_portal_admin_ok(p_resource_id) then
        return jsonb_build_object('outcome', 'not_found');
      end if;
      perform 1 from private.school_portal_orgs where id = p_resource_id for update;
      update private.school_portal_admins set removed_at = now(), removed_by = me
      where org_id = p_resource_id and user_id = nullif(body->>'userId', '')::uuid
        and removed_at is null;
      if not found then
        return jsonb_build_object('outcome', 'not_found');
      end if;
      -- The last administrator leaving closes the school's page.
      if not exists (select 1 from private.school_portal_admins a
          where a.org_id = p_resource_id and a.removed_at is null) then
        update private.school_portal_orgs set status = 'closed', closed_at = now(), updated_at = now()
        where id = p_resource_id;
        perform private.school_portal_end_org_links(p_resource_id, me);
      end if;
      response := jsonb_build_object('orgId', p_resource_id);

    when 'closeOrg' then
      if not private.school_portal_admin_ok(p_resource_id) then
        return jsonb_build_object('outcome', 'not_found');
      end if;
      update private.school_portal_orgs set status = 'closed', closed_at = now(), updated_at = now()
      where id = p_resource_id;
      update private.school_portal_admin_invites set revoked_at = now()
      where org_id = p_resource_id and accepted_at is null and revoked_at is null;
      perform private.school_portal_end_org_links(p_resource_id, me);
      response := jsonb_build_object('orgId', p_resource_id, 'status', 'closed');

    when 'requestLink' then
      if not private.school_portal_admin_ok(p_resource_id) then
        return jsonb_build_object('outcome', 'not_found');
      end if;
      if (select count(*) from private.school_portal_lookups k
          where k.admin_id = me and k.at > now() - interval '1 hour') >= 10
         or (select count(*) from private.school_portal_teacher_links l
          where l.org_id = p_resource_id and l.requested_at > now() - interval '1 day') >= 30 then
        return jsonb_build_object('outcome', 'rate_limited');
      end if;
      -- As the app shows it ("TC-" and ten digits) or the digits alone.
      v_teacher := private.school_portal_find_teacher(
        regexp_replace(upper(btrim(body->>'studafyId')), '^TC-', ''));
      insert into private.school_portal_lookups(admin_id, org_id, found)
      values (me, p_resource_id, v_teacher is not null);
      if v_teacher is null then
        -- A refusal, but the transaction still commits, so the lookup counts
        -- towards the limit; the API releases the idempotency record.
        return jsonb_build_object('outcome', 'teacher_not_found');
      end if;
      -- A request left waiting 14 days has expired; it makes way.
      update private.school_portal_teacher_links set status = 'expired'
      where org_id = p_resource_id and teacher_id = v_teacher and status = 'pending'
        and requested_at <= now() - interval '14 days';
      if exists (select 1 from private.school_portal_teacher_links l
          where l.org_id = p_resource_id and l.teacher_id = v_teacher
            and l.status in ('pending', 'linked')) then
        return jsonb_build_object('outcome', 'conflict', 'reason', 'already_requested');
      end if;
      if exists (select 1 from private.school_portal_teacher_links l
          where l.org_id = p_resource_id and l.teacher_id = v_teacher
            and l.status = 'declined' and l.decided_at > now() - interval '30 days') then
        return jsonb_build_object('outcome', 'conflict', 'reason', 'recently_declined');
      end if;
      if (select count(*) from private.school_portal_teacher_links l
          where l.teacher_id = v_teacher and l.status = 'pending'
            and l.requested_at > now() - interval '14 days') >= 5 then
        return jsonb_build_object('outcome', 'conflict', 'reason', 'teacher_busy');
      end if;
      insert into private.school_portal_teacher_links(org_id, teacher_id, requested_by)
      values (p_resource_id, v_teacher, me) returning * into v_link;
      -- The teacher's notice (in-app and push), filed under the teacher's
      -- own workspace; the outbox resolves it to this teacher alone.
      insert into public.notification_outbox(school_id, source_event_id, idempotency_key,
        channel, template_key, audience, payload)
      select m.school_id, v_link.id::text, 'school_portal.link_requested:' || v_link.id,
        'in_app', 'school_portal.link_requested',
        jsonb_build_object('teacherId', v_teacher), jsonb_build_object('id', v_link.id)
      from public.memberships m
      where m.user_id = v_teacher and m.role = 'teacher' and m.active and m.status = 'active'
      order by m.created_at, m.id
      limit 1;
      v_status := 201;
      response := jsonb_build_object('linkId', v_link.id,
        'teacher', private.school_portal_person(v_teacher), 'status', 'pending');

    when 'cancelLink' then
      select * into v_link from private.school_portal_teacher_links where id = p_resource_id for update;
      if v_link.id is null or not private.school_portal_admin_ok(v_link.org_id) then
        return jsonb_build_object('outcome', 'not_found');
      end if;
      if private.school_portal_link_status(v_link.status, v_link.requested_at) <> 'pending' then
        return jsonb_build_object('outcome', 'conflict', 'reason', 'not_pending');
      end if;
      update private.school_portal_teacher_links
      set status = 'cancelled', ended_at = now(), ended_by = me where id = v_link.id;
      response := jsonb_build_object('linkId', v_link.id, 'status', 'cancelled');

    when 'decideLink' then
      select * into v_link from private.school_portal_teacher_links
      where id = p_resource_id and teacher_id = me for update;
      if v_link.id is null then
        return jsonb_build_object('outcome', 'not_found');
      end if;
      if private.school_portal_link_status(v_link.status, v_link.requested_at) <> 'pending' then
        return jsonb_build_object('outcome', 'conflict', 'reason', 'not_pending');
      end if;
      if body->>'decision' = 'decline' then
        update private.school_portal_teacher_links
        set status = 'declined', decided_at = now() where id = v_link.id;
        response := jsonb_build_object('linkId', v_link.id, 'status', 'declined');
      elsif body->>'decision' = 'accept' then
        if (select o.status from private.school_portal_orgs o where o.id = v_link.org_id) <> 'active' then
          return jsonb_build_object('outcome', 'conflict', 'reason', 'school_unavailable');
        end if;
        -- One school at a time: the teacher must agree to leave the current one.
        select l.id into v_current from private.school_portal_teacher_links l
        where l.teacher_id = me and l.status = 'linked' for update;
        if v_current is not null then
          if coalesce((body->>'replaceCurrent')::boolean, false) is not true then
            return jsonb_build_object('outcome', 'conflict', 'reason', 'linked_elsewhere',
              'current', (select jsonb_build_object('linkId', l.id, 'orgName', o.name)
                from private.school_portal_teacher_links l
                join private.school_portal_orgs o on o.id = l.org_id where l.id = v_current));
          end if;
          update private.school_portal_teacher_links
          set status = 'unlinked', ended_at = now(), ended_by = me where id = v_current;
        end if;
        update private.school_portal_teacher_links
        set status = 'linked', decided_at = now() where id = v_link.id;
        response := jsonb_build_object('linkId', v_link.id, 'status', 'linked',
          'replaced', v_current);
      else
        return jsonb_build_object('outcome', 'invalid', 'path', 'decision');
      end if;

    when 'endLink' then
      select * into v_link from private.school_portal_teacher_links where id = p_resource_id for update;
      if v_link.id is null or (v_link.teacher_id <> me
          and not private.school_portal_admin_ok(v_link.org_id)) then
        return jsonb_build_object('outcome', 'not_found');
      end if;
      if v_link.status <> 'linked' then
        return jsonb_build_object('outcome', 'conflict', 'reason', 'not_linked');
      end if;
      update private.school_portal_teacher_links
      set status = 'unlinked', ended_at = now(), ended_by = me where id = v_link.id;
      response := jsonb_build_object('linkId', v_link.id, 'status', 'unlinked');

    when 'recordExport' then
      -- Every export is recorded before the website builds the file.
      if not private.school_portal_admin_ok(p_resource_id) then
        return jsonb_build_object('outcome', 'not_found');
      end if;
      if body->>'kind' not in ('students', 'marks', 'attendance', 'reports', 'class')
         or body->>'format' not in ('csv', 'pdf') then
        return jsonb_build_object('outcome', 'invalid');
      end if;
      if body->>'kind' <> 'reports' and not private.school_portal_class_visible(
          p_resource_id, nullif(body->>'classroomId', '')::uuid) then
        return jsonb_build_object('outcome', 'not_found');
      end if;
      insert into private.school_portal_views(admin_id, org_id, classroom_id, view,
        export_kind, export_format)
      values (me, p_resource_id, nullif(body->>'classroomId', '')::uuid, 'export',
        body->>'kind', body->>'format');
      v_status := 201;
      response := jsonb_build_object('recorded', true);

    when 'reportOrg' then
      select * into v_link from private.school_portal_teacher_links
      where id = p_resource_id and teacher_id = me;
      if v_link.id is null then
        return jsonb_build_object('outcome', 'not_found');
      end if;
      if exists (select 1 from private.school_portal_reports r
          where r.reported_by = me and r.link_id = v_link.id) then
        return jsonb_build_object('outcome', 'conflict', 'reason', 'already_reported');
      end if;
      insert into private.school_portal_reports(org_id, link_id, reported_by, reason, details)
      values (v_link.org_id, v_link.id, me, body->>'reason',
        nullif(btrim(body->>'details'), '')) returning id into v_id;
      v_status := 201;
      response := jsonb_build_object('reportId', v_id);

    when 'suspendOrg' then
      if not private.is_platform_operator() then
        return jsonb_build_object('outcome', 'forbidden');
      end if;
      select * into v_org from private.school_portal_orgs where id = p_resource_id for update;
      if v_org.id is null or v_org.status = 'closed' then
        return jsonb_build_object('outcome', 'not_found');
      end if;
      if coalesce((body->>'suspend')::boolean, true) then
        update private.school_portal_orgs set status = 'suspended', suspended_at = now(),
          suspended_by = me, suspended_reason = nullif(btrim(body->>'reason'), ''),
          updated_at = now() where id = v_org.id;
      else
        update private.school_portal_orgs set status = 'active', suspended_at = null,
          suspended_by = null, suspended_reason = null, updated_at = now() where id = v_org.id;
      end if;
      response := jsonb_build_object('orgId', v_org.id,
        'status', (select status from private.school_portal_orgs where id = v_org.id));
    else
      return jsonb_build_object('outcome', 'invalid');
  end case;

  insert into public.audit_events(school_id, actor_id, action, entity_type, entity_id,
    after_value, request_id)
  values (null, me, 'school_portal_' || p_operation, 'school_portal',
    coalesce(p_resource_id, (response->>'id')::uuid),
    -- What was done - never a student's details.
    jsonb_strip_nulls(response - 'teacher'),
    nullif(current_setting('studafy.request_id', true), ''));
  if not private.api_idempotency_complete(
      p_idempotency_id, p_idempotency_generation, v_status, response) then
    raise exception 'API062_IDEMPOTENCY_COMPLETION_FAILED';
  end if;
  return jsonb_build_object('outcome', 'ok', 'status', v_status, 'response', response);
exception when invalid_text_representation or check_violation or not_null_violation then
  return jsonb_build_object('outcome', 'invalid');
end;
$$;

-- ---------------------------------------------------------------------------
-- 5. A deleted account: its links, reports, administrator seats and
--    activity go with it; an org left with no administrator closes.
-- ---------------------------------------------------------------------------

create or replace function private.school_portal_forget_deleted_profile()
returns trigger language plpgsql security definer set search_path = '' as $$
declare v_org uuid;
begin
  if new.status = 'deleted' and old.status is distinct from 'deleted' then
    delete from private.school_portal_teacher_links where teacher_id = new.id;
    delete from private.school_portal_reports where reported_by = new.id;
    delete from private.school_portal_views where admin_id = new.id;
    delete from private.school_portal_lookups where admin_id = new.id;
    for v_org in
      update private.school_portal_admins set removed_at = now(), removed_by = new.id
      where user_id = new.id and removed_at is null returning org_id
    loop
      if not exists (select 1 from private.school_portal_admins a
          where a.org_id = v_org and a.removed_at is null) then
        update private.school_portal_orgs set status = 'closed', closed_at = now(), updated_at = now()
        where id = v_org and status <> 'closed';
        perform private.school_portal_end_org_links(v_org, null);
      end if;
    end loop;
  end if;
  return new;
end;
$$;
create trigger school_portal_forget_deleted_profile
after update of status on public.profiles
for each row execute function private.school_portal_forget_deleted_profile();

-- ---------------------------------------------------------------------------
-- 6. Retention: waiting requests expire after 14 days; the activity record
--    and lookups are kept 12 months (TODO(legal): confirm the period).
-- ---------------------------------------------------------------------------

create or replace function private.school_portal_purge(p_limit integer)
returns jsonb language plpgsql security definer set search_path = '' as $$
declare v_expired int; v_views int; v_lookups int;
begin
  if p_limit is null or p_limit < 1 or p_limit > 10000 then
    raise exception 'SCHOOL_PORTAL_PURGE_LIMIT';
  end if;
  update private.school_portal_teacher_links set status = 'expired'
  where id in (select id from private.school_portal_teacher_links
    where status = 'pending' and requested_at <= now() - interval '14 days'
    order by requested_at limit p_limit);
  get diagnostics v_expired = row_count;
  delete from private.school_portal_views where id in (
    select id from private.school_portal_views where at < now() - interval '12 months'
    order by at limit p_limit);
  get diagnostics v_views = row_count;
  delete from private.school_portal_lookups where id in (
    select id from private.school_portal_lookups where at < now() - interval '12 months'
    order by at limit p_limit);
  get diagnostics v_lookups = row_count;
  return jsonb_build_object('school_portal_expired', v_expired,
    'school_portal_views', v_views, 'school_portal_lookups', v_lookups);
end;
$$;

-- ---------------------------------------------------------------------------
-- 7. The export gains one section: re-issued whole from 202611030040 with
--    only "schoolPortal" added at the end.
-- ---------------------------------------------------------------------------
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
                order by created_at desc limit 5000) u), '[]'::jsonb)),
      -- DL-076: AI answers the person reported, with what they wrote.
      'aiOutputReports', coalesce((
        select jsonb_agg(jsonb_build_object(
          'feature', r.feature, 'reason', r.reason, 'details', r.details,
          'excerpt', r.excerpt, 'status', r.status, 'filedAt', r.created_at
        ) order by r.created_at)
        from private.ai_output_reports r where r.reporter_id = p_user), '[]'::jsonb),
      -- School Portal: the schools a teacher was asked by or linked with, the
      -- reports they filed, and the schools a person administers with what
      -- they opened (the activity record, newest 5000).
      'schoolPortal', jsonb_build_object(
        'links', coalesce((select jsonb_agg(jsonb_build_object(
            'school', o.name, 'status', l.status, 'requestedAt', l.requested_at,
            'decidedAt', l.decided_at, 'endedAt', l.ended_at) order by l.requested_at)
          from private.school_portal_teacher_links l
          join private.school_portal_orgs o on o.id = l.org_id
          where l.teacher_id = p_user), '[]'::jsonb),
        'reports', coalesce((select jsonb_agg(jsonb_build_object(
            'school', o.name, 'reason', r.reason, 'details', r.details, 'filedAt', r.created_at)
            order by r.created_at)
          from private.school_portal_reports r
          join private.school_portal_orgs o on o.id = r.org_id
          where r.reported_by = p_user), '[]'::jsonb),
        'administered', coalesce((select jsonb_agg(jsonb_build_object(
            'school', o.name, 'country', o.country, 'city', o.city, 'kind', o.kind,
            'contactEmail', o.contact_email, 'status', o.status, 'jobTitle', a.job_title,
            'addedAt', a.added_at, 'removedAt', a.removed_at) order by a.added_at)
          from private.school_portal_admins a
          join private.school_portal_orgs o on o.id = a.org_id
          where a.user_id = p_user), '[]'::jsonb),
        'activity', coalesce((select jsonb_agg(jsonb_build_object(
            'view', v.view, 'classroomId', v.classroom_id, 'studentId', v.student_id,
            'fileId', v.file_id, 'itemId', v.item_id, 'exportKind', v.export_kind,
            'exportFormat', v.export_format, 'at', v.at) order by v.at)
          from (select * from private.school_portal_views where admin_id = p_user
                order by at desc limit 5000) v), '[]'::jsonb))
    )
  );
$$;

-- ---------------------------------------------------------------------------
-- 8. Grants: all owned by postgres and closed; the API reads and commands,
--    the worker purges.
-- ---------------------------------------------------------------------------
do $grants$
declare fn text;
begin
  foreach fn in array array[
    'private.school_portal_admin_ok(uuid)',
    'private.school_portal_visible_classes(uuid)',
    'private.school_portal_class_visible(uuid, uuid)',
    'private.school_portal_link_status(text, timestamp with time zone)',
    'private.school_portal_find_teacher(text)',
    'private.school_portal_person(uuid)',
    'private.school_portal_log(uuid, text, uuid, uuid, uuid, uuid)',
    'private.school_portal_files(uuid[])',
    'private.school_portal_class_json(uuid, uuid)',
    'private.school_portal_student_stats(uuid)',
    'private.school_portal_attention_reasons(bigint, bigint, numeric, bigint)',
    'private.school_portal_overview(uuid)',
    'private.school_portal_reports(uuid)',
    'private.school_portal_student_page(uuid, uuid)',
    'private.school_portal_teacher_page(uuid, uuid)',
    'private.school_portal_reserved(uuid, bigint)',
    'private.school_portal_confirm_adult(jsonb)',
    'private.school_portal_end_org_links(uuid, uuid)',
    'private.school_portal_forget_deleted_profile()',
    'private.school_portal_purge(integer)',
    'private.api062_query(text, uuid, jsonb)',
    'private.api062_command(text, uuid, jsonb, uuid, bigint)',
    'private.data_export_document(uuid)'
  ] loop
    execute format('alter function %s owner to postgres', fn);
    execute format('revoke all on function %s from public, anon, authenticated, service_role, studafy_api_runtime, studafy_worker_runtime', fn);
  end loop;
end
$grants$;

grant execute on function private.api062_query(text, uuid, jsonb),
  private.api062_command(text, uuid, jsonb, uuid, bigint)
  to studafy_api_runtime;
grant execute on function private.school_portal_purge(integer) to studafy_worker_runtime;

-- ---------------------------------------------------------------------------
-- 9. Opening files from the portal (plan 7.4, "Files").
--
-- An administrator opens a file only through FILE-051 delivery: a
-- single-use grant, a signed link that expires in minutes, and a second
-- authorization when the bytes are served. The portal's own grant names the
-- school it was issued for (portal_org_id), and at serving time the file
-- must still belong to a class of a teacher linked with that school, read
-- by a live administrator of it. Never a storage-signed URL.
-- ---------------------------------------------------------------------------

alter table public.file_delivery_grants
  add column if not exists portal_org_id uuid
    references private.school_portal_orgs(id) on delete cascade;

-- A file the org may open right now: bound (not detached) to something of a
-- visible class - a published lesson, an announcement, an assignment, a
-- student's hand-in, a test or one of its questions, or a mark's results.
-- Never a message's file, never a student's own notebook or upload session.
create or replace function private.school_portal_file_visible(p_org uuid, p_file uuid)
returns boolean language sql stable security definer set search_path = '' as $$
  with visible as (select id from private.school_portal_visible_classes(p_org) v(id))
  select exists (
    select 1 from public.file_bindings fb
    where fb.file_object_id = p_file and fb.detached_at is null and (
      exists (select 1 from public.resource_publications rp
        where rp.resource_version_id = fb.resource_version_id
          and rp.state::text = 'published' and rp.withdrawn_at is null
          and rp.classroom_id in (select id from visible))
      or exists (select 1 from public.announcements an
        where an.id = fb.announcement_id and an.deleted_at is null
          and an.classroom_id in (select id from visible))
      or exists (select 1 from public.assignments a
        where a.id = fb.assignment_id and a.deleted_at is null
          and a.classroom_id in (select id from visible))
      or exists (select 1 from public.submission_attempts sa
        join public.submissions sb on sb.id = sa.submission_id
        join public.assignments a on a.id = sb.assignment_id and a.deleted_at is null
        where sa.id = fb.submission_attempt_id and a.classroom_id in (select id from visible))
      or exists (select 1 from public.assessments t
        where t.id = fb.assessment_id and t.deleted_at is null
          and t.classroom_id in (select id from visible))
      or exists (select 1 from public.assessment_questions q
        join public.assessments t on t.id = q.assessment_id and t.deleted_at is null
        where q.id = fb.assessment_question_id and t.classroom_id in (select id from visible))
      or exists (select 1 from public.grade_results g
        join public.assessments t on t.id = g.assessment_id and t.deleted_at is null
        where g.id = fb.grade_result_id and t.classroom_id in (select id from visible))));
$$;

-- The portal's download grant: api051_create_download_grant's checks, with
-- the portal's authorization in place of a school member's.
create or replace function private.api062_file_download(
  p_org uuid, p_file_id uuid, p_internal jsonb,
  p_idempotency_id uuid, p_idempotency_generation bigint)
returns jsonb language plpgsql security definer set search_path = '' as $$
declare
  f public.file_objects%rowtype;
  expires timestamptz := (p_internal->>'expiresAt')::timestamptz;
  response jsonb;
  request_id text := nullif(current_setting('studafy.request_id', true), '');
  v_variant text := coalesce(p_internal->>'variant', 'original');
  v_media text;
  v_name text;
begin
  if auth.uid() is null or request_id is null or not private.is_active_user()
     or not private.school_portal_reserved(p_idempotency_id, p_idempotency_generation) then
    return jsonb_build_object('outcome', 'forbidden');
  end if;
  select * into f from public.file_objects fo where fo.id = p_file_id for update;
  -- Authorize before revealing anything about the object's state.
  if f.id is null or f.deleted_at is not null
     or not private.school_portal_admin_ok(p_org)
     or not private.school_portal_file_visible(p_org, p_file_id) then
    return jsonb_build_object('outcome', 'not_found');
  end if;
  if f.scan_state <> 'clean' then
    return jsonb_build_object('outcome', 'file_not_clean');
  end if;
  if (p_internal->>'nonceHash') is null or (p_internal->>'nonceHash') !~ '^[0-9a-f]{64}$'
    or (p_internal->>'downloadUrl') is null
    or expires is null or expires <= now() + interval '30 seconds'
    or expires > now() + interval '10 minutes'
    or v_variant not in ('original', 'preview') then
    return jsonb_build_object('outcome', 'invalid');
  end if;
  if f.dedup_source_file_id is not null and not coalesce(
    (private.file051_effective_object(p_file_id)->>'rootClean')::boolean, false) then
    return jsonb_build_object('outcome', 'invalid_state');
  end if;

  v_media := f.detected_media_type;
  v_name := f.display_name;
  if v_variant = 'preview' then
    if f.detected_media_type = 'application/pdf' then
      v_variant := 'original';
    elsif exists (
      select 1 from private.file_renditions r
      where r.file_object_id = coalesce(f.dedup_source_file_id, f.id)
        and r.kind = 'pdf_preview' and r.status = 'ready') then
      v_media := 'application/pdf';
      v_name := private.file_preview_name(f.display_name);
    else
      return jsonb_build_object('outcome', 'preview_unavailable');
    end if;
  end if;

  insert into public.file_delivery_grants(
    school_id, file_object_id, recipient_id, nonce_hash, expires_at, request_id,
    variant, portal_org_id)
  values (f.school_id, f.id, auth.uid(), p_internal->>'nonceHash', expires,
    request_id, v_variant, p_org);
  perform private.school_portal_log(p_org, 'file', null, null, f.id);

  response := jsonb_build_object(
    'downloadUrl', p_internal->>'downloadUrl', 'expiresAt', expires,
    'displayName', v_name, 'mediaType', v_media);
  -- In the teacher's school's audit trail too: a school opened this file.
  insert into public.audit_events(school_id, actor_id, action, entity_type, entity_id, after_value, request_id)
  values (f.school_id, auth.uid(), 'file_download_grant_issued', 'file_object', f.id,
    jsonb_build_object('reason', 'school_portal', 'portalOrgId', p_org,
      'expiresAt', expires, 'variant', v_variant), request_id);
  if not private.api_idempotency_complete(p_idempotency_id, p_idempotency_generation, 200, response) then
    raise exception 'API062_IDEMPOTENCY_COMPLETION_FAILED';
  end if;
  return jsonb_build_object('outcome', 'ok', 'response', response);
end;
$$;

-- As 202611030060, with one addition: a grant issued by the portal is
-- re-authorized by the portal's own rule (still an administrator, file still
-- in a linked class) when a school member's rule does not admit the caller.
create or replace function private.api051_consume_download_grant(
  p_file_id uuid, p_nonce_hash text)
returns jsonb language plpgsql security definer set search_path = '' as $$
declare
  f public.file_objects%rowtype;
  authz jsonb;
  effective jsonb;
  request_id text := nullif(current_setting('studafy.request_id', true), '');
  v_variant text;
  v_portal_org uuid;
  r private.file_renditions%rowtype;
begin
  if auth.uid() is null or p_nonce_hash is null or p_nonce_hash !~ '^[0-9a-f]{64}$' then
    return jsonb_build_object('outcome', 'grant_invalid');
  end if;
  update public.file_delivery_grants
    set state = 'consumed', consumed_at = now()
    where nonce_hash = p_nonce_hash and file_object_id = p_file_id
      and recipient_id = auth.uid() and state = 'available' and expires_at > now()
    returning variant, portal_org_id into v_variant, v_portal_org;
  if not found then
    return jsonb_build_object('outcome', 'grant_invalid');
  end if;

  select * into f from public.file_objects fo where fo.id = p_file_id;
  if f.id is null or f.deleted_at is not null or f.scan_state <> 'clean' then
    return jsonb_build_object('outcome', 'not_found');
  end if;
  if v_portal_org is not null then
    -- A portal grant is served only by the portal's rule, never widened by
    -- whatever else the administrator might be.
    authz := case when private.school_portal_admin_ok(v_portal_org)
        and private.school_portal_file_visible(v_portal_org, p_file_id)
      then jsonb_build_object('allowed', true, 'reason', 'school_portal')
      else jsonb_build_object('allowed', false) end;
  else
    authz := private.file051_authorize_download(p_file_id);
  end if;
  if not coalesce((authz->>'allowed')::boolean, false) then
    return jsonb_build_object('outcome', 'not_found');
  end if;
  effective := private.file051_effective_object(p_file_id);
  if not coalesce((effective->>'rootClean')::boolean, false)
    or (effective->>'objectKey') is null then
    return jsonb_build_object('outcome', 'invalid_state');
  end if;
  if v_variant = 'preview' then
    select * into r from private.file_renditions x
    where x.file_object_id = coalesce(f.dedup_source_file_id, f.id)
      and x.kind = 'pdf_preview' and x.status = 'ready';
    if r.id is null then
      return jsonb_build_object('outcome', 'not_found');
    end if;
    effective := jsonb_build_object(
      'schoolId', f.school_id, 'bucket', r.bucket, 'objectKey', r.storage_path,
      'storedSha256', r.sha256, 'storedSizeBytes', r.size_bytes,
      'mediaType', 'application/pdf',
      'displayName', private.file_preview_name(f.display_name),
      'rootClean', true);
  end if;
  insert into public.audit_events(school_id, actor_id, action, entity_type, entity_id, after_value, request_id)
  values (f.school_id, auth.uid(), 'file_download_delivered', 'file_object', f.id,
    jsonb_strip_nulls(jsonb_build_object('reason', authz->>'reason', 'variant', v_variant,
      'portalOrgId', v_portal_org)), request_id);
  return jsonb_build_object('outcome', 'ok', 'response', effective);
end;
$$;

do $grants$
declare fn text;
begin
  foreach fn in array array[
    'private.school_portal_file_visible(uuid, uuid)',
    'private.api062_file_download(uuid, uuid, jsonb, uuid, bigint)',
    'private.api051_consume_download_grant(uuid, text)'
  ] loop
    execute format('alter function %s owner to postgres', fn);
    execute format('revoke all on function %s from public, anon, authenticated, service_role, studafy_api_runtime, studafy_worker_runtime', fn);
  end loop;
end
$grants$;
grant execute on function private.api062_file_download(uuid, uuid, jsonb, uuid, bigint),
  private.api051_consume_download_grant(uuid, text)
  to studafy_api_runtime;

-- ---------------------------------------------------------------------------
-- 10. Notices (plan step 3). The teacher hears about a school's request;
--     nobody else is told anything. Re-issued whole from 202609300001 with
--     only the School Portal branch added at the top.
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

  -- Studafy School Portal: a school asked a teacher to link. Only the
  -- teacher named on the request, and only while it still waits; never a
  -- student, a parent or anyone at the teacher's school.
  if p_template = 'school_portal.link_requested' then
    return (
      select coalesce(array_agg(l.teacher_id), array[]::uuid[])
      from private.school_portal_teacher_links l
      join public.profiles p on p.id = l.teacher_id and p.status = 'active'
      where l.id = v_source
        and (p_audience->>'teacherId') = l.teacher_id::text
        and private.school_portal_link_status(l.status, l.requested_at) = 'pending');
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

-- A teacher reporting a school alerts the operator (the safety reports'
-- Telegram relay, as private.ai_output_alerts_* in 202611030040). The alert
-- carries the report id, the school's id and the reason: never the
-- teacher's words or anyone's name.
create table private.school_portal_report_alerts (
  report_id uuid primary key
    references private.school_portal_reports(id) on delete cascade,
  created_at timestamptz not null default now(),
  attempts integer not null default 0 check (attempts >= 0),
  claimed_until timestamptz,
  sent_at timestamptz,
  last_error text check (last_error is null or last_error ~ '^[A-Z0-9_]{1,64}$')
);
create index school_portal_report_alerts_pending_idx
  on private.school_portal_report_alerts (created_at) where sent_at is null;
alter table private.school_portal_report_alerts enable row level security;
alter table private.school_portal_report_alerts force row level security;
revoke all on private.school_portal_report_alerts from public, anon, authenticated,
  service_role, studafy_api_runtime, studafy_worker_runtime;

create or replace function private.school_portal_alerts_enqueue()
returns trigger language plpgsql security definer set search_path = '' as $$
begin
  insert into private.school_portal_report_alerts (report_id) values (new.id)
  on conflict (report_id) do nothing;
  return new;
end;
$$;
create trigger school_portal_reports_alert_on_insert
  after insert on private.school_portal_reports
  for each row execute function private.school_portal_alerts_enqueue();

create or replace function private.school_portal_alerts_claim(
  p_limit integer, p_lease_seconds integer)
returns table (report_id uuid, org_id uuid, reason text, reported_at timestamptz,
  attempts integer)
language plpgsql security definer set search_path = '' as $$
#variable_conflict use_column
begin
  if p_limit is null or p_limit not between 1 and 100
     or p_lease_seconds is null or p_lease_seconds not between 10 and 3600 then
    raise exception 'SCHOOL_PORTAL_ALERTS_INVALID_CLAIM';
  end if;
  return query
  with due as (
    select a.report_id from private.school_portal_report_alerts a
    where a.sent_at is null and (a.claimed_until is null or a.claimed_until <= now())
    order by a.created_at limit p_limit
    for update skip locked
  ), claimed as (
    update private.school_portal_report_alerts a
    set claimed_until = now() + make_interval(secs => p_lease_seconds),
        attempts = a.attempts + 1
    from due where a.report_id = due.report_id
    returning a.report_id, a.attempts
  )
  select c.report_id, r.org_id, r.reason, r.created_at, c.attempts
  from claimed c join private.school_portal_reports r on r.id = c.report_id
  order by r.created_at;
end;
$$;

create or replace function private.school_portal_alerts_finish(
  p_report uuid, p_sent boolean, p_error text)
returns boolean language plpgsql security definer set search_path = '' as $$
declare v_attempts integer;
begin
  if p_sent then
    update private.school_portal_report_alerts
    set sent_at = now(), claimed_until = null, last_error = null
    where report_id = p_report and sent_at is null;
    return found;
  end if;
  update private.school_portal_report_alerts
  set claimed_until = now() + make_interval(
        mins => least(30, power(2, greatest(attempts - 1, 0))::integer)),
      last_error = case when p_error ~ '^[A-Z0-9_]{1,64}$' then p_error else 'SEND_FAILED' end
  where report_id = p_report and sent_at is null
  returning attempts into v_attempts;
  return v_attempts is not null;
end;
$$;

create or replace function private.school_portal_alerts_backlog()
returns jsonb language sql stable security definer set search_path = '' as $$
  select jsonb_build_object('unsent', count(*),
    'oldestSeconds', coalesce(extract(epoch from now() - min(a.created_at))::bigint, 0))
  from private.school_portal_report_alerts a where a.sent_at is null;
$$;

do $grants$
declare fn text;
begin
  foreach fn in array array[
    'private.api061_notification_recipients(uuid, text, text, jsonb)',
    'private.school_portal_alerts_enqueue()',
    'private.school_portal_alerts_claim(integer, integer)',
    'private.school_portal_alerts_finish(uuid, boolean, text)',
    'private.school_portal_alerts_backlog()'
  ] loop
    execute format('alter function %s owner to postgres', fn);
    execute format('revoke all on function %s from public, anon, authenticated, service_role, studafy_api_runtime, studafy_worker_runtime', fn);
  end loop;
end
$grants$;
grant execute on function private.school_portal_alerts_claim(integer, integer),
  private.school_portal_alerts_finish(uuid, boolean, text),
  private.school_portal_alerts_backlog()
  to studafy_worker_runtime;
