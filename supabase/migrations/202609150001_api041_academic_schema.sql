-- API-041 expand step. Forward-only additions needed by authoritative academic
-- commands; existing client grants and RLS policies are not widened.

alter type public.publication_state add value if not exists 'withdrawn';

alter table public.classrooms
  add column if not exists room text,
  add column if not exists version bigint not null default 1;
alter table public.classrooms
  add constraint api041_classrooms_version_check check (version > 0) not valid;
alter table public.classrooms
  add constraint api041_classrooms_room_length check (room is null or length(room) <= 80) not valid;

alter table public.lesson_sessions
  add column if not exists version bigint not null default 1;
alter table public.lesson_sessions
  add constraint api041_lesson_sessions_version_check check (version > 0) not valid;

alter table public.resource_publications
  add column if not exists version bigint not null default 1;
alter table public.resource_publications
  add constraint api041_resource_publications_version_check check (version > 0) not valid;

alter table public.resources
  add column if not exists version bigint not null default 1;
alter table public.resources
  add constraint api041_resources_version_check check (version > 0) not valid;

alter table public.grade_results alter column score drop not null;
alter table public.grade_results
  add constraint api041_grade_scored_state_check check (
    state = 'draft' or (
      score is not null and reviewed_by is not null and reviewed_at is not null
    )
  ) not valid;

alter table public.assessments drop constraint if exists assessments_delivery_check;
alter table public.assessments add constraint api041_assessment_delivery_check
  check (delivery in ('paper', 'online', 'practice')) not valid;

alter table public.assignments
  add constraint api041_assignment_window_check
  check (closes_at is null or closes_at >= due_at) not valid;

create table public.assessment_attempts (
  id uuid primary key default gen_random_uuid(),
  school_id uuid not null references public.schools(id) on delete cascade,
  assessment_id uuid not null,
  student_id uuid not null,
  operation_id uuid not null,
  submitted_at timestamptz not null default now(),
  version bigint not null default 1 check (version > 0),
  created_at timestamptz not null default now(),
  unique (assessment_id, student_id, operation_id),
  unique (school_id, id),
  foreign key (school_id, assessment_id)
    references public.assessments(school_id, id) on delete cascade,
  foreign key (school_id, student_id)
    references public.students(school_id, id) on delete cascade
);

create table public.assessment_answers (
  school_id uuid not null references public.schools(id) on delete cascade,
  attempt_id uuid not null,
  question_id uuid not null,
  answer_text text not null check (length(answer_text) <= 30000),
  created_at timestamptz not null default now(),
  primary key (attempt_id, question_id),
  foreign key (school_id, attempt_id)
    references public.assessment_attempts(school_id, id) on delete cascade,
  foreign key (school_id, question_id)
    references public.assessment_questions(school_id, id) on delete cascade
);

alter table public.assessment_attempts enable row level security;
alter table public.assessment_answers enable row level security;

create or replace function private.api041_reject_history_change()
returns trigger language plpgsql security invoker set search_path='' as $$
begin
  raise exception 'API041_IMMUTABLE_HISTORY';
end;
$$;

-- resource_versions, submission_attempts and grade_result_events already
-- carry the db020_reject_mutation append-only guard; duplicating it here would
-- change which exception surfaces first. Only the new API-041 history tables
-- get this guard.
create trigger api041_immutable_assessment_attempt before update or delete on public.assessment_attempts
  for each row execute function private.api041_reject_history_change();
create trigger api041_immutable_assessment_answer before update or delete on public.assessment_answers
  for each row execute function private.api041_reject_history_change();

alter function private.api041_reject_history_change() owner to postgres;
revoke all on function private.api041_reject_history_change()
from public,anon,authenticated,service_role,studafy_api_runtime,studafy_worker_runtime;

-- DB-020's validated same-school UNIQUE constraints already own matching
-- (school_id, id) btree indexes for every API-041 UUID cursor. Do not create
-- redundant indexes; the API-041 plan gate asserts those exact indexes remain
-- selected at synthetic scale.

revoke all privileges on public.assessment_attempts, public.assessment_answers
from public, anon, authenticated, service_role,
  studafy_api_runtime, studafy_worker_runtime;
-- API-041 creates no sequences, and DB-021 deliberately grants the service
-- role the audit identity sequence, so the runtime is the only role whose
-- sequence surface is re-asserted here.
revoke all privileges on all sequences in schema public
from studafy_api_runtime;

alter table public.classrooms validate constraint api041_classrooms_version_check;
alter table public.classrooms validate constraint api041_classrooms_room_length;
alter table public.lesson_sessions validate constraint api041_lesson_sessions_version_check;
alter table public.resource_publications validate constraint api041_resource_publications_version_check;
alter table public.resources validate constraint api041_resources_version_check;
alter table public.grade_results validate constraint api041_grade_scored_state_check;
alter table public.assessments validate constraint api041_assessment_delivery_check;
alter table public.assignments validate constraint api041_assignment_window_check;
