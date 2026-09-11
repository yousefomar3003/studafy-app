-- DB-020 constraint step: candidate keys, tenant-consistent relationships,
-- lifecycle checks, and immutable-history enforcement.

create or replace function public.sync_membership_lifecycle()
returns trigger
language plpgsql
security invoker
set search_path = ''
as $$
begin
  if tg_op = 'INSERT' or new.status is null then
    new.status := case when new.active then 'active' else 'suspended' end;
  elsif new.status is distinct from old.status and new.active is not distinct from old.active then
    new.active := new.status = 'active';
  elsif new.active is distinct from old.active and new.status is not distinct from old.status then
    new.status := case when new.active then 'active' else 'suspended' end;
  end if;
  return new;
end;
$$;

create or replace function public.sync_term_lifecycle()
returns trigger
language plpgsql
security invoker
set search_path = ''
as $$
begin
  if tg_op = 'INSERT' or new.status is null then
    new.status := case
      when new.active then 'active'::public.term_status
      when new.ends_on < current_date then 'closed'::public.term_status
      else 'planned'::public.term_status
    end;
  elsif new.status is distinct from old.status and new.active is not distinct from old.active then
    new.active := new.status = 'active';
  elsif new.active is distinct from old.active and new.status is not distinct from old.status then
    new.status := case
      when new.active then 'active'::public.term_status
      when new.ends_on < current_date then 'closed'::public.term_status
      else 'planned'::public.term_status
    end;
  end if;
  return new;
end;
$$;

create or replace function public.sync_enrollment_lifecycle()
returns trigger
language plpgsql
security invoker
set search_path = ''
as $$
begin
  if tg_op = 'INSERT' or new.status is null then
    new.status := case when new.active then 'active' else 'withdrawn' end;
  elsif new.status is distinct from old.status and new.active is not distinct from old.active then
    new.active := new.status = 'active';
  elsif new.active is distinct from old.active and new.status is not distinct from old.status then
    new.status := case when new.active then 'active' else 'withdrawn' end;
  end if;
  return new;
end;
$$;

create or replace function public.sync_classroom_lifecycle()
returns trigger
language plpgsql
security invoker
set search_path = ''
as $$
begin
  if tg_op = 'INSERT' or new.status is null then
    new.status := case when new.archived_at is null then 'active' else 'archived' end;
  elsif new.status = 'archived' and new.archived_at is null then
    new.archived_at := now();
  elsif new.status <> 'archived' then
    new.archived_at := null;
  end if;
  return new;
end;
$$;

create or replace function public.sync_submission_lifecycle()
returns trigger
language plpgsql
security invoker
set search_path = ''
as $$
begin
  if tg_op = 'INSERT' or new.status is null then
    new.status := case
      when new.excused then 'excused'::public.submission_status
      when new.submitted_at is not null then 'submitted'::public.submission_status
      else 'open'::public.submission_status
    end;
  elsif new.status = 'excused' then
    new.excused := true;
  elsif new.status = 'submitted' then
    new.excused := false;
  end if;
  return new;
end;
$$;

create or replace function public.sync_grade_publication_actor()
returns trigger
language plpgsql
security invoker
set search_path = ''
as $$
begin
  if new.state = 'published' and new.published_by is null then
    new.published_by := new.reviewed_by;
  end if;
  return new;
end;
$$;

create or replace function public.derive_school_id()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
declare
  derived_school uuid;
  second_school uuid;
begin
  case tg_table_name
    when 'guardian_links' then
      select school_id into derived_school from public.students where id = new.student_id;
    when 'enrollments' then
      select school_id into derived_school from public.classrooms where id = new.classroom_id;
      select school_id into second_school from public.students where id = new.student_id;
    when 'lesson_sessions' then
      select school_id into derived_school from public.classrooms where id = new.classroom_id;
    when 'lesson_materials' then
      select school_id into derived_school from public.lesson_sessions where id = new.session_id;
    when 'assignments' then
      select school_id into derived_school from public.classrooms where id = new.classroom_id;
    when 'submissions' then
      select school_id into derived_school from public.assignments where id = new.assignment_id;
      select school_id into second_school from public.students where id = new.student_id;
    when 'assessments' then
      select school_id into derived_school from public.classrooms where id = new.classroom_id;
    when 'assessment_questions' then
      select school_id into derived_school from public.assessments where id = new.assessment_id;
    when 'grade_results' then
      select school_id into derived_school from public.assessments where id = new.assessment_id;
      select school_id into second_school from public.students where id = new.student_id;
    when 'attendance_records' then
      select school_id into derived_school from public.lesson_sessions where id = new.session_id;
      select school_id into second_school from public.students where id = new.student_id;
    when 'wellbeing_events' then
      select school_id into derived_school from public.students where id = new.student_id;
      if new.classroom_id is not null then
        select school_id into second_school from public.classrooms where id = new.classroom_id;
      end if;
    when 'meetings' then
      select school_id into derived_school from public.classrooms where id = new.classroom_id;
    when 'meeting_deliveries' then
      select school_id into derived_school from public.meetings where id = new.meeting_id;
    when 'ai_grading_drafts' then
      select school_id into derived_school from public.grade_results where id = new.grade_result_id;
    when 'question_suggestions' then
      select school_id into derived_school from public.ai_grading_drafts where id = new.draft_id;
      select school_id into second_school from public.assessment_questions where id = new.question_id;
    when 'practice_sessions' then
      select school_id into derived_school from public.classrooms where id = new.classroom_id;
      select school_id into second_school from public.students where id = new.student_id;
    else
      raise exception 'Unsupported tenant derivation table';
  end case;

  if derived_school is null
     or (second_school is not null and second_school <> derived_school)
     or (new.school_id is not null and new.school_id <> derived_school) then
    raise exception 'Cross-school or unresolved relationship';
  end if;
  new.school_id := derived_school;
  return new;
end;
$$;

revoke execute on function public.sync_membership_lifecycle()
from public, anon, authenticated;
revoke execute on function public.sync_term_lifecycle()
from public, anon, authenticated;
revoke execute on function public.sync_enrollment_lifecycle()
from public, anon, authenticated;
revoke execute on function public.sync_classroom_lifecycle()
from public, anon, authenticated;
revoke execute on function public.sync_submission_lifecycle()
from public, anon, authenticated;
revoke execute on function public.sync_grade_publication_actor()
from public, anon, authenticated;
revoke execute on function public.derive_school_id()
from public, anon, authenticated;

create trigger db020_sync_membership_lifecycle
before insert or update of active, status on public.memberships
for each row execute function public.sync_membership_lifecycle();
create trigger db020_sync_term_lifecycle
before insert or update of active, status, ends_on on public.terms
for each row execute function public.sync_term_lifecycle();
create trigger db020_sync_enrollment_lifecycle
before insert or update of active, status on public.enrollments
for each row execute function public.sync_enrollment_lifecycle();
create trigger db020_sync_classroom_lifecycle
before insert or update of status, archived_at on public.classrooms
for each row execute function public.sync_classroom_lifecycle();
create trigger db020_sync_submission_lifecycle
before insert or update of status, excused, submitted_at on public.submissions
for each row execute function public.sync_submission_lifecycle();
create trigger db020_sync_grade_publication_actor
before insert or update of state, reviewed_by, published_by on public.grade_results
for each row execute function public.sync_grade_publication_actor();

do $db020$
declare
  table_name text;
begin
  foreach table_name in array array[
    'guardian_links', 'enrollments', 'lesson_sessions', 'lesson_materials',
    'assignments', 'submissions', 'assessments', 'assessment_questions',
    'grade_results', 'attendance_records', 'wellbeing_events', 'meetings',
    'meeting_deliveries', 'ai_grading_drafts', 'question_suggestions',
    'practice_sessions'
  ]
  loop
    execute format(
      'create trigger db020_derive_school before insert or update on public.%I '
      'for each row execute function public.derive_school_id()',
      table_name
    );
  end loop;
end
$db020$;

alter table public.memberships
  add constraint db020_memberships_school_id_key unique (school_id, id),
  add constraint db020_memberships_school_id_user_id_key unique (school_id, id, user_id),
  add constraint db020_memberships_status_active_check
    check (active = (status = 'active')) not valid,
  add constraint db020_memberships_version_check check (version > 0) not valid,
  add constraint db020_memberships_validity_check
    check (valid_until is null or valid_until >= valid_from) not valid;

alter table public.terms
  add constraint db020_terms_school_id_key unique (school_id, id),
  add constraint db020_terms_dates_check check (starts_on <= ends_on) not valid,
  add constraint db020_terms_status_active_check
    check (active = (status = 'active')) not valid;

alter table public.students
  add constraint db020_students_school_id_key unique (school_id, id),
  add constraint db020_students_school_id_required
    check (school_id is not null) not valid;

alter table public.classrooms
  add constraint db020_classrooms_school_id_key unique (school_id, id),
  add constraint db020_classrooms_term_school_fk
    foreign key (school_id, term_id)
    references public.terms (school_id, id)
    on delete restrict not valid,
  add constraint db020_classrooms_status_archive_check
    check ((status = 'archived') = (archived_at is not null)) not valid;

alter table public.guardian_links
  add constraint db020_guardian_links_school_id_required
    check (school_id is not null) not valid,
  add constraint db020_guardian_links_student_school_fk
    foreign key (school_id, student_id)
    references public.students (school_id, id)
    on delete cascade not valid,
  add constraint db020_guardian_links_verified_check
    check (
      status <> 'verified'
      or (verified_by is not null and verified_at is not null)
    ) not valid,
  add constraint db020_guardian_links_expiry_check
    check (expires_at is null or verified_at is null or expires_at >= verified_at)
    not valid;

alter table public.enrollments
  add constraint db020_enrollments_school_id_key
    unique (school_id, classroom_id, student_id),
  add constraint db020_enrollments_school_id_required
    check (school_id is not null) not valid,
  add constraint db020_enrollments_classroom_school_fk
    foreign key (school_id, classroom_id)
    references public.classrooms (school_id, id)
    on delete cascade not valid,
  add constraint db020_enrollments_student_school_fk
    foreign key (school_id, student_id)
    references public.students (school_id, id)
    on delete cascade not valid,
  add constraint db020_enrollments_status_active_check
    check (active = (status = 'active')) not valid,
  add constraint db020_enrollments_dates_check
    check (ends_on is null or ends_on >= starts_on) not valid;

alter table public.lesson_sessions
  add constraint db020_lesson_sessions_school_id_key unique (school_id, id),
  add constraint db020_lesson_sessions_school_id_required
    check (school_id is not null) not valid,
  add constraint db020_lesson_sessions_classroom_school_fk
    foreign key (school_id, classroom_id)
    references public.classrooms (school_id, id)
    on delete cascade not valid,
  add constraint db020_lesson_sessions_time_check
    check (ends_at > starts_at) not valid;

alter table public.lesson_materials
  add constraint db020_lesson_materials_school_id_required
    check (school_id is not null) not valid,
  add constraint db020_lesson_materials_session_school_fk
    foreign key (school_id, session_id)
    references public.lesson_sessions (school_id, id)
    on delete cascade not valid;

alter table public.assignments
  add constraint db020_assignments_school_id_key unique (school_id, id),
  add constraint db020_assignments_school_id_required
    check (school_id is not null) not valid,
  add constraint db020_assignments_classroom_school_fk
    foreign key (school_id, classroom_id)
    references public.classrooms (school_id, id)
    on delete cascade not valid,
  add constraint db020_assignments_version_check check (version > 0) not valid,
  add constraint db020_assignments_close_check
    check (closes_at is null or closes_at >= due_at) not valid,
  add constraint db020_assignments_publication_check
    check (state <> 'published' or published_at is not null) not valid;

alter table public.submissions
  add constraint db020_submissions_school_id_key unique (school_id, id),
  add constraint db020_submissions_school_id_required
    check (school_id is not null) not valid,
  add constraint db020_submissions_assignment_school_fk
    foreign key (school_id, assignment_id)
    references public.assignments (school_id, id)
    on delete cascade not valid,
  add constraint db020_submissions_student_school_fk
    foreign key (school_id, student_id)
    references public.students (school_id, id)
    on delete cascade not valid,
  add constraint db020_submissions_version_check check (version > 0) not valid,
  add constraint db020_submissions_state_check
    check (
      (status = 'submitted' and submitted_at is not null and not excused)
      or (status = 'excused' and excused)
      or status in ('open', 'withdrawn')
    ) not valid;

alter table public.submission_attempts
  add constraint db020_submission_attempts_school_submission_id_key
    unique (school_id, submission_id, id),
  add constraint db020_submission_attempts_school_id_key unique (school_id, id),
  add constraint db020_submission_attempts_submission_school_fk
    foreign key (school_id, submission_id)
    references public.submissions (school_id, id)
    on delete cascade not valid;

alter table public.submissions
  add constraint db020_submissions_current_attempt_school_fk
    foreign key (school_id, id, current_attempt_id)
    references public.submission_attempts (school_id, submission_id, id)
    on delete restrict not valid;

alter table public.assessments
  add constraint db020_assessments_school_id_key unique (school_id, id),
  add constraint db020_assessments_school_id_required
    check (school_id is not null) not valid,
  add constraint db020_assessments_classroom_school_fk
    foreign key (school_id, classroom_id)
    references public.classrooms (school_id, id)
    on delete cascade not valid,
  add constraint db020_assessments_version_check check (version > 0) not valid,
  add constraint db020_assessments_weight_check
    check (category_weight is null or category_weight between 0 and 100) not valid,
  add constraint db020_assessments_publication_check
    check (state <> 'published' or published_at is not null) not valid;

alter table public.assessment_questions
  add constraint db020_assessment_questions_school_id_key unique (school_id, id),
  add constraint db020_assessment_questions_school_id_required
    check (school_id is not null) not valid,
  add constraint db020_assessment_questions_assessment_school_fk
    foreign key (school_id, assessment_id)
    references public.assessments (school_id, id)
    on delete cascade not valid;

alter table public.grade_results
  add constraint db020_grade_results_school_id_key unique (school_id, id),
  add constraint db020_grade_results_school_id_required
    check (school_id is not null) not valid,
  add constraint db020_grade_results_assessment_school_fk
    foreign key (school_id, assessment_id)
    references public.assessments (school_id, id)
    on delete cascade not valid,
  add constraint db020_grade_results_student_school_fk
    foreign key (school_id, student_id)
    references public.students (school_id, id)
    on delete cascade not valid,
  add constraint db020_grade_results_score_check check (score >= 0) not valid,
  add constraint db020_grade_results_version_check check (version > 0) not valid,
  add constraint db020_grade_results_review_check
    check (
      state = 'draft'
      or (reviewed_by is not null and reviewed_at is not null)
    ) not valid,
  add constraint db020_grade_results_publication_check
    check (
      state <> 'published'
      or (published_at is not null and published_by is not null)
    ) not valid;

alter table public.attendance_records
  add constraint db020_attendance_records_school_id_key unique (school_id, id),
  add constraint db020_attendance_records_school_id_required
    check (school_id is not null) not valid,
  add constraint db020_attendance_records_session_school_fk
    foreign key (school_id, session_id)
    references public.lesson_sessions (school_id, id)
    on delete cascade not valid,
  add constraint db020_attendance_records_student_school_fk
    foreign key (school_id, student_id)
    references public.students (school_id, id)
    on delete cascade not valid;

alter table public.wellbeing_events
  add constraint db020_wellbeing_events_school_id_key unique (school_id, id),
  add constraint db020_wellbeing_events_school_id_required
    check (school_id is not null) not valid,
  add constraint db020_wellbeing_events_student_school_fk
    foreign key (school_id, student_id)
    references public.students (school_id, id)
    on delete cascade not valid,
  add constraint db020_wellbeing_events_classroom_school_fk
    foreign key (school_id, classroom_id)
    references public.classrooms (school_id, id)
    on delete set null not valid,
  add constraint db020_wellbeing_events_severity_check
    check (severity in ('low', 'medium', 'high', 'critical')) not valid,
  add constraint db020_wellbeing_events_status_check
    check (status in ('open', 'closed')) not valid;

alter table public.announcements
  add constraint db020_announcements_school_id_key unique (school_id, id),
  add constraint db020_announcements_classroom_school_fk
    foreign key (school_id, classroom_id)
    references public.classrooms (school_id, id)
    on delete cascade not valid,
  add constraint db020_announcements_publication_check
    check (state <> 'published' or published_at is not null) not valid;

alter table public.meetings
  add constraint db020_meetings_school_id_key unique (school_id, id),
  add constraint db020_meetings_school_id_required
    check (school_id is not null) not valid,
  add constraint db020_meetings_classroom_school_fk
    foreign key (school_id, classroom_id)
    references public.classrooms (school_id, id)
    on delete cascade not valid,
  add constraint db020_meetings_time_check check (ends_at > starts_at) not valid,
  add constraint db020_meetings_idempotency_key unique (school_id, idempotency_key);

alter table public.meeting_deliveries
  add constraint db020_meeting_deliveries_school_id_required
    check (school_id is not null) not valid,
  add constraint db020_meeting_deliveries_meeting_school_fk
    foreign key (school_id, meeting_id)
    references public.meetings (school_id, id)
    on delete cascade not valid,
  add constraint db020_meeting_deliveries_attempt_check
    check (attempt_count >= 0) not valid;

alter table public.file_objects
  add constraint db020_file_objects_school_id_key unique (school_id, id),
  add constraint db020_file_objects_scan_check
    check (
      (scan_state = 'clean' and scanned_at is not null)
      or scan_state <> 'clean'
    ) not valid;

alter table public.ai_grading_drafts
  add constraint db020_ai_grading_drafts_school_id_key unique (school_id, id),
  add constraint db020_ai_grading_drafts_school_id_required
    check (school_id is not null) not valid,
  add constraint db020_ai_grading_drafts_grade_school_fk
    foreign key (school_id, grade_result_id)
    references public.grade_results (school_id, id)
    on delete cascade not valid,
  add constraint db020_ai_grading_drafts_file_school_fk
    foreign key (school_id, file_object_id)
    references public.file_objects (school_id, id)
    on delete restrict not valid,
  add constraint db020_ai_grading_drafts_version_check check (version > 0) not valid;

alter table public.question_suggestions
  add constraint db020_question_suggestions_school_id_required
    check (school_id is not null) not valid,
  add constraint db020_question_suggestions_draft_school_fk
    foreign key (school_id, draft_id)
    references public.ai_grading_drafts (school_id, id)
    on delete cascade not valid,
  add constraint db020_question_suggestions_question_school_fk
    foreign key (school_id, question_id)
    references public.assessment_questions (school_id, id)
    on delete cascade not valid;

alter table public.practice_sessions
  add constraint db020_practice_sessions_school_id_required
    check (school_id is not null) not valid,
  add constraint db020_practice_sessions_classroom_school_fk
    foreign key (school_id, classroom_id)
    references public.classrooms (school_id, id)
    on delete cascade not valid,
  add constraint db020_practice_sessions_student_school_fk
    foreign key (school_id, student_id)
    references public.students (school_id, id)
    on delete cascade not valid,
  add constraint db020_practice_sessions_counts_check
    check (correct_count is null or correct_count between 0 and item_count) not valid;

alter table public.membership_events
  add constraint db020_membership_events_membership_school_fk
    foreign key (school_id, membership_id)
    references public.memberships (school_id, id)
    on delete restrict not valid;

alter table public.classroom_staff
  add constraint db020_classroom_staff_school_id_key unique (school_id, id),
  add constraint db020_classroom_staff_classroom_school_fk
    foreign key (school_id, classroom_id)
    references public.classrooms (school_id, id)
    on delete cascade not valid,
  add constraint db020_classroom_staff_membership_school_user_fk
    foreign key (school_id, membership_id, user_id)
    references public.memberships (school_id, id, user_id)
    on delete restrict not valid,
  add constraint db020_classroom_staff_status_end_check
    check ((status = 'ended') = (ends_at is not null)) not valid;

alter table public.class_schedules
  add constraint db020_class_schedules_classroom_school_fk
    foreign key (school_id, classroom_id)
    references public.classrooms (school_id, id)
    on delete cascade not valid;

alter table public.guardian_links
  add constraint db020_guardian_links_evidence_file_school_fk
    foreign key (school_id, evidence_file_id)
    references public.file_objects (school_id, id)
    on delete restrict not valid;

alter table public.resources
  add constraint db020_resources_school_id_key unique (school_id, id);

alter table public.resource_versions
  add constraint db020_resource_versions_school_id_key unique (school_id, id),
  add constraint db020_resource_versions_resource_school_fk
    foreign key (school_id, resource_id)
    references public.resources (school_id, id)
    on delete cascade not valid,
  add constraint db020_resource_versions_file_school_fk
    foreign key (school_id, file_object_id)
    references public.file_objects (school_id, id)
    on delete restrict not valid;

alter table public.resource_publications
  add constraint db020_resource_publications_school_id_key unique (school_id, id),
  add constraint db020_resource_publications_version_school_fk
    foreign key (school_id, resource_version_id)
    references public.resource_versions (school_id, id)
    on delete restrict not valid,
  add constraint db020_resource_publications_classroom_school_fk
    foreign key (school_id, classroom_id)
    references public.classrooms (school_id, id)
    on delete cascade not valid;

alter table public.grade_result_events
  add constraint db020_grade_result_events_grade_school_fk
    foreign key (school_id, grade_result_id)
    references public.grade_results (school_id, id)
    on delete restrict not valid;

alter table public.conversations
  add constraint db020_conversations_school_id_key unique (school_id, id),
  add constraint db020_conversations_close_check
    check ((state = 'closed') = (closed_at is not null)) not valid;

alter table public.conversation_participants
  add constraint db020_conversation_participants_conversation_school_fk
    foreign key (school_id, conversation_id)
    references public.conversations (school_id, id)
    on delete cascade not valid;

alter table public.messages
  add constraint db020_messages_school_id_key unique (school_id, id),
  add constraint db020_messages_conversation_school_fk
    foreign key (school_id, conversation_id)
    references public.conversations (school_id, id)
    on delete cascade not valid;

alter table public.file_bindings
  add constraint db020_file_bindings_file_school_fk
    foreign key (school_id, file_object_id)
    references public.file_objects (school_id, id)
    on delete restrict not valid,
  add constraint db020_file_bindings_resource_version_school_fk
    foreign key (school_id, resource_version_id)
    references public.resource_versions (school_id, id)
    on delete cascade not valid,
  add constraint db020_file_bindings_submission_attempt_school_fk
    foreign key (school_id, submission_attempt_id)
    references public.submission_attempts (school_id, id)
    on delete cascade not valid,
  add constraint db020_file_bindings_message_school_fk
    foreign key (school_id, message_id)
    references public.messages (school_id, id)
    on delete cascade not valid,
  add constraint db020_file_bindings_ai_draft_school_fk
    foreign key (school_id, ai_grading_draft_id)
    references public.ai_grading_drafts (school_id, id)
    on delete cascade not valid;

alter table public.upload_sessions
  add constraint db020_upload_sessions_file_school_fk
    foreign key (school_id, file_object_id)
    references public.file_objects (school_id, id)
    on delete restrict not valid;

alter table public.notification_outbox
  add constraint db020_notification_outbox_school_id_key unique (school_id, id);

alter table public.notifications
  add constraint db020_notifications_school_id_key unique (school_id, id);

alter table public.notification_deliveries
  add constraint db020_notification_deliveries_outbox_school_fk
    foreign key (school_id, outbox_id)
    references public.notification_outbox (school_id, id)
    on delete cascade not valid,
  add constraint db020_notification_deliveries_notification_school_fk
    foreign key (school_id, notification_id)
    references public.notifications (school_id, id)
    on delete set null (notification_id) not valid;

create unique index db020_idempotency_scope_key
on public.idempotency_records (
  coalesce(school_id, '00000000-0000-0000-0000-000000000000'::uuid),
  actor_id,
  scope,
  idempotency_key
);

create unique index db020_store_events_external_key
on public.store_events (platform, environment, external_event_id)
where external_event_id is not null;

create unique index db020_store_events_payload_key
on public.store_events (platform, environment, payload_hash);

create unique index db020_entitlements_active_key
on public.entitlements (
  user_id,
  coalesce(school_id, '00000000-0000-0000-0000-000000000000'::uuid),
  feature_key
)
where status in ('active', 'grace_period');

create unique index db020_classroom_staff_active_key
on public.classroom_staff (classroom_id, user_id, role)
where status = 'active';

create or replace function public.validate_grade_result_score()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
declare
  allowed_score numeric(8,2);
begin
  select a.maximum_score into allowed_score
  from public.assessments a
  where a.id = new.assessment_id;
  if allowed_score is null or new.score < 0 or new.score > allowed_score then
    raise exception 'Grade score is outside the assessment maximum';
  end if;
  return new;
end;
$$;

create or replace function public.validate_assessment_maximum()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  if exists (
    select 1 from public.grade_results g
    where g.assessment_id = new.id and g.score > new.maximum_score
  ) then
    raise exception 'Assessment maximum is below an existing grade';
  end if;
  return new;
end;
$$;

revoke execute on function public.validate_grade_result_score()
from public, anon, authenticated;
revoke execute on function public.validate_assessment_maximum()
from public, anon, authenticated;

create trigger db020_validate_grade_result_score
before insert or update of assessment_id, score on public.grade_results
for each row execute function public.validate_grade_result_score();

create trigger db020_validate_assessment_maximum
before update of maximum_score on public.assessments
for each row execute function public.validate_assessment_maximum();

create or replace function public.reject_append_only_mutation()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  raise exception 'Append-only relation cannot be updated or deleted';
end;
$$;

revoke execute on function public.reject_append_only_mutation()
from public, anon, authenticated;

do $db020$
declare
  table_name text;
begin
  foreach table_name in array array[
    'membership_events', 'resource_versions', 'submission_attempts',
    'grade_result_events', 'messages', 'store_transactions', 'audit_events'
  ]
  loop
    execute format(
      'create trigger db020_reject_mutation before update or delete on public.%I '
      'for each row execute function public.reject_append_only_mutation()',
      table_name
    );
  end loop;
end
$db020$;
