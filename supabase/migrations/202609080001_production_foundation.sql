create extension if not exists pgcrypto;

create type public.app_role as enum ('teacher', 'parent', 'student');
create type public.link_status as enum ('pending', 'verified', 'declined', 'revoked');
create type public.publication_state as enum ('draft', 'reviewed', 'published');
create type public.attendance_state as enum ('present', 'absent', 'late', 'excused');
create type public.meeting_audience as enum ('students', 'guardians', 'both');

create table public.schools (
  id uuid primary key default gen_random_uuid(),
  name text not null,
  timezone text not null default 'Asia/Riyadh',
  created_at timestamptz not null default now()
);

create table public.profiles (
  id uuid primary key references auth.users(id) on delete cascade,
  display_name text not null,
  locale text not null default 'en' check (locale in ('en', 'ar')),
  created_at timestamptz not null default now()
);

create table public.memberships (
  id uuid primary key default gen_random_uuid(),
  school_id uuid not null references public.schools(id) on delete cascade,
  user_id uuid not null references public.profiles(id) on delete cascade,
  role public.app_role not null,
  active boolean not null default true,
  created_at timestamptz not null default now(),
  unique (school_id, user_id, role)
);

create table public.terms (
  id uuid primary key default gen_random_uuid(),
  school_id uuid not null references public.schools(id) on delete cascade,
  name text not null,
  starts_on date not null,
  ends_on date not null,
  active boolean not null default false,
  unique (school_id, name)
);

create table public.students (
  id uuid primary key default gen_random_uuid(),
  school_id uuid references public.schools(id) on delete restrict,
  user_id uuid references public.profiles(id) on delete set null,
  studafy_id text not null unique,
  display_name text not null,
  provisional boolean not null default true,
  created_by uuid not null references public.profiles(id),
  created_at timestamptz not null default now()
);

create table public.guardian_links (
  id uuid primary key default gen_random_uuid(),
  student_id uuid not null references public.students(id) on delete cascade,
  guardian_id uuid not null references public.profiles(id) on delete cascade,
  status public.link_status not null default 'pending',
  relationship text,
  verified_by uuid references public.profiles(id),
  verified_at timestamptz,
  unique (student_id, guardian_id)
);

create table public.classrooms (
  id uuid primary key default gen_random_uuid(),
  school_id uuid not null references public.schools(id) on delete cascade,
  term_id uuid not null references public.terms(id) on delete restrict,
  name text not null,
  grade text,
  section text,
  teacher_id uuid not null references public.profiles(id),
  archived_at timestamptz
);

create table public.enrollments (
  classroom_id uuid not null references public.classrooms(id) on delete cascade,
  student_id uuid not null references public.students(id) on delete cascade,
  active boolean not null default true,
  primary key (classroom_id, student_id)
);

create table public.lesson_sessions (
  id uuid primary key default gen_random_uuid(),
  classroom_id uuid not null references public.classrooms(id) on delete cascade,
  starts_at timestamptz not null,
  ends_at timestamptz not null,
  title text,
  filed_at timestamptz,
  unique (classroom_id, starts_at)
);

create table public.lesson_materials (
  id uuid primary key default gen_random_uuid(),
  session_id uuid not null references public.lesson_sessions(id) on delete cascade,
  title text not null,
  body text,
  storage_path text,
  media_type text,
  created_by uuid not null references public.profiles(id),
  created_at timestamptz not null default now()
);

create table public.assignments (
  id uuid primary key default gen_random_uuid(),
  classroom_id uuid not null references public.classrooms(id) on delete cascade,
  title text not null,
  instructions text,
  due_at timestamptz not null,
  state public.publication_state not null default 'draft',
  created_by uuid not null references public.profiles(id),
  published_at timestamptz
);

create table public.submissions (
  id uuid primary key default gen_random_uuid(),
  assignment_id uuid not null references public.assignments(id) on delete cascade,
  student_id uuid not null references public.students(id) on delete cascade,
  submitted_at timestamptz,
  excused boolean not null default false,
  unique (assignment_id, student_id)
);

create table public.assessments (
  id uuid primary key default gen_random_uuid(),
  classroom_id uuid not null references public.classrooms(id) on delete cascade,
  title text not null,
  category text not null,
  maximum_score numeric(8,2) not null check (maximum_score > 0),
  category_weight numeric(5,2),
  scheduled_at timestamptz,
  state public.publication_state not null default 'draft',
  delivery text not null default 'paper' check (delivery in ('paper', 'practice')),
  created_by uuid not null references public.profiles(id),
  published_at timestamptz
);

create table public.assessment_questions (
  id uuid primary key default gen_random_uuid(),
  assessment_id uuid not null references public.assessments(id) on delete cascade,
  position integer not null,
  prompt text not null,
  preferred_answer text,
  maximum_score numeric(8,2) not null check (maximum_score > 0),
  unique (assessment_id, position)
);

create table public.grade_results (
  id uuid primary key default gen_random_uuid(),
  assessment_id uuid not null references public.assessments(id) on delete cascade,
  student_id uuid not null references public.students(id) on delete cascade,
  score numeric(8,2) not null,
  state public.publication_state not null default 'draft',
  feedback text,
  reviewed_by uuid references public.profiles(id),
  reviewed_at timestamptz,
  published_at timestamptz,
  unique (assessment_id, student_id)
);

create table public.attendance_records (
  id uuid primary key default gen_random_uuid(),
  session_id uuid not null references public.lesson_sessions(id) on delete cascade,
  student_id uuid not null references public.students(id) on delete cascade,
  state public.attendance_state not null,
  reason text,
  recorded_by uuid not null references public.profiles(id),
  recorded_at timestamptz not null default now(),
  unique (session_id, student_id)
);

create table public.wellbeing_events (
  id uuid primary key default gen_random_uuid(),
  student_id uuid not null references public.students(id) on delete cascade,
  classroom_id uuid references public.classrooms(id) on delete set null,
  kind text not null check (kind in ('strength', 'concern', 'note')),
  title text not null,
  context text,
  follow_up text,
  created_by uuid not null references public.profiles(id),
  created_at timestamptz not null default now()
);

create table public.announcements (
  id uuid primary key default gen_random_uuid(),
  school_id uuid not null references public.schools(id) on delete cascade,
  classroom_id uuid references public.classrooms(id) on delete cascade,
  title text not null,
  body text not null,
  audience public.meeting_audience not null default 'both',
  important boolean not null default false,
  published_at timestamptz not null default now(),
  created_by uuid not null references public.profiles(id)
);

create table public.meetings (
  id uuid primary key default gen_random_uuid(),
  classroom_id uuid not null references public.classrooms(id) on delete cascade,
  title text not null,
  starts_at timestamptz not null,
  ends_at timestamptz not null,
  audience public.meeting_audience not null,
  calendar_event_id text,
  meet_url text,
  state text not null default 'pending' check (state in ('pending', 'scheduled', 'cancelled', 'failed')),
  created_by uuid not null references public.profiles(id),
  created_at timestamptz not null default now()
);

create table public.notifications (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references public.profiles(id) on delete cascade,
  kind text not null,
  title text not null,
  body text not null,
  route text,
  entity_id uuid,
  read_at timestamptz,
  created_at timestamptz not null default now()
);

create table public.ai_grading_drafts (
  id uuid primary key default gen_random_uuid(),
  grade_result_id uuid not null references public.grade_results(id) on delete cascade,
  private_scan_path text not null,
  strictness text not null check (strictness in ('strict', 'balanced', 'lenient')),
  model_version text not null,
  status text not null default 'processing' check (status in ('processing', 'ready', 'failed', 'approved')),
  created_by uuid not null references public.profiles(id),
  created_at timestamptz not null default now()
);

create table public.question_suggestions (
  id uuid primary key default gen_random_uuid(),
  draft_id uuid not null references public.ai_grading_drafts(id) on delete cascade,
  question_id uuid not null references public.assessment_questions(id) on delete cascade,
  proposed_score numeric(8,2) not null,
  confidence numeric(5,4) not null check (confidence between 0 and 1),
  rationale text not null,
  teacher_score numeric(8,2),
  override_reason text,
  unique (draft_id, question_id)
);

create table public.subscription_entitlements (
  user_id uuid primary key references public.profiles(id) on delete cascade,
  product_id text not null,
  source text not null check (source in ('app_store', 'play_store', 'school')),
  active boolean not null default false,
  expires_at timestamptz,
  verified_at timestamptz not null default now()
);

create table public.audit_events (
  id bigint generated always as identity primary key,
  school_id uuid references public.schools(id) on delete restrict,
  actor_id uuid references public.profiles(id) on delete set null,
  action text not null,
  entity_type text not null,
  entity_id uuid,
  before_value jsonb,
  after_value jsonb,
  created_at timestamptz not null default now()
);

create or replace function public.is_school_member(target_school uuid, allowed_roles public.app_role[] default null)
returns boolean language sql stable security definer set search_path = '' as $$
  select exists (
    select 1 from public.memberships m
    where m.school_id = target_school and m.user_id = auth.uid() and m.active
      and (allowed_roles is null or m.role = any(allowed_roles))
  );
$$;

create or replace function public.can_access_student(target_student uuid)
returns boolean language sql stable security definer set search_path = '' as $$
  select exists (
    select 1 from public.students s where s.id = target_student and (
      s.user_id = auth.uid()
      or exists (select 1 from public.guardian_links g where g.student_id=s.id and g.guardian_id=auth.uid() and g.status='verified')
      or public.is_school_member(s.school_id, array['teacher']::public.app_role[])
    )
  );
$$;

alter table public.schools enable row level security;
alter table public.profiles enable row level security;
alter table public.memberships enable row level security;
alter table public.terms enable row level security;
alter table public.students enable row level security;
alter table public.guardian_links enable row level security;
alter table public.classrooms enable row level security;
alter table public.enrollments enable row level security;
alter table public.lesson_sessions enable row level security;
alter table public.lesson_materials enable row level security;
alter table public.assignments enable row level security;
alter table public.submissions enable row level security;
alter table public.assessments enable row level security;
alter table public.assessment_questions enable row level security;
alter table public.grade_results enable row level security;
alter table public.attendance_records enable row level security;
alter table public.wellbeing_events enable row level security;
alter table public.announcements enable row level security;
alter table public.meetings enable row level security;
alter table public.notifications enable row level security;
alter table public.ai_grading_drafts enable row level security;
alter table public.question_suggestions enable row level security;
alter table public.subscription_entitlements enable row level security;
alter table public.audit_events enable row level security;

create policy "profiles read self" on public.profiles for select using (id = auth.uid());
create policy "profiles update self" on public.profiles for update using (id = auth.uid()) with check (id = auth.uid());
create policy "memberships read self" on public.memberships for select using (user_id = auth.uid());
create policy "students read authorized" on public.students for select using (public.can_access_student(id));
create policy "guardians read own links" on public.guardian_links for select using (guardian_id = auth.uid() or public.can_access_student(student_id));
create policy "guardians request link" on public.guardian_links for insert with check (guardian_id = auth.uid() and status = 'pending');
create policy "notifications read own" on public.notifications for select using (user_id = auth.uid());
create policy "notifications update own" on public.notifications for update using (user_id = auth.uid()) with check (user_id = auth.uid());
create policy "entitlements read own" on public.subscription_entitlements for select using (user_id = auth.uid());
create policy "grades read published authorized" on public.grade_results for select using (state = 'published' and public.can_access_student(student_id));
create policy "attendance read authorized" on public.attendance_records for select using (public.can_access_student(student_id));
create policy "wellbeing read authorized" on public.wellbeing_events for select using (public.can_access_student(student_id));
create policy "submissions read authorized" on public.submissions for select using (public.can_access_student(student_id));

-- Teacher/admin write paths and recipient expansion run through audited Edge
-- Functions. Client tables intentionally have no broad write policies.

insert into storage.buckets (id, name, public)
values ('private-school-files', 'private-school-files', false)
on conflict (id) do nothing;
