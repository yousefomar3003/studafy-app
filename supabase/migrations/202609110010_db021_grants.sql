-- DB-021 least-privilege grant cutover. RLS is not a substitute for object and
-- column privileges; both layers must permit an operation.

revoke all on schema public, private
from public, anon, authenticated, service_role,
  studafy_api_runtime, studafy_worker_runtime;
grant usage on schema public to anon, authenticated, service_role;
grant usage on schema private to authenticated;

revoke all privileges on all tables in schema public
from public, anon, authenticated, service_role,
  studafy_api_runtime, studafy_worker_runtime;
revoke all privileges on all sequences in schema public
from public, anon, authenticated, service_role,
  studafy_api_runtime, studafy_worker_runtime;
revoke all privileges on all functions in schema public
from public, anon, authenticated, service_role,
  studafy_api_runtime, studafy_worker_runtime;

-- Flutter/session reads.
grant select (id, display_name, locale, status)
on public.profiles to authenticated;
grant select (
  id, school_id, user_id, role, active, status, valid_from, valid_until
)
on public.memberships to authenticated;
grant select (id, name, timezone, status, locale)
on public.schools to authenticated;
grant select (id, school_id, name, starts_on, ends_on, active, status)
on public.terms to authenticated;
grant select (
  id, school_id, user_id, studafy_id, display_name, provisional
)
on public.students to authenticated;
grant select (
  id, school_id, student_id, guardian_id, status, relationship, expires_at
)
on public.guardian_links to authenticated;
grant select (
  id, school_id, term_id, name, grade, section, teacher_id, status, archived_at
)
on public.classrooms to authenticated;
grant select (
  school_id, classroom_id, student_id, active, status, starts_on, ends_on
)
on public.enrollments to authenticated;
grant select (
  id, school_id, classroom_id, user_id, role, status, starts_at, ends_at
)
on public.classroom_staff to authenticated;
grant select (
  id, school_id, classroom_id, weekday, starts_at, ends_at,
  effective_from, effective_until
)
on public.class_schedules to authenticated;

-- Read-only learning and school feeds. Storage paths, answer keys, hashes,
-- audit payloads, and processing metadata are deliberately omitted.
grant select (
  id, school_id, classroom_id, starts_at, ends_at, title, filed_at, status
)
on public.lesson_sessions to authenticated;
grant select (
  id, school_id, session_id, title, body, media_type, created_by, created_at
)
on public.lesson_materials to authenticated;
grant select (
  id, school_id, classroom_id, title, instructions, due_at, closes_at,
  state, published_at, version, created_at
)
on public.assignments to authenticated;
grant select (
  id, school_id, assignment_id, student_id, submitted_at, excused,
  status, version, created_at, updated_at
)
on public.submissions to authenticated;
grant select (
  id, school_id, classroom_id, title, category, maximum_score,
  category_weight, scheduled_at, state, delivery, published_at, version
)
on public.assessments to authenticated;
grant select (
  id, school_id, assessment_id, position, prompt, maximum_score
)
on public.assessment_questions to authenticated;
grant select (
  id, school_id, assessment_id, student_id, score, state, feedback,
  reviewed_at, published_at, version
)
on public.grade_results to authenticated;
grant select (
  id, school_id, session_id, student_id, state, reason, recorded_at
)
on public.attendance_records to authenticated;
grant select (
  id, school_id, student_id, classroom_id, kind, title, context, follow_up,
  visibility, severity, status, created_at
)
on public.wellbeing_events to authenticated;
grant select (
  id, school_id, classroom_id, title, body, audience, important,
  published_at, state
)
on public.announcements to authenticated;
grant select (
  id, school_id, classroom_id, title, starts_at, ends_at, audience,
  meet_url, state, created_by, created_at
)
on public.meetings to authenticated;
grant select (
  school_id, meeting_id, recipient_id, state, delivered_at
)
on public.meeting_deliveries to authenticated;
grant select (
  id, school_id, user_id, kind, title, body, route, entity_id,
  read_at, created_at
)
on public.notifications to authenticated;
grant select (user_id, product_id, source, active, expires_at, verified_at)
on public.subscription_entitlements to authenticated;
grant select (
  id, user_id, purpose, policy_version, locale, accepted_at, withdrawn_at
)
on public.consent_records to authenticated;
grant select (
  id, school_id, student_id, classroom_id, topic, kind, item_count,
  correct_count, completed_at, created_at
)
on public.practice_sessions to authenticated;
grant select (
  id, school_id, title, resource_type, state, current_version,
  created_by, created_at, updated_at
)
on public.resources to authenticated;
grant select (
  id, school_id, resource_id, version, body, created_by, created_at
)
on public.resource_versions to authenticated;
grant select (
  id, school_id, resource_version_id, classroom_id, audience, state,
  published_at, withdrawn_at, created_at
)
on public.resource_publications to authenticated;

-- Two bounded public RPCs are the entire authenticated function surface.
grant execute on function public.record_policy_consent(text, text, text)
to authenticated;
grant execute on function public.mark_notifications_read()
to authenticated;

-- Existing contained Edge Functions use the service role. Keep only their
-- observed table operations; future services must add explicit grants.
grant select on public.enrollments, public.students, public.guardian_links,
  public.account_deletion_requests, public.subscription_entitlements,
  public.grade_results, public.ai_grading_drafts,
  public.assessment_questions, public.question_suggestions,
  public.meetings
to service_role;

grant insert on public.meetings, public.meeting_deliveries,
  public.account_deletion_requests, public.subscription_entitlements,
  public.notifications, public.practice_sessions, public.audit_events
to service_role;

grant update on public.meetings, public.meeting_deliveries,
  public.account_deletion_requests, public.subscription_entitlements,
  public.grade_results, public.ai_grading_drafts,
  public.question_suggestions
to service_role;

grant usage on sequence public.audit_events_id_seq to service_role;

-- Remove legacy policy helpers after every dependent policy has been replaced.
drop function public.is_school_member(uuid, public.app_role[]);
drop function public.is_class_teacher(uuid);
drop function public.can_access_student(uuid);
drop function public.can_access_classroom(uuid);

-- New objects stay closed until a later migration grants them intentionally.
alter default privileges for role postgres in schema public
  revoke all on tables from public, anon, authenticated, service_role;
alter default privileges for role postgres in schema public
  revoke all on sequences from public, anon, authenticated, service_role;
alter default privileges for role postgres in schema public
  revoke execute on functions from public, anon, authenticated, service_role;
alter default privileges for role postgres in schema private
  revoke all on tables from public, anon, authenticated, service_role;
alter default privileges for role postgres in schema private
  revoke all on sequences from public, anon, authenticated, service_role;
alter default privileges for role postgres in schema private
  revoke execute on functions from public, anon, authenticated, service_role;

-- Function EXECUTE is granted to PUBLIC by PostgreSQL's global default. A
-- schema-scoped revoke cannot override that built-in grant, so remove it at
-- the migration-owner level as well. Platform-owned defaults are managed by
-- Supabase and are outside the application's migration-role authority.
alter default privileges for role postgres
  revoke execute on functions from public;
