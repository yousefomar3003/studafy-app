create table public.practice_sessions (
  id uuid primary key default gen_random_uuid(),
  student_id uuid not null references public.students(id) on delete cascade,
  classroom_id uuid not null references public.classrooms(id) on delete cascade,
  topic text not null,
  kind text not null check (kind in ('quiz', 'flashcards')),
  item_count integer not null check (item_count > 0),
  correct_count integer,
  completed_at timestamptz,
  created_at timestamptz not null default now()
);
alter table public.practice_sessions enable row level security;
create policy "practice own" on public.practice_sessions for select
using (public.can_access_student(student_id));
-- Sessions are created by the Study Coach function after verifying enrollment.
