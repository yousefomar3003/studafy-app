-- DB-020 expand step: add tenant/lifecycle fields and the target foundation.
-- New public tables are RLS-enabled and have no client policies in Part 2A.

create or replace function public.set_updated_at()
returns trigger
language plpgsql
security invoker
set search_path = ''
as $$
begin
  new.updated_at := now();
  return new;
end;
$$;

revoke execute on function public.set_updated_at() from public, anon, authenticated;

alter table public.schools
  add column status public.school_status,
  add column locale text,
  add column retention_policy_version text,
  add column updated_at timestamptz,
  add column deleted_at timestamptz;

alter table public.profiles
  add column status public.profile_status,
  add column updated_at timestamptz,
  add column deleted_at timestamptz;

alter table public.memberships
  add column status public.membership_status,
  add column valid_from timestamptz,
  add column valid_until timestamptz,
  add column version bigint,
  add column updated_at timestamptz;

alter table public.terms
  add column status public.term_status,
  add column updated_at timestamptz;

alter table public.students
  add column updated_at timestamptz,
  add column deleted_at timestamptz;

alter table public.guardian_links
  add column school_id uuid,
  add column expires_at timestamptz,
  add column updated_at timestamptz;

alter table public.classrooms
  add column status public.classroom_status,
  add column created_at timestamptz,
  add column updated_at timestamptz;

alter table public.enrollments
  add column school_id uuid,
  add column status public.enrollment_status,
  add column starts_on date,
  add column ends_on date,
  add column created_at timestamptz,
  add column updated_at timestamptz;

alter table public.lesson_sessions
  add column school_id uuid,
  add column status public.lesson_session_status,
  add column created_at timestamptz,
  add column updated_at timestamptz;

alter table public.lesson_materials
  add column school_id uuid,
  add column updated_at timestamptz,
  add column deleted_at timestamptz;

alter table public.assignments
  add column school_id uuid,
  add column closes_at timestamptz,
  add column version bigint,
  add column created_at timestamptz,
  add column updated_at timestamptz,
  add column deleted_at timestamptz;

alter table public.submissions
  add column school_id uuid,
  add column status public.submission_status,
  add column version bigint,
  add column created_at timestamptz,
  add column updated_at timestamptz;

alter table public.assessments
  add column school_id uuid,
  add column version bigint,
  add column created_at timestamptz,
  add column updated_at timestamptz,
  add column deleted_at timestamptz;

alter table public.assessment_questions
  add column school_id uuid,
  add column created_at timestamptz,
  add column updated_at timestamptz;

alter table public.grade_results
  add column school_id uuid,
  add column version bigint,
  add column published_by uuid references public.profiles(id) on delete restrict,
  add column created_at timestamptz,
  add column updated_at timestamptz;

alter table public.attendance_records
  add column school_id uuid,
  add column updated_at timestamptz;

alter table public.wellbeing_events
  add column school_id uuid,
  add column visibility public.wellbeing_visibility,
  add column severity text,
  add column status text,
  add column updated_at timestamptz;

alter table public.announcements
  add column state public.resource_state,
  add column updated_at timestamptz,
  add column deleted_at timestamptz;

alter table public.meetings
  add column school_id uuid,
  add column idempotency_key text,
  add column updated_at timestamptz;

alter table public.meeting_deliveries
  add column school_id uuid,
  add column attempt_count integer,
  add column next_attempt_at timestamptz,
  add column error_code text,
  add column created_at timestamptz,
  add column updated_at timestamptz;

alter table public.notifications
  add column school_id uuid references public.schools(id) on delete cascade,
  add column source_event_id text,
  add column dedupe_key text,
  add column updated_at timestamptz;

alter table public.ai_grading_drafts
  add column school_id uuid,
  add column version bigint,
  add column updated_at timestamptz;

alter table public.question_suggestions
  add column school_id uuid,
  add column created_at timestamptz;

alter table public.subscription_entitlements
  add column updated_at timestamptz;

alter table public.audit_events
  add column request_id text;

alter table public.practice_sessions
  add column school_id uuid,
  add column updated_at timestamptz;

alter table public.consent_records
  add column updated_at timestamptz;

alter table public.account_deletion_requests
  add column version bigint,
  add column updated_at timestamptz;

create table public.membership_events (
  id bigint generated always as identity primary key,
  school_id uuid not null references public.schools(id) on delete restrict,
  membership_id uuid not null references public.memberships(id) on delete restrict,
  actor_id uuid references public.profiles(id) on delete set null,
  event_type text not null check (
    event_type in ('granted', 'suspended', 'reactivated', 'revoked', 'expired')
  ),
  reason text,
  idempotency_key text not null,
  created_at timestamptz not null default now(),
  unique (school_id, idempotency_key)
);

create table public.classroom_staff (
  id uuid primary key default gen_random_uuid(),
  school_id uuid not null references public.schools(id) on delete cascade,
  classroom_id uuid not null references public.classrooms(id) on delete cascade,
  membership_id uuid not null references public.memberships(id) on delete restrict,
  user_id uuid not null references public.profiles(id) on delete restrict,
  role public.classroom_staff_role not null,
  status public.staff_assignment_status not null default 'active',
  starts_at timestamptz not null default now(),
  ends_at timestamptz,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  check (ends_at is null or ends_at >= starts_at)
);

create table public.class_schedules (
  id uuid primary key default gen_random_uuid(),
  school_id uuid not null references public.schools(id) on delete cascade,
  classroom_id uuid not null references public.classrooms(id) on delete cascade,
  weekday smallint not null check (weekday between 1 and 7),
  starts_at time not null,
  ends_at time not null,
  effective_from date not null,
  effective_until date,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  check (ends_at > starts_at),
  check (effective_until is null or effective_until >= effective_from),
  unique (classroom_id, weekday, starts_at, effective_from)
);

create table public.file_objects (
  id uuid primary key default gen_random_uuid(),
  school_id uuid not null references public.schools(id) on delete restrict,
  bucket text not null,
  object_key text not null,
  uploader_id uuid not null references public.profiles(id) on delete restrict,
  size_bytes bigint not null check (size_bytes >= 0),
  declared_media_type text,
  detected_media_type text,
  sha256 text not null check (sha256 ~ '^[0-9a-f]{64}$'),
  scan_state public.file_scan_state not null default 'quarantined',
  scan_error_code text,
  encryption_key_id text,
  retention_until timestamptz,
  legal_hold boolean not null default false,
  created_at timestamptz not null default now(),
  scanned_at timestamptz,
  deleted_at timestamptz,
  unique (bucket, object_key)
);

create table public.resources (
  id uuid primary key default gen_random_uuid(),
  school_id uuid not null references public.schools(id) on delete cascade,
  title text not null,
  resource_type text not null,
  state public.resource_state not null default 'draft',
  current_version integer not null default 1 check (current_version > 0),
  created_by uuid not null references public.profiles(id) on delete restrict,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  deleted_at timestamptz
);

create table public.resource_versions (
  id uuid primary key default gen_random_uuid(),
  school_id uuid not null references public.schools(id) on delete cascade,
  resource_id uuid not null references public.resources(id) on delete cascade,
  version integer not null check (version > 0),
  body text,
  file_object_id uuid references public.file_objects(id) on delete restrict,
  content_hash text,
  created_by uuid not null references public.profiles(id) on delete restrict,
  created_at timestamptz not null default now(),
  unique (resource_id, version)
);

create table public.resource_publications (
  id uuid primary key default gen_random_uuid(),
  school_id uuid not null references public.schools(id) on delete cascade,
  resource_version_id uuid not null references public.resource_versions(id) on delete restrict,
  classroom_id uuid references public.classrooms(id) on delete cascade,
  audience public.meeting_audience not null default 'both',
  state public.resource_state not null default 'draft',
  published_at timestamptz,
  withdrawn_at timestamptz,
  created_by uuid not null references public.profiles(id) on delete restrict,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  check (state <> 'published' or published_at is not null),
  check (withdrawn_at is null or published_at is not null)
);

create table public.submission_attempts (
  id uuid primary key default gen_random_uuid(),
  school_id uuid not null references public.schools(id) on delete cascade,
  submission_id uuid not null references public.submissions(id) on delete cascade,
  operation_id uuid not null,
  answer_text text,
  submitted_at timestamptz not null,
  created_at timestamptz not null default now(),
  unique (submission_id, operation_id)
);

alter table public.submissions
  add column current_attempt_id uuid references public.submission_attempts(id) on delete restrict;

create table public.grade_result_events (
  id bigint generated always as identity primary key,
  school_id uuid not null references public.schools(id) on delete restrict,
  grade_result_id uuid not null references public.grade_results(id) on delete restrict,
  actor_id uuid references public.profiles(id) on delete set null,
  event_type text not null check (
    event_type in ('proposed', 'reviewed', 'published', 'corrected', 'withdrawn')
  ),
  previous_state public.publication_state,
  next_state public.publication_state not null,
  reason text,
  idempotency_key text not null,
  created_at timestamptz not null default now(),
  unique (school_id, idempotency_key)
);

create table public.conversations (
  id uuid primary key default gen_random_uuid(),
  school_id uuid not null references public.schools(id) on delete cascade,
  subject text,
  state public.conversation_state not null default 'active',
  created_by uuid not null references public.profiles(id) on delete restrict,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  closed_at timestamptz
);

create table public.conversation_participants (
  school_id uuid not null references public.schools(id) on delete cascade,
  conversation_id uuid not null references public.conversations(id) on delete cascade,
  user_id uuid not null references public.profiles(id) on delete cascade,
  joined_at timestamptz not null default now(),
  left_at timestamptz,
  last_read_at timestamptz,
  primary key (conversation_id, user_id),
  check (left_at is null or left_at >= joined_at)
);

create table public.messages (
  id uuid primary key default gen_random_uuid(),
  school_id uuid not null references public.schools(id) on delete cascade,
  conversation_id uuid not null references public.conversations(id) on delete cascade,
  sender_id uuid not null references public.profiles(id) on delete restrict,
  client_message_id uuid not null,
  body text not null,
  created_at timestamptz not null default now(),
  edited_at timestamptz,
  deleted_at timestamptz,
  unique (conversation_id, client_message_id)
);

create table public.file_bindings (
  id uuid primary key default gen_random_uuid(),
  school_id uuid not null references public.schools(id) on delete cascade,
  file_object_id uuid not null references public.file_objects(id) on delete restrict,
  resource_version_id uuid references public.resource_versions(id) on delete cascade,
  submission_attempt_id uuid references public.submission_attempts(id) on delete cascade,
  message_id uuid references public.messages(id) on delete cascade,
  ai_grading_draft_id uuid references public.ai_grading_drafts(id) on delete cascade,
  created_at timestamptz not null default now(),
  check (
    num_nonnulls(
      resource_version_id,
      submission_attempt_id,
      message_id,
      ai_grading_draft_id
    ) = 1
  )
);

alter table public.guardian_links
  add column evidence_file_id uuid references public.file_objects(id) on delete restrict;
alter table public.ai_grading_drafts
  add column file_object_id uuid references public.file_objects(id) on delete restrict;

create table public.upload_sessions (
  id uuid primary key default gen_random_uuid(),
  school_id uuid not null references public.schools(id) on delete cascade,
  uploader_id uuid not null references public.profiles(id) on delete restrict,
  purpose text not null,
  expected_size_bytes bigint not null check (expected_size_bytes >= 0),
  allowed_media_types text[] not null check (cardinality(allowed_media_types) > 0),
  nonce_hash text not null,
  state public.upload_session_state not null default 'initiated',
  expires_at timestamptz not null,
  completed_at timestamptz,
  file_object_id uuid references public.file_objects(id) on delete restrict,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (school_id, nonce_hash),
  check (expires_at > created_at),
  check (state <> 'completed' or (completed_at is not null and file_object_id is not null))
);

create table public.notification_outbox (
  id bigint generated always as identity primary key,
  school_id uuid not null references public.schools(id) on delete cascade,
  source_event_id text not null,
  idempotency_key text not null,
  channel text not null,
  template_key text not null,
  recipient_id uuid references public.profiles(id) on delete cascade,
  audience jsonb,
  payload jsonb not null default '{}'::jsonb,
  state public.outbox_state not null default 'pending',
  attempt_count integer not null default 0 check (attempt_count >= 0),
  next_attempt_at timestamptz not null default now(),
  last_error_code text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (school_id, idempotency_key),
  check (num_nonnulls(recipient_id, audience) = 1)
);

create table public.notification_deliveries (
  id bigint generated always as identity primary key,
  school_id uuid not null references public.schools(id) on delete cascade,
  outbox_id bigint not null references public.notification_outbox(id) on delete cascade,
  notification_id uuid references public.notifications(id) on delete set null,
  recipient_id uuid not null references public.profiles(id) on delete cascade,
  channel text not null,
  attempt integer not null check (attempt > 0),
  state public.delivery_state not null default 'pending',
  provider_message_id text,
  error_code text,
  attempted_at timestamptz not null default now(),
  delivered_at timestamptz,
  unique (outbox_id, recipient_id, channel, attempt)
);

create table public.store_products (
  id uuid primary key default gen_random_uuid(),
  feature_key text not null,
  platform public.store_platform not null,
  environment text not null check (environment in ('synthetic', 'development', 'staging', 'production')),
  store_product_id text not null,
  effective_from timestamptz not null default now(),
  effective_until timestamptz,
  active boolean not null default true,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (platform, environment, store_product_id),
  check (effective_until is null or effective_until >= effective_from)
);

create table public.store_transactions (
  id uuid primary key default gen_random_uuid(),
  platform public.store_platform not null,
  environment text not null check (environment in ('synthetic', 'development', 'staging', 'production')),
  purchaser_id uuid not null references public.profiles(id) on delete restrict,
  product_id uuid not null references public.store_products(id) on delete restrict,
  original_transaction_id text not null,
  transaction_id text not null,
  signed_data_hash text not null,
  state public.store_transaction_state not null,
  purchased_at timestamptz not null,
  effective_until timestamptz,
  created_at timestamptz not null default now(),
  unique (platform, environment, transaction_id)
);

create table public.store_events (
  id bigint generated always as identity primary key,
  platform public.store_platform not null,
  environment text not null check (environment in ('synthetic', 'development', 'staging', 'production')),
  external_event_id text,
  payload_hash text not null,
  state public.outbox_state not null default 'pending',
  attempt_count integer not null default 0 check (attempt_count >= 0),
  next_attempt_at timestamptz not null default now(),
  received_at timestamptz not null default now(),
  processed_at timestamptz,
  last_error_code text
);

create table public.entitlements (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references public.profiles(id) on delete cascade,
  school_id uuid references public.schools(id) on delete cascade,
  feature_key text not null,
  source public.store_platform not null,
  source_transaction_id uuid references public.store_transactions(id) on delete restrict,
  status public.entitlement_status not null,
  starts_at timestamptz not null,
  ends_at timestamptz,
  version bigint not null default 1 check (version > 0),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  check (ends_at is null or ends_at >= starts_at)
);

create table public.consent_policies (
  id uuid primary key default gen_random_uuid(),
  purpose text not null,
  policy_version text not null,
  locale text not null check (locale in ('en', 'ar')),
  title text not null,
  content_hash text not null,
  published_at timestamptz not null,
  effective_at timestamptz not null,
  retired_at timestamptz,
  created_at timestamptz not null default now(),
  unique (purpose, policy_version, locale),
  check (effective_at >= published_at),
  check (retired_at is null or retired_at >= effective_at)
);

alter table public.consent_records
  add column policy_id uuid references public.consent_policies(id) on delete restrict;

create table public.idempotency_records (
  id uuid primary key default gen_random_uuid(),
  school_id uuid references public.schools(id) on delete cascade,
  actor_id uuid not null references public.profiles(id) on delete cascade,
  scope text not null,
  idempotency_key text not null,
  request_hash text not null,
  status text not null check (status in ('reserved', 'completed', 'failed')),
  response_status integer,
  response_body jsonb,
  expires_at timestamptz not null,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  check (expires_at > created_at),
  check (status <> 'completed' or response_status is not null)
);

do $db020$
declare
  table_name text;
begin
  foreach table_name in array array[
    'schools', 'profiles', 'memberships', 'terms', 'students',
    'guardian_links', 'classrooms', 'enrollments', 'lesson_sessions',
    'lesson_materials', 'assignments', 'submissions', 'assessments',
    'assessment_questions', 'grade_results', 'attendance_records',
    'wellbeing_events', 'announcements', 'meetings', 'meeting_deliveries',
    'notifications', 'ai_grading_drafts', 'subscription_entitlements',
    'practice_sessions', 'consent_records', 'account_deletion_requests',
    'classroom_staff', 'class_schedules', 'resources',
    'resource_publications', 'conversations', 'upload_sessions',
    'notification_outbox', 'store_products', 'store_events', 'entitlements',
    'idempotency_records'
  ]
  loop
    execute format(
      'create trigger db020_set_updated_at before update on public.%I '
      'for each row execute function public.set_updated_at()',
      table_name
    );
  end loop;
end
$db020$;

do $db020$
declare
  table_name text;
begin
  foreach table_name in array array[
    'membership_events', 'classroom_staff', 'class_schedules', 'file_objects',
    'resources', 'resource_versions', 'resource_publications',
    'submission_attempts', 'grade_result_events', 'conversations',
    'conversation_participants', 'messages', 'file_bindings',
    'upload_sessions', 'notification_outbox', 'notification_deliveries',
    'store_products', 'store_transactions', 'store_events', 'entitlements',
    'consent_policies', 'idempotency_records'
  ]
  loop
    execute format('alter table public.%I enable row level security', table_name);
    execute format(
      'revoke all on table public.%I from anon, authenticated',
      table_name
    );
  end loop;
end
$db020$;
