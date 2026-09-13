-- DB-021 structural defense against property/relationship substitution.

create or replace function private.reject_immutable_columns()
returns trigger
language plpgsql
security invoker
set search_path = ''
as $$
declare
  column_name text;
begin
  foreach column_name in array tg_argv
  loop
    if (to_jsonb(new) -> column_name)
       is distinct from (to_jsonb(old) -> column_name) then
      raise exception using
        errcode = '22000',
        message = format(
          'Immutable relationship column cannot be changed: %I.%I',
          tg_table_name,
          column_name
        );
    end if;
  end loop;
  return new;
end;
$$;

alter function private.reject_immutable_columns() owner to postgres;
revoke all on function private.reject_immutable_columns()
from public, anon, authenticated, service_role;

create trigger db021_immutable_school
before update on public.schools
for each row execute function private.reject_immutable_columns('id', 'created_at');
create trigger db021_immutable_profile
before update on public.profiles
for each row execute function private.reject_immutable_columns('id', 'created_at');
create trigger db021_immutable_membership
before update on public.memberships
for each row execute function private.reject_immutable_columns(
  'id', 'school_id', 'user_id', 'role', 'created_at'
);
create trigger db021_immutable_term
before update on public.terms
for each row execute function private.reject_immutable_columns('id', 'school_id');
create trigger db021_immutable_student
before update on public.students
for each row execute function private.reject_immutable_columns(
  'id', 'school_id', 'user_id', 'created_by', 'created_at'
);
create trigger db021_immutable_guardian_link
before update on public.guardian_links
for each row execute function private.reject_immutable_columns(
  'id', 'school_id', 'student_id', 'guardian_id'
);
create trigger db021_immutable_classroom
before update on public.classrooms
for each row execute function private.reject_immutable_columns(
  'id', 'school_id', 'term_id', 'created_at'
);
create trigger db021_immutable_enrollment
before update on public.enrollments
for each row execute function private.reject_immutable_columns(
  'school_id', 'classroom_id', 'student_id', 'created_at'
);
create trigger db021_immutable_classroom_staff
before update on public.classroom_staff
for each row execute function private.reject_immutable_columns(
  'id', 'school_id', 'classroom_id', 'membership_id', 'user_id', 'created_at'
);
create trigger db021_immutable_class_schedule
before update on public.class_schedules
for each row execute function private.reject_immutable_columns(
  'id', 'school_id', 'classroom_id', 'created_at'
);
create trigger db021_immutable_lesson_session
before update on public.lesson_sessions
for each row execute function private.reject_immutable_columns(
  'id', 'school_id', 'classroom_id', 'created_at'
);
create trigger db021_immutable_lesson_material
before update on public.lesson_materials
for each row execute function private.reject_immutable_columns(
  'id', 'school_id', 'session_id', 'created_by', 'created_at'
);
create trigger db021_immutable_assignment
before update on public.assignments
for each row execute function private.reject_immutable_columns(
  'id', 'school_id', 'classroom_id', 'created_by', 'created_at'
);
create trigger db021_immutable_submission
before update on public.submissions
for each row execute function private.reject_immutable_columns(
  'id', 'school_id', 'assignment_id', 'student_id', 'created_at'
);
create trigger db021_immutable_assessment
before update on public.assessments
for each row execute function private.reject_immutable_columns(
  'id', 'school_id', 'classroom_id', 'created_by', 'created_at'
);
create trigger db021_immutable_assessment_question
before update on public.assessment_questions
for each row execute function private.reject_immutable_columns(
  'id', 'school_id', 'assessment_id', 'created_at'
);
create trigger db021_immutable_grade_result
before update on public.grade_results
for each row execute function private.reject_immutable_columns(
  'id', 'school_id', 'assessment_id', 'student_id', 'created_at'
);
create trigger db021_immutable_attendance_record
before update on public.attendance_records
for each row execute function private.reject_immutable_columns(
  'id', 'school_id', 'session_id', 'student_id', 'recorded_by', 'recorded_at'
);
create trigger db021_immutable_wellbeing_event
before update on public.wellbeing_events
for each row execute function private.reject_immutable_columns(
  'id', 'school_id', 'student_id', 'classroom_id', 'created_by', 'created_at'
);
create trigger db021_immutable_announcement
before update on public.announcements
for each row execute function private.reject_immutable_columns(
  'id', 'school_id', 'classroom_id', 'created_by'
);
create trigger db021_immutable_meeting
before update on public.meetings
for each row execute function private.reject_immutable_columns(
  'id', 'school_id', 'classroom_id', 'created_by', 'created_at'
);
create trigger db021_immutable_meeting_delivery
before update on public.meeting_deliveries
for each row execute function private.reject_immutable_columns(
  'school_id', 'meeting_id', 'recipient_id', 'created_at'
);
create trigger db021_immutable_notification
before update on public.notifications
for each row execute function private.reject_immutable_columns(
  'id', 'school_id', 'user_id', 'created_at'
);
create trigger db021_immutable_ai_grading_draft
before update on public.ai_grading_drafts
for each row execute function private.reject_immutable_columns(
  'id', 'school_id', 'grade_result_id', 'private_scan_path',
  'file_object_id', 'created_by', 'created_at'
);
create trigger db021_immutable_question_suggestion
before update on public.question_suggestions
for each row execute function private.reject_immutable_columns(
  'id', 'school_id', 'draft_id', 'question_id', 'created_at'
);
create trigger db021_immutable_subscription_entitlement
before update on public.subscription_entitlements
for each row execute function private.reject_immutable_columns('user_id');
create trigger db021_immutable_practice_session
before update on public.practice_sessions
for each row execute function private.reject_immutable_columns(
  'id', 'school_id', 'student_id', 'classroom_id', 'created_at'
);
create trigger db021_immutable_consent_record
before update on public.consent_records
for each row execute function private.reject_immutable_columns(
  'id', 'user_id', 'purpose', 'policy_version'
);
create trigger db021_immutable_account_deletion_request
before update on public.account_deletion_requests
for each row execute function private.reject_immutable_columns('id', 'user_id');

create trigger db021_immutable_file_object
before update on public.file_objects
for each row execute function private.reject_immutable_columns(
  'id', 'school_id', 'bucket', 'object_key', 'uploader_id', 'size_bytes',
  'sha256', 'created_at'
);
create trigger db021_immutable_resource
before update on public.resources
for each row execute function private.reject_immutable_columns(
  'id', 'school_id', 'created_by', 'created_at'
);
create trigger db021_immutable_resource_publication
before update on public.resource_publications
for each row execute function private.reject_immutable_columns(
  'id', 'school_id', 'resource_version_id', 'classroom_id',
  'created_by', 'created_at'
);
create trigger db021_immutable_file_binding
before update on public.file_bindings
for each row execute function private.reject_immutable_columns(
  'id', 'school_id', 'file_object_id', 'resource_version_id',
  'submission_attempt_id', 'message_id', 'ai_grading_draft_id', 'created_at'
);
create trigger db021_immutable_upload_session
before update on public.upload_sessions
for each row execute function private.reject_immutable_columns(
  'id', 'school_id', 'uploader_id', 'purpose', 'nonce_hash', 'created_at'
);
create trigger db021_immutable_notification_outbox
before update on public.notification_outbox
for each row execute function private.reject_immutable_columns(
  'id', 'school_id', 'source_event_id', 'idempotency_key',
  'recipient_id', 'audience', 'created_at'
);
create trigger db021_immutable_notification_delivery
before update on public.notification_deliveries
for each row execute function private.reject_immutable_columns(
  'id', 'school_id', 'outbox_id', 'recipient_id', 'channel'
);
create trigger db021_immutable_entitlement
before update on public.entitlements
for each row execute function private.reject_immutable_columns(
  'id', 'user_id', 'school_id', 'feature_key', 'source', 'created_at'
);
create trigger db021_immutable_idempotency_record
before update on public.idempotency_records
for each row execute function private.reject_immutable_columns(
  'id', 'school_id', 'actor_id', 'scope', 'idempotency_key',
  'request_hash', 'created_at'
);
